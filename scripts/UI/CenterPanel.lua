-- ============================================================================
-- UI/CenterPanel.lua - 中央竞拍信息面板
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local InfoFeed = require("UI.InfoFeed")

local CenterPanel = {}

local refs = UIState.refs
local C = Config.COLORS

local GS = GameState

-- ============================================================================
-- 信息弹出动画状态
-- ============================================================================

local animPhase = "none"   -- "none" | "measure" | "scale_up" | "hold" | "move"
local animTime = 0
local animData = nil       -- 当前动画的 { info, isSkill }
local animStartX, animStartY = 0, 0
local animTargetX, animTargetY = 0, 0
local animCardW = 350
local animCardH = 80

local SCALE_UP_DUR = 0.3
local HOLD_DUR = 0.6
local MOVE_DUR = 0.3

-- ============================================================================
-- 创建
-- ============================================================================

function CenterPanel.Create()
    refs.roundLabel = UI.Label {
        text = "", fontSize = 15, fontColor = C.textPrimary, textAlign = "center",
        fontWeight = "bold",
    }
    refs.roundTimerLabel = UI.Label {
        text = "", fontSize = 16, fontColor = C.accent, fontWeight = "bold",
    }
    -- multiplierLabel 已移至出价面板显示

    -- 信息流容器
    refs.infoFeedPanel = UI.Panel {
        id = "infoFeedPanel",
        width = "100%",
        flexDirection = "column", gap = 6,
    }

    -- 信息流滚动视图
    refs.infoFeedScroll = UI.ScrollView {
        id = "infoFeedScroll",
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        scrollY = true,
        children = { refs.infoFeedPanel },
    }

    -- 弹出动画层（不属于 centerPanel，由 GameController 添加到根层级）
    refs.infoPopupWrapper = UI.Panel {
        position = "absolute",
        overflow = "hidden",
        borderRadius = 0,
        visible = false,
    }
    refs.infoPopupOverlay = UI.Panel {
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
        visible = false,
        children = { refs.infoPopupWrapper },
    }

    return UI.Panel {
        id = "centerPanel",
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "column",
        overflow = "hidden",
        children = {
            -- 回合标题栏
            UI.Panel {
                width = "100%",
                backgroundColor = C.roundBanner,
                padding = { 6, 12 },
                alignItems = "center",
                flexDirection = "column", gap = 2,
                flexShrink = 0,
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 10,
                        children = { refs.roundLabel, refs.roundTimerLabel }
                    },
                }
            },
            -- 外层容器面板
            UI.Panel {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                flexShrink = 1,
                backgroundColor = { 20, 28, 50, 160 },
                borderRadius = 0,
                padding = 10,
                flexDirection = "column",
                overflow = "hidden",
                justifyContent = "flex-start",
                alignItems = "stretch",
                children = {
                    refs.infoFeedScroll,
                }
            },
        }
    }
end

-- 信息卡片和信息流由 InfoFeed 模块统一管理

-- ============================================================================
-- 更新
-- ============================================================================

function CenterPanel.Update()
    local phase = GS.GetPhase()
    local round = GS.GetCurrentRound()

    -- 回合标题
    if round > 0 then
        refs.roundLabel:SetText("第 " .. round .. " 轮")
    else
        refs.roundLabel:SetText(Config.GAME.Title)
    end

    -- 更新信息流
    InfoFeed.Rebuild()
end

-- ============================================================================
-- 弹出动画
-- ============================================================================

function CenterPanel.GetPopupOverlay()
    return refs.infoPopupOverlay
end

function CenterPanel.IsAnimating()
    return animPhase ~= "none" or #UIState.infoAnimQueue > 0
end

function CenterPanel.ResetAnimation()
    animPhase = "none"
    animTime = 0
    animData = nil
    UIState.infoAnimQueue = {}
    InfoFeed.Reset()
    if refs.infoPopupWrapper then refs.infoPopupWrapper:SetVisible(false) end
    if refs.infoPopupOverlay then refs.infoPopupOverlay:SetVisible(false) end
