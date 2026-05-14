-- ============================================================================
-- Config.lua - 拍卖之王 游戏配置聚合入口
-- ============================================================================
-- 本文件仅保留核心常量与工具函数，业务配置已拆分至子模块：
--   Config/Characters.lua  — 角色数据、AI 名字库
--   Config/Items.lua       — 藏品类别、物品池、仓库尺寸分组
--   Config/World.lua       — 世界地图、区域、仓库类型
--   Config/Rewards.lua     — 广告卡、在线时长奖励
-- ============================================================================

local Config = {}

-- ============================================================================
-- 游戏基础配置
-- ============================================================================

Config.GAME = {
    Title = "拍卖之王",
    Version = "1.1.18",
    MaxPlayers = 4,
    WarehouseColumns = 30,      -- 玩家仓库格子列数
    WarehouseMaxRows = 21,      -- 玩家仓库格子最大行数（满级 5+4*4=21）
    WarehouseDisplayRows = 5,   -- 玩家仓库初始行数
    LootColumns = 10,           -- 战利品仓库列数
    LootMaxRows = 20,           -- 战利品仓库行数
    StartingMoney = 800000,
    MaxRounds = 5,              -- 最多5轮暗标
    SealedBidSeconds = 30,      -- 暗标出价时间（第2轮起）
    FirstRoundSeconds = 60,     -- 第1轮出价时间
    TiebreakSeconds = 8,        -- 实时竞拍时间
    TiebreakExtend = 8,         -- 实时竞拍有人出价后重置秒数
    MinBidIncrement = 100,      -- 实时竞拍最小加价（绝对下限）
    TiebreakBidPercents = { 0.01, 0.05, 0.10 },
    -- 每轮倍率门槛（最高价 / 第二名 >= 此倍率则胜出，第5轮严格大于）
    Multipliers = { 2.0, 1.6, 1.4, 1.2 },
}

-- ============================================================================
-- 稀有度
-- ============================================================================

Config.RARITY = {
    { id = "white",  name = "白色", color = { 180, 180, 180, 255 } },
    { id = "green",  name = "绿色", color = { 30,  200, 80,  255 } },
    { id = "blue",   name = "蓝色", color = { 50,  130, 255, 255 } },
    { id = "purple", name = "紫色", color = { 180, 70,  255, 255 } },
    { id = "gold",   name = "金色", color = { 255, 180, 0,   255 } },
    { id = "red",    name = "红色", color = { 255, 50,  50,  255 } },
}

-- ============================================================================
-- 门票 / 角色币
-- ============================================================================

Config.CHARACTER_COIN_ICON = "Textures/tickets/character_coin.png"

Config.TICKETS = {
    port_1000w = {
        name = "1000万场门票",
        icon = "Textures/tickets/port_ticket_1000w.png",
    },
    port_5000w = {
        name = "5000万场门票",
        icon = "Textures/tickets/port_ticket_5000w.png",
    },

    -- 七大区域仓库指定门票
    ticket_suburb = {
        name = "城郊仓库指定券",
        icon = "Textures/tickets/ticket_suburb.png",
    },
    ticket_industrial = {
        name = "工业仓库指定券",
        icon = "Textures/tickets/ticket_industrial.png",
    },
    ticket_commercial = {
        name = "商业仓库指定券",
        icon = "Textures/tickets/ticket_commercial.png",
    },
    ticket_port = {
        name = "港口仓库指定券",
        icon = "Textures/tickets/ticket_port.png",
    },
    ticket_techpark = {
        name = "科技仓库指定券",
        icon = "Textures/tickets/ticket_techpark.png",
    },
    ticket_culture = {
        name = "文化仓库指定券",
        icon = "Textures/tickets/ticket_culture.png",
    },
    ticket_deepsea = {
        name = "深海仓库指定券",
        icon = "Textures/tickets/ticket_deepsea.png",
    },
    ticket_private = {
        name = "顶级私产指定券",
        icon = "Textures/tickets/ticket_private.png",
    },
}

