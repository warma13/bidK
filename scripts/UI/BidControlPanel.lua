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
local PropSystem = require("PropSystem")
local Props = require("Config.Props")
local InfoFeed = require("UI.InfoFeed")

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

-- ============================================================================
-- 道具系统（对局中使用）
-- ============================================================================

-- 效果类型对应颜色
local PROP_TYPE_COLORS = {
    [Props.EFFECT.SHOW_RARITY_CELL_COUNT] = { 70, 130, 220, 255 },
    [Props.EFFECT.SHOW_RARITY_ITEM_COUNT] = { 70, 180, 100, 255 },
    [Props.EFFECT.SHOW_RANDOM_SILHOUETTE] = { 150, 100, 200, 255 },
    [Props.EFFECT.SHOW_SIZE_AVG_VALUE]    = { 220, 170, 50, 255 },
}

--- 使用道具并将效果信息注入 InfoFeed
local function UseProp(propId)
    local warehouseItems = GS.GetWarehouseItems()
    local ok, info, errMsg = PropSystem.Use(propId, warehouseItems)
    if not ok then
        Utils.ShowMessage(errMsg or "使用失败")
        return
    end

    -- 处理 reveals（更新 UIState.itemRevealLevels）
    if info.reveals then
        for _, r in ipairs(info.reveals) do
            local cur = UIState.itemRevealLevels[r.itemIdx] or 0
            if r.targetLevel > cur then
                UIState.itemRevealLevels[r.itemIdx] = r.targetLevel
            end
        end
    end

    -- 注入信息流（isSkill=true 显示为紫色私人信息卡）
    InfoFeed.Enqueue(info, true)

    local def = Props.BY_ID[propId]
    Utils.ShowMessage("使用了 " .. (def and def.name or "道具"))

    -- 记录到 GameState（用于轮次框图标显示）
    local round = GS.GetCurrentRound()
    GS.RecordPropUsage(round, 1, propId, def and def.name or propId)

    -- 更新道具面板状态（本轮已用，禁用所有道具按钮）
    BidControlPanel.UpdatePropPanelState()

    -- 刷新玩家列表面板（使轮次框道具图标立即显示）
    PlayerListPanel.Update()

    -- 更新战利品展示面板
    local LootPanel = require("UI.LootPanel")
    LootPanel.Update()
end

--- 同步点击外部关闭遮罩的可见状态
local function UpdateDismissOverlay()
    local bidOpen  = UIState.bidPanelVisible
    local propOpen = refs.propPanel and refs.propPanel:IsVisible()
    if refs.panelDismissOverlay then
        refs.panelDismissOverlay:SetVisible(bidOpen or (propOpen == true))
    end
end

--- 关闭道具浮窗
local function ClosePropPanel()
    if refs.propPanel then
        refs.propPanel:SetVisible(false)
    end
    UpdateDismissOverlay()
end

--- 刷新道具浮窗内容（每次打开前调用）
local function UpdatePropPanel()
    if not refs.propRows then return end
    -- 本轮是否已用过道具（每轮只能用一次）
    local roundUsed = PropSystem.IsUsedThisRound()
    local hasAny = false
    for i, row in ipairs(refs.propRows) do
        local d = row.def
        local count = PropSystem.GetCount(d.id)
        local hasCount = count > 0

        -- 显示/隐藏行（无库存隐藏）
        row.widget:SetVisible(hasCount)
        if hasCount then hasAny = true end

        -- 刷新数量标签
        row.countLabel:SetText("×" .. count)

        -- 刷新使用按钮（本轮已用过则全部禁用）
        if roundUsed then
            row.useBtn:SetText("本轮已用")
            row.useBtn:SetDisabled(true)
            row.useBtn:SetStyle({ backgroundColor = { 50, 50, 60, 180 } })
        else
            row.useBtn:SetText("使用")
            row.useBtn:SetDisabled(false)
            row.useBtn:SetStyle({ backgroundColor = { 60, 170, 130, 255 } })
        end

        -- 图标透明度
        if roundUsed then
            row.iconPanel:SetStyle({ opacity = 0.4 })
        else
            row.iconPanel:SetStyle({ opacity = 1.0 })
        end
    end

    -- 无道具时显示提示
    if refs.propEmptyLabel then
        refs.propEmptyLabel:SetVisible(not hasAny)
    end

end

--- 外部调用：使用道具后立即刷新道具面板状态
function BidControlPanel.UpdatePropPanelState()
    UpdatePropPanel()
