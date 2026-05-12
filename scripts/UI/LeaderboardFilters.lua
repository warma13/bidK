-- ============================================================================
-- UI/LeaderboardFilters.lua - 排行榜过滤规则（模块化）
-- 每条规则是一个 { name, fn } 对象，fn(item) 返回 true 表示允许显示
-- ============================================================================

local LeaderboardFilters = {}

-- 1千亿 = 100,000,000,000
-- money_rank 以万为单位，所以阈值 = 100,000,000,000 / 10,000 = 10,000,000
local CHEAT_MONEY_RANK_THRESHOLD = 10000000

local filters = {
    {
        name = "cheat_money",
        fn = function(item)
            local rankValue = item.iscore and item.iscore.money_rank or 0
            return rankValue <= CHEAT_MONEY_RANK_THRESHOLD
        end,
    },
}

--- 判断某条排行榜数据是否允许显示
---@param item table 排行榜条目（含 userId, iscore）
---@return boolean
function LeaderboardFilters.IsAllowed(item)
    for _, f in ipairs(filters) do
        if not f.fn(item) then return false end
    end
    return true
end

--- 动态添加过滤规则
---@param name string 规则名（用于后续 Remove）
---@param fn function(item): boolean 返回 true 表示允许
function LeaderboardFilters.Add(name, fn)
    filters[#filters + 1] = { name = name, fn = fn }
end

--- 移除指定名称的过滤规则
---@param name string
function LeaderboardFilters.Remove(name)
    for i, f in ipairs(filters) do
        if f.name == name then
            table.remove(filters, i)
            return
        end
    end
end

return LeaderboardFilters
