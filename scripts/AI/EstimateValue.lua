-- ============================================================================
-- AI/EstimateValue.lua - AI 仓库估值模块（相对比例算法 v3 - tier感知）
--
-- 核心思想：
--   先验锚定使用仓库分层系统(tier)的加权中位数，而非 expectedValue
--   baseline = expectedValue × TIER_PRIOR_MULT / itemCount
--   池数据仅用于不同稀有度/类别之间的 **相对比例**
--   L0~L3 逐级替换为更精确的估值
--
-- 三层估值：
--   L0: baseline（仅知数量，已含 tier 修正）
--   L1: baseline × categoryRelative（知轮廓/类别）
--   L2: baseline × rarityRelative（知品质/稀有度）
--   L3: realValue（精确值）
--
-- 质量推断：当 ≥3 件物品已知精确值(L3)时，
--   用已知物品的 "实际值/估计值" 比率修正未知物品的估值
-- ============================================================================

local EstimateValue = {}

-- ============================================================================
-- 仓库分层系统 (Tier) 先验参数
-- 与 WarehouseGenerator.lua 中的 WAREHOUSE_TIERS 保持一致
-- AI 用这些数据建立先验估值锚定
-- ============================================================================

-- Tier 分布（复制自 WarehouseGenerator）
local WAREHOUSE_TIERS = {
    { id = "junk",     weight = 22, multMin = 0.10, multMax = 0.30 },
    { id = "poor",     weight = 25, multMin = 0.30, multMax = 0.60 },
    { id = "normal",   weight = 28, multMin = 0.60, multMax = 1.25 },
    { id = "good",     weight = 15, multMin = 1.25, multMax = 2.10 },
    { id = "treasure", weight = 7,  multMin = 2.10, multMax = 3.50 },
    { id = "jackpot",  weight = 3,  multMin = 3.50, multMax = 5.50 },
}

--- 计算 tier 分布的先验乘数
--- 使用加权中位数：找到累计权重达到 50% 的 tier，取该 tier 的中点值
--- 这比均值更保守，因为分布右偏（少数 jackpot 拉高均值）
--- junk(22%) + poor(25%) = 47%，中位数落在 normal tier 前端 → ≈0.65x
local function computeTierPriorMult()
    local totalWeight = 0
    for _, t in ipairs(WAREHOUSE_TIERS) do
        totalWeight = totalWeight + t.weight
    end
    local halfWeight = totalWeight * 0.5
    local acc = 0
    for _, t in ipairs(WAREHOUSE_TIERS) do
        local prevAcc = acc
        acc = acc + t.weight
        if acc >= halfWeight then
            -- 中位数落在此 tier 中
            -- 在 tier 内部按权重进度线性插值
            local progress = (halfWeight - prevAcc) / t.weight
            return t.multMin + (t.multMax - t.multMin) * progress
        end
    end
    return 0.65  -- fallback
end

--- 先验乘数：tier 分布的加权中位数
--- 代表"在不知道具体仓库分层的情况下，仓库实际价值对 expectedValue 的最佳猜测"
local TIER_PRIOR_MULT = computeTierPriorMult()

-- ============================================================================
-- 内部状态（Init 时构建）
-- ============================================================================

-- 稀有度相对比例: rarityRelative[rarity] = avg(该稀有度物品) / poolAvg
-- 表示该稀有度物品相对于池平均的价值倍率
local rarityRelative = {}

-- 类别相对比例: categoryRelative[category] = avg(该类别物品) / poolAvg
local categoryRelative = {}

-- 池平均值（所有物品的算术平均，用于计算相对比例的基准）
local poolAvg = 0

-- 是否已初始化
local initialized = false

-- ============================================================================
-- 加载物品池数据
-- ============================================================================

