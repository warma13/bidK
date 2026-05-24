-- ============================================================================
-- GameState.lua - 游戏状态管理（暗标仓库竞拍版）
-- ============================================================================

---@diagnostic disable: undefined-global
local Config = require("Config")
local UserCache = require("UserCache")
local WarehouseGenerator = require("WarehouseGenerator")
local MoneyManager = require("MoneyManager")
local SkillSystem = require("SkillSystem")
local SaveSystem = require("SaveSystem")
local SeasonPass = require("SeasonPass")
local GameState = {}

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
    roundPropUsage = {},        -- { [round] = { [playerIdx] = propId } } 每轮道具使用记录
    aiProps = {},               -- { [playerIdx] = { { id=propId, used=false }, ... } } AI持有的道具

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

    -- 创建玩家
    state.players = {}
    state.roundBids = {}
    state.roundPropUsage = {}
    state.aiProps = {}

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

        -- 异步获取 TapTap 昵称（使用缓存，避免每局重复请求）
        if myUserId ~= 0 then
            UserCache.GetNickname(myUserId, function(nick)
                state.players[1].name = nick
                GameState.NotifyChange()
            end)
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

    -- 初始化子模块
    MoneyManager.Setup({ state = state })
    SkillSystem.Setup({ state = state, secureAddMoney = MoneyManager.SecureAddMoney, validateMoney = MoneyManager.ValidateMoney })

    -- 通知资金变动（人类玩家初始资金）
    MoneyManager.NotifyMoneyChanged(1, state.players[1].money)

    -- 初始化 AI 道具（按难度/tier 随机分配）
    GameState._InitAIProps(diffIdx)

    print("[GameState] Initialized. Warehouse: " .. state.warehouseName)
    print("[GameState] Items: " .. #state.warehouseItems .. ", Total value: " .. state.warehouseTotalValue)
    for idx, player in ipairs(state.players) do
        print("[GameState] Player " .. idx .. ": " .. player.name .. " (" .. player.character.name
            .. ") money=" .. player.money
            .. " skill=" .. (player.character.activeSkill and player.character.activeSkill.name or "none"))
    end
end

-- ============================================================================
-- AI 道具初始化
-- ============================================================================

--- 按难度为 AI 玩家随机分配若干道具（不同品质）
---@param diffIdx number 难度索引（1=简单, 2=普通, 3=困难...）
function GameState._InitAIProps(diffIdx)
    local Props = require("Config.Props")

    -- ── 按区域 warehouseValue 决定 AI 道具品质权重 ──
    -- 经济学依据（AI 预算 ≈ warehouseValue × 2）：
    --   白=1500  绿=2500  蓝=8000  紫=30k~120k(均~55k)  金=150k~420k(均~270k)
    --   红色道具无金币价格（商城专供），AI 不使用
    local wv = state.expectedValue or 100000

    local REGION_PROP_CONFIG = {
        --                        white green blue purple gold red     min max
        -- 1万场: AI≈9万, 白绿为主, 蓝(8k)偶尔, 紫金买不起
        { maxWV =   50000, w = { white = 10, green = 5,  blue = 1, purple = 0, gold = 0, red = 0 }, count = { 0, 1 } },
        -- 10万场: AI≈16万, 白绿蓝, 紫(3~12万)太贵
        { maxWV =  100000, w = { white = 6,  green = 6,  blue = 3, purple = 0, gold = 0, red = 0 }, count = { 1, 1 } },
        -- 50万场: AI≈80万, 紫(5.5万≈7%预算)偶尔
        { maxWV =  500000, w = { white = 3,  green = 5,  blue = 6, purple = 1, gold = 0, red = 0 }, count = { 1, 2 } },
        -- 100万场: AI≈160万, 紫(5.5万≈3.4%)常见, 金(27万≈17%)偶尔
        { maxWV = 1000000, w = { white = 1,  green = 3,  blue = 5, purple = 3, gold = 1, red = 0 }, count = { 1, 2 } },
        -- 200万场: AI≈300万, 紫常见, 金(27万≈9%)小概率
        { maxWV = 2000000, w = { white = 0,  green = 2,  blue = 4, purple = 4, gold = 1, red = 0 }, count = { 1, 2 } },
        -- 500万场: AI≈800万, 紫(0.7%)日常, 金(3.4%)正常使用
        { maxWV = 5000000, w = { white = 0,  green = 1,  blue = 3, purple = 5, gold = 2, red = 0 }, count = { 2, 3 } },
        -- 1000万场+: AI≈1600万, 金(1.7%)随意买
        { maxWV = math.huge,w= { white = 0,  green = 0,  blue = 2, purple = 4, gold = 3, red = 0 }, count = { 2, 3 } },
    }

    local cfg = REGION_PROP_CONFIG[#REGION_PROP_CONFIG] -- fallback: 最高档
    for _, c in ipairs(REGION_PROP_CONFIG) do
        if wv <= c.maxWV then cfg = c; break end
    end

    local weights  = cfg.w
    local cntRange = cfg.count

    -- diffIdx 高难度额外给 +1 上限
    local d        = diffIdx or 1
    local maxCount = math.min(cntRange[2] + (d >= 3 and 1 or 0), 3)
    local minCount = cntRange[1]

    -- 按 tier 分组所有道具（覆盖白→绿→蓝→紫→金全品质）
    -- 过滤条件：inGame=true 且有金币价格（price字段）——商城专供道具(仅mallPrice)AI不使用
    local byTier = { white = {}, green = {}, blue = {}, purple = {}, gold = {}, red = {} }
    for _, def in ipairs(Props.LIST) do
        local t = def.tier or "white"
        if byTier[t] and def.inGame and def.price then
            byTier[t][#byTier[t] + 1] = def
        end
    end

    -- 构建加权候选池（每个 def 按对应品质权重重复入池）
    local pool = {}
    for tier, w in pairs(weights) do
        if w > 0 and byTier[tier] then
            for _, def in ipairs(byTier[tier]) do
                for _ = 1, w do
                    pool[#pool + 1] = def
                end
            end
        end
    end
    if #pool == 0 then return end

    -- 为每个 AI 玩家独立洗牌后按去重规则分配
    for idx, player in ipairs(state.players) do
        if not player.isHuman then
            local count = (minCount >= maxCount) and minCount
                       or math.random(minCount, maxCount)
            if count == 0 then
                state.aiProps[idx] = {}
            else
                -- 每个 AI 独立洗牌，保证分配多样性
                local shuffled = { table.unpack(pool) }
                for i = #shuffled, 2, -1 do
                    local j = math.random(1, i)
                    shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
                end
                local assigned, seen = {}, {}
                for _, def in ipairs(shuffled) do
                    if not seen[def.id] then
                        seen[def.id] = true
                        assigned[#assigned + 1] = { id = def.id, def = def, used = false }
                        if #assigned >= count then break end
                    end
                end
                state.aiProps[idx] = assigned
                if #assigned > 0 then
                    local names = {}
                    for _, ap in ipairs(assigned) do
                        names[#names + 1] = ap.def.name .. "(" .. ap.def.tier .. ")"
                    end
                    print("[GameState] AI" .. idx .. " [wv=" .. wv .. "] props: " .. table.concat(names, ", "))
                end
            end
        end
    end
end

--- 记录某轮某玩家使用了道具
---@param round number
---@param playerIdx number
---@param propId string
---@param propName string
function GameState.RecordPropUsage(round, playerIdx, propId, propName)
    if not state.roundPropUsage[round] then
        state.roundPropUsage[round] = {}
    end
    state.roundPropUsage[round][playerIdx] = { id = propId, name = propName }
    print("[GameState] Round " .. round .. " player " .. playerIdx .. " used prop: " .. propName)
end

--- 获取每轮道具使用记录
---@return table { [round] = { [playerIdx] = { id, name } } }
function GameState.GetRoundPropUsage()
    return state.roundPropUsage
end

--- 获取 AI 玩家分配的道具列表
---@param playerIdx number
---@return table { { id, def, used }, ... }
function GameState.GetAIProps(playerIdx)
    return state.aiProps[playerIdx] or {}
end

--- 标记某 AI 已使用本轮道具
---@param playerIdx number
---@param propIndex number 在 aiProps[playerIdx] 中的下标
function GameState.MarkAIPropUsed(playerIdx, propIndex)
    local props = state.aiProps[playerIdx]
    if props and props[propIndex] then
        props[propIndex].used = true
    end
end

--- 获取 AI 本轮可用道具（未使用过的）
---@param playerIdx number
---@param round number
---@return table|nil  第一个可用道具的条目，或 nil
function GameState.GetAIAvailableProp(playerIdx, round)
    -- 检查本轮该 AI 是否已使用
    local usage = state.roundPropUsage[round]
    if usage and usage[playerIdx] then return nil end  -- 本轮已用过

    local props = state.aiProps[playerIdx]
    if not props then return nil end
    for i, ap in ipairs(props) do
        if not ap.used then
            return ap, i
        end
    end
    return nil
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
    -- 加括号消除 and/or 运算符优先级歧义（and 比 or 优先级高，括号使意图明确）
    local humanBid = state.sealedBids[1] or (state.roundBids[state.currentRound] and state.roundBids[state.currentRound][1]) or 0
    -- 取所有轮次中玩家出价最高值
    for _, roundBids in pairs(state.roundBids) do
        local b = roundBids[1] or 0
        if b > humanBid then humanBid = b end
    end
    -- 构建完整历史记录（供个人信息页展示）
    local function BuildHistoryRecord(isWin, p, bid, prof)
        -- 汇总仓库物品（只保存展示用的简要信息）
        local items = {}
        for _, it in ipairs(state.warehouseItems) do
            items[#items + 1] = {
                name     = it.name,
                rarity   = it.rarity,
                image    = it.image or "",
                value    = it.baseValue or it.value or 0,
                w        = it.w or 1,
                h        = it.h or 1,
            }
        end
        -- 汇总所有玩家竞价（所有轮次最大出价）
        local playerBids = {}
        for pidx, pl in ipairs(state.players) do
            local maxBid = 0
            for _, rb in pairs(state.roundBids) do
                local b = rb[pidx] or 0
                if b > maxBid then maxBid = b end
            end
            if state.sealedBids[pidx] and state.sealedBids[pidx] > maxBid then
                maxBid = state.sealedBids[pidx]
            end
            playerBids[#playerBids + 1] = {
                name      = pl.name,
                isHuman   = pl.isHuman,
                charName  = pl.character and pl.character.name  or "",
                charAvatar= pl.character and pl.character.avatar or "",
                bid       = maxBid,
                isWinner  = (pidx == state.winner),
            }
        end
        -- 每轮出价快照（用于详情页）
        local roundBidsSnap = {}
        for rnd, rb in pairs(state.roundBids) do
            local row = {}
            for pidx = 1, #state.players do
                row[pidx] = rb[pidx] or 0
            end
            roundBidsSnap[rnd] = row
        end
        -- 每轮道具使用快照 { [rnd] = { [pidx] = { id, name } } }
        local roundPropsSnap = {}
        for rnd, ru in pairs(state.roundPropUsage) do
            local row = {}
            for pidx = 1, #state.players do
                if ru[pidx] then
                    row[pidx] = { id = ru[pidx].id, name = ru[pidx].name }
                end
            end
            roundPropsSnap[rnd] = row
        end
        return {
            timestamp    = os.time(),
            isWin        = isWin,
            warehouseName= GameState.GetWarehouseName(),
            charName     = p.character and p.character.name  or "",
            charAvatar   = p.character and p.character.avatar or "",
            items        = items,
            totalValue   = totalValue,
            bid          = bid,
            profit       = prof,
            players      = playerBids,
            roundBids    = roundBidsSnap,
            roundProps   = roundPropsSnap,
        }
    end

    if winnerPlayer and winnerPlayer.isHuman and SaveSystem.IsReady() then
        -- 统计本局红色藏品数（拍下即算，与后续入库/回收无关）
        local redWon = 0
        for _, it in ipairs(state.warehouseItems) do
            if it.rarity == "red" then redWon = redWon + 1 end
        end
        SaveSystem.RecordGameResult(true, profit, humanBid, redWon)
        SaveSystem.AddGameHistory(BuildHistoryRecord(true, winnerPlayer, humanBid, profit))
        SaveSystem.MarkDirty()

        -- 通行证 XP（赢局：入场费 + 花费 + 利润）
        if SeasonPass.IsReady() then
            SeasonPass.AddGameXP(state.entryFee or 0, humanBid or 0, profit or 0)
        end

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
        local humanPlayer = state.players[1]
        SaveSystem.RecordGameResult(false, 0, humanBid)
        if humanPlayer then
            SaveSystem.AddGameHistory(BuildHistoryRecord(false, humanPlayer, humanBid, 0))
        end

        -- 通行证 XP（输局：入场费 + 出价，无利润加成）
        if SeasonPass.IsReady() then
            SeasonPass.AddGameXP(state.entryFee or 0, humanBid or 0, 0)
        end
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
-- 资金操作
-- ============================================================================

GameState.ValidateMoney  = function(playerIdx) MoneyManager.ValidateMoney(playerIdx) end
GameState.SecureSetMoney = function(playerIdx, newValue, source, context) MoneyManager.SecureSetMoney(playerIdx, newValue, source, context) end
GameState.SecureAddMoney = function(playerIdx, delta, source, context) MoneyManager.SecureAddMoney(playerIdx, delta, source, context) end
GameState.LoadCloudMoney = function(callback) MoneyManager.LoadCloudMoney(callback) end
GameState.SaveCloudMoney = function() MoneyManager.SaveCloudMoney() end

-- ============================================================================
-- 提取模式：直接注入仓库数据（不触碰玩家/轮次状态）
-- ============================================================================

--- 供 ExtractionScreen 复用 LootPanel 时调用：只设置仓库数据和阶段
---@param warehouseData table  { items, grid, totalValue, warehouseName }
function GameState.SetExtractionWarehouse(warehouseData)
    state.warehouseData       = warehouseData
    state.warehouseItems      = warehouseData.items or {}
    state.warehouseName       = warehouseData.warehouseName or ""
    state.warehouseTotalValue = warehouseData.totalValue or 0
    state.warehouseTypeId     = "extraction"
    state.revealedItemIndex   = #state.warehouseItems  -- 不显示搜索图标
    state.phase               = GameState.PHASE.SEALED_BID  -- 非 WAREHOUSE_OPEN/GAME_OVER：启用流光但无搜索动画
end

function GameState.SetOnStateChange(fn) state.onStateChange = fn end
function GameState.SetOnMoneyChanged(fn) MoneyManager.SetOnMoneyChanged(fn) end

function GameState.NotifyChange()
    if state.onStateChange then
        state.onStateChange(GameState)
    end
end

return GameState
