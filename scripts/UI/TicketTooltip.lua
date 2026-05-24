-- ============================================================================
-- UI/TicketTooltip.lua - 通用奖励浮窗（鼠标位置定位）
--
-- 用法：
--   RewardScreen 中 children 最后加 TicketTooltip.CreateOverlay()
--   格子 onClick = function() TicketTooltip.ShowReward(reward) end
--   门票 onClick = function() TicketTooltip.Show(ticketId) end    -- 兼容旧接口
-- ============================================================================

local UI                = require("urhox-libs/UI")
local ItemDetailPanel   = require("UI.ItemDetailPanel")
local RewardItemAdapter = require("UI.RewardItemAdapter")
local SaveSystem        = require("SaveSystem")

local TicketTooltip = {}

---@type table ItemDetailPanel 实例
local detail    = nil
---@type table 全屏透明遮罩（点击外部关闭）
local backdrop  = nil
---@type table 顶层容器
local container = nil
---@type table 根节点引用（用于坐标转换）
local rootRef   = nil

local DETAIL_W = 200
local DETAIL_H = 260

-- ============================================================================
-- 创建 overlay（在宿主 Screen 中调用一次，返回 UI 节点插入 children）
-- ============================================================================

function TicketTooltip.CreateOverlay()
    detail = ItemDetailPanel.New({
        position = "absolute",
        left = 0, top = 0,
        width = DETAIL_W,
        onHide = function()
            if container then container:SetVisible(false) end
        end,
    })

    backdrop = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        onClick = function()
            TicketTooltip.Hide()
        end,
    }

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
-- 设置根引用（由宿主 Screen 在创建后调用，用于坐标转换）
-- ============================================================================

function TicketTooltip.SetRoot(root)
    rootRef = root
end

-- ============================================================================
-- 内部：根据鼠标位置定位浮窗
-- ============================================================================

local function PositionAtMouse()
    if not detail or not container then return end

    local rootLayout = rootRef and rootRef:GetAbsoluteLayout() or nil
    if not rootLayout then return end

    local rootX, rootY = rootLayout.x, rootLayout.y
    local rootW, rootH = rootLayout.w, rootLayout.h

    local mousePos = input.mousePosition
    local cx    = mousePos.x - rootX
    local clickY = mousePos.y - rootY

    -- 水平：居中于点击位置，不超出边界
    local px = cx - DETAIL_W / 2
    if px < 4 then px = 4 end
    if px + DETAIL_W > rootW - 4 then px = rootW - DETAIL_W - 4 end

    -- 垂直：优先显示在点击位置上方
    local py = clickY - DETAIL_H - 6
    if py < 4 then
        py = clickY + 16
    end

    detail:SetStyle({ left = px, top = py, right = nil, bottom = nil })
end

-- ============================================================================
-- 显示 / 隐藏
-- ============================================================================

--- 显示任意奖励类型的浮窗（通用接口）
function TicketTooltip.ShowReward(reward)
    if not detail or not container then return end
    if detail:IsVisible() then detail:Hide() end
    container:SetVisible(true)
    detail:Show(RewardItemAdapter.ToItem(reward))
    PositionAtMouse()
end

--- 显示已格式化的 item 对象（不经过 RewardItemAdapter）
function TicketTooltip.ShowItem(item)
    if not detail or not container then return end
    if detail:IsVisible() then detail:Hide() end
    container:SetVisible(true)
    detail:Show(item)
    PositionAtMouse()
end

--- 兼容旧接口：显示门票详情
function TicketTooltip.Show(ticketId)
    if not detail or not container then return end
    if detail:IsVisible() then detail:Hide() end
    container:SetVisible(true)
    local held = SaveSystem.GetTicketCount(ticketId)
    detail:Show(RewardItemAdapter.TicketItem(ticketId, held))
    PositionAtMouse()
end

function TicketTooltip.Hide()
    if detail then detail:Hide() end
    -- onHide 回调会关闭 container
end

function TicketTooltip.IsVisible()
    return detail ~= nil and detail:IsVisible()
end

return TicketTooltip
