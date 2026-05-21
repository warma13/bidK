-- ============================================================================
-- UI/TaskPanel.lua - 任务系统（每日任务 + 每周任务 + 救济金）
-- 按钮 + 弹窗，支持云端领取记录
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Config = require("Config")
local RewardSlot = require("UI.RewardSlot")
local Utils = require("UI.Utils")
local MoneyManager = require("MoneyManager")
local MoneyHUD = require("UI.MoneyHUD")
local SaveSystem = require("SaveSystem")
local SaveFramework = require("SaveFramework")
local FloatingMessage = require("UI.FloatingMessage")

local SeasonPass = require("SeasonPass")

local TaskPanel = {}

local C = Config.COLORS

-- 面板专用缩放：基准高度 720px，PC 端上限 1.0x，移动端上限 1.5x
local PlatformUtils = require("urhox-libs.Platform.PlatformUtils")
local sz
do
    local dpr     = graphics:GetDPR()
    local screenH = graphics:GetHeight() / dpr
    local scale   = math.max(0.8, screenH / 720)
    if PlatformUtils.IsMobilePlatform() then
        scale = math.min(1.5, scale)
    else
        scale = math.min(1.0, scale)
    end
    sz = function(base) return math.floor(base * scale) end
end

-- ============================================================================
-- 颜色补充（PropScreen 风格）
-- ============================================================================
local CC = {
    -- 侧栏标签 —— 与 PropScreen 完全一致
    tabActiveBg     = { 200, 230, 0,   255 },  -- 黄绿活跃背景
    tabActiveText   = { 10,  10,  10,  255 },  -- 活跃时深色文字
    tabActiveBorder = { 255, 255, 255, 255 },  -- 活跃时白色左边框
    tabInactiveBg   = { 60,  62,  70,  180 },  -- 非活跃背景
    tabInactiveText = { 180, 180, 185, 220 },  -- 非活跃文字
    -- 内容区
    rowSeparator    = { 55,  65,  95,  70  },
    rowBg           = { 15,  18,  30,  210 },
    btnClaim        = { 50,  200, 85,  255 },
    btnClaimText    = { 255, 255, 255, 255 },
    btnPending      = { 40,  48,  68,  220 },
    btnPendingText  = { 140, 155, 185, 200 },
    btnClaimAll     = { 195, 225, 0,   255 },
    btnClaimAllText = { 20,  22,  10,  255 },
    iconBadgeBg     = { 28,  33,  55,  225 },
    iconBadgeBorder = { 60,  72,  110, 160 },
    headerDivider   = { 50,  55,  70,  150 },  -- 与 PropScreen 一致
    headerPipe      = { 200, 230, 0,   255 },  -- 内容标题黄绿竖条
    reliefBg        = { 30,  36,  52,  200 },
    reliefBorder    = { 80,  60,  30,  180 },
    -- 返回按钮（PropScreen 底部返回按钮风格）
    backBtnText     = { 195, 215, 40,  230 },
    backBtnBg       = { 195, 215, 40,  20  },
    backBtnBorder   = { 195, 215, 40,  160 },
}

-- ============================================================================
-- 云端键名
-- ============================================================================
local KEY_DAILY_CLAIMED  = "task_daily_claimed"   -- 已领取每日任务位掩码（int）
local KEY_WEEKLY_CLAIMED = "task_weekly_claimed"  -- 已领取每周任务位掩码（int）
local KEY_DAILY_DATE     = "task_daily_date"      -- 上次重置日期
local KEY_WEEKLY_WEEK    = "task_weekly_week"     -- 上次重置周号

local MODULE_NAME = "task_panel"

