-- ============================================================================
-- network/Standalone.lua - 单机模式（保持原有完整游戏流程）
-- ============================================================================

local UI = require("urhox-libs/UI")
require("UI.PopoverPatch")  -- 动态高度补丁
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
-- 提前 require 确保模块在 SaveFramework.Init() 的 BatchGet 之前完成注册，
-- 否则其云端 key 不会被纳入初始 BatchGet，导致领取状态永远无法从云端还原
require("SeasonPass")
local AppPhase = require("AppPhase")
local GameLoop = require("GameLoop")

local Standalone = {}

-- ============================================================================
-- 帧更新模块注册（always 层：所有界面都需运行）
-- ============================================================================
local function RegisterModules()
    local FloatingMessage = require("UI.FloatingMessage")
    local DebugPanel = require("UI.DebugPanel")
    GameLoop.RegisterAlways("FloatingMessage",  function(dt) FloatingMessage.Update(dt) end)
    GameLoop.RegisterAlways("SaveFramework",    function(dt) SaveFramework.Update(dt) end)
    GameLoop.RegisterAlways("SaveSystem",       function(dt) SaveSystem.Update(dt) end)
    GameLoop.RegisterAlways("GameController",   function(dt) GameController.HandleUpdate(dt) end)
    GameLoop.RegisterAlways("OnlineReward",     function(dt) OnlineRewardPanel.Update(dt) end)
    GameLoop.RegisterAlways("DebugPanel",       function(_dt) DebugPanel.HandleUpdate() end)
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
    -- 移动端点击事件双触发修复
    -- 原理：SDL 在每次 Touch 事件后会模拟一次 Mouse 事件，导致按钮 onClick 触发两次
    --       （弹窗开了又关，表现为"点击被吞"）。
    --       iOS Safari 等浏览器的模拟 Mouse 事件可能延迟 300ms 以上，
    --       基于时间戳的防抖窗口无法可靠覆盖。
    -- 修复：一旦收到任何 Touch 事件，永久标记为触摸设备，屏蔽所有 SDL 模拟 Mouse 事件。
    --       触摸设备上 Mouse 事件全部是模拟的，屏蔽不影响真实操作。
    -- ====================================================================
    local platform = GetPlatform()
    if platform == "Android" or platform == "iOS" or platform == "Web" then
        local isTouchDevice = false

        local origHandleTouchBegin = UI.HandleTouchBegin
        UI.HandleTouchBegin = function(touchId, x, y, pressure)
            isTouchDevice = true
            origHandleTouchBegin(touchId, x, y, pressure)
        end

        local origHandleMouseDown = UI.HandleMouseDown
        UI.HandleMouseDown = function(x, y, button)
            if isTouchDevice then return end
            origHandleMouseDown(x, y, button)
        end

        local origHandleMouseUp = UI.HandleMouseUp
        UI.HandleMouseUp = function(x, y, button)
            if isTouchDevice then return end
            origHandleMouseUp(x, y, button)
        end

        local origHandleMouseMove = UI.HandleMouseMove
        UI.HandleMouseMove = function(x, y)
            if isTouchDevice then return end
            origHandleMouseMove(x, y)
        end
    end

    -- 全局去掉所有 UI 组件的默认圆角
    local Theme = UI.Theme
    local curTheme = Theme.GetTheme()
    -- 主题色：黄绿色 #C3D728（取自竞拍视觉风格）
    local noRadius = Theme.ExtendTheme(curTheme, {
        colors = {
            primary        = { 195, 215, 40,  255 },
            primaryHover   = { 215, 235, 60,  255 },
            primaryPressed = { 165, 185, 20,  255 },
        },
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
-- Phase 2: 预取状态机
--   启动时立即开始 BatchGet（与开始画面并行）；
--   用户点击"开始游戏"时数据通常已就绪，无需等待。
-- ============================================================================

-- 预取状态
local prefetchDone      = false   -- BatchGet + SaveSystem.Init 已完成
local prefetchSuccess   = nil     -- SaveSystem.Init 的 success 结果
local prefetchNewPlayer = nil     -- SaveSystem.Init 的 isNewPlayer 结果
local prefetchFwOk      = true    -- SaveFramework.Init 是否成功（失败只浮窗提示）
local prefetchWaiter    = nil     -- 用户已点击但数据未就绪时的等待回调

-- 超时保护：BatchGet 如果长时间无响应，显示等待时间并在 20 秒后提供重试按钮
local PREFETCH_RETRY_HINT = 20    -- 超过多少秒显示重试按钮（秒）
local prefetchElapsed     = 0     -- 已等待秒数
local prefetchTimerActive = false -- 是否在计时（用户点击后才开始倒计时）
local prefetchRetryShown  = false -- 是否已显示重试按钮

-- 所有数据就绪后执行的后半段逻辑（进入主菜单）
local function EnterMenu()
    if not prefetchSuccess then
        -- SaveSystem 失败：提示重试（重新拉起 StartScreen，注意避免循环）
        print("[Standalone] SaveSystem load failed")
        Utils.ShowMessage("存档加载失败，请检查网络后重试")
        -- 重置状态，允许重试
        prefetchDone      = false
        prefetchSuccess   = nil
        prefetchNewPlayer = nil
        prefetchWaiter    = nil
        -- 重新显示开始画面，用户再次点击时重新触发 StartPrefetch
        local function RetryLoad()
            prefetchDone    = false
            prefetchSuccess = nil
            StartPrefetch()  -- 重新拉取（前向引用，下方定义）
        end
        StartScreen.Show(RetryLoad, "重新加载")
        return
    end

    -- SaveFramework 失败只给浮窗提示，不阻断
    if not prefetchFwOk then
        pcall(function()
            local FloatingMessage = require("UI.FloatingMessage")
            FloatingMessage.Show("数据同步失败，请检查网络")
        end)
    end

    print("[Standalone] Phase 2 complete: data loaded. New player: " .. tostring(prefetchNewPlayer))

    -- 兜底检测：上次对局是否有未回收的结算数据
    local PendingSettlement = require("PendingSettlement")
    if PendingSettlement.HasPending() then
        local summary = PendingSettlement.GetSummary()
        print("[Standalone] Pending settlement detected: "
            .. (summary and summary.unrecycledCount or 0) .. " items to recover")
        local result = PendingSettlement.AutoRecover()
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
    require("SeasonPass").Init()
    SaveCompensation.RunOnce()
    GameController.ShowMenu()
end

-- 启动时立即调用：与开始画面并行拉取云端数据
StartPrefetch = function()
    -- 预注册 PendingSettlement，确保其 cloudKey 加入 Init 的 BatchGet
    require("PendingSettlement")

    -- 1) SaveFramework: 单次 BatchGet（money, adcard, redeem, online_reward 等）
    SaveFramework.Init(function(fwSuccess)
        prefetchFwOk = fwSuccess
        if not fwSuccess then
            print("[Standalone] SaveFramework load failed — using defaults")
        end
        -- 2) SaveSystem: 独立 BatchGet（游戏存档，带分块逻辑）
        SaveSystem.Init(function(success, isNewPlayer)
            prefetchDone      = true
            prefetchSuccess   = success
            prefetchNewPlayer = isNewPlayer

            -- 若用户已点击"开始游戏"并在等待，立即进入
            if prefetchWaiter then
                local waiter = prefetchWaiter
                prefetchWaiter = nil
                waiter()
            end
        end)
    end)
