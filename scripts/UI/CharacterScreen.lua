-- ============================================================================
-- UI/CharacterScreen.lua - 角色图鉴页（增量更新版）
-- ============================================================================
-- 布局：上中下三栏
--   上：标题栏（"角色"标题 + 点券余额 + 角色币余额）
--   中：三列内容区
--       左列：头像选择网格（可滚动，固定宽）
--       中列：角色立绘（全高 contain，flexGrow）
--       右列：专精/名字/能力/揭示/描述/解锁（可滚动，固定宽）
--   下：底栏（返回按钮）
--
-- 增量更新：选角色只更新变化部分（边框/立绘/详情），不全量重建 UI 树
-- ============================================================================

local UI                = require("urhox-libs/UI")
local UIState           = require("UI.UIState")
local Utils             = require("UI.Utils")
local SaveSystem        = require("SaveSystem")
local Characters        = require("Config.Characters")
local UnlockCharDialog  = require("UI.UnlockCharDialog")
local MoneyHUD          = require("UI.MoneyHUD")

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
-- 状态
-- ============================================================================

local selectedCharId = nil

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
    t = t:gsub("category_all",          "全部")
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

    local function GetCharById(id)
        for _, c in ipairs(Characters.CHARACTERS) do
            if c.id == id then return c end
        end
        return nil
    end

    -- ── 持久 widget 引用（增量更新用） ──────────────────────────────
    local avatarWidgets = {}    -- { [charId] = { card=widget, badge=widget|nil } }
    local portraitPanel         -- 中列立绘面板
    local specLabel             -- 专精 chip 文字
    local nameLabel             -- 角色名
    local abilityLabel          -- 能力副标题
    local descLabel             -- 描述
    local lockContainer         -- 底部解锁按钮容器
    local ticketBalLabel        -- 顶栏点券余额文字
    local coinBalLabel          -- 顶栏角色币余额文字

    -- ── 回退 ─────────────────────────────────────────────────────────
    local function doBack()
        UnsubscribeFromEvent("KeyDown")
        if onBackCallback then onBackCallback() end
    end

    -- ── 前向声明增量刷新函数 ──────────────────────────────────────
    local SelectChar, RefreshAfterUnlock

    -- ── 解锁弹窗 ─────────────────────────────────────────────────────
    local unlockDialog = UnlockCharDialog.Create({
        sz = sz,
        onUnlocked = function()
            RefreshAfterUnlock()
        end,
    })

    -- ── ESC 处理 ──────────────────────────────────────────────────────
    local function setupKeyHandler()
        UnsubscribeFromEvent("KeyDown")
        SubscribeToEvent("KeyDown", function(_, evData)
            local key = evData["Key"]:GetInt()
            if key == KEY_ESCAPE then
                if MoneyHUD.IsPopupOpen() then
                    MoneyHUD.HidePopup()
                elseif unlockDialog.isOpen() then
                    unlockDialog.hide()
                else
                    doBack()
                end
            end
        end)
    end

    -- ====================================================================
    -- 创建锁定节点（按需）
    -- ====================================================================
    local function CreateLockNode(char)
        local unlocked = not char.locked or SaveSystem.IsCharacterUnlocked(char.id)
        if unlocked then return nil end

        if char.unlockCost and char.unlockCost > 0 then
            return UI.Panel {
                width = "100%", flexDirection = "column", gap = sz(8),
                children = {
                    UI.Panel {
                        width = "100%", flexDirection = "row",
                        alignItems = "center", justifyContent = "center",
                        gap = sz(8), paddingVertical = sz(11),
                        backgroundColor = { 130, 100, 20, 220 }, borderRadius = sz(6),
                        borderWidth = 1, borderColor = { 200, 165, 50, 180 },
                        cursor = "pointer",
                        onClick = function()
                            Utils.PlayClick()
                            unlockDialog.show(char)
                        end,
                        children = {
                            UI.Panel {
                                width = sz(16), height = sz(16),
                                backgroundImage = "image/point_ticket_icon_20260518210650.png",
                                backgroundFit = "contain", flexShrink = 0,
                            },
                            UI.Label {
                                text = "300 点券  解锁",
                                fontSize = sz(13), fontWeight = "bold",
                                fontColor = { 255, 225, 80, 255 },
                            },
                        },
                    },
                },
            }
        else
            return UI.Panel {
                width = "100%",
                paddingHorizontal = sz(14), paddingVertical = sz(10),
                backgroundColor = { 30, 20, 10, 200 }, borderRadius = sz(6),
                borderWidth = 1, borderColor = { 120, 80, 20, 180 }, marginTop = sz(8),
                children = {
                    UI.Label {
                        text = "🔒  " .. (char.unlockDesc or "完成特定条件后解锁"),
                        fontSize = sz(12), fontColor = { 200, 170, 90, 230 }, flexShrink = 1,
                    },
                },
            }
        end
    end

    -- ====================================================================
    -- SelectChar: 增量更新选中角色（不重建 UI 树）
    -- ====================================================================
    SelectChar = function(newId)
        local oldId = selectedCharId
        if newId == oldId then return end
        selectedCharId = newId

        -- 1) 更新头像网格边框
        local oldW = avatarWidgets[oldId]
        if oldW then
            oldW.card:SetStyle({
                borderWidth = 1,
                borderColor = { 55, 58, 75, 180 },
            })
        end
        local newW = avatarWidgets[newId]
        if newW then
            newW.card:SetStyle({
                borderWidth = 2,
                borderColor = { 255, 255, 255, 255 },
            })
        end

        -- 2) 更新中列立绘
        local char = GetSelectedChar()
        if char.portrait then
            portraitPanel:SetStyle({
                backgroundImage = char.portrait,
                backgroundColor = nil,
            })
        else
            portraitPanel:SetStyle({
                backgroundImage = "",
                backgroundColor = { 18, 20, 35, 100 },
            })
        end

        -- 3) 更新右列详情
        local spec = GetSpecialtyLabel(char.specialty)
        specLabel.text = spec .. "专精"
        nameLabel.text = char.name
        abilityLabel.text = char.ability or ""
        descLabel.text = char.desc or ""

        -- 4) 更新底部锁定/解锁区域
        lockContainer:ClearChildren()
        local lockNode = CreateLockNode(char)
        if lockNode then
            lockContainer:SetStyle({ visible = true })
            lockContainer:AddChild(lockNode)
        else
            lockContainer:SetStyle({ visible = false })
        end
    end

    -- ====================================================================
    -- RefreshAfterUnlock: 解锁后刷新（余额 + 徽章 + 当前详情）
    -- ====================================================================
    RefreshAfterUnlock = function()
        -- 更新顶栏余额
        ticketBalLabel.text = tostring(SaveSystem.GetPointTickets())
        coinBalLabel.text   = tostring(SaveSystem.GetCharacterCoins())

        -- 更新所有头像的锁定徽章
        for _, c in ipairs(Characters.CHARACTERS) do
            local w = avatarWidgets[c.id]
            if w and w.badge then
                local isUnlocked = not c.locked or SaveSystem.IsCharacterUnlocked(c.id)
                w.badge:SetStyle({ visible = not isUnlocked })
            end
        end

        -- 更新右列底部锁定/解锁区域
        local char = GetSelectedChar()
        lockContainer:ClearChildren()
        local lockNode = CreateLockNode(char)
        if lockNode then
            lockContainer:SetStyle({ visible = true })
            lockContainer:AddChild(lockNode)
        else
            lockContainer:SetStyle({ visible = false })
        end
    end

    -- ====================================================================
    -- 一次性构建完整 UI 树
    -- ====================================================================

    local char     = GetSelectedChar()
    local spec     = GetSpecialtyLabel(char.specialty)

    -- ── 左列：头像网格 ───────────────────────────────────────────
    local avatarCards = {}
    for _, c in ipairs(Characters.CHARACTERS) do
        local cId   = c.id
        local cOk   = not c.locked or SaveSystem.IsCharacterUnlocked(c.id)
        local isSel = cId == selectedCharId

        local badge = UI.Panel {
            position = "absolute", right = sz(3), top = sz(3),
            width = sz(16), height = sz(16), borderRadius = sz(8),
            backgroundColor = { 10, 10, 18, 210 },
            alignItems = "center", justifyContent = "center",
            visible = not cOk,
            children = {
                UI.Panel {
                    width = sz(10), height = sz(10),
                    backgroundImage = "image/lock_icon_white_20260518134104.png",
                    backgroundFit = "contain",
                },
            },
        }

        local card = UI.Panel {
            width = sz(62), height = sz(62), overflow = "hidden",
            backgroundColor = { 22, 25, 40, 255 },
            backgroundImage = c.avatar, backgroundFit = "cover",
            borderWidth = isSel and 2 or 1,
            borderColor = isSel and { 255, 255, 255, 255 } or { 55, 58, 75, 180 },
            cursor = "pointer",
            onClick = function()
                Utils.PlayClick()
                SelectChar(cId)
            end,
            children = { badge },
        }

        avatarWidgets[cId] = { card = card, badge = badge }
        table.insert(avatarCards, card)
    end

    -- ── 中列：立绘面板 ──────────────────────────────────────────
    portraitPanel = UI.Panel {
        position = "absolute", left = 0, top = 0, right = 0, bottom = 0,
        backgroundImage = char.portrait or "",
        backgroundFit = "contain",
        backgroundColor = char.portrait and nil or { 18, 20, 35, 100 },
    }

    -- ── 右列：详情组件（持有引用） ──────────────────────────────
    specLabel = UI.Label {
        text = spec .. "专精",
        fontSize = sz(11), fontWeight = "bold",
        fontColor = { 245, 230, 150, 255 },
    }
    nameLabel = UI.Label {
        text = char.name,
        fontSize = sz(30), fontWeight = "bold",
        fontColor = { 242, 235, 210, 255 },
    }
    abilityLabel = UI.Label {
        text = char.ability or "",
        fontSize = sz(13),
        fontColor = { 195, 180, 115, 230 },
        letterSpacing = 1,
    }
    descLabel = UI.Label {
        text = char.desc or "",
        fontSize = sz(12),
        fontColor = { 185, 195, 215, 210 }, flexShrink = 1,
    }

    -- 底部锁定容器（仅包裹锁定内容，增量增删子节点）
    local initLockNode = CreateLockNode(char)
    lockContainer = UI.Panel {
        width = "100%",
        paddingHorizontal = sz(14), paddingVertical = sz(10),
        borderTopWidth = 1, borderColor = { 60, 60, 70, 150 },
        backgroundColor = { 10, 10, 15, 200 },
        visible = initLockNode ~= nil,
        children = initLockNode and { initLockNode } or {},
    }

    -- ── 顶部标题栏 ────────────────────────────────────────────────
    ticketBalLabel = UI.Label {
        text = tostring(SaveSystem.GetPointTickets()),
        fontSize = sz(13), fontWeight = "bold",
        fontColor = { 255, 215, 55, 255 },
    }
    coinBalLabel = UI.Label {
        text = tostring(SaveSystem.GetCharacterCoins()),
        fontSize = sz(13), fontWeight = "bold",
        fontColor = { 130, 215, 255, 255 },
    }

    local topBar = UI.Panel {
        width = "100%", height = sz(50), flexShrink = 0,
        flexDirection = "row", alignItems = "center",
        paddingHorizontal = sz(16), gap = sz(10),
        children = {
            UI.Panel {
                width = sz(22), height = sz(22), flexShrink = 0,
                backgroundImage = "image/icon_character_20260521112450.png",
                backgroundFit = "contain",
                pointerEvents = "none",
            },
            UI.Label {
                text = "角色",
                fontSize = sz(16), fontWeight = "bold",
                fontColor = { 235, 220, 155, 255 },
            },
            UI.Panel { flexGrow = 1 },
            -- 点券余额（点击打开"我的资产"）
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = sz(5),
                paddingHorizontal = sz(10), paddingVertical = sz(4),
                backgroundColor = { 60, 48, 8, 200 }, borderRadius = sz(14),
                borderWidth = 1, borderColor = { 160, 130, 30, 160 },
                cursor = "pointer",
                onClick = function()
                    Utils.PlayClick()
                    MoneyHUD.TogglePopup()
                end,
                children = {
                    UI.Panel {
                        width = sz(18), height = sz(18),
                        backgroundImage = "image/point_ticket_icon_20260518210650.png",
                        backgroundFit = "contain", flexShrink = 0,
                    },
                    ticketBalLabel,
                },
            },
            -- 角色币余额
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = sz(5),
                paddingHorizontal = sz(10), paddingVertical = sz(4),
                backgroundColor = { 8, 40, 60, 200 }, borderRadius = sz(14),
                borderWidth = 1, borderColor = { 50, 130, 180, 160 },
                children = {
                    UI.Panel {
                        width = sz(18), height = sz(18),
                        backgroundImage = "Textures/tickets/character_coin.png",
                        backgroundFit = "contain", flexShrink = 0,
                    },
                    coinBalLabel,
                },
            },
            -- ✕ 关闭按钮
            UI.Panel {
                width = sz(28), height = sz(28), borderRadius = sz(14),
                flexShrink = 0, justifyContent = "center", alignItems = "center",
                marginLeft = sz(4),
                hoverBackgroundColor = { 255, 255, 255, 20 },
                pressedBackgroundColor = { 255, 255, 255, 40 },
                onClick = function()
                    Utils.PlayClick()
                    doBack()
                end,
                children = {
                    UI.Label { text = "✕", fontSize = sz(14), fontColor = { 180, 170, 140, 200 } },
                },
            },
        },
    }

    -- ── 底部操作栏 ────────────────────────────────────────────────
    local bottomBar = UI.Panel {
        width = "100%", height = sz(58), flexShrink = 0,
        flexDirection = "row", alignItems = "center",
        paddingHorizontal = sz(16),
        children = {
            UI.Button {
                text = "返回",
                fontSize = sz(14), fontWeight = "bold",
                fontColor = { 195, 215, 40, 230 },
                paddingHorizontal = sz(28), paddingVertical = sz(10),
                backgroundColor = { 195, 215, 40, 18 },
                hoverBackgroundColor = { 195, 215, 40, 50 },
                pressedBackgroundColor = { 195, 215, 40, 110 },
                borderWidth = 1, borderColor = { 195, 215, 40, 160 },
                borderRadius = sz(4),
                onClick = function()
                    Utils.PlayClick()
                    doBack()
                end,
            },
        },
    }

    -- ── 中间三列内容区 ────────────────────────────────────────────
    local contentArea = UI.Panel {
        width = "100%", flexGrow = 1, flexShrink = 1,
        flexDirection = "row",
        children = {

            -- ===== 左列：头像选择网格 =====
            UI.Panel {
                width = sz(220), flexShrink = 0,
                flexDirection = "column",
                children = {
                    -- 半透明背景层（纹理 + 深色遮罩）
                    UI.Panel {
                        position = "absolute", left = 0, top = 0, right = 0, bottom = 0,
                        backgroundImage = "image/bg_texture_minimal_20260519075800.jpg",
                        backgroundFit = "cover",
                        backgroundColor = { 10, 10, 18, 200 },
                        opacity = 0.45,
                        pointerEvents = "none",
                    },
                    UI.ScrollView {
                        width = "100%", flexGrow = 1,
                        padding = sz(10),
                        children = {
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", flexWrap = "wrap", gap = sz(6),
                                children = avatarCards,
                            },
                        },
                    },
                },
            },

            -- ===== 中列：角色立绘 =====
            UI.Panel {
                flexGrow = 1, flexShrink = 1, height = "100%",
                overflow = "hidden",
                children = { portraitPanel },
            },

            -- ===== 右列：技能/详情/解锁 =====
            UI.Panel {
                width = sz(280), flexShrink = 0,
                flexDirection = "column",
                children = {
                    -- 半透明背景层（纹理 + 深色遮罩）
                    UI.Panel {
                        position = "absolute", left = 0, top = 0, right = 0, bottom = 0,
                        backgroundImage = "image/bg_texture_minimal_20260519075800.jpg",
                        backgroundFit = "cover",
                        backgroundColor = { 10, 10, 18, 200 },
                        opacity = 0.45,
                        pointerEvents = "none",
                    },
                    -- 可滚动内容
                    UI.ScrollView {
                        width = "100%", flexGrow = 1,
                        padding = sz(18),
                        children = {
                            UI.Panel {
                                width = "100%", flexDirection = "column", gap = sz(10),
                                children = {
                                    -- 专精 chip
                                    UI.Panel {
                                        flexDirection = "row",
                                        children = {
                                            UI.Panel {
                                                paddingHorizontal = sz(10), paddingVertical = sz(4),
                                                backgroundColor = { 145, 130, 30, 230 }, borderRadius = sz(3),
                                                children = { specLabel },
                                            },
                                        },
                                    },
                                    -- 角色名
                                    nameLabel,
                                    -- 能力副标题
                                    abilityLabel,
                                    -- 分隔线
                                    UI.Panel {
                                        width = "100%", height = 1,
                                        backgroundColor = { 40, 44, 70, 180 },
                                        marginVertical = sz(4),
                                    },
                                    -- 描述
                                    descLabel,
                                },
                            },
                        },
                    },
                    -- 固定底部：解锁按钮容器
                    lockContainer,
                },
            },
        },
    }

    -- ── SetRoot（仅调用一次） ─────────────────────────────────────
    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        backgroundImage = "image/char_screen_bg.jpg",
        backgroundFit = "cover", backgroundPosition = "center",
        children = {
            UI.SafeAreaView {
                edges = "all", width = "100%", height = "100%",
                children = {
                    UI.Panel {
                        width = "100%", height = "100%",
                        flexDirection = "column",
                        children = {
                            topBar,
                            contentArea,
                            bottomBar,
                            unlockDialog.panel,
                            MoneyHUD.CreatePopup(),
                        },
                    },
                },
            },
        },
    })

    setupKeyHandler()
end

return CharacterScreen
