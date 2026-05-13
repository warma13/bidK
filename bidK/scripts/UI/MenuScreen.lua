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

local MenuScreen = {}

function MenuScreen.Show(onStartCallback, onWarehouseCallback)
    UIState.currentScreen = "menu"
    local C = Config.COLORS

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
                    MoneyHUD.CreatePanel(),
                    AdCardPanel.CreateButton(),
                    OnlineRewardPanel.CreateButton(),
                },
            },
            SettingsPanel.CreatePopup(),
            MoneyHUD.CreatePopup(),
            AdCardPanel.CreatePopup(),
            OnlineRewardPanel.CreatePopup(),
            DebugPanel.CreateHUD(),
        }
    }
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = { menuRoot },
    })
end

return MenuScreen
