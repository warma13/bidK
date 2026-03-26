-- ============================================================================
-- Config/Warehouses/Repair.lua - 老修理铺物品配置
-- 旧城商业区仓库类型，包含 5 个品类共 145 件物品
-- value 即最终价格，无稀有度乘数
-- ============================================================================

local Repair = {}

-- 品类权重
Repair.categoryWeights = {
    tool    = 30,   -- 工具
    parts   = 30,   -- 零件
    electric = 25,  -- 电器
    hardware = 10,  -- 五金
    misc    = 5,    -- 杂货
}

local IMG = "items/"

-- ============================================================================
-- 工具 (29件)
-- ============================================================================
Repair.tool = {
    -- 白 ×10
    { name = "锈扳手",       rows = 1, cols = 2, quality = "white",    value = 25,      desc = "锈得拧不动的活动扳手",               image = IMG .. "工具/锈扳手.png" },
    { name = "断螺丝刀",     rows = 1, cols = 1, quality = "white",    value = 15,      desc = "刀头崩了的一字螺丝刀",               image = IMG .. "工具/断螺丝刀.png" },
    { name = "旧钳子",       rows = 1, cols = 1, quality = "white",    value = 30,      desc = "弹簧松了的尖嘴钳",                   image = IMG .. "工具/旧钳子.png" },
    { name = "钝锉刀",       rows = 1, cols = 2, quality = "white",    value = 20,      desc = "纹路磨平的三角锉",                   image = IMG .. "工具/钝锉刀.png" },
    { name = "旧铁锤",       rows = 1, cols = 1, quality = "white",    value = 35,      desc = "锤柄松动的小铁锤",                   image = IMG .. "工具/旧铁锤.png" },
    { name = "断锯条",       rows = 1, cols = 2, quality = "white",    value = 10,      desc = "断成两截的钢锯条",                   image = IMG .. "工具/断锯条.png" },
    { name = "旧卷尺",       rows = 1, cols = 1, quality = "white",    value = 20,      desc = "弹簧坏了收不回去的卷尺",             image = IMG .. "工具/旧卷尺.png" },
    { name = "秃毛刷子",     rows = 1, cols = 1, quality = "white",    value = 15,      desc = "毛掉了一半的油漆刷",                 image = IMG .. "工具/秃毛刷子.png" },
    { name = "旧砂纸",       rows = 1, cols = 1, quality = "white",    value = 10,      desc = "卷了边的粗砂纸",                     image = IMG .. "工具/旧砂纸.png" },
    { name = "破工具箱",     rows = 2, cols = 3, quality = "white",    value = 45,      desc = "搭扣坏了的铁皮工具箱",               image = IMG .. "工具/破工具箱.png" },
    -- 绿 ×8
    { name = "台钳",         rows = 2, cols = 2, quality = "green",  value = 180,     desc = "固定在工作台上的小台钳",             image = IMG .. "工具/台钳.png" },
    { name = "手摇钻",       rows = 1, cols = 2, quality = "green",  value = 150,     desc = "老式手摇胸钻，还能转",               image = IMG .. "工具/手摇钻.png" },
    { name = "铜焊枪",       rows = 1, cols = 2, quality = "green",  value = 200,     desc = "烧汽油的老式铜焊枪",                 image = IMG .. "工具/铜焊枪.png" },
    { name = "老水平仪",     rows = 1, cols = 2, quality = "green",  value = 130,     desc = "气泡管还完好的木水平尺",             image = IMG .. "工具/老水平仪.png" },
    { name = "铁皮剪",       rows = 1, cols = 2, quality = "green",  value = 160,     desc = "刃口还锋利的铁皮剪刀",               image = IMG .. "工具/铁皮剪.png" },
    { name = "老刨子",       rows = 1, cols = 2, quality = "green",  value = 220,     desc = "刨刃还能用的红木刨子",               image = IMG .. "工具/老刨子.png" },
    { name = "旧千斤顶",     rows = 2, cols = 2, quality = "green",  value = 250,     desc = "液压千斤顶，有点漏油",               image = IMG .. "工具/旧千斤顶.png" },
    { name = "拔轮器",       rows = 1, cols = 1, quality = "green",  value = 170,     desc = "三爪拔轮器，丝杆有磨损",             image = IMG .. "工具/拔轮器.png" },
    -- 蓝 ×5
    { name = "瑞士军刀",     rows = 1, cols = 1, quality = "blue",      value = 450,     desc = "功能齐全的老款瑞士军刀",             image = IMG .. "工具/瑞士军刀.png" },
    { name = "黄铜游标卡尺", rows = 1, cols = 2, quality = "blue",      value = 600,     desc = "刻度清晰的黄铜游标卡尺",             image = IMG .. "工具/黄铜游标卡尺.png" },
    { name = "老砂轮机",     rows = 2, cols = 2, quality = "blue",      value = 700,     desc = "铸铁底座的台式砂轮机",               image = IMG .. "工具/老砂轮机.png" },
    { name = "精密螺丝刀套装", rows = 1, cols = 2, quality = "blue",    value = 500,     desc = "木盒装的精密钟表螺丝刀",             image = IMG .. "工具/精密螺丝刀套装.png" },
    { name = "老车床卡盘",   rows = 2, cols = 2, quality = "blue",      value = 800,     desc = "三爪自定心卡盘，精度尚可",           image = IMG .. "工具/老车床卡盘.png" },
    -- 紫 ×3
    { name = "德国老虎钳",   rows = 2, cols = 2, quality = "purple",      value = 1500,    desc = "百年老厂铸造的重型虎钳",             image = IMG .. "工具/德国老虎钳.png" },
    { name = "铜制量角器套装", rows = 1, cols = 2, quality = "purple",    value = 40000,   desc = "航海用铜制量角器全套",               image = IMG .. "工具/铜制量角器套装.png" },
    { name = "老精密车床",   rows = 3, cols = 4, quality = "purple",      value = 180000,  desc = "瑞士产小型精密车床，齿轮完好",       image = IMG .. "工具/老精密车床.png" },
    -- 金 ×2
    { name = "钟表师工具箱", rows = 2, cols = 3, quality = "gold", value = 5000,    desc = "全套黄铜钟表维修工具",               image = IMG .. "工具/钟表师工具箱.png" },
    { name = "十九世纪测绘仪", rows = 2, cols = 2, quality = "gold", value = 2500000, desc = "黄铜经纬仪，镜片完好",             image = IMG .. "工具/十九世纪测绘仪.png" },
    -- 红 ×1
    { name = "达芬奇手稿复刻工具", rows = 3, cols = 3, quality = "red", value = 16000000, desc = "据传按达芬奇手稿打造的机械装置模型", image = IMG .. "工具/达芬奇手稿复刻工具.png" },
}

