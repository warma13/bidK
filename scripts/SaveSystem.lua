-- ============================================================================
-- SaveSystem.lua - 存档模块（注册到 SaveFramework）
-- ============================================================================
-- 架构：
--   SaveSystem/Codec.lua      编解码、校验、分片
--   SaveSystem/History.lua    对局历史环形缓冲区
--   SaveSystem/Migration.lua  版本迁移
--
-- 外部 API 完全不变：
--   Init, Save, SaveNow, MarkDirty, IsReady, Update
--   PauseForGame, ResumeAfterGame
--   AddWonItems, RemoveItems, RemoveItemsByName, GetItems, GetItemCount
--   RecordGameResult, GetStats
--   GetSettings, UpdateSettings
--   GetTicketCount, AddTickets, ConsumeTicket
--   GetCharacterCoins, AddCharacterCoins, SpendCharacterCoins
--   IsCharacterUnlocked, UnlockCharacter
--   GetWarehouseLevel, GetWarehouseCapacity, UpgradeWarehouse
--   GetPlayTime, AddGameHistory, GetGameHistory, LoadHistory
-- ============================================================================

local Config          = require("Config")
local WarehouseUpgrade = require("Config.WarehouseUpgrade")
local AntiCheat       = require("AntiCheat")
local SaveFramework   = require("SaveFramework")
local Codec           = require("SaveSystem.Codec")
local History         = require("SaveSystem.History")
local Migration       = require("SaveSystem.Migration")

local SaveSystem = {}

---@diagnostic disable: undefined-global

-- ============================================================================
-- 常量
-- ============================================================================

local CURRENT_VERSION = 3
local MODULE_NAME     = "save"

-- 云端 key 名
local KEY_HEAD     = "save_head"
local KEY_CORE     = "save_core"
local KEY_ITEMS    = "save_items"
local KEY_STATS    = "save_stats"
local KEY_SETTINGS = "save_settings"
local KEY_HIST_HEAD = History.KEY_HIST_HEAD   -- "save_hist_head"
local HIST_SLOTS    = History.HIST_SLOTS       -- 10

-- 本地文件名
local LOCAL_FILE = "save_data.json"

-- ============================================================================
-- 内部状态
-- ============================================================================

local initialized  = false
local saveConfirmed = false
local playTime     = 0
local playTimeAtLastDirty  = 0
local PLAY_TIME_DIRTY_INTERVAL = 60

-- 增量写入 checksum 缓存
-- lastSaved* 在保存成功后提交；pending* 在 writeBatch 时暂存，成功后才提交
local lastSavedChecksums = {}  -- { groupName -> checksum_string }
local lastHeadEntries    = {}  -- { groupName -> head entry table }（用于 HEAD 重建）
local pendingChecksums   = {}  -- 本次 writeBatch 计算的 checksums
local pendingHeadEntries = {}  -- 本次 writeBatch 计算的 head entries

local function checksumStr(cs)
    if type(cs) == "table" then return table.concat(cs, ",") end
    return tostring(cs)
end

-- 运行时存档数据
local saveData = {
    version = CURRENT_VERSION,
    timestamp = 0,
    playTime  = 0,
    core      = {},
    warehouseLevel = 1,
    items     = {},
    stats = {
        totalGames    = 0,
        wins          = 0,
        totalProfit   = 0,
        totalLoss     = 0,
        totalItemsWon = 0,
        maxProfit     = 0,
        maxLoss       = 0,
        highestBid    = 0,
        ticketGames   = 0,
        redItemsWon   = 0,
    },
    settings = {
        bgmVolume = 100,
        sfxVolume = 100,
    },
    tickets            = {},
    characterCoins     = 0,
    unlockedCharacters = {},
    propItems          = {},
    gameHistory        = {},
    mailRead           = {},    -- { [mailId] = true }
    mailClaimed        = {},    -- { [mailId] = true }
    overflowMails      = {},    -- 开箱仓库满时的溢出物品邮件
}

-- ============================================================================
-- 本地存储
-- 注意：WASM 平台（Web）下文件系统沙箱基于 IndexedDB，属于浏览器临时存储，
-- 清除浏览器缓存/隐身模式/跨设备 均会导致本地文件丢失。
-- 因此本地文件仅作为"本次会话的内存镜像"和"移动端离线加速"使用，
-- 不可作为防回档或数据可靠性的依据——云端 cloudKeys 才是唯一可信来源。
-- ============================================================================

