-- ============================================================================
-- UI/SeasonPassPanel.lua - 赛季通行证页面
-- ============================================================================

---@diagnostic disable: undefined-global

local UI                 = require("urhox-libs/UI")
local Config             = require("Config.SeasonPass")
local GlobalConfig       = require("Config")
local Props              = require("Config.Props")
local Chests             = require("Config.Chests")
local SeasonPass         = require("SeasonPass")
local SaveFW             = require("SaveFramework")
local Utils              = require("UI.Utils")
local FloatingMessage    = require("UI.FloatingMessage")
local ItemDetailPanel    = require("UI.ItemDetailPanel")
local RewardItemAdapter  = require("UI.RewardItemAdapter")

local SeasonPassPanel = {}

-- ============================================================================
-- 常量
-- ============================================================================

local CARD_W    = 80    -- 单张奖励卡片宽度
local CARD_H    = 90    -- 奖励卡片总高度（含标头+图标区）
local HEADER_H  = 22    -- 卡片标头（VIP/免费标签）高度
local CARD_GAP  = 3     -- 同一等级内卡片间距
local CELL_GAP  = 8     -- 不同等级之间的间距
local LEVEL_H   = 22    -- 底部等级号行高
local CELL_PAD_H = 5   -- 奖励区左右内边距
local CELL_PAD_T = 5   -- 奖励区顶部内边距
local CELL_PAD_B = 5   -- 奖励区底部内边距
local TIER_H    = CARD_H + LEVEL_H + CELL_PAD_T + CELL_PAD_B  -- 等级格总高度

local COLOR_VIP_BG      = { 180, 140, 40,  255 }
local COLOR_VIP_LOCKED  = { 60,  45,  15,  200 }
local COLOR_CLAIMED     = { 40,  120, 60,  255 }
local COLOR_XP_BAR      = { 195, 215, 40,  255 }
local COLOR_SEASON_ITEM = { 220, 60,  60,  255 }

-- ============================================================================
-- 工具
-- ============================================================================

local function RewardLabel(reward)
    if reward.type == "coins" then
        local n = reward.amount
        return n >= 10000 and string.format("%.0f万", n / 10000) or tostring(n)
    elseif reward.type == "chest" then
        return "×" .. (reward.count or 1)
    elseif reward.type == "tickets" then
        return "×" .. (reward.count or 1)
    end
    return ""
end

local function RewardColor(reward)
    if reward.type == "item"  then return COLOR_SEASON_ITEM end
    if reward.type == "chest" then
        local def = Chests.BY_ID[reward.id]
        if def then
            if def.tier == "gold"   then return { 255, 200, 50,  255 } end
            if def.tier == "purple" then return { 180, 120, 255, 255 } end
            if def.tier == "blue"   then return { 80,  160, 255, 255 } end
        end
        return { 255, 200, 50, 255 }  -- 礼盒默认金色
    end
    return { 220, 220, 220, 255 }
end

local function RewardIcon(reward)
    if reward.type == "coins"   then return Utils.GetIcon("coin") end
    if reward.type == "chest"   then
        local def = Chests.BY_ID[reward.id]
        return (def and def.iconImage) or Utils.GetIcon("chest")
    end
    if reward.type == "tickets" then
        local tc = GlobalConfig.TICKETS[reward.ticketId]
        return (tc and tc.icon) or Utils.GetIcon("gift")
    end
    return Utils.GetIcon("gift")
end



-- ============================================================================
-- 上方：选中等级的奖励详情卡
-- ============================================================================

