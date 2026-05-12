-- ============================================================================
-- Config/Characters.lua - 角色与 AI 名字库
-- ============================================================================

local M = {}

-- ============================================================================
-- 角色数据（统一揭示系统）
-- ============================================================================
--
-- revealEvent 字段说明:
--   trigger:  触发时机
--     "round_N"           — 第N回合触发（N=1..5）
--     "every_round"       — 每回合触发
--     "from_round_N"      — 从第N回合起每回合触发
--
--   target:   目标选择方式
--     "all"               — 仓库全部物品
--     "random_N"          — 随机N件
--     "highest_N"         — 品质最高的N件
--     "rare_random_N"     — 紫色及以上随机N件
--     "category_all"      — 指定品类全部物品
--     "category_random_N" — 指定品类随机N件
--
--   category: 限定品类（nil=不限, 字符串=指定品类, 数组=多品类）
--   level:    揭示等级 "L0"|"L1"|"L2"|"L3"
--
M.CHARACTERS = {
    -- ========== 赵沐瑶 — 能源专精 · 渐进型 ==========
    {
        id = 2,
        name = "赵沐瑶",
        avatar = "Textures/characters/ye_lingxi.png",
        portrait = "Textures/characters/portraits/portrait_zhao_muyao.png",
        ability = "能源嗅觉",
        desc = "第1轮：知晓能源的件数\n第2轮起每轮：鉴别能源中随机1件的品质\n第4轮：看透能源中最珍贵的1件",
        specialty = "energy",
        revealEvents = {
            { trigger = "round_1",      target = "category_all",      category = "energy", level = "L0" },
            { trigger = "from_round_2", target = "category_random_1", category = "energy", level = "L2" },
            { trigger = "round_4",      target = "highest_1",         category = "energy", level = "L3" },
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
    -- ========== 林远舟 — 古董专精 · 早期型 ==========
    {
        id = 1,
        name = "林远舟",
        avatar = "Textures/characters/gu_qianhe.png",
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
    -- ========== 钱思远 — 科技专精 · 后期爆发 ==========
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
    -- ========== 顾清韵 — 艺术专精 · 渐进升级 ==========
    {
        id = 4,
        name = "顾清韵",
        avatar = "Textures/characters/shen_jinghong.png",
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
    -- ========== 沈玉珂 — 珠宝专精 · 定向深度 ==========
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
    -- ========== 周正霆 — 机械专精 · 中期型 ==========
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
    -- ========== 方逸尘 — 运输专精 · R2定向 ==========
    {
        id = 7,
        name = "方逸尘",
        avatar = "Textures/characters/chen_laogen.png",
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
    -- ========== 韩墨璃 — 古董+艺术 · 持续型 ==========
    {
        id = 8,
        name = "韩墨璃",
        avatar = "Textures/characters/fang_jinshu.png",
        portrait = "Textures/characters/portraits/portrait_han_moli.png",
        ability = "文玩双绝",
        desc = "第1轮：知晓古董和艺术的件数\n每轮：鉴别古董或艺术中随机1件的品质",
        specialty = { "antique", "art" },
        revealEvents = {
            { trigger = "round_1",     target = "category_all",      category = { "antique", "art" }, level = "L0" },
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
    -- ========== 孙弈辰 — 能源+科技 · 后期广度 ==========
    {
        id = 9,
        name = "孙弈辰",
        avatar = "Textures/characters/sun_yichen.png",
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
    -- ========== 吴鉴之 — 跨品类 · 品质导向 ==========
    {
        id = 10,
        name = "吴鉴之",
        avatar = "Textures/characters/wu_jianzhi.png",
        portrait = "Textures/characters/portraits/portrait_wu_jianzhi.png",
        ability = "慧眼识珠",
        desc = "拍卖开始时，显示白色、绿色、蓝色品质藏品的总价值和品质",
        specialty = nil,
        revealEvents = {
            { trigger = "round_1", target = "all", rarity = {"white","green","blue"}, level = "L2" },
            { trigger = "round_1", target = "all", rarity = {"white","green","blue"}, level = "L0V" },
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
    -- ========== 陆鉴 — 轮廓洞察 · 锁定角色 ==========
    {
        id = 12,
        name = "陆鉴",
        avatar = "Textures/characters/lu_jian.png",
        portrait = "Textures/characters/portraits/portrait_lu_jian.png",
        ability = "形迹可循",
        desc = "第1轮：看到随机5件物品的轮廓\n第5轮：全场轮廓全开",
        specialty = nil,
        locked = true,
        unlockCost = 20,
        revealEvents = {
            { trigger = "round_1", target = "random_5", category = nil, level = "L1" },
            { trigger = "round_5", target = "all",      category = nil, level = "L1" },
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
            qualitySensUp = 0.45,
            qualitySensDown = 0.55,
        },
    },
    -- ========== 何启明 — 通才 · 信息洪流 ==========
    {
        id = 11,
        name = "何启明",
        avatar = "Textures/characters/he_qiming.png",
        portrait = "Textures/characters/portraits/portrait_he_qiming.png",
        ability = "消息灵通",
        desc = "每轮：鉴别仓库中随机3件物品的品质",
        specialty = nil,
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

M.AI_NAMES = {
    "老王头", "张三丰", "李铁嘴", "赵半仙", "钱多多",
    "孙大圣", "周伯通", "吴用", "郑老板", "冯掌柜",
    "陈大侠", "楚留香", "韩非子", "曹阿瞒", "刘皇叔",
    "杨过儿", "林黛玉", "薛宝钗", "贾宝玉", "诸葛亮",
    "司马懿", "黄药师", "欧阳锋", "段誉", "乔峰",
    "虚竹子", "令狐冲", "任我行", "东方不败", "独孤求败",
    "张无忌", "赵敏儿", "小龙女", "郭靖", "黄蓉",
    "韦小宝", "陈近南", "康熙爷", "鳌拜", "海大富",
}

return M
