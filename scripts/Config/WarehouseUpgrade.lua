-- ============================================================================
-- Config/WarehouseUpgrade.lua - 仓库升级配置与逻辑
-- 纯金币升级，每次扩展 4 行
-- ============================================================================

local Config = require("Config")

local WarehouseUpgrade = {}

-- 基础行数（初始仓库）
WarehouseUpgrade.BASE_ROWS = 5

-- 每次升级增加的行数
WarehouseUpgrade.ROWS_PER_UPGRADE = 4

-- 各等级配置（行数 = BASE_ROWS + (level-1) * ROWS_PER_UPGRADE）
WarehouseUpgrade.LEVELS = {
    [1] = { rows = 5 },    -- 初始: 30×5  = 150 格
    [2] = { rows = 9 },    -- 升级1: 30×9  = 270 格
    [3] = { rows = 13 },   -- 升级2: 30×13 = 390 格
    [4] = { rows = 17 },   -- 升级3: 30×17 = 510 格
    [5] = { rows = 21 },   -- 升级4: 30×21 = 630 格
}

WarehouseUpgrade.MAX_LEVEL = 5

-- 升级花费（从 level → level+1），纯金币
WarehouseUpgrade.COSTS = {
    [1] = { gold = 1250000 },     -- Lv.1 → Lv.2: 125万
    [2] = { gold = 12500000 },    -- Lv.2 → Lv.3: 1250万
    [3] = { gold = 125000000 },   -- Lv.3 → Lv.4: 1.25亿
    [4] = { gold = 1250000000 },  -- Lv.4 → Lv.5: 12.5亿
}

--- 获取指定等级的容量（格数）
---@param level number
---@return number
function WarehouseUpgrade.GetCapacity(level)
    local data = WarehouseUpgrade.LEVELS[level]
    if not data then
        data = WarehouseUpgrade.LEVELS[1]
    end
    return data.rows * Config.GAME.WarehouseColumns
end

--- 获取指定等级的行数
---@param level number
---@return number
function WarehouseUpgrade.GetRows(level)
    local data = WarehouseUpgrade.LEVELS[level]
    return data and data.rows or WarehouseUpgrade.BASE_ROWS
end

--- 获取升级到下一级所需的消耗
---@param currentLevel number
---@return table|nil  nil 表示已满级
function WarehouseUpgrade.GetUpgradeCost(currentLevel)
    return WarehouseUpgrade.COSTS[currentLevel]
end

--- 检查玩家是否满足升级条件（纯金币）
---@param currentLevel number 当前仓库等级
---@param gold number 玩家当前金币
---@return boolean canUpgrade 是否可升级
---@return table|nil details 条件满足情况 { gold = {need, have, ok} }
function WarehouseUpgrade.CheckUpgrade(currentLevel, gold)
    if currentLevel >= WarehouseUpgrade.MAX_LEVEL then
        return false, nil
    end

    local cost = WarehouseUpgrade.COSTS[currentLevel]
    if not cost then
        return false, nil
    end

    local goldOk = gold >= cost.gold
    local details = {
        gold = {
            need = cost.gold,
            have = gold,
            ok = goldOk,
        },
    }

    return goldOk, details
end

return WarehouseUpgrade
