-- ============================================================================
-- UI/PropScreen.lua - 道具商店页（网格卡片布局）
-- ============================================================================
-- 布局参考：
--   左侧边栏：分类标签（道具商店 高亮）
--   顶栏：商店标题 + 货币显示 + 关闭按钮
--   主区域：3列网格卡片，可滚动
--   购买弹窗：详情 + 数量选择 + 售价 + 黄色购买按钮
-- ============================================================================

local UI = require("urhox-libs/UI")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local SaveSystem = require("SaveSystem")
local Props = require("Config.Props")
local PropSystem = require("PropSystem")
local MoneyManager = require("MoneyManager")
local MoneyHUD = require("UI.MoneyHUD")

local PropScreen = {}

-- ============================================================================
-- 常量
-- ============================================================================

local COIN_ICON = "金币.png"

-- ============================================================================
-- 金币图标组件
-- ============================================================================

local function CoinIcon(size)
    return UI.Panel {
        width = size, height = size,
        backgroundImage = COIN_ICON,
        backgroundFit = "contain",
    }
end

-- ============================================================================
-- 价格层级颜色映射
-- ============================================================================

local function GetTierColors(price)
    if price <= 2000 then
        return {
            headerBg   = { 75, 78, 88, 255 },
            headerText = { 210, 212, 220, 255 },
            cardBg     = { 34, 36, 44, 255 },
            cardBorder = { 65, 68, 78, 180 },
            priceBg    = { 28, 30, 38, 255 },
            hexTint    = nil,
        }
    elseif price <= 5000 then
        return {
            headerBg   = { 30, 110, 65, 255 },
            headerText = { 190, 255, 210, 255 },
            cardBg     = { 22, 38, 30, 255 },
            cardBorder = { 40, 100, 65, 200 },
            priceBg    = { 18, 32, 26, 255 },
            hexTint    = { 80, 230, 120, 255 },
        }
    else
        return {
            headerBg   = { 85, 35, 130, 255 },
            headerText = { 230, 200, 255, 255 },
            cardBg     = { 28, 18, 42, 255 },
            cardBorder = { 100, 50, 155, 200 },
            priceBg    = { 22, 14, 35, 255 },
            hexTint    = { 200, 100, 255, 255 },
        }
    end
end

-- ============================================================================
-- 弹窗状态（模块级，供 GameController 的 ESC 处理使用）
-- ============================================================================