local function saveLocal()
    local ok, json = pcall(cjson.encode, saveData)
    if not ok then
        print("[SaveSystem] Local encode failed: " .. tostring(json))
        return
    end
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
    saveData.stats    = saveData.stats    or {}
    saveData.items    = saveData.items    or {}
    saveData.warehouseLevel = saveData.warehouseLevel or 1
    saveData.settings = saveData.settings or {}
    saveData.settings.bgmVolume = saveData.settings.bgmVolume or 100
    saveData.settings.sfxVolume = saveData.settings.sfxVolume or 100
    if saveData.settings.glowEffect == nil then
        local platform = GetPlatform and GetPlatform() or ""
        local isMobile = (platform == "Android" or platform == "iOS" or platform == "Web")
        saveData.settings.glowEffect = not isMobile
    end
    saveData.tickets            = saveData.tickets            or {}
    saveData.characterCoins     = saveData.characterCoins     or 0
    saveData.unlockedCharacters = saveData.unlockedCharacters or {}
    saveData.propItems          = saveData.propItems          or {}
    saveData.gameHistory        = saveData.gameHistory        or {}
    saveData.mailRead           = saveData.mailRead           or {}
    saveData.mailClaimed        = saveData.mailClaimed        or {}
    saveData.overflowMails      = saveData.overflowMails      or {}
    print("[SaveSystem] Local load OK (" .. #saveData.items .. " items)")
    return true
end

-- ============================================================================
-- 分组拆分 / 合并
-- ============================================================================

-- 独立分组的字段（不自动收入 core）
local SPLIT_GROUPS = { items = true, stats = true, settings = true, gameHistory = true }

local function splitIntoGroups()
    -- core 自动收录所有非独立分组字段，无需手动维护列表
    local core = {}
    for k, v in pairs(saveData) do
        if not SPLIT_GROUPS[k] then
            core[k] = v
        end
    end
    core.timestamp = os.time()  -- 覆盖为当前时间

    local compressedItems = {}
    for i, item in ipairs(saveData.items) do
        compressedItems[i] = Codec.CompressItem(item)
    end

    local stats    = {}
    for k, v in pairs(saveData.stats)    do stats[k]    = v end
    local settings = {}
    for k, v in pairs(saveData.settings) do settings[k] = v end

    return {
        core     = core,
        items    = { list = compressedItems },
        stats    = stats,
        settings = settings,
    }
end

local function mergeGroups(groups)
    local data = {
        version        = CURRENT_VERSION,
        timestamp      = 0,
        playTime       = 0,
        warehouseLevel = 1,
        items          = {},
        stats = {
            totalGames    = 0,
            wins          = 0,
            totalProfit   = 0,
            totalItemsWon = 0,
        },
    }

    if groups.core then
        -- 自动还原所有 core 字段，无需手动维护列表
        for k, v in pairs(groups.core) do
            data[k] = v
        end
        -- 确保必要字段有默认值
        data.version       = data.version       or CURRENT_VERSION
        data.warehouseLevel = data.warehouseLevel or 1
    end

    if groups.items and groups.items.list then
        for i, c in ipairs(groups.items.list) do
            data.items[i] = Codec.DecompressItem(c)
        end
    end

    if groups.stats then
        for k, v in pairs(groups.stats) do data.stats[k] = v end
    end
    data.stats.maxProfit   = data.stats.maxProfit   or 0
    data.stats.totalLoss   = data.stats.totalLoss   or 0
    data.stats.maxLoss     = data.stats.maxLoss     or 0
    data.stats.highestBid  = data.stats.highestBid  or 0
    data.stats.ticketGames = data.stats.ticketGames or 0
    data.stats.redItemsWon = data.stats.redItemsWon or 0

    data.settings = { bgmVolume = 100, sfxVolume = 100 }
    if groups.settings then
        for k, v in pairs(groups.settings) do data.settings[k] = v end
    end

    data.gameHistory = {}
    return data
end

-- ============================================================================
-- 内部：将存档写入 batch（save callback 和 WriteToBatch 共用）
-- ============================================================================

-- core 分组中变化频繁但不影响"真实数据"的字段，排除在 dirty 检测之外
-- （这些字段仍然会写入云端，只是不触发 core 的 dirty 判断）
local CORE_VOLATILE_FIELDS = { timestamp = true, playTime = true }

local function writeBatch(batch)
    saveData.timestamp = os.time()
    saveData.playTime  = playTime

    local groups = splitIntoGroups()
    pendingChecksums   = {}
    pendingHeadEntries = {}
    local headKeys     = {}
    local changedCount = 0
    local totalCount   = 0

    for groupName, groupData in pairs(groups) do
        totalCount = totalCount + 1
        local sanitized = Codec.SanitizeTable(groupData, groupName)
        local chunks, checksums, lengths = Codec.EncodeAndChunk(sanitized)
        local csStr   = checksumStr(checksums)
        local keyBase = "save_" .. groupName

        -- core 分组：用去除 volatile 字段后的稳定数据来判断是否需要写云端
        -- （pendingChecksums 也存稳定值，确保 commitChecksums 后下次比较仍能命中）
        local dirtyCheckStr = csStr
        if groupName == "core" then
            local stableCore = {}
            for k, v in pairs(groupData) do
                if not CORE_VOLATILE_FIELDS[k] then stableCore[k] = v end
            end
            local stableSanitized = Codec.SanitizeTable(stableCore, "core_stable")
            local _, stableCs = Codec.EncodeAndChunk(stableSanitized)
            dirtyCheckStr = checksumStr(stableCs)
        end

        pendingChecksums[groupName] = dirtyCheckStr

        if dirtyCheckStr ~= lastSavedChecksums[groupName] then
            -- 内容有变化，写入云端
            changedCount = changedCount + 1
            if #chunks == 1 then
                batch:Set(keyBase, chunks[1])
                headKeys[groupName] = { cs = checksums, len = lengths }
            else
                for i, chunk in ipairs(chunks) do
                    batch:Set(keyBase .. "_" .. (i - 1), chunk)
                end
                headKeys[groupName] = { chunks = #chunks, cs = checksums, len = lengths }
            end
            pendingHeadEntries[groupName] = headKeys[groupName]
        else
            -- 内容未变化，跳过数据 key，复用上次 head entry
            headKeys[groupName] = lastHeadEntries[groupName]
            pendingHeadEntries[groupName] = headKeys[groupName]
            print("[SaveSystem] Incremental: skip '" .. groupName .. "' (unchanged)")
        end
    end

    -- HEAD 始终重写（记录最新 timestamp 及所有分组 checksum）
    batch:Set(KEY_HEAD, {
        format    = 1,
        version   = saveData.version,
        timestamp = os.time(),
        keys      = headKeys,
    })
    saveLocal()
    print("[SaveSystem] writeBatch: " .. changedCount .. "/" .. totalCount .. " groups written")
end

-- 保存成功后提交 checksum 缓存（由 onSaved 及 DirectSave piggyback 路径调用）
local function commitChecksums()
    for k, v in pairs(pendingChecksums)   do lastSavedChecksums[k] = v end
    for k, v in pairs(pendingHeadEntries) do lastHeadEntries[k]    = v end
end

-- ============================================================================
-- SaveFramework 注册
-- ============================================================================

SaveFramework.Register(MODULE_NAME, {
    cloudKeys = {
        KEY_HEAD, KEY_CORE, KEY_ITEMS, KEY_STATS, KEY_SETTINGS, KEY_HIST_HEAD,
    },
    speculativeKeys = {
        "save_items_0", "save_items_1", "save_items_2", "save_items_3", "save_items_4",
    },

    load = function(values, iscores)
        local head = values[KEY_HEAD]
        if not head then
            -- 确认无任何存档 key 才算新玩家
            local hasAnyCloudKey = false
            for _, k in ipairs({ KEY_CORE, KEY_ITEMS, KEY_STATS, KEY_SETTINGS }) do
                if values[k] ~= nil then
                    hasAnyCloudKey = true
                    break
                end
            end
            if hasAnyCloudKey then
                print("[SaveSystem] head key missing but other keys exist — possible data corruption, aborting")
                return
            end
            print("[SaveSystem] No cloud save found (new player)")
            saveConfirmed = true
            saveLocal()
            return
        end

        if type(head) == "string" then
            local ok2, parsed = pcall(cjson.decode, head)
            if ok2 then head = parsed end
        end

        if type(head) ~= "table" or not head.keys then
            print("[SaveSystem] Invalid head format, aborting load (cloud data may still exist)")
            return
        end

        local SKIP_ON_FAIL = { history = true }

        local groups = {}
        for groupName, info in pairs(head.keys) do
            local optional = SKIP_ON_FAIL[groupName] == true
            local keyBase  = "save_" .. groupName
            local json

            if info.chunks and info.chunks > 1 then
                local parts = {}
                local allFound = true
                for i = 0, info.chunks - 1 do
                    local part = values[keyBase .. "_" .. i]
                    if not part then
                        print("[SaveSystem] Missing chunk: " .. keyBase .. "_" .. i)
                        allFound = false
                        break
                    end
                    parts[#parts + 1] = part
                end
                if not allFound then
                    if optional then
                        print("[SaveSystem] Skipping optional group '" .. groupName .. "' (incomplete chunks)")
                        goto continue_group
                    end
                    print("[SaveSystem] Incomplete chunks for group '" .. groupName .. "', aborting load")
                    return
                end
                if type(info.cs) == "table" then
                    for i, part in ipairs(parts) do
                        local expected = info.cs[i]
                        if expected and Codec.CalcChecksum(part) ~= expected then
                            if optional then
                                print("[SaveSystem] Skipping optional group '" .. groupName .. "' (checksum mismatch chunk " .. (i-1) .. ")")
                                goto continue_group
                            end
                            print("[SaveSystem] Chunk checksum mismatch: " .. keyBase .. "_" .. (i-1) .. ", aborting load")
                            return
                        end
                    end
                end
                json = table.concat(parts)
            else
                json = values[keyBase]
            end

            if json then
                if type(json) == "table" then
                    groups[groupName] = json
                else
                    if type(info.cs) == "number" then
                        if Codec.CalcChecksum(json) ~= info.cs then
                            if optional then
                                print("[SaveSystem] Skipping optional group '" .. groupName .. "' (checksum mismatch)")
                                goto continue_group
                            end
                            print("[SaveSystem] Checksum mismatch for group '" .. groupName .. "', aborting load")
                            return
                        end
                    end
                    local ok3, parsed = pcall(cjson.decode, json)
                    if ok3 then
                        groups[groupName] = parsed
                    else
                        if optional then
                            print("[SaveSystem] Skipping optional group '" .. groupName .. "' (decode failed)")
                            goto continue_group
                        end
                        print("[SaveSystem] Decode failed for group '" .. groupName .. "', aborting load")
                        return
                    end
                end
            end
            ::continue_group::
        end

        saveData = mergeGroups(groups)
        saveData.tickets            = saveData.tickets            or {}
        saveData.characterCoins     = saveData.characterCoins     or 0
        saveData.unlockedCharacters = saveData.unlockedCharacters or {}
        saveData.mailRead           = saveData.mailRead           or {}
        saveData.mailClaimed        = saveData.mailClaimed        or {}
        saveData.overflowMails      = saveData.overflowMails      or {}
        saveData.gameHistory        = {}

        -- 从 Config 恢复静态字段（瘦身后存档不再持久化 rarity/w/h/category/image/desc）
        for _, item in ipairs(saveData.items) do
            if item.name and not item.rarity then
                local static = Config.GetItemByName(item.name)
                if static then
                    item.rarity   = static.rarity
                    item.w        = static.w
                    item.h        = static.h
                    item.category = static.category
                    item.image    = static.image
                    item.desc     = static.desc
                else
                    -- 未知物品：兜底默认值
                    item.rarity   = item.rarity   or "white"
                    item.w        = item.w        or 1
                    item.h        = item.h        or 1
                    item.category = item.category or ""
                    item.image    = item.image    or ""
                    item.desc     = item.desc     or ""
                end
            end
        end

        -- 初始化历史记录 head 指针
        History.InitFromCloud(values[KEY_HIST_HEAD])

        playTime = saveData.playTime or 0
        Migration.Run(saveData)
        saveConfirmed = true
        saveLocal()
        print("[SaveSystem] Cloud load OK (" .. #saveData.items .. " items, Games: "
            .. (saveData.stats.totalGames or 0) .. ", histHead=" .. History.GetHead() .. ")")
    end,

    save = function(batch)
        if not saveConfirmed then
            print("[SaveSystem] save callback skipped: saveConfirmed=false (load not confirmed)")
            return
        end
        writeBatch(batch)
    end,

    defaults = function()
        saveConfirmed = true
        saveLocal()
        print("[SaveSystem] Defaults applied (new player or cloud error)")
    end,

    onSaved = function()
        commitChecksums()
        print("[SaveSystem] Cloud save confirmed (" .. #saveData.items .. " items)")
        pcall(function()
            local okORP, ORP = pcall(require, "UI.OnlineRewardPanel")
            if okORP and ORP and ORP.SyncNow then ORP.SyncNow() end
        end)
    end,
})

-- ============================================================================
-- 公开接口
-- ============================================================================

function SaveSystem.Init(onReady)
    if initialized then
        -- 只有 saveConfirmed=true 时才会进这里（失败时 initialized 保持 false，保留重试能力）
        if onReady then onReady(saveConfirmed, false) end
        return
    end

    -- 只有云端成功确认后才锁定 initialized，失败时保持 false，允许下次重试重走 BatchGet
    if saveConfirmed then
        initialized = true
    end

    local isNew = (#saveData.items == 0 and (saveData.stats.totalGames or 0) == 0)
    print("[SaveSystem] Init OK. Items: " .. #saveData.items
        .. ", Games: " .. (saveData.stats.totalGames or 0)
        .. ", saveConfirmed=" .. tostring(saveConfirmed))
    if onReady then onReady(saveConfirmed, isNew) end
end

function SaveSystem.Save()
    if not saveConfirmed then return end
    SaveFramework.MarkDirty(MODULE_NAME)
end

function SaveSystem.SaveNow()
    if not saveConfirmed then return end
    SaveFramework.MarkDirty(MODULE_NAME)
    pcall(function()
        local ok, ORP = pcall(require, "UI.OnlineRewardPanel")
        if ok and ORP and ORP.SyncNow then ORP.SyncNow() end
    end)
    SaveFramework.SaveNow("save_now")
end

function SaveSystem.MarkDirty()
    if not saveConfirmed then return end
    SaveFramework.MarkDirty(MODULE_NAME)
end

function SaveSystem.WriteToBatch(batch)
    writeBatch(batch)
end

function SaveSystem.Update(dt)
    if not initialized then return end
    playTime = playTime + dt
    if saveConfirmed and playTime - playTimeAtLastDirty >= PLAY_TIME_DIRTY_INTERVAL then
        playTimeAtLastDirty = playTime
        SaveFramework.MarkDirty(MODULE_NAME)
    end
end

function SaveSystem.IsReady()
    return initialized and saveConfirmed
end

function SaveSystem.PauseForGame()
    SaveFramework.PauseForGame()
end

function SaveSystem.ResumeAfterGame()
    SaveFramework.ResumeAfterGame()
end

-- ============================================================================
-- 物品
-- ============================================================================

function SaveSystem.AddWonItems(warehouseItems)
    local now = os.time()
    for _, item in ipairs(warehouseItems) do
        local entry = {
            name      = item.name,
            baseValue = item.baseValue or item.realValue or item.value or 0,
            wonAt     = now,
            gridX     = item.gridX,
            gridY     = item.gridY,
        }
        -- 立即补充静态字段，与 Load 恢复逻辑保持一致，确保本次会话内仓库可正常显示
        local static = Config.GetItemByName(entry.name)
        if static then
            entry.rarity   = static.rarity
            entry.w        = static.w
            entry.h        = static.h
            entry.category = static.category
            entry.image    = static.image
            entry.desc     = static.desc
        else
            entry.rarity   = "white"
            entry.w        = item.w or 1
            entry.h        = item.h or 1
            entry.category = item.category or ""
            entry.image    = item.image or ""
            entry.desc     = item.desc or ""
        end
        saveData.items[#saveData.items + 1] = entry
    end
    saveData.stats.totalItemsWon = (saveData.stats.totalItemsWon or 0) + #warehouseItems
    print("[SaveSystem] Added " .. #warehouseItems .. " items. Total: " .. #saveData.items)
end

function SaveSystem.RemoveItems(itemsToRemove)
    local removeSet = {}
    for _, item in ipairs(itemsToRemove) do removeSet[item] = true end
    local newItems = {}
    local removed  = 0
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

function SaveSystem.GetItems()     return saveData.items end
function SaveSystem.GetItemCount() return #saveData.items end

--- 检查一个藏品物品（需含 w, h 字段）能否放进当前仓库
---@param item table  { w=number, h=number, ... }
---@return boolean
function SaveSystem.CanAddItemToWarehouse(item)
    local WarehouseGrid = require("WarehouseGrid")
    local capacity = SaveSystem.GetWarehouseCapacity()
    local gridInst = WarehouseGrid.Create(capacity)
    WarehouseGrid.Rebuild(gridInst, saveData.items)
    return WarehouseGrid.CanFit(gridInst, item.w or 1, item.h or 1)
end

-- ============================================================================
-- 邮件附件（开箱溢出物品存入邮件，领取时再判断仓库空间）
-- ============================================================================

--- 将一个藏品物品以邮件形式存入存档（开箱仓库满时调用）
---@param item table  { name, w, h, baseValue, category, image, desc, quality/rarity, ... }
function SaveSystem.AddOverflowMailItem(item)
    if not saveData.overflowMails then saveData.overflowMails = {} end
    local entry = {
        id       = "overflow_" .. (item.name or "item") .. "_" .. os.time() .. "_" .. math.random(10000),
        wonAt    = os.time(),
        name     = item.name     or "未知物品",
        rarity   = item.rarity   or item.quality or "white",
        w        = item.w        or 1,
        h        = item.h        or 1,
        baseValue= item.baseValue or 0,
        category = item.category or "",
        image    = item.image    or "",
        desc     = item.desc     or "",
    }
    saveData.overflowMails[#saveData.overflowMails + 1] = entry
    print("[SaveSystem] Overflow mail added: " .. entry.name .. " id=" .. entry.id)
end

--- 获取所有仓库满邮件列表
---@return table[]
function SaveSystem.GetOverflowMails()
    return saveData.overflowMails or {}
end

--- 领取一封仓库满邮件（写入仓库，删除邮件条目）
---@param mailId string
---@return boolean ok
---@return string|nil errMsg  "full" 表示仓库仍然放不下
function SaveSystem.ClaimOverflowMail(mailId)
    if not saveData.overflowMails then return false, "not_found" end
    local idx = nil
    local entry = nil
    for i, m in ipairs(saveData.overflowMails) do
        if m.id == mailId then idx = i; entry = m; break end
    end
    if not entry then return false, "not_found" end
    -- 检查仓库空间
    if not SaveSystem.CanAddItemToWarehouse(entry) then
        return false, "full"
    end
    -- 写入仓库
    SaveSystem.AddWonItems({ entry })
    table.remove(saveData.overflowMails, idx)
    return true
end

-- ============================================================================
-- 统计 & 周期统计
-- ============================================================================

local function GetOrResetPeriodStats(key, currentPeriodKey)
    local s = saveData.stats[key]
    if not s or s.periodKey ~= currentPeriodKey then
        s = { periodKey=currentPeriodKey, profit=0, loss=0, maxProfit=0, maxLoss=0, red=0, wins=0, games=0 }
        saveData.stats[key] = s
    end
    return s
end

local function AccumulatePeriodStats(ps, isWin, profit)
    ps.games = (ps.games or 0) + 1
    if isWin then ps.wins = (ps.wins or 0) + 1 end
    if profit > 0 then
        ps.profit = (ps.profit or 0) + profit
        if profit > (ps.maxProfit or 0) then ps.maxProfit = profit end
    elseif profit < 0 then
        local loss = -profit
        ps.loss = (ps.loss or 0) + loss
        if loss > (ps.maxLoss or 0) then ps.maxLoss = loss end
    end
end

function SaveSystem.GetPeriodStats(period)
    local key, periodKey
    if     period == "day"   then key, periodKey = "dayStats",   os.date("%Y%m%d")
    elseif period == "week"  then key, periodKey = "weekStats",  os.date("%Y%W")
    elseif period == "month" then key, periodKey = "monthStats", os.date("%Y%m")
    else return nil
    end
    local s = saveData.stats[key]
    if not s or s.periodKey ~= periodKey then
        return { games=0, wins=0, profit=0, loss=0, maxProfit=0, maxLoss=0 }
    end
    return s
end

function SaveSystem.AddTicketGameStat()
    saveData.stats.ticketGames = (saveData.stats.ticketGames or 0) + 1
    print("[SaveSystem] ticketGames = " .. saveData.stats.ticketGames)
end

function SaveSystem.RecordGameResult(isWin, profit, myBid, redCount)
    saveData.stats.totalGames = (saveData.stats.totalGames or 0) + 1
    if isWin then saveData.stats.wins = (saveData.stats.wins or 0) + 1 end
    if profit > 0 then
        saveData.stats.totalProfit = (saveData.stats.totalProfit or 0) + profit
        if profit > (saveData.stats.maxProfit or 0) then saveData.stats.maxProfit = profit end
    elseif profit < 0 then
        local loss = -profit
        saveData.stats.totalLoss = (saveData.stats.totalLoss or 0) + loss
        if loss > (saveData.stats.maxLoss or 0) then saveData.stats.maxLoss = loss end
    end
    if myBid and myBid > (saveData.stats.highestBid or 0) then
        saveData.stats.highestBid = myBid
    end
    local today    = os.date("%Y%m%d")
    local thisWeek = os.date("%Y%W")
    local thisMonth= os.date("%Y%m")
    AccumulatePeriodStats(GetOrResetPeriodStats("dayStats",   today),    isWin, profit)
    AccumulatePeriodStats(GetOrResetPeriodStats("weekStats",  thisWeek), isWin, profit)
    AccumulatePeriodStats(GetOrResetPeriodStats("monthStats", thisMonth),isWin, profit)
    if redCount and redCount > 0 then
        saveData.stats.redItemsWon = (saveData.stats.redItemsWon or 0) + redCount
        saveData.stats["dayStats"].red   = (saveData.stats["dayStats"].red   or 0) + redCount
        saveData.stats["weekStats"].red  = (saveData.stats["weekStats"].red  or 0) + redCount
        saveData.stats["monthStats"].red = (saveData.stats["monthStats"].red or 0) + redCount
    end
    print("[SaveSystem] Game recorded. Total: " .. saveData.stats.totalGames
        .. ", Wins: " .. saveData.stats.wins
        .. ", MaxProfit: " .. (saveData.stats.maxProfit or 0)
        .. ", RedItems: " .. (saveData.stats.redItemsWon or 0))
end

function SaveSystem.GetStats() return saveData.stats end
function SaveSystem.GetPlayTime() return playTime end

-- ============================================================================
-- 对局历史
-- ============================================================================

function SaveSystem.AddGameHistory(record)
    History.Add(record, saveConfirmed)
    saveData.gameHistory = History.Get()
end

function SaveSystem.GetGameHistory()
    return History.Get()
end

function SaveSystem.LoadHistory(callback)
    History.Load(function(records)
        saveData.gameHistory = records
        if callback then callback(records) end
    end)
end

-- ============================================================================
-- 仓库等级
-- ============================================================================

function SaveSystem.GetWarehouseLevel()
    return saveData.warehouseLevel or 1
end

function SaveSystem.GetWarehouseCapacity()
    return WarehouseUpgrade.GetCapacity(saveData.warehouseLevel or 1)
end

function SaveSystem.UpgradeWarehouse(currentGold, deductGoldFn)
    local level = saveData.warehouseLevel or 1
    if level >= WarehouseUpgrade.MAX_LEVEL then return false, "already_max" end
    local canUpgrade, _ = WarehouseUpgrade.CheckUpgrade(level, currentGold)
    if not canUpgrade then return false, "not_enough" end
    local cost = WarehouseUpgrade.GetUpgradeCost(level)
    if deductGoldFn and cost then deductGoldFn(cost.gold) end
    saveData.warehouseLevel = level + 1
    print("[SaveSystem] Warehouse upgraded to Lv." .. saveData.warehouseLevel
        .. " (rows: " .. WarehouseUpgrade.GetRows(saveData.warehouseLevel)
        .. ", capacity: " .. WarehouseUpgrade.GetCapacity(saveData.warehouseLevel) .. ")")
    SaveSystem.SaveNow()
    return true
end

-- ============================================================================
-- 设置
-- ============================================================================

function SaveSystem.GetSettings()
    if not saveData.settings then
        saveData.settings = { bgmVolume = 100, sfxVolume = 100 }
    end
    return saveData.settings
end

function SaveSystem.UpdateSettings(patch)
    SaveSystem.GetSettings()
    for k, v in pairs(patch) do saveData.settings[k] = v end
    SaveSystem.MarkDirty()
end

-- ============================================================================
-- 门票
-- ============================================================================

function SaveSystem.GetTicketCount(ticketId)
    return (saveData.tickets and saveData.tickets[ticketId]) or 0
end

function SaveSystem.AddTickets(ticketId, count, skipSave)
    if not saveData.tickets then saveData.tickets = {} end
    saveData.tickets[ticketId] = (saveData.tickets[ticketId] or 0) + (count or 1)
    if not skipSave then
        SaveSystem.SaveNow()
    else
        SaveFramework.MarkDirty(MODULE_NAME)
    end
    print("[SaveSystem] Ticket added: " .. ticketId .. " +" .. (count or 1) .. " → " .. saveData.tickets[ticketId])
end

function SaveSystem.ConsumeTicket(ticketId)
    local cur = SaveSystem.GetTicketCount(ticketId)
    if cur <= 0 then return false end
    saveData.tickets[ticketId] = cur - 1
    SaveFramework.MarkDirty(MODULE_NAME)
    print("[SaveSystem] Ticket consumed: " .. ticketId .. " → " .. saveData.tickets[ticketId])
    return true
end

-- ============================================================================
-- 竞拍道具（propItems）
-- ============================================================================

function SaveSystem.GetPropCount(propId)
    local props = saveData.propItems
    if not props then return 0 end
    return props[propId] or 0
end

function SaveSystem.GetAllProps()
    return saveData.propItems or {}
end

function SaveSystem.AddProp(propId, count)
    if not saveData.propItems then saveData.propItems = {} end
    local cur = saveData.propItems[propId] or 0
    saveData.propItems[propId] = math.max(0, cur + (count or 1))
    SaveFramework.MarkDirty(MODULE_NAME)
    print("[SaveSystem] Prop " .. propId .. " +" .. (count or 1) .. " → " .. saveData.propItems[propId])
end

function SaveSystem.SetPropCount(propId, count)
    if not saveData.propItems then saveData.propItems = {} end
    saveData.propItems[propId] = math.max(0, count)
    SaveFramework.MarkDirty(MODULE_NAME)
end

-- ============================================================================
-- 道具每日购买记录（限购）
-- ============================================================================

function SaveSystem.GetPropDailyBought(propId)
    local today = os.date("%Y-%m-%d")
    local rec = saveData.propDailyBuy
    if not rec or rec.date ~= today then return 0 end
    return rec[propId] or 0
end

function SaveSystem.RecordPropDailyBuy(propId, count)
    local today = os.date("%Y-%m-%d")
    if not saveData.propDailyBuy or saveData.propDailyBuy.date ~= today then
        saveData.propDailyBuy = { date = today }
    end
    saveData.propDailyBuy[propId] = (saveData.propDailyBuy[propId] or 0) + (count or 1)
    SaveFramework.MarkDirty(MODULE_NAME)
end

function SaveSystem.GetDailySlotBought(slotIdx)
    local today = os.date("%Y-%m-%d")
    local rec = saveData.propDailyBuy
    if not rec or rec.date ~= today then return false end
    return rec["slot_" .. slotIdx] == true
end

function SaveSystem.RecordDailySlotBuy(slotIdx)
    local today = os.date("%Y-%m-%d")
    if not saveData.propDailyBuy or saveData.propDailyBuy.date ~= today then
        saveData.propDailyBuy = { date = today }
    end
    saveData.propDailyBuy["slot_" .. slotIdx] = true
    SaveFramework.MarkDirty(MODULE_NAME)
end

--- 今日是否已使用过广告刷新每日商店
---@return boolean
function SaveSystem.GetDailyAdRefreshUsed()
    local today = os.date("%Y-%m-%d")
    local rec = saveData.propDailyBuy
    if not rec or rec.date ~= today then return false end
    return rec["daily_shop_ad_refresh"] == true
end

--- 记录今日已使用广告刷新每日商店
function SaveSystem.RecordDailyAdRefresh()
    local today = os.date("%Y-%m-%d")
    if not saveData.propDailyBuy or saveData.propDailyBuy.date ~= today then
        saveData.propDailyBuy = { date = today }
    end
    saveData.propDailyBuy["daily_shop_ad_refresh"] = true
    SaveFramework.MarkDirty(MODULE_NAME)
end

-- ============================================================================
-- 点券（看广告专属，可购买道具）
-- ============================================================================

function SaveSystem.GetPointTickets()
    return saveData.pointTickets or 0
end

function SaveSystem.AddPointTickets(count)
    saveData.pointTickets = (saveData.pointTickets or 0) + (count or 0)
    SaveFramework.MarkDirty(MODULE_NAME)
    print("[SaveSystem] PointTickets +" .. (count or 0) .. " → " .. saveData.pointTickets)
end

function SaveSystem.SpendPointTickets(count)
    local cur = saveData.pointTickets or 0
    if cur < count then return false end
    saveData.pointTickets = cur - count
    SaveFramework.MarkDirty(MODULE_NAME)
    print("[SaveSystem] PointTickets -" .. count .. " → " .. saveData.pointTickets)
    return true
end

-- 角色币 & 角色解锁
-- ============================================================================

function SaveSystem.GetCharacterCoins()
    return saveData.characterCoins or 0
end

function SaveSystem.AddCharacterCoins(count)
    saveData.characterCoins = (saveData.characterCoins or 0) + (count or 1)
    SaveSystem.SaveNow()
    print("[SaveSystem] CharacterCoins +" .. (count or 1) .. " → " .. saveData.characterCoins)
end

function SaveSystem.SpendCharacterCoins(count)
    local cur = saveData.characterCoins or 0
    if cur < count then return false end
    saveData.characterCoins = cur - count
    SaveFramework.MarkDirty(MODULE_NAME)
    print("[SaveSystem] CharacterCoins -" .. count .. " → " .. saveData.characterCoins)
    return true
end

function SaveSystem.IsCharacterUnlocked(charId)
    if not saveData.unlockedCharacters then return false end
    return saveData.unlockedCharacters[tostring(charId)] == true
end

function SaveSystem.UnlockCharacter(charId)
    if not saveData.unlockedCharacters then saveData.unlockedCharacters = {} end
    saveData.unlockedCharacters[tostring(charId)] = true
    print("[SaveSystem] Character unlocked: id=" .. charId)
end

-- ============================================================================
-- Debug 接口（仅供 DebugPanel 使用）
-- ============================================================================

function SaveSystem.DebugSetTicket(ticketId, count)
    if not saveData.tickets then saveData.tickets = {} end
    saveData.tickets[ticketId] = math.max(0, count)
    SaveFramework.MarkDirty(MODULE_NAME)
    print("[SaveSystem][Debug] Ticket set: " .. ticketId .. " = " .. saveData.tickets[ticketId])
end

function SaveSystem.DebugSetCharacterCoins(count)
    saveData.characterCoins = math.max(0, count)
    SaveFramework.MarkDirty(MODULE_NAME)
    print("[SaveSystem][Debug] CharacterCoins set = " .. saveData.characterCoins)
end

function SaveSystem.DebugSetProp(propId, count)
    if not saveData.propItems then saveData.propItems = {} end
    saveData.propItems[propId] = math.max(0, count)
    SaveFramework.MarkDirty(MODULE_NAME)
    print("[SaveSystem][Debug] Prop set: " .. propId .. " = " .. saveData.propItems[propId])
end

-- ============================================================================
-- 邮件（已读 / 已领取）
-- ============================================================================

function SaveSystem.IsMailRead(mailId)
    return saveData.mailRead[mailId] == true
end

function SaveSystem.IsMailClaimed(mailId)
    return saveData.mailClaimed[mailId] == true
end

function SaveSystem.MarkMailRead(mailId)
    if saveData.mailRead[mailId] then return end
    saveData.mailRead[mailId] = true
    SaveFramework.MarkDirty(MODULE_NAME)
end

function SaveSystem.ClaimMail(mailId)
    if saveData.mailClaimed[mailId] then return false end
    saveData.mailRead[mailId]   = true
    saveData.mailClaimed[mailId] = true
    SaveFramework.MarkDirty(MODULE_NAME)
    return true
end

--- 返回未读邮件数量（含未领取奖励的）
function SaveSystem.GetUnreadMailCount()
    local Cfg   = require("Config")
    local mails = Cfg.MAILS or {}
    local count = 0
    for _, m in ipairs(mails) do
        if not saveData.mailRead[m.id] then
            count = count + 1
        end
    end
    return count
end

--- 返回有奖励且未领取的邮件数量
function SaveSystem.GetUnclaimedMailCount()
    local Cfg   = require("Config")
    local mails = Cfg.MAILS or {}
    local count = 0
    for _, m in ipairs(mails) do
        if m.reward and not saveData.mailClaimed[m.id] then
            count = count + 1
        end
    end
    return count
end

return SaveSystem
