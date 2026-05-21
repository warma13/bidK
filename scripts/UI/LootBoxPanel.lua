-- ============================================================================
-- UI/LootBoxPanel.lua - 礼盒开箱面板
-- 流程：idle → 点击"开启" → 抖动动画 → 展示奖励结果 → 确认关闭
-- ============================================================================

local UI       = require("urhox-libs/UI")
local Utils    = require("UI.Utils")
local LootBox  = require("LootBox")
local GameLoop = require("GameLoop")

local LootBoxPanel = {}

-- ============================================================================
-- 品质配色
-- ============================================================================
local TIER_STYLE = {
    white  = { glow = { 200, 205, 215, 255 }, label = "普通",   },
    green  = { glow = { 80,  230, 120, 255 }, label = "优秀",   },
    blue   = { glow = { 80,  160, 255, 255 }, label = "精良",   },
    purple = { glow = { 190, 80,  255, 255 }, label = "史诗",   },
    gold   = { glow = { 255, 200, 40,  255 }, label = "金色",   },
    red    = { glow = { 255, 60,  70,  255 }, label = "极稀有", },
}
local function GetStyle(tier) return TIER_STYLE[tier] or TIER_STYLE.white end

-- ============================================================================
-- 主入口：返回一个 overlay Panel，调用方 AddChild 到根节点
-- ============================================================================

