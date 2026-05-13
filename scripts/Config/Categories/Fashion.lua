-- ============================================================================
-- Config/Categories/Fashion.lua - 服饰奢品品类物品定义
-- 来源：时尚品牌服饰、设计师单品、奢华配饰
-- ============================================================================

local Fashion = {}

local IMG = "items/"

Fashion.items = {
    -- 白 ×12
    { name = "廉价皮带",         rows = 1, cols = 2, quality = "white",  value = 88,    desc = "合成革材质，扣头镀层已脱落",                     image = IMG .. "服饰/廉价皮带.png" },
    { name = "旧款太阳镜",       rows = 1, cols = 2, quality = "white",  value = 105,   desc = "过时款式的塑料框墨镜，镜片有划痕",               image = IMG .. "服饰/旧款太阳镜.png" },
    { name = "合成纤维围巾",     rows = 1, cols = 2, quality = "white",  value = 126,   desc = "化纤材质，洗后起球严重",                         image = IMG .. "服饰/合成纤维围巾.png" },
    { name = "仿品牌帆布包",     rows = 2, cols = 2, quality = "white",  value = 210,   desc = "低仿版帆布托特包，针脚歪斜",                     image = IMG .. "服饰/仿品牌帆布包.png" },
    { name = "廉价印花T恤",      rows = 1, cols = 2, quality = "white",  value = 77,    desc = "批发市场同款印花短袖，洗后褪色",                 image = IMG .. "服饰/廉价印花T恤.png" },
    { name = "旧款领带",         rows = 1, cols = 1, quality = "white",  value = 140,   desc = "涤纶材质，图案过时，有轻微油渍",                 image = IMG .. "服饰/旧款领带.png" },
    { name = "过期香水",         rows = 1, cols = 1, quality = "white",  value = 168,   desc = "香调已经变质，瓶身完好但香味全变",               image = IMG .. "服饰/过期香水.png" },
    { name = "仿制耳环",         rows = 1, cols = 1, quality = "white",  value = 95,    desc = "合金材质仿珍珠耳环，镀层已掉",                   image = IMG .. "服饰/仿制耳环.png" },
    { name = "过季棉麻风衣",     rows = 2, cols = 2, quality = "white",  value = 280,   desc = "三年前款式，棉麻混纺，扣子略松",                 image = IMG .. "服饰/过季棉麻风衣.png" },
    { name = "褪色牛仔夹克",     rows = 2, cols = 2, quality = "white",  value = 245,   desc = "洗旧色的牛仔外套，缝线有开线迹象",               image = IMG .. "服饰/褪色牛仔夹克.png" },
    { name = "二手皮革手提包",   rows = 2, cols = 2, quality = "white",  value = 350,   desc = "二手皮包，内衬破损，外皮磨损明显",               image = IMG .. "服饰/二手皮革手提包.png" },
    { name = "合成材质运动鞋",   rows = 1, cols = 2, quality = "white",  value = 196,   desc = "人造革面料运动鞋，气垫已失效",                   image = IMG .. "服饰/合成材质运动鞋.png" },
    -- 绿 ×12
    { name = "限量版滑板鞋",     rows = 1, cols = 2, quality = "green",  value = 780,   desc = "联名限定款帆布滑板鞋，鞋盒完好",                 image = IMG .. "服饰/限量版滑板鞋.png" },
    { name = "真皮商务皮带",     rows = 1, cols = 2, quality = "green",  value = 640,   desc = "意大利小牛皮商务皮带，五金扣光亮",               image = IMG .. "服饰/真皮商务皮带.png" },
    { name = "轻奢真丝丝巾",     rows = 1, cols = 2, quality = "green",  value = 860,   desc = "桑蚕丝印花丝巾，手工卷边工艺",                   image = IMG .. "服饰/轻奢真丝丝巾.png" },
    { name = "潮牌机能外套",     rows = 2, cols = 2, quality = "green",  value = 1120,  desc = "防水透气面料机能外套，拉链顺滑",                 image = IMG .. "服饰/潮牌机能外套.png" },
    { name = "设计师款墨镜",     rows = 1, cols = 2, quality = "green",  value = 920,   desc = "独立设计师品牌偏光墨镜，附原装皮套",             image = IMG .. "服饰/设计师款墨镜.png" },
    { name = "手工编织皮夹",     rows = 1, cols = 1, quality = "green",  value = 740,   desc = "植鞣革手工编织纹路钱夹，卡槽充足",               image = IMG .. "服饰/手工编织皮夹.png" },
    { name = "限量印花卫衣",     rows = 2, cols = 2, quality = "green",  value = 980,   desc = "艺术家联名卫衣，编号签名标签在",                 image = IMG .. "服饰/限量印花卫衣.png" },
    { name = "银质袖扣套装",     rows = 1, cols = 1, quality = "green",  value = 870,   desc = "925纯银袖扣一对，附原装绒布盒",                 image = IMG .. "服饰/银质袖扣套装.png" },
    { name = "轻奢马毛手包",     rows = 1, cols = 2, quality = "green",  value = 1050,  desc = "马毛拼接皮质手包，链条配件做工细腻",             image = IMG .. "服饰/轻奢马毛手包.png" },
    { name = "日系工匠布包",     rows = 2, cols = 2, quality = "green",  value = 830,   desc = "手织帆布搭配真皮提手，职人手工制作",             image = IMG .. "服饰/日系工匠布包.png" },
    { name = "精工牛仔裤",       rows = 2, cols = 2, quality = "green",  value = 760,   desc = "日本职人手工染色牛仔裤，原版布边",               image = IMG .. "服饰/精工牛仔裤.png" },
    { name = "手绣羊毛围巾",     rows = 1, cols = 2, quality = "green",  value = 1180,  desc = "苏格兰羊毛手工刺绣围巾，图案细腻",               image = IMG .. "服饰/手绣羊毛围巾.png" },
    -- 蓝 ×10
    { name = "意大利小牛皮公文包", rows = 2, cols = 2, quality = "blue",  value = 3200,  desc = "全粒面小牛皮手工锁边，铜扣五金件",               image = IMG .. "服饰/意大利小牛皮公文包.png" },
    { name = "顶级羊绒大衣",       rows = 2, cols = 2, quality = "blue",  value = 4600,  desc = "蒙古纯羊绒长款大衣，手工锁扣眼",                 image = IMG .. "服饰/顶级羊绒大衣.png" },
    { name = "品牌机械腕表",       rows = 1, cols = 1, quality = "blue",  value = 5800,  desc = "瑞士机械机芯腕表，蓝宝石镜面无划痕",             image = IMG .. "服饰/品牌机械腕表.png" },
    { name = "高定礼服裙",         rows = 2, cols = 2, quality = "blue",  value = 3900,  desc = "设计师高定工作室礼服，手工钉珠工艺",             image = IMG .. "服饰/高定礼服裙.png" },
    { name = "真皮骑士夹克",       rows = 2, cols = 2, quality = "blue",  value = 2900,  desc = "意大利植鞣革骑士夹克，金属拉链顺滑",             image = IMG .. "服饰/真皮骑士夹克.png" },
    { name = "纯银项链套装",       rows = 1, cols = 2, quality = "blue",  value = 2400,  desc = "925银手工锻打项链，附宝石吊坠一枚",               image = IMG .. "服饰/纯银项链套装.png" },
    { name = "手工棕色皮靴",       rows = 1, cols = 2, quality = "blue",  value = 3500,  desc = "西班牙手工制作切尔西靴，Goodyear沿条工艺",       image = IMG .. "服饰/手工棕色皮靴.png" },
    { name = "品牌皮草披肩",       rows = 2, cols = 2, quality = "blue",  value = 5200,  desc = "进口狐狸毛皮草披肩，附品牌防伪标",               image = IMG .. "服饰/品牌皮草披肩.png" },
    { name = "设计师奢华托特包",   rows = 2, cols = 2, quality = "blue",  value = 4100,  desc = "独立设计师手工缝制托特包，帆布配真皮撞色",       image = IMG .. "服饰/设计师奢华托特包.png" },
    { name = "限定款运动外套",     rows = 2, cols = 2, quality = "blue",  value = 2700,  desc = "运动品牌与艺术家限定联名外套，编号吊牌在",       image = IMG .. "服饰/限定款运动外套.png" },
    -- 紫 ×7
    { name = "顶级定制西装",       rows = 2, cols = 2, quality = "purple", value = 14800, desc = "萨维尔街裁缝全定制西装，手工锁扣眼蒸汽定型",     image = IMG .. "服饰/顶级定制西装.png" },
    { name = "珍稀蟒皮手提包",     rows = 2, cols = 2, quality = "purple", value = 19600, desc = "缅甸蟒蛇皮手工缝制包，金属扣件镀金处理",         image = IMG .. "服饰/珍稀蟒皮手提包.png" },
    { name = "珠宝镶嵌皮腰封",     rows = 1, cols = 2, quality = "purple", value = 12300, desc = "皮质腰封镶嵌多颗宝石，高级定制工坊出品",         image = IMG .. "服饰/珠宝镶嵌皮腰封.png" },
    { name = "皇室礼宾定制礼服",   rows = 2, cols = 2, quality = "purple", value = 26000, desc = "欧洲礼宾公司定制晚宴礼服，附来源证书",           image = IMG .. "服饰/皇室礼宾定制礼服.png" },
    { name = "传承皮草大衣",       rows = 2, cols = 2, quality = "purple", value = 31000, desc = "水貂皮全长大衣，手工缝制，附毛皮鉴定证书",       image = IMG .. "服饰/传承皮草大衣.png" },
    { name = "顶级定制珠宝腕表",   rows = 1, cols = 1, quality = "purple", value = 48000, desc = "珠宝表盘手工镶钻，机械芯，限量100枚附编号证书", image = IMG .. "服饰/顶级定制珠宝腕表.png" },
    { name = "手工刺绣旗袍",       rows = 2, cols = 2, quality = "purple", value = 17500, desc = "苏绣老工匠手工刺绣旗袍，真丝底布，附工匠签名",   image = IMG .. "服饰/手工刺绣旗袍.png" },
    -- 红 ×3
    { name = "传奇设计师孤品礼服", rows = 2, cols = 2, quality = "red",    value = 280000, desc = "已故传奇设计师最后遗作，全球孤品，附拍卖证明",   image = IMG .. "服饰/传奇设计师孤品礼服.png" },
    { name = "百年品牌典藏手袋",   rows = 2, cols = 2, quality = "red",    value = 420000, desc = "1920年代百年奢侈品牌原版手袋，附传承档案证书",   image = IMG .. "服饰/百年品牌典藏手袋.png" },
    { name = "皇室御用刺绣礼袍",   rows = 2, cols = 3, quality = "red",    value = 750000, desc = "欧洲皇室加冕典礼遗留礼袍，博物馆级别文物藏品",   image = IMG .. "服饰/皇室御用刺绣礼袍.png" },
}

return Fashion
