-- ============================================================================
-- UI/LeaderboardPanel.lua - 排行榜全屏页
-- ============================================================================
-- 布局（参考 PropScreen 风格）：
--   左侧边栏：多个排行维度分类
--   右侧内容：
--     顶部：标题栏 + 日/周/月 tabs + 关闭按钮
--     表头：排名 | 头像 | 名称 | 分值
--     列表：ScrollView 数据行
--     底部：我的排名（固定钉）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")
local LeaderboardFilters = require("UI.LeaderboardFilters")

local LeaderboardPanel = {}

local sz = Utils.sz
local PAGE_SIZE = 20
local MAX_TOTAL = 100

-- ============================================================================
-- 竞拍成功率编码方案
-- encoded = win_rate_bp * 1000000 + total_rounds
--   win_rate_bp = floor(win_rate% * 100)   → 0~10000（代表 0.00%~100.00%）
--   total_rounds                            → 0~999999
-- 这样排序时高胜率靠前，同胜率多局数靠前
-- ============================================================================

-- encoded = rate_bp * 100000 + total_rounds
--   rate_bp      = floor(win_rate% * 100)  → 0~10000
--   total_rounds                            → 0~99999
-- 最大值 10000*100000+99999 = 1,000,099,999 < int32 上限，不会溢出
local WIN_RATE_ROUNDS_DIVISOR = 100000

local function DecodeWinRate(encoded)
    local rounds   = encoded % WIN_RATE_ROUNDS_DIVISOR
    local rate_bp  = encoded // WIN_RATE_ROUNDS_DIVISOR
    local rate_pct = rate_bp / 100.0
    return rate_pct, rounds
end

-- ============================================================================
-- 排行维度定义
-- ============================================================================

-- fmt(rawScore) → 显示字符串（可选，不填则走通用 FormatValue）
local CATEGORIES = {
    { id = "money_rank",         label = "总利润",       key = "money_rank",         scale = 10000, unit = "" },
    { id = "loss_rank",          label = "总亏损",       key = "loss_rank",          scale = 10000, unit = "", negative = true },
    { id = "red_items_rank",     label = "红色藏品获取数", key = "red_items_rank",   scale = 1,     unit = "件" },
    { id = "single_profit_rank", label = "单次利润",     key = "single_profit_rank", scale = 10000, unit = "" },
    { id = "single_loss_rank",   label = "单次亏损",     key = "single_loss_rank",   scale = 10000, unit = "", negative = true },
    {
        id    = "win_rate_rank",
        label = "竞拍成功率",
        key   = "win_rate_rank",
        scale = 1,
        unit  = "special",
        fmt   = function(raw)
            local rate, rounds = DecodeWinRate(raw)
            if rounds == 0 then return "-- (0局)" end
            return string.format("%.1f%% (%d局)", rate, rounds)
        end,
    },
}

-- 时间段 tabs（suffix 由 GetRankKey 动态计算，这里只保留 label）
local TIME_TABS = {
    { label = "日榜", period = "day"   },
    { label = "周榜", period = "week"  },
    { label = "月榜", period = "month" },
}

--- 返回当前时间段的日期后缀字符串
--- day   → "_d20260517"
--- week  → "_w202621"   (年+ISO周号)
--- month → "_m202605"
local function GetPeriodSuffix(period)
    if period == "day" then
        return "_d" .. os.date("%Y%m%d")
    elseif period == "week" then
        return "_w" .. os.date("%Y%W")
    elseif period == "month" then
        return "_m" .. os.date("%Y%m")
    end
    return ""
end

-- 默认角色头像（未选角色时）
local DEFAULT_AVATAR = "Textures/characters/ye_lingxi.png"

-- ============================================================================
-- 内部状态
-- ============================================================================

local panel           = nil
local isVisible       = false
local activeCatIdx    = 1       -- 当前选中的分类索引
local activeTabIdx    = 1       -- 日/周/月

local loadedCount     = 0
local rawOffset       = 0
local allRankData     = {}      -- 所有已加载的排行数据
local rankRows        = {}      -- 行 UI 引用表
local listContainer   = nil     -- 列表容器
local loadMoreBtn     = nil
local listStatusLabel = nil
local scrollView      = nil     -- 引用，用于重置滚动

