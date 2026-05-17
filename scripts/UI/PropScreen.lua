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
local Props = require("Config.Props")
local PropSystem = require("PropSystem")
local MoneyManager = require("MoneyManager")
local MoneyHUD = require("UI.MoneyHUD")
local DailyShop = require("DailyShop")
local GameLoop = require("GameLoop")

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

-- ============================================================================
-- 价格层级颜色映射（white/green/blue/purple）
-- ============================================================================

local TIER_COLORS = {
    white = {
        headerBg   = { 75, 78, 88, 255 },
        headerText = { 210, 212, 220, 255 },
        cardBg     = { 34, 36, 44, 255 },
        cardBorder = { 65, 68, 78, 180 },
        priceBg    = { 28, 30, 38, 255 },
        hexTint    = nil,
        accent     = { 200, 205, 215, 255 },
    },
    green = {
        headerBg   = { 30, 110, 65, 255 },
        headerText = { 190, 255, 210, 255 },
        cardBg     = { 22, 38, 30, 255 },
        cardBorder = { 40, 100, 65, 200 },
        priceBg    = { 18, 32, 26, 255 },
        hexTint    = { 80, 230, 120, 255 },
        accent     = { 80, 230, 120, 255 },
    },
    blue = {
        headerBg   = { 25, 80, 155, 255 },
        headerText = { 190, 220, 255, 255 },
        cardBg     = { 18, 30, 55, 255 },
        cardBorder = { 40, 85, 170, 200 },
        priceBg    = { 14, 24, 46, 255 },
        hexTint    = { 80, 160, 255, 255 },
        accent     = { 100, 175, 255, 255 },
    },
    purple = {
        headerBg   = { 85, 35, 130, 255 },
        headerText = { 230, 200, 255, 255 },
        cardBg     = { 28, 18, 42, 255 },
        cardBorder = { 100, 50, 155, 200 },
        priceBg    = { 22, 14, 35, 255 },
        hexTint    = { 200, 100, 255, 255 },
        accent     = { 200, 100, 255, 255 },
    },
}

