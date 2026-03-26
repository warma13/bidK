-- ============================================================================
-- Config/Warehouses/Storage.lua - 居民储物间物品配置
-- 旧城商业区仓库类型，包含 5 个品类共 145 件物品
-- value 即最终价格，无稀有度乘数
-- ============================================================================

local Storage = {}

-- 品类权重
Storage.categoryWeights = {
    furniture = 25,   -- 家具
    clothing  = 20,   -- 衣物箱包
    toy       = 25,   -- 玩具文具
    kitchen   = 20,   -- 厨具餐具
    daily     = 10,   -- 日用杂物
}

local IMG = "items/"

-- ============================================================================
-- 家具 (29件)
-- ============================================================================
Storage.furniture = {
    -- 白 ×10
    { name = "破板凳",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "腿晃悠的小木板凳",                   image = IMG .. "家具/破板凳.png" },
    { name = "旧鞋架",       rows = 2, cols = 1, quality = "white",    value = 25,      desc = "歪了的塑料鞋架",                     image = IMG .. "家具/旧鞋架.png" },
    { name = "坏折叠椅",     rows = 1, cols = 1, quality = "white",    value = 20,      desc = "铁管弯了的折叠椅",                   image = IMG .. "家具/坏折叠椅.png" },
    { name = "旧衣架",       rows = 1, cols = 1, quality = "white",    value = 10,      desc = "一把变形的铁丝衣架",                 image = IMG .. "家具/旧衣架.png" },
    { name = "破花盆",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "裂了一道缝的陶花盆",                 image = IMG .. "家具/破花盆.png" },
    { name = "旧塑料桶",     rows = 2, cols = 2, quality = "white",    value = 20,      desc = "褪色变脆的塑料水桶",                 image = IMG .. "家具/旧塑料桶.png" },
    { name = "破竹帘",       rows = 1, cols = 3, quality = "white",    value = 30,      desc = "断了好几根的竹帘子",                 image = IMG .. "家具/破竹帘.png" },
    { name = "旧镜框",       rows = 2, cols = 1, quality = "white",    value = 25,      desc = "镜面起雾的木镜框",                   image = IMG .. "家具/旧镜框.png" },
    { name = "旧草席",       rows = 2, cols = 3, quality = "white",    value = 35,      desc = "卷了边的凉席",                       image = IMG .. "家具/旧草席.png" },
    { name = "旧五斗柜",     rows = 3, cols = 3, quality = "white",    value = 50,      desc = "抽屉拉不开的五斗柜",                 image = IMG .. "家具/旧五斗柜.png" },
    -- 绿 ×8
    { name = "老藤椅",       rows = 2, cols = 2, quality = "green",  value = 180,     desc = "坐面塌了的老藤椅",                   image = IMG .. "家具/老藤椅.png" },
    { name = "旧梳妆台",     rows = 2, cols = 2, quality = "green",  value = 220,     desc = "镜面斑驳的老梳妆台",                 image = IMG .. "家具/旧梳妆台.png" },
    { name = "老皮箱",       rows = 2, cols = 3, quality = "green",  value = 200,     desc = "牛皮手提箱，锁扣生锈",               image = IMG .. "家具/老皮箱.png" },
    { name = "旧书架",       rows = 3, cols = 2, quality = "green",  value = 250,     desc = "松木书架，搁板弯了",                 image = IMG .. "家具/旧书架.png" },
    { name = "老樟木箱",     rows = 2, cols = 3, quality = "green",  value = 280,     desc = "还有香味的樟木衣箱",                 image = IMG .. "家具/老樟木箱.png" },
    { name = "旧摇椅",       rows = 2, cols = 2, quality = "green",  value = 160,     desc = "咯吱响的竹摇椅",                     image = IMG .. "家具/旧摇椅.png" },
    { name = "老穿衣镜",     rows = 3, cols = 1, quality = "green",  value = 150,     desc = "木框落地穿衣镜",                     image = IMG .. "家具/老穿衣镜.png" },
    { name = "旧屏风",       rows = 3, cols = 2, quality = "green",  value = 230,     desc = "布面松了的三折屏风",                 image = IMG .. "家具/旧屏风.png" },
    -- 蓝 ×5
    { name = "老红木椅",     rows = 2, cols = 2, quality = "blue",      value = 500,     desc = "雕花靠背的红木椅子",                 image = IMG .. "家具/老红木椅.png" },
    { name = "旧留声机柜",   rows = 2, cols = 2, quality = "blue",      value = 700,     desc = "老式落地留声机柜，机芯缺失",         image = IMG .. "家具/旧留声机柜.png" },
    { name = "老黄花梨小几", rows = 1, cols = 2, quality = "blue",      value = 600,     desc = "包浆深厚的小茶几",                   image = IMG .. "家具/老黄花梨小几.png" },
    { name = "旧大衣柜",     rows = 3, cols = 4, quality = "blue",      value = 800,     desc = "雕花老衣柜，合页还好",               image = IMG .. "家具/旧大衣柜.png" },
    { name = "老罗汉床",     rows = 3, cols = 4, quality = "blue",      value = 750,     desc = "榆木罗汉床，榫卯结实",               image = IMG .. "家具/老罗汉床.png" },
    -- 紫 ×3
    { name = "老黄花梨圈椅", rows = 2, cols = 2, quality = "purple",      value = 1800,    desc = "明式圈椅，线条优美",                 image = IMG .. "家具/老黄花梨圈椅.png" },
    { name = "老紫檀条案",   rows = 2, cols = 4, quality = "purple",      value = 45000,   desc = "紫檀木条案，雕工精美",               image = IMG .. "家具/老紫檀条案.png" },
    { name = "清代架子床",   rows = 3, cols = 4, quality = "purple",      value = 200000,  desc = "三面围栏的清代架子床",               image = IMG .. "家具/清代架子床.png" },
    -- 金 ×2
    { name = "海南黄花梨笔筒", rows = 1, cols = 1, quality = "gold", value = 5000,  desc = "鬼脸纹海黄笔筒",                     image = IMG .. "家具/海南黄花梨笔筒.png" },
    { name = "明代楠木柜",   rows = 3, cols = 4, quality = "gold", value = 3000000, desc = "金丝楠木顶箱柜，铜件完整",           image = IMG .. "家具/明代楠木柜.png" },
    -- 红 ×1
    { name = "紫檀嵌玉屏风", rows = 3, cols = 4, quality = "red",    value = 18000000, desc = "清宫紫檀框嵌百宝大屏风", image = IMG .. "家具/紫檀嵌玉屏风.png" },
}

