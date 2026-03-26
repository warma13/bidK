-- ============================================================================
-- UI/GameController.lua - 游戏流程控制（初始化、回调、帧更新）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local AuctionEngine = require("AuctionEngine")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local MenuScreen = require("UI.MenuScreen")
local MapScreen = require("UI.MapScreen")
local LobbyScreen = require("UI.LobbyScreen")
local PlayerListPanel = require("UI.PlayerListPanel")
local CenterPanel = require("UI.CenterPanel")
local LootPanel = require("UI.LootPanel")
local BidControlPanel = require("UI.BidControlPanel")
local GameOverDialog = require("UI.GameOverDialog")
local ItemDetailPanel = require("UI.ItemDetailPanel")
local WarehouseItemListPanel = require("UI.WarehouseItemListPanel")
local DebugPanel = require("UI.DebugPanel")
local SettingsPanel = require("UI.SettingsPanel")
local VersionRewardPanel = require("UI.VersionRewardPanel")
local InfoFeed = require("UI.InfoFeed")
local TiebreakPanel = require("UI.TiebreakPanel")
local AIPlayer = require("AIPlayer")
local MoneyHUD = require("UI.MoneyHUD")
local MapSelectionScreen = require("UI.MapSelectionScreen")
local MyWarehousePanel = require("UI.MyWarehousePanel")

local GameController = {}

local GS = GameState

local C = Config.COLORS
local refs = UIState.refs

--- 判断 playerIdx 是否为本地玩家
---@param playerIdx number
---@return boolean
local function IsLocalPlayer(playerIdx)
    return playerIdx == 1
end

-- ============================================================================
-- 返回竞拍大厅
-- ============================================================================

local function GoBackToLobby()

    local regionId = GS.GetRegionId()
    local regionIdx = 1
    for i, r in ipairs(Config.REGIONS) do
        if r.id == regionId then regionIdx = i; break end
    end
    GameController.ShowLobby(regionIdx)
end

local confirmBackModal_ = nil
local function ConfirmGoBackToLobby()
    if confirmBackModal_ then return end
    confirmBackModal_ = UI.Modal {
        title = "确认返回",
        size = "sm",
        children = {
            UI.Label { text = "确定要返回竞拍大厅吗？", fontSize = 14 },
        },
    }
    local footer = UI.Panel {
        flexDirection = "row",
        justifyContent = "flex-end",
        gap = 10, width = "100%",
    }
    footer:AddChild(UI.Button {
        text = "取消", variant = "secondary",
        onClick = function()
            Utils.PlayClick()
            confirmBackModal_:Close()
            confirmBackModal_ = nil
        end,
    })
    footer:AddChild(UI.Button {
        text = "确定", variant = "primary",
        onClick = function()
            Utils.PlayClick()
            confirmBackModal_:Close()
            confirmBackModal_ = nil
            GoBackToLobby()
        end,
    })
    confirmBackModal_:SetFooter(footer)
    confirmBackModal_:Open()
end

-- ============================================================================
-- UI 组装
-- ============================================================================

