-- ============================================================================
-- GameSession.lua - 对局生命周期管理器
--
-- 职责：
--   1. 对局初始化（依赖注入、AuctionEngine.Init、CreateGameUI）
--   2. 所有对局回调（OnGameStateChanged、OnInfoRevealed 等）
--   3. 对局帧更新（AuctionEngine.Update、面板动画、倒计时等）
--   4. 统一退出路径 Exit()（GoBackToLobby 逻辑）
--
-- 设计原则：
--   - 通过 onExitCallback 通知 GameController 执行导航，避免循环依赖
--   - guard 闭包捕获 gameGeneration，自动失效旧回调
--   - 每个子模块 Update 用 SafeCall 隔离
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local AuctionEngine = require("AuctionEngine")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local PlayerListPanel = require("UI.PlayerListPanel")
local CenterPanel = require("UI.CenterPanel")
local LootPanel = require("UI.LootPanel")
local BidControlPanel = require("UI.BidControlPanel")
local GameOverDialog = require("UI.GameOverDialog")
local ItemDetailPanel = require("UI.ItemDetailPanel")
local WarehouseItemListPanel = require("UI.WarehouseItemListPanel")
local DebugPanel = require("UI.DebugPanel")
local SettingsPanel = require("UI.SettingsPanel")
local InfoFeed = require("UI.InfoFeed")
local TiebreakPanel = require("UI.TiebreakPanel")
local AIPlayer = require("AIPlayer")
local MoneyHUD = require("UI.MoneyHUD")
local MoneyManager = require("MoneyManager")
local SaveFramework = require("SaveFramework")
local AdCardPanel = require("UI.AdCardPanel")
local MyWarehousePanel = require("UI.MyWarehousePanel")
local AppPhase = require("AppPhase")
local PropSystem = require("PropSystem")

local GameSession = {}

local GS = GameState
local C = Config.COLORS
local refs = UIState.refs

--- 物品详情浮窗实例（对局期间共享给 LootPanel）
---@type table|nil
local itemDetail_ = nil

--- 退出回调（由 GameController 注册，避免循环依赖）
---@type fun(regionIdx: number)|nil
local onExitCallback_ = nil

--- 设置退出回调
---@param cb fun(regionIdx: number)
function GameSession.SetOnExitCallback(cb)
    onExitCallback_ = cb
end

-- ============================================================================
-- pcall 保护工具
-- ============================================================================

local function SafeCall(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        print("[GS-ERROR] " .. label .. ": " .. tostring(err))
    end
    return ok
end

-- ============================================================================
-- 统一退出路径
-- ============================================================================

local confirmBackModal_ = nil

function GameSession.Exit()
    AppPhase.Set(AppPhase.MENUS)
    UIState.gameUIActive = false

    -- 恢复所有模块的云端保存（对局结束）
    SaveFramework.ResumeAfterGame()
    local SaveSystem = require("SaveSystem")
    SaveSystem.ResumeAfterGame()

    -- 计算当前区域索引
    local regionId = GS.GetRegionId()
    local regionIdx = 1
    for i, r in ipairs(Config.REGIONS) do
        if r.id == regionId then regionIdx = i; break end
    end

    -- 通过回调通知 GameController 执行导航
    if onExitCallback_ then
        onExitCallback_(regionIdx)
    else
        print("[GameSession] WARNING: no onExitCallback set!")
    end
end

local function ConfirmExit()
    if confirmBackModal_ then return end
    confirmBackModal_ = UI.Modal {
        title = "确认返回",
        size = "sm",
        borderRadius = 0,
        headerBgColor = { 30, 32, 38, 200 },
        contentBgColor = { 22, 24, 30, 180 },
        onClose = function()
            confirmBackModal_ = nil
        end,
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = 8,
                paddingVertical = 6,
                children = {
                    UI.Label {
                        text = "确定要离开本局竞拍吗？",
                        fontSize = 15,
                        fontColor = "#FFFFFF",
                        fontWeight = "bold",
                    },
                },
            },
        },
    }
    local footer = UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        gap = 12, width = "100%",
        paddingVertical = 4,
    }
    footer:AddChild(UI.Button {
        text = "取消",
        width = 110, height = 38,
        fontSize = 14,
        backgroundColor = { 50, 55, 65, 200 },
        hoverBackgroundColor = { 70, 75, 90, 230 },
        pressedBackgroundColor = { 35, 38, 48, 255 },
        borderWidth = 1,
        borderColor = { 100, 105, 120, 130 },
        borderRadius = 0,
        onClick = function()
            Utils.PlayClick()
            confirmBackModal_:Close()
            confirmBackModal_ = nil
        end,
    })
    footer:AddChild(UI.Button {
        text = "离开",
        width = 110, height = 38,
        fontSize = 14,
        fontWeight = "bold",
        fontColor = { 255, 255, 255, 255 },
        backgroundColor = { 185, 45, 35, 220 },
        hoverBackgroundColor = { 210, 60, 48, 255 },
        pressedBackgroundColor = { 150, 30, 22, 255 },
        borderWidth = 0,
        borderRadius = 0,
        onClick = function()
            Utils.PlayClick()
            confirmBackModal_:Close()
            confirmBackModal_ = nil
            GameSession.Exit()
        end,
    })
    confirmBackModal_:SetFooter(footer)
    confirmBackModal_:Open()
