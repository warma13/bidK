-- ============================================================================
-- Config/Warehouses/DataCenter.lua - 黑夜之城物品配置
-- 科技产业园仓库类型，赛博朋克风格，包含 5 个品类共 59 件物品
-- value 即最终价格，无稀有度乘数
-- ============================================================================

local DataCenter = {}

-- 品类权重
DataCenter.categoryWeights = {
    energy     = 25,   -- 核心能源模块
    transport  = 20,   -- 载具改装件 / 数据传输
    art        = 15,   -- 数字艺术 / 街头文化
    tech       = 25,   -- 黑客装备 / 初代遗物 / 义体饰品
    mechanical = 15,   -- 义体改装件
}

local IMG = "items/数据中心/"

-- ============================================================================
-- 能源 (10件: 5白 + 1绿 + 1蓝 + 1紫 + 1金 + 1红)
-- ============================================================================
DataCenter.energy = {
    -- 白 x5
    { name = "微型散热片",     rows = 1, cols = 1, quality = "white",  value = 107,       desc = "从芯片上拆下的铜质散热鳍片",                       image = IMG .. "微型散热片.png" },
    { name = "冷却液管",       rows = 2, cols = 1, quality = "white",  value = 188,       desc = "液冷系统的硅胶软管",                               image = IMG .. "冷却液管.png" },
    { name = "UPS应急电源",    rows = 2, cols = 2, quality = "white",  value = 242,       desc = "电池鼓包的不间断电源",                             image = IMG .. "UPS应急电源.png" },
    { name = "液冷循环塔",     rows = 3, cols = 2, quality = "white",  value = 242,       desc = "漏液的小型液冷散热塔",                             image = IMG .. "液冷循环塔.png" },
    { name = "机房空调机组",   rows = 3, cols = 4, quality = "white",  value = 268,       desc = "压缩机报废的精密空调",                             image = IMG .. "机房空调机组.png" },
    -- 绿 x1
    { name = "废弃生物电池组", rows = 2, cols = 2, quality = "green",  value = 955,      desc = "从地下实验室回收的细胞培养型发电单元",             image = IMG .. "废弃生物电池组.png" },
    -- 蓝 x1
    { name = "微型聚变点火器", rows = 2, cols = 2, quality = "blue",   value = 3190,      desc = "曾短暂实现过自持反应的桌面级聚变装置",             image = IMG .. "微型聚变点火器.png" },
    -- 紫 x3
    { name = "旧等离子球",       rows = 1, cols = 1, quality = "purple", value = 629,    desc = "玻璃球内电弧闪烁的等离子装饰球",                   image = IMG .. "旧等离子球.png" },
    { name = "太阳能电池板碎片", rows = 2, cols = 2, quality = "purple", value = 1887,    desc = "还有部分光伏效率的多晶硅面板残片",                 image = IMG .. "太阳能电池板碎片.png" },
    { name = "量子真空能量模块", rows = 2, cols = 3, quality = "purple", value = 17297,   desc = "号称能从真空零点能中提取电力的概念原型",           image = IMG .. "量子真空能量模块.png" },
    -- 金 x3
    { name = "军用夜光管",       rows = 1, cols = 1, quality = "gold",   value = 5000,    desc = "氚气自发光管，十年不灭的冷光源",                   image = IMG .. "军用夜光管.png" },
    { name = "工业级激光管",     rows = 1, cols = 2, quality = "gold",   value = 5000,   desc = "CO2激光切割机的大功率激光管",                       image = IMG .. "工业级激光管.png" },
    { name = "反物质约束环",     rows = 2, cols = 2, quality = "gold",   value = 163399, desc = "仅存三枚的磁约束环，内壁仍有正电子痕迹",           image = IMG .. "反物质约束环.png" },
    -- 红 x3
    { name = "超导线圈组件",     rows = 2, cols = 2, quality = "red",    value = 180000,  desc = "高温超导磁体线圈，液氮冷却后仍可工作",             image = IMG .. "超导线圈组件.png" },
    { name = "核电站控制杆",     rows = 3, cols = 1, quality = "red",    value = 500000,  desc = "退役核反应堆的硼碳化物控制棒",                     image = IMG .. "核电站控制杆.png" },
    { name = "恒星之心冷核",     rows = 3, cols = 3, quality = "red",    value = 20000000, desc = "传说中的自持聚变核心，来源不明，疑似军方流出",     image = IMG .. "恒星之心冷核.png" },
}