-- ============================================================================
-- 衣物箱包 (29件)
-- ============================================================================
Storage.clothing = {
    -- 白 ×10
    { name = "旧棉鞋",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "鞋底开胶的老棉鞋",                   image = IMG .. "衣物/旧棉鞋.png" },
    { name = "破雨伞",       rows = 1, cols = 2, quality = "white",    value = 10,      desc = "骨架断了的折叠伞",                   image = IMG .. "衣物/破雨伞.png" },
    { name = "旧帆布包",     rows = 1, cols = 1, quality = "white",    value = 20,      desc = "磨出洞的军绿帆布包",                 image = IMG .. "衣物/旧帆布包.png" },
    { name = "破棉袄",       rows = 2, cols = 2, quality = "white",    value = 25,      desc = "跑棉花的老棉袄",                     image = IMG .. "衣物/破棉袄.png" },
    { name = "旧草帽",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "帽檐断了的麦秆草帽",                 image = IMG .. "衣物/旧草帽.png" },
    { name = "旧布鞋",       rows = 1, cols = 1, quality = "white",    value = 20,      desc = "千层底老布鞋，底磨穿了",             image = IMG .. "衣物/旧布鞋.png" },
    { name = "旧毛线团",     rows = 1, cols = 1, quality = "white",    value = 10,      desc = "缠乱了的毛线球",                     image = IMG .. "衣物/旧毛线团.png" },
    { name = "破围巾",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "起球的毛线围巾",                     image = IMG .. "衣物/破围巾.png" },
    { name = "旧皮带",       rows = 1, cols = 1, quality = "white",    value = 25,      desc = "皮面开裂的旧皮带",                   image = IMG .. "衣物/旧皮带.png" },
    { name = "旧衣物包裹",   rows = 2, cols = 3, quality = "white",    value = 40,      desc = "一大包旧衣服，用塑料袋装着",         image = IMG .. "衣物/旧衣物包裹.png" },
    -- 绿 ×8
    { name = "旧呢子大衣",   rows = 2, cols = 2, quality = "green",  value = 180,     desc = "七十年代的呢子大衣",                 image = IMG .. "衣物/旧呢子大衣.png" },
    { name = "老军装",       rows = 2, cols = 2, quality = "green",  value = 150,     desc = "六五式军装上衣",                     image = IMG .. "衣物/老军装.png" },
    { name = "旧真皮皮鞋",   rows = 1, cols = 1, quality = "green",  value = 130,     desc = "需要上油的老式皮鞋",                 image = IMG .. "衣物/旧真皮皮鞋.png" },
    { name = "老旗袍",       rows = 2, cols = 1, quality = "green",  value = 200,     desc = "面料有些褪色的丝绸旗袍",             image = IMG .. "衣物/老旗袍.png" },
    { name = "旧皮夹克",     rows = 2, cols = 2, quality = "green",  value = 220,     desc = "八十年代的皮夹克",                   image = IMG .. "衣物/旧皮夹克.png" },
    { name = "老手提箱",     rows = 2, cols = 3, quality = "green",  value = 160,     desc = "贴满标签的老手提箱",                 image = IMG .. "衣物/老手提箱.png" },
    { name = "旧丝巾",       rows = 1, cols = 1, quality = "green",  value = 120,     desc = "花色雅致的真丝方巾",                 image = IMG .. "衣物/旧丝巾.png" },
    { name = "老皮靴",       rows = 2, cols = 1, quality = "green",  value = 250,     desc = "翻毛皮的老军靴",                     image = IMG .. "衣物/老皮靴.png" },
    -- 蓝 ×5
    { name = "老缂丝围巾",   rows = 1, cols = 2, quality = "blue",      value = 500,     desc = "精美的缂丝工艺围巾",                 image = IMG .. "衣物/老缂丝围巾.png" },
    { name = "旧皮手套",     rows = 1, cols = 1, quality = "blue",      value = 400,     desc = "做工考究的羊皮手套",                 image = IMG .. "衣物/旧皮手套.png" },
    { name = "老旅行箱",     rows = 2, cols = 3, quality = "blue",      value = 650,     desc = "帆布包铜角的老旅行箱",               image = IMG .. "衣物/老旅行箱.png" },
    { name = "老手工旗袍",   rows = 2, cols = 1, quality = "blue",      value = 700,     desc = "手工盘扣苏绣旗袍",                   image = IMG .. "衣物/老手工旗袍.png" },
    { name = "老皮草大衣",   rows = 2, cols = 3, quality = "blue",      value = 800,     desc = "有年代感的貂皮大衣",                 image = IMG .. "衣物/老皮草大衣.png" },
    -- 紫 ×3
    { name = "民国名媛旗袍", rows = 2, cols = 1, quality = "purple",      value = 1500,    desc = "绣有暗花的高级定制旗袍",             image = IMG .. "衣物/民国名媛旗袍.png" },
    { name = "老LV旅行箱",   rows = 3, cols = 4, quality = "purple",      value = 55000,   desc = "老款LV帆布硬箱，五金完好",           image = IMG .. "衣物/老LV旅行箱.png" },
    { name = "宫廷龙袍残件", rows = 2, cols = 3, quality = "purple",      value = 180000,  desc = "明黄缎面绣龙的衣袍残片",             image = IMG .. "衣物/宫廷龙袍残件.png" },
    -- 金 ×2
    { name = "清代官帽",     rows = 1, cols = 1, quality = "gold", value = 4500,    desc = "红珊瑚顶戴的清代官帽",               image = IMG .. "衣物/清代官帽.png" },
    { name = "慈禧御用绣品", rows = 2, cols = 3, quality = "gold", value = 2800000, desc = "据传出自清宫的双面绣挂屏",           image = IMG .. "衣物/慈禧御用绣品.png" },
    -- 红 ×1
    { name = "明代织金蟒袍", rows = 2, cols = 3, quality = "red",    value = 15000000, desc = "保存完好的明代织金蟒袍", image = IMG .. "衣物/明代织金蟒袍.png" },
}

