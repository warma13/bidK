-- ============================================================================
-- ExtractionMode.lua - 提取玩法核心逻辑
--
-- 玩法概述：
--   玩家花钱进图，地图有多个容器，与3个AI竞争搜索。
--   每个容器有独立的物品搜索队列，各玩家维护独立搜索进度指针。
--   搜出的物品可被任何在场玩家手动拾取（双击取走）。
--   搜索可随时中断，保留进度；容器有封箱/开箱/搜索中等状态。
-- ============================================================================

local Config     = require("Config")
local SaveSystem = require("SaveSystem")

local EM = {}

-- ============================================================================
-- 常量
-- ============================================================================

-- 每局容器数量
EM.CONTAINER_COUNT = 10

-- 容器状态枚举
EM.CS = {
    SEALED      = "sealed",       -- 封箱，未被任何人打开
    OPENING     = "opening",      -- 正在开箱（耗时 1.5 秒）
    OPEN        = "open",         -- 已开箱，可直接搜索
    SEARCHING   = "searching",    -- 有玩家正在搜索中
    EMPTIED     = "emptied",      -- 所有物品已搜索完毕
}

-- 后手优势窗口（秒）：0.5 秒内跟进可跳过开箱直接搜
EM.FOLLOW_WINDOW = 0.5

-- 开箱耗时（秒）
EM.OPEN_TIME = 1.5

-- 每件物品搜索耗时（秒）：随物品价值浮动
EM.SEARCH_TIME_BASE = 0.5
EM.SEARCH_TIME_PER_10K = 0.02   -- 每1万元价值增加0.02秒（最高+2秒）
EM.SEARCH_TIME_MAX = 2.0

-- 拾取双击最大间隔（秒）
EM.DOUBLE_TAP_WINDOW = 0.4

-- AI 搜索行为配置
EM.AI_MOVE_TIME_MIN = 1.0   -- AI 移动到容器最短耗时（秒）
EM.AI_MOVE_TIME_MAX = 3.0   -- AI 移动到容器最长耗时（秒）
EM.AI_PICKUP_DELAY  = 0.5   -- AI 发现物品后多久拾取（秒）

-- ============================================================================
-- 数据结构说明（保存在 session 闭包中）
--
-- Container = {
--   id          : int          -- 1..CONTAINER_COUNT
--   name        : string       -- 显示名称
--   status      : EM.CS        -- 当前状态
--   openTimer   : float        -- 开箱倒计时（仅 OPENING 状态）
--   openedAt    : float        -- 开箱完成时的时间戳（用于后手优势判断）
--   items       : [ Item ]     -- 物品搜索队列（按位置顺序）
--   revealed    : { [pos]=bool } -- 已揭示的物品（可被所有人看到）
--   taken       : { [pos]=bool } -- 已被取走的物品
-- }
--
-- Item = {
--   pos         : int          -- 在容器队列中的逻辑位置 (1-based)
--   name        : string
--   baseValue   : int
--   searchTime  : float        -- 搜这件物品需要的秒数
-- }
--
-- PlayerSearch = {
--   playerIdx   : int
--   containerId : int          -- 正在搜索的容器 id（0=未搜索）
--   progress    : int          -- 已完成搜索到第几个位置（含已取走的计数）
--   timer       : float        -- 当前物品剩余搜索时间
--   state       : "idle"|"moving"|"opening"|"searching"|"done"
--   moveTimer   : float        -- 移动倒计时
-- }
--
-- RevealedItem = {
--   containerId : int
--   pos         : int
--   item        : Item         -- 物品数据
--   revealedBy  : int          -- 揭示者 playerIdx
--   available   : bool         -- 是否还可以拾取
-- }
-- ============================================================================

-- ============================================================================
-- 工具函数
-- ============================================================================

-- 计算物品搜索耗时
local function CalcSearchTime(baseValue)
    local extra = math.min((baseValue / 10000) * EM.SEARCH_TIME_PER_10K, EM.SEARCH_TIME_MAX - EM.SEARCH_TIME_BASE)
    return EM.SEARCH_TIME_BASE + extra
