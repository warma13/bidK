-- ============================================================================
-- WG/SessionParams.lua - 会话参数采样 + 仓库分层系统
-- ============================================================================

local RngGrid = require("WG.RngGrid")
local ItemPool = require("WG.ItemPool")

local M = {}

local MAX_CELLS = require("Config").GAME.LootColumns * require("Config").GAME.LootMaxRows

-- ============================================================================
-- 仓库分层系统（Tier）
-- 先掷骰决定本仓库的价值档位，再在档位区间内采样
--
-- 设计理念：warehouseValue（原 expectedValue）是"高点"而非平均值。
-- 大多数仓库（约 80-85%）实际价值低于 warehouseValue，
-- 只有少数宝藏/jackpot 仓库才会超过它，给玩家带来惊喜感。
--
-- 加权期望校验（multAvg = (multMin+multMax)/2）：
-- 25×0.325 + 23×0.45 + 22×0.625 + 13×0.825 + 9×1.40 + 6×2.50 + 2×4.35
-- = 8.125 + 10.35 + 13.75 + 10.725 + 12.60 + 15.00 + 8.70 = 79.25 / 100 ≈ 0.79×
-- ============================================================================
local WAREHOUSE_TIERS = {
    { id = "trash",    weight = 25, multMin = 0.25, multMax = 0.40, fillerRatio = 0.95, budgetK = 1.2 },
    { id = "junk",     weight = 23, multMin = 0.35, multMax = 0.55, fillerRatio = 0.90, budgetK = 1.0 },
    { id = "poor",     weight = 22, multMin = 0.50, multMax = 0.75, fillerRatio = 0.82, budgetK = 0.9 },
    { id = "normal",   weight = 13, multMin = 0.65, multMax = 1.00, fillerRatio = 0.75, budgetK = 0.8 },
    { id = "good",     weight = 9,  multMin = 1.00, multMax = 1.80, fillerRatio = 0.60, budgetK = 0.6 },
    { id = "treasure", weight = 6,  multMin = 1.80, multMax = 3.20, fillerRatio = 0.45, budgetK = 0.4 },
    { id = "jackpot",  weight = 2,  multMin = 3.20, multMax = 5.50, fillerRatio = 0.35, budgetK = 0.3 },
}
M.WAREHOUSE_TIERS = WAREHOUSE_TIERS

--- 按权重随机选取仓库分层
--- @return table tier 选中的分层配置
function M.rollTier()
    local totalWeight = 0
    for _, t in ipairs(WAREHOUSE_TIERS) do
        totalWeight = totalWeight + t.weight
    end
    local r = RngGrid.rng() * totalWeight
    local acc = 0
    for _, t in ipairs(WAREHOUSE_TIERS) do
        acc = acc + t.weight
        if r <= acc then return t end
    end
    return WAREHOUSE_TIERS[3]
end

-- ============================================================================
-- 辅助算法
-- ============================================================================

--- Box-Muller 变换生成标准正态随机数
local function randNormal()
    local u1 = RngGrid.rng()
    local u2 = RngGrid.rng()
    if u1 < 1e-10 then u1 = 1e-10 end
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

--- 计算物品池的理论价值边界（在给定格子数下）
local function calcValueBounds(whTypeId, targetCells)
    local pool = ItemPool.getPool(whTypeId)
    local entries = {}
    for _, e in ipairs(pool.allItems) do
        local cells = e.w * e.h
        entries[#entries + 1] = {
            valuePerCell = e.item.value / cells,
            cells = cells,
            value = e.item.value,
        }
    end

    table.sort(entries, function(a, b) return a.valuePerCell < b.valuePerCell end)
    local minVal = 0
    local remainMin = targetCells
    for _, e in ipairs(entries) do
        if remainMin <= 0 then break end
        if e.cells <= remainMin then
            minVal = minVal + e.value
            remainMin = remainMin - e.cells
        end
    end

    local maxVal = 0
    local remainMax = targetCells
    for i = #entries, 1, -1 do
        local e = entries[i]
        if remainMax <= 0 then break end
        if e.cells <= remainMax then
            maxVal = maxVal + e.value
            remainMax = remainMax - e.cells
        end
    end

    return minVal, maxVal
end

--- 根据目标平均格子数，混合"理想尺寸权重"与仓库本身风格权重
--- @param avgCells number 目标平均每件格子数
--- @param baseWeights table 仓库基础 sizeWeights（5个组）
--- @return table 混合后的 sizeWeights
function M.blendedSizeWeights(avgCells, baseWeights)
    local ideal
    if avgCells <= 1.3 then
        ideal = { 100,  0,  0,  0,  0 }
    elseif avgCells <= 1.8 then
        ideal = {  70, 30,  0,  0,  0 }
    elseif avgCells <= 2.5 then
        ideal = {  35, 55, 10,  0,  0 }
    elseif avgCells <= 3.5 then
        ideal = {  15, 40, 35, 10,  0 }
    elseif avgCells <= 5.0 then
        ideal = {   8, 22, 40, 25,  5 }
    elseif avgCells <= 6.5 then
        ideal = {   5, 12, 28, 40, 15 }
    else
        ideal = {   3,  8, 20, 35, 34 }
    end
    local blended = {}
    for i = 1, 5 do
        blended[i] = ideal[i] * 0.7 + (baseWeights[i] or 0) * 0.3
    end
    return blended
end

--- 生成本局的目标参数（价值 + 格子数 + 件数 + 分层）
--- @param whType table 仓库类型配置（需含 warehouseValue 字段）
--- @param whTypeId string 仓库类型ID
--- @return number targetValue, number targetCells, number targetItemCount, table tier
function M.sampleSessionParams(whType, whTypeId)
    local baseValue = whType.warehouseValue

    local pool = ItemPool.getPool(whTypeId)
    local poolMinValue = pool.poolMinValue

    local tier = M.rollTier()

    local mult = tier.multMin + RngGrid.rng() * (tier.multMax - tier.multMin)
    local targetValue = baseValue * mult
    targetValue = math.max(baseValue * 0.02, targetValue)

    local baseCount = math.floor(40 + randNormal() * 6 + 0.5)
    baseCount = math.max(10, math.min(MAX_CELLS, baseCount))

    local maxAffordableCount = math.floor(targetValue / poolMinValue)
    local targetItemCount = math.min(baseCount, math.max(3, maxAffordableCount))

    local fillRate = 0.50 + randNormal() * 0.12
    fillRate = math.max(0.20, math.min(0.80, fillRate))
    local targetCells = math.floor(MAX_CELLS * fillRate)
    targetCells = math.min(targetCells, targetItemCount * 5)
    targetCells = math.max(targetItemCount, math.min(MAX_CELLS - 10, targetCells))

    local _, boundMax = calcValueBounds(whTypeId, targetCells)
    targetValue = math.min(boundMax, targetValue)

    return targetValue, targetCells, targetItemCount, tier
end

return M
