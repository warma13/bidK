-- ============================================================================
-- UI/PersonalInfoDetail.lua
-- 个人信息页 - 对局详情（全屏）及对局列表辅助组件
-- 导出: PersonalInfoDetail.ItemThumbs, BuildDetailPanel, ShowMatchDetail
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")
local Props = require("Config.Props")
local PU = require("UI.PersonalInfoUtils")

local PersonalInfoDetail = {}

-- ── 物品缩略图行（历史列表行内使用） ────────────────────────────────────────────

function PersonalInfoDetail.ItemThumbs(items)
    local sz = Utils.sz
    local MAX_SHOW = 6
    local cells = {}
    for i = 1, math.min(MAX_SHOW, #items) do
        local it = items[i]
        local rc = PU.RARITY_COLORS[it.rarity or "white"] or { 200, 200, 200, 255 }
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

-- ── 对局结果简要面板（历史列表行内展开使用） ──────────────────────────────────────

function PersonalInfoDetail.BuildDetailPanel(rec)
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
                        PU.CoinIcon(sz(13)),
                        UI.Label {
                            text = PU.FormatNum(pl.bid or 0),
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
        children = (function()
            local rows = {
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
                                PU.CoinIcon(sz(11)),
                                UI.Label {
                                    text = PU.FormatNum(rec.totalValue or 0),
                                    fontSize = sz(11), fontColor = { 180, 185, 200, 220 },
                                },
                            },
                        },
                        rec.isWin and UI.Panel {
                            flexDirection = "row", alignItems = "center", gap = sz(3),
                            children = {
                                UI.Label { text = "盈利：", fontSize = sz(11), fontColor = { 100, 220, 140, 255 }, fontWeight = "bold" },
                                PU.CoinIcon(sz(11)),
                                UI.Label {
                                    text = PU.FormatNum(rec.profit or 0),
                                    fontSize = sz(11), fontColor = { 100, 220, 140, 255 }, fontWeight = "bold",
                                },
                            },
                        } or nil,
                    },
                },
            }
            for _, r in ipairs(playerRows) do rows[#rows + 1] = r end
            return rows
        end)(),
    }
end

-- ── 对局详情全屏页（调用 UI.SetRoot 替换整个 UI 树） ─────────────────────────────

