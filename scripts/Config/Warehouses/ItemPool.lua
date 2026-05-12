-- ============================================================================
-- Config/Warehouses/ItemPool.lua - 通用物品池
-- 全区域共享物品池，包含 7 个品类共 332 件物品（含 38 件新增金色/红色）
-- value 即最终价格，无稀有度乘数
-- weight 由 WarehouseGenerator 根据期望值自动计算，此处不指定
-- ============================================================================

local ItemPool = {}

-- 品类权重（控制每个品类被抽中的概率）
ItemPool.categoryWeights = {
    antique = 25,   -- 古董
    energy  = 35,   -- 能源（主力品类）
    tech    = 30,   -- 科技
    art     = 5,    -- 艺术
    jewel   = 5,    -- 珠宝
}

-- 图片基础路径
local IMG = "items/"

-- ============================================================================
-- 古董  (29件)
-- ============================================================================
ItemPool.antique = {
    -- 白 ×10
    { name = "铜钱",       rows = 1, cols = 1, quality = "white",    value = 242, weight = 2,      desc = "锈迹斑斑的清代铜钱",               image = IMG .. "古董/铜钱.png" },
    { name = "旧烟斗",     rows = 1, cols = 1, quality = "white",    value = 676, weight = 1,      desc = "磨得发亮的竹烟斗",                 image = IMG .. "古董/旧烟斗.png" },
    { name = "陶碗",       rows = 1, cols = 1, quality = "white",    value = 452, weight = 1,      desc = "粗陶大碗，有缺口",                 image = IMG .. "古董/陶碗.png" },
    { name = "破铜铃",     rows = 1, cols = 1, quality = "white",    value = 114, weight = 2,      desc = "摇不出声音的铜铃铛",               image = IMG .. "古董/破铜铃.png" },
    { name = "旧算盘",     rows = 2, cols = 3, quality = "white",    value = 335, weight = 1,      desc = "缺了几颗珠子的老算盘",             image = IMG .. "古董/旧算盘.png" },
    { name = "瓷碎片",     rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "看不出年代的瓷器碎片",             image = IMG .. "古董/瓷碎片.png" },
    { name = "老铜扣",     rows = 1, cols = 1, quality = "white",    value = 529, weight = 1,      desc = "衣服上拆下来的黄铜扣子",           image = IMG .. "古董/老铜扣.png" },
    { name = "旧木箱",     rows = 3, cols = 3, quality = "white",    value = 676, weight = 1,      desc = "铰链生锈的樟木小箱子",             image = IMG .. "古董/旧木箱.png" },
    { name = "竹书签",     rows = 1, cols = 1, quality = "white",    value = 242, weight = 2,      desc = "刻了几个字的竹片",                 image = IMG .. "古董/竹书签.png" },
    { name = "碎石磨",     rows = 2, cols = 2, quality = "white",    value = 452, weight = 1,      desc = "裂了一半的小石磨盘",               image = IMG .. "古董/碎石磨.png" },
    -- 绿 ×8
    { name = "老秤砣",     rows = 1, cols = 1, quality = "green",  value = 333, weight = 2,     desc = "刻有'公平交易'的铁秤砣",           image = IMG .. "古董/老秤砣.png" },
    { name = "铜墨盒",     rows = 1, cols = 1, quality = "green",  value = 1035, weight = 1,     desc = "盖面雕花的铜墨盒",                 image = IMG .. "古董/铜墨盒.png" },
    { name = "老铜尺",     rows = 1, cols = 2, quality = "green",  value = 374, weight = 2,     desc = "刻着鲁班尺寸的铜尺",               image = IMG .. "古董/老铜尺.png" },
    { name = "石砚台",     rows = 2, cols = 2, quality = "green",  value = 1994, weight = 1,     desc = "石质粗糙的老砚台",                 image = IMG .. "古董/石砚台.png" },
    { name = "老杆秤",     rows = 1, cols = 4, quality = "green",  value = 560, weight = 2,     desc = "秤杆上星点模糊的木杆秤",           image = IMG .. "古董/老杆秤.png" },
    { name = "铁如意",     rows = 1, cols = 2, quality = "green",  value = 1324, weight = 1,     desc = "小巧的铁打如意，把手磨亮",         image = IMG .. "古董/铁如意.png" },
    { name = "老铜锁",     rows = 1, cols = 1, quality = "green",  value = 465, weight = 2,     desc = "机关精巧的鱼形铜锁，带钥匙",       image = IMG .. "古董/老铜锁.png" },
    { name = "旧条案",     rows = 2, cols = 4, quality = "green",  value = 2604, weight = 1,     desc = "掉了漆的窄条案，榫卯松动",         image = IMG .. "古董/旧条案.png" },
    -- 蓝 ×5
    { name = "青花瓷片",   rows = 1, cols = 1, quality = "blue",      value = 686, weight = 3,     desc = "一块有完整纹样的青花瓷片",         image = IMG .. "古董/青花瓷片.png" },
    { name = "铜镇尺",     rows = 1, cols = 2, quality = "blue",      value = 2169, weight = 2,     desc = "雕有螭龙纹的铜镇纸",               image = IMG .. "古董/铜镇尺.png" },
    { name = "老玉扳指",   rows = 1, cols = 1, quality = "blue",      value = 2703, weight = 2,     desc = "带沁色的白玉扳指",                 image = IMG .. "古董/老玉扳指.png" },
    { name = "紫砂小壶",   rows = 1, cols = 1, quality = "blue",      value = 5000, weight = 1,     desc = "底款模糊的紫砂茶壶",               image = IMG .. "古董/紫砂小壶.png" },
    { name = "旧太师椅",   rows = 3, cols = 3, quality = "blue",      value = 9286, weight = 1,     desc = "雕花扶手的老红木太师椅，坐面塌了", image = IMG .. "古董/旧太师椅.png" },
    -- 紫 ×3
    { name = "鼻烟壶",     rows = 1, cols = 1, quality = "purple",      value = 2156, weight = 5,    desc = "内画鼻烟壶，画工精细",             image = IMG .. "古董/鼻烟壶.png" },
    { name = "铜佛像",     rows = 2, cols = 2, quality = "purple",      value = 8604, weight = 2,   desc = "鎏金残留的小铜佛坐像",             image = IMG .. "古董/铜佛像.png" },
    { name = "老樟木柜",   rows = 3, cols = 4, quality = "purple",      value = 26640, weight = 1,  desc = "满是樟木香的老柜子，铜件齐全",     image = IMG .. "古董/老樟木柜.png" },
    -- 金 ×6
    { name = "宣德小香炉", rows = 2, cols = 2, quality = "gold", value = 9150, weight = 18,    desc = "底款模糊的铜香炉，疑似宣德年",     image = IMG .. "古董/宣德小香炉.png" },
    { name = "田黄冻印章", rows = 1, cols = 1, quality = "gold", value = 110027, weight = 2, desc = "被当成普通石头的田黄冻方章",       image = IMG .. "古董/田黄冻印章.png" },
    { name = "清代鼻烟壶（珐琅）", rows = 1, cols = 1, quality = "gold", value = 22328, weight = 8,   desc = "铜胎画珐琅鼻烟壶，底款模糊",       image = IMG .. "古董/清代鼻烟壶（珐琅）.png" },
    { name = "明代铜佛手炉",       rows = 1, cols = 1, quality = "gold", value = 34371, weight = 5,   desc = "刻有宣德年款的铜手炉，包浆浑厚",   image = IMG .. "古董/明代铜佛手炉.png" },
    { name = "宋代建盏",           rows = 1, cols = 1, quality = "gold", value = 58676, weight = 3,  desc = "兔毫纹建盏，釉面完好，窑变自然",   image = IMG .. "古董/宋代建盏.png" },
    { name = "清乾隆粉彩瓶",       rows = 2, cols = 2, quality = "gold", value = 184476, weight = 1, desc = "矾红粉彩转心瓶，底款清晰'大清乾隆年制'", image = IMG .. "古董/清乾隆粉彩瓶.png" },
    -- 红 ×4
    { name = "元青花大罐", rows = 3, cols = 3, quality = "red",    value = 7619683, weight = 3, desc = "堆在角落的大肚瓷罐，釉面下隐约可见元代青花纹饰", image = IMG .. "古董/元青花大罐.png" },
    { name = "战国青铜剑",         rows = 2, cols = 1, quality = "red",  value = 214014, weight = 109,  desc = "绿锈覆盖的青铜短剑，剑身有铭文",   image = IMG .. "古董/战国青铜剑.png" },
    { name = "唐三彩骆驼俑",       rows = 2, cols = 2, quality = "red",  value = 2493617, weight = 8, desc = "釉色保存极好的三彩载乐骆驼俑",     image = IMG .. "古董/唐三彩骆驼俑.png" },
    { name = "商代青铜方鼎",       rows = 3, cols = 3, quality = "red",  value = 15851064, weight = 1, desc = "兽面纹青铜方鼎，出土级别文物",     image = IMG .. "古董/商代青铜方鼎.png" },
    -- ===== 新增物品 =====
    -- 白
    { name = "空药瓶",     rows = 1, cols = 1, quality = "white",    value = 105, weight = 3,       desc = "贴着手写标签的棕色玻璃小药瓶",       image = IMG .. "古董/空药瓶.png" },
    { name = "旧蒲团",     rows = 2, cols = 2, quality = "white",    value = 105, weight = 2,      desc = "棉絮跑出来的老蒲团坐垫",             image = IMG .. "古董/旧蒲团.png" },
    { name = "断尺",       rows = 3, cols = 1, quality = "white",    value = 105, weight = 3,      desc = "断了一截的木尺子",                   image = IMG .. "古董/断尺.png" },
    { name = "旧门环",     rows = 1, cols = 1, quality = "white",    value = 335, weight = 1,      desc = "铁锈斑驳的兽首门环",                 image = IMG .. "古董/旧门环.png" },
    -- 绿
    { name = "老铜壶",     rows = 2, cols = 1, quality = "green",  value = 793, weight = 2,     desc = "壶嘴磕了一个缺口的黄铜茶壶",         image = IMG .. "古董/老铜壶.png" },
    { name = "雕花门板",   rows = 4, cols = 2, quality = "green",  value = 2347, weight = 1,     desc = "拆下来的老房子雕花木门板",           image = IMG .. "古董/雕花门板.png" },
    { name = "老铜秤",     rows = 1, cols = 3, quality = "green",  value = 501, weight = 2,     desc = "挂在墙上的老式铜弹簧秤",             image = IMG .. "古董/老铜秤.png" },
    -- 蓝
    { name = "老匾额",     rows = 2, cols = 4, quality = "blue",      value = 3428, weight = 1,     desc = "黑底金字的老店铺匾额，漆面斑驳",     image = IMG .. "古董/老匾额.png" },
    { name = "铜火锅",     rows = 2, cols = 2, quality = "blue",      value = 1206, weight = 2,     desc = "紫铜炭火锅，烟囱完好",               image = IMG .. "古董/铜火锅.png" },
    -- 紫
    { name = "紫檀小方桌", rows = 4, cols = 4, quality = "purple",      value = 18591, weight = 1,   desc = "暗红包浆的老紫檀炕桌",               image = IMG .. "古董/紫檀小方桌.png" },
    -- 金
    { name = "黄花梨架子床", rows = 5, cols = 5, quality = "gold", value = 79726, weight = 2,  desc = "拆散的黄花梨架子床构件，隐约可辨明式风格", image = IMG .. "古董/黄花梨架子床.png" },
    -- 低价紫/金/红（补充低价占比）
    { name = "老铜碗",       rows = 1, cols = 1, quality = "purple",  value = 1998, weight = 5,    desc = "内壁刻有缠枝纹的黄铜碗",               image = IMG .. "古董/老铜碗.png" },
    { name = "竹编提篮",     rows = 2, cols = 2, quality = "purple",  value = 2900, weight = 4,    desc = "编工精细的老竹篮，提手完好",           image = IMG .. "古董/竹编提篮.png" },
    { name = "铜水烟袋",     rows = 1, cols = 1, quality = "purple",  value = 4871, weight = 3,    desc = "做工考究的铜质水烟袋，玉石嘴子",       image = IMG .. "古董/铜水烟袋.png" },
    { name = "银耳挖",       rows = 1, cols = 1, quality = "gold",    value = 10458, weight = 15,    desc = "纯银打造的耳挖勺，柄端雕龙",           image = IMG .. "古董/银耳挖.png" },
    { name = "老铜镜",       rows = 1, cols = 1, quality = "gold",    value = 18522, weight = 9,    desc = "背面瑞兽纹铜镜，锈蚀但纹路清晰",       image = IMG .. "古董/老铜镜.png" },
    { name = "汉代陶俑",     rows = 1, cols = 1, quality = "red",     value = 50000, weight = 500,  desc = "汉代灰陶侍女俑，头部微残",             image = IMG .. "古董/汉代陶俑.png" },
    { name = "清代官帽",     rows = 1, cols = 1, quality = "red",     value = 390682, weight = 58,  desc = "带翎管的七品官帽，顶珠完好",           image = IMG .. "古董/清代官帽.png" },
    -- 低价紫/金/红（第二批补充）
    { name = "铜香盒",       rows = 1, cols = 1, quality = "purple",  value = 2233, weight = 5,    desc = "盖子合不严的铜质香盒，内壁残留檀香味",     image = IMG .. "古董/铜香盒.png" },
    { name = "老铜秤杆",     rows = 1, cols = 2, quality = "purple",  value = 2618, weight = 4,    desc = "刻有十六进制星点的铜秤杆",                 image = IMG .. "古董/老铜秤杆.png" },
    { name = "瓷枕碎块",     rows = 1, cols = 1, quality = "purple",  value = 5913, weight = 3,    desc = "带完整花纹的宋代瓷枕碎片",                 image = IMG .. "古董/瓷枕碎块.png" },
    { name = "铜造像残件",   rows = 1, cols = 1, quality = "gold",    value = 11516, weight = 14,    desc = "断了一只手的小型铜鎏金佛像",               image = IMG .. "古董/铜造像残件.png" },
    { name = "老墨锭",       rows = 1, cols = 1, quality = "gold",    value = 20178, weight = 8,   desc = "刻有老字号堂名的古墨，金色描边",           image = IMG .. "古董/老墨锭.png" },
    { name = "唐代铜镜",     rows = 1, cols = 1, quality = "red",     value = 104218, weight = 232,  desc = "背面海兽葡萄纹的唐代铜镜，铸工精良",       image = IMG .. "古董/唐代铜镜.png" },
    { name = "汉代漆盒",     rows = 2, cols = 2, quality = "red",     value = 335560, weight = 68,  desc = "红黑漆面的汉代木胎漆器小盒",               image = IMG .. "古董/汉代漆盒.png" },
}

