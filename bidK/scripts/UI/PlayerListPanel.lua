-- ============================================================================
-- UI/PlayerListPanel.lua - 左侧玩家列表面板
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local PlayerListPanel = {}

local refs = UIState.refs
local C = Config.COLORS

local GS = GameState
local BID_ANIM_DURATION = 0.35  -- 单个金额展开动画时长
local BID_REVEAL_GAP = 0.3      -- 两个玩家之间的间隔
local BID_REVEAL_END_WAIT = 1.0 -- 最后一个揭示完后等待时长

-- 出价揭示动画状态（UI 驱动）
local revealAnim = {
    active = false,        -- 是否正在揭示动画中
    elapsed = 0,           -- 总计时器
    currentIdx = 0,        -- 当前正在揭示第几个玩家（1-based）
    playerOrder = {},      -- 揭示顺序 { playerIdx, ... }
    playerStartTimes = {}, -- 每个玩家动画开始时间
    allDone = false,       -- 全部展开完成
    waitTimer = 0,         -- 完成后等待计时
    finished = false,      -- 已通知引擎完成
}

-- ============================================================================
-- 创建
-- ============================================================================

local function CreatePlayerCard(idx)
    local badgeColor = C.playerBadge[idx] or C.playerHighlight
    local maxRounds = Config.GAME.MaxRounds

    -- 顶部行：编号 + 昵称 + 金额
    local nameLabel = UI.Label {
        text = "玩家 " .. idx,
        fontSize = 12, fontColor = C.textPrimary,
        fontWeight = "bold", flexShrink = 1,
    }
    refs.playerNameLabels[idx] = nameLabel

    -- 轮次道具格 + 出价
    refs.playerRoundSlots[idx] = {}
    refs.playerRoundBids[idx] = {}
    local roundSlotChildren = {}
    for r = 1, maxRounds do
        local slotLabel = UI.Label { text = "", fontSize = 11, textAlign = "center" }
        refs.playerRoundSlots[idx][r] = slotLabel

        local bidLabel = UI.Label {
            text = "", fontSize = 8, fontColor = C.textMuted, textAlign = "center",
        }
        refs.playerRoundBids[idx][r] = bidLabel

        roundSlotChildren[r] = UI.Panel {
            flexDirection = "column", alignItems = "center", gap = 1,
            flexGrow = 1, flexBasis = 0,
            children = {
                UI.Label { text = tostring(r), fontSize = 8, fontColor = C.textMuted, textAlign = "center" },
                UI.Panel {
                    width = "100%", aspectRatio = 1,
                    backgroundColor = { 50, 55, 80, 180 },
                    borderRadius = 0,
                    justifyContent = "center", alignItems = "center",
                    children = { slotLabel },
                },
                bidLabel,
            }
        }
    end

    -- 当前轮出价状态：硬币图标 + 金额展开容器
    local bidAmountLabel = UI.Label {
        text = "", fontSize = 10, fontColor = {255, 220, 100, 255},
        fontWeight = "bold",
    }
    refs.playerBidAmountLabels[idx] = bidAmountLabel

    local bidAmountPanel = UI.Panel {
        width = 0, height = 18,
        overflow = "hidden",
        justifyContent = "center", alignItems = "center",
        children = { bidAmountLabel },
    }
    refs.playerBidAmountPanels[idx] = bidAmountPanel

    local bidCoinIcon = UI.Panel {
        width = 14, height = 14,
        backgroundImage = Utils.GetIcon("coin"),
        backgroundFit = "contain",
        flexShrink = 0,
    }

    local bidContainer = UI.Panel {
        flexDirection = "row", alignItems = "center", gap = 2,
        backgroundColor = { 40, 45, 70, 200 },
        borderRadius = 0, paddingHorizontal = 5, paddingVertical = 2,
        visible = false,
        children = { bidCoinIcon, bidAmountPanel },
    }
    refs.playerBidContainers[idx] = bidContainer

    -- 角色名
    local charLabel = UI.Label {
        text = "", fontSize = 10, fontColor = C.textSecondary,
    }
    refs.playerCharLabels[idx] = charLabel

    -- 高亮条
    local highlight = UI.Panel {
        position = "absolute",
        left = 0, top = 0, bottom = 0,
        width = 3,
        backgroundColor = badgeColor,
        visible = false,
    }
    refs.playerHighlights[idx] = highlight

    local card = UI.Panel {
        id = "playerCard_" .. idx,
        flexDirection = "column",
        backgroundColor = { 15, 20, 35, 160 },
        borderRadius = 0,
        padding = 6, gap = 4,
        overflow = "hidden",
        flexShrink = 1,
        flexGrow = 1,
        flexBasis = 0,
        children = {
            highlight,
            -- 顶部行：编号徽章 + 昵称 + 出价状态
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 6, width = "100%",
                children = {
                    UI.Label {
                        text = tostring(idx),
                        fontSize = 11, fontColor = badgeColor,
                        fontWeight = "bold",
                        flexShrink = 0,
                    },
                    nameLabel,
                    UI.Panel { flexGrow = 1 },
                    bidContainer,
                }
            },
            -- 中间：头像+角色名 + 轮次道具格
            UI.Panel {
                flexDirection = "row", gap = 6, width = "100%", alignItems = "center",
                children = {
                    -- 头像 + 角色名纵向居中
                    UI.Panel {
                        flexDirection = "column", alignItems = "center", gap = 1,
                        flexShrink = 1,
                        children = {
                            UI.Panel {
                                id = "playerAvatar_" .. idx,
                                width = 40, height = 44,
                                backgroundColor = { 50, 55, 80, 200 },
                                borderRadius = 0,
                                justifyContent = "center", alignItems = "center",
                                children = {
                                    (function()
                                        local icon = UI.Panel {
                                            width = 28, height = 28,
                                            backgroundImage = "",
                                            backgroundFit = "cover",
                                            borderRadius = 0,
                                        }
                                        refs.playerAvatarIcons[idx] = icon
                                        return icon
                                    end)()
                                }
                            },
                            charLabel,
                        }
                    },
                    UI.Panel {
                        flexDirection = "row", gap = 4,
                        flexGrow = 1, flexShrink = 1,
                        children = roundSlotChildren,
                    },
                }
            },
        }
    }
    refs.playerPanels[idx] = card
    return card
