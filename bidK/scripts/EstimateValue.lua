-- ============================================================================
-- EstimateValue.lua - 仓库估价算法（统一模块）
-- 支持两种模式：
--   "min"      : 最低估价（保守，用于出价上限保护）
--   "expected" : 期望估价（中性，用于仓库质量判断）
-- 动态加载当前仓库类型对应的物品池，按品类权重计算池均价
-- ============================================================================

local Config = require("Config")

local EstimateValue = {}

-- ============================================================================
-- 依赖注入：GameState（多房间隔离时由 RoomInstance 注入正确的实例）
-- ============================================================================

---@type table GameState 模块引用（通过 Init 注入）
local _GameState = nil

--- 注入依赖（必须在使用前调用）
---@param gameState table GameState 模块
function EstimateValue.InjectDeps(gameState)
    _GameState = gameState
end

-- ============================================================================
-- 仓库类型 → 物品配置模块映射（与 WarehouseGenerator 保持一致）
-- ============================================================================

local warehouseModules = {
    grocery    = "Config.Warehouses.ItemPool",
    techpark   = "Config.Warehouses.TechPark",
    datacenter = { "Config.Warehouses.DataCenter", "Config.Warehouses.ItemPool" },
    quantumlab = { "Config.Warehouses.QuantumLab", "Config.Warehouses.ItemPool" },
    bondedport = { "Config.Warehouses.BondedPort", "Config.Warehouses.ItemPool" },
    shipwreck  = { "Config.Warehouses.Shipwreck", "Config.Warehouses.BondedPort", "Config.Warehouses.ItemPool" },
}

-- ============================================================================
-- 查找表缓存（按仓库类型缓存）
-- ============================================================================

--- 缓存结构: tableCache[whTypeId] = { min = {...}, avg = {...}, poolAvg = number }
local tableCache = {}