-- ============================================================================
-- 玩具文具 (29件)
-- ============================================================================
Storage.toy = {
    -- 白 ×10
    { name = "旧毛绒熊",     rows = 1, cols = 1, quality = "white",    value = 20,      desc = "棉花露出来的旧泰迪熊",               image = IMG .. "玩具/旧毛绒熊.png" },
    { name = "断蜡笔",       rows = 1, cols = 1, quality = "white",    value = 10,      desc = "剩半截的蜡笔盒",                     image = IMG .. "玩具/断蜡笔.png" },
    { name = "旧象棋",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "缺了几颗子的木象棋",                 image = IMG .. "玩具/旧象棋.png" },
    { name = "破积木",       rows = 1, cols = 2, quality = "white",    value = 20,      desc = "磨损的彩色积木块",                   image = IMG .. "玩具/破积木.png" },
    { name = "旧弹弓",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "皮筋松了的铁丝弹弓",                 image = IMG .. "玩具/旧弹弓.png" },
    { name = "坏万花筒",     rows = 1, cols = 1, quality = "white",    value = 25,      desc = "转不动的铁皮万花筒",                 image = IMG .. "玩具/坏万花筒.png" },
    { name = "旧钢笔",       rows = 1, cols = 1, quality = "white",    value = 30,      desc = "笔尖歪了的老钢笔",                   image = IMG .. "玩具/旧钢笔.png" },
    { name = "破拼图",       rows = 1, cols = 1, quality = "white",    value = 10,      desc = "少了几片的千片拼图",                 image = IMG .. "玩具/破拼图.png" },
    { name = "旧跳棋",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "掉了几颗玻璃珠的跳棋盘",             image = IMG .. "玩具/旧跳棋.png" },
    { name = "旧玩具箱",     rows = 2, cols = 3, quality = "white",    value = 40,      desc = "装满杂七杂八玩具的纸箱",             image = IMG .. "玩具/旧玩具箱.png" },
    -- 绿 ×8
    { name = "铁皮机器人",   rows = 1, cols = 1, quality = "green",  value = 180,     desc = "上发条会走的铁皮机器人",             image = IMG .. "玩具/铁皮机器人.png" },
    { name = "老地球仪",     rows = 2, cols = 2, quality = "green",  value = 150,     desc = "国界线过时的老地球仪",               image = IMG .. "玩具/老地球仪.png" },
    { name = "旧望远镜",     rows = 1, cols = 2, quality = "green",  value = 130,     desc = "塑料壳的儿童望远镜",                 image = IMG .. "玩具/旧望远镜.png" },
    { name = "老四驱车",     rows = 1, cols = 1, quality = "green",  value = 120,     desc = "奥迪双钻四驱车，缺电池盖",           image = IMG .. "玩具/老四驱车.png" },
    { name = "旧溜溜球",     rows = 1, cols = 1, quality = "green",  value = 100,     desc = "火力少年王同款悠悠球",               image = IMG .. "玩具/旧溜溜球.png" },
    { name = "老英雄钢笔",   rows = 1, cols = 1, quality = "green",  value = 200,     desc = "英雄100金笔，笔尖完好",              image = IMG .. "玩具/老英雄钢笔.png" },
    { name = "老水彩颜料",   rows = 1, cols = 2, quality = "green",  value = 160,     desc = "马利牌国画颜料盒",                   image = IMG .. "玩具/老水彩颜料.png" },
    { name = "旧显微镜",     rows = 2, cols = 1, quality = "green",  value = 250,     desc = "学生用单目显微镜",                   image = IMG .. "玩具/旧显微镜.png" },
    -- 蓝 ×5
    { name = "老万代高达",   rows = 2, cols = 1, quality = "blue",      value = 450,     desc = "初代RX-78高达模型",                  image = IMG .. "玩具/老万代高达.png" },
    { name = "旧乐高城堡",   rows = 2, cols = 3, quality = "blue",      value = 650,     desc = "拼好的乐高经典城堡",                 image = IMG .. "玩具/旧乐高城堡.png" },
    { name = "老变形金刚",   rows = 1, cols = 1, quality = "blue",      value = 500,     desc = "G1擎天柱玩具",                       image = IMG .. "玩具/老变形金刚.png" },
    { name = "老百科全书",   rows = 2, cols = 3, quality = "blue",      value = 550,     desc = "十二本装的少儿百科全书",             image = IMG .. "玩具/老百科全书.png" },
    { name = "旧派克笔套装", rows = 1, cols = 2, quality = "blue",      value = 700,     desc = "木盒装派克金笔钢笔套装",             image = IMG .. "玩具/旧派克笔套装.png" },
    -- 紫 ×3
    { name = "绝版高达模型", rows = 2, cols = 2, quality = "purple",      value = 1500,    desc = "限定版PG强袭自由高达",               image = IMG .. "玩具/绝版高达模型.png" },
    { name = "老版连环画全套", rows = 2, cols = 3, quality = "purple",    value = 48000,   desc = "六十年代《三国演义》连环画全48册",    image = IMG .. "玩具/老版连环画全套.png" },
    { name = "清代棋具",     rows = 2, cols = 2, quality = "purple",      value = 160000,  desc = "象牙围棋子配紫檀棋盒",               image = IMG .. "玩具/清代棋具.png" },
    -- 金 ×2
    { name = "初版万智牌黑莲花", rows = 1, cols = 1, quality = "gold", value = 5500, desc = "Alpha版黑莲花卡牌",                image = IMG .. "玩具/初版万智牌黑莲花.png" },
    { name = "宋版书残卷",   rows = 2, cols = 3, quality = "gold", value = 3500000, desc = "宋代刻本古籍残卷",                   image = IMG .. "玩具/宋版书残卷.png" },
    -- 红 ×1
    { name = "敦煌写经残页", rows = 2, cols = 3, quality = "red",    value = 20000000, desc = "疑似敦煌藏经洞流出的唐代写经残页", image = IMG .. "玩具/敦煌写经残页.png" },
}

