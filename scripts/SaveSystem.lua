-- ============================================================================
-- SaveSystem.lua - 单槽位云端存档系统
-- 云端优先，本地缓存，分片存储
-- ============================================================================
-- 架构：
--   云端是权威数据源（WASM 每次启动本地为空）
--   先写本地保证不丢，再异步上传云端
--   单 key 限制约 10KB，物品数据自动分片
-- ============================================================================

local Config = require("Config")
local WarehouseUpgrade = require("Config.WarehouseUpgrade")

local SaveSystem = {}

---@diagnostic disable: undefined-global

-- ============================================================================
-- 常量
-- ============================================================================

local CURRENT_VERSION = 1           -- 存档数据版本号
local CHUNK_SIZE = 8000             -- 单 key 最大字节数（留余量）
local SAVE_INTERVAL = 60            -- 自动保存间隔（秒）
local DIRTY_DELAY = 5               -- MarkDirty 延迟合并（秒）
local MAX_RETRY = 3                 -- 云端保存最大重试次数
local RETRY_INTERVAL = 10           -- 重试间隔（秒）

-- 云端 key 名
local KEY_HEAD  = "save_head"
local KEY_CORE  = "save_core"
local KEY_ITEMS = "save_items"
local KEY_STATS = "save_stats"

-- 本地文件名
local LOCAL_FILE = "save_data.json"

-- ============================================================================
-- 内部状态
-- ============================================================================

local initialized = false
local saveConfirmed = false         -- 云端数据已成功加载
local dirty = false                 -- 有未保存的改动
local dirtyTimer = 0                -- MarkDirty 延迟计时器
local autoSaveTimer = 0             -- 自动保存计时器
local retryTimer = 0                -- 云端重试计时器
local retryCount = 0                -- 当前重试次数
local pendingSave = false           -- 有待重试的保存
local playTime = 0                  -- 累计游戏时长

-- 运行时存档数据
local saveData = {
    version = CURRENT_VERSION,
    timestamp = 0,
    playTime = 0,
    core = {
        -- 核心数据由 MoneyManager 管理，这里记录统计
    },
    warehouseLevel = 1,             -- 仓库等级（1-3）
    items = {},                     -- 玩家拥有的物品列表
    stats = {
        totalGames = 0,             -- 总场次
        wins = 0,                   -- 胜场
        totalProfit = 0,            -- 累计利润
        totalItemsWon = 0,          -- 累计获得物品数
    },
    settings = {                    -- 用户设置
        bgmVolume = 100,
        sfxVolume = 100,

    },
}

-- ============================================================================
-- DJB2 校验
-- ============================================================================

local function CalcChecksum(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash << 5) + hash + string.byte(str, i)) & 0xFFFFFFFF
    end
    return hash
end

-- ============================================================================
-- 数据压缩：存档物品用短 key 节省空间
-- ============================================================================

-- 物品字段映射：长 key → 短 key
local ITEM_FIELD_MAP = {
    name     = "n",
    rarity   = "r",
    w        = "w",
    h        = "h",
    baseValue = "v",
    category = "c",
    image    = "i",
    desc     = "d",
    wonAt    = "t",     -- 获得时间戳
    gridX    = "gx",    -- 网格列位置 (1-based)
    gridY    = "gy",    -- 网格行位置 (1-based)
}

-- 反向映射
local ITEM_FIELD_REVERSE = {}
for long, short in pairs(ITEM_FIELD_MAP) do
    ITEM_FIELD_REVERSE[short] = long
end

--- 压缩单个物品（长 key → 短 key，去除默认值）
local function compressItem(item)
    local c = {}
    for long, short in pairs(ITEM_FIELD_MAP) do
        local val = item[long]
        if val ~= nil and val ~= "" and val ~= 0 then
            c[short] = val
        end
    end
    return c
end

--- 解压单个物品（短 key → 长 key，补回默认值）
local function decompressItem(c)
    local item = {}
    for short, long in pairs(ITEM_FIELD_REVERSE) do
        item[long] = c[short]
    end
    -- 补回默认值
    item.w = item.w or 1
    item.h = item.h or 1
    item.baseValue = item.baseValue or 0
    item.rarity = item.rarity or "white"
    item.category = item.category or ""
    item.desc = item.desc or ""
    item.image = item.image or ""
    -- gridX/gridY: nil 表示未放置（旧存档兼容）
    return item
end

-- ============================================================================
-- 分组与分片
-- ============================================================================

