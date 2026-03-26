-- ============================================================================
-- Config/WarehouseUpgrade.lua - 仓库升级配置与逻辑
-- ============================================================================

local WarehouseUpgrade = {}

-- 各等级容量
WarehouseUpgrade.LEVELS = {
    [1] = { capacity = 100 },
    [2] = { capacity = 150 },
    [3] = { capacity = 200 },
}

WarehouseUpgrade.MAX_LEVEL = 3

-- 升级消耗（从 level → level+1）
-- items: { { name=物品名, rarity=品质, count=所需数量 }, ... }
-- gold: 金币消耗
WarehouseUpgrade.COSTS = {
    -- Lv.1 → Lv.2
    [1] = {
        items = {
            { name = "铜墨盒",   rarity = "green", count = 2 },
            { name = "老铜锁",   rarity = "green", count = 2 },
            { name = "青花瓷片", rarity = "blue",  count = 1 },
        },
        gold = 3000,
    },
    -- Lv.2 → Lv.3
    [2] = {
        items = {
            { name = "老胶片相机", rarity = "blue",   count = 2 },
            { name = "绿松石珠串", rarity = "blue",   count = 1 },
            { name = "鼻烟壶",     rarity = "purple", count = 1 },
            { name = "机械秒表",   rarity = "purple", count = 1 },
        },
        gold = 30000,
    },
}

--- 获取指定等级的容量
---@param level number
---@return number
function WarehouseUpgrade.GetCapacity(level)
    local data = WarehouseUpgrade.LEVELS[level]
    return data and data.capacity or WarehouseUpgrade.LEVELS[1].capacity
end

--- 获取升级到下一级所需的消耗
---@param currentLevel number
---@return table|nil  nil 表示已满级
function WarehouseUpgrade.GetUpgradeCost(currentLevel)
    return WarehouseUpgrade.COSTS[currentLevel]
end

--- 检查玩家是否满足升级条件
---@param currentLevel number 当前仓库等级
---@param items table 玩家拥有的物品列表（SaveSystem 格式，字段: name, rarity）
---@param gold number 玩家当前金币
---@return boolean canUpgrade 是否可升级
---@return table details 各条件的满足情况 { items = { {name, rarity, need, have, ok}, ... }, gold = {need, have, ok} }
function WarehouseUpgrade.CheckUpgrade(currentLevel, items, gold)
    if currentLevel >= WarehouseUpgrade.MAX_LEVEL then
        return false, nil
    end

    local cost = WarehouseUpgrade.COSTS[currentLevel]
    if not cost then
        return false, nil
    end

    -- 统计玩家物品数量（按名称）
    local itemCounts = {}
    for _, item in ipairs(items) do
        local name = item.name
        itemCounts[name] = (itemCounts[name] or 0) + 1
    end

    local allOk = true
    local details = { items = {}, gold = {} }

    for _, req in ipairs(cost.items) do
        local have = itemCounts[req.name] or 0
        local ok = have >= req.count
        if not ok then allOk = false end
        details.items[#details.items + 1] = {
            name = req.name,
            rarity = req.rarity,
            need = req.count,
            have = have,
            ok = ok,
        }
    end

    local goldOk = gold >= cost.gold
    if not goldOk then allOk = false end
    details.gold = {
        need = cost.gold,
        have = gold,
        ok = goldOk,
    }

    return allOk, details
end

--- 执行升级：从物品列表中消耗指定物品（返回新列表和消耗的金币数）
---@param currentLevel number
---@param items table 玩家物品列表（会被修改）
---@return table newItems 消耗后的物品列表
---@return number goldCost 消耗的金币数
function WarehouseUpgrade.ConsumeItems(currentLevel, items)
    local cost = WarehouseUpgrade.COSTS[currentLevel]
    if not cost then return items, 0 end

    -- 按需消耗物品（从后往前删，避免索引错乱）
    for _, req in ipairs(cost.items) do
        local remaining = req.count
        -- 收集要删除的索引
        local toRemove = {}
        for i, item in ipairs(items) do
            if remaining <= 0 then break end
            if item.name == req.name then
                toRemove[#toRemove + 1] = i
                remaining = remaining - 1
            end
        end
        -- 从后往前删
        for j = #toRemove, 1, -1 do
            table.remove(items, toRemove[j])
        end
    end

    return items, cost.gold
end

return WarehouseUpgrade
