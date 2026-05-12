-- ============================================================================
-- UI/LeaderboardPanel.lua - 富豪榜弹窗
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local Utils = require("UI.Utils")
local LeaderboardFilters = require("UI.LeaderboardFilters")

local LeaderboardPanel = {}

local PAGE_SIZE = 20
local MAX_TOTAL = 100

-- 内部状态
local panel = nil
local isVisible = false
local loadedCount = 0         -- 已显示的条目数（过滤后）
local rawOffset = 0           -- 服务端分页偏移量（过滤前，用于下一页请求）
local allRankData = {}        -- 所有已加载的排行数据
local rankRows = {}           -- 行 UI 引用
local listContainer = nil     -- 列表容器（ScrollView 内）
local loadMoreBtn = nil       -- 加载更多按钮
local listStatusLabel = nil   -- 列表状态标签
local myRankLabel = nil       -- 底部自己排名文字
local myMoneyLabel = nil      -- 底部自己金币
local myNameLabel = nil       -- 底部自己名字
local myRankNumLabel = nil    -- 底部排名序号

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 创建一行排行榜 UI
local function CreateRankRow(index)
    local rankLabel = UI.Label {
        text = "#" .. index, fontSize = 13,
        fontColor = { 160, 155, 135, 200 },
        width = 30, textAlign = "center",
        flexShrink = 0,
    }
    local nameLabel = UI.Label {
        text = "---", fontSize = 13,
        fontColor = { 210, 210, 210, 255 },
        flexShrink = 1,
    }
    local moneyLabel = UI.Label {
        text = "0", fontSize = 13,
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
    }
    local row = UI.Panel {
        flexDirection = "row", alignItems = "center",
        width = "100%",
        paddingVertical = 5, paddingHorizontal = 12,
        gap = 8,
        visible = false,
        children = {
            rankLabel, nameLabel,
            UI.Panel { flexGrow = 1 },
            UI.Panel {
                width = 13, height = 13,
                backgroundImage = Utils.GetIcon("coin"),
                backgroundFit = "contain",
                flexShrink = 0,
            },
            moneyLabel,
        },
    }
    return {
        row = row,
        rankLabel = rankLabel,
        nameLabel = nameLabel,
        moneyLabel = moneyLabel,
    }
end

--- 设置行样式（第1名金色，自己蓝色）
local function StyleRow(r, rank, isMe)
    if rank == 1 then
        r.rankLabel:SetStyle({ fontColor = { 255, 210, 80, 255 }, fontWeight = "bold" })
        r.nameLabel:SetStyle({ fontColor = { 255, 230, 160, 255 } })
        r.row:SetStyle({ backgroundColor = { 255, 200, 50, 15 } })
    elseif isMe then
        r.nameLabel:SetStyle({ fontColor = { 100, 200, 255, 255 } })
        r.row:SetStyle({ backgroundColor = { 50, 120, 200, 25 } })
    else
        r.rankLabel:SetStyle({ fontColor = { 160, 155, 135, 200 } })
        r.nameLabel:SetStyle({ fontColor = { 210, 210, 210, 255 } })
        r.row:SetStyle({ backgroundColor = { 0, 0, 0, 0 } })
    end
end

--- 填充一行数据
local function FillRow(r, rank, name, money, isMe)
    r.rankLabel:SetText("#" .. rank)
    r.nameLabel:SetText(name)
    r.moneyLabel:SetText(Utils.FormatMoney(money))
    r.row:SetVisible(true)
    StyleRow(r, rank, isMe)
end

--- 批量查昵称并回填
local function ResolveNicknames(startIdx, endIdx)
    local userIds = {}
    local idxMap = {} -- userId -> list of row indices
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
            for _, info in ipairs(nicknames) do
                map[info.userId] = info.nickname or ""
            end
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

