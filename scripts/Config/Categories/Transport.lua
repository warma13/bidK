-- ============================================================================
-- Config/Categories/Transport.lua - 交通品类物品定义
-- 来源：ItemPool（通用池）+ DataCenter（赛博主题）
-- ============================================================================

local Transport = {}

local IMG = "items/"

Transport.items = {
    -- ===== ItemPool 通用交通物品 =====
    -- 白 ×10
    { name = "旧自行车轮",   rows = 2, cols = 2, quality = "white",  value = 114,  weight = 2,  desc = "辐条断了几根的自行车轮组",             image = IMG .. "交通/旧自行车轮.png" },
    { name = "坏电动滑板",   rows = 2, cols = 1, quality = "white",  value = 452,  weight = 1,  desc = "电池鼓包的电动滑板",                   image = IMG .. "交通/坏电动滑板.png" },
    { name = "旧头盔",       rows = 1, cols = 1, quality = "white",  value = 242,  weight = 2,  desc = "内衬脱胶的骑行头盔",                   image = IMG .. "交通/旧头盔.png" },
    { name = "破轮胎",       rows = 2, cols = 2, quality = "white",  value = 105,  weight = 2,  desc = "开裂的电动车真空胎",                   image = IMG .. "交通/破轮胎.png" },
    { name = "旧车载充电器", rows = 1, cols = 1, quality = "white",  value = 105,  weight = 3,  desc = "接口松动的点烟器充电头",               image = IMG .. "交通/旧车载充电器.png" },
    { name = "废弃反光镜",   rows = 1, cols = 1, quality = "white",  value = 105,  weight = 2,  desc = "碎了一角的电动车后视镜",               image = IMG .. "交通/废弃反光镜.png" },
    { name = "旧行车记录仪", rows = 1, cols = 1, quality = "white",  value = 335,  weight = 1,  desc = "屏幕花了的行车记录仪",                 image = IMG .. "交通/旧行车记录仪.png" },
    { name = "锈蚀链条",     rows = 1, cols = 2, quality = "white",  value = 105,  weight = 2,  desc = "锈得拉不动的自行车链条",               image = IMG .. "交通/锈蚀链条.png" },
    { name = "旧车牌框",     rows = 1, cols = 2, quality = "white",  value = 105,  weight = 3,  desc = "变形的铝合金车牌框",                   image = IMG .. "交通/旧车牌框.png" },
    { name = "旧仪表壳",     rows = 1, cols = 2, quality = "white",  value = 529,  weight = 1,  desc = "拆下来的电动摩托仪表面板",             image = IMG .. "交通/旧仪表壳.png" },
    -- 绿 ×8
    { name = "电动滑板车电池", rows = 1, cols = 2, quality = "green", value = 1035, weight = 1,  desc = "容量衰减的锂电池包",                   image = IMG .. "交通/电动滑板车电池.png" },
    { name = "旧GPS导航仪",  rows = 1, cols = 1, quality = "green",  value = 374,  weight = 2,  desc = "地图过期但屏幕还亮的导航仪",           image = IMG .. "交通/旧GPS导航仪.png" },
    { name = "碳纤维车架",   rows = 3, cols = 2, quality = "green",  value = 2604, weight = 1,  desc = "有暗裂的碳纤维自行车架",               image = IMG .. "交通/碳纤维车架.png" },
    { name = "旧行车电脑",   rows = 1, cols = 1, quality = "green",  value = 560,  weight = 2,  desc = "码表功能正常的骑行电脑",               image = IMG .. "交通/旧行车电脑.png" },
    { name = "电动车控制器", rows = 1, cols = 2, quality = "green",  value = 1324, weight = 1,  desc = "电动两轮车的主控制器",                 image = IMG .. "交通/电动车控制器.png" },
    { name = "旧赛车座椅",   rows = 2, cols = 3, quality = "green",  value = 1994, weight = 1,  desc = "布面磨损的运动桶椅",                   image = IMG .. "交通/旧赛车座椅.png",  tags = {"automotive"} },
    { name = "排气管总成",   rows = 3, cols = 1, quality = "green",  value = 793,  weight = 2,  desc = "改装摩托车的钛合金排气管",             image = IMG .. "交通/排气管总成.png",  tags = {"automotive"} },
    { name = "旧车载音响",   rows = 2, cols = 2, quality = "green",  value = 1178, weight = 1,  desc = "拆车件的品牌功放和喇叭",               image = IMG .. "交通/旧车载音响.png" },
    -- 蓝 ×5
    { name = "电动汽车电池模组",   rows = 2, cols = 3, quality = "blue",   value = 3428, weight = 1,  desc = "拆解的三元锂电池模组",                 image = IMG .. "交通/电动汽车电池模组.png",       tags = {"automotive"} },
    { name = "碳陶刹车盘",         rows = 2, cols = 2, quality = "blue",   value = 2169, weight = 2,  desc = "有磨损纹的碳陶制动盘",                 image = IMG .. "交通/碳陶刹车盘.png",             tags = {"automotive"} },
    { name = "旧涡轮增压器",       rows = 2, cols = 2, quality = "blue",   value = 5000, weight = 1,  desc = "叶片完好的废气涡轮",                   image = IMG .. "交通/旧涡轮增压器.png",           tags = {"automotive"} },
    { name = "自动驾驶传感器套件", rows = 2, cols = 2, quality = "blue",   value = 2703, weight = 2,  desc = "激光雷达+摄像头的车顶模组",           image = IMG .. "交通/自动驾驶传感器套件.png",     tags = {"automotive"} },
    { name = "赛车方向盘",         rows = 1, cols = 2, quality = "blue",   value = 1444, weight = 2,  desc = "碳纤维平底方向盘，按钮齐全",           image = IMG .. "交通/赛车方向盘.png",             tags = {"automotive"} },
    -- 紫 ×5
    { name = "电动汽车驱动电机",   rows = 3, cols = 3, quality = "purple", value = 16616, weight = 1,  desc = "永磁同步驱动电机总成",                 image = IMG .. "交通/电动汽车驱动电机.png",       tags = {"automotive"} },
    { name = "自动驾驶计算平台",   rows = 2, cols = 3, quality = "purple", value = 22771, weight = 1,  desc = "车载AI计算盒，芯片完好",               image = IMG .. "交通/自动驾驶计算平台.png",       tags = {"automotive"} },
    { name = "碳纤维车身面板",     rows = 4, cols = 3, quality = "purple", value = 11888, weight = 2,  desc = "轻量化碳纤维车门外板",                 image = IMG .. "交通/碳纤维车身面板.png",         tags = {"automotive"} },
    { name = "老自行车铃",         rows = 1, cols = 1, quality = "purple", value = 2559,  weight = 4,  desc = "永久牌自行车的黄铜铃铛，声音清脆",     image = IMG .. "交通/老自行车铃.png" },
    { name = "马车灯",             rows = 1, cols = 1, quality = "purple", value = 6864,  weight = 2,  desc = "欧式马车用的煤油提灯，铜框玻璃罩",     image = IMG .. "交通/马车灯.png" },
    -- 金 ×8
    { name = "电动超跑轮毂套装", rows = 2, cols = 2, quality = "gold", value = 61171,  weight = 3,  desc = "锻造铝合金轮毂四件套，限量编号",       image = IMG .. "交通/电动超跑轮毂套装.png",       tags = {"automotive"} },
    { name = "固态电池原型模组", rows = 3, cols = 2, quality = "gold", value = 105941, weight = 2,  desc = "实验室的全固态电池原型，能量密度远超量产品", image = IMG .. "交通/固态电池原型模组.png",   tags = {"automotive"} },
    { name = "老式船钟",         rows = 1, cols = 1, quality = "gold", value = 29686,  weight = 6,  desc = "黄铜航海船钟，八日走时机芯",           image = IMG .. "交通/老式船钟.png",               tags = {"maritime", "horology"} },
    { name = "蒸汽机车铭牌",     rows = 2, cols = 1, quality = "gold", value = 35450,  weight = 5,  desc = "'前进'型蒸汽机车的原装铸铁铭牌",     image = IMG .. "交通/蒸汽机车铭牌.png" },
    { name = "劳斯莱斯飞翼天使", rows = 1, cols = 1, quality = "gold", value = 151412, weight = 1,  desc = "银魅车型原装的纯银立标'欢庆女神'",   image = IMG .. "交通/劳斯莱斯飞翼天使.png",       tags = {"automotive"} },
    { name = "老式摩托油箱",     rows = 2, cols = 1, quality = "gold", value = 14769,  weight = 11, desc = "幸福牌摩托车原装油箱，漆面斑驳",       image = IMG .. "交通/老式摩托油箱.png",           tags = {"automotive"} },
    { name = "黄铜船锚模型",     rows = 1, cols = 1, quality = "gold", value = 22328,  weight = 8,  desc = "实心黄铜打造的等比船锚模型",           image = IMG .. "交通/黄铜船锚模型.png",           tags = {"maritime"} },
    { name = "蒸汽火车汽笛",     rows = 1, cols = 2, quality = "gold", value = 15235,  weight = 11, desc = "铜质三管蒸汽火车汽笛，可吹响",         image = IMG .. "交通/蒸汽火车汽笛.png" },
    -- 红 ×9
    { name = "飞行汽车原型引擎",   rows = 4, cols = 3, quality = "red", value = 6061058,  weight = 3,   desc = "eVTOL飞行汽车的电驱动力总成，仅存三台的工程样机", image = IMG .. "交通/飞行汽车原型引擎.png",  tags = {"automotive", "aerospace"} },
    { name = "协和号驾驶舱仪表盘", rows = 3, cols = 3, quality = "red", value = 1956811,  weight = 11,  desc = "协和号超音速客机退役拆解的完整驾驶仪表盘", image = IMG .. "交通/协和号驾驶舱仪表盘.png", tags = {"aerospace"} },
    { name = "一级方程式赛车引擎", rows = 4, cols = 3, quality = "red", value = 8762931,  weight = 2,   desc = "法拉利F1赛车的V10引擎总成，可运转",   image = IMG .. "交通/一级方程式赛车引擎.png",     tags = {"automotive"} },
    { name = "古董摩托车",         rows = 3, cols = 2, quality = "red", value = 122793,   weight = 195, desc = "长江750边三轮摩托，可修复运转",         image = IMG .. "交通/古董摩托车.png",             tags = {"automotive"} },
    { name = "老式火车模型",       rows = 2, cols = 3, quality = "red", value = 957587,   weight = 23,  desc = "蒸汽火车1:10铜制精密模型，可喷蒸汽",   image = IMG .. "交通/老式火车模型.png" },
    { name = "老式马车车轮",       rows = 2, cols = 2, quality = "red", value = 122793,   weight = 195, desc = "欧式四轮马车的铁箍木轮，雕花轮毂",     image = IMG .. "交通/老式马车车轮.png" },
    { name = "帆船铜舵轮",         rows = 2, cols = 2, quality = "red", value = 390682,   weight = 58,  desc = "大型帆船的黄铜包木舵轮，八辐设计",     image = IMG .. "交通/帆船铜舵轮.png",             tags = {"maritime"} },
    { name = "老船用铜钟",         rows = 1, cols = 1, quality = "purple", value = 2233,  weight = 5,   desc = "轮船甲板的报时铜钟，声音洪亮",         image = IMG .. "交通/老船用铜钟.png",             tags = {"maritime", "horology"} },
    { name = "旧火车钟",           rows = 1, cols = 1, quality = "purple", value = 3752,  weight = 3,   desc = "铁路车站挂钟，黑色铸铁壳",             image = IMG .. "交通/旧火车钟.png",               tags = {"horology"} },
    -- 紫（补充）
    { name = "老马鞍",             rows = 2, cols = 2, quality = "purple", value = 5913,  weight = 3,   desc = "牛皮马鞍，铜扣件齐全",                 image = IMG .. "交通/老马鞍.png" },
    { name = "航海羊皮地图",       rows = 1, cols = 2, quality = "gold",   value = 24842, weight = 7,   desc = "手绘的旧航海图，标注了老航线",         image = IMG .. "交通/航海羊皮地图.png",           tags = {"maritime"} },

    -- ===== DataCenter 赛博交通物品 =====
    { name = "飞行摩托引擎",     rows = 2, cols = 2, quality = "purple", value = 42000,  desc = "电动垂直起降摩托的矢量推力引擎",         image = IMG .. "交通/飞行摩托涡扇引擎.png",  tags = {"aerospace"} },
    { name = "追光者引擎原型",     rows = 3, cols = 3, quality = "red",    value = 28000000, desc = "实验性空间弯曲推进系统，功率不足",      image = IMG .. "交通/追光者引擎原型.png",    tags = {"aerospace"} },
    -- ===== 新增数据中心物品 =====
    { name = "深渊之眼监控核心", rows = 2, cols = 2, quality = "purple", value = 75000, desc = "深海无人探测器的核心监控模块", image = IMG .. "交通/深渊之眼监控核心.png",         tags = {"maritime"} },

}

return Transport
