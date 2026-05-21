-- ============================================================================
-- SeasonPass.lua - 赛季通行证核心模块
-- ============================================================================
-- 职责：
--   - 管理通行证等级（XP 累积）
--   - 管理高级奖励解锁（观看广告，每周上限 WEEKLY_VIP_LEVEL_CAP 级）
--   - 奖励领取与发放
--   - 注册到 SaveFramework 做云端持久化
--
-- XP 来源：每局结束调用 SeasonPass.AddGameXP(entryFee, spent, profit)
-- 高级解锁：AdTracker hook，每看一次广告 vipUnlocked+1，每周上限 50 级
-- ============================================================================

---@diagnostic disable: undefined-global

local cjson        = require("cjson")
local Config       = require("Config.SeasonPass")
local SaveFW       = require("SaveFramework")
local AdTracker    = require("AdTracker")
local MoneyManager = require("MoneyManager")

local SeasonPass = {}

-- Panel 刷新回调（由 UI.SeasonPassPanel 在加载时注入，避免循环依赖）
local Panel = {}
function SeasonPass.SetPanelCallbacks(callbacks) Panel = callbacks end

-- ============================================================================
-- 云端键名
-- ============================================================================

local KEY_SEASON_ID    = "sp_season_id"    -- 当前赛季 ID（检测换赛季）
local KEY_XP           = "sp_xp"           -- 累计 XP
local KEY_VIP_COUNT    = "sp_vip_count"    -- 累计已解锁 VIP 奖励数
local KEY_WEEK_VIP     = "sp_week_vip"     -- 本周已解锁 VIP 奖励数
local KEY_CLAIMED_FREE = "sp_claimed_free" -- 已领免费奖励位掩码（JSON 数组存 bit 块）
local KEY_CLAIMED_VIP  = "sp_claimed_vip"  -- 已领 VIP 奖励位掩码
-- 每周 XP 追踪
local KEY_WEEK_NO      = "sp_week_no"      -- 当前周号（"YYYY-VV"）
local KEY_WEEK_GAME_XP = "sp_week_game_xp" -- 本周对局来源 XP
local KEY_WEEK_TASK_XP = "sp_week_task_xp" -- 本周任务来源 XP

local MODULE_NAME = "season_pass"

-- ============================================================================
-- 内部状态
-- ============================================================================

local initialized   = false
local currentXP     = 0       -- 本赛季累计 XP
local vipUnlocked   = 0       -- 累计已解锁 VIP 奖励数
local claimedFree   = {}      -- [globalFreeIdx] = true
local claimedVip    = {}      -- [globalVipIdx]  = true
-- 每周追踪
local weekNo        = ""      -- 本周周号 "YYYY-VV"
local weekGameXP    = 0       -- 本周对局来源 XP（受 weeklyGameXPCap 限制）
local weekTaskXP    = 0       -- 本周任务来源 XP（受 weeklyTaskXPCap 限制）
local weekVipCount  = 0       -- 本周已解锁 VIP 奖励数（受每周高级等级上限限制）

local C     = Config
local TIERS = C.TIERS
local XPC   = C.XP
local MAX_LEVEL = C.SEASON.maxLevel

-- ============================================================================
-- 工具
-- ============================================================================

--- 根据 XP 计算当前等级（1-based，最大 MAX_LEVEL）
local function CalcLevel(xp)
    local lvl = math.floor(xp / XPC.perLevelXP) + 1
    return math.min(lvl, MAX_LEVEL)
end



--- 当前等级
function SeasonPass.GetLevel()
    return CalcLevel(currentXP)
end

--- 当前 XP
function SeasonPass.GetXP()
    return currentXP
end

--- 调试用：直接增加 XP（不走 entryFee 公式）
---@param amount integer
function SeasonPass.DebugAddXP(amount)
    if not initialized then return end
    local prev = CalcLevel(currentXP)
    currentXP = math.max(0, currentXP + amount)
    local now  = CalcLevel(currentXP)
    SaveFW.MarkDirty(MODULE_NAME)
    print(string.format("[SeasonPass][Debug] +%d XP → %d，等级 %d→%d", amount, currentXP, prev, now))
    if Panel.IsOpen and Panel.IsOpen() then Panel.Refresh() end
end

