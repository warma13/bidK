-- ============================================================================
-- Config/World.lua - 世界地图、区域与仓库类型定义
-- ============================================================================

local M = {}

-- 世界大地图背景
M.WORLD_MAP_BG = "image/world_map_20260323084303.png"

-- 默认 BGM（菜单、地图、仓库等通用界面）
M.DEFAULT_BGM = "audio/bgm_grocery.ogg"

-- ============================================================================
-- 区域定义
-- ============================================================================

M.REGIONS = {
    {
        id = "oldtown", name = "旧城商业区",
        icon = "region_oldtown_20260319111022.png",
        bg = "image/bg_oldtown_20260321192643.png",
        bgm = "audio/bgm_oldtown.ogg",
        desc = "老街深巷里的杂货铺仓库，破烂里藏着宝贝",
        mapX = 0.22, mapY = 0.65,
        warehouseTypes = { "grocery" },
        difficulties = {
            {
                level = "easy", label = "简单",
                entryFee = 0,
                startingMoney = 800000,
                expectedValue = 30000,
                assetRequirement = 0,
            },
            {
                level = "normal", label = "普通",
                entryFee = 5000,
                startingMoney = 800000,
                expectedValue = 100000,
                assetRequirement = 100000,
            },
        },
    },
    {
        id = "techpark", name = "科技产业园",
        icon = "image/warehouse_techpark_20260321194424.png",
        bg = "image/bg_techpark_20260321192636.png",
        bgm = "audio/bgm_techpark.ogg",
        desc = "倒闭的AI独角兽公司仓库，满是前沿设备和实验室遗物",
        mapX = 0.65, mapY = 0.35,
        warehouseTypes = { "techpark", "datacenter", "quantumlab" },
        difficulties = {
            {
                level = "hard", label = "50万场",
                entryFee = 25000,
                startingMoney = 3000000,
                expectedValue = 500000,
                assetRequirement = 500000,
            },
            {
                level = "nightmare", label = "200万场",
                entryFee = 40000,
                startingMoney = 10000000,
                expectedValue = 2000000,
                assetRequirement = 2000000,
            },
        },
    },
    {
        id = "bondedport", name = "港口保税区",
        icon = "image/warehouse_bondedport_20260323083437.png",
        bg = "image/edited_bg_bondedport_night_20260323131115.png",
        bgm = "audio/bgm_bondedport.ogg",
        desc = "繁忙国际港口的海关保税仓库区，无人认领的集装箱等你开箱",
        mapX = 0.72, mapY = 0.75,
        warehouseTypes = { "bondedport", "shipwreck" },
        difficulties = {
            {
                level = "expert", label = "1000万场",
                entryFee = 80000,
                startingMoney = 10000000,
                expectedValue = 10000000,
                assetRequirement = 10000000,
                requiredTicket = "port_1000w",
                ticketLabel = "1000万场门票",
            },
            {
                level = "legend", label = "5000万场",
                entryFee = 200000,
                startingMoney = 50000000,
                expectedValue = 50000000,
                assetRequirement = 50000000,
                requiredTicket = "port_5000w",
                ticketLabel = "5000万场门票",
            },
        },
    },
}

-- ============================================================================
-- 仓库类型定义
-- sizeWeights: { 1格, 2格, 4格, 6格, 9格+ }
-- ============================================================================

M.WAREHOUSE_TYPES = {
    grocery = {
        name = "街边杂货铺",
        icon = "warehouse_grocery_20260319111022.png",
        bg = "image/bg_warehouse_grocery_20260322132513.png",
        sizeWeights = { 35, 30, 20, 10, 5 },
    },
    techpark = {
        name = "AI独角兽总部",
        icon = "image/warehouse_techpark_20260321194424.png",
        bg = "image/bg_warehouse_techpark_20260322132509.png",
        sizeWeights = { 25, 25, 25, 15, 10 },
    },
    datacenter = {
        name = "黑夜之城",
        icon = "image/warehouse_datacenter_20260322110414.png",
        bg = "image/bg_warehouse_datacenter_20260322132508.png",
        sizeWeights = { 20, 25, 25, 18, 12 },
    },
    bondedport = {
        name = "海关保税仓",
        icon = "image/warehouse_bondedport_20260323083437.png",
        bg = "image/bg_warehouse_bondedport_20260323082731.png",
        sizeWeights = { 20, 22, 25, 18, 15 },
    },
    shipwreck = {
        name = "远洋货轮残骸",
        icon = "image/warehouse_shipwreck_20260328210723.png",
        bg = "image/bg_warehouse_shipwreck_20260328204443.png",
        sizeWeights = { 18, 20, 25, 20, 17 },
    },
    quantumlab = {
        name = "量子实验室",
        icon = "image/warehouse_quantumlab_20260512102209.png",
        bg = "image/warehouse_quantumlab_20260512102209.png",
        sizeWeights = { 22, 24, 25, 17, 12 },
    },
}

return M
