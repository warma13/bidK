-- ============================================================================
-- Config/Categories/Tech.lua - 科技品类物品定义
-- 来源：ItemPool（通用池）+ DataCenter（赛博主题）+ QuantumLab（量子主题）
-- ============================================================================

local Tech = {}

local IMG = "items/"

Tech.items = {
    -- ===== ItemPool 通用科技物品 =====
    -- 白 ×17
    { name = "坏闹钟",       rows = 1, cols = 1, quality = "white",  value = 114,  weight = 2,  desc = "指针不动的机械闹钟",               image = IMG .. "科技/坏闹钟.png" },
    { name = "旧计算器",     rows = 1, cols = 1, quality = "white",  value = 452,  weight = 1,  desc = "屏幕发暗的电子计算器",             image = IMG .. "科技/旧计算器.png" },
    { name = "断线耳机",     rows = 1, cols = 1, quality = "white",  value = 105,  weight = 2,  desc = "只有一边有声音的耳机",             image = IMG .. "科技/断线耳机.png" },
    { name = "旧遥控器",     rows = 1, cols = 1, quality = "white",  value = 105,  weight = 3,  desc = "按键失灵的电视遥控器",             image = IMG .. "科技/旧遥控器.png" },
    { name = "坏鼠标",       rows = 1, cols = 1, quality = "white",  value = 105,  weight = 2,  desc = "左键按不动的有线鼠标",             image = IMG .. "科技/坏鼠标.png" },
    { name = "旧磁带",       rows = 1, cols = 1, quality = "white",  value = 105,  weight = 2,  desc = "标签模糊的空白磁带",               image = IMG .. "科技/旧磁带.png" },
    { name = "坏石英表",     rows = 1, cols = 1, quality = "white",  value = 335,  weight = 1,  desc = "表盘进水的电子石英表",             image = IMG .. "科技/坏石英表.png" },
    { name = "旧软盘",       rows = 1, cols = 1, quality = "white",  value = 242,  weight = 2,  desc = "3.5寸软盘，贴着手写标签",           image = IMG .. "科技/旧软盘.png" },
    { name = "旧显示器",     rows = 3, cols = 3, quality = "white",  value = 676,  weight = 1,  desc = "花屏的CRT球面显示器",               image = IMG .. "科技/旧显示器.png" },
    { name = "旧打印机",     rows = 2, cols = 3, quality = "white",  value = 452,  weight = 1,  desc = "卡纸的针式打印机，色带干了",       image = IMG .. "科技/旧打印机.png" },
    { name = "旧网线",       rows = 1, cols = 3, quality = "white",  value = 105,  weight = 3,  desc = "一团缠成麻花的网线",               image = IMG .. "科技/旧网线.png" },
    { name = "旧机箱壳",     rows = 3, cols = 2, quality = "white",  value = 242,  weight = 2,  desc = "螺丝缺了一半的台式机铁皮壳",       image = IMG .. "科技/旧机箱壳.png" },
    { name = "旧天线",       rows = 4, cols = 1, quality = "white",  value = 105,  weight = 2,  desc = "弯了的室外鱼骨电视天线",           image = IMG .. "科技/旧天线.png" },
    { name = "碎屏手机",     rows = 1, cols = 1, quality = "white",  value = 529,  weight = 1,  desc = "屏幕摔成蜘蛛网的旧智能手机",       image = IMG .. "科技/碎屏手机.png" },
    { name = "旧充电头",     rows = 1, cols = 1, quality = "white",  value = 105,  weight = 3,  desc = "接口松动的快充充电器",             image = IMG .. "科技/旧充电头.png" },
    { name = "坏路由器",     rows = 1, cols = 2, quality = "white",  value = 242,  weight = 2,  desc = "天线断了一根的无线路由器",         image = IMG .. "科技/坏路由器.png" },
    { name = "旧USB集线器",  rows = 1, cols = 1, quality = "white",  value = 105,  weight = 2,  desc = "只有两个口能用的USB扩展坞",         image = IMG .. "科技/旧USB集线器.png" },
    -- 绿 ×11
    { name = "老式电话",     rows = 1, cols = 2, quality = "green",  value = 560,  weight = 2,  desc = "拨盘式黑色胶木电话机",             image = IMG .. "科技/老式电话.png" },
    { name = "旧万用表",     rows = 1, cols = 1, quality = "green",  value = 210,  weight = 3,  desc = "指针式万用电表，表盘泛黄",         image = IMG .. "科技/旧万用表.png" },
    { name = "老式BP机",     rows = 1, cols = 1, quality = "green",  value = 333,  weight = 2,  desc = "还能开机的摩托罗拉传呼机",         image = IMG .. "科技/老式BP机.png" },
    { name = "旧游戏卡带",   rows = 1, cols = 1, quality = "green",  value = 210,  weight = 3,  desc = "FC红白机卡带，标签磨损",           image = IMG .. "科技/旧游戏卡带.png" },
    { name = "旧收音机",     rows = 1, cols = 2, quality = "green",  value = 374,  weight = 2,  desc = "塑料壳AM/FM收音机",                 image = IMG .. "科技/旧收音机.png" },
    { name = "老键盘",       rows = 1, cols = 3, quality = "green",  value = 1035, weight = 1,  desc = "IBM机械键盘，缺几个键帽",           image = IMG .. "科技/老键盘.png" },
    { name = "旧温度计",     rows = 1, cols = 1, quality = "green",  value = 210,  weight = 3,  desc = "水银温度计，玻璃管完好",           image = IMG .. "科技/旧温度计.png" },
    { name = "旧传真机",     rows = 2, cols = 2, quality = "green",  value = 1583, weight = 1,  desc = "热敏纸传真机，还能通电",           image = IMG .. "科技/旧传真机.png" },
    { name = "老式座钟",     rows = 2, cols = 2, quality = "green",  value = 1711, weight = 1,  desc = "三五牌木壳座钟，发条还能上",       image = IMG .. "科技/老式座钟.png" },
    { name = "旧对讲机",     rows = 2, cols = 1, quality = "green",  value = 214,  weight = 3,  desc = "军绿色旧对讲机，天线还在",         image = IMG .. "科技/旧对讲机.png" },
    { name = "旧唱片",       rows = 2, cols = 2, quality = "green",  value = 465,  weight = 2,  desc = "封套破损的老黑胶唱片",             image = IMG .. "科技/旧唱片.png" },
    -- 绿（现代科技）
    { name = "二手机械键盘", rows = 1, cols = 3, quality = "green",  value = 1035, weight = 1,  desc = "轴体松动的Cherry红轴键盘",         image = IMG .. "科技/二手机械键盘.png" },
    { name = "旧平板电脑",   rows = 1, cols = 2, quality = "green",  value = 1324, weight = 1,  desc = "电池鼓包的旧款iPad",               image = IMG .. "科技/旧平板电脑.png" },
    { name = "旧无线耳机",   rows = 1, cols = 1, quality = "green",  value = 333,  weight = 2,  desc = "一只不出声的蓝牙耳机",             image = IMG .. "科技/旧无线耳机.png" },
    { name = "旧智能音箱",   rows = 1, cols = 1, quality = "green",  value = 210,  weight = 3,  desc = "联网失败的初代智能音箱",           image = IMG .. "科技/旧智能音箱.png" },
    -- 蓝 ×10
    { name = "老打字机",     rows = 2, cols = 3, quality = "blue",   value = 979,  weight = 2,  desc = "缺了几个键的英文打字机",           image = IMG .. "科技/老打字机.png" },
    { name = "真空管收音机", rows = 2, cols = 2, quality = "blue",   value = 5000, weight = 1,  desc = "木壳真空管短波收音机",             image = IMG .. "科技/真空管收音机.png" },
    { name = "老示波器",     rows = 2, cols = 2, quality = "blue",   value = 2703, weight = 2,  desc = "绿屏阴极射线示波器",               image = IMG .. "科技/老示波器.png" },
    { name = "老胶片相机",   rows = 1, cols = 1, quality = "blue",   value = 1444, weight = 2,  desc = "海鸥牌120双反相机",                 image = IMG .. "科技/老胶片相机.png" },
    { name = "红白机",       rows = 1, cols = 2, quality = "blue",   value = 2169, weight = 2,  desc = "任天堂FC兼容机，带手柄",           image = IMG .. "科技/红白机.png" },
    { name = "旧唱片机",     rows = 2, cols = 3, quality = "blue",   value = 4083, weight = 1,  desc = "木壳手摇唱片机，喇叭还在",         image = IMG .. "科技/旧唱片机.png" },
    { name = "老缝纫机头",   rows = 2, cols = 2, quality = "blue",   value = 786,  weight = 2,  desc = "蝴蝶牌缝纫机头，金色花纹完好",     image = IMG .. "科技/老缝纫机头.png" },
    { name = "二手VR头显",   rows = 2, cols = 2, quality = "blue",   value = 3428, weight = 1,  desc = "镜片有划痕的VR一体机",             image = IMG .. "科技/二手VR头显.png" },
    { name = "旧无人机",     rows = 2, cols = 2, quality = "blue",   value = 5000, weight = 1,  desc = "螺旋桨缺了一个的航拍无人机",       image = IMG .. "科技/旧无人机.png" },
    { name = "企业级交换机", rows = 2, cols = 3, quality = "blue",   value = 2169, weight = 2,  desc = "48口千兆以太网交换机",             image = IMG .. "科技/企业级交换机.png",       tags = {"server_hw"} },
    -- 紫 ×8
    { name = "电报机",               rows = 1, cols = 2, quality = "purple", value = 2233,  weight = 5,  desc = "铜质莫尔斯电码发报机",             image = IMG .. "科技/电报机.png" },
    { name = "老天文望远镜",         rows = 3, cols = 1, quality = "purple", value = 10428, weight = 2,  desc = "黄铜折射式天文望远镜",             image = IMG .. "科技/老天文望远镜.png",       tags = {"precision_optics"} },
    { name = "机械计算机",           rows = 2, cols = 3, quality = "purple", value = 27514, weight = 1,  desc = "手摇式机械计算机，齿轮精密",       image = IMG .. "科技/机械计算机.png" },
    { name = "老电影放映机",         rows = 3, cols = 3, quality = "purple", value = 8816,  weight = 2,  desc = "16mm胶片放映机，镜头完好",         image = IMG .. "科技/老电影放映机.png" },
    { name = "真空管计算机面板",     rows = 4, cols = 2, quality = "purple", value = 22771, weight = 1,  desc = "布满旋钮和真空管的仪器面板",       image = IMG .. "科技/真空管计算机面板.png" },
    { name = "AI训练显卡",           rows = 1, cols = 2, quality = "purple", value = 20763, weight = 1,  desc = "显存颗粒完好的数据中心GPU",         image = IMG .. "科技/AI训练显卡.png",         tags = {"server_hw"} },
    { name = "服务器机柜(满配)",     rows = 3, cols = 4, quality = "purple", value = 27514, weight = 1,  desc = "42U机柜塞满了刀片服务器",           image = IMG .. "科技/服务器机柜(满配).png",   tags = {"server_hw"} },
    { name = "机械秒表",             rows = 1, cols = 1, quality = "purple", value = 2156,  weight = 5,  desc = "瑞士产老式机械秒表，走时尚准",     image = IMG .. "科技/机械秒表.png",           tags = {"horology"} },
    -- 金 ×9
    { name = "初代随身听原型",       rows = 1, cols = 1, quality = "gold", value = 9910,   weight = 16, desc = "索尼Walkman工程验证机",             image = IMG .. "科技/初代随身听原型.png" },
    { name = "老街机框体",           rows = 3, cols = 4, quality = "gold", value = 136580, weight = 1,  desc = "八十年代日本产街机框体，屏幕还亮", image = IMG .. "科技/老街机框体.png" },
    { name = "老式军用电台",         rows = 2, cols = 2, quality = "gold", value = 26524,  weight = 6,  desc = "二战时期军用短波电台，面板完好",   image = IMG .. "科技/老式军用电台.png" },
    { name = "早期Apple-I主板",      rows = 2, cols = 3, quality = "gold", value = 43436,  weight = 4,  desc = "缺芯片的Apple-I电路板，序列号可查", image = IMG .. "科技/早期Apple-I主板.png" },
    { name = "登月相机镜头组件",     rows = 1, cols = 1, quality = "gold", value = 173016, weight = 1,  desc = "哈苏相机太空定制版的备用镜头模组", image = IMG .. "科技/登月相机镜头组件.png",   tags = {"aerospace"} },
    { name = "旧大型磁带机",         rows = 5, cols = 3, quality = "gold", value = 51788,  weight = 3,  desc = "七十年代大型磁带存储设备，转轴还能动", image = IMG .. "科技/旧大型磁带机.png",  tags = {"server_hw"} },
    { name = "定制AI芯片",           rows = 1, cols = 1, quality = "gold", value = 69408,  weight = 3,  desc = "独角兽公司自研的TPU芯片，未公开发售", image = IMG .. "科技/定制AI芯片.png",     tags = {"server_hw", "semiconductor"} },
    { name = "初代游戏机",           rows = 1, cols = 2, quality = "gold", value = 13273,  weight = 12, desc = "任天堂初代家用游戏机，缺电源线",   image = IMG .. "科技/初代游戏机.png" },
    { name = "老唱片机",             rows = 2, cols = 2, quality = "gold", value = 22328,  weight = 8,  desc = "手摇式留声机，铜喇叭口有凹痕",     image = IMG .. "科技/老唱片机.png" },
    -- 红 ×9
    { name = "恩尼格玛密码机零件",   rows = 2, cols = 2, quality = "red", value = 6061058,  weight = 3,   desc = "疑似二战恩尼格玛密码机的转子组件", image = IMG .. "科技/恩尼格玛密码机零件.png" },
    { name = "图灵手稿残页",         rows = 1, cols = 1, quality = "red", value = 2882835,  weight = 7,   desc = "疑似图灵亲笔的计算理论手稿残页", image = IMG .. "科技/图灵手稿残页.png" },
    { name = "阿波罗导航计算机",     rows = 3, cols = 3, quality = "red", value = 13643215, weight = 1,   desc = "阿波罗登月任务的机载导航计算机AGC", image = IMG .. "科技/阿波罗导航计算机.png",  tags = {"aerospace"} },
    { name = "量子计算处理器原型",   rows = 2, cols = 2, quality = "red", value = 7619683,  weight = 3,   desc = "超导量子比特处理器，密封在液氮容器中", image = IMG .. "科技/量子计算处理器原型.png", tags = {"semiconductor"} },
    { name = "爱迪生留声机部件",     rows = 1, cols = 2, quality = "red", value = 122793,   weight = 195, desc = "疑似爱迪生实验室的蜡筒留声机零件", image = IMG .. "科技/爱迪生留声机部件.png" },
    { name = "达芬奇手稿残页",       rows = 1, cols = 1, quality = "red", value = 646139,   weight = 34,  desc = "疑似达芬奇设计的机械装置草图残页", image = IMG .. "科技/达芬奇手稿残页.png" },
    { name = "老式相机",             rows = 1, cols = 1, quality = "purple", value = 3334,  weight = 4,   desc = "海鸥牌120胶片相机，镜头有霉丝",   image = IMG .. "科技/老式相机.png" },
    { name = "老天文台时钟",         rows = 2, cols = 2, quality = "red", value = 260582,   weight = 89,  desc = "天文台标准时钟机芯，精度极高",     image = IMG .. "科技/老天文台时钟.png" },
    { name = "早期X光管",            rows = 1, cols = 2, quality = "red", value = 60493,    weight = 410, desc = "20世纪初的玻璃X光真空管，完好罕见", image = IMG .. "科技/早期X光管.png" },
    -- 紫（补充）
    { name = "旧经纬仪",   rows = 1, cols = 2, quality = "purple", value = 2900,  weight = 4,  desc = "测量用的老式光学经纬仪，铜件齐全",     image = IMG .. "科技/旧经纬仪.png" },
    { name = "老航空仪表", rows = 1, cols = 1, quality = "purple", value = 4114,  weight = 3,  desc = "退役飞机拆下的机械高度表",             image = IMG .. "科技/老航空仪表.png" },
    { name = "铜望远镜",   rows = 1, cols = 2, quality = "purple", value = 6374,  weight = 2,  desc = "三节伸缩的黄铜航海望远镜",             image = IMG .. "科技/铜望远镜.png" },
    { name = "老式气压计", rows = 1, cols = 1, quality = "gold",   value = 13036, weight = 13, desc = "精密黄铜机械气压计，表盘完好",         image = IMG .. "科技/老式气压计.png" },
    { name = "军用罗盘",   rows = 1, cols = 1, quality = "gold",   value = 19458, weight = 9,  desc = "铝壳军用行军罗盘，荧光刻度",           image = IMG .. "科技/军用罗盘.png" },

    -- ===== DataCenter 赛博科技物品 =====
    { name = "数据存储柜",       rows = 1, cols = 1, quality = "white",  value = 380,    desc = "损坏的256GB NVMe闪存芯片",               image = IMG .. "科技/数据存储柜.png" },
    { name = "断线数据芯片",       rows = 1, cols = 1, quality = "green",  value = 1800,   desc = "专用AI推理加速芯片，封装完好",           image = IMG .. "科技/断线数据芯片.png",  tags = {"semiconductor"} },
    { name = "神经接口芯片",   rows = 1, cols = 1, quality = "blue",   value = 6500,   desc = "脑机接口信号处理芯片，32通道",           image = IMG .. "科技/神经接口芯片.png",  tags = {"semiconductor"} },
    { name = "初代VR头显",         rows = 2, cols = 2, quality = "green",  value = 3800,   desc = "8K分辨率VR一体机，电池衰减",             image = IMG .. "科技/初代VR头显.png" },
    { name = "量子密钥分发器", rows = 2, cols = 1, quality = "purple", value = 38000,  desc = "量子密钥分发QKD发射接收模块对",         image = IMG .. "科技/量子密钥分发器.png",  tags = {"semiconductor"} },
    { name = "意识数字化接口",   rows = 1, cols = 2, quality = "purple", value = 62000,  desc = "非侵入式256通道脑电信号采集设备",       image = IMG .. "科技/意识数字化接口.png",  tags = {"semiconductor"} },
    { name = "初代智能手机工程机", rows = 1, cols = 1, quality = "gold", value = 280000, desc = "iPhone原型机，内置测试固件",           image = IMG .. "科技/初代智能手机工程机.png" },
    { name = "硬盘阵列盒",     rows = 1, cols = 1, quality = "blue",   value = 11000,  desc = "仿神经突触的忆阻器存算一体芯片",         image = IMG .. "科技/硬盘阵列盒.png",  tags = {"server_hw"} },
    { name = "生物芯片植入器",       rows = 1, cols = 1, quality = "gold",   value = 560000, desc = "碳纳米管场效应晶体管芯片，超低功耗",     image = IMG .. "科技/生物芯片植入器.png",  tags = {"semiconductor"} },

    -- ===== QuantumLab 量子科技物品 =====
    { name = "比特矿机主板",       rows = 1, cols = 1, quality = "white",  value = 650,    desc = "5比特量子处理器芯片，铝质超导",         image = IMG .. "科技/比特矿机主板.png",  tags = {"server_hw"} },
    -- ===== 新增数据中心物品 =====
    { name = "创世区块硬盘", rows = 1, cols = 1, quality = "red", value = 12000000, desc = "存有比特币创世区块数据的原装硬盘", image = IMG .. "科技/创世区块硬盘.png",  tags = {"server_hw"} },
    { name = "加密U盘", rows = 1, cols = 1, quality = "green", value = 3500, desc = "军用级加密U盘，256位AES硬件加密", image = IMG .. "科技/加密U盘.png" },
    { name = "加密无线电台", rows = 2, cols = 2, quality = "blue", value = 18000, desc = "跳频加密短波电台，密钥每分钟更换", image = IMG .. "科技/加密无线电台.png" },
    { name = "烧毁的内存条", rows = 1, cols = 1, quality = "white", value = 150, desc = "过压损毁的DDR5内存条，芯片焦黑", image = IMG .. "科技/烧毁的内存条.png",  tags = {"server_hw"} },
    { name = "磁带备份库", rows = 3, cols = 2, quality = "blue", value = 22000, desc = "LTO-9磁带自动化备份系统，含机械臂", image = IMG .. "科技/磁带备份库.png",  tags = {"server_hw"} },
    { name = "神经信号转译器", rows = 1, cols = 1, quality = "gold", value = 380000, desc = "将神经电信号解码为数字指令的处理器", image = IMG .. "科技/神经信号转译器.png",  tags = {"semiconductor"} },
    { name = "绝版操作系统软盘", rows = 1, cols = 1, quality = "purple", value = 58000, desc = "Apple Lisa原版系统启动软盘，可运行", image = IMG .. "科技/绝版操作系统软盘.png" },
    { name = "脑电波耳机原型", rows = 1, cols = 2, quality = "purple", value = 95000, desc = "非侵入式脑机接口原型，32通道EEG", image = IMG .. "科技/脑电波耳机原型.png",  tags = {"semiconductor"} },

}

return Tech