--- 加载并合并多个模块的品类和权重（与 WarehouseGenerator 逻辑一致）
--- 多模块时：先加载的模块品类优先（去重 by id），categoryWeights 取并集（先出现的优先）
---@param moduleSpec string|table 模块名或模块名数组
---@return table mergedCategories 合并后的品类列表
---@return table mergedWeights 合并后的品类权重
local function loadAndMergeModules(moduleSpec)
    local modules = type(moduleSpec) == "table" and moduleSpec or { moduleSpec }
    local mergedCategories = {}
    local mergedWeights = {}
    local seenCatIds = {}

    for _, modName in ipairs(modules) do
        local mod = require(modName)

        -- 合并品类权重（先出现的优先）
        if mod.categoryWeights then
            for catId, w in pairs(mod.categoryWeights) do
                if not mergedWeights[catId] then
                    mergedWeights[catId] = w
                end
            end
        end

        -- 合并品类列表（去重 by id）
        if mod.categories then
            for _, cat in ipairs(mod.categories) do
                if not seenCatIds[cat.id] then
                    seenCatIds[cat.id] = true
                    mergedCategories[#mergedCategories + 1] = cat
                end
            end
        end
    end

    return mergedCategories, mergedWeights
end

--- 构建指定仓库类型的 min 和 avg 查找表
---@param whTypeId string 仓库类型ID
---@return table tables { min, avg, poolAvg }
local function buildTables(whTypeId)
    if tableCache[whTypeId] then return tableCache[whTypeId] end

    local moduleSpec = warehouseModules[whTypeId]
    if not moduleSpec then
        -- fallback 到 grocery
        moduleSpec = warehouseModules["grocery"]
        whTypeId = "grocery"
        if tableCache[whTypeId] then return tableCache[whTypeId] end
    end

    local allCategories, categoryWeights = loadAndMergeModules(moduleSpec)

    -- === min 查找表（用于最低估价） ===
    local qualityMinValue = {}       -- { [quality] = minValue }
    local qualitySizeMinValue = {}   -- { ["quality:WxH"] = minValue }

    -- === avg 查找表（用于期望估价） ===
    local categoryAvg = {}           -- { [catId] = avgValue }
    local categorySizeAvg = {}       -- { ["catId:WxH"] = avgValue }
    local categoryQualityAvg = {}    -- { ["catId:quality"] = avgValue }
    local qualityAvgWeighted = {}    -- { [quality] = 按品类权重加权的均价 }

    -- 池均价计算用的临时数据
    local totalCatWeight = 0

    -- 品质全局聚合（按品类权重加权）
    local qualitySumWeighted = {}    -- { [quality] = 加权价值总和 }
    local qualityCountWeighted = {}  -- { [quality] = 加权计数 }

    for _, cat in ipairs(allCategories) do
        local catId = cat.id
        local catWeight = categoryWeights[catId] or 1
        totalCatWeight = totalCatWeight + catWeight

        -- 品类内统计
        local catSum = 0
        local catCount = 0
        local sizeSum = {}    -- { ["WxH"] = sum }
        local sizeCount = {}  -- { ["WxH"] = count }
        local qualSum = {}    -- { [quality] = sum }
        local qualCount = {}  -- { [quality] = count }

        for _, item in ipairs(cat.items) do
            local q = item.quality
            local v = item.value
            local w = item.cols
            local h = item.rows

            -- min 表
            if not qualityMinValue[q] or v < qualityMinValue[q] then
                qualityMinValue[q] = v
            end
            local sizeKey = q .. ":" .. w .. "x" .. h
            if not qualitySizeMinValue[sizeKey] or v < qualitySizeMinValue[sizeKey] then
                qualitySizeMinValue[sizeKey] = v
            end

            -- 品类内 avg 聚合
            catSum = catSum + v
            catCount = catCount + 1

            local sk = w .. "x" .. h
            sizeSum[sk] = (sizeSum[sk] or 0) + v
            sizeCount[sk] = (sizeCount[sk] or 0) + 1

            qualSum[q] = (qualSum[q] or 0) + v
            qualCount[q] = (qualCount[q] or 0) + 1

            -- 品质全局加权聚合
            qualitySumWeighted[q] = (qualitySumWeighted[q] or 0) + v * catWeight
            qualityCountWeighted[q] = (qualityCountWeighted[q] or 0) + catWeight
        end

        -- 品类均价
        if catCount > 0 then
            categoryAvg[catId] = catSum / catCount
        end

        -- 品类+尺寸均价
        for sk, sum in pairs(sizeSum) do
            categorySizeAvg[catId .. ":" .. sk] = sum / sizeCount[sk]
        end

        -- 品类+品质均价
        for q, sum in pairs(qualSum) do
            categoryQualityAvg[catId .. ":" .. q] = sum / qualCount[q]
        end
    end

    -- 品质全局加权均价（无品类信息时使用）
    for q, sum in pairs(qualitySumWeighted) do
        qualityAvgWeighted[q] = sum / qualityCountWeighted[q]
    end

    -- 池均价 = Σ(品类概率 × 品类均价)
    local poolAvg = 0
    if totalCatWeight > 0 then
        for _, cat in ipairs(allCategories) do
            local catId = cat.id
            local catWeight = categoryWeights[catId] or 1
            local catAvg = categoryAvg[catId] or 0
            poolAvg = poolAvg + (catWeight / totalCatWeight) * catAvg
        end
    end

    -- 池加权中位数（robust estimator，不受极端高价物品影响）
    -- 将每个物品按品类权重展开后取中位数
    local weightedValues = {}
    for _, cat in ipairs(allCategories) do
        local catId = cat.id
        local catWeight = categoryWeights[catId] or 1
        for _, item in ipairs(cat.items) do
            for _ = 1, catWeight do
                weightedValues[#weightedValues + 1] = item.value
            end
        end
    end
    table.sort(weightedValues)
    local poolMedian = 0
    if #weightedValues > 0 then
        local mid = math.ceil(#weightedValues / 2)
        poolMedian = weightedValues[mid]
    end

    local tables = {
        min = {
            qualityMinValue = qualityMinValue,
            qualitySizeMinValue = qualitySizeMinValue,
        },
        avg = {
            categoryAvg = categoryAvg,
            categorySizeAvg = categorySizeAvg,
            categoryQualityAvg = categoryQualityAvg,
            qualityAvgWeighted = qualityAvgWeighted,
        },
        poolAvg = poolAvg,
        poolMedian = poolMedian,
    }
    tableCache[whTypeId] = tables
    return tables
end

-- ============================================================================
-- 取值函数
-- ============================================================================

--- min 模式：查询某品质+尺寸的最低价
local function getMinValue(tables, quality, w, h)
    local min = tables.min
    local key = quality .. ":" .. w .. "x" .. h
    return min.qualitySizeMinValue[key] or min.qualityMinValue[quality] or 0
end

--- expected 模式：根据信息层级查询条件期望值
--- @param tables table 查找表
--- @param level number 信息层级 0-3
--- @param item table 仓库物品 { category, rarity, w, h, realValue }
--- @return number 条件期望值
local function getExpectedValue(tables, level, item)
    local avg = tables.avg

    if level >= 3 then
        -- L3：精确值
        return item.realValue or 0
    end

    local cat = item.category
    local q = item.rarity
    local sk = item.w .. "x" .. item.h

    -- 对于未完全揭示的物品，使用 poolMedian（加权中位数）替代 poolAvg（算术平均）
    -- 因为物品池呈极端右偏分布（白色10-60, 红色8M-28M），算术平均被极端值拉高约20倍
    local fallback = tables.poolMedian

    if level >= 2 then
        -- L2：已知品质（通常也知道品类）
        if cat then
            local key = cat .. ":" .. q
            if avg.categoryQualityAvg[key] then
                return avg.categoryQualityAvg[key]
            end
        end
        -- 无品类信息，回退到全池品质加权均价
        return avg.qualityAvgWeighted[q] or fallback
    end

    if level >= 1 then
        -- L1：已知轮廓/尺寸（通常也知道品类）
        if cat then
            local key = cat .. ":" .. sk
            if avg.categorySizeAvg[key] then
                return avg.categorySizeAvg[key]
            end
            -- 该品类无匹配尺寸，回退到品类均价
            return avg.categoryAvg[cat] or fallback
        end
        return fallback
    end

    -- L0：只知道品类
    if cat then
        return avg.categoryAvg[cat] or fallback
    end

    -- 未知：池加权中位数（robust fallback）
    return fallback
end

-- ============================================================================
-- 从信息流收集约束（min 模式专用）
-- ============================================================================

--- 收集品质数量约束 { [rarityId] = count }
local function collectRarityCounts(publicInfos, skillInfos)
    local known = {}

    local function extract(info)
        if info.rarityId and info.rarityCount then
            known[info.rarityId] = info.rarityCount
        end
    end

    local function extractAll(info)
        extract(info)
        if info.extraInfos then
            for _, extra in ipairs(info.extraInfos) do
                extract(extra)
            end
        end
    end

    for _, info in ipairs(publicInfos) do extractAll(info) end
    for _, info in ipairs(skillInfos) do extractAll(info) end
    return known
end

--- 收集价值区间提示的最大下界
local function collectValueHintLow(publicInfos, skillInfos)
    local bestLow = 0

    local function check(info)
        if info.valueLow and info.valueLow > bestLow then bestLow = info.valueLow end
    end

    for _, info in ipairs(publicInfos) do check(info) end
    for _, info in ipairs(skillInfos) do
        check(info)
        if info.extraInfos then
            for _, extra in ipairs(info.extraInfos) do check(extra) end
        end
    end
    return bestLow
end

-- ============================================================================
-- 核心算法：最低估价 (min 模式)
-- ============================================================================

--- 计算已知信息下的仓库预估最低总价
--- @param infoState table 信息状态 { publicInfos, skillInfos, itemRevealLevels }
--- @param whTypeId string|nil 仓库类型ID（nil=使用 grocery）
--- @return number estimatedMin 预估最低价
--- @return number knownCount 已揭晓物品数（level 2+3）
--- @return number totalCount 总物品数
function EstimateValue.Calculate(infoState, whTypeId)
    local items = _GameState.GetWarehouseItems()
    if not items or #items == 0 then
        return 0, 0, 0
    end

    if not infoState then
        return 0, 0, #items
    end

    local tables = buildTables(whTypeId or "grocery")

    local publicInfos = infoState.publicInfos or {}
    local skillInfos = infoState.skillInfos or {}
    local revealLevels = infoState.itemRevealLevels or {}

    -- 按揭示等级分三档
    local fullyRevealed = {}     -- level 3：价值已知
    local qualityRevealed = {}   -- level 2：品质+尺寸已知
    local unknownItems = {}      -- level 0-1：品质未知

    for _, item in ipairs(items) do
        local level = revealLevels[item.idx] or 0
        if level >= 3 then
            fullyRevealed[#fullyRevealed + 1] = item
        elseif level >= 2 then
            qualityRevealed[#qualityRevealed + 1] = item
        else
            unknownItems[#unknownItems + 1] = item
        end
    end

    local knownCount = #fullyRevealed + #qualityRevealed

    -- 累加已知物品的最低估价
    local totalMin = 0

    -- level 3：直接用真实价值
    for _, item in ipairs(fullyRevealed) do
        totalMin = totalMin + (item.realValue or 0)
    end

    -- level 2：用该品质+尺寸在物品池中的最低价
    for _, item in ipairs(qualityRevealed) do
        totalMin = totalMin + getMinValue(tables, item.rarity, item.w, item.h)
    end

    -- 处理未知物品（通过品质名额约束）
    local rarityCounts = collectRarityCounts(publicInfos, skillInfos)

    if next(rarityCounts) then
        local remaining = {}
        for rarId, count in pairs(rarityCounts) do
            remaining[rarId] = count
        end

        for _, item in ipairs(fullyRevealed) do
            if remaining[item.rarity] then
                remaining[item.rarity] = remaining[item.rarity] - 1
                if remaining[item.rarity] <= 0 then remaining[item.rarity] = nil end
            end
        end
        for _, item in ipairs(qualityRevealed) do
            if remaining[item.rarity] then
                remaining[item.rarity] = remaining[item.rarity] - 1
                if remaining[item.rarity] <= 0 then remaining[item.rarity] = nil end
            end
        end

        local quotas = {}
        for rarId, count in pairs(remaining) do
            for _ = 1, count do
                quotas[#quotas + 1] = rarId
            end
        end

        if #quotas > 0 then
            local whiteBase = 0
            local itemWhiteCost = {}
            for i, item in ipairs(unknownItems) do
                local wc = getMinValue(tables, "white", item.w, item.h)
                itemWhiteCost[i] = wc
                whiteBase = whiteBase + wc
            end

            local quotasByRarity = {}
            for _, rarId in ipairs(quotas) do
                quotasByRarity[rarId] = (quotasByRarity[rarId] or 0) + 1
            end

            local assigned = {}
            for rarId, count in pairs(quotasByRarity) do
                local candidates = {}
                for i, item in ipairs(unknownItems) do
                    if not assigned[i] then
                        local rarCost = getMinValue(tables, rarId, item.w, item.h)
                        local delta = rarCost - itemWhiteCost[i]
                        candidates[#candidates + 1] = { idx = i, delta = delta }
                    end
                end
                table.sort(candidates, function(a, b) return a.delta < b.delta end)
                local take = math.min(count, #candidates)
                for j = 1, take do
                    assigned[candidates[j].idx] = true
                    whiteBase = whiteBase + candidates[j].delta
                end
            end

            totalMin = totalMin + whiteBase
        else
            for _, item in ipairs(unknownItems) do
                totalMin = totalMin + getMinValue(tables, "white", item.w, item.h)
            end
        end
    else
        for _, item in ipairs(unknownItems) do
            totalMin = totalMin + getMinValue(tables, "white", item.w, item.h)
        end
    end

    local hintLow = collectValueHintLow(publicInfos, skillInfos)
    return math.max(totalMin, hintLow), knownCount, #items
end

-- ============================================================================
-- 核心算法：期望估价 (expected 模式)
-- ============================================================================

--- 计算已知信息下的仓库期望总价值（中性无偏估价）
--- 每件物品根据信息层级取条件期望值，未知物品取池加权中位数
--- @param infoState table 信息状态 { publicInfos, skillInfos, itemRevealLevels }
--- @param whTypeId string|nil 仓库类型ID（nil=使用 grocery）
--- @return number expectedTotal 期望总价值
--- @return number poolAvg 池均价（单件期望）—— 兼容旧接口
--- @return number itemCount 物品总数
--- @return number poolMedian 池加权中位数（robust estimator）
function EstimateValue.CalculateExpected(infoState, whTypeId)
    local items = _GameState.GetWarehouseItems()
    if not items or #items == 0 then
        return 0, 0, 0, 0
    end

    local tables = buildTables(whTypeId or "grocery")

    if not infoState then
        -- 无信息状态，全部按池加权中位数
        return tables.poolMedian * #items, tables.poolAvg, #items, tables.poolMedian
    end

    local revealLevels = infoState.itemRevealLevels or {}

    local expectedTotal = 0
    for _, item in ipairs(items) do
        local level = revealLevels[item.idx] or 0
        expectedTotal = expectedTotal + getExpectedValue(tables, level, item)
    end

    return expectedTotal, tables.poolAvg, #items, tables.poolMedian
end

-- ============================================================================
-- 辅助接口
-- ============================================================================

--- 获取指定仓库类型的池均价
--- @param whTypeId string|nil 仓库类型ID
--- @return number poolAvg
function EstimateValue.GetPoolAverage(whTypeId)
    local tables = buildTables(whTypeId or "grocery")
    return tables.poolAvg
end

--- 获取指定仓库类型的池加权中位数（robust estimator）
--- @param whTypeId string|nil 仓库类型ID
--- @return number poolMedian
function EstimateValue.GetPoolMedian(whTypeId)
    local tables = buildTables(whTypeId or "grocery")
    return tables.poolMedian
end

--- 注册新的仓库类型模块映射（供外部扩展）
--- @param whTypeId string 仓库类型ID
--- @param moduleName string 模块路径
function EstimateValue.RegisterWarehouseModule(whTypeId, moduleName)
    warehouseModules[whTypeId] = moduleName
    tableCache[whTypeId] = nil  -- 清除旧缓存
end

return EstimateValue