end

-- ============================================================================
-- UI 组装
-- ============================================================================

local function CreateGameUI()
    -- 递增世代计数器，使旧回调中的 guard 闭包自动失效
    UIState.gameGeneration = UIState.gameGeneration + 1
    UIState.gameUIActive = true

    -- 左侧玩家列表
    refs.playerListPanel = PlayerListPanel.Create()

    -- 中间列：信息面板 + 出价面板
    refs.centerColumn = UI.Panel {
        id = "centerColumn",
        width = "44%", height = "100%",
        flexShrink = 1,
        flexDirection = "column",
        gap = 8,
        overflow = "visible",
        children = {
            CenterPanel.Create(),
            BidControlPanel.Create(),
        }
    }

    -- 根据仓库类型选择背景图
    local whType = Config.WAREHOUSE_TYPES[GS.GetWarehouseTypeId()]
    local bgImage = whType and whType.bg or "image/bg_warehouse_grocery_20260322132513.jpg"

    -- 顶部仓库信息栏
    local whName = whType and whType.name or "未知仓库"
    local diffLabel = GS.GetDiffLabel()
    local infoText = whName
    if diffLabel ~= "" then
        infoText = infoText .. " · " .. diffLabel
    end

    -- 返回按钮（在 topInfoBar 之前创建，以便引用）
    local sz = Utils.sz
    refs.backBtn = UI.Button {
        text = "返回",
        height = sz(28),
        fontSize = sz(12),
        fontColor = { 195, 215, 40, 230 },
        fontWeight = "bold",
        backgroundColor = { 195, 215, 40, 20 },
        hoverBackgroundColor = { 195, 215, 40, 50 },
        pressedBackgroundColor = { 195, 215, 40, 110 },
        borderWidth = 1,
        borderColor = { 195, 215, 40, 160 },
        borderRadius = 0,
        paddingHorizontal = sz(10),
        onClick = function()
            Utils.PlayClick()
            ConfirmExit()
        end,
    }

    local topInfoBar = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0,
        height = sz(44),
        paddingHorizontal = sz(12),
        backgroundColor = { 0, 0, 0, 180 },
        flexDirection = "row",
        alignItems = "center",
        children = {
            -- 左侧：返回 + 设置 + 金币
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = sz(4),
                children = {
                    refs.backBtn,
                    SettingsPanel.CreateCompactButton(),
                    PlayerListPanel.CreateMoneyHUD(),
                },
            },
            -- 中间：仓库名绝对定位居中（与大厅顶部栏保持一致）
            UI.Panel {
                position = "absolute", left = 0, right = 0, top = 0, bottom = 0,
                flexDirection = "row", alignItems = "center", justifyContent = "center",
                gap = sz(4),
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = infoText,
                        fontSize = sz(16),
                        fontColor = "#FFD700",
                        fontWeight = "bold",
                    },
                },
            },
        },
    }

    local uiRoot = UI.Panel {
        id = "root",
        width = "100%", height = "100%",
        flexDirection = "row",
        paddingVertical = "6%",
        paddingHorizontal = "2%",
        gap = 10,
        children = {
            refs.playerListPanel,
            refs.centerColumn,
            LootPanel.Create(),
            refs.panelDismissOverlay,
            refs.bidPanel,
            refs.propPanel,
            (function()
                refs.panelBackdrop = UI.Panel {
                    position = "absolute",
                    left = 0, top = 0,
                    width = "100%", height = "100%",
                    backgroundColor = { 0, 0, 0, 30 },
                    visible = false,
                    onClick = function(self, event)
                        local slotIdx = LootPanel.HitTestSlot(event.x, event.y)
                        if slotIdx then
                            Utils.PlayClick()
                            LootPanel._OnSlotClick(slotIdx)
                        else
                            if itemDetail_ then itemDetail_:Hide() end
                            WarehouseItemListPanel.Hide()
                        end
                    end,
                }
                return refs.panelBackdrop
            end)(),
            (function()
                itemDetail_ = ItemDetailPanel.New({
                    onShow = function()
                        local bd = refs.panelBackdrop
                        if bd then bd:SetVisible(true) end
                    end,
                    onHide = function()
                        local bd = refs.panelBackdrop
                        if not bd then return end
                        local wip = refs.warehouseItemListPanel
                        if not (wip and wip:IsVisible()) then
                            bd:SetVisible(false)
                        end
                    end,
                })
                UIState.itemDetail = itemDetail_
                refs.itemDetailPanel = itemDetail_:GetWidget()
                return refs.itemDetailPanel
            end)(),
            (function() refs.warehouseItemListPanel = WarehouseItemListPanel.Create(); return refs.warehouseItemListPanel end)(),
            CenterPanel.GetPopupOverlay(),
            TiebreakPanel.Create(),
            topInfoBar,
            (function() refs.settingsPopup = SettingsPanel.CreatePopup(); return refs.settingsPopup end)(),
            -- 结算界面 overlay（预挂载，避免动态 AddChild 布局刷新问题）
            GameOverDialog.CreateOverlay(),
        }
    }
    refs.gameRoot = uiRoot
    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = C.bgDark,
        backgroundImage = bgImage,
        backgroundFit = "cover",
        children = {
            UI.SafeAreaView {
                edges = "all", width = "100%", height = "100%",
                children = { uiRoot },
            },
        },
    })