local function BuildDetailCard(lvl, currentLevel, vipUnlocked, onClaim)
    local tier    = Config.TIERS[lvl]
    local reached = lvl <= currentLevel

    local function RewardRow(reward, claimed, locked, tapFn)
        local canTap = tapFn and not claimed and not locked
        local col    = locked and { 80, 80, 80, 180 } or RewardColor(reward)
        local bg     = claimed and COLOR_CLAIMED
                    or locked  and { 35, 35, 40, 220 }
                    or { 50, 50, 58, 255 }
        return UI.Panel {
            width = "100%", height = 44,
            backgroundColor = bg,
            borderRadius = 6,
            flexDirection = "row",
            alignItems = "center",
            paddingLeft = 14, paddingRight = 14,
            marginBottom = 6,
            cursor  = canTap and "pointer" or nil,
            onClick = canTap and tapFn or nil,
            children = {
                UI.Label {
                    text = claimed and "✓ 已领取" or RewardLabel(reward),
                    fontSize = 14,
                    fontColor = claimed and { 130, 210, 130, 255 } or col,
                    flexGrow = 1,
                },
                canTap and UI.Label {
                    text = "领取",
                    fontSize = 12,
                    fontColor = { 255, 220, 80, 255 },
                } or nil,
            }
        }
    end

    local freeRows = {}
    for _, reward in ipairs(tier.free) do
        local claimed = SeasonPass.IsFreeClaimedAt(lvl)
        local locked  = not reached
        local tapFn   = (reached and not claimed) and function()
            Utils.PlayClick()
            local ok, msg = SeasonPass.ClaimFree(lvl)
            FloatingMessage.Show(ok and ("领取：" .. msg) or msg)
            if ok and onClaim then onClaim() end
        end or nil
        freeRows[#freeRows + 1] = RewardRow(reward, claimed, locked, tapFn)
    end
    if #freeRows == 0 then
        freeRows[1] = UI.Label {
            text = "本级无免费奖励", fontSize = 12,
            fontColor = { 80, 80, 85, 255 },
            marginBottom = 6,
        }
    end

    local vipRows = {}
    for pos, reward in ipairs(tier.vip) do
        local gIdx     = Config.VIP_INDEX[lvl] and Config.VIP_INDEX[lvl][pos] or 0
        local unlocked = (vipUnlocked >= gIdx) and reached
        local claimed  = SeasonPass.IsVipClaimed(gIdx)
        local locked   = not unlocked
        local claimable = unlocked and not claimed
        local tapFn    = (unlocked and not claimed) and function()
            Utils.PlayClick()
            local ok, msg = SeasonPass.ClaimVip(lvl, pos)
            FloatingMessage.Show(ok and ("领取：" .. msg) or msg)
            if ok and onClaim then onClaim() end
        end or nil
        -- VIP 行带金色左边条
        local row = UI.Panel {
            width = "100%", height = 44,
            backgroundColor = claimed  and COLOR_CLAIMED
                           or unlocked and { 55, 42, 12, 255 }
                           or            { 30, 22, 8,  220 },
            borderRadius = 6,
            flexDirection = "row",
            alignItems = "center",
            paddingLeft = 14, paddingRight = 14,
            marginBottom = 6,
            cursor  = (unlocked and not claimed) and "pointer" or nil,
            onClick = tapFn or nil,
            children = {
                -- 左边金色竖条
                UI.Panel {
                    width = 3, height = 24,
                    backgroundColor = claimed and { 100, 180, 100, 255 } or COLOR_VIP_BG,
                    borderRadius = 2,
                    marginRight = 10,
                },
                UI.Label {
                    text = claimed   and "✓ 已领取"
                        or locked    and ("🔒 广告×" .. gIdx .. " 解锁")
                        or RewardLabel(reward),
                    fontSize = 13,
                    fontColor = claimed  and { 130, 210, 130, 255 }
                             or locked   and { 100, 80,  25,  200 }
                             or RewardColor(reward),
                    flexGrow = 1,
                },
                UI.Label {
                    text = "高级",
                    fontSize = 10, fontWeight = "bold",
                    fontColor = claimed and { 100, 180, 100, 255 } or COLOR_VIP_BG,
                },
            }
        }
        vipRows[#vipRows + 1] = row
    end

    return UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexDirection = "column",
        paddingLeft = 16, paddingRight = 16,
        paddingTop = 16, paddingBottom = 8,
        children = {
            -- 等级标题
            UI.Panel {
                width = "100%", flexDirection = "row",
                alignItems = "center", marginBottom = 14,
                gap = 10,
                children = {
                    UI.Panel {
                        width = 40, height = 40,
                        backgroundColor = reached and { 195, 215, 40, 255 } or { 40, 40, 48, 255 },
                        borderRadius = 6,
                        justifyContent = "center", alignItems = "center",
                        children = {
                            UI.Label {
                                text = tostring(lvl),
                                fontSize = 18, fontWeight = "bold",
                                fontColor = reached and { 20, 18, 5, 255 } or { 100, 100, 105, 255 },
                            }
                        }
                    },
                    UI.Label {
                        text = reached and "已解锁" or ("需达到 Lv." .. lvl),
                        fontSize = 13,
                        fontColor = reached and { 180, 220, 100, 255 } or { 100, 100, 110, 255 },
                    },
                }
            },
            -- 免费奖励区
            UI.Label {
                text = "免费奖励", fontSize = 11,
                fontColor = { 150, 150, 158, 255 },
                marginBottom = 6,
            },
            table.unpack(freeRows),
            -- 高级奖励区
            UI.Label {
                text = "高级奖励", fontSize = 11,
                fontColor = { 180, 150, 60, 255 },
                marginBottom = 6, marginTop = 4,
            },
            table.unpack(vipRows),
        }
    }
end

-- ============================================================================
-- 计算等级格宽度（依据奖励卡片数量）
-- ============================================================================

local function GetCellWidth(lvl)
    local tier = Config.TIERS[lvl]
    local n = #tier.free + #tier.vip
    if n == 0 then n = 1 end
    return n * CARD_W + (n - 1) * CARD_GAP + CELL_PAD_H * 2
end

-- ============================================================================
-- 底部等级格：奖励卡片横排 + 等级号在底部
-- ============================================================================

local function BuildTierCell(lvl, currentLevel, selectedLvl, vipUnlocked, onSelect, onShowDetail)
    local tier       = Config.TIERS[lvl]
    local reached    = lvl <= currentLevel
    local isSelected = lvl == selectedLvl
    local cellW      = GetCellWidth(lvl)

    -- 检查可领取红点
    local hasFreeClaimable = reached and not SeasonPass.IsFreeClaimedAt(lvl) and #tier.free > 0
    local hasVipClaimable  = false
    for pos = 1, #tier.vip do
        local gIdx = Config.VIP_INDEX[lvl] and Config.VIP_INDEX[lvl][pos] or 0
        if reached and (vipUnlocked >= gIdx) and not SeasonPass.IsVipClaimed(gIdx) then
            hasVipClaimable = true; break
        end
    end
    local hasClaimable = hasFreeClaimable or hasVipClaimable

    -- ---- 构建卡片（免费在前，高级在后）----
    local cards = {}

    -- 免费奖励卡（先放）
    for _, reward in ipairs(tier.free) do
        local claimed    = SeasonPass.IsFreeClaimedAt(lvl)
        local claimable  = reached and not claimed
        local bodyBg     = claimed and { 30, 55, 35, 230 } or { 36, 36, 42, 230 }

        cards[#cards + 1] = UI.Panel {
            width = CARD_W, height = CARD_H,
            flexShrink = 0,
            flexDirection = "column",
            borderRadius = 4,
            borderWidth = 1,
            borderColor = claimed and { 60, 150, 70, 200 } or { 70, 72, 82, 180 },
            overflow = "hidden",
            children = {
                UI.Panel {
                    width = "100%", height = HEADER_H,
                    overflow = "hidden",
                    justifyContent = "center", alignItems = "center",
                    children = {
                        UI.Panel {
                            position = "absolute",
                            left = 0, top = 0, right = 0, bottom = 0,
                            backgroundImage = "image/free_row_bg_20260517185454.png",
                            backgroundFit = "cover",
                            opacity = claimed and 0.5 or 0.9,
                            pointerEvents = "none",
                        },
                        UI.Label {
                            text = claimed and "✓" or "免费",
                            fontSize = 10, fontWeight = "bold",
                            fontColor = claimed and { 160, 240, 160, 255 } or { 200, 200, 205, 255 },
                        },
                    },
                },
                UI.Panel {
                    flexGrow = 1, width = "100%",
                    backgroundColor = bodyBg,
                    justifyContent = "center", alignItems = "center",
                    cursor = "pointer",
                    onClick = function(self)
                        if onShowDetail then onShowDetail(self, reward) end
                    end,
                    children = {
                        UI.Panel {
                            width = 40, height = 40,
                            backgroundImage = RewardIcon(reward),
                            backgroundFit = "contain",
                            pointerEvents = "none",
                        },
                        UI.Label {
                            text = RewardLabel(reward),
                            position = "absolute", bottom = 3, right = 5,
                            fontSize = 10,
                            fontColor = claimed and { 120, 210, 130, 255 } or RewardColor(reward),
                            pointerEvents = "none",
                        },
                        claimable and UI.Panel {
                            position = "absolute", top = 2, right = 2,
                            width = 7, height = 7,
                            borderRadius = 4,
                            backgroundColor = { 230, 50, 50, 255 },
                            pointerEvents = "none",
                        } or nil,
                    },
                },
            },
        }
    end

    -- 高级奖励卡（后放）
    for pos, reward in ipairs(tier.vip) do
        local gIdx     = Config.VIP_INDEX[lvl] and Config.VIP_INDEX[lvl][pos] or 0
        local unlocked = (vipUnlocked >= gIdx) and reached
        local claimed  = SeasonPass.IsVipClaimed(gIdx)
        local locked   = not unlocked

        local bodyBg = claimed  and { 30, 55, 35, 230 }
                    or locked   and { 28, 22, 10, 230 }
                    or            { 42, 33, 12, 230 }

        cards[#cards + 1] = UI.Panel {
            width = CARD_W, height = CARD_H,
            flexShrink = 0,
            flexDirection = "column",
            borderRadius = 4,
            borderWidth = 1,
            borderColor = claimed and { 60, 150, 70, 200 }
                       or locked  and { 100, 75, 18, 180 }
                       or           { 160, 120, 30, 200 },
            overflow = "hidden",
            children = {
                -- 标头：VIP 标签，金色背景图
                UI.Panel {
                    width = "100%", height = HEADER_H,
                    overflow = "hidden",
                    justifyContent = "center", alignItems = "center",
                    children = {
                        UI.Panel {
                            position = "absolute",
                            left = 0, top = 0, right = 0, bottom = 0,
                            backgroundImage = "image/vip_row_bg_20260517185454.png",
                            backgroundFit = "cover",
                            opacity = claimed and 0.5 or (locked and 0.6 or 0.95),
                            pointerEvents = "none",
                        },
                        UI.Label {
                            text = claimed and "✓" or "高级",
                            fontSize = 10, fontWeight = "bold",
                            fontColor = claimed  and { 160, 240, 160, 255 }
                                     or locked   and { 150, 115,  30, 220 }
                                     or            {  20,  15,   5, 255 },
                        },
                    },
                },
                -- 图标区（flexGrow，撑满剩余高度）
                UI.Panel {
                    flexGrow = 1, width = "100%",
                    backgroundColor = bodyBg,
                    justifyContent = "center", alignItems = "center",
                    cursor = "pointer",
                    onClick = function(self)
                        if onShowDetail then onShowDetail(self, reward) end
                    end,
                    children = {
                        -- 主图标（居中）
                        UI.Panel {
                            width = 40, height = 40,
                            backgroundImage = RewardIcon(reward),
                            backgroundFit = "contain",
                            opacity = locked and 0.35 or 1.0,
                            pointerEvents = "none",
                        },
                        -- 数量（右下角，绝对定位）
                        UI.Label {
                            text = RewardLabel(reward),
                            position = "absolute", bottom = 3, right = 5,
                            fontSize = 10,
                            fontColor = locked  and { 130, 100, 25, 200 }
                                     or claimed and { 120, 210, 130, 255 }
                                     or RewardColor(reward),
                            pointerEvents = "none",
                        },
                        -- 锁图标（右上角，绝对定位，仅锁定时）
                        locked and UI.Panel {
                            position = "absolute", top = 2, right = 2,
                            width = 16, height = 16,
                            backgroundImage = "image/lock_icon_white_20260518134104.png",
                            backgroundFit = "contain",
                            opacity = 0.55,
                            pointerEvents = "none",
                        } or nil,
                        -- 红点（右上角，解锁未领取时）
                        claimable and UI.Panel {
                            position = "absolute", top = 2, right = 2,
                            width = 7, height = 7,
                            borderRadius = 4,
                            backgroundColor = { 230, 50, 50, 255 },
                            pointerEvents = "none",
                        } or nil,
                    },
                },
            },
        }
    end

    -- 若无奖励，放一个空占位
    if #cards == 0 then
        cards[1] = UI.Panel { width = CARD_W, height = CARD_H, flexShrink = 0 }
    end

    local levelBg    = hasClaimable and { 195, 215, 40, 255 }
                    or reached      and { 90,  88,  95, 255 }
                    or                  { 55,  53,  58, 200 }
    local levelColor = hasClaimable and { 18, 20, 8, 255 } or { 22, 22, 26, 255 }
    local borderCol  = hasClaimable and { 195, 215, 40, 220 }
                    or reached      and { 100, 98, 108, 180 }
                    or                  { 70,  68, 76,  140 }
    local bgCol      = reached and { 20, 20, 26, 150 } or { 12, 12, 16, 130 }

    return UI.Panel {
        width      = cellW,
        height     = TIER_H,
        flexShrink = 0,
        flexDirection = "column",
        backgroundColor = bgCol,
        borderWidth = 2,
        borderColor = borderCol,
        borderRadius = 6,
        overflow = "hidden",
        children = {
            -- 卡片行（带内边距，卡片之间有间距）
            UI.Panel {
                width = cellW,
                height = CARD_H + CELL_PAD_T + CELL_PAD_B,
                paddingTop = CELL_PAD_T,
                paddingBottom = CELL_PAD_B,
                paddingHorizontal = CELL_PAD_H,
                flexDirection = "row",
                alignItems = "flex-start",
                gap = CARD_GAP,
                children = cards,
            },
            -- 等级号底栏
            UI.Panel {
                width = cellW, height = LEVEL_H,
                backgroundColor = levelBg,
                borderRadius = { bottomLeft = 4, bottomRight = 4 },
                justifyContent = "center", alignItems = "center",
                children = {
                    UI.Label {
                        text = tostring(lvl),
                        fontSize = 12, fontWeight = "bold",
                        fontColor = levelColor,
                    },
                    hasClaimable and UI.Panel {
                        position = "absolute",
                        top = 4, right = 6,
                        width = 7, height = 7,
                        backgroundColor = { 230, 60, 60, 255 },
                        borderRadius = 4,
                    } or nil,
                },
            },
        },
    }
end

-- ============================================================================
-- 赛季倒计时工具
-- ============================================================================

-- 解析 "YYYY-MM-DD" 字符串，返回 os.time 时间戳（当日 23:59:59）
local function ParseEndDate(dateStr)
    if not dateStr or dateStr == "" then return nil end
    local y, m, d = dateStr:match("(%d+)-(%d+)-(%d+)")
    if not y then return nil end
    return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d),
                     hour = 23, min = 59, sec = 59 })