-- 我的排名区域 widgets
local myRankNumLabel  = nil
local myNameLabel     = nil
local myValueLabel    = nil
local myAvatarPanel   = nil

-- 分类/tab 按钮引用，用于切换高亮
local catBtns         = {}
local tabBtns         = {}

-- 列标题 label（随分类切换）
local colValueLabel   = nil

-- ============================================================================
-- 工具
-- ============================================================================

local COIN_IMG = "金币.png"
local function CoinIcon(size)
    return UI.Panel {
        width = size, height = size, flexShrink = 0,
        backgroundImage = COIN_IMG,
        backgroundFit = "contain",
    }
end

-- 获取当前分类定义
local function GetCurCat()
    return CATEGORIES[activeCatIdx] or CATEGORIES[1]
end

-- 获取实际查询的 rank key（考虑时间 tab）
local function GetRankKey()
    local cat = GetCurCat()
    local tab = TIME_TABS[activeTabIdx]
    return cat.key .. GetPeriodSuffix(tab.period)
end

-- 格式化分值显示
local function FormatValue(rawScore, cat)
    cat = cat or GetCurCat()
    if cat.fmt then return cat.fmt(rawScore) end
    local v = rawScore * cat.scale
    local prefix = (cat.negative and rawScore > 0) and "-" or ""
    if cat.unit == "%" then
        return prefix .. string.format("%.1f%%", v)
    elseif cat.unit == "件" then
        return prefix .. string.format("%d件", math.floor(v))
    else
        return prefix .. Utils.FormatMoney(v)
    end
end

-- 显示/隐藏状态标签
local function ShowStatus(text)
    if listStatusLabel then
        listStatusLabel:Destroy()
        listStatusLabel = nil
    end
    listStatusLabel = UI.Label {
        text = text, fontSize = sz(13),
        fontColor = { 140, 140, 155, 200 },
        textAlign = "center",
        width = "100%",
        paddingVertical = sz(20),
    }
    listContainer:InsertChild(listStatusLabel, 1)
end

local function HideStatus()
    if listStatusLabel then
        listStatusLabel:Destroy()
        listStatusLabel = nil
    end
end

-- ============================================================================
-- 行 UI
-- ============================================================================

-- 奖牌图 (1/2/3 名)
local MEDAL_COLORS = {
    { 255, 210, 60,  255 },   -- 1 金
    { 190, 195, 205, 255 },   -- 2 银
    { 195, 140, 80,  255 },   -- 3 铜
}

local function MakeRankBadge(rank)
    if rank <= 3 then
        local c = MEDAL_COLORS[rank]
        return UI.Panel {
            width = sz(28), height = sz(28),
            borderRadius = sz(14),
            backgroundColor = { c[1], c[2], c[3], 40 },
            borderWidth = 1,
            borderColor = { c[1], c[2], c[3], 200 },
            justifyContent = "center", alignItems = "center",
            flexShrink = 0,
            children = {
                UI.Label {
                    text = tostring(rank),
                    fontSize = sz(12), fontWeight = "bold",
                    fontColor = { c[1], c[2], c[3], 255 },
                    pointerEvents = "none",
                },
            },
        }
    else
        return UI.Label {
            text = tostring(rank),
            fontSize = sz(12),
            fontColor = { 140, 140, 155, 200 },
            textAlign = "center",
            width = sz(28), flexShrink = 0,
        }
    end
end