--- 当前等级内进度 [0,1)
function SeasonPass.GetLevelProgress()
    if CalcLevel(currentXP) >= MAX_LEVEL then return 1.0 end
    local xpInLevel = currentXP % XPC.perLevelXP
    return xpInLevel / XPC.perLevelXP
end

--- 已解锁 VIP 奖励数
function SeasonPass.GetVipUnlocked()
    return vipUnlocked
end

--- 返回已完整解锁所有高级奖励的最高等级（0 表示尚未解锁任何等级）
function SeasonPass.GetHighLevel()
    local maxLvl = C.SEASON.maxLevel
    local high = 0
    for lvl = 1, maxLvl do
        local tier = C.TIERS[lvl]
        if not tier or not tier.vip or #tier.vip == 0 then break end
        local lastIdx = C.VIP_INDEX[lvl] and C.VIP_INDEX[lvl][#tier.vip]
        if lastIdx and vipUnlocked >= lastIdx then
            high = lvl
        else
            break
        end
    end
    return high
end

--- 本周已解锁高级等级数 / 每周上限（供 UI 展示）
function SeasonPass.GetWeeklyVipProgress()
    local rewardsPerLevel = 2  -- 每级约 2 个 VIP 奖励
    local cap = (C.WEEKLY_VIP_LEVEL_CAP or 50) * rewardsPerLevel
    local levelsDone = math.floor(weekVipCount / rewardsPerLevel)
    local levelsCap  = C.WEEKLY_VIP_LEVEL_CAP or 50
    return levelsDone, levelsCap, weekVipCount, cap
end

--- 某一级的免费奖励是否已领取（freeIdx = 该级在全局免费奖励序号）
--- 简化：用等级直接做索引（每级只有一组免费奖励）
function SeasonPass.IsFreeClaimedAt(lvl)
    return claimedFree[lvl] == true
end

--- 全局 VIP 序号 idx 是否已领取
function SeasonPass.IsVipClaimed(globalIdx)
    return claimedVip[globalIdx] == true
end

--- 某级 pos 位置的 VIP 奖励是否已解锁
function SeasonPass.IsVipUnlocked(lvl, pos)
    local gIdx = C.VIP_INDEX[lvl] and C.VIP_INDEX[lvl][pos]
    if not gIdx then return false end
    return vipUnlocked >= gIdx
end

-- ============================================================================
-- 奖励发放
-- ============================================================================

-- silent=true 时跳过金币保存（批量领取时由调用方统一发放）
local function GrantReward(reward, silent)
    if reward.type == "coins" then
        if not silent then
            MoneyManager.AddMoneyFromMenu(reward.amount, "season_pass")
        end
        return true, reward.amount .. " 金币"
    elseif reward.type == "chest" then
        -- 宝箱：发放实际礼盒道具到背包
        -- chest id 映射：统一映射到 Props 中定义的礼盒 id
        local CHEST_MAP = {
            chest_s1     = "chest_s1",
            chest_common = "chest_s1",
            chest_silver = "chest_s1",
            chest_gold   = "chest_s1",
        }
        local propId = CHEST_MAP[reward.id] or "chest_s1"
        local SaveSystem = require("SaveSystem")
        SaveSystem.AddProp(propId, 1)
        SaveFW.MarkDirty(MODULE_NAME)
        return true, "礼盒×1"
    elseif reward.type == "item" then
        -- 赛季限定藏品：加入仓库
        local SaveSystem = require("SaveSystem")
        local itemDef = nil
        for _, si in ipairs(C.SEASON_ITEMS) do
            if si.id == reward.itemId then itemDef = si break end
        end
        if not itemDef then return false, "未知藏品" end
        local ok = pcall(function()
            SaveSystem.AddWonItems({ {
                name   = itemDef.name,
                rarity = itemDef.rarity,
                value  = itemDef.value,
                icon   = itemDef.icon,
                source = "season_pass",
            } })
        end)
        return ok, itemDef.name
    elseif reward.type == "tickets" then
        local SaveSystem = require("SaveSystem")
        pcall(function()
            SaveSystem.AddTickets(reward.ticketId, reward.count, true)
        end)
        return true, reward.ticketId .. "×" .. reward.count
    end
    return false, "未知奖励类型"
end

-- ============================================================================
-- 领取奖励
-- ============================================================================

--- 领取某级的免费奖励
---@param lvl integer
---@return boolean success
---@return string message
function SeasonPass.ClaimFree(lvl)
    if not initialized then return false, "未初始化" end
    if lvl > CalcLevel(currentXP) then return false, "等级未到达" end
    if claimedFree[lvl] then return false, "已领取" end
    if not TIERS[lvl] or #TIERS[lvl].free == 0 then return false, "无免费奖励" end

    local msgs = {}
    for _, reward in ipairs(TIERS[lvl].free) do
        local ok, msg = GrantReward(reward, true)
        if ok then msgs[#msgs+1] = msg end
    end

    claimedFree[lvl] = true
    SaveFW.MarkDirty(MODULE_NAME)
    return true, table.concat(msgs, "、")
end

--- 领取某级 pos 位置的 VIP 奖励
---@param lvl integer
---@param pos integer
---@return boolean success
---@return string message
function SeasonPass.ClaimVip(lvl, pos)
    if not initialized then return false, "未初始化" end
    if lvl > CalcLevel(currentXP) then return false, "等级未到达" end

    local gIdx = C.VIP_INDEX[lvl] and C.VIP_INDEX[lvl][pos]
    if not gIdx then return false, "无效奖励" end
    if vipUnlocked < gIdx then return false, "需要观看更多广告解锁" end
    if claimedVip[gIdx] then return false, "已领取" end
    if not TIERS[lvl] or not TIERS[lvl].vip[pos] then return false, "奖励不存在" end

    local ok, msg = GrantReward(TIERS[lvl].vip[pos], true)
    if not ok then return false, msg end

    claimedVip[gIdx] = true
    SaveFW.MarkDirty(MODULE_NAME)
    return true, msg
end

-- ============================================================================
-- XP 增加（每局结束调用）
-- ============================================================================

--- 每周重置检查（内部辅助，在任意 XP 增加前调用）
local function CheckWeekReset()
    local thisWeek = os.date("%Y-%V")
    if weekNo ~= thisWeek then
        print(string.format("[SeasonPass] 新周 %s，重置每周计数（原 game=%d task=%d vip=%d）",
            thisWeek, weekGameXP, weekTaskXP, weekVipCount))
        weekNo       = thisWeek
        weekGameXP   = 0
        weekTaskXP   = 0
        weekVipCount = 0
        SaveFW.MarkDirty(MODULE_NAME)
    end
end

---@param entryFee integer  入场费
---@param spent    integer  花费金币（竞拍出价）
---@param profit   integer  利润（可为负）
function SeasonPass.AddGameXP(entryFee, spent, profit)
    if not initialized then return end
    CheckWeekReset()

    local xp = math.floor(
        (entryFee or 0)       * XPC.entryFeeRate +
        (spent    or 0)       * XPC.spentRate    +
        math.max(profit or 0, 0) * XPC.profitRate
    )
    xp = math.max(xp, 10)   -- 最低保底 10 XP，防止低价场一分没有

    -- 对局来源每周上限检查
    local weekTotal = weekGameXP + weekTaskXP
    local gameCap   = XPC.weeklyGameXPCap  or 46500
    local totalCap  = XPC.weeklyTotalXPCap or 50000
    local canGame   = math.max(0, math.min(gameCap - weekGameXP, totalCap - weekTotal))
    if canGame <= 0 then
        print(string.format("[SeasonPass] 本周对局 XP 已达上限（%d/%d），跳过",
            weekGameXP, gameCap))
        return
    end
    xp = math.min(xp, canGame)

    weekGameXP = weekGameXP + xp
    local prevLevel = CalcLevel(currentXP)
    currentXP = currentXP + xp
    local newLevel = CalcLevel(currentXP)
    print(string.format("[SeasonPass] +%d XP（对局）→ 共 %d XP，等级 %d→%d，本周对局XP=%d/%d",
        xp, currentXP, prevLevel, newLevel, weekGameXP, gameCap))
    SaveFW.MarkDirty(MODULE_NAME)

    -- 通知 UI 刷新（如果面板已打开）
    if Panel.IsOpen and Panel.IsOpen() then Panel.Refresh() end
end

--- 任务完成奖励 XP（每日/每周任务领取时调用）
---@param amount integer  XP 数量
---@param source string   来源描述（用于日志）
function SeasonPass.AddTaskXP(amount, source)
    if not initialized then return end
    if not amount or amount <= 0 then return end
    CheckWeekReset()

    local weekTotal = weekGameXP + weekTaskXP
    local taskCap   = XPC.weeklyTaskXPCap  or 3500
    local totalCap  = XPC.weeklyTotalXPCap or 50000
    local canTask   = math.max(0, math.min(taskCap - weekTaskXP, totalCap - weekTotal))
    if canTask <= 0 then
        print(string.format("[SeasonPass] 本周任务 XP 已达上限（%d/%d），跳过 %s",
            weekTaskXP, taskCap, source or ""))
        return
    end
    local actual = math.min(amount, canTask)

    weekTaskXP = weekTaskXP + actual
    local prevLevel = CalcLevel(currentXP)
    currentXP = currentXP + actual
    local newLevel = CalcLevel(currentXP)
    print(string.format("[SeasonPass] +%d XP（任务:%s）→ 共 %d XP，等级 %d→%d，本周任务XP=%d/%d",
        actual, source or "", currentXP, prevLevel, newLevel, weekTaskXP, taskCap))
    SaveFW.MarkDirty(MODULE_NAME)

    if Panel.IsOpen and Panel.IsOpen() then Panel.Refresh() end
end

--- 获取本周 XP 进度（供 UI 展示）
---@return integer weekGameXP, integer weekTaskXP, integer weeklyGameXPCap, integer weeklyTaskXPCap
function SeasonPass.GetWeeklyXPProgress()
    return weekGameXP, weekTaskXP,
           XPC.weeklyGameXPCap or 46500,
           XPC.weeklyTaskXPCap or 3500
end

-- ============================================================================
-- 广告 Hook（每看一个广告解锁下一个 VIP 奖励，每周上限 WEEKLY_VIP_LEVEL_CAP 级）
-- ============================================================================

local function OnAdWatched(todayCount, totalCount)
    if not initialized then return end
    CheckWeekReset()

    -- 每周高级等级上限检查（每级约含 2 个 VIP 奖励）
    local rewardsPerLevel = 2
    local weekCap = (C.WEEKLY_VIP_LEVEL_CAP or 50) * rewardsPerLevel
    if weekVipCount >= weekCap then
        print(string.format("[SeasonPass] 本周高级解锁已达上限（%d级/%d级），跳过",
            math.floor(weekVipCount / rewardsPerLevel), C.WEEKLY_VIP_LEVEL_CAP or 50))
        return
    end

    if vipUnlocked >= C.GLOBAL_VIP_TOTAL then return end  -- 全赛季已全解锁
    vipUnlocked  = vipUnlocked  + 1
    weekVipCount = weekVipCount + 1
    print(string.format("[SeasonPass] VIP解锁 → %d/%d，本周 %d/%d 个奖励（%d/%d 级）",
        vipUnlocked, C.GLOBAL_VIP_TOTAL,
        weekVipCount, weekCap,
        math.floor(weekVipCount / rewardsPerLevel), C.WEEKLY_VIP_LEVEL_CAP or 50))
    -- 广告成功后立即保存（防止广告后崩溃导致解锁丢失）
    SaveFW.SaveNow(MODULE_NAME)

    if Panel.IsOpen and Panel.IsOpen() then Panel.Refresh() end
end

-- ============================================================================
-- SaveFramework 注册
-- ============================================================================

-- 序列化 claimed 表 → JSON 字符串 "[1,3,5]"
-- 用 cjson 显式编码为字符串，云端原样存储，避免自动 JSON 处理把数字 key 变成字符串
local function SerializeClaimed(t)
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end
    table.sort(keys)
    return cjson.encode(keys)  -- 存为字符串 "[1,3,5]"，云端不做任何额外处理
end

-- 反序列化：从字符串 "[1,3,5]" 解析回 {[1]=true, [3]=true, [5]=true}
local function DeserializeClaimed(str)
    local t = {}
    if not str or str == "" then return t end
    if type(str) == "string" then
        -- 尝试 cjson 解码（新格式 "[1,3,5]"）
        local ok, decoded = pcall(cjson.decode, str)
        if ok and type(decoded) == "table" then
            for _, n in ipairs(decoded) do
                local k = math.floor(tonumber(n) or 0)
                if k > 0 then t[k] = true end
            end
            return t
        end
        -- 兼容旧格式 "1,3,5"（逗号分隔字符串）
        for s in str:gmatch("[^,]+") do
            local n = tonumber(s)
            if n then t[math.floor(n)] = true end
        end
    elseif type(str) == "table" then
        -- 兼容极少数情况下云端返回 table
        for _, n in ipairs(str) do
            local k = math.floor(tonumber(n) or 0)
            if k > 0 then t[k] = true end
        end
    end
    return t
end

SaveFW.Register(MODULE_NAME, {
    cloudKeys = {
        KEY_SEASON_ID,
        KEY_XP,
        KEY_VIP_COUNT,
        KEY_WEEK_VIP,
        KEY_CLAIMED_FREE,
        KEY_CLAIMED_VIP,
        KEY_WEEK_NO,
        KEY_WEEK_GAME_XP,
        KEY_WEEK_TASK_XP,
    },

    load = function(data)
        local savedSeasonId = data[KEY_SEASON_ID] or ""
        if savedSeasonId ~= C.SEASON.id then
            -- 换赛季，重置所有数据
            print("[SeasonPass] 新赛季 " .. C.SEASON.id .. "，重置通行证数据")
            currentXP    = 0
            vipUnlocked  = 0
            claimedFree  = {}
            claimedVip   = {}
            weekNo       = os.date("%Y-%V")
            weekGameXP   = 0
            weekTaskXP   = 0
            weekVipCount = 0
        else
            currentXP   = tonumber(data[KEY_XP])        or 0
            vipUnlocked = tonumber(data[KEY_VIP_COUNT])  or 0
            claimedFree = DeserializeClaimed(data[KEY_CLAIMED_FREE])
            claimedVip  = DeserializeClaimed(data[KEY_CLAIMED_VIP])
            -- 每周计数：若周号不同则自动清零
            local savedWeek = data[KEY_WEEK_NO] or ""
            local thisWeek  = os.date("%Y-%V")
            if savedWeek ~= thisWeek then
                weekNo       = thisWeek
                weekGameXP   = 0
                weekTaskXP   = 0
                weekVipCount = 0
            else
                weekNo       = savedWeek
                weekGameXP   = tonumber(data[KEY_WEEK_GAME_XP]) or 0
                weekTaskXP   = tonumber(data[KEY_WEEK_TASK_XP]) or 0
                weekVipCount = tonumber(data[KEY_WEEK_VIP])     or 0
            end
        end
        print(string.format("[SeasonPass] 加载完成：等级%d XP=%d VIP=%d 本周gameXP=%d taskXP=%d vip=%d",
            CalcLevel(currentXP), currentXP, vipUnlocked, weekGameXP, weekTaskXP, weekVipCount))
    end,

    save = function(batch)
        batch:Set(KEY_SEASON_ID,    C.SEASON.id)
        batch:Set(KEY_XP,           tostring(currentXP))
        batch:Set(KEY_VIP_COUNT,    tostring(vipUnlocked))
        batch:Set(KEY_WEEK_VIP,     tostring(weekVipCount))
        batch:Set(KEY_CLAIMED_FREE, SerializeClaimed(claimedFree))
        batch:Set(KEY_CLAIMED_VIP,  SerializeClaimed(claimedVip))
        batch:Set(KEY_WEEK_NO,      weekNo)
        batch:Set(KEY_WEEK_GAME_XP, tostring(weekGameXP))
        batch:Set(KEY_WEEK_TASK_XP, tostring(weekTaskXP))
    end,

    defaults = function()
        currentXP    = 0
        vipUnlocked  = 0
        claimedFree  = {}
        claimedVip   = {}
        weekVipCount = 0
        weekNo      = os.date("%Y-%V")
        weekGameXP  = 0
        weekTaskXP  = 0
    end,
})

-- ============================================================================
-- 初始化
-- ============================================================================

function SeasonPass.Init()
    if initialized then return end
    initialized = true
    AdTracker.RegisterHook("season_pass", OnAdWatched)
    print("[SeasonPass] 初始化完成，赛季=" .. C.SEASON.name)
end

function SeasonPass.IsReady()
    return initialized
end

return SeasonPass
