-- ============================================================================
-- UI/RewardItemAdapter.lua - 奖励对象 → ItemDetailPanel 展示数据 统一适配器
--
-- 用法：
--   local RewardItemAdapter = require("UI.RewardItemAdapter")
--   local item = RewardItemAdapter.ToItem(reward)          -- 标准转换
--   local item = RewardItemAdapter.ToItem(reward, {        -- 覆盖特定字段
--       subtitle = "当前持有 ×3",
--   })
--
-- reward 格式：
--   { type="coins",   amount=1000 }
--   { type="chest",   id="chest_gold" }
--   { type="item",    itemId="xxx" }          -- 赛季藏品
--   { type="tickets", ticketId="xxx", count=1 }
-- ============================================================================

---@diagnostic disable: undefined-global

local GlobalConfig      = require("Config")
local Chests            = require("Config.Chests")
local Utils             = require("UI.Utils")
local SeasonPassConfig  = require("Config.SeasonPass")

local RewardItemAdapter = {}

-- chest tier → rarity 映射
local TIER_RARITY = {
    white  = "common",
    green  = "uncommon",
    blue   = "rare",
    purple = "epic",
    gold   = "legendary",
}

-- ============================================================================
-- 查找 ticket 对应的区域名
-- ============================================================================
local function GetRegionNameForTicket(ticketId)
    for _, region in ipairs(GlobalConfig.REGIONS or {}) do
        if region.ticket == ticketId then
            return region.name
        end
    end
    return "—"
end

-- ============================================================================
-- ToItem(reward [, opts]) → item 对象（供 ItemDetailPanel.Show 使用）
--
-- opts 可选字段：
--   subtitle  string  覆盖 item.subtitle（用于显示当前持有数量等）
-- ============================================================================
function RewardItemAdapter.ToItem(reward, opts)
    opts = opts or {}
    local item

    if reward.type == "coins" then
        local n = reward.amount or 0
        local display = n >= 10000 and string.format("%.0f万", n / 10000) or tostring(n)
        item = {
            name     = "金币",
            subtitle = display .. " 枚金币",
            image    = Utils.GetIcon("coin"),
            rarity   = "common",
            desc     = "奖励金币",
            w = 1, h = 1,
        }

    elseif reward.type == "chest" then
        local def = Chests.BY_ID[reward.id]
        item = {
            name     = (def and def.name) or "礼盒",
            rarity   = (def and TIER_RARITY[def.tier]) or "legendary",
            image    = (def and def.iconImage) or Utils.GetIcon("chest"),
            desc     = (def and def.desc) or "随机开出十种品类藏品之一，有极低概率获得赛季稀有藏品",
            category = "chest",
            w = 1, h = 1,
        }

    elseif reward.type == "item" then
        local cfg = SeasonPassConfig
        for _, si in ipairs(cfg.SEASON_ITEMS or {}) do
            if si.id == reward.itemId then
                item = {
                    name      = si.name,
                    rarity    = si.rarity or "rare",
                    image     = si.icon,
                    realValue = si.value,
                    desc      = si.desc or "赛季限定藏品",
                    w = 1, h = 1,
                }
                break
            end
        end

    elseif reward.type == "tickets" then
        local tc = GlobalConfig.TICKETS[reward.ticketId]
        local regionName = GetRegionNameForTicket(reward.ticketId)
        item = {
            name         = (tc and tc.name) or "仓库指定券",
            subtitle     = "×" .. (reward.count or 1),
            image        = (tc and tc.icon) or Utils.GetIcon("gift"),
            rarity       = "blue",
            priceBarText = "仓库指定券",
            desc         = "解锁区域：" .. regionName .. "\n\n持有此券可指定进入该区域竞拍仓库，无需满足资产门槛，不消耗普通拍卖次数。",
            w = 3, h = 2,
        }
    end

    -- 兜底：未知类型
    if not item then
        item = {
            name  = "奖励",
            rarity = "common",
            image = Utils.GetIcon("gift"),
            desc  = "奖励",
            w = 1, h = 1,
        }
    end

    -- 应用覆盖字段
    if opts.subtitle ~= nil then
        item.subtitle = opts.subtitle
    end

    return item
end

-- ============================================================================
-- TicketItem(ticketId, heldCount) → item 对象
-- 便捷方法：TicketTooltip 等只有 ticketId（而非完整 reward）的场景
-- ============================================================================
function RewardItemAdapter.TicketItem(ticketId, heldCount)
    local subtitle = (heldCount and heldCount > 0) and ("×" .. heldCount) or ""
    return RewardItemAdapter.ToItem(
        { type = "tickets", ticketId = ticketId, count = 1 },
        { subtitle = subtitle }
    )
end

return RewardItemAdapter