--- 创建一行排行榜 UI（可复用）
local function CreateRankRow()
    local rankBadgeSlot = UI.Panel {
        width = sz(36), flexShrink = 0,
        alignItems = "center", justifyContent = "center",
    }
    local avatarPanel = UI.Panel {
        width = sz(40), height = sz(40),
        borderRadius = sz(20),
        backgroundColor = { 40, 42, 55, 255 },
        backgroundImage = DEFAULT_AVATAR,
        backgroundFit = "cover",
        overflow = "hidden",
        flexShrink = 0,
        borderWidth = 1,
        borderColor = { 70, 72, 88, 200 },
    }
    local nameLabel = UI.Label {
        text = "---", fontSize = sz(13),
        fontColor = { 210, 210, 215, 255 },
        flexShrink = 1,
    }
    local charTag = UI.Panel {
        paddingHorizontal = sz(5), paddingVertical = sz(2),
        backgroundColor = { 80, 55, 20, 200 },
        borderRadius = sz(3),
        borderWidth = 1,
        borderColor = { 160, 120, 50, 160 },
        visible = false,
        flexShrink = 0,
        children = {
            UI.Label {
                id = "charTagText",
                text = "",
                fontSize = sz(10),
                fontColor = { 220, 185, 100, 255 },
                pointerEvents = "none",
            },
        },
    }
    local valueLabel = UI.Label {
        text = "0", fontSize = sz(13),
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
        textAlign = "right",
        flexShrink = 0,
    }

    local row = UI.Panel {
        flexDirection = "row", alignItems = "center",
        width = "100%",
        paddingVertical = sz(8), paddingHorizontal = sz(12),
        gap = sz(8),
        visible = false,
        children = {
            rankBadgeSlot,
            avatarPanel,
            -- 名字+称号列（flex grow）
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                flexDirection = "column",
                gap = sz(3),
                children = { nameLabel, charTag },
            },
            -- 分值（coin + 数字）
            UI.Panel {
                flexDirection = "row", alignItems = "center",
                gap = sz(3), flexShrink = 0,
                children = { CoinIcon(sz(14)), valueLabel },
            },
        },
    }

    return {
        row           = row,
        rankBadgeSlot = rankBadgeSlot,
        avatarPanel   = avatarPanel,
        nameLabel     = nameLabel,
        charTag       = charTag,
        valueLabel    = valueLabel,
    }
end

--- 更新行样式（1名金色，自己蓝色）
local function StyleRow(r, rank, isMe)
    if isMe then
        r.row:SetStyle({ backgroundColor = { 50, 100, 200, 30 } })
        r.nameLabel:SetStyle({ fontColor = { 120, 210, 255, 255 } })
    elseif rank == 1 then
        r.row:SetStyle({ backgroundColor = { 255, 200, 50, 12 } })
        r.nameLabel:SetStyle({ fontColor = { 255, 230, 160, 255 } })
    elseif rank <= 3 then
        r.row:SetStyle({ backgroundColor = { 200, 180, 100, 8 } })
        r.nameLabel:SetStyle({ fontColor = { 225, 215, 185, 255 } })
    else
        r.row:SetStyle({ backgroundColor = (rank % 2 == 0) and { 255, 255, 255, 5 } or { 0, 0, 0, 0 } })
        r.nameLabel:SetStyle({ fontColor = { 210, 210, 215, 255 } })
    end
end

--- 填充行数据
local function FillRow(r, rank, data, isMe)
    -- 清除旧 badge slot
    r.rankBadgeSlot:RemoveAllChildren()
    r.rankBadgeSlot:AddChild(MakeRankBadge(rank))

    -- 头像
    local avatar = data.charAvatar or DEFAULT_AVATAR
    r.avatarPanel:SetStyle({ backgroundImage = avatar })

    -- 名字
    r.nameLabel:SetText(data.nickname or tostring(data.userId))

    -- 称号 badge
    local cn = data.charName or ""
    if cn ~= "" then
        r.charTag:GetChild("charTagText").text = cn
        r.charTag:SetVisible(true)
    else
        r.charTag:SetVisible(false)
    end

    -- 分值
    r.valueLabel:SetText(FormatValue(data.scoreRaw or 0))

    r.row:SetVisible(true)
    StyleRow(r, rank, isMe)
end

-- ============================================================================
-- 昵称异步回填
-- ============================================================================