end

function PlayerListPanel.Create()
    local cards = {}
    for i = 1, 4 do
        cards[i] = CreatePlayerCard(i)
    end
    return UI.Panel {
        id = "playerListPanel",
        width = "22%", height = "100%",
        flexShrink = 1,
        backgroundColor = { 0, 0, 0, 0 },
        flexDirection = "column",
        gap = 4,
        overflow = "hidden",
        children = cards,
    }
end

--- 创建左上角金币余额 HUD（独立于玩家列表，由 GameController 挂载）
function PlayerListPanel.CreateMoneyHUD()
    refs.playerMoneyLabel = UI.Label {
        text = "0", fontSize = 14,
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
    }
    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 5,
        paddingHorizontal = 10,
        width = 120,
        children = {
            UI.Panel {
                width = 18, height = 18,
                backgroundImage = Utils.GetIcon("coin"),
                backgroundFit = "contain",
                flexShrink = 0,
            },
            refs.playerMoneyLabel,
        },
    }
end

-- ============================================================================
-- 更新
-- ============================================================================

-- 获取玩家出价金额和对应的显示文本/宽度
local function GetBidDisplay(playerIdx)
    local sealedBids = GS.GetSealedBids()
    local roundBids = GS.GetRoundBids()
    local currentRound = GS.GetCurrentRound()
    -- 优先 roundBids，回退 sealedBids
    local amount = nil
    if roundBids[currentRound] and roundBids[currentRound][playerIdx] ~= nil then
        amount = roundBids[currentRound][playerIdx]
    elseif sealedBids[playerIdx] ~= nil then
        amount = sealedBids[playerIdx]
    end
    if amount == nil then return nil, "", 0 end
    if amount > 0 then
        return amount, Utils.FormatMoney(amount), 55
    else
        return amount, "弃权", 35
    end
end

