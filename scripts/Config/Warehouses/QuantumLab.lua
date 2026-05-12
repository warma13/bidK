-- ============================================================================
-- Config/Warehouses/QuantumLab.lua - 量子实验室物品配置
-- 科技产业园仓库类型，量子计算初创公司风格，包含 5 个品类共 60 件物品
-- value 即最终价格，无稀有度乘数
-- ============================================================================

local QuantumLab = {}

-- 品类权重
QuantumLab.categoryWeights = {
    tech       = 30,   -- 量子计算核心设备
    energy     = 25,   -- 低温冷却与能源系统
    mechanical = 20,   -- 精密仪器与机械部件
    art        = 15,   -- 科研记录、图纸、学术藏品
    jewel      = 10,   -- 稀有材料样品
}

local IMG = "image/"

-- ============================================================================
-- 科技 tech（16件: 5白 + 2绿 + 2蓝 + 3紫 + 2金 + 2红）
-- ============================================================================
QuantumLab.tech = {
    -- 白 x5
    { name = "烧毁的量子比特芯片", rows = 1, cols = 1, quality = "white",  value = 25,       desc = "过热失超的超导量子芯片残骸",                       image = IMG .. "烧毁的量子比特芯片_20260510130952.png" },
    { name = "标定用光纤",         rows = 1, cols = 2, quality = "white",  value = 35,       desc = "用于校准光量子设备的单模光纤",                     image = IMG .. "标定用光纤_20260510131225.png" },
    { name = "实验日志碎片",       rows = 1, cols = 1, quality = "white",  value = 20,       desc = "潦草手写的实验记录纸片",                           image = IMG .. "实验日志碎片_20260510131400.png" },
    { name = "废弃示波器",         rows = 2, cols = 2, quality = "white",  value = 45,       desc = "屏幕碎裂的高频示波器",                             image = IMG .. "废弃示波器_20260510131448.png" },
    { name = "旧型量子退火器",     rows = 2, cols = 3, quality = "white",  value = 50,       desc = "第一代量子退火计算设备，完全过时",                 image = IMG .. "旧型量子退火器_20260510130947.png" },
    -- 绿 x2
    { name = "光子探测模块",       rows = 1, cols = 2, quality = "green",  value = 200,      desc = "单光子雪崩二极管检测模块",                         image = IMG .. "光子探测模块_20260510131239.png" },
    { name = "纠缠光源组件",       rows = 2, cols = 2, quality = "green",  value = 250,      desc = "产生纠缠光子对的非线性晶体组件",                   image = IMG .. "纠缠光源组件_20260510131008.png" },
    -- 蓝 x2
    { name = "量子随机数发生器",   rows = 1, cols = 1, quality = "blue",   value = 600,      desc = "基于量子噪声的真随机数生成器",                     image = IMG .. "量子随机数发生器_20260510131305.png" },
    { name = "超导量子处理单元",   rows = 2, cols = 2, quality = "blue",   value = 800,      desc = "8比特超导量子处理器，有轻微退相干",               image = IMG .. "超导量子处理单元_20260510130949.png" },
    -- 紫 x3
    { name = "拓扑量子比特原型",   rows = 1, cols = 1, quality = "purple", value = 3000,     desc = "实验性拓扑量子比特，理论上抗噪声",                 image = IMG .. "拓扑量子比特原型_20260510130951.png" },
    { name = "量子纠错编码板",     rows = 2, cols = 2, quality = "purple", value = 8000,     desc = "实现表面码纠错的专用FPGA板",                       image = IMG .. "量子纠错编码板_20260510131455.png" },
    { name = "百比特量子芯片",     rows = 2, cols = 3, quality = "purple", value = 65000,    desc = "含128个超导量子比特的处理器芯片",                  image = IMG .. "百比特量子芯片_20260510131717.png" },
    -- 金 x2
    { name = "量子密钥卫星终端",   rows = 2, cols = 2, quality = "gold",   value = 40000,    desc = "与量子通信卫星对接的地面终端",                     image = IMG .. "量子密钥卫星终端_20260510131501.png" },
    { name = "千比特量子处理器",   rows = 2, cols = 3, quality = "gold",   value = 3000000,  desc = "1024比特超导量子芯片，仍可运行",                   image = IMG .. "千比特量子处理器_20260510131723.png" },
    -- 红 x2
    { name = "量子霸权验证板",     rows = 2, cols = 2, quality = "red",    value = 500000,   desc = "用于验证量子计算优越性的专用电路板",               image = IMG .. "量子霸权验证板_20260510131454.png" },
    { name = "通用量子计算核心",   rows = 3, cols = 3, quality = "red",    value = 22000000, desc = "传说中实现通用量子计算的核心模块，真伪未知",       image = IMG .. "通用量子计算核心_20260510131506.png" },
}

