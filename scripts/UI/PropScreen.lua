-- ============================================================================
-- UI/PropScreen.lua - 道具商店页（网格卡片布局）
-- ============================================================================
-- 布局：
--   左侧边栏：道具商店 / 每日商店（可点击切换）/ 商城 / 神秘商店 / 兑换所
--   顶栏：商店标题 + 货币显示 + 关闭按钮
--   主区域：3列网格卡片，可滚动
--              标题行：左侧"商品" + 右侧刷新倒计时（仅每日商店）
--   购买弹窗：详情 + 数量选择 + 售价 + 购买按钮
-- ============================================================================

local UI = require("urhox-libs/UI")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local SaveSystem = require("SaveSystem")
local Config = require("Config")
local Chests = require("Config.Chests")
local Props = require("Config.Props")
local PropSystem = require("PropSystem")
local MoneyManager = require("MoneyManager")
local MoneyHUD = require("UI.MoneyHUD")
local DailyShop = require("DailyShop")
local GameLoop = require("GameLoop")
local PropCardWidget = require("UI.PropCardWidget")
local FloatingMessage = require("UI.FloatingMessage")
local AdHelper = require("AdHelper")

local PropScreen = {}

-- ============================================================================
-- 倒计时更新（模块级，避免 SubscribeToEvent("Update") 覆盖 main 的 handler）
-- ============================================================================

---@type any
local _refreshLabel = nil   -- 当前活跃的倒计时 label，关闭页面时置 nil
local _refreshAccum = 0.0

GameLoop.RegisterScreen("prop", "PropScreenCountdown", function(dt)
    if not _refreshLabel then return end
    _refreshAccum = _refreshAccum + dt
    if _refreshAccum >= 1.0 then
        _refreshAccum = _refreshAccum - 1.0
        _refreshLabel.text = DailyShop.GetRefreshText()
    end
end)

-- ============================================================================
-- 常量
-- ============================================================================

local COIN_ICON = "金币.png"

-- ============================================================================
-- 辅助组件
-- ============================================================================

local function CoinIcon(size)
    return UI.Panel {
        width = size, height = size,
        backgroundImage = COIN_ICON,
        backgroundFit = "contain",
    }
end

-- 品质颜色由 PropCardWidget 统一管理
local function GetTierColors(def)
    return PropCardWidget.GetTierColors(def)
end

-- ============================================================================
-- 弹窗状态（模块级，供 ESC 处理使用）
-- ============================================================================

local activeCloseDialog = nil

function PropScreen.HasOpenDialog()
    return activeCloseDialog ~= nil
end

function PropScreen.DismissDialog()
    if activeCloseDialog then activeCloseDialog() end
end

-- ============================================================================
-- 主入口
-- ============================================================================

