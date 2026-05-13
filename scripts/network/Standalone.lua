-- ============================================================================
-- network/Standalone.lua - 单机模式（保持原有完整游戏流程）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local Utils = require("UI.Utils")
local StartScreen = require("UI.StartScreen")
local GameController = require("UI.GameController")
local MoneyHUD = require("UI.MoneyHUD")
local SettingsPanel = require("UI.SettingsPanel")
local AdCardPanel = require("UI.AdCardPanel")
local OnlineRewardPanel = require("UI.OnlineRewardPanel")
local VersionRewardPanel = require("UI.VersionRewardPanel")
local SaveSystem = require("SaveSystem")
local SaveFramework = require("SaveFramework")
local SaveCompensation = require("SaveCompensation")
local AppPhase = require("AppPhase")
local GameLoop = require("GameLoop")

local Standalone = {}

-- ============================================================================
-- 帧更新模块注册（always 层：所有界面都需运行）
-- ============================================================================
local function RegisterModules()
    local FloatingMessage = require("UI.FloatingMessage")
    GameLoop.RegisterAlways("FloatingMessage",  function(dt) FloatingMessage.Update(dt) end)
    GameLoop.RegisterAlways("SaveFramework",    function(dt) SaveFramework.Update(dt) end)
    GameLoop.RegisterAlways("SaveSystem",       function(dt) SaveSystem.Update(dt) end)
    GameLoop.RegisterAlways("GameController",   function(dt) GameController.HandleUpdate(dt) end)
    GameLoop.RegisterAlways("OnlineReward",     function(dt) OnlineRewardPanel.Update(dt) end)
end

-- ============================================================================
-- Phase 1: 同步引擎初始化（纯同步，不会失败）
--   UI 框架、触摸修复、主题、音效、帧更新注册
-- ============================================================================
local function InitEngine()
    graphics.windowTitle = Config.GAME.Title

    -- 初始化 UI 系统
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- ====================================================================
    -- 界面切换时自动清空 overlay 栈（防止幽灵弹窗）
    -- 原因：Modal 弹窗在 UI.SetRoot 切换界面后 DOM 节点被销毁，
    --       但仍留在 overlayStack_ 中，其 HitTest 仍返回 true，
    --       导致新界面所有点击被拦截，无法操作。
    -- 方案：monkey-patch UI.SetRoot，切换前强制清空 overlay 栈。
    -- 参考：https://www.taptap.cn/moment/800080279258530015
    -- ====================================================================
    do
        local origSetRoot = UI.SetRoot
        UI.SetRoot = function(widget, destroyOld)
            -- 切换前清空 overlay 栈，移除旧界面遗留的幽灵弹窗
            local stack = UI.GetOverlayStack()
            for i = #stack, 1, -1 do
                UI.PopOverlay()
            end
            UI.ClearFocus()
            origSetRoot(widget, destroyOld)
        end
    end

    -- ====================================================================
    -- 移动端点击事件双触发修复（SDL Touch → 模拟 Mouse 防抖）
    -- ====================================================================
    local platform = GetPlatform()
    if platform == "Android" or platform == "iOS" or platform == "Web" then
        local DEBOUNCE = 0.100  -- 100ms 窗口期（SDL 模拟 Mouse 通常在同帧/下帧到达，远 < 16ms）
        local lastTouchTime = -1  -- 初始为 -1，避免启动头 100ms 内误拦截鼠标事件

        -- Touch 开始时记录时间戳（TouchBegin，而非 TouchEnd）
        local origHandleTouchBegin = UI.HandleTouchBegin
        UI.HandleTouchBegin = function(touchId, x, y, pressure)
            lastTouchTime = time.elapsedTime
            origHandleTouchBegin(touchId, x, y, pressure)
        end

        -- Mouse 事件：距上次 Touch < 100ms 则视为 SDL 模拟事件，直接丢弃
        local origHandleMouseDown = UI.HandleMouseDown
        UI.HandleMouseDown = function(x, y, button)
            if time.elapsedTime - lastTouchTime < DEBOUNCE then return end
            origHandleMouseDown(x, y, button)
        end

        local origHandleMouseUp = UI.HandleMouseUp
        UI.HandleMouseUp = function(x, y, button)
            if time.elapsedTime - lastTouchTime < DEBOUNCE then return end
            origHandleMouseUp(x, y, button)
        end

        local origHandleMouseMove = UI.HandleMouseMove
        UI.HandleMouseMove = function(x, y)
            if time.elapsedTime - lastTouchTime < DEBOUNCE then return end
            origHandleMouseMove(x, y)
        end
    end

    -- 全局去掉所有 UI 组件的默认圆角
    local Theme = UI.Theme
    local curTheme = Theme.GetTheme()
    local noRadius = Theme.ExtendTheme(curTheme, {
        components = {
            Button = { borderRadius = 0 },
            Panel = { borderRadius = 0 },
            TextField = { borderRadius = 0 },
            Checkbox = { borderRadius = 0 },
            ProgressBar = { borderRadius = 0 },
        },
    })
    Theme.SetTheme(noRadius)

    -- 加载音效
    Utils.LoadSounds()

    -- 注册帧更新模块到 GameLoop
    RegisterModules()

    print("[Standalone] Phase 1 complete: engine initialized")