-- ============================================================================
-- 能源 energy（14件: 5白 + 1绿 + 1蓝 + 3紫 + 2金 + 2红）
-- ============================================================================
QuantumLab.energy = {
    -- 白 x5
    { name = "破损液氦容器",     rows = 2, cols = 2, quality = "white",  value = 40,       desc = "真空层破裂的小型液氦杜瓦瓶",                       image = IMG .. "破损液氦容器_20260510131451.png" },
    { name = "废旧冷却管路",     rows = 1, cols = 3, quality = "white",  value = 30,       desc = "结霜生锈的低温冷却铜管",                           image = IMG .. "废旧冷却管路_20260510131449.png" },
    { name = "漏气制冷阀",       rows = 1, cols = 1, quality = "white",  value = 20,       desc = "密封失效的针阀",                                   image = IMG .. "漏气制冷阀v2_20260510141143.png" },
    { name = "实验室电源模块",   rows = 2, cols = 2, quality = "white",  value = 45,       desc = "输出不稳的线性稳压电源",                           image = IMG .. "实验室电源模块_20260510131456.png" },
    { name = "液氮罐空壳",       rows = 2, cols = 3, quality = "white",  value = 35,       desc = "无法保温的液氮储存罐",                             image = IMG .. "液氮罐空壳_20260510131743.png" },
    -- 绿 x1
    { name = "脉冲管制冷机头",   rows = 2, cols = 2, quality = "green",  value = 220,      desc = "可达40K的脉冲管制冷机压缩头",                      image = IMG .. "脉冲管制冷机头_20260510132046.png" },
    -- 蓝 x1
    { name = "稀释制冷机混合室", rows = 2, cols = 3, quality = "blue",   value = 700,      desc = "可达10mK的稀释制冷机核心组件",                     image = IMG .. "稀释制冷机混合室_20260510131740.png" },
    -- 紫 x3
    { name = "超导磁体线圈",     rows = 1, cols = 1, quality = "purple", value = 2500,     desc = "NbTi超导线绕制的小型磁体",                         image = IMG .. "超导磁体线圈_20260510131813.png" },
    { name = "低温恒温器",       rows = 2, cols = 2, quality = "purple", value = 7000,     desc = "可将样品维持在毫开尔文温度的装置",                 image = IMG .. "低温恒温器_20260510131743.png" },
    { name = "氦-3回收系统",     rows = 3, cols = 3, quality = "purple", value = 55000,    desc = "珍贵的氦-3气体回收净化系统",                       image = IMG .. "氦-3回收系统_20260510131800.png" },
    -- 金 x2
    { name = "无液氦低温平台",   rows = 2, cols = 2, quality = "gold",   value = 35000,    desc = "不依赖液氦的干式稀释制冷平台",                     image = IMG .. "无液氦低温平台_20260510131741.png" },
    { name = "高纯氦-3气瓶",     rows = 1, cols = 1, quality = "gold",   value = 2800000,  desc = "99.999%纯度的氦-3气体，极其稀缺",                  image = IMG .. "高纯氦-3气瓶_20260510132049.png" },
    -- 红 x2
    { name = "毫开制冷机组",     rows = 3, cols = 4, quality = "red",    value = 600000,   desc = "可达5mK的完整稀释制冷系统",                        image = IMG .. "毫开制冷机组_20260510132022.png" },
    { name = "绝对零度逼近器",   rows = 3, cols = 3, quality = "red",    value = 18000000, desc = "实验性核去磁制冷装置，曾达到1微开",                image = IMG .. "绝对零度逼近器_20260510131744.png" },
}