-- ============================================================================
-- 能源  (29件)
-- ============================================================================
ItemPool.energy = {
    -- 白 ×10
    { name = "半截蜡烛",       rows = 1, cols = 1, quality = "white",    value = 242, weight = 2,      desc = "烧了一半的普通白蜡烛",             image = IMG .. "能源/半截蜡烛.png" },
    { name = "旧火柴盒",       rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "只剩几根火柴的铁皮盒子",           image = IMG .. "能源/旧火柴盒.png" },
    { name = "废旧电池",       rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "已经漏液的老式干电池",             image = IMG .. "能源/废旧电池.png" },
    { name = "旧灯泡",         rows = 1, cols = 1, quality = "white",    value = 114, weight = 2,      desc = "钨丝烧断的白炽灯泡",               image = IMG .. "能源/旧灯泡.png" },
    { name = "锈打火机",       rows = 1, cols = 1, quality = "white",    value = 335, weight = 1,      desc = "打不着的一次性打火机",             image = IMG .. "能源/锈打火机.png" },
    { name = "旧插排",         rows = 1, cols = 2, quality = "white",    value = 105, weight = 2,      desc = "外壳发黄的两孔插排",               image = IMG .. "能源/旧插排.png" },
    { name = "电线团",         rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "缠成一团的旧电线",                 image = IMG .. "能源/电线团.png" },
    { name = "旧灯笼",         rows = 2, cols = 2, quality = "white",    value = 452, weight = 1,      desc = "纸面破了的红灯笼骨架",             image = IMG .. "能源/旧灯笼.png" },
    { name = "碎灯罩",         rows = 1, cols = 1, quality = "white",    value = 242, weight = 2,      desc = "碎了一角的玻璃灯罩",               image = IMG .. "能源/碎灯罩.png" },
    { name = "旧煤炉",         rows = 2, cols = 3, quality = "white",    value = 529, weight = 1,      desc = "炉壁开裂的蜂窝煤炉子",             image = IMG .. "能源/旧煤炉.png" },
    -- 绿 ×8
    { name = "煤油灯",         rows = 2, cols = 1, quality = "green",  value = 333, weight = 2,     desc = "玻璃罩有裂纹的老煤油灯",           image = IMG .. "能源/煤油灯.png" },
    { name = "老式手电筒",     rows = 2, cols = 1, quality = "green",  value = 560, weight = 2,     desc = "拍两下才亮的铁皮手电",             image = IMG .. "能源/老式手电筒.png" },
    { name = "马灯",           rows = 1, cols = 1, quality = "green",  value = 210, weight = 3,     desc = "铁皮马灯，提手生锈但玻璃完好",     image = IMG .. "能源/马灯.png" },
    { name = "旧蓄电池",       rows = 1, cols = 2, quality = "green",  value = 374, weight = 2,     desc = "摩托车用的铅酸蓄电池",             image = IMG .. "能源/旧蓄电池.png" },
    { name = "铜灯座",         rows = 1, cols = 1, quality = "green",  value = 1035, weight = 1,     desc = "做工精细的铜质灯头底座",           image = IMG .. "能源/铜灯座.png" },
    { name = "老油灯",         rows = 1, cols = 1, quality = "green",  value = 267, weight = 2,     desc = "锡制菜油灯，灯芯还在",             image = IMG .. "能源/老油灯.png" },
    { name = "旧变压器",       rows = 2, cols = 2, quality = "green",  value = 1324, weight = 1,     desc = "小型铁芯变压器，线圈完好",         image = IMG .. "能源/旧变压器.png" },
    { name = "老取暖炉",       rows = 3, cols = 2, quality = "green",  value = 2347, weight = 1,     desc = "铸铁取暖炉，炉门还能开合",         image = IMG .. "能源/老取暖炉.png" },
    -- 蓝 ×5
    { name = "黄铜台灯",       rows = 2, cols = 1, quality = "blue",      value = 1444, weight = 2,     desc = "民国风格黄铜底座台灯",             image = IMG .. "能源/黄铜台灯.png" },
    { name = "铁壳电扇",       rows = 2, cols = 2, quality = "blue",      value = 9286, weight = 1,     desc = "五十年代铁壳台式电扇，还能转",     image = IMG .. "能源/铁壳电扇.png" },
    { name = "老式电表",       rows = 1, cols = 1, quality = "blue",      value = 686, weight = 3,     desc = "转盘式机械电表，木壳外框",         image = IMG .. "能源/老式电表.png" },
    { name = "老矿灯",         rows = 1, cols = 1, quality = "blue",      value = 2169, weight = 2,     desc = "铜质矿工头灯，乙炔式",             image = IMG .. "能源/老矿灯.png" },
    { name = "铜烛台",         rows = 1, cols = 2, quality = "blue",      value = 3428, weight = 1,     desc = "欧式三叉铜烛台，有绿锈",           image = IMG .. "能源/铜烛台.png" },
    -- 紫 ×3
    { name = "军用手摇发电机", rows = 2, cols = 3, quality = "purple",      value = 2559, weight = 4,    desc = "刻有编号的军用野战手摇发电机",     image = IMG .. "能源/军用手摇发电机.png" },
    { name = "老航标灯",       rows = 2, cols = 2, quality = "purple",      value = 13078, weight = 2,   desc = "港口退役的菲涅尔透镜航标灯",       image = IMG .. "能源/老航标灯.png" },
    { name = "蒂芙尼台灯",     rows = 2, cols = 2, quality = "purple",      value = 20763, weight = 1,  desc = "彩色玻璃拼花灯罩的台灯",           image = IMG .. "能源/蒂芙尼台灯.png" },
    -- 金 ×5
    { name = "爱迪生灯泡复刻", rows = 1, cols = 1, quality = "gold", value = 10181, weight = 16,    desc = "编号限量版爱迪生碳丝灯泡复刻品",   image = IMG .. "能源/爱迪生灯泡复刻.png" },
    { name = "老船灯",         rows = 2, cols = 3, quality = "gold", value = 93082, weight = 2, desc = "铜制远洋轮船甲板信号灯，有铭牌",   image = IMG .. "能源/老船灯.png" },
    { name = "古董打火机（Zippo初代）", rows = 1, cols = 1, quality = "gold", value = 15573, weight = 11,    desc = "1930年代初代Zippo，外壳磨花但机芯完好", image = IMG .. "能源/古董打火机（Zippo初代）.png" },
    { name = "老式风力发电机叶片",     rows = 4, cols = 1, quality = "gold", value = 40643, weight = 4,  desc = "早期丹麦实验风机的木质叶片，有铭牌",   image = IMG .. "能源/老式风力发电机叶片.png" },
    { name = "铀矿石标本（密封）",     rows = 1, cols = 1, quality = "gold", value = 110027, weight = 2, desc = "铅盒密封的高品位铀矿石样本，附检测证书", image = IMG .. "能源/铀矿石标本（密封）.png" },
    -- 红 ×3
    { name = "特斯拉线圈模型", rows = 3, cols = 3, quality = "red",    value = 4948211, weight = 4, desc = "疑似尼古拉·特斯拉工作室流出的缩比实验模型", image = IMG .. "能源/特斯拉线圈模型.png" },
    { name = "拉瓦锡实验器具",         rows = 2, cols = 2, quality = "red",  value = 1650771, weight = 13, desc = "疑似拉瓦锡实验室的铜质气体收集装置", image = IMG .. "能源/拉瓦锡实验器具.png" },
    { name = "居里夫人笔记本",         rows = 1, cols = 1, quality = "red",  value = 10460497, weight = 2, desc = "铅盒封存的放射性实验手稿，附盖革计数器读数", image = IMG .. "能源/居里夫人笔记本.png" },
    -- ===== 新增物品 =====
    -- 白
    { name = "旧开关面板", rows = 1, cols = 1, quality = "white",    value = 105, weight = 3,       desc = "发黄开裂的拉绳式老开关",             image = IMG .. "能源/旧开关面板.png" },
    { name = "旧灯管",     rows = 4, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "一根不亮了的日光灯管",               image = IMG .. "能源/旧灯管.png" },
    { name = "煤块",       rows = 1, cols = 1, quality = "white",    value = 105, weight = 3,       desc = "几块散落的蜂窝煤",                   image = IMG .. "能源/煤块.png" },
    -- 绿
    { name = "老电闸",     rows = 1, cols = 3, quality = "green",  value = 301, weight = 2,     desc = "瓷底座闸刀开关，铜触点发绿",         image = IMG .. "能源/老电闸.png" },
    { name = "铜质水烟壶", rows = 1, cols = 1, quality = "green",  value = 1178, weight = 1,     desc = "做工精细的黄铜水烟壶",               image = IMG .. "能源/铜质水烟壶.png" },
    { name = "旧落地灯架", rows = 3, cols = 1, quality = "green",  value = 642, weight = 2,     desc = "铁艺落地灯架，灯罩丢了",             image = IMG .. "能源/旧落地灯架.png" },
    -- 蓝
    { name = "铁壳暖炉",   rows = 3, cols = 2, quality = "blue",      value = 1796, weight = 2,     desc = "铸铁壁炉式暖炉，通风口精铸花纹",     image = IMG .. "能源/铁壳暖炉.png" },
    { name = "老式配电箱", rows = 2, cols = 3, quality = "blue",      value = 553, weight = 3,     desc = "木壳保险丝配电箱，铜件齐全",         image = IMG .. "能源/老式配电箱.png" },
    -- 紫
    { name = "军用柴油发电机", rows = 4, cols = 3, quality = "purple",  value = 11888, weight = 2,   desc = "五十年代军队野战柴油发电机组",       image = IMG .. "能源/军用柴油发电机.png" },
    -- 金
    { name = "老式路灯头", rows = 3, cols = 3, quality = "gold", value = 31488, weight = 5,   desc = "铸铁欧式路灯头，四面玻璃完好",       image = IMG .. "能源/老式路灯头.png" },
    -- 低价紫/金/红（补充低价占比）
    { name = "老煤油炉",     rows = 1, cols = 1, quality = "purple",  value = 2156, weight = 5,    desc = "黄铜煤油取暖炉，可折叠提手",           image = IMG .. "能源/老煤油炉.png" },
    { name = "铜烛剪",       rows = 1, cols = 1, quality = "purple",  value = 4114, weight = 3,    desc = "剪灯花用的铜质烛剪，做工精巧",         image = IMG .. "能源/铜烛剪.png" },
    { name = "铁路信号灯",   rows = 1, cols = 1, quality = "gold",    value = 13036, weight = 13,    desc = "铁路道口老式信号灯，红绿灯罩完好",     image = IMG .. "能源/铁路信号灯.png" },
    { name = "船用汽笛",     rows = 1, cols = 2, quality = "gold",    value = 19458, weight = 9,   desc = "黄铜船用蒸汽汽笛，还能吹响",           image = IMG .. "能源/船用汽笛.png" },
    { name = "瓦特蒸汽机零件", rows = 2, cols = 2, quality = "red",   value = 70763, weight = 348,  desc = "疑似早期蒸汽机的铜质气缸活塞组件",     image = IMG .. "能源/瓦特蒸汽机零件.png" },
    { name = "法拉第线圈装置", rows = 2, cols = 2, quality = "red",   value = 558839, weight = 40,  desc = "疑似法拉第实验用的感应线圈铜装置",     image = IMG .. "能源/法拉第线圈装置.png" },
    -- 低价紫/金/红（第二批补充）
    { name = "铜质油壶灯",   rows = 1, cols = 1, quality = "purple",  value = 2559, weight = 4,    desc = "做工精巧的黄铜长嘴油壶灯",                 image = IMG .. "能源/铜质油壶灯.png" },
    { name = "老煤气灯头",   rows = 1, cols = 1, quality = "purple",  value = 3334, weight = 4,    desc = "铸铁煤气路灯的灯头，玻璃罩完好",           image = IMG .. "能源/老煤气灯头.png" },
    { name = "老黄铜吊灯",   rows = 2, cols = 2, quality = "purple",  value = 5301, weight = 3,    desc = "三臂黄铜吊灯骨架，缺灯罩",                 image = IMG .. "能源/老黄铜吊灯.png" },
    { name = "铜质消防灯",   rows = 1, cols = 1, quality = "gold",    value = 13273, weight = 12,    desc = "老式消防车上的黄铜探照灯",                 image = IMG .. "能源/铜质消防灯.png" },
    { name = "航海罗经灯",   rows = 1, cols = 1, quality = "gold",    value = 22552, weight = 7,   desc = "铜壳航海罗盘照明灯，万向节完好",           image = IMG .. "能源/航海罗经灯.png" },
    { name = "老灯塔透镜",   rows = 2, cols = 2, quality = "red",     value = 214014, weight = 109,  desc = "退役灯塔的小型菲涅尔聚光透镜",             image = IMG .. "能源/老灯塔透镜.png" },
    { name = "矿井安全灯",   rows = 1, cols = 1, quality = "red",     value = 90489, weight = 269,  desc = "铜网罩安全灯，刻有19世纪矿区编号",         image = IMG .. "能源/矿井安全灯.png" },
}