-- ============================================================================
-- 零件 (29件)
-- ============================================================================
Repair.parts = {
    -- 白 ×10
    { name = "锈螺丝堆",     rows = 1, cols = 1, quality = "white",    value = 10,      desc = "一把生锈的混合螺丝",                 image = IMG .. "零件/锈螺丝堆.png" },
    { name = "旧皮带轮",     rows = 1, cols = 1, quality = "white",    value = 30,      desc = "磨出沟的铸铁皮带轮",                 image = IMG .. "零件/旧皮带轮.png" },
    { name = "断弹簧",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "失去弹性的压缩弹簧",                 image = IMG .. "零件/断弹簧.png" },
    { name = "旧轴承",       rows = 1, cols = 1, quality = "white",    value = 25,      desc = "转起来咯咯响的旧轴承",               image = IMG .. "零件/旧轴承.png" },
    { name = "废铜管",       rows = 1, cols = 2, quality = "white",    value = 20,      desc = "压扁了的一截铜管",                   image = IMG .. "零件/废铜管.png" },
    { name = "旧密封圈",     rows = 1, cols = 1, quality = "white",    value = 10,      desc = "硬化开裂的橡胶密封圈",               image = IMG .. "零件/旧密封圈.png" },
    { name = "碎齿轮",       rows = 1, cols = 1, quality = "white",    value = 20,      desc = "缺了几个齿的小铁齿轮",               image = IMG .. "零件/碎齿轮.png" },
    { name = "旧活塞",       rows = 1, cols = 1, quality = "white",    value = 35,      desc = "拉缸了的发动机活塞",                 image = IMG .. "零件/旧活塞.png" },
    { name = "断链条",       rows = 1, cols = 2, quality = "white",    value = 25,      desc = "锈死的自行车链条",                   image = IMG .. "零件/断链条.png" },
    { name = "旧阀门",       rows = 2, cols = 2, quality = "white",    value = 40,      desc = "关不严的铸铁闸阀",                   image = IMG .. "零件/旧阀门.png" },
    -- 绿 ×8
    { name = "黄铜齿轮组",   rows = 1, cols = 1, quality = "green",  value = 150,     desc = "配合精密的黄铜齿轮对",               image = IMG .. "零件/黄铜齿轮组.png" },
    { name = "老化油器",     rows = 1, cols = 1, quality = "green",  value = 180,     desc = "摩托车化油器，还能清洗",             image = IMG .. "零件/老化油器.png" },
    { name = "铜散热片",     rows = 2, cols = 1, quality = "green",  value = 130,     desc = "拆下来的铜翅片散热器",               image = IMG .. "零件/铜散热片.png" },
    { name = "旧压力表",     rows = 1, cols = 1, quality = "green",  value = 160,     desc = "指针还准的铜壳压力表",               image = IMG .. "零件/旧压力表.png" },
    { name = "老发电机线圈", rows = 2, cols = 2, quality = "green",  value = 220,     desc = "手工绕制的铜线圈",                   image = IMG .. "零件/老发电机线圈.png" },
    { name = "铸铁飞轮",     rows = 2, cols = 2, quality = "green",  value = 200,     desc = "老缝纫机的铸铁飞轮",                 image = IMG .. "零件/铸铁飞轮.png" },
    { name = "旧水泵",       rows = 2, cols = 2, quality = "green",  value = 260,     desc = "手动活塞式抽水泵",                   image = IMG .. "零件/旧水泵.png" },
    { name = "老连杆",       rows = 1, cols = 2, quality = "green",  value = 140,     desc = "发动机铝合金连杆",                   image = IMG .. "零件/老连杆.png" },
    -- 蓝 ×5
    { name = "精密轴承组",   rows = 1, cols = 1, quality = "blue",      value = 500,     desc = "日本产精密滚珠轴承",                 image = IMG .. "零件/精密轴承组.png" },
    { name = "老缝纫机头",   rows = 2, cols = 3, quality = "blue",      value = 650,     desc = "蜜蜂牌老缝纫机机头",                 image = IMG .. "零件/老缝纫机头.png" },
    { name = "铜制气压阀",   rows = 1, cols = 1, quality = "blue",      value = 550,     desc = "做工精细的铜制减压阀",               image = IMG .. "零件/铜制气压阀.png" },
    { name = "老柴油机喷油嘴", rows = 1, cols = 1, quality = "blue",    value = 400,     desc = "德国产精密喷油嘴",                   image = IMG .. "零件/老柴油机喷油嘴.png" },
    { name = "机械钟机芯",   rows = 2, cols = 2, quality = "blue",      value = 750,     desc = "老座钟机芯，齿轮完好",               image = IMG .. "零件/机械钟机芯.png" },
    -- 紫 ×3
    { name = "船用铜螺旋桨", rows = 2, cols = 2, quality = "purple",      value = 2000,    desc = "小型船舶的青铜螺旋桨",               image = IMG .. "零件/船用铜螺旋桨.png" },
    { name = "老蒸汽机调速器", rows = 2, cols = 2, quality = "purple",    value = 55000,   desc = "精密的离心调速器",                   image = IMG .. "零件/老蒸汽机调速器.png" },
    { name = "航空发动机涡轮叶片", rows = 1, cols = 1, quality = "purple", value = 150000, desc = "标有编号的退役涡轮叶片",             image = IMG .. "零件/航空发动机涡轮叶片.png" },
    -- 金 ×2
    { name = "古董怀表机芯", rows = 1, cols = 1, quality = "gold", value = 4000,    desc = "十九世纪瑞士产怀表机芯",             image = IMG .. "零件/古董怀表机芯.png" },
    { name = "老蒸汽机汽缸", rows = 3, cols = 3, quality = "gold", value = 2800000, desc = "铸有厂标的蒸汽机铜汽缸",             image = IMG .. "零件/老蒸汽机汽缸.png" },
    -- 红 ×1
    { name = "瓦特蒸汽机复刻件", rows = 3, cols = 4, quality = "red", value = 20000000, desc = "疑似早期瓦特蒸汽机的铸铁缸体残件", image = IMG .. "零件/瓦特蒸汽机复刻件.png" },
}

