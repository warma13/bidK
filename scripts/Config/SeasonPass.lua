-- ============================================================================
-- Config/SeasonPass.lua - 赛季通行证配置
-- ============================================================================

local M = {}

-- ============================================================================
-- 赛季基础信息
-- ============================================================================

M.SEASON = {
    id           = "2026_s1",   -- 换赛季时修改此 id，云端数据自动重置
    name         = "竞拍之王·第一赛季",
    durationDays = 30,
    maxLevel     = 150,
    endDate      = "2026-06-30",  -- 赛季结束日期（YYYY-MM-DD），倒计时显示用
}

-- ============================================================================
-- XP 公式
-- XP = entryFee × A + coinsSpent × B + max(profit,0) × C
-- 目标：高价场打一局约得 500-2000 XP，每级需 1000 XP，30天150级需日均5000 XP
-- ============================================================================

M.XP = {
    entryFeeRate  = 0.001,   -- 入场费每1000金币 = 1 XP
    spentRate     = 0.0005,  -- 花费每2000金币   = 1 XP
    profitRate    = 0.002,   -- 盈利每500金币    = 1 XP（仅正利润计入）
    perLevelXP    = 1000,    -- 每级所需 XP
    -- 每周 XP 上限（含任务 XP + 对局 XP）
    -- 150级 = 150,000 XP，约4周完成，每周理想值 ~37,500
    -- 留 33% 冗余，上限设为 50,000/周；任务每日可得最多 ~2,500，每周 ~3,500
    weeklyGameXPCap  = 46500,  -- 对局来源每周上限（总上限 50,000 - 任务最大 3,500）
    weeklyTaskXPCap  = 3500,   -- 任务来源每周上限
    weeklyTotalXPCap = 50000,  -- 合并上限（双保险，取最小值）
}

-- ============================================================================
-- 广告解锁 VIP
-- 每看一个广告，按顺序解锁下一个 VIP 奖励（不影响通行证等级）
-- ============================================================================

M.ADS_PER_VIP         = 1   -- 1个广告解锁1个VIP奖励（固定，保持简单）
M.WEEKLY_VIP_LEVEL_CAP = 50  -- 每周最多解锁高级等级数（与免费每周上限对齐）

-- ============================================================================
-- 赛季限定藏品（注入到拍卖物品池）
-- ============================================================================

M.SEASON_ITEMS = {
    {
        id    = "season_2026s1_jade_seal",
        name  = "传国玉玺",
        rarity = "red",
        value  = 1888888,
        icon   = "Items/season_jade_seal.png",
        desc   = "第一赛季限定藏品，玉质温润，雕工精绝",
    },
    {
        id    = "season_2026s1_golden_tree",
        name  = "聚宝摇钱树",
        rarity = "red",
        value  = 888888,
        icon   = "Items/season_golden_tree.png",
        desc   = "第一赛季限定藏品，枝繁叶茂，金光闪闪",
    },
}

-- ============================================================================
-- 150 级奖励表
-- 每级结构：{ free={...}, vip={...} }
-- 奖励类型：
--   { type="coins",   amount=N }
--   { type="chest",   id="chest_common"|"chest_silver"|"chest_gold" }
--   { type="item",    itemId="..." }   -- 赛季限定藏品
--   { type="tickets", ticketId="...", count=N }
-- ============================================================================

local function coins(n)      return { type = "coins",   amount = n * 5 } end
local function chest(id, n)      return { type = "chest",   id = id, count = (n or 1) * 5 } end
local function freeChest(id, n)  return { type = "chest",   id = id, count = (n or 1) } end
local function item(id)      return { type = "item",    itemId = id } end
local function ticket(id, n) return { type = "tickets", ticketId = id, count = n * 5 } end

-- ============================================================================
-- 奖励节奏设计（150级总览）
-- ● 每级基底     免费 1万  VIP 5万
-- ● 每5级        VIP 额外：仓库指定券×1（7种区域轮转）
-- ● 每10级       免费额外：礼盒×1；  VIP额外：道具箱×1（品质随进度提升）
-- ● 大里程碑     30/60/90/120/150：双轨强化；90/150含赛季限定藏品
-- ============================================================================