--- 将存档数据拆分为功能组
local function splitIntoGroups()
    -- core 组：统计信息
    local core = {
        version = saveData.version,
        timestamp = os.time(),
        playTime = saveData.playTime,
        warehouseLevel = saveData.warehouseLevel or 1,
    }

    -- items 组：压缩后的物品列表
    local compressedItems = {}
    for i, item in ipairs(saveData.items) do
        compressedItems[i] = compressItem(item)
    end
    local items = { list = compressedItems }

    -- stats 组
    local stats = {}
    for k, v in pairs(saveData.stats) do
        stats[k] = v
    end

    -- settings 组
    local settings = {}
    for k, v in pairs(saveData.settings) do
        settings[k] = v
    end

    return {
        core = core,
        items = items,
        stats = stats,
        settings = settings,
    }
end

--- 将各组合并还原为完整 saveData
local function mergeGroups(groups)
    local data = {
        version = CURRENT_VERSION,
        timestamp = 0,
        playTime = 0,
        warehouseLevel = 1,
        items = {},
        stats = {
            totalGames = 0,
            wins = 0,
            totalProfit = 0,
            totalItemsWon = 0,
        },
    }

    -- core
    if groups.core then
        data.version = groups.core.version or CURRENT_VERSION
        data.timestamp = groups.core.timestamp or 0
        data.playTime = groups.core.playTime or 0
        data.warehouseLevel = groups.core.warehouseLevel or 1
    end

    -- items：解压
    if groups.items and groups.items.list then
        for i, c in ipairs(groups.items.list) do
            data.items[i] = decompressItem(c)
        end
    end

    -- stats
    if groups.stats then
        for k, v in pairs(groups.stats) do
            data.stats[k] = v
        end
    end

    -- settings（始终初始化默认值，旧存档需要迁移）
    data.settings = {
        bgmVolume = 100,
        sfxVolume = 100,
    }
    if groups.settings then
        if groups.settings.bgmVolume then data.settings.bgmVolume = groups.settings.bgmVolume end
        if groups.settings.sfxVolume then data.settings.sfxVolume = groups.settings.sfxVolume end
    end

    return data
end

