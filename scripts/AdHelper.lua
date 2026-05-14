-- ============================================================================
-- AdHelper.lua - 广告 SDK 调用封装
-- 职责：SDK 可用性检查 + 三层 pcall 防崩溃 + 统一错误分类
-- 业务逻辑（计数、存档、hook）由调用方负责，不在此处处理
-- ============================================================================

---@diagnostic disable: undefined-global

local FloatingMessage = require("UI.FloatingMessage")

local AdHelper = {}

-- ============================================================================
-- 错误码（onFail 的 reason 参数）
-- ============================================================================
AdHelper.REASON_NO_SDK        = "no_sdk"         -- SDK 不存在或方法未挂载
AdHelper.REASON_USER_CANCEL   = "user_cancel"    -- 用户手动关闭
AdHelper.REASON_UNSUPPORTED   = "unsupported"    -- 平台不支持激励广告
AdHelper.REASON_CRASH         = "callback_crash" -- 回调本身发生了未预期的崩溃
AdHelper.REASON_UNKNOWN       = "unknown"        -- 其他失败

-- ============================================================================
-- 内部：将 SDK result.msg 映射到错误码
-- ============================================================================
local function ClassifyMsg(msg)
    if not msg then return AdHelper.REASON_UNKNOWN end
    local s = tostring(msg):lower()
    if s:find("unsupported") then
        return AdHelper.REASON_UNSUPPORTED
    end
    if s:find("cancel") or s:find("close") or s:find("skip")
        or s:find("跳过") or s:find("手动关闭") or s:find("embed manual") then
        return AdHelper.REASON_USER_CANCEL
    end
    return AdHelper.REASON_UNKNOWN
end

-- ============================================================================
-- 主接口
-- ============================================================================

--- 播放激励视频广告
---
--- 三层 pcall 防护：
---   第一层：整个 SDK 回调体（防异步回调时 UI 已销毁）
---   第二层：onSuccess 业务逻辑
---   第三层：onFail 业务逻辑
---
---@param onSuccess fun()         广告完整观看后调用
---@param onFail    fun(reason:string)  失败/取消时调用，reason 为 AdHelper.REASON_* 之一
function AdHelper.WatchRewardAd(onSuccess, onFail)
    -- ── 1. SDK 可用性检查 ─────────────────────────────────────────────────
    if not sdk or type(sdk.ShowRewardVideoAd) ~= "function" then
        pcall(FloatingMessage.Show, "广告不可用")
        pcall(onFail, AdHelper.REASON_NO_SDK)
        return
    end

    -- ── 2. 加载提示 ──────────────────────────────────────────────────────
    pcall(FloatingMessage.Show, "广告加载中...")

    -- ── 3. 调用 SDK ──────────────────────────────────────────────────────
    sdk:ShowRewardVideoAd(function(result)

        -- 标记 onFail 是否已被调用，防止崩溃兜底时重复调用
        local failDispatched = false

        -- ── 第一层 pcall：整个回调体 ──────────────────────────────────────
        local ok, err = pcall(function()

            if result and result.success then
                -- ── 第二层 pcall：onSuccess ───────────────────────────────
                local sok, serr = pcall(onSuccess)
                if not sok then
                    print("[AdHelper] onSuccess crash: " .. tostring(serr))
                end
            else
                -- ── 第二层 pcall：onFail ──────────────────────────────────
                local reason = ClassifyMsg(result and result.msg)
                failDispatched = true
                local fok, ferr = pcall(onFail, reason)
                if not fok then
                    print("[AdHelper] onFail crash: " .. tostring(ferr))
                end
            end

        end)

        -- ── 第一层兜底：回调体本身崩溃 ───────────────────────────────────
        if not ok then
            print("[AdHelper] SDK callback crash prevented: " .. tostring(err))
            if not failDispatched then
                pcall(onFail, AdHelper.REASON_CRASH)
            end
        end

    end)
end

return AdHelper