function PlayerListPanel.Update()
    local players = GS.GetPlayers()
    local phase = GS.GetPhase()
    local bidLocked = GS.GetBidLocked()
    local roundBids = GS.GetRoundBids()
    local maxRounds = Config.GAME.MaxRounds

    -- 刷新金币余额
    local mySlot = 1
    if players[mySlot] and refs.playerMoneyLabel then
        refs.playerMoneyLabel:SetText(Utils.FormatMoney(players[mySlot].money))
    end

    for idx = 1, 4 do
        local player = players[idx]
        if player then
            refs.playerNameLabels[idx]:SetText(player.name)
            if refs.playerAvatarIcons[idx] then
                refs.playerAvatarIcons[idx]:SetStyle({ backgroundImage = player.character.avatar })
            end
            refs.playerCharLabels[idx]:SetText(player.character.name)

            -- 轮次出价历史
            local currentRound = GS.GetCurrentRound()
            for r = 1, maxRounds do
                -- BID_REVEAL 阶段：当前轮次的出价仅在该玩家揭示动画开始后才显示
                local hide = (phase == GS.PHASE.BID_REVEAL and r == currentRound
                    and not (revealAnim.active and revealAnim.playerStartTimes[idx]))
                if not hide and roundBids[r] and roundBids[r][idx] then
                    local amount = roundBids[r][idx]
                    if amount > 0 then
                        refs.playerRoundBids[idx][r]:SetText(Utils.FormatMoney(amount))
                    else
                        refs.playerRoundBids[idx][r]:SetText("弃")
                    end
                else
                    refs.playerRoundBids[idx][r]:SetText("")
                end
            end

            -- 当前出价状态（硬币+金额展开）
            local container = refs.playerBidContainers[idx]
            local amountPanel = refs.playerBidAmountPanels[idx]
            local amountLabel = refs.playerBidAmountLabels[idx]

            local visible = false
            local text = ""
            local width = 0

            if phase == GS.PHASE.SEALED_BID then
                -- 确认出价后只显示硬币图标
                if player.isHuman then
                    visible = UIState.playerBidConfirmed == true
                else
                    visible = UIState.aiBidConfirmed[idx] == true
                end
                -- width = 0, text = "" → 只有硬币

            elseif phase == GS.PHASE.BID_REVEAL then
                -- 由 revealAnim 驱动，这里根据动画状态计算
                visible = true  -- 所有人都显示硬币
                local _, bText, bTargetW = GetBidDisplay(idx)
                -- 检查该玩家是否已开始揭示（必须动画已激活且有开始时间）
                local startTime = revealAnim.active and revealAnim.playerStartTimes[idx]
                if startTime then
                    text = bText
                    local animElapsed = revealAnim.elapsed - startTime
                    if animElapsed >= BID_ANIM_DURATION then
                        width = bTargetW  -- 动画完成，保持目标宽度
                    else
                        -- 动画中：ease-out 插值
                        local t = animElapsed / BID_ANIM_DURATION
                        local eased = 1 - (1 - t) * (1 - t)
                        width = math.floor(eased * bTargetW)
                    end
                end
                -- 未开始揭示的玩家：visible=true, width=0 → 只有硬币

            elseif phase == GS.PHASE.TIEBREAK_BID then
                visible = GS.IsTiebreakParticipant(idx)

            elseif phase == GS.PHASE.ROUND_JUDGE
                or phase == GS.PHASE.WAREHOUSE_OPEN
                or phase == GS.PHASE.GAME_OVER then
                local bidAmt, bText, bTargetW = GetBidDisplay(idx)
                if bTargetW > 0 then
                    visible = true
                    -- 显示等效出价（all_in / bid_boost）
                    local activated = GS.GetActiveSkillActivated()
                    local ch = players[idx] and players[idx].character
                    if activated[idx] and ch and ch.activeSkill and ch.activeSkill.effect == "all_in" and bidAmt and bidAmt > 0 then
                        local effBid = math.floor(bidAmt * 1.5)
                        text = Utils.FormatMoney(effBid)
                        bTargetW = 75
                    else
                        local boostMult = GS.GetBidBoostMultiplier(idx)
                        if boostMult > 1.0 and bidAmt and bidAmt > 0 then
                            local effBid = math.floor(bidAmt * boostMult)
                            text = Utils.FormatMoney(effBid) .. "↑"
                            bTargetW = 65
                        else
                            text = bText
                        end
                    end
                    width = bTargetW
                end
            end

            container:SetVisible(visible)
            amountLabel:SetText(text)
            amountPanel:SetStyle({ width = width })

            -- 高亮逻辑：自己的玩家（徽章色）
            if idx == mySlot then
                refs.playerHighlights[idx]:SetVisible(true)
                refs.playerHighlights[idx]:SetStyle({ backgroundColor = C.playerBadge[idx] or C.playerHighlight })
            else
                refs.playerHighlights[idx]:SetVisible(false)
            end
        end
    end
