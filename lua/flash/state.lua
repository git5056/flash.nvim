local require = require("flash.require")

local Cache = require("flash.cache")
local Config = require("flash.config")
local Hacks = require("flash.hacks")
local Highlight = require("flash.highlight")
local Jump = require("flash.jump")
local Matcher = require("flash.search.matcher")
local Pattern = require("flash.search.pattern")
local Prompt = require("flash.prompt")
local Rainbow = require("flash.rainbow")
local Search = require("flash.search")
local Util = require("flash.util")
local UtilLCG = require("flash.utillcg")


---@class Flash.State.Config: Flash.Config
---@field matcher? fun(win: window, state:Flash.State, pos: {from:Pos, to:Pos}): Flash.Match[]
---@field filter? fun(matches:Flash.Match[], state:Flash.State): Flash.Match[]
---@field pattern? string
---@field labeler? fun(matches:Flash.Match[], state:Flash.State)
---@field actions? table<string, fun(state:Flash.State, char:string):boolean?>

---@class Flash.State
---@field win window
---@field wins window[]
---@field cache Flash.Cache
---@field pos Pos
---@field view any
---@field results Flash.Match[]
---@field target? Flash.Match
---@field pattern Flash.Pattern
---@field opts Flash.State.Config
---@field labeler fun(matches:Flash.Match[], state:Flash.State)
---@field visible boolean
---@field matcher fun(win: window, state:Flash.State): Flash.Matcher
---@field matchers Flash.Matcher[]
---@field restore_windows? fun()
---@field rainbow? Flash.Rainbow
---@field ns number
---@field langmap table<string, string>
local M = {}
M.__index = M

---@type table<Flash.State, boolean>
M._states = setmetatable({}, { __mode = "k" })

function M.setup()
  if M._did_setup then
    return
  end
  M._did_setup = true
  local ns = vim.api.nvim_create_namespace("flash")
  vim.api.nvim_set_decoration_provider(ns, {
    on_start = function()
      for state in pairs(M._states) do
        if state.visible then
          local ok, err = pcall(state.update, state)
          if not ok then
            vim.schedule(function()
              vim.notify("Flash error during redraw:\n" .. err, vim.log.levels.ERROR, { title = "flash.nvim" })
            end)
          end
        end
      end
    end,
  })
end

---@param char string
function M:lmap(char)
  return vim.bo.iminsert == 1 and self.langmap[char] or char
end

function M:get_char()
  local ret = Util.get_char()
  return ret and self:lmap(ret) or nil
end

