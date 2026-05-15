-- ============================================================================
-- SkillSystem.lua - 揭示技能系统
-- 从 GameState.lua 提取，通过 Setup(ctx) 注入上下文
-- ============================================================================

local SkillSystem = {}

local ctx = nil

function SkillSystem.Setup(context)
    ctx = context
end

return SkillSystem