end

-- ============================================================================
-- Phase 2: 异步数据加载（可能失败，可重试）
--   SaveFramework → SaveSystem → 进入主菜单
-- ============================================================================
local function LoadAndEnter()
    -- 预注册 PendingSettlement，确保其 cloudKey 加入 Init 的 BatchGet
    require("PendingSettlement")

    -- 1) SaveFramework: 单次 BatchGet 加载所有注册模块（money, adcard, redeem 等）
    SaveFramework.Init(function(fwSuccess)
        if not fwSuccess then
            -- WASM 无本地缓存：云端拉取失败意味着金币/广告卡等数据用默认值兜底，
            -- 玩家本局的数据可能不准确，给予提示但不阻断流程。
            print("[Standalone] SaveFramework load failed — using defaults")
            pcall(function()
                local FloatingMessage = require("UI.FloatingMessage")
                FloatingMessage.Show("数据同步失败，请检查网络")
            end)
        end
        -- 2) SaveSystem: 加载游戏存档（独立的 BatchGet，带分块逻辑）
        SaveSystem.Init(function(success, isNewPlayer)
            if not success then
                print("[Standalone] SaveSystem load failed")
                Utils.ShowMessage("存档加载失败，请检查网络后重试")
                StartScreen.Show(LoadAndEnter)
                return
            end
            print("[Standalone] Phase 2 complete: data loaded. New player: " .. tostring(isNewPlayer))

            -- 兜底检测：上次对局是否有未回收的结算数据
            local PendingSettlement = require("PendingSettlement")
            if PendingSettlement.HasPending() then
                local summary = PendingSettlement.GetSummary()
                print("[Standalone] Pending settlement detected: "
                    .. (summary and summary.unrecycledCount or 0) .. " items to recover")
                local result = PendingSettlement.AutoRecover()
                -- 通知玩家
                local FloatingMessage = require("UI.FloatingMessage")
                if result.placed > 0 or result.recycledCount > 0 then
                    local msg = "已恢复上局物品: "
                        .. (result.placed > 0 and (result.placed .. "件入库") or "")
                        .. (result.placed > 0 and result.recycledCount > 0 and ", " or "")
                        .. (result.recycledCount > 0 and (result.recycledCount .. "件回收+"
                            .. result.recycledValue) or "")
                    FloatingMessage.Show(msg)
                end
            end

            SettingsPanel.Init()
            AdCardPanel.Init()
            OnlineRewardPanel.Init()
            VersionRewardPanel.Init()
            -- 各模块数据就绪后执行一次补偿检查
            SaveCompensation.RunOnce()
            GameController.ShowMenu()
        end)
    end)
end

-- ============================================================================
-- Start(): 两阶段启动
-- ============================================================================
function Standalone.Start()
    AppPhase.Set(AppPhase.BOOT)
    InitEngine()

    AppPhase.Set(AppPhase.LOADING)
    StartScreen.Show(LoadAndEnter)

    print("=== " .. Config.GAME.Title .. " [Standalone] Started ===")
end

function Standalone.Stop()
    -- 退出前保存在线时间
    OnlineRewardPanel.Shutdown()
    UI.Shutdown()
end

-- ============================================================================
-- 帧更新：委托给 GameLoop 统一调度
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function Standalone.HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    GameLoop.Update(dt)
end

return Standalone