-- ============================================================================
-- 任务配置
-- ============================================================================
local DAILY_TASKS = {
    -- ── 上线签到 ────────────────────────────────────────────────────────────
    {
        id    = 1,
        title = "今日上线",
        desc  = "今日登录游戏",
        reward = { coins = 10000, tickets = 0, xp = 100 },
        -- 每日重置时 snap.hasLogin = false；进入游戏后置 true
        checkFn = function(snap) return (snap.hasLogin and 1 or 0) end,
        target = 1,
    },
    -- ── 参与竞拍 ────────────────────────────────────────────────────────────
    {
        id    = 2,
        title = "初试身手",
        desc  = "今日参与 1 场拍卖",
        reward = { coins = 10000, tickets = 0, xp = 100 },
        checkFn = function(snap) return (SaveSystem.GetStats().totalGames or 0) - (snap.totalGames or 0) end,
        target = 1,
    },
    {
        id    = 3,
        title = "竞价达人",
        desc  = "今日参与 3 场拍卖",
        reward = { coins = 20000, tickets = 0, xp = 200 },
        checkFn = function(snap) return (SaveSystem.GetStats().totalGames or 0) - (snap.totalGames or 0) end,
        target = 3,
    },
    {
        id    = 4,
        title = "拍场老手",
        desc  = "今日参与 9 场拍卖",
        reward = { coins = 40000, tickets = 0, xp = 400 },
        checkFn = function(snap) return (SaveSystem.GetStats().totalGames or 0) - (snap.totalGames or 0) end,
        target = 9,
    },
    -- ── 成功竞拍 ────────────────────────────────────────────────────────────
    {
        id    = 5,
        title = "得意满载",
        desc  = "今日成功竞拍 1 场",
        reward = { coins = 10000, tickets = 0, xp = 100 },
        checkFn = function(snap) return (SaveSystem.GetStats().wins or 0) - (snap.wins or 0) end,
        target = 1,
    },
    {
        id    = 6,
        title = "收藏新星",
        desc  = "今日成功竞拍 3 场",
        reward = { coins = 20000, tickets = 0, xp = 200 },
        checkFn = function(snap) return (SaveSystem.GetStats().wins or 0) - (snap.wins or 0) end,
        target = 3,
    },
    {
        id    = 7,
        title = "拍宝大师",
        desc  = "今日成功竞拍 9 场",
        reward = { coins = 40000, tickets = 0, xp = 400 },
        checkFn = function(snap) return (SaveSystem.GetStats().wins or 0) - (snap.wins or 0) end,
        target = 9,
    },
    -- ── 竞拍收益 ────────────────────────────────────────────────────────────
    {
        id    = 8,
        title = "小试牛刀",
        desc  = "今日竞拍收益达 10 万",
        reward = { coins = 10000, tickets = 0, xp = 200 },
        checkFn = function(snap) return (SaveSystem.GetStats().totalProfit or 0) - (snap.totalProfit or 0) end,
        target = 100000,
    },
    {
        id    = 9,
        title = "财富涌现",
        desc  = "今日竞拍收益达 100 万",
        reward = { coins = 20000, tickets = 0, xp = 400 },
        checkFn = function(snap) return (SaveSystem.GetStats().totalProfit or 0) - (snap.totalProfit or 0) end,
        target = 1000000,
    },
    {
        id    = 10,
        title = "富甲一方",
        desc  = "今日竞拍收益达 300 万",
        reward = { coins = 40000, tickets = 0, xp = 600 },
        checkFn = function(snap) return (SaveSystem.GetStats().totalProfit or 0) - (snap.totalProfit or 0) end,
        target = 3000000,
    },
}

local WEEKLY_TASKS = {
    -- ── 使用指定门票参与 ──────────────────────────────────────────────────────
    {
        id    = 1,
        title = "拍场常客",
        desc  = "本周使用指定门票参与 10 场",
        reward = { coins = 500000, tickets = 0, xp = 500 },
        checkFn = function(snap) return (SaveSystem.GetStats().ticketGames or 0) - (snap.ticketGames or 0) end,
        target = 10,
    },
    {
        id    = 2,
        title = "券场达人",
        desc  = "本周使用指定门票参与 30 场",
        reward = { coins = 1000000, tickets = 0, xp = 1000 },
        checkFn = function(snap) return (SaveSystem.GetStats().ticketGames or 0) - (snap.ticketGames or 0) end,
        target = 30,
    },
    {
        id    = 3,
        title = "拍场宗师",
        desc  = "本周使用指定门票参与 60 场",
        reward = { coins = 2500000, tickets = 0, xp = 2000 },
        checkFn = function(snap) return (SaveSystem.GetStats().ticketGames or 0) - (snap.ticketGames or 0) end,
        target = 60,
    },
    -- ── 累积拍下红色物品 ──────────────────────────────────────────────────────
    {
        id    = 4,
        title = "红色猎手",
        desc  = "本周累积拍下红色物品 100 件",
        reward = { coins = 500000, tickets = 0, xp = 500 },
        checkFn = function(snap) return (SaveSystem.GetStats().redItemsWon or 0) - (snap.redItemsWon or 0) end,
        target = 100,
    },
    {
        id    = 5,
        title = "珍品收藏",
        desc  = "本周累积拍下红色物品 300 件",
        reward = { coins = 1000000, tickets = 0, xp = 1000 },
        checkFn = function(snap) return (SaveSystem.GetStats().redItemsWon or 0) - (snap.redItemsWon or 0) end,
        target = 300,
    },
    {
        id    = 6,
        title = "顶级藏家",
        desc  = "本周累积拍下红色物品 600 件",
        reward = { coins = 2500000, tickets = 0, xp = 2000 },
        checkFn = function(snap) return (SaveSystem.GetStats().redItemsWon or 0) - (snap.redItemsWon or 0) end,
        target = 600,
    },
    -- ── 累积在线时长 ──────────────────────────────────────────────────────────
    {
        id    = 7,
        title = "初心玩家",
        desc  = "本周累积在线 3 小时",
        reward = { coins = 500000, tickets = 0, xp = 500 },
        -- checkFn 返回小时数（整数）
        checkFn = function(snap) return math.floor((SaveSystem.GetPlayTime() - (snap.playTime or 0)) / 3600) end,
        target = 3,
        unit = "h",
    },
    {
        id    = 8,
        title = "忠实玩家",
        desc  = "本周累积在线 9 小时",
        reward = { coins = 1000000, tickets = 0, xp = 1000 },
        checkFn = function(snap) return math.floor((SaveSystem.GetPlayTime() - (snap.playTime or 0)) / 3600) end,
        target = 9,
        unit = "h",
    },
    {
        id    = 9,
        title = "骨灰玩家",
        desc  = "本周累积在线 18 小时",
        reward = { coins = 2500000, tickets = 0, xp = 2000 },
        checkFn = function(snap) return math.floor((SaveSystem.GetPlayTime() - (snap.playTime or 0)) / 3600) end,
        target = 18,
        unit = "h",
    },
}