end

-- 生成容器名称
local function ContainerName(idx)
    local names = {
        "A区储物柜", "B区储物柜", "C区储物柜", "D区储物柜", "E区储物柜",
        "F区储物柜", "G区储物柜", "H区储物柜", "I区储物柜", "J区储物柜",
    }
    return names[idx] or ("储物柜" .. idx)
end

-- 使用 WarehouseGenerator 的物品数据生成容器物品队列
-- 每个容器放 3~7 件物品
local function GenContainerItems(allItems, rng)
    -- 将全部物品随机分配到各容器
    local containers = {}
    for i = 1, EM.CONTAINER_COUNT do
        containers[i] = {}
    end

    -- 打乱物品顺序
    local pool = {}
    for _, item in ipairs(allItems) do
        pool[#pool + 1] = item
    end
    for i = #pool, 2, -1 do
        local j = math.floor(rng() * i) + 1
        pool[i], pool[j] = pool[j], pool[i]
    end

    -- 循环分配（确保每个容器至少 3 件）
    local minPerContainer = 3
    local total = #pool
    local idx = 1
    -- 先保证每个容器 minPerContainer 件
    for c = 1, EM.CONTAINER_COUNT do
        for k = 1, minPerContainer do
            if idx <= total then
                containers[c][#containers[c] + 1] = pool[idx]
                idx = idx + 1
            end
        end
    end
    -- 剩余物品随机分配
    while idx <= total do
        local c = math.floor(rng() * EM.CONTAINER_COUNT) + 1
        if #containers[c] < 7 then
            containers[c][#containers[c] + 1] = pool[idx]
            idx = idx + 1
        end
    end

    -- 转成带 pos 的 Item 格式
    local result = {}
    for c = 1, EM.CONTAINER_COUNT do
        result[c] = {}
        for pos, item in ipairs(containers[c]) do
            -- 保留原始物品全部字段（idx/icon/image/rarity 等供 LootPanel 渲染使用）
            local entry = {}
            for k, v in pairs(item) do entry[k] = v end
            entry.pos        = pos
            entry.name       = item.name or ("物品" .. pos)
            entry.baseValue  = item.baseValue or 0
            entry.searchTime = CalcSearchTime(item.baseValue or 0)
            result[c][pos] = entry
        end
    end
    return result
end

-- ============================================================================
-- Session（单局数据）
-- ============================================================================

---@class ExtractionSession
local ExtractionSession = {}
ExtractionSession.__index = ExtractionSession

--- 创建新的提取对局
--- @param params table { regionId, entryFee, allItems, onStateChange, onReveal, onTake, onGameOver }
function EM.NewSession(params)
    local s = setmetatable({}, ExtractionSession)

    s.regionId    = params.regionId    or "suburb"
    s.entryFee    = params.entryFee    or 0
    s.allItems    = params.allItems    or {}

    -- 回调
    s.onStateChange = params.onStateChange  -- function(session)
    s.onReveal      = params.onReveal       -- function(containerId, pos, item, byPlayerIdx)
    s.onTake        = params.onTake         -- function(containerId, pos, item, byPlayerIdx)
    s.onGameOver    = params.onGameOver     -- function(result)

    -- 时间戳（秒）
    s.elapsed = 0

    -- 初始化容器
    local rng = math.random
    s.containers = {}
    local containerItems = GenContainerItems(s.allItems, rng)
    for i = 1, EM.CONTAINER_COUNT do
        s.containers[i] = {
            id        = i,
            name      = ContainerName(i),
            status    = EM.CS.SEALED,
            openTimer = 0,
            openedAt  = -99,  -- 很早以前开的（初始值保证后手判断不触发）
            items     = containerItems[i],
            revealed  = {},
            taken     = {},
        }
    end

    -- 玩家数：玩家本人(idx=1) + 3个AI(idx=2,3,4)
    s.PLAYER_COUNT = 4
    s.HUMAN_IDX    = 1

    -- 每位玩家的搜索状态
    s.searches = {}
    for i = 1, s.PLAYER_COUNT do
        s.searches[i] = {
            playerIdx   = i,
            containerId = 0,
            progress    = 0,
            timer       = 0,
            state       = "idle",
            moveTimer   = 0,
        }
    end

    -- 背包（已拾取物品）
    s.backpacks = {}
    for i = 1, s.PLAYER_COUNT do
        s.backpacks[i] = {}
    end

    -- 背包容量：玩家 20 格，AI 20 格
    s.backpackCapacity = 20

    -- 已揭示待拾取的物品列表（共享可见）
    s.revealedItems = {}   -- key = "cid_pos" → RevealedItem

    -- 双击检测（人类玩家）
    s.lastTapItem = nil   -- { cid, pos, time }

    -- AI 决策状态
    s.aiTargetContainers = {}   -- { [aiIdx] = targetContainerId }
    for i = 2, s.PLAYER_COUNT do
        s.aiTargetContainers[i] = 0
    end

    -- 游戏是否结束
    s.gameOver = false
    s.gameOverResult = nil

    -- 初始 AI 指派目标容器
    s:_AIAssignInitialTargets()

    return s
end

-- ============================================================================
-- 容器操作
-- ============================================================================

--- 玩家尝试进入容器（开始搜索）
--- @return string "ok"|"need_open"|"following"|"busy"|"done"
function ExtractionSession:PlayerEnterContainer(playerIdx, containerId)
    local search = self.searches[playerIdx]
    local container = self.containers[containerId]
    if not container then return "invalid" end

    -- 已经在该容器搜索
    if search.containerId == containerId and search.state == "searching" then
        return "already_here"
    end

    -- 容器已清空
    if container.status == EM.CS.EMPTIED then
        return "done"
    end

    -- 记录玩家离开旧容器（如有）
    if search.containerId ~= 0 and search.containerId ~= containerId then
        self:_PlayerLeaveContainer(playerIdx)
    end

    local now = self.elapsed

    if container.status == EM.CS.SEALED then
        -- 封箱：开始开箱
        container.status    = EM.CS.OPENING
        container.openTimer = EM.OPEN_TIME
        search.containerId  = containerId
        search.state        = "opening"
        self:_Notify()
        return "need_open"

    elseif container.status == EM.CS.OPENING then
        -- 正在开箱中：后手判断
        local timeLeft = container.openTimer
        local elapsed  = EM.OPEN_TIME - timeLeft
        if elapsed <= EM.FOLLOW_WINDOW then
            -- 在后手窗口内，跳过开箱，进入搜索
            search.containerId = containerId
            search.state       = "searching"
            self:_StartSearchTimer(playerIdx)
            self:_Notify()
            return "following"
        else
            -- 超过窗口，等待开箱完成
            search.containerId = containerId
            search.state       = "opening"
            self:_Notify()
            return "waiting_open"
        end

    elseif container.status == EM.CS.OPEN or container.status == EM.CS.SEARCHING then
        -- 已开箱或有人在搜：直接进入搜索
        container.status   = EM.CS.SEARCHING
        search.containerId = containerId
        search.state       = "searching"
        self:_StartSearchTimer(playerIdx)
        self:_Notify()
        return "ok"
    end

    return "unknown"
end

--- 玩家离开容器（中断搜索，保留进度）
function ExtractionSession:PlayerLeaveContainer(playerIdx)
    self:_PlayerLeaveContainer(playerIdx)
    self:_Notify()
end

function ExtractionSession:_PlayerLeaveContainer(playerIdx)
    local search = self.searches[playerIdx]
    if search.containerId == 0 then return end

    local container = self.containers[search.containerId]
    -- 如果离开后没有任何玩家在搜索，改回 OPEN
    local stillSearching = false
    for i = 1, self.PLAYER_COUNT do
        if i ~= playerIdx then
            local s = self.searches[i]
            if s.containerId == search.containerId and s.state == "searching" then
                stillSearching = true
                break
            end
        end
    end
    if container and not stillSearching and container.status == EM.CS.SEARCHING then
        container.status = EM.CS.OPEN
    end

    search.containerId = 0
    search.state       = "idle"
    search.timer       = 0
    search.progress    = 0   -- 离开容器时清零进度，防止进入新容器时 _GetNextSearchPos 找不到物品
end

--- 启动当前位置的搜索计时器
function ExtractionSession:_StartSearchTimer(playerIdx)
    local search    = self.searches[playerIdx]
    local container = self.containers[search.containerId]
    if not container then return end

    -- 找到下一个未搜索的位置
    local nextPos = self:_GetNextSearchPos(search.containerId, search.progress)
    if nextPos then
        local item = container.items[nextPos]
        search.timer    = item and item.searchTime or EM.SEARCH_TIME_BASE
        search.progress = nextPos - 1   -- progress 表示"上一个完成的位置"
    else
        -- 所有物品已搜索完
        search.state = "done"
    end
end

--- 获取容器中下一个待搜索的位置（跳过已取走）
--- progress 是"已完成的最后位置"
function ExtractionSession:_GetNextSearchPos(containerId, progress)
    local container = self.containers[containerId]
    if not container then return nil end

    -- 找第一个 pos > progress 且未 revealed 的物品
    local nextPos = nil
    for _, item in ipairs(container.items) do
        if item.pos > progress and not container.revealed[item.pos] then
            if not nextPos or item.pos < nextPos then
                nextPos = item.pos
            end
        end
    end
    return nextPos
end

-- ============================================================================
-- 放入物品到容器
-- ============================================================================

--- 玩家将物品放入容器
--- @param item table { name, baseValue }
--- @param containerId number
--- @param insertPos number|nil  -- nil 则追加到末尾
function ExtractionSession:PlayerInsertItem(playerIdx, item, containerId, insertPos)
    local container = self.containers[containerId]
    if not container then return end

    local items = container.items

    -- 构造新物品
    local newItem = {
        name        = item.name,
        baseValue   = item.baseValue or 0,
        searchTime  = CalcSearchTime(item.baseValue or 0),
    }

    -- 确定插入位置
    local maxPos = 0
    for _, it in ipairs(items) do
        if it.pos > maxPos then maxPos = it.pos end
    end

    -- 检查各玩家当前搜索进度，判断 insertPos 是否在所有搜索者的进度之前
    local minProgress = math.huge
    for i = 1, self.PLAYER_COUNT do
        local s = self.searches[i]
        if s.containerId == containerId and (s.state == "searching" or s.state == "opening") then
            minProgress = math.min(minProgress, s.progress)
        end
    end
    if minProgress == math.huge then minProgress = 0 end

    -- 决定实际插入的位置
    local actualPos
    if insertPos == nil then
        -- 无指定，追加末尾
        actualPos = maxPos + 1
    elseif insertPos <= minProgress then
        -- 放置位置在当前搜索进度之前 → 追加到队列末尾
        actualPos = maxPos + 1
    else
        -- 放置在队列中间：需要腾出位置，后续物品 pos+1
        actualPos = insertPos
        for _, it in ipairs(items) do
            if it.pos >= insertPos then
                it.pos = it.pos + 1
            end
        end
        -- 同步更新已揭示/已取走的位置映射
        local newRevealed = {}
        for pos, v in pairs(container.revealed) do
            if pos >= insertPos then newRevealed[pos + 1] = v
            else newRevealed[pos] = v end
        end
        container.revealed = newRevealed

        local newTaken = {}
        for pos, v in pairs(container.taken) do
            if pos >= insertPos then newTaken[pos + 1] = v
            else newTaken[pos] = v end
        end
        container.taken = newTaken

        -- 同步更新 revealedItems 字典键
        local toUpdate = {}
        for key, ri in pairs(self.revealedItems) do
            if ri.containerId == containerId and ri.pos >= insertPos then
                toUpdate[#toUpdate + 1] = { key = key, ri = ri }
            end
        end
        for _, entry in ipairs(toUpdate) do
            self.revealedItems[entry.key] = nil
            entry.ri.pos = entry.ri.pos + 1
            self.revealedItems[entry.ri.containerId .. "_" .. entry.ri.pos] = entry.ri
        end
    end

    newItem.pos = actualPos
    items[#items + 1] = newItem

    self:_Notify()
end

-- ============================================================================
-- 拾取物品（双击）
-- ============================================================================

--- 人类玩家单击/双击物品
--- @return boolean  true = 已触发拾取
function ExtractionSession:HumanTapItem(containerId, pos)
    local now  = self.elapsed
    local key  = containerId .. "_" .. pos

    -- 检查物品是否可拾取
    local ri = self.revealedItems[key]
    if not ri or not ri.available then return false end

    local last = self.lastTapItem
    if last and last.cid == containerId and last.pos == pos
        and (now - last.time) <= EM.DOUBLE_TAP_WINDOW then
        -- 双击确认拾取
        self.lastTapItem = nil
        self:_TakeItem(self.HUMAN_IDX, containerId, pos)
        return true
    else
        -- 第一次点击：记录时间
        self.lastTapItem = { cid = containerId, pos = pos, time = now }
        return false
    end
end

--- 实际拾取操作（内部）
function ExtractionSession:_TakeItem(playerIdx, containerId, pos)
    local key = containerId .. "_" .. pos
    local ri  = self.revealedItems[key]
    if not ri or not ri.available then return end

    local bp = self.backpacks[playerIdx]
    if #bp >= self.backpackCapacity then
        -- 背包已满，不能拾取
        if self.onBackpackFull then self.onBackpackFull(playerIdx) end
        return
    end

    ri.available = false
    local container = self.containers[containerId]
    if container then container.taken[pos] = true end

    bp[#bp + 1] = ri.item

    if self.onTake then
        self.onTake(containerId, pos, ri.item, playerIdx)
    end
    self:_Notify()
end

-- ============================================================================
-- 主更新循环
-- ============================================================================

--- 每帧调用，dt 为秒
function ExtractionSession:Update(dt)
    if self.gameOver then return end
    self.elapsed = self.elapsed + dt

    -- 更新开箱计时器
    for _, container in ipairs(self.containers) do
        if container.status == EM.CS.OPENING then
            container.openTimer = container.openTimer - dt
            if container.openTimer <= 0 then
                container.openTimer = 0
                container.status    = EM.CS.OPEN
                container.openedAt  = self.elapsed
                -- 通知等待开箱的玩家进入搜索
                self:_OnContainerOpened(container.id)
                self:_Notify()
            end
        end
    end

    -- 更新玩家搜索进度
    for i = 1, self.PLAYER_COUNT do
        self:_UpdatePlayerSearch(i, dt)
    end

    -- AI 决策
    for i = 2, self.PLAYER_COUNT do
        self:_UpdateAI(i, dt)
    end

    -- 检查游戏结束条件（所有容器清空或时间耗尽）
    self:_CheckGameOver()
end

--- 容器开箱完成后的处理：所有在此等待的玩家开始搜索
function ExtractionSession:_OnContainerOpened(containerId)
    for i = 1, self.PLAYER_COUNT do
        local s = self.searches[i]
        if s.containerId == containerId and s.state == "opening" then
            s.state = "searching"
            self:_StartSearchTimer(i)
        end
    end
end

--- 更新单个玩家的搜索进度
function ExtractionSession:_UpdatePlayerSearch(playerIdx, dt)
    local search    = self.searches[playerIdx]
    if search.state ~= "searching" then return end
    if search.containerId == 0 then return end

    local container = self.containers[search.containerId]
    if not container then return end

    search.timer = search.timer - dt
    if search.timer > 0 then return end

    -- 搜索完成当前位置
    local nextPos = self:_GetNextSearchPos(search.containerId, search.progress)
    if not nextPos then
        -- 所有物品搜完
        search.state = "done"
        self:_CheckContainerEmptied(search.containerId)
        return
    end

    -- 揭示该物品
    local item = container.items[nextPos]
    if item then
        container.revealed[nextPos] = true
        search.progress = nextPos

        -- 加入待拾取列表
        local key = search.containerId .. "_" .. nextPos
        if not container.taken[nextPos] then
            self.revealedItems[key] = {
                containerId = search.containerId,
                pos         = nextPos,
                item        = item,
                revealedBy  = playerIdx,
                available   = true,
            }
        end

        if self.onReveal then
            self.onReveal(search.containerId, nextPos, item, playerIdx)
        end
        self:_Notify()
    end

    -- 继续搜索下一件
    local afterPos = self:_GetNextSearchPos(search.containerId, search.progress)
    if afterPos then
        local nextItem = container.items[afterPos]
        search.timer = nextItem and nextItem.searchTime or EM.SEARCH_TIME_BASE
    else
        search.state = "done"
        self:_CheckContainerEmptied(search.containerId)
    end
end

--- 检查容器是否已被完全搜索并清空
function ExtractionSession:_CheckContainerEmptied(containerId)
    local container = self.containers[containerId]
    if not container then return end

    -- 检查是否所有物品都已 revealed
    local allRevealed = true
    for _, item in ipairs(container.items) do
        if not container.revealed[item.pos] then
            allRevealed = false
            break
        end
    end
    if allRevealed then
        container.status = EM.CS.EMPTIED
        self:_Notify()
    end
end

-- ============================================================================
-- AI 决策
-- ============================================================================

--- 初始给 AI 分配目标容器（分散到不同容器）
function ExtractionSession:_AIAssignInitialTargets()
    local used = {}
    for i = 2, self.PLAYER_COUNT do
        local c = 0
        for attempt = 1, 20 do
            local candidate = math.random(1, EM.CONTAINER_COUNT)
            if not used[candidate] then
                c = candidate
                used[candidate] = true
                break
            end
        end
        if c == 0 then c = i end   -- fallback
        self.aiTargetContainers[i] = c
        self.searches[i].state     = "moving"
        self.searches[i].moveTimer = EM.AI_MOVE_TIME_MIN
            + math.random() * (EM.AI_MOVE_TIME_MAX - EM.AI_MOVE_TIME_MIN)
    end
end

--- 每帧 AI 行为更新
function ExtractionSession:_UpdateAI(aiIdx, dt)
    local search = self.searches[aiIdx]

    if search.state == "moving" then
        search.moveTimer = search.moveTimer - dt
        if search.moveTimer <= 0 then
            -- 到达目标容器
            local targetCid = self.aiTargetContainers[aiIdx]
            if targetCid > 0 then
                self:PlayerEnterContainer(aiIdx, targetCid)
            end
        end

    elseif search.state == "done" or search.state == "idle" then
        -- 寻找下一个有物品的容器
        local nextCid = self:_AIPickNextContainer(aiIdx)
        if nextCid then
            self.aiTargetContainers[aiIdx] = nextCid
            search.state     = "moving"
            search.moveTimer = EM.AI_MOVE_TIME_MIN
                + math.random() * (EM.AI_MOVE_TIME_MAX - EM.AI_MOVE_TIME_MIN)
        end

        -- AI 拾取逻辑：检查周围揭示物品
        self:_AIPickupNearby(aiIdx, dt)

    elseif search.state == "searching" then
        -- AI 主动拾取已揭示但未被取走的物品
        self:_AIPickupNearby(aiIdx, dt)
    end
end

--- AI 选择下一个目标容器
function ExtractionSession:_AIPickNextContainer(aiIdx)
    -- 优先选择有揭示物品未取走的容器
    for cid, container in ipairs(self.containers) do
        if container.status ~= EM.CS.EMPTIED then
            for _, item in ipairs(container.items) do
                local key = cid .. "_" .. item.pos
                local ri  = self.revealedItems[key]
                if ri and ri.available then
                    return cid
                end
            end
        end
    end

    -- 选最近的未清空容器
    for cid, container in ipairs(self.containers) do
        if container.status ~= EM.CS.EMPTIED then
            -- 排除当前 AI 已经在的容器
            local sameContainer = false
            for i = 2, self.PLAYER_COUNT do
                if i ~= aiIdx and self.searches[i].containerId == cid then
                    sameContainer = true
                    break
                end
            end
            if not sameContainer then
                return cid
            end
        end
    end

    -- 实在没有就随便找一个
    for cid, container in ipairs(self.containers) do
        if container.status ~= EM.CS.EMPTIED then
            return cid
        end
    end

    return nil
end

--- AI 拾取周围已揭示物品（简单策略：拾取当前容器的揭示物品）
function ExtractionSession:_AIPickupNearby(aiIdx, dt)
    local search = self.searches[aiIdx]
    local cid    = search.containerId
    if cid == 0 then return end

    local bp = self.backpacks[aiIdx]
    if #bp >= self.backpackCapacity then return end

    for key, ri in pairs(self.revealedItems) do
        if ri.containerId == cid and ri.available then
            self:_TakeItem(aiIdx, ri.containerId, ri.pos)
            return  -- 每帧只取一件
        end
    end
end

-- ============================================================================
-- 游戏结束检查
-- ============================================================================

function ExtractionSession:_CheckGameOver()
    -- 所有容器清空
    local allEmpty = true
    for _, container in ipairs(self.containers) do
        if container.status ~= EM.CS.EMPTIED then
            allEmpty = false
            break
        end
    end

    -- 还有揭示但未取走的物品不算结束
    if allEmpty then
        local anyLeft = false
        for _, ri in pairs(self.revealedItems) do
            if ri.available then anyLeft = true; break end
        end
        if not anyLeft then
            self:_TriggerGameOver()
        end
    end
end

function ExtractionSession:_TriggerGameOver()
    if self.gameOver then return end
    self.gameOver = true

    -- 统计结果
    local humanItems = self.backpacks[self.HUMAN_IDX]
    local totalValue = 0
    for _, item in ipairs(humanItems) do
        totalValue = totalValue + (item.baseValue or 0)
    end

    self.gameOverResult = {
        items      = humanItems,
        totalValue = totalValue,
        entryFee   = self.entryFee,
        profit     = totalValue - self.entryFee,
    }

    if self.onGameOver then
        self.onGameOver(self.gameOverResult)
    end
end

--- 玩家主动撤离
function ExtractionSession:HumanExtract()
    if self.gameOver then return end
    self:_TriggerGameOver()
end

-- ============================================================================
-- 通知
-- ============================================================================

function ExtractionSession:_Notify()
    if self.onStateChange then
        self.onStateChange(self)
    end
end

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 获取容器状态摘要（供 UI 渲染）
function ExtractionSession:GetContainerSummary(cid)
    local container = self.containers[cid]
    if not container then return nil end

    local searchers = {}
    for i = 1, self.PLAYER_COUNT do
        local s = self.searches[i]
        if s.containerId == cid then
            searchers[#searchers + 1] = i
        end
    end

    return {
        id         = cid,
        name       = container.name,
        status     = container.status,
        openTimer  = container.openTimer,
        itemCount  = #container.items,
        searchers  = searchers,
    }
end

--- 获取容器内所有可见物品（已揭示）
function ExtractionSession:GetVisibleItems(cid)
    local result = {}
    for key, ri in pairs(self.revealedItems) do
        if ri.containerId == cid then
            result[#result + 1] = ri
        end
    end
    table.sort(result, function(a, b) return a.pos < b.pos end)
    return result
end

--- 获取玩家背包
function ExtractionSession:GetBackpack(playerIdx)
    return self.backpacks[playerIdx] or {}
end

--- 获取搜索进度百分比（0~1）
function ExtractionSession:GetSearchProgress(cid)
    local container = self.containers[cid]
    if not container or #container.items == 0 then return 1 end
    local revealedCount = 0
    for pos, _ in pairs(container.revealed) do
        revealedCount = revealedCount + 1
    end
    return revealedCount / #container.items
end

return EM
