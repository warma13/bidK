-- ============================================================================
-- UI/MenuScreen.lua - 主菜单屏幕
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local UIState = require("UI.UIState")
local MoneyHUD = require("UI.MoneyHUD")
local Utils = require("UI.Utils")
local LeaderboardPanel = require("UI.LeaderboardPanel")
local DebugPanel = require("UI.DebugPanel")
local SettingsPanel = require("UI.SettingsPanel")
local AdCardPanel = require("UI.AdCardPanel")
local OnlineRewardPanel = require("UI.OnlineRewardPanel")
local StatsPanel = require("UI.StatsPanel")
local VersionRewardPanel = require("UI.VersionRewardPanel")

local MenuScreen = {}

-- ============================================================================
-- 版本公告
-- ============================================================================
local ANNOUNCEMENTS = {
    {
        date  = "2026-05-13",
        title = "v1.3 更新公告",
        items = {
            "移除了门票入场限制，现在无需门票即可参与竞拍",
            "已有的旧门票已自动转换为高价值指定门票 ×10",
            "新增区域与仓库：深海打捞站、文化艺术区等",
            "新增品类：服饰、医疗",
        },
    },
}

local function CreateAnnouncementButton(announcementOverlay)
    local sz = Utils.sz
    local visible = false

    local btn = UI.Panel {
        height = sz(38),
        backgroundColor = { 0, 0, 0, 100 },
        borderRadius = 0,
        paddingHorizontal = sz(12),
        flexDirection = "row",
        alignItems = "center",
        gap = sz(5),
        cursor = "pointer",
        onClick = function()
            Utils.PlayClick()
            visible = not visible
            announcementOverlay:SetVisible(visible)
        end,
        children = {
            UI.Label { text = "📢", fontSize = sz(14), pointerEvents = "none" },
            UI.Label {
                text = "公告",
                fontSize = sz(13),
                fontColor = { 255, 220, 120, 230 },
                pointerEvents = "none",
            },
        },
    }
    return btn
end