-- ============================================================================
-- 交通/传输 (10件: 5白 + 1绿 + 1蓝 + 1紫 + 1金 + 1红)
-- ============================================================================
DataCenter.transport = {
    -- 白 x5
    { name = "废旧光纤头",     rows = 1, cols = 1, quality = "white",  value = 105,       desc = "折断的多模光纤连接头",                             image = IMG .. "废旧光纤头.png" },
    { name = "旧型号线缆束",   rows = 1, cols = 2, quality = "white",  value = 188,       desc = "捆扎整齐的淘汰线缆",                               image = IMG .. "旧型号线缆束.png" },
    { name = "天线模组",       rows = 2, cols = 1, quality = "white",  value = 161,       desc = "锈蚀的短波天线组件",                               image = IMG .. "天线模组.png" },
    { name = "废旧路由核心",   rows = 2, cols = 2, quality = "white",  value = 215,       desc = "固件损坏的核心路由模块",                           image = IMG .. "废旧路由核心.png" },
    { name = "工业级交换机",   rows = 2, cols = 3, quality = "white",  value = 268,       desc = "端口烧毁过半的万兆交换机",                         image = IMG .. "工业级交换机.png" },
    -- 绿 x1
    { name = "磁悬浮底盘组件", rows = 2, cols = 2, quality = "green",  value = 859,      desc = "从报废磁浮列车上拆下的超导轴承套件",               image = IMG .. "磁悬浮底盘组件.png" },
    -- 蓝 x1
    { name = "飞行摩托涡扇引擎", rows = 2, cols = 3, quality = "blue", value = 2924,     desc = "城市飞行载具的矢量推力涡扇，有磨损但可修复",       image = IMG .. "飞行摩托涡扇引擎.png" },
    -- 紫 x3
    { name = "电磁悬浮陀螺",     rows = 1, cols = 1, quality = "purple", value = 943,   desc = "永磁悬浮的金属陀螺，可无摩擦旋转数小时",           image = IMG .. "电磁悬浮陀螺.png" },
    { name = "信号干扰器外壳",   rows = 1, cols = 2, quality = "purple", value = 2201,   desc = "地下市场流通的宽频信号干扰器，芯片被拆走",         image = IMG .. "信号干扰器外壳.png" },
    { name = "反重力推进试验板", rows = 2, cols = 3, quality = "purple", value = 18869,   desc = "绝密项目泄露的反重力悬浮板，仍能短暂悬停",         image = IMG .. "反重力推进试验板.png" },
    -- 金 x3
    { name = "碳纳米管样品管",   rows = 1, cols = 1, quality = "gold",   value = 5000,   desc = "密封的碳纳米管研究样品，纯度99.9%",                 image = IMG .. "碳纳米管样品管.png" },
    { name = "无人机涡轮引擎",   rows = 1, cols = 2, quality = "gold",   value = 5000,  desc = "微型涡喷发动机，推力惊人",                         image = IMG .. "无人机涡轮引擎.png" },
    { name = "超导磁轨弹射模块", rows = 3, cols = 2, quality = "gold",   value = 150830, desc = "轨道发射系统的核心加速组件",                       image = IMG .. "超导磁轨弹射模块.png" },
    -- 红 x3
    { name = "军用外骨骼脚踝",   rows = 1, cols = 1, quality = "red",    value = 200000,  desc = "动力外骨骼的脚踝关节模块，液压驱动",               image = IMG .. "军用外骨骼脚踝.png" },
    { name = "磁浮列车制动器",   rows = 2, cols = 2, quality = "red",    value = 650000,  desc = "实验型磁浮列车的涡电流制动单元",                   image = IMG .. "磁浮列车制动器.png" },
    { name = "追光者引擎原型",   rows = 3, cols = 3, quality = "red",    value = 18000000, desc = "突破音障的单人飞行器引擎，全球仅制造过两台",       image = IMG .. "追光者引擎原型.png" },
}