local function CreateGameUI()
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
    local bgImage = whType and whType.bg or "image/bg_warehouse_grocery_20260322132513.png"

    -- 顶部仓库信息栏
    local whName = whType and whType.name or "未知仓库"
    local diffLabel = GS.GetDiffLabel()
    local infoText = whName
    if diffLabel ~= "" then
        infoText = infoText .. " · " .. diffLabel
    end

    local topInfoBar = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0,
        height = 32,
        backgroundColor = "rgba(0,0,0,0.55)",
        flexDirection = "row",
        alignItems = "center",
        children = {
            -- 左侧：金币
            PlayerListPanel.CreateMoneyHUD(),
            -- 中间：仓库名居中（用 flexGrow 撑开）
            UI.Panel {
                flexGrow = 1,
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = infoText,
                        fontSize = 14,
                        fontColor = "#FFD700",
                    },
                },
            },
            -- 右侧占位（与左侧对称，让中间真正居中）
            UI.Panel { width = 120 },
        },
    }

    local uiRoot = UI.Panel {
        id = "root",
        width = "100%", height = "100%",
        backgroundColor = C.bgDark,
        backgroundImage = bgImage,
        backgroundFit = "cover",
        flexDirection = "row",
        paddingVertical = "6%",
        paddingHorizontal = "2%",
        gap = 10,
        children = {
            -- 底层：主布局（flex row 排列：左侧玩家 + 中间列 + 右侧战利品）
            refs.playerListPanel,
            refs.centerColumn,       -- 含 CenterPanel + BidControlPanel（工具栏）
            LootPanel.Create(),
            -- 中层：弹出面板（absolute 定位，层级由顺序决定，后面的覆盖前面的）
            refs.bidPanel,           -- 出价小键盘（需要覆盖在战利品面板之上）
            (function() refs.itemDetailPanel = ItemDetailPanel.Create(); return refs.itemDetailPanel end)(),
            (function() refs.warehouseItemListPanel = WarehouseItemListPanel.Create(); return refs.warehouseItemListPanel end)(),
            CenterPanel.GetPopupOverlay(),
            TiebreakPanel.Create(),
            -- 顶层：全局 UI
            topInfoBar,
            UI.Panel {
                position = "absolute",
                left = 8, top = 36,
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    SettingsPanel.CreateButton(),
                    UI.Button {
                        text = "返回",
                        width = 56, height = 28, fontSize = 12,
                        onClick = function()
                            Utils.PlayClick()
                            ConfirmGoBackToLobby()
                        end,
                    },
                },
            },
            SettingsPanel.CreatePopup(),
            DebugPanel.CreateHUD(),
            DebugPanel.CreateDebugPanel(),
        }
    }
    refs.gameRoot = uiRoot
    UI.SetRoot(uiRoot)
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
    -- GameOverDialog 用 AddChild 动态追加到 gameRoot 末尾，层级高于所有初始 children。
    -- 需要把 ItemDetailPanel 和 WarehouseItemListPanel 重新提升到最上层，
    -- 使它们能覆盖在结算面板之上。
    if refs.gameRoot and refs.itemDetailPanel then
        refs.itemDetailPanel:Remove()
        refs.gameRoot:AddChild(refs.itemDetailPanel)
    end
    if refs.gameRoot and refs.warehouseItemListPanel then
        refs.warehouseItemListPanel:Remove()
        refs.gameRoot:AddChild(refs.warehouseItemListPanel)
    end
end

-- 注册到 BidControlPanel
BidControlPanel.SetOnGameOverClick(ShowGameOver)
TiebreakPanel.SetOnBackClick(function() GoBackToLobby() end)

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

    -- 离开竞拍阶段时关闭弹窗
    if phase ~= GS.PHASE.TIEBREAK_BID and TiebreakPanel.IsVisible() then
        TiebreakPanel.Hide()
    end

    UpdateAllUI()
end

local function OnInfoRevealed(round, publicInfos, skillInfos)
    -- 立即应用公开信息的揭示动作到 itemRevealLevels（不等动画）
    for _, info in ipairs(publicInfos or {}) do
        if info.reveals then
            for _, r in ipairs(info.reveals) do
                local cur = UIState.itemRevealLevels[r.itemIdx] or 0
                if r.targetLevel > cur then
                    UIState.itemRevealLevels[r.itemIdx] = r.targetLevel
                end
            end
        end
        -- 信息卡片入队，走弹出动画流程
        InfoFeed.Enqueue(info, false)
    end

    -- 角色私密线索（自己的槽位）
    local mySlot = 1
    if skillInfos and skillInfos[mySlot] then
        local skillInfo = skillInfos[mySlot]
        -- reveal_item 技能：直接将物品揭示到等级 3
        if skillInfo.revealedItem then
            local itemIdx = skillInfo.revealedItem.idx
            if itemIdx then
                local cur = UIState.itemRevealLevels[itemIdx] or 0
                if 3 > cur then
                    UIState.itemRevealLevels[itemIdx] = 3
                end
            end
        end
        -- 应用 reveals（品质揭示等）
        if skillInfo.reveals then
            for _, r in ipairs(skillInfo.reveals) do
                local cur = UIState.itemRevealLevels[r.itemIdx] or 0
                if r.targetLevel > cur then
                    UIState.itemRevealLevels[r.itemIdx] = r.targetLevel
                end
            end
        end
        InfoFeed.Enqueue(skillInfo, true)

        -- 处理额外线索（extraInfos）
        if skillInfo.extraInfos then
            for _, extraInfo in ipairs(skillInfo.extraInfos) do
                -- 额外揭示的物品也要更新揭示等级
                if extraInfo.revealedItem and extraInfo.revealedItem.idx then
                    local cur = UIState.itemRevealLevels[extraInfo.revealedItem.idx] or 0
                    if 3 > cur then
                        UIState.itemRevealLevels[extraInfo.revealedItem.idx] = 3
                    end
                end
                -- 应用额外线索的 reveals
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

    -- 更新其他面板（不含信息流）
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
    -- 揭示物品：从 level 2（轮廓）升级为 level 3（显示图片）
    UIState.itemRevealLevels[item.idx] = 3
    Utils.PlaySfx("bid_place")
    LootPanel.Update()
    -- 通知结算面板累加战利品价值
    GameOverDialog.OnItemRevealed(item)