local activeCloseDialog = nil   -- 当前打开的购买弹窗的关闭函数

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

    -- 存储各卡片的数量 Label 引用，购买后直接更新文本
    ---@type table<number, Widget>
    local cardCountLabels = {}

    -- 弹窗挂载容器（渲染在主商店之上，空时不可见）
    local overlayContainer = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        pointerEvents = "box-none",
    }

    -- 当前弹窗 overlay（nil 表示未打开）
    ---@type Widget|nil
    local currentDialog = nil

    -- ── 关闭弹窗 ─────────────────────────────────────────────
    local function CloseDialog()
        if currentDialog then
            overlayContainer:RemoveChild(currentDialog)
            currentDialog = nil
        end
        activeCloseDialog = nil  -- 同步清除模块级指针
    end

    -- ── 构建购买弹窗（独立 overlay，不影响主商店） ─────────────
    local function OpenDialog(propIdx, buyQty)
        CloseDialog()

        local dp = Props.LIST[propIdx]
        if not dp then return end

        local dMoney      = MoneyHUD.GetMoney()
        local dOwned      = PropSystem.GetCount(dp.id)
        -- 每日限购计算
        local dDailyLimit    = dp.dailyLimit  -- nil 表示无限制
        local dDailyBought   = dDailyLimit and SaveSystem.GetPropDailyBought(dp.id) or 0
        local dDailyReached  = dDailyLimit and (dDailyBought >= dDailyLimit)
        local dMaxBuyable    = dDailyReached and 0
                            or (dDailyLimit and math.min(dp.maxStack - dOwned, dDailyLimit - dDailyBought))
                            or (dp.maxStack - dOwned)
        local qty        = math.max(1, math.min(buyQty, math.max(1, dMaxBuyable)))
        local totalPrice = dp.price * qty
        local dCanAfford = dMoney >= totalPrice
        local dMaxed     = dOwned >= dp.maxStack
        local dCanBuy    = dCanAfford and not dMaxed and not dDailyReached
        local tier       = GetTierColors(dp.price)

        -- 数量 Label 引用（弹窗内部更新用）
        ---@type Widget
        local qtyLabel
        ---@type Widget
        local priceLabel
        ---@type Widget
        local buyBtnLabel
        ---@type Widget
        local ownedLabel  -- "已拥有: N"

        -- 更新数量相关显示（不重建弹窗）
        local function RefreshQtyDisplay(newQty)
            qty = math.max(1, math.min(newQty, math.max(1, dMaxBuyable)))
            totalPrice = dp.price * qty
            dCanAfford = dMoney >= totalPrice
            dCanBuy    = dCanAfford and not dMaxed

            if qtyLabel   then qtyLabel.text   = tostring(qty) end
            if priceLabel then priceLabel.text  = Utils.FormatMoney(totalPrice) .. "/" .. Utils.FormatMoney(dMoney) end
            if priceLabel then priceLabel.props.fontColor = dCanAfford and { 240, 235, 215, 255 } or { 220, 80, 70, 255 } end
            if buyBtnLabel then
                buyBtnLabel.text = dDailyReached and "今日已购"
                    or (dMaxed and "已达上限")
                    or (dCanAfford and "购买" or "余额不足")
            end
        end

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
                -- ── 标题栏 ───────────────────────────────────
                UI.Panel {
                    width = "100%", height = sz(44),
                    flexDirection = "row",
                    alignItems = "center",
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
                        UI.Panel {
                            width = sz(30), height = sz(30),
                            alignItems = "center", justifyContent = "center",
                            cursor = "pointer",
                            onClick = function()
                                Utils.PlayClick()
                                CloseDialog()
                            end,
                            children = {
                                UI.Label {
                                    text = "✕",
                                    fontSize = sz(18), fontWeight = "bold",
                                    fontColor = { 180, 185, 200, 220 },
                                },
                            },
                        },
                    },
                },

                -- ── 道具信息区 ───────────────────────────────
                UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    padding = sz(20),
                    gap = sz(20),
                    borderBottomWidth = 1,
                    borderColor = { 55, 58, 70, 120 },
                    children = {
                        -- 左：图标（带六边形背景框）
                        UI.Panel {
                            flexDirection = "column",
                            alignItems = "center",
                            gap = sz(4),
                            children = {
                                UI.Panel {
                                    width = sz(90), height = sz(90),
                                    alignItems = "center",
                                    justifyContent = "center",
                                    children = {
                                        UI.Panel {
                                            position = "absolute",
                                            width = sz(78),
                                            height = sz(90),
                                            backgroundImage = "image/ui_hex_frame_trimmed.png",
                                            backgroundFit = "fill",
                                            imageTint = tier.hexTint,
                                        },
                                        dp.iconImage
                                            and UI.Panel {
                                                width = sz(46), height = sz(46),
                                                backgroundImage = dp.iconImage,
                                                backgroundFit = "contain",
                                            }
                                            or UI.Label {
                                                text = dp.icon,
                                                fontSize = sz(36),
                                            },
                                    },
                                },
                                (function()
                                    local lbl = UI.Label {
                                        text = "×" .. dOwned,
                                        fontSize = sz(13), fontWeight = "bold",
                                        fontColor = { 200, 205, 215, 220 },
                                    }
                                    ownedLabel = lbl
                                    return lbl
                                end)(),
                            },
                        },
                        -- 右：名称 + 描述 + 已拥有
                        UI.Panel {
                            flexGrow = 1, flexShrink = 1,
                            flexDirection = "column",
                            gap = sz(8),
                            children = {
                                UI.Label {
                                    text = dp.name,
                                    fontSize = sz(18), fontWeight = "bold",
                                    fontColor = { 240, 235, 215, 255 },
                                },
                                UI.Label {
                                    text = dp.desc,
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

                -- ── 购买数 + 售价 + 按钮 ─────────────────────
                UI.Panel {
                    width = "100%",
                    flexDirection = "column",
                    padding = sz(20),
                    gap = sz(14),
                    children = {
                        UI.Label {
                            text = "购买数",
                            fontSize = sz(13),
                            fontColor = { 160, 165, 180, 200 },
                        },
                        UI.Panel {
                            width = "100%",
                            flexDirection = "row",
                            alignItems = "center",
                            gap = sz(12),
                            children = {
                                -- [-]
                                UI.Panel {
                                    width = sz(36), height = sz(36),
                                    backgroundColor = { 55, 58, 68, 255 },
                                    borderRadius = sz(4),
                                    borderWidth = 1,
                                    borderColor = { 80, 82, 95, 200 },
                                    alignItems = "center", justifyContent = "center",
                                    cursor = "pointer",
                                    onClick = function()
                                        if qty > 1 then
                                            Utils.PlayClick()
                                            RefreshQtyDisplay(qty - 1)
                                        end
                                    end,
                                    children = {
                                        UI.Label {
                                            text = "－",
                                            fontSize = sz(18), fontWeight = "bold",
                                            fontColor = { 220, 220, 225, 255 },
                                        },
                                    },
                                },
                                -- 数量
                                UI.Panel {
                                    width = sz(60), height = sz(36),
                                    backgroundColor = { 45, 48, 58, 255 },
                                    borderRadius = sz(4),
                                    borderWidth = 1,
                                    borderColor = { 80, 82, 95, 200 },
                                    alignItems = "center", justifyContent = "center",
                                    children = {
                                        (function()
                                            local lbl = UI.Label {
                                                text = tostring(qty),
                                                fontSize = sz(16), fontWeight = "bold",
                                                fontColor = { 240, 240, 245, 255 },
                                            }
                                            qtyLabel = lbl
                                            return lbl
                                        end)(),
                                    },
                                },
                                -- [+]
                                UI.Panel {
                                    width = sz(36), height = sz(36),
                                    backgroundColor = { 55, 58, 68, 255 },
                                    borderRadius = sz(4),
                                    borderWidth = 1,
                                    borderColor = { 80, 82, 95, 200 },
                                    alignItems = "center", justifyContent = "center",
                                    cursor = "pointer",
                                    onClick = function()
                                        if qty < dMaxBuyable then
                                            Utils.PlayClick()
                                            RefreshQtyDisplay(qty + 1)
                                        end
                                    end,
                                    children = {
                                        UI.Label {
                                            text = "＋",
                                            fontSize = sz(18), fontWeight = "bold",
                                            fontColor = { 220, 220, 225, 255 },
                                        },
                                    },
                                },
                                UI.Panel { width = sz(8) },
                                -- 售价
                                UI.Panel {
                                    flexDirection = "row",
                                    alignItems = "center",
                                    gap = sz(6),
                                    children = {
                                        UI.Label {
                                            text = "售价:",
                                            fontSize = sz(13),
                                            fontColor = { 160, 165, 180, 200 },
                                        },
                                        CoinIcon(sz(18)),
                                        (function()
                                            local lbl = UI.Label {
                                                text = Utils.FormatMoney(totalPrice) .. "/" .. Utils.FormatMoney(dMoney),
                                                fontSize = sz(14), fontWeight = "bold",
                                                fontColor = dCanAfford
                                                    and { 240, 235, 215, 255 }
                                                    or  { 220, 80, 70, 255 },
                                            }
                                            priceLabel = lbl
                                            return lbl
                                        end)(),
                                    },
                                },
                                UI.Panel { flexGrow = 1 },
                                -- 购买按钮
                                UI.Panel {
                                    width = sz(120), height = sz(40),
                                    backgroundColor = dCanBuy
                                        and { 230, 200, 30, 255 }
                                        or  { 60, 62, 70, 200 },
                                    borderRadius = sz(6),
                                    alignItems = "center", justifyContent = "center",
                                    cursor = dCanBuy and "pointer" or "default",
                                    onClick = function()
                                        if not dCanBuy then return end
                                        Utils.PlayClick()
                                        local purchaseQty = qty
                                        local buyTotal = dp.price * purchaseQty
                                        MoneyManager.AddMoneyFromMenu(-buyTotal, "buy_prop_" .. dp.id, {
                                            silent = true,
                                            batchSetup = function(batch)
                                                SaveSystem.AddProp(dp.id, purchaseQty)
                                                SaveSystem.WriteToBatch(batch)
                                            end,
                                            ok = function()
                                                -- 记录每日购买次数
                                                if dp.dailyLimit then
                                                    SaveSystem.RecordPropDailyBuy(dp.id, purchaseQty)
                                                end
                                                -- 购买成功：仅更新卡片数量 Label，不重建主商店
                                                local newOwned = PropSystem.GetCount(dp.id)
                                                if cardCountLabels[propIdx] then
                                                    cardCountLabels[propIdx].text = "×" .. newOwned
                                                end
                                                Utils.ShowMessage(dp.name .. " ×" .. purchaseQty .. " 购买成功")
                                            end,
                                            error = function()
                                                SaveSystem.AddProp(dp.id, -purchaseQty)
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
                                                fontColor = dCanBuy
                                                    and { 20, 20, 20, 255 }
                                                    or  { 110, 110, 115, 200 },
                                            }
                                            buyBtnLabel = lbl
                                            return lbl
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
            onClick = function()
                CloseDialog()
            end,
            children = { dialogBox },
        }

        currentDialog = overlay
        activeCloseDialog = CloseDialog  -- 注册到模块级，供 ESC 使用
        overlayContainer:AddChild(overlay)
    end

    -- ── 左侧边栏 ─────────────────────────────────────────────
    local sidebarCategories = {
        { label = "道具商店", active = true },
        { label = "商城",     active = false },
        { label = "神秘商店", active = false },
        { label = "兑换所",   active = false },
        { label = "每日商城", active = false },
    }
    local sidebarItems = {}
    for _, cat in ipairs(sidebarCategories) do
        table.insert(sidebarItems, UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "stretch",
            borderRadius = sz(4),
            overflow = "hidden",
            backgroundColor = cat.active
                and { 200, 230, 0, 255 }
                or  { 60, 62, 70, 180 },
            cursor = cat.active and "default" or "pointer",
            children = {
                UI.Panel {
                    width = sz(4),
                    flexShrink = 0,
                    backgroundColor = cat.active
                        and { 255, 255, 255, 255 }
                        or  { 0, 0, 0, 0 },
                },
                UI.Panel {
                    flexGrow = 1,
                    paddingVertical = sz(12),
                    paddingLeft = sz(12),
                    paddingRight = sz(10),
                    children = {
                        UI.Label {
                            text = cat.label,
                            fontSize = sz(14), fontWeight = "bold",
                            fontColor = cat.active
                                and { 10, 10, 10, 255 }
                                or  { 180, 180, 185, 220 },
                        },
                    },
                },
            },
        })
    end

    local sidebar = UI.Panel {
        width = sz(140),
        flexShrink = 0,
        flexDirection = "column",
        paddingTop = sz(4),
        paddingHorizontal = sz(8),
        gap = sz(4),
        children = {
            table.unpack(sidebarItems),
            UI.Panel { flexGrow = 1 },
            UI.Panel {
                width = "100%",
                paddingHorizontal = sz(8), paddingVertical = sz(9),
                children = {
                    UI.Panel {
                        width = "100%",
                        paddingVertical = sz(7),
                        backgroundColor = { 30, 32, 50, 210 },
                        borderRadius = sz(6),
                        borderWidth = 1,
                        borderColor = { 60, 65, 95, 200 },
                        alignItems = "center",
                        justifyContent = "center",
                        cursor = "pointer",
                        onClick = function()
                            Utils.PlayClick()
                            CloseDialog()
                            if onBackCallback then onBackCallback() end
                        end,
                        children = {
                            UI.Label {
                                text = "返回",
                                fontSize = sz(13),
                                fontColor = { 180, 185, 210, 230 },
                            },
                        },
                    },
                },
            },
        },
    }

    -- ── 商品卡片（一次性构建，记录数量 Label 引用） ───────────
    local cards = {}
    for i, p in ipairs(Props.LIST) do
        local count = PropSystem.GetCount(p.id)
        local tier  = GetTierColors(p.price)

        -- 数量角标 Label
        local countLbl = UI.Label {
            text = "×" .. count,
            fontSize = sz(12),
            fontColor = { 180, 185, 195, 220 },
        }
        cardCountLabels[i] = countLbl

        table.insert(cards, UI.Panel {
            width = "31.5%",
            flexDirection = "column",
            backgroundColor = tier.cardBg,
            borderWidth = 1,
            borderColor = tier.cardBorder,
            overflow = "hidden",
            cursor = "pointer",
            onClick = function()
                Utils.PlayClick()
                OpenDialog(i, 1)
            end,
            children = {
                -- 名称条
                UI.Panel {
                    width = "100%",
                    paddingVertical = sz(6),
                    paddingHorizontal = sz(10),
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
                    width = "100%",
                    height = sz(90),
                    alignItems = "center",
                    justifyContent = "center",
                    children = {
                        UI.Panel {
                            width = sz(70), height = sz(70),
                            alignItems = "center",
                            justifyContent = "center",
                            children = {
                                UI.Panel {
                                    position = "absolute",
                                    width = sz(61),
                                    height = sz(70),
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
                        -- ×数量角标
                        UI.Panel {
                            position = "absolute",
                            right = sz(12), bottom = sz(4),
                            children = { countLbl },
                        },
                    },
                },
                -- 价格底栏
                UI.Panel {
                    width = "100%",
                    paddingVertical = sz(6),
                    paddingHorizontal = sz(10),
                    backgroundColor = tier.priceBg,
                    borderTopWidth = 1,
                    borderColor = tier.cardBorder,
                    flexDirection = "row",
                    alignItems = "center",
                    justifyContent = "center",
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
        })
    end

    -- ── 顶栏 ─────────────────────────────────────────────────
    local myMoney = MoneyHUD.GetMoney()
    local topBar = UI.Panel {
        width = "100%", height = sz(50),
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = sz(16),
        borderBottomWidth = 1,
        borderColor = { 50, 55, 70, 100 },
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = sz(10),
                children = {
                    UI.Panel {
                        width = sz(26), height = sz(26),
                        backgroundImage = "image/icon_cart.png",
                        backgroundFit = "contain",
                    },
                    UI.Panel {
                        width = 1, height = sz(20),
                        backgroundColor = { 180, 185, 200, 80 },
                    },
                    UI.Label {
                        text = "商店",
                        fontSize = sz(18), fontWeight = "bold",
                        fontColor = { 240, 235, 220, 255 },
                    },
                },
            },
            UI.Panel { flexGrow = 1 },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = sz(14),
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = sz(6),
                        paddingHorizontal = sz(10), paddingVertical = sz(5),
                        backgroundColor = { 0, 0, 0, 120 },
                        borderRadius = sz(14),
                        borderWidth = 1,
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
                        borderWidth = 1,
                        borderColor = { 70, 75, 90, 180 },
                        alignItems = "center", justifyContent = "center",
                        cursor = "pointer",
                        onClick = function()
                            Utils.PlayClick()
                            CloseDialog()
                            if onBackCallback then onBackCallback() end
                        end,
                        children = {
                            UI.Label {
                                text = "✕",
                                fontSize = sz(18), fontWeight = "bold",
                                fontColor = { 180, 220, 0, 230 },
                            },
                        },
                    },
                },
            },
        },
    }

    -- ── 主内容区 ─────────────────────────────────────────────
    local mainArea = UI.Panel {
        flexGrow = 1, flexShrink = 1,
        flexDirection = "column",
        children = {
            UI.Panel {
                width = "100%",
                paddingLeft = sz(14), paddingRight = sz(16), paddingVertical = sz(10),
                flexDirection = "row", alignItems = "center",
                backgroundColor = { 20, 22, 32, 230 },
                borderBottomWidth = 1,
                borderColor = { 50, 55, 70, 150 },
                gap = sz(10),
                children = {
                    UI.Panel {
                        width = sz(3), height = sz(16),
                        backgroundColor = { 200, 230, 0, 255 },
                        borderRadius = sz(2),
                    },
                    UI.Label {
                        text = "全部商品",
                        fontSize = sz(14), fontWeight = "bold",
                        fontColor = { 230, 230, 235, 255 },
                    },
                },
            },
            UI.ScrollView {
                width = "100%", flexGrow = 1,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        flexWrap = "wrap",
                        gap = sz(10),
                        padding = sz(12),
                        children = cards,
                    },
                },
            },
        },
    }

    -- ── 整体布局（仅设置一次） ───────────────────────────────
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = {
            UI.Panel {
                width = "100%", height = "100%",
                children = {
                    -- 主商店内容
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
                                        children = {
                                            sidebar,
                                            mainArea,
                                        },
                                    },
                                },
                            },
                        },
                    },
                    -- 弹窗容器（叠在商店之上）
                    overlayContainer,
                },
            },
        },
    })
end

return PropScreen
