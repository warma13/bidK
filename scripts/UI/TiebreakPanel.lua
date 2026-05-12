-- ============================================================================
-- UI/TiebreakPanel.lua - 实时竞拍全屏弹窗
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local AuctionEngine = require("AuctionEngine")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")

local TiebreakPanel = {}

local C = Config.COLORS
local refs = UIState.refs

local GS = GameState

-- 外部注册返回回调
TiebreakPanel._onBackClick = nil
function TiebreakPanel.SetOnBackClick(fn)
    TiebreakPanel._onBackClick = fn
end

-- 内部状态
local panel = nil
local timerLabel = nil
local highBidLabel = nil
local bidderNameLabel = nil
local bidderAvatarIcon = nil
local backBtn = nil
local confirmModal = nil
local bidConfirmModal_ = nil
local bidButtons = {}
local isVisible = false


-- ============================================================================
-- 创建
-- ============================================================================

function TiebreakPanel.Create()
    -- 倒计时
    timerLabel = UI.Label {
        text = "8", fontSize = 36,
        fontColor = { 255, 255, 255, 255 },
        fontWeight = "bold",
    }

    -- 最高价
    highBidLabel = UI.Label {
        text = "0", fontSize = 36,
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
    }

    -- 最高出价人头像
    bidderAvatarIcon = UI.Panel {
        width = 48, height = 52,
        backgroundColor = { 50, 55, 80, 200 },
        borderRadius = 0,
        justifyContent = "center", alignItems = "center",
        children = {
            (function()
                local icon = UI.Panel {
                    width = 36, height = 36,
                    backgroundImage = "",
                    backgroundFit = "cover",
                    borderRadius = 0,
                }
                refs.tiebreakBidderIcon = icon
                return icon
            end)()
        }
    }

    -- 最高出价人名字
    bidderNameLabel = UI.Label {
        text = "---",
        fontSize = 16, fontColor = { 255, 255, 255, 255 },
        fontWeight = "bold",
    }

    -- 加价百分比按钮（1%, 5%, 10%）
    bidButtons = {}
    local function SubmitTiebreakBid(nextAmount)
        Utils.PlaySfx("bid_place")
        if not AuctionEngine.CanTiebreakBid() then return end
        AuctionEngine.PlayerTiebreakBid(nextAmount)
    end

    local btnChildren = {}
    for i, pct in ipairs(Config.GAME.TiebreakBidPercents) do
        local btn = UI.Button {
            text = "+" .. math.floor(pct * 100) .. "%",
            height = 36,
            paddingHorizontal = 12,
            fontSize = 13,
            onClick = function()
                local currentBid = GS.GetCurrentBid()
                local inc = Config.CalcBidIncrement(currentBid, pct)
                local nextAmount = currentBid + inc
                local mySlot = 1
                local player = GS.GetPlayers()[mySlot]
                if not player or nextAmount > player.money then return end

                -- 检查是否比本轮暗标出价翻倍
                local round = GS.GetCurrentRound()
                local roundBids = GS.GetRoundBids()
                local myBid = roundBids[round] and roundBids[round][mySlot]
                if myBid and myBid > 0 and nextAmount > myBid * 2 then
                    if bidConfirmModal_ then return end
                    bidConfirmModal_ = UI.Modal {
                        title = "出价提醒",
                        size = "sm",
                        children = {
                            UI.Label {
                                text = "本次出价 " .. Utils.FormatMoney(nextAmount)
                                    .. " 超过暗标出价的两倍，确认加价吗？",
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
                            bidConfirmModal_:Close()
                            bidConfirmModal_ = nil
                        end,
                    })
                    footer:AddChild(UI.Button {
                        text = "确认加价",
                        variant = "primary",
                        onClick = function()
                            Utils.PlayClick()
                            bidConfirmModal_:Close()
                            bidConfirmModal_ = nil
                            SubmitTiebreakBid(nextAmount)
                        end,
                    })
                    bidConfirmModal_:SetFooter(footer)
                    bidConfirmModal_:Open()
                else
                    SubmitTiebreakBid(nextAmount)
                end
            end,
        }
        bidButtons[i] = btn
        btnChildren[i] = btn
    end

    panel = UI.Panel {
        id = "tiebreakOverlay",
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 180 },
        justifyContent = "center", alignItems = "center",
        visible = false,
        children = {
            -- 居中弹窗（按屏幕比例设置尺寸，避免小屏溢出）
            UI.Panel {
                width = "40%", maxWidth = 420, minWidth = 260,
                maxHeight = "90%",
                backgroundColor = { 20, 25, 45, 240 },
                borderRadius = 0,
                borderWidth = 1, borderColor = { 80, 90, 130, 180 },
                flexDirection = "column",
                alignItems = "center",
                overflow = "scroll",
                padding = 16, gap = 10,
                children = {
                    -- 标题
                    UI.Label {
                        text = "实时竞拍",
                        fontSize = 18, fontColor = { 255, 200, 80, 255 },
                        fontWeight = "bold",
                    },
                    -- 倒计时
                    UI.Panel {
                        width = 60, height = 60,
                        backgroundColor = { 40, 20, 20, 200 },
                        borderRadius = 0,
                        borderWidth = 2, borderColor = { 200, 60, 60, 200 },
                        justifyContent = "center", alignItems = "center",
                        flexShrink = 0,
                        children = { timerLabel },
                    },
                    -- 分隔
                    UI.Panel { width = "80%", height = 1, backgroundColor = { 80, 90, 120, 100 } },
                    -- 当前最高价
                    UI.Label {
                        text = "当前最高价",
                        fontSize = 12, fontColor = C.textSecondary,
                    },
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 6,
                        children = {
                            UI.Panel {
                                width = 24, height = 24,
                                backgroundImage = Utils.GetIcon("coin"),
                                backgroundFit = "contain",
                                flexShrink = 0,
                            },
                            highBidLabel,
                        },
                    },
                    -- 最高出价人
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 10,
                        paddingVertical = 6, paddingHorizontal = 12,
                        backgroundColor = { 40, 50, 80, 160 },
                        borderRadius = 0,
                        children = {
                            bidderAvatarIcon,
                            bidderNameLabel,
                        },
                    },
                    -- 分隔
                    UI.Panel { width = "80%", height = 1, backgroundColor = { 80, 90, 120, 100 } },
                    -- 加价按钮区
                    UI.Label {
                        text = "选择加价",
                        fontSize = 12, fontColor = C.textSecondary,
                    },
                    UI.Panel {
                        flexDirection = "row", flexWrap = "wrap",
                        justifyContent = "center", gap = 8,
                        children = btnChildren,
                    },
                    -- 返回按钮
                    (function()
                        backBtn = UI.Button {
                            text = "返回", width = 120, height = 36, fontSize = 14,
                            marginTop = 4, flexShrink = 0,
                            onClick = function()
                                Utils.PlayClick()
                                TiebreakPanel.ShowConfirmBack()
                            end,
                        }
                        return backBtn
                    end)(),
                },
            },
        },
    }
    return panel
