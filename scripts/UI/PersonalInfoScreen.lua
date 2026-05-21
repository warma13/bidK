-- ============================================================================
-- UI/PersonalInfoScreen.lua - 个人信息全屏页（全屏切换，参考 PropScreen 模式）
-- ============================================================================
-- 布局：
--   左侧边栏：信息 / 历史 两个 tab
--   右侧内容：
--     - 信息 tab：顶部角色头像+昵称 + 2行×4列统计数据
--     - 历史 tab：VirtualList 对局列表（分页 10 条，底部加载更多）
--                 点击行展开详情
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local SaveSystem = require("SaveSystem")
local Config = require("Config")
local Props = require("Config.Props")

local PersonalInfoScreen = {}

-- ESC 回调（由 GameController 统一处理）
PersonalInfoScreen._goBack = nil
PersonalInfoScreen._goBackFromDetail = nil
PersonalInfoScreen._initialTab = 1   -- Show() 打开时起始 tab（用完即重置）

function PersonalInfoScreen.GoBack()
    if PersonalInfoScreen._goBack then PersonalInfoScreen._goBack() end
end
function PersonalInfoScreen.GoBackFromDetail()
    if PersonalInfoScreen._goBackFromDetail then PersonalInfoScreen._goBackFromDetail() end
end

local PAGE_SIZE = 10

-- 稀有度颜色
local RARITY_COLORS = {
    red    = { 235, 80,  60,  255 },
    gold   = { 220, 180, 60,  255 },
    purple = { 170, 100, 230, 255 },
    blue   = { 80,  150, 230, 255 },
    green  = { 80,  200, 120, 255 },
    white  = { 190, 192, 200, 255 },
}

-- 道具 tier → 六边形染色
local PROP_HEX_TINT = {
    white  = { 190, 192, 200, 220 },
    green  = { 80,  230, 120, 255 },
    blue   = { 80,  160, 255, 255 },
    purple = { 200, 100, 255, 255 },
    red    = { 255,  80,  80, 255 },
}

-- 金币图标路径
local COIN_IMG = "金币.png"

-- 生成内联金币图标 Panel（正方形，backgroundFit contain）
local function CoinIcon(size)
    return UI.Panel {
        width = size, height = size, flexShrink = 0,
        backgroundImage = COIN_IMG,
        backgroundFit = "contain",
    }
end

-- 生成道具六边形图标（hexW×hexH 容器，内含六边形框 + 道具图）
-- propDef: Props.BY_ID[id] 或 nil（空格时传 nil）
-- hexW/hexH: 六边形容器尺寸（保持 78:90 比例）
-- iconSize: 内部图标尺寸
local function MakePropHexIcon(propDef, hexW, hexH, iconSize)
    local tint = propDef and (PROP_HEX_TINT[propDef.tier] or PROP_HEX_TINT.white)
                          or { 120, 122, 135, 80 }  -- 空格：灰暗
    local inner
    if propDef then
        if (propDef.iconImage or "") ~= "" then
            inner = UI.Panel {
                width = iconSize, height = iconSize,
                backgroundImage = propDef.iconImage,
                backgroundFit = "contain",
            }
        else
            inner = UI.Label {
                text = propDef.icon or "?",
                fontSize = iconSize * 0.75,
                textAlign = "center",
            }
        end
    end
    local children = {
        UI.Panel {
            position = "absolute",
            width = hexW, height = hexH,
            backgroundImage = "image/ui_hex_frame_trimmed.png",
            backgroundFit = "fill",
            imageTint = tint,
        },
    }
    if inner then children[#children + 1] = inner end
    return UI.Panel {
        width = hexW, height = hexH,
        alignItems = "center", justifyContent = "center",
        children = children,
    }
end

-- ============================================================================
-- 格式化工具
-- ============================================================================

local function FormatPlayTime(seconds)
    seconds = math.floor(seconds or 0)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then return h .. "h" .. m .. "min"
    elseif m > 0 then return m .. "min"
    else return seconds .. "s" end
end

local function FormatNum(n)
    n = math.floor(n or 0)
    if n >= 100000000 then return string.format("%.1f亿", n / 100000000)
    elseif n >= 10000  then return string.format("%.0fK", n / 1000) end
    local s, result, count = tostring(n), "", 0
    for i = #s, 1, -1 do
        count = count + 1
        result = s:sub(i, i) .. result
        if count % 3 == 0 and i > 1 then result = "," .. result end
    end
    return result
end

local function FormatPct(num, denom)
    if not denom or denom == 0 then return "0.0%" end
    return string.format("%.1f%%", num / denom * 100)
end

local function FormatDate(ts)
    if not ts or ts == 0 then return "—" end
    return os.date("%Y-%m-%d %H:%M", ts)
end

-- ============================================================================
-- 信息 Tab
-- ============================================================================

local function StatCard(label, value, hiColor)
    local sz = Utils.sz
    return UI.Panel {
        flex = 1,
        flexDirection = "column",
        alignItems = "flex-start",
        paddingVertical = sz(14),
        paddingHorizontal = sz(18),
        backgroundColor = { 255, 255, 255, 5 },
        borderRadius = sz(4),
        children = {
            UI.Label {
                text = label,
                fontSize = sz(11),
                fontColor = { 140, 145, 160, 200 },
                marginBottom = sz(6),
            },
            UI.Label {
                text = tostring(value),
                fontSize = sz(20),
                fontWeight = "bold",
                fontColor = hiColor or { 240, 242, 248, 255 },
            },
        },
    }
end

local function BuildInfoTab()
    local sz = Utils.sz
    local stats    = SaveSystem.IsReady() and SaveSystem.GetStats()     or {}
    local items    = SaveSystem.IsReady() and SaveSystem.GetItems()      or {}
    local playTime = (SaveSystem.GetPlayTime and SaveSystem.GetPlayTime()) or 0

    local totalGames  = stats.totalGames   or 0
    local wins        = stats.wins         or 0
    local totalProfit = stats.totalProfit  or 0
    local totalLoss   = stats.totalLoss    or 0
    local netProfit   = totalProfit - totalLoss   -- 净利润（可能为负）
    local maxProfit   = stats.maxProfit    or 0
    local highestBid  = stats.highestBid   or 0
    local totalItems  = stats.totalItemsWon or 0

    local totalAssets = 0
    for _, item in ipairs(items) do
        totalAssets = totalAssets + (item.baseValue or 0)
    end
    local ok, MoneyHUD = pcall(require, "UI.MoneyHUD")
    if ok and MoneyHUD and MoneyHUD.GetMoney then
        totalAssets = totalAssets + (MoneyHUD.GetMoney() or 0)
    end

    local row1 = {
        { label = "游戏时长",    value = FormatPlayTime(playTime),   color = nil },
        { label = "总竞拍局数",  value = FormatNum(totalGames),      color = nil },
        { label = "竞拍胜率",    value = FormatPct(wins, totalGames),color = { 100, 210, 150, 255 } },
        { label = "总资产",      value = FormatNum(totalAssets),     color = { 220, 195, 100, 255 } },
    }
    local row2 = {
        { label = "总盈利",      value = (netProfit >= 0 and "+" or "") .. FormatNum(netProfit),
                               color = netProfit > 0 and { 100, 220, 140, 255 }
                                    or netProfit < 0 and { 220, 100, 90,  255 }
                                    or nil },
        { label = "单局最高利润",value = FormatNum(maxProfit),       color = maxProfit > 0  and { 100, 220, 140, 255 } or nil },
        { label = "最高出价",    value = FormatNum(highestBid),      color = nil },
        { label = "收藏品总数",  value = FormatNum(totalItems),      color = nil },
    }

    local function MakeRow(defs)
        local cells = {}
        for i, d in ipairs(defs) do
            cells[#cells + 1] = StatCard(d.label, d.value, d.color)
            if i < #defs then
                cells[#cells + 1] = UI.Panel { width = sz(4), backgroundColor = { 0, 0, 0, 0 } }
            end
        end
        return UI.Panel {
            width = "100%", flexDirection = "row", gap = sz(4),
            children = cells,
        }
    end

    -- ── 用户信息头部（头像 + 昵称 + ID） ──
    -- 角色头像：取当前选中角色，默认赵沐瑶（index 1）
    local charIdx = UIState.selectedCharIdx or 1
    local chars = Config.CHARACTERS or {}
    local selectedChar = chars[charIdx] or chars[1] or {}
    local charAvatarPath = selectedChar.avatar or "Textures/characters/ye_lingxi.png"

    local avatarPanel = UI.Panel {
        width = sz(58), height = sz(58),
        borderRadius = 0,
        overflow = "hidden",
        flexShrink = 0,
        backgroundColor = { 35, 38, 52, 255 },
        borderWidth = 2, borderColor = { 200, 230, 0, 100 },
        children = {
            UI.Panel {
                width = "100%", height = "100%",
                backgroundImage = charAvatarPath,
                backgroundFit = "cover",
            },
        },
    }

    local nicknameLbl = UI.Label {
        text = "—",
        fontSize = sz(16), fontWeight = "bold",
        fontColor = { 220, 225, 240, 255 },
    }
    local userIdLbl = UI.Label {
        text = "",
        fontSize = sz(11),
        fontColor = { 130, 135, 155, 200 },
    }

    -- 异步获取昵称
    local myUserId = (lobby and lobby:GetMyUserId()) or 0
    if myUserId ~= 0 then
        userIdLbl.text = "ID: " .. tostring(myUserId)
        GetUserNickname({
            userIds = { myUserId },
            onSuccess = function(nicknames)
                if nicknames and #nicknames > 0 and nicknames[1].nickname then
                    nicknameLbl.text = nicknames[1].nickname
                end
            end,
            onError = function() end,
        })
    else
        nicknameLbl.text = "游客"
    end

    local profileHeader = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = sz(14),
        paddingVertical = sz(16),
        paddingHorizontal = sz(4),
        marginBottom = sz(6),
        borderBottomWidth = 1,
        borderColor = { 255, 255, 255, 10 },
        children = {
            avatarPanel,
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                flexDirection = "column",
                gap = sz(5),
                children = { nicknameLbl, userIdLbl },
            },
        },
    }

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = sz(10),
        children = { profileHeader, MakeRow(row1), MakeRow(row2) },
    }
