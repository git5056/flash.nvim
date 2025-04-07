---@class Flash.Labeler
---@field state Flash.State
---@field used table<string, string>
---@field labels string[]
local M = {}
M.__index = M

function M.new(state)
  M.initonce()
  local self
  self = setmetatable({}, M)
  self.state = state
  self.used = {}
  self:reset()
  return self
end

 local labels_left = "qwerdfcxzQWERDFCXZ"
 local labels_right = "phojukilnPHOJUKILN"
 local labels_sp = "as"

function M.keymap(obj,str)
    for i = 1, #str do
    local ch = str:sub(i,i)
    -- local zb = string.byte(str,i)
    obj[ch] = true 
    -- print(string.byte(str, i)) -- 打印字节值
    -- print(str:sub(i, i)) -- 打印字节对应的字符
  end
end

function M.initonce()
  if M.isinitq then
    return
  end
  M.labels_left_map={}
  M.labels_right_map={}
  M.labels_sp_map={}
 require("flash.utillcg").dotest() 
 M.keymap(M.labels_left_map,labels_left or "") 
 M.keymap(M.labels_right_map,labels_right or "") 
 M.keymap(M.labels_sp_map,labels_sp or "") 
  M.isinitq = true
  M.labels_left = {}
  M.labels_left_a = {}
  M.labels_right = {}
  M.labels_sp = {}
  M.labels_Aa_map = {}
  M.labels_left_notA = {}
  local ba = string.byte("a",1)
  local bz = string.byte("z",1)
  local bA = string.byte("A",1)
  local bZ = string.byte("Z",1)
  local aAd = string.byte("A",1) - ba 
  -- local str = require("flash.config").defaults.labels_left
  local str = labels_left or ""
  for i = 1, #str do
    table.insert(M.labels_left,str:sub(i,i))
    local lower = str:sub(i,i):lower()
    local upper = str:sub(i,i):upper()
    local isupper = upper == str:sub(i,i)
    local zb = string.byte(str,i)
    -- require("flash.util").log("vvxxxvvvqq",{lower, zb,ba,bz},"")
    if not (bA <= zb and zb <= bZ) then
      table.insert(M.labels_left_notA,str:sub(i,i))
    end
    if ba <= zb and zb <= bz then
      table.insert(M.labels_left_a,str:sub(i,i))
      if M.labels_left_map[upper] then
        local zbg = zb + aAd
        M.labels_Aa_map[lower] = upper 
        -- require("flash.util").log("123vvxxxvvvqq",{zbg},"")
      end 
    end
    -- require("flash.util").log("vvxxxvvvqq",{M.labels_Aa_map},"")
  end

  M.labels_left_count = #M.labels_left
  M.labels_left_a_count = #M.labels_left_a
  M.labels_left_notA_count = #M.labels_left_notA
  
  str = labels_right or ""
  -- str = require("flash.config").defaults.labels_right
  for i = 1,  #str do
    table.insert(M.labels_right,str:sub(i,i))
  end
  
  str = labels_sp or ""
  -- str = require("flash.config").defaults.labels_sp
  for i = 1, #str do
    table.insert(M.labels_sp,str:sub(i,i))
  end
end

function M:labeler()
  return function()
    return self:update()
  end
end

function M:update()
  if #self.state.pattern() < self.state.opts.label.min_pattern_length then
    return
  end

  local matches = self:filter()
  self.cur_matches = matches

  self:reset()

  if #self.state.pattern() < self.state.opts.label.min_pattern_length then
    return
  end

  --[[ local matches = self:filter()
  self.cur_matches = matches
   ]]
  for _, match in ipairs(matches) do
    -- self:label(match, true)
  end

  for _, match in ipairs(matches) do
    if not self:label(match) then
      break
    end
  end
end

