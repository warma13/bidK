-- ============================================================================
-- Config/Categories/Jewel.lua - 珠宝品类物品池
-- 来源：ItemPool.jewel + QuantumLab.jewel
-- ============================================================================

local Jewel = {}

local IMG = "items/"
local IMG_QL = "items/"

Jewel.items = {
    -- ===== ItemPool 通用珠宝物品 =====
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
    -- 新增：白
    { name = "旧珠花",     rows = 1, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "掉了几颗珠子的头饰珠花",             image = IMG .. "珠宝/旧珠花.png" },
    { name = "旧表带",     rows = 3, cols = 1, quality = "white",    value = 105, weight = 2,      desc = "皮面开裂的旧表带",                   image = IMG .. "珠宝/旧表带.png",      tags = {"horology"} },
    { name = "铜纽扣盒",   rows = 1, cols = 2, quality = "white",    value = 189, weight = 2,      desc = "装满各色旧铜纽扣的铁盒",             image = IMG .. "珠宝/铜纽扣盒.png" },
    -- 新增：绿
    { name = "老银烟杆",   rows = 4, cols = 1, quality = "green",  value = 1711, weight = 1,     desc = "包浆厚重的银质旱烟杆",               image = IMG .. "珠宝/老银烟杆.png" },
    { name = "珊瑚树摆件", rows = 2, cols = 2, quality = "green",  value = 2604, weight = 1,     desc = "小型浅色珊瑚枝摆件",                 image = IMG .. "珠宝/珊瑚树摆件.png" },
    { name = "银手链",     rows = 1, cols = 3, quality = "green",  value = 793, weight = 2,     desc = "做工粗犷的老银手链",                 image = IMG .. "珠宝/银手链.png" },
    -- 新增：蓝
    { name = "老檀木珠串", rows = 1, cols = 2, quality = "blue",      value = 1206, weight = 2,     desc = "满是包浆的老檀木108颗长珠串",         image = IMG .. "珠宝/老檀木珠串.png" },
    { name = "银质梳妆盒", rows = 2, cols = 3, quality = "blue",      value = 6020, weight = 1,     desc = "雕花银质梳妆盒，内衬绒布",           image = IMG .. "珠宝/银质梳妆盒.png" },
    { name = "旧象牙筷",   rows = 3, cols = 1, quality = "blue",      value = 2169, weight = 2,     desc = "一双发黄的旧象牙筷子",               image = IMG .. "珠宝/旧象牙筷.png" },
    -- 新增：紫
    { name = "老金丝楠木匣", rows = 3, cols = 2, quality = "purple",    value = 13078, weight = 2,   desc = "金丝纹理明显的小木匣",               image = IMG .. "珠宝/老金丝楠木匣.png" },
    { name = "老珍珠冠",   rows = 2, cols = 2, quality = "purple",      value = 20763, weight = 1,  desc = "用珍珠和银丝编成的头冠",             image = IMG .. "珠宝/老珍珠冠.png" },
    -- 新增：金
    { name = "翡翠玉如意", rows = 3, cols = 1, quality = "gold", value = 98716, weight = 2, desc = "满绿翡翠雕成的如意，体量罕见",       image = IMG .. "珠宝/翡翠玉如意.png" },
    -- 科技相关：白
    { name = "坏智能手环",     rows = 1, cols = 1, quality = "white",  value = 335, weight = 1,      desc = "屏幕不亮的运动手环",                 image = IMG .. "珠宝/坏智能手环.png" },
    { name = "旧蓝牙戒指",     rows = 1, cols = 1, quality = "white",  value = 529, weight = 1,      desc = "充不进电的智能戒指",                 image = IMG .. "珠宝/旧蓝牙戒指.png" },
    -- 科技相关：绿
    { name = "钛合金表壳",     rows = 1, cols = 1, quality = "green",  value = 2347, weight = 1,     desc = "没有机芯的钛合金手表壳",             image = IMG .. "珠宝/钛合金表壳.png",  tags = {"horology"} },
    -- 科技相关：蓝
    { name = "铂金催化剂样品", rows = 1, cols = 1, quality = "blue",   value = 7411, weight = 1,     desc = "实验室遗留的铂金催化剂小瓶",         image = IMG .. "珠宝/铂金催化剂样品.png" },
    -- 科技相关：紫
    { name = "稀土金属样品套装", rows = 2, cols = 2, quality = "purple", value = 26640, weight = 1, desc = "标注齐全的17种稀土元素样品盒",       image = IMG .. "珠宝/稀土金属样品套装.png" },
    -- 科技相关：金
    { name = "铱金坩埚",       rows = 1, cols = 1, quality = "gold",   value = 77206, weight = 2,  desc = "实验室的高纯度铱金属坩埚，极耐高温", image = IMG .. "珠宝/铱金坩埚.png" },
    -- 低价补充
    { name = "银质发簪",         rows = 1, cols = 1, quality = "purple",  value = 2559, weight = 4,    desc = "缠丝工艺的老银发簪，簪头蝴蝶",         image = IMG .. "珠宝/银质发簪.png" },
    { name = "绿松石散珠",       rows = 1, cols = 1, quality = "purple",  value = 4114, weight = 3,    desc = "几颗天然绿松石圆珠，颜色尚可",         image = IMG .. "珠宝/绿松石散珠.png" },
    { name = "老银锁片",         rows = 1, cols = 1, quality = "gold",    value = 9910, weight = 16,    desc = "刻有'长命百岁'的银质长命锁",           image = IMG .. "珠宝/老银锁片.png" },
    { name = "玛瑙扳指",         rows = 1, cols = 1, quality = "gold",    value = 15573, weight = 11,    desc = "缠丝玛瑙扳指，纹理天然",               image = IMG .. "珠宝/玛瑙扳指.png" },
    { name = "翡翠观音挂件",     rows = 1, cols = 1, quality = "red",     value = 70763, weight = 348,  desc = "冰糯种翡翠观音牌，种水尚可",           image = IMG .. "珠宝/翡翠观音挂件.png" },
    { name = "老坑翡翠手镯",     rows = 1, cols = 1, quality = "red",     value = 646139, weight = 34,  desc = "老坑冰种飘花翡翠手镯，微有石纹",       image = IMG .. "珠宝/老坑翡翠手镯.png" },
    { name = "老银手镯",       rows = 1, cols = 1, quality = "purple",  value = 2156, weight = 5,    desc = "苗族银匠打制的老银手镯",                   image = IMG .. "珠宝/老银手镯.png" },
    { name = "蜜蜡碎料",       rows = 1, cols = 1, quality = "purple",  value = 3334, weight = 4,    desc = "几块天然蜜蜡原石碎料",                     image = IMG .. "珠宝/蜜蜡碎料.png" },
    { name = "珍珠碎串",       rows = 1, cols = 1, quality = "purple",  value = 5301, weight = 3,    desc = "断线散落的淡水珍珠一把",                   image = IMG .. "珠宝/珍珠碎串.png" },
    { name = "银质酒杯",       rows = 1, cols = 1, quality = "gold",    value = 11516, weight = 14,    desc = "欧式纯银雕花小酒杯",                       image = IMG .. "珠宝/银质酒杯.png" },
    { name = "琥珀虫珀",       rows = 1, cols = 1, quality = "gold",    value = 17447, weight = 10,    desc = "内含完整小虫的天然琥珀",                   image = IMG .. "珠宝/琥珀虫珀.png" },
    { name = "翡翠戒面",       rows = 1, cols = 1, quality = "red",     value = 214014, weight = 109,  desc = "满绿蛋面翡翠裸石，水头好",                 image = IMG .. "珠宝/翡翠戒面.png" },
    { name = "天然珍珠项链",   rows = 1, cols = 2, quality = "red",     value = 460518, weight = 49,  desc = "大溪地天然黑珍珠短项链",                   image = IMG .. "珠宝/天然珍珠项链.png" },

    -- ===== QuantumLab 稀有材料 =====
    -- 白 x3
    { name = "硅晶片废料",     rows = 1, cols = 1, quality = "white",  value = 105,       desc = "碎裂的半导体级硅晶圆边角料",                       image = IMG_QL .. "珠宝/硅晶片废料_20260510133238.png" },
    { name = "石英窗片",       rows = 1, cols = 1, quality = "white",  value = 177,       desc = "划痕累累的光学石英观察窗",                         image = IMG_QL .. "珠宝/石英窗片_20260510133242.png" },
    { name = "铟锡靶材残片",   rows = 1, cols = 2, quality = "white",  value = 236,       desc = "ITO溅射靶材的边角余料",                            image = IMG_QL .. "珠宝/铟锡靶材残片_20260510133447.png" },
    -- 绿 x1
    { name = "蓝宝石基板",     rows = 1, cols = 1, quality = "green",  value = 790,       desc = "用于外延生长的蓝宝石衬底",                         image = IMG_QL .. "珠宝/蓝宝石基板_20260510133253.png" },
    -- 蓝 x1
    { name = "铌酸锂晶体",     rows = 1, cols = 1, quality = "blue",   value = 2368,      desc = "非线性光学晶体，可用于频率转换",                   image = IMG_QL .. "珠宝/铌酸锂晶体_20260510133256.png" },
    -- 紫 x1
    { name = "金刚石NV色心样品", rows = 1, cols = 1, quality = "purple", value = 1996,     desc = "含氮空位色心的人造金刚石，量子传感器核心",         image = IMG_QL .. "珠宝/金刚石NV色心样品_20260510133240.png" },
    -- 金 x1
    { name = "超纯锗单晶",     rows = 1, cols = 2, quality = "gold",   value = 5000,      desc = "12N纯度的锗单晶锭，探测器级材料",                  image = IMG_QL .. "珠宝/超纯锗单晶_20260510133239.png" },
    -- 红 x1
    { name = "反氢原子捕获瓶", rows = 2, cols = 2, quality = "red",    value = 15000000,  desc = "磁阱中仍约束着微量反氢原子的真空容器",             image = IMG_QL .. "珠宝/反氢原子捕获瓶_20260510133240.png" },
    -- ===== 新增数据中心物品 =====
    { name = "液态金属戒指", rows = 1, cols = 1, quality = "blue", value = 12000, desc = "镓铟锡液态金属铸造戒指，温热即变形", image = IMG .. "珠宝/液态金属戒指.png" },
    { name = "碳纤维手骨套件", rows = 1, cols = 2, quality = "purple", value = 45000, desc = "仿生义肢用碳纤维手骨骨架套件", image = IMG .. "珠宝/碳纤维手骨套件.png" },
    { name = "碳纳米管样品管", rows = 1, cols = 1, quality = "blue", value = 8800, desc = "多壁碳纳米管粉末样品，密封管装", image = IMG .. "珠宝/碳纳米管样品管.png" },
    { name = "纳米涂层脊椎链", rows = 1, cols = 2, quality = "gold", value = 185000, desc = "纳米材料涂层仿生脊椎链节", image = IMG .. "珠宝/纳米涂层脊椎链.png" },
    { name = "钛合金义眼", rows = 1, cols = 1, quality = "purple", value = 38000, desc = "钛合金外壳义眼，内置光学传感器", image = IMG .. "珠宝/钛合金义眼.png" },
    { name = "银翼钛金胸甲", rows = 2, cols = 2, quality = "gold", value = 220000, desc = "钛合金内芯镀银外甲，赛博武士风格", image = IMG .. "珠宝/银翼钛金胸甲.png" },
    { name = "静电护腕", rows = 1, cols = 1, quality = "green", value = 2800, desc = "防静电导电护腕，精密操作必备", image = IMG .. "珠宝/静电护腕.png" },

    -- ===== 高级腕表系列（horology 标签） =====
    { name = "瑞士机芯怀表",     rows = 1, cols = 1, quality = "blue",   value = 18000,   tags = {"horology"}, desc = "19世纪瑞士金壳怀表，机芯仍走时准确，附原配表链",       image = IMG .. "珠宝/瑞士机芯怀表.png" },
    { name = "劳力士水鬼",       rows = 1, cols = 1, quality = "purple", value = 85000,   tags = {"horology"}, desc = "1960年代劳力士Submariner，原版蚊香盘，附鉴定书",         image = IMG .. "珠宝/劳力士水鬼.png" },
    { name = "百达翡丽年历表",   rows = 1, cols = 1, quality = "gold",   value = 460000,  tags = {"horology"}, desc = "百达翡丽5396G年历腕表，18K白金，附原装表盒和证书",       image = IMG .. "珠宝/百达翡丽年历表.png" },
    { name = "百年灵限量飞行表", rows = 1, cols = 1, quality = "red",    value = 1800000, tags = {"horology"}, desc = "百年灵为某航空公司定制的限量款，编号001/001，附出厂档案", image = IMG .. "珠宝/百年灵限量飞行表.png" },
    { name = "百达翡丽孤品三问", rows = 1, cols = 1, quality = "red",    value = 8500000, tags = {"horology"}, desc = "百达翡丽特别定制款三问报时表，全球孤品，附拍卖记录",     image = IMG .. "珠宝/百达翡丽孤品三问.png" },

}

return Jewel
