-- ============================================================================
-- GameState.lua - 游戏状态管理（暗标仓库竞拍版）
-- ============================================================================

---@diagnostic disable: undefined-global
local Config = require("Config")
local WarehouseGenerator = require("WarehouseGenerator")
local AntiCheat = require("AntiCheat")
local MoneyManager = require("MoneyManager")
local SkillSystem = require("SkillSystem")
local SaveSystem = require("SaveSystem")
local GameState = {}

-- 受保护的关键数值（SecureValue）
local secureMoney = {}       -- { [playerIdx] = SecureValue }
local secureTotalValue = nil  -- SecureValue

-- 游戏阶段
GameState.PHASE = {
    CHAR_SELECT     = "char_select",
    WAREHOUSE_INTRO = "warehouse_intro",
    INFO_REVEAL     = "info_reveal",
    SEALED_BID      = "sealed_bid",
    BID_REVEAL      = "bid_reveal",
    ROUND_JUDGE     = "round_judge",
    TIEBREAK_BID    = "tiebreak_bid",
    WAREHOUSE_OPEN  = "warehouse_open",
    GAME_OVER       = "game_over",
}

-- 状态数据
local state = {
    phase = GameState.PHASE.CHAR_SELECT,

    -- 玩家 [1..4]
    players = {},

    -- 仓库
    warehouseName = "",
    warehouseItems = {},
    warehouseTotalValue = 0,

    -- 轮次
    currentRound = 0,

    -- 暗标出价
    sealedBids = {},        -- { [playerIdx] = amount }
    bidLocked = {},         -- { [playerIdx] = true } 已锁定出价
    revealOrder = {},       -- 揭晓顺序
    revealIndex = 0,        -- 当前揭晓到第几位

    -- 倍率判定结果
    judgeResult = nil,
    -- { winner, highBid, highBidder, secondBid, secondBidder,
    --   ratio, required, passed, isTie }

    -- 实时竞拍（第4轮平局）
    tiebreakPlayers = {},
    currentBid = 0,
    currentBidder = 0,
    bidHistory = {},
    roundBids = {},             -- { [round] = { [playerIdx] = amount } } 每轮出价记录

    -- 倒计时
    timer = 0,

    -- 仓库开箱
    revealedItemIndex = 0,

    -- 最终赢家
    winner = 0,
    winnerPaid = 0,

    -- UI回调
    onStateChange = nil,
}

-- ============================================================================
-- 初始化
-- ============================================================================