-- ============================================================================
-- 电器 (29件)
-- ============================================================================
Repair.electric = {
    -- 白 ×10
    { name = "烧坏保险丝",   rows = 1, cols = 1, quality = "white",    value = 10,      desc = "熔断的陶瓷保险丝",                   image = IMG .. "电器/烧坏保险丝.png" },
    { name = "旧开关",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "拨不动的老式拉线开关",               image = IMG .. "电器/旧开关.png" },
    { name = "断电线",       rows = 1, cols = 1, quality = "white",    value = 10,      desc = "皮破了的一截旧电线",                 image = IMG .. "电器/断电线.png" },
    { name = "旧灯头",       rows = 1, cols = 1, quality = "white",    value = 20,      desc = "发黑的铜灯头",                       image = IMG .. "电器/旧灯头.png" },
    { name = "坏电熨斗",     rows = 1, cols = 2, quality = "white",    value = 35,      desc = "底板烧糊的老电熨斗",                 image = IMG .. "电器/坏电熨斗.png" },
    { name = "旧电阻",       rows = 1, cols = 1, quality = "white",    value = 10,      desc = "一把混杂的碳膜电阻",                 image = IMG .. "电器/旧电阻.png" },
    { name = "坏电风扇",     rows = 2, cols = 2, quality = "white",    value = 40,      desc = "扇叶断了的台式电扇",                 image = IMG .. "电器/坏电风扇.png" },
    { name = "旧电容",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "鼓包的电解电容",                     image = IMG .. "电器/旧电容.png" },
    { name = "坏日光灯",     rows = 1, cols = 3, quality = "white",    value = 20,      desc = "闪个不停的旧日光灯管",               image = IMG .. "电器/坏日光灯.png" },
    { name = "旧电闸",       rows = 1, cols = 1, quality = "white",    value = 30,      desc = "触点烧蚀的老式刀闸",                 image = IMG .. "电器/旧电闸.png" },
    -- 绿 ×8
    { name = "老万用表",     rows = 1, cols = 1, quality = "green",  value = 150,     desc = "指针还灵的模拟万用表",               image = IMG .. "电器/老万用表.png" },
    { name = "旧电烙铁",     rows = 1, cols = 2, quality = "green",  value = 120,     desc = "铜头发黑的老电烙铁",                 image = IMG .. "电器/旧电烙铁.png" },
    { name = "旧电机",       rows = 2, cols = 2, quality = "green",  value = 200,     desc = "单相交流电机，线圈完好",             image = IMG .. "电器/旧电机.png" },
    { name = "老变压器",     rows = 2, cols = 2, quality = "green",  value = 180,     desc = "工字型铁芯变压器",                   image = IMG .. "电器/老变压器.png" },
    { name = "旧吸尘器",     rows = 2, cols = 2, quality = "green",  value = 160,     desc = "苏联产的金属吸尘器",                 image = IMG .. "电器/旧吸尘器.png" },
    { name = "老电话交换机", rows = 2, cols = 3, quality = "green",  value = 250,     desc = "小型步进式电话交换机",               image = IMG .. "电器/老电话交换机.png" },
    { name = "旧稳压器",     rows = 2, cols = 2, quality = "green",  value = 140,     desc = "碳刷式交流稳压器",                   image = IMG .. "电器/旧稳压器.png" },
    { name = "老电唱机",     rows = 2, cols = 2, quality = "green",  value = 230,     desc = "木壳电唱机，唱臂还好",               image = IMG .. "电器/老电唱机.png" },
    -- 蓝 ×5
    { name = "老示波器",     rows = 2, cols = 2, quality = "blue",      value = 550,     desc = "军绿色的模拟示波器",                 image = IMG .. "电器/老示波器.png" },
    { name = "真空管功放",   rows = 2, cols = 3, quality = "blue",      value = 700,     desc = "四只电子管的老功放机",               image = IMG .. "电器/真空管功放.png" },
    { name = "老信号发生器", rows = 2, cols = 2, quality = "blue",      value = 600,     desc = "HP产音频信号发生器",                 image = IMG .. "电器/老信号发生器.png" },
    { name = "旧对讲机",     rows = 1, cols = 1, quality = "blue",      value = 450,     desc = "频率固定的军用对讲机",               image = IMG .. "电器/旧对讲机.png" },
    { name = "老短波电台",   rows = 2, cols = 3, quality = "blue",      value = 800,     desc = "手提式短波收发电台",                 image = IMG .. "电器/老短波电台.png" },
    -- 紫 ×3
    { name = "老尼克松真空管", rows = 1, cols = 1, quality = "purple",    value = 1800,    desc = "稀有型号的音频真空管",               image = IMG .. "电器/老尼克松真空管.png" },
    { name = "军用通信设备",   rows = 2, cols = 3, quality = "purple",    value = 60000,   desc = "冷战时期军用无线电台",               image = IMG .. "电器/军用通信设备.png" },
    { name = "老X光机",       rows = 3, cols = 3, quality = "purple",     value = 160000,  desc = "便携式医用X光机，铜壳外框",          image = IMG .. "电器/老X光机.png" },
    -- 金 ×2
    { name = "飞利浦初代CDPlayer", rows = 2, cols = 2, quality = "gold", value = 5500, desc = "飞利浦CD-100原型机",             image = IMG .. "电器/飞利浦初代CDPlayer.png" },
    { name = "老粒子探测器",   rows = 3, cols = 3, quality = "gold", value = 3000000, desc = "实验室退役的盖革-弥勒计数管",     image = IMG .. "电器/老粒子探测器.png" },
    -- 红 ×1
    { name = "早期晶体管原型", rows = 1, cols = 1, quality = "red",  value = 18000000, desc = "疑似贝尔实验室早期晶体管实验品", image = IMG .. "电器/早期晶体管原型.png" },
}