function M:reset()
  local skip = {} ---@type table<string, boolean>
  self.labels = {}

  -- require("flash.util").log("rese",{"aa"},"")
  if self.state.modelsp == 1 then
    if self.state.onlytwo then
      self.labels = { self.state.onlytwoitems[1].label, self.state.onlytwoitems[2].label}
      return
    end
  end

  for _, l in ipairs(self.state:labels()) do
    if not skip[l] then
      self.labels[#self.labels + 1] = l
      skip[l] = true
    end
  end
  if not self.state.opts.search.max_length or #self.state.pattern() < self.state.opts.search.max_length then
    for _, win in pairs(self.state.wins) do
      self.labels = self:skip(win, self.labels)
    end
  end
  for _, m in ipairs(self.state.results) do
    if m.label ~= false then
      m.label = nil
    end
  end
end

function M:valid(label)
--[[   if self.modellabel == 2 then
    -- 这个验证有点多余，直接返回true
    return true
  end ]]
  return vim.tbl_contains(self.labels, label)
end

function M:use(label)
  self.labels = vim.tbl_filter(function(c)
    return c ~= label
  end, self.labels)
end

---@param m Flash.Match
---@param used boolean?
function M:label(m, used)
  if m.label ~= nil then
    return true
  end
  local notrm = false
  local pos = m.pos:id(m.win)
  local label ---@type string?
  if used then
    label = self.used[pos]
  else
    label = self.labels[1]
    if self.modellabel == 2 then
      local isUseUpper = false
      local isUseLower = false
      if label then
          isUseLower = label == label:lower() 
      -- if self.modellabel_lastsel then
        -- if M.labels_Aa_map[self.modellabel_lastsel] then 
          --label = M.labels_Aa_map[self.modellabel_lastsel]
          -- isUseUpper = true
        -- end
        -- self.modellabel_lastsel = nil
      -- end
        if isUseLower and  M.labels_Aa_map[label] then
           notrm = true
        end
      end
    end
  end

  if label and self:valid(label) then
    if not notrm then
      self:use(label)
    end 
    local reuse = self.state.opts.label.reuse == "all"
      or (self.state.opts.label.reuse == "lowercase" and label:lower() == label)

    if reuse then
      self.used[pos] = label
    end
    m.label = label
    local debug = false
    -- debug  = true
    if debug and self.modellabel == 2 then
      self.modellabel_step = self.modellabel_step + 1 
      m.label = label .. self.modellabel_step
    end
    if notrm then
      -- 不删除，将当前的小写字母替换为其大写字母，继续使用
      self.labels[1] = M.labels_Aa_map[label]
      self.modellabel_lastsel = nil
    end
  end
  return #self.labels > 0
end

function M:filter()
  ---@type Flash.Match[]
  local ret = {}

  local target = self.state.target

  local from = vim.api.nvim_win_get_cursor(self.state.win)
  ---@type table<number, boolean>
  local folds = {}

  -- only label visible matches
  for _, match in ipairs(self.state.results) do
    -- and don't label the first match in the current window
    local skip = (target and match.pos == target.pos)
      and not self.state.opts.label.current
      and match.win == self.state.win

    -- Only label the first match in each fold
    if not skip and match.fold then
      if folds[match.fold] then
        skip = true
      else
        folds[match.fold] = true
      end
    end

    if not skip then
      table.insert(ret, match)
    end
  end

  local theself = self
  -- sort by current win, other win, then by distance
  table.sort(ret, function(a, b)
    local use_distance = self.state.opts.label.distance and a.win == self.state.win
      -- require("flash.util").log("xxxxsort",{use_distance})
    -- if theself.modellabel > 0 then
    if (theself.state.modelsp == 1)  then
      use_distance = true and a.win == self.state.win
    end

    -- use_distance =true
    if a.win ~= b.win then
      local aw = a.win == self.state.win and 0 or a.win
      local bw = b.win == self.state.win and 0 or b.win
      return aw < bw
    end
    -- 计算相距当前光标的距离，从近及远(曼哈顿距离)
    -- 优先当前光标同一行的项，顺序从左及右(目的是用来替代f快捷键查询当前行的字符)
     if (theself.state.modelsp == 1) and use_distance  then
      if a.pos[1] == b.pos[1] and a.pos[1] == from[1] then
        return a.pos[2] < b.pos[2]
      end 
      if a.pos[1] == from[1] then
        return true
      elseif b.pos[1] == from[1] then
        return false
      end
    -- if (theself.modellabel or 0) > 0 and use_distance then
     local da = math.abs( from[1] - a.pos[1]) + math.abs(from[2] - a.pos[2]) 
     local db = math.abs( from[1] - b.pos[1]) + math.abs(from[2] - b.pos[2]) 
      -- require("flash.util").log("sort",{da,db})
      return da < db
    end
    if use_distance then
      local dfrom = from[1] * vim.go.columns + from[2]
      local da = a.pos[1] * vim.go.columns + a.pos[2]
      local db = b.pos[1] * vim.go.columns + b.pos[2]
      return math.abs(dfrom - da) < math.abs(dfrom - db)
    end
    if a.pos[1] ~= b.pos[1] then
      return a.pos[1] < b.pos[1]
    end
    return a.pos[2] < b.pos[2]
  end)
  return ret
end

-- Returns valid labels for the current search pattern
-- in this window.
---@param labels string[]
---@return string[] returns labels to skip or `nil` when all labels should be skipped
function M:skip(win, labels)
  local pattern = self.state.pattern.skip

  -- skip all labels if the pattern is empty
  if pattern == "" then
    return {}
  end

  -- skip all labels if the pattern is invalid
  local ok = pcall(vim.regex, pattern)
  if not ok then
    return {}
  end

  -- skip all labels if the pattern ends with a backslash
  -- except if it's escaped
  if pattern:find("\\$") and not pattern:find("\\\\$") then
    return {}
  end

  vim.api.nvim_win_call(win, function()
    while #labels > 0 do
      -- this is needed, since an uppercase label would trigger smartcase
      local label_group = table.concat(labels, "")
      if vim.go.ignorecase then
        label_group = label_group:lower()
      end

      local p = "\\%(" .. pattern .. "\\)\\m\\zs[" .. label_group .. "]"
      local pos
      ok, pos = pcall(vim.fn.searchpos, p, "cnw")

      if not ok then
        labels = {}
        break
      end

      -- not found, we're done
      if pos[1] == 0 then
        return
      end

      local line = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1]
      local char = vim.fn.strpart(line, pos[2] - 1, 1, true)

      local label_count = #labels
      labels = vim.tbl_filter(function(c)
        -- when ignorecase is set, we need to skip
        -- both the upper and lower case labels
        if vim.go.ignorecase then
          return c:lower() ~= char:lower()
        end
        return c ~= char
      end, labels)

      -- HACK: this will fail if the pattern is an incomplete regex
      -- In that case, we skip all labels
      if label_count == #labels then
        labels = {}
        break
      end
    end
  end)
  self.modellabel = 0
  self.modellabel_step = 0
  if self.state.modelsp == 1 then
    local t = self.cur_matches or {}
    labels = M.labels_left_notA
    -- require("flash.util").log("12312vvqq",{labels},"")
    if #t <= M.labels_left_notA_count then
      -- labels = {"q","w","e","r","d","f","z","x","c","Q","W","E","R","D","F","C","Z","X","C"}
      -- 仅使用非大写
      labels = M.labels_left_notA
      self.modellabel = 1
    else 
      -- 使用所有
      self.modellabel = 2 
      --  {"q","w","e","r","d","f","z","x","c","Q","W","E","R","D","F","C","Z","X","C"}
    end
      --labels = {"Q","W","E","R","D","F","C","Z","X","C"}
  end
  return copy_array(labels)
  -- return labels
end

function copy_array(orig)
    local copy = {}
    for key, value in pairs(orig) do
        copy[key] = value
    end
    return copy
end
 
return M
