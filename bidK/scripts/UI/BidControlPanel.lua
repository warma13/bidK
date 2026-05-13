-- ============================================================================
-- UI/BidControlPanel.lua - 底部出价控制面板（键盘 + 工具栏）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local AuctionEngine = require("AuctionEngine")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local PlayerListPanel = require("UI.PlayerListPanel")
local AIPlayer = require("AIPlayer")

local BidControlPanel = {}

local refs = UIState.refs
local C = Config.COLORS

local GS = GameState

-- 极简风格色板
local KB = {
    bg      = { 18, 20, 28, 250 },
    btn     = { 42, 46, 58, 255 },
    btnHov  = { 58, 62, 76, 255 },
    accent  = { 60, 170, 130, 255 },
    accentH = { 75, 195, 150, 255 },
    txtW    = { 230, 235, 245, 255 },
    txtDim  = { 150, 155, 170, 255 },
    gap     = 2,
    radius  = 0,
}

-- ============================================================================
-- 出价交互逻辑
-- ============================================================================

local function GetCurrentMultiplier()
    local round = GS.GetCurrentRound()
    return Config.GAME.Multipliers[round] or 1.0
end

local function RefreshBidDisplay()
    UIState.playerBidAmount = tonumber(UIState.bidInputStr) or 0
    if UIState.playerBidAmount > 0 then
        refs.bidAmountLabel:SetText(Utils.FormatMoney(UIState.playerBidAmount))
    else
        refs.bidAmountLabel:SetText("0")
    end
end

local function ApplyMultiplier()
    local current = tonumber(UIState.bidInputStr) or 0
    if current <= 0 then return end
    local mult = GetCurrentMultiplier()
    local result = math.floor(current * mult)
    local mySlot = 1
    local player = GS.GetPlayers()[mySlot]
    if player and result > player.money then
        result = player.money
    end
    UIState.bidInputStr = tostring(result)
    RefreshBidDisplay()
end

local function AppendBidDigit(digit)
    if UIState.playerBidConfirmed then
        UIState.playerBidConfirmed = false
    end
    UIState.bidInputStr = UIState.bidInputStr .. digit
    if #UIState.bidInputStr > 9 then
        UIState.bidInputStr = UIState.bidInputStr:sub(1, 9)
    end
    local mySlot = 1
    local player = GS.GetPlayers()[mySlot]
    local amount = tonumber(UIState.bidInputStr) or 0
    if player and amount > player.money then
        UIState.bidInputStr = tostring(player.money)
    end
    RefreshBidDisplay()
end

local function BidBackspace()
    if #UIState.bidInputStr > 0 then
        UIState.bidInputStr = UIState.bidInputStr:sub(1, -2)
    end
    RefreshBidDisplay()
end

local function BidReset()
    UIState.bidInputStr = ""
    UIState.playerBidAmount = 0
    refs.bidAmountLabel:SetText("0")
end

local function ToggleBidPanel()
    local phase = GS.GetPhase()
    if phase == GS.PHASE.GAME_OVER then
        -- 由 GameController 处理结算弹窗
        if BidControlPanel._onGameOverClick then
            BidControlPanel._onGameOverClick()
        end
        return
    end
    if phase ~= GS.PHASE.SEALED_BID then
        return
    end
    -- 已确认出价/弃权后不允许再打开
    if UIState.playerBidConfirmed then return end
    UIState.bidPanelVisible = not UIState.bidPanelVisible
    if refs.bidPanel then
        refs.bidPanel:SetVisible(UIState.bidPanelVisible)
    end

end

local function OnForfeitClicked()
    local phase = GS.GetPhase()
    if phase == GS.PHASE.SEALED_BID then
        UIState.playerBidAmount = 0
        UIState.bidInputStr = ""
        AuctionEngine.PlayerSealedBid(0)
        AIPlayer.OnPlayerBidConfirmed()
        UIState.playerBidConfirmed = true
        Utils.PlaySfx("bid_place")
        -- 弃权不弹 toast
        UIState.bidPanelVisible = false
        if refs.bidPanel then
            refs.bidPanel:SetVisible(false)
        end
        BidControlPanel.Update()
        PlayerListPanel.Update()
    end