end

function CenterPanel.UpdateAnimation(dt)
    -- 无动画运行时，检查队列
    if animPhase == "none" then
        if #UIState.infoAnimQueue == 0 then return end

        -- 取出下一条信息，进入 measure 阶段
        animData = table.remove(UIState.infoAnimQueue, 1)
        animPhase = "measure"
        animTime = 0

        -- 计算最终宽度
        local screenW = UI.GetWidth()
        animCardW = math.floor(screenW * 0.36)

        -- 创建信息卡片放入弹出容器
        local card = InfoFeed.CreateInfoCard(animData.info, animData.isSkill)
        refs.infoPopupWrapper:ClearChildren()
        refs.infoPopupWrapper:AddChild(card)

        -- 以最终宽度放到屏幕外，等一帧让布局计算自然高度
        refs.infoPopupWrapper:SetStyle({
            left = -9999,
            top = -9999,
            width = animCardW,
            scale = 1.0,
        })
        refs.infoPopupWrapper:SetVisible(true)
        refs.infoPopupOverlay:SetVisible(true)
        return
    end

    animTime = animTime + dt
    local screenW = UI.GetWidth()
    local screenH = UI.GetHeight()

    if animPhase == "measure" then
        -- 一帧后读取实际布局尺寸
        local layout = refs.infoPopupWrapper:GetAbsoluteLayout()
        animCardW = layout.w
        animCardH = layout.h
        if animCardH < 10 then animCardH = 80 end

        -- 开始 scale_up：卡片保持自然尺寸，用 scale 属性做视觉缩放
        animPhase = "scale_up"
        animTime = 0
        refs.infoPopupWrapper:SetStyle({
            left = (screenW - animCardW) / 2,
            top = (screenH - animCardH) / 2,
            scale = 0.5,
        })

    elseif animPhase == "scale_up" then
        local t = math.min(animTime / SCALE_UP_DUR, 1.0)
        local eased = 1 - (1 - t) * (1 - t)  -- ease-out
        local s = 0.5 + 0.5 * eased
        refs.infoPopupWrapper:SetStyle({
            left = (screenW - animCardW) / 2,
            top = (screenH - animCardH) / 2,
            scale = s,
        })
        if t >= 1.0 then
            animPhase = "hold"
            animTime = 0
        end

    elseif animPhase == "hold" then
        if animTime >= HOLD_DUR then
            animPhase = "move"
            animTime = 0
            animStartX = (screenW - animCardW) / 2
            animStartY = (screenH - animCardH) / 2
            -- 目标位置：信息流内容底部（新卡片实际出现的位置）
            local scrollLayout = refs.infoFeedScroll:GetAbsoluteLayout()
            local feedLayout = refs.infoFeedPanel:GetAbsoluteLayout()
            animTargetX = scrollLayout.x
            -- 新卡片会加在 feedPanel 底部
            animTargetY = feedLayout.y + feedLayout.h
            -- 限制在滚动区域可见范围内
            local scrollBottom = scrollLayout.y + scrollLayout.h - animCardH
            if animTargetY > scrollBottom then
                animTargetY = scrollBottom
            end
        end

    elseif animPhase == "move" then
        local t = math.min(animTime / MOVE_DUR, 1.0)
        local eased = t * t
        local curX = animStartX + (animTargetX - animStartX) * eased
        local curY = animStartY + (animTargetY - animStartY) * eased
        local s = 1.0 - 0.15 * eased
        refs.infoPopupWrapper:SetStyle({
            left = curX,
            top = curY,
            scale = s,
        })

        if t >= 1.0 then
            -- 动画完成：隐藏弹出层
            refs.infoPopupWrapper:SetVisible(false)
            refs.infoPopupOverlay:SetVisible(false)

            -- 将信息追加到统一信息流
            InfoFeed.Append(animData.info, animData.isSkill)
            InfoFeed.Rebuild()

            animPhase = "none"
            animData = nil
        end
    end
end

return CenterPanel