end

local function UpdateAllUI()
    PlayerListPanel.Update()
    CenterPanel.Update()
    BidControlPanel.Update()
    LootPanel.Update()
end

-- ============================================================================
-- 结算弹窗
-- ============================================================================

local function ShowGameOver()
    GameOverDialog.Show()
    local panelsToRelayer = { refs.itemDetailPanel, refs.warehouseItemListPanel, refs.settingsPopup }
    for _, panel in ipairs(panelsToRelayer) do
        if refs.gameRoot and panel then
            panel:Remove()
            refs.gameRoot:AddChild(panel)
        end
    end
end

-- 注册到 BidControlPanel / TiebreakPanel
BidControlPanel.SetOnGameOverClick(ShowGameOver)
TiebreakPanel.SetOnBackClick(function() GameSession.Exit() end)

-- ============================================================================
-- 回调
-- ============================================================================

local function OnGameStateChanged(gameState)
    local phase = gameState.GetPhase()

    if phase == GS.PHASE.WAREHOUSE_INTRO then
        Utils.PlaySfx("round_start")
    elseif phase == GS.PHASE.SEALED_BID then
        UIState.playerBidConfirmed = false
        UIState.aiBidConfirmed = {}
        UIState.bidInputStr = ""
        UIState.playerBidAmount = 0
        UIState.lastTickSecond = -1
        UIState.bidPanelVisible = false
        if refs.bidPanel then refs.bidPanel:SetVisible(false) end
    elseif phase == GS.PHASE.BID_REVEAL then
        UIState.bidPanelVisible = false
        if refs.bidPanel then refs.bidPanel:SetVisible(false) end
    elseif phase == GS.PHASE.TIEBREAK_BID then
        UIState.lastTickSecond = -1
        UIState.bidPanelVisible = false
        if refs.bidPanel then refs.bidPanel:SetVisible(false) end
        TiebreakPanel.Show()
    end

    if phase ~= GS.PHASE.TIEBREAK_BID and TiebreakPanel.IsVisible() then
        TiebreakPanel.Hide()
    end

    UpdateAllUI()
