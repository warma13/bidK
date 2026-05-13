-- ============================================================================
-- RecycleManager.lua - 物品回收/变现管理
-- 纯逻辑模块，无 UI 依赖。处理物品回收计价、按品质筛选等。
-- ============================================================================

local Config = require("Config")

local RecycleManager = {}

-- 品质排序（从低到高），用于自动回收时按品质优先级
local RARITY_ORDER = {}
for i, r in ipairs(Config.RARITY) do
    RARITY_ORDER[r.id] = i
end

--- 获取物品的回收价值（= 物品真实价值）
---@param item table
---@return number
function RecycleManager.GetRecycleValue(item)
    return item.realValue or item.baseValue or 0
end

--- 计算一批物品的总回收价值
---@param items table[]
---@return number
function RecycleManager.GetTotalRecycleValue(items)
    local total = 0
    for _, item in ipairs(items) do
        total = total + RecycleManager.GetRecycleValue(item)
    end
    return total
end

--- 按品质筛选物品（返回匹配和不匹配的两个列表）
---@param items table[] 物品列表
---@param selectedRarities table<string,boolean> 选中的品质 { white=true, green=true, ... }
---@return table[] toRecycle 需要回收的物品
---@return table[] toKeep 保留的物品
function RecycleManager.FilterByRarity(items, selectedRarities)
    local toRecycle = {}
    local toKeep = {}
    for _, item in ipairs(items) do
        local rarity = item.rarity or "white"
        if selectedRarities[rarity] then
            toRecycle[#toRecycle + 1] = item
        else
            toKeep[#toKeep + 1] = item
        end
    end
    return toRecycle, toKeep
end

--- 按品质从低到高排序物品（用于自动回收时优先回收低品质）
---@param items table[]
---@return table[] 排序后的新列表（不修改原列表）
function RecycleManager.SortByRarityAsc(items)
    local sorted = {}
    for i, item in ipairs(items) do
        sorted[i] = item
    end
    table.sort(sorted, function(a, b)
        local oa = RARITY_ORDER[a.rarity or "white"] or 0
        local ob = RARITY_ORDER[b.rarity or "white"] or 0
        if oa ~= ob then return oa < ob end
        -- 同品质按价值从低到高
        local va = a.realValue or a.baseValue or 0
        local vb = b.realValue or b.baseValue or 0
        return va < vb
    end)
    return sorted
end

--- 自动回收：从品质最低开始移除物品，直到剩余物品能放进仓库
--- 需要配合 WarehouseGrid 使用
---@param items table[] 待放入仓库的物品
---@param warehouseGrid table WarehouseGrid 模块引用
---@param gridInst table WarehouseGrid 实例（已包含现有物品）
---@return table[] kept 保留放入仓库的物品
---@return table[] recycled 被自动回收的物品
---@return number recycledValue 自动回收总金额
function RecycleManager.AutoRecycleForFit(items, warehouseGrid, gridInst)
    -- 按品质从低到高排序
    local sorted = RecycleManager.SortByRarityAsc(items)

    -- 尝试全部放入
    local placed, overflow = warehouseGrid.AutoPlaceMany(gridInst, sorted)
    if #overflow == 0 then
        return placed, {}, 0
    end

    -- 有溢出，需要回收。先全部撤出，然后从最低品质开始逐个尝试回收
    -- 撤回已放入的
    for _, item in ipairs(placed) do
        warehouseGrid.Remove(gridInst, item)
    end

    -- 从最低品质开始标记回收，直到剩余能放下
    local recycled = {}
    local recycledValue = 0
    local remaining = {}
    for i = 1, #sorted do
        remaining[i] = sorted[i]
    end

    -- 逐个从最低品质移除，每次尝试放入
    local tryIdx = 1
    while tryIdx <= #remaining do
        -- 尝试当前 remaining 列表放入
        local testPlaced, testOverflow = warehouseGrid.AutoPlaceMany(gridInst, remaining)
        if #testOverflow == 0 then
            -- 全部放下了
            return testPlaced, recycled, recycledValue
        end
        -- 放不下，撤回并回收最低品质的一个
        for _, item in ipairs(testPlaced) do
            warehouseGrid.Remove(gridInst, item)
        end

        -- 移除 remaining 中品质最低的（第一个，因为已排序）
        local victim = table.remove(remaining, 1)
        recycled[#recycled + 1] = victim
        recycledValue = recycledValue + RecycleManager.GetRecycleValue(victim)
    end

    -- 全部被回收了
    return {}, recycled, recycledValue
end

--- 获取品质排序值（数字越小品质越低）
---@param rarityId string
---@return number
function RecycleManager.GetRarityOrder(rarityId)
    return RARITY_ORDER[rarityId] or 0
end

return RecycleManager
