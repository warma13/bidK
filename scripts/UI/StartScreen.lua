-- ============================================================================
-- UI/StartScreen.lua - 开始界面（游戏启动首屏）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")

local StartScreen = {}

---@type Widget|nil  主按钮（"开始游戏" / "加载中..."）
local btn_        = nil
---@type Widget|nil  等待提示文字（"已等待 Xs，请稍候..."）
local waitLabel_  = nil
---@type Widget|nil  重试按钮（超时后显示）
local retryBtn_   = nil

--- 显示开始界面
---@param onStartCallback fun() 点击"开始游戏"后的回调
---@param buttonText? string 按钮文案，默认"开始游戏"
function StartScreen.Show(onStartCallback, buttonText)
    btn_       = nil
    waitLabel_ = nil
    retryBtn_  = nil

    local root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 18, 18, 22, 255 },
        backgroundImage = "main_hall_bg_20260319134729.jpg",
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
                btn_ = UI.Button {
                    text = buttonText or "开始游戏",
                    width = 200, height = 50,
                    fontSize = 20,
                    fontWeight = "bold",
                    backgroundColor = { 200, 210, 0, 240 },
                    fontColor = { 15, 15, 10, 255 },
                    borderWidth = 0,
                    borderRadius = 4,
                    onClick = function()
                        Utils.PlayClick()
                        btn_:SetDisabled(true)
                        btn_:SetText("加载中...")
                        if onStartCallback then onStartCallback() end
                    end,
                }
                return btn_
            end)(),
            -- 等待时间提示（初始隐藏）
            (function()
                waitLabel_ = UI.Label {
                    text = "",
                    fontSize = 13,
                    fontColor = { 180, 180, 180, 220 },
                    marginTop = 12,
                    visible = false,
                }
                return waitLabel_
            end)(),
            -- 手动重试按钮（超时后显示）
            (function()
                retryBtn_ = UI.Button {
                    text = "重新连接",
                    width = 160, height = 40,
                    fontSize = 16,
                    fontWeight = "bold",
                    backgroundColor = { 80, 120, 200, 220 },
                    fontColor = { 255, 255, 255, 255 },
                    borderWidth = 0,
                    borderRadius = 4,
                    marginTop = 8,
                    visible = false,
                    onClick = function()
                        Utils.PlayClick()
                        if StartScreen.onRetryCallback_ then
                            StartScreen.onRetryCallback_()
                        end
                    end,
                }
                return retryBtn_
            end)(),
        },
    }
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = { root },
    })
end

--- 更新等待时间文案（在加载中状态下显示已等待秒数）
---@param seconds number 已等待秒数
function StartScreen.SetWaitSeconds(seconds)
    if not waitLabel_ then return end
    local s = math.floor(seconds)
    waitLabel_:SetText("已等待 " .. s .. " 秒，正在连接服务器...")
    waitLabel_:SetVisible(true)
end

--- 显示重试按钮，并注册重试回调
---@param onRetry fun() 点击"重新连接"后的回调
function StartScreen.ShowRetryButton(onRetry)
    StartScreen.onRetryCallback_ = onRetry
    if retryBtn_ then
        retryBtn_:SetVisible(true)
    end
    if waitLabel_ then
        waitLabel_:SetText("连接超时，请检查网络")
    end
end

--- 隐藏等待提示和重试按钮（数据加载完毕后调用）
function StartScreen.HideWaiting()
    if waitLabel_ then waitLabel_:SetVisible(false) end
    if retryBtn_  then retryBtn_:SetVisible(false)  end
    StartScreen.onRetryCallback_ = nil
end

return StartScreen