-- ============================================================================
-- 机械 mechanical（12件: 4白 + 1绿 + 1蓝 + 2紫 + 2金 + 2红）
-- ============================================================================
QuantumLab.mechanical = {
    -- 白 x4
    { name = "损坏的真空泵",   rows = 2, cols = 2, quality = "white",  value = 40,       desc = "叶片磨损的旋片真空泵",                             image = IMG .. "损坏的真空泵_20260510132336.png" },
    { name = "光学平台碎片",   rows = 2, cols = 3, quality = "white",  value = 50,       desc = "切割过的蜂窝光学面包板残片",                       image = IMG .. "光学平台碎片_20260510132249.png" },
    { name = "废旧精密导轨",   rows = 1, cols = 3, quality = "white",  value = 35,       desc = "锈蚀的直线导轨滑台",                               image = IMG .. "废旧精密导轨_20260510132240.png" },
    { name = "报废分子泵",     rows = 2, cols = 2, quality = "white",  value = 45,       desc = "轴承卡死的涡轮分子泵",                             image = IMG .. "报废分子泵v2_20260510141803.png" },
    -- 绿 x1
    { name = "六轴精密调节架", rows = 1, cols = 1, quality = "green",  value = 180,      desc = "光学元件用六自由度微调架",                         image = IMG .. "六轴精密调节架_20260510132550.png" },
    -- 蓝 x1
    { name = "超高真空腔体",   rows = 2, cols = 2, quality = "blue",   value = 650,      desc = "可达10^-10 Pa的不锈钢真空腔",                      image = IMG .. "超高真空腔体_20260510132253.png" },
    -- 紫 x2
    { name = "精密位移台",     rows = 1, cols = 2, quality = "purple", value = 4000,     desc = "纳米级精度的压电驱动位移台",                       image = IMG .. "精密位移台_20260510132507.png" },
    { name = "离子阱电极组",   rows = 2, cols = 2, quality = "purple", value = 50000,    desc = "用于囚禁单个离子的微加工电极",                     image = IMG .. "离子阱电极组_20260510132241.png" },
    -- 金 x2
    { name = "无振动光学台",   rows = 3, cols = 4, quality = "gold",   value = 30000,    desc = "主动减震的大型气浮光学平台",                       image = IMG .. "无振动光学台_20260510132503.png" },
    { name = "原子钟机芯",     rows = 1, cols = 1, quality = "gold",   value = 2500000,  desc = "铯原子钟的核心振荡模块",                           image = IMG .. "原子钟机芯_20260510132246.png" },
    -- 红 x2
    { name = "引力波探测臂",   rows = 1, cols = 4, quality = "red",    value = 400000,   desc = "激光干涉仪的精密反射臂",                           image = IMG .. "引力波探测臂_20260510132745.png" },
    { name = "粒子加速腔",     rows = 3, cols = 4, quality = "red",    value = 17000000, desc = "小型直线加速器的射频超导腔体",                     image = IMG .. "粒子加速腔_20260510132808.png" },
}