-- ============================================================================
-- 五金 (29件)
-- ============================================================================
Repair.hardware = {
    -- 白 ×10
    { name = "弯铁钉",       rows = 1, cols = 1, quality = "white",    value = 5,       desc = "砸弯了的一把铁钉",                   image = IMG .. "五金/弯铁钉.png" },
    { name = "旧铁丝",       rows = 1, cols = 1, quality = "white",    value = 10,      desc = "缠成一团的锈铁丝",                   image = IMG .. "五金/旧铁丝.png" },
    { name = "废铁片",       rows = 1, cols = 1, quality = "white",    value = 15,      desc = "边角料的薄铁片",                     image = IMG .. "五金/废铁片.png" },
    { name = "旧合页",       rows = 1, cols = 1, quality = "white",    value = 20,      desc = "锈住的铁合页",                       image = IMG .. "五金/旧合页.png" },
    { name = "断锁头",       rows = 1, cols = 1, quality = "white",    value = 25,      desc = "钥匙孔堵死的挂锁",                   image = IMG .. "五金/断锁头.png" },
    { name = "旧铁桶",       rows = 2, cols = 2, quality = "white",    value = 30,      desc = "漏底的铁皮桶",                       image = IMG .. "五金/旧铁桶.png" },
    { name = "废角铁",       rows = 1, cols = 2, quality = "white",    value = 15,      desc = "切歪了的角铁料头",                   image = IMG .. "五金/废角铁.png" },
    { name = "旧门把手",     rows = 1, cols = 1, quality = "white",    value = 20,      desc = "松动的铁门把手",                     image = IMG .. "五金/旧门把手.png" },
    { name = "碎铁链",       rows = 1, cols = 1, quality = "white",    value = 25,      desc = "断了几环的铁链子",                   image = IMG .. "五金/碎铁链.png" },
    { name = "旧铁皮柜",     rows = 3, cols = 3, quality = "white",    value = 50,      desc = "门关不严的铁皮储物柜",               image = IMG .. "五金/旧铁皮柜.png" },
    -- 绿 ×8
    { name = "黄铜门锁",     rows = 1, cols = 1, quality = "green",  value = 150,     desc = "机关还灵的老黄铜锁",                 image = IMG .. "五金/黄铜门锁.png" },
    { name = "铸铁炉架",     rows = 2, cols = 2, quality = "green",  value = 180,     desc = "花纹精致的铸铁壁炉架",               image = IMG .. "五金/铸铁炉架.png" },
    { name = "旧铁砧",       rows = 2, cols = 2, quality = "green",  value = 250,     desc = "小型铁匠铁砧，砧面有坑",             image = IMG .. "五金/旧铁砧.png" },
    { name = "铜水龙头",     rows = 1, cols = 1, quality = "green",  value = 120,     desc = "做工厚实的老铜龙头",                 image = IMG .. "五金/铜水龙头.png" },
    { name = "铁艺花架",     rows = 2, cols = 2, quality = "green",  value = 200,     desc = "手工锻打的铁艺花架",                 image = IMG .. "五金/铁艺花架.png" },
    { name = "旧保险箱",     rows = 3, cols = 3, quality = "green",  value = 280,     desc = "密码已知的小保险箱",                 image = IMG .. "五金/旧保险箱.png" },
    { name = "铜配件盒",     rows = 1, cols = 2, quality = "green",  value = 160,     desc = "装满各种铜螺母的分格盒",             image = IMG .. "五金/铜配件盒.png" },
    { name = "旧铁闸门",     rows = 3, cols = 4, quality = "green",  value = 230,     desc = "卷帘式铁闸门，轴承还好",             image = IMG .. "五金/旧铁闸门.png" },
    -- 蓝 ×5
    { name = "铸铁街灯柱",   rows = 3, cols = 1, quality = "blue",      value = 500,     desc = "欧式铸铁路灯柱，花纹精美",           image = IMG .. "五金/铸铁街灯柱.png" },
    { name = "老铜风向标",   rows = 2, cols = 2, quality = "blue",      value = 650,     desc = "公鸡造型的铜风向标",                 image = IMG .. "五金/老铜风向标.png" },
    { name = "铸铁暖气片",   rows = 3, cols = 2, quality = "blue",      value = 550,     desc = "花纹铸铁暖气片，维多利亚风格",       image = IMG .. "五金/铸铁暖气片.png" },
    { name = "老黄铜望远镜", rows = 1, cols = 3, quality = "blue",      value = 700,     desc = "三节伸缩式黄铜望远镜",               image = IMG .. "五金/老黄铜望远镜.png" },
    { name = "铁艺大门",     rows = 3, cols = 4, quality = "blue",      value = 800,     desc = "锻打铁艺庭院大门",                   image = IMG .. "五金/铁艺大门.png" },
    -- 紫 ×3
    { name = "铜制船舵",     rows = 2, cols = 2, quality = "purple",      value = 1500,    desc = "黄铜包木的老船舵轮",                 image = IMG .. "五金/铜制船舵.png" },
    { name = "铸铁壁炉全套", rows = 3, cols = 3, quality = "purple",      value = 50000,   desc = "维多利亚铸铁壁炉含烟囱配件",         image = IMG .. "五金/铸铁壁炉全套.png" },
    { name = "老船锚",       rows = 3, cols = 3, quality = "purple",      value = 170000,  desc = "十九世纪锻铁船锚，有铭文",           image = IMG .. "五金/老船锚.png" },
    -- 金 ×2
    { name = "铜制天平",     rows = 1, cols = 2, quality = "gold", value = 4500,    desc = "药房用精密铜天平",                   image = IMG .. "五金/铜制天平.png" },
    { name = "铸铁大钟",     rows = 3, cols = 3, quality = "gold", value = 3200000, desc = "教堂退役的铸铁大钟",                 image = IMG .. "五金/铸铁大钟.png" },
    -- 红 ×1
    { name = "中世纪铁甲残片", rows = 2, cols = 2, quality = "red",  value = 14000000, desc = "疑似中世纪板甲的胸甲残片", image = IMG .. "五金/中世纪铁甲残片.png" },
}