---@param chestDef table  Props 里的礼盒定义
---@param onClose  fun()  关闭后回调（刷新背包用）
---@return any  overlay Panel（直接 AddChild 到父容器）
function LootBoxPanel.Show(chestDef, onClose)
    local sz = Utils.sz

    -- ── 状态 ─────────────────────────────────────────
    local phase        = "idle"   -- "idle" | "opening" | "result"
    local animTime     = 0
    local ANIM_DUR     = 1.1
    local rolledResult = nil
    local animActive   = true    -- false 后 GameLoop tick 自动跳过

    -- ── 前向声明节点引用 ─────────────────────────────
    ---@type any
    local overlayRoot  = nil
    ---@type any
    local chestWrap    = nil   -- 箱子容器（抖动用）
    ---@type any
    local openBtn      = nil   -- 开启按钮
    ---@type any
    local confirmBtn   = nil   -- 确认关闭按钮
    ---@type any
    local descRow      = nil   -- 底部概率说明行
    ---@type any
    local contentArea  = nil   -- 动态内容区（注入奖励卡）

    -- ── 关闭 ─────────────────────────────────────────
    local function Close()
        animActive = false
        if overlayRoot then overlayRoot:SetVisible(false) end
        if onClose then onClose() end
    end

    -- ── 展示奖励卡 ───────────────────────────────────
    local function ShowResult(result)
        phase = "result"
        local style = GetStyle(result.quality)
        local isRed = result.quality == "red"

        -- 统一展示字段（藏品 / 道具 共用）
        local def
        if result.type == "prop" then
            local p = result.prop
            def = {
                name      = p.name,
                desc      = p.desc or "",
                icon      = p.icon or "📦",
                iconImage = (p.iconImage and p.iconImage ~= "") and p.iconImage or nil,
                isProp    = true,
            }
        else
            local item = result.item
            def = {
                name      = item.name,
                desc      = item.desc or "",
                icon      = "🎁",
                iconImage = (item.image and item.image ~= "") and item.image or nil,
            }
        end

        if chestWrap then chestWrap:SetVisible(false) end
        if openBtn   then openBtn:SetVisible(false)   end
        if descRow   then descRow:SetVisible(false)   end

        -- 品质配色（仓库同款）
        local TIER_BG     = { white={34,36,44,255},  green={22,38,30,255},   blue={18,30,55,255},
                              purple={28,18,42,255}, gold={38,28,8,255},     red={40,8,12,255} }
        local HEX_TINT    = { white=nil, green={80,230,120,255}, blue={80,160,255,255},
                              purple={200,100,255,255}, gold={255,200,60,255}, red={255,80,90,255} }
        local cardBg     = TIER_BG[result.quality]     or TIER_BG.white
        local cardBorder = { style.glow[1], style.glow[2], style.glow[3], 200 }
        local hexTint    = HEX_TINT[result.quality]
        local iconSize   = isRed and sz(100) or sz(80)

        local rewardCard = UI.Panel {
            width         = sz(200),
            flexDirection = "column",
            alignItems    = "center",
            backgroundColor = cardBg,
            borderWidth   = isRed and 2 or 1,
            borderColor   = cardBorder,
            borderRadius  = sz(3),
            overflow      = "hidden",
            backgroundImage = "image/backpack_card_bg_20260518071322.png",
            backgroundFit   = "cover",
            children = {
                -- 顶部名称条
                UI.Panel {
                    width = "100%",
                    paddingVertical = sz(7), paddingHorizontal = sz(8),
                    alignItems = "center",
                    borderBottomWidth = 1, borderColor = cardBorder,
                    children = {
                        UI.Label {
                            text = def.name,
                            fontSize = isRed and sz(15) or sz(13),
                            fontWeight = "bold",
                            fontColor  = style.glow,
                            textAlign  = "center",
                        },
                    },
                },
                -- 图标区
                UI.Panel {
                    width = "100%", height = iconSize + sz(20),
                    alignItems = "center", justifyContent = "center",
                    children = {
                        def.isProp and (
                            -- 道具：六边形框（仓库同款）
                            UI.Panel {
                                width = sz(84), height = sz(84),
                                alignItems = "center", justifyContent = "center",
                                children = {
                                    UI.Panel {
                                        position = "absolute",
                                        width = sz(74), height = sz(84),
                                        backgroundImage = "image/ui_hex_frame_trimmed.png",
                                        backgroundFit = "fill",
                                        imageTint = hexTint,
                                    },
                                    def.iconImage and UI.Panel {
                                        width = sz(44), height = sz(44),
                                        backgroundImage = def.iconImage,
                                        backgroundFit   = "contain",
                                    } or UI.Label { text = def.icon or "📦", fontSize = sz(30) },
                                },
                            }
                        ) or (
                            -- 藏品 / 礼盒：直接显示大图
                            def.iconImage and UI.Panel {
                                width = iconSize, height = iconSize,
                                backgroundImage = def.iconImage,
                                backgroundFit   = "contain",
                            } or UI.Label { text = def.icon or "🎁", fontSize = isRed and sz(52) or sz(40) }
                        ),
                    },
                },

                -- 描述
                UI.Panel {
                    width = "100%",
                    paddingHorizontal = sz(10), paddingVertical = sz(8),
                    alignItems = "center",
                    children = {
                        UI.Label {
                            text      = def.desc, fontSize = sz(11),
                            fontColor = { 175, 180, 200, 190 },
                            textAlign = "center", flexShrink = 1,
                        },
                    },
                },
            },
        }

        local card = rewardCard

        if contentArea then contentArea:AddChild(card) end
        if confirmBtn  then confirmBtn:SetVisible(true) end
    end

    -- ── 帧更新（弹跳抖动动画）通过 GameLoop 驱动，不直接订阅 Update ──
    -- 动画节奏（总时长 ANIM_DUR = 1.1s）：
    --   0.00~0.30s  蓄力：小幅颤抖，越来越快
    --   0.30~0.85s  爆发：大幅左右跳动 + 上下弹跳
    --   0.85~1.10s  收尾：快速衰减归位
    GameLoop.RegisterAlways("LootBoxPanel_anim", function(dt)
        if not animActive then return end
        if phase ~= "opening" then return end
        animTime = animTime + dt

        if chestWrap then
            local t = animTime / ANIM_DUR  -- 0→1 归一化进度

            local shakeX, shakeY = 0, 0

            if t < 0.25 then
                -- 蓄力：纯左右小颤抖，幅度渐大
                local p   = t / 0.25
                shakeX = math.sin(animTime * 22) * sz(3) * p * p
                shakeY = 0

            elseif t < 0.85 then
                -- 爆发：左右高频抖动 + 上下低频跳动（频率差异大，不会转圈）
                local p   = (t - 0.25) / 0.60
                local env = math.sin(p * math.pi)   -- 钟形包络 0→1→0
                -- X：高频左右抖动（~25 Hz）
                shakeX = math.sin(animTime * 25) * sz(14) * env
                -- Y：低频跳动（~6 Hz），abs(sin) 模拟弹跳，负值 = 向上
                shakeY = -math.abs(math.sin(animTime * 6)) * sz(12) * env

            else
                -- 收尾：快速衰减，只剩轻微左右
                local p   = (t - 0.85) / 0.15
                local amp = sz(5) * (1 - p) * (1 - p)
                shakeX = math.sin(animTime * 30) * amp
                shakeY = 0
            end

            chestWrap.props.translateX = shakeX
            chestWrap.props.translateY = shakeY
        end

        if animTime >= ANIM_DUR then
            phase = "committing"
            if chestWrap then
                chestWrap.props.translateX = 0
                chestWrap.props.translateY = 0
            end
            LootBox.Commit(chestDef.id, rolledResult)
            ShowResult(rolledResult)
        end
    end)

    -- ── 点击开启 ─────────────────────────────────────
    local function OnOpen()
        if phase ~= "idle" then return end
        if not LootBox.HasStock(chestDef.id) then
            Close(); return
        end
        local result, err = LootBox.Roll(chestDef.id)
        if not result then
            print("[LootBoxPanel] Roll failed: " .. (err or "?"))
            Close(); return
        end
        rolledResult = result
        phase        = "opening"
        animTime     = 0
        Utils.PlayClick()
    end

    -- ── 构建 UI 树 ────────────────────────────────────
    local chestStyle = GetStyle(chestDef.tier or "gold")

    chestWrap = UI.Panel {
        width = sz(150), height = sz(150),
        alignItems = "center", justifyContent = "center",
        children = {
            UI.Panel {
                width = sz(130), height = sz(130),
                backgroundImage = chestDef.iconImage or "image/chest_luxury_20260517200416.png",
                backgroundFit   = "contain",
            },
        },
    }

    contentArea = UI.Panel {
        flexGrow       = 1,
        flexDirection  = "column",
        alignItems     = "center",
        justifyContent = "center",
        gap            = sz(6),
        children       = { chestWrap },
    }

    openBtn = UI.Panel {
        width = sz(200), height = sz(48),
        backgroundColor = { 200, 170, 20, 255 },
        borderRadius    = 0,
        alignItems      = "center", justifyContent = "center",
        cursor          = "pointer",
        onClick         = OnOpen,
        children = {
            UI.Panel {
                position = "absolute",
                left = sz(8), top = 0, bottom = 0, width = sz(4),
                backgroundColor = { 255, 255, 255, 50 },
                pointerEvents   = "none",
            },
            UI.Label {
                text = "开 启 礼 盒",
                fontSize = sz(16), fontWeight = "bold",
                fontColor = { 15, 10, 0, 255 },
                letterSpacing = sz(2),
            },
        },
    }

    confirmBtn = UI.Panel {
        width = sz(200), height = sz(44),
        backgroundColor = { 40, 43, 60, 230 },
        borderWidth = 1, borderColor = { 75, 80, 105, 180 },
        borderRadius    = 0,
        alignItems      = "center", justifyContent = "center",
        cursor          = "pointer",
        visible         = false,
        onClick         = function()
            Utils.PlayClick()
            Close()
        end,
        children = {
            UI.Label {
                text = "收下，关闭",
                fontSize = sz(14), fontWeight = "bold",
                fontColor = { 200, 205, 225, 230 },
            },
        },
    }

    -- 道具箱不显示红色概率行，仅藏品礼盒显示
    if not chestDef.isPropBox then
        local redDesc = chestDef.id == "chest_gold"
            and "必出红色品质藏品，0.1% 极稀有限定"
            or  "0.01% 概率获得极稀有红色限定藏品"
        descRow = UI.Panel {
            flexDirection = "row", alignItems = "center", gap = sz(5),
            children = {
                UI.Label {
                    text = "★",
                    fontSize = sz(10), fontWeight = "bold",
                    fontColor = { 255, 80, 90, 230 },
                },
                UI.Label {
                    text = redDesc,
                    fontSize  = sz(10),
                    fontColor = { 135, 140, 165, 175 },
                },
            },
        }
    end

    overlayRoot = UI.Panel {
        position        = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 185 },
        alignItems      = "center",
        justifyContent  = "center",
        children = {
            -- 卡片主体
            UI.Panel {
                width           = sz(320),
                flexDirection   = "column",
                alignItems      = "center",
                backgroundColor = { 12, 14, 24, 252 },
                borderRadius    = sz(6),
                borderWidth     = 1,
                borderColor     = chestStyle.glow,
                overflow        = "hidden",
                children = {
                    -- ── 顶栏 ──
                    UI.Panel {
                        width           = "100%",
                        paddingHorizontal = sz(16), paddingVertical = sz(11),
                        flexDirection   = "row", alignItems = "center",
                        backgroundColor = { 18, 20, 33, 255 },
                        borderBottomWidth = 1, borderColor = { 45, 50, 70, 160 },
                        children = {
                            UI.Label {
                                text = chestDef.name,
                                fontSize = sz(15), fontWeight = "bold",
                                fontColor = { 235, 220, 190, 255 },
                                flexGrow = 1,
                            },
                            UI.Panel {
                                width = sz(28), height = sz(28),
                                borderRadius = sz(4),
                                backgroundColor = { 38, 40, 56, 200 },
                                borderWidth = 1, borderColor = { 68, 72, 92, 180 },
                                alignItems = "center", justifyContent = "center",
                                cursor = "pointer",
                                onClick = function()
                                    Utils.PlayClick()
                                    Close()
                                end,
                                children = {
                                    UI.Label {
                                        text = "✕", fontSize = sz(14),
                                        fontColor = { 175, 180, 200, 220 },
                                    },
                                },
                            },
                        },
                    },
                    -- ── 内容区 ──
                    UI.Panel {
                        width = "100%",
                        paddingVertical = sz(20),
                        flexDirection = "column", alignItems = "center",
                        justifyContent = "center",
                        children = { contentArea },
                    },
                    -- ── 底部按钮区 ──
                    UI.Panel {
                        width = "100%",
                        paddingHorizontal = sz(16), paddingBottom = sz(16), paddingTop = sz(10),
                        flexDirection = "column", alignItems = "center", gap = sz(8),
                        borderTopWidth = 1, borderColor = { 40, 44, 62, 120 },
                        children = { openBtn, confirmBtn, descRow },
                    },
                },
            },
        },
    }

    return overlayRoot
end

return LootBoxPanel