end

-- ============================================================================
-- 动画更新（每帧调用）
-- ============================================================================

local AuctionEngine_ = nil  -- 延迟加载避免循环引用

function PlayerListPanel.UpdateAnimations(dt)
    local phase = GS.GetPhase()

    if phase == GS.PHASE.BID_REVEAL then
        -- 首次进入 BID_REVEAL：初始化顺序揭示动画
        if not revealAnim.active then
            revealAnim.active = true
            revealAnim.elapsed = 0
            revealAnim.currentIdx = 0
            revealAnim.playerOrder = { 1, 2, 3, 4 }
            revealAnim.playerStartTimes = {}
            revealAnim.allDone = false
            revealAnim.waitTimer = 0
            revealAnim.finished = false
        end

        revealAnim.elapsed = revealAnim.elapsed + dt

        -- 依次启动每个玩家的展开动画
        if not revealAnim.allDone then
            local nextIdx = revealAnim.currentIdx + 1
            if nextIdx <= #revealAnim.playerOrder then
                local shouldStart = false
                if revealAnim.currentIdx == 0 then
                    -- 第一个玩家：立即开始（加一小段初始延迟）
                    shouldStart = revealAnim.elapsed >= BID_REVEAL_GAP
                else
                    -- 后续玩家：上一个动画完成后 + 间隔
                    local prevPlayer = revealAnim.playerOrder[revealAnim.currentIdx]
                    local prevStart = revealAnim.playerStartTimes[prevPlayer] or 0
                    shouldStart = (revealAnim.elapsed - prevStart) >= (BID_ANIM_DURATION + BID_REVEAL_GAP)
                end
                if shouldStart then
                    local playerIdx = revealAnim.playerOrder[nextIdx]
                    revealAnim.playerStartTimes[playerIdx] = revealAnim.elapsed
                    revealAnim.currentIdx = nextIdx
                    Utils.PlaySfx("bid_place")
                end
            else
                -- 所有玩家都已启动，检查最后一个是否播完
                local lastPlayer = revealAnim.playerOrder[#revealAnim.playerOrder]
                local lastStart = revealAnim.playerStartTimes[lastPlayer] or 0
                if (revealAnim.elapsed - lastStart) >= BID_ANIM_DURATION then
                    revealAnim.allDone = true
                    revealAnim.waitTimer = 0
                end
            end
        else
            -- 全部展开完成，等待 1 秒后通知引擎
            revealAnim.waitTimer = revealAnim.waitTimer + dt
            if revealAnim.waitTimer >= BID_REVEAL_END_WAIT and not revealAnim.finished then
                revealAnim.finished = true
                if not AuctionEngine_ then
                    AuctionEngine_ = require("AuctionEngine")
                end
                AuctionEngine_.FinishBidReveal()
            end
        end
    else
        -- 离开 BID_REVEAL 阶段，彻底重置动画状态
        -- 必须清空 playerStartTimes，否则下一轮进入 BID_REVEAL 时
        -- 残留的旧值会导致 Update() 在动画初始化前就显示所有出价（一帧闪现）
        if revealAnim.active then
            revealAnim.active = false
            revealAnim.elapsed = 0
            revealAnim.currentIdx = 0
            revealAnim.playerStartTimes = {}
            revealAnim.allDone = false
            revealAnim.waitTimer = 0
            revealAnim.finished = false
        end
    end
end

return PlayerListPanel