-- ============================================================================
-- 模块状态
-- ============================================================================
local cloudLoaded  = false
local popupVisible = false

local dailyClaimedBits  = 0
local weeklyClaimedBits = 0
local dailyDate  = ""
local weeklyWeek = ""

-- 每日/每周快照（统计归零的基准点）
local dailySnap  = {}
local weeklySnap = {}

-- UI 引用
local btnBadge     = nil
local popupOverlay = nil
local tabIndex     = 1  -- 默认选中"每日任务"
local tabContents  = {}
local tabButtons   = {}
local tabBorders   = {}
local tabLabels    = {}  -- 标签文字引用（用于切换颜色）
local claimAllBtns = {}
local rowUpdateFns = {}   -- key: "d_<id>" / "w_<id>" → 刷新该行 UI 状态的函数
local UpdateClaimAllBtns  -- forward declaration

-- ============================================================================
-- SaveFramework 注册
-- ============================================================================
SaveFramework.Register(MODULE_NAME, {
    cloudKeys = {
        KEY_DAILY_CLAIMED, KEY_WEEKLY_CLAIMED,
        KEY_DAILY_DATE, KEY_WEEKLY_WEEK,
        "task_daily_snap", "task_weekly_snap",
    },
    load = function(values, iscores)
        local today  = os.date("%Y-%m-%d")
        local thisWeek = os.date("%Y-%V")

        local savedDate = values[KEY_DAILY_DATE] or ""
        local savedWeek = values[KEY_WEEKLY_WEEK] or ""

        -- 每日重置
        if savedDate ~= today then
            dailyClaimedBits = 0
            dailyDate = today
            -- 更新每日快照（hasLogin=true 表示今日已上线，totalProfit 用于收益计算）
            local s = SaveSystem.GetStats()
            dailySnap = {
                totalGames   = s.totalGames   or 0,
                wins         = s.wins         or 0,
                totalItemsWon= s.totalItemsWon or 0,
                highestBid   = s.highestBid   or 0,
                playTime     = SaveSystem.GetPlayTime(),
                totalProfit  = s.totalProfit  or 0,
                hasLogin     = true,  -- 今日已上线（重置即登录）
            }
            SaveFramework.MarkDirty(MODULE_NAME)
        else
            dailyClaimedBits = iscores[KEY_DAILY_CLAIMED] or 0
            dailyDate = today
            local snap = values["task_daily_snap"]
            if snap then
                local ok, t = pcall(function() return cjson.decode(snap) end)
                if ok and t then
                    -- 兼容旧存档：补全缺失字段
                    local s = SaveSystem.GetStats()
                    t.totalProfit = t.totalProfit or (s.totalProfit or 0)
                    t.hasLogin    = true  -- 当前在线即为今日已上线
                    dailySnap = t
                end
            end
        end

        -- 每周重置
        if savedWeek ~= thisWeek then
            weeklyClaimedBits = 0
            weeklyWeek = thisWeek
            local s = SaveSystem.GetStats()
            weeklySnap = {
                totalGames   = s.totalGames    or 0,
                wins         = s.wins          or 0,
                totalItemsWon= s.totalItemsWon or 0,
                highestBid   = s.highestBid    or 0,
                ticketGames  = s.ticketGames   or 0,
                redItemsWon  = s.redItemsWon   or 0,
                playTime     = SaveSystem.GetPlayTime(),
            }
            SaveFramework.MarkDirty(MODULE_NAME)
        else
            weeklyClaimedBits = iscores[KEY_WEEKLY_CLAIMED] or 0
            weeklyWeek = thisWeek
            local snap = values["task_weekly_snap"]
            if snap then
                local ok, t = pcall(function() return cjson.decode(snap) end)
                if ok and t then
                    -- 兼容旧存档：补全缺失字段
                    local s = SaveSystem.GetStats()
                    t.ticketGames = t.ticketGames or (s.ticketGames or 0)
                    t.redItemsWon = t.redItemsWon or (s.redItemsWon or 0)
                    t.playTime    = t.playTime    or SaveSystem.GetPlayTime()
                    weeklySnap = t
                end
            end
        end

        cloudLoaded = true
    end,
    save = function(batch)
        batch:SetInt(KEY_DAILY_CLAIMED,  dailyClaimedBits)
        batch:SetInt(KEY_WEEKLY_CLAIMED, weeklyClaimedBits)
        batch:Set(KEY_DAILY_DATE,   dailyDate)
        batch:Set(KEY_WEEKLY_WEEK,  weeklyWeek)
        batch:Set("task_daily_snap",  cjson.encode(dailySnap))
        batch:Set("task_weekly_snap", cjson.encode(weeklySnap))
    end,
    defaults = function()
        -- SaveFramework 调用 defaults() 时不传参数，此处只初始化本地变量
        dailyClaimedBits  = 0
        weeklyClaimedBits = 0
        dailyDate  = ""
        weeklyWeek = ""
        dailySnap  = {}
        weeklySnap = {}
        cloudLoaded = true
        print("[TaskPanel] Defaults applied")
    end,
})