-- ============================================================================
-- 艺术 (10件: 5白 + 1绿 + 1蓝 + 1紫 + 1金 + 1红)
-- ============================================================================
DataCenter.art = {
    -- 白 x5
    { name = "LED指示灯组",    rows = 1, cols = 1, quality = "white",  value = 135,       desc = "闪烁不定的服务器状态指示灯",                       image = IMG .. "LED指示灯组.png" },
    { name = "氖气灯管碎片",   rows = 1, cols = 1, quality = "white",  value = 161,       desc = "碎裂的霓虹灯管残片",                               image = IMG .. "氖气灯管碎片.png" },
    { name = "碳纤维面板",     rows = 1, cols = 2, quality = "white",  value = 215,       desc = "机柜侧板，边角有裂纹",                             image = IMG .. "碳纤维面板.png" },
    { name = "全息投影底座",   rows = 2, cols = 2, quality = "white",  value = 242,       desc = "投影模糊的桌面全息装置",                           image = IMG .. "全息投影底座.png" },
    { name = "生物识别门锁",   rows = 2, cols = 3, quality = "white",  value = 242,       desc = "传感器失灵的虹膜识别门禁",                         image = IMG .. "生物识别门锁.png" },
    -- 绿 x1
    { name = "霓虹书法灯管",   rows = 1, cols = 2, quality = "green",  value = 764,      desc = "街头艺术家手折的霓虹灯管书法作品",                 image = IMG .. "霓虹书法灯管.png" },
    -- 蓝 x1
    { name = "全息投影画框",   rows = 2, cols = 2, quality = "blue",   value = 2658,      desc = "内置微型投影仪的相框，可播放动态画作",             image = IMG .. "全息投影画框.png" },
    -- 紫 x3
    { name = "像素画打印件",   rows = 1, cols = 1, quality = "purple",  value = 786,    desc = "早期像素艺术家的签名限量打印件",                   image = IMG .. "像素画打印件.png" },
    { name = "霓虹灯管字母",   rows = 1, cols = 2, quality = "purple",  value = 1887,    desc = "拆自废弃酒吧的霓虹灯字母，还能亮",                 image = IMG .. "霓虹灯管字母.png" },
    { name = "AI协作画布原件", rows = 2, cols = 3, quality = "purple",  value = 14152,   desc = "第一批人机协作艺术运动中的布面油画原作",           image = IMG .. "AI协作画布原件.png" },
    -- 金 x3
    { name = "赛博涂鸦模板",   rows = 1, cols = 1, quality = "gold",   value = 5000,   desc = "知名街头艺术家的镂空喷漆模板原件",                 image = IMG .. "赛博涂鸦模板.png" },
    { name = "全息投影名片盒", rows = 1, cols = 1, quality = "gold",   value = 5000,   desc = "可投射3D全息影像的名片收纳盒",                     image = IMG .. "全息投影名片盒.png" },
    { name = "废墟摄影集孤本", rows = 2, cols = 2, quality = "gold",   value = 138261,  desc = "知名摄影师深入禁区拍摄的限量签名摄影集",           image = IMG .. "废墟摄影集孤本.png" },
    -- 红 x3
    { name = "街头涂鸦墙砖",   rows = 2, cols = 2, quality = "red",    value = 250000,  desc = "传奇涂鸦艺术家的原作墙砖，从拆迁现场抢救",         image = IMG .. "街头涂鸦墙砖.png" },
    { name = "动态光雕原件",   rows = 2, cols = 3, quality = "red",    value = 700000,  desc = "获奖新媒体艺术装置的核心光雕投影模块",             image = IMG .. "动态光雕原件.png" },
    { name = "电子涅槃装置",   rows = 3, cols = 4, quality = "red",    value = 16000000, desc = "传奇新媒体艺术家遗作，由2048块LED矩阵组成",         image = IMG .. "电子涅槃装置.png" },
}

