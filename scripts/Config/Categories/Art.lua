-- ============================================================================
-- Config/Categories/Art.lua - 艺术品类物品池
-- 来源：ItemPool.art + DataCenter.art + QuantumLab.art
-- ============================================================================

local Art = {}

local IMG = "items/"
local IMG_QL = "items/"

Art.items = {
    -- ===== ItemPool 通用艺术物品 =====
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
    -- 新增：白
    { name = "旧对联",     rows = 4, cols = 1, quality = "white",    value = 105, weight = 3,      desc = "墨迹模糊的手写春联",                 image = IMG .. "艺术/旧对联.png" },
    { name = "碎花布",     rows = 2, cols = 2, quality = "white",    value = 105, weight = 2,      desc = "一块褪色的老式碎花棉布",             image = IMG .. "艺术/碎花布.png" },
    { name = "旧竹筷",     rows = 3, cols = 1, quality = "white",    value = 105, weight = 3,      desc = "一把用旧了的竹筷子",                 image = IMG .. "艺术/旧竹筷.png" },
    -- 新增：绿
    { name = "木雕挂屏",   rows = 3, cols = 2, quality = "green",  value = 886, weight = 1,     desc = "浮雕花鸟纹的木板挂饰",               image = IMG .. "艺术/木雕挂屏.png" },
    { name = "旧绣品",     rows = 2, cols = 3, quality = "green",  value = 1583, weight = 1,     desc = "有些脱线的湘绣牡丹图案",             image = IMG .. "艺术/旧绣品.png" },
    { name = "老灯笼骨架", rows = 1, cols = 3, quality = "green",  value = 210, weight = 3,     desc = "可折叠的竹制宫灯骨架",               image = IMG .. "艺术/老灯笼骨架.png" },
    -- 新增：蓝
    { name = "铜佛龛",     rows = 3, cols = 2, quality = "blue",      value = 4083, weight = 1,     desc = "小型铜质佛龛，门扇可开合",           image = IMG .. "艺术/铜佛龛.png" },
    { name = "老蓝印花布", rows = 2, cols = 4, quality = "blue",      value = 1796, weight = 2,     desc = "整幅的手工蓝印花布门帘",             image = IMG .. "艺术/老蓝印花布.png" },
    -- 新增：紫
    { name = "漆器大盘",   rows = 3, cols = 3, quality = "purple",      value = 14139, weight = 2,   desc = "剔红工艺的大漆盘，花纹繁复",         image = IMG .. "艺术/漆器大盘.png" },
    -- 新增：金
    { name = "苏绣双面绣屏风", rows = 5, cols = 3, quality = "gold", value = 70061, weight = 3,  desc = "四扇苏绣双面绣屏风，两面图案不同",   image = IMG .. "艺术/苏绣双面绣屏风.png" },
    -- 现代艺术品：白
    { name = "旧海报",         rows = 2, cols = 1, quality = "white",  value = 105, weight = 2,      desc = "卷边褪色的电影首映海报",             image = IMG .. "艺术/旧海报.png" },
    { name = "碎马赛克片",     rows = 1, cols = 1, quality = "white",  value = 105, weight = 2,      desc = "从墙上脱落的彩色马赛克碎片",         image = IMG .. "艺术/碎马赛克片.png" },
    { name = "旧画框",         rows = 2, cols = 3, quality = "white",  value = 335, weight = 1,      desc = "里面没画的镀金塑料画框",             image = IMG .. "艺术/旧画框.png" },
    -- 现代艺术品：绿
    { name = "设计师台灯",     rows = 2, cols = 1, quality = "green",  value = 560, weight = 2,     desc = "造型独特的北欧设计台灯",             image = IMG .. "艺术/设计师台灯.png" },
    { name = "残缺手办",       rows = 1, cols = 1, quality = "green",  value = 1035, weight = 1,     desc = "断了剑的限量版游戏角色手办",         image = IMG .. "艺术/残缺手办.png" },
    { name = "概念艺术画册",   rows = 1, cols = 2, quality = "green",  value = 333, weight = 2,     desc = "绝版游戏概念设定集",                 image = IMG .. "艺术/概念艺术画册.png" },
    -- 现代艺术品：蓝
    { name = "现代抽象油画",   rows = 2, cols = 3, quality = "blue",   value = 5000, weight = 1,     desc = "签名模糊的当代抽象派油画",           image = IMG .. "艺术/现代抽象油画.png" },
    { name = "设计师限量摆件", rows = 1, cols = 1, quality = "blue",   value = 2169, weight = 2,     desc = "编号限量版的树脂艺术摆件",           image = IMG .. "艺术/设计师限量摆件.png" },
    -- 现代艺术品：紫
    { name = "当代艺术家签名版画", rows = 2, cols = 3, quality = "purple", value = 18591, weight = 1, desc = "背面有亲笔签名和编号的丝网版画",   image = IMG .. "艺术/当代艺术家签名版画.png" },
    { name = "LED动态艺术装置", rows = 3, cols = 2, quality = "purple", value = 12313, weight = 2,  desc = "编程控制的LED光影艺术装置",           image = IMG .. "艺术/LED动态艺术装置.png" },
    -- 现代艺术品：金
    { name = "知名艺术家雕塑", rows = 3, cols = 3, quality = "gold",   value = 93082, weight = 2, desc = "当代著名雕塑家的不锈钢作品，底座有铭牌", image = IMG .. "艺术/知名艺术家雕塑.png" },
    -- 低价紫/金/红补充
    { name = "砖雕花片",         rows = 1, cols = 1, quality = "purple",  value = 2233, weight = 5,    desc = "老宅拆下的浮雕花卉砖片",               image = IMG .. "艺术/砖雕花片.png" },
    { name = "粗陶花瓶",         rows = 1, cols = 1, quality = "purple",  value = 3492, weight = 4,    desc = "民间艺人手捏的粗陶花瓶，釉色素雅",     image = IMG .. "艺术/粗陶花瓶.png" },
    { name = "老年画原版",       rows = 1, cols = 2, quality = "gold",    value = 10181, weight = 16,    desc = "杨柳青年画木版原版，刻工细腻",         image = IMG .. "艺术/老年画原版.png" },
    { name = "民国月份牌",       rows = 1, cols = 1, quality = "gold",    value = 15235, weight = 11,    desc = "民国彩印美女月份牌广告画",             image = IMG .. "艺术/民国月份牌.png" },
    { name = "清宫如意",         rows = 2, cols = 1, quality = "red",     value = 104218, weight = 12,  desc = "紫檀嵌玉如意，做工精细",               image = IMG .. "艺术/清宫如意.png" },
    { name = "宋代瓷枕",         rows = 1, cols = 2, quality = "red",     value = 558839, weight = 6,  desc = "磁州窑虎形瓷枕，纹饰清晰",             image = IMG .. "艺术/宋代瓷枕.png" },
    { name = "老铜墨盒",       rows = 1, cols = 1, quality = "purple",  value = 2618, weight = 4,    desc = "盖面刻山水画的文房铜墨盒",                 image = IMG .. "艺术/老铜墨盒.png" },
    { name = "核雕手串",       rows = 1, cols = 1, quality = "purple",  value = 2156, weight = 5,    desc = "橄榄核雕十八罗汉手串",                     image = IMG .. "艺术/核雕手串.png" },
    { name = "木版年画",       rows = 1, cols = 2, quality = "purple",  value = 4871, weight = 3,    desc = "保存尚好的老版杨柳青年画",                 image = IMG .. "艺术/木版年画.png" },
    { name = "石雕门墩",       rows = 2, cols = 2, quality = "gold",    value = 15573, weight = 11,    desc = "青石抱鼓石门墩，浮雕狮子",                 image = IMG .. "艺术/石雕门墩.png" },
    { name = "铜制文镇",       rows = 1, cols = 1, quality = "gold",    value = 10458, weight = 15,    desc = "铜雕卧牛造型文镇，做工精致",               image = IMG .. "艺术/铜制文镇.png" },
    { name = "明代木雕佛像",   rows = 2, cols = 2, quality = "red",     value = 152813, weight = 10,  desc = "金漆大部脱落的明代木雕观音",               image = IMG .. "艺术/明代木雕佛像.png" },
    { name = "唐卡残片",       rows = 1, cols = 2, quality = "red",     value = 60493, weight = 15,  desc = "带矿物颜料的老唐卡画面残片",               image = IMG .. "艺术/唐卡残片.png" },

    -- ===== DataCenter 赛博艺术物品 =====
    -- 白 x5
    { name = "LED指示灯组",    rows = 1, cols = 1, quality = "white",  value = 135,       desc = "闪烁不定的服务器状态指示灯",                       image = IMG .. "艺术/LED指示灯组.png" },
    { name = "氖气灯管碎片",   rows = 1, cols = 1, quality = "white",  value = 161,       desc = "碎裂的霓虹灯管残片",                               image = IMG .. "艺术/氖气灯管碎片.png" },
    { name = "碳纤维面板",     rows = 1, cols = 2, quality = "white",  value = 215,       desc = "机柜侧板，边角有裂纹",                             image = IMG .. "艺术/碳纤维面板.png" },
    { name = "全息投影底座",   rows = 2, cols = 2, quality = "white",  value = 242,       desc = "投影模糊的桌面全息装置",                           image = IMG .. "艺术/全息投影底座.png" },
    { name = "生物识别门锁",   rows = 2, cols = 3, quality = "white",  value = 242,       desc = "传感器失灵的虹膜识别门禁",                         image = IMG .. "艺术/生物识别门锁.png" },
    -- 绿 x1
    { name = "霓虹书法灯管",   rows = 1, cols = 2, quality = "green",  value = 764,       desc = "街头艺术家手折的霓虹灯管书法作品",                 image = IMG .. "艺术/霓虹书法灯管.png" },
    -- 蓝 x1
    { name = "全息投影画框",   rows = 2, cols = 2, quality = "blue",   value = 2658,      desc = "内置微型投影仪的相框，可播放动态画作",             image = IMG .. "艺术/全息投影画框.png" },
    -- 紫 x3
    { name = "像素画打印件",   rows = 1, cols = 1, quality = "purple",  value = 786,       desc = "早期像素艺术家的签名限量打印件",                   image = IMG .. "艺术/像素画打印件.png" },
    { name = "霓虹灯管字母",   rows = 1, cols = 2, quality = "purple",  value = 1887,      desc = "拆自废弃酒吧的霓虹灯字母，还能亮",                 image = IMG .. "艺术/霓虹灯管字母.png" },
    { name = "AI协作画布原件", rows = 2, cols = 3, quality = "purple",  value = 14152,     desc = "第一批人机协作艺术运动中的布面油画原作",           image = IMG .. "艺术/AI协作画布原件.png" },
    -- 金 x3
    { name = "赛博涂鸦模板",   rows = 1, cols = 1, quality = "gold",   value = 5000,      desc = "知名街头艺术家的镂空喷漆模板原件",                 image = IMG .. "艺术/赛博涂鸦模板.png" },
    { name = "全息投影名片盒", rows = 1, cols = 1, quality = "gold",   value = 5000,      desc = "可投射3D全息影像的名片收纳盒",                     image = IMG .. "艺术/全息投影名片盒.png" },
    { name = "废墟摄影集孤本", rows = 2, cols = 2, quality = "gold",   value = 138261,    desc = "知名摄影师深入禁区拍摄的限量签名摄影集",           image = IMG .. "艺术/废墟摄影集孤本.png" },
    -- 红 x3
    { name = "街头涂鸦墙砖",   rows = 2, cols = 2, quality = "red",    value = 250000,    desc = "传奇涂鸦艺术家的原作墙砖，从拆迁现场抢救",         image = IMG .. "艺术/街头涂鸦墙砖.png" },
    { name = "动态光雕原件",   rows = 2, cols = 3, quality = "red",    value = 700000,    desc = "获奖新媒体艺术装置的核心光雕投影模块",             image = IMG .. "艺术/动态光雕原件.png" },
    { name = "电子涅槃装置",   rows = 3, cols = 4, quality = "red",    value = 16000000,  desc = "传奇新媒体艺术家遗作，由2048块LED矩阵组成",         image = IMG .. "艺术/电子涅槃装置.png" },

    -- ===== QuantumLab 学术艺术藏品 =====
    -- 白 x3
    { name = "实验室白板涂鸦",   rows = 2, cols = 2, quality = "white",  value = 177,       desc = "写满公式的白板，被咖啡渍污染",                     image = IMG_QL .. "艺术/实验室白板涂鸦_20260510133142.png" },
    { name = "旧学术海报",       rows = 1, cols = 2, quality = "white",  value = 147,       desc = "褪色的学术会议海报",                               image = IMG_QL .. "艺术/旧学术海报_20260510133014.png" },
    { name = "破碎的分子模型",   rows = 1, cols = 1, quality = "white",  value = 118,       desc = "缺了几个原子球的分子结构模型",                     image = IMG_QL .. "艺术/破碎的分子模型_20260510132752.png" },
    -- 绿 x1
    { name = "量子艺术版画",     rows = 2, cols = 2, quality = "green",  value = 878,       desc = "用量子随机数生成的限量版画",                       image = IMG_QL .. "艺术/量子艺术版画_20260510132741.png" },
    -- 蓝 x1
    { name = "薛定谔的猫雕塑",   rows = 1, cols = 1, quality = "blue",   value = 2605,      desc = "半透明树脂中嵌着猫骨架的概念雕塑",                 image = IMG_QL .. "艺术/薛定谔的猫雕塑_20260510133237.png" },
    -- 紫 x2
    { name = "费曼手稿复制件",   rows = 1, cols = 1, quality = "purple", value = 1397,      desc = "费曼亲笔路径积分推导的高仿复制件",                 image = IMG_QL .. "艺术/费曼手稿复制件_20260510133116.png" },
    { name = "量子纠缠艺术装置", rows = 2, cols = 3, quality = "purple", value = 17964,     desc = "两地同步变色的光纤艺术装置",                       image = IMG_QL .. "艺术/量子纠缠艺术装置_20260510133022.png" },
    -- 金 x1
    { name = "诺贝尔奖章复刻",   rows = 1, cols = 1, quality = "gold",   value = 5000,      desc = "某年物理学奖章的精仿品，纯金镀层",                 image = IMG_QL .. "艺术/诺贝尔奖章复刻_20260510133126.png" },
    -- 红 x1
    { name = "爱因斯坦亲笔信",   rows = 1, cols = 1, quality = "red",    value = 350000,    desc = "讨论EPR悖论的私人信件，真伪待鉴",                  image = IMG_QL .. "艺术/爱因斯坦亲笔信_20260510133616.png" },
}

return Art