end

--- 打开/刷新道具浮窗
local function ShowPropPanel()
    UpdatePropPanel()
    if refs.propPanel then
        refs.propPanel:SetVisible(true)
    end

    UpdateDismissOverlay()
end

local function OnPropButtonClicked()
    local phase = GS.GetPhase()
    if phase ~= GS.PHASE.SEALED_BID then return end
    if UIState.playerBidConfirmed then
        Utils.ShowMessage("已确认出价，无法使用道具")
        return
    end
    -- 切换浮窗显示/隐藏
    if refs.propPanel and refs.propPanel:IsVisible() then
        ClosePropPanel()
    else
        -- 如果出价面板打开，先关闭
        if UIState.bidPanelVisible then
            UIState.bidPanelVisible = false
            if refs.bidPanel then refs.bidPanel:SetVisible(false) end
        end
        ShowPropPanel()
    end
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
    -- 打开出价面板时关闭道具浮窗
    if refs.propPanel and refs.propPanel:IsVisible() then
        ClosePropPanel()
    end
    UIState.bidPanelVisible = not UIState.bidPanelVisible
    if refs.bidPanel then
        refs.bidPanel:SetVisible(UIState.bidPanelVisible)
    end
    UpdateDismissOverlay()
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
        UpdateDismissOverlay()
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
    UpdateDismissOverlay()
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

            -- 条件2：超过场次入场门槛的两倍
            if not confirmReason then
                local assetReq = GS.GetAssetRequirement()
                if assetReq > 0 and amount > assetReq * 2 then
                    confirmReason = "本次出价 " .. Utils.FormatMoney(amount)
                        .. " 超过本场门槛（" .. Utils.FormatMoney(assetReq) .. "）的两倍，确认出价吗？"
                end
            end

            if confirmReason then
                -- 弹窗确认（先清理残留弹窗）
                CloseBidConfirmModal()
                bidConfirmModal_ = UI.Modal {
                    title = "出价提醒",
                    size = "sm",
                    borderRadius = 0,
                    headerBgColor = { 30, 32, 38, 200 },
                    contentBgColor = { 22, 24, 30, 180 },
                    onClose = function()
                        bidConfirmModal_ = nil
                    end,
                    children = {
                        UI.Panel {
                            flexDirection = "column",
                            alignItems = "center",
                            gap = Utils.sz(6),
                            paddingVertical = Utils.sz(4),
                            children = {
    
                                UI.Label {
                                    text = confirmReason,
                                    fontSize = Utils.sz(13),
                                    fontColor = { 210, 215, 230, 255 },
                                    textAlign = "center",
                                    lineHeight = 1.5,
                                },
                            },
                        },
                    },
                }
                local footer = UI.Panel {
                    flexDirection = "row",
                    justifyContent = "center",
                    gap = Utils.sz(12),
                    width = "100%",
                    paddingVertical = Utils.sz(4),
                }
                footer:AddChild(UI.Button {
                    text = "取消",
                    flexGrow = 1, height = Utils.sz(38),
                    fontSize = Utils.sz(14),
                    backgroundColor = { 50, 55, 65, 200 },
                    hoverBackgroundColor = { 70, 75, 90, 230 },
                    pressedBackgroundColor = { 35, 38, 48, 255 },
                    borderWidth = 1,
                    borderColor = { 100, 105, 120, 130 },
                    borderRadius = 0,
                    onClick = function()
                        Utils.PlayClick()
                        CloseBidConfirmModal()
                    end,
                })
                footer:AddChild(UI.Button {
                    text = "确认出价",
                    flexGrow = 1, height = Utils.sz(38),
                    fontSize = Utils.sz(14),
                    fontWeight = "bold",
                    fontColor = { 255, 255, 255, 255 },
                    backgroundColor = { 60, 170, 130, 255 },
                    hoverBackgroundColor = { 80, 200, 155, 255 },
                    pressedBackgroundColor = { 45, 140, 105, 255 },
                    borderWidth = 0,
                    borderRadius = 0,
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
    local sz = Utils.sz

    -- 隐藏标签（逻辑兼容）
    refs.timerLabel = UI.Label { text = "", fontSize = 1, visible = false }
    refs.bidStatusLabel = UI.Label { text = "", fontSize = 1, visible = false }
    refs.bidHintLabel = UI.Label { text = "", fontSize = 1, visible = false }

    -- 键盘区×倍率数值标签
    refs.bidMultiplierValueLabel = UI.Label {
        text = "×1.0", fontSize = sz(12), fontColor = { 255, 255, 255, 255 }, fontWeight = "bold",
    }

    -- 金额显示
    refs.bidAmountLabel = UI.Label {
        text = "0", fontSize = sz(22), fontColor = C.accent, textAlign = "right", fontWeight = "bold",
    }

    -- 确认按钮
    refs.bidButton = UI.Button {
        text = "确认出价",
        width = "100%", height = sz(36), fontSize = sz(13),
        onClick = function() OnBidButtonClicked() end,
    }

    -- 倍率提示
    refs.bidMultiplierLabel = UI.Label {
        text = "", fontSize = sz(11), fontColor = KB.txtDim, lineHeight = 1.4,
    }

    -- 数字键按钮生成
    local KEY_W = sz(52)
    local KEY_H = sz(42)
    local SIDE_W = sz(56)
    local function keyBtn(label, onPress)
        return UI.Button {
            text = label, width = KEY_W, height = KEY_H, fontSize = sz(15),
            backgroundColor = KB.btn,
            borderRadius = KB.radius,
            textColor = KB.txtW,
            hoverBackgroundColor = KB.btnHov,
            pressedBackgroundColor = { 80, 85, 100, 255 },
            onClick = function() Utils.PlayClick() onPress() end,
        }
    end

    -- 出价弹出面板（由 GameController 提升到根级别，定位相对于全屏 uiRoot）
    local bidBottom = math.floor(UI.GetWidth() * 0.06 + sz(50))
    refs.bidPanel = UI.Panel {
        id = "bidPanel",
        position = "absolute",
        bottom = bidBottom,
        left = "24%",
        width = KEY_W * 3 + SIDE_W + sz(6) * 3 + sz(12) + sz(160),  -- 键盘+侧栏+右栏自适应
        backgroundColor = KB.bg,
        borderRadius = 0,
        padding = sz(6), gap = sz(8),
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
                                keyBtn("1", function() AppendBidDigit("1") end),
                                keyBtn("2", function() AppendBidDigit("2") end),
                                keyBtn("3", function() AppendBidDigit("3") end),
                            }},
                            UI.Panel { flexDirection = "row", gap = KB.gap, children = {
                                keyBtn("4", function() AppendBidDigit("4") end),
                                keyBtn("5", function() AppendBidDigit("5") end),
                                keyBtn("6", function() AppendBidDigit("6") end),
                            }},
                            UI.Panel { flexDirection = "row", gap = KB.gap, children = {
                                keyBtn("7", function() AppendBidDigit("7") end),
                                keyBtn("8", function() AppendBidDigit("8") end),
                                keyBtn("9", function() AppendBidDigit("9") end),
                            }},
                            UI.Panel { flexDirection = "row", gap = KB.gap, children = {
                                keyBtn("0",   function() AppendBidDigit("0") end),
                                keyBtn("00",  function() AppendBidDigit("00") end),
                                keyBtn("000", function() AppendBidDigit("000") end),
                            }},
                        }
                    },
                    -- 3个竖向按钮
                    UI.Panel {
                        flexDirection = "column", gap = KB.gap,
                        width = SIDE_W,
                        children = {
                            -- 退格按钮
                            UI.Panel {
                                width = SIDE_W, flexGrow = 1,
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
                                width = SIDE_W, flexGrow = 2,
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
                                width = SIDE_W, flexGrow = 1,
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
                                    UI.Label { text = "清空", fontSize = sz(12), fontColor = KB.txtDim },
                                }
                            },
                        }
                    },
                }
            },
            -- 右栏：信息 + 金额 + 确认
            UI.Panel {
                flexDirection = "column", gap = sz(6),
                flexGrow = 1, flexShrink = 1,
                justifyContent = "space-between",
                children = {
                    refs.bidMultiplierLabel,
                    UI.Panel {
                        width = "100%",
                        backgroundColor = { 10, 12, 20, 255 },
                        borderRadius = KB.radius, borderWidth = 1,
                        borderColor = { 80, 90, 110, 180 },
                        paddingVertical = sz(8), paddingHorizontal = sz(10),
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
        text = "出价", width = sz(120), height = sz(42), fontSize = sz(14),
        variant = "primary",
        textColor = { 20, 25, 10, 255 },
        fontWeight = "bold",
        onClick = function() Utils.PlayClick() ToggleBidPanel() end,
    }

    refs.toolbarForfeitBtn = UI.Button {
        text = "弃权", width = sz(80), height = sz(42), fontSize = sz(13),
        backgroundColor = { 180, 45, 45, 255 },
        hoverBackgroundColor = { 210, 60, 60, 255 },
        pressedBackgroundColor = { 150, 30, 30, 255 },
        textColor = { 255, 220, 220, 255 },
        onClick = function() OnForfeitClicked() end,
    }

    refs.toolbarPropBtn = UI.Button {
        text = "道具", width = sz(80), height = sz(42), fontSize = sz(13),
        backgroundColor = { 60, 100, 180, 255 },
        hoverBackgroundColor = { 80, 120, 210, 255 },
        pressedBackgroundColor = { 45, 80, 155, 255 },
        textColor = { 210, 225, 255, 255 },
        onClick = function() Utils.PlayClick() OnPropButtonClicked() end,
    }

    -- -------------------------------------------------------------------------
    -- 道具浮窗（横向卡片 + 可滑动，absolute，提升至根级别）
    -- -------------------------------------------------------------------------
    local propBottom = math.floor(UI.GetWidth() * 0.06 + 50)
    local CARD_W   = sz(96)   -- 卡片宽度（缩放）
    local CARD_H   = sz(152)  -- 卡片高度（缩放）
    local PPAD     = sz(8)    -- 面板内边距
    local HEX_SZ   = sz(62)   -- 六边形背景框尺寸
    local ICON_SZ  = sz(36)   -- 道具图标尺寸

    -- 品质层级颜色（与商店保持一致，按 def.tier 字段判断）
    local TIER_COLORS_BID = {
        white  = { headerBg = { 75, 78, 88, 255 },   headerText = { 210, 212, 220, 255 },
                   cardBg   = { 28, 30, 42, 235 },   cardBorder = { 65, 68, 78, 180 },   hexTint = nil },
        green  = { headerBg = { 30, 110, 65, 255 },  headerText = { 190, 255, 210, 255 },
                   cardBg   = { 20, 35, 28, 235 },   cardBorder = { 40, 100, 65, 200 },  hexTint = { 80, 230, 120, 255 } },
        blue   = { headerBg = { 25, 80, 155, 255 },  headerText = { 190, 220, 255, 255 },
                   cardBg   = { 18, 30, 55, 235 },   cardBorder = { 40, 85, 170, 200 },  hexTint = { 80, 160, 255, 255 } },
        purple = { headerBg = { 85, 35, 130, 255 },  headerText = { 230, 200, 255, 255 },
                   cardBg   = { 26, 16, 40, 235 },   cardBorder = { 100, 50, 155, 200 }, hexTint = { 200, 100, 255, 255 } },
        red    = { headerBg = { 130, 30, 30, 255 },  headerText = { 255, 200, 200, 255 },
                   cardBg   = { 40, 16, 16, 235 },   cardBorder = { 160, 50, 50, 200 },  hexTint = { 255, 80, 80, 255 } },
    }
    local function GetTierColors(def)
        return TIER_COLORS_BID[def.tier] or TIER_COLORS_BID.white
    end

    -- 构建所有道具卡片（静态结构，通过 UpdatePropPanel 刷新状态）
    refs.propRows = {}
    local propCardWidgets = {}

    for i, d in ipairs(Props.LIST) do
        local propId = d.id
        local tier   = GetTierColors(d)

        -- 六边形背景框 + 道具图标（点击弹出描述 Popover）
        local iconPanel = UI.Popover {
            title = d.name,
            content = d.desc,
            placement = "top",
            trigger = "click",
            maxWidth = 220,
            children = {
                UI.Panel {
                    width = HEX_SZ, height = HEX_SZ, flexShrink = 0,
                    alignItems = "center", justifyContent = "center",
                    cursor = "pointer",
                    children = {
                        UI.Panel {
                            position = "absolute",
                            width = HEX_SZ * 0.88, height = HEX_SZ,
                            backgroundImage = "image/ui_hex_frame_trimmed.png",
                            backgroundFit = "fill",
                            imageTint = tier.hexTint,
                        },
                        d.iconImage and UI.Panel {
                            width = ICON_SZ, height = ICON_SZ,
                            backgroundImage = d.iconImage,
                            backgroundFit = "contain",
                        } or UI.Label { text = d.icon, fontSize = sz(26) },
                    },
                },
            },
        }

        local countLabel = UI.Label {
            text = "×0", fontSize = sz(11),
            fontColor = { 200, 205, 215, 220 }, fontWeight = "bold",
            textAlign = "center",
        }

        local useBtn = UI.Button {
            text = "使用",
            width = CARD_W - PPAD * 2, height = sz(28), fontSize = sz(12),
            backgroundColor = { 60, 170, 130, 255 },
            borderRadius = sz(6),
            onClick = function()
                Utils.PlayClick()
                ClosePropPanel()
                UseProp(propId)
            end,
        }

        -- 卡片：名称条（同商店）+ 六边形图标 + 数量 + 使用按钮
        local cardWidget = UI.Panel {
            width = CARD_W, height = CARD_H, flexShrink = 0,
            backgroundColor = tier.cardBg,
            borderRadius = sz(8),
            borderWidth = 1,
            borderColor = tier.cardBorder,
            overflow = "hidden",
            flexDirection = "column",
            alignItems = "center",
            children = {
                -- 名称条（顶部色带）
                UI.Panel {
                    width = "100%",
                    paddingVertical = sz(5), paddingHorizontal = sz(6),
                    backgroundColor = tier.headerBg,
                    children = {
                        UI.Label {
                            text = d.name, fontSize = sz(10), fontWeight = "bold",
                            fontColor = tier.headerText, textAlign = "center",
                            width = "100%",
                        },
                    },
                },
                -- 图标区（六边形）
                UI.Panel {
                    flexGrow = 1, width = "100%",
                    alignItems = "center", justifyContent = "center",
                    paddingVertical = sz(4),
                    gap = sz(2),
                    flexDirection = "column",
                    children = {
                        iconPanel,
                        countLabel,
                    },
                },
                -- 使用按钮区
                UI.Panel {
                    width = "100%",
                    paddingHorizontal = PPAD, paddingVertical = sz(6),
                    alignItems = "center",
                    children = { useBtn },
                },
            },
        }

        refs.propRows[i] = {
            def        = d,
            widget     = cardWidget,
            iconPanel  = iconPanel,
            countLabel = countLabel,
            useBtn     = useBtn,
        }
        propCardWidgets[i] = cardWidget
    end

    refs.propEmptyLabel = UI.Label {
        text = "暂无可用道具，请在商店购买",
        fontSize = sz(12),
        fontColor = { 130, 135, 155, 255 },
        textAlign = "center",
        visible = false,
    }

    -- 浮窗宽度：展示 4.5 张卡片（半露第 5 张提示可滑动），超出横向滑动
    -- panelW 固定（不随卡片数量增加），内部 ScrollView 负责滚动
    -- 4.5 * CARD_W + 3.5 * gap + 2 * PPAD
    local panelW = math.floor(4.5 * sz(96) + 3.5 * sz(8)) + PPAD * 2

    refs.propPanel = UI.Panel {
        id = "propPanel",
        position = "absolute",
        bottom = propBottom + sz(4),
        left = math.floor((UI.GetWidth() - panelW) / 2),
        width = panelW,
        backgroundColor = { 12, 14, 24, 248 },
        borderRadius = sz(14),
        borderWidth = 1,
        borderColor = { 55, 60, 88, 200 },
        paddingHorizontal = PPAD, paddingTop = sz(10), paddingBottom = sz(10),
        gap = sz(8),
        flexDirection = "column",
        visible = false,
        children = {
            -- 标题行
            UI.Panel {
                width = "100%",
                flexDirection = "row", alignItems = "center",
                justifyContent = "space-between",
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = sz(7),
                        children = {
                            UI.Panel {
                                width = sz(3), height = sz(14),
                                backgroundColor = { 100, 200, 160, 255 },
                                borderRadius = sz(2),
                            },
                            UI.Label {
                                text = "使用道具", fontSize = sz(13), fontWeight = "bold",
                                fontColor = { 215, 225, 240, 255 },
                            },
                        },
                    },
                    UI.Panel {
                        width = sz(22), height = sz(22),
                        backgroundColor = { 45, 50, 72, 210 },
                        borderRadius = sz(11),
                        justifyContent = "center", alignItems = "center",
                        cursor = "pointer",
                        hoverStyle = { backgroundColor = { 70, 75, 100, 255 } },
                        onClick = function() ClosePropPanel() end,
                        children = {
                            UI.Label { text = "✕", fontSize = sz(10), fontColor = { 170, 175, 195, 255 } },
                        },
                    },
                },
            },
            -- 横向可滑动卡片区
            (function()
                -- 卡片总宽度：显式告知 Yoga 内容宽度，确保 ScrollView 检测到溢出
                local totalCardW = #propCardWidgets * CARD_W + math.max(0, #propCardWidgets - 1) * sz(8)
                local sv = UI.ScrollView {
                    width = "100%",
                    height = CARD_H,
                    scrollX = true,
                    scrollY = false,
                    showScrollbar = false,
                    bounces = true,
                    children = {
                        UI.Panel {
                            width = totalCardW,   -- 显式宽度：确保 Yoga 在 overflow:hidden 容器里正确撑开
                            flexDirection = "row",
                            alignItems = "flex-start",
                            gap = sz(8),
                            children = (function()
                                local cards = {}
                                for _, w in ipairs(propCardWidgets) do
                                    cards[#cards + 1] = w
                                end
                                return cards
                            end)(),
                        },
                    },
                }
                -- 桌面端：竖向滚轮 → 横向滚动（同 patchTabWheel 模式）
                sv.OnWheel = function(self, dx, dy)
                    local dir = 0
                    if math.abs(dx) > math.abs(dy) then
                        dir = dx > 0 and 1 or -1
                    elseif dy ~= 0 then
                        dir = dy > 0 and -1 or 1  -- 滚轮向下 → 向右滚
                    end
                    if dir ~= 0 then
                        self:ScrollBy(dir * 60, 0)
                        self.scrollbarOpacity_ = 1
                        self.scrollbarFadeTimer_ = 1
                    end
                end
                return sv
            end)(),
            refs.propEmptyLabel,
        },
    }

    -- -------------------------------------------------------------------------
    -- 点击外部关闭遮罩（全屏透明，置于 bidPanel/propPanel 之下）
    -- -------------------------------------------------------------------------
    refs.panelDismissOverlay = UI.Panel {
        id = "panelDismissOverlay",
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 0 },
        visible = false,
        onClick = function()
            UIState.bidPanelVisible = false
            if refs.bidPanel then refs.bidPanel:SetVisible(false) end
            ClosePropPanel()
            if refs.panelDismissOverlay then
                refs.panelDismissOverlay:SetVisible(false)
            end
        end,
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
                width = "100%", height = sz(50),
                backgroundColor = C.bgPanel,
                borderRadius = 0,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                paddingHorizontal = 12,
                gap = 12,
                children = {
                    refs.toolbarPropBtn,
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
    refs.toolbarPropBtn:SetVisible(true)

    -- 阶段离开 SEALED_BID 时，清理残留的确认/道具浮窗
    if phase ~= GS.PHASE.SEALED_BID then
        CloseBidConfirmModal()
        ClosePropPanel()
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
            refs.toolbarPropBtn:SetDisabled(true)
            refs.bidButton:SetDisabled(true)
            refs.bidButton:SetText("已锁定")
        else
            refs.toolbarBidBtn:SetText("出价")
            refs.toolbarBidBtn:SetDisabled(false)
            refs.toolbarForfeitBtn:SetDisabled(false)
            refs.toolbarPropBtn:SetDisabled(false)
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
        refs.toolbarPropBtn:SetDisabled(true)
        if UIState.bidPanelVisible then
            UIState.bidPanelVisible = false
            if refs.bidPanel then refs.bidPanel:SetVisible(false) end
        end

    elseif phase == GS.PHASE.GAME_OVER then
        refs.toolbarBidBtn:SetText("结算")
        refs.toolbarBidBtn:SetDisabled(false)
        refs.toolbarForfeitBtn:SetDisabled(true)
        refs.toolbarPropBtn:SetDisabled(true)
        if UIState.bidPanelVisible then
            UIState.bidPanelVisible = false
            if refs.bidPanel then refs.bidPanel:SetVisible(false) end
        end

    else
        refs.toolbarBidBtn:SetText("出价")
        refs.toolbarBidBtn:SetDisabled(true)
        refs.toolbarForfeitBtn:SetDisabled(true)
        refs.toolbarPropBtn:SetDisabled(true)
        refs.bidMultiplierLabel:SetText("")
        if UIState.bidPanelVisible then
            UIState.bidPanelVisible = false
            if refs.bidPanel then refs.bidPanel:SetVisible(false) end
        end
    end
end

return BidControlPanel
