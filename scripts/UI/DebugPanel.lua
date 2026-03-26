-- ============================================================================
-- UI/DebugPanel.lua - 调试面板 + 常驻HUD（用户ID / 版本号）
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local GameState = require("GameState")
local AuctionEngine = require("AuctionEngine")
local Utils = require("UI.Utils")

local DebugPanel = {}

local VERSION = "v1.0.13"

local hudRoot = nil
local debugPanel = nil
local debugVisible = false
local moneyLabel = nil
local userIdLabel = nil

-- ============================================================================
-- 创建常驻 HUD（用户ID右上角 + 版本号左下角）
-- ============================================================================

function DebugPanel.CreateHUD()
    local myUserId = lobby and lobby:GetMyUserId() or 0
    local userId = myUserId ~= 0 and tostring(myUserId) or "Guest"

    hudRoot = UI.Panel {
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
        pointerEvents = "none",
        children = {
            -- 右上角：用户ID
            UI.Panel {
                position = "absolute",
                right = 8, top = 6,
                backgroundColor = { 0, 0, 0, 100 },
                borderRadius = 0,
                paddingHorizontal = 8, paddingVertical = 3,
                children = {
                    UI.Label {
                        id = "debugUserIdLabel",
                        text = userId,
                        fontSize = 10, fontColor = { 180, 185, 200, 180 },
                    },
                },
            },
            -- 左下角：版本号
            UI.Panel {
                position = "absolute",
                left = 8, bottom = 6,
                backgroundColor = { 0, 0, 0, 100 },
                borderRadius = 0,
                paddingHorizontal = 8, paddingVertical = 3,
                children = {
                    UI.Label {
                        text = VERSION,
                        fontSize = 10, fontColor = { 180, 185, 200, 180 },
                    },
                },
            },
        },
    }
    userIdLabel = hudRoot:FindById("debugUserIdLabel")
    return hudRoot
end

--- 刷新用户ID显示（当 lobby 延迟可用时调用）
function DebugPanel.RefreshUserId()
    local myUserId = lobby and lobby:GetMyUserId() or 0
    local userId = myUserId ~= 0 and tostring(myUserId) or "Guest"
    if userIdLabel then
        userIdLabel:SetText(userId)
    end
end

-- ============================================================================
-- 创建 F8 调试面板
-- ============================================================================

function DebugPanel.CreateDebugPanel()
    moneyLabel = UI.Label {
        text = "", fontSize = 11, fontColor = { 200, 210, 230, 255 },
    }

    debugPanel = UI.Panel {
        position = "absolute",
        left = "50%", top = "50%",
        marginLeft = -120, marginTop = -60,
        width = 240,
        backgroundColor = { 15, 18, 30, 230 },
        borderRadius = 0,
        borderWidth = 1, borderColor = { 80, 90, 120, 150 },
        padding = 12, gap = 8,
        flexDirection = "column",
        alignItems = "center",
        visible = false,
        children = {
            UI.Label {
                text = "Debug", fontSize = 14,
                fontColor = { 255, 200, 80, 255 }, fontWeight = "bold",
            },
            moneyLabel,
            UI.Button {
                text = "跳过倒计时", width = "100%", height = 32, fontSize = 12,
                onClick = function()
                    Utils.PlayClick()
                    AuctionEngine.DebugSkipTimer()
                    Utils.ShowMessage("[Debug] 倒计时已跳过")
                end,
            },
            UI.Button {
                text = "+1亿", width = "100%", height = 32, fontSize = 12,
                variant = "primary",
                onClick = function()
                    Utils.PlayClick()
                    GameState.AddMoney(1, 100000000)
                    Utils.ShowMessage("[Debug] +1亿")
                end,
            },
            UI.Button {
                text = "进入竞拍", width = "100%", height = 32, fontSize = 12,
                onClick = function()
                    Utils.PlayClick()
                    AuctionEngine.DebugEnterTiebreak()
                    Utils.ShowMessage("[Debug] 已进入实时竞拍")
                    DebugPanel.Toggle()
                end,
            },
        },
    }
    return debugPanel
end

-- ============================================================================
-- F8 切换
-- ============================================================================

function DebugPanel.Toggle()
    debugVisible = not debugVisible
    if debugPanel then
        debugPanel:SetVisible(debugVisible)
    end
end

-- ============================================================================
-- 帧更新（检测 F8 按键 + 刷新资金显示）
-- ============================================================================

function DebugPanel.HandleUpdate()
    if input:GetKeyPress(KEY_F8) then
        DebugPanel.Toggle()
    end

    if debugVisible and moneyLabel then
        local players = GameState.GetPlayers()
        if players and players[1] then
            moneyLabel:SetText("资金: " .. Utils.FormatMoney(players[1].money))
        end
    end
end

return DebugPanel
