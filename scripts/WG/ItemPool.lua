-- ============================================================================
-- WG/ItemPool.lua - 物品池 + 预算权重选品
-- ============================================================================

local Config   = require("Config")
local RngGrid  = require("WG.RngGrid")

local M = {}

-- 缓存：whTypeId → { sizeGroups, allItems, poolMinValue }
local poolCache = {}

-- ============================================================================
-- 预算权重计算
-- ============================================================================

--- 计算物品的预算制权重（非对称高斯衰减）
--- @param value number 物品价值
--- @param targetPerPick number 当前目标均价
--- @param k number|nil 集中度参数，默认 1.5
local function budgetWeight(value, targetPerPick, k)
    if targetPerPick <= 0 then targetPerPick = 1 end
    k = k or 1.5
    local logRatio = math.log(value / targetPerPick)
    if logRatio > 0 then
        return math.exp(-(k * 0.5) * logRatio * logRatio)
    else
        return math.exp(-k * logRatio * logRatio)
    end
end

-- ============================================================================
-- 内部工具
-- ============================================================================

--- 根据权重数组随机选择一个索引（1-based）
function M.weightedRandom(weights)
    local total = 0
    for i = 1, #weights do
        total = total + weights[i]
    end
    if total <= 0 then return 1 end
    local r = RngGrid.rng() * total
    local acc = 0
    for i = 1, #weights do
        acc = acc + weights[i]
        if r <= acc then return i end
    end
    return #weights
end

-- ============================================================================
-- 物品池构建
-- ============================================================================