--- 获取指定仓库类型的合并物品池
---@param warehouseTypeId string|nil
---@return table[] 物品列表 { rarity, category, valueMin, valueMax, ... }
local function loadPool(warehouseTypeId)
    -- 仓库类型 → 模块映射（与 WarehouseGenerator 保持一致）
    local warehouseModules = {
        grocery    = { "Config.Warehouses.ItemPool" },
        techpark   = { "Config.Warehouses.TechPark" },
        datacenter = { "Config.Warehouses.DataCenter", "Config.Warehouses.ItemPool" },
        quantumlab = { "Config.Warehouses.QuantumLab", "Config.Warehouses.ItemPool" },
        bondedport = { "Config.Warehouses.BondedPort", "Config.Warehouses.ItemPool" },
        shipwreck  = { "Config.Warehouses.Shipwreck", "Config.Warehouses.BondedPort", "Config.Warehouses.ItemPool" },
    }

    local modules = warehouseModules[warehouseTypeId]
    if not modules then
        modules = { "Config.Warehouses.ItemPool" }
    end

    -- 合并所有模块的物品
    local allItems = {}
    local seenCatIds = {}
    for _, modPath in ipairs(modules) do
        local ok, mod = pcall(require, modPath)
        if ok and mod then
            -- 通过 mod.categories 遍历（与 WarehouseGenerator/EstimateValue 一致）
            if mod.categories then
                for _, cat in ipairs(mod.categories) do
                    if not seenCatIds[cat.id] then
                        seenCatIds[cat.id] = true
                        for _, item in ipairs(cat.items) do
                            allItems[#allItems + 1] = {
                                rarity   = item.quality or "white",
                                category = cat.id,
                                value    = item.value or 0,
                            }
                        end
                    end
                end
            end
        end
    end

    return allItems
end

-- ============================================================================
-- 初始化：构建相对比例表
-- ============================================================================

--- 初始化估值模块，构建相对比例表
---@param warehouseTypeId string|nil 仓库类型
function EstimateValue.Init(warehouseTypeId)
    local pool = loadPool(warehouseTypeId)

    -- 计算池平均值
    local totalValue = 0
    for _, item in ipairs(pool) do
        totalValue = totalValue + item.value
    end
    poolAvg = #pool > 0 and (totalValue / #pool) or 1

    -- 按稀有度分组求平均
    local raritySum = {}
    local rarityCount = {}
    for _, item in ipairs(pool) do
        local r = item.rarity
        raritySum[r] = (raritySum[r] or 0) + item.value
        rarityCount[r] = (rarityCount[r] or 0) + 1
    end

    rarityRelative = {}
    for r, sum in pairs(raritySum) do
        local avg = sum / rarityCount[r]
        rarityRelative[r] = avg / poolAvg
    end

    -- 按类别分组求平均
    local catSum = {}
    local catCount = {}
    for _, item in ipairs(pool) do
        local c = item.category
        catSum[c] = (catSum[c] or 0) + item.value
        catCount[c] = (catCount[c] or 0) + 1
    end

    categoryRelative = {}
    for c, sum in pairs(catSum) do
        local avg = sum / catCount[c]
        categoryRelative[c] = avg / poolAvg
    end

    initialized = true

    -- 调试日志
    print("[EstimateValue] Init warehouseTypeId=" .. tostring(warehouseTypeId)
        .. " poolSize=" .. #pool
        .. " poolAvg=" .. string.format("%.1f", poolAvg)
        .. " tierPriorMult=" .. string.format("%.3f", TIER_PRIOR_MULT))
    for r, rel in pairs(rarityRelative) do
        print("[EstimateValue]   rarity " .. r .. " relative=" .. string.format("%.3f", rel))
    end
end

-- ============================================================================
-- 核心估值函数
-- ============================================================================