-- ============================================================================
-- 科技  (29件)
-- ============================================================================
ItemPool.tech = {
    -- 白 ×10
    { name = "坏闹钟",         rows = 1, cols = 1, quality = "white",    value = 114, weight = 2,      desc = "指针不动的机械闹钟",               image = IMG .. "科技/坏闹钟.png" },
    { name = "旧计算器",       rows = 1, cols = 1, quality = "white",    value = 452, weight = 1,      desc = "屏幕发暗的电子计算器",             image = IMG .. "科技/旧计算器.png" },
    { name = "断线耳机",       rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "只有一边有声音的耳机",             image = IMG .. "科技/断线耳机.png" },
    { name = "旧遥控器",       rows = 1, cols = 1, quality = "white",    value = 105, weight = 3,      desc = "按键失灵的电视遥控器",             image = IMG .. "科技/旧遥控器.png" },
    { name = "坏鼠标",         rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "左键按不动的有线鼠标",             image = IMG .. "科技/坏鼠标.png" },
    { name = "旧磁带",         rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "标签模糊的空白磁带",               image = IMG .. "科技/旧磁带.png" },
    { name = "坏石英表",       rows = 1, cols = 1, quality = "white",    value = 335, weight = 1,      desc = "表盘进水的电子石英表",             image = IMG .. "科技/坏石英表.png" },
    { name = "旧软盘",         rows = 1, cols = 1, quality = "white",    value = 242, weight = 2,      desc = "3.5寸软盘，贴着手写标签",           image = IMG .. "科技/旧软盘.png" },
    { name = "旧显示器",       rows = 3, cols = 3, quality = "white",    value = 676, weight = 1,      desc = "花屏的CRT球面显示器",               image = IMG .. "科技/旧显示器.png" },
    { name = "旧打印机",       rows = 2, cols = 3, quality = "white",    value = 452, weight = 1,      desc = "卡纸的针式打印机，色带干了",       image = IMG .. "科技/旧打印机.png" },
    -- 绿 ×8
    { name = "老式电话",       rows = 1, cols = 2, quality = "green",  value = 560, weight = 2,     desc = "拨盘式黑色胶木电话机",             image = IMG .. "科技/老式电话.png" },
    { name = "旧万用表",       rows = 1, cols = 1, quality = "green",  value = 210, weight = 3,     desc = "指针式万用电表，表盘泛黄",         image = IMG .. "科技/旧万用表.png" },
    { name = "老式BP机",       rows = 1, cols = 1, quality = "green",  value = 333, weight = 2,     desc = "还能开机的摩托罗拉传呼机",         image = IMG .. "科技/老式BP机.png" },
    { name = "旧游戏卡带",     rows = 1, cols = 1, quality = "green",  value = 210, weight = 3,     desc = "FC红白机卡带，标签磨损",           image = IMG .. "科技/旧游戏卡带.png" },
    { name = "旧收音机",       rows = 1, cols = 2, quality = "green",  value = 374, weight = 2,     desc = "塑料壳AM/FM收音机",                 image = IMG .. "科技/旧收音机.png" },
    { name = "老键盘",         rows = 1, cols = 3, quality = "green",  value = 1035, weight = 1,     desc = "IBM机械键盘，缺几个键帽",           image = IMG .. "科技/老键盘.png" },
    { name = "旧温度计",       rows = 1, cols = 1, quality = "green",  value = 210, weight = 3,     desc = "水银温度计，玻璃管完好",           image = IMG .. "科技/旧温度计.png" },
    { name = "旧传真机",       rows = 2, cols = 2, quality = "green",  value = 1583, weight = 1,     desc = "热敏纸传真机，还能通电",           image = IMG .. "科技/旧传真机.png" },
    -- 蓝 ×5
    { name = "老打字机",       rows = 2, cols = 3, quality = "blue",      value = 979, weight = 2,     desc = "缺了几个键的英文打字机",           image = IMG .. "科技/老打字机.png" },
    { name = "真空管收音机",   rows = 2, cols = 2, quality = "blue",      value = 5000, weight = 1,     desc = "木壳真空管短波收音机",             image = IMG .. "科技/真空管收音机.png" },
    { name = "老示波器",       rows = 2, cols = 2, quality = "blue",      value = 2703, weight = 2,     desc = "绿屏阴极射线示波器",               image = IMG .. "科技/老示波器.png" },
    { name = "老胶片相机",     rows = 1, cols = 1, quality = "blue",      value = 1444, weight = 2,     desc = "海鸥牌120双反相机",                 image = IMG .. "科技/老胶片相机.png" },
    { name = "红白机",         rows = 1, cols = 2, quality = "blue",      value = 2169, weight = 2,     desc = "任天堂FC兼容机，带手柄",           image = IMG .. "科技/红白机.png" },
    -- 紫 ×3
    { name = "电报机",         rows = 1, cols = 2, quality = "purple",      value = 2233, weight = 5,    desc = "铜质莫尔斯电码发报机",             image = IMG .. "科技/电报机.png" },
    { name = "老天文望远镜",   rows = 3, cols = 1, quality = "purple",      value = 10428, weight = 2,   desc = "黄铜折射式天文望远镜",             image = IMG .. "科技/老天文望远镜.png" },
    { name = "机械计算机",     rows = 2, cols = 3, quality = "purple",      value = 27514, weight = 1,  desc = "手摇式机械计算机，齿轮精密",       image = IMG .. "科技/机械计算机.png" },
    -- 金 ×5
    { name = "初代随身听原型", rows = 1, cols = 1, quality = "gold", value = 9910, weight = 16,    desc = "索尼Walkman工程验证机",             image = IMG .. "科技/初代随身听原型.png" },
    { name = "老街机框体",     rows = 3, cols = 4, quality = "gold", value = 136580, weight = 1, desc = "八十年代日本产街机框体，屏幕还亮", image = IMG .. "科技/老街机框体.png" },
    { name = "老式军用电台",           rows = 2, cols = 2, quality = "gold", value = 26524, weight = 6,   desc = "二战时期军用短波电台，面板完好",   image = IMG .. "科技/老式军用电台.png" },
    { name = "早期Apple-I主板",        rows = 2, cols = 3, quality = "gold", value = 43436, weight = 4,  desc = "缺芯片的Apple-I电路板，序列号可查", image = IMG .. "科技/早期Apple-I主板.png" },
    { name = "登月相机镜头组件",       rows = 1, cols = 1, quality = "gold", value = 173016, weight = 1, desc = "哈苏相机太空定制版的备用镜头模组", image = IMG .. "科技/登月相机镜头组件.png" },
    -- 红 ×3
    { name = "恩尼格玛密码机零件", rows = 2, cols = 2, quality = "red", value = 6061058, weight = 3, desc = "疑似二战恩尼格玛密码机的转子组件", image = IMG .. "科技/恩尼格玛密码机零件.png" },
    { name = "图灵手稿残页",           rows = 1, cols = 1, quality = "red",  value = 2882835, weight = 7, desc = "疑似图灵亲笔的计算理论手稿残页", image = IMG .. "科技/图灵手稿残页.png" },
    { name = "阿波罗导航计算机",       rows = 3, cols = 3, quality = "red",  value = 13643215, weight = 1, desc = "阿波罗登月任务的机载导航计算机AGC", image = IMG .. "科技/阿波罗导航计算机.png" },
    -- ===== 新增物品 =====
    -- 白
    { name = "旧网线",     rows = 1, cols = 3, quality = "white",    value = 105, weight = 3,       desc = "一团缠成麻花的网线",                 image = IMG .. "科技/旧网线.png" },
    { name = "旧机箱壳",   rows = 3, cols = 2, quality = "white",    value = 242, weight = 2,      desc = "螺丝缺了一半的台式机铁皮壳",         image = IMG .. "科技/旧机箱壳.png" },
    { name = "旧天线",     rows = 4, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "弯了的室外鱼骨电视天线",             image = IMG .. "科技/旧天线.png" },
    -- 绿
    { name = "老式座钟",   rows = 2, cols = 2, quality = "green",  value = 1711, weight = 1,     desc = "三五牌木壳座钟，发条还能上",         image = IMG .. "科技/老式座钟.png" },
    { name = "旧对讲机",   rows = 2, cols = 1, quality = "green",  value = 214, weight = 3,     desc = "军绿色旧对讲机，天线还在",           image = IMG .. "科技/旧对讲机.png" },
    { name = "旧唱片",     rows = 2, cols = 2, quality = "green",  value = 465, weight = 2,     desc = "封套破损的老黑胶唱片",               image = IMG .. "科技/旧唱片.png" },
    -- 蓝
    { name = "旧唱片机",   rows = 2, cols = 3, quality = "blue",      value = 4083, weight = 1,     desc = "木壳手摇唱片机，喇叭还在",           image = IMG .. "科技/旧唱片机.png" },
    { name = "老缝纫机头", rows = 2, cols = 2, quality = "blue",      value = 786, weight = 2,     desc = "蝴蝶牌缝纫机头，金色花纹完好",       image = IMG .. "科技/老缝纫机头.png" },
    -- 紫
    { name = "老电影放映机", rows = 3, cols = 3, quality = "purple",    value = 8816, weight = 2,   desc = "16mm胶片放映机，镜头完好",           image = IMG .. "科技/老电影放映机.png" },
    { name = "真空管计算机面板", rows = 4, cols = 2, quality = "purple",  value = 22771, weight = 1,  desc = "布满旋钮和真空管的仪器面板",       image = IMG .. "科技/真空管计算机面板.png" },
    -- 金
    { name = "旧大型磁带机", rows = 5, cols = 3, quality = "gold", value = 51788, weight = 3,  desc = "七十年代大型磁带存储设备，转轴还能动", image = IMG .. "科技/旧大型磁带机.png" },
    -- ===== 科技产业园新增：现代科技物品 =====
    -- 白
    { name = "碎屏手机",       rows = 1, cols = 1, quality = "white",  value = 529, weight = 1,      desc = "屏幕摔成蜘蛛网的旧智能手机",         image = IMG .. "科技/碎屏手机.png" },
    { name = "旧充电头",       rows = 1, cols = 1, quality = "white",  value = 105, weight = 3,      desc = "接口松动的快充充电器",               image = IMG .. "科技/旧充电头.png" },
    { name = "坏路由器",       rows = 1, cols = 2, quality = "white",  value = 242, weight = 2,      desc = "天线断了一根的无线路由器",           image = IMG .. "科技/坏路由器.png" },
    { name = "旧USB集线器",    rows = 1, cols = 1, quality = "white",  value = 105, weight = 2,      desc = "只有两个口能用的USB扩展坞",           image = IMG .. "科技/旧USB集线器.png" },
    -- 绿
    { name = "二手机械键盘",   rows = 1, cols = 3, quality = "green",  value = 1035, weight = 1,     desc = "轴体松动的Cherry红轴键盘",           image = IMG .. "科技/二手机械键盘.png" },
    { name = "旧平板电脑",     rows = 1, cols = 2, quality = "green",  value = 1324, weight = 1,     desc = "电池鼓包的旧款iPad",                 image = IMG .. "科技/旧平板电脑.png" },
    { name = "旧无线耳机",     rows = 1, cols = 1, quality = "green",  value = 333, weight = 2,     desc = "一只不出声的蓝牙耳机",               image = IMG .. "科技/旧无线耳机.png" },
    { name = "旧智能音箱",     rows = 1, cols = 1, quality = "green",  value = 210, weight = 3,     desc = "联网失败的初代智能音箱",             image = IMG .. "科技/旧智能音箱.png" },
    -- 蓝
    { name = "二手VR头显",     rows = 2, cols = 2, quality = "blue",   value = 3428, weight = 1,     desc = "镜片有划痕的VR一体机",               image = IMG .. "科技/二手VR头显.png" },
    { name = "旧无人机",       rows = 2, cols = 2, quality = "blue",   value = 5000, weight = 1,     desc = "螺旋桨缺了一个的航拍无人机",         image = IMG .. "科技/旧无人机.png" },
    { name = "企业级交换机",   rows = 2, cols = 3, quality = "blue",   value = 2169, weight = 2,     desc = "48口千兆以太网交换机",               image = IMG .. "科技/企业级交换机.png" },
    -- 紫
    { name = "AI训练显卡",     rows = 1, cols = 2, quality = "purple",  value = 20763, weight = 1,  desc = "显存颗粒完好的数据中心GPU",           image = IMG .. "科技/AI训练显卡.png" },
    { name = "服务器机柜(满配)", rows = 3, cols = 4, quality = "purple", value = 27514, weight = 1, desc = "42U机柜塞满了刀片服务器",           image = IMG .. "科技/服务器机柜(满配).png" },
    -- 金
    { name = "定制AI芯片",     rows = 1, cols = 1, quality = "gold",   value = 69408, weight = 3,  desc = "独角兽公司自研的TPU芯片，未公开发售", image = IMG .. "科技/定制AI芯片.png" },
    -- 红
    { name = "量子计算处理器原型", rows = 2, cols = 2, quality = "red", value = 7619683, weight = 3, desc = "超导量子比特处理器，密封在液氮容器中", image = IMG .. "科技/量子计算处理器原型.png" },
    -- 低价紫/金/红（补充低价占比）
    { name = "机械秒表",         rows = 1, cols = 1, quality = "purple",  value = 2156, weight = 5,    desc = "瑞士产老式机械秒表，走时尚准",         image = IMG .. "科技/机械秒表.png" },
    { name = "老式相机",         rows = 1, cols = 1, quality = "purple",  value = 3334, weight = 4,    desc = "海鸥牌120胶片相机，镜头有霉丝",       image = IMG .. "科技/老式相机.png" },
    { name = "初代游戏机",       rows = 1, cols = 2, quality = "gold",    value = 13273, weight = 12,    desc = "任天堂初代家用游戏机，缺电源线",       image = IMG .. "科技/初代游戏机.png" },
    { name = "老唱片机",         rows = 2, cols = 2, quality = "gold",    value = 22328, weight = 8,   desc = "手摇式留声机，铜喇叭口有凹痕",         image = IMG .. "科技/老唱片机.png" },
    { name = "爱迪生留声机部件", rows = 1, cols = 2, quality = "red",     value = 122793, weight = 195,  desc = "疑似爱迪生实验室的蜡筒留声机零件",     image = IMG .. "科技/爱迪生留声机部件.png" },
    { name = "达芬奇手稿残页",   rows = 1, cols = 1, quality = "red",     value = 646139, weight = 34,  desc = "疑似达芬奇设计的机械装置草图残页",     image = IMG .. "科技/达芬奇手稿残页.png" },
    -- 低价紫/金/红（第二批补充）
    { name = "旧经纬仪",       rows = 1, cols = 2, quality = "purple",  value = 2900, weight = 4,    desc = "测量用的老式光学经纬仪，铜件齐全",         image = IMG .. "科技/旧经纬仪.png" },
    { name = "老航空仪表",     rows = 1, cols = 1, quality = "purple",  value = 4114, weight = 3,    desc = "退役飞机拆下的机械高度表",                 image = IMG .. "科技/老航空仪表.png" },
    { name = "铜望远镜",       rows = 1, cols = 2, quality = "purple",  value = 6374, weight = 2,    desc = "三节伸缩的黄铜航海望远镜",                 image = IMG .. "科技/铜望远镜.png" },
    { name = "老式气压计",     rows = 1, cols = 1, quality = "gold",    value = 13036, weight = 13,    desc = "精密黄铜机械气压计，表盘完好",             image = IMG .. "科技/老式气压计.png" },
    { name = "军用罗盘",       rows = 1, cols = 1, quality = "gold",    value = 19458, weight = 9,   desc = "铝壳军用行军罗盘，荧光刻度",               image = IMG .. "科技/军用罗盘.png" },
    { name = "老天文台时钟",   rows = 2, cols = 2, quality = "red",     value = 260582, weight = 89,  desc = "天文台标准时钟机芯，精度极高",             image = IMG .. "科技/老天文台时钟.png" },
    { name = "早期X光管",      rows = 1, cols = 2, quality = "red",     value = 60493, weight = 410,  desc = "20世纪初的玻璃X光真空管，完好罕见",        image = IMG .. "科技/早期X光管.png" },
}