local function ResolveNicknames(startIdx, endIdx)
    local userIds, idxMap = {}, {}
    for i = startIdx, endIdx do
        local d = allRankData[i]
        if d then
            userIds[#userIds + 1] = d.userId
            if not idxMap[d.userId] then idxMap[d.userId] = {} end
            table.insert(idxMap[d.userId], i)
        end
    end
    if #userIds == 0 then return end
    GetUserNickname({
        userIds = userIds,
        onSuccess = function(nicknames)
            local map = {}
            for _, info in ipairs(nicknames) do map[info.userId] = info.nickname or "" end
            for uid, indices in pairs(idxMap) do
                local nick = map[uid]
                if nick and nick ~= "" then
                    for _, idx in ipairs(indices) do
                        allRankData[idx].nickname = nick
                        if rankRows[idx] then
                            rankRows[idx].nameLabel:SetText(nick)
                        end
                    end
                end
            end
        end,
        onError = function() end,
    })
end

-- ============================================================================
-- 数据加载
-- ============================================================================

local function LoadMyRank()
    if not clientCloud then
        myRankNumLabel:SetText("--")
        myNameLabel:SetText("未登录")
        myValueLabel:SetText("--")
        return
    end
    local cat = GetCurCat()
    local myId = clientCloud.userId
    clientCloud:GetUserRank(myId, GetRankKey(), {
        ok = function(rank, scoreValue)
            if rank then
                myRankNumLabel:SetText("#" .. rank)
                myValueLabel:SetText(FormatValue(scoreValue or 0, cat))
            else
                myRankNumLabel:SetText("未上榜")
                myValueLabel:SetText(FormatValue(0, cat))
            end
        end,
    })
    GetUserNickname({
        userIds = { myId },
        onSuccess = function(nicknames)
            if nicknames and #nicknames > 0 and nicknames[1].nickname then
                myNameLabel:SetText(nicknames[1].nickname)
            else
                myNameLabel:SetText(tostring(myId))
            end
        end,
        onError = function()
            myNameLabel:SetText(tostring(clientCloud.userId))
        end,
    })
end

local function LoadPage(isAutoLoad)
    if not clientCloud then
        ShowStatus("排行榜不可用")
        loadMoreBtn:SetVisible(false)
        return
    end
    if not isAutoLoad then ShowStatus("加载中...") end
    loadMoreBtn:SetDisabled(true)

    local cat   = GetCurCat()
    local start = rawOffset
    clientCloud:GetRankList(GetRankKey(), start, PAGE_SIZE, {
        ok = function(rankList)
            rawOffset = rawOffset + #rankList

            if #rankList == 0 and loadedCount == 0 then
                ShowStatus("暂无数据")
                loadMoreBtn:SetVisible(false)
                return
            end

            HideStatus()

            local myId     = clientCloud and clientCloud.userId or 0
            local prevCount = loadedCount
            local added     = 0

            for _, item in ipairs(rankList) do
                if LeaderboardFilters.IsAllowed(item) then
                    added = added + 1
                    local globalIdx = prevCount + added
                    local rankKey   = GetRankKey()
                    local scoreRaw  = item.iscore and item.iscore[rankKey] or 0
                    allRankData[globalIdx] = {
                        userId     = item.userId,
                        scoreRaw   = scoreRaw,
                        nickname   = tostring(item.userId),
                        charAvatar = item.iscore and item.iscore.charAvatar or nil,
                        charName   = item.iscore and item.iscore.charName   or "",
                    }

                    local r = CreateRankRow()
                    rankRows[globalIdx] = r
                    listContainer:AddChild(r.row)

                    local isMe = (item.userId == myId)
                    FillRow(r, globalIdx, allRankData[globalIdx], isMe)
                end
            end

            loadedCount = prevCount + added
            ResolveNicknames(prevCount + 1, loadedCount)

            local serverHasMore = (#rankList == PAGE_SIZE)
            local displayNotFull = (added < PAGE_SIZE / 2)

            if not serverHasMore or loadedCount >= MAX_TOTAL then
                loadMoreBtn:SetVisible(false)
            elseif displayNotFull then
                LoadPage(true)
            else
                loadMoreBtn:SetVisible(true)
                loadMoreBtn:SetDisabled(false)
            end
        end,
    })
end

-- ============================================================================
-- 重置并重新加载（切换分类/tab 时调用）
-- ============================================================================

local function ResetAndLoad()
    loadedCount = 0
    rawOffset   = 0
    allRankData = {}
    HideStatus()
    for _, r in ipairs(rankRows) do r.row:Destroy() end
    rankRows = {}
    loadMoreBtn:SetVisible(false)

    -- 更新列标题文字
    if colValueLabel then
        colValueLabel.text = GetCurCat().label
    end

    LoadMyRank()
    LoadPage()
end

-- ============================================================================
-- 创建 UI
-- ============================================================================

function LeaderboardPanel.Create()
    -- ── 左侧分类边栏 ─────────────────────────────────────────────────────
    -- 侧边栏分类按钮（PropScreen 风格：激活时黄绿色背景+左侧竖条）
    local sidebarChildren = {}
    for i, cat in ipairs(CATEGORIES) do
        local isActive = (i == activeCatIdx)
        local barWidget = UI.Panel {
            width = sz(4), flexShrink = 0,
            backgroundColor = isActive and { 255, 255, 255, 255 } or { 0, 0, 0, 0 },
        }
        local lblWidget = UI.Label {
            text = cat.label,
            fontSize = sz(13), fontWeight = "bold",
            fontColor = isActive and { 10, 10, 10, 255 } or { 180, 180, 185, 220 },
            pointerEvents = "none",
        }
        local btn = UI.Panel {
            width = "100%",
            flexDirection = "row", alignItems = "stretch",
            borderRadius = sz(4), overflow = "hidden",
            backgroundColor = isActive and { 200, 230, 0, 255 } or { 60, 62, 70, 180 },
            cursor = "pointer",
            onClick = function()
                if activeCatIdx == i then return end
                Utils.PlayClick()
                -- 取消旧高亮
                local oldBar = catBtns[activeCatIdx].bar
                local oldLbl = catBtns[activeCatIdx].lbl
                local oldPanel = catBtns[activeCatIdx].panel
                oldBar:SetStyle({ backgroundColor = { 0, 0, 0, 0 } })
                oldLbl:SetStyle({ fontColor = { 180, 180, 185, 220 } })
                oldPanel:SetStyle({ backgroundColor = { 60, 62, 70, 180 } })
                activeCatIdx = i
                -- 新高亮
                catBtns[i].bar:SetStyle({ backgroundColor = { 255, 255, 255, 255 } })
                catBtns[i].lbl:SetStyle({ fontColor = { 10, 10, 10, 255 } })
                catBtns[i].panel:SetStyle({ backgroundColor = { 200, 230, 0, 255 } })
                -- 更新列标题
                if colValueLabel then colValueLabel:SetStyle({ text = GetCurCat().label }) end
                ResetAndLoad()
            end,
            children = {
                barWidget,
                UI.Panel {
                    flexGrow = 1,
                    paddingVertical = sz(11), paddingLeft = sz(10), paddingRight = sz(8),
                    children = { lblWidget },
                },
            },
        }
        catBtns[i] = { panel = btn, bar = barWidget, lbl = lblWidget }
        sidebarChildren[#sidebarChildren + 1] = btn
    end

    -- 返回键（侧栏底部）
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
                    LeaderboardPanel.Hide()
                end,
            },
        },
    }

    local sidebar = UI.Panel {
        width = sz(165),
        flexShrink = 0,
        flexDirection = "column",
        backgroundColor = { 10, 12, 20, 160 },
        paddingTop = sz(6),
        paddingHorizontal = sz(8),
        gap = sz(4),
        children = sidebarChildren,
    }

    -- ── 顶部 Tabs（独立行，与主体同级）─────────────────────────────────────
    local tabBtnChildren = {}
    for i, tab in ipairs(TIME_TABS) do
        local isAct = (i == activeTabIdx)
        local tbtn
        tbtn = UI.Button {
            text = tab.label,
            width = sz(80), height = sz(40),
            fontSize = sz(14),
            fontWeight = isAct and "bold" or "normal",
            fontColor = isAct and { 220, 195, 100, 255 } or { 160, 158, 145, 200 },
            backgroundColor = { 0, 0, 0, 0 },
            borderWidth = 0,
            borderRadius = 0,
            borderBottomWidth = isAct and 2 or 0,
            borderColor = { 220, 195, 100, 255 },
            onClick = function()
                if activeTabIdx == i then return end
                tabBtns[activeTabIdx]:SetStyle({
                    fontColor = { 160, 158, 145, 200 },
                    fontWeight = "normal",
                    borderBottomWidth = 0,
                })
                activeTabIdx = i
                tabBtns[activeTabIdx]:SetStyle({
                    fontColor = { 220, 195, 100, 255 },
                    fontWeight = "bold",
                    borderBottomWidth = 2,
                })
                ResetAndLoad()
            end,
        }
        tabBtns[i] = tbtn
        tabBtnChildren[#tabBtnChildren + 1] = tbtn
    end

    -- ── 表头 ──────────────────────────────────────────────────────────────
    colValueLabel = UI.Label {
        text = GetCurCat().label,
        fontSize = sz(11),
        fontColor = { 170, 168, 155, 220 },
        textAlign = "right",
        flexShrink = 0,
        paddingRight = sz(4),
    }

    local tableHeader = UI.Panel {
        width = "100%",
        flexDirection = "row", alignItems = "center",
        paddingHorizontal = sz(12), paddingVertical = sz(6),
        marginTop = sz(8),
        backgroundColor = { 20, 22, 35, 180 },
        borderBottomWidth = 1,
        borderColor = { 70, 65, 50, 100 },
        gap = sz(8),
        children = {
            UI.Label { text = "排名", fontSize = sz(11), fontColor = { 140, 138, 125, 200 }, width = sz(36), textAlign = "center", flexShrink = 0 },
            UI.Label { text = "头像", fontSize = sz(11), fontColor = { 140, 138, 125, 200 }, width = sz(40), textAlign = "center", flexShrink = 0 },
            UI.Label { text = "名称", fontSize = sz(11), fontColor = { 140, 138, 125, 200 }, flexGrow = 1, flexShrink = 1 },
            colValueLabel,
        },
    }

    -- ── 列表容器 ──────────────────────────────────────────────────────────
    listContainer = UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 1,
    }

    loadMoreBtn = UI.Button {
        text = "加载更多",
        width = sz(130), height = sz(34),
        fontSize = sz(13),
        backgroundColor = { 40, 42, 58, 200 },
        fontColor = { 180, 180, 190, 255 },
        borderWidth = 1,
        borderColor = { 80, 78, 65, 150 },
        borderRadius = sz(4),
        marginTop = sz(8),
        marginBottom = sz(8),
        visible = false,
        onClick = function() LoadPage() end,
    }

    scrollView = UI.ScrollView {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        scrollY = true,
        showScrollbar = true,
        children = {
            listContainer,
            UI.Panel {
                width = "100%", alignItems = "center",
                children = { loadMoreBtn },
            },
        },
    }

    -- ── 我的排名（底部固定） ───────────────────────────────────────────────
    myRankNumLabel = UI.Label {
        text = "--", fontSize = sz(13),
        fontColor = { 100, 200, 255, 255 },
        fontWeight = "bold",
        width = sz(36), textAlign = "center",
        flexShrink = 0,
    }
    myAvatarPanel = UI.Panel {
        width = sz(40), height = sz(40),
        borderRadius = sz(20),
        backgroundColor = { 40, 42, 55, 255 },
        backgroundImage = DEFAULT_AVATAR,
        backgroundFit = "cover",
        overflow = "hidden",
        flexShrink = 0,
        borderWidth = 1,
        borderColor = { 60, 120, 200, 180 },
    }
    myNameLabel = UI.Label {
        text = "...", fontSize = sz(13),
        fontColor = { 100, 200, 255, 255 },
        flexGrow = 1, flexShrink = 1,
    }
    myValueLabel = UI.Label {
        text = "--", fontSize = sz(13),
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
        flexShrink = 0,
    }

    local myRankBar = UI.Panel {
        width = "100%",
        flexDirection = "row", alignItems = "center",
        paddingHorizontal = sz(12), paddingTop = sz(10), paddingBottom = sz(14),
        backgroundColor = { 25, 50, 90, 120 },
        borderTopWidth = 1,
        borderColor = { 60, 100, 180, 80 },
        gap = sz(8),
        children = {
            myRankNumLabel,
            myAvatarPanel,
            myNameLabel,
            UI.Panel {
                flexDirection = "row", alignItems = "center",
                gap = sz(3), flexShrink = 0,
                children = { CoinIcon(sz(14)), myValueLabel },
            },
        },
    }

    -- ── Tab 行（独占一行，有外边距不铺满）────────────────────────────────
    local tabRow = UI.Panel {
        width = "100%",
        flexDirection = "row", alignItems = "flex-end",
        paddingHorizontal = sz(16),
        paddingTop = sz(4),
        paddingBottom = sz(0),
        children = tabBtnChildren,
    }

    -- Tab 行底部分隔线（独立 Panel，避免 borderBottom 渲染异常）
    local tabDivider = UI.Panel {
        width = "100%", height = 1, flexShrink = 0,
        backgroundColor = { 50, 55, 70, 180 },
    }

    -- ── 右侧内容区（仅数据，tab 在上层）──────────────────────────────────
    local rightContent = UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        flexDirection = "column",
        borderWidth = 1,
        borderColor = { 50, 55, 70, 150 },
        borderRadius = sz(4),
        overflow = "hidden",
        children = {
            tableHeader,
            scrollView,
            myRankBar,
        },
    }

    -- ── 主面板 ────────────────────────────────────────────────────────────
    panel = UI.Panel {
        id = "leaderboardScreen",
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
        backgroundColor = { 17, 18, 25, 255 },
        backgroundImage = "image/edited_leaderboard_bg_blur_20260517025942.png",
        backgroundFit = "cover",
        visible = false,
        flexDirection = "column",
        children = {
            -- 背景遮罩（压暗背景图，半透明让金色纹理透出）
            UI.Panel {
                position = "absolute",
                left = 0, top = 0,
                width = "100%", height = "100%",
                backgroundColor = { 8, 10, 18, 140 },
            },
            -- 顶部标题栏（PropScreen 风格）
            UI.Panel {
                width = "100%", height = sz(50),
                flexDirection = "row", alignItems = "center",
                paddingHorizontal = sz(16),
                borderBottomWidth = 1,
                borderColor = { 50, 55, 70, 100 },
                gap = sz(10),
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = sz(10),
                        children = {
                            UI.Label {
                                text = "★", fontSize = sz(20),
                                fontColor = { 220, 195, 100, 255 },
                            },
                            UI.Panel { width = 1, height = sz(20), backgroundColor = { 180, 185, 200, 80 } },
                            UI.Label {
                                text = "排行榜",
                                fontSize = sz(18), fontWeight = "bold",
                                fontColor = { 240, 235, 220, 255 },
                            },
                        },
                    },
                    UI.Panel { flexGrow = 1 },
                    -- 关闭按钮（PropScreen 风格）
                    UI.Panel {
                        width = sz(34), height = sz(34),
                        borderRadius = sz(4),
                        backgroundColor = { 40, 42, 55, 200 },
                        borderWidth = 1, borderColor = { 70, 75, 90, 180 },
                        alignItems = "center", justifyContent = "center",
                        cursor = "pointer",
                        onClick = function()
                            Utils.PlayClick()
                            LeaderboardPanel.Hide()
                        end,
                        children = {
                            UI.Label {
                                text = "✕", fontSize = sz(18), fontWeight = "bold",
                                fontColor = { 180, 220, 0, 230 },
                                pointerEvents = "none",
                            },
                        },
                    },
                },
            },
            -- Tab 行 + 底部分隔线
            tabRow,
            tabDivider,
            -- 主体（侧栏 + 内容，左右分栏）
            UI.Panel {
                flexGrow = 1, flexBasis = 0,
                flexDirection = "row",
                marginHorizontal = sz(12),
                marginBottom = sz(12),
                marginTop = sz(8),
                gap = sz(8),
                children = { sidebar, rightContent },
            },
        },
    }
    return panel
end

-- ============================================================================
-- 显示 / 隐藏
-- ============================================================================

function LeaderboardPanel.Show()
    if isVisible then return end
    isVisible = true
    if panel then panel:SetVisible(true) end
    ResetAndLoad()
end

function LeaderboardPanel.Hide()
    isVisible = false
    if panel then panel:SetVisible(false) end
end

function LeaderboardPanel.IsVisible()
    return isVisible
end

return LeaderboardPanel