end

local function FormatCountdown(endDate)
    local endTs = ParseEndDate(endDate)
    if not endTs then return nil end
    local now    = os.time()
    local diff   = endTs - now
    if diff <= 0 then return "已结束" end
    local days   = math.floor(diff / 86400)
    local hours  = math.floor((diff % 86400) / 3600)
    local mins   = math.floor((diff % 3600) / 60)
    if days >= 1 then
        return string.format("剩余 %d 天 %02d 小时", days, hours)
    else
        return string.format("剩余 %02d:%02d", hours, mins)
    end
end

-- ============================================================================
-- 顶部 XP 信息栏
-- ============================================================================

local function BuildHeader()
    local level      = SeasonPass.GetLevel()
    local progress   = SeasonPass.GetLevelProgress()
    local totalXP    = SeasonPass.GetXP()
    local perLevel   = Config.XP.perLevelXP
    local maxLevel   = Config.SEASON.maxLevel
    local isMax      = level >= maxLevel
    local xpInLevel  = isMax and perLevel or (totalXP % perLevel)
    local highLevel  = SeasonPass.GetHighLevel()

    local countdownText = FormatCountdown(Config.SEASON.endDate)

    local barW = 200

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 16, paddingRight = 16,
        paddingTop = 8, paddingBottom = 6,
        backgroundColor = { 0, 0, 0, 0 },
        gap = 14,
        children = {
            -- 徽章图标（放大）
            UI.Panel {
                width = 68, height = 68,
                flexShrink = 0,
                backgroundImage = "image/season_pass_badge_20260517160522.png",
                backgroundFit = "contain",
            },
            -- 进度条 + 等级 + XP
            UI.Panel {
                width = barW,
                flexShrink = 0,
                flexDirection = "column",
                justifyContent = "center",
                gap = 5,
                children = {
                    -- 等级标签 + 高级等级徽标
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 8,
                        children = {
                            UI.Label {
                                text = "等级 " .. level,
                                fontSize = 16, fontWeight = "bold",
                                fontColor = { 255, 255, 255, 255 },
                            },
                            UI.Panel {
                                paddingHorizontal = 7, paddingVertical = 2,
                                backgroundColor = highLevel > 0
                                    and { 180, 140, 40, 230 }
                                    or  { 60,  60,  60, 180 },
                                borderRadius = 4,
                                children = {
                                    UI.Label {
                                        text = highLevel > 0
                                            and ("高级 " .. highLevel .. "级")
                                            or "高级 0级",
                                        fontSize = 11, fontWeight = "bold",
                                        fontColor = highLevel > 0
                                            and { 255, 235, 150, 255 }
                                            or  { 140, 140, 140, 200 },
                                    },
                                },
                            },
                        },
                    },
                    -- 进度条
                    UI.Panel {
                        width = barW, height = 7,
                        backgroundColor = { 35, 35, 42, 200 },
                        borderRadius = 4, overflow = "hidden",
                        children = {
                            UI.Panel {
                                width = string.format("%d%%", math.floor(progress * 100)),
                                height = "100%",
                                backgroundColor = COLOR_XP_BAR,
                                borderRadius = 4,
                            }
                        }
                    },
                    -- XP 数字（白色）
                    UI.Label {
                        text = isMax and "已达最高等级"
                            or string.format("%d / %d", xpInLevel, perLevel),
                        fontSize = 12,
                        fontColor = { 255, 255, 255, 220 },
                    },
                    -- 赛季倒计时
                    countdownText and UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 5,
                        marginTop = 2,
                        children = {
                            UI.Panel {
                                width = 6, height = 6,
                                borderRadius = 3,
                                backgroundColor = countdownText == "已结束"
                                    and { 160, 80, 80, 220 }
                                    or  { 195, 215, 40, 220 },
                            },
                            UI.Label {
                                text = "赛季结束：" .. countdownText,
                                fontSize = 11,
                                fontColor = countdownText == "已结束"
                                    and { 200, 120, 120, 220 }
                                    or  { 195, 215, 40, 200 },
                            },
                        },
                    } or nil,
                },
            },
        }
    }
