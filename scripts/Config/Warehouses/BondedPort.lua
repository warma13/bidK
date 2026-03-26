-- ============================================================================
-- Config/Warehouses/BondedPort.lua - 港口保税区物品配置
-- 港口独有品类：洋酒烟草（29件）
-- 通过 WarehouseGenerator 合并 ItemPool 共享物品池使用
-- value 即最终价格，无稀有度乘数
-- ============================================================================

local BondedPort = {}

-- 品类权重（港口保税区：通用品类 + 独有的洋酒烟草）
BondedPort.categoryWeights = {
    antique    = 15,   -- 古董：国际走私古董时有截获
    energy     = 5,    -- 能源：港口能源物品较少
    tech       = 15,   -- 科技：电子产品是国际货运大宗
    art        = 10,   -- 艺术：艺术品跨境运输常见
    jewel      = 12,   -- 珠宝：海关截获珠宝走私常见
    mechanical = 13,   -- 机械：进口工业设备/精密仪器
    transport  = 10,   -- 交通：滞留进口车辆零件
    liquor     = 20,   -- 洋酒烟草：港口独有品类
}

local IMG = "items/洋酒烟草/"

-- ============================================================================
-- 洋酒烟草  (29件)
-- 来源：海关截获的走私烟酒、超期未提的进口酒水、货主弃货的免税品集装箱
-- ============================================================================
BondedPort.liquor = {
    -- 白 ×10
    { name = "碎酒瓶",       rows = 1, cols = 1, quality = "white",  value = 5,       desc = "运输途中碎了的红酒瓶，只剩瓶底",               image = IMG .. "碎酒瓶.png" },
    { name = "空雪茄盒",     rows = 1, cols = 2, quality = "white",  value = 15,      desc = "古巴雪茄木盒，里面空的",                       image = IMG .. "空雪茄盒.png" },
    { name = "过期烟条",     rows = 1, cols = 3, quality = "white",  value = 25,      desc = "受潮发霉的整条外烟",                           image = IMG .. "过期烟条.png" },
    { name = "散装茶包",     rows = 1, cols = 1, quality = "white",  value = 10,      desc = "破了包装的锡兰红茶袋",                         image = IMG .. "散装茶包.png" },
    { name = "烂软木塞",     rows = 1, cols = 1, quality = "white",  value = 3,       desc = "发霉膨胀的红酒软木塞",                         image = IMG .. "烂软木塞.png" },
    { name = "破酒杯",       rows = 1, cols = 1, quality = "white",  value = 8,       desc = "缺了口的玻璃高脚杯",                           image = IMG .. "破酒杯.png" },
    { name = "旧开瓶器",     rows = 1, cols = 1, quality = "white",  value = 20,      desc = "生锈的海马刀开瓶器",                           image = IMG .. "旧开瓶器.png" },
    { name = "褪色酒标",     rows = 1, cols = 1, quality = "white",  value = 5,       desc = "从酒瓶上脱落的纸质酒标",                       image = IMG .. "褪色酒标.png" },
    { name = "空威士忌瓶",   rows = 1, cols = 1, quality = "white",  value = 30,      desc = "空的威士忌玻璃瓶，造型好看",                   image = IMG .. "空威士忌瓶.png" },
    { name = "发霉烟丝",     rows = 1, cols = 1, quality = "white",  value = 12,      desc = "铁罐装烟斗丝，打开全是霉味",                   image = IMG .. "发霉烟丝.png" },
    -- 绿 ×8
    { name = "法国白兰地",   rows = 1, cols = 1, quality = "green",  value = 180,     desc = "普通年份的法国白兰地，标签完好",               image = IMG .. "法国白兰地.png" },
    { name = "古巴雪茄（半盒）", rows = 1, cols = 2, quality = "green", value = 250,  desc = "半盒哈瓦那雪茄，保湿袋还在",                   image = IMG .. "古巴雪茄（半盒）.png" },
    { name = "日本清酒礼盒", rows = 2, cols = 2, quality = "green",  value = 300,     desc = "大吟酿清酒礼盒装，包装完好",                   image = IMG .. "日本清酒礼盒.png" },
    { name = "苏格兰威士忌", rows = 1, cols = 1, quality = "green",  value = 220,     desc = "12年单一麦芽，铁盒微凹",                       image = IMG .. "苏格兰威士忌.png" },
    { name = "锡兰红茶铁罐", rows = 1, cols = 1, quality = "green",  value = 150,     desc = "进口锡兰高地红茶，密封铁罐装",                 image = IMG .. "锡兰红茶铁罐.png" },
    { name = "意大利陈醋",   rows = 1, cols = 1, quality = "green",  value = 130,     desc = "摩德纳产传统巴萨米克醋，12年陈",               image = IMG .. "意大利陈醋.png" },
    { name = "波特酒",       rows = 1, cols = 1, quality = "green",  value = 200,     desc = "葡萄牙10年陈酿波特酒，木塞完好",               image = IMG .. "波特酒.png" },
    { name = "烟斗礼盒",     rows = 1, cols = 2, quality = "green",  value = 280,     desc = "石楠木烟斗配皮套，做工精细",                   image = IMG .. "烟斗礼盒.png" },
    -- 蓝 ×5
    { name = "年份波尔多红酒", rows = 1, cols = 1, quality = "blue",  value = 600,    desc = "2005年份波尔多列级庄，酒标完好",               image = IMG .. "年份波尔多红酒.png" },
    { name = "限量版朗姆酒", rows = 1, cols = 1, quality = "blue",    value = 750,    desc = "加勒比限量陈酿朗姆，编号瓶",                   image = IMG .. "限量版朗姆酒.png" },
    { name = "整箱进口雪茄", rows = 2, cols = 3, quality = "blue",    value = 900,    desc = "12支装古巴Cohiba雪茄，密封完好",               image = IMG .. "整箱进口雪茄.png" },
    { name = "冰酒礼盒",     rows = 1, cols = 1, quality = "blue",    value = 500,    desc = "加拿大VQA级冰酒，375ml金标",                   image = IMG .. "冰酒礼盒.png" },
    { name = "年份龙舌兰",   rows = 1, cols = 1, quality = "blue",    value = 650,    desc = "墨西哥陈年龙舌兰，手工吹制玻璃瓶",             image = IMG .. "年份龙舌兰.png" },
    -- 紫 ×5
    { name = "陈年黄酒坛",   rows = 2, cols = 2, quality = "purple",  value = 3000,    desc = "女儿红十年陈酿，坛口封蜡完好",                image = IMG .. "陈年黄酒坛.png" },
    { name = "古巴雪茄单支", rows = 1, cols = 1, quality = "purple",  value = 5000,    desc = "单支Behike限量雪茄，雪茄管密封",              image = IMG .. "古巴雪茄单支.png" },
    { name = "老窖原浆酒",   rows = 1, cols = 1, quality = "purple",  value = 8000,    desc = "泸州老窖原浆封坛酒，窖藏二十年",              image = IMG .. "老窖原浆酒.png" },
    { name = "50年威士忌",   rows = 1, cols = 1, quality = "purple",  value = 85000,   desc = "苏格兰50年单桶威士忌，水晶瓶装",              image = IMG .. "50年威士忌.png" },
    { name = "年份香槟木箱", rows = 2, cols = 3, quality = "purple",  value = 120000,  desc = "6瓶装唐培里侬年份香槟，原木箱封条完好",        image = IMG .. "年份香槟木箱.png" },
    -- 金 ×5
    { name = "进口雪茄保湿柜", rows = 2, cols = 2, quality = "gold",  value = 5000,    desc = "西班牙雪松木保湿柜，恒温恒湿器完好",          image = IMG .. "进口雪茄保湿柜.png" },
    { name = "单瓶年份红酒", rows = 1, cols = 1, quality = "gold",    value = 8000,    desc = "1990年拉菲副牌，酒标完好软木塞紧实",          image = IMG .. "单瓶年份红酒.png" },
    { name = "日本限定清酒", rows = 1, cols = 1, quality = "gold",    value = 12000,   desc = "十四代龙泉大吟酿，木箱密封未拆",              image = IMG .. "日本限定清酒.png" },
    { name = "百年干邑白兰地", rows = 1, cols = 1, quality = "gold",  value = 18000,   desc = "1920年代干邑白兰地，蜡封完好",                image = IMG .. "百年干邑白兰地.png" },
    { name = "限量版茅台",   rows = 1, cols = 1, quality = "gold",    value = 45000,   desc = "80年代出口特供茅台，编号瓶身",                image = IMG .. "限量版茅台.png" },
    -- 红 ×4
    { name = "整箱进口红酒", rows = 2, cols = 3, quality = "red",     value = 80000,   desc = "12瓶装波尔多列级庄红酒，原箱未拆",            image = IMG .. "整箱进口红酒.png" },
    { name = "百年陈酿白兰地", rows = 1, cols = 1, quality = "red",   value = 150000,  desc = "1900年代法国白兰地，蜡封瓶口完好",            image = IMG .. "百年陈酿白兰地.png" },
    { name = "整箱年份茅台", rows = 3, cols = 3, quality = "red",     value = 350000,  desc = "1970年代出口茅台原箱12瓶，海关扣押未拆封",    image = IMG .. "整箱年份茅台.png" },
    { name = "沉船打捞香槟", rows = 2, cols = 2, quality = "red",     value = 800000,  desc = "波罗的海沉船打捞的19世纪凯歌香槟，海水浸泡后风味独特", image = IMG .. "沉船打捞香槟.png" },
}

-- 品类列表（仅包含独有品类，通用品类通过 WarehouseGenerator 合并 ItemPool）
BondedPort.categories = {
    { id = "liquor", name = "烟酒", icon = "", items = BondedPort.liquor },
}

return BondedPort