-- ============================================================================
-- 艺术  (29件)
-- ============================================================================
ItemPool.art = {
    -- 白 ×10
    { name = "褪色年画",   rows = 2, cols = 1, quality = "white",    value = 452, weight = 1,      desc = "颜色褪了大半的门神年画",             image = IMG .. "艺术/褪色年画.png" },
    { name = "破草编篮",   rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "边缘散了的草编小篮子",               image = IMG .. "艺术/破草编篮.png" },
    { name = "旧剪纸",     rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "发黄卷边的窗花剪纸",                 image = IMG .. "艺术/旧剪纸.png" },
    { name = "泥哨子",     rows = 1, cols = 1, quality = "white",    value = 114, weight = 2,      desc = "上釉脱落的泥叫叫",                   image = IMG .. "艺术/泥哨子.png" },
    { name = "旧皮影",     rows = 1, cols = 2, quality = "white",    value = 529, weight = 1,      desc = "关节断了的旧皮影戏偶",               image = IMG .. "艺术/旧皮影.png" },
    { name = "旧中国结",   rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "褪色打结的红色中国结",               image = IMG .. "艺术/旧中国结.png" },
    { name = "碎刺绣",     rows = 1, cols = 1, quality = "white",    value = 335, weight = 1,      desc = "剪裁下来的一块旧刺绣布料",           image = IMG .. "艺术/碎刺绣.png" },
    { name = "旧蒲扇",     rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "边沿破损的棕叶蒲扇",                 image = IMG .. "艺术/旧蒲扇.png" },
    { name = "石膏像",     rows = 2, cols = 2, quality = "white",    value = 242, weight = 2,      desc = "缺了鼻子的石膏大卫头像",             image = IMG .. "艺术/石膏像.png" },
    { name = "旧风筝",     rows = 2, cols = 3, quality = "white",    value = 335, weight = 1,      desc = "骨架歪了的燕子风筝",                 image = IMG .. "艺术/旧风筝.png" },
    -- 绿 ×8
    { name = "旧折扇",     rows = 1, cols = 2, quality = "green",  value = 560, weight = 2,     desc = "竹骨折扇，扇面有模糊墨迹",           image = IMG .. "艺术/旧折扇.png" },
    { name = "木雕小鱼",   rows = 1, cols = 1, quality = "green",  value = 210, weight = 3,     desc = "刀工粗犷的黄杨木小鱼",               image = IMG .. "艺术/木雕小鱼.png" },
    { name = "陶笛",       rows = 1, cols = 1, quality = "green",  value = 210, weight = 3,     desc = "六孔陶笛，还能吹响",                 image = IMG .. "艺术/陶笛.png" },
    { name = "老邮票",     rows = 1, cols = 1, quality = "green",  value = 333, weight = 2,     desc = "一小叠盖过戳的旧邮票",               image = IMG .. "艺术/老邮票.png" },
    { name = "绣花鞋垫",   rows = 1, cols = 1, quality = "green",  value = 210, weight = 3,     desc = "手工十字绣鞋垫，花样精致",           image = IMG .. "艺术/绣花鞋垫.png" },
    { name = "旧年历画",   rows = 2, cols = 1, quality = "green",  value = 267, weight = 2,     desc = "八十年代明星挂历画",                 image = IMG .. "艺术/旧年历画.png" },
    { name = "铜风铃",     rows = 1, cols = 1, quality = "green",  value = 1035, weight = 1,     desc = "挂了四个铜铃的小风铃",               image = IMG .. "艺术/铜风铃.png" },
    { name = "旧竹帘",     rows = 1, cols = 4, quality = "green",  value = 374, weight = 2,     desc = "编工整齐的旧竹帘画，画了仕女图",     image = IMG .. "艺术/旧竹帘.png" },
    -- 蓝 ×5
    { name = "泥人",       rows = 1, cols = 1, quality = "blue",      value = 465, weight = 3,     desc = "天津泥人张风格的彩塑小人",           image = IMG .. "艺术/泥人.png" },
    { name = "竹雕笔筒",   rows = 2, cols = 1, quality = "blue",      value = 1444, weight = 2,     desc = "浮雕山水纹老竹笔筒",                 image = IMG .. "艺术/竹雕笔筒.png" },
    { name = "老烙画",     rows = 2, cols = 2, quality = "blue",      value = 979, weight = 2,     desc = "木板烙画，画的是八仙过海",           image = IMG .. "艺术/老烙画.png" },
    { name = "景泰蓝小瓶", rows = 1, cols = 1, quality = "blue",      value = 2703, weight = 2,     desc = "巴掌大的景泰蓝掐丝花瓶",             image = IMG .. "艺术/景泰蓝小瓶.png" },
    { name = "旧木屏风",   rows = 3, cols = 4, quality = "blue",      value = 7411, weight = 1,     desc = "四扇折叠木屏风，雕花残损但框架完好", image = IMG .. "艺术/旧木屏风.png" },
    -- 紫 ×3
    { name = "微雕核桃",   rows = 1, cols = 1, quality = "purple",      value = 1998, weight = 5,    desc = "核桃壳上刻了一首完整的诗",           image = IMG .. "艺术/微雕核桃.png" },
    { name = "老紫砂壶",   rows = 1, cols = 1, quality = "purple",      value = 7995, weight = 2,   desc = "壶身刻字的老紫砂壶",                 image = IMG .. "艺术/老紫砂壶.png" },
    { name = "象牙果雕件", rows = 1, cols = 1, quality = "purple",      value = 21412, weight = 1,  desc = "象牙果雕刻的观音像，工艺精湛",       image = IMG .. "艺术/象牙果雕件.png" },
    -- 金 ×5
    { name = "名家印章",   rows = 1, cols = 1, quality = "gold", value = 8148, weight = 20,    desc = "底款刻有近代篆刻家名号的寿山石印",   image = IMG .. "艺术/名家印章.png" },
    { name = "青铜小兽",   rows = 1, cols = 1, quality = "gold", value = 104724, weight = 2, desc = "锈蚀严重但造型独特的青铜摆件",       image = IMG .. "艺术/青铜小兽.png" },
    { name = "名家竹雕臂搁",           rows = 2, cols = 1, quality = "gold", value = 11516, weight = 14,    desc = "留青竹刻臂搁，底部刻有名号",       image = IMG .. "艺术/名家竹雕臂搁.png" },
    { name = "明代铜鎏金佛像",         rows = 2, cols = 2, quality = "gold", value = 50893, weight = 3,  desc = "鎏金保存完好的藏传佛教小佛像",     image = IMG .. "艺术/明代铜鎏金佛像.png" },
    { name = "齐白石虾图残卷",         rows = 2, cols = 3, quality = "gold", value = 148268, weight = 1, desc = "破损但有落款印章的齐白石水墨画卷", image = IMG .. "艺术/齐白石虾图残卷.png" },
    -- 红 ×3
    { name = "宋拓碑帖残页", rows = 2, cols = 3, quality = "red",  value = 4448983, weight = 5,  desc = "疑似宋代拓本的碑帖残页，字迹清晰", image = IMG .. "艺术/宋拓碑帖残页.png" },
    { name = "敦煌壁画残片",           rows = 2, cols = 2, quality = "red",  value = 1372612, weight = 16, desc = "带矿物颜料的唐代壁画脱落残片",     image = IMG .. "艺术/敦煌壁画残片.png" },
    { name = "张大千泼墨山水",         rows = 3, cols = 4, quality = "red",  value = 7619683, weight = 3, desc = "张大千晚年泼墨山水真迹，有多枚藏印", image = IMG .. "艺术/张大千泼墨山水.png" },
    -- ===== 新增物品 =====
    -- 白
    { name = "旧对联",     rows = 4, cols = 1, quality = "white",    value = 105, weight = 3,      desc = "墨迹模糊的手写春联",                 image = IMG .. "艺术/旧对联.png" },
    { name = "碎花布",     rows = 2, cols = 2, quality = "white",    value = 105, weight = 2,      desc = "一块褪色的老式碎花棉布",             image = IMG .. "艺术/碎花布.png" },
    { name = "旧竹筷",     rows = 3, cols = 1, quality = "white",    value = 105, weight = 3,       desc = "一把用旧了的竹筷子",                 image = IMG .. "艺术/旧竹筷.png" },
    -- 绿
    { name = "木雕挂屏",   rows = 3, cols = 2, quality = "green",  value = 886, weight = 1,     desc = "浮雕花鸟纹的木板挂饰",               image = IMG .. "艺术/木雕挂屏.png" },
    { name = "旧绣品",     rows = 2, cols = 3, quality = "green",  value = 1583, weight = 1,     desc = "有些脱线的湘绣牡丹图案",             image = IMG .. "艺术/旧绣品.png" },
    { name = "老灯笼骨架", rows = 1, cols = 3, quality = "green",  value = 210, weight = 3,     desc = "可折叠的竹制宫灯骨架",               image = IMG .. "艺术/老灯笼骨架.png" },
    -- 蓝
    { name = "铜佛龛",     rows = 3, cols = 2, quality = "blue",      value = 4083, weight = 1,     desc = "小型铜质佛龛，门扇可开合",           image = IMG .. "艺术/铜佛龛.png" },
    { name = "老蓝印花布", rows = 2, cols = 4, quality = "blue",      value = 1796, weight = 2,     desc = "整幅的手工蓝印花布门帘",             image = IMG .. "艺术/老蓝印花布.png" },
    -- 紫
    { name = "漆器大盘",   rows = 3, cols = 3, quality = "purple",      value = 14139, weight = 2,   desc = "剔红工艺的大漆盘，花纹繁复",         image = IMG .. "艺术/漆器大盘.png" },
    -- 金
    { name = "苏绣双面绣屏风", rows = 5, cols = 3, quality = "gold", value = 70061, weight = 3,  desc = "四扇苏绣双面绣屏风，两面图案不同",   image = IMG .. "艺术/苏绣双面绣屏风.png" },
    -- ===== 科技产业园新增：现代艺术品 =====
    -- 白
    { name = "旧海报",         rows = 2, cols = 1, quality = "white",  value = 105, weight = 2,      desc = "卷边褪色的电影首映海报",             image = IMG .. "艺术/旧海报.png" },
    { name = "碎马赛克片",     rows = 1, cols = 1, quality = "white",  value = 105, weight = 2,      desc = "从墙上脱落的彩色马赛克碎片",         image = IMG .. "艺术/碎马赛克片.png" },
    { name = "旧画框",         rows = 2, cols = 3, quality = "white",  value = 335, weight = 1,      desc = "里面没画的镀金塑料画框",             image = IMG .. "艺术/旧画框.png" },
    -- 绿
    { name = "设计师台灯",     rows = 2, cols = 1, quality = "green",  value = 560, weight = 2,     desc = "造型独特的北欧设计台灯",             image = IMG .. "艺术/设计师台灯.png" },
    { name = "残缺手办",       rows = 1, cols = 1, quality = "green",  value = 1035, weight = 1,     desc = "断了剑的限量版游戏角色手办",         image = IMG .. "艺术/残缺手办.png" },
    { name = "概念艺术画册",   rows = 1, cols = 2, quality = "green",  value = 333, weight = 2,     desc = "绝版游戏概念设定集",                 image = IMG .. "艺术/概念艺术画册.png" },
    -- 蓝
    { name = "现代抽象油画",   rows = 2, cols = 3, quality = "blue",   value = 5000, weight = 1,     desc = "签名模糊的当代抽象派油画",           image = IMG .. "艺术/现代抽象油画.png" },
    { name = "设计师限量摆件", rows = 1, cols = 1, quality = "blue",   value = 2169, weight = 2,     desc = "编号限量版的树脂艺术摆件",           image = IMG .. "艺术/设计师限量摆件.png" },
    -- 紫
    { name = "当代艺术家签名版画", rows = 2, cols = 3, quality = "purple", value = 18591, weight = 1, desc = "背面有亲笔签名和编号的丝网版画",   image = IMG .. "艺术/当代艺术家签名版画.png" },
    { name = "LED动态艺术装置", rows = 3, cols = 2, quality = "purple", value = 12313, weight = 2,  desc = "编程控制的LED光影艺术装置",           image = IMG .. "艺术/LED动态艺术装置.png" },
    -- 金
    { name = "知名艺术家雕塑", rows = 3, cols = 3, quality = "gold",   value = 93082, weight = 2, desc = "当代著名雕塑家的不锈钢作品，底座有铭牌", image = IMG .. "艺术/知名艺术家雕塑.png" },
    -- 低价紫/金/红（补充低价占比）
    { name = "砖雕花片",         rows = 1, cols = 1, quality = "purple",  value = 2233, weight = 5,    desc = "老宅拆下的浮雕花卉砖片",               image = IMG .. "艺术/砖雕花片.png" },
    { name = "粗陶花瓶",         rows = 1, cols = 1, quality = "purple",  value = 3492, weight = 4,    desc = "民间艺人手捏的粗陶花瓶，釉色素雅",     image = IMG .. "艺术/粗陶花瓶.png" },
    { name = "老年画原版",       rows = 1, cols = 2, quality = "gold",    value = 10181, weight = 16,    desc = "杨柳青年画木版原版，刻工细腻",         image = IMG .. "艺术/老年画原版.png" },
    { name = "民国月份牌",       rows = 1, cols = 1, quality = "gold",    value = 15235, weight = 11,    desc = "民国彩印美女月份牌广告画",             image = IMG .. "艺术/民国月份牌.png" },
    { name = "清宫如意",         rows = 2, cols = 1, quality = "red",     value = 104218, weight = 232,  desc = "紫檀嵌玉如意，做工精细",               image = IMG .. "艺术/清宫如意.png" },
    { name = "宋代瓷枕",         rows = 1, cols = 2, quality = "red",     value = 558839, weight = 40,  desc = "磁州窑虎形瓷枕，纹饰清晰",             image = IMG .. "艺术/宋代瓷枕.png" },
    -- 低价紫/金/红（第二批补充）
    { name = "老铜墨盒",       rows = 1, cols = 1, quality = "purple",  value = 2618, weight = 4,    desc = "盖面刻山水画的文房铜墨盒",                 image = IMG .. "艺术/老铜墨盒.png" },
    { name = "核雕手串",       rows = 1, cols = 1, quality = "purple",  value = 2156, weight = 5,    desc = "橄榄核雕十八罗汉手串",                     image = IMG .. "艺术/核雕手串.png" },
    { name = "木版年画",       rows = 1, cols = 2, quality = "purple",  value = 4871, weight = 3,    desc = "保存尚好的老版杨柳青年画",                 image = IMG .. "艺术/木版年画.png" },
    { name = "石雕门墩",       rows = 2, cols = 2, quality = "gold",    value = 15573, weight = 11,    desc = "青石抱鼓石门墩，浮雕狮子",                 image = IMG .. "艺术/石雕门墩.png" },
    { name = "铜制文镇",       rows = 1, cols = 1, quality = "gold",    value = 10458, weight = 15,    desc = "铜雕卧牛造型文镇，做工精致",               image = IMG .. "艺术/铜制文镇.png" },
    { name = "明代木雕佛像",   rows = 2, cols = 2, quality = "red",     value = 152813, weight = 155,  desc = "金漆大部脱落的明代木雕观音",               image = IMG .. "艺术/明代木雕佛像.png" },
    { name = "唐卡残片",       rows = 1, cols = 2, quality = "red",     value = 60493, weight = 410,  desc = "带矿物颜料的老唐卡画面残片",               image = IMG .. "艺术/唐卡残片.png" },
}