-- ============================================================================
-- 工具函数
-- ============================================================================
local function GetTaskProgress(task, snap)
    if not snap then return 0 end
    local ok, v = pcall(task.checkFn, snap)
    if not ok then return 0 end
    return math.max(0, math.floor(v))
end

local function IsTaskComplete(task, snap)
    return GetTaskProgress(task, snap) >= task.target
end

local function IsBitSet(bits, idx)
    return (bits & (1 << (idx - 1))) ~= 0
end

local function SetBit(bits, idx)
    return bits | (1 << (idx - 1))
end

local function CountClaimable(tasks, claimedBits, snap)
    local n = 0
    for _, task in ipairs(tasks) do
        if not IsBitSet(claimedBits, task.id) and IsTaskComplete(task, snap) then
            n = n + 1
        end
    end
    return n
end

local function UpdateBadge()
    if not btnBadge then return end
    local n = CountClaimable(DAILY_TASKS, dailyClaimedBits, dailySnap)
             + CountClaimable(WEEKLY_TASKS, weeklyClaimedBits, weeklySnap)
    btnBadge:SetVisible(n > 0)
end

UpdateClaimAllBtns = function()
    local function setBtn(btn, active)
        if not btn then return end
        btn.props.backgroundColor = active and CC.btnClaimAll or { 55, 60, 72, 200 }
        btn.props.fontColor       = active and CC.btnClaimAllText or { 110, 120, 140, 180 }
    end
    setBtn(claimAllBtns[1], CountClaimable(DAILY_TASKS,  dailyClaimedBits,  dailySnap)  > 0)
    setBtn(claimAllBtns[2], CountClaimable(WEEKLY_TASKS, weeklyClaimedBits, weeklySnap) > 0)
end

-- ============================================================================
-- 领取逻辑
-- ============================================================================
local function DoClaimTask(isWeekly, taskId, onDone, silent)
    local tasks       = isWeekly and WEEKLY_TASKS or DAILY_TASKS
    local snap        = isWeekly and weeklySnap   or dailySnap
    local claimedBits = isWeekly and weeklyClaimedBits or dailyClaimedBits

    local task
    for _, t in ipairs(tasks) do
        if t.id == taskId then task = t; break end
    end
    if not task then return end
    if IsBitSet(claimedBits, taskId) then return end
    if not IsTaskComplete(task, snap) then return end

    if isWeekly then
        weeklyClaimedBits = SetBit(weeklyClaimedBits, taskId)
    else
        dailyClaimedBits = SetBit(dailyClaimedBits, taskId)
    end

    if task.reward.coins > 0 then
        MoneyManager.AddMoneyFromMenu(task.reward.coins, "任务奖励", { skipSave = true })
        FloatingMessage.Show("+" .. task.reward.coins .. " 金币", C.accent)
    end

    if task.reward.xp and task.reward.xp > 0 then
        local taskLabel = (isWeekly and "weekly" or "daily") .. "_" .. taskId
        pcall(function() SeasonPass.AddTaskXP(task.reward.xp, taskLabel) end)
        FloatingMessage.Show("+" .. task.reward.xp .. " 通行证XP", { 130, 220, 255, 255 })
    end

    SaveFramework.MarkDirty(MODULE_NAME)
    UpdateBadge()
    UpdateClaimAllBtns()
    if onDone then onDone() end
end

-- ============================================================================
-- UI 构建辅助
-- ============================================================================
-- 大额奖励格式化（≥1万显示"X万"）
local function FormatReward(coins)
    if coins >= 10000 then
        local wan = coins / 10000
        if wan == math.floor(wan) then
            return tostring(math.floor(wan)) .. "万"
        else
            return string.format("%.1f", wan) .. "万"
        end
    end
    return tostring(coins)
end