end

-- ============================================================================
-- 历史 Tab 工具
-- ============================================================================

local function ItemThumbs(items)
    local sz = Utils.sz
    local MAX_SHOW = 6
    local cells = {}
    for i = 1, math.min(MAX_SHOW, #items) do
        local it = items[i]
        local rc = RARITY_COLORS[it.rarity or "white"] or { 200, 200, 200, 255 }
        cells[#cells + 1] = UI.Panel {
            width = sz(24), height = sz(24),
            borderRadius = sz(3),
            borderWidth = 1,
            borderColor = { rc[1], rc[2], rc[3], 180 },
            backgroundColor = { 30, 32, 42, 255 },
            overflow = "hidden",
            children = (it.image and it.image ~= "") and {
                UI.Panel {
                    width = "100%", height = "100%",
                    backgroundImage = it.image,
                    backgroundFit = "contain",
                },
            } or {
                UI.Label {
                    text = (it.name or "?"):sub(1, 1),
                    fontSize = sz(10), fontColor = rc,
                    width = "100%", height = "100%",
                    textAlign = "center",
                },
            },
        }
    end
    if #items > MAX_SHOW then
        cells[#cells + 1] = UI.Label {
            text = "+" .. (#items - MAX_SHOW),
            fontSize = sz(11), fontColor = { 150, 155, 170, 200 },
            alignSelf = "center",
        }
    end
    return UI.Panel {
        flexDirection = "row", alignItems = "center", gap = sz(3),
        children = cells,
    }
end

local function BuildDetailPanel(rec)
    local sz = Utils.sz
    local players = rec.players or {}
    local playerRows = {}
    for i, pl in ipairs(players) do
        playerRows[#playerRows + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            paddingVertical = sz(8),
            paddingHorizontal = sz(14),
            gap = sz(10),
            backgroundColor = pl.isWinner and { 50, 160, 90, 25 } or { 255, 255, 255, 0 },
            borderBottomWidth = (i < #players) and 1 or 0,
            borderColor = { 255, 255, 255, 10 },
            children = {
                UI.Panel {
                    width = sz(28), height = sz(28),
                    borderRadius = sz(14),
                    overflow = "hidden",
                    flexShrink = 0,
                    backgroundColor = { 40, 44, 58, 255 },
                    children = (pl.charAvatar and pl.charAvatar ~= "") and {
                        UI.Panel {
                            width = "100%", height = "100%",
                            backgroundImage = pl.charAvatar,
                            backgroundFit = "cover",
                        },
                    } or nil,
                },
                UI.Label {
                    text = pl.name or "—",
                    fontSize = sz(12),
                    fontColor = pl.isHuman and { 220, 195, 100, 255 } or { 190, 192, 202, 255 },
                    flexGrow = 1, flexShrink = 1,
                },
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = sz(3),
                    flexShrink = 0,
                    children = {
                        CoinIcon(sz(13)),
                        UI.Label {
                            text = FormatNum(pl.bid or 0),
                            fontSize = sz(13), fontWeight = "bold",
                            fontColor = pl.isWinner and { 100, 220, 140, 255 } or { 190, 192, 202, 255 },
                        },
                    },
                },
                pl.isWinner and UI.Panel {
                    width = sz(24), height = sz(16),
                    borderRadius = sz(3),
                    alignItems = "center", justifyContent = "center",
                    backgroundColor = { 50, 160, 90, 180 },
                    children = {
                        UI.Label { text = "赢", fontSize = sz(9), fontWeight = "bold", fontColor = { 255, 255, 255, 255 } },
                    },
                } or UI.Panel { width = sz(24) },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        backgroundColor = { 16, 18, 28, 255 },
        borderRadius = sz(4),
        overflow = "hidden",
        marginTop = sz(2),
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = sz(14),
                paddingVertical = sz(7),
                gap = sz(14),
                backgroundColor = { 255, 255, 255, 5 },
                children = {
                    UI.Label {
                        text = "仓库：" .. (rec.warehouseName or "—"),
                        fontSize = sz(11), fontColor = { 160, 165, 180, 220 }, flexGrow = 1,
                    },
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = sz(3),
                        children = {
                            UI.Label { text = "估值：", fontSize = sz(11), fontColor = { 180, 185, 200, 220 } },
                            CoinIcon(sz(11)),
                            UI.Label {
                                text = FormatNum(rec.totalValue or 0),
                                fontSize = sz(11), fontColor = { 180, 185, 200, 220 },
                            },
                        },
                    },
                    rec.isWin and UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = sz(3),
                        children = {
                            UI.Label { text = "盈利：", fontSize = sz(11), fontColor = { 100, 220, 140, 255 }, fontWeight = "bold" },
                            CoinIcon(sz(11)),
                            UI.Label {
                                text = FormatNum(rec.profit or 0),
                                fontSize = sz(11), fontColor = { 100, 220, 140, 255 }, fontWeight = "bold",
                            },
                        },
                    } or nil,
                },
            },
            table.unpack(playerRows),
        },
    }
