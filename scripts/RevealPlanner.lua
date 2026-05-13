-- ============================================================================
-- RevealPlanner.lua - 仓库公开信息揭示计划生成器
-- 纯数据模块，不依赖 UI，根据仓库物品生成每轮的揭示计划
--
-- 每场竞拍共 5 轮，奇数轮（1 3 5）显示揭示信息，偶数轮（2 4）不揭示
--
-- 揭示类型（8 种）：
--   total_cells         - 所有藏品格子总数（纯文字）
--   quality_outline     - 所有 X 品质藏品的轮廓（L1）
--   random_items_full   - 随机 N 件藏品完整信息（L3）
--   random_items_quality- 随机 N 件藏品品质（L2）
--   top_value_item      - 最高价值藏品完整信息（L3）
--   top_cells_item      - 占格数最多的藏品完整信息（L3）
--   quality_avg_cells   - X 品质藏品平均格子数（纯文字）
--   quality_avg_value   - X 品质藏品平均价值（纯文字）
--   quality_count       - 本场拍卖共有 X 品质藏品 N 件（纯文字）
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
    roundPlans = {},           -- { [round] = { info1, ... } }
    usedQualities = {},        -- 已使用的品质 { [qualityId] = true }
    regionId = nil,            -- 当前仓库所属区域ID
}

-- ============================================================================
-- 统计分析
-- ============================================================================

local stats = {}

