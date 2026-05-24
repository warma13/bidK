-- ============================================================================
-- UI/RewardScreen.lua - 奖励中心（全屏分页）
-- 包含：广告卡 / 在线奖励 / 版本奖励（含公告）
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")
local AdCardPanel = require("UI.AdCardPanel")
local OnlineRewardPanel = require("UI.OnlineRewardPanel")
local VersionRewardPanel = require("UI.VersionRewardPanel")
local TicketTooltip = require("UI.TicketTooltip")

local RewardScreen = {}

-- 当前活跃的返回函数（Show 时赋值，供外部 ESC 调用）
local goBackFn = nil

-- ============================================================================
-- Tab 定义
-- ============================================================================
local TABS = {
    {
        id    = "adcard",
        label = "广告卡",
        icon  = "image/ad_card_icon_20260519095522.png",
        build = function() return AdCardPanel.CreateContent() end,
        onShow = function()
            AdCardPanel.RefreshAll()
        end,
        onHide = function()
            -- 广告卡隐藏时重置 watching 状态保护已由 AdCardPanel.Update 处理
        end,
    },
    {
        id    = "online",
        label = "在线奖励",
        icon  = "image/online_reward_icon_20260519095303.png",
        build = function() return OnlineRewardPanel.CreateContent() end,
        onShow = function()
            OnlineRewardPanel._contentActive = true
            OnlineRewardPanel.RefreshAll()
        end,
        onHide = function()
            OnlineRewardPanel._contentActive = false
        end,
    },
    {
        id    = "version",
        label = "版本奖励",
        icon  = "image/version_reward_icon_20260519095237.png",
        build = function() return VersionRewardPanel.CreateContent() end,
        onShow = function()
            VersionRewardPanel.RefreshAll()
        end,
        onHide = function() end,
    },
}

-- ============================================================================
-- Show
-- ============================================================================

