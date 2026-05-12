-- ============================================================================
-- AppPhase.lua - 全局应用阶段管理（单一 Phase 变量控制全局状态）
-- ============================================================================

local AppPhase = {}

-- 阶段枚举
AppPhase.BOOT     = "BOOT"      -- Start() 被调用前 / 引擎初始化中
AppPhase.LOADING  = "LOADING"   -- 异步加载存档（SaveFramework / SaveSystem）
AppPhase.MENUS    = "MENUS"     -- 主菜单 / 地图 / 大厅等非对局界面
AppPhase.IN_GAME  = "IN_GAME"   -- 对局进行中

-- 合法阶段集合（用于校验）
local VALID = {
    [AppPhase.BOOT]    = true,
    [AppPhase.LOADING] = true,
    [AppPhase.MENUS]   = true,
    [AppPhase.IN_GAME] = true,
}

-- 当前阶段
local current = AppPhase.BOOT

--- 获取当前阶段
---@return string
function AppPhase.Get()
    return current
end

--- 设置阶段（带校验 + 日志）
---@param phase string
function AppPhase.Set(phase)
    if not VALID[phase] then
        print("[AppPhase] WARNING: invalid phase '" .. tostring(phase) .. "', ignored")
        return
    end
    if current ~= phase then
        print("[AppPhase] " .. current .. " -> " .. phase)
        current = phase
    end
end

--- 快捷判断：当前是否在对局中
---@return boolean
function AppPhase.IsInGame()
    return current == AppPhase.IN_GAME
end

--- 快捷判断：当前是否在菜单中
---@return boolean
function AppPhase.IsMenus()
    return current == AppPhase.MENUS
end

return AppPhase