-- ============================================================================
-- 珠宝  (29件)
-- ============================================================================
ItemPool.jewel = {
    -- 白 ×10
    { name = "铜手镯",     rows = 1, cols = 1, quality = "white",    value = 866, weight = 1,      desc = "发绿的铜手镯，款式老旧",             image = IMG .. "珠宝/铜手镯.png" },
    { name = "玻璃珠",     rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "颜色浑浊的旧玻璃弹珠",               image = IMG .. "珠宝/玻璃珠.png" },
    { name = "假珍珠",     rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "掉漆的塑料珍珠项链",                 image = IMG .. "珠宝/假珍珠.png" },
    { name = "断链子",     rows = 1, cols = 1, quality = "white",    value = 242, weight = 2,      desc = "断了的镀金项链",                     image = IMG .. "珠宝/断链子.png" },
    { name = "旧胸针",     rows = 1, cols = 1, quality = "white",    value = 114, weight = 2,      desc = "掉了石头的合金胸针",                 image = IMG .. "珠宝/旧胸针.png" },
    { name = "铁戒指",     rows = 1, cols = 1, quality = "white",    value = 105, weight = 3,      desc = "锈迹斑斑的铁质戒指",                 image = IMG .. "珠宝/铁戒指.png" },
    { name = "旧发卡",     rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "失去弹性的金属发卡",                 image = IMG .. "珠宝/旧发卡.png" },
    { name = "旧袖扣",     rows = 1, cols = 1, quality = "white",    value = 452, weight = 1,      desc = "一对不配套的旧袖扣",                 image = IMG .. "珠宝/旧袖扣.png" },
    { name = "旧首饰盒",   rows = 2, cols = 2, quality = "white",    value = 335, weight = 1,      desc = "绒布掉光的木首饰盒，里面空的",       image = IMG .. "珠宝/旧首饰盒.png" },
    { name = "碎珠子堆",   rows = 1, cols = 2, quality = "white",    value = 114, weight = 2,      desc = "一小包颜色不一的散珠子",             image = IMG .. "珠宝/碎珠子堆.png" },
    -- 绿 ×8
    { name = "银耳环",     rows = 1, cols = 1, quality = "green",  value = 1035, weight = 1,     desc = "氧化发黑的银质耳环",                 image = IMG .. "珠宝/银耳环.png" },
    { name = "铜鎏金戒指", rows = 1, cols = 1, quality = "green",  value = 333, weight = 2,     desc = "鎏金大部分脱落的铜戒",               image = IMG .. "珠宝/铜鎏金戒指.png" },
    { name = "珊瑚珠",     rows = 1, cols = 1, quality = "green",  value = 560, weight = 2,     desc = "一颗暗红色的小珊瑚珠",               image = IMG .. "珠宝/珊瑚珠.png" },
    { name = "老银簪",     rows = 1, cols = 1, quality = "green",  value = 374, weight = 2,     desc = "发黑的银簪子，花纹还在",             image = IMG .. "珠宝/老银簪.png" },
    { name = "琥珀小块",   rows = 1, cols = 1, quality = "green",  value = 1324, weight = 1,     desc = "指甲盖大小的琥珀碎块",               image = IMG .. "珠宝/琥珀小块.png" },
    { name = "旧玛瑙珠",   rows = 1, cols = 1, quality = "green",  value = 210, weight = 3,     desc = "一颗磨损的红玛瑙珠子",               image = IMG .. "珠宝/旧玛瑙珠.png" },
    { name = "银指环",     rows = 1, cols = 1, quality = "green",  value = 465, weight = 2,     desc = "刻有简单花纹的银指环",               image = IMG .. "珠宝/银指环.png" },
    { name = "旧珠宝匣",   rows = 2, cols = 3, quality = "green",  value = 1994, weight = 1,     desc = "漆面斑驳的老珠宝匣，铜搭扣还好使",   image = IMG .. "珠宝/旧珠宝匣.png" },
    -- 蓝 ×5
    { name = "玉坠子",     rows = 1, cols = 1, quality = "blue",      value = 1444, weight = 2,     desc = "被当成石头的小玉坠",                 image = IMG .. "珠宝/玉坠子.png" },
    { name = "老银锁",     rows = 1, cols = 1, quality = "blue",      value = 979, weight = 2,     desc = "刻着'长命百岁'的银质小锁片",         image = IMG .. "珠宝/老银锁.png" },
    { name = "绿松石珠串", rows = 1, cols = 1, quality = "blue",      value = 2703, weight = 2,     desc = "几颗绿松石串成的短手链",             image = IMG .. "珠宝/绿松石珠串.png" },
    { name = "银鎏金耳坠", rows = 1, cols = 1, quality = "blue",      value = 2169, weight = 2,     desc = "做工讲究的银鎏金流苏耳坠",           image = IMG .. "珠宝/银鎏金耳坠.png" },
    { name = "老翡翠片",   rows = 1, cols = 1, quality = "blue",      value = 5000, weight = 1,     desc = "被当成普通石片的翡翠薄片",           image = IMG .. "珠宝/老翡翠片.png" },
    -- 紫 ×3
    { name = "老蜜蜡珠串", rows = 1, cols = 1, quality = "purple",      value = 2233, weight = 5,    desc = "包浆浑厚的蜜蜡佛珠手串",             image = IMG .. "珠宝/老蜜蜡珠串.png" },
    { name = "南红玛瑙挂件", rows = 1, cols = 1, quality = "purple",    value = 9880, weight = 2,   desc = "颜色纯正的柿子红南红挂件",           image = IMG .. "珠宝/南红玛瑙挂件.png" },
    { name = "和田玉牌",   rows = 1, cols = 1, quality = "purple",      value = 28557, weight = 1,  desc = "被误认为普通石头的羊脂白玉牌",       image = IMG .. "珠宝/和田玉牌.png" },
    -- 金 ×5
    { name = "老翡翠扳指", rows = 1, cols = 1, quality = "gold", value = 10181, weight = 16,    desc = "水头极好的冰种翡翠扳指",             image = IMG .. "珠宝/老翡翠扳指.png" },
    { name = "清代金耳环", rows = 1, cols = 1, quality = "gold", value = 133551, weight = 1, desc = "做工精细的足金累丝耳环",             image = IMG .. "珠宝/清代金耳环.png" },
    { name = "老金戒指",               rows = 1, cols = 1, quality = "gold", value = 7956, weight = 20,    desc = "刻有'百年好合'的足金戒指，磨损严重", image = IMG .. "珠宝/老金戒指.png" },
    { name = "祖母绿原石",             rows = 1, cols = 1, quality = "gold", value = 43138, weight = 4,  desc = "未切割的哥伦比亚祖母绿原石，透光翠绿", image = IMG .. "珠宝/祖母绿原石.png" },
    { name = "克什米尔蓝宝石",         rows = 1, cols = 1, quality = "gold", value = 184386, weight = 1, desc = "矢车菊蓝色天然蓝宝石裸石，附旧鉴定书", image = IMG .. "珠宝/克什米尔蓝宝石.png" },
    -- 红 ×4
    { name = "帝王绿翡翠珠", rows = 1, cols = 1, quality = "red",  value = 13643215, weight = 1, desc = "被压在杂物下的一颗帝王绿翡翠圆珠，色正水透", image = IMG .. "珠宝/帝王绿翡翠珠.png" },
    { name = "红珊瑚雕件",             rows = 1, cols = 1, quality = "red",  value = 390682, weight = 58,  desc = "阿卡深红珊瑚雕刻观音像，色泽浓郁", image = IMG .. "珠宝/红珊瑚雕件.png" },
    { name = "鸽血红宝石",             rows = 1, cols = 1, quality = "red",  value = 3711888, weight = 6, desc = "缅甸产鸽血红红宝石裸石，5克拉以上", image = IMG .. "珠宝/鸽血红宝石.png" },
    { name = "粉钻原石",               rows = 1, cols = 1, quality = "red",  value = 18896291, weight = 1, desc = "阿盖尔矿区的稀有粉钻原石，重达12克拉", image = IMG .. "珠宝/粉钻原石.png" },
    -- ===== 新增物品 =====
    -- 白
    { name = "旧珠花",     rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "掉了几颗珠子的头饰珠花",             image = IMG .. "珠宝/旧珠花.png" },
    { name = "旧表带",     rows = 3, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "皮面开裂的旧表带",                   image = IMG .. "珠宝/旧表带.png" },
    { name = "铜纽扣盒",   rows = 1, cols = 2, quality = "white",    value = 189, weight = 2,      desc = "装满各色旧铜纽扣的铁盒",             image = IMG .. "珠宝/铜纽扣盒.png" },
    -- 绿
    { name = "老银烟杆",   rows = 4, cols = 1, quality = "green",  value = 1711, weight = 1,     desc = "包浆厚重的银质旱烟杆",               image = IMG .. "珠宝/老银烟杆.png" },
    { name = "珊瑚树摆件", rows = 2, cols = 2, quality = "green",  value = 2604, weight = 1,     desc = "小型浅色珊瑚枝摆件",                 image = IMG .. "珠宝/珊瑚树摆件.png" },
    { name = "银手链",     rows = 1, cols = 3, quality = "green",  value = 793, weight = 2,     desc = "做工粗犷的老银手链",                 image = IMG .. "珠宝/银手链.png" },
    -- 蓝
    { name = "老檀木珠串", rows = 1, cols = 2, quality = "blue",      value = 1206, weight = 2,     desc = "满是包浆的老檀木108颗长珠串",         image = IMG .. "珠宝/老檀木珠串.png" },
    { name = "银质梳妆盒", rows = 2, cols = 3, quality = "blue",      value = 6020, weight = 1,     desc = "雕花银质梳妆盒，内衬绒布",           image = IMG .. "珠宝/银质梳妆盒.png" },
    { name = "旧象牙筷",   rows = 3, cols = 1, quality = "blue",      value = 2169, weight = 2,     desc = "一双发黄的旧象牙筷子",               image = IMG .. "珠宝/旧象牙筷.png" },
    -- 紫
    { name = "老金丝楠木匣", rows = 3, cols = 2, quality = "purple",    value = 13078, weight = 2,   desc = "金丝纹理明显的小木匣",               image = IMG .. "珠宝/老金丝楠木匣.png" },
    { name = "老珍珠冠",   rows = 2, cols = 2, quality = "purple",      value = 20763, weight = 1,  desc = "用珍珠和银丝编成的头冠",             image = IMG .. "珠宝/老珍珠冠.png" },
    -- 金
    { name = "翡翠玉如意", rows = 3, cols = 1, quality = "gold", value = 98716, weight = 2, desc = "满绿翡翠雕成的如意，体量罕见",       image = IMG .. "珠宝/翡翠玉如意.png" },
    -- ===== 科技产业园新增：科技相关贵金属/稀有材料 =====
    -- 白
    { name = "坏智能手环",     rows = 1, cols = 1, quality = "white",  value = 335, weight = 1,      desc = "屏幕不亮的运动手环",                 image = IMG .. "珠宝/坏智能手环.png" },
    { name = "旧蓝牙戒指",     rows = 1, cols = 1, quality = "white",  value = 529, weight = 1,      desc = "充不进电的智能戒指",                 image = IMG .. "珠宝/旧蓝牙戒指.png" },
    -- 绿
    { name = "钛合金表壳",     rows = 1, cols = 1, quality = "green",  value = 2347, weight = 1,     desc = "没有机芯的钛合金手表壳",             image = IMG .. "珠宝/钛合金表壳.png" },
    -- 蓝
    { name = "铂金催化剂样品", rows = 1, cols = 1, quality = "blue",   value = 7411, weight = 1,     desc = "实验室遗留的铂金催化剂小瓶",         image = IMG .. "珠宝/铂金催化剂样品.png" },
    -- 紫
    { name = "稀土金属样品套装", rows = 2, cols = 2, quality = "purple", value = 26640, weight = 1, desc = "标注齐全的17种稀土元素样品盒",       image = IMG .. "珠宝/稀土金属样品套装.png" },
    -- 金
    { name = "铱金坩埚",       rows = 1, cols = 1, quality = "gold",   value = 77206, weight = 2,  desc = "实验室的高纯度铱金属坩埚，极耐高温", image = IMG .. "珠宝/铱金坩埚.png" },
    -- 低价紫/金/红（补充低价占比）
    { name = "银质发簪",         rows = 1, cols = 1, quality = "purple",  value = 2559, weight = 4,    desc = "缠丝工艺的老银发簪，簪头蝴蝶",         image = IMG .. "珠宝/银质发簪.png" },
    { name = "绿松石散珠",       rows = 1, cols = 1, quality = "purple",  value = 4114, weight = 3,    desc = "几颗天然绿松石圆珠，颜色尚可",         image = IMG .. "珠宝/绿松石散珠.png" },
    { name = "老银锁片",         rows = 1, cols = 1, quality = "gold",    value = 9910, weight = 16,    desc = "刻有'长命百岁'的银质长命锁",           image = IMG .. "珠宝/老银锁片.png" },
    { name = "玛瑙扳指",         rows = 1, cols = 1, quality = "gold",    value = 15573, weight = 11,    desc = "缠丝玛瑙扳指，纹理天然",               image = IMG .. "珠宝/玛瑙扳指.png" },
    { name = "翡翠观音挂件",     rows = 1, cols = 1, quality = "red",     value = 70763, weight = 348,  desc = "冰糯种翡翠观音牌，种水尚可",           image = IMG .. "珠宝/翡翠观音挂件.png" },
    { name = "老坑翡翠手镯",     rows = 1, cols = 1, quality = "red",     value = 646139, weight = 34,  desc = "老坑冰种飘花翡翠手镯，微有石纹",       image = IMG .. "珠宝/老坑翡翠手镯.png" },
    -- 低价紫/金/红（第二批补充）
    { name = "老银手镯",       rows = 1, cols = 1, quality = "purple",  value = 2156, weight = 5,    desc = "苗族银匠打制的老银手镯",                   image = IMG .. "珠宝/老银手镯.png" },
    { name = "蜜蜡碎料",       rows = 1, cols = 1, quality = "purple",  value = 3334, weight = 4,    desc = "几块天然蜜蜡原石碎料",                     image = IMG .. "珠宝/蜜蜡碎料.png" },
    { name = "珍珠碎串",       rows = 1, cols = 1, quality = "purple",  value = 5301, weight = 3,    desc = "断线散落的淡水珍珠一把",                   image = IMG .. "珠宝/珍珠碎串.png" },
    { name = "银质酒杯",       rows = 1, cols = 1, quality = "gold",    value = 11516, weight = 14,    desc = "欧式纯银雕花小酒杯",                       image = IMG .. "珠宝/银质酒杯.png" },
    { name = "琥珀虫珀",       rows = 1, cols = 1, quality = "gold",    value = 17447, weight = 10,    desc = "内含完整小虫的天然琥珀",                   image = IMG .. "珠宝/琥珀虫珀.png" },
    { name = "翡翠戒面",       rows = 1, cols = 1, quality = "red",     value = 214014, weight = 109,  desc = "满绿蛋面翡翠裸石，水头好",                 image = IMG .. "珠宝/翡翠戒面.png" },
    { name = "天然珍珠项链",   rows = 1, cols = 2, quality = "red",     value = 460518, weight = 49,  desc = "大溪地天然黑珍珠短项链",                   image = IMG .. "珠宝/天然珍珠项链.png" },
}

