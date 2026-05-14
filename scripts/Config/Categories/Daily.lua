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

    -- ===== 食品杂货系列 =====
    -- 白 ×5
    { name = "过期罐头",           rows = 1, cols = 1, quality = "white",  value = 84,     desc = "生锈变鼓的进口番茄罐头",                               image = IMG .. "日用/过期罐头.png" },
    { name = "散装方便面",         rows = 1, cols = 2, quality = "white",  value = 105,    desc = "没有料包的散装方便面一把",                             image = IMG .. "日用/散装方便面.png" },
    { name = "发霉茶砖",           rows = 1, cols = 2, quality = "white",  value = 147,    desc = "受潮长白毛的老式压制砖茶",                             image = IMG .. "日用/发霉茶砖.png" },
    { name = "腐坏香辛料",         rows = 1, cols = 1, quality = "white",  value = 98,     desc = "结块发潮的进口胡椒粉铁罐",                             image = IMG .. "日用/腐坏香辛料.png" },
    { name = "碎饼干袋",           rows = 1, cols = 2, quality = "white",  value = 77,     desc = "压碎了的进口黄油饼干一袋",                             image = IMG .. "日用/碎饼干袋.png" },
    -- 绿 ×5
    { name = "特级初榨橄榄油",     rows = 1, cols = 1, quality = "green",  value = 680,    desc = "西班牙产特级初榨橄榄油，500ml暗色玻璃瓶",             image = IMG .. "日用/特级初榨橄榄油.png" },
    { name = "麦卢卡蜂蜜礼盒",     rows = 1, cols = 2, quality = "green",  value = 920,    desc = "新西兰麦卢卡蜂蜜礼盒，附天然蜂巢一块",               image = IMG .. "日用/麦卢卡蜂蜜礼盒.png" },
    { name = "古树普洱散茶",       rows = 1, cols = 1, quality = "green",  value = 760,    desc = "百年古树春茶散料，密封铁罐装，附产地证",               image = IMG .. "日用/古树普洱散茶.png" },
    { name = "宇治抹茶礼盒",       rows = 1, cols = 2, quality = "green",  value = 840,    desc = "日本宇治仪式级抹茶粉，60g铁罐礼盒装",                 image = IMG .. "日用/宇治抹茶礼盒.png" },
    { name = "喜马拉雅粉盐块",     rows = 1, cols = 1, quality = "green",  value = 580,    desc = "整块喜马拉雅玫瑰岩盐，附木盒和研磨器",               image = IMG .. "日用/喜马拉雅粉盐块.png" },
    -- 蓝 ×4
    { name = "法国黑松露罐头",     rows = 1, cols = 1, quality = "blue",   value = 3200,   desc = "产自佩里戈尔的整颗黑松露罐头，夏季采摘",               image = IMG .. "日用/法国黑松露罐头.png" },
    { name = "伊比利亚火腿",       rows = 2, cols = 3, quality = "blue",   value = 5800,   desc = "48个月陈化的伊比利亚橡果喂养前腿火腿",                 image = IMG .. "日用/伊比利亚火腿.png" },
    { name = "帕玛森干酪整块",     rows = 1, cols = 2, quality = "blue",   value = 2400,   desc = "36个月陈化帕玛森干酪原块，约1.5kg",                   image = IMG .. "日用/帕玛森干酪整块.png" },
    { name = "皇家鱼子酱小罐",     rows = 1, cols = 1, quality = "blue",   value = 4600,   desc = "俄罗斯星鲟鱼子酱，30g原装锡罐密封",                   image = IMG .. "日用/皇家鱼子酱小罐.png" },
    -- 紫 ×3
    { name = "正宗白松露",         rows = 1, cols = 1, quality = "purple", value = 18000,  desc = "意大利阿尔巴产白松露，真空密封，附产地认证证书",       image = IMG .. "日用/正宗白松露.png" },
    { name = "顶级藏红花礼盒",     rows = 1, cols = 1, quality = "purple", value = 12500,  desc = "伊朗科尔霍拉桑顶级藏红花，5g黄金礼盒装",               image = IMG .. "日用/顶级藏红花礼盒.png" },
    { name = "极品大闸蟹礼盒",     rows = 2, cols = 2, quality = "purple", value = 15800,  desc = "阳澄湖极品大闸蟹干腌礼盒，附防伪溯源码证书",           image = IMG .. "日用/极品大闸蟹礼盒.png" },
    -- 金 ×3
    { name = "野生冬虫夏草",       rows = 1, cols = 1, quality = "gold",   value = 68000,  desc = "西藏那曲野生冬虫夏草，30条正品礼盒，附检测报告",       image = IMG .. "日用/野生冬虫夏草.png" },
    { name = "老班章普洱生饼",     rows = 1, cols = 2, quality = "gold",   value = 45000,  desc = "2003年老班章单株古树春茶生饼，附多枚藏家钤印证书",     image = IMG .. "日用/老班章普洱生饼.png" },
    { name = "顶级和牛干货礼盒",   rows = 2, cols = 2, quality = "gold",   value = 38000,  desc = "A5级神户和牛风干牛肉礼盒，限量木箱装，附认证书",       image = IMG .. "日用/顶级和牛干货礼盒.png" },
    -- 红 ×2
    { name = "宫廷贡茶孤本",       rows = 1, cols = 2, quality = "red",    value = 380000, desc = "疑似清宫档案记载的皇室贡茶残饼，附多份考证资料",       image = IMG .. "日用/宫廷贡茶孤本.png" },
    { name = "传世古树普洱生茶",   rows = 2, cols = 2, quality = "red",    value = 650000, desc = "清末百年古树头春正山手工制饼，附多位资深藏家证书",     image = IMG .. "日用/传世古树普洱生茶.png" },

    -- ===== 家居快消系列 =====
    -- 白 ×5
    { name = "碎陶瓷杯",           rows = 1, cols = 1, quality = "white",  value = 70,     desc = "磕了缺口的白瓷马克杯",                                 image = IMG .. "日用/碎陶瓷杯.png" },
    { name = "旧香皂盒",           rows = 1, cols = 1, quality = "white",  value = 84,     desc = "发霉的塑料肥皂盒，里面还有半块旧皂",                   image = IMG .. "日用/旧香皂盒.png" },
    { name = "破损台历",           rows = 1, cols = 2, quality = "white",  value = 105,    desc = "纸面破损的老式木座台历，日期停在过去",                 image = IMG .. "日用/破损台历.png" },
    { name = "磨损浴室拖鞋",       rows = 1, cols = 2, quality = "white",  value = 98,     desc = "鞋底快磨平的廉价浴室拖鞋一双",                         image = IMG .. "日用/磨损浴室拖鞋.png" },
    { name = "废弃橡皮手套",       rows = 1, cols = 1, quality = "white",  value = 63,     desc = "老化开裂的橡胶洗碗手套一副",                           image = IMG .. "日用/废弃橡皮手套.png" },
    -- 绿 ×5
    { name = "复古发条闹钟",       rows = 1, cols = 1, quality = "green",  value = 780,    desc = "双铃圆顶机械发条闹钟，还能准时响",                     image = IMG .. "日用/复古发条闹钟.png" },
    { name = "铜制烟灰缸",         rows = 1, cols = 1, quality = "green",  value = 640,    desc = "厚实黄铜烟灰缸，底部刻有几何纹饰",                     image = IMG .. "日用/铜制烟灰缸.png" },
    { name = "老式旅行熨斗",       rows = 1, cols = 1, quality = "green",  value = 720,    desc = "折叠式小型旅行熨斗，蒸汽功能仍完好",                   image = IMG .. "日用/老式旅行熨斗.png" },
    { name = "玻璃香皂碟套装",     rows = 1, cols = 2, quality = "green",  value = 540,    desc = "手工吹制磨砂玻璃皂托，三件套原装礼盒",                 image = IMG .. "日用/玻璃香皂碟套装.png" },
    { name = "竹制餐具礼盒",       rows = 1, cols = 2, quality = "green",  value = 860,    desc = "手工竹制筷子+勺+叉三件套，原装礼盒",                   image = IMG .. "日用/竹制餐具礼盒.png" },
    -- 蓝 ×4
    { name = "进口香氛蜡烛礼盒",   rows = 2, cols = 2, quality = "blue",   value = 2800,   desc = "法国圣日耳曼香氛蜡烛礼盒，三种香调",                   image = IMG .. "日用/进口香氛蜡烛礼盒.png" },
    { name = "黄铜剃须套装",       rows = 1, cols = 2, quality = "blue",   value = 3600,   desc = "银尖獾毛剃须刷配黄铜剃须碗，英国手工制",               image = IMG .. "日用/黄铜剃须套装.png" },
    { name = "手工植物香皂礼盒",   rows = 2, cols = 2, quality = "blue",   value = 2200,   desc = "比利时天然植物精油香皂十二宫礼盒",                     image = IMG .. "日用/手工植物香皂礼盒.png" },
    { name = "水晶烟灰缸",         rows = 1, cols = 1, quality = "blue",   value = 4100,   desc = "手工切割波西米亚水晶烟灰缸，重约1.2kg",               image = IMG .. "日用/水晶烟灰缸.png" },
    -- 紫 ×3
    { name = "银制餐具六件套",     rows = 2, cols = 2, quality = "purple", value = 14800,  desc = "英国925纯银餐叉+餐刀+汤匙各一对，皮革收纳盒装",       image = IMG .. "日用/银制餐具六件套.png" },
    { name = "法国珐琅瓷咖啡具",   rows = 2, cols = 2, quality = "purple", value = 11200,  desc = "法国利摩日珐琅瓷咖啡壶附四套杯碟，原装礼盒",           image = IMG .. "日用/法国珐琅瓷咖啡具.png" },
    { name = "大师调香香氛礼盒",   rows = 2, cols = 2, quality = "purple", value = 9600,   desc = "顶级调香师手工制作香氛全系列礼盒，限量50套",           image = IMG .. "日用/大师调香香氛礼盒.png" },
    -- 金 ×3
    { name = "百年雕花海泡石烟斗", rows = 1, cols = 1, quality = "gold",   value = 38000,  desc = "英国邓希尔百年老店雕花海泡石烟斗，附原装皮套",         image = IMG .. "日用/百年雕花海泡石烟斗.png" },
    { name = "皇室骨瓷茶具套装",   rows = 2, cols = 2, quality = "gold",   value = 55000,  desc = "英国皇家御用骨瓷茶具一套，壶杯碟具齐全，附王室徽记证书", image = IMG .. "日用/皇室骨瓷茶具套装.png" },
    { name = "维多利亚纯银咖啡具", rows = 2, cols = 2, quality = "gold",   value = 72000,  desc = "维多利亚时代英国纯银咖啡壶+糖缸+奶壶套装，附鉴定证书", image = IMG .. "日用/维多利亚纯银咖啡具.png" },
    -- 红 ×2
    { name = "御用银丝梳妆套盒",   rows = 2, cols = 2, quality = "red",    value = 180000, desc = "欧洲皇室御用纯银梳妆套盒，镶嵌宝石，附皇室档案证书",   image = IMG .. "日用/御用银丝梳妆套盒.png" },
    { name = "清宫纯银火锅",       rows = 3, cols = 3, quality = "red",    value = 420000, desc = "清朝宫廷御用纯银丝工火锅，八仙过海纹饰，附宫廷档案",   image = IMG .. "日用/清宫纯银火锅.png" },
}

return Daily
