-- ============================================================================
-- UI/GameController.lua - 屏幕导航控制器
--
-- 职责：仅负责屏幕间导航（ShowMenu / ShowMap / ShowLobby / ShowWarehouse）
-- 对局生命周期已搬到 GameSession.lua
-- ============================================================================

local Config = require("Config")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local MenuScreen = require("UI.MenuScreen")
local MapScreen = require("UI.MapScreen")
local LobbyScreen = require("UI.LobbyScreen")
local MapSelectionScreen = require("UI.MapSelectionScreen")
local MyWarehousePanel = require("UI.MyWarehousePanel")
local AppPhase = require("AppPhase")
local GameSession = require("GameSession")
local GameOverDialog = require("UI.GameOverDialog")

local GameController = {}

-- ============================================================================
-- 注册退出回调：GameSession 退出对局后导航回大厅
-- ============================================================================

GameSession.SetOnExitCallback(function(regionIdx)
    GameController.ShowLobby(regionIdx)
end)

-- ============================================================================
-- 屏幕导航
-- ============================================================================

function GameController.ShowMenu()
    AppPhase.Set(AppPhase.MENUS)
    -- 回到菜单时恢复默认 BGM
    Utils.PlayBgm(nil)
    MenuScreen.Show(
        function() GameController.ShowMap() end,
        function() GameController.ShowWarehouse() end
    )
end

function GameController.ShowWarehouse()
    MyWarehousePanel.Show(function()
        GameController.ShowMenu()
    end)
end

function GameController.ShowMap()
    MapScreen.Show(
        function() GameController.ShowMenu() end,
        function(regionIdx) GameController.ShowLobby(regionIdx) end
    )
end

function GameController.ShowLobby(regionIdx)
    LobbyScreen.Show(
        regionIdx,
        function() GameController.ShowMap() end,
        function(regionId, charIdx, diffIdx, whTypeId)
            if whTypeId then
                -- 指定仓库：直接启动，无动画
                GameSession.Start(regionId, charIdx, diffIdx, whTypeId)
            else
                -- 神秘仓库：走轮盘抽选动画
                GameController.ShowMapSelection(regionId, charIdx, diffIdx)
            end
        end
    )
end

function GameController.ShowMapSelection(regionId, charIdx, diffIdx)
    -- 查找区域的仓库类型列表
    local region
    for _, r in ipairs(Config.REGIONS) do
        if r.id == regionId then region = r; break end
    end
    local warehouseTypes = region and region.warehouseTypes or {}

    -- 单一仓库类型：跳过动画直接进入
    if #warehouseTypes <= 1 then
        GameSession.Start(regionId, charIdx, diffIdx, warehouseTypes[1])
        return
    end

    -- 多种仓库类型：显示轮盘抽选
    MapSelectionScreen.Show(regionId, warehouseTypes, function(selectedTypeId)
        GameSession.Start(regionId, charIdx, diffIdx, selectedTypeId)
    end)
end

-- ============================================================================
-- 帧更新（委托给 GameSession）
-- ============================================================================

function GameController.HandleUpdate(dt)
    GameSession.HandleUpdate(dt)

    -- ESC 快捷键：各屏幕返回
    if input:GetKeyPress(KEY_ESCAPE) then
        -- 优先关闭已打开的确认弹窗
        if GameSession.HasConfirmModal() then
            GameSession.DismissConfirm()
            return
        end
        if GameOverDialog.HasConfirmModal() then
            GameOverDialog.DismissConfirm()
            return
        end

        local screen = UIState.currentScreen
        if GameOverDialog.IsVisible() then
            -- 竞拍结算：确认返回
            GameOverDialog.ConfirmGoHome()
        elseif screen == "game" then
            -- 对局中：确认退出
            GameSession.ConfirmExit()
        elseif screen == "lobby" then
            -- 竞拍大厅 → 竞拍区域
            GameController.ShowMap()
        elseif screen == "map" then
            -- 竞拍区域 → 主菜单
            GameController.ShowMenu()
        elseif screen == "warehouse" then
            -- 仓库 → 主菜单
            GameController.ShowMenu()
        end
    end
end

-- 暴露当前状态模块给其他 UI 模块（兼容旧调用）
function GameController.GetGS()
    return GameSession.GetGS()
end

return GameController