-- ============================================================================
-- 机械  (29件) — 科技产业园新增品类
-- ============================================================================
ItemPool.mechanical = {
    -- 白 ×10
    { name = "废弃电路板",     rows = 1, cols = 2, quality = "white",  value = 105, weight = 2,      desc = "焊点氧化的绿色PCB废板",               image = IMG .. "机械/废弃电路板.png" },
    { name = "旧散热风扇",     rows = 1, cols = 1, quality = "white",  value = 105, weight = 2,      desc = "积满灰尘的机箱散热风扇",               image = IMG .. "机械/旧散热风扇.png" },
    { name = "锈蚀轴承",       rows = 1, cols = 1, quality = "white",  value = 114, weight = 2,      desc = "转不动了的工业滚珠轴承",               image = IMG .. "机械/锈蚀轴承.png" },
    { name = "废齿轮组",       rows = 1, cols = 1, quality = "white",  value = 242, weight = 2,      desc = "几个磨损严重的金属齿轮",               image = IMG .. "机械/废齿轮组.png" },
    { name = "旧电机外壳",     rows = 2, cols = 2, quality = "white",  value = 452, weight = 1,      desc = "只剩铝壳的电机残骸",                   image = IMG .. "机械/旧电机外壳.png" },
    { name = "断裂传动带",     rows = 2, cols = 1, quality = "white",  value = 105, weight = 2,      desc = "老化断裂的橡胶同步带",                 image = IMG .. "机械/断裂传动带.png" },
    { name = "废弃传感器",     rows = 1, cols = 1, quality = "white",  value = 335, weight = 1,      desc = "接口氧化的温湿度传感器",               image = IMG .. "机械/废弃传感器.png" },
    { name = "旧工具箱",       rows = 2, cols = 3, quality = "white",  value = 676, weight = 1,      desc = "少了几件工具的铁皮工具箱",             image = IMG .. "机械/旧工具箱.png" },
    { name = "锈蚀弹簧组",     rows = 1, cols = 1, quality = "white",  value = 105, weight = 2,      desc = "一堆锈在一起的工业弹簧",               image = IMG .. "机械/锈蚀弹簧组.png" },
    { name = "旧线缆束",       rows = 1, cols = 3, quality = "white",  value = 105, weight = 3,      desc = "一捆剪断的工业控制线缆",               image = IMG .. "机械/旧线缆束.png" },
    -- 绿 ×8
    { name = "步进电机",       rows = 1, cols = 1, quality = "green",  value = 374, weight = 2,     desc = "还能转的42步进电机",                   image = IMG .. "机械/步进电机.png" },
    { name = "小型气缸",       rows = 2, cols = 1, quality = "green",  value = 1035, weight = 1,     desc = "铝合金气动气缸，密封完好",             image = IMG .. "机械/小型气缸.png" },
    { name = "旧减速器",       rows = 1, cols = 1, quality = "green",  value = 560, weight = 2,     desc = "行星减速器，齿轮有磨损",               image = IMG .. "机械/旧减速器.png" },
    { name = "旧PLC控制器",    rows = 1, cols = 2, quality = "green",  value = 1324, weight = 1,     desc = "西门子老型号PLC模块",                   image = IMG .. "机械/旧PLC控制器.png" },
    { name = "激光切割头",     rows = 1, cols = 1, quality = "green",  value = 1994, weight = 1,     desc = "镜片有划痕的CO2激光头",                 image = IMG .. "机械/激光切割头.png" },
    { name = "旧伺服驱动器",   rows = 2, cols = 1, quality = "green",  value = 793, weight = 2,     desc = "通电有反应的伺服驱动板",               image = IMG .. "机械/旧伺服驱动器.png" },
    { name = "小型液压缸",     rows = 2, cols = 1, quality = "green",  value = 1711, weight = 1,     desc = "微型液压油缸，略有渗油",               image = IMG .. "机械/小型液压缸.png" },
    { name = "精密导轨",       rows = 1, cols = 3, quality = "green",  value = 1178, weight = 1,     desc = "直线导轨滑块，表面有锈斑",             image = IMG .. "机械/精密导轨.png" },
    -- 蓝 ×5
    { name = "机械臂关节模组", rows = 2, cols = 2, quality = "blue",   value = 2169, weight = 2,     desc = "六轴机械臂的腕部关节总成",             image = IMG .. "机械/机械臂关节模组.png" },
    { name = "小型CNC主轴",    rows = 2, cols = 1, quality = "blue",   value = 3428, weight = 1,     desc = "数控机床电主轴，转速尚可",             image = IMG .. "机械/小型CNC主轴.png" },
    { name = "工业视觉相机",   rows = 1, cols = 1, quality = "blue",   value = 1206, weight = 2,     desc = "高分辨率工业检测相机",                 image = IMG .. "机械/工业视觉相机.png" },
    { name = "协作机器人控制柜", rows = 2, cols = 3, quality = "blue", value = 5000, weight = 1,     desc = "协作机器人专用控制箱",                 image = IMG .. "机械/协作机器人控制柜.png" },
    { name = "精密谐波减速机", rows = 1, cols = 1, quality = "blue",   value = 2703, weight = 2,     desc = "日本产谐波减速器，精度尚存",           image = IMG .. "机械/精密谐波减速机.png" },
    -- 紫 ×3
    { name = "六轴工业机械臂", rows = 3, cols = 2, quality = "purple", value = 15810, weight = 1,   desc = "整台小型六轴机械臂，缺控制柜",         image = IMG .. "机械/六轴工业机械臂.png" },
    { name = "高精度3D打印机", rows = 3, cols = 3, quality = "purple", value = 21412, weight = 1,  desc = "金属粉末激光烧结3D打印机",             image = IMG .. "机械/高精度3D打印机.png" },
    { name = "精密坐标测量仪", rows = 2, cols = 2, quality = "purple", value = 2900, weight = 4,    desc = "三坐标测量仪的测量头组件",             image = IMG .. "机械/精密坐标测量仪.png" },
    -- 金 ×5
    { name = "人形机器人原型", rows = 4, cols = 2, quality = "gold",   value = 66742, weight = 3,  desc = "展厅里的双足机器人，外壳完好",         image = IMG .. "机械/人形机器人原型.png" },
    { name = "光刻机镜组模块", rows = 2, cols = 2, quality = "gold",   value = 127315, weight = 1, desc = "疑似深紫外光刻机的精密镜组",           image = IMG .. "机械/光刻机镜组模块.png" },
    { name = "瑞士钟表机芯",           rows = 1, cols = 1, quality = "gold", value = 31400, weight = 5,   desc = "百达翡丽的废弃机芯，齿轮精密",     image = IMG .. "机械/瑞士钟表机芯.png" },
    { name = "德国光学镜头",           rows = 1, cols = 1, quality = "gold", value = 47898, weight = 4,  desc = "蔡司工厂流出的未镀膜APO镜头毛坯",   image = IMG .. "机械/德国光学镜头.png" },
    { name = "航天陀螺仪",             rows = 1, cols = 1, quality = "gold", value = 133551, weight = 1, desc = "航天惯性导航用的高精度光纤陀螺仪",   image = IMG .. "机械/航天陀螺仪.png" },
    -- 红 ×3
    { name = "ASML光刻机核心组件", rows = 4, cols = 4, quality = "red", value = 8762931, weight = 2, desc = "角落里用木箱封装的光刻机关键模块，编号与失踪清单吻合", image = IMG .. "机械/ASML光刻机核心组件.png" },
    { name = "战斗机弹射座椅",         rows = 3, cols = 2, quality = "red",  value = 1182135, weight = 18, desc = "完整的马丁贝克弹射座椅，火工品已拆除", image = IMG .. "机械/战斗机弹射座椅.png" },
    { name = "航天发动机喷嘴",         rows = 2, cols = 2, quality = "red",  value = 6061058, weight = 3, desc = "液体火箭发动机的再生冷却喷嘴总成", image = IMG .. "机械/航天发动机喷嘴.png" },
    -- 低价紫/金/红（补充低价占比）
    { name = "手动缝纫机",       rows = 2, cols = 2, quality = "purple",  value = 2233, weight = 5,    desc = "蝴蝶牌老式手动缝纫机，脚踏板完好",     image = IMG .. "机械/手动缝纫机.png" },
    { name = "铜质天平",         rows = 1, cols = 2, quality = "purple",  value = 4995, weight = 3,    desc = "带砝码套装的精密铜天平，刻度清晰",     image = IMG .. "机械/铜质天平.png" },
    { name = "航海六分仪",       rows = 1, cols = 1, quality = "gold",    value = 15573, weight = 11,    desc = "黄铜航海六分仪，镜片有划痕",           image = IMG .. "机械/航海六分仪.png" },
    { name = "老式显微镜",       rows = 1, cols = 1, quality = "gold",    value = 26524, weight = 6,   desc = "黄铜筒身的老式光学显微镜",             image = IMG .. "机械/老式显微镜.png" },
    { name = "蒸汽朋克机械钟",   rows = 2, cols = 2, quality = "red",     value = 187461, weight = 125,  desc = "纯手工齿轮传动座钟，齿轮外露可赏",     image = IMG .. "机械/蒸汽朋克机械钟.png" },
    { name = "潜艇潜望镜",       rows = 3, cols = 1, quality = "red",     value = 786253, weight = 28,  desc = "退役潜艇拆下的光学潜望镜筒",           image = IMG .. "机械/潜艇潜望镜.png" },
    -- 低价紫/金/红（第二批补充）
    { name = "胜家缝纫机头",   rows = 1, cols = 2, quality = "purple",  value = 2900, weight = 4,    desc = "带金色花纹的胜家缝纫机头",                 image = IMG .. "机械/老缝纫机头.png" },
    { name = "铜质打字机键",   rows = 1, cols = 1, quality = "purple",  value = 1998, weight = 5,    desc = "一整套圆形铜质打字机按键",                 image = IMG .. "机械/铜质打字机键.png" },
    { name = "老钟表发条",     rows = 1, cols = 1, quality = "purple",  value = 4526, weight = 3,    desc = "瑞士产座钟的盘形发条组件",                 image = IMG .. "机械/老钟表发条.png" },
    { name = "老式计量秤",     rows = 1, cols = 2, quality = "gold",    value = 14769, weight = 11,    desc = "带铜砝码的精密药房计量秤",                 image = IMG .. "机械/老式计量秤.png" },
    { name = "铜质望远镜筒",   rows = 1, cols = 2, quality = "gold",    value = 20178, weight = 8,   desc = "黄铜制舰载望远镜的镜筒",                   image = IMG .. "机械/铜质望远镜筒.png" },
    { name = "古董留声机",     rows = 2, cols = 2, quality = "red",     value = 335560, weight = 68,  desc = "完整的大喇叭花铜质留声机",                 image = IMG .. "机械/古董留声机.png" },
    { name = "瑞士八音盒",     rows = 1, cols = 2, quality = "red",     value = 104218, weight = 232,  desc = "72音瑞士机械八音盒，可演奏多首曲",         image = IMG .. "机械/瑞士八音盒.png" },
}

