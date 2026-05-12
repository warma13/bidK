-- ============================================================================
-- SkillSystem.lua - 主动技能 + 被动效果
-- 从 GameState.lua 提取，通过 Setup(ctx) 注入上下文
-- ============================================================================

local SkillSystem = {}

-- 注入的上下文（由 GameState.Init 调用 Setup 设置）
local ctx = nil  -- { state, secureAddMoney, validateMoney }

--- 注入运行时上下文（每次 GameState.Init 时调用）
function SkillSystem.Setup(context)
    ctx = context
end

-- ============================================================================
-- 主动技能
-- ============================================================================

--- 使用主动技能（返回 true/false）
function SkillSystem.UseActiveSkill(playerIdx)
    local state = ctx.state
    if (state.activeSkillUses[playerIdx] or 0) <= 0 then return false end
    if state.activeSkillActivated[playerIdx] then return false end  -- 本轮已用
    state.activeSkillUses[playerIdx] = state.activeSkillUses[playerIdx] - 1
    state.activeSkillActivated[playerIdx] = true
    local player = state.players[playerIdx]
    print("[GameState] Player " .. playerIdx .. " (" .. player.name .. ") used active skill! Remaining: " .. state.activeSkillUses[playerIdx])
    return true
end

--- 重置本轮主动技能激活状态（每轮开始时调用）
function SkillSystem.ResetRoundSkills()
    local state = ctx.state
    for idx = 1, #state.players do
        state.activeSkillActivated[idx] = false
    end
end

--- 获取玩家主动技能信息
function SkillSystem.GetActiveSkillInfo(playerIdx)
    local state = ctx.state
    local player = state.players[playerIdx]
    if not player then return nil end
    local ch = player.character
    if not ch.activeSkill then return nil end
    return {
        name = ch.activeSkill.name,
        icon = ch.activeSkill.icon,
        effect = ch.activeSkill.effect,
        maxUses = ch.activeSkill.maxUses,
        remaining = state.activeSkillUses[playerIdx] or 0,
        activatedThisRound = state.activeSkillActivated[playerIdx] or false,
    }
end

-- ============================================================================
-- 被动效果
-- ============================================================================

--- 每轮未成交时应用被动效果（利息、累积加成）
function SkillSystem.ApplyRoundPassives()
    local state = ctx.state
    for idx, player in ipairs(state.players) do
        local ch = player.character
        if ch.passiveEffect then
            local pe = ch.passiveEffect
            -- 马库斯：未成交轮次+利息
            if pe.type == "interest" then
                ctx.validateMoney(idx)
                local interest = math.floor(player.money * pe.interestRate)
                if interest > 0 then
                    ctx.secureAddMoney(idx, interest)
                    print("[GameState] " .. player.name .. " earned interest: +" .. interest .. " (total: " .. player.money .. ")")
                end
            end
            -- 老陈：累积出价加成
            if pe.type == "bid_boost" then
                state.bidBoostStacks[idx] = (state.bidBoostStacks[idx] or 0) + 1
                local totalBoost = state.bidBoostStacks[idx] * pe.boostPerRound
                print("[GameState] " .. player.name .. " bid boost stacked to " .. state.bidBoostStacks[idx]
                    .. " (+" .. string.format("%.0f%%", totalBoost * 100) .. ")")
            end
        end
    end
end

--- 获取玩家出价加成倍率（老陈的 bid_boost）
function SkillSystem.GetBidBoostMultiplier(playerIdx)
    local state = ctx.state
    local player = state.players[playerIdx]
    if not player then return 1.0 end
    local ch = player.character
    if ch.passiveEffect and ch.passiveEffect.type == "bid_boost" then
        local stacks = state.bidBoostStacks[playerIdx] or 0
        return 1.0 + stacks * ch.passiveEffect.boostPerRound
    end
    return 1.0
end

--- 获取成交折扣率（艾莎的 discount）
function SkillSystem.GetDiscountRate(playerIdx)
    local state = ctx.state
    local player = state.players[playerIdx]
    if not player then return 0 end
    local ch = player.character
    if ch.passiveEffect and ch.passiveEffect.type == "discount" then
        return ch.passiveEffect.discountRate or 0
    end
    return 0
end

--- 获取结算价值加成率（加布里埃拉/铁柱）
function SkillSystem.GetValueBonus(playerIdx)
    local state = ctx.state
    local player = state.players[playerIdx]
    if not player then return 0 end
    local ch = player.character
    if not ch.passiveEffect then return 0 end
    local pe = ch.passiveEffect

    if pe.type == "treasure_master" then
        return pe.valueBonus or 0
    elseif pe.type == "specialty" then
        if player.specialtyMatch then
            return pe.valueBonus or 0
        end
    end
    return 0
end

return SkillSystem
