--- UserCache.lua
--- 用户昵称内存缓存，避免每次打开界面都重复请求 GetUserNickname。
---
--- API：
---   UserCache.GetNickname(userId, onResult)
---     - userId   : number
---     - onResult : function(nickname: string)  -- 总是回调，无论缓存命中与否
---
--- 缓存策略：进程级内存缓存，重启后清空（符合游戏会话特性）。
--- 同一 userId 在首次请求尚未返回时，后续请求会被排队，待结果回来后一并触发。

local UserCache = {}

---@type table<number, string>          -- userId -> nickname
local _cache = {}

---@type table<number, function[]>      -- userId -> pending callbacks (nil = 已缓存 or 无请求)
local _pending = {}

--- 获取用户昵称（有缓存直接返回，否则发起一次网络请求）
---@param userId   number
---@param onResult fun(nickname: string)
function UserCache.GetNickname(userId, onResult)
    if userId == nil or userId == 0 then
        onResult("游客")
        return
    end

    -- 命中缓存
    if _cache[userId] ~= nil then
        onResult(_cache[userId])
        return
    end

    -- 已有进行中的请求，排队等结果
    if _pending[userId] then
        table.insert(_pending[userId], onResult)
        return
    end

    -- 发起首次请求
    _pending[userId] = { onResult }

    GetUserNickname({
        userIds = { userId },
        onSuccess = function(nicknames)
            local nick = tostring(userId)
            if nicknames and #nicknames > 0 and nicknames[1].nickname then
                nick = nicknames[1].nickname
            end
            _cache[userId] = nick
            local cbs = _pending[userId]
            _pending[userId] = nil
            if cbs then
                for _, cb in ipairs(cbs) do cb(nick) end
            end
        end,
        onError = function()
            local nick = tostring(userId)
            _cache[userId] = nick
            local cbs = _pending[userId]
            _pending[userId] = nil
            if cbs then
                for _, cb in ipairs(cbs) do cb(nick) end
            end
        end,
    })
end

--- 批量预热昵称缓存（排行榜等场景使用）
--- 对已缓存的 userId 跳过请求，只请求缺失的。
---@param userIds  number[]
---@param onDone   fun(map: table<number, string>)  -- userId -> nickname
function UserCache.BatchGetNicknames(userIds, onDone)
    local result = {}
    local missing = {}

    for _, uid in ipairs(userIds) do
        if _cache[uid] ~= nil then
            result[uid] = _cache[uid]
        else
            missing[#missing + 1] = uid
        end
    end

    if #missing == 0 then
        onDone(result)
        return
    end

    -- 对 missing 中已有 pending 的 uid 也不重复请求
    local toFetch = {}
    local fetchCount = 0
    for _, uid in ipairs(missing) do
        if not _pending[uid] then
            _pending[uid] = {}
            toFetch[#toFetch + 1] = uid
        end
        -- 无论是否新建 pending，都注册一个回调来填充 result
        table.insert(_pending[uid], function(nick)
            result[uid] = nick
            fetchCount = fetchCount + 1
            if fetchCount == #missing then
                onDone(result)
            end
        end)
    end

    -- 触发首次 pending 中才新建的请求（已有 pending 的不重复请求）
    if #toFetch == 0 then return end

    GetUserNickname({
        userIds = toFetch,
        onSuccess = function(nicknames)
            local map = {}
            if nicknames then
                for _, info in ipairs(nicknames) do
                    if info.userId and info.nickname then
                        map[info.userId] = info.nickname
                    end
                end
            end
            for _, uid in ipairs(toFetch) do
                local nick = map[uid] or tostring(uid)
                _cache[uid] = nick
                local cbs = _pending[uid]
                _pending[uid] = nil
                if cbs then
                    for _, cb in ipairs(cbs) do cb(nick) end
                end
            end
        end,
        onError = function()
            for _, uid in ipairs(toFetch) do
                local nick = tostring(uid)
                _cache[uid] = nick
                local cbs = _pending[uid]
                _pending[uid] = nil
                if cbs then
                    for _, cb in ipairs(cbs) do cb(nick) end
                end
            end
        end,
    })
end

return UserCache
