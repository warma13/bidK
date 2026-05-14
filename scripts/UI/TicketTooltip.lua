-- ============================================================================
-- UI/TicketTooltip.lua - 仓库指定券说明浮窗（复用 ItemDetailPanel）
--
-- 用法：
--   MenuScreen 中 children 最后加 TicketTooltip.CreateOverlay()
--   门票图标 onClick = function() TicketTooltip.Show(ticketId) end
-- ============================================================================

local UI              = require("urhox-libs/UI")
local ItemDetailPanel = require("UI.ItemDetailPanel")
local Config          = require("Config")
local Utils           = require("UI.Utils")

local TicketTooltip = {}

---@type table ItemDetailPanel 实例
local detail   = nil
---@type table 全屏透明遮罩（点击外部关闭）
local backdrop = nil
---@type table 顶层容器
local container = nil

-- ============================================================================
-- 查找 ticket 对应区域名
-- ============================================================================

local function GetRegionForTicket(ticketId)
    for _, region in ipairs(Config.REGIONS) do
        if region.ticket == ticketId then
            return region.name
        end
    end
    return nil
end

-- ============================================================================
-- 创建 overlay（在 MenuScreen 中调用一次，返回 UI 节点插入 children）
-- ============================================================================

function TicketTooltip.CreateOverlay()
    -- ItemDetailPanel 贴右侧，垂直居中偏上（靠近里程碑列表区域）
    detail = ItemDetailPanel.New({
        right  = "3%",
        top    = "22%",
        width  = 200,
        onHide = function()
            if container then container:SetVisible(false) end
        end,
    })

    -- 全屏透明遮罩：点击外部区域关闭浮窗
    backdrop = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        onClick = function()
            TicketTooltip.Hide()
        end,
    }

    -- 顶层容器：backdrop + ItemDetailPanel 叠在一起
    container = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        visible = false,
        children = {
            backdrop,
            detail:GetWidget(),
        },
    }

    return container
end

-- ============================================================================
-- 显示 / 隐藏
-- ============================================================================

function TicketTooltip.Show(ticketId)
    if not detail or not container then return end
    local tConf = Config.TICKETS[ticketId]
    if not tConf then return end

    local regionName = GetRegionForTicket(ticketId) or "—"

    -- 先显示容器，再 Show 内容（确保可见后渲染）
    container:SetVisible(true)

    detail:Show({
        name     = tConf.name or ticketId,
        rarity   = "blue",
        subtitle = "仓库指定券",
        image    = tConf.icon or "",
        desc     = "解锁区域：" .. regionName .. "\n\n持有此券可指定进入该区域竞拍仓库，无需满足资产门槛，不消耗普通拍卖次数。",
        w        = 3,
        h        = 2,
    })
end

function TicketTooltip.Hide()
    if detail then detail:Hide() end
    -- onHide 回调会关闭 container
end

return TicketTooltip
