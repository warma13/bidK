-- ============================================================================
-- network/RoomManager.lua - 房间管理器（服务端）
-- 负责房间的查找、创建、分配、清理
-- ============================================================================

local Shared = require("network.Shared")
local RoomInstance = require("network.RoomInstance")

local RoomManager = {}

-- 数据结构
local rooms_ = {}            -- { [roomId] = room }
local playerToRoom_ = {}     -- { [userId] = roomId }

-- ============================================================================
-- 房间查找与创建
-- ============================================================================

--- 生成房间类型键
---@param regionId string
---@param diffIdx number
---@return string
local function MakeRoomKey(regionId, diffIdx)
    return regionId .. "_" .. tostring(diffIdx)
end

--- 查找同类型的 WAITING 状态房间
---@param roomKey string
---@return table|nil room
local function FindWaitingRoom(roomKey)
    for _, room in pairs(rooms_) do
        if room.key == roomKey and room.state == RoomInstance.STATE.WAITING
           and room.playerCount < room.maxPlayers then
            return room
        end
    end
    return nil
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 玩家加入房间
---@param userId number
---@param connection userdata
---@param nickname string
---@param regionId string
---@param diffIdx number
---@param scene userdata 场景引用（分配给连接）
---@return boolean success
function RoomManager.JoinRoom(userId, connection, nickname, regionId, diffIdx, scene, charIdx)
    -- 已在房间中，先离开
    if playerToRoom_[userId] then
        RoomManager.LeaveRoom(userId)
    end

    local roomKey = MakeRoomKey(regionId, diffIdx)

    -- 查找或创建房间
    local room = FindWaitingRoom(roomKey)
    if not room then
        room = RoomInstance.Create(roomKey, regionId, diffIdx)
        rooms_[room.id] = room
    end

    -- 分配 scene 给连接（启用远程事件传输）
    connection.scene = scene

    -- 加入房间
    local slotIdx = RoomInstance.AddPlayer(room, userId, connection, nickname, charIdx)
    if not slotIdx then
        print("[RoomManager] Failed to add player " .. userId .. " to room " .. room.id)
        return false
    end

    playerToRoom_[userId] = room.id

    -- 通知客户端槽位分配
    local vm = Shared.PackEvent({
        slot = slotIdx,
        maxPlayers = room.maxPlayers,
    })
    connection:SendRemoteEvent(Shared.EVENTS.S_ASSIGN_SLOT, true, vm)

    -- 广播房间状态给所有房间内的玩家
    RoomManager.BroadcastRoomStatus(room)

    -- 检查是否满员，满员则开始游戏
    if room.playerCount >= room.maxPlayers then
        print("[RoomManager] Room " .. room.id .. " is full, starting game!")
        RoomInstance.StartGame(room)
    end

    return true
end

--- 玩家离开房间
---@param userId number
function RoomManager.LeaveRoom(userId)
    local roomId = playerToRoom_[userId]
    if not roomId then return end

    local room = rooms_[roomId]
    if not room then
        playerToRoom_[userId] = nil
        return
    end

    if room.state == RoomInstance.STATE.WAITING then
        RoomInstance.RemovePlayer(room, userId)
        playerToRoom_[userId] = nil

        -- 广播更新后的房间状态
        RoomManager.BroadcastRoomStatus(room)

        -- 空房间直接销毁
        if room.playerCount <= 0 then
            RoomInstance.Destroy(room)
            rooms_[roomId] = nil
            print("[RoomManager] Empty room " .. roomId .. " destroyed")
        end
    elseif room.state == RoomInstance.STATE.PLAYING then
        -- 游戏中不能真正离开，只标记断线
        RoomInstance.MarkDisconnected(room, userId)
        playerToRoom_[userId] = nil
    elseif room.state == RoomInstance.STATE.SETTLING
        or room.state == RoomInstance.STATE.FINISHED then
        -- 结算/已结束：直接清除映射，允许玩家加入新房间
        playerToRoom_[userId] = nil
        print("[RoomManager] Player " .. userId .. " left " .. room.state .. " room " .. roomId)
    end