-- 单个任务行（新样式：上行任务名+进度，下行奖励格子，右侧领取按钮）
local function TaskRow(task, claimedBits, snap, isWeekly)
    local isClaimed  = IsBitSet(claimedBits, task.id)
    local isComplete = IsTaskComplete(task, snap)
    local progress   = GetTaskProgress(task, snap)
    local u = task.unit or ""

    -- 前置声明（闭包引用）
    ---@type table
    local titleLabel = nil
    ---@type table
    local claimBtn   = nil
    ---@type table
    local claimedLbl = nil
    ---@type table
    local pendingLbl = nil

    local function MakeTitleText(prog)
        local p = FormatReward(math.min(prog, task.target)) .. u
        local t = FormatReward(task.target) .. u
        return task.title .. "(" .. p .. "/" .. t .. ")"
    end

    -- 奖励格子列表
    local slots = {}
    if task.reward.coins and task.reward.coins > 0 then
        slots[#slots + 1] = RewardSlot.Make({
            size        = 52,
            image       = Utils.GetIcon("coin"),
            count       = FormatReward(task.reward.coins),
            bgColor     = { 20, 48, 28, 230 },
            borderColor = { 55, 130, 70, 180 },
        }, sz)
    end
    if task.reward.xp and task.reward.xp > 0 then
        slots[#slots + 1] = RewardSlot.Make({
            size          = 52,
            image         = "image/xp_gold_20260518121142.png",
            count         = tostring(task.reward.xp),
            borderColor   = { 50, 105, 175, 180 },
        }, sz)
    end

    -- 状态：已领取标签
    claimedLbl = UI.Panel {
        width = sz(72), height = sz(40),
        borderRadius = sz(6),
        backgroundColor = { 38, 44, 60, 200 },
        borderWidth = 1, borderColor = { 70, 78, 100, 160 },
        alignItems = "center", justifyContent = "center",
        visible = isClaimed,
        pointerEvents = "none",
        children = {
            UI.Label {
                text = "已领取", fontSize = sz(12),
                fontColor = { 120, 135, 160, 200 },
                pointerEvents = "none",
            },
        },
    }

    -- 状态：未完成标签
    pendingLbl = UI.Panel {
        width = sz(72), height = sz(40),
        borderRadius = sz(6),
        backgroundColor = CC.btnPending,
        borderWidth = 1, borderColor = { 60, 68, 95, 150 },
        alignItems = "center", justifyContent = "center",
        visible = not isComplete and not isClaimed,
        pointerEvents = "none",
        children = {
            UI.Label {
                text = "未完成", fontSize = sz(12),
                fontColor = CC.btnPendingText,
                pointerEvents = "none",
            },
        },
    }

    -- 状态：领取按钮
    claimBtn = UI.Button {
        text = "领取",
        width = sz(72), height = sz(40),
        fontSize = sz(15), fontWeight = "bold",
        backgroundColor = CC.btnClaim,
        fontColor = CC.btnClaimText,
        borderRadius = sz(6),
        visible = isComplete and not isClaimed,
        onClick = function(self)
            DoClaimTask(isWeekly, task.id, function()
                self:SetVisible(false)
                claimedLbl:SetVisible(true)
                pendingLbl:SetVisible(false)
                UpdateBadge()
            end)
        end,
    }

    -- 任务标题（带进度）
    titleLabel = UI.Label {
        text = MakeTitleText(progress),
        fontSize = sz(13), fontColor = C.textPrimary,
        marginBottom = sz(6),
        pointerEvents = "none",
    }

    -- 注册刷新函数
    local rowKey = (isWeekly and "w_" or "d_") .. task.id
    rowUpdateFns[rowKey] = function()
        local bits     = isWeekly and weeklyClaimedBits or dailyClaimedBits
        local curSnap  = isWeekly and weeklySnap or dailySnap
        local claimed  = IsBitSet(bits, task.id)
        local complete = IsTaskComplete(task, curSnap)
        local prog     = GetTaskProgress(task, curSnap)
        claimBtn:SetVisible(complete and not claimed)
        claimedLbl:SetVisible(claimed)
        pendingLbl:SetVisible(not complete and not claimed)
        titleLabel.props.text = MakeTitleText(prog)
    end

    -- 拼装格子行 children（避免 table.unpack 非末尾问题）
    local slotRowChildren = {}
    for _, s in ipairs(slots) do
        slotRowChildren[#slotRowChildren + 1] = s
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingVertical = sz(12), paddingLeft = sz(14), paddingRight = sz(12),
        backgroundImage = "image/task_row_bg_20260516173338.png",
        backgroundFit = "cover",
        marginBottom = sz(10),
        borderRadius = sz(6),
        overflow = "hidden",
        children = {
            -- 左侧竖线装饰
            UI.Panel {
                width = sz(3), alignSelf = "stretch",
                flexShrink = 0,
                backgroundColor = { 90, 95, 110, 160 },
                marginRight = sz(12),
                borderRadius = sz(2),
                pointerEvents = "none",
            },
            -- 中间：任务名（上）+ 奖励格子（下）
            UI.Panel {
                flex = 1,
                flexDirection = "column",
                justifyContent = "center",
                pointerEvents = "none",
                children = {
                    titleLabel,
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = sz(8),
                        pointerEvents = "none",
                        children = slotRowChildren,
                    },
                },
            },
            -- 右侧：三态按钮
            UI.Panel {
                marginLeft = sz(10),
                flexShrink = 0,
                alignItems = "center", justifyContent = "center",
                children = { claimBtn, claimedLbl, pendingLbl },
            },
        },
    }
end

