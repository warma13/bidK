-- ============================================================================
-- network/Standalone.lua - 单机模式（保持原有完整游戏流程）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local Utils = require("UI.Utils")
local StartScreen = require("UI.StartScreen")
local GameController = require("UI.GameController")
local MoneyHUD = require("UI.MoneyHUD")
local RewardPanel = require("UI.RewardPanel")
local SettingsPanel = require("UI.SettingsPanel")
local VersionRewardPanel = require("UI.VersionRewardPanel")
local SaveSystem = require("SaveSystem")

local Standalone = {}

function Standalone.Start()
    graphics.windowTitle = Config.GAME.Title

    -- 初始化 UI 系统
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 全局去掉所有 UI 组件的默认圆角
    local Theme = UI.Theme
    local curTheme = Theme.GetTheme()
    local noRadius = Theme.ExtendTheme(curTheme, {
        components = {
            Button = { borderRadius = 0 },
            Panel = { borderRadius = 0 },
            TextField = { borderRadius = 0 },
            Checkbox = { borderRadius = 0 },
            ProgressBar = { borderRadius = 0 },
        },
    })
    Theme.SetTheme(noRadius)

    -- 加载音效
    Utils.LoadSounds()

    -- 加载存档并进入主菜单（可重试）
    local function loadAndEnter()
        MoneyHUD.LoadFromCloud(function()
            SaveSystem.Init(function(success, isNewPlayer)
                if not success then
                    print("[Standalone] SaveSystem load failed")
                    Utils.ShowMessage("存档加载失败，请检查网络后重试")
                    StartScreen.Show(loadAndEnter)
                    return
                end
                print("[Standalone] SaveSystem ready. New player: " .. tostring(isNewPlayer))
                SettingsPanel.Init()
                RewardPanel.Init()
                VersionRewardPanel.Init()
                GameController.ShowMenu()
            end)
        end)
    end

    -- 显示开始界面，点击后加载存档
    StartScreen.Show(loadAndEnter)

    print("=== " .. Config.GAME.Title .. " [Standalone] Started ===")
end

function Standalone.Stop()
    UI.Shutdown()
end

---@param eventType string
---@param eventData UpdateEventData
function Standalone.HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    SaveSystem.Update(dt)
    RewardPanel.Update(dt)
    GameController.HandleUpdate(dt)
end

return Standalone