local function analyze(items)
    stats = {
        totalCount    = #items,
        totalCells    = 0,         -- 所有物品格子总数
        qualityItems  = {},        -- { [qualityId] = { item, ... } }
        qualityIds    = {},        -- 有物品的品质ID列表（低→高）
        mostValuable  = nil,       -- 价值最高的物品
        mostCells     = nil,       -- 占格数最多的物品
    }

    local maxVal   = -1
    local maxCells = -1

    for _, item in ipairs(items) do
        local cells = (item.w or 1) * (item.h or 1)
        stats.totalCells = stats.totalCells + cells

        if cells > maxCells then
            maxCells = cells
            stats.mostCells = item
        end

        local q = item.rarity
        if q then
            if not stats.qualityItems[q] then
                stats.qualityItems[q] = {}
            end
            local list = stats.qualityItems[q]
            list[#list + 1] = item
        end

        local val = item.realValue or Config.GetItemRealValue(item)
        if val > maxVal then
            maxVal = val
            stats.mostValuable = item
        end
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

--- 从未使用的品质中随机选一个（preferHigh=true 时偏好高品质）
local function pickUnusedQuality(preferHigh)
    local candidates = {}
    for _, qId in ipairs(stats.qualityIds) do
        if not data.usedQualities[qId] then
            candidates[#candidates + 1] = qId
        end
    end
    if #candidates == 0 then
        -- 全部用过，重置
        data.usedQualities = {}
        candidates = {}
        for _, qId in ipairs(stats.qualityIds) do
            candidates[#candidates + 1] = qId
        end
    end
    if #candidates == 0 then return nil end

    if preferHigh then
        table.sort(candidates, function(a, b)
            return (QUALITY_ORDER[a] or 0) > (QUALITY_ORDER[b] or 0)
        end)
        -- 从前两个高品质中随机选
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
    local rarOrder  = {}
    for _, item in ipairs(items) do
        local rar  = Config.GetRarity(item.rarity)
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

-- ============================================================================
-- 全局 FormatValue
-- ============================================================================

function FormatValue(val)
    if val >= 10000 then
        return string.format("%.1f万", val / 10000)
    end
    return tostring(math.floor(val))
end

-- ============================================================================
-- 6 种信息生成器
-- ============================================================================

local generators = {}

-- ----- 1. 所有藏品格子总数（纯文字，不揭示） -----
function generators.total_cells()
    return {
        type        = "total_cells",
        text        = "所有藏品总占用的格子数量为 " .. stats.totalCells .. " 格",
        reveals     = {},
        -- 机器可读字段
        totalCells  = stats.totalCells,
        totalCount  = stats.totalCount,
    }
end

-- ----- 1b. 每件藏品平均格子数（纯文字，不揭示） -----
function generators.avg_cells_per_item()
    if stats.totalCount == 0 then return nil end
    local avg = stats.totalCells / stats.totalCount
    return {
        type             = "avg_cells_per_item",
        text             = "每件藏品平均占用的格子数量约为" .. string.format("%.2f", avg) .. "格",
        reveals          = {},
        -- 机器可读字段
        avgCellsPerItem  = avg,
        totalCount       = stats.totalCount,
    }
end

-- ----- 2. 所有 X 品质藏品的轮廓（L1） -----
function generators.quality_outline(qualityId)
    qualityId = qualityId or pickUnusedQuality(false)
    if not qualityId then return nil end
    local items = stats.qualityItems[qualityId]
    if not items or #items == 0 then return nil end

    local colorName = QUALITY_COLOR_NAME[qualityId] or qualityId
    data.usedQualities[qualityId] = true
    return {
        type    = "quality_outline",
        text    = "扫描到全部 " .. #items .. " 件" .. colorName .. "品质藏品的轮廓",
        reveals = makeReveals(items, 1),
    }
end

-- ----- 3. 随机 N 件藏品完整信息（L3） -----
function generators.random_items_full(n)
    -- n 为 nil 时随机选 4 或 6
    if not n then
        n = (math.random(2) == 1) and 4 or 6
    end
    if #data.items == 0 then return nil end
    local selected = pickRandom(data.items, n)

    local parts = {}
    for _, item in ipairs(selected) do
        local rar = Config.GetRarity(item.rarity)
        local val = item.realValue or Config.GetItemRealValue(item)
        parts[#parts + 1] = item.name .. "（" .. rar.name .. "，" .. FormatValue(val) .. "）"
    end

    return {
        type    = "random_items_full",
        text    = "随机鉴定 " .. #selected .. " 件藏品：" .. table.concat(parts, "、"),
        reveals = makeReveals(selected, 3),
    }
end

-- ----- 4. 随机 N 件藏品品质（L2） -----
function generators.random_items_quality(n)
    if not n then
        n = (math.random(2) == 1) and 3 or 12
    end
    if #data.items == 0 then return nil end
    local selected = pickRandom(data.items, n)

    return {
        type    = "random_items_quality",
        text    = "鉴别 " .. #selected .. " 件藏品品质：" .. qualityBreakdownText(selected),
        reveals = makeReveals(selected, 2),
    }
end

-- ----- 5. 最高价值藏品完整信息（L3） -----
function generators.top_value_item()
    local item = stats.mostValuable
    if not item then return nil end

    local rar = Config.GetRarity(item.rarity)
    local val = item.realValue or Config.GetItemRealValue(item)
    return {
        type    = "top_value_item",
        text    = "发现最高价值藏品：" .. item.name .. "（" .. rar.name .. "，" .. FormatValue(val) .. "）",
        reveals = makeReveals({ item }, 3),
    }
end

-- ----- 6. X 品质藏品平均格子数（纯文字，不揭示） -----
function generators.quality_avg_cells(qualityId)
    qualityId = qualityId or pickUnusedQuality(true)
    if not qualityId then return nil end
    local items = stats.qualityItems[qualityId]
    if not items or #items == 0 then return nil end

    local totalCells = 0
    for _, item in ipairs(items) do
        totalCells = totalCells + (item.w or 1) * (item.h or 1)
    end
    local avg = math.floor(totalCells / #items + 0.5)
    local colorName = QUALITY_COLOR_NAME[qualityId] or qualityId

    data.usedQualities[qualityId] = true
    return {
        type            = "quality_avg_cells",
        text            = colorName .. "品质藏品共 " .. #items .. " 件，平均占 " .. avg .. " 格",
        reveals         = {},
        -- 机器可读字段
        rarityId        = qualityId,
        rarityCount     = #items,
        rarityAvgCells  = avg,
    }
end

-- ----- 7. 占格数最多的藏品完整信息（L3） -----
function generators.top_cells_item()
    local item = stats.mostCells
    if not item then return nil end

    local rar   = Config.GetRarity(item.rarity)
    local val   = item.realValue or Config.GetItemRealValue(item)
    local cells = (item.w or 1) * (item.h or 1)
    return {
        type    = "top_cells_item",
        text    = "占位格数最多的藏品：" .. item.name .. "（" .. rar.name .. "，占 " .. cells .. " 格，" .. FormatValue(val) .. "）",
        reveals = makeReveals({ item }, 3),
    }
end

-- ----- 8. X 品质藏品平均价值（纯文字，不揭示） -----
function generators.quality_avg_value(qualityId)
    qualityId = qualityId or pickUnusedQuality(false)
    if not qualityId then return nil end
    local items = stats.qualityItems[qualityId]
    if not items or #items == 0 then return nil end

    local totalVal = 0
    for _, item in ipairs(items) do
        totalVal = totalVal + (item.realValue or Config.GetItemRealValue(item))
    end
    local avg = totalVal / #items
    local colorName = QUALITY_COLOR_NAME[qualityId] or qualityId

    data.usedQualities[qualityId] = true
    return {
        type             = "quality_avg_value",
        text             = "所有" .. colorName .. "品质藏品的平均价值约为" .. string.format("%.2f", avg),
        reveals          = {},
        -- 机器可读字段
        rarityId         = qualityId,
        rarityCount      = #items,
        rarityAvgValue   = avg,
    }
end

-- ----- 9. 随机显示 1 件最高品质的藏品完整信息（L3） -----
function generators.highest_quality_item()
    -- 找出仓库中品质最高的等级
    local topQualityId = nil
    local topOrder = -1
    for _, qId in ipairs(stats.qualityIds) do
        local ord = QUALITY_ORDER[qId] or 0
        if ord > topOrder and stats.qualityItems[qId] and #stats.qualityItems[qId] > 0 then
            topOrder = ord
            topQualityId = qId
        end
    end
    if not topQualityId then return nil end

    local items = stats.qualityItems[topQualityId]
    local item  = items[math.random(1, #items)]
    local rar   = Config.GetRarity(item.rarity)
    local val   = item.realValue or Config.GetItemRealValue(item)
    return {
        type    = "highest_quality_item",
        text    = "随机展示1件最高品质藏品：" .. item.name .. "（" .. rar.name .. "，" .. FormatValue(val) .. "）",
        reveals = makeReveals({ item }, 3),
    }
end

-- ----- 10. X 品质藏品总占格子数（纯文字，不揭示） -----
function generators.quality_total_cells(qualityId)
    qualityId = qualityId or pickUnusedQuality(false)
    if not qualityId then return nil end
    local items = stats.qualityItems[qualityId]
    if not items or #items == 0 then return nil end

    local totalCells = 0
    for _, item in ipairs(items) do
        totalCells = totalCells + (item.w or 1) * (item.h or 1)
    end
    local avg = math.floor(totalCells / #items + 0.5)
    local colorName = QUALITY_COLOR_NAME[qualityId] or qualityId

    data.usedQualities[qualityId] = true
    return {
        type              = "quality_total_cells",
        text              = colorName .. "品质总占用的格子数量为" .. totalCells .. "格",
        reveals           = {},
        -- 机器可读字段
        rarityId          = qualityId,
        rarityCount       = #items,
        rarityTotalCells  = totalCells,
        rarityAvgCells    = avg,
    }
end

-- ----- 11. 随机 N 件藏品的平均价值（纯文字，不揭示） -----
function generators.random_avg_value(n)
    if not n then
        n = (math.random(2) == 1) and 4 or 6
    end
    if #data.items == 0 then return nil end
    local selected = pickRandom(data.items, n)

    local totalVal = 0
    for _, item in ipairs(selected) do
        totalVal = totalVal + (item.realValue or Config.GetItemRealValue(item))
    end
    local avg = totalVal / #selected
    return {
        type            = "random_avg_value",
        text            = "随机选择的" .. #selected .. "件藏品的平均价值约为" .. string.format("%.1f", avg),
        reveals         = {},
        -- 机器可读字段
        sampleCount     = #selected,
        sampleAvgValue  = avg,
        totalCount      = stats.totalCount,
    }
end

-- ----- 12. 本场拍卖共有 X 品质藏品 N 件（纯文字，不揭示） -----
function generators.quality_count(qualityId)
    qualityId = qualityId or pickUnusedQuality(false)
    if not qualityId then return nil end
    local items = stats.qualityItems[qualityId]
    if not items or #items == 0 then return nil end

    local colorName = QUALITY_COLOR_NAME[qualityId] or qualityId
    data.usedQualities[qualityId] = true
    return {
        type        = "quality_count",
        text        = "本场拍卖共有" .. colorName .. "品质藏品 " .. #items .. " 件",
        reveals     = {},
        -- 机器可读字段
        rarityId    = qualityId,
        rarityCount = #items,
    }
end

-- ============================================================================
-- 每轮候选池配置
-- 每轮从候选池中随机抽取 1 个，尝试生成直到成功
-- ============================================================================

--[[
  揭示节奏：奇数轮（1 3 5）显示揭示信息，偶数轮（2 4）不揭示（让玩家专注竞拍）

  - R1: 整体概况（总格子数、大量品质鉴别、轮廓）
  - R2: 不揭示
  - R3: 发现重要藏品（随机完整、最高价值、占格最多）
  - R4: 不揭示
  - R5: 品质分析（平均价值、平均格子、轮廓）
]]
local ROUND_CONFIG = {
    -- R1: 整体概况
    [1] = {
        { gen = "total_cells" },
        { gen = "avg_cells_per_item" },
        { gen = "quality_count" },
        { gen = "quality_total_cells" },
        { gen = "random_items_quality" },
        { gen = "random_avg_value" },
        { gen = "random_items_full" },
    },

    -- R2: 非1万场时使用
    [2] = {
        { gen = "quality_outline" },
        { gen = "quality_count" },
        { gen = "quality_total_cells" },
        { gen = "random_items_quality" },
        { gen = "avg_cells_per_item" },
    },

    -- R3: 发现重要藏品
    [3] = {
        { gen = "random_items_full" },
        { gen = "top_value_item" },
        { gen = "top_cells_item" },
        { gen = "highest_quality_item" },
        { gen = "random_avg_value" },
        { gen = "quality_count" },
    },

    -- R4: 非1万场时使用
    [4] = {
        { gen = "random_avg_value" },
        { gen = "quality_avg_value" },
        { gen = "quality_avg_cells" },
        { gen = "random_items_full" },
        { gen = "highest_quality_item" },
    },

    -- R5: 品质深度分析
    [5] = {
        { gen = "quality_avg_value" },
        { gen = "quality_avg_cells" },
        { gen = "quality_total_cells" },
        { gen = "quality_count" },
        { gen = "random_avg_value" },
        { gen = "highest_quality_item" },
    },
}

-- ============================================================================
-- 为某一轮生成信息（从候选池中随机抽 1 个）
-- ============================================================================

local function tryGenerate(entry)
    local genFn = generators[entry.gen]
    if not genFn then return nil end
    if entry.args then
        if entry.args.qualityId then
            return genFn(entry.args.qualityId)
        elseif entry.args.n then
            return genFn(entry.args.n)
        end
    end
    return genFn()
end

local function generateRound(round)
    -- 50万场（commercial）只在奇数轮揭示，偶数轮跳过
    if data.regionId == "commercial" and (round == 2 or round == 4) then
        return {}
    end

    local config = ROUND_CONFIG[round]
    if not config then return {} end

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
---@param regionId string|nil 仓库所属区域ID（"suburb"=1万场，只在奇数轮揭示）
function RevealPlanner.Init(items, regionId)
    data.items = items
    data.itemRevealLevels = {}
    data.roundPlans = {}
    data.usedQualities = {}
    data.regionId = regionId

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