-- 全部领取按钮行
local function ClaimAllBar(isWeekly, onClaimAll)
    local tasks  = isWeekly and WEEKLY_TASKS or DAILY_TASKS
    local bits   = isWeekly and weeklyClaimedBits or dailyClaimedBits
    local snap   = isWeekly and weeklySnap or dailySnap
    local active = CountClaimable(tasks, bits, snap) > 0

    local claimBtn = UI.Button {
        text = "全部领取",
        fontSize = sz(13),
        backgroundColor = active and CC.btnClaimAll or { 55, 60, 72, 200 },
        fontColor       = active and CC.btnClaimAllText or { 110, 120, 140, 180 },
        paddingHorizontal = sz(18), paddingVertical = sz(7),
        borderRadius = sz(6),
        onClick = function(self) onClaimAll() end,
    }

    return UI.Panel {
        width = "100%",
        paddingHorizontal = sz(12), paddingVertical = sz(10),
        borderTopWidth = 1, borderTopColor = CC.headerDivider,
        backgroundColor = { 0, 0, 0, 0 },
        alignItems = "flex-end",
        children = { claimBtn },
    }, claimBtn
end

-- ============================================================================
-- 构建标签内容
-- ============================================================================
-- tabIndex: 1=竞拍旅程(暂用统计), 2=每日任务, 3=每周任务, 4=救济金

