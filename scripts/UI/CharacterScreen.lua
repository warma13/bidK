-- ============================================================================
-- UI/CharacterScreen.lua - 角色图鉴页
-- ============================================================================
-- 布局：三列
--   左列：头像选择网格（可滚动，3列）
--   中列：技能/详情描述区（专精 + 名字 + 能力 + 描述 + 揭示事件）
--   右列：角色立绘（全高 contain）
--   右上角：X 关闭按钮（绝对定位）
-- ============================================================================

local UI = require("urhox-libs/UI")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local SaveSystem = require("SaveSystem")
local Characters = require("Config.Characters")

local CharacterScreen = {}

-- ============================================================================
-- 常量
-- ============================================================================

local SPECIALTY_NAMES = {
    antique    = "古董",
    tech       = "科技",
    energy     = "能源",
    jewel      = "珠宝",
    art        = "艺术",
    mechanical = "机械",
    transport  = "交通",
    fashion    = "服饰",
    biotech    = "医疗",
    daily      = "日用",
}

local REVEAL_LEVEL_TEXT = {
    L0  = "数量",
    L1  = "轮廓",
    L2  = "品质",
    L3  = "全知",
    L0V = "总价",
}

-- ============================================================================
-- 常量：解锁费用
-- ============================================================================

local UNLOCK_TICKET_COST = 300  -- 解锁所需点券
local COIN_TO_TICKET     = 10   -- 1 角色币抵扣 10 点券

-- ============================================================================
-- 状态
-- ============================================================================

local selectedCharId = nil
local dialogCharId = nil  -- 当前弹窗对应的角色 id，nil 表示无弹窗

-- ============================================================================
-- 工具
-- ============================================================================

local function GetSpecialtyLabel(specialty)
    if not specialty then return "通才" end
    if type(specialty) == "table" then
        local parts = {}
        for _, s in ipairs(specialty) do
            table.insert(parts, SPECIALTY_NAMES[s] or s)
        end
        return table.concat(parts, "+")
    end
    return SPECIALTY_NAMES[specialty] or specialty
end

local function FormatRevealEvent(ev)
    local triggerText = ev.trigger
    if ev.trigger == "every_round" then
        triggerText = "每轮"
    elseif ev.trigger:match("^round_(%d+)$") then
        triggerText = "第" .. ev.trigger:match("^round_(%d+)$") .. "轮"
    elseif ev.trigger:match("^from_round_(%d+)$") then
        triggerText = "第" .. ev.trigger:match("^from_round_(%d+)$") .. "轮起每轮"
    end
    local t = ev.target or ""
    t = t:gsub("category_all",        "全部")
         :gsub("category_random_(%d+)", "随机%1件")
         :gsub("^random_(%d+)$",        "随机%1件")
         :gsub("^all$",                 "全部")
         :gsub("^highest_(%d+)$",       "最高%1件")
    local levelText = REVEAL_LEVEL_TEXT[ev.level] or ev.level
    return triggerText .. "：" .. t .. " [" .. levelText .. "]"
end

-- ============================================================================
-- 主入口
-- ============================================================================