function M:labels()
  local labels = self.opts.labels
  if self.opts.label.uppercase then
    labels = labels .. self.opts.labels:upper()
  end
  local list = vim.fn.split(labels, "\\zs")
  local ret = {} ---@type string[]
  local added = {} ---@type table<string, boolean>
  for _, l in ipairs(vim.fn.split(self.opts.label.exclude, "\\zs")) do
    added[l] = true
  end
  for _, l in ipairs(list) do
    if not added[l] then
      added[l] = true
      ret[#ret + 1] = self:lmap(l)
    end
  end
  return ret
end

function M.is_search()
  local t = vim.fn.getcmdtype()
  return t == "/" or t == "?"
end

---@param opts? Flash.State.Config
function M.new(opts)
  M.setup()
  local self = setmetatable({}, M)
  self.opts = Config.get(opts)
  self.langmap = {}
  if vim.bo.iminsert == 1 then
    local lmap = vim.api.nvim_buf_get_keymap(0, "l")
    for _, m in ipairs(lmap) do
      if m.lhs ~= "" then
        self.langmap[m.lhs] = m.rhs
      end
    end
  end
  self.results = {}
  self.matchers = {}
  self.wins = {}
  self.matcher = self.opts.matcher
  if type(self.matcher) == "function" then
    self.matcher = Matcher.from(self.opts.matcher)
  elseif self.matcher == nil then
    self.matcher = Search.new
  end
  self.pattern = Pattern.new(self.opts.pattern, self.opts.search.mode, self.opts.search.trigger)
  self.visible = true
  self.cache = Cache.new(self)
  self.labeler = self.opts.labeler or require("flash.labeler").new(self):labeler()
  self.ns = vim.api.nvim_create_namespace(self.opts.ns or "flash")
  M._states[self] = true
  if self.opts.label.rainbow.enabled then
    self.rainbow = Rainbow.new(self)
  end

  self:update()
  return self
end

---@param target? string|Flash.Match.Find|Flash.Match
---@return Flash.Match?
function M:jump(target)
  local match ---@type Flash.Match?
  if type(target) == "string" then
    --match = self:find({ label = target })
    match = self:find({ label = target ,able_aimtwo=true})
  elseif target and target.end_pos then
    match = target
  elseif target then
    match = self:find(target)
  else
    match = self.target
  end
  -- if match then
  --   if self.opts.action then
  --     self.opts.action(match, self)
  --   else
  --     Jump.jump(match, self)
  --     Jump.on_jump(self)
  --   end
  --   return match
  -- end

  if match and not self.onlytwo then
    -- 原有逻辑
    if self.opts.action then
      self.opts.action(match, self)
    else
      Jump.jump(match, self)
      Jump.on_jump(self)
    end
    return match
  end

  -- 从最后2项中最终命中
  if self.modelsp == 1  and match and self.onlytwo and self.aim_final then
    if self.opts.action then
      self.opts.action(match, self)
    else
      Jump.jump(match, self)
      Jump.on_jump(self)
    end
    return match
  end

  if self.modelsp == 1 then
    -- 为最后2项指定label
    if match and self.onlytwo then
      match.label = "s"
      self.count_onlytwo_tmp = 1
      if match == self.onlytwoitems[1] then
        self.onlytwoitems[2].label =   self.onlytwoitems[2].label:lower()
        self.modelsimulate_step = 0
        self.modelsimulate_another_key = self.onlytwoitems[2].label
      else 
        self.onlytwoitems[1].label =   self.onlytwoitems[1].label:lower()
        self.modelsimulate_step = 1 
        self.modelsimulate_another_key = self.onlytwoitems[1].label
      end
      
      if self.modelspautojump then
        self.modelsimulate = self.onlytwoitems
        Jump.jump(match, self)
        Jump.on_jump(self)
        return match
      end 

      if self.opts.action then
        -- self.opts.action(match, self)
      else
        -- Jump.jump(match, self)
        -- Jump.on_jump(self)
      end
      -- return match
    end

  end

end

-- Will restore all window views
function M:restore()
  if self.restore_windows then
    self.restore_windows()
  end
end

function M:get_matcher(win)
  self.matchers[win] = self.matchers[win] or self.matcher(win, self)
  return self.matchers[win]
end

---@param opts? Flash.Match.Find | {label?:string, pos?: Pos}
function M:find(opts)
  -- if opts and opts.label then
  --   for _, m in ipairs(self.results) do
  --     if m.label == opts.label then
  --       return m
  --     end
  --   end
  --   return
  -- end
  
  if opts and opts.label then
     if not self.onlytwo then
        self.onlytwoitems={}
     end

     if self.modelsp == 1 then
        self.modelsp_s = false 
        if opts.label == "a" and (self.modelsp_step or 0) > 1 then
          for key, value in pairs(self.modelsp_matchers_allmap) do
            if value.modelsp_step == self.modelsp_step then
                value.modelsp_step = self.modelsp_step - 1
                self.modelsp_s = true
            end
          end          

          if self.modelsp_s then
            self.modelsp_step = self.modelsp_step - 1 
            return
          end
        end
        if opts.label == "s" then
        --  require("flash.util").log("qweqw",{},"")
         local winmap ={} 
         if #self.results > 0 then 
          -- and #self.modelsp_matchers_allmap > 0 then
        --  require("flash.util").log("2qweqw",{},"")
            -- 需要排除的
            for _, m in ipairs(self.results) do
              -- require("flash.util").log("3qweqw",{},"")
               local buf = winmap[m.win] or vim.api.nvim_win_get_buf(m.win)
               winmap[m.win] = buf
               id = m.pos:id(buf) 
               local tmpm = self.modelsp_matchers_allmap[id] 
               if m.label == nil and self.modelsp_matchers_allmap[id] then
                --  if tmpm.modelsp_step ~= self.modelsp_step then
                   tmpm.modelsp_step = tmpm.modelsp_step + 1 
                  --  require("flash.util").log("aaaaaxxxxx",tmpm,"")
                --  end
               end 
            end
          self.modelsp_step = self.modelsp_step + 1
          self.modelsp_s = true 
          end 
        return 
        end
     end

     local target_lower =  opts.label and   opts.label:lower() or ""
     local target_islower = target_lower == opts.label
     local count_aim = 0
     local m_aim = nil
    for _, m in ipairs(self.results) do
        local chars = vim.fn.strchars(m.label)
        local label_lower = m.label and m.label:lower() or ""
        local label_islower = label_lower == m.label

        if self.modelsp == 1 and label_lower == target_lower and target_lower ~= "" then
          count_aim =count_aim + 1
          if not self.onlytwo then
            table.insert(self.onlytwoitems, m)
          end
          if m_aim == nil then
            m_aim = m
          elseif (label_islower == true) then
            -- 优先命中小写的label
            m_aim = m
          end
 
          if target_islower == false and label_islower == false then
            if self.onlytwo then
              self.aim_final = true
            end
            return m
          end
          if count_aim == 2 then
            if opts.able_aimtwo then
              -- 重复按相同键位或者按指定切换键位进行切换
              self.onlytwo = true
              return m_aim
            end

            -- 提前返回,已命中且只存在最后2个可选择切换项,后面的比较无意义
            return 
          end
        else
          -- 原有逻辑
          if m.label == opts.label then
            return m
          end

        end
    end

    if count_aim == 1 and m_aim ~= nil then
      if self.onlytwo then
        self.aim_final = true
      end
      return m_aim
    end

    return 
  end

  opts = Matcher.defaults({
    forward = self.opts.search.forward,
    wrap = self.opts.search.wrap,
  }, opts)


  local matcher = self:get_matcher(self.win)
  local ret = matcher:find(opts)
  -- Util.log("get_matcher",{opts,ret,self.results})
  if ret then
    for _, m in ipairs(self.results) do
      if m.pos == ret.pos and m.end_pos == ret.end_pos then
        return m
      end
    end
  end
  return ret
end

-- Checks if the given pattern is a jump label and jumps to it.
---@param pattern string
function M:check_jump(pattern)
  if not self.visible then
    return
  end

  if self.opts.search.trigger ~= "" and self.pattern():sub(-1) ~= self.opts.search.trigger then
    return
  end
  local chars = vim.fn.strchars(pattern)

  if pattern:find(self.pattern(), 1, true) == 1 and chars == vim.fn.strchars(self.pattern()) + 1 then
    local label = vim.fn.strcharpart(pattern, chars - 1, 1)
    if self:jump(label) then
      return true
    end
  end

  -- if pattern:find(self.pattern(), 1, true) == 2 and chars == vim.fn.strchars(self.pattern()) + 1 then
  --   local label = vim.fn.strcharpart(pattern, chars - 1, 1)
  --   if self:jump(label) then
  --     return true
  --   end
  -- end
end

---@param opts? {pattern:string, force:boolean, check_jump:boolean}
---@return boolean? abort `true` if the search was aborted
function M:update(opts)
  opts = opts or {}

  local modelsp_s = false
  if opts.pattern then
    -- abort if pattern is a jump label
    if opts.check_jump ~= false and self:check_jump(opts.pattern) then
      return true
    end

    -- self.pattern:set(opts.pattern)

    if  self.modelsp == 1 and self.count_onlytwo_tmp == 1 and self.onlytwo then
      self.count_onlytwo_tmp = 2
      -- 仅过滤到最后2项的时候不设置新的匹配项,其他情况照旧
      -- self.pattern:set(opts.pattern_orig)
    else 
      if self.modelsp == 1 and self.modelsp_s == true and (self.modelsp_inputkey == "s" or self.modelsp_inputkey == "a" ) then 
       -- 排除某些选择项,故不进行set pattern  
       modelsp_s = true
      else
        self.pattern:set(opts.pattern)
      end 

      -- self.pattern:set(opts.pattern)
    end

  end

  if not self.visible then
    return
  end

  -- if self.cache:update() or opts.force then
  --   self:_update()
  -- end
  if  self.modelsp == 1 and self.count_onlytwo_tmp == 2 and self.onlytwo then
    self.count_onlytwo_tmp = 3
    if self.cache:update({forceflush=true}) or opts.force then
      self:_update()
    end
  elseif self.modelsp == 1 and modelsp_s then 
    -- require("flash.util").log("jjjjjqwe", {})
    if self.cache:update({forceflush=true}) or opts.force then
      -- require("flash.util").log("lllqwe", {})
      self:_update()
    end
  else
    -- 原有逻辑
    if self.cache:update() or opts.force then
      self:_update()
    end
  end

end

function M:hide()
  if self.visible then
    self.visible = false
    Highlight.clear(self.ns)
  end
end

function M:show()
  if not self.visible then
    self.visible = true
    -- force cache to update win and position
    self.win = nil
    self:update({ force = true })
  end
end

function M:_update()
  -- This is needed because we trigger searches during redraw.
  -- We need to save the state of the incsearch so that current match
  -- will still be displayed correctly.
  if M.is_search() then
    Hacks.save_incsearch_state()
  end

  local lastres = self.results
  self.results = {}
  local done = {} ---@type table<string, boolean>
  ---@type Flash.Matcher[]
  local matchers = {}
  for _, win in ipairs(self.wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    matchers[win] = self:get_matcher(win)
    local state = self.cache:get_state(win)
    -- Util.log("eeeeee",{state},"")
    for _, m in ipairs(state and state.matches or {}) do
      local id = m.pos:id(buf) .. m.end_pos:id(buf)
        -- Util.log("zxcvvxv",id,"")
      if not done[id] then
        done[id] = true
        table.insert(self.results, m)
        --Util.log("vvxxxvvv",self.results,"")
      end
    end
  end
  self.matchers = matchers

  for _, match in ipairs(self.results) do
    vim.api.nvim_win_call(match.win, function()
      local fold = vim.fn.foldclosed(match.pos[1])
      match.fold = fold ~= -1 and fold or nil
    end)
  end

  self:update_target()
  self.labeler(self.results, self)

  if M.is_search() then
    Hacks.restore_incsearch_state()
  end

  Highlight.update(self)
end

function M:update_target()
  -- set target to next match.
  -- When not using incremental search,
  -- we need to set the target to the previous match
  self.target = self:find({
    pos = self.pos,
    count = vim.v.count1,
  })

  local info = vim.fn.getwininfo(self.win)[1]
  local function is_visible()
    return self.target and self.target.pos[1] >= info.topline and self.target.pos[1] <= info.botline
  end

  if self.opts.search.incremental then
    -- only update cursor if the target is not visible
    -- and we are not activated
    if self.target and not self.is_search() then
      vim.api.nvim_win_set_cursor(self.win, self.target.pos)
    end
  elseif not is_visible() then
    self.target = self:find({
      pos = self.pos,
      count = vim.v.count1,
      forward = not self.opts.search.forward,
    })
    if not is_visible() then
      self.target = nil
    end
  end
end

---@class Flash.Step.Options
---@field actions? table<string, fun(state:Flash.State, char:string):boolean?>
---@field restore? boolean
---@field abort? fun()
---@field jump_on_max_length? boolean

---@param opts? Flash.Step.Options
function M:step(opts)
  opts = opts or {}
  if not M.is_search() then
    Prompt.set(self.pattern(), self.opts.prompt.enabled)
  end
  local actions = opts.actions or self.opts.actions or {}
  local c = self:get_char()
  Util.log("char input", {c})
  self.modelsp_inputkey = c
  if c == nil then
    vim.api.nvim_input("<esc>")
    if opts.restore ~= false then
      self:restore()
    end
    if opts.abort then
      opts.abort()
    end
    return
  elseif actions[c] then
    local ret = actions[c](self, c)

    if ret == nil then
      return true
    end
    return ret
    -- jump to first
  elseif c == Util.CR then
    self:jump()
    return
  end

  local orig = self.pattern()
  self.pattern_orig = orig

  -- break if we jumped
  if self:update({ pattern = self.pattern:extend(c) }) then
    return
  end

  -- when we exceed max length, either jump to the label,
  -- or input the last key and break
  if self.opts.search.max_length and #self.pattern() > self.opts.search.max_length then
    self:update({ pattern = orig })
    if opts.jump_on_max_length ~= false then
      self:jump()
    end
    vim.api.nvim_input(c)
    return
  end

  -- exit if no results and not in regular search mode
  if #self.results == 0 and not self.pattern:empty() and self.pattern.mode ~= "search" then
    if self.opts.search.incremental then
      vim.api.nvim_input(c)
    end
    return
  end
  --self.opts.jump.autojump = true
  -- autojump if only one result
  if #self.results == 1 and self.opts.jump.autojump then
    self:jump()
    return
  end
  return true
end

---@param opts? Flash.Step.Options
function M:loop(opts)
  while self:step(opts) do
  end
  self:hide()
  -- Prompt.hide()
  if self.modelsp == 1 and self.onlytwo and self.modelsimulate then
    -- 默认选中一个，另外的则若再次输入,则切换光标位置,此时只有s键和目标label可以使用,
    -- 若其他按键则退出,且当作在普通模式的一次输入
    -- 因此若想要再次进入s的选择状态，需要按下其他键列如同时按下jk
    Prompt.set("current in flash tmp switch model,please press [" .. self.modelsimulate_another_key .. "] to switch to another label by you last selected one,or other key to use like as normal model",true)
    while true do
      local c = self:get_char()
      Util.log("char input2", {c})
      -- Util.log("input key", {c})
      -- if not (c == "s" or c == self.modelsimulate_another_key)then
      if not (c == self.modelsimulate_another_key) then
        Prompt.hide()
        if c == nil then
          vim.api.nvim_input("<esc>")
          return
        end

        vim.api.nvim_input(c)
        return
      end
      self.modelsimulate_step = self.modelsimulate_step + 1
      local match = self.modelsimulate[self.modelsimulate_step%2+1]
      -- Util.log("sw cursor", {match,self.modelsimulate,self.modelsimulate_step%2+1})
      Jump.jump(match, self)
      Jump.on_jump(self)
    end
  end

  Prompt.hide()
end

return M