end

-- ============================================================================
-- 颜色常量（道具页风格）
-- ============================================================================

local CC = {
    -- 全部领取：主题黄绿色
    btnClaimAll     = { 195, 215, 40,  255 },   -- 主题黄绿底色
    btnClaimAllText = { 18,  20,  8,   255 },   -- 深色文字
    btnClaimAllDim  = { 55,  60,  25,  180 },   -- 无奖励时暗绿底
    btnClaimAllDimText = { 100, 110, 45,  180 },-- 暗文字
    -- 返回按钮：道具页风格（黄绿透明边框）
    backBtnText     = { 195, 215, 40,  230 },
    backBtnBg       = { 195, 215, 40,  20  },
    backBtnBorder   = { 195, 215, 40,  160 },
    headerDivider   = { 50,  55,  70,  150 },
}

-- ============================================================================
-- 统计可领取数量
-- ============================================================================

local function CountClaimable(currentLevel, vipUnlocked)
    local count = 0
    for lvl = 1, currentLevel do
        local tier = Config.TIERS[lvl]
        if tier and #tier.free > 0 and not SeasonPass.IsFreeClaimedAt(lvl) then
            count = count + 1
        end
        if tier then
            for pos = 1, #tier.vip do
                local gIdx = Config.VIP_INDEX[lvl] and Config.VIP_INDEX[lvl][pos] or 0
                if (vipUnlocked >= gIdx) and not SeasonPass.IsVipClaimed(gIdx) then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- ============================================================================