end

local function OnInfoRevealed(round, publicInfos, skillInfos)
    for _, info in ipairs(publicInfos or {}) do
        if info.reveals then
            for _, r in ipairs(info.reveals) do
                local cur = UIState.itemRevealLevels[r.itemIdx] or 0
                if r.targetLevel > cur then
                    UIState.itemRevealLevels[r.itemIdx] = r.targetLevel
                end
            end
        end
        InfoFeed.Enqueue(info, false)
    end

    local mySlot = 1
    if skillInfos and skillInfos[mySlot] then
        local skillInfo = skillInfos[mySlot]
        if skillInfo.revealedItem then
            local itemIdx = skillInfo.revealedItem.idx
            if itemIdx then
                local cur = UIState.itemRevealLevels[itemIdx] or 0
                if 4 > cur then
                    UIState.itemRevealLevels[itemIdx] = 4
                end
            end
        end
        if skillInfo.reveals then
            for _, r in ipairs(skillInfo.reveals) do
                local cur = UIState.itemRevealLevels[r.itemIdx] or 0
                if r.targetLevel > cur then
                    UIState.itemRevealLevels[r.itemIdx] = r.targetLevel
                end
            end
        end
        InfoFeed.Enqueue(skillInfo, true)

        if skillInfo.extraInfos then
            for _, extraInfo in ipairs(skillInfo.extraInfos) do
                if extraInfo.revealedItem and extraInfo.revealedItem.idx then
                    local cur = UIState.itemRevealLevels[extraInfo.revealedItem.idx] or 0
                    if 4 > cur then
                        UIState.itemRevealLevels[extraInfo.revealedItem.idx] = 4
                    end
                end
                if extraInfo.reveals then
                    for _, r in ipairs(extraInfo.reveals) do
                        local cur = UIState.itemRevealLevels[r.itemIdx] or 0
                        if r.targetLevel > cur then
                            UIState.itemRevealLevels[r.itemIdx] = r.targetLevel
                        end
                    end
                end
                InfoFeed.Enqueue(extraInfo, true)
            end
        end
    end

    PlayerListPanel.Update()
    BidControlPanel.Update()
    LootPanel.Update()
end

local function OnBidRevealed(revealIndex, playerIdx, amount)
    -- UI 驱动的揭示动画，此回调不再使用
end

local function OnJudgeResult(result)
    if result.passed then
        Utils.PlaySfx("bid_success")
    end
    UpdateAllUI()
end

local function OnItemRevealed(itemIndex, item)
    UIState.itemRevealLevels[item.idx] = 4
    Utils.PlaySfx("bid_place")
    LootPanel.Update()
    GameOverDialog.OnItemRevealed(item)
end