--- 加载自己的排名（优先）
local function LoadMyRank()
    if not clientCloud then
        myRankNumLabel:SetText("--")
        myNameLabel:SetText("未登录")
        myMoneyLabel:SetText("--")
        return
    end

    local myId = clientCloud.userId
    clientCloud:GetUserRank(myId, "money_rank", {
        ok = function(rank, scoreValue)
            if rank then
                myRankNumLabel:SetText("#" .. rank)
                -- money_rank 以万为单位，乘回显示
                myMoneyLabel:SetText(Utils.FormatMoney((scoreValue or 0) * 10000))
            else
                myRankNumLabel:SetText("未上榜")
                myMoneyLabel:SetText(Utils.FormatMoney(0))
            end
        end,
    })

    -- 查自己昵称
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
            myNameLabel:SetText(tostring(myId))
        end,
    })
end

--- 显示状态文字（移除旧的再插入新的，避免隐藏后仍占布局）
local function ShowStatus(text)
    if listStatusLabel then
        listStatusLabel:Destroy()
        listStatusLabel = nil
    end
    listStatusLabel = UI.Label {
        text = text, fontSize = 13,
        fontColor = { 160, 160, 160, 200 },
        textAlign = "center",
        width = "100%",
        paddingVertical = 16,
    }
    -- 插入到 listContainer 最前面（1-based）
    listContainer:InsertChild(listStatusLabel, 1)
end

--- 移除状态文字
local function HideStatus()
    if listStatusLabel then
        listStatusLabel:Destroy()
        listStatusLabel = nil
    end
end