function GameState.Init(playerCharIdx, regionId, diffIdx, warehouseTypeId, playersConfig)
    math.randomseed(os.time())

    state.phase = GameState.PHASE.CHAR_SELECT
    state.currentRound = 0
    state.winner = 0
    state.winnerPaid = 0
    state.settled = false

    -- 反作弊重置
    AntiCheat.reset()
    secureMoney = {}

    -- 生成仓库（使用 WarehouseGenerator，传入区域和难度）
    state.warehouseData = WarehouseGenerator.Generate(regionId, warehouseTypeId, diffIdx)
    state.warehouseName = state.warehouseData.warehouseName
    state.warehouseItems = state.warehouseData.items
    state.warehouseTotalValue = state.warehouseData.totalValue
    state.warehouseTypeId = warehouseTypeId or "grocery"
    state.regionId = regionId

    -- 存储仓库价值（AI 决策锚点；warehouseValue 是高点/天花板，非平均值）
    local region = state.warehouseData.region
    local difficulties = region and region.difficulties or {}
    local difficulty = difficulties[diffIdx or 1] or difficulties[1]
    state.expectedValue = difficulty and (difficulty.warehouseValue or difficulty.expectedValue) or 100000
    state.startingMoney = difficulty and difficulty.startingMoney or Config.GAME.StartingMoney
    state.entryFee = difficulty and difficulty.entryFee or 0
    state.diffLabel = difficulty and difficulty.label or ""
    state.assetRequirement = difficulty and difficulty.assetRequirement or 0

    -- 保护仓库总价值
    secureTotalValue = AntiCheat.SecureValue(state.warehouseTotalValue)

    -- 创建玩家
    state.players = {}
    state.roundBids = {}

    if playersConfig then
        -- ========================================
        -- 多人模式：使用服务端提供的玩家配置
        -- ========================================
        for idx, pc in ipairs(playersConfig) do
            local char = Config.CHARACTERS[pc.charIdx] or Config.CHARACTERS[1]
            local money = state.startingMoney
            if char.bonusMoney then
                money = math.floor(money * char.bonusMoney)
            end
            state.players[idx] = {
                name = pc.name or ("Player" .. idx),
                isHuman = pc.isHuman,
                character = char,
                money = money,
                personality = char.personality,
                userId = pc.userId,
            }
        end
        state.myUserId = 0  -- 服务端无"我的"概念
    else
        -- ========================================
        -- 单机模式：1 人类 + 3 AI
        -- ========================================
        local availChars = {}
        for i, ch in ipairs(Config.CHARACTERS) do
            if i ~= playerCharIdx then
                availChars[#availChars + 1] = ch
            end
        end
        for i = #availChars, 2, -1 do
            local j = math.random(1, i)
            availChars[i], availChars[j] = availChars[j], availChars[i]
        end

        -- 玩家1（人类）—— 使用持久化钱包，不用 startingMoney（那是给 AI 的）
        local playerChar = Config.CHARACTERS[playerCharIdx]
        local MoneyHUD = require("UI.MoneyHUD")
        local playerMoney = MoneyHUD.GetMoney()

        -- 获取 TapTap 用户信息
        local myUserId = lobby and lobby:GetMyUserId() or 0
        local playerName = tostring(myUserId)
        state.myUserId = myUserId

        state.players[1] = {
            name = playerName,
            isHuman = true,
            character = playerChar,
            money = playerMoney,
        }

        -- 异步获取 TapTap 昵称
        if myUserId ~= 0 then
            GetUserNickname({
                userIds = { myUserId },
                onSuccess = function(nicknames)
                    if nicknames and #nicknames > 0 and nicknames[1].nickname then
                        state.players[1].name = nicknames[1].nickname
                        GameState.NotifyChange()
                    end
                end,
            })
        end

        -- AI 玩家 2-4：从名字库不放回抽取
        local namePool = {}
        for _, n in ipairs(Config.AI_NAMES) do namePool[#namePool + 1] = n end
        for i = #namePool, 2, -1 do
            local j = math.random(1, i)
            namePool[i], namePool[j] = namePool[j], namePool[i]
        end
        local aiNames = { namePool[1], namePool[2], namePool[3] }
        -- AI 资金按仓库 tier 动态调整：tier 越高，AI 资金倍率越大，保证高价值仓库有足够竞争力
        local AI_TIER_MULTIPLIERS = {
            trash    = 2.0,
            junk     = 2.0,
            poor     = 2.0,
            normal   = 2.0,
            good     = 3.0,
            treasure = 5.0,
            jackpot  = 8.0,
        }
        local whTier = state.warehouseData and state.warehouseData.tier or "normal"
        local tierMult = AI_TIER_MULTIPLIERS[whTier] or 2.0
        local aiBaseMoney = state.expectedValue * tierMult
        print("[GameState] AI money: tier=" .. whTier .. " mult=x" .. tierMult .. " base=" .. aiBaseMoney)
        for i = 1, 3 do
            local aiChar = availChars[i]
            local aiMoney = aiBaseMoney
            if aiChar.bonusMoney then
                aiMoney = math.floor(aiMoney * aiChar.bonusMoney)
            end
            state.players[i + 1] = {
                name = aiNames[i],
                isHuman = false,
                character = aiChar,
                money = aiMoney,
                personality = aiChar.personality,
            }
        end
    end

    -- 为所有玩家创建资金保护
    for idx, player in ipairs(state.players) do
        secureMoney[idx] = AntiCheat.SecureValue(player.money)
    end

    -- 初始化子模块（必须在 secureMoney 和 state 准备好之后）
    MoneyManager.Setup({ state = state, secureMoney = secureMoney, AntiCheat = AntiCheat })
    SkillSystem.Setup({ state = state, secureAddMoney = MoneyManager.SecureAddMoney, validateMoney = MoneyManager.ValidateMoney })

    -- 通知资金变动（人类玩家初始资金）
    MoneyManager.NotifyMoneyChanged(1, state.players[1].money)

    print("[GameState] Initialized. Warehouse: " .. state.warehouseName)
    print("[GameState] Items: " .. #state.warehouseItems .. ", Total value: " .. state.warehouseTotalValue)
    for idx, player in ipairs(state.players) do
        print("[GameState] Player " .. idx .. ": " .. player.name .. " (" .. player.character.name
            .. ") money=" .. player.money
            .. " skill=" .. (player.character.activeSkill and player.character.activeSkill.name or "none"))
    end
end

-- ============================================================================
-- 阶段流转
-- ============================================================================

function GameState.SetPhase(newPhase)
    local old = state.phase
    state.phase = newPhase
    print("[GameState] Phase: " .. old .. " -> " .. newPhase)
    GameState.NotifyChange()
end

-- 开始仓库介绍
function GameState.StartWarehouseIntro()
    state.phase = GameState.PHASE.WAREHOUSE_INTRO
    GameState.NotifyChange()
end

-- 开始新一轮信息揭露
function GameState.StartInfoReveal(round)
    state.currentRound = round
    state.sealedBids = {}
    state.bidLocked = {}
    state.revealIndex = 0
    state.judgeResult = nil
    state.phase = GameState.PHASE.INFO_REVEAL
    GameState.NotifyChange()
end

-- 进入暗标出价阶段
function GameState.StartSealedBid()
    if state.currentRound == 1 then
        state.timer = Config.GAME.FirstRoundSeconds
    else
        state.timer = Config.GAME.SealedBidSeconds
    end
    state.phase = GameState.PHASE.SEALED_BID
    GameState.NotifyChange()
end

-- 提交暗标出价（可反复修改，以最后一次为准）
function GameState.PlaceSealedBid(playerIdx, amount)
    if state.phase ~= GameState.PHASE.SEALED_BID then return false end
    local player = state.players[playerIdx]
    if not player then return false end

    -- 反作弊：校验资金是否被篡改
    GameState.ValidateMoney(playerIdx)

    if amount < 0 then amount = 0 end
    if amount > player.money then amount = player.money end
    local flooredAmount = math.floor(amount)
    state.sealedBids[playerIdx] = flooredAmount
    state.bidLocked[playerIdx] = true

    print("[GameState] Player " .. playerIdx .. " (" .. player.name .. ") sealed bid: " .. amount)
    return true
end

-- 倒计时结束，锁定所有出价
function GameState.FinalizeSealedBids()
    for idx = 1, #state.players do
        if not state.sealedBids[idx] then
            state.sealedBids[idx] = 0  -- 未出价视为0（弃权）
        end
    end
    -- 记录本轮出价到历史
    local round = state.currentRound
    state.roundBids[round] = {}
    for idx = 1, #state.players do
        local bid = state.sealedBids[idx] or 0
        state.roundBids[round][idx] = bid
    end

    -- 生成揭晓顺序（1→2→3→4）
    state.revealOrder = { 1, 2, 3, 4 }
    state.revealIndex = 0
    state.phase = GameState.PHASE.BID_REVEAL
    print("[GameState] Bids finalized. Entering reveal phase.")
    GameState.NotifyChange()
end

-- 揭晓下一位玩家的出价
function GameState.RevealNextBid()
    state.revealIndex = state.revealIndex + 1
    if state.revealIndex > #state.revealOrder then
        return false  -- 全部揭晓完毕
    end
    local pIdx = state.revealOrder[state.revealIndex]
    local bid = state.sealedBids[pIdx] or 0
    print("[GameState] Reveal #" .. state.revealIndex .. ": Player " .. pIdx
        .. " (" .. state.players[pIdx].name .. ") bid " .. bid)
    GameState.NotifyChange()
    return true
end

-- 执行倍率判定
function GameState.PerformJudgment()
    state.phase = GameState.PHASE.ROUND_JUDGE

    -- 反作弊：校验所有玩家资金
    for idx = 1, #state.players do
        GameState.ValidateMoney(idx)
    end

    -- 收集出价
    local bids = {}
    for idx = 1, #state.players do
        local rawBid = state.sealedBids[idx] or 0
        bids[#bids + 1] = { playerIdx = idx, amount = rawBid, rawAmount = rawBid }
    end
    table.sort(bids, function(a, b) return a.amount > b.amount end)

    local highBid = bids[1].amount
    local highBidder = bids[1].playerIdx
    local highRawBid = bids[1].rawAmount
    local secondBid = bids[2].amount
    local secondBidder = bids[2].playerIdx

    local required = Config.GAME.Multipliers[state.currentRound] or 1.0
    local ratio = 0
    if secondBid > 0 then
        ratio = highBid / secondBid
    elseif highBid > 0 then
        ratio = 999  -- 只有一人出价
    end

    local passed = false
    local isTie = false

    if state.currentRound < 5 then
        -- 第1-4轮：最高价 >= 第二名 × 倍率
        passed = (highBid > 0) and (ratio >= required)
    else
        -- 第5轮：最高价 > 第二名（严格大于）
        if highBid > secondBid and highBid > 0 then
            passed = true
        elseif highBid == secondBid and highBid > 0 then
            -- 平局 → 实时竞拍
            isTie = true
            passed = false
        else
            -- 所有人出价为0
            passed = false
        end
    end

    state.judgeResult = {
        winner = passed and highBidder or 0,
        highBid = highBid,
        highBidder = highBidder,
        secondBid = secondBid,
        secondBidder = secondBidder,
        ratio = ratio,
        required = required,
        passed = passed,
        isTie = isTie,
        allBids = bids,
    }

    if passed then
        state.winner = highBidder
        local actualPay = highRawBid
        state.winnerPaid = actualPay
        GameState.SecureAddMoney(highBidder, -actualPay, "round_winner_pay", "R" .. state.currentRound)
        print("[GameState] Round " .. state.currentRound .. " WINNER: " .. state.players[highBidder].name
            .. " (bid " .. highBid .. ", paid " .. actualPay
            .. ", ratio " .. string.format("%.2f", ratio) .. "x >= " .. required .. "x)")
    elseif isTie then
        print("[GameState] Round " .. state.currentRound .. " TIE at " .. highBid .. ". Entering tiebreak.")
    else
        print("[GameState] Round " .. state.currentRound .. " NO WINNER (ratio "
            .. string.format("%.2f", ratio) .. "x < " .. required .. "x)")
    end

    GameState.NotifyChange()
end

-- ============================================================================
-- 实时竞拍（第4轮平局）
-- ============================================================================

function GameState.SetupTiebreak()
    -- 找出并列最高的玩家
    local maxBid = state.judgeResult.highBid
    state.tiebreakPlayers = {}
    for idx = 1, #state.players do
        if (state.sealedBids[idx] or 0) == maxBid then
            state.tiebreakPlayers[#state.tiebreakPlayers + 1] = idx
        end
    end

    state.currentBid = maxBid
    state.currentBidder = 0
    state.bidHistory = {}
    state.timer = Config.GAME.TiebreakSeconds
    state.phase = GameState.PHASE.TIEBREAK_BID

    print("[GameState] Tiebreak started. Participants: " .. #state.tiebreakPlayers
        .. ", starting bid: " .. maxBid)
    GameState.NotifyChange()
end

-- 实时竞拍出价
function GameState.PlaceTiebreakBid(playerIdx, amount)
    if state.phase ~= GameState.PHASE.TIEBREAK_BID then return false, "非竞拍阶段" end

    -- 检查是否为参与者
    local isParticipant = false
    for _, idx in ipairs(state.tiebreakPlayers) do
        if idx == playerIdx then isParticipant = true; break end
    end
    if not isParticipant then return false, "非参与者" end

    -- 反作弊：校验资金
    GameState.ValidateMoney(playerIdx)

    local player = state.players[playerIdx]
    if amount <= state.currentBid then return false, "出价必须高于当前价" end
    if amount > player.money then return false, "资金不足" end

    state.currentBid = amount
    state.currentBidder = playerIdx
    state.bidHistory[#state.bidHistory + 1] = {
        playerIdx = playerIdx,
        amount = amount,
        time = state.timer,
    }

    -- 重置倒计时
    if state.timer < Config.GAME.TiebreakExtend then
        state.timer = Config.GAME.TiebreakExtend
    end

    print("[GameState] Tiebreak bid: " .. player.name .. " bids " .. amount)
    GameState.NotifyChange()
    return true
end

-- 实时竞拍结束
function GameState.EndTiebreak()
    if state.currentBidder > 0 then
        state.winner = state.currentBidder
        state.winnerPaid = state.currentBid
        GameState.SecureAddMoney(state.currentBidder, -state.currentBid, "tiebreak_winner_pay")
        print("[GameState] Tiebreak winner: " .. state.players[state.currentBidder].name
            .. " paid " .. state.currentBid)
    else
        -- 无人加价，随机选一个并列者
        local idx = state.tiebreakPlayers[math.random(1, #state.tiebreakPlayers)]
        local bid = state.sealedBids[idx] or 0
        state.winner = idx
        state.winnerPaid = bid
        GameState.SecureAddMoney(idx, -bid, "tiebreak_random_pay")
        print("[GameState] Tiebreak no additional bids. Random winner: " .. state.players[idx].name)
    end
end

-- ============================================================================
-- 仓库开箱
-- ============================================================================

function GameState.StartWarehouseOpen()
    state.revealedItemIndex = 0
    state.phase = GameState.PHASE.WAREHOUSE_OPEN
    GameState.NotifyChange()
end

--- 结算：将仓库物品价值加到赢家资金，给输家发福利金
function GameState.SettleWarehouseValue()
    if state.settled then return end  -- 防止重复结算
    state.settled = true

    -- 反作弊：结算前校验资金
    for idx = 1, #state.players do
        GameState.ValidateMoney(idx)
    end

    local winner = state.winner
    if winner <= 0 then return end

    -- 计算仓库物品总价值，仅用于利润计算和输家福利
    -- 赢家获得的是实物（由 GameOverDialog 的回收/入库流程处理变现），不在此处加钱
    local totalValue = GameState.GetWarehouseTotalValue()
    local boostedValue = totalValue
    print("[GameState] Settlement: " .. state.players[winner].name
        .. " warehouse value " .. boostedValue)

    -- 输家福利：如果赢家亏损（付的比物品价值多），每个输家获得亏损额的 1/10
    local profit = boostedValue - (state.winnerPaid or 0)
    if profit < 0 then
        local bonus = math.floor(math.abs(profit) / 10)
        if bonus > 0 then
            for idx = 1, #state.players do
                if idx ~= winner then
                    GameState.SecureAddMoney(idx, bonus, "loser_consolation")
                    print("[GameState] Settlement: " .. state.players[idx].name
                        .. " receives consolation bonus " .. bonus)
                end
            end
        end
    end

    -- 记录战绩（战利品不再自动入库，由 GameOverDialog 的回收/返回流程处理）
    local winnerPlayer = state.players[winner]
    -- 玩家本局出价（人类玩家是 index 1）
    local humanBid = state.sealedBids[1] or state.roundBids[state.currentRound] and state.roundBids[state.currentRound][1] or 0
    -- 取所有轮次中玩家出价最高值
    for _, roundBids in pairs(state.roundBids) do
        local b = roundBids[1] or 0
        if b > humanBid then humanBid = b end
    end
    if winnerPlayer and winnerPlayer.isHuman and SaveSystem.IsReady() then
        SaveSystem.RecordGameResult(true, profit, humanBid)
        SaveSystem.MarkDirty()

        -- 兜底：立即将战利品保存到云端，防止玩家杀进程导致物品丢失
        local PendingSettlement = require("PendingSettlement")
        PendingSettlement.Save(state.warehouseItems, {
            winner = winner,
            winnerPaid = state.winnerPaid or 0,
            warehouseName = GameState.GetWarehouseName(),
            profit = profit,
        })
    elseif SaveSystem.IsReady() then
        -- 人类玩家输了，也记录战绩（传入本局最高出价）
        SaveSystem.RecordGameResult(false, 0, humanBid)
        SaveSystem.MarkDirty()
    end

    GameState.NotifyChange()
end

function GameState.RevealNextItem()
    state.revealedItemIndex = state.revealedItemIndex + 1
    if state.revealedItemIndex > #state.warehouseItems then
        return false  -- 全部展示完毕
    end
    GameState.NotifyChange()
    return true
end

-- ============================================================================
-- 倒计时
-- ============================================================================

function GameState.UpdateTimer(dt)
    if state.phase ~= GameState.PHASE.SEALED_BID
       and state.phase ~= GameState.PHASE.TIEBREAK_BID then
        return
    end
    state.timer = state.timer - dt
    if state.timer <= 0 then
        state.timer = 0
    end
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

function GameState.GetNextTiebreakBidAmount()
    if state.currentBid == 0 then return Config.GAME.MinBidIncrement end
    local increment = Config.CalcBidIncrement(state.currentBid, 0.05)
    return state.currentBid + increment
end

-- 是否为实时竞拍参与者
function GameState.IsTiebreakParticipant(playerIdx)
    for _, idx in ipairs(state.tiebreakPlayers) do
        if idx == playerIdx then return true end
    end
    return false
end

-- ============================================================================
-- Getters
-- ============================================================================

function GameState.GetPhase()          return state.phase end
function GameState.GetPlayers()        return state.players end
function GameState.GetCurrentRound()   return state.currentRound end
function GameState.GetTimer()          return state.timer end
function GameState.GetWarehouseName()  return state.warehouseName end
function GameState.GetWarehouseItems() return state.warehouseItems end
function GameState.GetWarehouseTotalValue()
    -- 校验 secureTotalValue 一致性
    if secureTotalValue then
        local secureVal = secureTotalValue.get()
        if secureVal ~= state.warehouseTotalValue then
            print("[AntiCheat] WARNING: warehouseTotalValue tampered! Restoring.")
            state.warehouseTotalValue = secureVal
        end
    end
    return state.warehouseTotalValue
end
function GameState.GetWarehouseData() return state.warehouseData end
function GameState.GetExpectedValue()      return state.expectedValue or 100000 end
function GameState.GetAssetRequirement()   return state.assetRequirement or 0 end
function GameState.GetSealedBids()     return state.sealedBids end
function GameState.GetBidLocked()      return state.bidLocked end
function GameState.GetRevealIndex()    return state.revealIndex end
function GameState.GetRevealOrder()    return state.revealOrder end
function GameState.GetJudgeResult()    return state.judgeResult end
function GameState.GetTiebreakPlayers() return state.tiebreakPlayers end
function GameState.GetCurrentBid()     return state.currentBid end
function GameState.GetCurrentBidder()  return state.currentBidder end
function GameState.GetBidHistory()     return state.bidHistory end
function GameState.GetRoundBids()      return state.roundBids end
function GameState.GetRevealedItemIndex() return state.revealedItemIndex end
function GameState.GetWinner()         return state.winner end
function GameState.GetWinnerPaid()     return state.winnerPaid end
function GameState.GetMyUserId()           return state.myUserId or 0 end
function GameState.GetWarehouseTypeId()    return state.warehouseTypeId or "grocery" end
function GameState.GetEntryFee()           return state.entryFee or 0 end
function GameState.GetDiffLabel()          return state.diffLabel or "" end
function GameState.GetRegionId()           return state.regionId or "" end

-- ============================================================================
-- 安全资金操作（AntiCheat 集成）
-- ============================================================================

--- 校验玩家资金是否被篡改，被篡改则恢复
GameState.ValidateMoney = function(playerIdx) MoneyManager.ValidateMoney(playerIdx) end

--- 安全修改资金（同时更新明文和 SecureValue，人类玩家自动云端保存 + 记账）
GameState.SecureSetMoney = function(playerIdx, newValue, source, context) MoneyManager.SecureSetMoney(playerIdx, newValue, source, context) end

--- 安全增减资金
GameState.SecureAddMoney = function(playerIdx, delta, source, context) MoneyManager.SecureAddMoney(playerIdx, delta, source, context) end

--- 从云端加载资金（游戏初始化时调用，异步）
GameState.LoadCloudMoney = function(callback) MoneyManager.LoadCloudMoney(callback) end

--- 保存人类玩家资金到云端
GameState.SaveCloudMoney = function() MoneyManager.SaveCloudMoney() end

-- Debug helpers（反作弊保护：生产环境下为空操作）
function GameState.SetTimer(val)
    print("[AntiCheat] SetTimer blocked.")
end
function GameState.AddMoney(playerIdx, amount)
    print("[AntiCheat] AddMoney blocked.")
end

function GameState.SetOnStateChange(fn) state.onStateChange = fn end
function GameState.SetOnMoneyChanged(fn) MoneyManager.SetOnMoneyChanged(fn) end

function GameState.NotifyChange()
    if state.onStateChange then
        state.onStateChange(GameState)
    end
end

return GameState
