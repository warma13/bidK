-- ============================================================================
-- RevealPlanner.lua - 仓库公开信息揭示计划生成器
-- 纯数据模块，不依赖 UI，根据仓库物品生成每轮的揭示计划
--
-- 评分公式: S = ΔW(m) × T(n) × Q(q)
-- 每轮 5 个备选方案，随机抽取 1 个
-- ============================================================================

local Config = require("Config")

local RevealPlanner = {}

-- 品质 → 颜色名称映射
local QUALITY_COLOR_NAME = {
    white     = "白色",
    green     = "绿色",
    blue      = "蓝色",
    purple    = "紫色",
    gold      = "金色",
    red       = "红色",
}

-- 品质排序索引（用于比较高低）
local QUALITY_ORDER = {}
for i, r in ipairs(Config.RARITY) do
    QUALITY_ORDER[r.id] = i
end

-- ============================================================================
-- 内部数据
-- ============================================================================

local data = {
    items = {},                -- 仓库物品列表
    itemRevealLevels = {},     -- { [itemIdx] = 0|1|2|3 }
    roundPlans = {},           -- { [round] = { info1, info2 } }
    usedCategories = {},       -- 已使用的品类 { [catId] = true }
    usedQualities = {},        -- 已使用的品质 { [qualityId] = true }
}

-- ============================================================================
-- 统计分析
-- ============================================================================

local stats = {}

