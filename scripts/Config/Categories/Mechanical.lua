-- ============================================================================
-- Config/Categories/Mechanical.lua - 机械品类物品池
-- 来源：ItemPool.mechanical + DataCenter.mechanical + QuantumLab.mechanical
-- ============================================================================

local Mechanical = {}

local IMG = "items/"
local IMG_QL = "items/"

Mechanical.items = {
    -- ===== ItemPool 通用机械物品 =====
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
    { name = "机械臂关节模组", rows = 2, cols = 2, quality = "blue",   value = 2169, weight = 2,     desc = "六轴机械臂的腕部关节总成",             image = IMG .. "机械/机械臂关节模组.png",   tags = {"industrial_robot"} },
    { name = "小型CNC主轴",    rows = 2, cols = 1, quality = "blue",   value = 3428, weight = 1,     desc = "数控机床电主轴，转速尚可",             image = IMG .. "机械/小型CNC主轴.png",       tags = {"precision_optics"} },
    { name = "工业视觉相机",   rows = 1, cols = 1, quality = "blue",   value = 1206, weight = 2,     desc = "高分辨率工业检测相机",                 image = IMG .. "机械/工业视觉相机.png" },
    { name = "协作机器人控制柜", rows = 2, cols = 3, quality = "blue", value = 5000, weight = 1,     desc = "协作机器人专用控制箱",                 image = IMG .. "机械/协作机器人控制柜.png",  tags = {"industrial_robot"} },
    { name = "精密谐波减速机", rows = 1, cols = 1, quality = "blue",   value = 2703, weight = 2,     desc = "日本产谐波减速器，精度尚存",           image = IMG .. "机械/精密谐波减速机.png",    tags = {"industrial_robot", "precision_optics"} },
    -- 紫 ×3
    { name = "六轴工业机械臂", rows = 3, cols = 2, quality = "purple", value = 15810, weight = 1,   desc = "整台小型六轴机械臂，缺控制柜",         image = IMG .. "机械/六轴工业机械臂.png",    tags = {"industrial_robot"} },
    { name = "高精度3D打印机", rows = 3, cols = 3, quality = "purple", value = 21412, weight = 1,  desc = "金属粉末激光烧结3D打印机",             image = IMG .. "机械/高精度3D打印机.png",    tags = {"precision_optics"} },
    { name = "精密坐标测量仪", rows = 2, cols = 2, quality = "purple", value = 2900, weight = 4,    desc = "三坐标测量仪的测量头组件",             image = IMG .. "机械/精密坐标测量仪.png",    tags = {"precision_optics"} },
    -- 金 ×5
    { name = "人形机器人原型", rows = 4, cols = 2, quality = "gold",   value = 66742, weight = 3,  desc = "展厅里的双足机器人，外壳完好",         image = IMG .. "机械/人形机器人原型.png",    tags = {"industrial_robot"} },
    { name = "光刻机镜组模块", rows = 2, cols = 2, quality = "gold",   value = 127315, weight = 1, desc = "疑似深紫外光刻机的精密镜组",           image = IMG .. "机械/光刻机镜组模块.png",    tags = {"semiconductor", "precision_optics"} },
    { name = "瑞士钟表机芯",   rows = 1, cols = 1, quality = "gold",   value = 31400, weight = 5,   desc = "百达翡丽的废弃机芯，齿轮精密",         image = IMG .. "机械/瑞士钟表机芯.png",      tags = {"horology"} },
    { name = "德国光学镜头",   rows = 1, cols = 1, quality = "gold",   value = 47898, weight = 4,  desc = "蔡司工厂流出的未镀膜APO镜头毛坯",     image = IMG .. "机械/德国光学镜头.png",      tags = {"precision_optics"} },
    { name = "航天陀螺仪",     rows = 1, cols = 1, quality = "gold",   value = 133551, weight = 1, desc = "航天惯性导航用的高精度光纤陀螺仪",     image = IMG .. "机械/航天陀螺仪.png",        tags = {"aerospace", "precision_optics"} },
    -- 红 ×3
    { name = "ASML光刻机核心组件", rows = 4, cols = 4, quality = "red", value = 8762931, weight = 2, desc = "角落里用木箱封装的光刻机关键模块，编号与失踪清单吻合", image = IMG .. "机械/ASML光刻机核心组件.png", tags = {"semiconductor", "precision_optics"} },
    { name = "战斗机弹射座椅",     rows = 3, cols = 2, quality = "red",  value = 1182135, weight = 18, desc = "完整的马丁贝克弹射座椅，火工品已拆除", image = IMG .. "机械/战斗机弹射座椅.png",    tags = {"aerospace"} },
    { name = "航天发动机喷嘴",     rows = 2, cols = 2, quality = "red",  value = 6061058, weight = 3, desc = "液体火箭发动机的再生冷却喷嘴总成",   image = IMG .. "机械/航天发动机喷嘴.png",    tags = {"aerospace"} },
    -- 低价补充
    { name = "手动缝纫机",       rows = 2, cols = 2, quality = "purple",  value = 2233, weight = 5,    desc = "蝴蝶牌老式手动缝纫机，脚踏板完好",     image = IMG .. "机械/手动缝纫机.png" },
    { name = "铜质天平",         rows = 1, cols = 2, quality = "purple",  value = 4995, weight = 3,    desc = "带砝码套装的精密铜天平，刻度清晰",     image = IMG .. "机械/铜质天平.png" },
    { name = "航海六分仪",       rows = 1, cols = 1, quality = "gold",    value = 15573, weight = 11,    desc = "黄铜航海六分仪，镜片有划痕",           image = IMG .. "机械/航海六分仪.png",       tags = {"maritime"} },
    { name = "老式显微镜",       rows = 1, cols = 1, quality = "gold",    value = 26524, weight = 6,   desc = "黄铜筒身的老式光学显微镜",             image = IMG .. "机械/老式显微镜.png",       tags = {"precision_optics"} },
    { name = "蒸汽朋克机械钟",   rows = 2, cols = 2, quality = "red",     value = 187461, weight = 125,  desc = "纯手工齿轮传动座钟，齿轮外露可赏",     image = IMG .. "机械/蒸汽朋克机械钟.png",   tags = {"horology"} },
    { name = "潜艇潜望镜",       rows = 3, cols = 1, quality = "red",     value = 786253, weight = 28,  desc = "退役潜艇拆下的光学潜望镜筒",           image = IMG .. "机械/潜艇潜望镜.png",       tags = {"maritime"} },
    { name = "胜家缝纫机头",   rows = 1, cols = 2, quality = "purple",  value = 2900, weight = 4,    desc = "带金色花纹的胜家缝纫机头",                 image = IMG .. "机械/老缝纫机头.png" },
    { name = "铜质打字机键",   rows = 1, cols = 1, quality = "purple",  value = 1998, weight = 5,    desc = "一整套圆形铜质打字机按键",                 image = IMG .. "机械/铜质打字机键.png" },
    { name = "老钟表发条",     rows = 1, cols = 1, quality = "purple",  value = 4526, weight = 3,    desc = "瑞士产座钟的盘形发条组件",                 image = IMG .. "机械/老钟表发条.png" },
    { name = "老式计量秤",     rows = 1, cols = 2, quality = "gold",    value = 14769, weight = 11,    desc = "带铜砝码的精密药房计量秤",                 image = IMG .. "机械/老式计量秤.png" },
    { name = "铜质望远镜筒",   rows = 1, cols = 2, quality = "gold",    value = 20178, weight = 8,   desc = "黄铜制舰载望远镜的镜筒",                   image = IMG .. "机械/铜质望远镜筒.png" },
    { name = "古董留声机",     rows = 2, cols = 2, quality = "red",     value = 335560, weight = 68,  desc = "完整的大喇叭花铜质留声机",                 image = IMG .. "机械/古董留声机.png" },
    { name = "瑞士八音盒",     rows = 1, cols = 2, quality = "red",     value = 104218, weight = 232,  desc = "72音瑞士机械八音盒，可演奏多首曲",         image = IMG .. "机械/瑞士八音盒.png" },

    -- ===== DataCenter 义体机械物品 =====
    -- 白 x3
    { name = "合金螺栓",       rows = 1, cols = 1, quality = "white",  value = 105,       desc = "机柜上拆下的钛合金螺栓",                           image = IMG .. "机械/合金螺栓.png" },
    { name = "机架式服务器",   rows = 3, cols = 2, quality = "white",  value = 268,       desc = "主板被拆走的1U服务器空壳",                         image = IMG .. "机械/机架式服务器.png",      tags = {"server_hw"} },
    { name = "主机框架残骸",   rows = 4, cols = 4, quality = "white",  value = 268,       desc = "只剩框架的大型主机外壳",                           image = IMG .. "机械/主机框架残骸.png" },
    -- 绿 x1
    { name = "液压指关节组",   rows = 1, cols = 1, quality = "green",  value = 955,       desc = "工业机械手的指节部件，精度达0.01mm",               image = IMG .. "机械/液压指关节组.png",      tags = {"industrial_robot"} },
    -- 蓝 x1
    { name = "动力外骨骼腿部", rows = 2, cols = 3, quality = "blue",   value = 3190,      desc = "军用外骨骼的下肢模块，可增强负重至200kg",           image = IMG .. "机械/动力外骨骼腿部.png",    tags = {"industrial_robot"} },
    -- 紫 x3
    { name = "旧伺服电机",     rows = 1, cols = 1, quality = "purple",  value = 1101,      desc = "拆机的步进电机，精度尚可，外壳有磨损",             image = IMG .. "机械/旧伺服电机.png" },
    { name = "气动缸筒",       rows = 2, cols = 1, quality = "purple",  value = 2516,      desc = "高压气动执行器，密封圈完好，可直接使用",           image = IMG .. "机械/气动缸筒.png" },
    { name = "机械臂全套框架", rows = 3, cols = 3, quality = "purple",  value = 15725,     desc = "六自由度仿生机械臂的碳钛合金骨架",                 image = IMG .. "机械/机械臂全套框架.png",    tags = {"industrial_robot"} },
    -- 金 x3
    { name = "精密减速器",     rows = 1, cols = 1, quality = "gold",    value = 5000,      desc = "谐波减速器，传动比1:100，齿隙极小",                image = IMG .. "机械/精密减速器.png",        tags = {"industrial_robot"} },
    { name = "碳纤维机械臂段", rows = 2, cols = 1, quality = "gold",    value = 5000,      desc = "轻量化碳纤维臂节，强度高重量轻",                   image = IMG .. "机械/碳纤维机械臂段.png",    tags = {"industrial_robot"} },
    { name = "微型陀螺稳定仪", rows = 1, cols = 1, quality = "gold",    value = 157115,    desc = "军工级姿态稳定系统，可保持任何平台绝对水平",       image = IMG .. "机械/微型陀螺稳定仪.png",    tags = {"aerospace"} },
    -- 红 x3
    { name = "仿生关节组件",   rows = 2, cols = 2, quality = "red",     value = 150000,    desc = "高仿真人工关节，钛合金球头配陶瓷内衬",             image = IMG .. "机械/仿生关节组件.png" },
    { name = "液压动力单元",   rows = 2, cols = 3, quality = "red",     value = 500000,    desc = "重型机甲用液压泵站，输出扭矩惊人",                 image = IMG .. "机械/液压动力单元.png" },
    { name = "铁骑全身外骨骼", rows = 3, cols = 4, quality = "red",     value = 19000000,  desc = "完整的动力外骨骼套装，穿戴者可举起2吨重物",         image = IMG .. "机械/铁骑全身外骨骼.png",    tags = {"industrial_robot"} },

    -- ===== QuantumLab 精密仪器 =====
    -- 白 x4
    { name = "损坏的真空泵",   rows = 2, cols = 2, quality = "white",  value = 236,       desc = "叶片磨损的旋片真空泵",                             image = IMG_QL .. "机械/损坏的真空泵_20260510132336.png" },
    { name = "光学平台碎片",   rows = 2, cols = 3, quality = "white",  value = 295,       desc = "切割过的蜂窝光学面包板残片",                       image = IMG_QL .. "机械/光学平台碎片_20260510132249.png" },
    { name = "废旧精密导轨",   rows = 1, cols = 3, quality = "white",  value = 206,       desc = "锈蚀的直线导轨滑台",                               image = IMG_QL .. "机械/废旧精密导轨_20260510132240.png" },
    { name = "报废分子泵",     rows = 2, cols = 2, quality = "white",  value = 266,       desc = "轴承卡死的涡轮分子泵",                             image = IMG_QL .. "机械/报废分子泵v2_20260510141803.png" },
    -- 绿 x1
    { name = "六轴精密调节架", rows = 1, cols = 1, quality = "green",  value = 790,       desc = "光学元件用六自由度微调架",                         image = IMG_QL .. "机械/六轴精密调节架_20260510132550.png", tags = {"precision_optics"} },
    -- 蓝 x1
    { name = "超高真空腔体",   rows = 2, cols = 2, quality = "blue",   value = 3079,      desc = "可达10^-10 Pa的不锈钢真空腔",                      image = IMG_QL .. "机械/超高真空腔体_20260510132253.png",   tags = {"precision_optics"} },
    -- 紫 x2
    { name = "精密位移台",     rows = 1, cols = 2, quality = "purple", value = 1597,      desc = "纳米级精度的压电驱动位移台",                       image = IMG_QL .. "机械/精密位移台_20260510132507.png",     tags = {"precision_optics"} },
    { name = "离子阱电极组",   rows = 2, cols = 2, quality = "purple", value = 19960,     desc = "用于囚禁单个离子的微加工电极",                     image = IMG_QL .. "机械/离子阱电极组_20260510132241.png",   tags = {"precision_optics"} },
    -- 金 x2
    { name = "无振动光学台",   rows = 3, cols = 4, quality = "gold",   value = 5000,      desc = "主动减震的大型气浮光学平台",                       image = IMG_QL .. "机械/无振动光学台_20260510132503.png",   tags = {"precision_optics"} },
    { name = "原子钟机芯",     rows = 1, cols = 1, quality = "gold",   value = 112952,    desc = "铯原子钟的核心振荡模块",                           image = IMG_QL .. "机械/原子钟机芯_20260510132246.png",     tags = {"precision_optics"} },
    -- 红 x2
    { name = "引力波探测臂",   rows = 1, cols = 4, quality = "red",    value = 400000,    desc = "激光干涉仪的精密反射臂",                           image = IMG_QL .. "机械/引力波探测臂_20260510132745.png",   tags = {"precision_optics"} },
    { name = "粒子加速腔",     rows = 3, cols = 4, quality = "red",    value = 17000000,  desc = "小型直线加速器的射频超导腔体",                     image = IMG_QL .. "机械/粒子加速腔_20260510132808.png",     tags = {"precision_optics"} },
    -- ===== 新增数据中心物品 =====
    { name = "信号干扰器外壳", rows = 1, cols = 1, quality = "green", value = 1500, desc = "信号干扰设备的钛合金外壳，内部线路已移除", image = IMG .. "机械/信号干扰器外壳.png" },
    { name = "军用外骨骼脚踝", rows = 1, cols = 1, quality = "blue", value = 8500, desc = "军用动力外骨骼踝关节模块，液压驱动", image = IMG .. "机械/军用外骨骼脚踝.png" },
    { name = "军用夜光管", rows = 1, cols = 1, quality = "green", value = 2200, desc = "第三代微光夜视管，已达使用年限", image = IMG .. "机械/军用夜光管.png" },
    { name = "军用无人机主板", rows = 1, cols = 2, quality = "blue", value = 6800, desc = "战术级无人机控制主板，加密固件", image = IMG .. "机械/军用无人机主板.png" },
    { name = "反物质约束环", rows = 1, cols = 1, quality = "red", value = 8800000, desc = "用于约束反物质粒子的超导磁环", image = IMG .. "机械/反物质约束环.png" },
    { name = "反重力推进试验板", rows = 2, cols = 2, quality = "purple", value = 85000, desc = "实验室级反重力效应研究装置", image = IMG .. "机械/反重力推进试验板.png" },
    { name = "天线模组", rows = 1, cols = 1, quality = "white", value = 380, desc = "宽频天线模组，频率覆盖广", image = IMG .. "机械/天线模组.png" },
    { name = "工业级交换机", rows = 2, cols = 2, quality = "green", value = 3200, desc = "工业以太网核心交换机，防尘防震", image = IMG .. "机械/工业级交换机.png" },
    { name = "工业级激光管", rows = 1, cols = 3, quality = "blue", value = 12000, desc = "大功率CO2激光切割管，已老化", image = IMG .. "机械/工业级激光管.png" },
    { name = "废旧VR手套", rows = 1, cols = 1, quality = "white", value = 280, desc = "触觉反馈VR交互手套，关节传感器失灵", image = IMG .. "机械/废旧VR手套.png" },
    { name = "废旧光纤头", rows = 1, cols = 1, quality = "white", value = 120, desc = "磨损严重的LC光纤连接头", image = IMG .. "机械/废旧光纤头.png" },
    { name = "废旧路由核心", rows = 1, cols = 1, quality = "white", value = 350, desc = "核心路由器主板，芯片组已部分失效", image = IMG .. "机械/废旧路由核心.png" },
    { name = "无人机涡轮引擎", rows = 1, cols = 2, quality = "blue", value = 9500, desc = "小型涡轮喷气无人机发动机", image = IMG .. "机械/无人机涡轮引擎.png" },
    { name = "旧型号线缆束", rows = 1, cols = 2, quality = "white", value = 180, desc = "各类规格旧线缆捆扎，品相混杂", image = IMG .. "机械/旧型号线缆束.png" },
    { name = "机房空调机组", rows = 2, cols = 3, quality = "green", value = 4500, desc = "精密机房专用空调，制冷量10kW", image = IMG .. "机械/机房空调机组.png" },
    { name = "磁悬浮底盘组件", rows = 2, cols = 2, quality = "purple", value = 68000, desc = "磁悬浮交通工具的底盘悬浮模块", image = IMG .. "机械/磁悬浮底盘组件.png" },
    { name = "磁浮列车制动器", rows = 1, cols = 2, quality = "blue", value = 18000, desc = "涡流制动器，磁浮列车专用", image = IMG .. "机械/磁浮列车制动器.png" },

}

return Mechanical
