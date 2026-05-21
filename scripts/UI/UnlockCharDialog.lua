-- ============================================================================
-- UI/UnlockCharDialog.lua - 角色解锁确认弹窗（公共组件）
-- ============================================================================
-- 用法：
--   local UnlockCharDialog = require "UI.UnlockCharDialog"
--
--   -- 创建一次（放到根容器的 children 里）
--   local unlockDialog = UnlockCharDialog.Create({
--       sz         = Utils.sz,          -- 尺寸缩放函数
--       onUnlocked = function(ch) ... end,  -- 解锁成功回调
--   })
--   -- 根容器 children 里加 unlockDialog.panel
--
--   -- 点击"解锁"按钮时：
--   unlockDialog.show(ch)  -- ch 是 Config.CHARACTERS[i]
-- ============================================================================

local UI         = require("urhox-libs/UI")
local SaveSystem = require("SaveSystem")

local UNLOCK_TICKET_COST = 300  -- 解锁所需点券
local COIN_TO_TICKET     = 10   -- 1 角色币抵扣 10 点券

local UnlockCharDialog = {}

--- 创建解锁弹窗组件。
--- @param opts table  { sz: function, onUnlocked: function(ch) }
--- @return table      { panel: UI.Panel, show: function(ch) }
function UnlockCharDialog.Create(opts)
    local sz         = opts.sz or function(n) return n end
    local onUnlocked = opts.onUnlocked or function() end

    local overlay  -- 前向声明

    local function hide()
        overlay:SetVisible(false)
    end

    -- ── 可变 UI 引用 ──────────────────────────────────────────────────────
    local dlgAvatarPanel = UI.Panel {
        width = sz(64), height = sz(64),
        borderRadius = sz(32), overflow = "hidden",
        borderWidth = 2, borderColor = { 180, 148, 50, 220 },
        backgroundFit = "cover", flexShrink = 0,
    }
    local dlgNameLbl = UI.Label {
        text = "", fontSize = sz(22), fontWeight = "bold",
        fontColor = { 242, 232, 195, 255 },
    }
    local dlgAbilityLbl = UI.Label {
        text = "", fontSize = sz(12),
        fontColor = { 180, 160, 95, 200 },
    }
    local dlgDiscountLbl = UI.Label {
        text = "", fontSize = sz(12), fontWeight = "bold",
        fontColor = { 140, 220, 120, 240 },
    }
    local dlgDiscountRow = UI.Panel {
        width = "100%", flexDirection = "row",
        alignItems = "center", justifyContent = "center",
        gap = sz(6), paddingVertical = sz(6),
        backgroundColor = { 30, 60, 30, 160 }, borderRadius = sz(6),
        visible = false,
        children = {
            UI.Panel {
                width = sz(16), height = sz(16),
                backgroundImage = "Textures/tickets/character_coin.png",
                backgroundFit = "contain", flexShrink = 0,
            },
            dlgDiscountLbl,
        },
    }
    local dlgActualCostLbl = UI.Label {
        text = "", fontSize = sz(14), fontWeight = "bold",
        fontColor = { 255, 215, 55, 255 },
    }
    local dlgBalanceLbl = UI.Label {
        text = "", fontSize = sz(11), textAlign = "center",
        fontColor = { 120, 195, 100, 220 },
    }
    local dlgConfirmLbl = UI.Label {
        text = "确认解锁", fontSize = sz(14), fontWeight = "bold",
        fontColor = { 255, 225, 80, 255 },
    }

    -- 当前正在操作的角色（show() 时写入，confirm 时读取）
    local currentChar = nil

    local dlgConfirmBtn = UI.Panel {
        flexGrow = 1, paddingVertical = sz(14),
        alignItems = "center", justifyContent = "center",
        backgroundColor = { 130, 100, 18, 240 },
        cursor = "pointer",
        onClick = function()
            local ch = currentChar
            if not ch then return end
            local charCoins      = SaveSystem.GetCharacterCoins()
            local currentTickets = SaveSystem.GetPointTickets()
            local coinsToUse     = math.min(charCoins, math.floor(UNLOCK_TICKET_COST / COIN_TO_TICKET))
            local actualCost     = UNLOCK_TICKET_COST - coinsToUse * COIN_TO_TICKET
            if currentTickets < actualCost then return end

            SaveSystem.AddPointTickets(-actualCost)
            if coinsToUse > 0 then
                SaveSystem.SpendCharacterCoins(coinsToUse)
            end
            SaveSystem.UnlockCharacter(ch.id)
            SaveSystem.Save()
            hide()
            onUnlocked(ch)
        end,
        children = { dlgConfirmLbl },
    }

    -- ── 弹窗整体结构 ──────────────────────────────────────────────────────
    overlay = UI.Panel {
        position = "absolute", left = 0, top = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 160 },
        alignItems = "center", justifyContent = "center",
        visible = false,
        onClick = function() hide() end,
        children = {
            UI.Panel {
                width = sz(300), flexDirection = "column",
                backgroundColor = { 20, 18, 28, 255 },
                borderRadius = sz(12), borderWidth = 1,
                borderColor = { 180, 148, 50, 180 },
                overflow = "hidden",
                onClick = function() end,  -- 吸收点击，不关闭
                children = {
                    -- 顶部金色细条
                    UI.Panel { width = "100%", height = sz(4), backgroundColor = { 200, 165, 50, 255 } },
                    -- 头像 + 名字区
                    UI.Panel {
                        width = "100%", flexDirection = "row",
                        alignItems = "center", gap = sz(14),
                        paddingHorizontal = sz(20),
                        paddingTop = sz(18), paddingBottom = sz(16),
                        borderBottomWidth = 1, borderColor = { 50, 44, 30, 200 },
                        children = {
                            dlgAvatarPanel,
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                flexDirection = "column", gap = sz(4),
                                children = { dlgNameLbl, dlgAbilityLbl },
                            },
                        },
                    },
                    -- 费用区
                    UI.Panel {
                        width = "100%", flexDirection = "column",
                        alignItems = "center", gap = sz(8),
                        paddingHorizontal = sz(20),
                        paddingTop = sz(16), paddingBottom = sz(18),
                        borderBottomWidth = 1, borderColor = { 50, 44, 30, 200 },
                        children = {
                            -- 基础费用行
                            UI.Panel {
                                flexDirection = "row", alignItems = "center",
                                justifyContent = "center", gap = sz(8),
                                paddingHorizontal = sz(24), paddingVertical = sz(10),
                                backgroundColor = { 40, 32, 6, 240 },
                                borderRadius = sz(8), borderWidth = 1,
                                borderColor = { 160, 130, 30, 150 }, width = "100%",
                                children = {
                                    UI.Panel {
                                        width = sz(20), height = sz(20),
                                        backgroundImage = "image/point_ticket_icon_20260518210650.png",
                                        backgroundFit = "contain", flexShrink = 0,
                                    },
                                    UI.Label {
                                        text = tostring(UNLOCK_TICKET_COST),
                                        fontSize = sz(26), fontWeight = "bold",
                                        fontColor = { 255, 215, 55, 255 },
                                    },
                                    UI.Label {
                                        text = "点券",
                                        fontSize = sz(14), fontColor = { 210, 185, 100, 220 },
                                    },
                                },
                            },
                            dlgDiscountRow,
                            -- 实际消耗行
                            UI.Panel {
                                width = "100%", flexDirection = "row",
                                alignItems = "center", justifyContent = "center", gap = sz(6),
                                children = {
                                    UI.Label { text = "实际消耗：", fontSize = sz(12), fontColor = { 180, 185, 200, 200 } },
                                    UI.Panel {
                                        width = sz(16), height = sz(16),
                                        backgroundImage = "image/point_ticket_icon_20260518210650.png",
                                        backgroundFit = "contain", flexShrink = 0,
                                    },
                                    dlgActualCostLbl,
                                },
                            },
                            dlgBalanceLbl,
                        },
                    },
                    -- 按钮区
                    UI.Panel {
                        width = "100%", flexDirection = "row",
                        children = {
                            UI.Panel {
                                flexGrow = 1, paddingVertical = sz(14),
                                alignItems = "center", justifyContent = "center",
                                borderRightWidth = 1, borderColor = { 50, 44, 30, 200 },
                                cursor = "pointer",
                                onClick = function() hide() end,
                                children = {
                                    UI.Label { text = "取消", fontSize = sz(14), fontColor = { 160, 160, 170, 220 } },
                                },
                            },
                            dlgConfirmBtn,
                        },
                    },
                },
            },
        },
    }

    -- ── 对外接口 ──────────────────────────────────────────────────────────
    local function show(ch)
        currentChar = ch
        local charCoins      = SaveSystem.GetCharacterCoins()
        local currentTickets = SaveSystem.GetPointTickets()
        local coinsToUse     = math.min(charCoins, math.floor(UNLOCK_TICKET_COST / COIN_TO_TICKET))
        local discount       = coinsToUse * COIN_TO_TICKET
        local actualCost     = UNLOCK_TICKET_COST - discount
        local canAfford      = currentTickets >= actualCost

        dlgAvatarPanel:SetStyle({ backgroundImage = ch.avatar })
        dlgNameLbl:SetText(ch.name)
        dlgAbilityLbl:SetText(ch.ability or "")

        if coinsToUse > 0 then
            dlgDiscountLbl:SetText(
                tostring(coinsToUse) .. " 角色币 × " .. COIN_TO_TICKET ..
                " = -" .. tostring(discount) .. " 点券"
            )
            dlgDiscountRow:SetVisible(true)
        else
            dlgDiscountRow:SetVisible(false)
        end

        dlgActualCostLbl:SetText(tostring(actualCost) .. " 点券")
        dlgBalanceLbl:SetText(canAfford
            and ("当前点券 " .. currentTickets .. "，解锁后剩余 " .. (currentTickets - actualCost))
            or  ("点券不足，当前仅有 " .. currentTickets .. " 点券"))
        dlgBalanceLbl:SetStyle({ fontColor = canAfford and { 120, 195, 100, 220 } or { 220, 80, 70, 230 } })
        dlgConfirmBtn:SetStyle({ backgroundColor = canAfford and { 130, 100, 18, 240 } or { 35, 35, 40, 200 } })
        dlgConfirmLbl:SetText(canAfford and "确认解锁" or "余额不足")
        dlgConfirmLbl:SetStyle({ fontColor = canAfford and { 255, 225, 80, 255 } or { 110, 110, 115, 200 } })

        overlay:SetVisible(true)
    end

    local function isOpen()
        return overlay:IsVisible()
    end

    return { panel = overlay, show = show, hide = hide, isOpen = isOpen }
end

return UnlockCharDialog
