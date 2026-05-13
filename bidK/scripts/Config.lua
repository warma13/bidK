-- ============================================================================
-- Config.lua - 拍卖之王 游戏配置数据
-- ============================================================================

local Config = {}

-- 游戏基础配置
Config.GAME = {
    Title = "拍卖之王",
    Version = "1.1.9",
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
    TiebreakBidPercents = { 0.01, 0.05, 0.10 },  -- 加价百分比选项
    -- 每轮倍率门槛（最高价 / 第二名 >= 此倍率则胜出，第5轮严格大于）
    Multipliers = { 2.0, 1.6, 1.4, 1.2 },
}

-- 稀有度配置
Config.RARITY = {
    { id = "white",   name = "白色", color = { 180, 180, 180, 255 } },
    { id = "green",   name = "绿色", color = { 30, 200, 80, 255 } },
    { id = "blue",    name = "蓝色", color = { 50, 130, 255, 255 } },
    { id = "purple",  name = "紫色", color = { 180, 70, 255, 255 } },
    { id = "gold",    name = "金色", color = { 255, 180, 0, 255 } },
    { id = "red",     name = "红色", color = { 255, 50, 50, 255 } },
}

-- 角色币图标
Config.CHARACTER_COIN_ICON = "Textures/tickets/character_coin.png"

-- 门票/入场券定义
Config.TICKETS = {
    port_1000w = {
        name = "1000万场门票",
        icon = "Textures/tickets/port_ticket_1000w.png",
    },
    port_5000w = {
        name = "5000万场门票",
        icon = "Textures/tickets/port_ticket_5000w.png",
    },
}

-- 藏品类别
Config.CATEGORIES = {
    { id = "energy",     name = "能源",   icon = "" },
    { id = "transport",  name = "交通",   icon = "" },
    { id = "art",        name = "艺术",   icon = "" },
    { id = "tech",       name = "科技",   icon = "" },
    { id = "antique",    name = "古董",   icon = "" },
    { id = "jewel",      name = "珠宝",   icon = "" },
    { id = "mechanical", name = "机械",   icon = "" },
    { id = "liquor",     name = "烟酒", icon = "" },
}

