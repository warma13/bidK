-- ============================================================================
-- network/RoomInstance.lua - 房间实例（服务端）
-- 每个房间拥有独立的模块副本，支持多房间并发
-- ============================================================================

local Shared = require("network.Shared")
local Config = require("Config")

local RoomInstance = {}

-- 房间状态常量
RoomInstance.STATE = {
    WAITING  = "waiting",
    PLAYING  = "playing",
    SETTLING = "settling",   -- 结算阶段（玩家可回收物品或入库）
    FINISHED = "finished",
}

-- 结算超时（秒）
local SETTLE_TIMEOUT = 60

-- 排行榜缩放因子
local RANK_SCALE = 10000
local INT32_MAX = 2147483647

-- 需要隔离的模块名列表（require 路径）
local ISOLATED_MODULES = {
    "AntiCheat",
    "MoneyManager",
    "SkillSystem",
    "RevealPlanner",
    "EstimateValue",
    "InfoSystem",
    "GameState",
    "AIPlayer",
    "AI.InfoEstimation",
    "AI.Strategies",
    "AuctionEngine",
}

-- ============================================================================
-- 模块隔离：通过清空 package.loaded 并重新 require 创建全新副本
-- ============================================================================

--- 创建一组独立的模块副本
---@return table modules 隔离后的模块集合
local function CreateModuleSet()
    -- 1. 暂存并清空 package.loaded 中的旧引用
    local saved = {}
    for _, name in ipairs(ISOLATED_MODULES) do
        saved[name] = package.loaded[name]
        package.loaded[name] = nil
    end

    -- 2. 按依赖顺序重新 require，得到全新的副本
    local modules = {}
    modules.AntiCheat       = require("AntiCheat")
    modules.MoneyManager    = require("MoneyManager")
    modules.SkillSystem     = require("SkillSystem")
    modules.RevealPlanner   = require("RevealPlanner")
    modules.EstimateValue   = require("EstimateValue")
    modules.InfoSystem      = require("InfoSystem")
    modules.GameState       = require("GameState")
    modules.AIPlayer        = require("AIPlayer")
    modules.InfoEstimation  = require("AI.InfoEstimation")
    modules.Strategies      = require("AI.Strategies")
    modules.AuctionEngine   = require("AuctionEngine")

    -- 3. 恢复 package.loaded 中的原始引用（不影响其他房间）
    for _, name in ipairs(ISOLATED_MODULES) do
        package.loaded[name] = saved[name]
    end

    return modules
end

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 广播事件到房间内所有真人玩家
local function BroadcastToRoom(room, eventName, data)
    local vm = Shared.PackEvent(data)
    for _, slot in ipairs(room.slots) do
        if slot.connection then
            slot.connection:SendRemoteEvent(eventName, true, vm)
        end
    end
end

--- 发送事件到指定槽位
local function SendToSlot(room, slotIdx, eventName, data)
    local slot = room.slots[slotIdx]
    if not slot or not slot.connection then return end
    local vm = Shared.PackEvent(data)
    slot.connection:SendRemoteEvent(eventName, true, vm)
end

-- ============================================================================
-- 注册引擎回调（从旧 Server.lua 迁移，使用隔离的模块引用）
-- ============================================================================