-- ============================================================================
-- 厨具餐具 (29件)
-- ============================================================================
Storage.kitchen = {
    -- 白 ×10
    { name = "缺口碗",       rows = 1, cols = 1, quality = "white",    value = 10,      desc = "豁了口的粗瓷大碗",                   image = IMG .. "厨具/缺口碗.png" },
    { name = "旧铝锅",       rows = 2, cols = 2, quality = "white",    value = 30,      desc = "底部发黑的铝锅",                     image = IMG .. "厨具/旧铝锅.png" },
    { name = "断筷子",       rows = 1, cols = 1, quality = "white",    value = 5,       desc = "不成对的旧筷子",                     image = IMG .. "厨具/断筷子.png" },
    { name = "旧菜刀",       rows = 1, cols = 1, quality = "white",    value = 25,      desc = "刃口卷了的菜刀",                     image = IMG .. "厨具/旧菜刀.png" },
    { name = "破热水瓶",     rows = 2, cols = 1, quality = "white",    value = 20,      desc = "内胆碎了的竹壳热水瓶",               image = IMG .. "厨具/破热水瓶.png" },
    { name = "旧搪瓷盆",     rows = 2, cols = 2, quality = "white",    value = 25,      desc = "掉瓷的搪瓷洗脸盆",                   image = IMG .. "厨具/旧搪瓷盆.png" },
    { name = "旧饭盒",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "凹了的铝制饭盒",                     image = IMG .. "厨具/旧饭盒.png" },
    { name = "破水壶",       rows = 1, cols = 1, quality = "white",    value = 20,      desc = "壶嘴漏水的铝水壶",                   image = IMG .. "厨具/破水壶.png" },
    { name = "旧漏勺",       rows = 1, cols = 1, quality = "white",    value = 10,      desc = "把手松动的铁漏勺",                   image = IMG .. "厨具/旧漏勺.png" },
    { name = "旧碗柜",       rows = 3, cols = 3, quality = "white",    value = 45,      desc = "纱门破了的老碗橱",                   image = IMG .. "厨具/旧碗柜.png" },
    -- 绿 ×8
    { name = "老铁壶",       rows = 1, cols = 1, quality = "green",  value = 150,     desc = "铸铁茶壶，壶盖齐全",                 image = IMG .. "厨具/老铁壶.png" },
    { name = "旧铜锅",       rows = 2, cols = 2, quality = "green",  value = 200,     desc = "铜底铁把的老炒锅",                   image = IMG .. "厨具/旧铜锅.png" },
    { name = "老蒸笼",       rows = 2, cols = 2, quality = "green",  value = 130,     desc = "三层竹蒸笼",                         image = IMG .. "厨具/老蒸笼.png" },
    { name = "旧搪瓷套碗",   rows = 1, cols = 2, quality = "green",  value = 160,     desc = "一套五个可叠放搪瓷碗",               image = IMG .. "厨具/旧搪瓷套碗.png" },
    { name = "老石磨",       rows = 2, cols = 2, quality = "green",  value = 250,     desc = "小型手摇石磨",                       image = IMG .. "厨具/老石磨.png" },
    { name = "旧铜火锅",     rows = 2, cols = 2, quality = "green",  value = 220,     desc = "炭火铜火锅，烟囱齐全",               image = IMG .. "厨具/旧铜火锅.png" },
    { name = "老陶罐",       rows = 2, cols = 2, quality = "green",  value = 180,     desc = "腌咸菜的大陶罐",                     image = IMG .. "厨具/老陶罐.png" },
    { name = "旧锡壶",       rows = 1, cols = 1, quality = "green",  value = 140,     desc = "锡制温酒壶",                         image = IMG .. "厨具/旧锡壶.png" },
    -- 蓝 ×5
    { name = "老紫砂煲",     rows = 2, cols = 2, quality = "blue",      value = 500,     desc = "老紫砂炖盅，盖子齐全",               image = IMG .. "厨具/老紫砂煲.png" },
    { name = "铜制涮锅",     rows = 2, cols = 2, quality = "blue",      value = 600,     desc = "黄铜涮羊肉锅，做工精细",             image = IMG .. "厨具/铜制涮锅.png" },
    { name = "老青花瓷碗套", rows = 1, cols = 2, quality = "blue",      value = 700,     desc = "成套的青花瓷碗碟",                   image = IMG .. "厨具/老青花瓷碗套.png" },
    { name = "旧银筷子",     rows = 1, cols = 1, quality = "blue",      value = 450,     desc = "发黑的银质筷子一双",                 image = IMG .. "厨具/旧银筷子.png" },
    { name = "铁板烧铁板",   rows = 2, cols = 3, quality = "blue",      value = 550,     desc = "厚铸铁板烧铁板，带底座",             image = IMG .. "厨具/铁板烧铁板.png" },
    -- 紫 ×3
    { name = "景德镇茶具套装", rows = 1, cols = 2, quality = "purple",    value = 1800,    desc = "景德镇手绘粉彩茶具",                 image = IMG .. "厨具/景德镇茶具套装.png" },
    { name = "银制餐具套装", rows = 2, cols = 3, quality = "purple",      value = 50000,   desc = "欧式银质刀叉勺全套",                 image = IMG .. "厨具/银制餐具套装.png" },
    { name = "清代粉彩大盘", rows = 2, cols = 2, quality = "purple",      value = 170000,  desc = "盘面绘有花鸟的粉彩大盘",             image = IMG .. "厨具/清代粉彩大盘.png" },
    -- 金 ×2
    { name = "宣德炉香薰",   rows = 1, cols = 1, quality = "gold", value = 4000,    desc = "带底款的宣德炉形香薰",               image = IMG .. "厨具/宣德炉香薰.png" },
    { name = "元代钧窑碗",   rows = 1, cols = 1, quality = "gold", value = 2500000, desc = "窑变天蓝釉的钧窑碗",                 image = IMG .. "厨具/元代钧窑碗.png" },
    -- 红 ×1
    { name = "汝窑天青釉盏", rows = 1, cols = 1, quality = "red",    value = 22000000, desc = "极其罕见的宋代汝窑天青釉茶盏", image = IMG .. "厨具/汝窑天青釉盏.png" },
}