end

-- 用户点击"开始游戏"时调用
local function LoadAndEnter()
    if prefetchDone then
        -- 数据已就绪，直接进入
        EnterMenu()
    else
        -- 仍在加载中，注册等待回调；界面保持 StartScreen 显示
        print("[Standalone] Data not ready yet, waiting for prefetch...")
        prefetchWaiter = EnterMenu

        -- 启动等待计时器：每秒更新等待文案，超过 PREFETCH_RETRY_HINT 秒显示重试按钮
        prefetchElapsed     = 0
        prefetchRetryShown  = false
        prefetchTimerActive = true

        -- 定义重试动作（重置状态并重新发起 BatchGet）
        local lastShownSec = -1  -- 上次更新文案时的整秒值，避免每帧 SetText
        local function DoRetry()
            print("[Standalone] Manual retry: resetting prefetch state")
            -- 先隐藏重试按钮、重置文案
            StartScreen.HideWaiting()
            -- 重置所有预取状态
            prefetchTimerActive = false
            prefetchRetryShown  = false
            prefetchElapsed     = 0
            lastShownSec        = -1
            prefetchDone        = false
            prefetchSuccess     = nil
            prefetchNewPlayer   = nil
            prefetchFwOk        = true
            prefetchWaiter      = EnterMenu
            -- SaveFramework.Init 内部有 initGeneration 机制：
            -- initialized=false 时重新发 BatchGet；旧的悬挂回调因 gen 不匹配被丢弃
            StartPrefetch()
            -- 重新启动计时（复用已注册的 RegisterAlways 闭包）
            prefetchElapsed     = 0
            prefetchTimerActive = true
        end

        GameLoop.RegisterAlways("PrefetchTimeout", function(dt)
            if not prefetchTimerActive then return end

            -- 数据已就绪，停止计时并隐藏等待提示
            if prefetchDone then
                prefetchTimerActive = false
                StartScreen.HideWaiting()
                return
            end

            prefetchElapsed = prefetchElapsed + dt

            -- 整秒才刷新一次文案，避免每帧 SetText
            local secs = math.floor(prefetchElapsed)
            if secs ~= lastShownSec then
                lastShownSec = secs
                StartScreen.SetWaitSeconds(secs)
            end

            -- 超过阈值后显示重试按钮（只显示一次）
            if not prefetchRetryShown and prefetchElapsed >= PREFETCH_RETRY_HINT then
                prefetchRetryShown = true
                print("[Standalone] ⏰ Prefetch slow (" .. PREFETCH_RETRY_HINT
                    .. "s elapsed) — showing retry button")
                StartScreen.ShowRetryButton(DoRetry)
            end
        end)
    end
end

-- ============================================================================
-- Start(): 两阶段启动
-- ============================================================================
function Standalone.Start()
    AppPhase.Set(AppPhase.BOOT)
    InitEngine()

    AppPhase.Set(AppPhase.LOADING)
    -- 立即开始拉取云端数据（与开始画面并行，减少等待）
    StartPrefetch()
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
