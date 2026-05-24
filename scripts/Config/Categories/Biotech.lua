-- ============================================================================
-- Config/Categories/Biotech.lua - 医疗品类物品定义
-- 来源：医院、诊所、医疗实验室、急救仓库
-- ============================================================================

local Biotech = {}

local IMG = "items/医疗/"

Biotech.items = {
    -- 白 ×12
    { name = "注射器",         rows = 1, cols = 1, quality = "white",  value = 70,    desc = "一次性无菌注射器，包装完好未开封",               image = IMG .. "注射器.png" },
    { name = "小药瓶",         rows = 1, cols = 1, quality = "white",  value = 84,    desc = "棕色玻璃药瓶，内含未知粉末",                     image = IMG .. "小药瓶.png" },
    { name = "外科手套",       rows = 1, cols = 2, quality = "white",  value = 105,   desc = "无菌乳胶外科手套，一盒50双",                     image = IMG .. "外科手套.png" },
    { name = "手术镊子",       rows = 1, cols = 1, quality = "white",  value = 126,   desc = "不锈钢外科镊子，尖端未变形",                     image = IMG .. "手术镊子.png" },
    { name = "盐溶液",         rows = 1, cols = 1, quality = "white",  value = 98,    desc = "0.9%氯化钠注射液，250ml袋装",                    image = IMG .. "盐溶液.png" },
    { name = "样本试管",       rows = 1, cols = 1, quality = "white",  value = 112,   desc = "真空采血试管一盒，紫色盖EDTA抗凝",               image = IMG .. "样本试管.png" },
    { name = "手术剪刀",       rows = 1, cols = 1, quality = "white",  value = 140,   desc = "医用不锈钢剪刀，刃口锋利无锈迹",                 image = IMG .. "手术剪刀.png" },
    { name = "额温枪",         rows = 1, cols = 2, quality = "white",  value = 168,   desc = "红外额温计，电池已更换，精度±0.2℃",              image = IMG .. "额温枪.png" },
    { name = "医用酒精",       rows = 1, cols = 1, quality = "white",  value = 91,    desc = "75%乙醇消毒液，500ml喷壶装",                     image = IMG .. "医用酒精.png" },
    { name = "含氟牙膏",       rows = 1, cols = 1, quality = "white",  value = 63,    desc = "医用氟化钠防龋牙膏，未开封",                     image = IMG .. "含氟牙膏.png" },
    { name = "输液工具",       rows = 1, cols = 2, quality = "white",  value = 154,   desc = "一次性输液器套装，含针头和管路",                 image = IMG .. "输液工具.png" },
    { name = "旧型号血糖仪",   rows = 1, cols = 2, quality = "white",  value = 210,   desc = "已停产款式血糖检测仪，试纸还剩半盒",             image = IMG .. "旧型号血糖仪.png" },
    -- 绿 ×12
    { name = "血压仪",         rows = 1, cols = 2, quality = "green",  value = 680,   desc = "电子上臂式血压计，附大码袖带，精度±3mmHg",      image = IMG .. "血压仪.png" },
    { name = "听诊器",         rows = 1, cols = 2, quality = "green",  value = 840,   desc = "双面胸件听诊器，医用级软管，音质清晰",           image = IMG .. "听诊器.png" },
    { name = "急救喷雾",       rows = 1, cols = 1, quality = "green",  value = 560,   desc = "速效关节止痛喷雾，冷冻型，未过期",               image = IMG .. "急救喷雾.png" },
    { name = "血氧仪",         rows = 1, cols = 1, quality = "green",  value = 720,   desc = "指夹式脉搏血氧仪，OLED大屏，两节电池在",        image = IMG .. "血氧仪.png" },
    { name = "静脉定位器",     rows = 1, cols = 2, quality = "green",  value = 980,   desc = "近红外静脉成像仪，手持式，帮助难找血管者",       image = IMG .. "静脉定位器.png" },
    { name = "无菌敷料包",     rows = 1, cols = 2, quality = "green",  value = 490,   desc = "独立包装无菌纱布与绷带组合，战地急救用",         image = IMG .. "无菌敷料包.png" },
    { name = "检眼镜",         rows = 1, cols = 2, quality = "green",  value = 1140,  desc = "直接检眼镜，LED光源，可换头，附皮套",            image = IMG .. "检眼镜.png" },
    { name = "哮喘吸入器",     rows = 1, cols = 1, quality = "green",  value = 630,   desc = "定量压力气雾吸入器，沙丁胺醇，未过期",           image = IMG .. "哮喘吸入器.png" },
    { name = "便携氧气筒",     rows = 1, cols = 2, quality = "green",  value = 860,   desc = "2升铝合金便携氧气瓶，附氧气面罩和流量表",        image = IMG .. "便携氧气筒.png" },
    { name = "医用滤毒罐",     rows = 1, cols = 1, quality = "green",  value = 770,   desc = "综合防护型滤毒罐，适配多种防毒面具接口",         image = IMG .. "医用滤毒罐.png" },
    { name = "骨锯",           rows = 1, cols = 2, quality = "green",  value = 1260,  desc = "摆动骨锯，不锈钢锯片可消毒，手术室配置",         image = IMG .. "骨锯.png" },
    { name = "医用酒精桶",     rows = 2, cols = 2, quality = "green",  value = 560,   desc = "20升医用酒精储存桶，密封阀完好",                 image = IMG .. "医用酒精桶.png" },
    -- 蓝 ×10
    { name = "离心机",         rows = 2, cols = 2, quality = "blue",   value = 3800,  desc = "台式高速离心机，最大转速12000rpm，含多种转头",   image = IMG .. "离心机.png" },
    { name = "电子显微镜",     rows = 2, cols = 2, quality = "blue",   value = 5600,  desc = "数码变焦电子显微镜，配置CCD摄像模块",            image = IMG .. "电子显微镜.png" },
    { name = "人工膝关节",     rows = 1, cols = 2, quality = "blue",   value = 4200,  desc = "钛合金全膝关节置换假体，原装无菌包装",           image = IMG .. "人工膝关节.png" },
    { name = "医疗无人机",     rows = 2, cols = 2, quality = "blue",   value = 4900,  desc = "急救物资投送无人机，保温舱容积5L，续航45分钟",   image = IMG .. "医疗无人机.png" },
    { name = "生化培养箱",     rows = 2, cols = 2, quality = "blue",   value = 3200,  desc = "CO₂细胞培养箱，温控精度±0.1℃，双层门密封",      image = IMG .. "生化培养箱.png" },
    { name = "核磁共振线圈",   rows = 2, cols = 2, quality = "blue",   value = 6100,  desc = "脊柱专用表面线圈，与1.5T/3.0T设备兼容",         image = IMG .. "核磁共振线圈.png" },
    { name = "腹腔镜套件",     rows = 2, cols = 2, quality = "blue",   value = 5300,  desc = "10mm腹腔镜镜头及套管套件，视野广角120°",        image = IMG .. "腹腔镜套件.png" },
    { name = "呼吸机",         rows = 2, cols = 2, quality = "blue",   value = 7800,  desc = "便携式正压通气呼吸机，支持CPAP/BiPAP多模式",    image = IMG .. "呼吸机.png" },
    { name = "冷冻存储罐",     rows = 2, cols = 2, quality = "blue",   value = 2900,  desc = "液氮生物样本存储罐，35升容量，静止蒸发率低",     image = IMG .. "冷冻存储罐.png" },
    { name = "骨密度检测仪",   rows = 2, cols = 2, quality = "blue",   value = 3500,  desc = "超声骨密度仪，足跟法测量，附打印模块",           image = IMG .. "骨密度检测仪.png" },
    -- 紫 ×6
    { name = "心脏支架",       rows = 1, cols = 1, quality = "purple", value = 9800,  desc = "药物洗脱冠状动脉支架，进口钴铬合金，原装灭菌",   image = IMG .. "心脏支架.png" },
    { name = "体内除颤器",     rows = 1, cols = 2, quality = "purple", value = 14500, desc = "植入式心律转复除颤器，双腔ICD，含原装导线",       image = IMG .. "体内除颤器.png" },
    { name = "人工耳蜗",       rows = 1, cols = 2, quality = "purple", value = 12000, desc = "22通道人工耳蜗植入体，附言语处理器和充电架",     image = IMG .. "人工耳蜗.png" },
    { name = "稀有血液样本",   rows = 1, cols = 1, quality = "purple", value = 18000, desc = "RhNull全表型阴性血液冷冻样本，医学研究极稀品",   image = IMG .. "稀有血液样本.png" },
    { name = "便携生命支持装置", rows = 2, cols = 2, quality = "purple", value = 22000, desc = "野战级便携心肺支持设备，电池续航6小时",           image = IMG .. "便携生命支持装置.png" },
    { name = "手术机器人臂",   rows = 2, cols = 2, quality = "purple", value = 35000, desc = "微创手术辅助机械臂单元，7自由度精准操控模块",     image = IMG .. "手术机器人臂.png" },
    -- 红 ×3
    { name = "ECMO",           rows = 2, cols = 3, quality = "red",    value = 120000, desc = "体外膜肺氧合设备，含离心泵、膜肺和循环管路",     image = IMG .. "ECMO.png" },
    { name = "复苏呼吸机",     rows = 2, cols = 2, quality = "red",    value = 85000,  desc = "顶级ICU呼吸机，全模式覆盖，内置氧气浓度仪",     image = IMG .. "复苏呼吸机.png" },
    { name = "基因测序系统",   rows = 2, cols = 3, quality = "red",    value = 200000, desc = "桌面型第三代纳米孔测序仪，实时输出，附分析软件", image = IMG .. "基因测序系统.png" },
    -- 高端科研仪器 白 ×3
    { name = "PCR试剂盒",      rows = 1, cols = 2, quality = "white",  value = 168,   desc = "实时荧光定量PCR试剂盒，50反应份，含阳性对照",   image = IMG .. "PCR试剂盒.png",               tags = {"research_instrument"} },
    { name = "基因芯片",       rows = 1, cols = 1, quality = "white",  value = 210,   desc = "单通道基因表达谱芯片，可检测25000个探针位点",   image = IMG .. "基因芯片.png",                 tags = {"research_instrument"} },
    { name = "单克隆抗体试剂", rows = 1, cols = 1, quality = "white",  value = 280,   desc = "小鼠来源单克隆抗体，100μg冻干粉，抗体效价高",   image = IMG .. "单克隆抗体试剂.png",           tags = {"research_instrument"} },
    -- 高端科研仪器 绿 ×4
    { name = "荧光显微镜镜头", rows = 1, cols = 1, quality = "green",  value = 1200,  desc = "60倍油浸荧光物镜，NA1.4，多色荧光兼容",         image = IMG .. "荧光显微镜镜头.png",           tags = {"research_instrument"} },
    { name = "冷冻切片机刀片", rows = 1, cols = 2, quality = "green",  value = 680,   desc = "冷冻切片机专用高碳钢刀片，一盒50片，未开封",     image = IMG .. "冷冻切片机刀片.png",           tags = {"research_instrument"} },
    { name = "流式细胞仪耗材包", rows = 1, cols = 2, quality = "green", value = 980,  desc = "流式专用样品管、鞘液和校准微球套装",             image = IMG .. "流式细胞仪耗材包.png",         tags = {"research_instrument"} },
    { name = "蛋白质电泳系统", rows = 2, cols = 2, quality = "green",  value = 1450,  desc = "迷你凝胶电泳槽套装，含电源模块和转膜夹具",       image = IMG .. "蛋白质电泳系统.png",           tags = {"research_instrument"} },
    -- 高端科研仪器 蓝 ×3
    { name = "原子力显微镜探针", rows = 1, cols = 1, quality = "blue", value = 3200,  desc = "硅基悬臂AFM探针，针尖曲率半径<5nm，10根装",     image = IMG .. "原子力显微镜探针.png",         tags = {"research_instrument"} },
    { name = "质谱仪离子源模块", rows = 1, cols = 2, quality = "blue", value = 5800,  desc = "ESI电喷雾离子源模块，兼容多品牌质谱仪接口",       image = IMG .. "质谱仪离子源模块.png",         tags = {"research_instrument"} },
    { name = "超分辨率成像探针", rows = 1, cols = 1, quality = "blue", value = 4400,  desc = "STED超分辨荧光探针，光稳定性极高，分辨率<50nm",  image = IMG .. "超分辨率成像探针.png",         tags = {"research_instrument"} },
    -- 金 ×3
    { name = "冷冻电镜样品台",       rows = 2, cols = 2, quality = "gold",  value = 58000,  desc = "cryo-EM自动样品台，液氮冷却，附振动隔离底座",         image = IMG .. "冷冻电镜样品台.png",           tags = {"research_instrument"} },
    { name = "微型介入导管机器人",   rows = 2, cols = 2, quality = "gold",  value = 75000,  desc = "血管介入微型机器人，0.5mm导管径，磁场导航",           image = IMG .. "微型介入导管机器人.png",       tags = {"research_instrument"} },
    { name = "质子治疗准直器",       rows = 2, cols = 2, quality = "gold",  value = 95000,  desc = "多叶准直器模块，用于质子束精准形塑，医院级别",         image = IMG .. "质子治疗准直器.png",           tags = {"research_instrument"} },
    -- 金 ×7（补充）
    { name = "术中荧光造影仪",       rows = 1, cols = 2, quality = "gold",  value = 68000,  desc = "近红外荧光手术成像仪，实时识别肿瘤边界，含滤光镜组",   image = IMG .. "术中荧光造影仪.png" },
    { name = "手术导航系统",         rows = 2, cols = 2, quality = "gold",  value = 92000,  desc = "光学手术导航仪，追踪精度±0.3mm，含反光球与参考支架",   image = IMG .. "手术导航系统.png" },
    { name = "神经外科定向仪",       rows = 2, cols = 2, quality = "gold",  value = 105000, desc = "框架式立体定向仪，精度±0.1mm，附MRI兼容底座",           image = IMG .. "神经外科定向仪.png" },
    { name = "高通量药物筛选平台",   rows = 2, cols = 2, quality = "gold",  value = 128000, desc = "384孔板自动化药物筛选工作站，含高精度分液机械臂",       image = IMG .. "高通量药物筛选平台.png" },
    { name = "基因编辑递送系统",     rows = 2, cols = 2, quality = "gold",  value = 82000,  desc = "脂质纳米颗粒基因编辑递送平台，含sgRNA体外转录套件",     image = IMG .. "基因编辑递送系统.png",         tags = {"research_instrument"} },
    { name = "人工心脏辅助泵",       rows = 1, cols = 2, quality = "gold",  value = 190000, desc = "植入式左心室辅助装置，离心流型，含外部控制器和备用电源", image = IMG .. "人工心脏辅助泵.png" },
    { name = "手术机器人单臂模块",   rows = 2, cols = 2, quality = "gold",  value = 155000, desc = "腔镜手术机器人单工作臂，7自由度精密关节，原装消毒包装", image = IMG .. "手术机器人单臂模块.png" },
    -- 红 ×5（补充）
    { name = "单细胞测序平台",       rows = 2, cols = 2, quality = "red",   value = 820000,  desc = "超高通量单细胞RNA测序仪，一次处理10000细胞，含试剂盒",  image = IMG .. "单细胞测序平台.png",           tags = {"research_instrument"} },
    { name = "流式细胞分选仪",       rows = 2, cols = 3, quality = "red",   value = 1250000, desc = "高速细胞分选仪，每秒可分选70000个，15色荧光同步检测",  image = IMG .. "流式细胞分选仪.png" },
    { name = "手术机器人系统",       rows = 3, cols = 3, quality = "red",   value = 2400000, desc = "完整四臂腔镜手术机器人，含主控台、患者车及全套器械",    image = IMG .. "手术机器人系统.png" },
    { name = "超导脑磁图仪",         rows = 3, cols = 3, quality = "red",   value = 3600000, desc = "248通道SQUID脑磁图仪，液氦冷却系统完整，信号噪声极低", image = IMG .. "超导脑磁图仪.png" },
    { name = "质子治疗加速器喷嘴",   rows = 3, cols = 4, quality = "red",   value = 5800000, desc = "旋转机架质子治疗加速器同步喷嘴模块，含全套控制系统",    image = IMG .. "质子治疗加速器喷嘴.png" },
}

return Biotech
