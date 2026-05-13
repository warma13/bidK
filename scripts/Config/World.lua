-- ============================================================================
-- Config/World.lua - 世界地图、区域与仓库类型定义
-- 7个区域 / 50个仓库类型
-- ============================================================================

local M = {}

M.WORLD_MAP_BG = "image/world_map_bg.png"
M.DEFAULT_BGM  = "audio/bgm_grocery.ogg"

-- ============================================================================
-- 区域定义
-- ============================================================================

M.REGIONS = {

    -- ── 区域1：城郊旧仓区（1万门槛，4仓库）────────────────────────────
    {
        id = "suburb", name = "城郊旧仓区",
        ticket = "ticket_suburb",
        icon = "",
        bg   = "image/bg_oldtown_20260321192643.png",
        bgm  = "audio/bgm_oldtown.ogg",
        desc = "城郊居民区的老旧储物仓，五金杂货与遗留旧物混杂一处",
        mapX = 0.23, mapY = 0.58,
        warehouseTypes = { "suburb_unknown", "suburb_basement", "suburb_supermarket", "suburb_recycling", "suburb_hardware" },
        difficulties = {
            {
                level = "suburb", label = "1万场",
                entryFee = 0,
                startingMoney = 80000,
                warehouseValue = 10000,
                assetRequirement = 10000,
            },
        },
    },

    -- ── 区域2：工业物流园（10万门槛，6仓库）───────────────────────────
    {
        id = "industrial", name = "工业物流园",
        ticket = "ticket_industrial",
        icon = "",
        bg   = "image/bg_warehouse_techpark_20260322132509.png",
        bgm  = "audio/bgm_grocery.ogg",
        desc = "老工业区的厂房与物流仓库，机械零件和电子废品堆积如山",
        mapX = 0.36, mapY = 0.50,
        warehouseTypes = { "ind_unknown", "ind_autoparts", "ind_building", "ind_machinery", "ind_ewaste", "ind_appliance", "ind_unclaimed" },
        difficulties = {
            {
                level = "industrial", label = "10万场",
                entryFee = 3000,
                startingMoney = 600000,
                warehouseValue = 80000,
                assetRequirement = 100000,
            },
        },
    },

    -- ── 区域3：商业综合体（50万门槛，8仓库）───────────────────────────
    {
        id = "commercial", name = "商业综合体",
        ticket = "ticket_commercial",
        icon = "",
        bg   = "image/bg_oldtown_20260321192643.png",
        bgm  = "audio/bgm_grocery.ogg",
        desc = "大型购物中心与品牌连锁店的滞销库存和清仓货物",
        mapX = 0.52, mapY = 0.82,
        warehouseTypes = { "com_unknown", "com_department", "com_brandclear", "com_superstore", "com_jewelry", "com_sports", "com_imports", "com_furniture", "com_cosmetics" },
        difficulties = {
            {
                level = "commercial", label = "50万场",
                entryFee = 15000,
                startingMoney = 3000000,
                warehouseValue = 400000,
                assetRequirement = 500000,
            },
        },
    },

    -- ── 区域4：国际港口区（100万门槛，8仓库）──────────────────────────
    {
        id = "port", name = "国际港口区",
        ticket = "ticket_port",
        icon = "image/warehouse_bondedport_20260323083437.png",
        bg   = "image/edited_bg_bondedport_night_20260323131115.png",
        bgm  = "audio/bgm_bondedport.ogg",
        desc = "繁忙国际港口的海关扣押仓与保税区，全球各地货物汇聚于此",
        mapX = 0.78, mapY = 0.70,
        warehouseTypes = { "port_unknown", "port_customs", "port_container", "port_unclaimed", "port_bonded", "port_coldchain", "port_artship", "port_yacht", "port_auction" },
        difficulties = {
            {
                level = "port", label = "100万场",
                entryFee = 30000,
                startingMoney = 6000000,
                warehouseValue = 800000,
                assetRequirement = 1000000,
            },
        },
    },

    -- ── 区域5：科技创新园（200万门槛，8仓库）──────────────────────────
    {
        id = "techpark", name = "科技创新园",
        ticket = "ticket_techpark",
        icon = "image/warehouse_techpark_20260321194424.png",
        bg   = "image/bg_techpark_20260321192636.png",
        bgm  = "audio/bgm_techpark.ogg",
        desc = "高新技术企业集聚区，倒闭的AI公司与实验室剩余设备等待拍卖",
        mapX = 0.67, mapY = 0.35,
        warehouseTypes = { "tech_unknown", "tech_incubator", "tech_quantum", "tech_semiconductor", "tech_medical", "tech_newenergy", "tech_aerospace", "tech_datacenter", "tech_university" },
        difficulties = {
            {
                level = "techpark", label = "200万场",
                entryFee = 50000,
                startingMoney = 12000000,
                warehouseValue = 1500000,
                assetRequirement = 2000000,
            },
        },
    },

    -- ── 区域6：文化艺术区（500万门槛，8仓库）──────────────────────────
    {
        id = "culture", name = "文化艺术区",
        ticket = "ticket_culture",
        icon = "",
        bg   = "image/bg_oldtown_20260321192643.png",
        bgm  = "audio/bgm_oldtown.ogg",
        desc = "古玩市场、拍卖行与私人博物馆聚集地，顶级藏品竞拍之所",
        mapX = 0.12, mapY = 0.22,
        warehouseTypes = { "cult_unknown", "cult_museum", "cult_auction", "cult_antique", "cult_luxury", "cult_gallery", "cult_jewelry", "cult_watch", "cult_wine" },
        difficulties = {
            {
                level = "culture", label = "500万场",
                entryFee = 100000,
                startingMoney = 30000000,
                warehouseValue = 4000000,
                assetRequirement = 5000000,
            },
        },
    },

    -- ── 区域7：深海打捞站（500万门槛，8仓库）──────────────────────────
    {
        id = "deepsea", name = "深海打捞站",
        ticket = "ticket_deepsea",
        icon = "image/warehouse_shipwreck_20260328210723.png",
        bg   = "image/bg_warehouse_shipwreck_20260328204443.png",
        bgm  = "audio/bgm_bondedport.ogg",
        desc = "远洋打捞与水下考古的物资集散地，海底遗物与远古宝藏静待发掘",
        mapX = 0.91, mapY = 0.58,
        warehouseTypes = { "sea_unknown", "sea_archaeology", "sea_wreck", "sea_expedition", "sea_research", "sea_biology", "sea_maintenance", "sea_minerals", "sea_harbor" },
        difficulties = {
            {
                level = "deepsea", label = "500万场",
                entryFee = 120000,
                startingMoney = 30000000,
                warehouseValue = 4000000,
                assetRequirement = 5000000,
            },
        },
    },
}