end

local bidConfirmModal_ = nil

local function CloseBidConfirmModal()
    if bidConfirmModal_ then
        pcall(function() bidConfirmModal_:Close() end)
        bidConfirmModal_ = nil
    end
end

local function SubmitSealedBid(amount)
    local ok = AuctionEngine.PlayerSealedBid(amount)
    if not ok then
        -- 阶段已切换（如倒计时耗尽），出价失败
        Utils.ShowMessage("出价超时，本轮已结束")
        return
    end
    AIPlayer.OnPlayerBidConfirmed()
    UIState.playerBidConfirmed = true
    Utils.PlaySfx("bid_place")
    UIState.bidPanelVisible = false
    if refs.bidPanel then refs.bidPanel:SetVisible(false) end
    BidControlPanel.Update()
    PlayerListPanel.Update()
end

local function OnBidButtonClicked()
    local phase = GS.GetPhase()

    if phase == GS.PHASE.SEALED_BID then
        if UIState.playerBidAmount > 0 then
            local amount = UIState.playerBidAmount
            local round = GS.GetCurrentRound()

            -- 检查是否需要弹窗确认
            local confirmReason = nil

            -- 条件1：超过上轮出价的两倍
            if round > 1 then
                local roundBids = GS.GetRoundBids()
                local mySlot = 1
                local prevBid = roundBids[round - 1] and roundBids[round - 1][mySlot]
                if prevBid and prevBid > 0 and amount > prevBid * 2 then
                    confirmReason = "本次出价 " .. Utils.FormatMoney(amount)
                        .. " 超过上轮出价的两倍，确认出价吗？"
                end
            end

            -- 条件2：超过场次期望值的两倍
            if not confirmReason then
                local expectedValue = GS.GetExpectedValue()
                if amount > expectedValue * 2 then
                    confirmReason = "本次出价 " .. Utils.FormatMoney(amount)
                        .. " 超过仓库期望价值（" .. Utils.FormatMoney(expectedValue) .. "）的两倍，确认出价吗？"
                end
            end

            if confirmReason then
                -- 弹窗确认（先清理残留弹窗）
                CloseBidConfirmModal()
                bidConfirmModal_ = UI.Modal {
                    title = "出价提醒",
                    size = "sm",
                    children = {
                        UI.Label {
                            text = confirmReason,
                            fontSize = 14,
                        },
                    },
                }
                local footer = UI.Panel {
                    flexDirection = "row",
                    justifyContent = "flex-end",
                    gap = 10,
                    width = "100%",
                }
                footer:AddChild(UI.Button {
                    text = "取消",
                    variant = "secondary",
                    onClick = function()
                        Utils.PlayClick()
                        CloseBidConfirmModal()
                    end,
                })
                footer:AddChild(UI.Button {
                    text = "确认出价",
                    variant = "primary",
                    onClick = function()
                        Utils.PlayClick()
                        CloseBidConfirmModal()
                        SubmitSealedBid(amount)
                    end,
                })
                bidConfirmModal_:SetFooter(footer)
                bidConfirmModal_:Open()
            else
                SubmitSealedBid(amount)
            end
        else
            Utils.ShowMessage("请输入出价金额")
        end

    elseif phase == GS.PHASE.GAME_OVER then
        if BidControlPanel._onGameOverClick then
            BidControlPanel._onGameOverClick()
        end
    end
end

-- 外部注册结算弹窗回调
BidControlPanel._onGameOverClick = nil
function BidControlPanel.SetOnGameOverClick(fn)
    BidControlPanel._onGameOverClick = fn
end



-- ============================================================================
-- 创建
-- ============================================================================

