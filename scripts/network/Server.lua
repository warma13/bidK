-- ============================================================================
-- network/Server.lua - 服务端逻辑（常驻服事件路由器）
-- 接收客户端事件，路由到对应房间的 RoomInstance
-- ============================================================================

local Shared = require("network.Shared")
local RoomManager = require("network.RoomManager")

local Server = {}

-- 连接跟踪（userId ↔ connection 映射）
local connections_ = {}      -- { [userId] = { connection, nickname } }
local scene_ = nil

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 根据 connection 查找 userId
local function FindUserIdByConnection(connection)
    for userId, info in pairs(connections_) do
        if info.connection == connection then
            return userId
        end
    end
    return nil
end

-- ============================================================================
-- 连接事件处理
-- ============================================================================

function HandleClientIdentity(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local identity = connection.identity
    local userId = identity["user_id"]:GetInt64()

    if connections_[userId] then
        print("[Server] Player " .. userId .. " already connected, updating connection")
        connections_[userId].connection = connection
        return
    end

    connections_[userId] = {
        connection = connection,
        nickname = tostring(userId),
    }

    -- 异步获取昵称
    GetUserNickname({
        userIds = { userId },
        onSuccess = function(nicknames)
            if nicknames and #nicknames > 0 and nicknames[1].nickname then
                local info = connections_[userId]
                if info then
                    info.nickname = nicknames[1].nickname
                    print("[Server] Player " .. userId .. " nickname: " .. info.nickname)
                end
            end
        end,
    })

    print("[Server] Player connected: userId=" .. userId)
end

function HandleClientDisconnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local userId = FindUserIdByConnection(connection)
    if not userId then return end

    print("[Server] Player disconnected: userId=" .. userId)

    -- 通知 RoomManager 处理断线
    RoomManager.HandleDisconnect(userId)

    -- 移除连接记录
    connections_[userId] = nil
end

-- ============================================================================
-- 客户端远程事件处理
-- ============================================================================

--- 玩家请求加入房间
function HandleJoinRoom(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local userId = FindUserIdByConnection(connection)
    if not userId then
        print("[Server] C_JoinRoom from unknown connection")
        return
    end

    local data = Shared.UnpackEvent(eventData)
    local regionId = data.regionId
    local diffIdx = data.diffIdx
    local charIdx = data.charIdx

    if not regionId or not diffIdx then
        print("[Server] C_JoinRoom missing regionId or diffIdx")
        return
    end

    local info = connections_[userId]
    local nickname = info and info.nickname or tostring(userId)

    print("[Server] Player " .. userId .. " requests join room: region=" .. regionId .. " diff=" .. diffIdx .. " char=" .. tostring(charIdx))

    local ok = RoomManager.JoinRoom(userId, connection, nickname, regionId, diffIdx, scene_, charIdx)
    if not ok then
        print("[Server] Failed to join room for player " .. userId)
    end
end

--- 玩家请求离开房间
function HandleLeaveRoom(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local userId = FindUserIdByConnection(connection)
    if not userId then return end

    print("[Server] Player " .. userId .. " requests leave room")
    RoomManager.LeaveRoom(userId)
end

--- 暗标出价（路由到房间）
function HandleClientSealedBid(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local userId = FindUserIdByConnection(connection)
    if not userId then return end

    local data = Shared.UnpackEvent(eventData)
    RoomManager.RouteAction(userId, "sealed_bid", data)
end

--- 实时竞拍出价（路由到房间）
function HandleClientTiebreakBid(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local userId = FindUserIdByConnection(connection)
    if not userId then return end

    local data = Shared.UnpackEvent(eventData)
    RoomManager.RouteAction(userId, "tiebreak_bid", data)
end

--- 使用技能（路由到房间）
function HandleClientUseSkill(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local userId = FindUserIdByConnection(connection)
    if not userId then return end

    RoomManager.RouteAction(userId, "use_skill")
end

--- 跳过开箱（路由到房间）
function HandleClientSkipWarehouse(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local userId = FindUserIdByConnection(connection)
    if not userId then return end

    RoomManager.RouteAction(userId, "skip_warehouse")
end

--- 回收物品（路由到房间）
function HandleClientRecycleItems(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local userId = FindUserIdByConnection(connection)
    if not userId then return end

    local data = Shared.UnpackEvent(eventData)
    RoomManager.RouteAction(userId, "recycle_items", data)
end

--- 离开结算（路由到房间）
function HandleClientLeaveSettle(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local userId = FindUserIdByConnection(connection)
    if not userId then return end

    RoomManager.RouteAction(userId, "leave_settle")
end

--- 断线重连请求状态（路由到房间）
function HandleClientRequestState(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local userId = FindUserIdByConnection(connection)
    if not userId then return end

    RoomManager.RouteAction(userId, "request_state")
end

-- ============================================================================
-- 入口
-- ============================================================================

function Server.Start()
    print("[Server] === Auction Server Starting (Persistent World) ===")

    -- 注册远程事件
    Shared.RegisterEvents()

    -- 创建最小场景（网络连接需要场景）
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 订阅连接事件
    SubscribeToEvent("ClientIdentity", "HandleClientIdentity")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")

    -- 订阅客户端远程事件
    local E = Shared.EVENTS
    SubscribeToEvent(E.C_JOIN_ROOM,       "HandleJoinRoom")
    SubscribeToEvent(E.C_LEAVE_ROOM,      "HandleLeaveRoom")
    SubscribeToEvent(E.C_SEALED_BID,      "HandleClientSealedBid")
    SubscribeToEvent(E.C_TIEBREAK_BID,    "HandleClientTiebreakBid")
    SubscribeToEvent(E.C_USE_SKILL,       "HandleClientUseSkill")
    SubscribeToEvent(E.C_SKIP_WAREHOUSE,  "HandleClientSkipWarehouse")
    SubscribeToEvent(E.C_RECYCLE_ITEMS,   "HandleClientRecycleItems")
    SubscribeToEvent(E.C_LEAVE_SETTLE,    "HandleClientLeaveSettle")
    SubscribeToEvent(E.C_REQUEST_STATE,   "HandleClientRequestState")

    print("[Server] Waiting for players...")
end

function Server.Stop()
    print("[Server] Server stopped")
end

---@param eventType string
---@param eventData UpdateEventData
function Server.HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    RoomManager.Update(dt)
end

return Server