--- 估算仓库总价值
--- 每件物品根据信息层级获得不同精度的估值：
---   L0: baseline
---   L1: baseline × categoryRelative
---   L2: baseline × rarityRelative
---   L3: realValue（精确值）
--- 当 ≥3 件 L3 物品已知时，用质量比率修正未知物品
---
---@param infoState table { itemRevealLevels }
---@param items table[] 仓库物品列表（来自 GameState）
---@param expectedValue number 区域期望价值
---@return number totalEstimate 总估值
---@return number knownCount L3 物品数量
---@return number itemCount 物品总数
function EstimateValue.Estimate(infoState, items, expectedValue)
    if not items or #items == 0 then
        return expectedValue * TIER_PRIOR_MULT, 0, 0
    end

    local itemCount = #items
    -- 使用 tier 分布的加权中位数作为先验锚定（而非直接用 expectedValue）
    -- 这样 AI 对大多数仓库（junk/poor/normal，75%概率）不会严重高估
    local baseline = expectedValue * TIER_PRIOR_MULT / itemCount
    local revealLevels = infoState.itemRevealLevels or {}

    -- 第一遍：按信息层级估算每件物品
    local perItemEstimate = {}  -- [idx] = 估值
    local perItemLevel = {}     -- [idx] = 信息层级
    local l3Values = {}         -- L3 物品的 { estimate_before_l3, realValue }
    local l3Count = 0

    for _, item in ipairs(items) do
        local idx = item.idx
        local level = revealLevels[idx] or 0
        local est = baseline

        if level >= 3 then
            -- L3: 精确值
            est = item.realValue or item.value or baseline
            l3Count = l3Count + 1
        elseif level >= 2 then
            -- L2: 知品质 → baseline × rarityRelative
            local rr = rarityRelative[item.rarity] or 1.0
            est = baseline * rr
        elseif level >= 1 then
            -- L1: 知轮廓/类别 → baseline × categoryRelative
            local cr = categoryRelative[item.category] or 1.0
            est = baseline * cr
        end
        -- L0: 直接用 baseline

        perItemEstimate[idx] = est
        perItemLevel[idx] = level

        -- 记录 L3 物品的"如果不是L3会估多少" vs "实际值"
        if level >= 3 then
            -- 假设只有 L2 信息时的估值
            local rr = rarityRelative[item.rarity] or 1.0
            local hypothetical = baseline * rr
            l3Values[#l3Values + 1] = {
                hypothetical = hypothetical,
                real = item.realValue or item.value or baseline,
            }
        end
    end

    -- 质量推断：当 ≥3 件 L3 已知时，计算质量比率
    local qualityRatio = 1.0
    if l3Count >= 3 then
        local sumHypo = 0
        local sumReal = 0
        for _, v in ipairs(l3Values) do
            sumHypo = sumHypo + v.hypothetical
            sumReal = sumReal + v.real
        end
        if sumHypo > 0 then
            qualityRatio = sumReal / sumHypo
            -- 限制修正范围 [0.3, 3.0]，避免极端偏差
            qualityRatio = math.max(0.3, math.min(3.0, qualityRatio))
        end
    end

    -- 第二遍：应用质量修正，累加总估值
    local totalEstimate = 0
    for _, item in ipairs(items) do
        local idx = item.idx
        local level = perItemLevel[idx] or 0
        local est = perItemEstimate[idx] or baseline

        -- L3 物品不需要修正（已是精确值）
        -- 非 L3 物品按质量比率修正
        if level < 3 and l3Count >= 3 then
            est = est * qualityRatio
        end

        totalEstimate = totalEstimate + est
    end

    return totalEstimate, l3Count, itemCount
end

-- ============================================================================
-- 辅助查询接口
-- ============================================================================

--- 获取池平均值（供外部使用）
---@param warehouseTypeId string|nil 未使用，保持接口兼容
---@return number
function EstimateValue.GetPoolAverage(warehouseTypeId)
    return poolAvg
end

--- 获取 tier 先验修正后的期望值
--- 即 expectedValue × TIER_PRIOR_MULT
---@param expectedValue number 区域/难度的原始期望值
---@return number 修正后的期望值
function EstimateValue.GetTierPriorValue(expectedValue)
    return expectedValue * TIER_PRIOR_MULT
end

--- 获取 tier 先验乘数
---@return number
function EstimateValue.GetTierPriorMult()
    return TIER_PRIOR_MULT
end

--- 获取池中位数（兼容旧接口，返回 poolAvg）
---@param warehouseTypeId string|nil
---@return number
function EstimateValue.GetPoolMedian(warehouseTypeId)
    return poolAvg  -- 新算法不依赖中位数，返回均值保持接口兼容
end

--- 获取稀有度相对比例表
---@return table { [rarity] = relative_ratio }
function EstimateValue.GetRarityRelative()
    return rarityRelative
end

--- 获取类别相对比例表
---@return table { [category] = relative_ratio }
function EstimateValue.GetCategoryRelative()
    return categoryRelative
end

--- 是否已初始化
---@return boolean
function EstimateValue.IsInitialized()
    return initialized
end

return EstimateValue