function BidControlPanel.Create()
    -- 隐藏标签（逻辑兼容）
    refs.timerLabel = UI.Label { text = "", fontSize = 1, visible = false }
    refs.bidStatusLabel = UI.Label { text = "", fontSize = 1, visible = false }
    refs.bidHintLabel = UI.Label { text = "", fontSize = 1, visible = false }

    -- 键盘区×倍率数值标签
    refs.bidMultiplierValueLabel = UI.Label {
        text = "×1.0", fontSize = 12, fontColor = { 255, 255, 255, 255 }, fontWeight = "bold",
    }

    -- 金额显示
    refs.bidAmountLabel = UI.Label {
        text = "0", fontSize = 22, fontColor = C.accent, textAlign = "right", fontWeight = "bold",
    }

    -- 确认按钮
    refs.bidButton = UI.Button {
        text = "确认出价",
        width = "100%", height = 36, fontSize = 13,
        onClick = function() OnBidButtonClicked() end,
    }

    -- 倍率提示
    refs.bidMultiplierLabel = UI.Label {
        text = "", fontSize = 11, fontColor = KB.txtDim, lineHeight = 1.4,
    }

    -- 数字键按钮生成
    local function keyBtn(label, w, onPress)
        return UI.Button {
            text = label, width = w or 52, height = 42, fontSize = 15,
            backgroundColor = KB.btn,
            borderRadius = KB.radius,
            textColor = KB.txtW,
            hoverBackgroundColor = KB.btnHov,
            pressedBackgroundColor = { 80, 85, 100, 255 },
            onClick = function() Utils.PlayClick() onPress() end,
        }
    end

    -- 出价弹出面板（由 GameController 提升到根级别，定位相对于全屏 uiRoot）
    -- paddingVertical="6%" 在 Yoga 中基于宽度解析（同 CSS）
    local bidBottom = math.floor(UI.GetWidth() * 0.06 + 50)
    refs.bidPanel = UI.Panel {
        id = "bidPanel",
        position = "absolute",
        bottom = bidBottom,
        left = "24%",
        width = 420,
        backgroundColor = KB.bg,
        borderRadius = 0,
        padding = 6, gap = 8,
        flexDirection = "row",
        visible = false,
        children = {
            -- 左栏：键盘区
            UI.Panel {
                flexDirection = "row", gap = KB.gap,
                children = {
                    -- 4×3 数字键盘
                    UI.Panel {
                        flexDirection = "column", gap = KB.gap,
                        children = {
                            UI.Panel { flexDirection = "row", gap = KB.gap, children = {
                                keyBtn("1", 52, function() AppendBidDigit("1") end),
                                keyBtn("2", 52, function() AppendBidDigit("2") end),
                                keyBtn("3", 52, function() AppendBidDigit("3") end),
                            }},
                            UI.Panel { flexDirection = "row", gap = KB.gap, children = {
                                keyBtn("4", 52, function() AppendBidDigit("4") end),
                                keyBtn("5", 52, function() AppendBidDigit("5") end),
                                keyBtn("6", 52, function() AppendBidDigit("6") end),
                            }},
                            UI.Panel { flexDirection = "row", gap = KB.gap, children = {
                                keyBtn("7", 52, function() AppendBidDigit("7") end),
                                keyBtn("8", 52, function() AppendBidDigit("8") end),
                                keyBtn("9", 52, function() AppendBidDigit("9") end),
                            }},
                            UI.Panel { flexDirection = "row", gap = KB.gap, children = {
                                keyBtn("0", 52, function() AppendBidDigit("0") end),
                                keyBtn("00", 52, function() AppendBidDigit("00") end),
                                keyBtn("000", 52, function() AppendBidDigit("000") end),
                            }},
                        }
                    },
                    -- 3个竖向按钮
                    UI.Panel {
                        flexDirection = "column", gap = KB.gap,
                        width = 56,
                        children = {
                            -- 退格按钮
                            UI.Panel {
                                width = 56, flexGrow = 1,
                                backgroundImage = "backspace_icon_20260318061717.png",
                                backgroundFit = "contain",
                                backgroundColor = KB.btn,
                                borderRadius = KB.radius,
                                justifyContent = "center", alignItems = "center",
                                cursor = "pointer",
                                hoverStyle = { backgroundColor = KB.btnHov },
                                onClick = function() Utils.PlayClick() BidBackspace() end,
                                onPointerDown = function(_, w) w:SetStyle({ backgroundColor = { 80, 85, 100, 255 } }) end,
                                onPointerUp = function(_, w) w:SetStyle({ backgroundColor = KB.btn }) end,
                                onPointerLeave = function(_, w) w:SetStyle({ backgroundColor = KB.btn }) end,
                            },
                            -- ×倍率按钮
                            UI.Panel {
                                width = 56, flexGrow = 2,
                                backgroundColor = KB.accent,
                                borderRadius = KB.radius,
                                justifyContent = "center", alignItems = "center",
                                cursor = "pointer",
                                hoverStyle = { backgroundColor = KB.accentH },
                                onClick = function() Utils.PlayClick() ApplyMultiplier() end,
                                onPointerDown = function(_, w) w:SetStyle({ backgroundColor = { 95, 215, 170, 255 } }) end,
                                onPointerUp = function(_, w) w:SetStyle({ backgroundColor = KB.accent }) end,
                                onPointerLeave = function(_, w) w:SetStyle({ backgroundColor = KB.accent }) end,
                                children = { refs.bidMultiplierValueLabel },
                            },
                            -- 清空按钮
                            UI.Panel {
                                width = 56, flexGrow = 1,
                                backgroundColor = KB.btn,
                                borderRadius = KB.radius,
                                justifyContent = "center", alignItems = "center",
                                cursor = "pointer",
                                hoverStyle = { backgroundColor = KB.btnHov },
                                onClick = function() Utils.PlayClick() BidReset() end,
                                onPointerDown = function(_, w) w:SetStyle({ backgroundColor = { 80, 85, 100, 255 } }) end,
                                onPointerUp = function(_, w) w:SetStyle({ backgroundColor = KB.btn }) end,
                                onPointerLeave = function(_, w) w:SetStyle({ backgroundColor = KB.btn }) end,
                                children = {
                                    UI.Label { text = "清空", fontSize = 12, fontColor = KB.txtDim },
                                }
                            },
                        }
                    },
                }
            },
            -- 右栏：信息 + 金额 + 确认
            UI.Panel {
                flexDirection = "column", gap = 6,
                flexGrow = 1, flexShrink = 1,
                justifyContent = "space-between",
                children = {
                    refs.bidMultiplierLabel,
                    UI.Panel {
                        width = "100%",
                        backgroundColor = { 10, 12, 20, 255 },
                        borderRadius = KB.radius, borderWidth = 1,
                        borderColor = { 80, 90, 110, 180 },
                        padding = { 8, 10 },
                        justifyContent = "center", alignItems = "flex-end",
                        children = { refs.bidAmountLabel },
                    },
                    refs.bidButton,
                }
            },
        }
    }

    -- 底部工具栏按钮
    refs.toolbarBidBtn = UI.Button {
        text = "出价", width = 120, height = 42, fontSize = 14,
        variant = "primary",
        onClick = function() Utils.PlayClick() ToggleBidPanel() end,
    }

    refs.toolbarForfeitBtn = UI.Button {
        text = "弃权", width = 80, height = 42, fontSize = 13,
        onClick = function() OnForfeitClicked() end,
    }

    -- bidPanel 不再放在这里，由 GameController 提升到根级别以解决 z-index 层级问题
    return UI.Panel {
        id = "bidControlArea",
        width = "100%",
        flexShrink = 0,
        flexDirection = "column",
        children = {
            -- 底部工具栏（marginTop=auto 推到底部，与战利品仓库底部对齐）
            UI.Panel {
                id = "bottomToolbar",
                width = "100%", height = 50,
                backgroundColor = C.bgPanel,
                borderRadius = 0,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                paddingHorizontal = 12,
                gap = 12,
                children = {
                    refs.toolbarBidBtn,
                    refs.toolbarForfeitBtn,
                }
            },
        }
    }
