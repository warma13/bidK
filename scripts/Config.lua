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
    Version = "1.1.34",
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
        ticketPrice = 5,
    },
    ticket_industrial = {
        name = "工业仓库指定券",
        icon = "Textures/tickets/ticket_industrial.png",
        ticketPrice = 10,
    },
    ticket_commercial = {
        name = "商业仓库指定券",
        icon = "Textures/tickets/ticket_commercial.png",
        ticketPrice = 15,
    },
    ticket_port = {
        name = "港口仓库指定券",
        icon = "Textures/tickets/ticket_port.png",
        ticketPrice = 20,
    },
    ticket_techpark = {
        name = "科技仓库指定券",
        icon = "Textures/tickets/ticket_techpark.png",
        ticketPrice = 25,
    },
    ticket_culture = {
        name = "文化仓库指定券",
        icon = "Textures/tickets/ticket_culture.png",
        ticketPrice = 35,
    },
    ticket_deepsea = {
        name = "深海仓库指定券",
        icon = "Textures/tickets/ticket_deepsea.png",
        ticketPrice = 40,
    },
    ticket_private = {
        name = "顶级私产指定券",
        icon = "Textures/tickets/ticket_private.png",
        ticketPrice = 50,
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

-- 物品名称 → 静态属性 索引（懒加载，首次调用时构建）
local _itemStaticIndex = nil

function Config.GetItemByName(name)
    if not _itemStaticIndex then
        _itemStaticIndex = {}
        local ItemPool = require("Config.Warehouses.ItemPool")
        for _, cat in ipairs(ItemPool.categories) do
            for _, item in ipairs(cat.items) do
                _itemStaticIndex[item.name] = {
                    rarity   = item.quality,
                    w        = item.cols,
                    h        = item.rows,
                    category = cat.id,
                    image    = item.image or "",
                    desc     = item.desc or "",
                }
            end
        end
    end
    return _itemStaticIndex[name]
end

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

-- ============================================================================
-- 奖励类型注册表（图标/名称集中配置，供所有面板复用）
-- ============================================================================
-- 每种 type 对应：
--   icon      string   资源路径（传给 backgroundImage）
--   name      string   显示名称
--   countFmt  fn(amount) → string  右下角数量文案
-- ticket 类型图标通过 Config.TICKETS[ticketId].icon 动态取，此处不填 icon
Config.REWARD_TYPES = {
    coins = {
        name     = "金币",
        icon     = "Textures/icons/icon_coin.png",
        countFmt = function(amount) return require("UI.Utils").FormatMoney(amount) end,
    },
    bp_exp = {
        name     = "通行证经验",
        icon     = "image/xp_gold_20260518121142.png",
        countFmt = function(amount) return "×" .. amount end,
    },
    ticket = {
        name     = "积分券",
        icon     = nil,   -- 动态：Config.TICKETS[ticketId].icon
        countFmt = function(amount) return "×" .. (amount or 1) end,
    },
    point_tickets = {
        name     = "点券",
        icon     = "image/point_ticket_icon_20260518210650.png",
        countFmt = function(amount) return "×" .. (amount or 1) end,
    },
    chest = {
        name     = "礼盒",
        icon     = nil,   -- 动态：通过 chestId 从 Chests 配置获取
        countFmt = function(amount) return "×" .. (amount or 1) end,
    },
}

--- 获取奖励图标路径（coins 走 Utils.GetIcon，ticket 走 Config.TICKETS）
function Config.GetRewardIcon(reward)
    if not reward then return "" end
    if reward.type == "coins" then
        return require("UI.Utils").GetIcon("coin")
    elseif reward.type == "ticket" and reward.ticketId then
        local t = Config.TICKETS[reward.ticketId]
        return t and t.icon or "image/point_ticket_icon_20260518210650.png"
    elseif reward.type == "chest" and reward.chestId then
        local Chests = require("Config.Chests")
        local c = Chests.BY_ID[reward.chestId]
        return c and c.iconImage or ""
    else
        local rt = Config.REWARD_TYPES[reward.type]
        return rt and rt.icon or ""
    end
end

--- 获取奖励数量文案
function Config.GetRewardCount(reward)
    if not reward then return "" end
    local rt = Config.REWARD_TYPES[reward.type]
    if rt and rt.countFmt then return rt.countFmt(reward.amount) end
    return reward.amount and ("×" .. reward.amount) or ""
end

--- 获取奖励名称
function Config.GetRewardName(reward)
    if not reward then return "奖励" end
    if reward.type == "ticket" and reward.ticketId then
        local t = Config.TICKETS[reward.ticketId]
        return t and t.name or "积分券"
    elseif reward.type == "chest" and reward.chestId then
        local Chests = require("Config.Chests")
        local c = Chests.BY_ID[reward.chestId]
        return c and c.name or "礼盒"
    end
    local rt = Config.REWARD_TYPES[reward.type]
    return rt and rt.name or "奖励"
end

-- ============================================================================
-- 系统邮件（id 不可变更，用于标记已读/已领取）
-- ============================================================================
-- reward  字段：单奖励 { type="coins"|"bp_exp"|"ticket"|"point_tickets"|"chest", amount=N, ticketId/chestId="..." }
-- rewards 字段：多奖励数组，与 reward 互斥（优先使用 rewards）
-- veteranOnly = true：仅老玩家可见（存档创建日期 < 邮件 date 时才显示）
--   新注册玩家（存档创建日期 ≥ 邮件日期）不会看到此邮件，防止刷号领附件
-- 每次版本更新在此追加一条新记录，id 固定不变，旧公告永久保留。
-- id 命名规范：v{版本号下划线形式}_update，例如 v1_1_28_update
Config.MAILS = {
    {
        id     = "v1_1_28_update",
        title  = "1.1.28 版本更新公告",
        sender = "系统",
        date   = "2026-05-21",
        expiry = "",
        veteranOnly = true,
        body   = "感谢各位拍友一直以来的支持！本次更新带来以下新内容：\n\n"
              .. "【新增】通行证系统\n参与对局、完成每日任务可获得通行证经验，积累经验升级通行证，解锁丰厚赛季奖励。看广告可自动解锁高级奖励，无需手动领取。\n\n"
              .. "【新增】金色 & 红色道具\n部分道具现有金色（稀有）和红色（传说）品质版本，每日商店有概率刷新，也可在商城直接购买。\n\n"
              .. "【新增】礼盒系统\n商城新增礼盒，开启有机会获得赛季限定红色藏品，手气好的拍友不要错过！\n\n"
              .. "【调整】局内效果改动\n在揭示物品信息（L2）之前新增 L2 提示效果，启用「显示品质」时不再显示完整物品轮廓。\n\n"
              .. "【优化】部分体验优化\n修复了若干已知问题，优化了界面流畅度，感谢大家的反馈！\n\n"
              .. "特别感谢所有玩家的支持，祝大家游戏愉快！",
        rewards = {
            { type = "bp_exp",       amount = 1000 },
            { type = "coins",        amount = 1000000 },
            { type = "point_tickets", amount = 50 },
        },
    },
    {
        id     = "v1_1_29_update",
        title  = "1.1.29 版本更新公告",
        sender = "系统",
        date   = "2026-05-21",
        expiry = "",
        veteranOnly = true,
        body   = "感谢各位拍友的持续支持！本次更新内容：\n\n"
              .. "【优化】生成算法优化\n改进了仓库物品的生成算法，物品分布更加合理，游戏体验更佳。\n\n"
              .. "【加强】部分角色技能加强\n对部分角色的技能进行了数值调整和效果加强，让每位角色都更具竞争力。\n\n"
              .. "感谢大家的反馈，祝游戏愉快！",
        rewards = {
            { type = "coins", amount = 2000000 },
        },
    },
    {
        id     = "v1_1_30_update",
        title  = "1.1.30 版本更新公告",
        sender = "系统",
        date   = "2026-05-21",
        expiry = "",
        body   = "感谢各位拍友的持续支持！本次更新内容：\n\n"
              .. "【新增】背景音乐\n新增休闲风格背景音乐，可在设置面板中切换曲目。\n\n"
              .. "【修复】抽选仓库时可点击\n修复了在抽选仓库动画播放期间仍可点击底部按钮的问题。\n\n"
              .. "【优化】邮件系统\n新增删除已读邮件功能，保持收件箱整洁。\n\n"
              .. "感谢大家的反馈，祝游戏愉快！",
    },
    {
        id     = "v1_1_32_update",
        title  = "1.1.32 版本更新公告",
        sender = "系统",
        date   = "2026-05-22",
        expiry = "",
        veteranOnly = true,
        body   = "感谢各位拍友的持续支持！本次更新内容：\n\n"
              .. "【修复】战利品生成算法\n修复了仓库物品生成中的多个问题，战利品分布更加合理。\n\n"
              .. "【优化】信息揭示与利用\n优化了竞拍信息的揭示逻辑，修复了部分信息泄露问题；AI 现在能更好地利用格子信息进行估值。\n\n"
              .. "【优化】区域选择界面\n优化了区域选择界面的 UI 展示效果，视觉体验更佳。\n\n"
              .. "感谢大家的反馈，祝游戏愉快！",
        rewards = {
            { type = "coins",         amount = 2000000 },
            { type = "point_tickets", amount = 30 },
            { type = "chest",         amount = 1, chestId = "chest_gold" },
        },
    },
    {
        id     = "v1_1_33_update",
        title  = "1.1.33 版本更新公告",
        sender = "系统",
        date   = "2026-05-23",
        expiry = "",
        body   = "感谢各位拍友的持续支持！本次更新对多位角色的技能进行了调整与强化。\n\n"
              .. "【加强】吴鉴之 · 慧眼识珠\n全面重新设计：第1轮改为鉴别全场品质最高的3件藏品，后续每轮持续扫描随机2件品质，第4轮精读最贵藏品的轮廓和品质。从「看便宜货」改为「锁定高价值目标」。\n\n"
              .. "【加强】陆鉴 · 形迹可循\n第2轮起揭示等级从轮廓提升为轮廓+品质，第4轮新增紫色及以上藏品的轮廓扫描，信息质量大幅提升。\n\n"
              .. "【加强】裴锦书 · 烟火慧眼\n第1轮日用品揭示从轮廓升级为轮廓+品质，通才品质信息提前至第2轮，第5轮新增日用品精确价值全览。\n\n"
              .. "【修复】谢怀仁 · 医眼如炬\n修复了技能信息越往后越弱的设计缺陷：第2轮起揭示升级为轮廓+品质，第5轮新增全场医疗藏品完整复扫。\n\n"
              .. "【加强】程云裳 · 锦绣眼\n第1轮服饰揭示从轮廓升级为轮廓+品质，后续改为每轮随机1件通才品质，第4轮新增精读随机1件服饰精确价值。\n\n"
              .. "【修复+加强】江识玉 · 双向侦查\n修正第1轮全场最高藏品的揭示精度，新增第2轮起珠宝持续品质追踪，以及第4轮全场最贵2件复扫，「双向」名副其实。\n\n"
              .. "【加强】周正霆 · 精密制造\n新增第4轮再精读机械随机1件全部信息，第5轮新增通才随机2件品质收尾，补足后两轮信息空白。\n\n"
              .. "感谢大家的反馈，祝游戏愉快！",
    },
    {
        id     = "v1_1_34_update",
        title  = "1.1.34 版本更新公告",
        sender = "系统",
        date   = "2026-05-23",
        expiry = "",
        body   = "感谢各位拍友的持续支持！本次更新带来以下优化：\n\n"
              .. "【优化】战利品生成算法\n重新设计仓库物品选取权重，极端高价物品（如顶级限量藏品）的出现频率与仓库实际价值档位动态挂钩，使仓库内容分布更加合理，普通仓库中的物品价值区间更贴近实际体验。\n\n"
              .. "【优化】AI出价逻辑\nAI对红色藏品的估值不再受极端高价物品干扰，出价参考值更符合当前仓库的整体价值，第一轮出价大幅改善，竞拍对局体验更平衡。\n\n"
              .. "感谢大家的反馈，祝游戏愉快！",
        rewards = {
            { type = "coins",         amount = 2000000 },
            { type = "point_tickets", amount = 30 },
            { type = "chest",         amount = 1, chestId = "chest_common" },
        },
    },
}

return Config