-- 藏品数据池 (30件)
Config.ITEMS = {
    -- 能源类
    { id = 1,  name = "特斯拉线圈原型",   category = "energy",    rarity = "gold", baseValue = 8000,  icon = "", desc = "尼古拉·特斯拉亲手制作的无线电力传输装置原型" },
    { id = 2,  name = "老式煤油灯",       category = "energy",    rarity = "white",    baseValue = 800,   icon = "", desc = "19世纪矿工使用的黄铜煤油灯" },
    { id = 3,  name = "核燃料棒模型",     category = "energy",    rarity = "blue",      baseValue = 3500,  icon = "", desc = "冷战时期核电站展示用的燃料棒模型" },
    { id = 4,  name = "太阳能电池板初代", category = "energy",    rarity = "green",  baseValue = 1500,  icon = "", desc = "1970年代实验室原型太阳能电池板" },
    { id = 5,  name = "爱迪生灯泡复刻",   category = "energy",    rarity = "purple",      baseValue = 5500,  icon = "", desc = "爱迪生实验室编号第一的碳丝灯泡复刻品" },

    -- 交通类
    { id = 6,  name = "蒸汽火车模型",     category = "transport", rarity = "green",  baseValue = 1800,  icon = "", desc = "史蒂芬森火箭号的精密缩比模型" },
    { id = 7,  name = "飞艇导航仪",       category = "transport", rarity = "blue",      baseValue = 3000,  icon = "", desc = "齐柏林飞艇上使用的黄铜导航仪器" },
    { id = 8,  name = "老式自行车",       category = "transport", rarity = "white",    baseValue = 600,   icon = "", desc = "维多利亚时代的高轮自行车" },
    { id = 9,  name = "协和号机头碎片",   category = "transport", rarity = "gold", baseValue = 9000,  icon = "", desc = "协和超音速客机退役后的机头铝合金碎片" },
    { id = 10, name = "螺旋桨",           category = "transport", rarity = "purple",      baseValue = 5000,  icon = "", desc = "二战P-51野马战斗机原装螺旋桨" },

    -- 艺术类
    { id = 11, name = "防织藏毯",         category = "art",       rarity = "blue",      baseValue = 3200,  icon = "", desc = "来自西藏的手工编织藏毯，图案精美绝伦" },
    { id = 12, name = "铜版画原版",       category = "art",       rarity = "purple",      baseValue = 6000,  icon = "", desc = "文艺复兴时期大师的铜版画印刷原版" },
    { id = 13, name = "陶瓷花瓶",         category = "art",       rarity = "white",    baseValue = 700,   icon = "", desc = "民国时期景德镇窑出品的青花瓷瓶" },
    { id = 14, name = "象牙微雕",         category = "art",       rarity = "gold", baseValue = 8500,  icon = "", desc = "清代宫廷微雕大师的传世之作" },
    { id = 15, name = "木版年画",         category = "art",       rarity = "green",  baseValue = 1200,  icon = "", desc = "杨柳青年画原版木刻板" },

    -- 科技类
    { id = 16, name = "机械计算机",       category = "tech",      rarity = "purple",      baseValue = 5800,  icon = "", desc = "查尔斯·巴贝奇差分机的齿轮组件" },
    { id = 17, name = "电报机",           category = "tech",      rarity = "green",  baseValue = 1600,  icon = "", desc = "莫尔斯电码时代的黄铜电报发报机" },
    { id = 18, name = "真空管收音机",     category = "tech",      rarity = "blue",      baseValue = 2800,  icon = "", desc = "1940年代飞利浦全波段真空管收音机" },
    { id = 19, name = "初代芯片",         category = "tech",      rarity = "gold", baseValue = 9500,  icon = "", desc = "Intel 4004处理器工程样品" },
    { id = 20, name = "磁带录音机",       category = "tech",      rarity = "white",    baseValue = 500,   icon = "", desc = "索尼Walkman初代工程原型" },

    -- 古董类
    { id = 21, name = "青铜鼎",           category = "antique",   rarity = "gold", baseValue = 10000, icon = "", desc = "战国时期青铜鼎，铸有铭文" },
    { id = 22, name = "玉如意",           category = "antique",   rarity = "purple",      baseValue = 6500,  icon = "", desc = "清乾隆年间和田玉如意" },
    { id = 23, name = "铜钱串",           category = "antique",   rarity = "white",    baseValue = 400,   icon = "", desc = "北宋年间铜钱一串" },
    { id = 24, name = "景泰蓝花瓶",       category = "antique",   rarity = "blue",      baseValue = 3800,  icon = "", desc = "明代景泰蓝掐丝珐琅花瓶" },
    { id = 25, name = "鼻烟壶",           category = "antique",   rarity = "green",  baseValue = 1400,  icon = "", desc = "清代内画鼻烟壶" },

    -- 珠宝类
    { id = 26, name = "红宝石胸针",       category = "jewel",     rarity = "purple",      baseValue = 7000,  icon = "", desc = "维多利亚女王时代的红宝石黄金胸针" },
    { id = 27, name = "珍珠项链",         category = "jewel",     rarity = "blue",      baseValue = 3500,  icon = "", desc = "南海珍珠串联的双层项链" },
    { id = 28, name = "翡翠扳指",         category = "jewel",     rarity = "gold", baseValue = 8800,  icon = "", desc = "满绿冰种翡翠扳指" },
    { id = 29, name = "银质怀表",         category = "jewel",     rarity = "green",  baseValue = 1800,  icon = "", desc = "瑞士百达翡丽1880年代银壳怀表" },
    { id = 30, name = "琥珀挂件",         category = "jewel",     rarity = "white",    baseValue = 900,   icon = "", desc = "波罗的海天然琥珀雕刻挂件" },
}

-- ============================================================================
-- 揭示系统常量
-- ============================================================================

-- 揭示等级权重 W(m): 越高等级信息越有价值
Config.REVEAL_WEIGHTS = {
    L0 = 1,   -- 知道数量
    L1 = 3,   -- 知道轮廓（尺寸/形状）
    L2 = 6,   -- 知道品质（颜色）
    L3 = 10,  -- 知道完整信息（名称+价值）
}

-- 品质权重 Q(q): 基于价格比的立方根（白→红价差约84万倍，Q差100倍）
Config.QUALITY_WEIGHTS = {
    white  = 1,
    green  = 2,
    blue   = 3,
    purple = 10,
    gold   = 20,
    red    = 100,
}

-- 仓库物品数量分布（用于评分计算）
-- 典型仓库: 30白 + 15绿 + 8蓝 + 4紫 + 2金 + 1红 = 60件
Config.WAREHOUSE_DISTRIBUTION = {
    white = 30, green = 15, blue = 8, purple = 4, gold = 2, red = 1,
}
-- Q_avg ≈ 4.4, ΣQ_cat ≈ 38, 目标均分 ≈ 175