end

-- ============================================================================
-- 更新
-- ============================================================================

function BidControlPanel.Update()
    local phase = GS.GetPhase()
    local timer = GS.GetTimer()
    local isBidPhase = (phase == GS.PHASE.SEALED_BID or phase == GS.PHASE.TIEBREAK_BID)

    -- 倒计时
    if isBidPhase then
        local timeStr = tostring(math.ceil(timer))
        local timeColor = timer <= 5 and C.danger or C.accent
        refs.timerLabel:SetText(timeStr)
        refs.timerLabel:SetStyle({ fontColor = timeColor })
        refs.roundTimerLabel:SetText(timeStr)
        refs.roundTimerLabel:SetStyle({ fontColor = timeColor })
    else
        refs.timerLabel:SetText("--")
        refs.timerLabel:SetStyle({ fontColor = C.textMuted })
        refs.roundTimerLabel:SetText("")
    end

    -- 更新键盘区倍率显示
    local currentMult = GetCurrentMultiplier()
    refs.bidMultiplierValueLabel:SetText("×" .. currentMult)

    -- 工具栏按钮状态（默认恢复可见）
    refs.toolbarBidBtn:SetVisible(true)
    refs.toolbarForfeitBtn:SetVisible(true)

    -- 阶段离开 SEALED_BID 时，清理残留的确认弹窗
    if phase ~= GS.PHASE.SEALED_BID then
        CloseBidConfirmModal()
    end

    if phase == GS.PHASE.SEALED_BID then
        if UIState.playerBidConfirmed then
            -- 已确认出价或弃权，锁死所有操作
            if UIState.playerBidAmount > 0 then
                refs.toolbarBidBtn:SetText(Utils.FormatMoney(UIState.playerBidAmount))
            else
                refs.toolbarBidBtn:SetText("已弃权")
            end
            refs.toolbarBidBtn:SetDisabled(true)
            refs.toolbarForfeitBtn:SetDisabled(true)
            refs.bidButton:SetDisabled(true)
            refs.bidButton:SetText("已锁定")
        else
            refs.toolbarBidBtn:SetText("出价")
            refs.toolbarBidBtn:SetDisabled(false)
            refs.toolbarForfeitBtn:SetDisabled(false)
            refs.bidButton:SetText("确认出价")
            refs.bidButton:SetDisabled(false)
        end
        RefreshBidDisplay()

        local round = GS.GetCurrentRound()
        local mult = Config.GAME.Multipliers[round] or 1.0
        if round < 5 then
            refs.bidMultiplierLabel:SetText("胜出: 最高价 >= 第2名 x" .. mult)
        else
            refs.bidMultiplierLabel:SetText("最终轮: 最高价胜出")
        end

    elseif phase == GS.PHASE.TIEBREAK_BID then
        -- 竞拍阶段由 TiebreakPanel 全屏处理，底部工具栏保持默认
        refs.toolbarBidBtn:SetText("竞拍中")
        refs.toolbarBidBtn:SetDisabled(true)
        refs.toolbarForfeitBtn:SetDisabled(true)
        if UIState.bidPanelVisible then
            UIState.bidPanelVisible = false
            if refs.bidPanel then refs.bidPanel:SetVisible(false) end
        end

    elseif phase == GS.PHASE.GAME_OVER then
        refs.toolbarBidBtn:SetText("结算")
        refs.toolbarBidBtn:SetDisabled(false)
        refs.toolbarForfeitBtn:SetDisabled(true)
        if UIState.bidPanelVisible then
            UIState.bidPanelVisible = false
            if refs.bidPanel then refs.bidPanel:SetVisible(false) end
        end

    else
        refs.toolbarBidBtn:SetText("出价")
        refs.toolbarBidBtn:SetDisabled(true)
        refs.toolbarForfeitBtn:SetDisabled(true)
        refs.bidMultiplierLabel:SetText("")
        if UIState.bidPanelVisible then
            UIState.bidPanelVisible = false
            if refs.bidPanel then refs.bidPanel:SetVisible(false) end
        end
    end
end

return BidControlPanel