--- 构建仓库物品池（统一池模式）
function M.getPool(whTypeId)
    if poolCache[whTypeId] then return poolCache[whTypeId] end

    local whCfg = Config.WAREHOUSE_TYPES[whTypeId]
    if not whCfg then
        whTypeId = "suburb_basement"
        if poolCache[whTypeId] then return poolCache[whTypeId] end
        whCfg = Config.WAREHOUSE_TYPES[whTypeId]
    end

    local sizeGroups = { {}, {}, {}, {}, {} }
    local allItems = {}

    local allowed = nil
    if whCfg.allowedCategories then
        allowed = {}
        for _, catId in ipairs(whCfg.allowedCategories) do
            allowed[catId] = true
        end
    end

    local itemPoolMod = require("Config.Warehouses.ItemPool")
    local seenNames = {}
    local prefTags = whCfg.preferredTags

    for _, cat in ipairs(itemPoolMod.categories) do
        if not allowed or allowed[cat.id] then
            local catWeight
            if whCfg.categoryWeights then
                catWeight = whCfg.categoryWeights[cat.id] or 0
            else
                catWeight = itemPoolMod.categoryWeights[cat.id] or 1
            end
            if catWeight <= 0 then goto skipCategory end

            for _, item in ipairs(cat.items) do
                if seenNames[item.name] then goto skipItem end
                seenNames[item.name] = true

                local w = item.cols
                local h = item.rows

                local tagBonus = 1.0
                if prefTags and item.tags then
                    for _, tag in ipairs(item.tags) do
                        local bonus = prefTags[tag]
                        if bonus and bonus > tagBonus then
                            tagBonus = bonus
                        end
                    end
                end

                local entry = {
                    item = item,
                    catIcon = cat.icon,
                    catId = cat.id,
                    w = w,
                    h = h,
                    catWeight = catWeight,
                    tagBonus = tagBonus,
                }
                allItems[#allItems + 1] = entry

                local cells = w * h
                local groupIdx = Config.ITEM_SIZE_GROUPS[cells] or 1
                sizeGroups[groupIdx][#sizeGroups[groupIdx] + 1] = entry

                ::skipItem::
            end
        end
        ::skipCategory::
    end

    local poolMinValue = math.huge
    for _, e in ipairs(allItems) do
        if e.item.value < poolMinValue then
            poolMinValue = e.item.value
        end
    end
    if poolMinValue == math.huge then poolMinValue = 1 end

    local pool = { sizeGroups = sizeGroups, allItems = allItems, poolMinValue = poolMinValue }
    poolCache[whTypeId] = pool
    return pool
end

-- ============================================================================
-- 权重选品
-- ============================================================================

--- 从候选列表中按预算制权重加权随机选取
--- @param pool table 候选 entry 列表
--- @param targetPerPick number 当前目标均价
--- @param k number|nil budgetWeight 集中度参数
--- @param lowerBound number|nil 价值下界（低于此值权重衰减 90%）
function M.pickWeightedBudget(pool, targetPerPick, k, lowerBound)
    local total = 0
    for _, e in ipairs(pool) do
        local bw = budgetWeight(e.item.value, targetPerPick, k)
        if e.item.value < targetPerPick * 0.4 then
            bw = 0
        elseif lowerBound and e.item.value < lowerBound then
            bw = bw * 0.1
        end
        e._dynWeight = e.catWeight * bw * (e.tagBonus or 1.0)
        total = total + e._dynWeight
    end
    if total <= 0 then
        local fallbackTotal = 0
        for _, e in ipairs(pool) do
            e._dynWeight = e.catWeight * (e.tagBonus or 1.0)
            fallbackTotal = fallbackTotal + e._dynWeight
        end
        if fallbackTotal <= 0 then return pool[1] end
        local fr = RngGrid.rng() * fallbackTotal
        local facc = 0
        for _, e in ipairs(pool) do
            facc = facc + e._dynWeight
            if fr <= facc then return e end
        end
        return pool[#pool]
    end
    local r = RngGrid.rng() * total
    local acc = 0
    for _, e in ipairs(pool) do
        acc = acc + e._dynWeight
        if r <= acc then return e end
    end
    return pool[#pool]
end

--- 从候选列表中按品类权重×物品权重随机选取（不考虑预算，用于填充阶段）
function M.pickWeightedCategory(pool)
    local total = 0
    for _, e in ipairs(pool) do
        total = total + e.catWeight * (e.tagBonus or 1.0)
    end
    if total <= 0 then return pool[1] end
    local r = RngGrid.rng() * total
    local acc = 0
    for _, e in ipairs(pool) do
        acc = acc + e.catWeight * (e.tagBonus or 1.0)
        if r <= acc then return e end
    end
    return pool[#pool]
end

--- 从物品池中按尺寸权重选一个尺寸组，再从中选取物品
--- @param whTypeId string 仓库类型ID
--- @param whType table 仓库类型配置（含 sizeWeights）
--- @param targetPerPick number|nil 目标均价（nil=不考虑预算）
--- @param maxValue number|nil 单品价值上限
--- @param budgetK number|nil budgetWeight 集中度参数
--- @param lowerBound number|nil 价值软下界
--- @param minValue number|nil 价值硬下限
function M.pickFromPool(whTypeId, whType, targetPerPick, maxValue, budgetK, lowerBound, minValue)
    local pool = M.getPool(whTypeId)
    local sizeWeights = whType.sizeWeights

    local attempts = 0
    while attempts < 10 do
        local groupIdx = M.weightedRandom(sizeWeights)
        local group = pool.sizeGroups[groupIdx]
        if #group > 0 then
            local available = {}
            for _, e in ipairs(group) do
                local v = e.item.value
                if (not maxValue or v <= maxValue) and (not minValue or v >= minValue) then
                    available[#available + 1] = e
                end
            end
            if #available > 0 then
                if targetPerPick then
                    return M.pickWeightedBudget(available, targetPerPick, budgetK, lowerBound)
                else
                    return M.pickWeightedCategory(available)
                end
            end
        end
        attempts = attempts + 1
    end

    if targetPerPick and minValue then
        local priceFiltered = {}
        for _, e in ipairs(pool.allItems) do
            local v = e.item.value
            if (not maxValue or v <= maxValue) and v >= minValue then
                priceFiltered[#priceFiltered + 1] = e
            end
        end
        if #priceFiltered > 0 then
            return M.pickWeightedBudget(priceFiltered, targetPerPick, budgetK, lowerBound)
        end
    end

    if targetPerPick then
        local maxFiltered = {}
        for _, e in ipairs(pool.allItems) do
            if not maxValue or e.item.value <= maxValue then
                maxFiltered[#maxFiltered + 1] = e
            end
        end
        if #maxFiltered > 0 then
            return M.pickWeightedBudget(maxFiltered, targetPerPick, budgetK, lowerBound)
        end
        return M.pickWeightedBudget(pool.allItems, targetPerPick, budgetK, lowerBound)
    else
        return M.pickWeightedCategory(pool.allItems)
    end
end

--- Fisher-Yates 洗牌
function M.shuffle(t)
    for i = #t, 2, -1 do
        local j = RngGrid.rng(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

return M