-- 一键全部领取
-- ============================================================================

local function DoClaimAll(currentLevel, vipUnlocked, onDone)
    -- 第一遍：统计所有待领取金币总量（不发放）
    local totalCoins = 0
    local function AccumulateCoins(tier)
        for _, reward in ipairs(tier.free or {}) do
            if reward.type == "coins" then totalCoins = totalCoins + (reward.amount or 0) end
        end
        for _, reward in ipairs(tier.vip or {}) do
            if reward.type == "coins" then totalCoins = totalCoins + (reward.amount or 0) end
        end
    end

    local msgs = {}
    for lvl = 1, currentLevel do
        local tier = Config.TIERS[lvl]
        if tier and #tier.free > 0 and not SeasonPass.IsFreeClaimedAt(lvl) then
            AccumulateCoins(tier)
            local ok, msg = SeasonPass.ClaimFree(lvl)
            if ok then msgs[#msgs + 1] = msg end
        end
        if tier then
            for pos = 1, #tier.vip do
                local gIdx = Config.VIP_INDEX[lvl] and Config.VIP_INDEX[lvl][pos] or 0
                if (vipUnlocked >= gIdx) and not SeasonPass.IsVipClaimed(gIdx) then
                    local ok, msg = SeasonPass.ClaimVip(lvl, pos)
                    if ok then msgs[#msgs + 1] = msg end
                end
            end
        end
    end

    -- 全部领取完毕后统一处理：金币一次性发放，标脏延迟保存
    if #msgs > 0 then
        if totalCoins > 0 then
            local MoneyManager = require("MoneyManager")
            MoneyManager.AddMoneyFromMenu(totalCoins, "season_pass", { skipSave = true })
        end
        SaveFW.MarkDirty("season_pass_panel")
        FloatingMessage.Show("已领取 " .. #msgs .. " 项奖励")
    else
        FloatingMessage.Show("暂无可领取奖励")
    end
    if onDone then onDone() end
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 是否有可领取的奖励（供外部红点判断）
function SeasonPassPanel.HasClaimable()
    local currentLevel = SeasonPass.GetLevel()
    local vipUnlocked  = SeasonPass.GetVipUnlocked()
    return CountClaimable(currentLevel, vipUnlocked) > 0
end

---@param onBackCallback? function
function SeasonPassPanel.Show(onBackCallback, selectedLvl)
    -- 每次重建前先清掉上一次注册的 KeyDown 监听器，防止 Rebuild() 叠加
    UnsubscribeFromEvent("KeyDown")
    SeasonPass.Init()
    local currentLevel = SeasonPass.GetLevel()
    -- 默认选中当前等级（至少为1）
    selectedLvl = selectedLvl or math.max(currentLevel, 1)

    local function SelectLevel(lvl)
        SeasonPassPanel.Show(onBackCallback, lvl)
    end

    local function Rebuild()
        SeasonPassPanel.Show(onBackCallback, selectedLvl)
    end

    local function DoBack()
        UnsubscribeFromEvent("KeyDown")
        Utils.PlayClick()
        if onBackCallback then onBackCallback() end
    end

    local maxLvl      = Config.SEASON.maxLevel
    local vipUnlocked = SeasonPass.GetVipUnlocked()
    local claimable   = CountClaimable(currentLevel, vipUnlocked)
    local hasClaimable = claimable > 0

    -- 累加每格实际宽度（各格宽度由奖励数量决定）
    local totalW = 0
    local cellOffsets = {}  -- cellOffsets[lvl] = 该等级格左边缘的 X 偏移
    for lvl = 1, maxLvl do
        cellOffsets[lvl] = totalW + math.max(0, lvl - 1) * CELL_GAP
        totalW = totalW + GetCellWidth(lvl)
    end
    totalW = totalW + math.max(0, maxLvl - 1) * CELL_GAP

    -- 创建浮窗实例（绝对定位，动态计算坐标后显示）
    local detailInst = ItemDetailPanel.New({
        position = "absolute",
        left = 0, top = 0,
        width = 210,
    })
    ---@type Node
    local rootRef = nil   -- 由根 Panel 创建后赋值

    local DETAIL_W = 210

    -- 点击图标时定位浮窗到点击位置正上方
    -- 使用鼠标实际坐标，避免 ScrollView 滚动后 GetAbsoluteLayout 偏移不准的问题
    local function ShowDetailAt(iconWidget, reward)
        if detailInst:IsVisible() then detailInst:Hide() end
        detailInst:Show(RewardItemAdapter.ToItem(reward))

        local rootLayout = rootRef and rootRef:GetAbsoluteLayout() or nil
        if not rootLayout then return end

        local rootX, rootY = rootLayout.x, rootLayout.y
        local rootW, rootH = rootLayout.w, rootLayout.h

        -- 用鼠标实际位置（滚动后依然准确）
        local mousePos = input.mousePosition
        local cx      = mousePos.x - rootX
        local clickY  = mousePos.y - rootY

        local detailH = 260
        local px = cx - DETAIL_W / 2
        if px < 4 then px = 4 end
        if px + DETAIL_W > rootW - 4 then px = rootW - DETAIL_W - 4 end

        local py = clickY - detailH - 6
        if py < 4 then
            py = clickY + 16   -- 上方空间不足则显示在点击处下方
        end

        detailInst:GetWidget():SetStyle({ left = px, top = py, right = nil, bottom = nil })
    end

    -- 懒加载缓存：只在 cell 首次进入视口时创建，之后缓存复用
    local createdCells = {}  -- createdCells[lvl] = widget

    -- ESC 键绑定
    local escHandler = nil
    escHandler = UI.Panel {
        position = "absolute",
        width = 0, height = 0,
        onKeyPress = function(self, key)
            if key == KEY_ESCAPE then
                DoBack()
            end
        end,
    }

    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        backgroundImage = "image/season_pass_bg_v3_20260517142939.jpg",
        backgroundFit = "cover",
        children = {
            -- 毛玻璃纹理叠加层（全屏覆盖）
            UI.Panel {
                position = "absolute",
                left = 0, top = 0, right = 0, bottom = 0,
                backgroundImage = "image/frosted_glass_overlay_20260517184616.jpg",
                backgroundFit = "cover",
                opacity = 0.45,
                pointerEvents = "none",
            },
            UI.SafeAreaView {
                edges = "all", width = "100%", height = "100%",
                onKeyPress = function(self, key)
                    if key == KEY_ESCAPE then
                        DoBack()
                    end
                end,
                children = {
                    (function()
                        local bgPanel = UI.Panel {
                        width = "100%", height = "100%",
                        flexDirection = "column",
                        -- 点击空白处关闭浮窗
                        onClick = function()
                            if detailInst:IsVisible() then detailInst:Hide() end
                        end,
                        children = {
                            -- 顶栏（透明）
                    UI.Panel {
                        width = "100%", height = 48,
                        backgroundColor = { 0, 0, 0, 0 },
                        flexDirection = "row",
                        alignItems = "center",
                        paddingLeft = 0, paddingRight = 16,
                        children = {
                            -- "通行证"子容器：左侧黄绿渐变（左→右：实色→透明）
                            UI.Panel {
                                height = 48,
                                width = 160,
                                flexShrink = 0,
                                overflow = "hidden",
                                flexDirection = "row",
                                alignItems = "center",
                                paddingLeft = 16,
                                children = {
                                    -- 渐变层（left→right: 黄绿→透明，4 段叠加）
                                    UI.Panel { position = "absolute", left = 0, top = 0, bottom = 0, width = 160, backgroundColor = { 195, 215, 40, 22  }, pointerEvents = "none" },
                                    UI.Panel { position = "absolute", left = 0, top = 0, bottom = 0, width = 120, backgroundColor = { 195, 215, 40, 22  }, pointerEvents = "none" },
                                    UI.Panel { position = "absolute", left = 0, top = 0, bottom = 0, width = 80,  backgroundColor = { 195, 215, 40, 22  }, pointerEvents = "none" },
                                    UI.Panel { position = "absolute", left = 0, top = 0, bottom = 0, width = 40,  backgroundColor = { 195, 215, 40, 22  }, pointerEvents = "none" },
                                    -- 文字
                                    UI.Label {
                                        text = "通行证",
                                        fontSize = 18, fontWeight = "bold",
                                        fontColor = { 255, 255, 255, 255 },
                                    },
                                },
                            },
                            UI.Panel { flexGrow = 1 },
                            UI.Panel {
                                width = 32, height = 32, flexShrink = 0,
                                borderRadius = 4,
                                backgroundColor = { 40, 42, 55, 200 },
                                borderWidth = 1, borderColor = { 70, 75, 90, 180 },
                                alignItems = "center", justifyContent = "center",
                                cursor = "pointer",
                                onClick = function()
                                    Utils.PlayClick()
                                    DoBack()
                                end,
                                children = {
                                    UI.Label {
                                        text = "✕", fontSize = 18, fontWeight = "bold",
                                        fontColor = { 180, 220, 0, 230 },
                                    },
                                },
                            },
                        }
                    },
                    -- XP 头部
                    BuildHeader(),
                    -- 中间空白区（撑开背景图显示区域）
                    UI.Panel { width = "100%", flexGrow = 1 },
                    -- 返回 + 全部领取同行
                    UI.Panel {
                        width = "100%",
                        paddingHorizontal = 8, paddingVertical = 9,
                        backgroundColor = { 0, 0, 0, 0 },
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 8,
                        children = {
                            UI.Button {
                                text = "返回",
                                width = 110,
                                paddingVertical = 7,
                                fontSize = 13,
                                fontColor = CC.backBtnText,
                                fontWeight = "bold",
                                backgroundColor = CC.backBtnBg,
                                hoverBackgroundColor = { 195, 215, 40, 50 },
                                pressedBackgroundColor = { 195, 215, 40, 110 },
                                borderWidth = 1,
                                borderColor = CC.backBtnBorder,
                                borderRadius = 0,
                                onClick = function() DoBack() end,
                            },
                            UI.Panel { flexGrow = 1 },
                            UI.Button {
                                text = "全部领取",
                                fontSize = 13,
                                backgroundColor = hasClaimable and CC.btnClaimAll or CC.btnClaimAllDim,
                                fontColor       = hasClaimable and CC.btnClaimAllText or CC.btnClaimAllDimText,
                                paddingHorizontal = 18, paddingVertical = 7,
                                borderRadius = 6,
                                onClick = hasClaimable and function()
                                    Utils.PlayClick()
                                    DoClaimAll(currentLevel, vipUnlocked, Rebuild)
                                end or nil,
                            },
                        },
                    },
                    -- 底部横向滚动等级条
                    UI.Panel {
                        width = "100%",
                        height = TIER_H + 24,
                        paddingHorizontal = 12,
                        paddingVertical = 12,
                        backgroundColor = { 0, 0, 0, 0 },
                        children = {
                            (function()
                                -- 视口宽度估算（布局稳定前的保守值）
                                local VIEWPORT_BUFFER = 120  -- 视口两侧各预留的缓冲像素

                                -- 内容容器：固定总宽，在 ScrollView 流内（非绝对定位）
                                -- 这样 ScrollView 能感知内容宽度从而启用水平滚动
                                -- 内部 cell 用 position="absolute" 定位到各自偏移处
                                local contentPanel = UI.Panel {
                                    width = totalW,
                                    height = TIER_H,
                                    flexShrink = 0,
                                }

                                -- 根据当前滚动偏移，创建/显示/隐藏可见范围内的 cell
                                local function UpdateVisible(scrollX, viewW)
                                    local lo = scrollX - VIEWPORT_BUFFER
                                    local hi = scrollX + viewW + VIEWPORT_BUFFER
                                    for lvl = 1, maxLvl do
                                        local ox = cellOffsets[lvl]
                                        local cw = GetCellWidth(lvl)
                                        local visible = ox + cw >= lo and ox <= hi
                                        if visible then
                                            if not createdCells[lvl] then
                                                -- 首次进入视口：按需创建
                                                local cell = BuildTierCell(
                                                    lvl, currentLevel, selectedLvl,
                                                    vipUnlocked, SelectLevel, ShowDetailAt
                                                )
                                                -- 绝对定位到正确位置
                                                cell:SetStyle({
                                                    position = "absolute",
                                                    left = ox,
                                                    top = 0,
                                                    width = cw,
                                                    height = TIER_H,
                                                })
                                                contentPanel:AddChild(cell)
                                                createdCells[lvl] = cell
                                            else
                                                createdCells[lvl]:SetVisible(true)
                                            end
                                        else
                                            if createdCells[lvl] then
                                                createdCells[lvl]:SetVisible(false)
                                            end
                                        end
                                    end
                                end

                                local sv = UI.ScrollView {
                                    width = "100%",
                                    height = TIER_H,
                                    scrollX = true,
                                    scrollY = false,
                                    showScrollbar = false,
                                    bounces = true,
                                    onScroll = function(self, sx, sy)
                                        local vw = self:GetLayout().w
                                        if vw <= 0 then vw = 400 end
                                        UpdateVisible(sx, vw)
                                    end,
                                    children = { contentPanel }
                                }
                                sv.OnWheel = function(self, dx, dy)
                                    local dir = 0
                                    if math.abs(dx) > math.abs(dy) then
                                        dir = dx > 0 and 1 or -1
                                    elseif dy ~= 0 then
                                        dir = dy > 0 and -1 or 1
                                    end
                                    if dir ~= 0 then
                                        self:ScrollBy(dir * 60, 0)
                                    end
                                end
                                -- 初始定位：currentLevel 精确对齐左侧，不做额外偏移
                                -- 偏移会导致虚拟渲染预创建范围偏离实际可见区域，出现空白
                                local targetX = math.max(0, cellOffsets[currentLevel] or 0)
                                sv:SetScrollDirect(targetX, 0)
                                -- 初始渲染：用较大视口估算（1400）确保宽屏下全部可见格都被创建
                                UpdateVisible(targetX, 1400)
                                return sv
                            end)()
                        }
                    },
                    -- 奖励详情浮窗（绝对定位，叠在最上层）
                    detailInst:GetWidget(),
                }
            }
                    rootRef = bgPanel   -- 直接记录引用，供 ShowDetailAt 计算坐标
                    return bgPanel
                end)()
                }
            },
        },
    })

    -- 订阅 ESC 键（全局键盘事件）
    SubscribeToEvent("KeyDown", function(eventType, eventData)
        local key = eventData["Key"]:GetInt()
        if key == KEY_ESCAPE then
            UnsubscribeFromEvent("KeyDown")
            DoBack()
        end
    end)
end

-- 将刷新回调注入 SeasonPass，避免循环依赖
SeasonPass.SetPanelCallbacks({
    IsOpen  = function() return SeasonPassPanel.IsOpen and SeasonPassPanel.IsOpen() end,
    Refresh = function() if SeasonPassPanel.Refresh then SeasonPassPanel.Refresh() end end,
})

return SeasonPassPanel
