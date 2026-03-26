-- ============================================================================
-- AI/InfoEstimation.lua - AI 信息状态管理 + 揭示等级更新
-- 从 AIPlayer.lua 提取，管理每个 AI 的独立信息视角
-- ============================================================================

local InfoEstimation = {}

-- ============================================================================
-- 依赖注入（多房间隔离时由 RoomInstance 注入正确的实例）
-- ============================================================================

local _EstimateValue = nil
local _AntiCheat = nil

--- 注入依赖（必须在使用前调用）
---@param estimateValue table EstimateValue 模块
---@param antiCheat table AntiCheat 模块
function InfoEstimation.InjectDeps(estimateValue, antiCheat)
    _EstimateValue = estimateValue
    _AntiCheat = antiCheat
end

-- ============================================================================
-- 揭示等级更新
-- ============================================================================

--- 根据信息中的 reveals 字段更新 itemRevealLevels
---@param infoState table { publicInfos, skillInfos, itemRevealLevels }
function InfoEstimation.UpdateRevealLevels(infoState)
    local levels = infoState.itemRevealLevels

    local function applyReveals(info)
        if info.reveals then
            for _, r in ipairs(info.reveals) do
                local cur = levels[r.itemIdx] or 0
                if r.targetLevel > cur then
                    levels[r.itemIdx] = r.targetLevel
                end
            end
        end
        if info.revealedItem and info.revealedItem.idx then
            local cur = levels[info.revealedItem.idx] or 0
            if 3 > cur then levels[info.revealedItem.idx] = 3 end
        end
    end

    local function applyAll(info)
        applyReveals(info)
        if info.extraInfos then
            for _, extra in ipairs(info.extraInfos) do
                applyReveals(extra)
            end
        end
    end

    for _, info in ipairs(infoState.publicInfos) do applyAll(info) end
    for _, info in ipairs(infoState.skillInfos) do applyAll(info) end
end

-- ============================================================================
-- 估值计算
-- ============================================================================

--- 为某个 AI 构建/更新信息状态并计算估值
--- AI 的估值以 expectedValue（区域行情常识）为先验锚点，
--- 随着信息揭示逐渐偏移到基于实际物品的推算值。
--- 同时计算期望估价（用于仓库质量判断）。
---@param playerIdx number
---@param round number
---@param infoSystem table { GetAllPublicInfos, GetPlayerSkillInfos }
---@param infoStates table 所有 AI 的 infoStates 引用
---@param expectedValue number 区域/难度的期望仓库价值（行业常识）
---@param warehouseTypeId string|nil 当前仓库类型
---@return number estimate 估值（用于出价）
---@return table cachedSecureValue AntiCheat SecureValue
---@return number expectedTotal 期望总价值（用于质量判断）
---@return number poolAvg 池均价（单件）
---@return number itemCount 物品总数
function InfoEstimation.ComputeEstimate(playerIdx, round, infoSystem, infoStates, expectedValue, warehouseTypeId)
    local state = infoStates[playerIdx]
    if not state then
        state = { publicInfos = {}, skillInfos = {}, itemRevealLevels = {} }
        infoStates[playerIdx] = state
    end

    state.publicInfos = infoSystem.GetAllPublicInfos(round)
    state.skillInfos = infoSystem.GetPlayerSkillInfos(playerIdx, round)
    InfoEstimation.UpdateRevealLevels(state)

    -- 用 EstimateValue 算法计算基于已知信息的最低估价
    local infoMin, knownCount, totalCount = _EstimateValue.Calculate(state, warehouseTypeId)

    -- 期望估价（中性无偏，用于质量判断）
    local expectedTotal, poolAvg, itemCount = _EstimateValue.CalculateExpected(state, warehouseTypeId)

    -- 先验：AI 对这个区域/难度的仓库行情认知
    local prior = expectedValue or 100000

    -- 信息置信度：已揭示物品越多，越信任实际数据
    local confidence = 0
    if totalCount > 0 and knownCount > 0 then
        confidence = knownCount / totalCount
    end

    -- 基于已知物品外推总价值
    -- infoMin 是已知部分的最低价，按比例外推到全仓库
    local projected = prior
    if confidence > 0 then
        projected = infoMin / confidence
    end

    -- 混合：低置信度信先验，高置信度信外推
    -- 用 sqrt 让置信度增长更快（少量信息就开始影响判断）
    local blend = math.sqrt(confidence)
    local estimate = prior * (1 - blend) + projected * blend

    -- 估价波动：±不确定性（信息越多越确定）
    local uncertainty = 0.20 - (round - 1) * 0.03 - confidence * 0.10
    uncertainty = math.max(uncertainty, 0.02)
    estimate = estimate * (1 + (math.random() * 2 - 1) * uncertainty)
    estimate = math.max(estimate, prior * 0.1)

    return estimate, _AntiCheat.SecureValue(estimate), expectedTotal, poolAvg, itemCount
end

return InfoEstimation