-- ============================================================================
-- 角色数据（统一揭示系统）
-- ============================================================================
--
-- 每个角色的技能由 revealEvents 数组定义，统一引擎处理。
--
-- revealEvent 字段说明:
--   trigger:  触发时机
--     "round_N"         — 第N回合触发（N=1..5）
--     "every_round"     — 每回合触发
--     "from_round_N"    — 从第N回合起每回合触发
--
--   target:   目标选择方式
--     "all"             — 仓库全部物品
--     "random_N"        — 随机N件（N为数字）
--     "highest_N"       — 品质最高的N件
--     "rare_random_N"   — 紫色及以上随机N件
--     "category_all"    — 指定品类全部物品
--     "category_random_N" — 指定品类随机N件
--
--   category: 限定品类（nil=不限, 字符串=指定品类, 数组=多品类）
--
--   level:    揭示到的等级 "L0" | "L1" | "L2" | "L3"
--
-- 评分公式: S = ΔW(m) × T(n) × Q(q)
--   ΔW = W_new - W_old（同一物品升级时只计增量）
--   T(n) = (R+1-n)/R, R=5（越早的回合越值钱）
--   Q(q) = QUALITY_WEIGHTS[rarity]
--
Config.CHARACTERS = {
    -- ========== 赵沐瑶 — 能源专精 · 渐进型 (≈173) ==========
    {
        id = 2,
        name = "赵沐瑶",
        avatar = "Textures/characters/ye_lingxi.png",  -- 女
        portrait = "Textures/characters/portraits/portrait_zhao_muyao.png",
        ability = "能源嗅觉",
        desc = "第1轮：知晓能源的件数\n第2轮起每轮：鉴别能源中随机1件的品质\n第4轮：看透能源中最珍贵的1件",
        specialty = "energy",
        revealEvents = {
            { trigger = "round_1",    target = "category_all",      category = "energy", level = "L0" },
            { trigger = "from_round_2", target = "category_random_1", category = "energy", level = "L2" },
            { trigger = "round_4",    target = "highest_1",         category = "energy", level = "L3" },
        },
        personality = {
            style = "grower",
            bidLow = 0.35, bidHigh = 0.65,
            tiebreakMaxRatio = 1.6,
            resignStyle = "meme",
            numberStyle = "round",
            bluffTendency = 0.10,
            pumpTendency = 0.05,
            resignThreshold = 0.25,
            qualitySensUp = 0.20,
            qualitySensDown = 0.50,
        },
    },
    -- ========== 林远舟 — 古董专精 · 早期型 (≈170) ==========
    {
        id = 1,
        name = "林远舟",
        avatar = "Textures/characters/gu_qianhe.png",  -- 男
        portrait = "Textures/characters/portraits/portrait_lin_yuanzhou.png",
        ability = "博古通今",
        desc = "第1轮：知晓古董的件数\n第2轮：鉴别古董中随机3件的品质\n第4轮：看透古董中最珍贵的1件",
        specialty = "antique",
        revealEvents = {
            { trigger = "round_1", target = "category_all",      category = "antique", level = "L0" },
            { trigger = "round_2", target = "category_random_3", category = "antique", level = "L2" },
            { trigger = "round_4", target = "highest_1",         category = "antique", level = "L3" },
        },
        personality = {
            style = "info_driven",
            bidLow = 0.40, bidHigh = 0.70,
            tiebreakMaxRatio = 1.6,
            resignStyle = "silent",
            numberStyle = "precise",
            bluffTendency = 0.05,
            pumpTendency = 0.0,
            resignThreshold = 0.25,
            qualitySensUp = 0.50,
            qualitySensDown = 0.50,
        },
    },
    -- ========== 3. 钱思远 — 科技专精 · 后期爆发 (≈173) ==========
    {
        id = 3,
        name = "钱思远",
        avatar = "Textures/characters/qian_bonian.png",
        portrait = "Textures/characters/portraits/portrait_qian_siyuan.png",
        ability = "数据分析",
        desc = "第1轮：知晓科技的件数\n第3轮：鉴别全部科技物品的品质\n第5轮：看透科技中最珍贵的1件",
        specialty = "tech",
        revealEvents = {
            { trigger = "round_1", target = "category_all", category = "tech", level = "L0" },
            { trigger = "round_3", target = "category_all", category = "tech", level = "L2" },
            { trigger = "round_5", target = "highest_1",    category = "tech", level = "L3" },
        },
        personality = {
            style = "banker",
            bidLow = 0.30, bidHigh = 0.55,
            tiebreakMaxRatio = 1.8,
            resignStyle = "silent",
            numberStyle = "precise",
            bluffTendency = 0.10,
            pumpTendency = 0.20,
            resignThreshold = 0.20,
            qualitySensUp = 0.15,
            qualitySensDown = 0.70,
        },
    },
    -- ========== 4. 顾清韵 — 艺术专精 · 渐进升级 (≈173) ==========
    {
        id = 4,
        name = "顾清韵",
        avatar = "Textures/characters/shen_jinghong.png",  -- 女
        portrait = "Textures/characters/portraits/portrait_gu_qingyun.png",
        ability = "艺术直觉",
        desc = "第1轮：看到全部艺术物品的轮廓\n第3轮：鉴别全部艺术物品的品质\n第5轮：看透艺术中最珍贵的1件",
        specialty = "art",
        revealEvents = {
            { trigger = "round_1", target = "category_all", category = "art", level = "L1" },
            { trigger = "round_3", target = "category_all", category = "art", level = "L2" },
            { trigger = "round_5", target = "highest_1",    category = "art", level = "L3" },
        },
        personality = {
            style = "info_driven",
            bidLow = 0.40, bidHigh = 0.70,
            tiebreakMaxRatio = 1.6,
            resignStyle = "cute",
            numberStyle = "lucky",
            bluffTendency = 0.05,
            pumpTendency = 0.0,
            resignThreshold = 0.25,
            qualitySensUp = 0.50,
            qualitySensDown = 0.50,
        },
    },
    -- ========== 5. 沈玉珂 — 珠宝专精 · 定向深度 (≈172) ==========
    {
        id = 5,
        name = "沈玉珂",
        avatar = "Textures/characters/su_qiaoqiao.png",
        portrait = "Textures/characters/portraits/portrait_shen_yuke.png",
        ability = "珠光宝气",
        desc = "第1轮：知晓珠宝的件数\n第2轮：看透珠宝中随机2件的全部信息\n第4轮：鉴别珠宝中另外随机2件的品质",
        specialty = "jewel",
        revealEvents = {
            { trigger = "round_1", target = "category_all",      category = "jewel", level = "L0" },
            { trigger = "round_2", target = "category_random_2", category = "jewel", level = "L3" },
            { trigger = "round_4", target = "category_random_2", category = "jewel", level = "L2" },
        },
        personality = {
            style = "sniper",
            bidLow = 0.40, bidHigh = 0.80,
            tiebreakMaxRatio = 1.8,
            resignStyle = "silent",
            numberStyle = "precise",
            bluffTendency = 0.0,
            pumpTendency = 0.0,
            resignThreshold = 0.35,
            qualitySensUp = 0.60,
            qualitySensDown = 0.70,
        },
    },
    -- ========== 6. 周正霆 — 机械专精 · 中期型 (≈175) ==========
    {
        id = 6,
        name = "周正霆",
        avatar = "Textures/characters/zhao_tiezhu.png",
        portrait = "Textures/characters/portraits/portrait_zhou_zhengting.png",
        ability = "精密制造",
        desc = "第1轮：知晓机械的件数\n第2轮：看到全部机械物品的轮廓\n第3轮：看透机械中随机2件的全部信息",
        specialty = "mechanical",
        revealEvents = {
            { trigger = "round_1", target = "category_all",      category = "mechanical", level = "L0" },
            { trigger = "round_2", target = "category_all",      category = "mechanical", level = "L1" },
            { trigger = "round_3", target = "category_random_2", category = "mechanical", level = "L3" },
        },
        personality = {
            style = "specialist",
            bidLow = 0.35, bidHigh = 0.70,
            tiebreakMaxRatio = 1.7,
            resignStyle = "meme",
            numberStyle = "round",
            bluffTendency = 0.15,
            pumpTendency = 0.10,
            resignThreshold = 0.25,
            qualitySensUp = 0.40,
            qualitySensDown = 0.50,
        },
    },
    -- ========== 7. 方逸尘 — 运输专精 · R2定向 (≈176) ==========
    {
        id = 7,
        name = "方逸尘",
        avatar = "Textures/characters/chen_laogen.png",  -- 男
        portrait = "Textures/characters/portraits/portrait_fang_yichen.png",
        ability = "物流天眼",
        desc = "第1轮：知晓交通的件数\n第2轮：鉴别全部交通物品的品质\n第4轮：看透交通中最珍贵的1件",
        specialty = "transport",
        revealEvents = {
            { trigger = "round_1", target = "category_all", category = "transport", level = "L0" },
            { trigger = "round_2", target = "category_all", category = "transport", level = "L2" },
            { trigger = "round_4", target = "highest_1",    category = "transport", level = "L3" },
        },
        personality = {
            style = "gambler",
            bidLow = 0.35, bidHigh = 0.65,
            tiebreakMaxRatio = 2.0,
            resignStyle = "meme",
            numberStyle = "round",
            bluffTendency = 0.25,
            pumpTendency = 0.15,
            resignThreshold = 0.20,
            qualitySensUp = 0.60,
            qualitySensDown = 0.25,
        },
    },
    -- ========== 8. 韩墨白 — 古董+艺术 · 持续型 (≈177) ==========
    {
        id = 8,
        name = "韩墨璃",
        avatar = "Textures/characters/fang_jinshu.png",  -- 女
        portrait = "Textures/characters/portraits/portrait_han_moli.png",
        ability = "文玩双绝",
        desc = "第1轮：知晓古董和艺术的件数\n每轮：鉴别古董或艺术中随机1件的品质",
        specialty = { "antique", "art" },
        revealEvents = {
            { trigger = "round_1",    target = "category_all",      category = { "antique", "art" }, level = "L0" },
            { trigger = "every_round", target = "category_random_1", category = { "antique", "art" }, level = "L2" },
        },
        personality = {
            style = "veteran",
            bidLow = 0.35, bidHigh = 0.60,
            tiebreakMaxRatio = 1.7,
            resignStyle = "meme",
            numberStyle = "round",
            bluffTendency = 0.20,
            pumpTendency = 0.15,
            resignThreshold = 0.20,
            qualitySensUp = 0.30,
            qualitySensDown = 0.60,
        },
    },
    -- ========== 9. 孙弈辰 — 能源+科技 · 后期广度 (≈174) ==========
    {
        id = 9,
        name = "孙弈辰",
        avatar = "Textures/characters/sun_yichen.png",  -- 男·新
        portrait = "Textures/characters/portraits/portrait_sun_yichen.png",
        ability = "理工之星",
        desc = "第1轮：知晓能源和科技的件数\n第3轮：鉴别全部能源和科技物品的品质\n第5轮：看透其中最珍贵的1件",
        specialty = { "energy", "tech" },
        revealEvents = {
            { trigger = "round_1", target = "category_all", category = { "energy", "tech" }, level = "L0" },
            { trigger = "round_3", target = "category_all", category = { "energy", "tech" }, level = "L2" },
            { trigger = "round_5", target = "highest_1",    category = { "energy", "tech" }, level = "L3" },
        },
        personality = {
            style = "grower",
            bidLow = 0.30, bidHigh = 0.55,
            tiebreakMaxRatio = 1.6,
            resignStyle = "silent",
            numberStyle = "precise",
            bluffTendency = 0.10,
            pumpTendency = 0.10,
            resignThreshold = 0.25,
            qualitySensUp = 0.20,
            qualitySensDown = 0.50,
        },
    },
    -- ========== 10. 吴鉴之 — 跨品类 · 品质导向 (≈176) ==========
    {
        id = 10,
        name = "吴鉴之",
        avatar = "Textures/characters/wu_jianzhi.png",  -- 男·新
        portrait = "Textures/characters/portraits/portrait_wu_jianzhi.png",
        ability = "慧眼识珠",
        desc = "第1轮：看到仓库全部物品的轮廓\n第3轮：看透紫色及以上随机2件的全部信息",
        specialty = nil, -- 跨品类通才
        revealEvents = {
            { trigger = "round_1", target = "all",           category = nil, level = "L1" },
            { trigger = "round_3", target = "rare_random_2", category = nil, level = "L3" },
        },
        personality = {
            style = "sniper",
            bidLow = 0.40, bidHigh = 0.75,
            tiebreakMaxRatio = 1.8,
            resignStyle = "silent",
            numberStyle = "precise",
            bluffTendency = 0.05,
            pumpTendency = 0.0,
            resignThreshold = 0.30,
            qualitySensUp = 0.60,
            qualitySensDown = 0.70,
        },
    },
    -- ========== 11. 何启明 — 通才 · 信息洪流 (≈171) ==========
    {
        id = 11,
        name = "何启明",
        avatar = "Textures/characters/he_qiming.png",  -- 男·新
        portrait = "Textures/characters/portraits/portrait_he_qiming.png",
        ability = "消息灵通",
        desc = "每轮：鉴别仓库中随机3件物品的品质",
        specialty = nil, -- 通才
        revealEvents = {
            { trigger = "every_round", target = "random_3", category = nil, level = "L2" },
        },
        personality = {
            style = "arbitrage",
            bidLow = 0.40, bidHigh = 0.70,
            tiebreakMaxRatio = 1.5,
            resignStyle = "cute",
            numberStyle = "lucky",
            bluffTendency = 0.10,
            pumpTendency = 0.05,
            resignThreshold = 0.25,
            qualitySensUp = 0.35,
            qualitySensDown = 0.30,
        },
    },
}