end

-- ============================================================================
-- 显示 / 隐藏
-- ============================================================================

function TiebreakPanel.Show()
    isVisible = true
    if panel then
        panel:SetVisible(true)
        TiebreakPanel.Refresh()
    end
end

function TiebreakPanel.Hide()
    isVisible = false
    if panel then
        panel:SetVisible(false)
    end
end

function TiebreakPanel.IsVisible()
    return isVisible
end

-- ============================================================================
-- 刷新数据
-- ============================================================================

function TiebreakPanel.Refresh()
    if not isVisible then return end

    -- 最高价
    local currentBid = GS.GetCurrentBid()
    highBidLabel:SetText(Utils.FormatMoney(currentBid))

    -- 最高出价人
    local bidderIdx = GS.GetCurrentBidder()
    local players = GS.GetPlayers()
    if bidderIdx > 0 and players[bidderIdx] then
        local p = players[bidderIdx]
        bidderNameLabel:SetText(p.name)
        if refs.tiebreakBidderIcon and p.character then
            refs.tiebreakBidderIcon:SetStyle({ backgroundImage = p.character.avatar })
        end
    else
        bidderNameLabel:SetText("等待出价...")
        if refs.tiebreakBidderIcon then
            refs.tiebreakBidderIcon:SetStyle({ backgroundImage = "" })
        end
    end

    -- 按钮状态（动态更新文本和可用性）
    local canBid = AuctionEngine.CanTiebreakBid()
    local mySlot = 1
    local playerMoney = (players[mySlot] and players[mySlot].money) or 0
    for i, pct in ipairs(Config.GAME.TiebreakBidPercents) do
        if bidButtons[i] then
            local inc = Config.CalcBidIncrement(currentBid, pct)
            local nextAmount = currentBid + inc
            local disabled = (not canBid) or (nextAmount > playerMoney)
            bidButtons[i]:SetDisabled(disabled)
            bidButtons[i]:SetText("+" .. math.floor(pct * 100) .. "% (" .. Utils.FormatMoney(inc) .. ")")
        end
    end
end

-- ============================================================================
-- 每帧更新（倒计时显示 + 按钮状态）
-- ============================================================================

function TiebreakPanel.Update(dt)
    if not isVisible then return end

    -- 倒计时
    local timer = GS.GetTimer()
    local sec = math.ceil(timer)
    if sec < 0 then sec = 0 end
    timerLabel:SetText(tostring(sec))

    -- 倒计时颜色：<=3秒变红闪烁
    if sec <= 3 then
        local flash = math.floor(timer * 4) % 2
        if flash == 0 then
            timerLabel:SetStyle({ fontColor = { 255, 60, 60, 255 } })
        else
            timerLabel:SetStyle({ fontColor = { 255, 180, 180, 255 } })
        end
    else
        timerLabel:SetStyle({ fontColor = { 255, 255, 255, 255 } })
    end

    -- 刷新按钮可用状态
    TiebreakPanel.Refresh()
end

-- ============================================================================
-- 确认返回弹窗
-- ============================================================================

function TiebreakPanel.ShowConfirmBack()
    if confirmModal then return end
    confirmModal = UI.Modal {
        title = "确认返回",
        size = "sm",
        onClose = function()
            confirmModal = nil
        end,
        children = {
            UI.Label { text = "确定要返回竞拍大厅吗？", fontSize = 14 },
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
            confirmModal:Close()
            confirmModal = nil
        end,
    })
    footer:AddChild(UI.Button {
        text = "确定",
        variant = "primary",
        onClick = function()
            Utils.PlayClick()
            confirmModal:Close()
            confirmModal = nil
            if TiebreakPanel._onBackClick then
                TiebreakPanel._onBackClick()
            end
        end,
    })
    confirmModal:SetFooter(footer)
    confirmModal:Open()
end

return TiebreakPanel