function CharacterScreen.Show(onBackCallback)
    UIState.currentScreen = "character"
    local sz = Utils.sz

    if not selectedCharId and #Characters.CHARACTERS > 0 then
        selectedCharId = Characters.CHARACTERS[1].id
    end

    local function GetSelectedChar()
        for _, c in ipairs(Characters.CHARACTERS) do
            if c.id == selectedCharId then return c end
        end
        return Characters.CHARACTERS[1]
    end

    local function Rebuild()
        local char = GetSelectedChar()
        local isUnlocked = not char.locked or SaveSystem.IsCharacterUnlocked(char.id)
        local specLabel = GetSpecialtyLabel(char.specialty)

        -- ── 左列：头像选择网格 ────────────────────────────────────────────
        local avatarCards = {}
        for _, c in ipairs(Characters.CHARACTERS) do
            local cId = c.id
            local cUnlocked = not c.locked or SaveSystem.IsCharacterUnlocked(c.id)
            local isSel = cId == selectedCharId

            local badge = nil
            if not cUnlocked then
                badge = UI.Panel {
                    position = "absolute", right = sz(3), top = sz(3),
                    width = sz(16), height = sz(16),
                    borderRadius = sz(8),
                    backgroundColor = { 30, 30, 40, 220 },
                    alignItems = "center", justifyContent = "center",
                    children = {
                        UI.Label { text = "🔒", fontSize = sz(9) },
                    },
                }
            end

            table.insert(avatarCards, UI.Panel {
                width = sz(62), height = sz(62),
                overflow = "hidden",
                backgroundColor = { 22, 25, 40, 255 },
                backgroundImage = c.avatar,
                backgroundFit = "cover",
                borderWidth = isSel and 2 or 1,
                borderColor = isSel and { 255, 255, 255, 255 } or { 120, 120, 120, 180 },
                cursor = "pointer",
                onClick = function()
                    Utils.PlayClick()
                    selectedCharId = cId
                    Rebuild()
                end,
                children = {
                    badge,
                },
            })
        end

        -- ── 中列：技能/详情描述区 ─────────────────────────────────────────
        local skillNodes = {}
        if char.revealEvents and #char.revealEvents > 0 then
            for i, ev in ipairs(char.revealEvents) do
                table.insert(skillNodes, UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    alignItems = "flex-start",
                    gap = sz(8),
                    marginBottom = sz(6),
                    children = {
                        UI.Panel {
                            width = sz(20), height = sz(20),
                            borderRadius = sz(10),
                            backgroundColor = { 55, 95, 195, 220 },
                            alignItems = "center", justifyContent = "center",
                            flexShrink = 0, marginTop = sz(1),
                            children = {
                                UI.Label {
                                    text = tostring(i),
                                    fontSize = sz(10), fontWeight = "bold",
                                    fontColor = { 215, 230, 255, 255 },
                                },
                            },
                        },
                        UI.Label {
                            text = FormatRevealEvent(ev),
                            fontSize = sz(12),
                            fontColor = { 195, 210, 235, 230 },
                            flexShrink = 1,
                        },
                    },
                })
            end
        end

        -- 锁定/解锁状态提示
        local statusNode = nil
        if not isUnlocked then
            if char.unlockCost and char.unlockCost > 0 then
                -- 有费用：显示解锁按钮
                local charCoins    = SaveSystem.GetCharacterCoins()
                local coinsToUse   = math.min(charCoins, math.floor(UNLOCK_TICKET_COST / COIN_TO_TICKET))
                local actualCost   = UNLOCK_TICKET_COST - coinsToUse * COIN_TO_TICKET
                -- 底部按钮子节点
                local btnChildren = {
                    UI.Panel {
                        width = sz(16), height = sz(16),
                        backgroundImage = "image/point_ticket_icon_20260518210650.png",
                        backgroundFit = "contain", flexShrink = 0,
                    },
                    UI.Label {
                        text = tostring(actualCost) .. " 点券  解锁",
                        fontSize = sz(13), fontWeight = "bold",
                        fontColor = { 255, 225, 80, 255 },
                    },
                }
                if coinsToUse > 0 then
                    table.insert(btnChildren, UI.Label {
                        text = "(-" .. tostring(coinsToUse) .. "角色币)",
                        fontSize = sz(11),
                        fontColor = { 180, 220, 140, 210 },
                    })
                end
                statusNode = UI.Panel {
                    width = "100%",
                    flexDirection = "column", gap = sz(8),
                    children = {
                        -- 解锁按钮
                        UI.Panel {
                            width = "100%",
                            flexDirection = "row", alignItems = "center", justifyContent = "center",
                            gap = sz(8),
                            paddingVertical = sz(11),
                            backgroundColor = { 130, 100, 20, 220 },
                            borderRadius = sz(6),
                            borderWidth = 1,
                            borderColor = { 200, 165, 50, 180 },
                            cursor = "pointer",
                            onClick = function()
                                Utils.PlayClick()
                                dialogCharId = char.id
                                Rebuild()
                            end,
                            children = btnChildren,
                        },
                    },
                }
            else
                -- 无费用：显示条件提示
                statusNode = UI.Panel {
                    width = "100%",
                    paddingHorizontal = sz(14), paddingVertical = sz(10),
                    backgroundColor = { 30, 20, 10, 200 },
                    borderRadius = sz(6),
                    borderWidth = 1,
                    borderColor = { 120, 80, 20, 180 },
                    marginTop = sz(8),
                    children = {
                        UI.Label {
                            text = "🔒  " .. (char.unlockDesc or "完成特定条件后解锁"),
                            fontSize = sz(12),
                            fontColor = { 200, 170, 90, 230 },
                            flexShrink = 1,
                        },
                    },
                }
            end
        end

        -- ── 主树 ─────────────────────────────────────────────────────────
        local newRoot = UI.Panel {
            width = "100%", height = "100%",
            backgroundImage = "image/char_screen_bg.jpg",
            backgroundFit = "cover",
            backgroundPosition = "center",
            flexDirection = "row",
            children = {

                -- ===== 左列：头像选择网格 =====
                UI.Panel {
                    width = sz(220),
                    flexShrink = 0,
                    flexDirection = "column",
                    backgroundColor = { 15, 15, 20, 120 },
                    backdropBlur = 20,
                    children = {
                        -- 标题栏
                        UI.Panel {
                            width = "100%", height = sz(48),
                            flexDirection = "row", alignItems = "center",
                            paddingHorizontal = sz(12),
                            gap = sz(8),
                            borderBottomWidth = 1,
                            borderColor = { 60, 60, 60, 120 },
                            children = {
                                UI.Label {
                                    text = "角色",
                                    fontSize = sz(15), fontWeight = "bold",
                                    fontColor = { 230, 215, 160, 255 },
                                },
                                UI.Panel { flexGrow = 1 },
                                -- 竞买币
                                UI.Panel {
                                    flexDirection = "row", alignItems = "center", gap = sz(4),
                                    paddingHorizontal = sz(8), paddingVertical = sz(3),
                                    backgroundColor = { 0, 0, 0, 160 },
                                    borderRadius = sz(12),
                                    borderWidth = 1,
                                    borderColor = { 100, 80, 20, 160 },
                                    children = {
                                        UI.Panel {
                                            width = sz(16), height = sz(16),
                                            backgroundImage = "Textures/tickets/character_coin.png",
                                            backgroundFit = "contain",
                                            flexShrink = 0,
                                        },
                                        UI.Label {
                                            text = tostring(SaveSystem.GetCharacterCoins()),
                                            fontSize = sz(12), fontWeight = "bold",
                                            fontColor = { 255, 210, 55, 255 },
                                        },
                                    },
                                },
                            },
                        },
                        -- 头像网格（可滚动）
                        UI.ScrollView {
                            width = "100%", flexGrow = 1,
                            padding = sz(10),
                            children = {
                                UI.Panel {
                                    width = "100%",
                                    flexDirection = "row",
                                    flexWrap = "wrap",
                                    gap = sz(6),
                                    children = avatarCards,
                                },
                            },
                        },
                        -- 固定底部：返回按钮
                        UI.Panel {
                            width = "100%",
                            paddingHorizontal = sz(12), paddingVertical = sz(9),
                            borderTopWidth = 1,
                            borderColor = { 60, 60, 60, 120 },
                            flexDirection = "row",
                            alignItems = "center",
                            children = {
                                UI.Button {
                                    text = "返回",
                                    fontSize = sz(13),
                                    fontColor = { 195, 215, 40, 230 },
                                    fontWeight = "bold",
                                    paddingHorizontal = sz(14), paddingVertical = sz(7),
                                    backgroundColor = { 195, 215, 40, 20 },
                                    hoverBackgroundColor = { 195, 215, 40, 50 },
                                    pressedBackgroundColor = { 195, 215, 40, 110 },
                                    borderWidth = 1,
                                    borderColor = { 195, 215, 40, 160 },
                                    borderRadius = 0,
                                    onClick = function()
                                        Utils.PlayClick()
                                        if onBackCallback then onBackCallback() end
                                    end,
                                },
                            },
                        },
                    },
                },

                -- ===== 中列：角色立绘 =====
                UI.Panel {
                    flexGrow = 1, flexShrink = 1,
                    height = "100%",
                    overflow = "hidden",
                    children = {
                        char.portrait and UI.Panel {
                            position = "absolute",
                            left = 0, top = 0, right = 0, bottom = 0,
                            backgroundImage = char.portrait,
                            backgroundFit = "contain",
                        } or UI.Panel {
                            position = "absolute",
                            left = 0, top = 0, right = 0, bottom = 0,
                            backgroundColor = { 18, 20, 35, 100 },
                        },
                    },
                },

                -- ===== 右列：技能/详情描述 =====
                UI.Panel {
                    width = sz(280),
                    flexShrink = 0,
                    flexDirection = "column",
                    backgroundColor = { 15, 15, 20, 120 },
                    backdropBlur = 20,
                    children = {
                        -- 可滚动内容区
                        UI.ScrollView {
                            width = "100%", flexGrow = 1,
                            padding = sz(18),
                            children = {
                                UI.Panel {
                                    width = "100%",
                                    flexDirection = "column",
                                    gap = sz(10),
                                    children = {
                                        -- 专精 chip
                                        UI.Panel {
                                            flexDirection = "row",
                                            children = {
                                                UI.Panel {
                                                    paddingHorizontal = sz(10), paddingVertical = sz(4),
                                                    backgroundColor = { 145, 130, 30, 230 },
                                                    borderRadius = sz(3),
                                                    children = {
                                                        UI.Label {
                                                            text = specLabel .. "专精",
                                                            fontSize = sz(11), fontWeight = "bold",
                                                            fontColor = { 245, 230, 150, 255 },
                                                        },
                                                    },
                                                },
                                            },
                                        },
                                        -- 角色名
                                        UI.Label {
                                            text = char.name,
                                            fontSize = sz(30), fontWeight = "bold",
                                            fontColor = { 242, 235, 210, 255 },
                                        },
                                        -- 能力副标题
                                        char.ability and UI.Label {
                                            text = char.ability,
                                            fontSize = sz(13),
                                            fontColor = { 195, 180, 115, 230 },
                                            letterSpacing = 1,
                                        } or nil,
                                        -- 分隔线
                                        UI.Panel {
                                            width = "100%", height = 1,
                                            backgroundColor = { 40, 44, 70, 180 },
                                            marginVertical = sz(4),
                                        },
                                        -- 描述
                                        char.desc and UI.Label {
                                            text = char.desc,
                                            fontSize = sz(12),
                                            fontColor = { 185, 195, 215, 210 },
                                            flexShrink = 1,
                                        } or nil,
                                    },
                                },
                            },
                        },
                        -- 固定底部：解锁按钮（仅未解锁且有费用时显示）
                        statusNode and UI.Panel {
                            width = "100%",
                            paddingHorizontal = sz(14), paddingVertical = sz(10),
                            borderTopWidth = 1,
                            borderColor = { 60, 60, 70, 150 },
                            backgroundColor = { 10, 10, 15, 200 },
                            children = { statusNode },
                        } or nil,
                    },
                },

            },
        }

        -- ── 解锁确认弹窗（自定义 overlay，绝对定位覆盖全屏）────────────
        local dialogOverlay = nil
        if dialogCharId then
            local dc = nil
            for _, c in ipairs(Characters.CHARACTERS) do
                if c.id == dialogCharId then dc = c; break end
            end
            if dc then
                local charCoins      = SaveSystem.GetCharacterCoins()
                local currentTickets = SaveSystem.GetPointTickets()
                local coinsToUse     = math.min(charCoins, math.floor(UNLOCK_TICKET_COST / COIN_TO_TICKET))
                local discount       = coinsToUse * COIN_TO_TICKET
                local actualCost     = UNLOCK_TICKET_COST - discount
                local canAfford      = currentTickets >= actualCost

                dialogOverlay = UI.Panel {
                    position = "absolute",
                    left = 0, top = 0, right = 0, bottom = 0,
                    backgroundColor = { 0, 0, 0, 160 },
                    alignItems = "center", justifyContent = "center",
                    -- 点击遮罩关闭
                    onClick = function()
                        dialogCharId = nil
                        Rebuild()
                    end,
                    children = {
                        -- 卡片容器（点击不穿透到遮罩）
                        UI.Panel {
                            width = sz(300),
                            flexDirection = "column",
                            backgroundColor = { 20, 18, 28, 255 },
                            borderRadius = sz(12),
                            borderWidth = 1,
                            borderColor = { 180, 148, 50, 180 },
                            overflow = "hidden",
                            onClick = function() end,  -- 吸收点击，不关闭
                            children = {
                                -- 顶部金色细条
                                UI.Panel {
                                    width = "100%", height = sz(4),
                                    backgroundColor = { 200, 165, 50, 255 },
                                },
                                -- 头像 + 名字区
                                UI.Panel {
                                    width = "100%",
                                    flexDirection = "row",
                                    alignItems = "center",
                                    gap = sz(14),
                                    paddingHorizontal = sz(20),
                                    paddingTop = sz(18),
                                    paddingBottom = sz(16),
                                    borderBottomWidth = 1,
                                    borderColor = { 50, 44, 30, 200 },
                                    children = {
                                        -- 头像圆框
                                        UI.Panel {
                                            width = sz(64), height = sz(64),
                                            borderRadius = sz(32),
                                            overflow = "hidden",
                                            borderWidth = 2,
                                            borderColor = { 180, 148, 50, 220 },
                                            backgroundImage = dc.avatar,
                                            backgroundFit = "cover",
                                            flexShrink = 0,
                                        },
                                        -- 名字 + 能力
                                        UI.Panel {
                                            flexGrow = 1, flexShrink = 1,
                                            flexDirection = "column",
                                            gap = sz(4),
                                            children = {
                                                UI.Label {
                                                    text = dc.name,
                                                    fontSize = sz(22), fontWeight = "bold",
                                                    fontColor = { 242, 232, 195, 255 },
                                                },
                                                UI.Label {
                                                    text = dc.ability or "",
                                                    fontSize = sz(12),
                                                    fontColor = { 180, 160, 95, 200 },
                                                },
                                            },
                                        },
                                    },
                                },
                                -- 费用区
                                UI.Panel {
                                    width = "100%",
                                    flexDirection = "column",
                                    alignItems = "center",
                                    gap = sz(8),
                                    paddingHorizontal = sz(20),
                                    paddingTop = sz(16),
                                    paddingBottom = sz(18),
                                    borderBottomWidth = 1,
                                    borderColor = { 50, 44, 30, 200 },
                                    children = {
                                        -- 基础费用行
                                        UI.Panel {
                                            flexDirection = "row",
                                            alignItems = "center",
                                            justifyContent = "center",
                                            gap = sz(8),
                                            paddingHorizontal = sz(24),
                                            paddingVertical = sz(10),
                                            backgroundColor = { 40, 32, 6, 240 },
                                            borderRadius = sz(8),
                                            borderWidth = 1,
                                            borderColor = { 160, 130, 30, 150 },
                                            width = "100%",
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
                                                    fontSize = sz(14),
                                                    fontColor = { 210, 185, 100, 220 },
                                                },
                                            },
                                        },
                                        -- 角色币抵扣行（有角色币时才显示）
                                        coinsToUse > 0 and UI.Panel {
                                            width = "100%",
                                            flexDirection = "row", alignItems = "center",
                                            justifyContent = "center", gap = sz(6),
                                            paddingVertical = sz(6),
                                            backgroundColor = { 30, 60, 30, 160 },
                                            borderRadius = sz(6),
                                            children = {
                                                UI.Panel {
                                                    width = sz(16), height = sz(16),
                                                    backgroundImage = "Textures/tickets/character_coin.png",
                                                    backgroundFit = "contain", flexShrink = 0,
                                                },
                                                UI.Label {
                                                    text = tostring(coinsToUse) .. " 角色币 × " .. COIN_TO_TICKET .. " = -" .. tostring(discount) .. " 点券",
                                                    fontSize = sz(12), fontWeight = "bold",
                                                    fontColor = { 140, 220, 120, 240 },
                                                },
                                            },
                                        } or nil,
                                        -- 实际消耗行
                                        UI.Panel {
                                            width = "100%",
                                            flexDirection = "row", alignItems = "center",
                                            justifyContent = "center", gap = sz(6),
                                            children = {
                                                UI.Label {
                                                    text = "实际消耗：",
                                                    fontSize = sz(12),
                                                    fontColor = { 180, 185, 200, 200 },
                                                },
                                                UI.Panel {
                                                    width = sz(16), height = sz(16),
                                                    backgroundImage = "image/point_ticket_icon_20260518210650.png",
                                                    backgroundFit = "contain", flexShrink = 0,
                                                },
                                                UI.Label {
                                                    text = tostring(actualCost) .. " 点券",
                                                    fontSize = sz(14), fontWeight = "bold",
                                                    fontColor = { 255, 215, 55, 255 },
                                                },
                                            },
                                        },
                                        -- 余额提示
                                        UI.Label {
                                            text = canAfford
                                                and ("当前点券 " .. currentTickets .. "，解锁后剩余 " .. (currentTickets - actualCost))
                                                or  ("点券不足，当前仅有 " .. currentTickets .. " 点券"),
                                            fontSize = sz(11),
                                            fontColor = canAfford
                                                and { 120, 195, 100, 220 }
                                                or  { 220, 80, 70, 230 },
                                            textAlign = "center",
                                        },
                                    },
                                },
                                -- 按钮区
                                UI.Panel {
                                    width = "100%",
                                    flexDirection = "row",
                                    children = {
                                        -- 取消
                                        UI.Panel {
                                            flexGrow = 1,
                                            paddingVertical = sz(14),
                                            alignItems = "center", justifyContent = "center",
                                            borderRightWidth = 1,
                                            borderColor = { 50, 44, 30, 200 },
                                            cursor = "pointer",
                                            onClick = function()
                                                Utils.PlayClick()
                                                dialogCharId = nil
                                                Rebuild()
                                            end,
                                            children = {
                                                UI.Label {
                                                    text = "取消",
                                                    fontSize = sz(14),
                                                    fontColor = { 160, 160, 170, 220 },
                                                },
                                            },
                                        },
                                        -- 确认
                                        UI.Panel {
                                            flexGrow = 1,
                                            paddingVertical = sz(14),
                                            alignItems = "center", justifyContent = "center",
                                            backgroundColor = canAfford and { 130, 100, 18, 240 } or { 35, 35, 40, 200 },
                                            cursor = canAfford and "pointer" or "default",
                                            onClick = function()
                                                if not canAfford then return end
                                                Utils.PlayClick()
                                                -- 扣除点券
                                                SaveSystem.AddPointTickets(-actualCost)
                                                -- 扣除角色币（抵扣部分）
                                                if coinsToUse > 0 then
                                                    SaveSystem.SpendCharacterCoins(coinsToUse)
                                                end
                                                SaveSystem.UnlockCharacter(dc.id)
                                                SaveSystem.Save()
                                                dialogCharId = nil
                                                Rebuild()
                                            end,
                                            children = {
                                                UI.Label {
                                                    text = canAfford and "确认解锁" or "余额不足",
                                                    fontSize = sz(14), fontWeight = "bold",
                                                    fontColor = canAfford
                                                        and { 255, 225, 80, 255 }
                                                        or  { 110, 110, 115, 200 },
                                                },
                                            },
                                        },
                                    },
                                },
                                -- 看广告得点券（仅点券不足时显示）
                                not canAfford and UI.Panel {
                                    width = "100%",
                                    paddingHorizontal = sz(16), paddingVertical = sz(10),
                                    borderTopWidth = 1,
                                    borderColor = { 50, 44, 30, 200 },
                                    children = {
                                        UI.Button {
                                            width = "100%", height = sz(36),
                                            variant = "primary",
                                            onClick = function()
                                                Utils.PlayClick()
                                                dialogCharId = nil
                                                Rebuild()
                                                local AdCardPanel = require("UI.AdCardPanel")
                                                if AdCardPanel.CanWatchAd() then
                                                    AdCardPanel.WatchAd()
                                                end
                                            end,
                                            children = {
                                                UI.Panel {
                                                    flexDirection = "row", alignItems = "center", gap = sz(4),
                                                    justifyContent = "center", width = "100%", height = "100%",
                                                    children = {
                                                        UI.Label {
                                                            text = "看广告",
                                                            fontSize = sz(13), fontWeight = "bold",
                                                            fontColor = { 20, 20, 20, 255 },
                                                        },
                                                        UI.Panel {
                                                            width = sz(16), height = sz(16),
                                                            backgroundImage = Utils.GetIcon("coin"),
                                                            backgroundFit = "contain", flexShrink = 0,
                                                        },
                                                        (function()
                                                            local AdCardPanel = require("UI.AdCardPanel")
                                                            local tier = AdCardPanel.GetCurrentTier()
                                                            local coins = tier and tier.coinsPerAd or 0
                                                            return UI.Label {
                                                                text = "+" .. Utils.FormatMoney(coins),
                                                                fontSize = sz(13), fontWeight = "bold",
                                                                fontColor = { 20, 20, 20, 255 },
                                                            }
                                                        end)(),
                                                        UI.Panel {
                                                            width = sz(16), height = sz(16),
                                                            backgroundImage = "image/point_ticket_icon_20260518210650.png",
                                                            backgroundFit = "contain", flexShrink = 0,
                                                        },
                                                        UI.Label {
                                                            text = "×10",
                                                            fontSize = sz(11), fontWeight = "bold",
                                                            fontColor = { 20, 20, 20, 255 },
                                                        },
                                                    },
                                                },
                                            },
                                        },
                                    },
                                } or nil,
                            },
                        },
                    },
                }
            end
        end

        -- X 关闭按钮（绝对定位，右上角，叠在最顶层）
        local rootWithX = UI.Panel {
            width = "100%", height = "100%",
            children = {
                newRoot,
                -- X 按钮
                UI.Panel {
                    position = "absolute",
                    right = sz(14), top = sz(10),
                    width = sz(32), height = sz(32),
                    borderRadius = sz(4),
                    backgroundColor = { 40, 42, 55, 200 },
                    borderWidth = 1,
                    borderColor = { 70, 75, 90, 180 },
                    alignItems = "center", justifyContent = "center",
                    cursor = "pointer",
                    onClick = function()
                        Utils.PlayClick()
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
                -- 解锁弹窗 overlay
                dialogOverlay,
            },
        }

        UI.SetRoot(UI.SafeAreaView {
            edges = "all", width = "100%", height = "100%",
            children = { rootWithX },
        })
    end

    Rebuild()
end

return CharacterScreen