-- 仓库名称池
Config.WAREHOUSE_NAMES = {
    "未知仓库", "废弃实验室", "老宅密室", "地下金库",
    "海关查扣库", "收藏家遗物", "古堡地窖", "博物馆仓库",
}

-- （AI 性格参数已内嵌到每个角色的 personality 字段中）

-- 颜色主题
Config.COLORS = {
    bgDark       = { 20, 22, 30, 255 },
    bgPanel      = { 30, 35, 50, 230 },
    bgPanelLight = { 40, 48, 68, 200 },
    bgOverlay    = { 15, 18, 28, 200 },
    textPrimary  = { 220, 225, 240, 255 },
    textSecondary = { 180, 190, 210, 255 },
    textMuted    = { 145, 155, 180, 230 },
    accent       = { 255, 210, 0, 255 },
    accentDim    = { 200, 165, 0, 200 },
    danger       = { 220, 60, 60, 255 },
    success      = { 40, 200, 100, 255 },
    bidButton    = { 240, 220, 0, 255 },
    bidButtonText = { 20, 20, 20, 255 },
    playerHighlight = { 0, 180, 160, 255 },
    playerBadge = {
        { 0, 200, 120, 255 },     -- 1号 绿色
        { 0, 160, 220, 255 },     -- 2号 蓝色
        { 200, 80, 200, 255 },    -- 3号 紫色
        { 0, 180, 160, 255 },     -- 4号 青色
    },
    gridSlotBg   = { 45, 50, 70, 180 },
    gridSlotBorder = { 70, 80, 110, 150 },
    roundBanner  = { 60, 70, 95, 240 },
    infoNew      = { 100, 200, 255, 255 },   -- 新揭露信息高亮
    infoSkill    = { 200, 150, 255, 255 },   -- 私密线索颜色
    sealed       = { 80, 90, 120, 255 },     -- 暗标/隐藏状态
}

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