end

-- ============================================================================
-- 对局详情页（全屏）
-- ============================================================================

local function ShowMatchDetail(rec, onBack)
    local sz = Utils.sz
    local players   = rec.players  or {}
    local roundBids = rec.roundBids or {}

    -- 始终显示 5 轮（不足的显示空/0）
    local SHOW_ROUNDS = 5
    local roundProps = rec.roundProps or {}

    -- 找赢家名字
    local winnerName = "—"
    for _, pl in ipairs(players) do
        if pl.isWinner then
            winnerName = pl.name or "—"
            break
        end
    end

    -- ── 列宽定义 ─────────────────────────────────────────────
    -- 玩家列 flex 填充剩余空间；其余固定宽度，避免空白撑大
    local colWidths = {
        profitW = sz(88),   -- 净利润（固定）
        bidW    = sz(88),   -- 最终出价（固定）
        roundW  = sz(58),   -- 每轮出价方块（固定）
    }

    -- ── 表头 ──────────────────────────────────────────────────
    local headerRow = UI.Panel {
        width = "100%", flexDirection = "row",
        alignItems = "center",
        paddingVertical = sz(8), paddingHorizontal = sz(14),
        borderBottomWidth = 1, borderColor = { 255, 255, 255, 15 },
        backgroundColor = { 255, 255, 255, 5 },
        children = (function()
            local cells = {
                -- 玩家列：flexGrow 填充剩余
                UI.Label {
                    text = "玩家", flexGrow = 1, flexShrink = 1,
                    fontSize = sz(11), fontWeight = "bold",
                    fontColor = { 140, 145, 165, 200 },
                    textAlign = "left",
                },
                UI.Label {
                    text = "净利润",
                    width = colWidths.profitW, flexShrink = 0,
                    fontSize = sz(11), fontWeight = "bold",
                    fontColor = { 140, 145, 165, 200 },
                    textAlign = "center",
                },
                UI.Label {
                    text = "最终出价",
                    width = colWidths.bidW, flexShrink = 0,
                    fontSize = sz(11), fontWeight = "bold",
                    fontColor = { 140, 145, 165, 200 },
                    textAlign = "center",
                },
            }
            for r = 1, SHOW_ROUNDS do
                cells[#cells + 1] = UI.Panel {
                    width = colWidths.roundW, flexShrink = 0,
                    alignItems = "center", justifyContent = "flex-end",
                    children = {
                        UI.Label {
                            text = "第" .. r .. "轮",
                            fontSize = sz(11), fontWeight = "bold",
                            fontColor = { 140, 145, 165, 200 },
                            textAlign = "center",
                        },
                    },
                }
            end
            return cells
        end)(),
    }

    -- ── 玩家行 ──────────────────────────────────────────────────
    local playerRows = {}
    for i, pl in ipairs(players) do
        local isHighlight = pl.isWinner

        -- 计算净利润（只有人类赢家有有效利润）
        local profitSign, profitNum, profitColor, profitIsCoin
        if pl.isWinner then
            local pf = rec.profit or 0
            if pl.isHuman then
                profitSign  = pf >= 0 and "+" or ""
                profitNum   = FormatNum(pf)
                profitColor = pf >= 0 and { 100, 220, 140, 255 } or { 220, 100, 90, 255 }
                profitIsCoin = true
            else
                -- AI 赢家估算：totalValue - bid
                local aiProfit = (rec.totalValue or 0) - (pl.bid or 0)
                profitSign  = aiProfit >= 0 and "+" or ""
                profitNum   = FormatNum(aiProfit)
                profitColor = aiProfit >= 0 and { 100, 220, 140, 255 } or { 220, 100, 90, 255 }
                profitIsCoin = true
            end
        else
            profitSign  = ""
            profitNum   = "—"
            profitColor = { 140, 145, 162, 200 }
            profitIsCoin = false
        end

        -- 轮次格子：六边形道具图标 + 出价在下方
        local roundCells = {}
        -- 六边形尺寸：保持 78:90 比例，高度适配 roundW
        local rndHexH = colWidths.roundW
        local rndHexW = math.floor(rndHexH * 78 / 90 + 0.5)
        local rndIconSize = sz(26)
        for r = 1, SHOW_ROUNDS do
            local rb = roundBids[r] or roundBids[tostring(r)] or {}
            local rp = roundProps[r] or roundProps[tostring(r)] or {}
            local bid  = rb[i] or rb[tostring(i)] or 0
            local prop = rp[i] or rp[tostring(i)]   -- { id, name } or nil
            local hasBid  = bid > 0
            local hasProp = prop and (prop.name or "") ~= ""

            -- 查 propDef
            local propDef = (prop and prop.id) and Props.BY_ID[prop.id] or nil
            if not propDef and hasProp then
                for _, def in ipairs(Props.LIST) do
                    if def.name == prop.name then propDef = def; break end
                end
            end

            -- 有道具显示六边形，无道具显示半透明底框（出过价）或完全淡化
            local hexIcon
            if hasProp then
                hexIcon = MakePropHexIcon(propDef, rndHexW, rndHexH, rndIconSize)
            else
                -- 无道具：显示空六边形占位
                hexIcon = MakePropHexIcon(nil, rndHexW, rndHexH, rndIconSize)
            end

            -- 价格文字（在六边形下）
            local priceColor = hasBid
                and (isHighlight and { 140, 230, 160, 255 } or { 190, 194, 210, 220 })
                or  { 80, 83, 100, 130 }

            roundCells[#roundCells + 1] = UI.Panel {
                width = colWidths.roundW, flexShrink = 0,
                flexDirection = "column",
                alignItems = "center",
                gap = sz(3),
                children = {
                    hexIcon,
                    -- 价格（金币图标 + 数字）
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", justifyContent = "center",
                        gap = sz(2), width = colWidths.roundW,
                        children = {
                            CoinIcon(sz(9)),
                            UI.Label {
                                text = hasBid and FormatNum(bid) or "0",
                                fontSize = sz(10), fontWeight = hasBid and "bold" or "normal",
                                fontColor = priceColor,
                            },
                        },
                    },
                },
            }
        end

        -- 玩家信息列
        local nameColor = pl.isHuman and { 220, 195, 100, 255 } or { 190, 192, 202, 255 }
        local playerCell = UI.Panel {
            flexGrow = 1, flexShrink = 1,
            flexDirection = "row", alignItems = "center", gap = sz(8),
        }
        -- 头像
        local avatarNode = UI.Panel {
            width = sz(32), height = sz(32), borderRadius = sz(3),
            overflow = "hidden", flexShrink = 0,
            backgroundColor = { 40, 44, 58, 255 },
            borderWidth = isHighlight and 2 or 0,
            borderColor = { 100, 200, 120, 180 },
        }
        if (pl.charAvatar or "") ~= "" then
            avatarNode:AddChild(UI.Panel {
                width = "100%", height = "100%",
                backgroundImage = pl.charAvatar, backgroundFit = "cover",
            })
        end
        playerCell:AddChild(avatarNode)

        -- 胜负标签 + 名字
        local badgeTxt = pl.isWinner and "竞拍成功" or "竞拍失败"
        local badgeBg  = pl.isWinner and { 50, 160, 90, 200 } or { 130, 50, 50, 200 }
        playerCell:AddChild(UI.Panel {
            flexGrow = 1, flexShrink = 1,
            flexDirection = "column", gap = sz(3),
            children = {
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = sz(5),
                    children = {
                        UI.Panel {
                            paddingHorizontal = sz(5), paddingVertical = sz(2),
                            borderRadius = sz(3),
                            backgroundColor = badgeBg,
                            children = {
                                UI.Label { text = badgeTxt, fontSize = sz(9), fontWeight = "bold", fontColor = { 255, 255, 255, 255 } },
                            },
                        },
                        UI.Label {
                            text = pl.name or "玩家" .. i,
                            fontSize = sz(12), fontWeight = "bold",
                            fontColor = nameColor,
                            flexShrink = 1,
                        },
                    },
                },
                UI.Label {
                    text = pl.charName or "",
                    fontSize = sz(10), fontColor = { 130, 135, 155, 180 },
                },
            },
        })

        local rowChildren = {
            playerCell,
            -- 利润列：有金币时显示图标+数字，否则显示"—"
            UI.Panel {
                width = colWidths.profitW, flexShrink = 0,
                flexDirection = "row", alignItems = "center", justifyContent = "center",
                gap = sz(2),
                children = profitIsCoin and {
                    UI.Label { text = profitSign, fontSize = sz(13), fontWeight = "bold", fontColor = profitColor },
                    CoinIcon(sz(12)),
                    UI.Label { text = profitNum, fontSize = sz(13), fontWeight = "bold", fontColor = profitColor },
                } or {
                    UI.Label { text = profitNum, fontSize = sz(13), fontWeight = "bold", fontColor = profitColor, textAlign = "center" },
                },
            },
            -- 总出价列
            UI.Panel {
                width = colWidths.bidW, flexShrink = 0,
                flexDirection = "row", alignItems = "center", justifyContent = "center",
                gap = sz(2),
                children = {
                    CoinIcon(sz(12)),
                    UI.Label {
                        text = FormatNum(pl.bid or 0),
                        fontSize = sz(13), fontWeight = "bold",
                        fontColor = pl.isWinner and { 220, 195, 100, 255 } or { 190, 192, 202, 255 },
                    },
                },
            },
        }
        for _, rc in ipairs(roundCells) do
            rowChildren[#rowChildren + 1] = rc
        end

        playerRows[#playerRows + 1] = UI.Panel {
            width = "100%", flexDirection = "row",
            alignItems = "center",
            paddingVertical = sz(6), paddingHorizontal = sz(14),
            gap = sz(4),
            backgroundColor = isHighlight and { 50, 160, 90, 18 } or { 255, 255, 255, 0 },
            borderBottomWidth = (i < #players) and 1 or 0,
            borderColor = { 255, 255, 255, 8 },
            children = rowChildren,
        }
    end

    -- ── 页面布局 ─────────────────────────────────────────────────
    local resultTxt   = rec.isWin and "竞拍成功" or "竞拍失败"
    local resultColor = rec.isWin and { 100, 225, 140, 255 } or { 220, 90, 80, 255 }

    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = {
            UI.Panel {
                width = "100%", height = "100%",
                backgroundImage = "image/task_bg_20260516170303.jpg",
                backgroundFit = "cover",
                flexDirection = "column",
                children = {
                    -- 高斯模糊遮罩
                    UI.Panel {
                        position = "absolute",
                        left = 0, top = 0, right = 0, bottom = 0,
                        backdropBlur = 40,
                        backgroundColor = { 6, 8, 16, 210 },
                    },
                    -- ── 顶部信息区 ────────────────────────────────
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row", alignItems = "center",
                        paddingHorizontal = sz(16), paddingTop = sz(10), paddingBottom = sz(8),
                        borderBottomWidth = 1, borderColor = { 255, 255, 255, 12 },
                        children = {
                            -- 左侧：结果大字 + 三项元信息（同行）
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                flexDirection = "column", gap = sz(4),
                                children = {
                                    UI.Label {
                                        text = resultTxt,
                                        fontSize = sz(22), fontWeight = "bold",
                                        fontColor = resultColor,
                                    },
                                    UI.Panel {
                                        flexDirection = "row", alignItems = "center",
                                        flexWrap = "wrap", gap = sz(12),
                                        children = {
                                            UI.Panel {
                                                flexDirection = "row", alignItems = "center", gap = sz(4),
                                                children = {
                                                    UI.Label { text = "仓库", fontSize = sz(11), fontColor = { 140, 145, 165, 200 } },
                                                    UI.Label { text = rec.warehouseName or "—", fontSize = sz(11), fontWeight = "bold", fontColor = { 220, 222, 235, 255 } },
                                                },
                                            },
                                            UI.Panel {
                                                flexDirection = "row", alignItems = "center", gap = sz(4),
                                                children = {
                                                    UI.Label { text = "时间", fontSize = sz(11), fontColor = { 140, 145, 165, 200 } },
                                                    UI.Label { text = FormatDate(rec.timestamp), fontSize = sz(11), fontWeight = "bold", fontColor = { 220, 222, 235, 255 } },
                                                },
                                            },
                                            UI.Panel {
                                                flexDirection = "row", alignItems = "center", gap = sz(4),
                                                children = {
                                                    UI.Label { text = "获胜者", fontSize = sz(11), fontColor = { 140, 145, 165, 200 } },
                                                    UI.Label { text = winnerName, fontSize = sz(11), fontWeight = "bold", fontColor = { 220, 195, 100, 255 } },
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                            -- 右侧：✕ 关闭按钮
                            UI.Panel {
                                width = sz(34), height = sz(34),
                                borderRadius = sz(4),
                                backgroundColor = { 40, 42, 55, 200 },
                                borderWidth = 1, borderColor = { 70, 75, 90, 180 },
                                alignItems = "center", justifyContent = "center",
                                cursor = "pointer",
                                onClick = function()
                                    Utils.PlayClick()
                                    if onBack then onBack() end
                                end,
                                children = {
                                    UI.Label { text = "✕", fontSize = sz(16), fontWeight = "bold", fontColor = { 180, 220, 0, 230 } },
                                },
                            },
                        },
                    },
                    -- ── 表格区域 ──────────────────────────────────
                    UI.ScrollView {
                        width = "100%", flexGrow = 1,
                        children = {
                            UI.Panel {
                                width = "100%", flexDirection = "column",
                                margin = sz(10),
                                backgroundColor = { 18, 20, 30, 220 },
                                borderRadius = sz(6),
                                overflow = "hidden",
                                borderWidth = 1, borderColor = { 255, 255, 255, 12 },
                                children = (function()
                                    local t = { headerRow }
                                    for _, pr in ipairs(playerRows) do
                                        t[#t + 1] = pr
                                    end
                                    return t
                                end)(),
                            },
                        },
                    },
                    -- ── 底部返回栏 ────────────────────────────────
                    UI.Panel {
                        width = "100%",
                        paddingHorizontal = sz(8), paddingVertical = sz(9),
                        borderTopWidth = 1, borderColor = { 255, 255, 255, 10 },
                        children = {
                            UI.Button {
                                text = "返回",
                                width = sz(120), paddingVertical = sz(7),
                                fontSize = sz(13), fontWeight = "bold",
                                fontColor = { 195, 215, 40, 230 },
                                backgroundColor = { 195, 215, 40, 20 },
                                hoverBackgroundColor = { 195, 215, 40, 50 },
                                pressedBackgroundColor = { 195, 215, 40, 110 },
                                borderWidth = 1, borderColor = { 195, 215, 40, 160 },
                                borderRadius = sz(4),
                                onClick = function()
                                    Utils.PlayClick()
                                    if onBack then onBack() end
                                end,
                            },
                        },
                    },
                },
            },
        },
    })
end

-- ============================================================================
-- 历史 Tab 主体
-- ============================================================================

local function BuildHistoryTab(onShowDetail, onBack)
    local sz = Utils.sz
    -- 懒加载：初次打开历史 Tab 时才从云端拉取对局记录
    local allHistory = {}
    local loadedCount = 0

    ---@type any
    local vlist = nil
    ---@type any
    local loadMorePanel = nil
    ---@type any
    local loadMoreBtn = nil

    local ROW_HEIGHT = sz(72)
    -- 道具格数量
    local PROP_SLOTS = 5
    -- 物品缩略图最多显示数
    local THUMB_MAX = 5

    local function GetDisplayData()
        local slice = {}
        for i = 1, loadedCount do
            slice[#slice + 1] = { index = i, rec = allHistory[i] }
        end
        return slice
    end

    -- 收集本场所有使用过的道具列表（去重，按轮次顺序）
    local function CollectUsedProps(rec)
        local propList = {}
        local roundProps = rec.roundProps or {}
        -- 找玩家自己的 pidx（通常是1，isHuman）
        local humanIdx = 1
        for i, pl in ipairs(rec.players or {}) do
            if pl.isHuman then humanIdx = i; break end
        end
        -- 遍历各轮
        local rounds = {}
        for rnd, _ in pairs(roundProps) do
            rounds[#rounds + 1] = tonumber(rnd) or 0
        end
        table.sort(rounds)
        for _, rnd in ipairs(rounds) do
            local row = roundProps[rnd] or roundProps[tostring(rnd)] or {}
            local p = row[humanIdx] or row[tostring(humanIdx)]
            if p and (p.name or "") ~= "" then
                propList[#propList + 1] = p
            end
        end
        return propList
    end

    -- 按 value 降序排列取前 N 个物品
    local function TopItems(items, n)
        local sorted = {}
        for _, it in ipairs(items or {}) do sorted[#sorted + 1] = it end
        table.sort(sorted, function(a, b)
            return (a.value or 0) > (b.value or 0)
        end)
        local result = {}
        for i = 1, math.min(n, #sorted) do result[#result + 1] = sorted[i] end
        return result
    end

    local function createItem()
        local s = Utils.sz

        -- ── 左段：头像(+名字) + 竖列信息 ──────────────────────
        local avatarImg = UI.Panel {
            width = s(40), height = s(40), borderRadius = 0,
            overflow = "hidden", flexShrink = 0,
            backgroundColor = { 40, 44, 58, 255 },
            borderWidth = 1, borderColor = { 255, 255, 255, 120 },
        }
        local nameLbl = UI.Label {
            text = "—", fontSize = s(9),
            fontColor = { 160, 165, 180, 200 },
            textAlign = "center",
            width = s(40), flexShrink = 0,
        }
        local resultLbl = UI.Label {
            text = "竞拍成功", fontSize = s(12), fontWeight = "bold",
            fontColor = { 100, 220, 140, 255 },
            flexShrink = 0,
        }
        local dateLbl = UI.Label {
            text = "—", fontSize = s(10),
            fontColor = { 120, 125, 145, 200 },
            flexShrink = 0,
        }
        local leftSeg = UI.Panel {
            width = s(160), flexShrink = 0,
            flexDirection = "row", alignItems = "center", gap = s(8),
            paddingHorizontal = s(6),
            children = {
                -- 头像列：头像 + 名字
                UI.Panel {
                    flexShrink = 0,
                    flexDirection = "column", alignItems = "center", gap = s(2),
                    children = { avatarImg, nameLbl },
                },
                -- 信息列：结果 + 时间
                UI.Panel {
                    flexGrow = 1, flexShrink = 1,
                    flexDirection = "column", justifyContent = "center", gap = s(4),
                    children = { resultLbl, dateLbl },
                },
            },
        }

        -- ── 中左段：藏品价值 + 物品图标 ──────────────────────
        local valueLbl  = UI.Label { text = "—", fontSize = s(10), fontWeight = "bold", fontColor = { 220, 225, 235, 255 } }
        local itemArea  = UI.Panel { flexDirection = "row", alignItems = "center", gap = s(3) }
        local midLeftSeg = UI.Panel {
            flexGrow = 1, flexShrink = 1,
            flexDirection = "column", justifyContent = "center", gap = s(6),
            paddingHorizontal = s(10),
            borderLeftWidth = 1, borderColor = { 255, 255, 255, 12 },
            children = {
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = s(4),
                    children = {
                        UI.Label { text = "藏品价值:", fontSize = s(10), fontColor = { 140, 145, 165, 180 } },
                        CoinIcon(s(13)),
                        valueLbl,
                    },
                },
                itemArea,
            },
        }

        -- ── 中右段：竞拍消耗 + 道具格 ────────────────────────
        local costLbl   = UI.Label { text = "—", fontSize = s(10), fontWeight = "bold", fontColor = { 220, 225, 235, 255 } }
        local profitLbl = UI.Label { text = "", fontSize = s(10), fontColor = { 220, 100, 90, 255 } }
        local propArea  = UI.Panel { flexDirection = "row", alignItems = "center", gap = s(3) }
        local midRightSeg = UI.Panel {
            width = s(200), flexShrink = 0,
            flexDirection = "column", justifyContent = "center", gap = s(6),
            paddingHorizontal = s(10),
            borderLeftWidth = 1, borderColor = { 255, 255, 255, 12 },
            children = {
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = s(4),
                    children = {
                        UI.Label { text = "竞拍消耗:", fontSize = s(10), fontColor = { 140, 145, 165, 180 } },
                        CoinIcon(s(13)),
                        costLbl,
                        profitLbl,
                    },
                },
                propArea,
            },
        }

        local mainRow = UI.Panel {
            width = "100%", height = ROW_HEIGHT,
            flexDirection = "row", alignItems = "center",
            paddingHorizontal = s(10), gap = s(0),
            cursor = "pointer",
            backgroundColor = { 20, 22, 32, 160 },
            borderBottomWidth = 1, borderColor = { 80, 85, 100, 50 },
            hoverBackgroundColor = { 50, 55, 75, 200 },
            pressedBackgroundColor = { 70, 76, 100, 230 },
        }
        mainRow:AddChild(leftSeg)
        mainRow:AddChild(midLeftSeg)
        mainRow:AddChild(midRightSeg)

        local row = UI.Panel {
            width = "100%", flexDirection = "column",
            children = { mainRow },
        }
        row._avatarImg    = avatarImg
        row._resultLbl    = resultLbl
        row._dateLbl      = dateLbl
        row._nameLbl      = nameLbl
        row._valueLbl     = valueLbl
        row._itemArea     = itemArea
        row._costLbl      = costLbl
        row._profitLbl    = profitLbl
        row._propArea     = propArea
        row._mainRow      = mainRow
        return row
    end

    local function bindItem(widget, data, _idx)
        if not data then return end
        local rec = data.rec
        local s = Utils.sz

        -- 头像
        local imgPanel = widget._avatarImg
        for _, c in ipairs(imgPanel.children or {}) do imgPanel:RemoveChild(c) end
        if (rec.charAvatar or "") ~= "" then
            imgPanel:AddChild(UI.Panel {
                width = "100%", height = "100%",
                backgroundImage = rec.charAvatar, backgroundFit = "cover",
            })
        end

        -- 竞拍结果
        if rec.isWin then
            widget._resultLbl.text = "竞拍成功"
            widget._resultLbl.props.fontColor = { 100, 220, 140, 255 }
        else
            widget._resultLbl.text = "竞拍失败"
            widget._resultLbl.props.fontColor = { 220, 100, 90, 255 }
        end

        -- 时间 & 玩家名
        widget._dateLbl.text = FormatDate(rec.timestamp)
        widget._nameLbl.text = rec.charName or "—"

        -- 藏品价值
        widget._valueLbl.text = FormatNum(rec.totalValue or 0)

        -- 物品图标（前5高价值）
        local ia = widget._itemArea
        for _, c in ipairs(ia.children or {}) do ia:RemoveChild(c) end
        local topItems = TopItems(rec.items or {}, THUMB_MAX)
        for _, it in ipairs(topItems) do
            local rc = RARITY_COLORS[it.rarity or "white"] or { 200, 200, 200, 255 }
            local cell = UI.Panel {
                width = s(24), height = s(24), borderRadius = s(3),
                borderWidth = 1, borderColor = { rc[1], rc[2], rc[3], 160 },
                backgroundColor = { 30, 32, 42, 255 },
                overflow = "hidden",
            }
            if (it.image or "") ~= "" then
                cell:AddChild(UI.Panel {
                    width = "100%", height = "100%",
                    backgroundImage = it.image, backgroundFit = "contain",
                })
            else
                cell:AddChild(UI.Label {
                    text = (it.name or "?"):sub(1, 1),
                    fontSize = s(10), fontColor = rc,
                    width = "100%", height = "100%", textAlign = "center",
                })
            end
            ia:AddChild(cell)
        end

        -- 竞拍消耗
        widget._costLbl.text = FormatNum(rec.bid or 0)
        if rec.isWin then
            local p = rec.profit or 0
            widget._profitLbl.text = "(" .. (p >= 0 and "+" or "") .. FormatNum(p) .. ")"
            widget._profitLbl.props.fontColor = p >= 0 and { 100, 220, 140, 255 } or { 220, 100, 90, 255 }
        else
            widget._profitLbl.text = ""
        end

        -- 道具格（六边形图标）
        local pa = widget._propArea
        for _, c in ipairs(pa.children or {}) do pa:RemoveChild(c) end
        local usedProps = CollectUsedProps(rec)
        -- 六边形尺寸：保持 78:90 比例，槽高 28px
        local hexH = s(28)
        local hexW = math.floor(hexH * 78 / 90 + 0.5)
        for slot = 1, PROP_SLOTS do
            local prop = usedProps[slot]
            local propDef = (prop and prop.id) and Props.BY_ID[prop.id] or nil
            -- 如果没有 id，尝试通过 name 匹配
            if not propDef and prop and (prop.name or "") ~= "" then
                for _, def in ipairs(Props.LIST) do
                    if def.name == prop.name then propDef = def; break end
                end
            end
            pa:AddChild(MakePropHexIcon(propDef, hexW, hexH, s(16)))
        end

        -- 整行点击 → 详情页
        widget._mainRow.props.onClick = function()
            Utils.PlayClick()
            if onShowDetail then onShowDetail(rec) end
        end
    end

    local emptyLabel = UI.Label {
        text = "暂无对局记录，完成一场对局后将在此显示",
        fontSize = sz(13), fontColor = { 130, 135, 155, 180 },
        textAlign = "center", padding = sz(40),
        visible = false,
    }

    local loadingLabel = UI.Label {
        text = "加载中...",
        fontSize = sz(13), fontColor = { 130, 135, 155, 180 },
        textAlign = "center", padding = sz(40),
        visible = true,
    }

    -- VirtualList 初始化时 Yoga 布局未完成，需传 viewportHeight 让对象池预热正确
    local dpr = graphics:GetDPR()
    local screenH = graphics:GetHeight() / dpr
    vlist = UI.VirtualList {
        width = "100%", flexGrow = 1, flexShrink = 1,
        viewportHeight = screenH,
        data = {},
        itemHeight = ROW_HEIGHT,
        itemGap = 1,
        createItem = createItem,
        bindItem = bindItem,
        visible = false,
    }

    loadMoreBtn = UI.Button {
        text = "加载更多",
        paddingHorizontal = sz(24), paddingVertical = sz(8),
        fontSize = sz(12), fontColor = { 180, 185, 200, 240 },
        backgroundColor = { 255, 255, 255, 8 },
        hoverBackgroundColor = { 255, 255, 255, 18 },
        borderWidth = 1, borderColor = { 255, 255, 255, 20 },
        borderRadius = sz(4),
        onClick = function()
            Utils.PlayClick()
            loadedCount = math.min(loadedCount + PAGE_SIZE, #allHistory)
            if vlist then vlist:SetData(GetDisplayData()) end
            local rem = #allHistory - loadedCount
            if rem <= 0 then
                if loadMorePanel then loadMorePanel:SetVisible(false) end
            else
                loadMoreBtn.text = "加载更多（" .. math.min(PAGE_SIZE, rem) .. " 条）"
            end
        end,
    }
    loadMorePanel = UI.Panel {
        width = "100%", alignItems = "center",
        paddingVertical = sz(10),
        visible = false,
        children = { loadMoreBtn },
    }

    -- 懒加载：异步从云端拉取历史记录，完成后刷新 UI
    SaveSystem.LoadHistory(function(records)
        allHistory = records
        loadedCount = math.min(PAGE_SIZE, #allHistory)
        loadingLabel:SetVisible(false)
        if #allHistory == 0 then
            emptyLabel:SetVisible(true)
        else
            vlist:SetData(GetDisplayData())
            vlist:SetVisible(true)
            local remaining = #allHistory - loadedCount
            if remaining > 0 then
                loadMoreBtn.text = "加载更多（" .. math.min(PAGE_SIZE, remaining) .. " 条）"
                loadMorePanel:SetVisible(true)
            end
        end
    end)

    return UI.Panel {
        width = "100%", flexGrow = 1, flexShrink = 1, flexDirection = "column",
        children = { loadingLabel, emptyLabel, vlist, loadMorePanel },
    }
end

-- ============================================================================
-- 公开接口：全屏切换（参考 PropScreen.Show 模式）
-- ============================================================================

function PersonalInfoScreen.Show(onBackCallback)
    UIState.currentScreen = "personal_info"
    local sz = Utils.sz

    -- 读取并重置起始 tab（从详情页返回时为 2）
    local startTab = PersonalInfoScreen._initialTab or 1
    PersonalInfoScreen._initialTab = 1

    local activeTab = 1
    local sidebarRefs = {}

    -- 内容容器（右侧，tab 切换时替换子节点）
    local contentContainer = UI.Panel {
        flexGrow = 1, flexShrink = 1,
        flexDirection = "column",
        overflow = "hidden",
    }

    -- 详情页回调：ShowMatchDetail 会替换整个 UI 树，返回时必须重建页面
    local function OnShowDetail(rec)
        UIState.currentScreen = "personal_info_detail"
        PersonalInfoScreen._goBackFromDetail = function()
            PersonalInfoScreen._goBackFromDetail = nil
            PersonalInfoScreen._initialTab = 2   -- 返回后直接打开对局 tab
            PersonalInfoScreen.Show(onBackCallback)
        end
        ShowMatchDetail(rec, PersonalInfoScreen._goBackFromDetail)
    end

    -- 预构建两个 tab 内容
    local infoTabContent = UI.ScrollView {
        width = "100%", flexGrow = 1,
        paddingHorizontal = sz(20), paddingTop = sz(16),
        children = { BuildInfoTab() },
    }
    local function GoBackFromHistory()
        Utils.PlayClick()
        UIState.currentScreen = "menu"
        if onBackCallback then
            onBackCallback()
        else
            local GameController = require("UI.GameController")
            GameController.ShowMenu()
        end
    end

    local historyTabContent = UI.Panel {
        width = "100%", flexGrow = 1, flexShrink = 1, flexDirection = "column",
        paddingHorizontal = sz(8), paddingTop = sz(8),
        children = { BuildHistoryTab(OnShowDetail, GoBackFromHistory) },
    }

    local tabContents = { infoTabContent, historyTabContent }
    local currentContent = tabContents[1]
    contentContainer:AddChild(currentContent)

    local function SwitchTab(idx)
        if activeTab == idx then return end
        contentContainer:RemoveChild(currentContent)
        activeTab = idx
        currentContent = tabContents[idx]
        contentContainer:AddChild(currentContent)
        for i, ref in ipairs(sidebarRefs) do
            local isActive = (i == idx)
            ref.panel.props.backgroundColor = isActive and { 200, 230, 0, 255 } or { 60, 62, 70, 180 }
            ref.bar.props.backgroundColor   = isActive and { 255, 255, 255, 255 } or { 0, 0, 0, 0 }
            ref.lbl.props.fontColor         = isActive and { 10, 10, 10, 255 } or { 180, 180, 185, 220 }
        end
    end

    -- 从详情页返回时直接跳到指定 tab
    if startTab ~= 1 then SwitchTab(startTab) end

    -- 侧边栏 tabs
    local tabDefs = { { label = "信息" }, { label = "对局" } }
    local sidebarItemWidgets = {}
    for i, def in ipairs(tabDefs) do
        local isActive = (i == activeTab)
        local barWidget = UI.Panel {
            width = sz(4), flexShrink = 0,
            backgroundColor = isActive and { 255, 255, 255, 255 } or { 0, 0, 0, 0 },
        }
        local lblWidget = UI.Label {
            text = def.label,
            fontSize = sz(14), fontWeight = "bold",
            fontColor = isActive and { 10, 10, 10, 255 } or { 180, 180, 185, 220 },
        }
        local itemPanel = UI.Panel {
            width = "100%",
            flexDirection = "row", alignItems = "stretch",
            borderRadius = sz(4), overflow = "hidden",
            backgroundColor = isActive and { 200, 230, 0, 255 } or { 60, 62, 70, 180 },
            cursor = "pointer",
            onClick = function() Utils.PlayClick(); SwitchTab(i) end,
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

    local function GoBack()
        Utils.PlayClick()
        UIState.currentScreen = "menu"
        PersonalInfoScreen._goBack = nil
        if onBackCallback then
            onBackCallback()
        else
            -- 通过 GameController 回菜单，确保所有回调都正确传入
            local GameController = require("UI.GameController")
            GameController.ShowMenu()
        end
    end
    PersonalInfoScreen._goBack = GoBack

    local tabGroup = UI.Panel {
        width = "100%", flexDirection = "column", gap = sz(4),
        children = sidebarItemWidgets,
    }

    local sidebar = UI.Panel {
        width = sz(140), flexShrink = 0,
        flexDirection = "column",
        paddingTop = sz(4), paddingHorizontal = sz(8), gap = sz(4),
        children = { tabGroup },
    }

    -- ── 顶栏（PropScreen 风格：图标 + 竖线 + 标题 + 右侧关闭） ──
    local topBar = UI.Panel {
        width = "100%", height = sz(50),
        flexDirection = "row", alignItems = "center",
        paddingHorizontal = sz(16),
        borderBottomWidth = 1, borderColor = { 50, 55, 70, 100 },
        children = {
            -- 左侧：图标 + 竖线 + 标题
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = sz(10),
                children = {
                    UI.Panel {
                        width = sz(22), height = sz(22),
                        backgroundImage = "image/nav_stats_20260515210551.png",
                        backgroundFit = "contain",
                    },
                    UI.Panel { width = 1, height = sz(20), backgroundColor = { 180, 185, 200, 80 } },
                    UI.Label {
                        text = "信息",
                        fontSize = sz(18), fontWeight = "bold",
                        fontColor = { 240, 235, 220, 255 },
                    },
                },
            },
            UI.Panel { flexGrow = 1 },
            -- 右侧：关闭按钮
            UI.Panel {
                width = sz(34), height = sz(34),
                borderRadius = sz(4),
                backgroundColor = { 40, 42, 55, 200 },
                borderWidth = 1, borderColor = { 70, 75, 90, 180 },
                alignItems = "center", justifyContent = "center",
                cursor = "pointer",
                onClick = GoBack,
                children = {
                    UI.Label {
                        text = "✕", fontSize = sz(18), fontWeight = "bold",
                        fontColor = { 180, 220, 0, 230 },
                    },
                },
            },
        },
    }

    -- ── 主布局 ─────────────────────────────────────────────────
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = {
            UI.Panel {
                width = "100%", height = "100%",
                backgroundImage = "image/task_bg_20260516170303.jpg",
                backgroundFit = "cover",
                flexDirection = "column",
                children = {
                    -- 高斯模糊 + 暗色遮罩
                    UI.Panel {
                        position = "absolute",
                        left = 0, top = 0, right = 0, bottom = 0,
                        backdropBlur = 40,
                        backgroundColor = { 6, 8, 16, 200 },
                    },
                    -- 顶栏
                    topBar,
                    -- 侧边栏 + 内容区
                    UI.Panel {
                        width = "100%", flexGrow = 1, flexShrink = 1,
                        flexDirection = "row",
                        overflow = "hidden",
                        children = { sidebar, contentContainer },
                    },
                    -- 底部返回栏（与 topBar 同级，在 overflow=hidden 之外）
                    UI.Panel {
                        width = "100%",
                        paddingHorizontal = sz(8), paddingVertical = sz(9),
                        borderTopWidth = 1, borderColor = { 255, 255, 255, 10 },
                        children = {
                            UI.Button {
                                text = "返回",
                                width = sz(120), paddingVertical = sz(7),
                                fontSize = sz(13), fontWeight = "bold",
                                fontColor = { 195, 215, 40, 230 },
                                backgroundColor = { 195, 215, 40, 20 },
                                hoverBackgroundColor = { 195, 215, 40, 50 },
                                pressedBackgroundColor = { 195, 215, 40, 110 },
                                borderWidth = 1, borderColor = { 195, 215, 40, 160 },
                                borderRadius = sz(4),
                                onClick = GoBack,
                            },
                        },
                    },
                },
            },
        },
    })
end

return PersonalInfoScreen