local function analyze(items)
    stats = {
        totalCount = #items,
        catItems = {},       -- { [catId] = { item, ... } }
        catNames = {},       -- { [catId] = name }
        catIds = {},         -- { catId, ... } 有物品的品类ID列表
        qualityItems = {},   -- { [qualityId] = { item, ... } }
        qualityIds = {},     -- { qualityId, ... } 有物品的品质ID列表（低→高）
    }

    for _, item in ipairs(items) do
        local cat = item.category
        if cat then
            if not stats.catItems[cat] then
                stats.catItems[cat] = {}
                local catDef = Config.GetCategory(cat)
                stats.catNames[cat] = catDef and catDef.name or cat
            end
            local list = stats.catItems[cat]
            list[#list + 1] = item
        end

        local q = item.rarity
        if q then
            if not stats.qualityItems[q] then
                stats.qualityItems[q] = {}
            end
            local list = stats.qualityItems[q]
            list[#list + 1] = item
        end
    end

    for catId in pairs(stats.catItems) do
        stats.catIds[#stats.catIds + 1] = catId
    end

    for qId in pairs(stats.qualityItems) do
        stats.qualityIds[#stats.qualityIds + 1] = qId
    end
    table.sort(stats.qualityIds, function(a, b)
        return (QUALITY_ORDER[a] or 0) < (QUALITY_ORDER[b] or 0)
    end)
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

--- Fisher-Yates 洗牌
local function shuffle(list)
    local copy = {}
    for i, v in ipairs(list) do copy[i] = v end
    for i = #copy, 2, -1 do
        local j = math.random(1, i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    return copy
end

--- 从列表中随机选 N 个元素
local function pickRandom(list, n)
    if #list <= n then return list end
    local shuffled = shuffle(list)
    local result = {}
    for i = 1, n do result[i] = shuffled[i] end
    return result
end

--- 从未使用的品类中随机选一个
local function pickUnusedCategory()
    local candidates = {}
    for _, catId in ipairs(stats.catIds) do
        if not data.usedCategories[catId] then
            candidates[#candidates + 1] = catId
        end
    end
    if #candidates == 0 then candidates = stats.catIds end
    if #candidates == 0 then return nil end
    return candidates[math.random(1, #candidates)]
end

--- 从未使用的品质中随机选一个
local function pickUnusedQuality(preferHigh)
    local candidates = {}
    for _, qId in ipairs(stats.qualityIds) do
        if not data.usedQualities[qId] then
            candidates[#candidates + 1] = qId
        end
    end
    if #candidates == 0 then candidates = stats.qualityIds end
    if #candidates == 0 then return nil end

    if preferHigh then
        table.sort(candidates, function(a, b)
            return (QUALITY_ORDER[a] or 0) > (QUALITY_ORDER[b] or 0)
        end)
        local top = math.min(2, #candidates)
        return candidates[math.random(1, top)]
    else
        return candidates[math.random(1, #candidates)]
    end
end

--- 创建揭示动作列表（只升不降）
local function makeReveals(items, targetLevel)
    local reveals = {}
    for _, item in ipairs(items) do
        if item.idx then
            local cur = data.itemRevealLevels[item.idx] or 0
            if targetLevel > cur then
                reveals[#reveals + 1] = { itemIdx = item.idx, targetLevel = targetLevel }
            end
        end
    end
    return reveals
end

--- 应用揭示动作到内部状态
local function applyReveals(reveals)
    for _, r in ipairs(reveals) do
        local cur = data.itemRevealLevels[r.itemIdx] or 0
        if r.targetLevel > cur then
            data.itemRevealLevels[r.itemIdx] = r.targetLevel
        end
    end
end

--- 按品质分组统计描述文本
local function qualityBreakdownText(items)
    local rarCounts = {}
    local rarOrder = {}
    for _, item in ipairs(items) do
        local rar = Config.GetRarity(item.rarity)
        local name = rar.name
        if not rarCounts[name] then
            rarCounts[name] = 0
            rarOrder[#rarOrder + 1] = name
        end
        rarCounts[name] = rarCounts[name] + 1
    end
    local parts = {}
    for _, name in ipairs(rarOrder) do
        parts[#parts + 1] = rarCounts[name] .. "件" .. name
    end
    return table.concat(parts, "、")
end

--- 获取未完全揭示的物品候选
local function getUnrevealedItems(belowLevel)
    local candidates = {}
    for _, item in ipairs(data.items) do
        if item.idx and (data.itemRevealLevels[item.idx] or 0) < belowLevel then
            candidates[#candidates + 1] = item
        end
    end
    return candidates
end

-- ============================================================================
-- 全局 FormatValue（InfoSystem 也用到）
-- ============================================================================

function FormatValue(val)
    if val >= 10000 then
        return string.format("%.1f万", val / 10000)
    end
    return tostring(math.floor(val))
end

-- ============================================================================
-- 信息生成器
-- ============================================================================

local generators = {}

-- ----- L2 品类全部品质 -----
-- R1: 6 × 1.0 × 37.7 ≈ 226
-- R3: 6 × 0.6 × 37.7 ≈ 136 (ΔW 可能因前轮揭示降低)
function generators.category_quality(catId)
    catId = catId or pickUnusedCategory()
    if not catId then return nil end
    local items = stats.catItems[catId]
    if not items or #items == 0 then return nil end
    local catName = stats.catNames[catId] or catId

    data.usedCategories[catId] = true
    return {
        type = "category_quality",
        text = catName .. "类藏品共" .. #items .. "件：" .. qualityBreakdownText(items),
        reveals = makeReveals(items, 2),
    }
end

-- ----- L1 双品类全部轮廓 -----
-- R1: 3 × 1.0 × 75.4 ≈ 226
function generators.dual_category_outline()
    local candidates = {}
    for _, catId in ipairs(stats.catIds) do
        if not data.usedCategories[catId] then
            candidates[#candidates + 1] = catId
        end
    end
    if #candidates < 2 then
        -- 不够2个未使用品类，用全部品类
        candidates = {}
        for _, catId in ipairs(stats.catIds) do
            candidates[#candidates + 1] = catId
        end
    end
    if #candidates < 2 then return nil end

    local picked = pickRandom(candidates, 2)
    local allItems = {}
    local names = {}
    for _, catId in ipairs(picked) do
        data.usedCategories[catId] = true
        local catName = stats.catNames[catId] or catId
        names[#names + 1] = catName
        for _, item in ipairs(stats.catItems[catId] or {}) do
            allItems[#allItems + 1] = item
        end
    end

    return {
        type = "dual_category_outline",
        text = "扫描到" .. table.concat(names, "和") .. "类共" .. #allItems .. "件藏品的轮廓",
        reveals = makeReveals(allItems, 1),
    }
end

-- ----- L1 单品类全部轮廓 -----
-- R2: 3 × 0.8 × 37.7 ≈ 90
-- R3: 3 × 0.6 × 37.7 ≈ 68
function generators.category_outline(catId)
    catId = catId or pickUnusedCategory()
    if not catId then return nil end
    local items = stats.catItems[catId]
    if not items or #items == 0 then return nil end
    local catName = stats.catNames[catId] or catId

    data.usedCategories[catId] = true
    return {
        type = "category_outline",
        text = "扫描到" .. catName .. "类" .. #items .. "件藏品的轮廓",
        reveals = makeReveals(items, 1),
    }
end

-- ----- L2 某品质全部物品 -----
-- R1: 6 × 1.0 × 30(绿色ΣQ) ≈ 180
function generators.quality_group_quality(qualityId)
    qualityId = qualityId or pickUnusedQuality(false)
    if not qualityId then return nil end
    local items = stats.qualityItems[qualityId]
    if not items or #items == 0 then return nil end
    local colorName = QUALITY_COLOR_NAME[qualityId] or qualityId

    data.usedQualities[qualityId] = true
    return {
        type = "quality_group_quality",
        text = "鉴别出全部" .. #items .. "件" .. colorName .. "品质藏品",
        reveals = makeReveals(items, 2),
    }
end

-- ----- L1 品质尺寸线索 -----
-- R2: 3 × 0.8 × 40 ≈ 96
function generators.rarity_size_hint(qualityId)
    qualityId = qualityId or "gold"
    local items = stats.qualityItems[qualityId]
    if not items or #items == 0 then
        qualityId = pickUnusedQuality(true)
        if not qualityId then return nil end
        items = stats.qualityItems[qualityId]
        if not items or #items == 0 then return nil end
    end

    local colorName = QUALITY_COLOR_NAME[qualityId] or qualityId
    local totalCells = 0
    for _, item in ipairs(items) do
        totalCells = totalCells + (item.w or 1) * (item.h or 1)
    end
    local avgCells = math.floor(totalCells / #items + 0.5)

    data.usedQualities[qualityId] = true
    return {
        type = "rarity_size_hint",
        text = colorName .. "品质藏品共" .. #items .. "件，平均占" .. avgCells .. "格",
        reveals = makeReveals(items, 1),
    }
end

-- ----- L3 N 件随机完整信息 -----
-- R1(n=2): 10 × 1.0 × 8.8 ≈ 88
-- R2(n=1): 10 × 0.8 × 4.4 ≈ 35
-- R3(n=3): 10 × 0.6 × 13.2 ≈ 79
-- R4(n=1): 10 × 0.4 × 4.4 ≈ 18
function generators.random_items_full(n)
    n = n or 3
    local candidates = getUnrevealedItems(3)
    if #candidates == 0 then return nil end

    local selected = pickRandom(candidates, n)
    local parts = {}
    for _, item in ipairs(selected) do
        local rar = Config.GetRarity(item.rarity)
        local val = item.realValue or Config.GetItemRealValue(item)
        parts[#parts + 1] = item.name .. "（" .. rar.name .. "，" .. FormatValue(val) .. "）"
    end

    return {
        type = "random_items_full",
        text = "发现" .. #selected .. "件藏品：" .. table.concat(parts, "、"),
        reveals = makeReveals(selected, 3),
    }
end

-- ----- L3 N 件偏好高品质完整信息 -----
-- R3(n=1): 10 × 0.6 × 20(gold) ≈ 120
function generators.random_highest_full(n)
    n = n or 1
    local candidates = getUnrevealedItems(3)
    if #candidates == 0 then return nil end

    -- 按品质排序，从高到低
    table.sort(candidates, function(a, b)
        return (QUALITY_ORDER[a.rarity] or 0) > (QUALITY_ORDER[b.rarity] or 0)
    end)

    -- 取前 n×3 个中随机 n 个（偏好高品质但保留随机性）
    local pool = {}
    local poolSize = math.min(n * 3, #candidates)
    for i = 1, poolSize do
        pool[#pool + 1] = candidates[i]
    end
    local selected = pickRandom(pool, n)

    local parts = {}
    for _, item in ipairs(selected) do
        local rar = Config.GetRarity(item.rarity)
        local val = item.realValue or Config.GetItemRealValue(item)
        parts[#parts + 1] = item.name .. "（" .. rar.name .. "，" .. FormatValue(val) .. "）"
    end

    return {
        type = "random_highest_full",
        text = "发现珍品：" .. table.concat(parts, "、"),
        reveals = makeReveals(selected, 3),
    }
end

-- ----- L2 N 件随机品质 -----
-- R1(n=4): 6 × 1.0 × 17.6 ≈ 106
-- R2(n=3): 6 × 0.8 × 13.2 ≈ 63
-- R3(n=5): 6 × 0.6 × 22 ≈ 79
-- R4(n=2): 6 × 0.4 × 8.8 ≈ 21
-- R5(n=1): 6 × 0.2 × 4.4 ≈ 5
function generators.random_items_quality(n)
    n = n or 2
    local candidates = getUnrevealedItems(2)
    if #candidates == 0 then
        candidates = getUnrevealedItems(3)
    end
    if #candidates == 0 then return nil end

    local selected = pickRandom(candidates, n)
    return {
        type = "random_items_quality",
        text = "鉴别" .. #selected .. "件品质：" .. qualityBreakdownText(selected),
        reveals = makeReveals(selected, 2),
    }
end

-- ----- L1 N 件随机轮廓 -----
-- R4(n=3): 3 × 0.4 × 13.2 ≈ 16
-- R5(n=1): 3 × 0.2 × 4.4 ≈ 3
function generators.random_items_outline(n)
    n = n or 3
    local candidates = getUnrevealedItems(1)
    if #candidates == 0 then
        candidates = getUnrevealedItems(2)
    end
    if #candidates == 0 then return nil end

    local selected = pickRandom(candidates, n)
    return {
        type = "random_items_outline",
        text = "扫描到" .. #selected .. "件藏品的轮廓",
        reveals = makeReveals(selected, 1),
    }
end

-- ----- L0 品质件数 -----
-- R4: 1 × 0.4 × 40(purple) ≈ 16
-- R5: 1 × 0.2 × 40(gold) ≈ 8
function generators.rarity_count(qualityId)
    qualityId = qualityId or pickUnusedQuality(true)
    if not qualityId then return nil end
    local items = stats.qualityItems[qualityId]
    if not items or #items == 0 then return nil end
    local colorName = QUALITY_COLOR_NAME[qualityId] or qualityId

    data.usedQualities[qualityId] = true
    return {
        type = "rarity_count",
        text = colorName .. "品质的藏品有 " .. #items .. " 件",
        reveals = {},
    }
end

-- ----- L0 总件数 -----
-- R5: 1 × 0.2 × 264 ≈ 53（纯数量信息）
function generators.total_count()
    return {
        type = "total_count",
        text = "仓库中共有 " .. stats.totalCount .. " 件藏品",
        reveals = {},
    }
end

-- ----- L0 品类件数 -----
-- R4: 1 × 0.4 × 37.7 ≈ 15
-- R5: 1 × 0.2 × 37.7 ≈ 8
function generators.category_count(catId)
    catId = catId or pickUnusedCategory()
    if not catId then return nil end
    local items = stats.catItems[catId]
    if not items or #items == 0 then return nil end
    local catName = stats.catNames[catId] or catId

    data.usedCategories[catId] = true
    return {
        type = "category_count",
        text = catName .. "类藏品有 " .. #items .. " 件",
        reveals = {},
    }
end

-- ============================================================================
-- 每轮 5 个备选方案（随机抽取 1 个）
-- ============================================================================

local ROUND_CONFIG = {
    -- R1 (T=1.0): 大信息量回合
    [1] = {
        -- A: L2 × 1品类全部品质 ≈ 226
        { gen = "category_quality" },
        -- B: L1 × 2品类全部轮廓 ≈ 226
        { gen = "dual_category_outline" },
        -- C: L3 × 2件随机完整 ≈ 88
        { gen = "random_items_full", args = { n = 2 } },
        -- D: L2 × 4件随机品质 ≈ 106
        { gen = "random_items_quality", args = { n = 4 } },
        -- E: L2 × 某品质全部 ≈ 180(绿) / 120(蓝)
        { gen = "quality_group_quality" },
    },

    -- R2 (T=0.8): 中等信息量
    [2] = {
        -- A: L1 × 金色物品尺寸 ≈ 96
        { gen = "rarity_size_hint", args = { qualityId = "gold" } },
        -- B: L2 × 3件随机品质 ≈ 63
        { gen = "random_items_quality", args = { n = 3 } },
        -- C: L1 × 1品类全部轮廓 ≈ 90
        { gen = "category_outline" },
        -- D: L3 × 1件随机完整 ≈ 35
        { gen = "random_items_full", args = { n = 1 } },
        -- E: L0 × 某高品质件数 ≈ 32(purple)
        { gen = "rarity_count", args = { qualityId = "purple" } },
    },

    -- R3 (T=0.6): 中等偏低
    [3] = {
        -- A: L3 × 3件随机完整 ≈ 79
        { gen = "random_items_full", args = { n = 3 } },
        -- B: L2 × 1品类全部品质 ≈ 136(首次) / 更低(已有揭示)
        { gen = "category_quality" },
        -- C: L2 × 5件随机品质 ≈ 79
        { gen = "random_items_quality", args = { n = 5 } },
        -- D: L3 × 1件偏高品质 ≈ 120(gold)
        { gen = "random_highest_full", args = { n = 1 } },
        -- E: L1 × 1品类全部轮廓 ≈ 68
        { gen = "category_outline" },
    },

    -- R4 (T=0.4): 小信息量
    [4] = {
        -- A: L2 × 2件随机品质 ≈ 21
        { gen = "random_items_quality", args = { n = 2 } },
        -- B: L3 × 1件随机完整 ≈ 18
        { gen = "random_items_full", args = { n = 1 } },
        -- C: L1 × 3件随机轮廓 ≈ 16
        { gen = "random_items_outline", args = { n = 3 } },
        -- D: L0 × 某品质件数 ≈ 16
        { gen = "rarity_count" },
        -- E: L0 × 1品类件数 ≈ 15
        { gen = "category_count" },
    },

    -- R5 (T=0.2): 微信息量
    [5] = {
        -- A: L0 × 金色件数 ≈ 8
        { gen = "rarity_count", args = { qualityId = "gold" } },
        -- B: L0 × 某品质件数 ≈ varies
        { gen = "rarity_count" },
        -- C: L0 × 1品类件数 ≈ 8
        { gen = "category_count" },
        -- D: L2 × 1件随机品质 ≈ 5
        { gen = "random_items_quality", args = { n = 1 } },
        -- E: L1 × 1件随机轮廓 ≈ 3
        { gen = "random_items_outline", args = { n = 1 } },
    },
}

-- ============================================================================
-- 为某一轮生成信息（从 5 个备选中随机选 1 个）
-- ============================================================================

local function tryGenerate(entry)
    local genFn = generators[entry.gen]
    if not genFn then return nil end

    if entry.args then
        if entry.args.qualityId then
            return genFn(entry.args.qualityId)
        elseif entry.args.n then
            return genFn(entry.args.n)
        elseif entry.args.catId then
            return genFn(entry.args.catId)
        end
    end
    return genFn()
end

local function generateRound(round)
    local config = ROUND_CONFIG[round]
    if not config then return {} end

    -- 打乱顺序，依次尝试直到成功
    local shuffled = shuffle(config)
    for _, entry in ipairs(shuffled) do
        local info = tryGenerate(entry)
        if info then
            info.round = round
            info.scope = "public"
            applyReveals(info.reveals)
            return { info }
        end
    end

    return {}
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 初始化：分析仓库物品，预生成所有轮次的揭示计划
---@param items table 仓库物品列表
function RevealPlanner.Init(items)
    data.items = items
    data.itemRevealLevels = {}
    data.roundPlans = {}
    data.usedCategories = {}
    data.usedQualities = {}

    for _, item in ipairs(items) do
        if item.idx then
            data.itemRevealLevels[item.idx] = 0
        end
    end

    analyze(items)

    for round = 1, Config.GAME.MaxRounds do
        data.roundPlans[round] = generateRound(round)
        for _, info in ipairs(data.roundPlans[round]) do
            print("[RevealPlanner] Round " .. round .. " [" .. info.type .. "]: " .. info.text)
        end
    end
end

--- 获取某轮的揭示计划
---@param round number 轮次
---@return table[] infos 信息列表，每条含 { type, text, reveals, round, scope }
function RevealPlanner.GetRoundPlan(round)
    return data.roundPlans[round] or {}
end

--- 查询某物品当前揭示等级
---@param itemIdx number
---@return number 0|1|2|3
function RevealPlanner.GetItemRevealLevel(itemIdx)
    return data.itemRevealLevels[itemIdx] or 0
end

--- 获取所有物品的揭示等级表
---@return table { [itemIdx] = level }
function RevealPlanner.GetAllRevealLevels()
    return data.itemRevealLevels
end

return RevealPlanner
