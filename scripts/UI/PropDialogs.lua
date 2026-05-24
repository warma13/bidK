-- ============================================================================
-- UI/PropDialogs.lua - 道具商店弹窗模块
-- 包含：OpenMallDialog（点券购买）、OpenDialog（金币购买）
-- ============================================================================
-- 使用方式：
--   local PropDialogs = require("UI.PropDialogs")
--   local dialogs = PropDialogs.Create(deps)
--   dialogs.openMall(opts)
--   dialogs.openShop(def, slotIdx)
-- ============================================================================

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")
local SaveSystem = require("SaveSystem")
local MoneyManager = require("MoneyManager")
local MoneyHUD = require("UI.MoneyHUD")
local PropSystem = require("PropSystem")
local PropCardWidget = require("UI.PropCardWidget")
local FloatingMessage = require("UI.FloatingMessage")

local PropDialogs = {}

-- ============================================================================
-- Create(deps) → { openMall, openShop }
-- ============================================================================
-- deps 字段：
--   overlayContainer  : UI Panel，弹窗挂载容器
--   setActiveClose    : function(fn)  写入模块级 activeCloseDialog
--   clearActiveClose  : function()    清除模块级 activeCloseDialog
--   coinIcon          : function(size) → widget
--   sz                : function(n)   → scaled number
--   onDailyBought     : function(slotIdx) 每日购买完成回调
--   onRegularBought   : function(def, newCount, labelKey) 普通购买完成回调
--   onMallBought      : function()    商城购买完成回调
--   getTopBarTicket   : function() → label widget or nil
-- ============================================================================
function PropDialogs.Create(deps)
    local overlayContainer = deps.overlayContainer
    local setActive        = deps.setActiveClose
    local clearActive      = deps.clearActiveClose
    local CoinIcon         = deps.coinIcon
    local sz               = deps.sz

    ---@type any
    local currentDialog = nil

    local function CloseDialog()
        if currentDialog then
            overlayContainer:RemoveChild(currentDialog)
            currentDialog = nil
        end
        clearActive()
    end

    -- ── 商城购买弹窗（点券计价）─────────────────────────────────
    -- opts 字段：name, icon, iconText, desc, price, isGameProp, tier,
    --           getCount(), onBuy(qty), cardBg, cardBorder, headerBg, headerText
    local function OpenMallDialog(opts)
        CloseDialog()
        local o = opts
        local ptBalance = SaveSystem.GetPointTickets()
        local owned     = o.getCount and o.getCount() or 0
        local qty       = 1
        local canAfford = ptBalance >= o.price * qty

        local qtyInput, priceLabel, buyBtnLabel

        local function RefreshDisplay(newQty)
            qty        = math.max(1, newQty)
            canAfford  = ptBalance >= o.price * qty
            if qtyInput    then qtyInput:SetValue(tostring(qty)) end
            if priceLabel  then
                priceLabel.text = (o.price * qty) .. " / " .. ptBalance
                priceLabel.props.fontColor = canAfford
                    and { 100, 220, 255, 255 } or { 220, 80, 70, 255 }
            end
            if buyBtnLabel then
                buyBtnLabel.text = canAfford and "购买" or "点券不足"
            end
        end

        local dialogBox = UI.Panel {
            width = sz(480),
            flexDirection = "column",
            backgroundColor = { 22, 25, 35, 252 },
            borderRadius = sz(8),
            borderWidth = 1,
            borderColor = { 60, 90, 130, 200 },
            overflow = "hidden",
            onClick = function() end,
            children = {
                -- 标题栏
                UI.Panel {
                    width = "100%", height = sz(44),
                    flexDirection = "row", alignItems = "center",
                    paddingHorizontal = sz(16),
                    backgroundColor = { 18, 22, 32, 255 },
                    borderBottomWidth = 1,
                    borderColor = { 55, 75, 110, 180 },
                    children = {
                        UI.Panel {
                            width = sz(18), height = sz(18),
                            backgroundImage = "image/point_ticket_icon_20260518210650.png",
                            backgroundFit = "contain",
                        },
                        UI.Panel { width = sz(8) },
                        UI.Label {
                            text = "商城购买",
                            fontSize = sz(16), fontWeight = "bold",
                            fontColor = { 240, 235, 220, 255 },
                        },
                        UI.Panel { flexGrow = 1 },
                        UI.Panel {
                            width = sz(30), height = sz(30),
                            alignItems = "center", justifyContent = "center",
                            cursor = "pointer",
                            onClick = function() Utils.PlayClick(); CloseDialog() end,
                            children = {
                                UI.Label {
                                    text = "✕", fontSize = sz(18), fontWeight = "bold",
                                    fontColor = { 180, 185, 200, 220 },
                                },
                            },
                        },
                    },
                },
                -- 道具信息行
                UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    padding = sz(18), gap = sz(16),
                    borderBottomWidth = 1,
                    borderColor = { 55, 75, 110, 100 },
                    children = {
                        -- 图标区：对局道具用六边形，票券/礼盒用纯图片
                        (function()
                            if o.isGameProp then
                                local tc = PropCardWidget.TIER_COLORS[o.tier] or PropCardWidget.TIER_COLORS.white
                                return UI.Panel {
                                    flexDirection = "column", alignItems = "center", gap = sz(4),
                                    children = {
                                        UI.Panel {
                                            width = sz(90), height = sz(90),
                                            alignItems = "center", justifyContent = "center",
                                            children = {
                                                UI.Panel {
                                                    position = "absolute",
                                                    width = sz(78), height = sz(90),
                                                    backgroundImage = "image/ui_hex_frame_trimmed.png",
                                                    backgroundFit = "fill",
                                                    imageTint = tc.hexTint,
                                                },
                                                o.icon ~= "" and UI.Panel {
                                                    width = sz(46), height = sz(46),
                                                    backgroundImage = o.icon,
                                                    backgroundFit = "contain",
                                                } or UI.Label { text = o.iconText or "?", fontSize = sz(36) },
                                            },
                                        },
                                        UI.Label {
                                            text = "×" .. (o.getCount and o.getCount() or 0),
                                            fontSize = sz(13), fontWeight = "bold",
                                            fontColor = { 200, 205, 215, 220 },
                                        },
                                    },
                                }
                            else
                                return UI.Panel {
                                    flexDirection = "column", alignItems = "center", gap = sz(4),
                                    children = {
                                        UI.Panel {
                                            width = sz(80), height = sz(80),
                                            backgroundColor = { 38, 40, 52, 255 },
                                            borderRadius = sz(8),
                                            borderWidth = 1,
                                            borderColor = { 65, 68, 85, 180 },
                                            justifyContent = "center", alignItems = "center",
                                            children = {
                                                o.icon ~= "" and UI.Panel {
                                                    width = sz(56), height = sz(56),
                                                    backgroundImage = o.icon,
                                                    backgroundFit = "contain",
                                                } or UI.Label { text = o.iconText or "?", fontSize = sz(36) },
                                            },
                                        },
                                        UI.Label {
                                            text = "×" .. (o.getCount and o.getCount() or 0),
                                            fontSize = sz(13), fontWeight = "bold",
                                            fontColor = { 200, 205, 215, 220 },
                                        },
                                    },
                                }
                            end
                        end)(),
                        UI.Panel {
                            flexGrow = 1, flexShrink = 1,
                            flexDirection = "column", gap = sz(6),
                            justifyContent = "center",
                            children = {
                                UI.Label {
                                    text = o.name,
                                    fontSize = sz(17), fontWeight = "bold",
                                    fontColor = { 240, 235, 215, 255 },
                                },
                                UI.Label {
                                    text = o.desc or "",
                                    fontSize = sz(12),
                                    fontColor = { 155, 160, 175, 200 },
                                    flexShrink = 1,
                                },
                                UI.Label {
                                    text = "已拥有：" .. owned,
                                    fontSize = sz(12),
                                    fontColor = { 130, 140, 160, 200 },
                                },
                            },
                        },
                    },
                },
                -- 数量选择 + 价格 + 购买按钮
                UI.Panel {
                    width = "100%",
                    flexDirection = "column",
                    padding = sz(18), gap = sz(14),
                    children = {
                        UI.Label {
                            text = "购买数量",
                            fontSize = sz(13),
                            fontColor = { 155, 160, 175, 200 },
                        },
                        UI.Panel {
                            width = "100%",
                            flexDirection = "row", alignItems = "center", gap = sz(10),
                            children = {
                                -- 减号
                                UI.Panel {
                                    width = sz(36), height = sz(36),
                                    backgroundColor = { 45, 50, 65, 255 },
                                    borderRadius = sz(4), borderWidth = 1,
                                    borderColor = { 75, 80, 100, 200 },
                                    alignItems = "center", justifyContent = "center",
                                    cursor = "pointer",
                                    onClick = function()
                                        if qty > 1 then Utils.PlayClick(); RefreshDisplay(qty - 1) end
                                    end,
                                    children = { UI.Label { text = "－", fontSize = sz(18), fontWeight = "bold", fontColor = { 200, 205, 220, 255 } } },
                                },
                                -- 数量输入框
                                (function()
                                    local tf = UI.TextField {
                                        value = "1",
                                        width = sz(60), height = sz(36),
                                        fontSize = sz(16), fontWeight = "bold",
                                        fontColor = { 240, 240, 245, 255 },
                                        backgroundColor = { 38, 42, 55, 255 },
                                        borderRadius = sz(4), borderWidth = 1,
                                        borderColor = { 80, 130, 200, 200 },
                                        textAlign = "center",
                                        maxLength = 3,
                                        onChange = function(self, val)
                                            local n = tonumber(val)
                                            if n and n >= 1 then
                                                RefreshDisplay(math.floor(n))
                                            end
                                        end,
                                        onSubmit = function(self, val)
                                            local n = tonumber(val)
                                            RefreshDisplay(n and math.floor(n) or 1)
                                            self:SetValue(tostring(qty))
                                        end,
                                    }
                                    qtyInput = tf
                                    return tf
                                end)(),
                                -- 加号
                                UI.Panel {
                                    width = sz(36), height = sz(36),
                                    backgroundColor = { 45, 50, 65, 255 },
                                    borderRadius = sz(4), borderWidth = 1,
                                    borderColor = { 75, 80, 100, 200 },
                                    alignItems = "center", justifyContent = "center",
                                    cursor = "pointer",
                                    onClick = function()
                                        Utils.PlayClick(); RefreshDisplay(qty + 1)
                                    end,
                                    children = { UI.Label { text = "＋", fontSize = sz(18), fontWeight = "bold", fontColor = { 200, 205, 220, 255 } } },
                                },
                                UI.Panel { width = sz(6) },
                                -- 点券余额显示
                                UI.Panel {
                                    flexDirection = "row", alignItems = "center", gap = sz(5),
                                    children = {
                                        UI.Label { text = "点券:", fontSize = sz(12), fontColor = { 150, 155, 175, 200 } },
                                        UI.Panel {
                                            width = sz(14), height = sz(14),
                                            backgroundImage = "image/point_ticket_icon_20260518210650.png",
                                            backgroundFit = "contain",
                                        },
                                        (function()
                                            local lbl = UI.Label {
                                                text = (o.price * qty) .. " / " .. ptBalance,
                                                fontSize = sz(13), fontWeight = "bold",
                                                fontColor = canAfford and { 100, 220, 255, 255 } or { 220, 80, 70, 255 },
                                            }
                                            priceLabel = lbl; return lbl
                                        end)(),
                                    },
                                },
                            },
                        },
                        -- 购买按钮（全宽）
                        (function()
                            local btn = UI.Panel {
                                width = "100%", height = sz(44),
                                backgroundColor = canAfford and { 30, 120, 200, 255 } or { 50, 52, 62, 200 },
                                borderRadius = sz(6),
                                alignItems = "center", justifyContent = "center",
                                cursor = canAfford and "pointer" or "default",
                                onClick = function()
                                    local curPt = SaveSystem.GetPointTickets()
                                    local total = o.price * qty
                                    if curPt < total then
                                        FloatingMessage.Show("点券不足（需 " .. total .. " 券）", { 255, 80, 80, 255 })
                                        return
                                    end
                                    Utils.PlayClick()
                                    local ok = SaveSystem.SpendPointTickets(total)
                                    if ok then
                                        o.onBuy(qty)
                                        SaveSystem.Save()
                                        CloseDialog()
                                        -- 回调：刷新商城卡片数量
                                        if deps.onMallBought then deps.onMallBought() end
                                        -- 刷新顶栏点券余额
                                        local tlbl = deps.getTopBarTicket and deps.getTopBarTicket()
                                        if tlbl then tlbl:SetText(tostring(SaveSystem.GetPointTickets())) end
                                        FloatingMessage.Show(
                                            "已获得 " .. o.name .. (qty > 1 and "  ×" .. qty or ""),
                                            { 100, 220, 255, 255 }
                                        )
                                    end
                                end,
                            }
                            local lbl = UI.Label {
                                text = canAfford and "购买" or "点券不足",
                                fontSize = sz(15), fontWeight = "bold",
                                fontColor = canAfford and { 255, 255, 255, 255 } or { 110, 110, 120, 200 },
                            }
                            buyBtnLabel = lbl
                            btn:AddChild(lbl)
                            return btn
                        end)(),
                    },
                },
            },
        }

        local overlay = UI.Panel {
            position = "absolute",
            left = 0, top = 0, right = 0, bottom = 0,
            backgroundColor = { 0, 0, 0, 140 },
            backdropBlur = 80,
            alignItems = "center", justifyContent = "center",
            onClick = function() CloseDialog() end,
            children = { dialogBox },
        }
        currentDialog = overlay
        setActive(CloseDialog)
        overlayContainer:AddChild(overlay)
    end

    -- ── 购买弹窗（金币计价）──────────────────────────────────────
    -- slotIdx: 每日商店槽位索引（1..12），普通商店传 nil
    local function OpenDialog(def, slotIdx)
        CloseDialog()
        if not def then return end

        local dMoney         = MoneyHUD.GetMoney()
        local dOwned         = PropSystem.GetCount(def.id)
        local dDailyLimit    = slotIdx and 1 or def.dailyLimit
        local dDailyBought   = slotIdx and (SaveSystem.GetDailySlotBought(slotIdx) and 1 or 0)
                            or (dDailyLimit and SaveSystem.GetPropDailyBought(def.id) or 0)
        local dDailyReached  = dDailyLimit and (dDailyBought >= dDailyLimit)
        local dMaxBuyable    = dDailyReached and 0
                            or (dDailyLimit and math.min(def.maxStack - dOwned, dDailyLimit - dDailyBought))
                            or (def.maxStack - dOwned)
        local qty            = math.max(1, math.min(1, math.max(1, dMaxBuyable)))
        local totalPrice     = def.price * qty
        local dCanAfford     = dMoney >= totalPrice
        local dMaxed         = dOwned >= def.maxStack
        local dCanBuy        = dCanAfford and not dMaxed and not dDailyReached
        local tier           = PropCardWidget.GetTierColors(def)

        local qtyInput, priceLabel, buyBtnLabel

        local function RefreshQtyDisplay(newQty)
            qty        = math.max(1, math.min(newQty, math.max(1, dMaxBuyable)))
            totalPrice = def.price * qty
            dCanAfford = dMoney >= totalPrice
            dCanBuy    = dCanAfford and not dMaxed and not dDailyReached
            if qtyInput then qtyInput:SetValue(tostring(qty)) end
            if priceLabel then
                priceLabel.text = Utils.FormatMoney(totalPrice) .. "/" .. Utils.FormatMoney(dMoney)
                priceLabel.props.fontColor = dCanAfford and { 240, 235, 215, 255 } or { 220, 80, 70, 255 }
            end
            if buyBtnLabel then
                buyBtnLabel.text = dDailyReached and "今日已购"
                    or (dMaxed and "已达上限")
                    or (dCanAfford and "购买" or "余额不足")
            end
        end

        local dailyBadge = def.dailyLimit and UI.Panel {
            flexDirection = "row", alignItems = "center",
            paddingHorizontal = sz(8), paddingVertical = sz(3),
            backgroundColor = tier.headerBg,
            borderRadius = sz(10),
            gap = sz(4),
            children = {
                UI.Label {
                    text = "每日限购 " .. def.dailyLimit,
                    fontSize = sz(11), fontWeight = "bold",
                    fontColor = tier.headerText,
                },
            },
        } or UI.Panel {}

        local dialogBox = UI.Panel {
            width = sz(600),
            flexDirection = "column",
            backgroundColor = { 30, 32, 40, 250 },
            borderRadius = sz(8),
            borderWidth = 1,
            borderColor = { 60, 62, 75, 200 },
            overflow = "hidden",
            onClick = function() end,
            children = {
                -- 标题栏
                UI.Panel {
                    width = "100%", height = sz(44),
                    flexDirection = "row", alignItems = "center",
                    paddingHorizontal = sz(16),
                    backgroundColor = { 25, 27, 35, 255 },
                    borderBottomWidth = 1,
                    borderColor = { 55, 58, 70, 180 },
                    children = {
                        CoinIcon(sz(18)),
                        UI.Panel { width = sz(8) },
                        UI.Label {
                            text = "购买",
                            fontSize = sz(16), fontWeight = "bold",
                            fontColor = { 240, 235, 220, 255 },
                        },
                        UI.Panel { flexGrow = 1 },
                        dailyBadge,
                        UI.Panel { width = sz(10) },
                        UI.Panel {
                            width = sz(30), height = sz(30),
                            alignItems = "center", justifyContent = "center",
                            cursor = "pointer",
                            onClick = function() Utils.PlayClick(); CloseDialog() end,
                            children = {
                                UI.Label {
                                    text = "✕", fontSize = sz(18), fontWeight = "bold",
                                    fontColor = { 180, 185, 200, 220 },
                                },
                            },
                        },
                    },
                },
                -- 道具信息区
                UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    padding = sz(20), gap = sz(20),
                    borderBottomWidth = 1,
                    borderColor = { 55, 58, 70, 120 },
                    children = {
                        UI.Panel {
                            flexDirection = "column", alignItems = "center", gap = sz(4),
                            children = {
                                UI.Panel {
                                    width = sz(90), height = sz(90),
                                    alignItems = "center", justifyContent = "center",
                                    children = {
                                        UI.Panel {
                                            position = "absolute",
                                            width = sz(78), height = sz(90),
                                            backgroundImage = "image/ui_hex_frame_trimmed.png",
                                            backgroundFit = "fill",
                                            imageTint = tier.hexTint,
                                        },
                                        def.iconImage
                                            and UI.Panel {
                                                width = sz(46), height = sz(46),
                                                backgroundImage = def.iconImage,
                                                backgroundFit = "contain",
                                            }
                                            or UI.Label { text = def.icon, fontSize = sz(36) },
                                    },
                                },
                                UI.Label {
                                    text = "×" .. dOwned,
                                    fontSize = sz(13), fontWeight = "bold",
                                    fontColor = { 200, 205, 215, 220 },
                                },
                            },
                        },
                        UI.Panel {
                            flexGrow = 1, flexShrink = 1,
                            flexDirection = "column", gap = sz(8),
                            children = {
                                UI.Label {
                                    text = def.name,
                                    fontSize = sz(18), fontWeight = "bold",
                                    fontColor = { 240, 235, 215, 255 },
                                },
                                UI.Label {
                                    text = def.desc,
                                    fontSize = sz(12),
                                    fontColor = { 160, 165, 180, 200 },
                                    flexShrink = 1,
                                },
                                UI.Panel { height = sz(4) },
                                UI.Label {
                                    text = "已拥有: " .. dOwned,
                                    fontSize = sz(13),
                                    fontColor = { 140, 145, 160, 200 },
                                },
                            },
                        },
                    },
                },
                -- 数量 + 价格 + 购买按钮
                UI.Panel {
                    width = "100%",
                    flexDirection = "column",
                    padding = sz(20), gap = sz(14),
                    children = {
                        UI.Label {
                            text = "购买数",
                            fontSize = sz(13),
                            fontColor = { 160, 165, 180, 200 },
                        },
                        UI.Panel {
                            width = "100%",
                            flexDirection = "row", alignItems = "center", gap = sz(12),
                            children = {
                                UI.Panel {
                                    width = sz(36), height = sz(36),
                                    backgroundColor = { 55, 58, 68, 255 },
                                    borderRadius = sz(4), borderWidth = 1,
                                    borderColor = { 80, 82, 95, 200 },
                                    alignItems = "center", justifyContent = "center",
                                    cursor = "pointer",
                                    onClick = function()
                                        if qty > 1 then Utils.PlayClick(); RefreshQtyDisplay(qty - 1) end
                                    end,
                                    children = { UI.Label { text = "－", fontSize = sz(18), fontWeight = "bold", fontColor = { 220, 220, 225, 255 } } },
                                },
                                (function()
                                    local tf = UI.TextField {
                                        value = tostring(qty),
                                        width = sz(60), height = sz(36),
                                        fontSize = sz(16), fontWeight = "bold",
                                        fontColor = { 240, 240, 245, 255 },
                                        backgroundColor = { 45, 48, 58, 255 },
                                        borderRadius = sz(4), borderWidth = 1,
                                        borderColor = { 100, 120, 160, 220 },
                                        textAlign = "center",
                                        maxLength = 4,
                                        onChange = function(self, val)
                                            local n = tonumber(val)
                                            if n and n >= 1 then
                                                RefreshQtyDisplay(math.floor(n))
                                                if math.floor(n) ~= n or tostring(math.floor(n)) ~= val then
                                                    self:SetValue(tostring(qty))
                                                end
                                            end
                                        end,
                                        onSubmit = function(self, val)
                                            local n = tonumber(val)
                                            RefreshQtyDisplay(n and math.floor(n) or 1)
                                            self:SetValue(tostring(qty))
                                        end,
                                    }
                                    qtyInput = tf
                                    return tf
                                end)(),
                                UI.Panel {
                                    width = sz(36), height = sz(36),
                                    backgroundColor = { 55, 58, 68, 255 },
                                    borderRadius = sz(4), borderWidth = 1,
                                    borderColor = { 80, 82, 95, 200 },
                                    alignItems = "center", justifyContent = "center",
                                    cursor = "pointer",
                                    onClick = function()
                                        if qty < dMaxBuyable then Utils.PlayClick(); RefreshQtyDisplay(qty + 1) end
                                    end,
                                    children = { UI.Label { text = "＋", fontSize = sz(18), fontWeight = "bold", fontColor = { 220, 220, 225, 255 } } },
                                },
                                UI.Panel { width = sz(8) },
                                UI.Panel {
                                    flexDirection = "row", alignItems = "center", gap = sz(6),
                                    children = {
                                        UI.Label { text = "售价:", fontSize = sz(13), fontColor = { 160, 165, 180, 200 } },
                                        CoinIcon(sz(18)),
                                        (function()
                                            local lbl = UI.Label {
                                                text = Utils.FormatMoney(totalPrice) .. "/" .. Utils.FormatMoney(dMoney),
                                                fontSize = sz(14), fontWeight = "bold",
                                                fontColor = dCanAfford and { 240, 235, 215, 255 } or { 220, 80, 70, 255 },
                                            }
                                            priceLabel = lbl; return lbl
                                        end)(),
                                    },
                                },
                                UI.Panel { flexGrow = 1 },
                                UI.Panel {
                                    width = sz(120), height = sz(40),
                                    backgroundColor = dCanBuy and { 230, 200, 30, 255 } or { 60, 62, 70, 200 },
                                    borderRadius = sz(6),
                                    alignItems = "center", justifyContent = "center",
                                    cursor = dCanBuy and "pointer" or "default",
                                    onClick = function()
                                        if not dCanBuy then return end
                                        Utils.PlayClick()
                                        local purchaseQty = qty
                                        local buyTotal = def.price * purchaseQty
                                        MoneyManager.AddMoneyFromMenu(-buyTotal, "buy_prop_" .. def.id, {
                                            silent = true,
                                            batchSetup = function(batch)
                                                SaveSystem.AddProp(def.id, purchaseQty)
                                                SaveSystem.WriteToBatch(batch)
                                            end,
                                            ok = function()
                                                if slotIdx then
                                                    SaveSystem.RecordDailySlotBuy(slotIdx)
                                                    if deps.onDailyBought then deps.onDailyBought(slotIdx) end
                                                elseif def.dailyLimit then
                                                    SaveSystem.RecordPropDailyBuy(def.id, purchaseQty)
                                                    if deps.onDailyBought then deps.onDailyBought(nil) end
                                                else
                                                    local newOwned = PropSystem.GetCount(def.id)
                                                    if deps.onRegularBought then
                                                        deps.onRegularBought(def.id, newOwned)
                                                    end
                                                end
                                                Utils.ShowMessage(def.name .. " ×" .. purchaseQty .. " 购买成功")
                                            end,
                                            error = function()
                                                SaveSystem.AddProp(def.id, -purchaseQty)
                                                Utils.ShowMessage("购买失败，请重试")
                                            end,
                                        })
                                        CloseDialog()
                                    end,
                                    children = {
                                        (function()
                                            local lbl = UI.Label {
                                                text = dDailyReached and "今日已购"
                                                    or (dMaxed and "已达上限")
                                                    or (dCanAfford and "购买" or "余额不足"),
                                                fontSize = sz(15), fontWeight = "bold",
                                                fontColor = dCanBuy and { 20, 20, 20, 255 } or { 110, 110, 115, 200 },
                                            }
                                            buyBtnLabel = lbl; return lbl
                                        end)(),
                                    },
                                },
                            },
                        },
                    },
                },
            },
        }

        local overlay = UI.Panel {
            position = "absolute",
            left = 0, top = 0, right = 0, bottom = 0,
            backgroundColor = { 0, 0, 0, 140 },
            backdropBlur = 80,
            alignItems = "center", justifyContent = "center",
            onClick = function() CloseDialog() end,
            children = { dialogBox },
        }

        currentDialog = overlay
        setActive(CloseDialog)
        overlayContainer:AddChild(overlay)
    end

    return {
        openMall = OpenMallDialog,
        openShop = OpenDialog,
        close    = CloseDialog,
    }
end

return PropDialogs
