-- ============================================================================
-- DailyShop.lua - 每日商店管理器
-- ============================================================================
-- 功能：
--   - 每天凌晨0点刷新，基于当天日期确定性生成12个道具
--   - 权重：蓝色80，紫色30，金色10，红色1
--   - 允许重复出现相同道具
--   - GetRefreshText() 返回下次刷新倒计时字符串
-- ============================================================================

local Props = require("Config.Props")

local DailyShop = {}

-- ============================================================================
-- 权重表（按 tier 分配权重）
-- ============================================================================

local TIER_WEIGHTS = {
    blue   = 80,
    purple = 30,
    gold   = 10,
    red    = 1,
}

-- 从所有 dailyShop=true 的道具中按 tier 分组
local function BuildWeightedPool()
    local pool = {}  -- { def=..., weight=... }
    for _, p in ipairs(Props.LIST) do
        if p.dailyShop then
            local w = TIER_WEIGHTS[p.tier] or 0
            if w > 0 then
                pool[#pool + 1] = { def = p, weight = w }
            end
        end
    end
    return pool
end

-- ============================================================================
-- 简单 LCG 随机数生成器（日期种子，保证同一天结果相同）
-- ============================================================================

local function MakeLCG(seed)
    local s = seed
    return function()
        -- LCG 参数（Numerical Recipes）
        s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
        return s / 0x100000000  -- [0, 1)
    end
end

-- 将日期字符串 "YYYYMMDD" 转为整数种子
local function DateToSeed(year, month, day)
    return year * 10000 + month * 100 + day
end

-- 获取当前本地日期 (year, month, day)
local function GetToday()
    local t = os.date("*t")
    return t.year, t.month, t.day
end

-- ============================================================================
-- 加权随机选取
-- ============================================================================

local function WeightedPick(pool, rand)
    local totalWeight = 0
    for _, entry in ipairs(pool) do
        totalWeight = totalWeight + entry.weight
    end
    local r = rand() * totalWeight
    local acc = 0
    for _, entry in ipairs(pool) do
        acc = acc + entry.weight
        if r < acc then
            return entry.def
        end
    end
    -- fallback: 最后一个
    return pool[#pool].def
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 获取今日商店的12个道具列表（允许重复）
---@return table  道具定义数组（长度12）
function DailyShop.GetTodayItems()
    local pool = BuildWeightedPool()
    if #pool == 0 then return {} end

    local year, month, day = GetToday()
    local seed = DateToSeed(year, month, day)
    local rand = MakeLCG(seed)

    local items = {}
    for i = 1, 12 do
        items[i] = WeightedPick(pool, rand)
    end
    return items
end

--- 获取下次刷新倒计时字符串，如 "05:30后刷新"
---@return string
function DailyShop.GetRefreshText()
    local t = os.date("*t")
    -- 距离次日 00:00:00 的秒数
    local secondsLeft = (23 - t.hour) * 3600 + (59 - t.min) * 60 + (60 - t.sec)
    local hours   = math.floor(secondsLeft / 3600)
    local minutes = math.floor((secondsLeft % 3600) / 60)
    local seconds = secondsLeft % 60
    return string.format("%02d:%02d:%02d后刷新", hours, minutes, seconds)
end

return DailyShop