local function RegisterEngineCallbacks(room)
    local m = room.modules
    local GS = m.GameState
    local AE = m.AuctionEngine

    GS.SetOnStateChange(function(gs)
        BroadcastToRoom(room, Shared.EVENTS.S_PHASE_CHANGE, {
            phase = gs.GetPhase(),
            round = gs.GetCurrentRound(),
            timer = gs.GetTimer(),
        })
    end)

    GS.SetOnMoneyChanged(function(playerIdx, newValue)
        BroadcastToRoom(room, Shared.EVENTS.S_MONEY_UPDATE, {
            playerIdx = playerIdx,
            money = newValue,
        })
    end)

    AE.SetOnInfoRevealed(function(round, publicInfos, skillInfos)
        BroadcastToRoom(room, Shared.EVENTS.S_INFO_REVEALED, {
            round = round,
            publicInfos = publicInfos,
        })
        -- 私密线索只发给对应真人
        if skillInfos then
            for playerIdx, skillInfo in pairs(skillInfos) do
                local players = GS.GetPlayers()
                local player = players[playerIdx]
                if player and player.isHuman then
                    -- 找到对应 slot
                    for slotIdx, slot in ipairs(room.slots) do
                        if slot.userId and player.userId and slot.userId == player.userId then
                            SendToSlot(room, slotIdx, Shared.EVENTS.S_PRIVATE_INFO, {
                                round = round,
                                playerIdx = playerIdx,
                                skillInfo = skillInfo,
                            })
                            break
                        end
                    end
                end
            end
        end
    end)

    AE.SetOnAISealedBidConfirmed(function(playerIdx)
        BroadcastToRoom(room, Shared.EVENTS.S_AI_BID_CONFIRMED, {
            playerIdx = playerIdx,
        })
    end)

    AE.SetOnBidRevealed(function(revealIndex, playerIdx, amount)
        BroadcastToRoom(room, Shared.EVENTS.S_BID_REVEALED, {
            revealIndex = revealIndex,
            playerIdx = playerIdx,
            amount = amount,
        })
    end)

    AE.SetOnJudgeResult(function(result)
        local serialResult = {
            winner = result.winner,
            highBid = result.highBid,
            highBidder = result.highBidder,
            secondBid = result.secondBid,
            secondBidder = result.secondBidder,
            ratio = result.ratio,
            required = result.required,
            passed = result.passed,
            isTie = result.isTie,
        }
        if result.allBids then
            serialResult.allBids = {}
            for i, b in ipairs(result.allBids) do
                serialResult.allBids[i] = {
                    playerIdx = b.playerIdx,
                    amount = b.amount,
                    rawAmount = b.rawAmount,
                }
            end
        end
        BroadcastToRoom(room, Shared.EVENTS.S_JUDGE_RESULT, { result = serialResult })
    end)

    AE.SetOnTiebreakStart(function(tiebreakPlayers)
        BroadcastToRoom(room, Shared.EVENTS.S_TIEBREAK_START, {
            tiebreakPlayers = tiebreakPlayers,
            startBid = GS.GetCurrentBid(),
            timer = GS.GetTimer(),
        })
    end)

    AE.SetOnBidPlaced(function(playerIdx, amount)
        BroadcastToRoom(room, Shared.EVENTS.S_BID_PLACED, {
            playerIdx = playerIdx,
            amount = amount,
        })
    end)

    AE.SetOnWarehouseOpen(function()
        BroadcastToRoom(room, Shared.EVENTS.S_WAREHOUSE_OPEN, {
            winner = GS.GetWinner(),
            winnerPaid = GS.GetWinnerPaid(),
        })
    end)

    AE.SetOnItemRevealed(function(itemIndex, item)
        BroadcastToRoom(room, Shared.EVENTS.S_ITEM_REVEALED, {
            itemIndex = itemIndex,
            item = {
                idx = item.idx,
                name = item.name,
                rarity = item.rarity,
                category = item.category,
                value = item.value,
                desc = item.desc,
                icon = item.icon,
                image = item.image,
            },
        })
    end)

    AE.SetOnGameOver(function()
        local players = GS.GetPlayers()
        local winner = GS.GetWinner()
        local winnerPaid = GS.GetWinnerPaid()
        local warehouseTotalValue = GS.GetWarehouseTotalValue()

        -- 收集每轮赢家信息
        local roundResults = GS.GetRoundResults and GS.GetRoundResults() or {}

        -- 构建每位玩家的完整结算数据
        local finalPlayers = {}
        for idx, p in ipairs(players) do
            local pData = {
                idx = idx,
                name = p.name,
                moneyBeforeGame = p.moneyBeforeGame or (p.money + (winnerPaid or 0)),
                entryFee = room.entryFee or 0,
                moneyInGame = p.moneyInGame or p.money,
                moneyAfterGame = p.money,
                characterId = p.character and p.character.id or nil,
                characterName = p.character and p.character.name or nil,
                roundsWon = {},
                itemsWon = {},
                winningBid = 0,
                bonus = 0,
            }

            -- 如果是赢家，记录赢得的物品
            if idx == winner then
                pData.winningBid = winnerPaid or 0
                -- 物品从 warehouse items 获取
                local warehouseItems = GS.GetWarehouseItems()
                for _, item in ipairs(warehouseItems) do
                    pData.itemsWon[#pData.itemsWon + 1] = {
                        name = item.name,
                        rarity = item.rarity,
                        baseValue = item.baseValue or item.value or 0,
                        w = item.w,
                        h = item.h,
                        category = item.category,
                        desc = item.desc,
                        icon = item.icon,
                        image = item.image,
                    }
                end
            end

            finalPlayers[idx] = pData
        end

        -- 进入结算阶段
        room.state = RoomInstance.STATE.SETTLING
        room.settleTimer = SETTLE_TIMEOUT
        room.settledCount = 0
        room.humanCount = 0
        room.settleData = {}

        -- 初始化每个真人玩家的结算数据
        for slotIdx, slot in pairs(room.slots) do
            if slot.userId then
                room.humanCount = room.humanCount + 1
                local playerIdx = RoomInstance.FindPlayerIdx(room, slot.userId)
                local pData = playerIdx and finalPlayers[playerIdx] or nil
                room.settleData[slotIdx] = {
                    userId = slot.userId,
                    playerIdx = playerIdx,
                    moneyAfterGame = pData and pData.moneyAfterGame or 0,
                    itemsWon = pData and pData.itemsWon or {},
                    pendingItems = {},
                    recycledMoney = 0,
                    settled = false,
                }
                -- 复制 itemsWon 到 pendingItems（可操作副本）
                local sd = room.settleData[slotIdx]
                for _, item in ipairs(sd.itemsWon) do
                    sd.pendingItems[#sd.pendingItems + 1] = item
                end
            end
        end

        print("[Room " .. room.id .. "] Game over → SETTLING ("
            .. room.humanCount .. " humans, timeout=" .. SETTLE_TIMEOUT .. "s)")

        -- 广播 S_GAME_OVER
        BroadcastToRoom(room, Shared.EVENTS.S_GAME_OVER, {
            winner = winner,
            winnerPaid = winnerPaid,
            warehouseTotalValue = warehouseTotalValue,
            players = finalPlayers,
            roundResults = roundResults,
            settleTimeout = SETTLE_TIMEOUT,
        })

        -- 立即写入金币（步骤1：游戏结束时写金币，不含物品）
        RoomInstance._PersistMoney(room)
    end)

    AE.SetOnActiveSkillUsed(function(playerIdx, skillInfo, resultData)
        local serialSkill = {
            name = skillInfo.name,
            effect = skillInfo.effect,
            remaining = skillInfo.remaining,
        }
        BroadcastToRoom(room, Shared.EVENTS.S_SKILL_USED, {
            playerIdx = playerIdx,
            skillInfo = serialSkill,
            resultData = resultData,
        })
    end)
end

-- ============================================================================
-- 房间创建和管理
-- ============================================================================

local nextRoomId_ = 1

--- 创建新房间
---@param roomKey string 房间类型键，如 "oldtown_1"
---@param regionId string 区域 ID
---@param diffIdx number 难度索引
---@return table room 房间实例
function RoomInstance.Create(roomKey, regionId, diffIdx)
    local room = {
        id = nextRoomId_,
        key = roomKey,
        regionId = regionId,
        diffIdx = diffIdx,
        state = RoomInstance.STATE.WAITING,
        slots = {},          -- { [1..4] = { userId, connection, nickname, charIdx } }
        playerCount = 0,
        maxPlayers = 4,
        modules = nil,       -- 隔离的模块集（游戏开始时创建）
        waitTimer = 0,       -- 等待计时
        waitTimerActive = false,
        lastTimerSync = -1,
    }
    nextRoomId_ = nextRoomId_ + 1
    print("[Room " .. room.id .. "] Created: key=" .. roomKey .. " region=" .. regionId .. " diff=" .. diffIdx)
    return room
end

--- 添加玩家到房间
---@param room table 房间实例
---@param userId number 用户 ID
---@param connection userdata 网络连接
---@param nickname string 昵称
---@return number|nil slotIdx 分配的槽位，nil 表示房间已满
function RoomInstance.AddPlayer(room, userId, connection, nickname, charIdx)
    if room.state ~= RoomInstance.STATE.WAITING then return nil end
    if room.playerCount >= room.maxPlayers then return nil end

    -- 找空槽位
    local slotIdx = nil
    for i = 1, room.maxPlayers do
        if not room.slots[i] then
            slotIdx = i
            break
        end
    end
    if not slotIdx then return nil end

    room.slots[slotIdx] = {
        userId = userId,
        connection = connection,
        nickname = nickname or ("Player" .. slotIdx),
        charIdx = charIdx,  -- 玩家选择的角色索引（允许与其他玩家相同）
    }
    room.playerCount = room.playerCount + 1

    -- 首人加入，启动等待计时
    if room.playerCount == 1 and not room.waitTimerActive then
        room.waitTimerActive = true
        room.waitTimer = 0
        print("[Room " .. room.id .. "] First player joined, starting 15s wait timer")
    end

    print("[Room " .. room.id .. "] Player " .. userId .. " joined slot " .. slotIdx
        .. " (" .. room.playerCount .. "/" .. room.maxPlayers .. ")")

    return slotIdx
end

--- 从房间移除玩家（仅 WAITING 状态）
---@param room table 房间实例
---@param userId number 用户 ID
---@return boolean 是否成功移除
function RoomInstance.RemovePlayer(room, userId)
    if room.state ~= RoomInstance.STATE.WAITING then return false end

    for i, slot in pairs(room.slots) do
        if slot.userId == userId then
            room.slots[i] = nil
            room.playerCount = room.playerCount - 1
            print("[Room " .. room.id .. "] Player " .. userId .. " left (" .. room.playerCount .. "/" .. room.maxPlayers .. ")")
            return true
        end
    end
    return false
end

--- 标记断线玩家（PLAYING 状态，保留槽位但清除 connection）
---@param room table
---@param userId number
function RoomInstance.MarkDisconnected(room, userId)
    for _, slot in pairs(room.slots) do
        if slot.userId == userId then
            slot.connection = nil
            print("[Room " .. room.id .. "] Player " .. userId .. " disconnected (slot preserved)")
            return
        end
    end
end

--- 构建玩家配置（从房间槽位信息 + AI 填充）
local function BuildPlayersConfig(room)
    local totalChars = #Config.CHARACTERS

    local playersConfig = {}

    -- 真人玩家（按槽位顺序，使用玩家选择的角色）
    for slotIdx = 1, room.maxPlayers do
        local slot = room.slots[slotIdx]
        if slot then
            -- 使用玩家选择的角色，如果无效则随机
            local charIdx = slot.charIdx
            if not charIdx or charIdx < 1 or charIdx > totalChars then
                charIdx = math.random(1, totalChars)
            end
            slot.charIdx = charIdx
            playersConfig[#playersConfig + 1] = {
                name = slot.nickname or ("Player" .. slotIdx),
                isHuman = true,
                charIdx = charIdx,
                userId = slot.userId,
            }
        end
    end

    -- AI 填充空位（随机角色）
    local aiNamePool = {}
    for _, n in ipairs(Config.AI_NAMES) do aiNamePool[#aiNamePool + 1] = n end
    for i = #aiNamePool, 2, -1 do
        local j = math.random(1, i)
        aiNamePool[i], aiNamePool[j] = aiNamePool[j], aiNamePool[i]
    end
    local aiIdx = 1
    while #playersConfig < room.maxPlayers do
        local charIdx = math.random(1, totalChars)
        playersConfig[#playersConfig + 1] = {
            name = aiNamePool[aiIdx] or ("AI_" .. aiIdx),
            isHuman = false,
            charIdx = charIdx,
        }
        aiIdx = aiIdx + 1
    end

    return playersConfig
end

--- 开始游戏（入口：先做入场费校验，再初始化）
---@param room table 房间实例
function RoomInstance.StartGame(room)
    if room.state ~= RoomInstance.STATE.WAITING then return end
    room.waitTimerActive = false

    -- 查找区域和难度配置
    local region = Config.REGIONS[1]
    for _, r in ipairs(Config.REGIONS) do
        if r.id == room.regionId then region = r; break end
    end
    local diff = region.difficulties and region.difficulties[room.diffIdx]
    local entryFee = diff and diff.entryFee or 0
    room.entryFee = entryFee
    room.startingMoney = diff and diff.startingMoney or 800000

    print("[Room " .. room.id .. "] Starting game with " .. room.playerCount .. " real players + "
        .. (room.maxPlayers - room.playerCount) .. " AI (entryFee=" .. entryFee .. ")")

    if entryFee <= 0 then
        -- 免费场：跳过入场费校验
        RoomInstance._StartGameAfterValidation(room, {})
        return
    end

    -- 异步校验入场费：批量查询所有真人玩家余额
    local humanSlots = {}
    for slotIdx = 1, room.maxPlayers do
        local slot = room.slots[slotIdx]
        if slot and slot.userId then
            humanSlots[#humanSlots + 1] = { slotIdx = slotIdx, slot = slot }
        end
    end

    if #humanSlots == 0 then
        RoomInstance._StartGameAfterValidation(room, {})
        return
    end

    -- 使用 BatchGet 多人模式查询所有真人余额
    local batchGet = serverCloud:BatchGet() ---@diagnostic disable-line: undefined-global
    for _, hs in ipairs(humanSlots) do
        batchGet:Player(hs.slot.userId)
    end
    batchGet:Key("player_money")
    batchGet:Fetch({
        ok = function(results)
            local failedSlots = {}
            -- results 是按 Player 顺序返回的数组
            for i, hs in ipairs(humanSlots) do
                local r = results[i]
                local money = 0
                if r and r.score and type(r.score.player_money) == "number" then
                    money = r.score.player_money
                elseif r and r.iscore then
                    money = r.iscore.player_money or 0
                end

                if money < entryFee then
                    -- 余额不足
                    failedSlots[#failedSlots + 1] = hs
                    print("[Room " .. room.id .. "] Player " .. hs.slot.userId
                        .. " insufficient funds: " .. money .. " < " .. entryFee)
                    -- 通知该玩家加入失败
                    if hs.slot.connection then
                        local vm = Shared.PackEvent({ reason = "insufficient_funds" })
                        hs.slot.connection:SendRemoteEvent(Shared.EVENTS.S_JOIN_FAILED, true, vm)
                    end
                else
                    -- 余额充足，记录原始金额用于结算展示
                    hs.slot.moneyBeforeGame = money
                end
            end

            -- 移除失败的玩家
            for _, hs in ipairs(failedSlots) do
                room.slots[hs.slotIdx] = nil
                room.playerCount = room.playerCount - 1
            end

            -- 扣除入场费（批量写入）
            local deductSlots = {}
            for _, hs in ipairs(humanSlots) do
                local stillIn = room.slots[hs.slotIdx] ~= nil
                if stillIn then
                    deductSlots[#deductSlots + 1] = hs
                end
            end

            if #deductSlots > 0 then
                -- 逐个扣除（BatchCommit 只支持单 uid）
                local deductPending = #deductSlots
                for _, hs in ipairs(deductSlots) do
                    local newMoney = (hs.slot.moneyBeforeGame or 0) - entryFee
                    serverCloud:BatchSet(hs.slot.userId) ---@diagnostic disable-line: undefined-global
                        :Set("player_money", newMoney)
                        :Save("entry_fee_deduct", {
                            ok = function()
                                print("[Room " .. room.id .. "] Deducted entryFee " .. entryFee
                                    .. " from player " .. hs.slot.userId
                                    .. " (remaining=" .. newMoney .. ")")
                                deductPending = deductPending - 1
                                if deductPending <= 0 then
                                    RoomInstance._StartGameAfterValidation(room, deductSlots)
                                end
                            end,
                            error = function(code, reason)
                                print("[Room " .. room.id .. "] WARNING: Failed to deduct entryFee for "
                                    .. hs.slot.userId .. ": " .. tostring(reason))
                                deductPending = deductPending - 1
                                if deductPending <= 0 then
                                    RoomInstance._StartGameAfterValidation(room, deductSlots)
                                end
                            end,
                        })
                end
            else
                -- 所有人都失败了（理论上不太可能）
                RoomInstance._StartGameAfterValidation(room, {})
            end
        end,
        error = function(code, reason)
            print("[Room " .. room.id .. "] WARNING: BatchGet failed (" .. tostring(reason)
                .. "), starting without fee check")
            RoomInstance._StartGameAfterValidation(room, {})
        end,
    })
end

--- 入场费校验完成后真正初始化游戏
---@param room table
---@param deductedSlots table 已成功扣费的玩家槽位信息
function RoomInstance._StartGameAfterValidation(room, deductedSlots)
    room.state = RoomInstance.STATE.PLAYING

    -- 创建隔离的模块副本
    room.modules = CreateModuleSet()
    local m = room.modules

    -- 依赖注入：将隔离后的模块实例互相注入（解决文件级 require 缓存问题）
    m.EstimateValue.InjectDeps(m.GameState)
    m.InfoEstimation.InjectDeps(m.EstimateValue, m.AntiCheat)
    m.Strategies.InjectDeps(m.GameState, m.InfoSystem, m.EstimateValue)
    m.AIPlayer.InjectDeps(m.GameState, m.Strategies, m.InfoEstimation, m.AntiCheat)
    m.AuctionEngine.InjectDeps(m.GameState, m.AIPlayer, m.InfoSystem)

    -- 构建扣费后的金额映射（userId → 扣费后金额）
    local moneyAfterFee = {}
    for _, hs in ipairs(deductedSlots) do
        if hs.slot and hs.slot.userId then
            moneyAfterFee[hs.slot.userId] = (hs.slot.moneyBeforeGame or 0) - (room.entryFee or 0)
        end
    end

    -- 构建玩家配置
    local playersConfig = BuildPlayersConfig(room)

    -- 将真人玩家的 money 设为扣费后金额
    for _, pc in ipairs(playersConfig) do
        if pc.isHuman and pc.userId and moneyAfterFee[pc.userId] then
            pc.startingMoney = moneyAfterFee[pc.userId]
            pc.moneyBeforeGame = (moneyAfterFee[pc.userId] + (room.entryFee or 0))
        end
    end

    -- 查找区域配置和仓库类型
    local region = Config.REGIONS[1]
    for _, r in ipairs(Config.REGIONS) do
        if r.id == room.regionId then region = r; break end
    end
    local warehouseTypes = region.warehouseTypes or {}
    local warehouseTypeId = warehouseTypes[math.random(1, math.max(1, #warehouseTypes))]

    -- 初始化引擎（headless 模式）
    m.MoneyManager.SetServerMode(true)
    m.AuctionEngine.SetHeadless(true)
    m.AuctionEngine.Init(1, room.regionId, room.diffIdx, warehouseTypeId, playersConfig)

    -- 注册引擎回调
    RegisterEngineCallbacks(room)

    -- 广播 S_GAME_INIT
    local GS = m.GameState
    local players = GS.GetPlayers()
    local serializedPlayers = Shared.SerializePlayers(players)

    local items = GS.GetWarehouseItems()
    local serializedItems = {}
    for i, item in ipairs(items) do
        serializedItems[i] = {
            idx = item.idx,
            name = item.name,
            rarity = item.rarity,
            category = item.category,
            desc = item.desc,
            icon = item.icon,
            image = item.image,
            w = item.w,
            h = item.h,
            gridRow = item.gridRow,
            gridCol = item.gridCol,
        }
    end

    local warehouseData = GS.GetWarehouseData()
    local grid = warehouseData and warehouseData.grid or nil

    -- 给每个真人玩家发送 S_GAME_INIT（含各自的 mySlot）
    local userIdToPlayerIdx = {}
    for idx, p in ipairs(players) do
        if p.isHuman and p.userId then
            userIdToPlayerIdx[p.userId] = idx
        end
    end

    for slotIdx, slot in pairs(room.slots) do
        if slot.connection then
            local playerIdx = userIdToPlayerIdx[slot.userId] or slotIdx
            local initData = {
                players = serializedPlayers,
                warehouseName = GS.GetWarehouseName(),
                warehouseItems = serializedItems,
                warehouseTypeId = warehouseTypeId,
                regionId = room.regionId,
                diffLabel = GS.GetDiffLabel(),
                entryFee = room.entryFee or 0,
                expectedValue = GS.GetExpectedValue(),
                grid = grid,
                mySlot = playerIdx,
                config = {
                    maxRounds = Config.GAME.MaxRounds,
                    sealedBidSeconds = Config.GAME.SealedBidSeconds,
                    firstRoundSeconds = Config.GAME.FirstRoundSeconds,
                    tiebreakSeconds = Config.GAME.TiebreakSeconds,
                    multipliers = Config.GAME.Multipliers,
                },
            }
            local vm = Shared.PackEvent(initData)
            slot.connection:SendRemoteEvent(Shared.EVENTS.S_GAME_INIT, true, vm)
        end
    end

    -- 启动游戏
    m.AuctionEngine.StartGame()
    print("[Room " .. room.id .. "] Game initialized and started")
end

--- 帧更新
---@param room table
---@param dt number
function RoomInstance.Update(room, dt)
    if room.state == RoomInstance.STATE.WAITING then
        -- 等待超时检查
        if room.waitTimerActive then
            room.waitTimer = room.waitTimer + dt
            if room.waitTimer >= 15.0 then
                room.waitTimerActive = false
                print("[Room " .. room.id .. "] Wait timeout! Starting with " .. room.playerCount .. " real players")
                RoomInstance.StartGame(room)
            end
        end
        return
    end

    if room.state == RoomInstance.STATE.PLAYING then
        local m = room.modules
        if not m then return end

        -- 驱动 AuctionEngine
        m.AuctionEngine.Update(dt)

        -- 倒计时同步
        local GS = m.GameState
        local phase = GS.GetPhase()
        if phase == GS.PHASE.SEALED_BID or phase == GS.PHASE.TIEBREAK_BID then
            local timer = GS.GetTimer()
            local sec = math.floor(timer)
            if sec ~= room.lastTimerSync then
                room.lastTimerSync = sec
                BroadcastToRoom(room, Shared.EVENTS.S_TIMER_SYNC, {
                    timer = timer,
                    phase = phase,
                })
            end
        else
            room.lastTimerSync = -1
        end
        return
    end

    if room.state == RoomInstance.STATE.SETTLING then
        -- 结算超时检查
        room.settleTimer = room.settleTimer - dt
        if room.settleTimer <= 0 then
            print("[Room " .. room.id .. "] Settle timeout! Auto-settling all remaining players")
            RoomInstance._AutoSettleAll(room)
        end
    end
end

--- 处理暗标出价（路由到房间内的 GameState）
---@param room table
---@param userId number
---@param amount number
function RoomInstance.HandleSealedBid(room, userId, amount)
    if room.state ~= RoomInstance.STATE.PLAYING then return end
    local m = room.modules
    if not m then return end

    -- 找到 userId 对应的 playerIdx
    local playerIdx = RoomInstance.FindPlayerIdx(room, userId)
    if not playerIdx then return end

    local ok = m.GameState.PlaceSealedBid(playerIdx, amount)
    if ok then
        print("[Room " .. room.id .. "] Player " .. userId .. " (idx=" .. playerIdx .. ") sealed bid: " .. amount)
        -- 真人玩家用 S_PLAYER_BID_CONFIRMED（区别于 AI 的 S_AI_BID_CONFIRMED）
        BroadcastToRoom(room, Shared.EVENTS.S_PLAYER_BID_CONFIRMED, { playerIdx = playerIdx })
    end
end

--- 处理实时竞拍出价
function RoomInstance.HandleTiebreakBid(room, userId, amount)
    if room.state ~= RoomInstance.STATE.PLAYING then return end
    local m = room.modules
    if not m then return end

    local playerIdx = RoomInstance.FindPlayerIdx(room, userId)
    if not playerIdx then return end

    local ok, err = m.GameState.PlaceTiebreakBid(playerIdx, amount)
    if ok then
        print("[Room " .. room.id .. "] Player " .. userId .. " tiebreak bid: " .. amount)
    else
        print("[Room " .. room.id .. "] Player " .. userId .. " tiebreak bid rejected: " .. tostring(err))
    end
end

--- 处理技能使用
function RoomInstance.HandleUseSkill(room, userId)
    if room.state ~= RoomInstance.STATE.PLAYING then return end
    local m = room.modules
    if not m then return end

    local playerIdx = RoomInstance.FindPlayerIdx(room, userId)
    if not playerIdx then return end

    local skillInfo = m.GameState.GetActiveSkillInfo(playerIdx)
    if not skillInfo then return end
    if skillInfo.remaining <= 0 then return end
    if skillInfo.activatedThisRound then return end

    local phase = m.GameState.GetPhase()
    local allowedPhase = (phase == m.GameState.PHASE.SEALED_BID or phase == m.GameState.PHASE.INFO_REVEAL)
    if not allowedPhase then
        if skillInfo.effect == "all_in" and phase == m.GameState.PHASE.BID_REVEAL then
            allowedPhase = true
        end
    end
    if not allowedPhase then return end

    local ok = m.GameState.UseActiveSkill(playerIdx)
    if not ok then return end

    print("[Room " .. room.id .. "] Player " .. userId .. " used skill: " .. (skillInfo.name or "unknown"))

    if skillInfo.effect == "reveal_top3" then
        m.InfoSystem.RevealTopItems(3, 1)
    end
end

--- 处理跳过开箱
function RoomInstance.HandleSkipWarehouse(room)
    if room.state ~= RoomInstance.STATE.PLAYING then return end
    local m = room.modules
    if not m then return end
    m.AuctionEngine.SkipWarehouseOpen()
end

--- 查找 userId 对应的 playerIdx
---@param room table
---@param userId number
---@return number|nil
function RoomInstance.FindPlayerIdx(room, userId)
    local m = room.modules
    if not m then return nil end
    local players = m.GameState.GetPlayers()
    for idx, p in ipairs(players) do
        if p.isHuman and p.userId == userId then
            return idx
        end
    end
    return nil
end

--- 获取房间内连接的真人数量
function RoomInstance.GetConnectedCount(room)
    local count = 0
    for _, slot in pairs(room.slots) do
        if slot.connection then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- 结算阶段处理
-- ============================================================================

--- 处理物品回收请求（C_RECYCLE_ITEMS）
---@param room table
---@param userId number
---@param rarities table 要回收的品质列表，如 { "white", "green" }
function RoomInstance.HandleRecycleItems(room, userId, rarities)
    if room.state ~= RoomInstance.STATE.SETTLING then return end

    -- 找到对应的 slotIdx
    local slotIdx = nil
    for si, slot in pairs(room.slots) do
        if slot.userId == userId then slotIdx = si; break end
    end
    if not slotIdx or not room.settleData[slotIdx] then return end
    local sd = room.settleData[slotIdx]
    if sd.settled then return end

    -- 没有物品可回收（输家）
    if #sd.pendingItems == 0 then
        SendToSlot(room, slotIdx, Shared.EVENTS.S_RECYCLE_RESULT, {
            recycledItems = {},
            totalValue = 0,
            remainingItems = {},
        })
        return
    end

    -- 构建品质筛选表
    local selectedRarities = {}
    for _, r in ipairs(rarities) do
        selectedRarities[r] = true
    end

    -- 使用 RecycleManager 按品质筛选
    local RecycleManager = require("RecycleManager")
    local toRecycle, toKeep = RecycleManager.FilterByRarity(sd.pendingItems, selectedRarities)
    local totalValue = RecycleManager.GetTotalRecycleValue(toRecycle)

    -- 更新结算数据
    sd.pendingItems = toKeep
    sd.recycledMoney = sd.recycledMoney + totalValue
    sd.moneyAfterGame = sd.moneyAfterGame + totalValue

    -- 序列化回收结果
    local recycledSerialized = {}
    for i, item in ipairs(toRecycle) do
        recycledSerialized[i] = {
            name = item.name,
            rarity = item.rarity,
            baseValue = item.baseValue or item.value or 0,
            recycleValue = RecycleManager.GetRecycleValue(item),
        }
    end
    local remainingSerialized = {}
    for i, item in ipairs(toKeep) do
        remainingSerialized[i] = {
            name = item.name,
            rarity = item.rarity,
            baseValue = item.baseValue or item.value or 0,
            w = item.w,
            h = item.h,
        }
    end

    print("[Room " .. room.id .. "] Player " .. userId .. " recycled "
        .. #toRecycle .. " items for " .. totalValue)

    SendToSlot(room, slotIdx, Shared.EVENTS.S_RECYCLE_RESULT, {
        recycledItems = recycledSerialized,
        totalValue = totalValue,
        remainingItems = remainingSerialized,
    })
end

--- 处理离开结算请求（C_LEAVE_SETTLE）
---@param room table
---@param userId number
function RoomInstance.HandleLeaveSettle(room, userId)
    if room.state ~= RoomInstance.STATE.SETTLING then return end

    local slotIdx = nil
    for si, slot in pairs(room.slots) do
        if slot.userId == userId then slotIdx = si; break end
    end
    if not slotIdx or not room.settleData[slotIdx] then return end
    local sd = room.settleData[slotIdx]
    if sd.settled then return end

    print("[Room " .. room.id .. "] Player " .. userId .. " requesting leave settle")

    -- 剩余物品全部入库（无 WarehouseGrid 时直接全存）
    local storedItems = sd.pendingItems
    local autoRecycledItems = {}
    local autoRecycledValue = 0

    -- TODO: 如果有 WarehouseGrid 实例可用，使用 RecycleManager.AutoRecycleForFit
    -- 当前简化处理：所有剩余物品直接入库

    -- 更新最终金额
    sd.moneyAfterGame = sd.moneyAfterGame + autoRecycledValue
    sd.finalMoney = sd.moneyAfterGame
    sd.finalItems = storedItems
    sd.settled = true

    -- 持久化到 serverCloud（步骤2：写入金币 + 物品存档）
    RoomInstance._PersistSettlement(room, slotIdx)

    -- 序列化入库结果
    local storedSerialized = {}
    for i, item in ipairs(storedItems) do
        storedSerialized[i] = {
            name = item.name,
            rarity = item.rarity,
            baseValue = item.baseValue or item.value or 0,
        }
    end

    SendToSlot(room, slotIdx, Shared.EVENTS.S_SETTLE_COMPLETE, {
        storedItems = storedSerialized,
        autoRecycledItems = {},
        autoRecycledValue = autoRecycledValue,
        finalMoney = sd.finalMoney,
    })

    -- 通知该玩家可以返回大厅
    SendToSlot(room, slotIdx, Shared.EVENTS.S_RETURN_LOBBY, {})

    -- 检查是否所有人都结算完
    RoomInstance._CheckAllSettled(room)
end

--- 自动结算所有未结算的玩家（超时/断线时调用）
function RoomInstance._AutoSettleAll(room)
    for slotIdx, sd in pairs(room.settleData) do
        if not sd.settled then
            RoomInstance._AutoSettleForPlayer(room, slotIdx)
        end
    end
    -- 强制标记完成
    room.state = RoomInstance.STATE.FINISHED
    print("[Room " .. room.id .. "] All players auto-settled, room FINISHED")
end

--- 自动结算单个玩家（全部物品入库/回收）
---@param room table
---@param slotIdx number
function RoomInstance._AutoSettleForPlayer(room, slotIdx)
    local sd = room.settleData[slotIdx]
    if not sd or sd.settled then return end

    print("[Room " .. room.id .. "] Auto-settling player (slot=" .. slotIdx
        .. " userId=" .. tostring(sd.userId) .. ")")

    -- 简化处理：所有剩余物品直接入库
    sd.finalMoney = sd.moneyAfterGame
    sd.finalItems = sd.pendingItems
    sd.settled = true

    -- 持久化
    RoomInstance._PersistSettlement(room, slotIdx)
end

--- 检查是否所有真人都已结算
function RoomInstance._CheckAllSettled(room)
    local allDone = true
    for _, sd in pairs(room.settleData) do
        if not sd.settled then
            allDone = false
            break
        end
    end
    if allDone then
        room.state = RoomInstance.STATE.FINISHED
        print("[Room " .. room.id .. "] All players settled, room FINISHED")
    end
end

-- ============================================================================
-- serverCloud 持久化
-- ============================================================================

--- 将金币排行榜值转换
local function ToRankValue(amount)
    local v = math.floor(amount / RANK_SCALE)
    if v > INT32_MAX then v = INT32_MAX end
    return v
end

--- 游戏结束时立即写入所有真人的金币（步骤1）
function RoomInstance._PersistMoney(room)
    for slotIdx, sd in pairs(room.settleData) do
        if sd.userId and sd.moneyAfterGame then
            serverCloud:BatchSet(sd.userId) ---@diagnostic disable-line: undefined-global
                :Set("player_money", sd.moneyAfterGame)
                :SetInt("money_rank", ToRankValue(sd.moneyAfterGame))
                :Save("game_over_money", {
                    ok = function()
                        print("[Room " .. room.id .. "] Persisted money for user " .. sd.userId
                            .. ": " .. sd.moneyAfterGame)
                    end,
                    error = function(code, reason)
                        print("[Room " .. room.id .. "] WARNING: Failed to persist money for user "
                            .. sd.userId .. ": " .. tostring(reason))
                    end,
                })
        end
    end
end

--- 结算完成时写入最终金币 + 物品存档（步骤2）
---@param room table
---@param slotIdx number
function RoomInstance._PersistSettlement(room, slotIdx)
    local sd = room.settleData[slotIdx]
    if not sd or not sd.userId then return end

    local batch = serverCloud:BatchSet(sd.userId) ---@diagnostic disable-line: undefined-global

    -- 更新最终金币（可能经过回收增加了）
    batch:Set("player_money", sd.finalMoney or sd.moneyAfterGame)
    batch:SetInt("money_rank", ToRankValue(sd.finalMoney or sd.moneyAfterGame))

    -- 写入物品存档（如果有新物品）
    -- 注意：完整的物品存档写入需要先读取现有存档再合并
    -- 当前实现将新物品追加到现有存档
    if sd.finalItems and #sd.finalItems > 0 then
        -- 读取现有存档后合并写入
        RoomInstance._MergeAndPersistItems(room, slotIdx)
    else
        -- 无新物品，仅写入金币
        batch:Save("settle_money", {
            ok = function()
                print("[Room " .. room.id .. "] Settlement persisted for user " .. sd.userId
                    .. " (money=" .. (sd.finalMoney or sd.moneyAfterGame) .. ", no new items)")
            end,
            error = function(code, reason)
                print("[Room " .. room.id .. "] WARNING: Settlement persist failed for user "
                    .. sd.userId .. ": " .. tostring(reason))
            end,
        })
    end
end

--- 读取现有物品存档 → 合并新物品 → 写回 serverCloud
---@param room table
---@param slotIdx number
function RoomInstance._MergeAndPersistItems(room, slotIdx)
    local sd = room.settleData[slotIdx]
    if not sd or not sd.userId then return end

    -- 物品字段压缩映射（与 SaveSystem 保持一致）
    local ITEM_FIELD_MAP = {
        name = "n", rarity = "r", w = "w", h = "h",
        baseValue = "v", category = "c", image = "i", desc = "d",
        wonAt = "t", gridX = "gx", gridY = "gy",
    }

    local function compressItem(item)
        local c = {}
        for long, short in pairs(ITEM_FIELD_MAP) do
            local val = item[long]
            if val ~= nil and val ~= "" and val ~= 0 then
                c[short] = val
            end
        end
        -- 记录获得时间
        c.t = os.time()
        return c
    end

    local CHUNK_SIZE = 8000

    -- 先读取现有的物品存档头
    serverCloud:Get(sd.userId, "save_items", { ---@diagnostic disable-line: undefined-global
        ok = function(scores)
            -- 解析现有物品（如果存在）
            local existingItems = {}
            local existingData = scores and scores.save_items
            if existingData and type(existingData) == "string" and #existingData > 0 then
                local ok2, decoded = pcall(cjson.decode, existingData) ---@diagnostic disable-line: undefined-global
                if ok2 and type(decoded) == "table" then
                    existingItems = decoded
                end
            elseif existingData and type(existingData) == "table" then
                existingItems = existingData
            end

            -- 压缩并追加新物品
            for _, item in ipairs(sd.finalItems) do
                existingItems[#existingItems + 1] = compressItem(item)
            end

            -- 编码并分块
            local json = cjson.encode(existingItems) ---@diagnostic disable-line: undefined-global
            local len = #json

            local writeBatch = serverCloud:BatchSet(sd.userId) ---@diagnostic disable-line: undefined-global
            -- 写入最终金币
            writeBatch:Set("player_money", sd.finalMoney or sd.moneyAfterGame)
            writeBatch:SetInt("money_rank", ToRankValue(sd.finalMoney or sd.moneyAfterGame))

            if len <= CHUNK_SIZE then
                writeBatch:Set("save_items", json)
            else
                -- 分块写入
                local chunkIdx = 0
                for i = 1, len, CHUNK_SIZE do
                    local chunk = json:sub(i, math.min(i + CHUNK_SIZE - 1, len))
                    writeBatch:Set("save_items_" .. chunkIdx, chunk)
                    chunkIdx = chunkIdx + 1
                end
                -- 写入 head 信息
                writeBatch:Set("save_items_head", cjson.encode({ ---@diagnostic disable-line: undefined-global
                    chunks = chunkIdx,
                    totalLen = len,
                }))
            end

            writeBatch:Save("settle_items", {
                ok = function()
                    print("[Room " .. room.id .. "] Settlement items persisted for user " .. sd.userId
                        .. " (money=" .. (sd.finalMoney or sd.moneyAfterGame)
                        .. ", items=" .. #existingItems .. ")")
                end,
                error = function(code, reason)
                    print("[Room " .. room.id .. "] WARNING: Items persist failed for user "
                        .. sd.userId .. ": " .. tostring(reason))
                end,
            })
        end,
        error = function(code, reason)
            -- 读取失败，仍然尝试只写入新物品
            print("[Room " .. room.id .. "] WARNING: Failed to read existing items for user "
                .. sd.userId .. ": " .. tostring(reason) .. ", writing new items only")

            local newItems = {}
            for _, item in ipairs(sd.finalItems) do
                newItems[#newItems + 1] = compressItem(item)
            end

            serverCloud:BatchSet(sd.userId) ---@diagnostic disable-line: undefined-global
                :Set("player_money", sd.finalMoney or sd.moneyAfterGame)
                :SetInt("money_rank", ToRankValue(sd.finalMoney or sd.moneyAfterGame))
                :Set("save_items", cjson.encode(newItems)) ---@diagnostic disable-line: undefined-global
                :Save("settle_items_fallback", {
                    ok = function()
                        print("[Room " .. room.id .. "] Fallback items persist OK for user " .. sd.userId)
                    end,
                    error = function(code2, reason2)
                        print("[Room " .. room.id .. "] CRITICAL: All persist failed for user "
                            .. sd.userId .. ": " .. tostring(reason2))
                    end,
                })
        end,
    })
end

-- ============================================================================
-- 房间销毁
-- ============================================================================

--- 断线重连后请求完整状态（TODO: 实现完整状态同步）
function RoomInstance.HandleRequestState(room, userId)
    print("[Room " .. room.id .. "] Player " .. userId .. " requested state sync (not yet implemented)")
end

--- 销毁房间（释放模块引用）
function RoomInstance.Destroy(room)
    room.modules = nil
    room.slots = {}
    room.settleData = nil
    room.playerCount = 0
    print("[Room " .. room.id .. "] Destroyed")
end

return RoomInstance