end

--- 处理玩家断线
---@param userId number
function RoomManager.HandleDisconnect(userId)
    local roomId = playerToRoom_[userId]
    if not roomId then return end

    local room = rooms_[roomId]
    if not room then
        playerToRoom_[userId] = nil
        return
    end

    if room.state == RoomInstance.STATE.WAITING then
        RoomManager.LeaveRoom(userId)
    elseif room.state == RoomInstance.STATE.PLAYING then
        RoomInstance.MarkDisconnected(room, userId)
        playerToRoom_[userId] = nil
    elseif room.state == RoomInstance.STATE.SETTLING
        or room.state == RoomInstance.STATE.FINISHED then
        playerToRoom_[userId] = nil
    end
end

--- 获取玩家所在的房间
---@param userId number
---@return table|nil room
function RoomManager.GetPlayerRoom(userId)
    local roomId = playerToRoom_[userId]
    if not roomId then return nil end
    return rooms_[roomId]
end

--- 广播房间状态到房间内所有玩家
function RoomManager.BroadcastRoomStatus(room)
    local playerNames = {}
    for slotIdx = 1, room.maxPlayers do
        local slot = room.slots[slotIdx]
        if slot then
            playerNames[#playerNames + 1] = slot.nickname or ("Player" .. slotIdx)
        end
    end

    local data = {
        roomId = room.id,
        playerCount = room.playerCount,
        maxPlayers = room.maxPlayers,
        players = playerNames,
    }

    local vm = Shared.PackEvent(data)
    for _, slot in pairs(room.slots) do
        if slot.connection then
            slot.connection:SendRemoteEvent(Shared.EVENTS.S_ROOM_STATUS, true, vm)
        end
    end
end

--- 帧更新：驱动所有房间，回收已完成的空房间
---@param dt number
function RoomManager.Update(dt)
    local toRemove = {}

    for roomId, room in pairs(rooms_) do
        RoomInstance.Update(room, dt)

        -- 回收 FINISHED 的房间
        if room.state == RoomInstance.STATE.FINISHED then
            -- 检查是否还有连接的玩家
            if RoomInstance.GetConnectedCount(room) <= 0 then
                toRemove[#toRemove + 1] = roomId
            end
        end
    end

    for _, roomId in ipairs(toRemove) do
        local room = rooms_[roomId]
        if room then
            -- 清理 playerToRoom 映射
            for _, slot in pairs(room.slots) do
                if slot.userId then
                    playerToRoom_[slot.userId] = nil
                end
            end
            RoomInstance.Destroy(room)
            rooms_[roomId] = nil
            print("[RoomManager] Recycled finished room " .. roomId)
        end
    end
end

--- 路由操作到玩家所在的房间
---@param userId number
---@param action string "sealed_bid"|"tiebreak_bid"|"use_skill"|"skip_warehouse"
---@param data table|nil
function RoomManager.RouteAction(userId, action, data)
    local room = RoomManager.GetPlayerRoom(userId)
    if not room then
        print("[RoomManager] RouteAction: player " .. userId .. " not in any room")
        return
    end

    if action == "sealed_bid" then
        RoomInstance.HandleSealedBid(room, userId, data and data.amount or 0)
    elseif action == "tiebreak_bid" then
        RoomInstance.HandleTiebreakBid(room, userId, data and data.amount or 0)
    elseif action == "use_skill" then
        RoomInstance.HandleUseSkill(room, userId)
    elseif action == "skip_warehouse" then
        RoomInstance.HandleSkipWarehouse(room)
    elseif action == "recycle_items" then
        RoomInstance.HandleRecycleItems(room, userId, data)
    elseif action == "leave_settle" then
        RoomInstance.HandleLeaveSettle(room, userId)
    elseif action == "request_state" then
        RoomInstance.HandleRequestState(room, userId)
    end
end

return RoomManager