-- 随机抽取N件藏品（允许重复，价值有波动）
function Config.RandomItems(count)
    local pool = Config.ITEMS
    local result = {}
    for i = 1, count do
        local src = pool[math.random(1, #pool)]
        local item = {
            id = src.id * 1000 + i,
            name = src.name,
            category = src.category,
            rarity = src.rarity,
            baseValue = math.floor(src.baseValue * (0.8 + math.random() * 0.4)),
            icon = src.icon,
            desc = src.desc,
        }
        result[i] = item
    end
    return result
end

function Config.RandomWarehouseName()
    return Config.WAREHOUSE_NAMES[math.random(1, #Config.WAREHOUSE_NAMES)]
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

-- ============================================================================
-- 仓库物品池（带 m×n 尺寸）
-- ============================================================================

Config.WHITE_ITEMS = {
    -- 1×1 小件（8个）
    { name = "旧钥匙",   icon = "", w = 1, h = 1, valueMin = 100,  valueMax = 500 },
    { name = "硬币",     icon = "", w = 1, h = 1, valueMin = 200,  valueMax = 800 },
    { name = "打火机",   icon = "", w = 1, h = 1, valueMin = 100,  valueMax = 300 },
    { name = "旧手表",   icon = "", w = 1, h = 1, valueMin = 300,  valueMax = 1000 },
    { name = "扑克牌",   icon = "🃏", w = 1, h = 1, valueMin = 50,   valueMax = 200 },
    { name = "钢笔",     icon = "", w = 1, h = 1, valueMin = 100,  valueMax = 500 },
    { name = "骰子",     icon = "", w = 1, h = 1, valueMin = 50,   valueMax = 150 },
    { name = "蜡烛",     icon = "", w = 1, h = 1, valueMin = 50,   valueMax = 200 },
    -- 2×1 横向小件（5个）
    { name = "旧书",     icon = "", w = 2, h = 1, valueMin = 200,  valueMax = 800 },
    { name = "键盘",     icon = "", w = 2, h = 1, valueMin = 300,  valueMax = 1000 },
    { name = "球棒",     icon = "", w = 2, h = 1, valueMin = 200,  valueMax = 600 },
    { name = "鞋盒",     icon = "", w = 2, h = 1, valueMin = 100,  valueMax = 500 },
    { name = "工具盒",   icon = "", w = 2, h = 1, valueMin = 300,  valueMax = 900 },
    -- 1×2 纵向小件（4个）
    { name = "花瓶",     icon = "", w = 1, h = 2, valueMin = 200,  valueMax = 1000 },
    { name = "酒瓶",     icon = "", w = 1, h = 2, valueMin = 300,  valueMax = 1200 },
    { name = "雨伞",     icon = "", w = 1, h = 2, valueMin = 100,  valueMax = 400 },
    { name = "台灯",     icon = "", w = 1, h = 2, valueMin = 200,  valueMax = 700 },
    -- 2×2 中型物件（5个）
    { name = "收音机",   icon = "", w = 2, h = 2, valueMin = 500,  valueMax = 2000 },
    { name = "保险箱",   icon = "", w = 2, h = 2, valueMin = 800,  valueMax = 3000 },
    { name = "电饭煲",   icon = "", w = 2, h = 2, valueMin = 300,  valueMax = 1000 },
    { name = "工具箱",   icon = "", w = 2, h = 2, valueMin = 500,  valueMax = 1500 },
    { name = "旧相机",   icon = "", w = 2, h = 2, valueMin = 600,  valueMax = 2500 },
    -- 3×2 中大型（3个）
    { name = "行李箱",   icon = "", w = 3, h = 2, valueMin = 500,  valueMax = 2000 },
    { name = "电视机",   icon = "", w = 3, h = 2, valueMin = 1000, valueMax = 4000 },
    { name = "吉他盒",   icon = "", w = 3, h = 2, valueMin = 800,  valueMax = 3000 },
    -- 2×3 纵向中大型（2个）
    { name = "落地扇",   icon = "", w = 2, h = 3, valueMin = 400,  valueMax = 1500 },
    { name = "衣架柜",   icon = "", w = 2, h = 3, valueMin = 500,  valueMax = 1800 },
    -- 3×3 大型（2个）
    { name = "洗衣机",   icon = "", w = 3, h = 3, valueMin = 2000, valueMax = 6000 },
    { name = "小冰箱",   icon = "", w = 3, h = 3, valueMin = 1500, valueMax = 5000 },
    -- 4×3 大件（1个）
    { name = "书架",     icon = "", w = 4, h = 3, valueMin = 2000, valueMax = 5000 },
    -- 4×4 超大件（1个）
    { name = "旧沙发",   icon = "", w = 4, h = 4, valueMin = 3000, valueMax = 8000 },
    -- 5×5 巨型（1个）
    { name = "大衣柜",   icon = "", w = 5, h = 5, valueMin = 5000, valueMax = 12000 },
}

-- ============================================================================
-- 区域定义
-- ============================================================================

-- 世界大地图背景
Config.WORLD_MAP_BG = "image/world_map_20260323084303.png"

-- 默认 BGM（菜单、地图、仓库等通用界面）
Config.DEFAULT_BGM = "audio/bgm_grocery.ogg"

Config.REGIONS = {
    {
        id = "oldtown", name = "旧城商业区",
        icon = "region_oldtown_20260319111022.png",
        bg = "image/bg_oldtown_20260321192643.png",
        bgm = "audio/bgm_oldtown.ogg",
        desc = "老街深巷里的杂货铺仓库，破烂里藏着宝贝",
        -- 地图上的位置（百分比，相对于地图宽高）
        mapX = 0.22, mapY = 0.65,
        warehouseTypes = { "grocery" },
        difficulties = {
            {
                level = "easy", label = "简单",
                entryFee = 0,
                startingMoney = 800000,
                expectedValue = 30000,
                assetRequirement = 0,
            },
            {
                level = "normal", label = "普通",
                entryFee = 5000,
                startingMoney = 800000,
                expectedValue = 100000,
                assetRequirement = 100000,
            },
        },
    },
    {
        id = "techpark", name = "科技产业园",
        icon = "image/warehouse_techpark_20260328213929.png",
        bg = "image/bg_techpark_20260321192636.png",
        bgm = "audio/bgm_techpark.ogg",
        desc = "倒闭的AI独角兽公司仓库，满是前沿设备和实验室遗物",
        mapX = 0.65, mapY = 0.35,
        warehouseTypes = { "techpark", "datacenter", "quantumlab" },
        difficulties = {
            {
                level = "hard", label = "50万场",
                entryFee = 25000,
                startingMoney = 3000000,
                expectedValue = 500000,
                assetRequirement = 500000,
            },
            {
                level = "nightmare", label = "200万场",
                entryFee = 40000,
                startingMoney = 10000000,
                expectedValue = 2000000,
                assetRequirement = 2000000,
            },
        },
    },
    {
        id = "bondedport", name = "港口保税区",
        icon = "image/warehouse_bondedport_20260323083437.png",
        bg = "image/edited_bg_bondedport_night_20260323131115.png",
        bgm = "audio/bgm_bondedport.ogg",
        desc = "繁忙国际港口的海关保税仓库区，无人认领的集装箱等你开箱",
        mapX = 0.72, mapY = 0.75,
        warehouseTypes = { "bondedport", "shipwreck" },
        difficulties = {
            {
                level = "expert", label = "1000万场",
                entryFee = 80000,
                startingMoney = 10000000,
                expectedValue = 10000000,
                assetRequirement = 10000000,
                requiredTicket = "port_1000w",
                ticketLabel = "1000万场门票",
            },
            {
                level = "legend", label = "5000万场",
                entryFee = 200000,
                startingMoney = 50000000,
                expectedValue = 50000000,
                assetRequirement = 50000000,
                requiredTicket = "port_5000w",
                ticketLabel = "5000万场门票",
            },
        },
    },
}

-- ============================================================================
-- 仓库类型定义
-- sizeWeights: { 1格, 2格, 4格, 6格, 9格+ }
-- ============================================================================

Config.WAREHOUSE_TYPES = {
    grocery = {
        name = "街边杂货铺",
        icon = "warehouse_grocery_20260319111022.png",
        bg = "image/bg_warehouse_grocery_20260322132513.png",
        sizeWeights = { 35, 30, 20, 10, 5 },
    },
    repair = {
        name = "老修理铺",
        bg = "image/bg_warehouse_repair_20260322132510.png",
        sizeWeights = { 30, 30, 22, 12, 6 },
    },
    storage = {
        name = "居民储物间",
        bg = "image/bg_warehouse_storage_20260322132545.png",
        sizeWeights = { 32, 28, 22, 12, 6 },
    },
    techpark = {
        name = "AI独角兽总部",
        icon = "image/warehouse_techpark_20260328213929.png",
        bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 25, 25, 25, 15, 10 },
    },
    datacenter = {
        name = "黑夜之城",
        icon = "image/warehouse_datacenter_20260322110414.png",
        bg = "image/bg_warehouse_datacenter_20260322132508.png",
        sizeWeights = { 20, 25, 25, 18, 12 },
    },
    bondedport = {
        name = "海关保税仓",
        icon = "image/warehouse_bondedport_20260323083437.png",
        bg = "image/bg_warehouse_bondedport_20260323082731.png",
        sizeWeights = { 20, 22, 25, 18, 15 },
    },
    shipwreck = {
        name = "远洋货轮残骸",
        icon = "image/warehouse_shipwreck_20260328210723.png",
        bg = "image/bg_warehouse_shipwreck_20260328204443.png",
        sizeWeights = { 18, 20, 25, 20, 17 },
    },
    quantumlab = {
        name = "量子实验室",
        icon = "image/warehouse_techpark_20260328213929.png",
        bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 22, 24, 25, 17, 12 },
    },
}

-- 物品尺寸分组（占格数 → sizeWeights 索引）
Config.ITEM_SIZE_GROUPS = {
    [1] = 1,              -- S: 1×1
    [2] = 2,              -- S: 1×2, 2×1
    [3] = 2,              -- M: 1×3, 3×1
    [4] = 3,              -- M: 2×2, 1×4, 4×1
    [6] = 4,              -- L: 2×3, 3×2
    [8] = 4,              -- XL: 2×4, 4×2
    [9] = 5,              -- XL: 3×3
    [12] = 5,             -- XXL: 3×4, 4×3
    [15] = 5,             -- XXL: 3×5, 5×3
    [16] = 5,             -- XXL: 4×4
    [25] = 5,             -- XXL: 5×5
}

-- AI 名字库（不放回抽取）
Config.AI_NAMES = {
    "老王头", "张三丰", "李铁嘴", "赵半仙", "钱多多",
    "孙大圣", "周伯通", "吴用", "郑老板", "冯掌柜",
    "陈大侠", "楚留香", "韩非子", "曹阿瞒", "刘皇叔",
    "杨过儿", "林黛玉", "薛宝钗", "贾宝玉", "诸葛亮",
    "司马懿", "黄药师", "欧阳锋", "段誉", "乔峰",
    "虚竹子", "令狐冲", "任我行", "东方不败", "独孤求败",
    "张无忌", "赵敏儿", "小龙女", "郭靖", "黄蓉",
    "韦小宝", "陈近南", "康熙爷", "鳌拜", "海大富",
}

-- ============================================================================
-- 广告卡系统配置
-- ============================================================================

Config.AD_CARD = {
    MAX_DAILY_ADS = 30,  -- 每日最多看30次广告

    -- 卡等级（累计卡点升级，每看满当日上限获得1卡点）
    CARD_TIERS = {
        { name = "普通卡", pointsNeeded = 0,   coinsPerAd = 1000,   color = { 180, 180, 180, 255 } },
        { name = "铜卡",   pointsNeeded = 3,   coinsPerAd = 2000,   color = { 200, 140, 80, 255 } },
        { name = "银卡",   pointsNeeded = 7,   coinsPerAd = 4000,   color = { 180, 200, 220, 255 } },
        { name = "金卡",   pointsNeeded = 15,  coinsPerAd = 10000,  color = { 255, 200, 50, 255 } },
        { name = "钻石卡", pointsNeeded = 30,  coinsPerAd = 20000,  color = { 100, 200, 255, 255 } },
        { name = "至尊卡", pointsNeeded = 60,  coinsPerAd = 40000,  color = { 255, 100, 100, 255 } },
    },

    -- 每日里程碑奖励（当日看广告达到指定次数可领取）
    DAILY_MILESTONES = {
        { adsRequired = 5,  coins = 10000,   label = "看5次" },
        { adsRequired = 10, coins = 20000,   label = "看10次" },
        { adsRequired = 15, coins = 40000,   label = "看15次", bonusPoints = 1 },
        { adsRequired = 20, coins = 50000,   label = "看20次" },
        { adsRequired = 25, coins = 100000,  label = "看25次", bonusPoints = 1, ticket = "port_1000w" },
        { adsRequired = 30, coins = 200000,  label = "看30次", bonusPoints = 2, ticket = "port_5000w" },
    },
}

-- ============================================================================
-- 在线时长奖励配置
-- ============================================================================

Config.ONLINE_REWARD = {
    MILESTONES = {
        { minutes = 1,   coins = 2000,    label = "1分钟" },
        { minutes = 3,   coins = 4000,    label = "3分钟" },
        { minutes = 5,   coins = 10000,   label = "5分钟" },
        { minutes = 10,  coins = 20000,   label = "10分钟" },
        { minutes = 20,  coins = 40000,   label = "20分钟" },
        { minutes = 40,  coins = 100000,  label = "40分钟", ticket = "port_1000w" },
        { minutes = 60,  coins = 200000,  label = "1小时",  ticket = "port_5000w" },
    },
}

-- ============================================================================
-- 竞拍加价辅助
-- ============================================================================

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