end

local function OnWarehouseOpen()
    -- 开箱：所有物品设为 level 1（灰色轮廓 + 搜索图标），等待逐个揭示
    local items = GS.GetWarehouseItems()
    for i = 1, #items do
        UIState.itemRevealLevels[items[i].idx] = 1
    end

    -- 隐藏左侧玩家面板和中间列
    if refs.playerListPanel then
        refs.playerListPanel:SetVisible(false)
    end
    if refs.centerColumn then
        refs.centerColumn:SetVisible(false)
    end

    -- 显示结算面板（开箱阶段就开始展示，数值从0滚动）
    ShowGameOver()

    UpdateAllUI()
end

local function OnTiebreakBidPlaced(playerIdx, amount)
    local players = GS.GetPlayers()
    -- 出价不弹 toast
    -- 刷新竞拍弹窗
    TiebreakPanel.Refresh()
    UpdateAllUI()
end

local function OnGameOver()
    -- 确保所有物品都完全揭示
    local items = GS.GetWarehouseItems()
    for i = 1, #items do
        UIState.itemRevealLevels[items[i].idx] = 3
    end
    Utils.PlaySfx("game_over")
    UpdateAllUI()

    -- 隐藏物品详情面板
    ItemDetailPanel.Hide()

    -- 通知结算面板显示最终值和再来一局按钮
    GameOverDialog.OnGameOver()

end

-- ============================================================================
-- 开始游戏
-- ============================================================================

--- 技能使用回调（单机/网络共用）
local function OnActiveSkillUsed(playerIdx, skillInfo, resultData)
    -- 维克多：reveal_top3 → 将揭示的物品加入信息流动画
    if skillInfo.effect == "reveal_top3" and resultData then
        for _, itemInfo in ipairs(resultData) do
            if itemInfo.revealedItem and itemInfo.revealedItem.idx then
                local cur = UIState.itemRevealLevels[itemInfo.revealedItem.idx] or 0
                if 3 > cur then
                    UIState.itemRevealLevels[itemInfo.revealedItem.idx] = 3
                end
            end
            itemInfo.scope = "skill"
            itemInfo.targetPlayer = playerIdx
            InfoFeed.Enqueue(itemInfo, true)
        end
        LootPanel.Update()
    elseif skillInfo.effect == "all_in" then
        local allInInfo = {
            text = "全押已激活! 出价×1.5，无视倍率门槛",
            icon = "",
            scope = "skill",
            targetPlayer = playerIdx,
            round = GS.GetCurrentRound(),
        }
        InfoFeed.Enqueue(allInInfo, true)
    end
    CenterPanel.Update()
end