-- ============================================================================
-- 杂货 (29件)
-- ============================================================================
Repair.misc = {
    -- 白 ×10
    { name = "旧抹布",       rows = 1, cols = 1, quality = "white",    value = 5,       desc = "沾满油污的破棉布",                   image = IMG .. "杂货/旧抹布.png" },
    { name = "空机油瓶",     rows = 1, cols = 1, quality = "white",    value = 10,      desc = "滴干净了的铁皮机油罐",               image = IMG .. "杂货/空机油瓶.png" },
    { name = "旧手套",       rows = 1, cols = 1, quality = "white",    value = 10,      desc = "磨穿了的帆布手套",                   image = IMG .. "杂货/旧手套.png" },
    { name = "废纸箱",       rows = 2, cols = 2, quality = "white",    value = 15,      desc = "压扁的瓦楞纸箱",                     image = IMG .. "杂货/废纸箱.png" },
    { name = "旧记账本",     rows = 1, cols = 1, quality = "white",    value = 20,      desc = "字迹潦草的账本",                     image = IMG .. "杂货/旧记账本.png" },
    { name = "破搪瓷杯",     rows = 1, cols = 1, quality = "white",    value = 15,      desc = "掉瓷的搪瓷茶缸",                     image = IMG .. "杂货/破搪瓷杯.png" },
    { name = "旧挂钟",       rows = 2, cols = 1, quality = "white",    value = 40,      desc = "不走了的塑料挂钟",                   image = IMG .. "杂货/旧挂钟.png" },
    { name = "旧围裙",       rows = 1, cols = 1, quality = "white",    value = 10,      desc = "油渍斑斑的帆布围裙",                 image = IMG .. "杂货/旧围裙.png" },
    { name = "空焊丝盘",     rows = 1, cols = 1, quality = "white",    value = 15,      desc = "只剩几圈焊丝的线盘",                 image = IMG .. "杂货/空焊丝盘.png" },
    { name = "旧工作台",     rows = 2, cols = 4, quality = "white",    value = 50,      desc = "台面坑洼的木工作台",                 image = IMG .. "杂货/旧工作台.png" },
    -- 绿 ×8
    { name = "老自行车",     rows = 2, cols = 3, quality = "green",  value = 200,     desc = "二八大杠，轮胎没气但骨架完好",       image = IMG .. "杂货/老自行车.png" },
    { name = "旧风扇罩",     rows = 2, cols = 2, quality = "green",  value = 130,     desc = "铁丝编的大吊扇防护罩",               image = IMG .. "杂货/旧风扇罩.png" },
    { name = "铁皮招牌",     rows = 2, cols = 3, quality = "green",  value = 180,     desc = "油漆斑驳的'修理部'铁皮招牌",         image = IMG .. "杂货/铁皮招牌.png" },
    { name = "旧收银机",     rows = 2, cols = 2, quality = "green",  value = 220,     desc = "按键弹出的老式收银机",               image = IMG .. "杂货/旧收银机.png" },
    { name = "老座钟",       rows = 1, cols = 2, quality = "green",  value = 250,     desc = "不走了的德国杜鹃座钟",               image = IMG .. "杂货/老座钟.png" },
    { name = "旧缝纫机",     rows = 2, cols = 3, quality = "green",  value = 280,     desc = "脚踏缝纫机，针还在",                 image = IMG .. "杂货/旧缝纫机.png" },
    { name = "老电话亭牌",   rows = 2, cols = 1, quality = "green",  value = 150,     desc = "'公用电话'的搪瓷指示牌",             image = IMG .. "杂货/老电话亭牌.png" },
    { name = "旧打气筒",     rows = 2, cols = 1, quality = "green",  value = 140,     desc = "铜嘴的老式打气筒",                   image = IMG .. "杂货/旧打气筒.png" },
    -- 蓝 ×5
    { name = "老挂钟",       rows = 2, cols = 2, quality = "blue",      value = 500,     desc = "机械挂钟，钟摆还在摆",               image = IMG .. "杂货/老挂钟.png" },
    { name = "搪瓷广告牌",   rows = 2, cols = 3, quality = "blue",      value = 650,     desc = "五十年代的搪瓷产品广告牌",           image = IMG .. "杂货/搪瓷广告牌.png" },
    { name = "旧点唱机",     rows = 3, cols = 2, quality = "blue",      value = 800,     desc = "投币式老点唱机，外壳有划痕",         image = IMG .. "杂货/旧点唱机.png" },
    { name = "铁皮玩具车",   rows = 1, cols = 1, quality = "blue",      value = 400,     desc = "手工涂装的铁皮消防车",               image = IMG .. "杂货/铁皮玩具车.png" },
    { name = "老弹球机",     rows = 3, cols = 2, quality = "blue",      value = 750,     desc = "木框台式弹球机，玻璃完好",           image = IMG .. "杂货/老弹球机.png" },
    -- 紫 ×3
    { name = "老霓虹灯招牌", rows = 2, cols = 4, quality = "purple",      value = 1500,    desc = "玻璃管完好的霓虹灯招牌",             image = IMG .. "杂货/老霓虹灯招牌.png" },
    { name = "老加油机",     rows = 3, cols = 2, quality = "purple",      value = 45000,   desc = "指针式老加油站计量泵",               image = IMG .. "杂货/老加油机.png" },
    { name = "旧摩托车",     rows = 3, cols = 4, quality = "purple",      value = 200000,  desc = "长江750侧三轮摩托车",                image = IMG .. "杂货/旧摩托车.png" },
    -- 金 ×2
    { name = "老可口可乐冰柜", rows = 2, cols = 2, quality = "gold", value = 6000,  desc = "五十年代可口可乐品牌冰柜",           image = IMG .. "杂货/老可口可乐冰柜.png" },
    { name = "老汽油泵",     rows = 3, cols = 2, quality = "gold", value = 2600000, desc = "Art Deco风格的老加油站汽油泵",       image = IMG .. "杂货/老汽油泵.png" },
    -- 红 ×1
    { name = "福特T型车零件箱", rows = 3, cols = 4, quality = "red", value = 22000000, desc = "印有福特标志的原厂零件木箱，内含完整备件", image = IMG .. "杂货/福特T型车零件箱.png" },
}

-- 品类列表
Repair.categories = {
    { id = "tool",     name = "工具", icon = "", items = Repair.tool },
    { id = "parts",    name = "零件", icon = "", items = Repair.parts },
    { id = "electric", name = "电器", icon = "", items = Repair.electric },
    { id = "hardware", name = "五金", icon = "", items = Repair.hardware },
    { id = "misc",     name = "杂货", icon = "", items = Repair.misc },
}

return Repair