function PropScreen.Show(onBackCallback)
    UIState.currentScreen = "prop"
    local sz = Utils.sz

    -- 分离普通商店和每日商店列表
    -- 道具商店只展示白色/绿色品质道具
    local regularList = {}
    for _, p in ipairs(Props.LIST) do
        local tier = p.tier or "white"
        if not p.dailyShop and (tier == "white" or tier == "green") then
            regularList[#regularList + 1] = p
        end
    end

    -- 每日商店：使用 DailyShop 模块动态生成12个道具，已购买的排到最后
    -- dailyList 存储 {def, slotIdx} 对，以槽位为单位独立追踪购买状态
    -- 如果今日已使用广告刷新，使用广告刷新后的道具列表
    local rawDailyItems = (not DailyShop.CanAdRefresh())
        and DailyShop.GetAdRefreshedItems()
        or  DailyShop.GetTodayItems()
    local dailyList = {}
    for i, p in ipairs(rawDailyItems) do
        dailyList[i] = { def = p, slotIdx = i }
    end
    table.sort(dailyList, function(a, b)
        local aBought = SaveSystem.GetDailySlotBought(a.slotIdx)
        local bBought = SaveSystem.GetDailySlotBought(b.slotIdx)
        if aBought == bBought then return false end
        return not aBought  -- 未购买的排前面
    end)

    -- 当前激活的分类：1=道具商店  2=每日商店
    local activeSection = 1

    -- 存储各卡片的数量 Label（propId+index 混合键 → label widget）
    local cardCountLabels = {}

    -- 前向声明：每日商店购买后重建分区（定义在 sectionPanels/contentContainer 之后）
    local RebuildDailySection
    -- 前向声明：商城购买后刷新卡片 & 顶栏点券（定义在 mallGridPanel/topBar 之后）
    local RefreshMallGrid
    ---@type any
    local topBar

    -- 弹窗挂载容器
    local overlayContainer = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        pointerEvents = "box-none",
    }

    local currentDialog = nil

    -- ── 关闭弹窗 ─────────────────────────────────────────────
    local function CloseDialog()
        if currentDialog then
            overlayContainer:RemoveChild(currentDialog)
            currentDialog = nil
        end
        activeCloseDialog = nil
    end

    -- ── 商城购买弹窗（点券计价）───────────────────────────────
    -- opts 字段：name, icon, desc, price, itemType("ticket"/"chest"), itemId,
    --           onBuy(qty), getCount(), headerBg, cardBg, cardBorder, headerText
    local function OpenMallDialog(opts)
        CloseDialog()
        local o = opts
        local ptBalance = SaveSystem.GetPointTickets()
        local owned     = o.getCount and o.getCount() or 0
        local qty       = 1
        local canAfford = ptBalance >= o.price * qty

        local qtyInput, priceLabel, buyBtnLabel, ownedLabel

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
                                -- 六边形框（与道具商店弹窗一致）
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
                                -- 票券/礼盒：纯图片，无六边形
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
                                (function()
                                    local lbl = UI.Label {
                                        text = "已拥有：" .. owned,
                                        fontSize = sz(12),
                                        fontColor = { 130, 140, 160, 200 },
                                    }
                                    ownedLabel = lbl
                                    return lbl
                                end)(),
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
                                        -- 刷新商城卡片数量
                                        if RefreshMallGrid then RefreshMallGrid() end
                                        -- 刷新顶栏点券余额
                                        local tlbl = topBar and topBar:FindById("topbar_ticket_label")
                                        if tlbl then tlbl:SetText(tostring(SaveSystem.GetPointTickets())) end
                                        FloatingMessage.Show(
                                            "已获得 " .. o.name .. (qty > 1 and "  ×" .. qty or ""),
                                            { 100, 220, 255, 255 }
                                        )
                                    end
                                end,
                            }
                            -- 购买按钮标签（后绑定，供 RefreshDisplay 更新颜色）
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
        currentDialog     = overlay
        activeCloseDialog = CloseDialog
        overlayContainer:AddChild(overlay)
    end

    -- ── 购买弹窗 ─────────────────────────────────────────────
    -- slotIdx: 每日商店槽位索引（1..12），普通商店传 nil
    local function OpenDialog(def, slotIdx)
        CloseDialog()
        if not def then return end

        local dMoney         = MoneyHUD.GetMoney()
        local dOwned         = PropSystem.GetCount(def.id)
        -- 每日商店：按槽位独立判断；普通商店：按 prop 级每日限额判断（通常为 nil）
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
        local tier           = GetTierColors(def)

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
                                                -- 同步修正输入框显示（不触发递归）
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
                                                    -- 每日商店：按槽位记录购买，重建分区
                                                    SaveSystem.RecordDailySlotBuy(slotIdx)
                                                    if RebuildDailySection then RebuildDailySection() end
                                                elseif def.dailyLimit then
                                                    SaveSystem.RecordPropDailyBuy(def.id, purchaseQty)
                                                    if RebuildDailySection then RebuildDailySection() end
                                                else
                                                    -- 普通道具只更新数量 label
                                                    local newOwned = PropSystem.GetCount(def.id)
                                                    for key, lbl in pairs(cardCountLabels) do
                                                        if key == def.id or key:sub(1, #def.id) == def.id then
                                                            lbl.text = "×" .. newOwned
                                                        end
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

        currentDialog     = overlay
        activeCloseDialog = CloseDialog
        overlayContainer:AddChild(overlay)
    end

    -- ── 构建卡片网格 ──────────────────────────────────────────
    -- 每日商店时 list 元素为 {def, slotIdx}；普通商店时为 prop def
    local function BuildCards(list, isDaily)
        local cards = {}
        for i, entry in ipairs(list) do
            local p, slotIdx
            if isDaily then
                p       = entry.def
                slotIdx = entry.slotIdx
            else
                p       = entry
                slotIdx = nil
            end
            local count    = PropSystem.GetCount(p.id)
            local labelKey = isDaily and (p.id .. ":" .. i) or p.id
            -- 是否今日已购（每日商店按槽位独立判断）
            local isBought = slotIdx
                and SaveSystem.GetDailySlotBought(slotIdx)
                or false

            -- 已购买遮罩（绝对定位，覆盖整个图标区域，半透明）
            local boughtOverlay = isBought and UI.Panel {
                position = "absolute",
                left = 0, top = 0, right = 0, bottom = 0,
                alignItems = "center", justifyContent = "center",
                opacity = 0.72,
                children = {
                    UI.Panel {
                        position = "absolute",
                        left = 0, top = 0, right = 0, bottom = 0,
                        backgroundImage = "image/task_row_bg_20260516173338.png",
                        backgroundFit = "cover",
                        backgroundColor = { 0, 0, 0, 60 },
                    },
                    UI.Label {
                        text = "已购买",
                        fontSize = sz(14), fontWeight = "bold",
                        fontColor = { 220, 50, 50, 255 },
                    },
                },
            } or nil

            local countLabelOut = {}
            local card = PropCardWidget.ShopCard {
                def           = p,
                count         = count,
                countLabel    = countLabelOut,
                boughtOverlay = boughtOverlay,
                onClick = function()
                    Utils.PlayClick()
                    OpenDialog(p, slotIdx)
                end,
            }
            cardCountLabels[labelKey] = countLabelOut[1]
            cardCountLabels[p.id]     = countLabelOut[1]
            cards[#cards + 1]         = card
        end
        return cards
    end

    -- ── 内容区（道具商店 / 每日商店，通过 display 切换） ────────
    local sectionPanels = {}

    -- 节标题行（左侧"商品"，右侧刷新时间）
    -- 返回 panel；若 showRefresh=true，同时将倒计时 label 引用写入 refreshCountdownLabel
    local function MakeSectionHeader(showRefresh)
        local rightWidget
        if showRefresh then
            local lbl = UI.Label {
                text = DailyShop.GetRefreshText(),
                fontSize = sz(12),
                fontColor = { 120, 160, 220, 200 },
            }
            _refreshLabel = lbl   -- 交给模块级 GameLoop 回调更新
            _refreshAccum = 0.0

            local canRefresh = DailyShop.CanAdRefresh()
            local adBtn = UI.Panel {
                flexDirection = "row", alignItems = "center",
                paddingHorizontal = sz(8), paddingVertical = sz(3),
                backgroundColor = canRefresh and { 35, 70, 150, 180 } or { 30, 30, 36, 100 },
                borderRadius = sz(4),
                borderWidth = 1,
                borderColor = canRefresh and { 70, 120, 210, 180 } or { 45, 45, 55, 80 },
                onClick = canRefresh and function()
                    AdHelper.WatchRewardAd(
                        function()
                            -- 广告看完：执行刷新，重建 dailyList 并刷新 UI
                            DailyShop.DoAdRefresh()
                            local newRaw = DailyShop.GetAdRefreshedItems()
                            -- 清空并重新填充 dailyList（保持槽位索引一致）
                            for i = 1, #dailyList do dailyList[i] = nil end
                            for i, p in ipairs(newRaw) do
                                dailyList[i] = { def = p, slotIdx = i }
                            end
                            if RebuildDailySection then RebuildDailySection() end
                            FloatingMessage.Show("每日商店已刷新")
                        end,
                        function(reason)
                            if reason ~= AdHelper.REASON_USER_CANCEL then
                                FloatingMessage.Show("广告播放失败，请稍后重试")
                            end
                        end
                    )
                end or nil,
                children = {
                    UI.Label {
                        text = canRefresh and "广告刷新" or "今日已刷新",
                        fontSize = sz(11),
                        fontColor = canRefresh and { 150, 195, 255, 220 } or { 70, 70, 80, 140 },
                    },
                },
            }

            rightWidget = UI.Panel {
                flexDirection = "row", alignItems = "center",
                gap = sz(10),
                children = { lbl, adBtn },
            }
        else
            rightWidget = UI.Panel {}
        end

        return UI.Panel {
            width = "100%",
            flexDirection = "row", alignItems = "center",
            paddingLeft = sz(14), paddingRight = sz(16), paddingVertical = sz(8),
            backgroundColor = { 20, 22, 32, 230 },
            borderBottomWidth = 1,
            borderColor = { 50, 55, 70, 150 },
            children = {
                UI.Panel {
                    width = sz(3), height = sz(16),
                    backgroundColor = { 200, 230, 0, 255 },
                    borderRadius = sz(2),
                },
                UI.Panel { width = sz(8) },
                UI.Label {
                    text = "商品",
                    fontSize = sz(14), fontWeight = "bold",
                    fontColor = { 230, 230, 235, 255 },
                },
                UI.Panel { flexGrow = 1 },
                rightWidget,
            },
        }
    end

    local regularCards = BuildCards(regularList, false)
    local dailyCards   = BuildCards(dailyList, true)

    -- 各分区的固定标题栏（放 ScrollView 外，不随内容滚动）
    local regularHeader = MakeSectionHeader(false)
    local dailyHeader   = MakeSectionHeader(true)

    local regularSection = UI.Panel {
        width = "100%",
        flexDirection = "row", flexWrap = "wrap",
        gap = sz(10), padding = sz(12),
        children = regularCards,
    }

    local dailySection = UI.Panel {
        width = "100%",
        flexDirection = "row", flexWrap = "wrap",
        gap = sz(10), padding = sz(12),
        children = dailyCards,
    }

    -- ── 商城分区（点券购买仓库指定券 + 藏品礼盒 + 金色/红色道具） ──
    -- 仓库指定券固定顺序
    local MALL_TICKET_ORDER = {
        "ticket_suburb",
        "ticket_industrial",
        "ticket_commercial",
        "ticket_port",
        "ticket_techpark",
        "ticket_culture",
        "ticket_deepsea",
        "ticket_private",
    }
    -- 礼盒固定顺序
    local MALL_CHEST_ORDER = { "chest_common", "chest_silver", "chest_gold" }

    -- 筛选 Tab 定义
    local MALL_TABS = {
        { id = "all",    label = "全部" },
        { id = "ticket", label = "票券" },
        { id = "chest",  label = "礼盒" },
        { id = "gold",   label = "金色道具" },
        { id = "red",    label = "红色道具" },
    }
    local mallActiveTab = "all"

    -- 构建所有商城道具数据（返回含 category 标记的列表）
    local function BuildMallItems()
        local items = {}
        local ptBalance = SaveSystem.GetPointTickets()

        -- ① 票券
        for _, ticketId in ipairs(MALL_TICKET_ORDER) do
            local def = Config.TICKETS[ticketId]
            if def and def.ticketPrice then
                local price = def.ticketPrice
                -- 构造兼容 ShopCard 的 fakeDef（票券用白色品质外壳）
                local fakeDef = {
                    id        = ticketId,
                    name      = def.name,
                    desc      = "解锁对应区域仓库拍卖的限定入场券",
                    icon      = "🎫",
                    iconImage = def.icon,
                    tier      = "white",
                    price     = price,
                }
                items[#items + 1] = {
                    category = "ticket",
                    fakeDef  = fakeDef,
                    price    = price,
                    canAfford= ptBalance >= price,
                    getCount = function() return SaveSystem.GetTicketCount(ticketId) end,
                    onBuy    = function(qty) SaveSystem.AddTickets(ticketId, qty) end,
                }
            end
        end

        -- ② 礼盒
        for _, chestId in ipairs(MALL_CHEST_ORDER) do
            local def = Chests.BY_ID[chestId]
            if def and def.ticketPrice then
                local price = def.ticketPrice
                local fakeDef = {
                    id        = chestId,
                    name      = def.name,
                    desc      = def.desc or "随机开出十种品类藏品之一",
                    icon      = "🎁",
                    iconImage = def.iconImage or "",
                    tier      = def.tier or "white",
                    price     = price,
                }
                items[#items + 1] = {
                    category = "chest",
                    fakeDef  = fakeDef,
                    price    = price,
                    canAfford= ptBalance >= price,
                    getCount = function() return SaveSystem.GetPropCount(chestId) end,
                    onBuy    = function(qty) SaveSystem.AddProp(chestId, qty) end,
                }
            end
        end

        -- ③ 金色道具
        for _, p in ipairs(Props.LIST) do
            if p.tier == "gold" and p.mallPrice then
                local price = p.mallPrice
                items[#items + 1] = {
                    category = "gold",
                    fakeDef  = p,
                    price    = price,
                    canAfford= ptBalance >= price,
                    getCount = function() return SaveSystem.GetPropCount(p.id) end,
                    onBuy    = function(qty) SaveSystem.AddProp(p.id, qty) end,
                }
            end
        end

        -- ④ 红色道具
        for _, p in ipairs(Props.LIST) do
            if p.tier == "red" and p.mallPrice then
                local price = p.mallPrice
                items[#items + 1] = {
                    category = "red",
                    fakeDef  = p,
                    price    = price,
                    canAfford= ptBalance >= price,
                    getCount = function() return SaveSystem.GetPropCount(p.id) end,
                    onBuy    = function(qty) SaveSystem.AddProp(p.id, qty) end,
                }
            end
        end

        return items
    end

    -- 将一个商城 item 渲染为卡片
    -- 对局内道具（gold/red）用 ShopCard（六边形），票券/礼盒用简单图片卡
    local function MallItemCard(item)
        local def        = item.fakeDef
        local isGameProp = def.inGame == true
        local ptIcon     = "image/point_ticket_icon_20260518210650.png"
        local priceColor = item.canAfford
            and { 100, 220, 255, 255 } or { 150, 150, 155, 200 }

        local function onClickHandler()
            Utils.PlayClick()
            local tc = PropCardWidget.TIER_COLORS[def.tier] or PropCardWidget.TIER_COLORS.white
            OpenMallDialog {
                name        = def.name,
                icon        = def.iconImage or "",
                iconText    = def.icon,
                desc        = def.desc or "",
                price       = item.price,
                canAfford   = item.canAfford,
                isGameProp  = isGameProp,
                tier        = def.tier,
                cardBg      = tc.cardBg,
                cardBorder  = tc.cardBorder,
                headerBg    = tc.headerBg,
                headerText  = tc.headerText,
                getCount    = item.getCount,
                onBuy       = item.onBuy,
            }
        end

        -- 对局内道具：用 ShopCard（带六边形）
        if isGameProp then
            return PropCardWidget.ShopCard {
                def    = def,
                count  = item.getCount(),
                width  = "31.5%",
                priceOverride = {
                    price     = item.price,
                    icon      = ptIcon,
                    fontColor = priceColor,
                },
                onClick = onClickHandler,
            }
        end

        -- 票券 / 礼盒：简单图片卡（无六边形）
        -- padding/fontSize 与 ShopCard 对齐，保证同行等高
        local count = item.getCount()
        return UI.Panel {
            width = "31.5%",
            flexDirection = "column",
            backgroundColor = { 28, 30, 40, 255 },
            borderWidth = 1,
            borderColor = { 55, 60, 78, 180 },
            overflow = "hidden",
            cursor = "pointer",
            onClick = onClickHandler,
            children = {
                -- 名称条
                UI.Panel {
                    width = "100%",
                    paddingVertical = sz(6), paddingHorizontal = sz(10),
                    backgroundColor = { 38, 40, 52, 255 },
                    children = {
                        UI.Label {
                            text = def.name,
                            fontSize = sz(12), fontWeight = "bold",
                            fontColor = { 220, 222, 230, 255 },
                            numberOfLines = 1,
                        },
                    },
                },
                -- 图片区
                UI.Panel {
                    width = "100%",
                    height = sz(90),
                    alignItems = "center", justifyContent = "center",
                    padding = sz(8),
                    children = {
                        def.iconImage ~= "" and UI.Panel {
                            width = "80%", height = "80%",
                            backgroundImage = def.iconImage,
                            backgroundFit = "contain",
                            pointerEvents = "none",
                        } or UI.Label {
                            text = def.icon or "?",
                            fontSize = sz(36),
                            pointerEvents = "none",
                        },
                        -- 数量角标（右下）
                        UI.Panel {
                            position = "absolute", right = sz(6), bottom = sz(4),
                            pointerEvents = "none",
                            children = {
                                UI.Label {
                                    text = "×" .. count,
                                    fontSize = sz(12),
                                    fontColor = { 180, 185, 195, 220 },
                                },
                            },
                        },
                    },
                },
                -- 价格底栏（与 ShopCard 对齐：paddingVertical sz(6)、icon 16×16、fontSize sz(13)）
                UI.Panel {
                    width = "100%",
                    flexDirection = "row", alignItems = "center", justifyContent = "center",
                    gap = sz(4),
                    paddingVertical = sz(6), paddingHorizontal = sz(10),
                    backgroundColor = { 22, 24, 34, 255 },
                    borderTopWidth = 1, borderColor = { 55, 60, 78, 180 },
                    children = {
                        UI.Panel {
                            width = sz(16), height = sz(16),
                            backgroundImage = ptIcon,
                            backgroundFit = "contain",
                        },
                        UI.Label {
                            text = tostring(item.price),
                            fontSize = sz(13), fontWeight = "bold",
                            fontColor = priceColor,
                        },
                    },
                },
            },
        }
    end

    -- 卡片容器（Tab 切换时替换 children）
    ---@type any
    local mallGridPanel = nil

    local function BuildMallGrid(tabId)
        local allItems = BuildMallItems()
        local filtered = {}
        for _, item in ipairs(allItems) do
            if tabId == "all" or item.category == tabId then
                filtered[#filtered + 1] = item
            end
        end
        local cards = {}
        for _, item in ipairs(filtered) do
            cards[#cards + 1] = MallItemCard(item)
        end
        return cards
    end

    -- Tab 引用列表（用于切换高亮）
    local mallTabRefs = {}

    -- 刷新当前 Tab 的商城卡片（购买后调用）
    RefreshMallGrid = function()
        if mallGridPanel then
            local newCards = BuildMallGrid(mallActiveTab)
            mallGridPanel:RemoveAllChildren()
            for _, card in ipairs(newCards) do
                mallGridPanel:AddChild(card)
            end
        end
    end

    local function SwitchMallTab(tabId)
        if mallActiveTab == tabId then return end
        mallActiveTab = tabId
        -- 更新 Tab 高亮
        for _, ref in ipairs(mallTabRefs) do
            local isActive = ref.id == tabId
            ref.panel.props.backgroundColor = isActive
                and { 60, 130, 200, 240 } or { 28, 32, 44, 200 }
            ref.lbl.props.fontColor = isActive
                and { 255, 255, 255, 255 } or { 160, 165, 180, 200 }
        end
        -- 重建卡片网格
        RefreshMallGrid()
    end

    -- 构建 Tab 栏
    local tabBarChildren = {}
    for _, tab in ipairs(MALL_TABS) do
        local isActive = tab.id == mallActiveTab
        local lbl = UI.Label {
            text      = tab.label,
            fontSize  = sz(11), fontWeight = isActive and "bold" or "normal",
            fontColor = isActive and { 255, 255, 255, 255 } or { 160, 165, 180, 200 },
        }
        local tabPanel = UI.Panel {
            paddingHorizontal = sz(10), paddingVertical = sz(6),
            backgroundColor   = isActive and { 60, 130, 200, 240 } or { 28, 32, 44, 200 },
            borderRadius      = sz(4),
            cursor            = "pointer",
            onClick           = function() SwitchMallTab(tab.id) end,
            children          = { lbl },
        }
        mallTabRefs[#mallTabRefs + 1] = { id = tab.id, panel = tabPanel, lbl = lbl }
        tabBarChildren[#tabBarChildren + 1] = tabPanel
    end

    mallGridPanel = UI.Panel {
        width = "100%",
        flexDirection = "row", flexWrap = "wrap",
        gap = sz(10), padding = sz(12),
        children = BuildMallGrid(mallActiveTab),
    }

    -- 商城固定标题（标题行 + Tab 筛选栏，放 ScrollView 外不随内容滚动）
    local mallHeader = UI.Panel {
        width = "100%",
        flexDirection = "column",
        children = {
            -- 标题行
            UI.Panel {
                width = "100%",
                flexDirection = "row", alignItems = "center",
                paddingLeft = sz(14), paddingRight = sz(16), paddingVertical = sz(8),
                backgroundColor = { 20, 22, 32, 230 },
                borderBottomWidth = 1,
                borderColor = { 50, 55, 70, 150 },
                children = {
                    UI.Panel { width = sz(3), height = sz(16), backgroundColor = { 100, 210, 255, 255 }, borderRadius = sz(2) },
                    UI.Panel { width = sz(8) },
                    UI.Label { text = "商城", fontSize = sz(14), fontWeight = "bold", fontColor = { 230, 230, 235, 255 } },
                },
            },
            -- 筛选 Tab 栏
            UI.Panel {
                width = "100%",
                flexDirection = "row", flexWrap = "wrap",
                gap = sz(6), paddingHorizontal = sz(12), paddingVertical = sz(8),
                backgroundColor = { 18, 20, 30, 220 },
                borderBottomWidth = 1,
                borderColor = { 45, 50, 65, 150 },
                children = tabBarChildren,
            },
        },
    }

    -- 商城滚动区域（只含卡片网格）
    local mallSection = mallGridPanel

    sectionPanels = { regularSection, dailySection, mallSection }

    -- 各分区对应的固定 header（与 sectionPanels 索引对齐）
    local sectionHeaders = { regularHeader, dailyHeader, mallHeader }

    -- 固定 header 容器（放在 ScrollView 上方，不随内容滚动）
    ---@type any
    local sectionHeaderContainer = UI.Panel {
        width = "100%",
        children = { regularHeader },
    }

    -- 内容容器：每次只挂载当前分区（AddChild/RemoveChild 切换）
    local contentContainer = UI.Panel {
        width = "100%",
        flexDirection = "column",
        children = { regularSection },
    }

    -- 实现前向声明：购买每日道具后重建每日分区（排序+遮罩+数量全部刷新）
    RebuildDailySection = function()
        -- 重新排序，已购买槽位排末尾（按槽位独立判断）
        table.sort(dailyList, function(a, b)
            local aBought = SaveSystem.GetDailySlotBought(a.slotIdx)
            local bBought = SaveSystem.GetDailySlotBought(b.slotIdx)
            if aBought == bBought then return false end
            return not aBought
        end)
        -- 清空旧的 daily label 引用，避免指向已销毁的 widget
        for k in pairs(cardCountLabels) do
            if type(k) == "string" and k:find(":") then
                cardCountLabels[k] = nil
            end
        end
        local newDailyCards = BuildCards(dailyList, true)
        local newDailySection = UI.Panel {
            width = "100%",
            flexDirection = "row", flexWrap = "wrap",
            gap = sz(10), padding = sz(12),
            children = newDailyCards,
        }
        -- 重建固定标题（广告刷新后 canRefresh 状态变化）
        local newDailyHeader = MakeSectionHeader(true)
        -- 若当前正显示每日商店，替换 contentContainer 中的 grid 及固定 header
        if activeSection == 2 then
            contentContainer:RemoveChild(sectionPanels[2])
            contentContainer:AddChild(newDailySection)
            sectionHeaderContainer:RemoveChild(sectionHeaders[2])
            sectionHeaderContainer:AddChild(newDailyHeader)
        end
        sectionPanels[2]  = newDailySection
        sectionHeaders[2] = newDailyHeader
        dailyHeader = newDailyHeader
    end

    -- ── 左侧边栏（道具商店 / 每日商店 可点击切换） ─────────────
    -- 每个入口持有需要更新的子组件引用：{ panel, bar, label }
    local sidebarEntries = {
        { label = "道具商店" },
        { label = "每日商店" },
        { label = "商城" },
    }

    -- 存储各侧边栏入口的可更新引用
    local sidebarRefs = {}  -- [i] = { panel=, bar=, lbl= }

    local function SwitchSection(idx)
        if activeSection == idx then return end
        -- 移除旧分区，挂载新分区（grid 内容）
        contentContainer:RemoveChild(sectionPanels[activeSection])
        contentContainer:AddChild(sectionPanels[idx])
        -- 切换固定 header
        sectionHeaderContainer:RemoveChild(sectionHeaders[activeSection])
        sectionHeaderContainer:AddChild(sectionHeaders[idx])
        activeSection = idx
        -- 更新侧边栏高亮
        for i, ref in ipairs(sidebarRefs) do
            local isActive = (i == idx)
            ref.panel.props.backgroundColor = isActive and { 200, 230, 0, 255 } or { 60, 62, 70, 180 }
            ref.bar.props.backgroundColor   = isActive and { 255, 255, 255, 255 } or { 0, 0, 0, 0 }
            ref.lbl.props.fontColor         = isActive and { 10, 10, 10, 255 } or { 180, 180, 185, 220 }
        end
    end

    -- 构建可切换的侧边栏项（直接持有子组件引用）
    local sidebarItemWidgets = {}
    for i, entry in ipairs(sidebarEntries) do
        local isActive = (i == activeSection)
        local barWidget = UI.Panel {
            width = sz(4), flexShrink = 0,
            backgroundColor = isActive and { 255, 255, 255, 255 } or { 0, 0, 0, 0 },
        }
        local lblWidget = UI.Label {
            text = entry.label,
            fontSize = sz(14), fontWeight = "bold",
            fontColor = isActive and { 10, 10, 10, 255 } or { 180, 180, 185, 220 },
        }
        local itemPanel = UI.Panel {
            width = "100%",
            flexDirection = "row", alignItems = "stretch",
            borderRadius = sz(4), overflow = "hidden",
            backgroundColor = isActive and { 200, 230, 0, 255 } or { 60, 62, 70, 180 },
            cursor = "pointer",
            onClick = function()
                Utils.PlayClick()
                SwitchSection(i)
            end,
            children = {
                barWidget,
                UI.Panel {
                    flexGrow = 1,
                    paddingVertical = sz(12), paddingLeft = sz(12), paddingRight = sz(10),
                    children = { lblWidget },
                },
            },
        }
        sidebarRefs[i] = { panel = itemPanel, bar = barWidget, lbl = lblWidget }
        sidebarItemWidgets[i] = itemPanel
    end

    -- 构建侧边栏子节点列表（仅道具商店和每日商店）
    local sidebarChildren = {}
    for _, w in ipairs(sidebarItemWidgets) do
        sidebarChildren[#sidebarChildren + 1] = w
    end
    sidebarChildren[#sidebarChildren + 1] = UI.Panel { flexGrow = 1 }
    sidebarChildren[#sidebarChildren + 1] = UI.Panel {
        width = "100%",
        paddingHorizontal = sz(8), paddingVertical = sz(9),
        children = {
            UI.Button {
                text = "返回",
                width = "100%", paddingVertical = sz(7),
                fontSize = sz(13), fontWeight = "bold",
                fontColor = { 195, 215, 40, 230 },
                backgroundColor = { 195, 215, 40, 20 },
                hoverBackgroundColor = { 195, 215, 40, 50 },
                pressedBackgroundColor = { 195, 215, 40, 110 },
                borderWidth = 1, borderColor = { 195, 215, 40, 160 },
                borderRadius = 0,
                onClick = function()
                    Utils.PlayClick()
                    CloseDialog()
                    if onBackCallback then onBackCallback() end
                end,
            },
        },
    }

    local sidebar = UI.Panel {
        width = sz(140), flexShrink = 0,
        flexDirection = "column",
        paddingTop = sz(4), paddingHorizontal = sz(8), gap = sz(4),
        children = sidebarChildren,
    }

    -- ── 主内容区 ─────────────────────────────────────────────
    local mainArea = UI.Panel {
        flexGrow = 1, flexShrink = 1,
        flexDirection = "column",
        children = {
            -- 固定标题栏（不随内容滚动）
            sectionHeaderContainer,
            -- 可滚动的卡片网格
            UI.ScrollView {
                width = "100%", flexGrow = 1,
                children = { contentContainer },
            },
        },
    }

    -- ── 顶栏 ─────────────────────────────────────────────────
    -- 资产弹窗（挂到 overlayContainer，点击金币/点券时打开）
    local assetPopupVisible = false
    local assetPopup = nil

    local topBarMoneyLabel  = nil
    local topBarTicketLabel = nil

    local function refreshAssetPopup()
        if not assetPopup then return end
        local ml = assetPopup:FindById("tb_popup_money")
        if ml then ml:SetText(Utils.FormatMoneyExact(MoneyHUD.GetMoney())) end
        local tl = assetPopup:FindById("tb_popup_tickets")
        if tl then tl:SetText(tostring(SaveSystem.GetPointTickets())) end
    end

    local function hideAssetPopup()
        if assetPopup then
            assetPopup:SetVisible(false)
            assetPopupVisible = false
        end
    end

    local function toggleAssetPopup()
        if not assetPopup then return end
        assetPopupVisible = not assetPopupVisible
        if assetPopupVisible then refreshAssetPopup() end
        assetPopup:SetVisible(assetPopupVisible)
    end

    -- 构建资产弹窗（稍后加入 overlayContainer）
    local function buildAssetPopup()
        local watchAdBtnRef = nil
        local watchAdAmtRef = nil
        local popupContent = UI.Panel {
            width = sz(280),
            backgroundColor = { 30, 33, 48, 245 },
            borderRadius = sz(8), borderWidth = 1,
            borderColor = { 80, 85, 110, 180 },
            padding = sz(16), gap = sz(12),
            flexDirection = "column",
            onClick = function() end,
            children = {
                UI.Label {
                    text = "我的资产", fontSize = sz(16), fontWeight = "bold",
                    fontColor = { 255, 220, 100, 255 },
                    textAlign = "center", width = "100%",
                },
                UI.Panel { width = "100%", height = 1, backgroundColor = { 80, 85, 110, 120 } },
                -- 金币行
                UI.Panel {
                    width = "100%", flexDirection = "row",
                    justifyContent = "space-between", alignItems = "center",
                    children = {
                        UI.Panel {
                            flexDirection = "row", alignItems = "center", gap = sz(6),
                            children = {
                                UI.Panel { width = sz(20), height = sz(20), backgroundImage = Utils.GetIcon("coin"), backgroundFit = "contain", flexShrink = 0 },
                                UI.Label { text = "金币", fontSize = sz(13), fontColor = { 200, 205, 220, 255 } },
                            },
                        },
                        UI.Label { id = "tb_popup_money", text = Utils.FormatMoneyExact(MoneyHUD.GetMoney()), fontSize = sz(14), fontWeight = "bold", fontColor = { 255, 220, 100, 255 } },
                    },
                },
                -- 点券行
                UI.Panel {
                    width = "100%", flexDirection = "row",
                    justifyContent = "space-between", alignItems = "center",
                    children = {
                        UI.Panel {
                            flexDirection = "row", alignItems = "center", gap = sz(6),
                            children = {
                                UI.Panel { width = sz(20), height = sz(20), backgroundImage = "image/point_ticket_icon_20260518210650.png", backgroundFit = "contain", flexShrink = 0 },
                                UI.Label { text = "点券", fontSize = sz(13), fontColor = { 200, 205, 220, 255 } },
                            },
                        },
                        UI.Label { id = "tb_popup_tickets", text = tostring(SaveSystem.GetPointTickets()), fontSize = sz(14), fontWeight = "bold", fontColor = { 120, 210, 255, 255 } },
                    },
                },
                UI.Panel { width = "100%", height = 1, backgroundColor = { 80, 85, 110, 120 } },
                -- 看广告按钮
                (function()
                    local watchAdAmountLabel = UI.Label { text = "", fontSize = sz(13), fontWeight = "bold", fontColor = { 20, 20, 20, 255 } }
                    watchAdAmtRef = watchAdAmountLabel
                    local btn = UI.Button {
                        width = "100%", height = sz(36), variant = "primary",
                        onClick = function()
                            Utils.PlayClick()
                            hideAssetPopup()
                            local AdCardPanel = require("UI.AdCardPanel")
                            if AdCardPanel.CanWatchAd() then AdCardPanel.WatchAd() end
                        end,
                        children = {
                            UI.Panel {
                                flexDirection = "row", alignItems = "center", gap = sz(4),
                                justifyContent = "center", width = "100%", height = "100%",
                                children = {
                                    UI.Label { text = "看广告", fontSize = sz(13), fontWeight = "bold", fontColor = { 20, 20, 20, 255 } },
                                    UI.Panel { width = sz(16), height = sz(16), backgroundImage = Utils.GetIcon("coin"), backgroundFit = "contain", flexShrink = 0 },
                                    watchAdAmountLabel,
                                    UI.Panel { width = sz(16), height = sz(16), backgroundImage = "image/point_ticket_icon_20260518210650.png", backgroundFit = "contain", flexShrink = 0 },
                                    UI.Label { text = "×10", fontSize = sz(11), fontColor = { 20, 20, 20, 255 } },
                                },
                            },
                        },
                    }
                    watchAdBtnRef = btn
                    return btn
                end)(),
                -- 关闭按钮
                UI.Button {
                    text = "关闭", width = "100%", height = sz(36), fontSize = sz(13),
                    onClick = function() Utils.PlayClick(); hideAssetPopup() end,
                },
            },
        }
        -- 刷新广告按钮文字
        local ok, AdCardPanel = pcall(require, "UI.AdCardPanel")
        if ok and watchAdAmtRef then
            local tier = AdCardPanel.GetCurrentTier and AdCardPanel.GetCurrentTier()
            if tier and tier.coinsPerAd then
                watchAdAmtRef:SetText("+" .. Utils.FormatMoney(tier.coinsPerAd))
            end
            if watchAdBtnRef then
                watchAdBtnRef:SetDisabled(not AdCardPanel.CanWatchAd())
            end
        end

        assetPopup = UI.Panel {
            position = "absolute", left = 0, top = 0, width = "100%", height = "100%",
            backgroundColor = { 0, 0, 0, 150 },
            justifyContent = "center", alignItems = "center",
            visible = false,
            onClick = function() hideAssetPopup() end,
            children = {
                UI.Panel { justifyContent = "center", alignItems = "center", children = { popupContent } },
            },
        }
        return assetPopup
    end

    local myMoney = MoneyHUD.GetMoney()
    topBar = UI.Panel {
        width = "100%", height = sz(50),
        flexDirection = "row", alignItems = "center",
        paddingHorizontal = sz(16),
        borderBottomWidth = 1, borderColor = { 50, 55, 70, 100 },
        children = {
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = sz(10),
                children = {
                    UI.Panel {
                        width = sz(26), height = sz(26),
                        backgroundImage = "image/icon_cart.png",
                        backgroundFit = "contain",
                    },
                    UI.Panel { width = 1, height = sz(20), backgroundColor = { 180, 185, 200, 80 } },
                    UI.Label {
                        text = "商店",
                        fontSize = sz(18), fontWeight = "bold",
                        fontColor = { 240, 235, 220, 255 },
                    },
                },
            },
            UI.Panel { flexGrow = 1 },
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = sz(8),
                children = {
                    -- 金币
                    UI.Panel {
                        flexDirection = "row", alignItems = "center",
                        gap = sz(6), paddingHorizontal = sz(10), paddingVertical = sz(5),
                        backgroundColor = { 0, 0, 0, 120 },
                        borderRadius = sz(14), borderWidth = 1,
                        borderColor = { 100, 80, 20, 150 },
                        cursor = "pointer",
                        onClick = function() Utils.PlayClick(); toggleAssetPopup() end,
                        children = {
                            CoinIcon(sz(18)),
                            UI.Label {
                                text = Utils.FormatMoney(myMoney),
                                fontSize = sz(14), fontWeight = "bold",
                                fontColor = { 255, 215, 55, 255 },
                            },
                        },
                    },
                    -- 点券
                    UI.Panel {
                        flexDirection = "row", alignItems = "center",
                        gap = sz(6), paddingHorizontal = sz(10), paddingVertical = sz(5),
                        backgroundColor = { 0, 0, 0, 120 },
                        borderRadius = sz(14), borderWidth = 1,
                        borderColor = { 40, 120, 180, 150 },
                        cursor = "pointer",
                        onClick = function() Utils.PlayClick(); toggleAssetPopup() end,
                        children = {
                            UI.Panel {
                                width = sz(16), height = sz(16),
                                backgroundImage = "image/point_ticket_icon_20260518210650.png",
                                backgroundFit = "contain", flexShrink = 0,
                            },
                            UI.Label {
                                id = "topbar_ticket_label",
                                text = tostring(SaveSystem.GetPointTickets()),
                                fontSize = sz(14), fontWeight = "bold",
                                fontColor = { 100, 210, 255, 255 },
                            },
                        },
                    },
                    UI.Panel {
                        width = sz(34), height = sz(34),
                        borderRadius = sz(4),
                        backgroundColor = { 40, 42, 55, 200 },
                        borderWidth = 1, borderColor = { 70, 75, 90, 180 },
                        alignItems = "center", justifyContent = "center",
                        cursor = "pointer",
                        onClick = function()
                            Utils.PlayClick()
                            CloseDialog()
                            if onBackCallback then onBackCallback() end
                        end,
                        children = {
                            UI.Label {
                                text = "✕", fontSize = sz(18), fontWeight = "bold",
                                fontColor = { 180, 220, 0, 230 },
                            },
                        },
                    },
                },
            },
        },
    }

    -- 构建并挂入资产弹窗
    overlayContainer:AddChild(buildAssetPopup())

    -- 关闭屏幕时停止倒计时更新（清空模块级引用）
    local _origBack = onBackCallback
    onBackCallback = function()
        _refreshLabel = nil
        if _origBack then _origBack() end
    end

    -- ── 整体布局 ─────────────────────────────────────────────
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = {
            UI.Panel {
                width = "100%", height = "100%",
                children = {
                    UI.Panel {
                        width = "100%", height = "100%",
                        backgroundImage = "image/prop_shop_bg.jpg",
                        backgroundFit = "cover",
                        children = {
                            UI.Panel {
                                position = "absolute",
                                left = 0, top = 0, right = 0, bottom = 0,
                                backdropBlur = 60,
                                backgroundColor = { 8, 10, 20, 100 },
                            },
                            UI.Panel {
                                width = "100%", height = "100%",
                                flexDirection = "column",
                                children = {
                                    topBar,
                                    UI.Panel {
                                        width = "100%", flexGrow = 1,
                                        flexDirection = "row",
                                        children = { sidebar, mainArea },
                                    },
                                },
                            },
                        },
                    },
                    overlayContainer,
                },
            },
        },
    })
end

return PropScreen