--- 将单个组 JSON 编码后按 CHUNK_SIZE 分片
local function encodeAndChunk(groupData)
    local json = cjson.encode(groupData)
    local len = #json
    if len <= CHUNK_SIZE then
        return { json }, CalcChecksum(json), len
    end
    -- 分片
    local chunks = {}
    for i = 1, len, CHUNK_SIZE do
        chunks[#chunks + 1] = json:sub(i, math.min(i + CHUNK_SIZE - 1, len))
    end
    local checksums = {}
    local lengths = {}
    for i, chunk in ipairs(chunks) do
        checksums[i] = CalcChecksum(chunk)
        lengths[i] = #chunk
    end
    return chunks, checksums, lengths
end

-- ============================================================================
-- 本地存储（运行时缓存）
-- ============================================================================

local function saveLocal()
    local ok, json = pcall(cjson.encode, saveData)
    if not ok then
        print("[SaveSystem] Local encode failed: " .. tostring(json))
        return
    end
    -- 先写临时文件再改名（原子写入）
    local tmpFile = File(LOCAL_FILE .. ".tmp", FILE_WRITE)
    if tmpFile and tmpFile:IsOpen() then
        tmpFile:WriteString(json)
        tmpFile:Close()
    end
    local file = File(LOCAL_FILE, FILE_WRITE)
    if file and file:IsOpen() then
        file:WriteString(json)
        file:Close()
    end
    print("[SaveSystem] Local save OK (" .. #json .. " bytes, " .. #saveData.items .. " items)")
end

local function loadLocal()
    if not fileSystem:FileExists(LOCAL_FILE) then return false end
    local file = File(LOCAL_FILE, FILE_READ)
    if not file or not file:IsOpen() then return false end
    local json = file:ReadString()
    file:Close()
    if not json or #json == 0 then return false end
    local ok, data = pcall(cjson.decode, json)
    if not ok then
        print("[SaveSystem] Local decode failed")
        return false
    end
    saveData = data
    -- 确保字段存在
    saveData.stats = saveData.stats or {}
    saveData.items = saveData.items or {}
    saveData.warehouseLevel = saveData.warehouseLevel or 1
    saveData.settings = saveData.settings or {}
    saveData.settings.bgmVolume = saveData.settings.bgmVolume or 100
    saveData.settings.sfxVolume = saveData.settings.sfxVolume or 100
    print("[SaveSystem] Local load OK (" .. #saveData.items .. " items)")
    return true
end

-- ============================================================================
-- 云端读写
-- ============================================================================

--- 保存到云端（分片 + 批量写入）
local function saveCloud(onComplete)
    if not clientCloud then
        print("[SaveSystem] clientCloud not available, skipping cloud save")
        if onComplete then onComplete(true) end
        return
    end

    local groups = splitIntoGroups()

    -- 编码各组
    local batch = clientCloud:BatchSet()
    local headKeys = {}

    for groupName, groupData in pairs(groups) do
        local chunks, checksums, lengths = encodeAndChunk(groupData)
        local keyBase = "save_" .. groupName

        if #chunks == 1 then
            -- 单片
            batch:Set(keyBase, chunks[1])
            headKeys[groupName] = {
                cs = checksums,
                len = lengths,
            }
        else
            -- 多片
            for i, chunk in ipairs(chunks) do
                batch:Set(keyBase .. "_" .. (i - 1), chunk)
            end
            headKeys[groupName] = {
                chunks = #chunks,
                cs = checksums,
                len = lengths,
            }
        end
    end

    -- 写入 head
    local head = {
        format = 1,
        version = saveData.version,
        timestamp = os.time(),
        keys = headKeys,
    }
    batch:Set(KEY_HEAD, head)

    batch:Save("save_game", {
        ok = function()
            retryCount = 0
            pendingSave = false
            print("[SaveSystem] Cloud save OK (" .. #saveData.items .. " items)")
            if onComplete then onComplete(true) end
        end,
        error = function(code, reason)
            print("[SaveSystem] Cloud save failed: " .. tostring(reason))
            pendingSave = true
            if onComplete then onComplete(false) end
        end,
    })
end

--- 从云端加载
local function loadCloud(onComplete)
    if not clientCloud then
        print("[SaveSystem] clientCloud not available")
        onComplete(false, "no clientCloud")
        return
    end

    -- 先读 head
    clientCloud:Get(KEY_HEAD, {
        ok = function(values, iscores)
            local head = values[KEY_HEAD]
            if not head then
                print("[SaveSystem] No cloud save found (new player)")
                onComplete(false, "no_data")
                return
            end

            -- head 可能是 table（由 Set() 写入时自动编解码）
            if type(head) == "string" then
                local ok2, parsed = pcall(cjson.decode, head)
                if ok2 then head = parsed end
            end

            if type(head) ~= "table" or not head.keys then
                print("[SaveSystem] Invalid head format")
                onComplete(false, "invalid_head")
                return
            end

            -- 收集所有需要读取的 key
            local keysToRead = {}
            for groupName, info in pairs(head.keys) do
                local keyBase = "save_" .. groupName
                if info.chunks and info.chunks > 1 then
                    for i = 0, info.chunks - 1 do
                        keysToRead[#keysToRead + 1] = keyBase .. "_" .. i
                    end
                else
                    keysToRead[#keysToRead + 1] = keyBase
                end
            end

            if #keysToRead == 0 then
                print("[SaveSystem] No group keys in head")
                onComplete(false, "empty_head")
                return
            end

            -- 批量读取所有组
            local batchGet = clientCloud:BatchGet()
            for _, key in ipairs(keysToRead) do
                batchGet:Key(key)
            end

            batchGet:Fetch({
                ok = function(vals, _)
                    -- 解析各组
                    local groups = {}
                    for groupName, info in pairs(head.keys) do
                        local keyBase = "save_" .. groupName
                        local json
                        if info.chunks and info.chunks > 1 then
                            -- 多片拼接
                            local parts = {}
                            for i = 0, info.chunks - 1 do
                                local part = vals[keyBase .. "_" .. i]
                                if not part then
                                    print("[SaveSystem] Missing chunk: " .. keyBase .. "_" .. i)
                                    onComplete(false, "missing_chunk")
                                    return
                                end
                                parts[#parts + 1] = part
                            end
                            json = table.concat(parts)
                        else
                            json = vals[keyBase]
                        end

                        if json then
                            -- 如果已经是 table（clientCloud:Set 写 table 时会自动编解码）
                            if type(json) == "table" then
                                groups[groupName] = json
                            else
                                -- 校验
                                if type(info.cs) == "number" then
                                    local cs = CalcChecksum(json)
                                    if cs ~= info.cs then
                                        print("[SaveSystem] Checksum mismatch for " .. groupName)
                                    end
                                end
                                local ok3, parsed = pcall(cjson.decode, json)
                                if ok3 then
                                    groups[groupName] = parsed
                                else
                                    print("[SaveSystem] Decode failed for " .. groupName)
                                end
                            end
                        end
                    end

                    -- 合并
                    saveData = mergeGroups(groups)
                    saveLocal() -- 缓存到本地
                    print("[SaveSystem] Cloud load OK (" .. #saveData.items .. " items)")
                    onComplete(true)
                end,
                error = function(code, reason)
                    print("[SaveSystem] Cloud batch read failed: " .. tostring(reason))
                    onComplete(false, reason)
                end,
            })
        end,
        error = function(code, reason)
            print("[SaveSystem] Cloud head read failed: " .. tostring(reason))
            onComplete(false, reason)
        end,
    })
end

-- ============================================================================
-- 版本迁移
-- ============================================================================

local MIGRATIONS = {
    -- [1] = function(data) ... end,  -- v1 → v2 时添加
}

local function runMigrations()
    while saveData.version < CURRENT_VERSION do
        local fn = MIGRATIONS[saveData.version]
        if fn then
            fn(saveData)
            saveData.version = saveData.version + 1
            print("[SaveSystem] Migrated to v" .. saveData.version)
        else
            break
        end
    end
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 初始化：从云端加载存档
---@param onReady function(success: boolean, isNewPlayer: boolean)
function SaveSystem.Init(onReady)
    if initialized then
        if onReady then onReady(true, false) end
        return
    end

    print("[SaveSystem] Init: loading from cloud...")
    loadCloud(function(success, reason)
        if success then
            runMigrations()
            saveConfirmed = true
            initialized = true
            print("[SaveSystem] Ready. Items: " .. #saveData.items
                .. ", Games: " .. (saveData.stats.totalGames or 0))
            if onReady then onReady(true, false) end
        elseif reason == "no_data" then
            -- 云端无数据 = 新玩家
            saveConfirmed = true
            initialized = true
            saveLocal() -- 初始化本地缓存
            print("[SaveSystem] New player, empty save")
            if onReady then onReady(true, true) end
        else
            -- 云端加载失败（网络等问题），不 fallback 本地
            print("[SaveSystem] Cloud load failed: " .. tostring(reason))
            if onReady then onReady(false, false) end
        end
    end)
end

--- 常规保存（本地 + 异步云端）
function SaveSystem.Save()
    if not saveConfirmed then return end
    saveData.timestamp = os.time()
    saveData.playTime = playTime
    saveLocal()
    saveCloud()
    dirty = false
    dirtyTimer = 0
    autoSaveTimer = 0
end

--- 立即保存（关键事件：竞拍结束、购买等）
function SaveSystem.SaveNow()
    if not saveConfirmed then return end
    SaveSystem.Save()
end

--- 标记脏数据（延迟合并）
function SaveSystem.MarkDirty()
    dirty = true
    dirtyTimer = DIRTY_DELAY
end

--- 每帧调用
function SaveSystem.Update(dt)
    if not initialized then return end

    playTime = playTime + dt

    -- 脏标记延迟保存
    if dirty and dirtyTimer > 0 then
        dirtyTimer = dirtyTimer - dt
        if dirtyTimer <= 0 then
            SaveSystem.Save()
        end
    end

    -- 自动保存
    autoSaveTimer = autoSaveTimer + dt
    if autoSaveTimer >= SAVE_INTERVAL then
        autoSaveTimer = 0
        if saveConfirmed then
            SaveSystem.Save()
        end
    end

    -- 云端重试
    if pendingSave then
        retryTimer = retryTimer + dt
        if retryTimer >= RETRY_INTERVAL and retryCount < MAX_RETRY then
            retryTimer = 0
            retryCount = retryCount + 1
            print("[SaveSystem] Retrying cloud save (" .. retryCount .. "/" .. MAX_RETRY .. ")")
            saveCloud()
        end
    end
end

-- ============================================================================
-- 业务接口
-- ============================================================================

--- 添加战利品物品（竞拍结束后调用，保留网格位置）
---@param warehouseItems table 物品列表（需含 w, h，可选 gridX, gridY）
function SaveSystem.AddWonItems(warehouseItems)
    local now = os.time()
    for _, item in ipairs(warehouseItems) do
        saveData.items[#saveData.items + 1] = {
            name = item.name,
            rarity = item.rarity,
            w = item.w,
            h = item.h,
            baseValue = item.baseValue or item.realValue or item.value or 0,
            category = item.category or "",
            image = item.image or "",
            desc = item.desc or "",
            wonAt = now,
            gridX = item.gridX,  -- 网格列位置（由 WarehouseGrid 设置）
            gridY = item.gridY,  -- 网格行位置
        }
    end
    saveData.stats.totalItemsWon = (saveData.stats.totalItemsWon or 0) + #warehouseItems
    print("[SaveSystem] Added " .. #warehouseItems .. " items. Total: " .. #saveData.items)
end

--- 移除指定物品列表（按引用匹配 name+wonAt，用于回收）
---@param itemsToRemove table[] 要移除的物品
function SaveSystem.RemoveItems(itemsToRemove)
    -- 建立待移除物品的标记集合
    local removeSet = {}
    for _, item in ipairs(itemsToRemove) do
        removeSet[item] = true
    end
    -- 通过 name+rarity+wonAt 匹配（因为 itemsToRemove 来自 GetItems 的引用）
    local newItems = {}
    local removed = 0
    for _, item in ipairs(saveData.items) do
        if removeSet[item] then
            removed = removed + 1
        else
            newItems[#newItems + 1] = item
        end
    end
    saveData.items = newItems
    print("[SaveSystem] Removed " .. removed .. " items. Remaining: " .. #saveData.items)
end

--- 记录一场游戏结果
---@param isWin boolean 是否赢了
---@param profit number 利润（正/负）
function SaveSystem.RecordGameResult(isWin, profit)
    saveData.stats.totalGames = (saveData.stats.totalGames or 0) + 1
    if isWin then
        saveData.stats.wins = (saveData.stats.wins or 0) + 1
    end
    saveData.stats.totalProfit = (saveData.stats.totalProfit or 0) + profit
    print("[SaveSystem] Game recorded. Total: " .. saveData.stats.totalGames
        .. ", Wins: " .. saveData.stats.wins)
end

--- 获取玩家拥有的所有物品
---@return table
function SaveSystem.GetItems()
    return saveData.items
end

--- 获取统计数据
---@return table
function SaveSystem.GetStats()
    return saveData.stats
end

--- 获取物品数量
---@return number
function SaveSystem.GetItemCount()
    return #saveData.items
end

--- 获取累计游戏时长
---@return number
function SaveSystem.GetPlayTime()
    return playTime
end

--- 存档是否已加载
---@return boolean
function SaveSystem.IsReady()
    return initialized and saveConfirmed
end

-- ============================================================================
-- 仓库等级接口
-- ============================================================================

--- 获取当前仓库等级
---@return number
function SaveSystem.GetWarehouseLevel()
    return saveData.warehouseLevel or 1
end

--- 获取当前仓库容量
---@return number
function SaveSystem.GetWarehouseCapacity()
    return WarehouseUpgrade.GetCapacity(saveData.warehouseLevel or 1)
end

--- 执行仓库升级（消耗物品和金币）
---@param currentGold number 当前金币数
---@param deductGoldFn function(amount) 扣金币的回调
---@return boolean success
---@return string|nil error
function SaveSystem.UpgradeWarehouse(currentGold, deductGoldFn)
    local level = saveData.warehouseLevel or 1
    if level >= WarehouseUpgrade.MAX_LEVEL then
        return false, "already_max"
    end

    local canUpgrade, details = WarehouseUpgrade.CheckUpgrade(level, saveData.items, currentGold)
    if not canUpgrade then
        return false, "not_enough"
    end

    -- 消耗物品
    local _, goldCost = WarehouseUpgrade.ConsumeItems(level, saveData.items)

    -- 扣金币
    if deductGoldFn then
        deductGoldFn(goldCost)
    end

    -- 升级
    saveData.warehouseLevel = level + 1
    print("[SaveSystem] Warehouse upgraded to Lv." .. saveData.warehouseLevel
        .. " (capacity: " .. WarehouseUpgrade.GetCapacity(saveData.warehouseLevel) .. ")")

    -- 立即保存
    SaveSystem.SaveNow()
    return true
end

--- 从物品列表中删除指定物品（按名称和数量）
---@param name string
---@param count number
function SaveSystem.RemoveItemsByName(name, count)
    local remaining = count
    for i = #saveData.items, 1, -1 do
        if remaining <= 0 then break end
        if saveData.items[i].name == name then
            table.remove(saveData.items, i)
            remaining = remaining - 1
        end
    end
end

-- ============================================================================
-- 用户设置接口
-- ============================================================================

--- 获取用户设置
---@return table { bgmVolume, sfxVolume }
function SaveSystem.GetSettings()
    if not saveData.settings then
        saveData.settings = {
            bgmVolume = 100, sfxVolume = 100,
        }
    end
    return saveData.settings
end

--- 更新用户设置（合并传入的字段，触发延迟保存）
---@param patch table 要更新的字段
function SaveSystem.UpdateSettings(patch)
    SaveSystem.GetSettings() -- 确保 settings 已初始化
    for k, v in pairs(patch) do
        saveData.settings[k] = v
    end
    SaveSystem.MarkDirty()
end

return SaveSystem