-- ============================================================================
-- 交通  (29件) — 科技产业园新增品类
-- ============================================================================
ItemPool.transport = {
    -- 白 ×10
    { name = "旧自行车轮",     rows = 2, cols = 2, quality = "white",  value = 114, weight = 2,      desc = "辐条断了几根的自行车轮组",             image = IMG .. "交通/旧自行车轮.png" },
    { name = "坏电动滑板",     rows = 2, cols = 1, quality = "white",  value = 452, weight = 1,      desc = "电池鼓包的电动滑板",                   image = IMG .. "交通/坏电动滑板.png" },
    { name = "旧头盔",         rows = 1, cols = 1, quality = "white",  value = 242, weight = 2,      desc = "内衬脱胶的骑行头盔",                   image = IMG .. "交通/旧头盔.png" },
    { name = "破轮胎",         rows = 2, cols = 2, quality = "white",  value = 105, weight = 2,      desc = "开裂的电动车真空胎",                   image = IMG .. "交通/破轮胎.png" },
    { name = "旧车载充电器",   rows = 1, cols = 1, quality = "white",  value = 105, weight = 3,      desc = "接口松动的点烟器充电头",               image = IMG .. "交通/旧车载充电器.png" },
    { name = "废弃反光镜",     rows = 1, cols = 1, quality = "white",  value = 105, weight = 2,      desc = "碎了一角的电动车后视镜",               image = IMG .. "交通/废弃反光镜.png" },
    { name = "旧行车记录仪",   rows = 1, cols = 1, quality = "white",  value = 335, weight = 1,      desc = "屏幕花了的行车记录仪",                 image = IMG .. "交通/旧行车记录仪.png" },
    { name = "锈蚀链条",       rows = 1, cols = 2, quality = "white",  value = 105, weight = 2,      desc = "锈得拉不动的自行车链条",               image = IMG .. "交通/锈蚀链条.png" },
    { name = "旧车牌框",       rows = 1, cols = 2, quality = "white",  value = 105, weight = 3,       desc = "变形的铝合金车牌框",                   image = IMG .. "交通/旧车牌框.png" },
    { name = "旧仪表壳",       rows = 1, cols = 2, quality = "white",  value = 529, weight = 1,      desc = "拆下来的电动摩托仪表面板",             image = IMG .. "交通/旧仪表壳.png" },
    -- 绿 ×8
    { name = "电动滑板车电池", rows = 1, cols = 2, quality = "green",  value = 1035, weight = 1,     desc = "容量衰减的锂电池包",                   image = IMG .. "交通/电动滑板车电池.png" },
    { name = "旧GPS导航仪",    rows = 1, cols = 1, quality = "green",  value = 374, weight = 2,     desc = "地图过期但屏幕还亮的导航仪",           image = IMG .. "交通/旧GPS导航仪.png" },
    { name = "碳纤维车架",     rows = 3, cols = 2, quality = "green",  value = 2604, weight = 1,     desc = "有暗裂的碳纤维自行车架",               image = IMG .. "交通/碳纤维车架.png" },
    { name = "旧行车电脑",     rows = 1, cols = 1, quality = "green",  value = 560, weight = 2,     desc = "码表功能正常的骑行电脑",               image = IMG .. "交通/旧行车电脑.png" },
    { name = "电动车控制器",   rows = 1, cols = 2, quality = "green",  value = 1324, weight = 1,     desc = "电动两轮车的主控制器",                 image = IMG .. "交通/电动车控制器.png" },
    { name = "旧赛车座椅",     rows = 2, cols = 3, quality = "green",  value = 1994, weight = 1,     desc = "布面磨损的运动桶椅",                   image = IMG .. "交通/旧赛车座椅.png" },
    { name = "排气管总成",     rows = 3, cols = 1, quality = "green",  value = 793, weight = 2,     desc = "改装摩托车的钛合金排气管",             image = IMG .. "交通/排气管总成.png" },
    { name = "旧车载音响",     rows = 2, cols = 2, quality = "green",  value = 1178, weight = 1,     desc = "拆车件的品牌功放和喇叭",               image = IMG .. "交通/旧车载音响.png" },
    -- 蓝 ×5
    { name = "电动汽车电池模组", rows = 2, cols = 3, quality = "blue", value = 3428, weight = 1,     desc = "拆解的三元锂电池模组",                 image = IMG .. "交通/电动汽车电池模组.png" },
    { name = "碳陶刹车盘",     rows = 2, cols = 2, quality = "blue",   value = 2169, weight = 2,     desc = "有磨损纹的碳陶制动盘",                 image = IMG .. "交通/碳陶刹车盘.png" },
    { name = "旧涡轮增压器",   rows = 2, cols = 2, quality = "blue",   value = 5000, weight = 1,     desc = "叶片完好的废气涡轮",                   image = IMG .. "交通/旧涡轮增压器.png" },
    { name = "自动驾驶传感器套件", rows = 2, cols = 2, quality = "blue", value = 2703, weight = 2,   desc = "激光雷达+摄像头的车顶模组",           image = IMG .. "交通/自动驾驶传感器套件.png" },
    { name = "赛车方向盘",     rows = 1, cols = 2, quality = "blue",   value = 1444, weight = 2,     desc = "碳纤维平底方向盘，按钮齐全",           image = IMG .. "交通/赛车方向盘.png" },
    -- 紫 ×3
    { name = "电动汽车驱动电机", rows = 3, cols = 3, quality = "purple", value = 16616, weight = 1,  desc = "永磁同步驱动电机总成",                 image = IMG .. "交通/电动汽车驱动电机.png" },
    { name = "自动驾驶计算平台", rows = 2, cols = 3, quality = "purple", value = 22771, weight = 1, desc = "车载AI计算盒，芯片完好",               image = IMG .. "交通/自动驾驶计算平台.png" },
    { name = "碳纤维车身面板", rows = 4, cols = 3, quality = "purple", value = 11888, weight = 2,   desc = "轻量化碳纤维车门外板",                 image = IMG .. "交通/碳纤维车身面板.png" },
    -- 金 ×5
    { name = "电动超跑轮毂套装", rows = 2, cols = 2, quality = "gold", value = 61171, weight = 3,  desc = "锻造铝合金轮毂四件套，限量编号",       image = IMG .. "交通/电动超跑轮毂套装.png" },
    { name = "固态电池原型模组", rows = 3, cols = 2, quality = "gold", value = 105941, weight = 2, desc = "实验室的全固态电池原型，能量密度远超量产品", image = IMG .. "交通/固态电池原型模组.png" },
    { name = "老式船钟",               rows = 1, cols = 1, quality = "gold", value = 29686, weight = 6,   desc = "黄铜航海船钟，八日走时机芯",       image = IMG .. "交通/老式船钟.png" },
    { name = "蒸汽机车铭牌",           rows = 2, cols = 1, quality = "gold", value = 35450, weight = 5,   desc = "'前进'型蒸汽机车的原装铸铁铭牌",   image = IMG .. "交通/蒸汽机车铭牌.png" },
    { name = "劳斯莱斯飞翼天使",       rows = 1, cols = 1, quality = "gold", value = 151412, weight = 1, desc = "银魅车型原装的纯银立标'欢庆女神'", image = IMG .. "交通/劳斯莱斯飞翼天使.png" },
    -- 红 ×3
    { name = "飞行汽车原型引擎", rows = 4, cols = 3, quality = "red",  value = 6061058, weight = 3, desc = "eVTOL飞行汽车的电驱动力总成，仅存三台的工程样机", image = IMG .. "交通/飞行汽车原型引擎.png" },
    { name = "协和号驾驶舱仪表盘",     rows = 3, cols = 3, quality = "red",  value = 1956811, weight = 11, desc = "协和号超音速客机退役拆解的完整驾驶仪表盘", image = IMG .. "交通/协和号驾驶舱仪表盘.png" },
    { name = "一级方程式赛车引擎",     rows = 4, cols = 3, quality = "red",  value = 8762931, weight = 2, desc = "法拉利F1赛车的V10引擎总成，可运转", image = IMG .. "交通/一级方程式赛车引擎.png" },
    -- 低价紫/金/红（补充低价占比）
    { name = "老自行车铃",       rows = 1, cols = 1, quality = "purple",  value = 2559, weight = 4,    desc = "永久牌自行车的黄铜铃铛，声音清脆",     image = IMG .. "交通/老自行车铃.png" },
    { name = "马车灯",           rows = 1, cols = 1, quality = "purple",  value = 6864, weight = 2,    desc = "欧式马车用的煤油提灯，铜框玻璃罩",     image = IMG .. "交通/马车灯.png" },
    { name = "老式摩托油箱",     rows = 2, cols = 1, quality = "gold",    value = 14769, weight = 11,    desc = "幸福牌摩托车原装油箱，漆面斑驳",       image = IMG .. "交通/老式摩托油箱.png" },
    { name = "黄铜船锚模型",     rows = 1, cols = 1, quality = "gold",    value = 22328, weight = 8,   desc = "实心黄铜打造的等比船锚模型",           image = IMG .. "交通/黄铜船锚模型.png" },
    { name = "古董摩托车",       rows = 3, cols = 2, quality = "red",     value = 122793, weight = 195,  desc = "长江750边三轮摩托，可修复运转",         image = IMG .. "交通/古董摩托车.png" },
    { name = "老式火车模型",     rows = 2, cols = 3, quality = "red",     value = 957587, weight = 23,  desc = "蒸汽火车1:10铜制精密模型，可喷蒸汽",   image = IMG .. "交通/老式火车模型.png" },
    -- 低价紫/金/红（第二批补充）
    { name = "老船用铜钟",     rows = 1, cols = 1, quality = "purple",  value = 2233, weight = 5,    desc = "轮船甲板的报时铜钟，声音洪亮",             image = IMG .. "交通/老船用铜钟.png" },
    { name = "旧火车钟",       rows = 1, cols = 1, quality = "purple",  value = 3752, weight = 3,    desc = "铁路车站挂钟，黑色铸铁壳",                 image = IMG .. "交通/旧火车钟.png" },
    { name = "老马鞍",         rows = 2, cols = 2, quality = "purple",  value = 5913, weight = 3,    desc = "牛皮马鞍，铜扣件齐全",                     image = IMG .. "交通/老马鞍.png" },
    { name = "蒸汽火车汽笛",   rows = 1, cols = 2, quality = "gold",    value = 15235, weight = 11,    desc = "铜质三管蒸汽火车汽笛，可吹响",             image = IMG .. "交通/蒸汽火车汽笛.png" },
    { name = "航海羊皮地图",   rows = 1, cols = 2, quality = "gold",    value = 24842, weight = 7,   desc = "手绘的旧航海图，标注了老航线",             image = IMG .. "交通/航海羊皮地图.png" },
    { name = "老式马车车轮",   rows = 2, cols = 2, quality = "red",     value = 122793, weight = 195,  desc = "欧式四轮马车的铁箍木轮，雕花轮毂",         image = IMG .. "交通/老式马车车轮.png" },
    { name = "帆船铜舵轮",     rows = 2, cols = 2, quality = "red",     value = 390682, weight = 58,  desc = "大型帆船的黄铜包木舵轮，八辐设计",         image = IMG .. "交通/帆船铜舵轮.png" },
}

-- 所有品类列表（方便遍历）
ItemPool.categories = {
    { id = "antique",    name = "古董", icon = "", items = ItemPool.antique },
    { id = "energy",     name = "能源", icon = "", items = ItemPool.energy },
    { id = "tech",       name = "科技", icon = "", items = ItemPool.tech },
    { id = "art",        name = "艺术", icon = "", items = ItemPool.art },
    { id = "jewel",      name = "珠宝", icon = "", items = ItemPool.jewel },
    { id = "mechanical", name = "机械", icon = "", items = ItemPool.mechanical },
    { id = "transport",  name = "交通", icon = "", items = ItemPool.transport },
}

return ItemPool