-- 指定券按区域顺序轮转（共7种）
local TICKET_ROTATION = {
    "ticket_suburb", "ticket_commercial", "ticket_industrial",
    "ticket_port",   "ticket_culture",    "ticket_techpark",
    "ticket_deepsea",
}

-- 道具箱品质随等级提升（白→绿→蓝→紫）
local function PropChestByLevel(lvl)
    if lvl <= 40  then return chest("chest_common")  end   -- 白色
    if lvl <= 80  then return chest("chest_silver")  end   -- 绿/蓝
    if lvl <= 120 then return chest("chest_gold")    end   -- 紫
    return chest("chest_gold")
end

-- 构造 150 级奖励
local function BuildTiers()
    local t = {}

    -- 大里程碑集中定义（覆盖通用逻辑）
    local MILESTONES = {
        [30]  = {
            free = { coins(10000), freeChest("chest_s1") },
            vip  = { coins(50000), chest("chest_common"), ticket("ticket_commercial", 1) },
        },
        [60]  = {
            free = { coins(10000), freeChest("chest_s1") },
            vip  = { coins(50000), chest("chest_silver"), ticket("ticket_port", 1) },
        },
        [90]  = {
            free = { coins(10000), freeChest("chest_s1"), item("season_2026s1_golden_tree") },
            vip  = { coins(50000), chest("chest_gold"),  ticket("ticket_techpark", 1) },
        },
        [120] = {
            free = { coins(10000), freeChest("chest_s1") },
            vip  = { coins(50000), chest("chest_gold"),  ticket("ticket_deepsea", 1) },
        },
        [150] = {
            free = { coins(10000), freeChest("chest_s1"), item("season_2026s1_jade_seal") },
            vip  = { coins(50000), chest("chest_gold"),  ticket("ticket_private", 1) },
        },
    }

    -- 通用逻辑：逐级生成
    local ticketSlot = 0   -- 指定券轮转指针

    for lvl = 1, 150 do
        if MILESTONES[lvl] then
            -- 大里程碑直接使用预设
            t[lvl] = { free = MILESTONES[lvl].free, vip = MILESTONES[lvl].vip }
        elseif lvl % 10 == 0 then
            -- 每10级：免费+礼盒，VIP+道具箱
            t[lvl] = {
                free = { coins(10000), freeChest("chest_s1") },
                vip  = { coins(50000), PropChestByLevel(lvl) },
            }
        elseif lvl % 5 == 0 then
            -- 每5级：VIP 加指定券（轮转）
            ticketSlot = (ticketSlot % #TICKET_ROTATION) + 1
            local tid = TICKET_ROTATION[ticketSlot]
            t[lvl] = {
                free = { coins(10000) },
                vip  = { coins(50000), ticket(tid, 1) },
            }
        else
            -- 普通级：仅金币
            t[lvl] = {
                free = { coins(10000) },
                vip  = { coins(50000) },
            }
        end
    end

    return t
end

M.TIERS = BuildTiers()

-- ============================================================================
-- 预计算每级 VIP 奖励的全局序号（供解锁判断使用）
-- vipIndex[lvl][pos] = globalIdx
-- globalVipTotal = 所有 VIP 奖励总数
-- ============================================================================

local vipIndex = {}
local globalVipTotal = 0

for lvl = 1, M.SEASON.maxLevel do
    vipIndex[lvl] = {}
    local vips = M.TIERS[lvl].vip
    for pos = 1, #vips do
        globalVipTotal = globalVipTotal + 1
        vipIndex[lvl][pos] = globalVipTotal
    end
end

M.VIP_INDEX       = vipIndex        -- [lvl][pos] -> globalIdx
M.GLOBAL_VIP_TOTAL = globalVipTotal  -- 看满所有广告需要的总数

return M