local function OnWarehouseOpen()
    local items = GS.GetWarehouseItems()
    for i = 1, #items do
        UIState.itemRevealLevels[items[i].idx] = 1
    end

    if refs.playerListPanel then
        refs.playerListPanel:SetStyle({ visibility = "hidden" })
    end
    if refs.centerColumn then
        refs.centerColumn:SetStyle({ visibility = "hidden" })
    end
    if refs.backBtn then
        refs.backBtn:SetVisible(false)
    end

    ShowGameOver()
    UpdateAllUI()
end

local function OnTiebreakBidPlaced(playerIdx, amount)
    TiebreakPanel.Refresh()
    UpdateAllUI()
end

local function OnGameOver()
    local items = GS.GetWarehouseItems()
    for i = 1, #items do
        UIState.itemRevealLevels[items[i].idx] = 4
    end
    Utils.PlaySfx("game_over")
    UpdateAllUI()
    if itemDetail_ then itemDetail_:Hide() end
    GameOverDialog.OnGameOver()
end


-- ============================================================================
-- 开始对局
-- ============================================================================

function GameSession.Start(regionId, charIdx, diffIdx, warehouseTypeId)
    AppPhase.Set(AppPhase.IN_GAME)
    print("[GameSession] Start BEGIN regionId=" .. tostring(regionId) .. " charIdx=" .. tostring(charIdx))

    GS = GameState
    UIState.currentScreen = "game"

    -- 切换区域 BGM
    Utils.PlayBgm(regionId)

    -- 依赖注入
    do
        local _EstimateValue  = require("EstimateValue")
        local _InfoEstimation = require("AI.InfoEstimation")
        local _Strategies     = require("AI.Strategies")
        local _InfoSystem     = require("InfoSystem")
        local _AntiCheat      = require("AntiCheat")
        _EstimateValue.InjectDeps(GameState)
        _InfoEstimation.InjectDeps(_EstimateValue, _AntiCheat, GameState)
        _Strategies.InjectDeps(GameState, _InfoSystem, _EstimateValue)
        AIPlayer.InjectDeps(GameState, _Strategies, _InfoEstimation, _AntiCheat, _EstimateValue)
        AuctionEngine.InjectDeps(GameState, AIPlayer, _InfoSystem)
    end
    print("[GameSession] Deps injected")

    -- 对局中暂停云端保存
    SaveFramework.PauseForGame()
    local SaveSystem = require("SaveSystem")
    SaveSystem.PauseForGame()

    PropSystem.ResetGameUsage()

    AuctionEngine.Init(charIdx, regionId, diffIdx, warehouseTypeId)
    print("[GameSession] AuctionEngine.Init done")

    CreateGameUI()
    print("[GameSession] CreateGameUI done, generation=" .. UIState.gameGeneration)

    -- guard 闭包：捕获当前 generation，回调时若 generation 不匹配则静默忽略
    local gen = UIState.gameGeneration
    local function guard(fn)
        return function(...)
            if UIState.gameGeneration ~= gen then
                print("[GameSession-GUARD] Stale callback ignored (gen " .. gen .. " vs " .. UIState.gameGeneration .. ")")
                return
            end
            fn(...)
        end
    end

    GameState.SetOnStateChange(guard(OnGameStateChanged))
    GameState.SetOnMoneyChanged(guard(function(playerIdx, newValue)
        if playerIdx == 1 then MoneyHUD.SetMoney(newValue) end
    end))
    AuctionEngine.SetOnAISealedBidConfirmed(guard(function(playerIdx)
        UIState.aiBidConfirmed[playerIdx] = true
        PlayerListPanel.Update()
    end))
    AuctionEngine.SetOnInfoRevealed(guard(OnInfoRevealed))
    AuctionEngine.SetOnBidRevealed(guard(OnBidRevealed))
    AuctionEngine.SetOnJudgeResult(guard(OnJudgeResult))
    AuctionEngine.SetOnItemRevealed(guard(OnItemRevealed))
    AuctionEngine.SetOnWarehouseOpen(guard(OnWarehouseOpen))
    AuctionEngine.SetOnBidPlaced(guard(OnTiebreakBidPlaced))
    AuctionEngine.SetOnGameOver(guard(OnGameOver))
    UIState.ResetGameState()
    LootPanel.ResetCache()
    CenterPanel.ResetAnimation()

    PlayerListPanel.Update()
    print("[GameSession] Callbacks registered, calling AuctionEngine.StartGame...")

    AuctionEngine.StartGame()
    print("[GameSession] AuctionEngine.StartGame returned")