--- 加载排行榜（分页）
--- @param isAutoLoad boolean? 是否为过滤后自动补加载（不重置状态文字）
local function LoadPage(isAutoLoad)
    if not clientCloud then
        ShowStatus("排行榜不可用")
        loadMoreBtn:SetVisible(false)
        return
    end

    if not isAutoLoad then
        ShowStatus("加载中...")
    end
    loadMoreBtn:SetDisabled(true)

    -- rawOffset 记录服务端真实位置，与过滤后的 loadedCount 分离
    local start = rawOffset
    clientCloud:GetRankList("money_rank", start, PAGE_SIZE, {
        ok = function(rankList)
            -- 更新服务端偏移量（无论过滤与否，始终按实际拉取数推进）
            rawOffset = rawOffset + #rankList

            if #rankList == 0 and loadedCount == 0 then
                ShowStatus("暂无数据")
                loadMoreBtn:SetVisible(false)
                return
            end

            HideStatus()

            local myId = clientCloud and clientCloud.userId or 0
            local prevCount = loadedCount
            local added = 0

            for i, item in ipairs(rankList) do
                -- 过滤规则（作弊者、测试账号等）
                if LeaderboardFilters.IsAllowed(item) then
                    added = added + 1
                    local globalIdx = prevCount + added
                    -- money_rank 以万为单位，乘回显示
                    local displayMoney = (item.iscore.money_rank or 0) * 10000
                    allRankData[globalIdx] = {
                        userId = item.userId,
                        money = displayMoney,
                        nickname = tostring(item.userId),
                    }

                    local r = CreateRankRow(globalIdx)
                    rankRows[globalIdx] = r
                    listContainer:AddChild(r.row)

                    local isMe = (item.userId == myId)
                    FillRow(r, globalIdx, tostring(item.userId), displayMoney, isMe)
                end
            end

            loadedCount = prevCount + added

            -- 异步获取昵称
            ResolveNicknames(prevCount + 1, loadedCount)

            local serverHasMore = (#rankList == PAGE_SIZE)
            local displayNotFull = (added < PAGE_SIZE / 2)  -- 过滤后本页显示不足半页

            if not serverHasMore or loadedCount >= MAX_TOTAL then
                -- 服务端已无更多数据，或已达显示上限
                loadMoreBtn:SetVisible(false)
            elseif displayNotFull then
                -- 过滤掉了较多条目，自动补加载下一页，避免用户看到空页
                LoadPage(true)
            else
                loadMoreBtn:SetVisible(true)
                loadMoreBtn:SetDisabled(false)
            end
        end,
    })
end

-- ============================================================================
-- 创建 UI
-- ============================================================================

function LeaderboardPanel.Create()
    -- 列表容器（行会动态添加）
    listContainer = UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 1,
    }

    -- listStatusLabel 由 ShowStatus/HideStatus 动态管理，不在此创建
    listStatusLabel = nil

    loadMoreBtn = UI.Button {
        text = "加载更多",
        width = 140, height = 34,
        fontSize = 13,
        backgroundColor = { 50, 55, 75, 200 },
        fontColor = { 200, 200, 200, 255 },
        borderWidth = 1, borderColor = { 100, 100, 120, 150 },
        borderRadius = 0,
        marginTop = 8,
        visible = false,
        onClick = function()
            LoadPage()
        end,
    }

    -- 底部自己排名
    myRankNumLabel = UI.Label {
        text = "--", fontSize = 14,
        fontColor = { 100, 200, 255, 255 },
        fontWeight = "bold",
        width = 40, textAlign = "center",
        flexShrink = 0,
    }
    myNameLabel = UI.Label {
        text = "...", fontSize = 13,
        fontColor = { 100, 200, 255, 255 },
        flexShrink = 1,
    }
    myMoneyLabel = UI.Label {
        text = "--", fontSize = 13,
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
    }

    panel = UI.Panel {
        id = "leaderboardOverlay",
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 160 },
        justifyContent = "center", alignItems = "center",
        visible = false,
        -- 点击遮罩关闭
        onClick = function(self, x, y)
            LeaderboardPanel.Hide()
        end,
        children = {
            -- 居中弹窗
            UI.Panel {
                width = 340, height = "70%",
                backgroundColor = { 22, 26, 42, 245 },
                borderRadius = 0,
                borderWidth = 1, borderColor = { 90, 85, 65, 150 },
                flexDirection = "column",
                -- 阻止点击穿透到遮罩
                onClick = function() end,
                children = {
                    -- 头部：标题 + 关闭
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row", alignItems = "center",
                        paddingHorizontal = 16, paddingVertical = 12,
                        children = {
                            UI.Label {
                                text = "富豪榜",
                                fontSize = 17, fontColor = { 220, 200, 140, 255 },
                                fontWeight = "bold",
                            },
                            UI.Panel { flexGrow = 1 },
                            UI.Button {
                                text = "X",
                                width = 28, height = 28,
                                fontSize = 14,
                                backgroundColor = { 0, 0, 0, 0 },
                                fontColor = { 160, 160, 160, 200 },
                                borderWidth = 0,
                                onClick = function()
                                    LeaderboardPanel.Hide()
                                end,
                            },
                        },
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = { 80, 75, 55, 80 } },
                    -- 滚动列表区域
                    UI.ScrollView {
                        width = "100%",
                        flexGrow = 1,
                        flexBasis = 0,
                        scrollY = true,
                        showScrollbar = true,
                        children = {
                            listContainer,
                            -- 加载更多按钮居中
                            UI.Panel {
                                width = "100%",
                                alignItems = "center",
                                paddingVertical = 8,
                                children = { loadMoreBtn },
                            },
                        },
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = { 80, 75, 55, 80 } },
                    -- 底部：我的排名（固定）
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row", alignItems = "center",
                        paddingHorizontal = 12, paddingVertical = 10,
                        backgroundColor = { 30, 50, 80, 80 },
                        gap = 8,
                        children = {
                            UI.Label {
                                text = "我的排名", fontSize = 11,
                                fontColor = { 140, 160, 200, 180 },
                                flexShrink = 0,
                            },
                            myRankNumLabel,
                            myNameLabel,
                            UI.Panel { flexGrow = 1 },
                            UI.Panel {
                                width = 13, height = 13,
                                backgroundImage = Utils.GetIcon("coin"),
                                backgroundFit = "contain",
                                flexShrink = 0,
                            },
                            myMoneyLabel,
                        },
                    },
                },
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

    -- 重置数据
    loadedCount = 0
    rawOffset = 0
    allRankData = {}

    -- 销毁旧的状态标签
    HideStatus()

    -- 彻底移除旧行（Destroy 从 DOM 中删除，避免隐藏元素仍占布局空间）
    for i, r in ipairs(rankRows) do
        r.row:Destroy()
    end
    rankRows = {}

    if panel then panel:SetVisible(true) end

    -- 优先加载自己的排名
    LoadMyRank()
    -- 加载第一页
    LoadPage()
end

function LeaderboardPanel.Hide()
    isVisible = false
    if panel then panel:SetVisible(false) end
end

function LeaderboardPanel.IsVisible()
    return isVisible
end

return LeaderboardPanel
