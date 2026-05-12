-- ============================================================================
-- UI/StartScreen.lua - 开始界面（游戏启动首屏）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")

local StartScreen = {}

--- 显示开始界面
---@param onStartCallback fun() 点击"开始游戏"后的回调
function StartScreen.Show(onStartCallback)
    ---@type Widget|nil
    local btn = nil

    local root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 18, 18, 22, 255 },
        backgroundImage = "main_hall_bg_20260319134729.png",
        backgroundFit = "cover",
        justifyContent = "center",
        alignItems = "center",
        children = {
            -- 游戏标题
            UI.Label {
                text = "拍卖之王",
                fontSize = 42,
                fontWeight = "bold",
                fontColor = { 255, 220, 120, 255 },
                marginBottom = 60,
            },
            -- 开始游戏按钮
            (function()
                btn = UI.Button {
                    text = "开始游戏",
                    width = 200, height = 50,
                    fontSize = 20,
                    fontWeight = "bold",
                    backgroundColor = { 200, 210, 0, 240 },
                    fontColor = { 15, 15, 10, 255 },
                    borderWidth = 0,
                    borderRadius = 4,
                    onClick = function()
                        Utils.PlayClick()
                        btn:SetDisabled(true)
                        btn:SetText("加载中...")
                        if onStartCallback then onStartCallback() end
                    end,
                }
                return btn
            end)(),
        },
    }
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = { root },
    })
end

return StartScreen
