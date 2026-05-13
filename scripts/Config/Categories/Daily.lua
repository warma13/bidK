-- ============================================================================
-- Config/Categories/Daily.lua - 日用品类物品定义
-- 来源：BondedPort（港口保税区独有品类：洋酒烟草）
-- ============================================================================

local Daily = {}

local IMG = "items/"

Daily.items = {
    -- 白 ×10
    { name = "碎酒瓶",       rows = 1, cols = 1, quality = "white",  value = 105,    desc = "运输途中碎了的红酒瓶，只剩瓶底",               image = IMG .. "日用/碎酒瓶.png" },
    { name = "空雪茄盒",     rows = 1, cols = 2, quality = "white",  value = 211,    desc = "古巴雪茄木盒，里面空的",                       image = IMG .. "日用/空雪茄盒.png" },
    { name = "过期烟条",     rows = 1, cols = 3, quality = "white",  value = 351,    desc = "受潮发霉的整条外烟",                           image = IMG .. "日用/过期烟条.png" },
    { name = "散装茶包",     rows = 1, cols = 1, quality = "white",  value = 140,    desc = "破了包装的锡兰红茶袋",                         image = IMG .. "日用/散装茶包.png" },
    { name = "烂软木塞",     rows = 1, cols = 1, quality = "white",  value = 105,    desc = "发霉膨胀的红酒软木塞",                         image = IMG .. "日用/烂软木塞.png" },
    { name = "破酒杯",       rows = 1, cols = 1, quality = "white",  value = 112,    desc = "缺了口的玻璃高脚杯",                           image = IMG .. "日用/破酒杯.png" },
    { name = "旧开瓶器",     rows = 1, cols = 1, quality = "white",  value = 281,    desc = "生锈的海马刀开瓶器",                           image = IMG .. "日用/旧开瓶器.png" },
    { name = "褪色酒标",     rows = 1, cols = 1, quality = "white",  value = 105,    desc = "从酒瓶上脱落的纸质酒标",                       image = IMG .. "日用/褪色酒标.png" },
    { name = "空威士忌瓶",   rows = 1, cols = 1, quality = "white",  value = 421,    desc = "空的威士忌玻璃瓶，造型好看",                   image = IMG .. "日用/空威士忌瓶.png" },
    { name = "发霉烟丝",     rows = 1, cols = 1, quality = "white",  value = 168,    desc = "铁罐装烟斗丝，打开全是霉味",                   image = IMG .. "日用/发霉烟丝.png" },
    -- 绿 ×8
    { name = "法国白兰地",       rows = 1, cols = 1, quality = "green",  value = 758,   desc = "普通年份的法国白兰地，标签完好",               image = IMG .. "日用/法国白兰地.png" },
    { name = "古巴雪茄（半盒）", rows = 1, cols = 2, quality = "green",  value = 1053,  desc = "半盒哈瓦那雪茄，保湿袋还在",                   image = IMG .. "日用/古巴雪茄（半盒）.png" },
    { name = "日本清酒礼盒",     rows = 2, cols = 2, quality = "green",  value = 1263,  desc = "大吟酿清酒礼盒装，包装完好",                   image = IMG .. "日用/日本清酒礼盒.png" },
    { name = "苏格兰威士忌",     rows = 1, cols = 1, quality = "green",  value = 926,   desc = "12年单一麦芽，铁盒微凹",                       image = IMG .. "日用/苏格兰威士忌.png" },
    { name = "锡兰红茶铁罐",     rows = 1, cols = 1, quality = "green",  value = 632,   desc = "进口锡兰高地红茶，密封铁罐装",                 image = IMG .. "日用/锡兰红茶铁罐.png" },
    { name = "意大利陈醋",       rows = 1, cols = 1, quality = "green",  value = 547,   desc = "摩德纳产传统巴萨米克醋，12年陈",               image = IMG .. "日用/意大利陈醋.png" },
    { name = "波特酒",           rows = 1, cols = 1, quality = "green",  value = 842,   desc = "葡萄牙10年陈酿波特酒，木塞完好",               image = IMG .. "日用/波特酒.png" },
    { name = "烟斗礼盒",         rows = 1, cols = 2, quality = "green",  value = 1179,  desc = "石楠木烟斗配皮套，做工精细",                   image = IMG .. "日用/烟斗礼盒.png" },
    -- 蓝 ×5
    { name = "年份波尔多红酒", rows = 1, cols = 1, quality = "blue",    value = 2647,  desc = "2005年份波尔多列级庄，酒标完好",               image = IMG .. "日用/年份波尔多红酒.png" },
    { name = "限量版朗姆酒",   rows = 1, cols = 1, quality = "blue",    value = 3309,  desc = "加勒比限量陈酿朗姆，编号瓶",                   image = IMG .. "日用/限量版朗姆酒.png" },
    { name = "整箱进口雪茄",   rows = 2, cols = 3, quality = "blue",    value = 3971,  desc = "12支装古巴Cohiba雪茄，密封完好",               image = IMG .. "日用/整箱进口雪茄.png" },
    { name = "冰酒礼盒",       rows = 1, cols = 1, quality = "blue",    value = 2206,  desc = "加拿大VQA级冰酒，375ml金标",                   image = IMG .. "日用/冰酒礼盒.png" },
    { name = "年份龙舌兰",     rows = 1, cols = 1, quality = "blue",    value = 2868,  desc = "墨西哥陈年龙舌兰，手工吹制玻璃瓶",             image = IMG .. "日用/年份龙舌兰.png" },
    -- 紫 ×5
    { name = "陈年黄酒坛",   rows = 2, cols = 2, quality = "purple",  value = 611,    desc = "女儿红十年陈酿，坛口封蜡完好",                image = IMG .. "日用/陈年黄酒坛.png" },
    { name = "古巴雪茄单支", rows = 1, cols = 1, quality = "purple",  value = 1018,   desc = "单支Behike限量雪茄，雪茄管密封",              image = IMG .. "日用/古巴雪茄单支.png" },
    { name = "老窖原浆酒",   rows = 1, cols = 1, quality = "purple",  value = 1629,   desc = "泸州老窖原浆封坛酒，窖藏二十年",              image = IMG .. "日用/老窖原浆酒.png" },
    { name = "50年威士忌",   rows = 1, cols = 1, quality = "purple",  value = 17308,  desc = "苏格兰50年单桶威士忌，水晶瓶装",              image = IMG .. "日用/50年威士忌.png" },
    { name = "年份香槟木箱", rows = 2, cols = 3, quality = "purple",  value = 24434,  desc = "6瓶装唐培里侬年份香槟，原木箱封条完好",        image = IMG .. "日用/年份香槟木箱.png" },
    -- 金 ×5
    { name = "进口雪茄保湿柜", rows = 2, cols = 2, quality = "gold",  value = 14205,  desc = "西班牙雪松木保湿柜，恒温恒湿器完好",          image = IMG .. "日用/进口雪茄保湿柜.png" },
    { name = "单瓶年份红酒",   rows = 1, cols = 1, quality = "gold",  value = 22727,  desc = "1990年拉菲副牌，酒标完好软木塞紧实",          image = IMG .. "日用/单瓶年份红酒.png" },
    { name = "日本限定清酒",   rows = 1, cols = 1, quality = "gold",  value = 34091,  desc = "十四代龙泉大吟酿，木箱密封未拆",              image = IMG .. "日用/日本限定清酒.png" },
    { name = "百年干邑白兰地", rows = 1, cols = 1, quality = "gold",  value = 51136,  desc = "1920年代干邑白兰地，蜡封完好",                image = IMG .. "日用/百年干邑白兰地.png" },
    { name = "限量版茅台",     rows = 1, cols = 1, quality = "gold",  value = 127841, desc = "80年代出口特供茅台，编号瓶身",                image = IMG .. "日用/限量版茅台.png" },
    -- 红 ×4
    { name = "整箱进口红酒",   rows = 2, cols = 3, quality = "red",   value = 80000,  desc = "12瓶装波尔多列级庄红酒，原箱未拆",            image = IMG .. "日用/整箱进口红酒.png" },
    { name = "百年陈酿白兰地", rows = 1, cols = 1, quality = "red",   value = 150000, desc = "1900年代法国白兰地，蜡封瓶口完好",            image = IMG .. "日用/百年陈酿白兰地.png" },
    { name = "整箱年份茅台",   rows = 3, cols = 3, quality = "red",   value = 350000, desc = "1970年代出口茅台原箱12瓶，海关扣押未拆封",    image = IMG .. "日用/整箱年份茅台.png" },
    { name = "沉船打捞香槟",   rows = 2, cols = 2, quality = "red",   value = 800000, desc = "波罗的海沉船打捞的19世纪凯歌香槟，海水浸泡后风味独特", image = IMG .. "日用/沉船打捞香槟.png" },
}

return Daily
