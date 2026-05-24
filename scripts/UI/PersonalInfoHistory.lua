-- ============================================================================
-- UI/PersonalInfoHistory.lua
-- 个人信息页 - 对局历史 Tab
-- 导出: PersonalInfoHistory.Build(onShowDetail, onBack) → widget
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")
local SaveSystem = require("SaveSystem")
local Props = require("Config.Props")
local PU = require("UI.PersonalInfoUtils")

local PersonalInfoHistory = {}

function PersonalInfoHistory.Build(onShowDetail, onBack)
    local sz = Utils.sz

    local allHistory  = {}
    local loadedCount = 0

    ---@type any
    local vlist = nil
    ---@type any
    local loadMorePanel = nil
    ---@type any
    local loadMoreBtn = nil

    local ROW_HEIGHT = sz(72)
    local PAGE_SIZE  = 10
    local PROP_SLOTS = 5
    local THUMB_MAX  = 5

    local function GetDisplayData()
        local slice = {}
        for i = 1, loadedCount do
            slice[#slice + 1] = { index = i, rec = allHistory[i] }
        end
        return slice
    end

    -- 收集本场所有使用过的道具列表（按轮次顺序）
    local function CollectUsedProps(rec)
        local propList = {}
        local roundProps = rec.roundProps or {}
        local humanIdx = 1
        for i, pl in ipairs(rec.players or {}) do
            if pl.isHuman then humanIdx = i; break end
        end
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
        table.sort(sorted, function(a, b) return (a.value or 0) > (b.value or 0) end)
        local result = {}
        for i = 1, math.min(n, #sorted) do result[#result + 1] = sorted[i] end
        return result
    end

    -- VirtualList 行工厂
    local function createItem()
        local s = Utils.sz

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
                UI.Panel {
                    flexShrink = 0,
                    flexDirection = "column", alignItems = "center", gap = s(2),
                    children = { avatarImg, nameLbl },
                },
                UI.Panel {
                    flexGrow = 1, flexShrink = 1,
                    flexDirection = "column", justifyContent = "center", gap = s(4),
                    children = { resultLbl, dateLbl },
                },
            },
        }

        local valueLbl   = UI.Label { text = "—", fontSize = s(10), fontWeight = "bold", fontColor = { 220, 225, 235, 255 } }
        local itemArea   = UI.Panel { flexDirection = "row", alignItems = "center", gap = s(3) }
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
                        PU.CoinIcon(s(13)),
                        valueLbl,
                    },
                },
                itemArea,
            },
        }

        local costLbl    = UI.Label { text = "—", fontSize = s(10), fontWeight = "bold", fontColor = { 220, 225, 235, 255 } }
        local profitLbl  = UI.Label { text = "", fontSize = s(10), fontColor = { 220, 100, 90, 255 } }
        local propArea   = UI.Panel { flexDirection = "row", alignItems = "center", gap = s(3) }
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
                        PU.CoinIcon(s(13)),
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
        row._avatarImg  = avatarImg
        row._resultLbl  = resultLbl
        row._dateLbl    = dateLbl
        row._nameLbl    = nameLbl
        row._valueLbl   = valueLbl
        row._itemArea   = itemArea
        row._costLbl    = costLbl
        row._profitLbl  = profitLbl
        row._propArea   = propArea
        row._mainRow    = mainRow
        return row
    end

    -- VirtualList 行绑定
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

        widget._dateLbl.text = PU.FormatDate(rec.timestamp)
        widget._nameLbl.text = rec.charName or "—"

        widget._valueLbl.text = PU.FormatNum(rec.totalValue or 0)

        -- 物品图标（前5高价值）
        local ia = widget._itemArea
        for _, c in ipairs(ia.children or {}) do ia:RemoveChild(c) end
        local topItems = TopItems(rec.items or {}, THUMB_MAX)
        for _, it in ipairs(topItems) do
            local rc = PU.RARITY_COLORS[it.rarity or "white"] or { 200, 200, 200, 255 }
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
        widget._costLbl.text = PU.FormatNum(rec.bid or 0)
        if rec.isWin then
            local p = rec.profit or 0
            widget._profitLbl.text = "(" .. (p >= 0 and "+" or "") .. PU.FormatNum(p) .. ")"
            widget._profitLbl.props.fontColor = p >= 0 and { 100, 220, 140, 255 } or { 220, 100, 90, 255 }
        else
            widget._profitLbl.text = ""
        end

        -- 道具格（六边形图标）
        local pa = widget._propArea
        for _, c in ipairs(pa.children or {}) do pa:RemoveChild(c) end
        local usedProps = CollectUsedProps(rec)
        local hexH = s(28)
        local hexW = math.floor(hexH * 78 / 90 + 0.5)
        for slot = 1, PROP_SLOTS do
            local prop = usedProps[slot]
            local propDef = (prop and prop.id) and Props.BY_ID[prop.id] or nil
            if not propDef and prop and (prop.name or "") ~= "" then
                for _, def in ipairs(Props.LIST) do
                    if def.name == prop.name then propDef = def; break end
                end
            end
            pa:AddChild(PU.MakePropHexIcon(propDef, hexW, hexH, s(16)))
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

    local dpr     = graphics:GetDPR()
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

    -- 懒加载：异步从云端拉取历史记录
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

return PersonalInfoHistory