-- ============================================================================
-- 科技 (21件: 6白 + 3绿 + 3蓝 + 3紫 + 3金 + 3红)
-- 包含三个子方向：黑客装备、初代遗物、义体饰品
-- ============================================================================
DataCenter.tech = {
    -- 白 x6
    { name = "断线数据芯片",   rows = 1, cols = 1, quality = "white",  value = 161,       desc = "接口烧毁的微型数据芯片",                           image = IMG .. "断线数据芯片.png" },
    { name = "烧毁的内存条",   rows = 1, cols = 1, quality = "white",  value = 107,       desc = "过热变形的DDR模组",                                 image = IMG .. "烧毁的内存条.png" },
    { name = "静电护腕",       rows = 1, cols = 1, quality = "white",  value = 135,       desc = "机房技术员用过的防静电手环",                       image = IMG .. "静电护腕.png" },
    { name = "硬盘阵列盒",     rows = 2, cols = 2, quality = "white",  value = 268,       desc = "缺了几块盘的RAID阵列托盘",                         image = IMG .. "硬盘阵列盒.png" },
    { name = "数据存储柜",     rows = 3, cols = 3, quality = "white",  value = 268,       desc = "空空如也的数据存储机柜",                           image = IMG .. "数据存储柜.png" },
    { name = "磁带备份库",     rows = 3, cols = 3, quality = "white",  value = 242,       desc = "磁带发霉的离线备份柜",                             image = IMG .. "磁带备份库.png" },
    -- 绿 x3 (黑客/遗物/义体各1)
    { name = "加密无线电台",   rows = 1, cols = 2, quality = "green",  value = 1050,      desc = "地下电台使用的跳频加密通信设备",                   image = IMG .. "加密无线电台.png" },
    { name = "初代VR头显",     rows = 1, cols = 2, quality = "green",  value = 811,      desc = "2012年众筹时代的初代虚拟现实头显开发机",           image = IMG .. "初代VR头显.png" },
    { name = "钛合金义眼",     rows = 1, cols = 1, quality = "green",  value = 907,      desc = "医疗级钛合金打造的仿生义眼，虹膜可变色",           image = IMG .. "钛合金义眼.png" },
    -- 蓝 x3
    { name = "神经信号转译器", rows = 1, cols = 2, quality = "blue",   value = 3456,      desc = "读取脑电信号并转为数字指令的实验设备",             image = IMG .. "神经信号转译器.png" },
    { name = "比特矿机主板",   rows = 2, cols = 2, quality = "blue",   value = 2924,      desc = "2010年代早期挖矿使用的ASIC矿机主板",               image = IMG .. "比特矿机主板.png" },
    { name = "碳纤维手骨套件", rows = 1, cols = 2, quality = "blue",   value = 2658,      desc = "替换手部骨骼的轻量化碳纤维假体，附带触觉反馈",     image = IMG .. "碳纤维手骨套件.png" },
    -- 紫 x5
    { name = "量子密钥分发器", rows = 1, cols = 2, quality = "purple",  value = 629,    desc = "利用量子纠缠实现绝对安全通信的便携终端",           image = IMG .. "量子密钥分发器.png" },
    { name = "加密U盘",         rows = 1, cols = 1, quality = "purple",  value = 1101,    desc = "军用级硬件加密U盘，自毁机制完好",                   image = IMG .. "加密U盘.png" },
    { name = "废旧VR手套",       rows = 1, cols = 2, quality = "purple",  value = 2516,    desc = "力反馈VR手套，三根手指传感器还能用",               image = IMG .. "废旧VR手套.png" },
    { name = "绝版操作系统软盘", rows = 1, cols = 1, quality = "purple", value = 17297,   desc = "未拆封的初代图形界面操作系统3.5寸安装盘",           image = IMG .. "绝版操作系统软盘.png" },
    { name = "纳米涂层脊椎链", rows = 2, cols = 1, quality = "purple",  value = 53464,  desc = "贴合颈部的柔性金属链，表面有纳米变色涂层",         image = IMG .. "纳米涂层脊椎链.png" },
    -- 金 x5
    { name = "液态金属戒指",       rows = 1, cols = 1, quality = "gold", value = 5000,    desc = "内含可编程液态金属，能自动变形适配任意手指",       image = IMG .. "液态金属戒指.png" },
    { name = "生物芯片植入器",     rows = 1, cols = 1, quality = "gold", value = 5000,   desc = "皮下NFC芯片的注射式植入器，附带读写器",           image = IMG .. "生物芯片植入器.png" },
    { name = "脑电波耳机原型",     rows = 1, cols = 2, quality = "gold", value = 5000,   desc = "通过脑电波控制设备的原型耳机",                     image = IMG .. "脑电波耳机原型.png" },
    { name = "深渊之眼监控核心",   rows = 2, cols = 2, quality = "gold", value = 9427,  desc = "能同时解析万路视频流的AI识别处理器",               image = IMG .. "深渊之眼监控核心.png" },
    { name = "初代智能手机工程机", rows = 1, cols = 1, quality = "gold", value = 175968, desc = "改变世界的那款手机的内部工程测试版",               image = IMG .. "初代智能手机工程机.png" },
    -- 红 x5
    { name = "军用无人机主板",     rows = 1, cols = 2, quality = "red",  value = 120000,  desc = "侦察无人机的飞控主板，芯片型号敏感",               image = IMG .. "军用无人机主板.png" },
    { name = "神经接口芯片",       rows = 1, cols = 1, quality = "red",  value = 350000,  desc = "脑机接口的植入式芯片，附带电极阵列",               image = IMG .. "神经接口芯片.png" },
    { name = "银翼钛金胸甲",   rows = 2, cols = 3, quality = "red",    value = 15000000, desc = "航空钛金锻造的胸部装饰甲，内嵌心率监测和微型屏幕", image = IMG .. "银翼钛金胸甲.png" },
    { name = "创世区块硬盘",   rows = 1, cols = 1, quality = "red",    value = 20000000, desc = "据传存有最早期数字货币钱包私钥的硬盘",             image = IMG .. "创世区块硬盘.png" },
    { name = "意识数字化接口", rows = 2, cols = 3, quality = "red",    value = 22000000, desc = "据传能将人类意识映射为数据的神经扫描设备",         image = IMG .. "意识数字化接口.png" },
}

