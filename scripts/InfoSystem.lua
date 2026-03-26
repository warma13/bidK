-- ============================================================================
-- InfoSystem.lua - 信息揭露系统
-- 分析仓库内容，生成每轮的全场信息和角色私密线索
-- 统一 revealEvents 引擎
-- ============================================================================

local Config = require("Config")
local RevealPlanner = require("RevealPlanner")

local InfoSystem = {}

-- 内部数据
local data = {
    warehouseItems = {},       -- 仓库藏品列表
    warehouseStats = {},       -- 仓库统计数据
    roundInfos = {},           -- { [round] = { publics={...}, skills={[playerIdx]=...} } }
    warehouseTypeId = nil,     -- 当前仓库类型ID
    players = nil,             -- 玩家列表引用（按需生成时使用）
}

-- ============================================================================
-- 初始化
-- ============================================================================

function InfoSystem.Init(warehouseItems, players, warehouseTypeId)
    data.warehouseItems = warehouseItems
    data.roundInfos = {}
    data.warehouseTypeId = warehouseTypeId
    data.players = players

    -- 统计仓库数据
    data.warehouseStats = InfoSystem.AnalyzeWarehouse(warehouseItems)

    -- 初始化专精匹配（兼容旧数据）
    InfoSystem.InitSpecialty(players)

    -- RevealPlanner 负责公开信息生成
    RevealPlanner.Init(warehouseItems)

    print("[InfoSystem] Initialized with " .. #warehouseItems .. " items (lazy generation)")
    print("[InfoSystem] Total value: " .. data.warehouseStats.totalValue)
end

--- 按需生成指定轮次的信息（反作弊）
local function EnsureRoundGenerated(round)
    if data.roundInfos[round] then return end
    data.roundInfos[round] = {
        publics = RevealPlanner.GetRoundPlan(round),
        skills = InfoSystem.GenerateSkillInfos(round, data.players),
    }
    print("[InfoSystem] Generated info for round " .. round .. " on demand")
end

-- ============================================================================
-- 初始化专精匹配（兼容旧数据，新角色不再使用）
-- ============================================================================

function InfoSystem.InitSpecialty(players)
    if not Config.WAREHOUSE_TYPES then return end
    local typeIds = {}
    for typeId, _ in pairs(Config.WAREHOUSE_TYPES) do
        typeIds[#typeIds + 1] = typeId
    end
    for _, player in ipairs(players) do
        local char = player.character
        if char.passiveEffect and char.passiveEffect.type == "specialty" then
            local randType = typeIds[math.random(1, #typeIds)]
            player.specialtyType = randType
            player.specialtyMatch = (randType == data.warehouseTypeId)
            local typeName = Config.WAREHOUSE_TYPES[randType] and Config.WAREHOUSE_TYPES[randType].name or randType
            print("[InfoSystem] " .. char.name .. " specialty: " .. typeName
                .. (player.specialtyMatch and " (MATCH!)" or " (no match)"))
        end
    end
end

-- ============================================================================
-- 分析仓库内容，建立统计数据
-- ============================================================================

function InfoSystem.AnalyzeWarehouse(items)
    local stats = {
        totalCount = #items,
        totalValue = 0,
        categoryCounts = {},
        categoryNames = {},
        rarityCounts = {},
        rarityNames = {},
        highestRarity = nil,
        lowestRarity = nil,
        mostValuableItem = nil,
        leastValuableItem = nil,
        rarityOrder = {},
    }

    for i, r in ipairs(Config.RARITY) do
        stats.rarityOrder[r.id] = i
    end

    local highIdx, lowIdx = 0, 999
    local highVal, lowVal = 0, 999999999

    for _, item in ipairs(items) do
        local realValue = item.realValue or Config.GetItemRealValue(item)
        stats.totalValue = stats.totalValue + realValue

        if item.category then
            local cat = Config.GetCategory(item.category)
            stats.categoryCounts[item.category] = (stats.categoryCounts[item.category] or 0) + 1
            stats.categoryNames[item.category] = cat.name
        end

        local rar = Config.GetRarity(item.rarity)
        stats.rarityCounts[item.rarity] = (stats.rarityCounts[item.rarity] or 0) + 1
        stats.rarityNames[item.rarity] = rar.name

        local rIdx = stats.rarityOrder[item.rarity] or 0
        if rIdx > highIdx then
            highIdx = rIdx
            stats.highestRarity = item.rarity
        end
        if rIdx < lowIdx then
            lowIdx = rIdx
            stats.lowestRarity = item.rarity
        end
        if realValue > highVal then
            highVal = realValue
            stats.mostValuableItem = item
        end
        if realValue < lowVal then
            lowVal = realValue
            stats.leastValuableItem = item
        end
    end

    return stats
end

-- ============================================================================
-- 工具函数
-- ============================================================================

function FormatValue(val)
    if val >= 10000 then
        return string.format("%.1f万", val / 10000)
    end
    return tostring(math.floor(val))
end

function InfoSystem.MakeRarityReveals(rarityId)
    local reveals = {}
    for _, item in ipairs(data.warehouseItems) do
        if item.rarity == rarityId and item.idx then
            reveals[#reveals + 1] = { itemIdx = item.idx, targetLevel = 2 }
        end
    end
    return reveals
end

-- ============================================================================
-- 揭示事件引擎（统一处理 revealEvents）
-- ============================================================================

--- 判断揭示事件是否在指定回合触发
function InfoSystem.ShouldTrigger(trigger, round)
    if trigger == "every_round" then return true end
    local exactRound = trigger:match("^round_(%d+)$")
    if exactRound then return round == tonumber(exactRound) end
    local fromRound = trigger:match("^from_round_(%d+)$")
    if fromRound then return round >= tonumber(fromRound) end
    return false
end

--- 按品类过滤仓库物品
function InfoSystem.FilterByCategory(category)
    if not category then return data.warehouseItems end
    local catSet = {}
    if type(category) == "string" then
        catSet[category] = true
    elseif type(category) == "table" then
        for _, c in ipairs(category) do catSet[c] = true end
    end
    local result = {}
    for _, item in ipairs(data.warehouseItems) do
        if catSet[item.category] then result[#result + 1] = item end
    end
    return result
end

--- 获取品类显示名称
function InfoSystem.GetCategoryDisplayName(category)
    if not category then return nil end
    if type(category) == "string" then
        local cat = Config.GetCategory(category)
        return cat and cat.name or category
    elseif type(category) == "table" then
        local names = {}
        for _, c in ipairs(category) do
            local cat = Config.GetCategory(c)
            names[#names + 1] = cat and cat.name or c
        end
        return table.concat(names, "和")
    end
    return nil
end

--- 从候选列表中随机挑选N件
function InfoSystem.PickRandomItems(candidates, n)
    if #candidates <= n then return candidates end
    local copy = {}
    for i, item in ipairs(candidates) do copy[i] = item end
    for i = #copy, 2, -1 do
        local j = math.random(1, i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    local result = {}
    for i = 1, n do result[i] = copy[i] end
    return result
end

--- 从候选列表中挑选品质最高的N件
function InfoSystem.PickHighestItems(candidates, n)
    local sorted = {}
    for i, item in ipairs(candidates) do sorted[i] = item end
    table.sort(sorted, function(a, b)
        local aIdx = data.warehouseStats.rarityOrder[a.rarity] or 0
        local bIdx = data.warehouseStats.rarityOrder[b.rarity] or 0
        if aIdx ~= bIdx then return aIdx > bIdx end
        local aVal = a.realValue or Config.GetItemRealValue(a)
        local bVal = b.realValue or Config.GetItemRealValue(b)
        return aVal > bVal
    end)
    local result = {}
    for i = 1, math.min(n, #sorted) do result[i] = sorted[i] end
    return result
end

--- 根据target类型选择物品
function InfoSystem.SelectItems(target, candidates)
    if target == "all" or target == "category_all" then
        return candidates
    end
    local n = tonumber(target:match("(%d+)$"))
    if not n then return {} end

    if target:match("^random_") or target:match("^category_random_") then
        return InfoSystem.PickRandomItems(candidates, n)
    elseif target:match("^highest_") then
        return InfoSystem.PickHighestItems(candidates, n)
    elseif target:match("^rare_random_") then
        local rares = {}
        for _, item in ipairs(candidates) do
            local rIdx = data.warehouseStats.rarityOrder[item.rarity] or 0
            if rIdx >= 4 then rares[#rares + 1] = item end
        end
        return InfoSystem.PickRandomItems(rares, n)
    end
    return {}
end

--- 处理单个揭示事件，返回一条线索 info 或 nil
function InfoSystem.ProcessRevealEvent(event, playerIdx, round)
    local level = event.level
    local target = event.target
    local category = event.category
    local candidates = InfoSystem.FilterByCategory(category)
    local catName = InfoSystem.GetCategoryDisplayName(category)

    if level == "L0" then
        -- 数量信息
        local text
        if catName then
            text = catName .. "类共有 " .. #candidates .. " 件物品"
        else
            text = "仓库共有 " .. #candidates .. " 件物品"
        end
        return { text = text, icon = "" }
    end

    -- L1/L2/L3: 选择具体物品
    local selected = InfoSystem.SelectItems(target, candidates)
    if #selected == 0 then return nil end

    local levelNum = ({ L1 = 1, L2 = 2, L3 = 3 })[level] or 2
    local reveals = {}
    for _, item in ipairs(selected) do
        if item.idx then
            reveals[#reveals + 1] = { itemIdx = item.idx, targetLevel = levelNum }
        end
    end

    local text
    if level == "L1" then
        -- 轮廓信息
        if catName then
            text = "你看到了 " .. #selected .. " 件" .. catName .. "物品的轮廓"
        else
            text = "你看到了 " .. #selected .. " 件物品的轮廓"
        end

    elseif level == "L2" then
        -- 品质鉴别：按品质分组统计
        local rarCounts = {}
        local rarOrder = {}
        for _, item in ipairs(selected) do
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
        local prefix = catName and (catName .. "中") or ""
        text = "鉴别" .. prefix .. #selected .. "件品质：" .. table.concat(parts, "、")

    elseif level == "L3" then
        -- 完整信息
        local parts = {}
        for _, item in ipairs(selected) do
            local rar = Config.GetRarity(item.rarity)
            local val = item.realValue or Config.GetItemRealValue(item)
            parts[#parts + 1] = item.name .. "（" .. rar.name .. "，" .. FormatValue(val) .. "）"
        end
        text = "看透：" .. table.concat(parts, "、")
    else
        -- 无新线索时不生成条目
        return nil
    end

    local result = { text = text, icon = "", reveals = reveals }

    -- L3 保留 revealedItem 字段兼容旧逻辑
    if level == "L3" and #selected >= 1 then
        result.revealedItem = selected[1]
    end

    return result
end

-- ============================================================================
-- 生成角色私密线索（每轮每位角色，可能多条）
-- ============================================================================

function InfoSystem.GenerateSkillInfos(round, players)
    local skills = {}

    for idx, player in ipairs(players) do
        local char = player.character
        local revealEvents = char.revealEvents
        local infos = {}

        if revealEvents then
            for _, event in ipairs(revealEvents) do
                if InfoSystem.ShouldTrigger(event.trigger, round) then
                    local result = InfoSystem.ProcessRevealEvent(event, idx, round)
                    if result then
                        infos[#infos + 1] = result
                    end
                end
            end
        end

        -- 无线索时跳过，不生成空条目
        if #infos > 0 then
            local info = infos[1]
            info.round = round
            info.scope = "skill"
            info.targetPlayer = idx
            -- 额外线索存入 extraInfos
            if #infos > 1 then
                info.extraInfos = {}
                for i = 2, #infos do
                    infos[i].round = round
                    infos[i].scope = "skill"
                    infos[i].targetPlayer = idx
                    info.extraInfos[#info.extraInfos + 1] = infos[i]
                end
            end
            skills[idx] = info

            if player.isHuman then
                print("[InfoSystem] Round " .. round .. " skill for " .. player.name .. ": " .. info.text)
                if info.extraInfos then
                    for _, extra in ipairs(info.extraInfos) do
                        print("[InfoSystem]   extra: " .. extra.text)
                    end
                end
            end
        end
    end

    return skills
end

-- ============================================================================
-- 主动技能：全仓透视（返回价值最高的N件物品信息列表）
-- ============================================================================

function InfoSystem.RevealTopItems(count, skip)
    skip = skip or 0
    local sorted = {}
    for _, item in ipairs(data.warehouseItems) do
        sorted[#sorted + 1] = item
    end
    table.sort(sorted, function(a, b)
        local va = a.realValue or Config.GetItemRealValue(a)
        local vb = b.realValue or Config.GetItemRealValue(b)
        return va > vb
    end)

    local result = {}
    local startIdx = skip + 1
    local endIdx = math.min(skip + count, #sorted)
    for i = startIdx, endIdx do
        local item = sorted[i]
        local rar = Config.GetRarity(item.rarity)
        local val = item.realValue or Config.GetItemRealValue(item)
        result[#result + 1] = {
            text = "TOP" .. i .. "：" .. item.name .. "（" .. rar.name .. "，价值 " .. val .. "）",
            icon = "",
            revealedItem = item,
            round = 0,
            scope = "skill",
        }
    end
    return result
end

-- ============================================================================
-- 辅助函数（保留兼容）
-- ============================================================================

function InfoSystem.PickUnrevealedItem(playerIdx, currentRound)
    local shown = {}
    for r = 1, currentRound - 1 do
        if data.roundInfos[r] and data.roundInfos[r].skills[playerIdx] then
            local si = data.roundInfos[r].skills[playerIdx]
            if si.revealedItem then
                local rid = si.revealedItem.id or si.revealedItem.idx
                if rid then shown[rid] = true end
            end
            if si.extraInfos then
                for _, extra in ipairs(si.extraInfos) do
                    if extra.revealedItem then
                        local rid = extra.revealedItem.id or extra.revealedItem.idx
                        if rid then shown[rid] = true end
                    end
                end
            end
        end
    end
    for r = 1, currentRound do
        if data.roundInfos[r] and data.roundInfos[r].publics then
            for _, pi in ipairs(data.roundInfos[r].publics) do
                if pi.revealedItem then
                    local rid = pi.revealedItem.id or pi.revealedItem.idx
                    if rid then shown[rid] = true end
                end
            end
        end
    end

    local candidates = {}
    for _, item in ipairs(data.warehouseItems) do
        local itemId = item.id or item.idx
        if itemId and not shown[itemId] then
            candidates[#candidates + 1] = item
        end
    end

    if #candidates == 0 then return nil end
    return candidates[math.random(1, #candidates)]
end

-- ============================================================================
-- 外部接口
-- ============================================================================

function InfoSystem.GetRoundInfos(round)
    EnsureRoundGenerated(round)
    return data.roundInfos[round]
end

function InfoSystem.GetAllPublicInfos(upToRound)
    local result = {}
    for r = 1, upToRound do
        EnsureRoundGenerated(r)
        if data.roundInfos[r] and data.roundInfos[r].publics then
            for _, info in ipairs(data.roundInfos[r].publics) do
                result[#result + 1] = info
            end
        end
    end
    return result
end

function InfoSystem.GetPlayerSkillInfos(playerIdx, upToRound)
    local result = {}
    for r = 1, upToRound do
        EnsureRoundGenerated(r)
        if data.roundInfos[r] and data.roundInfos[r].skills[playerIdx] then
            result[#result + 1] = data.roundInfos[r].skills[playerIdx]
        end
    end
    return result
end

function InfoSystem.GetWarehouseStats()
    return data.warehouseStats
end

return InfoSystem