end

-- ============================================================================
-- 对局帧更新
-- ============================================================================

function GameSession.HandleUpdate(dt)
    -- 全屏通用更新
    SafeCall("AdCardPanel.Update", AdCardPanel.Update, dt)

    -- 仓库面板滑动选择更新
    if UIState.currentScreen == "warehouse" then
        SafeCall("MyWarehousePanel.Update", MyWarehousePanel.Update, dt)
    end

    -- 非游戏屏幕或游戏UI未激活时不走对局更新
    if UIState.currentScreen ~= "game" then return end
    if not UIState.gameUIActive then return end

    -- ========== 对局更新 ==========

    SafeCall("AuctionEngine.Update", AuctionEngine.Update, dt)

    local phase = GS.GetPhase()

    if phase == GS.PHASE.BID_REVEAL then
        SafeCall("PlayerListPanel.Update", PlayerListPanel.Update)
    end

    SafeCall("PlayerListPanel.UpdateAnimations", PlayerListPanel.UpdateAnimations, dt)

    if phase == GS.PHASE.SEALED_BID or phase == GS.PHASE.TIEBREAK_BID then
        local timer = GS.GetTimer()
        local sec = math.ceil(timer)
        if sec ~= UIState.lastTickSecond then
            SafeCall("BidControlPanel.Update", BidControlPanel.Update)
        end
    end

    -- 倒计时滴答声
    if phase == GS.PHASE.SEALED_BID or phase == GS.PHASE.TIEBREAK_BID then
        local timer = GS.GetTimer()
        local sec = math.ceil(timer)
        if sec <= 5 and sec >= 1 and sec ~= UIState.lastTickSecond then
            UIState.lastTickSecond = sec
            Utils.PlaySfx("timer_tick")
        end
    else
        UIState.lastTickSecond = -1
    end

    SafeCall("TiebreakPanel.Update", TiebreakPanel.Update, dt)
    -- DebugPanel.HandleUpdate 已由 GameLoop.RegisterAlways 统一驱动
    SafeCall("Utils.UpdateMessageTimer", Utils.UpdateMessageTimer, dt)

    if LootPanel.IsHitAreasDirty() then
        SafeCall("LootPanel.UpdateImageHitAreas", LootPanel.UpdateImageHitAreas)
    end

    UIState.glowTime = UIState.glowTime + dt
    SafeCall("LootPanel.UpdateGlow", LootPanel.UpdateGlow)

    local animOk = SafeCall("CenterPanel.UpdateAnimation", CenterPanel.UpdateAnimation, dt)
    if not animOk then
        print("[GameSession] CenterPanel animation crashed, resetting")
        SafeCall("CenterPanel.ResetAnimation", CenterPanel.ResetAnimation)
    end

    SafeCall("GameOverDialog.Update", GameOverDialog.Update, dt)


end

-- 暴露当前状态模块给其他 UI 模块
function GameSession.GetGS()
    return GS
end

-- 暴露确认退出弹窗（供 ESC 快捷键调用）
function GameSession.ConfirmExit()
    ConfirmExit()
end

-- 关闭确认退出弹窗（ESC 二次按下时取消）
function GameSession.DismissConfirm()
    if confirmBackModal_ then
        confirmBackModal_:Close()
        confirmBackModal_ = nil
    end
end

function GameSession.HasConfirmModal()
    return confirmBackModal_ ~= nil
end

return GameSession