local function CreateAnnouncementPopup()
    local sz = Utils.sz
    local visible = false

    -- 公告条目列表
    local itemNodes = {}
    for _, ann in ipairs(ANNOUNCEMENTS) do
        -- 标题行
        table.insert(itemNodes, UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            gap = sz(6),
            marginBottom = sz(4),
            children = {
                UI.Panel {
                    width = sz(3), height = sz(14),
                    backgroundColor = { 255, 200, 60, 255 },
                    borderRadius = sz(2), flexShrink = 0,
                },
                UI.Label {
                    text = ann.title .. "  " .. ann.date,
                    fontSize = sz(12),
                    fontColor = { 255, 220, 120, 255 },
                    fontWeight = "bold",
                },
            },
        })
        -- 条目
        for _, item in ipairs(ann.items) do
            table.insert(itemNodes, UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "flex-start",
                gap = sz(6),
                marginBottom = sz(5),
                children = {
                    UI.Label {
                        text = "•",
                        fontSize = sz(12),
                        fontColor = { 160, 200, 255, 220 },
                        marginTop = sz(1), flexShrink = 0,
                    },
                    UI.Label {
                        text = item,
                        fontSize = sz(12),
                        fontColor = { 210, 215, 230, 240 },
                        flexShrink = 1,
                    },
                },
            })
        end
    end

    ---@type any
    local overlay = nil
    overlay = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 140 },
        visible = false,
        onClick = function()
            visible = false
            overlay:SetVisible(false)
        end,
        children = {
            UI.Panel {
                onClick = function() end, -- 阻止点穿
                width = sz(340),
                backgroundColor = { 18, 22, 35, 250 },
                borderRadius = sz(8),
                borderWidth = 1,
                borderColor = { 60, 75, 120, 180 },
                overflow = "hidden",
                children = {
                    -- 标题栏
                    UI.Panel {
                        width = "100%",
                        paddingHorizontal = sz(14), paddingVertical = sz(10),
                        flexDirection = "row",
                        alignItems = "center",
                        justifyContent = "space-between",
                        backgroundColor = { 25, 30, 52, 255 },
                        borderBottomWidth = 1,
                        borderColor = { 50, 65, 110, 150 },
                        children = {
                            UI.Panel {
                                flexDirection = "row", alignItems = "center", gap = sz(6),
                                children = {
                                    UI.Label { text = "📢", fontSize = sz(15), pointerEvents = "none" },
                                    UI.Label {
                                        text = "版本公告",
                                        fontSize = sz(14),
                                        fontColor = { 230, 230, 245, 255 },
                                        fontWeight = "bold",
                                    },
                                },
                            },
                            UI.Button {
                                text = "✕",
                                width = sz(26), height = sz(26),
                                fontSize = sz(12),
                                backgroundColor = { 50, 55, 75, 200 },
                                fontColor = { 180, 185, 200, 230 },
                                borderRadius = sz(4),
                                onClick = function()
                                    Utils.PlayClick()
                                    visible = false
                                    overlay:SetVisible(false)
                                end,
                            },
                        },
                    },
                    -- 公告内容
                    UI.Panel {
                        width = "100%",
                        padding = sz(14),
                        flexDirection = "column",
                        gap = sz(0),
                        children = itemNodes,
                    },
                    -- 底部关闭按钮
                    UI.Panel {
                        width = "100%",
                        paddingBottom = sz(12), paddingTop = sz(4),
                        alignItems = "center",
                        children = {
                            UI.Button {
                                text = "知道了",
                                width = sz(90), height = sz(30),
                                fontSize = sz(12),
                                backgroundColor = { 255, 200, 60, 230 },
                                fontColor = { 20, 15, 5, 255 },
                                fontWeight = "bold",
                                borderRadius = sz(4),
                                onClick = function()
                                    Utils.PlayClick()
                                    visible = false
                                    overlay:SetVisible(false)
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
    return overlay
end

function MenuScreen.Show(onStartCallback, onWarehouseCallback)
    UIState.currentScreen = "menu"
    local C = Config.COLORS

    local announcementPopup = CreateAnnouncementPopup()
    local announcementBtn   = CreateAnnouncementButton(announcementPopup)

    local menuRoot = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 18, 18, 22, 255 },
        backgroundImage = "main_hall_bg_20260319134729.png",
        backgroundFit = "cover",
        children = {
            -- 左下角：仓库按钮
            UI.Button {
                position = "absolute",
                left = "2%", bottom = "8%",
                text = "仓库",
                width = Utils.sz(100), height = Utils.sz(50),
                fontSize = Utils.sz(16),
                backgroundColor = { 20, 22, 30, 200 },
                fontColor = { 190, 195, 210, 255 },
                borderWidth = 1,
                borderColor = { 80, 85, 100, 160 },
                borderRadius = 0,
                onClick = function()
                    Utils.PlayClick()
                    if onWarehouseCallback then onWarehouseCallback() end
                end,
            },
            -- 右下角：富豪榜 + 竞拍按钮组
            UI.Panel {
                position = "absolute",
                right = "2%", bottom = "2%",
                flexDirection = "column",
                alignItems = "flex-end",
                gap = Utils.sz(6),
                children = {
                    UI.Button {
                        text = "富豪榜",
                        width = Utils.sz(120), height = Utils.sz(36),
                        fontSize = Utils.sz(14),
                        backgroundColor = { 0, 0, 0, 100 },
                        fontColor = { 220, 200, 140, 255 },
                        borderWidth = 1,
                        borderColor = { 160, 140, 80, 120 },
                        borderRadius = 0,
                        onClick = function()
                            Utils.PlayClick()
                            LeaderboardPanel.Show()
                        end,
                    },
                    UI.Button {
                        text = "竞拍 »",
                        width = Utils.sz(140), height = Utils.sz(55),
                        fontSize = Utils.sz(20),
                        fontWeight = "bold",
                        backgroundColor = { 200, 210, 0, 240 },
                        fontColor = { 15, 15, 10, 255 },
                        borderWidth = 0,
                        borderRadius = Utils.sz(4),
                        onClick = function()
                            Utils.PlayClick()
                            if onStartCallback then onStartCallback() end
                        end,
                    },
                },
            },
            LeaderboardPanel.Create(),
            UI.Panel {
                position = "absolute",
                left = Utils.sz(8), top = Utils.sz(8),
                flexDirection = "row",
                alignItems = "center",
                gap = Utils.sz(8),
                children = {
                    SettingsPanel.CreateButton(),
                    StatsPanel.CreateButton(),
                    MoneyHUD.CreatePanel(),
                    AdCardPanel.CreateButton(),
                    OnlineRewardPanel.CreateButton(),
                    announcementBtn,
                    VersionRewardPanel.CreateButton(),
                },
            },
            SettingsPanel.CreatePopup(),
            StatsPanel.CreatePopup(),
            MoneyHUD.CreatePopup(),
            AdCardPanel.CreatePopup(),
            OnlineRewardPanel.CreatePopup(),
            announcementPopup,
            VersionRewardPanel.CreatePopup(),
        }
    }
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = { menuRoot, DebugPanel.CreateHUD() },
    })
end

return MenuScreen
