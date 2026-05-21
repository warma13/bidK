-- ============================================================================
-- SaveCompensation.lua - 一次性补偿模块
-- 检测已领取的在线里程碑 + 广告里程碑，对照实际门票/角色币数量，补足差额
-- 每个用户只运行一次（以 comp_done 云端 key 防重）
-- ============================================================================

---@diagnostic disable: undefined-global

local SaveCompensation = {}

local KEY_COMP_DONE    = "comp_done"     -- 是否已补偿过（"1" = 已完成）
local KEY_COMP_LOG     = "comp_log"      -- 补偿记录（字符串，供调试）

local ran = false  -- 防止同一次启动重复执行

-- ============================================================================
-- 内部工具
-- ============================================================================

-- 与 Utils.TodayStr() 保持相同格式；此模块不依赖 UI 层，故本地定义
local function TodayStr()
    return os.date("%Y-%m-%d")
end

-- 统计某 bits 掩码中，各 ticket 类型应发放的总数
-- milestones: Config 里的 milestone 数组（每项可含 .ticket 字段）
-- bits: 已领取位掩码
local function CountExpectedTickets(milestones, bits)
    local expected = {}  -- { ticketId -> count }
    for i, ms in ipairs(milestones) do
        local bit = 1 << (i - 1)
        if (bits & bit) ~= 0 and ms.ticket then
            expected[ms.ticket] = (expected[ms.ticket] or 0) + (ms.ticketCount or 1)
        end
    end
    return expected
end

-- 合并两张 expected 表（在线 + 广告）
local function MergeExpected(a, b)
    local result = {}
    for k, v in pairs(a) do result[k] = (result[k] or 0) + v end
    for k, v in pairs(b) do result[k] = (result[k] or 0) + v end
    return result
end

-- ============================================================================
-- 补偿执行
-- ============================================================================

local function DoCompensate(onlineBits, adBits, dailyCount)
    local Config      = require("Config")
    local SaveSystem  = require("SaveSystem")
    local OC = Config.ONLINE_REWARD or require("Config.Rewards").ONLINE_REWARD
    local AC = Config.AD_CARD       or require("Config.Rewards").AD_CARD

    local log = {}

    -- ---- 1. 门票补偿 ----
    local expectedOnline = CountExpectedTickets(OC.MILESTONES,       onlineBits)
    local expectedAd     = CountExpectedTickets(AC.DAILY_MILESTONES, adBits)
    local expectedAll    = MergeExpected(expectedOnline, expectedAd)

    for ticketId, expectedCount in pairs(expectedAll) do
        local actual = SaveSystem.GetTicketCount(ticketId)
        if actual < expectedCount then
            local diff = expectedCount - actual
            SaveSystem.AddTickets(ticketId, diff)
            local msg = "门票补偿 " .. ticketId .. " +" .. diff
                     .. " (实际" .. actual .. " 应有" .. expectedCount .. ")"
            table.insert(log, msg)
            print("[SaveCompensation] " .. msg)
        else
            print("[SaveCompensation] 门票 " .. ticketId
                  .. " 无需补偿 (actual=" .. actual .. " expected=" .. expectedCount .. ")")
        end
    end

    -- ---- 2. 点券补偿（今日看广告次数 × 10 = 应得点券数）----
    -- 点券是累计值，只补偿"今日应得但未到账"的部分
    if dailyCount > 0 then
        local expectedTickets = dailyCount * 10
        local actualTickets   = SaveSystem.GetPointTickets()
        if actualTickets < expectedTickets then
            local diff = expectedTickets - actualTickets
            SaveSystem.AddPointTickets(diff)
            local msg = "点券补偿 +" .. diff
                     .. " (实际" .. actualTickets .. " 今日应得" .. expectedTickets .. ")"
            table.insert(log, msg)
            print("[SaveCompensation] " .. msg)
        else
            print("[SaveCompensation] 点券无需补偿 (actual="
                  .. SaveSystem.GetPointTickets() .. " expected=" .. expectedTickets .. ")")
        end
    end

    -- ---- 3. 写入补偿记录（标记为已完成，永不再运行） ----
    local logStr  = #log > 0 and table.concat(log, "; ") or "无需补偿"

    if clientCloud then
        local batch = clientCloud:BatchSet()
        batch:Set(KEY_COMP_DONE, "1")
        batch:Set(KEY_COMP_LOG,  logStr)
        batch:Save("comp", {
            ok    = function() print("[SaveCompensation] 补偿记录已写入云端: " .. logStr) end,
            error = function(_, reason) print("[SaveCompensation] 补偿记录写入失败: " .. tostring(reason)) end,
        })
    end

    print("[SaveCompensation] 完成: " .. logStr)
end

-- ============================================================================
-- 入口：SaveFramework Init 完成后调用
-- ============================================================================

function SaveCompensation.RunOnce()
    if ran then return end
    ran = true

    if not clientCloud then
        print("[SaveCompensation] 无 clientCloud，跳过")
        return
    end

    -- 读取云端 comp_done，判断是否已补偿过
    local today = TodayStr()
    local batch = clientCloud:BatchGet()
    batch:Key(KEY_COMP_DONE)
    batch:Fetch({
        ok = function(values, _)
            local done = values[KEY_COMP_DONE] or ""
            if done == "1" then
                print("[SaveCompensation] 该用户已补偿过，跳过")
                return
            end

            -- 读取当前数据（SaveFramework 已完成 Init，各模块数据已就绪）
            local ok1, AdCardPanel       = pcall(require, "UI.AdCardPanel")
            local ok2, OnlineRewardPanel = pcall(require, "UI.OnlineRewardPanel")
            if not ok1 or not ok2 then
                print("[SaveCompensation] 模块加载失败，跳过")
                return
            end

            local adDate     = AdCardPanel.GetDailyDate()
            local onlineDate = OnlineRewardPanel.GetOnlineDate()

            -- 仅对今天的数据补偿（若模块日期不是今天，说明数据已重置，不需要补偿）
            local adBits     = (adDate     == today) and AdCardPanel.GetMilestoneBits()      or 0
            local onlineBits = (onlineDate == today) and OnlineRewardPanel.GetClaimedBits()  or 0
            local dailyCount = (adDate     == today) and AdCardPanel.GetDailyCount()         or 0

            print("[SaveCompensation] 开始检查 date=" .. today
                  .. " adBits=" .. adBits .. " onlineBits=" .. onlineBits
                  .. " dailyCount=" .. dailyCount)

            DoCompensate(onlineBits, adBits, dailyCount)
        end,
        error = function(_, reason)
            print("[SaveCompensation] 读取 comp_date 失败: " .. tostring(reason) .. "，跳过")
        end,
    })
end

return SaveCompensation