-- ============================================================================
-- 艺术 art（9件: 3白 + 1绿 + 1蓝 + 2紫 + 1金 + 1红）
-- ============================================================================
QuantumLab.art = {
    -- 白 x3
    { name = "实验室白板涂鸦",   rows = 2, cols = 2, quality = "white",  value = 30,       desc = "写满公式的白板，被咖啡渍污染",                     image = IMG .. "实验室白板涂鸦_20260510133142.png" },
    { name = "旧学术海报",       rows = 1, cols = 2, quality = "white",  value = 25,       desc = "褪色的学术会议海报",                               image = IMG .. "旧学术海报_20260510133014.png" },
    { name = "破碎的分子模型",   rows = 1, cols = 1, quality = "white",  value = 20,       desc = "缺了几个原子球的分子结构模型",                     image = IMG .. "破碎的分子模型_20260510132752.png" },
    -- 绿 x1
    { name = "量子艺术版画",     rows = 2, cols = 2, quality = "green",  value = 200,      desc = "用量子随机数生成的限量版画",                       image = IMG .. "量子艺术版画_20260510132741.png" },
    -- 蓝 x1
    { name = "薛定谔的猫雕塑",   rows = 1, cols = 1, quality = "blue",   value = 550,      desc = "半透明树脂中嵌着猫骨架的概念雕塑",                 image = IMG .. "薛定谔的猫雕塑_20260510133237.png" },
    -- 紫 x2
    { name = "费曼手稿复制件",   rows = 1, cols = 1, quality = "purple", value = 3500,     desc = "费曼亲笔路径积分推导的高仿复制件",                 image = IMG .. "费曼手稿复制件_20260510133116.png" },
    { name = "量子纠缠艺术装置", rows = 2, cols = 3, quality = "purple", value = 45000,    desc = "两地同步变色的光纤艺术装置",                       image = IMG .. "量子纠缠艺术装置_20260510133022.png" },
    -- 金 x1
    { name = "诺贝尔奖章复刻",   rows = 1, cols = 1, quality = "gold",   value = 15000,    desc = "某年物理学奖章的精仿品，纯金镀层",                 image = IMG .. "诺贝尔奖章复刻_20260510133126.png" },
    -- 红 x1
    { name = "爱因斯坦亲笔信",   rows = 1, cols = 1, quality = "red",    value = 350000,   desc = "讨论EPR悖论的私人信件，真伪待鉴",                  image = IMG .. "爱因斯坦亲笔信_20260510133616.png" },
}

-- ============================================================================
-- 珠宝/稀有材料 jewel（8件: 3白 + 1绿 + 1蓝 + 1紫 + 1金 + 1红）
-- ============================================================================
QuantumLab.jewel = {
    -- 白 x3
    { name = "硅晶片废料",     rows = 1, cols = 1, quality = "white",  value = 15,       desc = "碎裂的半导体级硅晶圆边角料",                       image = IMG .. "硅晶片废料_20260510133238.png" },
    { name = "石英窗片",       rows = 1, cols = 1, quality = "white",  value = 30,       desc = "划痕累累的光学石英观察窗",                         image = IMG .. "石英窗片_20260510133242.png" },
    { name = "铟锡靶材残片",   rows = 1, cols = 2, quality = "white",  value = 40,       desc = "ITO溅射靶材的边角余料",                            image = IMG .. "铟锡靶材残片_20260510133447.png" },
    -- 绿 x1
    { name = "蓝宝石基板",     rows = 1, cols = 1, quality = "green",  value = 180,      desc = "用于外延生长的蓝宝石衬底",                         image = IMG .. "蓝宝石基板_20260510133253.png" },
    -- 蓝 x1
    { name = "铌酸锂晶体",     rows = 1, cols = 1, quality = "blue",   value = 500,      desc = "非线性光学晶体，可用于频率转换",                   image = IMG .. "铌酸锂晶体_20260510133256.png" },
    -- 紫 x1
    { name = "金刚石NV色心样品", rows = 1, cols = 1, quality = "purple", value = 5000,    desc = "含氮空位色心的人造金刚石，量子传感器核心",         image = IMG .. "金刚石NV色心样品_20260510133240.png" },
    -- 金 x1
    { name = "超纯锗单晶",     rows = 1, cols = 2, quality = "gold",   value = 25000,    desc = "12N纯度的锗单晶锭，探测器级材料",                  image = IMG .. "超纯锗单晶_20260510133239.png" },
    -- 红 x1
    { name = "反氢原子捕获瓶", rows = 2, cols = 2, quality = "red",    value = 15000000, desc = "磁阱中仍约束着微量反氢原子的真空容器",             image = IMG .. "反氢原子捕获瓶_20260510133240.png" },
}

-- 品类列表
QuantumLab.categories = {
    { id = "tech",       name = "量子设备",   icon = "", items = QuantumLab.tech },
    { id = "energy",     name = "低温能源",   icon = "", items = QuantumLab.energy },
    { id = "mechanical", name = "精密仪器",   icon = "", items = QuantumLab.mechanical },
    { id = "art",        name = "学术藏品",   icon = "", items = QuantumLab.art },
    { id = "jewel",      name = "稀有材料",   icon = "", items = QuantumLab.jewel },
}

return QuantumLab