-- ============================================================================
-- UI 颜色主题
-- ============================================================================

Config.COLORS = {
    bgDark          = { 20,  22,  30,  255 },
    bgPanel         = { 30,  35,  50,  230 },
    bgPanelLight    = { 40,  48,  68,  200 },
    bgOverlay       = { 15,  18,  28,  200 },
    textPrimary     = { 220, 225, 240, 255 },
    textSecondary   = { 180, 190, 210, 255 },
    textMuted       = { 145, 155, 180, 230 },
    accent          = { 255, 210, 0,   255 },
    accentDim       = { 200, 165, 0,   200 },
    danger          = { 220, 60,  60,  255 },
    success         = { 40,  200, 100, 255 },
    bidButton       = { 240, 220, 0,   255 },
    bidButtonText   = { 20,  20,  20,  255 },
    playerHighlight = { 0,   180, 160, 255 },
    playerBadge = {
        { 0,   200, 120, 255 },  -- 1号 绿色
        { 0,   160, 220, 255 },  -- 2号 蓝色
        { 200, 80,  200, 255 },  -- 3号 紫色
        { 0,   180, 160, 255 },  -- 4号 青色
    },
    gridSlotBg      = { 45,  50,  70,  180 },
    gridSlotBorder  = { 70,  80,  110, 150 },
    roundBanner     = { 60,  70,  95,  240 },
    infoNew         = { 100, 200, 255, 255 },  -- 新揭露信息高亮
    infoSkill       = { 200, 150, 255, 255 },  -- 私密线索颜色
    sealed          = { 80,  90,  120, 255 },  -- 暗标/隐藏状态
}

-- ============================================================================
-- 加载子模块
-- ============================================================================

local Characters = require("Config.Characters")
Config.CHARACTERS    = Characters.CHARACTERS
Config.AI_NAMES      = Characters.AI_NAMES

local Items = require("Config.Items")
Config.CATEGORIES        = Items.CATEGORIES
Config.ITEM_SIZE_GROUPS  = Items.ITEM_SIZE_GROUPS

local World = require("Config.World")
Config.WORLD_MAP_BG    = World.WORLD_MAP_BG
Config.DEFAULT_BGM     = World.DEFAULT_BGM
Config.REGIONS         = World.REGIONS
Config.WAREHOUSE_TYPES = World.WAREHOUSE_TYPES

local Rewards = require("Config.Rewards")
Config.AD_CARD       = Rewards.AD_CARD
Config.ONLINE_REWARD = Rewards.ONLINE_REWARD

-- ============================================================================
-- 工具函数
-- ============================================================================

function Config.GetRarity(rarityId)
    for _, r in ipairs(Config.RARITY) do
        if r.id == rarityId then return r end
    end
    return Config.RARITY[1]
end

function Config.GetCategory(catId)
    for _, c in ipairs(Config.CATEGORIES) do
        if c.id == catId then return c end
    end
    return Config.CATEGORIES[1]
end

function Config.GetItemRealValue(item)
    return item.realValue or item.baseValue or 0
end

function Config.GetItemsTotalValue(items)
    local total = 0
    for _, item in ipairs(items) do
        total = total + Config.GetItemRealValue(item)
    end
    return total
end

--- 将加价金额取整到美观数字
function Config.RoundBidIncrement(inc)
    if inc >= 100000 then
        return math.floor(inc / 10000) * 10000
    elseif inc >= 10000 then
        return math.floor(inc / 1000) * 1000
    elseif inc >= 1000 then
        return math.floor(inc / 100) * 100
    end
    return inc
end

--- 根据当前出价和百分比计算加价金额（含下限和取整）
function Config.CalcBidIncrement(currentBid, percent)
    local inc = math.floor(currentBid * percent)
    inc = math.max(inc, Config.GAME.MinBidIncrement)
    return Config.RoundBidIncrement(inc)
end

return Config