function RewardScreen.Show(onBackCallback)
    local sz = Utils.sz

    -- 注册返回函数供 ESC 快捷键调用
    goBackFn = function()
        Utils.PlayClick()
        for _, t in ipairs(TABS) do
            if t.id == activeTabId and t.onHide then t.onHide() end
        end
        goBackFn = nil
        if onBackCallback then onBackCallback() end
    end

    local activeTabId = TABS[1].id

    -- 侧边栏引用（{ panel, bar, lbl }）
    local sidebarRefs = {}

    -- 内容容器（动态替换子节点）
    ---@type any
    local contentContainer = nil
    -- 当前内容面板
    ---@type any
    local currentContent = nil

    local function SwitchTab(tabId)
        if activeTabId == tabId and currentContent then return end

        -- 通知旧 tab 隐藏
        for _, t in ipairs(TABS) do
            if t.id == activeTabId and t.onHide then t.onHide() end
        end

        activeTabId = tabId

        -- 重建内容面板
        local newContent = nil
        for _, t in ipairs(TABS) do
            if t.id == tabId then
                newContent = t.build()
                break
            end
        end

        if contentContainer and newContent then
            if currentContent then
                contentContainer:RemoveChild(currentContent)
            end
            contentContainer:AddChild(newContent)
            currentContent = newContent
        end

        -- 通知新 tab 显示
        for _, t in ipairs(TABS) do
            if t.id == tabId and t.onShow then t.onShow() end
        end

        -- 更新侧边栏高亮
        for _, ref in ipairs(sidebarRefs) do
            local isActive = (ref.tabId == tabId)
            ref.panel:SetStyle({
                backgroundColor = isActive and { 200, 230, 0, 255 } or { 60, 62, 70, 180 },
            })
            ref.bar:SetStyle({
                backgroundColor = isActive and { 255, 255, 255, 255 } or { 0, 0, 0, 0 },
            })
            ref.lbl:SetStyle({
                fontColor = isActive and { 10, 10, 10, 255 } or { 180, 180, 185, 220 },
            })
        end
    end

    -- ── 侧边栏 ──────────────────────────────────────────────────
    local sidebarItems = {}
    for i, tab in ipairs(TABS) do
        local isActive = (tab.id == activeTabId)

        local barWidget = UI.Panel {
            width = sz(4), flexShrink = 0,
            backgroundColor = isActive and { 255, 255, 255, 255 } or { 0, 0, 0, 0 },
        }
        local lblWidget = UI.Label {
            text = tab.label,
            fontSize = sz(13), fontWeight = "bold",
            fontColor = isActive and { 10, 10, 10, 255 } or { 180, 180, 185, 220 },
        }

        -- 红点（广告卡 / 在线奖励 / 版本奖励 均可能有红点）
        local badgeWidget = UI.Panel {
            position = "absolute",
            right = sz(6), top = sz(6),
            width = sz(8), height = sz(8),
            borderRadius = sz(4),
            backgroundColor = { 255, 60, 60, 255 },
            visible = false,
            pointerEvents = "none",
        }

        local tabId = tab.id  -- capture
        local itemPanel = UI.Panel {
            width = "100%",
            flexDirection = "row", alignItems = "stretch",
            borderRadius = sz(4), overflow = "visible",
            backgroundColor = isActive and { 200, 230, 0, 255 } or { 60, 62, 70, 180 },
            cursor = "pointer",
            onClick = function()
                Utils.PlayClick()
                SwitchTab(tabId)
            end,
            children = {
                barWidget,
                UI.Panel {
                    flexGrow = 1,
                    paddingVertical = sz(12), paddingLeft = sz(10), paddingRight = sz(8),
                    flexDirection = "row", alignItems = "center", gap = sz(8),
                    children = {
                        lblWidget,
                    },
                },
                badgeWidget,
            },
        }

        sidebarRefs[i] = { tabId = tabId, panel = itemPanel, bar = barWidget, lbl = lblWidget, badge = badgeWidget }
        sidebarItems[i] = itemPanel
    end

    local sidebar = UI.Panel {
        width = sz(130), height = "100%",
        flexDirection = "column",
        borderRightWidth = 1,
        borderColor = { 50, 60, 90, 180 },
        paddingTop = sz(8), paddingBottom = sz(8),
        paddingHorizontal = sz(6),
        gap = sz(4),
        children = (function()
            local ch = {}
            for _, w in ipairs(sidebarItems) do ch[#ch + 1] = w end
            ch[#ch + 1] = UI.Panel { flexGrow = 1 }
            ch[#ch + 1] = UI.Panel {
                width = "100%",
                paddingHorizontal = sz(8), paddingVertical = sz(6),
                children = {
                    UI.Button {
                        text = "返回",
                        width = "100%", paddingVertical = sz(7),
                        fontSize = sz(13), fontWeight = "bold",
                        fontColor = { 195, 215, 40, 230 },
                        backgroundColor = { 195, 215, 40, 20 },
                        borderWidth = 1, borderColor = { 195, 215, 40, 160 },
                        borderRadius = 0,
                        onClick = function()
                            Utils.PlayClick()
                            -- 离开时通知当前 tab
                            for _, t in ipairs(TABS) do
                                if t.id == activeTabId and t.onHide then t.onHide() end
                            end
                            if onBackCallback then onBackCallback() end
                        end,
                    },
                },
            }
            return ch
        end)(),
    }

    -- ── 内容区域 ─────────────────────────────────────────────────
    contentContainer = UI.Panel {
        flex = 1, flexShrink = 1, height = "100%",
        flexDirection = "column",
        padding = sz(16),
        overflow = "hidden",
    }

    -- ── 顶部标题栏 ───────────────────────────────────────────────
    local topBar = UI.Panel {
        width = "100%", flexShrink = 0,
        height = sz(44),
        flexDirection = "row", alignItems = "center",
        paddingHorizontal = sz(16),
        borderBottomWidth = 1, borderColor = { 50, 60, 90, 180 },
        children = {
            UI.Panel {
                width = sz(20), height = sz(20), flexShrink = 0,
                backgroundImage = "image/reward_center_icon_20260519095246.png",
                backgroundFit = "contain",
                pointerEvents = "none",
            },
            UI.Panel { width = sz(8) },
            UI.Label {
                text = "奖励中心",
                fontSize = sz(15), fontWeight = "bold",
                fontColor = { 240, 235, 220, 255 },
            },
            UI.Panel { flexGrow = 1 },
            UI.Panel {
                width = sz(32), height = sz(32), flexShrink = 0,
                borderRadius = sz(4),
                backgroundColor = { 40, 42, 55, 200 },
                borderWidth = 1, borderColor = { 70, 75, 90, 180 },
                alignItems = "center", justifyContent = "center",
                cursor = "pointer",
                onClick = function()
                    Utils.PlayClick()
                    for _, t in ipairs(TABS) do
                        if t.id == activeTabId and t.onHide then t.onHide() end
                    end
                    if onBackCallback then onBackCallback() end
                end,
                children = {
                    UI.Label {
                        text = "✕", fontSize = sz(18), fontWeight = "bold",
                        fontColor = { 180, 220, 0, 230 },
                    },
                },
            },
        },
    }

    -- ── 主体（侧边栏 + 内容）────────────────────────────────────
    local body = UI.Panel {
        width = "100%", flex = 1, flexShrink = 1,
        flexDirection = "row",
        children = { sidebar, contentContainer },
    }

    -- ── 根节点 ───────────────────────────────────────────────────
    local screenRoot = UI.Panel {
        width = "100%", height = "100%",
        flexDirection = "column",
        overflow = "hidden",
        children = {
            topBar,
            body,
            TicketTooltip.CreateOverlay(),
        },
    }
    TicketTooltip.SetRoot(screenRoot)

    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        backgroundImage = "image/reward_center_bg_20260519073207.jpg",
        backgroundFit = "cover",
        children = {
            -- 毛玻璃遮罩（全屏覆盖）
            UI.Panel {
                position = "absolute", left = 0, top = 0, right = 0, bottom = 0,
                backgroundImage = "image/frosted_glass_overlay_20260517184616.jpg",
                backgroundFit = "cover",
                opacity = 0.35,
                pointerEvents = "none",
            },
            UI.SafeAreaView {
                edges = "all", width = "100%", height = "100%",
                children = { screenRoot },
            },
        },
    })

    -- 初始展示第一个 Tab
    SwitchTab(TABS[1].id)
end

function RewardScreen.IsOpen()
    return goBackFn ~= nil
end

function RewardScreen.GoBack()
    if goBackFn then goBackFn() end
end

return RewardScreen
