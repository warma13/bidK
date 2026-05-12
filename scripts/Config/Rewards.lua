-- ============================================================================
-- Config/Rewards.lua - 广告卡与在线时长奖励配置
-- ============================================================================

local M = {}

-- ============================================================================
-- 广告卡系统
-- ============================================================================

M.AD_CARD = {
    MAX_DAILY_ADS = 30,  -- 每日最多看30次广告

    -- 卡等级（累计卡点升级，每看满当日上限获得1卡点）
    CARD_TIERS = {
        { name = "普通卡", pointsNeeded = 0,   coinsPerAd = 500000,  color = { 180, 180, 180, 255 } },
        { name = "铜卡",   pointsNeeded = 3,   coinsPerAd = 600000,  color = { 200, 140, 80,  255 } },
        { name = "银卡",   pointsNeeded = 10,  coinsPerAd = 800000,  color = { 180, 200, 220, 255 } },
        { name = "金卡",   pointsNeeded = 30,  coinsPerAd = 1000000, color = { 255, 200, 50,  255 } },
        { name = "钻石卡", pointsNeeded = 60,  coinsPerAd = 1500000, color = { 100, 200, 255, 255 } },
        { name = "至尊卡", pointsNeeded = 200, coinsPerAd = 2000000, color = { 255, 100, 100, 255 } },
    },

    -- 每日里程碑奖励（当日看广告达到指定次数可领取）
    DAILY_MILESTONES = {
        { adsRequired = 5,  coins = 1500000, label = "看5次",  ticket = "port_1000w" },
        { adsRequired = 10, coins = 2000000, label = "看10次", ticket = "port_1000w" },
        { adsRequired = 15, coins = 2500000, label = "看15次", ticket = "port_5000w" },
        { adsRequired = 20, coins = 3000000, label = "看20次", ticket = "port_5000w" },
        { adsRequired = 25, coins = 4000000, label = "看25次", ticket = "port_5000w" },
        { adsRequired = 30, coins = 5000000, label = "看30次", ticket = "port_5000w" },
    },
}

-- ============================================================================
-- 在线时长奖励
-- ============================================================================

M.ONLINE_REWARD = {
    MILESTONES = {
        { minutes = 1,   coins = 100000,  label = "1分钟"  },
        { minutes = 3,   coins = 200000,  label = "3分钟"  },
        { minutes = 10,  coins = 300000,  label = "10分钟" },
        { minutes = 30,  coins = 500000,  label = "30分钟", ticket = "port_1000w" },
        { minutes = 60,  coins = 1000000, label = "1小时",  ticket = "port_1000w" },
        { minutes = 120, coins = 3000000, label = "2小时",  ticket = "port_5000w" },
        { minutes = 180, coins = 5000000, label = "3小时",  ticket = "port_5000w" },
    },
}

return M
