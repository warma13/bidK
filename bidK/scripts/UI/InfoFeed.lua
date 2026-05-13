-- ============================================================================
-- UI/InfoFeed.lua - 统一信息流管理模块
-- 负责信息卡片的追加、排序、渲染，保证插入顺序正确
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local UIState = require("UI.UIState")

local InfoFeed = {}

local GS = GameState

local C = Config.COLORS

-- 全局插入序号，每次追加递增，保证时间线顺序
local insertSeq = 0

-- 已提交的信息列表 { { info=..., isSkill=bool, seq=number }, ... }
local feedEntries = {}

-- 上次 Rebuild 时的 entry 数量，用于脏检测避免无效重建
local lastRebuiltCount = 0

-- ============================================================================
-- 信息卡片创建
-- ============================================================================

function InfoFeed.CreateInfoCard(info, isSkill, dark)
    local avatarImage = nil
    local titleText = GS.GetWarehouseName() .. ":竞拍信息"

    if isSkill then
        local player = GS.GetPlayers()[1]
        if player then
            avatarImage = player.character.avatar
            titleText = player.character.name .. ":" .. player.character.ability
        end
    else
        -- 仓库信息卡片：使用仓库图标
        local whData = GS.GetWarehouseData()
        if whData and whData.warehouseTypeId then
            local whType = Config.WAREHOUSE_TYPES[whData.warehouseTypeId]
            if whType and whType.icon and whType.icon ~= "" then
                avatarImage = whType.icon
            end
        end
    end

    local cardBg, thumbBg, titleColor, descColor
    if dark then
        cardBg = { 30, 38, 58, 200 }
        thumbBg = { 40, 50, 72, 255 }
        titleColor = isSkill and { 190, 160, 230, 255 } or { 210, 215, 230, 255 }
        descColor = { 150, 155, 170, 255 }
    else
        cardBg = { 245, 245, 248, 255 }
        thumbBg = isSkill and { 230, 220, 240, 255 } or { 220, 222, 228, 255 }
        titleColor = isSkill and { 90, 50, 130, 255 } or { 45, 45, 50, 255 }
        descColor = { 100, 100, 110, 255 }
    end

    return UI.Panel {
        width = "100%",
        backgroundColor = cardBg,
        borderRadius = 0,
        flexDirection = "row",
        alignItems = "center",
        flexShrink = 0,
        overflow = "hidden",
        paddingHorizontal = 12,
        paddingVertical = 10,
        gap = 10,
        children = {
            avatarImage and UI.Panel {
                width = 36, height = 36,
                backgroundImage = avatarImage,
                backgroundFit = "cover",
                borderRadius = 0,
                flexShrink = 0,
            } or nil,
            UI.Panel {
                flexDirection = "column",
                flexShrink = 1, flexGrow = 1,
                children = {
                    UI.Label {
                        text = titleText,
                        fontSize = 14, fontColor = titleColor,
                        fontWeight = "bold",
                    },
                    UI.Panel { height = 4 },
                    UI.Label {
                        text = info.text,
                        fontSize = 12, fontColor = descColor,
                        lineHeight = 1.4,
                        whiteSpace = "normal",
                    },
                }
            },
        }
    }
end

-- ============================================================================
-- 追加信息（动画完成后调用）
-- ============================================================================

function InfoFeed.Append(info, isSkill)
    insertSeq = insertSeq + 1
    feedEntries[#feedEntries + 1] = {
        info = info,
        isSkill = isSkill,
        seq = insertSeq,
    }
    -- 同步到 UIState（供 EstimateValue 等模块查询）
    if isSkill then
        UIState.revealedSkillInfos[#UIState.revealedSkillInfos + 1] = info
    else
        UIState.revealedPublicInfos[#UIState.revealedPublicInfos + 1] = info
    end
end

-- ============================================================================
-- 入队动画（外部调用，将信息放入动画队列）
-- ============================================================================

function InfoFeed.Enqueue(info, isSkill)
    UIState.infoAnimQueue[#UIState.infoAnimQueue + 1] = { info = info, isSkill = isSkill }
end

-- ============================================================================
-- 重建信息流 UI
-- ============================================================================

function InfoFeed.Rebuild()
    local refs = UIState.refs
    if not refs.infoFeedPanel then return end

    -- 脏检测：entry 数量未变化时跳过重建，避免闪烁
    if #feedEntries == lastRebuiltCount then return end
    lastRebuiltCount = #feedEntries

    -- feedEntries 已按 seq 自然有序（Append 按调用顺序递增）
    local feedChildren = {}
    for _, entry in ipairs(feedEntries) do
        feedChildren[#feedChildren + 1] = InfoFeed.CreateInfoCard(entry.info, entry.isSkill, true)
    end

    if #feedChildren == 0 then
        feedChildren[1] = UI.Panel {
            width = "100%", height = 80,
            justifyContent = "center", alignItems = "center",
            children = {
                UI.Label { text = "等待信息揭露...", fontSize = 12, fontColor = C.textMuted }
            }
        }
    end

    refs.infoFeedPanel:ClearChildren()
    for _, child in ipairs(feedChildren) do
        refs.infoFeedPanel:AddChild(child)
    end

    if refs.infoFeedScroll and refs.infoFeedScroll.ScrollToBottom then
        refs.infoFeedScroll:ScrollToBottom()
    end
end

-- ============================================================================
-- 重置
-- ============================================================================

function InfoFeed.Reset()
    insertSeq = 0
    feedEntries = {}
    lastRebuiltCount = 0
end

-- ============================================================================
-- 查询
-- ============================================================================

function InfoFeed.GetEntryCount()
    return #feedEntries
end

return InfoFeed
