-- ============================================================================
-- Config/Categories/Antique.lua - 古董品类物品定义
-- 来源：ItemPool 通用池
-- ============================================================================

local Antique = {}

local IMG = "items/"

Antique.items = {
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
    { name = "空药瓶",     rows = 1, cols = 1, quality = "white",    value = 105, weight = 3,      desc = "贴着手写标签的棕色玻璃小药瓶",     image = IMG .. "古董/空药瓶.png" },
    { name = "旧蒲团",     rows = 2, cols = 2, quality = "white",    value = 105, weight = 2,      desc = "棉絮跑出来的老蒲团坐垫",           image = IMG .. "古董/旧蒲团.png" },
    { name = "断尺",       rows = 3, cols = 1, quality = "white",    value = 105, weight = 3,      desc = "断了一截的木尺子",                 image = IMG .. "古董/断尺.png" },
    { name = "旧门环",     rows = 1, cols = 1, quality = "white",    value = 335, weight = 1,      desc = "铁锈斑驳的兽首门环",               image = IMG .. "古董/旧门环.png" },
    -- 绿 ×11
    { name = "老秤砣",     rows = 1, cols = 1, quality = "green",    value = 333,  weight = 2,     desc = "刻有'公平交易'的铁秤砣",           image = IMG .. "古董/老秤砣.png" },
    { name = "铜墨盒",     rows = 1, cols = 1, quality = "green",    value = 1035, weight = 1,     desc = "盖面雕花的铜墨盒",                 image = IMG .. "古董/铜墨盒.png" },
    { name = "老铜尺",     rows = 1, cols = 2, quality = "green",    value = 374,  weight = 2,     desc = "刻着鲁班尺寸的铜尺",               image = IMG .. "古董/老铜尺.png" },
    { name = "石砚台",     rows = 2, cols = 2, quality = "green",    value = 1994, weight = 1,     desc = "石质粗糙的老砚台",                 image = IMG .. "古董/石砚台.png" },
    { name = "老杆秤",     rows = 1, cols = 4, quality = "green",    value = 560,  weight = 2,     desc = "秤杆上星点模糊的木杆秤",           image = IMG .. "古董/老杆秤.png" },
    { name = "铁如意",     rows = 1, cols = 2, quality = "green",    value = 1324, weight = 1,     desc = "小巧的铁打如意，把手磨亮",         image = IMG .. "古董/铁如意.png" },
    { name = "老铜锁",     rows = 1, cols = 1, quality = "green",    value = 465,  weight = 2,     desc = "机关精巧的鱼形铜锁，带钥匙",       image = IMG .. "古董/老铜锁.png" },
    { name = "旧条案",     rows = 2, cols = 4, quality = "green",    value = 2604, weight = 1,     desc = "掉了漆的窄条案，榫卯松动",         image = IMG .. "古董/旧条案.png" },
    { name = "老铜壶",     rows = 2, cols = 1, quality = "green",    value = 793,  weight = 2,     desc = "壶嘴磕了一个缺口的黄铜茶壶",       image = IMG .. "古董/老铜壶.png" },
    { name = "雕花门板",   rows = 4, cols = 2, quality = "green",    value = 2347, weight = 1,     desc = "拆下来的老房子雕花木门板",         image = IMG .. "古董/雕花门板.png" },
    { name = "老铜秤",     rows = 1, cols = 3, quality = "green",    value = 501,  weight = 2,     desc = "挂在墙上的老式铜弹簧秤",           image = IMG .. "古董/老铜秤.png" },
    -- 蓝 ×7
    { name = "青花瓷片",   rows = 1, cols = 1, quality = "blue",     value = 686,  weight = 3,     desc = "一块有完整纹样的青花瓷片",         image = IMG .. "古董/青花瓷片.png" },
    { name = "铜镇尺",     rows = 1, cols = 2, quality = "blue",     value = 2169, weight = 2,     desc = "雕有螭龙纹的铜镇纸",               image = IMG .. "古董/铜镇尺.png" },
    { name = "老玉扳指",   rows = 1, cols = 1, quality = "blue",     value = 2703, weight = 2,     desc = "带沁色的白玉扳指",                 image = IMG .. "古董/老玉扳指.png" },
    { name = "紫砂小壶",   rows = 1, cols = 1, quality = "blue",     value = 5000, weight = 1,     desc = "底款模糊的紫砂茶壶",               image = IMG .. "古董/紫砂小壶.png" },
    { name = "旧太师椅",   rows = 3, cols = 3, quality = "blue",     value = 9286, weight = 1,     desc = "雕花扶手的老红木太师椅，坐面塌了", image = IMG .. "古董/旧太师椅.png" },
    { name = "老匾额",     rows = 2, cols = 4, quality = "blue",     value = 3428, weight = 1,     desc = "黑底金字的老店铺匾额，漆面斑驳",   image = IMG .. "古董/老匾额.png" },
    { name = "铜火锅",     rows = 2, cols = 2, quality = "blue",     value = 1206, weight = 2,     desc = "紫铜炭火锅，烟囱完好",             image = IMG .. "古董/铜火锅.png" },
    -- 紫 ×9
    { name = "鼻烟壶",     rows = 1, cols = 1, quality = "purple",   value = 2156,  weight = 5,    desc = "内画鼻烟壶，画工精细",             image = IMG .. "古董/鼻烟壶.png" },
    { name = "铜佛像",     rows = 2, cols = 2, quality = "purple",   value = 8604,  weight = 2,    desc = "鎏金残留的小铜佛坐像",             image = IMG .. "古董/铜佛像.png" },
    { name = "老樟木柜",   rows = 3, cols = 4, quality = "purple",   value = 26640, weight = 1,    desc = "满是樟木香的老柜子，铜件齐全",     image = IMG .. "古董/老樟木柜.png" },
    { name = "老铜碗",     rows = 1, cols = 1, quality = "purple",   value = 1998,  weight = 5,    desc = "内壁刻有缠枝纹的黄铜碗",           image = IMG .. "古董/老铜碗.png" },
    { name = "竹编提篮",   rows = 2, cols = 2, quality = "purple",   value = 2900,  weight = 4,    desc = "编工精细的老竹篮，提手完好",       image = IMG .. "古董/竹编提篮.png" },
    { name = "铜水烟袋",   rows = 1, cols = 1, quality = "purple",   value = 4871,  weight = 3,    desc = "做工考究的铜质水烟袋，玉石嘴子",   image = IMG .. "古董/铜水烟袋.png" },
    { name = "紫檀小方桌", rows = 4, cols = 4, quality = "purple",   value = 18591, weight = 1,    desc = "暗红包浆的老紫檀炕桌",             image = IMG .. "古董/紫檀小方桌.png" },
    { name = "铜香盒",     rows = 1, cols = 1, quality = "purple",   value = 2233,  weight = 5,    desc = "盖子合不严的铜质香盒，内壁残留檀香味", image = IMG .. "古董/铜香盒.png" },
    { name = "老铜秤杆",   rows = 1, cols = 2, quality = "purple",   value = 2618,  weight = 4,    desc = "刻有十六进制星点的铜秤杆",         image = IMG .. "古董/老铜秤杆.png" },
    -- 金 ×9
    { name = "宣德小香炉",         rows = 2, cols = 2, quality = "gold",   value = 9150,   weight = 18,   desc = "底款模糊的铜香炉，疑似宣德年",         image = IMG .. "古董/宣德小香炉.png" },
    { name = "田黄冻印章",         rows = 1, cols = 1, quality = "gold",   value = 110027, weight = 2,    desc = "被当成普通石头的田黄冻方章",           image = IMG .. "古董/田黄冻印章.png" },
    { name = "清代鼻烟壶（珐琅）", rows = 1, cols = 1, quality = "gold",   value = 22328,  weight = 8,    desc = "铜胎画珐琅鼻烟壶，底款模糊",           image = IMG .. "古董/清代鼻烟壶（珐琅）.png" },
    { name = "明代铜佛手炉",       rows = 1, cols = 1, quality = "gold",   value = 34371,  weight = 5,    desc = "刻有宣德年款的铜手炉，包浆浑厚",       image = IMG .. "古董/明代铜佛手炉.png" },
    { name = "宋代建盏",           rows = 1, cols = 1, quality = "gold",   value = 58676,  weight = 3,    desc = "兔毫纹建盏，釉面完好，窑变自然",       image = IMG .. "古董/宋代建盏.png" },
    { name = "清乾隆粉彩瓶",       rows = 2, cols = 2, quality = "gold",   value = 184476, weight = 1,    desc = "矾红粉彩转心瓶，底款清晰'大清乾隆年制'", image = IMG .. "古董/清乾隆粉彩瓶.png" },
    { name = "黄花梨架子床",       rows = 5, cols = 5, quality = "gold",   value = 79726,  weight = 2,    desc = "拆散的黄花梨架子床构件，隐约可辨明式风格", image = IMG .. "古董/黄花梨架子床.png" },
    { name = "银耳挖",             rows = 1, cols = 1, quality = "gold",   value = 10458,  weight = 15,   desc = "纯银打造的耳挖勺，柄端雕龙",           image = IMG .. "古董/银耳挖.png" },
    { name = "老铜镜",             rows = 1, cols = 1, quality = "gold",   value = 18522,  weight = 9,    desc = "背面瑞兽纹铜镜，锈蚀但纹路清晰",       image = IMG .. "古董/老铜镜.png" },
    -- 红 ×10
    { name = "元青花大罐",   rows = 3, cols = 3, quality = "red",    value = 7619683,  weight = 3,    desc = "堆在角落的大肚瓷罐，釉面下隐约可见元代青花纹饰", image = IMG .. "古董/元青花大罐.png" },
    { name = "战国青铜剑",   rows = 2, cols = 1, quality = "red",    value = 214014,   weight = 109,  desc = "绿锈覆盖的青铜短剑，剑身有铭文",       image = IMG .. "古董/战国青铜剑.png" },
    { name = "唐三彩骆驼俑", rows = 2, cols = 2, quality = "red",    value = 2493617,  weight = 8,    desc = "釉色保存极好的三彩载乐骆驼俑",         image = IMG .. "古董/唐三彩骆驼俑.png" },
    { name = "商代青铜方鼎", rows = 3, cols = 3, quality = "red",    value = 15851064, weight = 1,    desc = "兽面纹青铜方鼎，出土级别文物",         image = IMG .. "古董/商代青铜方鼎.png" },
    { name = "汉代陶俑",     rows = 1, cols = 1, quality = "red",    value = 50000,    weight = 500,  desc = "汉代灰陶侍女俑，头部微残",             image = IMG .. "古董/汉代陶俑.png" },
    { name = "清代官帽",     rows = 1, cols = 1, quality = "red",    value = 390682,   weight = 58,   desc = "带翎管的七品官帽，顶珠完好",           image = IMG .. "古董/清代官帽.png" },
    { name = "瓷枕碎块",     rows = 1, cols = 1, quality = "purple", value = 5913,     weight = 3,    desc = "带完整花纹的宋代瓷枕碎片",             image = IMG .. "古董/瓷枕碎块.png" },
    { name = "铜造像残件",   rows = 1, cols = 1, quality = "gold",   value = 11516,    weight = 14,   desc = "断了一只手的小型铜鎏金佛像",           image = IMG .. "古董/铜造像残件.png" },
    { name = "老墨锭",       rows = 1, cols = 1, quality = "gold",   value = 20178,    weight = 8,    desc = "刻有老字号堂名的古墨，金色描边",       image = IMG .. "古董/老墨锭.png" },
    { name = "唐代铜镜",     rows = 1, cols = 1, quality = "red",    value = 104218,   weight = 232,  desc = "背面海兽葡萄纹的唐代铜镜，铸工精良",   image = IMG .. "古董/唐代铜镜.png" },
    { name = "汉代漆盒",     rows = 2, cols = 2, quality = "red",    value = 335560,   weight = 68,   desc = "红黑漆面的汉代木胎漆器小盒",           image = IMG .. "古董/汉代漆盒.png" },

    -- ===== 航海文物系列（maritime 标签） =====
    -- 白
    { name = "锈蚀船钉",       rows = 1, cols = 1, quality = "white",  value = 189,   weight = 3,  desc = "从沉船木料上取下的锻铁方头钉",                   image = IMG .. "古董/锈蚀船钉.png",     tags = {"maritime"} },
    { name = "沉船木板碎件",   rows = 1, cols = 2, quality = "white",  value = 452,   weight = 2,  desc = "打捞上岸的旧船肋骨木料，已石化",                 image = IMG .. "古董/沉船木板碎件.png", tags = {"maritime"} },
    -- 绿
    { name = "水手铜望远镜",   rows = 1, cols = 3, quality = "green",  value = 1711,  weight = 2,  desc = "黄铜单筒望远镜，镜片发雾但镜身完整",             image = IMG .. "古董/水手铜望远镜.png", tags = {"maritime"} },
    { name = "沉船陶罐",       rows = 2, cols = 1, quality = "green",  value = 2347,  weight = 2,  desc = "打捞自沉船货舱的宋代陶罐，外壁附着贝壳",         image = IMG .. "古董/沉船陶罐.png",     tags = {"maritime"} },
    -- 蓝
    { name = "黄铜六分仪",     rows = 1, cols = 1, quality = "blue",   value = 5413,  weight = 1,  desc = "清末航海用铜制六分仪，附原装皮盒，刻度清晰",     image = IMG .. "古董/黄铜六分仪.png",   tags = {"maritime"} },
    -- 紫
    { name = "清代海关铜印",   rows = 1, cols = 1, quality = "purple", value = 12889, weight = 2,  desc = "清代粤海关铜质关防印，背面刻官署名与年份",       image = IMG .. "古董/清代海关铜印.png", tags = {"maritime"} },
    { name = "老水手罗盘",     rows = 1, cols = 1, quality = "purple", value = 18450, weight = 1,  desc = "欧式黄铜干罗盘，玫瑰盘图案完好，压仓盒包原装",   image = IMG .. "古董/老水手罗盘.png",   tags = {"maritime"} },
    -- 金
    { name = "沉船铜炮",       rows = 2, cols = 4, quality = "gold",   value = 68240, weight = 2,  desc = "明代福船遗存的青铜炮，炮口海兽纹，铭文可辨",     image = IMG .. "古董/沉船铜炮.png",     tags = {"maritime"} },
    -- 红
    { name = "郑和宝船出水铜牌", rows = 1, cols = 2, quality = "red", value = 4870000, weight = 2, desc = "疑为永乐年宝船随行物件的铜质铭牌，附出水记录档", image = IMG .. "古董/郑和宝船出水铜牌.png", tags = {"maritime"} },

    -- ===== 书画善本系列（manuscript 标签） =====
    -- 金
    { name = "明代名家信札",     rows = 1, cols = 2, quality = "gold", value = 95000,    weight = 2, tags = {"manuscript"}, desc = "一批明代文人往来信件，含名臣手书数通，笔迹清晰",       image = IMG .. "古董/明代名家信札.png" },
    { name = "宋版刻本",         rows = 2, cols = 2, quality = "gold", value = 320000,   weight = 1, tags = {"manuscript"}, desc = "南宋淳熙年刻印经部典籍，存世仅数十册，品相尚好",       image = IMG .. "古董/宋版刻本.png" },
    -- 红
    { name = "唐人写经卷",       rows = 1, cols = 3, quality = "red",  value = 2400000,  weight = 2, tags = {"manuscript"}, desc = "唐代敦煌写经残卷，有题记纪年，出土有据，装裱未开",     image = IMG .. "古董/唐人写经卷.png" },
    { name = "宋徽宗瘦金体手卷", rows = 1, cols = 4, quality = "red",  value = 12000000, weight = 1, tags = {"manuscript"}, desc = "据传宋徽宗亲笔瘦金体题跋残卷，附民国鉴定录及旧藏印",   image = IMG .. "古董/宋徽宗瘦金体手卷.png" },
}

return Antique