-- ============================================================================
-- 日用杂物 (29件)
-- ============================================================================
Storage.daily = {
    -- 白 ×10
    { name = "旧闹钟",       rows = 1, cols = 1, quality = "white",    value = 20,      desc = "不响了的上弦闹钟",                   image = IMG .. "日用/旧闹钟.png" },
    { name = "空药瓶",       rows = 1, cols = 1, quality = "white",    value = 5,       desc = "旧玻璃药瓶",                         image = IMG .. "日用/空药瓶.png" },
    { name = "旧台历",       rows = 1, cols = 1, quality = "white",    value = 10,      desc = "过期的翻页台历",                     image = IMG .. "日用/旧台历.png" },
    { name = "断柄扫帚",     rows = 2, cols = 1, quality = "white",    value = 10,      desc = "把断了的竹扫帚",                     image = IMG .. "日用/断柄扫帚.png" },
    { name = "旧相册",       rows = 1, cols = 2, quality = "white",    value = 30,      desc = "塑料封皮的老相册",                   image = IMG .. "日用/旧相册.png" },
    { name = "旧电扇",       rows = 2, cols = 2, quality = "white",    value = 35,      desc = "塑料壳台扇，叶片变形",               image = IMG .. "日用/旧电扇.png" },
    { name = "破暖壶",       rows = 2, cols = 1, quality = "white",    value = 15,      desc = "外壳磕碰的铁皮暖壶",                 image = IMG .. "日用/破暖壶.png" },
    { name = "旧温度计",     rows = 1, cols = 1, quality = "white",    value = 15,      desc = "水银柱断了的温度计",                 image = IMG .. "日用/旧温度计.png" },
    { name = "旧日记本",     rows = 1, cols = 1, quality = "white",    value = 20,      desc = "写了几页就搁置的日记本",             image = IMG .. "日用/旧日记本.png" },
    { name = "旧行李箱",     rows = 2, cols = 3, quality = "white",    value = 45,      desc = "轮子坏了的旧行李箱",                 image = IMG .. "日用/旧行李箱.png" },
    -- 绿 ×8
    { name = "老座机电话",   rows = 1, cols = 1, quality = "green",  value = 150,     desc = "按键电话机，还能拨号",               image = IMG .. "日用/老座机电话.png" },
    { name = "旧收音机",     rows = 1, cols = 2, quality = "green",  value = 180,     desc = "牡丹牌半导体收音机",                 image = IMG .. "日用/旧收音机.png" },
    { name = "老台灯",       rows = 1, cols = 1, quality = "green",  value = 120,     desc = "绿罩子的老银行台灯",                 image = IMG .. "日用/老台灯.png" },
    { name = "旧手风琴",     rows = 2, cols = 3, quality = "green",  value = 250,     desc = "还能拉响的鹦鹉牌手风琴",             image = IMG .. "日用/旧手风琴.png" },
    { name = "老二胡",       rows = 2, cols = 1, quality = "green",  value = 200,     desc = "蛇皮鼓面的老二胡",                   image = IMG .. "日用/老二胡.png" },
    { name = "旧挂历",       rows = 2, cols = 1, quality = "green",  value = 130,     desc = "八十年代美人挂历画",                 image = IMG .. "日用/旧挂历.png" },
    { name = "老算盘",       rows = 1, cols = 3, quality = "green",  value = 160,     desc = "十三档花梨木算盘",                   image = IMG .. "日用/老算盘.png" },
    { name = "旧药箱",       rows = 1, cols = 2, quality = "green",  value = 140,     desc = "铝制医药箱，红十字标",               image = IMG .. "日用/旧药箱.png" },
    -- 蓝 ×5
    { name = "老唱片",       rows = 1, cols = 1, quality = "blue",      value = 400,     desc = "黑胶唱片，邓丽君专辑",               image = IMG .. "日用/老唱片.png" },
    { name = "旧自鸣钟",     rows = 2, cols = 2, quality = "blue",      value = 600,     desc = "到点会敲的老自鸣钟",                 image = IMG .. "日用/旧自鸣钟.png" },
    { name = "老口琴",       rows = 1, cols = 1, quality = "blue",      value = 500,     desc = "Hohner老口琴，音还准",               image = IMG .. "日用/老口琴.png" },
    { name = "旧照相机",     rows = 1, cols = 1, quality = "blue",      value = 550,     desc = "凤凰205B相机，带皮套",               image = IMG .. "日用/旧照相机.png" },
    { name = "老手摇唱机",   rows = 2, cols = 3, quality = "blue",      value = 750,     desc = "百代牌手摇留声机",                   image = IMG .. "日用/老手摇唱机.png" },
    -- 紫 ×3
    { name = "民国老照片集", rows = 1, cols = 2, quality = "purple",      value = 1200,    desc = "一册民国时期的老照片",               image = IMG .. "日用/民国老照片集.png" },
    { name = "老柯达相机",   rows = 1, cols = 1, quality = "purple",      value = 42000,   desc = "柯达Retina古董相机",                 image = IMG .. "日用/老柯达相机.png" },
    { name = "老风琴",       rows = 3, cols = 4, quality = "purple",      value = 150000,  desc = "教堂退役的簧风琴",                   image = IMG .. "日用/老风琴.png" },
    -- 金 ×2
    { name = "老上海牌手表", rows = 1, cols = 1, quality = "gold", value = 5000,    desc = "编号靠前的老上海牌手表",             image = IMG .. "日用/老上海牌手表.png" },
    { name = "老钢琴",       rows = 3, cols = 4, quality = "gold", value = 2800000, desc = "施坦威老三角钢琴",                   image = IMG .. "日用/老钢琴.png" },
    -- 红 ×1
    { name = "斯特拉迪瓦里小提琴", rows = 1, cols = 2, quality = "red", value = 25000000, desc = "被当成旧琴丢在角落的意大利名琴", image = IMG .. "日用/斯特拉迪瓦里小提琴.png" },
}

-- 品类列表
Storage.categories = {
    { id = "furniture", name = "家具", icon = "", items = Storage.furniture },
    { id = "clothing",  name = "衣物", icon = "", items = Storage.clothing },
    { id = "toy",       name = "玩具", icon = "", items = Storage.toy },
    { id = "kitchen",   name = "厨具", icon = "", items = Storage.kitchen },
    { id = "daily",     name = "日用", icon = "", items = Storage.daily },
}

return Storage
