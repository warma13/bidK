-- ============================================================================
-- UI/UIState.lua - 集中管理 UI refs 和游戏状态变量
-- ============================================================================

local UIState = {}

-- UI 组件引用
UIState.refs = {
    playerPanels = {},
    playerMoneyLabels = {},
    playerBidLabels = {},
    playerBidContainers = {},     -- 硬币+金额容器
    playerBidAmountPanels = {},   -- 金额展开区域（动画宽度）
    playerBidAmountLabels = {},   -- 金额文字
    playerHighlights = {},
    playerRoundSlots = {},
    playerRoundBids = {},
    playerNameLabels = {},
    playerCharLabels = {},
    playerAvatarIcons = {},

    roundLabel = nil,
    multiplierLabel = nil,
    roundTimerLabel = nil,

    -- 中栏
    centerTitle = nil,
    centerDesc = nil,
    infoFeedPanel = nil,
    infoFeedScroll = nil,

    -- 右侧仓库藏品面板
    lootGrid = nil,
    lootSlots = {},
    lootSlotIcons = {},
    lootTotalLabel = nil,

    -- 底部出价面板
    timerLabel = nil,
    bidStatusLabel = nil,
    bidButton = nil,
    bidAmountLabel = nil,
    bidHintLabel = nil,
    bidMultiplierLabel = nil,
    bidMultiplierValueLabel = nil,
    bidPanel = nil,

    -- 工具栏
    toolbarBidBtn = nil,
    toolbarItemBtn = nil,
    toolbarForfeitBtn = nil,

    -- 布局容器
    gameRoot = nil,
    centerColumn = nil,

    -- 消息
    messageLabel = nil,
    messageTimer = 0,
}

-- 屏幕状态
UIState.currentScreen = "menu"      -- "menu" | "map" | "game"
UIState.selectedRegionIdx = 1
UIState.selectedDifficultyIdx = 1
UIState.selectedCharIdx = 1

-- 信息数据
UIState.revealedPublicInfos = {}
UIState.revealedSkillInfos = {}
UIState.itemRevealLevels = {}    -- { [itemIdx] = 0|1|2|3 }

-- 出价状态
UIState.playerBidAmount = 0
UIState.playerBidConfirmed = false
UIState.aiBidConfirmed = {}          -- { [playerIdx] = true } AI 出价后由回调设置
UIState.bidInputStr = ""
UIState.bidPanelVisible = false
UIState.skillPanelVisible = false

-- 动画
UIState.glowTime = 0
UIState.infoAnimQueue = {}    -- 信息揭露动画队列 { { info=..., isSkill=bool }, ... }

-- 倒计时滴答
UIState.lastTickSecond = -1

-- 重置游戏状态（新一局）
function UIState.ResetGameState()
    UIState.revealedPublicInfos = {}
    UIState.revealedSkillInfos = {}
    UIState.itemRevealLevels = {}    -- { [itemIdx] = 0|1|2|3 }
    UIState.playerBidAmount = 0
    UIState.playerBidConfirmed = false
    UIState.aiBidConfirmed = {}
    UIState.bidInputStr = ""
    UIState.bidPanelVisible = false
    UIState.skillPanelVisible = false
    UIState.lastTickSecond = -1
    UIState.infoAnimQueue = {}
end

return UIState
