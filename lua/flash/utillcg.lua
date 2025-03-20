-- 简单用一下。因为默认的math的貌似不能随意设置随机种子。可能是我没找到
-- 线性同余法生成器
local LCG = {}
LCG.__index = LCG

function LCG.new(seed, a, c, m)
    -- 初始化参数
    -- a, c, m 是线性同余法的参数
    -- 通常 a, c, m 需要是互质的，并且 m 是一个较大的质数
    -- 一个常用的选择是 a = 1664525, c = 1013904223, m = 2^32
    local obj = {
        seed = seed % m, -- 确保种子在 m 的范围内
        a = a,
        c = c,
        m = m
    }
      local self = setmetatable(obj, LCG)
return self 
end

function LCG.newrnd(seed)
  return LCG.new(seed, 1664525, 1013904223, 4294967296) 
end
 
function LCG:next()
    -- 计算下一个随机数
    self.seed = (self.a * self.seed + self.c) % self.m
    return self.seed / self.m -- 归一化到 [0, 1)
end

function LCG:nextint(maxnum)
   return math.floor(self:next() * maxnum)
end

function LCG.dotest()
  return
end
function LCG.dotest2()
  
  -- -- 使用示例
  local lcg = LCG.new(123456789, 1664525, 1013904223, 4294967296) -- 使用一个大质数作为模数 m
  for i = 1, 10 do
   require("flash.util").log("xx",{lcg:nextint(100)},"")
   print(lcg:next(100)) -- 打印接下来的10个随机数
  end

  local arr ={1,2,3,4,5,6,7,8,9,10}
  local arr_used ={}
  for i = 1, #arr do
    local idx = lcg:nextint(#arr-i)
    local idx0=idx
    idx=idx+1
    local idx2 = idx
--[[     while arr_used[idx2] ~= nil do 
     if arr_used[idx] then
      idx2 = arr_used[idx] 
     end 
    end
 ]]
    
    arr_used[idx2] = idx2+1
    --[[ if arr_used[idx2+1] then
      arr_used[idx2] = arr_used[idx2+1]
    else
      arr_used[idx2] = idx2+1
    end ]]

    require("flash.util").log("qqqxx",{"这是第" .. i .. "次循环:" .. idx0 ..":".. idx2 ..":".. (arr[idx2] or "a") .. "\n"})
    -- print("这是第" .. i .. "次循环:" .. arr[idx2] .. "\n")
end

end

return LCG