local function GetTierColors(def)
    return TIER_COLORS[def.tier] or TIER_COLORS.white
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
    local regularList = {}
    for _, p in ipairs(Props.LIST) do
        if not p.dailyShop then
            regularList[#regularList + 1] = p
        end
    end

    -- 每日商店：使用 DailyShop 模块动态生成12个道具，已购买的排到最后
    local dailyList = DailyShop.GetTodayItems()
    table.sort(dailyList, function(a, b)
        local aBought = a.dailyLimit and (SaveSystem.GetPropDailyBought(a.id) >= a.dailyLimit) or false
        local bBought = b.dailyLimit and (SaveSystem.GetPropDailyBought(b.id) >= b.dailyLimit) or false
        if aBought == bBought then return false end
        return not aBought  -- 未购买的排前面
    end)

    -- 当前激活的分类：1=道具商店  2=每日商店
    local activeSection = 1

    -- 存储各卡片的数量 Label（propId+index 混合键 → label widget）
    local cardCountLabels = {}

    -- 前向声明：每日商店购买后重建分区（定义在 sectionPanels/contentContainer 之后）
    local RebuildDailySection

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

    -- ── 购买弹窗 ─────────────────────────────────────────────
    local function OpenDialog(def)
        CloseDialog()
        if not def then return end

        local dMoney         = MoneyHUD.GetMoney()
        local dOwned         = PropSystem.GetCount(def.id)
        local dDailyLimit    = def.dailyLimit
        local dDailyBought   = dDailyLimit and SaveSystem.GetPropDailyBought(def.id) or 0
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
                                                if def.dailyLimit then
                                                    SaveSystem.RecordPropDailyBuy(def.id, purchaseQty)
                                                    -- 重建每日商店：刷新排序、遮罩、数量
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
    -- labelKeySuffix：每日商店中同一道具可能多次出现，加 index 做唯一键
    local function BuildCards(list, labelKeySuffix)
        local cards = {}
        for i, p in ipairs(list) do
            local count       = PropSystem.GetCount(p.id)
            local tier        = GetTierColors(p)
            local labelKey    = labelKeySuffix and (p.id .. ":" .. i) or p.id
            -- 是否今日已购
            local isBought = p.dailyLimit
                and (SaveSystem.GetPropDailyBought(p.id) >= p.dailyLimit)
                or false

            local countLbl = UI.Label {
                text = "×" .. count,
                fontSize = sz(12),
                fontColor = { 180, 185, 195, 220 },
            }
            cardCountLabels[labelKey] = countLbl
            cardCountLabels[p.id] = countLbl

            -- 已购买遮罩（绝对定位，覆盖整个图标区域，半透明）
            local boughtOverlay = isBought and UI.Panel {
                position = "absolute",
                left = 0, top = 0, right = 0, bottom = 0,
                alignItems = "center", justifyContent = "center",
                opacity = 0.72,
                children = {
                    -- 纹理背景（半透明）
                    UI.Panel {
                        position = "absolute",
                        left = 0, top = 0, right = 0, bottom = 0,
                        backgroundImage = "image/task_row_bg_20260516173338.png",
                        backgroundFit = "cover",
                        backgroundColor = { 0, 0, 0, 60 },
                    },
                    -- 已购买文字
                    UI.Label {
                        text = "已购买",
                        fontSize = sz(14), fontWeight = "bold",
                        fontColor = { 220, 50, 50, 255 },
                    },
                },
            } or nil

            cards[#cards + 1] = UI.Panel {
                width = "31.5%",
                flexDirection = "column",
                backgroundColor = tier.cardBg,
                borderWidth = 1, borderColor = tier.cardBorder,
                overflow = "hidden",
                cursor = "pointer",
                onClick = function()
                    Utils.PlayClick()
                    OpenDialog(p)
                end,
                children = {
                    -- 名称条
                    UI.Panel {
                        width = "100%",
                        paddingVertical = sz(6), paddingHorizontal = sz(10),
                        backgroundColor = tier.headerBg,
                        children = {
                            UI.Label {
                                text = p.name,
                                fontSize = sz(12), fontWeight = "bold",
                                fontColor = tier.headerText,
                            },
                        },
                    },
                    -- 图标区域
                    UI.Panel {
                        width = "100%", height = sz(90),
                        alignItems = "center", justifyContent = "center",
                        children = (function()
                            local children = {
                                UI.Panel {
                                    width = sz(70), height = sz(70),
                                    alignItems = "center", justifyContent = "center",
                                    children = {
                                        UI.Panel {
                                            position = "absolute",
                                            width = sz(61), height = sz(70),
                                            backgroundImage = "image/ui_hex_frame_trimmed.png",
                                            backgroundFit = "fill",
                                            imageTint = tier.hexTint,
                                        },
                                        p.iconImage
                                            and UI.Panel {
                                                width = sz(36), height = sz(36),
                                                backgroundImage = p.iconImage,
                                                backgroundFit = "contain",
                                            }
                                            or UI.Label { text = p.icon, fontSize = sz(26) },
                                    },
                                },
                                UI.Panel {
                                    position = "absolute",
                                    right = sz(12), bottom = sz(4),
                                    children = { countLbl },
                                },
                            }
                            if boughtOverlay then
                                children[#children + 1] = boughtOverlay
                            end
                            return children
                        end)(),
                    },
                    -- 价格底栏
                    UI.Panel {
                        width = "100%",
                        paddingVertical = sz(6), paddingHorizontal = sz(10),
                        backgroundColor = tier.priceBg,
                        borderTopWidth = 1, borderColor = tier.cardBorder,
                        flexDirection = "row", alignItems = "center", justifyContent = "center",
                        gap = sz(4),
                        children = {
                            CoinIcon(sz(16)),
                            UI.Label {
                                text = Utils.FormatMoney(p.price),
                                fontSize = sz(13), fontWeight = "bold",
                                fontColor = { 220, 200, 120, 255 },
                            },
                        },
                    },
                },
            }
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
            rightWidget = lbl
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

    local regularSection = UI.Panel {
        width = "100%",
        flexDirection = "column",
        children = {
            MakeSectionHeader(false),
            UI.Panel {
                width = "100%",
                flexDirection = "row", flexWrap = "wrap",
                gap = sz(10), padding = sz(12),
                children = regularCards,
            },
        },
    }

    local dailySection = UI.Panel {
        width = "100%",
        flexDirection = "column",
        children = {
            MakeSectionHeader(true),
            UI.Panel {
                width = "100%",
                flexDirection = "row", flexWrap = "wrap",
                gap = sz(10), padding = sz(12),
                children = dailyCards,
            },
        },
    }

    sectionPanels = { regularSection, dailySection }

    -- 内容容器：每次只挂载当前分区（AddChild/RemoveChild 切换）
    local contentContainer = UI.Panel {
        width = "100%",
        flexDirection = "column",
        children = { regularSection },
    }

    -- 实现前向声明：购买每日道具后重建每日分区（排序+遮罩+数量全部刷新）
    RebuildDailySection = function()
        -- 重新排序，已购买排末尾
        table.sort(dailyList, function(a, b)
            local aBought = a.dailyLimit and (SaveSystem.GetPropDailyBought(a.id) >= a.dailyLimit) or false
            local bBought = b.dailyLimit and (SaveSystem.GetPropDailyBought(b.id) >= b.dailyLimit) or false
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
            flexDirection = "column",
            children = {
                MakeSectionHeader(true),
                UI.Panel {
                    width = "100%",
                    flexDirection = "row", flexWrap = "wrap",
                    gap = sz(10), padding = sz(12),
                    children = newDailyCards,
                },
            },
        }
        -- 若当前正显示每日商店，替换 contentContainer 中的面板
        if activeSection == 2 then
            contentContainer:RemoveChild(sectionPanels[2])
            contentContainer:AddChild(newDailySection)
        end
        sectionPanels[2] = newDailySection
    end

    -- ── 左侧边栏（道具商店 / 每日商店 可点击切换） ─────────────
    -- 每个入口持有需要更新的子组件引用：{ panel, bar, label }
    local sidebarEntries = {
        { label = "道具商店" },
        { label = "每日商店" },
    }

    -- 存储各侧边栏入口的可更新引用
    local sidebarRefs = {}  -- [i] = { panel=, bar=, lbl= }

    local function SwitchSection(idx)
        if activeSection == idx then return end
        -- 移除旧分区，挂载新分区
        contentContainer:RemoveChild(sectionPanels[activeSection])
        contentContainer:AddChild(sectionPanels[idx])
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
            UI.ScrollView {
                width = "100%", flexGrow = 1,
                children = { contentContainer },
            },
        },
    }

    -- ── 顶栏 ─────────────────────────────────────────────────
    local myMoney = MoneyHUD.GetMoney()
    local topBar = UI.Panel {
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
                flexDirection = "row", alignItems = "center", gap = sz(14),
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center",
                        gap = sz(6), paddingHorizontal = sz(10), paddingVertical = sz(5),
                        backgroundColor = { 0, 0, 0, 120 },
                        borderRadius = sz(14), borderWidth = 1,
                        borderColor = { 100, 80, 20, 150 },
                        children = {
                            CoinIcon(sz(18)),
                            UI.Label {
                                text = Utils.FormatMoney(myMoney),
                                fontSize = sz(14), fontWeight = "bold",
                                fontColor = { 255, 215, 55, 255 },
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
                        backgroundImage = "image/prop_shop_bg.png",
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