-- ============================================================================
-- 仓库类型定义（50个）
-- sizeWeights: { 1格, 2格, 4格, 6格, 9格+ }
-- categoryWeights: 品类权重（覆盖 ItemPool 默认值）
-- allowedCategories: （可选）限定品类白名单
-- ============================================================================

M.WAREHOUSE_TYPES = {

    -- ── 区域1：城郊旧仓区 ────────────────────────────────────────────────

    suburb_unknown = {
        name = "神秘仓库",
        desc = "来源不明的城郊仓库，无人知晓里面藏着什么——也许是邻居多年的杂物，也许是意外之财",
        icon = "image/icon_unknown_warehouse.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 38, 28, 18, 10, 6 },
        categoryWeights = { daily = 30, antique = 20, mechanical = 20, tech = 15, art = 10, fashion = 5 },
    },
    suburb_basement = {
        name = "居民楼地下储物间",
        desc = "老旧居民楼深处的地下储物间，住户多年积攒的生活杂物与偶尔遗忘的心爱之物混存于此",
        icon = "image/icon_suburb_basement.png", bg = "image/bg_warehouse_grocery_20260322132513.png",
        sizeWeights = { 42, 30, 15, 8, 5 },
        categoryWeights = { daily = 45, antique = 20, mechanical = 15, art = 10, fashion = 5, jewel = 5 },
    },
    suburb_supermarket = {
        name = "社区大卖场库房",
        desc = "城郊大卖场的滞销存货仓，日用百货、家电零件与过季商品堆满货架，等待打包处理",
        icon = "image/icon_suburb_supermarket.png", bg = "image/bg_warehouse_grocery_20260322132513.png",
        sizeWeights = { 40, 32, 16, 8, 4 },
        categoryWeights = { daily = 60, mechanical = 15, transport = 10, tech = 8, fashion = 7 },
    },
    suburb_recycling = {
        name = "废品收购站",
        desc = "街头废品站堆积的旧电器与拆解零件，懂行的人往往能从这里淘出意想不到的好货",
        icon = "image/icon_suburb_recycling.png", bg = "image/bg_warehouse_grocery_20260322132513.png",
        sizeWeights = { 35, 28, 20, 12, 5 },
        categoryWeights = { mechanical = 35, energy = 25, tech = 20, transport = 12, daily = 8 },
    },
    suburb_hardware = {
        name = "五金杂货备货仓",
        desc = "经营了几十年的五金杂货店后仓，工具、配件与日用品积压数年，老板急于清仓变现",
        icon = "image/icon_suburb_hardware.png", bg = "image/bg_warehouse_grocery_20260322132513.png",
        sizeWeights = { 38, 30, 18, 10, 4 },
        categoryWeights = { mechanical = 40, daily = 25, transport = 18, energy = 10, tech = 7 },
    },

    -- ── 区域2：工业物流园 ────────────────────────────────────────────────

    ind_unknown = {
        name = "神秘仓库",
        desc = "工业园区一处来历不明的封存仓库，长期无人问津，里面究竟放着机器还是废铁，只有打开才能知道",
        icon = "image/icon_unknown_warehouse.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 25, 27, 24, 15, 9 },
        categoryWeights = { mechanical = 30, tech = 25, transport = 20, energy = 15, daily = 10 },
    },
    ind_autoparts = {
        name = "汽配件批发仓",
        desc = "关停的汽配批发商留下的整仓库存，发动机总成、传动轴与各类车身配件堆满数排货架",
        icon = "image/icon_ind_autoparts.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 25, 28, 24, 15, 8 },
        categoryWeights = { transport = 45, mechanical = 30, energy = 10, tech = 8, daily = 7 },
        preferredTags = { automotive = 3.0 },
    },
    ind_building = {
        name = "建材经销商仓库",
        desc = "建材经销商破产留下的原材料库，钢筋、水泥辅料与五金件混放，偶有贵重工具夹杂其间",
        icon = "image/icon_ind_building.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 22, 26, 26, 16, 10 },
        categoryWeights = { mechanical = 45, energy = 22, transport = 15, tech = 10, daily = 8 },
    },
    ind_machinery = {
        name = "机械设备租赁停放仓",
        desc = "倒闭的机械租赁公司的存放仓，工业机器人手臂、精密加工设备与重型机械整齐停放，静候拍卖",
        icon = "image/icon_ind_machinery.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 18, 22, 28, 20, 12 },
        categoryWeights = { mechanical = 52, transport = 22, energy = 14, tech = 7, daily = 5 },
        preferredTags = { industrial_robot = 3.0, precision_optics = 1.5 },
    },
    ind_ewaste = {
        name = "废旧电子回收站",
        desc = "专业电子废品回收站的暂存仓，废旧主板、显示器与通讯设备叠放成山，残余价值等待发掘",
        icon = "image/icon_ind_ewaste.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 30, 28, 22, 13, 7 },
        categoryWeights = { tech = 40, energy = 28, mechanical = 20, daily = 7, art = 5 },
    },
    ind_appliance = {
        name = "家电维修备件库",
        desc = "大型家电维修中心的零部件仓，积压多年的空调压缩机、洗衣机电机与电视面板等待出清",
        icon = "image/icon_ind_appliance.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 28, 28, 22, 14, 8 },
        categoryWeights = { tech = 35, mechanical = 30, daily = 18, energy = 10, fashion = 7 },
    },
    ind_unclaimed = {
        name = "无主件暂存仓",
        desc = "物流园区多年积累的无主货物暂存库，来源五花八门，日用品、科技产品与古玩同处一室",
        icon = "image/icon_ind_unclaimed.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 32, 28, 20, 13, 7 },
        categoryWeights = { daily = 28, tech = 22, antique = 18, mechanical = 15, art = 10, fashion = 7 },
    },

    -- ── 区域3：商业综合体 ────────────────────────────────────────────────

    com_unknown = {
        name = "神秘仓库",
        desc = "商业综合体内一间封存的神秘库房，据说是某品牌撤场时仓促留下的存货，内容至今无人知晓",
        icon = "image/icon_unknown_warehouse.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 28, 26, 24, 14, 8 },
        categoryWeights = { daily = 30, fashion = 22, jewel = 20, art = 18, antique = 10 },
    },
    com_department = {
        name = "百货公司地下仓",
        desc = "停业百货公司的地下存货仓，滞销家电、节庆装饰品与各楼层散货在此混合堆放，待价而沽",
        icon = "image/icon_com_department.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 28, 26, 24, 14, 8 },
        categoryWeights = { daily = 50, fashion = 18, art = 12, jewel = 12, mechanical = 8 },
    },
    com_brandclear = {
        name = "品牌专卖店清仓库",
        desc = "多家品牌专卖店关店后集中存放的季末清仓货品，服装、箱包与配饰品牌混杂，成色不一",
        icon = "image/icon_com_brandclear.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 25, 27, 25, 15, 8 },
        categoryWeights = { fashion = 30, art = 25, jewel = 22, daily = 15, antique = 8 },
    },
    com_superstore = {
        name = "连锁超市配送中心",
        desc = "连锁超市关闭的区域配送中心，日用百货、食品包装物料与促销赠品堆满整仓，急需出清",
        icon = "image/icon_com_superstore.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 30, 28, 22, 13, 7 },
        categoryWeights = { daily = 65, transport = 12, mechanical = 10, fashion = 8, tech = 5 },
    },
    com_jewelry = {
        name = "珠宝展厅备货室",
        desc = "高档珠宝连锁店的区域备货室，黄金首饰、宝石裸石与艺术摆件静候下一次展览，机不可失",
        icon = "image/icon_com_jewelry.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 28, 26, 24, 14, 8 },
        categoryWeights = { jewel = 50, art = 28, antique = 12, fashion = 6, daily = 4 },
    },
    com_sports = {
        name = "运动品牌区域仓",
        desc = "运动品牌区域总仓，自行车、健身器材与户外装备按季节轮换，断码积压品常有意外惊喜",
        icon = "image/icon_com_sports.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 30, 28, 22, 13, 7 },
        categoryWeights = { daily = 45, transport = 22, mechanical = 18, fashion = 10, tech = 5 },
    },
    com_imports = {
        name = "进口食品代理商仓库",
        desc = "进口食品代理商的清仓库，洋酒、零食与特色食材堆叠其中，偶有限量版礼盒混入其中",
        icon = "image/icon_com_imports.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 32, 28, 20, 13, 7 },
        categoryWeights = { daily = 55, transport = 18, tech = 12, fashion = 10, antique = 5 },
    },
    com_furniture = {
        name = "家居品牌旗舰库房",
        desc = "高端家居品牌展厅撤场后的样品仓，实木家具、艺术灯具与软装陈设品尚有大量库存",
        icon = "image/icon_com_furniture.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 22, 26, 26, 17, 9 },
        categoryWeights = { daily = 42, mechanical = 28, art = 18, fashion = 7, antique = 5 },
    },
    com_cosmetics = {
        name = "美妆集合店配货仓",
        desc = "美妆集合店的区域配货仓，护肤品、香水与彩妆礼盒成箱存放，部分为限量版及联名款",
        icon = "image/icon_com_cosmetics.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 32, 28, 20, 13, 7 },
        categoryWeights = { daily = 55, fashion = 22, art = 15, jewel = 5, biotech = 3 },
    },

    -- ── 区域4：国际港口区 ────────────────────────────────────────────────

    port_unknown = {
        name = "神秘仓库",
        desc = "港口区某处封存的神秘货仓，货主不知所踪，舱单早已销毁，里面或藏宝物，或尽是废料",
        icon = "image/icon_unknown_warehouse.png", bg = "image/edited_bg_bondedport_night_20260323131115.png",
        sizeWeights = { 20, 23, 26, 18, 13 },
        categoryWeights = { antique = 22, jewel = 22, tech = 18, art = 20, transport = 10, fashion = 8 },
    },
    port_customs = {
        name = "海关扣押货物仓",
        desc = "海关依法扣押的走私嫌疑货物临时存放仓，古玩字画、名表珠宝与进口电子产品混杂其中",
        icon = "image/icon_port_customs.png", bg = "image/bg_warehouse_bondedport_20260323082731.png",
        sizeWeights = { 20, 23, 26, 18, 13 },
        categoryWeights = { antique = 22, jewel = 22, tech = 18, art = 15, transport = 13, fashion = 10 },
    },
    port_container = {
        name = "集装箱拆箱仓",
        desc = "国际航线集装箱拆箱后的散货暂存仓，机械零件、电子设备与工业原料一字排开，来源全球",
        icon = "image/icon_port_container.png", bg = "image/bg_warehouse_bondedport_20260323082731.png",
        sizeWeights = { 18, 22, 28, 20, 12 },
        categoryWeights = { mechanical = 30, tech = 22, transport = 22, daily = 15, energy = 11 },
    },
    port_unclaimed = {
        name = "无人认领快递仓",
        desc = "港口快递中转站积压的无主包裹仓，电子产品、艺术品与各类网购货物等待最后的认领期限",
        icon = "image/icon_port_unclaimed.png", bg = "image/bg_warehouse_bondedport_20260323082731.png",
        sizeWeights = { 25, 25, 24, 16, 10 },
        categoryWeights = { tech = 25, daily = 25, jewel = 18, art = 18, antique = 9, fashion = 5 },
    },
    port_bonded = {
        name = "保税区免税品仓",
        desc = "保税区内的免税品专属仓储，名酒、名表、珠宝与高档电子产品在此待关，等待正式报关入市",
        icon = "image/icon_port_bonded.png", bg = "image/bg_warehouse_bondedport_20260323082731.png",
        sizeWeights = { 22, 24, 25, 18, 11 },
        categoryWeights = { jewel = 30, art = 22, antique = 22, tech = 14, fashion = 12 },
    },
    port_coldchain = {
        name = "冷链国际货运中心",
        desc = "专业冷链物流仓储设施，低温储存的进口食品、药品与生物样本因物流中断滞留于此",
        icon = "image/icon_port_coldchain.png", bg = "image/bg_warehouse_bondedport_20260323082731.png",
        sizeWeights = { 18, 20, 28, 20, 14 },
        categoryWeights = { daily = 35, transport = 28, energy = 18, mechanical = 12, tech = 7 },
    },
    port_artship = {
        name = "艺术品国际转运库",
        desc = "专门承运艺术品的国际转运仓，油画、雕塑与古籍善本在专业包装箱中静待最终目的地",
        icon = "image/icon_port_artship.png", bg = "image/bg_warehouse_bondedport_20260323082731.png",
        sizeWeights = { 22, 23, 26, 18, 11 },
        categoryWeights = { art = 45, antique = 28, jewel = 15, fashion = 7, daily = 5 },
    },
    port_yacht = {
        name = "游艇码头附属仓库",
        desc = "豪华游艇俱乐部码头旁的附属仓库，船用导航仪、潜水设备与航海艺术品有序存放其中",
        icon = "image/icon_port_yacht.png", bg = "image/bg_warehouse_bondedport_20260323082731.png",
        sizeWeights = { 18, 20, 27, 22, 13 },
        categoryWeights = { transport = 30, mechanical = 22, tech = 18, art = 15, energy = 8, fashion = 7 },
        preferredTags = { maritime = 2.0 },
    },
    port_auction = {
        name = "港口拍卖行存货库",
        desc = "港口知名拍卖行的季前存货库，各地送拍的古董珍玩、珠宝字画汇聚一堂，藏品水准极高",
        icon = "image/icon_port_auction.png", bg = "image/bg_warehouse_bondedport_20260323082731.png",
        sizeWeights = { 20, 22, 26, 20, 12 },
        categoryWeights = { antique = 28, art = 22, jewel = 22, tech = 18, fashion = 10 },
    },

    -- ── 区域5：科技创新园 ────────────────────────────────────────────────

    tech_unknown = {
        name = "神秘仓库",
        desc = "科技园区一处无标识的密封仓库，可能是倒闭初创公司的设备遗留，也可能是某研究项目的存档",
        icon = "image/icon_unknown_warehouse.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 18, 20, 26, 23, 13 },
        categoryWeights = { tech = 40, energy = 22, mechanical = 18, biotech = 12, art = 8 },
    },
    tech_incubator = {
        name = "科技孵化器设备库",
        desc = "科技孵化器关闭园区的设备清算仓，服务器、3D打印机与各类创业公司遗留的研发设备集中于此",
        icon = "image/icon_tech_incubator.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 18, 20, 26, 22, 14 },
        categoryWeights = { tech = 45, energy = 22, mechanical = 18, biotech = 10, art = 5 },
    },
    tech_quantum = {
        name = "量子计算研究所存货间",
        desc = "量子计算实验室迁址后留下的仪器仓，精密光学元件、低温超导线圈与量子芯片样品封存待拍",
        icon = "image/icon_tech_quantum.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 15, 18, 27, 25, 15 },
        categoryWeights = { tech = 52, energy = 22, mechanical = 14, biotech = 8, art = 4 },
        preferredTags = { precision_optics = 3.0, semiconductor = 2.0 },
    },
    tech_semiconductor = {
        name = "半导体工厂余料仓",
        desc = "半导体生产线停产后遗留的余料仓，晶圆碎片、芯片模组与精密检测设备堆满整个货架",
        icon = "image/icon_tech_semiconductor.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 20, 22, 26, 20, 12 },
        categoryWeights = { tech = 55, energy = 18, mechanical = 14, transport = 8, daily = 5 },
        preferredTags = { semiconductor = 4.0, precision_optics = 2.0 },
    },
    tech_medical = {
        name = "医疗器械代理商仓库",
        desc = "医疗器械代理商清算留下的整仓库存，影像设备、手术器械与生化检测仪器静候重新上岗",
        icon = "image/icon_tech_medical.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 22, 23, 26, 18, 11 },
        categoryWeights = { tech = 35, mechanical = 28, energy = 20, biotech = 12, daily = 5 },
    },
    tech_newenergy = {
        name = "新能源车零件仓",
        desc = "新能源汽车配件供应商的库存清仓仓，电池模组、驱动电机与充电桩核心组件大量堆积",
        icon = "image/icon_tech_newenergy.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 18, 20, 26, 23, 13 },
        categoryWeights = { transport = 35, energy = 30, tech = 22, mechanical = 8, daily = 5 },
    },
    tech_aerospace = {
        name = "航空航天配件储存库",
        desc = "航空航天配件供应商的封存库，钛合金结构件、航空精密传感器与导航系统备件静待处置",
        icon = "image/icon_tech_aerospace.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 16, 18, 27, 25, 14 },
        categoryWeights = { tech = 35, mechanical = 30, transport = 22, energy = 8, art = 5 },
        preferredTags = { aerospace = 3.5, precision_optics = 1.5 },
    },
    tech_datacenter = {
        name = "数据中心淘汰设备间",
        desc = "大型数据中心设备更换后的淘汰设备仓，服务器机架、网络交换机与存储阵列整列封存",
        icon = "image/icon_tech_datacenter.png", bg = "image/bg_warehouse_datacenter_20260322132508.png",
        sizeWeights = { 18, 20, 26, 23, 13 },
        categoryWeights = { tech = 60, energy = 18, mechanical = 12, transport = 6, daily = 4 },
        preferredTags = { server_hw = 4.0, semiconductor = 2.0 },
    },
    tech_university = {
        name = "高校实验室拍卖仓",
        desc = "高校科研院所设备更新后的器材拍卖仓，电子仪器、生物实验设备与光学平台集中变现",
        icon = "image/icon_tech_university.png", bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 20, 22, 26, 20, 12 },
        categoryWeights = { tech = 38, energy = 22, mechanical = 18, art = 12, biotech = 10 },
    },

    -- ── 区域6：文化艺术区 ────────────────────────────────────────────────

    cult_unknown = {
        name = "神秘仓库",
        desc = "文化艺术区深处的一间神秘库房，外人从未得见其内，传言收有某位离世藏家的毕生珍藏",
        icon = "image/icon_unknown_warehouse.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 15, 18, 25, 26, 16 },
        categoryWeights = { art = 32, antique = 30, jewel = 22, fashion = 10, daily = 6 },
    },
    cult_museum = {
        name = "私人博物馆藏品库",
        desc = "解散的私人博物馆藏品清仓库，历代字画、青铜器与东西方古典艺术品同处一室，品质上乘",
        icon = "image/icon_cult_museum.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 15, 18, 25, 26, 16 },
        categoryWeights = { art = 38, antique = 35, jewel = 15, fashion = 7, daily = 5 },
    },
    cult_auction = {
        name = "拍卖行季末清仓",
        desc = "知名拍卖行年末库存清仓，流拍品与瑕疵品被集中处理，名家佳作混迹其中，考验眼力",
        icon = "image/icon_cult_auction.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 16, 19, 25, 25, 15 },
        categoryWeights = { antique = 30, art = 28, jewel = 22, tech = 10, fashion = 10 },
    },
    cult_antique = {
        name = "古玩商协会联合仓",
        desc = "古玩商行协会会员联合存放的货物仓，陶瓷古玩、玉器文房与钱币邮票分区陈列，来源有据",
        icon = "image/icon_cult_antique.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 14, 18, 25, 27, 16 },
        categoryWeights = { antique = 55, art = 22, jewel = 12, daily = 7, fashion = 4 },
    },
    cult_luxury = {
        name = "奢侈品修复中心存货室",
        desc = "顶级奢侈品修复中心的寄存库，送修待取的名包名表与艺术品因原主失联而转入拍卖程序",
        icon = "image/icon_cult_luxury.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 16, 19, 25, 25, 15 },
        categoryWeights = { art = 30, jewel = 30, antique = 25, fashion = 12, daily = 3 },
    },
    cult_gallery = {
        name = "画廊地下储藏室",
        desc = "著名画廊关闭后的地下储藏室，数十幅原作与艺术版画在恒温环境中保存完好，待价而沽",
        icon = "image/icon_cult_gallery.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 15, 18, 25, 26, 16 },
        categoryWeights = { art = 58, antique = 18, jewel = 12, fashion = 7, daily = 5 },
    },
    cult_jewelry = {
        name = "高端珠宝商联合金库",
        desc = "多家高端珠宝商联合使用的安保金库，钻石裸石、铂金首饰与彩色宝石成品大量封存",
        icon = "image/icon_cult_jewelry.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 18, 20, 25, 24, 13 },
        categoryWeights = { jewel = 55, art = 22, antique = 12, fashion = 8, daily = 3 },
    },
    cult_watch = {
        name = "名表收藏家存储室",
        desc = "资深名表收藏家去世后留下的专属存储室，百达翡丽、劳力士等顶级腕表静待新的主人",
        icon = "image/icon_cult_watch.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 20, 22, 25, 22, 11 },
        categoryWeights = { jewel = 40, art = 28, antique = 22, tech = 6, fashion = 4 },
        preferredTags = { horology = 4.0 },
    },
    cult_wine = {
        name = "顶级红酒窖藏仓",
        desc = "葡萄酒庄园主人遗产中的私家酒窖，数百支年份波尔多与勃艮第佳酿在此沉睡，岁月已给出答案",
        icon = "image/icon_cult_wine.png", bg = "image/bg_oldtown_20260321192643.png",
        sizeWeights = { 22, 23, 25, 20, 10 },
        categoryWeights = { antique = 40, art = 28, daily = 17, jewel = 10, fashion = 5 },
    },

    -- ── 区域7：深海打捞站 ────────────────────────────────────────────────

    sea_unknown = {
        name = "神秘仓库",
        desc = "打捞站码头旁一间来历不明的封存仓库，据说装的是某次秘密深海作业的收获，从未公开过",
        icon = "image/icon_unknown_warehouse.png", bg = "image/bg_warehouse_shipwreck_20260328204443.png",
        sizeWeights = { 15, 18, 26, 26, 15 },
        categoryWeights = { antique = 30, art = 25, tech = 18, mechanical = 15, jewel = 12 },
    },
    sea_archaeology = {
        name = "深海考古打捞物资库",
        desc = "水下考古队多年打捞成果的存放库，沉船遗物、海底文物与陶瓷碎片按年代编号存放",
        icon = "image/icon_sea_archaeology.png", bg = "image/bg_warehouse_shipwreck_20260328204443.png",
        sizeWeights = { 15, 18, 25, 26, 16 },
        categoryWeights = { antique = 38, art = 28, tech = 15, mechanical = 12, jewel = 7 },
        preferredTags = { maritime = 2.5 },
    },
    sea_wreck = {
        name = "海底沉船文物存放处",
        desc = "深海沉船打捞队的文物存放仓，锈迹斑斑的船锚、铜炮与船货在防腐处理后等待研究和拍卖",
        icon = "image/icon_sea_wreck.png", bg = "image/bg_warehouse_shipwreck_20260328204443.png",
        sizeWeights = { 14, 17, 25, 27, 17 },
        categoryWeights = { antique = 48, art = 28, jewel = 12, mechanical = 8, daily = 4 },
        preferredTags = { maritime = 3.0 },
    },
    sea_expedition = {
        name = "远洋探险队装备仓",
        desc = "解散远洋探险队留下的全套装备仓，深潜头盔、水下摄影设备与船只零件整装待售",
        icon = "image/icon_sea_expedition.png", bg = "image/bg_warehouse_shipwreck_20260328204443.png",
        sizeWeights = { 16, 19, 26, 25, 14 },
        categoryWeights = { mechanical = 30, tech = 25, transport = 20, energy = 15, daily = 10 },
    },
    sea_research = {
        name = "水下科考站备用库",
        desc = "水下科考站关闭后的备用物资仓，声学探测仪、水下机器人配件与科研采样设备有序存放",
        icon = "image/icon_sea_research.png", bg = "image/bg_warehouse_shipwreck_20260328204443.png",
        sizeWeights = { 18, 20, 26, 23, 13 },
        categoryWeights = { tech = 35, energy = 28, mechanical = 22, biotech = 10, daily = 5 },
    },
    sea_biology = {
        name = "海洋生物样本冷库",
        desc = "海洋研究机构关闭的冷库，珍稀海洋生物标本、深海鱼类样品与生物提取物分类封存其中",
        icon = "image/icon_sea_biology.png", bg = "image/bg_warehouse_shipwreck_20260328204443.png",
        sizeWeights = { 20, 22, 26, 20, 12 },
        categoryWeights = { tech = 38, energy = 28, mechanical = 20, biotech = 10, daily = 4 },
    },
    sea_maintenance = {
        name = "深潜设备维修站仓",
        desc = "深潜设备维修站的备件仓，潜水艇密封件、水下焊接设备与高压气罐整齐码放待用",
        icon = "image/icon_sea_maintenance.png", bg = "image/bg_warehouse_shipwreck_20260328204443.png",
        sizeWeights = { 16, 18, 26, 25, 15 },
        categoryWeights = { mechanical = 40, tech = 28, energy = 22, transport = 7, daily = 3 },
    },
    sea_minerals = {
        name = "海底矿产样本库",
        desc = "深海矿产勘探项目终止后的样本库，锰结核、热液矿化物与海底岩芯样品等待学术或商业处置",
        icon = "image/icon_sea_minerals.png", bg = "image/bg_warehouse_shipwreck_20260328204443.png",
        sizeWeights = { 18, 20, 26, 23, 13 },
        categoryWeights = { antique = 30, tech = 25, energy = 22, mechanical = 15, art = 8 },
    },
    sea_harbor = {
        name = "港湾打捞临时堆场",
        desc = "港湾打捞作业的临时堆场，随机打捞上来的锚链、船用机械与偶然出水的古物杂乱堆放",
        icon = "image/icon_sea_harbor.png", bg = "image/bg_warehouse_shipwreck_20260328204443.png",
        sizeWeights = { 20, 22, 26, 20, 12 },
        categoryWeights = { antique = 25, mechanical = 28, transport = 22, daily = 15, tech = 10 },
        preferredTags = { maritime = 2.5 },
    },
}

return M