-- ============================================================================
-- 机械 (8件: 3白 + 1绿 + 1蓝 + 1紫 + 1金 + 1红)
-- ============================================================================
DataCenter.mechanical = {
    -- 白 x3
    { name = "合金螺栓",       rows = 1, cols = 1, quality = "white",  value = 105,       desc = "机柜上拆下的钛合金螺栓",                           image = IMG .. "合金螺栓.png" },
    { name = "机架式服务器",   rows = 3, cols = 2, quality = "white",  value = 268,       desc = "主板被拆走的1U服务器空壳",                         image = IMG .. "机架式服务器.png" },
    { name = "主机框架残骸",   rows = 4, cols = 4, quality = "white",  value = 268,       desc = "只剩框架的大型主机外壳",                           image = IMG .. "主机框架残骸.png" },
    -- 绿 x1
    { name = "液压指关节组",   rows = 1, cols = 1, quality = "green",  value = 955,      desc = "工业机械手的指节部件，精度达0.01mm",               image = IMG .. "液压指关节组.png" },
    -- 蓝 x1
    { name = "动力外骨骼腿部", rows = 2, cols = 3, quality = "blue",   value = 3190,      desc = "军用外骨骼的下肢模块，可增强负重至200kg",           image = IMG .. "动力外骨骼腿部.png" },
    -- 紫 x3
    { name = "旧伺服电机",     rows = 1, cols = 1, quality = "purple",  value = 1101,    desc = "拆机的步进电机，精度尚可，外壳有磨损",             image = IMG .. "旧伺服电机.png" },
    { name = "气动缸筒",       rows = 2, cols = 1, quality = "purple",  value = 2516,    desc = "高压气动执行器，密封圈完好，可直接使用",           image = IMG .. "气动缸筒.png" },
    { name = "机械臂全套框架", rows = 3, cols = 3, quality = "purple",  value = 15725,   desc = "六自由度仿生机械臂的碳钛合金骨架",                 image = IMG .. "机械臂全套框架.png" },
    -- 金 x3
    { name = "精密减速器",     rows = 1, cols = 1, quality = "gold",    value = 5000,   desc = "谐波减速器，传动比1:100，齿隙极小",                image = IMG .. "精密减速器.png" },
    { name = "碳纤维机械臂段", rows = 2, cols = 1, quality = "gold",    value = 5000,   desc = "轻量化碳纤维臂节，强度高重量轻",                   image = IMG .. "碳纤维机械臂段.png" },
    { name = "微型陀螺稳定仪", rows = 1, cols = 1, quality = "gold",    value = 157115, desc = "军工级姿态稳定系统，可保持任何平台绝对水平",       image = IMG .. "微型陀螺稳定仪.png" },
    -- 红 x3
    { name = "仿生关节组件",   rows = 2, cols = 2, quality = "red",     value = 150000,  desc = "高仿真人工关节，钛合金球头配陶瓷内衬",             image = IMG .. "仿生关节组件.png" },
    { name = "液压动力单元",   rows = 2, cols = 3, quality = "red",     value = 500000,  desc = "重型机甲用液压泵站，输出扭矩惊人",                 image = IMG .. "液压动力单元.png" },
    { name = "铁骑全身外骨骼", rows = 3, cols = 4, quality = "red",     value = 19000000, desc = "完整的动力外骨骼套装，穿戴者可举起2吨重物",         image = IMG .. "铁骑全身外骨骼.png" },
}

-- 品类列表
DataCenter.categories = {
    { id = "energy",     name = "能源设备",   icon = "", items = DataCenter.energy },
    { id = "transport",  name = "数据传输",   icon = "", items = DataCenter.transport },
    { id = "art",        name = "数字艺术",   icon = "", items = DataCenter.art },
    { id = "tech",       name = "科技元件",   icon = "", items = DataCenter.tech },
    { id = "mechanical", name = "机械装置",   icon = "", items = DataCenter.mechanical },
}

return DataCenter