function PersonalInfoDetail.ShowMatchDetail(rec, onBack)
    local sz = Utils.sz
    local players   = rec.players  or {}
    local roundBids = rec.roundBids or {}

    local SHOW_ROUNDS = 5
    local roundProps  = rec.roundProps or {}

    -- 找赢家名字
    local winnerName = "—"
    for _, pl in ipairs(players) do
        if pl.isWinner then winnerName = pl.name or "—"; break end
    end

    -- 列宽定义
    local colWidths = {
        profitW = sz(88),
        bidW    = sz(88),
        roundW  = sz(58),
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

        local profitSign, profitNum, profitColor, profitIsCoin
        if pl.isWinner then
            local pf = rec.profit or 0
            if pl.isHuman then
                profitSign  = pf >= 0 and "+" or ""
                profitNum   = PU.FormatNum(pf)
                profitColor = pf >= 0 and { 100, 220, 140, 255 } or { 220, 100, 90, 255 }
                profitIsCoin = true
            else
                local aiProfit = (rec.totalValue or 0) - (pl.bid or 0)
                profitSign  = aiProfit >= 0 and "+" or ""
                profitNum   = PU.FormatNum(aiProfit)
                profitColor = aiProfit >= 0 and { 100, 220, 140, 255 } or { 220, 100, 90, 255 }
                profitIsCoin = true
            end
        else
            profitSign   = ""
            profitNum    = "—"
            profitColor  = { 140, 145, 162, 200 }
            profitIsCoin = false
        end

        -- 轮次格子
        local roundCells = {}
        local rndHexH = colWidths.roundW
        local rndHexW = math.floor(rndHexH * 78 / 90 + 0.5)
        local rndIconSize = sz(26)
        for r = 1, SHOW_ROUNDS do
            local rb = roundBids[r] or roundBids[tostring(r)] or {}
            local rp = roundProps[r] or roundProps[tostring(r)] or {}
            local bid  = rb[i] or rb[tostring(i)] or 0
            local prop = rp[i] or rp[tostring(i)]
            local hasBid  = bid > 0
            local hasProp = prop and (prop.name or "") ~= ""

            local propDef = (prop and prop.id) and Props.BY_ID[prop.id] or nil
            if not propDef and hasProp then
                for _, def in ipairs(Props.LIST) do
                    if def.name == prop.name then propDef = def; break end
                end
            end

            local hexIcon = PU.MakePropHexIcon(propDef, rndHexW, rndHexH, rndIconSize)

            local priceColor = hasBid
                and (isHighlight and { 140, 230, 160, 255 } or { 190, 194, 210, 220 })
                or  { 80, 83, 100, 130 }

            roundCells[#roundCells + 1] = UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = sz(3),
                children = {
                    hexIcon,
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", justifyContent = "center",
                        gap = sz(2), width = colWidths.roundW,
                        children = {
                            PU.CoinIcon(sz(9)),
                            UI.Label {
                                text = hasBid and PU.FormatNum(bid) or "0",
                                fontSize = sz(10), fontWeight = hasBid and "bold" or "normal",
                                fontColor = priceColor,
                            },
                        },
                    },
                },
            }
        end

        -- 玩家信息列
        local nameColor  = pl.isHuman and { 220, 195, 100, 255 } or { 190, 192, 202, 255 }
        local playerCell = UI.Panel {
            flexGrow = 1, flexShrink = 1,
            flexDirection = "row", alignItems = "center", gap = sz(8),
        }
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
            UI.Panel {
                width = colWidths.profitW, flexShrink = 0,
                flexDirection = "row", alignItems = "center", justifyContent = "center",
                gap = sz(2),
                children = profitIsCoin and {
                    UI.Label { text = profitSign, fontSize = sz(13), fontWeight = "bold", fontColor = profitColor },
                    PU.CoinIcon(sz(12)),
                    UI.Label { text = profitNum, fontSize = sz(13), fontWeight = "bold", fontColor = profitColor },
                } or {
                    UI.Label { text = profitNum, fontSize = sz(13), fontWeight = "bold", fontColor = profitColor, textAlign = "center" },
                },
            },
            UI.Panel {
                width = colWidths.bidW, flexShrink = 0,
                flexDirection = "row", alignItems = "center", justifyContent = "center",
                gap = sz(2),
                children = {
                    PU.CoinIcon(sz(12)),
                    UI.Label {
                        text = PU.FormatNum(pl.bid or 0),
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

    local tableChildren = { headerRow }
    for _, pr in ipairs(playerRows) do tableChildren[#tableChildren + 1] = pr end

    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        backgroundImage = "image/task_bg_20260516170303.jpg",
        backgroundFit = "cover",
        children = {
            UI.Panel {
                position = "absolute",
                left = 0, top = 0, right = 0, bottom = 0,
                backdropBlur = 40,
                backgroundColor = { 6, 8, 16, 210 },
            },
            UI.SafeAreaView {
                edges = "all", width = "100%", height = "100%",
                children = {
                    UI.Panel {
                        width = "100%", height = "100%",
                        flexDirection = "column",
                        children = {
                            -- 顶部信息区
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", alignItems = "center",
                                paddingHorizontal = sz(16), paddingTop = sz(10), paddingBottom = sz(8),
                                borderBottomWidth = 1, borderColor = { 255, 255, 255, 12 },
                                children = {
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
                                                            UI.Label { text = PU.FormatDate(rec.timestamp), fontSize = sz(11), fontWeight = "bold", fontColor = { 220, 222, 235, 255 } },
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
                            -- 表格区域
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
                                        children = tableChildren,
                                    },
                                },
                            },
                            -- 底部返回栏
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
            },
        },
    })
end

return PersonalInfoDetail