local function BuildDailyContent()
    local rows = {}
    for _, task in ipairs(DAILY_TASKS) do
        rows[#rows + 1] = TaskRow(task, dailyClaimedBits, dailySnap, false)
    end

    -- 剩余时间
    local hour   = tonumber(os.date("%H")) or 0
    local minute = tonumber(os.date("%M")) or 0
    local remainHour   = 23 - hour
    local remainMinute = 59 - minute
    local timeStr = remainHour .. "小时" .. remainMinute .. "分"

    return UI.Panel {
        flex = 1, flexDirection = "column",
        children = {
            -- 内容区标题（PropScreen 竖条风格）
            UI.Panel {
                width = "100%",
                paddingLeft = sz(14), paddingRight = sz(16), paddingVertical = sz(10),
                flexDirection = "row", alignItems = "center",
                backgroundColor = { 20, 22, 32, 230 },
                borderBottomWidth = 1, borderBottomColor = CC.headerDivider,
                gap = sz(10),
                pointerEvents = "none",
                children = {
                    UI.Panel {
                        width = sz(3), height = sz(16),
                        backgroundColor = CC.headerPipe, borderRadius = sz(2),
                    },
                    UI.Label {
                        text = "每日任务",
                        fontSize = sz(14), fontWeight = "bold",
                        fontColor = { 230, 230, 235, 255 },
                    },
                    UI.Panel { flexGrow = 1 },
                    UI.Label { text = "剩余: " .. timeStr,
                        fontSize = sz(11), fontColor = C.textMuted },
                },
            },
            -- 任务列表
            UI.ScrollView {
                flex = 1, width = "100%",
                paddingHorizontal = sz(10), paddingTop = sz(10),
                children = rows,
            },
            -- 全部领取
            (function()
                local panel, btn = ClaimAllBar(false, function()
                    local claimed = false
                    for _, task in ipairs(DAILY_TASKS) do
                        if not IsBitSet(dailyClaimedBits, task.id) and IsTaskComplete(task, dailySnap) then
                            DoClaimTask(false, task.id, nil, true)
                            claimed = true
                        end
                    end
                    -- 循环结束后标脏，延迟5秒保存
                    if claimed then SaveFramework.MarkDirty(MODULE_NAME) end
                    for _, task in ipairs(DAILY_TASKS) do
                        local fn = rowUpdateFns["d_" .. task.id]
                        if fn then fn() end
                    end
                    UpdateBadge()
                end)
                claimAllBtns[1] = btn
                return panel
            end)(),
        },
    }
end

local function BuildWeeklyContent()
    local rows = {}
    for _, task in ipairs(WEEKLY_TASKS) do
        rows[#rows + 1] = TaskRow(task, weeklyClaimedBits, weeklySnap, true)
    end

    -- %w: 0=周日 … 6=周六，以周日为每周起点，剩余天数 = 6 - 今天
    local weekday = tonumber(os.date("%w")) or 0
    local remainDays = 6 - weekday
    local timeStr = remainDays .. "天"

    return UI.Panel {
        flex = 1, flexDirection = "column",
        children = {
            -- 内容区标题（PropScreen 竖条风格）
            UI.Panel {
                width = "100%",
                paddingLeft = sz(14), paddingRight = sz(16), paddingVertical = sz(10),
                flexDirection = "row", alignItems = "center",
                backgroundColor = { 20, 22, 32, 230 },
                borderBottomWidth = 1, borderBottomColor = CC.headerDivider,
                gap = sz(10),
                pointerEvents = "none",
                children = {
                    UI.Panel {
                        width = sz(3), height = sz(16),
                        backgroundColor = CC.headerPipe, borderRadius = sz(2),
                    },
                    UI.Label {
                        text = "每周任务",
                        fontSize = sz(14), fontWeight = "bold",
                        fontColor = { 230, 230, 235, 255 },
                    },
                    UI.Panel { flexGrow = 1 },
                    UI.Label { text = "剩余: " .. timeStr,
                        fontSize = sz(11), fontColor = C.textMuted },
                },
            },
            UI.ScrollView {
                flex = 1, width = "100%",
                paddingHorizontal = sz(10), paddingTop = sz(10),
                children = rows,
            },
            (function()
                local panel, btn = ClaimAllBar(true, function()
                    local claimed = false
                    for _, task in ipairs(WEEKLY_TASKS) do
                        if not IsBitSet(weeklyClaimedBits, task.id) and IsTaskComplete(task, weeklySnap) then
                            DoClaimTask(true, task.id, nil, true)
                            claimed = true
                        end
                    end
                    -- 循环结束后标脏，延迟5秒保存
                    if claimed then SaveFramework.MarkDirty(MODULE_NAME) end
                    for _, task in ipairs(WEEKLY_TASKS) do
                        local fn = rowUpdateFns["w_" .. task.id]
                        if fn then fn() end
                    end
                    UpdateBadge()
                end)
                claimAllBtns[2] = btn
                return panel
            end)(),
        },
    }
end


-- ============================================================================
-- 弹窗构建
-- ============================================================================
local function BuildPopupContent()

    -- 标签切换（PropScreen 风格：切换背景色 + 边框色 + 文字色）
    local function switchTab(idx)
        tabIndex = idx
        for i, content in ipairs(tabContents) do
            content:SetVisible(i == idx)
        end
        for i, btn in ipairs(tabButtons) do
            local isActive = (i == idx)
            -- 切换行背景
            btn.props.backgroundColor = isActive and CC.tabActiveBg or CC.tabInactiveBg
            -- 切换左边框颜色（活跃白色，非活跃灰色）
            if tabBorders[i] then
                tabBorders[i].props.backgroundColor = isActive and CC.tabActiveBorder or { 90, 95, 110, 140 }
            end
            -- 切换文字颜色
            if tabLabels[i] then
                tabLabels[i].props.fontColor = isActive and CC.tabActiveText or CC.tabInactiveText
            end
        end
    end

    local TAB_NAMES = { "每日任务", "每周任务" }

    tabContents = {
        BuildDailyContent(),
        BuildWeeklyContent(),
    }

    tabButtons = {}
    tabBorders = {}
    local tabItems = {}
    for i, name in ipairs(TAB_NAMES) do
        local isActive = (i == tabIndex)
        local capturedI = i

        -- PropScreen 风格：行容器包含左边框 + 内容区（活跃白色，非活跃灰色）
        local leftBorder = UI.Panel {
            width = sz(4),
            flexShrink = 0,
            backgroundColor = isActive and CC.tabActiveBorder or { 90, 95, 110, 140 },
            visible = true,
        }
        tabBorders[i] = leftBorder

        local tabLabel = UI.Label {
            text = name,
            fontSize = sz(14), fontWeight = "bold",
            fontColor = isActive and CC.tabActiveText or CC.tabInactiveText,
            pointerEvents = "none",
        }
        tabLabels[i] = tabLabel

        local btn = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "stretch",
            borderRadius = sz(4),
            overflow = "hidden",
            backgroundColor = isActive and CC.tabActiveBg or CC.tabInactiveBg,
            cursor = "pointer",
            marginBottom = sz(4),
            onClick = function(self)
                Utils.PlayClick()
                switchTab(capturedI)
            end,
            children = {
                leftBorder,
                UI.Panel {
                    flexGrow = 1,
                    paddingVertical = sz(12),
                    paddingLeft = sz(12),
                    paddingRight = sz(10),
                    pointerEvents = "none",
                    children = { tabLabel },
                },
            },
        }
        tabButtons[i] = btn
        tabItems[i] = btn

        -- 初始可见性
        tabContents[i]:SetVisible(i == tabIndex)
    end

    -- 手动构建侧栏 children（避免 table.unpack 非末尾截断问题）
    local sidebarChildren = {}
    for _, item in ipairs(tabItems) do
        sidebarChildren[#sidebarChildren + 1] = item
    end
    sidebarChildren[#sidebarChildren + 1] = UI.Panel { flexGrow = 1 }
    sidebarChildren[#sidebarChildren + 1] = UI.Panel {
        width = "100%",
        paddingHorizontal = sz(8), paddingVertical = sz(9),
        children = {
            UI.Button {
                text = "返回",
                width = "100%",
                paddingVertical = sz(7),
                fontSize = sz(13),
                fontColor = CC.backBtnText,
                fontWeight = "bold",
                backgroundColor = CC.backBtnBg,
                hoverBackgroundColor = { 195, 215, 40, 50 },
                pressedBackgroundColor = { 195, 215, 40, 110 },
                borderWidth = 1,
                borderColor = CC.backBtnBorder,
                borderRadius = 0,
                onClick = function()
                    Utils.PlayClick()
                    popupVisible = false
                    if popupOverlay then popupOverlay:SetVisible(false) end
                end,
            },
        },
    }

    return UI.Panel {
        flex = 1, flexDirection = "row",
        children = {
            -- 左侧侧栏（PropScreen 风格：width=140，底部返回按钮）
            UI.Panel {
                width = sz(140),
                flexShrink = 0,
                flexDirection = "column",
                paddingTop = sz(4),
                paddingHorizontal = sz(8),
                children = sidebarChildren,
            },
            -- 右侧内容区（叠放，按可见性切换，留边距）
            UI.Panel {
                flex = 1, flexDirection = "row",
                padding = sz(12),
                children = {
                    UI.Panel {
                        flex = 1, flexDirection = "row",
                        backgroundColor = { 0, 0, 0, 0 },
                        borderRadius = sz(8),
                        overflow = "hidden",
                        children = tabContents,
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 公开 API
-- ============================================================================

---@return table
function TaskPanel.CreateButton()
    local nsz = Utils.sz
    popupVisible = false

    btnBadge = UI.Panel {
        position = "absolute", right = -3, top = -3,
        width = nsz(10), height = nsz(10),
        borderRadius = nsz(5),
        backgroundColor = { 255, 60, 60, 255 },
        visible = false, pointerEvents = "none",
    }

    UpdateBadge()

    return UI.Panel {
        paddingHorizontal = nsz(10), paddingVertical = nsz(4),
        flexDirection = "column", alignItems = "center",
        justifyContent = "center", gap = nsz(2),
        cursor = "pointer",
        backgroundColor = { 20, 24, 38, 180 },
        borderWidth = 1, borderColor = { 70, 85, 130, 160 },
        borderRadius = nsz(6),
        onClick = function(self)
            Utils.PlayClick()
            popupVisible = not popupVisible
            if popupOverlay then
                popupOverlay:SetVisible(popupVisible)
            end
        end,
        children = {
            UI.Panel {
                width = nsz(26), height = nsz(26),
                backgroundImage = "image/nav_task_20260516154023.png",
                backgroundFit = "contain",
                pointerEvents = "none",
                children = { btnBadge },
            },
            UI.Label {
                text = "任务",
                fontSize = nsz(11), fontColor = { 200, 205, 220, 200 },
                pointerEvents = "none",
            },
        },
    }
end

---@return table
function TaskPanel.CreatePopup()

    local innerContent = BuildPopupContent()

    popupOverlay = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        backgroundImage = "image/task_bg.jpg",
        backgroundFit = "cover",
        flexDirection = "column",
        visible = false,
        children = {
            -- 顶栏（PropScreen 风格：图标+标题在左，✕ 按钮在右）
            UI.Panel {
                width = "100%", height = sz(50),
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = sz(16),
                borderBottomWidth = 1, borderBottomColor = CC.headerDivider,
                children = {
                    -- 左侧：图标 + 分隔线 + 标题
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = sz(10),
                        pointerEvents = "none",
                        children = {
                            UI.Panel {
                                width = sz(26), height = sz(26),
                                backgroundImage = "image/nav_task_20260516154023.png",
                                backgroundFit = "contain",
                            },
                            UI.Panel {
                                width = 1, height = sz(20),
                                backgroundColor = { 180, 185, 200, 80 },
                            },
                            UI.Label {
                                text = "任务中心",
                                fontSize = sz(18), fontWeight = "bold",
                                fontColor = { 240, 235, 220, 255 },
                            },
                        },
                    },
                    UI.Panel { flexGrow = 1 },
                    -- 右侧：金币显示 + ✕ 关闭按钮
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = sz(10),
                        children = {
                            -- 金币余额
                            UI.Panel {
                                flexDirection = "row", alignItems = "center",
                                gap = sz(6),
                                paddingHorizontal = sz(10), paddingVertical = sz(5),
                                backgroundColor = { 0, 0, 0, 120 },
                                borderRadius = sz(14),
                                borderWidth = 1, borderColor = { 100, 80, 20, 150 },
                                pointerEvents = "none",
                                children = {
                                    UI.Panel {
                                        width = sz(20), height = sz(20),
                                        backgroundImage = Utils.GetIcon("coin"),
                                        backgroundFit = "contain",
                                        pointerEvents = "none",
                                    },
                                    UI.Label {
                                        text = Utils.FormatMoney(MoneyHUD.GetMoney()),
                                        fontSize = sz(14), fontWeight = "bold",
                                        fontColor = { 255, 215, 55, 255 },
                                        pointerEvents = "none",
                                    },
                                },
                            },
                            -- ✕ 关闭按钮
                            UI.Panel {
                                width = sz(34), height = sz(34),
                                borderRadius = sz(4),
                                backgroundColor = { 40, 42, 55, 200 },
                                borderWidth = 1, borderColor = { 70, 75, 90, 180 },
                                alignItems = "center", justifyContent = "center",
                                cursor = "pointer",
                                onClick = function()
                                    Utils.PlayClick()
                                    popupVisible = false
                                    if popupOverlay then popupOverlay:SetVisible(false) end
                                end,
                                children = {
                                    UI.Label {
                                        text = "✕",
                                        fontSize = sz(18), fontWeight = "bold",
                                        fontColor = { 180, 220, 0, 230 },
                                        pointerEvents = "none",
                                    },
                                },
                            },
                        },
                    },
                },
            },
            -- 主体内容
            innerContent,
        },
    }
    return popupOverlay
end

---刷新角标（在 SaveFramework 加载完毕后调用）
function TaskPanel.RefreshBadge()
    UpdateBadge()
end

return TaskPanel