function GameController.StartGame(regionId, charIdx, diffIdx, warehouseTypeId)


    GS = GameState
    UIState.currentScreen = "game"

    -- 切换区域 BGM
    Utils.PlayBgm(regionId)

    -- 单机模式：注入全局模块实例（与多人模式的 RoomInstance 注入链对应）
    do
        local _EstimateValue  = require("EstimateValue")
        local _InfoEstimation = require("AI.InfoEstimation")
        local _Strategies     = require("AI.Strategies")
        local _InfoSystem     = require("InfoSystem")
        local _AntiCheat      = require("AntiCheat")
        _EstimateValue.InjectDeps(GameState)
        _InfoEstimation.InjectDeps(_EstimateValue, _AntiCheat)
        _Strategies.InjectDeps(GameState, _InfoSystem, _EstimateValue)
        AIPlayer.InjectDeps(GameState, _Strategies, _InfoEstimation, _AntiCheat)
        AuctionEngine.InjectDeps(GameState, AIPlayer, _InfoSystem)
    end

    AuctionEngine.Init(charIdx, regionId, diffIdx, warehouseTypeId)

    -- CreateGameUI 在 Init 之后，因为 BidControlPanel 需要 SkillSystem.Setup 已完成
    CreateGameUI()

    GameState.SetOnStateChange(OnGameStateChanged)
    GameState.SetOnMoneyChanged(function(playerIdx, newValue)
        if playerIdx == 1 then MoneyHUD.SetMoney(newValue) end
    end)
    AuctionEngine.SetOnAISealedBidConfirmed(function(playerIdx)
        UIState.aiBidConfirmed[playerIdx] = true
        PlayerListPanel.Update()
    end)
    AuctionEngine.SetOnInfoRevealed(OnInfoRevealed)
    AuctionEngine.SetOnBidRevealed(OnBidRevealed)
    AuctionEngine.SetOnJudgeResult(OnJudgeResult)
    AuctionEngine.SetOnItemRevealed(OnItemRevealed)
    AuctionEngine.SetOnWarehouseOpen(OnWarehouseOpen)
    AuctionEngine.SetOnBidPlaced(OnTiebreakBidPlaced)
    AuctionEngine.SetOnGameOver(OnGameOver)
    AuctionEngine.SetOnActiveSkillUsed(OnActiveSkillUsed)

    UIState.ResetGameState()
    LootPanel.ResetCache()
    CenterPanel.ResetAnimation()

    PlayerListPanel.Update()

    AuctionEngine.StartGame()
end

-- 暴露当前状态模块给其他 UI 模块
function GameController.GetGS()
    return GS
end

-- ============================================================================
-- 帧更新
-- ============================================================================

function GameController.HandleUpdate(dt)
    if UIState.currentScreen ~= "game" then return end

    AuctionEngine.Update(dt)

    local phase = GS.GetPhase()

    -- PlayerListPanel.Update() 仅在 BID_REVEAL 阶段每帧调用（动画插值驱动）
    -- 其他阶段由 UpdateAllUI()（状态变化回调）触发
    if phase == GS.PHASE.BID_REVEAL then
        PlayerListPanel.Update()
    end

    -- 出价展开动画
    PlayerListPanel.UpdateAnimations(dt)

    -- BidControlPanel.Update() 仅在竞拍阶段每秒更新一次（倒计时显示）
    -- 其他阶段由 UpdateAllUI()（状态变化回调）触发
    if phase == GS.PHASE.SEALED_BID or phase == GS.PHASE.TIEBREAK_BID then
        local timer = GS.GetTimer()
        local sec = math.ceil(timer)
        if sec ~= UIState.lastTickSecond then
            BidControlPanel.Update()
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

    -- 竞拍面板更新
    TiebreakPanel.Update(dt)

    -- 调试面板
    DebugPanel.HandleUpdate()

    -- 消息计时器
    Utils.UpdateMessageTimer(dt)

    -- 图片点击区域同步（仅在状态变化或布局变化时刷新）
    if LootPanel.IsHitAreasDirty() then
        LootPanel.UpdateImageHitAreas()
    end

    -- 流光动画
    UIState.glowTime = UIState.glowTime + dt
    LootPanel.UpdateGlow()

    -- 信息弹出动画
    CenterPanel.UpdateAnimation(dt)

    -- 结算面板数字滚动动画
    GameOverDialog.Update(dt)

end

-- ============================================================================
-- 屏幕导航
-- ============================================================================

function GameController.ShowMenu()
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
        function(regionId, charIdx, diffIdx) GameController.ShowMapSelection(regionId, charIdx, diffIdx) end
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
        GameController.StartGame(regionId, charIdx, diffIdx, warehouseTypes[1])
        return
    end

    -- 多种仓库类型：显示轮盘抽选
    MapSelectionScreen.Show(regionId, warehouseTypes, function(selectedTypeId)
        GameController.StartGame(regionId, charIdx, diffIdx, selectedTypeId)
    end)
end

return GameController
