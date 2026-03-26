-- ============================================================================
-- UI/MenuScreen.lua - 主菜单屏幕
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local UIState = require("UI.UIState")
local MoneyHUD = require("UI.MoneyHUD")
local Utils = require("UI.Utils")
local LeaderboardPanel = require("UI.LeaderboardPanel")
local RewardPanel = require("UI.RewardPanel")
local DebugPanel = require("UI.DebugPanel")
local SettingsPanel = require("UI.SettingsPanel")
local VersionRewardPanel = require("UI.VersionRewardPanel")

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
                width = "12%", height = "12%",
                fontSize = 16,
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
            -- 右下角：富豪榜（竞拍上方）
            UI.Button {
                position = "absolute",
                right = "2%", bottom = "22%",
                text = "富豪榜",
                width = "12%", height = "8%",
                fontSize = 14,
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
            -- 右下角：竞拍大按钮（醒目黄绿色）
            UI.Button {
                position = "absolute",
                right = "1.5%", bottom = "6%",
                text = "竞拍 »",
                width = "16%", height = "14%",
                fontSize = 22,
                fontWeight = "bold",
                backgroundColor = { 200, 210, 0, 240 },
                fontColor = { 15, 15, 10, 255 },
                borderWidth = 0,
                borderRadius = 4,
                onClick = function()
                    Utils.PlayClick()
                    if onStartCallback then onStartCallback() end
                end,
            },
            LeaderboardPanel.Create(),
            MoneyHUD.CreatePanel(),
            UI.Panel {
                position = "absolute",
                left = 8, top = 6,
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    SettingsPanel.CreateButton(),
                    VersionRewardPanel.CreateButton(),
                    RewardPanel.CreateButton(),
                },
            },
            SettingsPanel.CreatePopup(),
            VersionRewardPanel.CreatePopup(),
            RewardPanel.CreatePopup(),
            DebugPanel.CreateHUD(),
        }
    }
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = { menuRoot },
    })
end

return MenuScreen
