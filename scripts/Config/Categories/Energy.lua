-- ============================================================================
-- Config/Categories/Energy.lua - 能源品类物品定义
-- 来源：ItemPool（通用池）+ DataCenter（赛博主题）+ QuantumLab（量子主题）
-- ============================================================================

local Energy = {}

-- ============================================================================
-- ItemPool 通用能源物品
-- ============================================================================
local IMG = "items/"

Energy.items = {
    -- ===== ItemPool 通用能源物品 =====
    -- 白 ×13
    { name = "半截蜡烛",       rows = 1, cols = 1, quality = "white",  value = 242,  weight = 2,  desc = "烧了一半的普通白蜡烛",             image = IMG .. "能源/半截蜡烛.png" },
    { name = "旧火柴盒",       rows = 1, cols = 1, quality = "white",  value = 105,  weight = 2,  desc = "只剩几根火柴的铁皮盒子",           image = IMG .. "能源/旧火柴盒.png" },
    { name = "废旧电池",       rows = 1, cols = 1, quality = "white",  value = 105,  weight = 2,  desc = "已经漏液的老式干电池",             image = IMG .. "能源/废旧电池.png" },
    { name = "旧灯泡",         rows = 1, cols = 1, quality = "white",  value = 114,  weight = 2,  desc = "钨丝烧断的白炽灯泡",               image = IMG .. "能源/旧灯泡.png" },
    { name = "锈打火机",       rows = 1, cols = 1, quality = "white",  value = 335,  weight = 1,  desc = "打不着的一次性打火机",             image = IMG .. "能源/锈打火机.png" },
    { name = "旧插排",         rows = 1, cols = 2, quality = "white",  value = 105,  weight = 2,  desc = "外壳发黄的两孔插排",               image = IMG .. "能源/旧插排.png" },
    { name = "电线团",         rows = 1, cols = 1, quality = "white",  value = 105,  weight = 2,  desc = "缠成一团的旧电线",                 image = IMG .. "能源/电线团.png" },
    { name = "旧灯笼",         rows = 2, cols = 2, quality = "white",  value = 452,  weight = 1,  desc = "纸面破了的红灯笼骨架",             image = IMG .. "能源/旧灯笼.png" },
    { name = "碎灯罩",         rows = 1, cols = 1, quality = "white",  value = 242,  weight = 2,  desc = "碎了一角的玻璃灯罩",               image = IMG .. "能源/碎灯罩.png" },
    { name = "旧煤炉",         rows = 2, cols = 3, quality = "white",  value = 529,  weight = 1,  desc = "炉壁开裂的蜂窝煤炉子",             image = IMG .. "能源/旧煤炉.png" },
    { name = "旧开关面板",     rows = 1, cols = 1, quality = "white",  value = 105,  weight = 3,  desc = "发黄开裂的拉绳式老开关",           image = IMG .. "能源/旧开关面板.png" },
    { name = "旧灯管",         rows = 4, cols = 1, quality = "white",  value = 105,  weight = 2,  desc = "一根不亮了的日光灯管",             image = IMG .. "能源/旧灯管.png" },
    { name = "煤块",           rows = 1, cols = 1, quality = "white",  value = 105,  weight = 3,  desc = "几块散落的蜂窝煤",                 image = IMG .. "能源/煤块.png" },
    -- 绿 ×11
    { name = "煤油灯",         rows = 2, cols = 1, quality = "green",  value = 333,  weight = 2,  desc = "玻璃罩有裂纹的老煤油灯",           image = IMG .. "能源/煤油灯.png" },
    { name = "老式手电筒",     rows = 2, cols = 1, quality = "green",  value = 560,  weight = 2,  desc = "拍两下才亮的铁皮手电",             image = IMG .. "能源/老式手电筒.png" },
    { name = "马灯",           rows = 1, cols = 1, quality = "green",  value = 210,  weight = 3,  desc = "铁皮马灯，提手生锈但玻璃完好",     image = IMG .. "能源/马灯.png" },
    { name = "旧蓄电池",       rows = 1, cols = 2, quality = "green",  value = 374,  weight = 2,  desc = "摩托车用的铅酸蓄电池",             image = IMG .. "能源/旧蓄电池.png" },
    { name = "铜灯座",         rows = 1, cols = 1, quality = "green",  value = 1035, weight = 1,  desc = "做工精细的铜质灯头底座",           image = IMG .. "能源/铜灯座.png" },
    { name = "老油灯",         rows = 1, cols = 1, quality = "green",  value = 267,  weight = 2,  desc = "锡制菜油灯，灯芯还在",             image = IMG .. "能源/老油灯.png" },
    { name = "旧变压器",       rows = 2, cols = 2, quality = "green",  value = 1324, weight = 1,  desc = "小型铁芯变压器，线圈完好",         image = IMG .. "能源/旧变压器.png" },
    { name = "老取暖炉",       rows = 3, cols = 2, quality = "green",  value = 2347, weight = 1,  desc = "铸铁取暖炉，炉门还能开合",         image = IMG .. "能源/老取暖炉.png" },
    { name = "老电闸",         rows = 1, cols = 3, quality = "green",  value = 301,  weight = 2,  desc = "瓷底座闸刀开关，铜触点发绿",       image = IMG .. "能源/老电闸.png" },
    { name = "铜质水烟壶",     rows = 1, cols = 1, quality = "green",  value = 1178, weight = 1,  desc = "做工精细的黄铜水烟壶",             image = IMG .. "能源/铜质水烟壶.png" },
    { name = "旧落地灯架",     rows = 3, cols = 1, quality = "green",  value = 642,  weight = 2,  desc = "铁艺落地灯架，灯罩丢了",           image = IMG .. "能源/旧落地灯架.png" },
    -- 蓝 ×7
    { name = "黄铜台灯",       rows = 2, cols = 1, quality = "blue",   value = 1444, weight = 2,  desc = "民国风格黄铜底座台灯",             image = IMG .. "能源/黄铜台灯.png" },
    { name = "铁壳电扇",       rows = 2, cols = 2, quality = "blue",   value = 9286, weight = 1,  desc = "五十年代铁壳台式电扇，还能转",     image = IMG .. "能源/铁壳电扇.png" },
    { name = "老式电表",       rows = 1, cols = 1, quality = "blue",   value = 686,  weight = 3,  desc = "转盘式机械电表，木壳外框",         image = IMG .. "能源/老式电表.png" },
    { name = "老矿灯",         rows = 1, cols = 1, quality = "blue",   value = 2169, weight = 2,  desc = "铜质矿工头灯，乙炔式",             image = IMG .. "能源/老矿灯.png" },
    { name = "铜烛台",         rows = 1, cols = 2, quality = "blue",   value = 3428, weight = 1,  desc = "欧式三叉铜烛台，有绿锈",           image = IMG .. "能源/铜烛台.png" },
    { name = "铁壳暖炉",       rows = 3, cols = 2, quality = "blue",   value = 1796, weight = 2,  desc = "铸铁壁炉式暖炉，通风口精铸花纹",   image = IMG .. "能源/铁壳暖炉.png" },
    { name = "老式配电箱",     rows = 2, cols = 3, quality = "blue",   value = 553,  weight = 3,  desc = "木壳保险丝配电箱，铜件齐全",       image = IMG .. "能源/老式配电箱.png" },
    -- 紫 ×6
    { name = "军用手摇发电机", rows = 2, cols = 3, quality = "purple", value = 2559,  weight = 4,  desc = "刻有编号的军用野战手摇发电机",     image = IMG .. "能源/军用手摇发电机.png" },
    { name = "老航标灯",       rows = 2, cols = 2, quality = "purple", value = 13078, weight = 2,  desc = "港口退役的菲涅尔透镜航标灯",       image = IMG .. "能源/老航标灯.png" },
    { name = "蒂芙尼台灯",     rows = 2, cols = 2, quality = "purple", value = 20763, weight = 1,  desc = "彩色玻璃拼花灯罩的台灯",           image = IMG .. "能源/蒂芙尼台灯.png" },
    { name = "军用柴油发电机", rows = 4, cols = 3, quality = "purple", value = 11888, weight = 2,  desc = "五十年代军队野战柴油发电机组",     image = IMG .. "能源/军用柴油发电机.png" },
    { name = "老煤油炉",       rows = 1, cols = 1, quality = "purple", value = 2156,  weight = 5,  desc = "黄铜煤油取暖炉，可折叠提手",       image = IMG .. "能源/老煤油炉.png" },
    { name = "铜烛剪",         rows = 1, cols = 1, quality = "purple", value = 4114,  weight = 3,  desc = "剪灯花用的铜质烛剪，做工精巧",     image = IMG .. "能源/铜烛剪.png" },
    -- 金 ×9
    { name = "爱迪生灯泡复刻",         rows = 1, cols = 1, quality = "gold", value = 10181,  weight = 16, desc = "编号限量版爱迪生碳丝灯泡复刻品",   image = IMG .. "能源/爱迪生灯泡复刻.png" },
    { name = "老船灯",                 rows = 2, cols = 3, quality = "gold", value = 93082,  weight = 2,  desc = "铜制远洋轮船甲板信号灯，有铭牌",   image = IMG .. "能源/老船灯.png" },
    { name = "古董打火机（Zippo初代）", rows = 1, cols = 1, quality = "gold", value = 15573,  weight = 11, desc = "1930年代初代Zippo，外壳磨花但机芯完好", image = IMG .. "能源/古董打火机（Zippo初代）.png" },
    { name = "老式风力发电机叶片",     rows = 4, cols = 1, quality = "gold", value = 40643,  weight = 4,  desc = "早期丹麦实验风机的木质叶片，有铭牌",   image = IMG .. "能源/老式风力发电机叶片.png" },
    { name = "铀矿石标本（密封）",     rows = 1, cols = 1, quality = "gold", value = 110027, weight = 2,  desc = "铅盒密封的高品位铀矿石样本，附检测证书", image = IMG .. "能源/铀矿石标本（密封）.png" },
    { name = "老式路灯头",             rows = 3, cols = 3, quality = "gold", value = 31488,  weight = 5,  desc = "铸铁欧式路灯头，四面玻璃完好",       image = IMG .. "能源/老式路灯头.png" },
    { name = "铁路信号灯",             rows = 1, cols = 1, quality = "gold", value = 13036,  weight = 13, desc = "铁路道口老式信号灯，红绿灯罩完好",   image = IMG .. "能源/铁路信号灯.png" },
    { name = "船用汽笛",               rows = 1, cols = 2, quality = "gold", value = 19458,  weight = 9,  desc = "黄铜船用蒸汽汽笛，还能吹响",         image = IMG .. "能源/船用汽笛.png" },
    { name = "铜质消防灯",             rows = 1, cols = 1, quality = "gold", value = 13273,  weight = 12, desc = "老式消防车上的黄铜探照灯",           image = IMG .. "能源/铜质消防灯.png" },
    -- 红 ×7
    { name = "特斯拉线圈模型",   rows = 3, cols = 3, quality = "red",    value = 4948211, weight = 4,   desc = "疑似尼古拉·特斯拉工作室流出的缩比实验模型", image = IMG .. "能源/特斯拉线圈模型.png" },
    { name = "拉瓦锡实验器具",   rows = 2, cols = 2, quality = "red",    value = 1650771, weight = 13,  desc = "疑似拉瓦锡实验室的铜质气体收集装置",       image = IMG .. "能源/拉瓦锡实验器具.png" },
    { name = "居里夫人笔记本",   rows = 1, cols = 1, quality = "red",    value = 10460497, weight = 2,  desc = "铅盒封存的放射性实验手稿，附盖革计数器读数", image = IMG .. "能源/居里夫人笔记本.png" },
    { name = "瓦特蒸汽机零件",   rows = 2, cols = 2, quality = "red",    value = 70763,   weight = 348, desc = "疑似早期蒸汽机的铜质气缸活塞组件",         image = IMG .. "能源/瓦特蒸汽机零件.png" },
    { name = "法拉第线圈装置",   rows = 2, cols = 2, quality = "red",    value = 558839,  weight = 40,  desc = "疑似法拉第实验用的感应线圈铜装置",         image = IMG .. "能源/法拉第线圈装置.png" },
    { name = "航海罗经灯",       rows = 1, cols = 1, quality = "gold",   value = 22552,   weight = 7,   desc = "铜壳航海罗盘照明灯，万向节完好",           image = IMG .. "能源/航海罗经灯.png" },
    { name = "老灯塔透镜",       rows = 2, cols = 2, quality = "red",    value = 214014,  weight = 109, desc = "退役灯塔的小型菲涅尔聚光透镜",             image = IMG .. "能源/老灯塔透镜.png" },
    { name = "矿井安全灯",       rows = 1, cols = 1, quality = "red",    value = 90489,   weight = 269, desc = "铜网罩安全灯，刻有19世纪矿区编号",         image = IMG .. "能源/矿井安全灯.png" },

    -- ===== DataCenter 赛博能源物品 =====
    { name = "微型散热片",     rows = 1, cols = 2, quality = "white",  value = 220,   desc = "CPU散热鳍片组，铝制氧化发黑",             image = IMG .. "能源/微型散热片.png" },
    { name = "废弃生物电池组",   rows = 1, cols = 2, quality = "white",  value = 280,   desc = "冗余电源模组，接头氧化",                 image = IMG .. "能源/废弃生物电池组.png" },
    { name = "液冷循环塔",   rows = 1, cols = 1, quality = "green",  value = 850,   desc = "铜底水冷头，导热面有划痕",               image = IMG .. "能源/液冷循环塔.png" },
    { name = "UPS应急电源",      rows = 2, cols = 2, quality = "green",  value = 3200,  desc = "48V工业UPS，电池可更换",                 image = IMG .. "能源/UPS应急电源.png" },
    { name = "旧等离子球",     rows = 1, cols = 1, quality = "blue",   value = 1800,  desc = "高压等离子球，触碰有放电反应",           image = IMG .. "能源/旧等离子球.png" },
    { name = "超导磁轨弹射模块", rows = 2, cols = 2, quality = "purple", value = 28000, desc = "低温超导线圈，液氮冷却痕迹明显",         image = IMG .. "能源/超导磁轨弹射模块.png" },
    { name = "超导线圈组件",   rows = 1, cols = 3, quality = "blue",   value = 12000, desc = "高温超导带材制作的电缆段",               image = IMG .. "能源/超导线圈组件.png" },
    { name = "恒星之心冷核", rows = 1, cols = 1, quality = "gold",   value = 180000, desc = "实验性聚变反应堆的核心磁约束线圈",      image = IMG .. "能源/恒星之心冷核.png" },
    { name = "量子真空能量模块", rows = 2, cols = 2, quality = "red",    value = 8500000, desc = "疑似提取量子真空能量的实验装置",        image = IMG .. "能源/量子真空能量模块.png" },
    { name = "微型聚变点火器", rows = 2, cols = 3, quality = "red",  value = 3600000, desc = "惯性约束聚变的激光点火靶室模块",        image = IMG .. "能源/微型聚变点火器.png" },

    -- ===== QuantumLab 量子能源物品 =====
    { name = "冷却液管",     rows = 3, cols = 3, quality = "gold",   value = 750000, desc = "完整的激光多普勒冷却实验台",            image = IMG .. "能源/冷却液管.png" },
    -- ===== 新增数据中心物品 =====
    { name = "太阳能电池板碎片", rows = 1, cols = 2, quality = "white", value = 280, desc = "单晶硅太阳能电池板碎块，仍有发电能力", image = IMG .. "能源/太阳能电池板碎片.png" },
    { name = "核电站控制杆", rows = 1, cols = 4, quality = "purple", value = 85000, desc = "核反应堆控制棒，高硼钢材质", image = IMG .. "能源/核电站控制杆.png" },
    { name = "老煤气灯头", rows = 1, cols = 1, quality = "green", value = 1200, desc = "民国街头煤气路灯的铸铁灯头", image = IMG .. "能源/老煤气灯头.png" },
    { name = "老黄铜吊灯", rows = 2, cols = 2, quality = "blue", value = 9500, desc = "维多利亚时代黄铜瓦斯吊灯，做工精细", image = IMG .. "能源/老黄铜吊灯.png" },
    { name = "铜质油壶灯", rows = 1, cols = 1, quality = "green", value = 2200, desc = "手工锻铜阿拉伯风格油壶灯，有使用痕迹", image = IMG .. "能源/铜质油壶灯.png" },
    -- ===== 同尺寸低价诱饵（3×3：对应特斯拉线圈模型）=====
    { name = "旧锅炉箱", rows = 3, cols = 3, quality = "white", value = 1850, weight = 2, desc = "锈蚀严重的民用小型锅炉箱，阀门缺失", image = IMG .. "能源/旧锅炉箱.png" },
    { name = "旧变电柜", rows = 3, cols = 3, quality = "green", value = 5200, weight = 1, desc = "废弃厂房拆下的旧变电开关柜，铜件尚存", image = IMG .. "能源/旧变电柜.png" },

}

return Energy
