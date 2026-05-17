-- ============================================================================
-- SaveSystem.lua - 存档模块（注册到 SaveFramework）
-- ============================================================================
-- 重构后的架构：
--   SaveSystem 不再独立发起 clientCloud 请求
--   通过 SaveFramework.Register("save", ...) 注册自己的 load/save/defaults
--   启动时由 SaveFramework.Init 单次 BatchGet 加载所有模块
--   保存时由 SaveFramework.Save 合并所有脏模块到一次 BatchSet
--
-- 外部 API 保持完全不变：
--   Init, Save, SaveNow, MarkDirty, IsReady, Update
--   PauseForGame, ResumeAfterGame
--   AddWonItems, RemoveItems, RemoveItemsByName, GetItems, GetItemCount
--   RecordGameResult, GetStats
--   GetSettings, UpdateSettings
--   GetTicketCount, AddTickets, ConsumeTicket
--   GetCharacterCoins, AddCharacterCoins, SpendCharacterCoins
--   IsCharacterUnlocked, UnlockCharacter
--   GetWarehouseLevel, GetWarehouseCapacity, UpgradeWarehouse
--   GetPlayTime
-- ============================================================================

local Config = require("Config")
local WarehouseUpgrade = require("Config.WarehouseUpgrade")
local AntiCheat = require("AntiCheat")
local SaveFramework = require("SaveFramework")

local SaveSystem = {}

---@diagnostic disable: undefined-global

-- ============================================================================
-- 常量
-- ============================================================================

local CURRENT_VERSION = 3           -- 存档数据版本号（对应项目 v1.1.11）
local CHUNK_SIZE = 8000             -- 单 key 最大字节数（留余量）
local MODULE_NAME = "save"          -- 在 SaveFramework 中的模块名

-- 云端 key 名
local KEY_HEAD    = "save_head"
local KEY_CORE    = "save_core"
local KEY_ITEMS   = "save_items"
local KEY_STATS   = "save_stats"
local KEY_SETTINGS = "save_settings"
local KEY_HISTORY = "save_history"

-- 历史记录最大条数
local MAX_HISTORY = 100

-- 本地文件名
local LOCAL_FILE = "save_data.json"

-- ============================================================================
-- 内部状态
-- ============================================================================

local initialized = false
local saveConfirmed = false         -- 云端数据已成功加载
local playTime = 0                  -- 累计游戏时长
local playTimeAtLastDirty = 0       -- 上次因时长变化标脏时的 playTime
local PLAY_TIME_DIRTY_INTERVAL = 60 -- 每累计 60 秒标一次脏

-- 运行时存档数据
local saveData = {
    version = CURRENT_VERSION,
    timestamp = 0,
    playTime = 0,
    core = {},
    warehouseLevel = 1,
    items = {},
    stats = {
        totalGames = 0,
        wins = 0,
        totalProfit = 0,   -- 累计正利润之和（仅 profit>0 的局）
        totalLoss = 0,     -- 累计亏损之和（仅 profit<0 的局，存正数）
        totalItemsWon = 0,
        maxProfit = 0,     -- 单局最高利润
        maxLoss = 0,       -- 单局最大亏损（存正数）
        highestBid = 0,
        ticketGames = 0,   -- 使用指定门票参与的场次
        redItemsWon = 0,   -- 拍得的红色物品件数
    },
    settings = {
        bgmVolume = 100,
        sfxVolume = 100,
    },
    tickets = {},
    characterCoins = 0,
    unlockedCharacters = {},
    propItems = {},
    gameHistory = {},   -- 对局历史记录（最多 MAX_HISTORY 条，最新在前）
}

-- ============================================================================
-- 数据消毒：递归清理 NaN / Inf / function / userdata，防止 cjson 编码崩溃
-- ============================================================================

local function SanitizeTable(t, path, visited)
    path    = path    or "root"
    visited = visited or {}
    if visited[t] then
        print("[SaveSystem] SanitizeTable: circular ref at " .. path .. ", skipped")
        return {}
    end
    visited[t] = true

    local out = {}
    for k, v in pairs(t) do
        local tp = type(v)
        if tp == "number" then
            if v ~= v then        -- NaN
                print("[SaveSystem] SanitizeTable: NaN replaced at " .. path .. "." .. tostring(k))
                out[k] = 0
            elseif v == math.huge or v == -math.huge then
                print("[SaveSystem] SanitizeTable: Inf replaced at " .. path .. "." .. tostring(k))
                out[k] = 0
            else
                out[k] = v
            end
        elseif tp == "string" or tp == "boolean" then
            out[k] = v
        elseif tp == "table" then
            out[k] = SanitizeTable(v, path .. "." .. tostring(k), visited)
        else
            -- function / userdata / thread → 丢弃
            print("[SaveSystem] SanitizeTable: dropped " .. tp .. " at " .. path .. "." .. tostring(k))
        end
    end
    return out
end

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

local ITEM_FIELD_MAP = {
    name     = "n",
    rarity   = "r",
    w        = "w",
    h        = "h",
    baseValue = "v",
    category = "c",
    image    = "i",
    desc     = "d",
    wonAt    = "t",
    gridX    = "gx",
    gridY    = "gy",
}

local ITEM_FIELD_REVERSE = {}
for long, short in pairs(ITEM_FIELD_MAP) do
    ITEM_FIELD_REVERSE[short] = long
end

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

local function decompressItem(c)
    local item = {}
    for short, long in pairs(ITEM_FIELD_REVERSE) do
        item[long] = c[short]
    end
    item.w = item.w or 1
    item.h = item.h or 1
    item.baseValue = item.baseValue or 0
    item.rarity = item.rarity or "white"
    item.category = item.category or ""
    item.desc = item.desc or ""
    item.image = item.image or ""
    return item
end

-- ============================================================================
-- 历史记录压缩（节省云端存储空间，约节省 40% 体积）
--
-- 格式说明（新格式，标识：无 timestamp 字段，改用 ts）：
--   记录级：ts/w/wn/cn/it/tv/b/pf/pl/rb/rp
--   物品(it)：n/r/i/v/[w]/[h]   r=稀有度整数(0-5)，w=h=1时省略
--   玩家(pl)：n/[h]/[cn]/[b]/[wn]  默认值省略
--   roundBids(rb)：[[b1,b2,...], ...]  数组套数组替代嵌套字典
--   roundProps(rp)：[[r,p,id], ...]   稀疏三元组，省略 prop.name（可推导）
--   charAvatar 全部省略，运行时从 charName 反查 Config.Characters
-- ============================================================================

-- 稀有度字符串 ↔ 整数（0=white … 5=red）
local RARITY_PACK   = { white=0, green=1, blue=2, purple=3, gold=4, red=5 }
local RARITY_UNPACK = { [0]="white", [1]="green", [2]="blue", [3]="purple", [4]="gold", [5]="red" }

-- 角色名 → avatar 路径（延迟初始化，从 Config.Characters 构建）
local charAvatarByName = nil
local function GetCharAvatarByName()
    if not charAvatarByName then
        charAvatarByName = {}
        local ok, Chars = pcall(require, "Config.Characters")
        if ok and Chars and Chars.CHARACTERS then
            for _, c in ipairs(Chars.CHARACTERS) do
                if c.name and c.avatar then
                    charAvatarByName[c.name] = c.avatar
                end
            end
        end
    end
    return charAvatarByName
end

-- prop id → name（延迟初始化）
local propNameById = nil
local function GetPropNameById()
    if not propNameById then
        propNameById = {}
        local ok, Props = pcall(require, "Config.Props")
        if ok and Props and Props.LIST then
            for _, p in ipairs(Props.LIST) do
                if p.id and p.name then propNameById[p.id] = p.name end
            end
        end
    end
    return propNameById
end

local function compressHistoryRecord(rec)
    -- ── items ──────────────────────────────────────────────────────────────
    local citems = {}
    if rec.items then
        for _, it in ipairs(rec.items) do
            local ci = { n = it.name, r = RARITY_PACK[it.rarity] or 0 }
            if it.image  and it.image  ~= "" then ci.i = it.image  end
            if it.value  and it.value  ~= 0  then ci.v = it.value  end
            if it.w      and it.w      ~= 1  then ci.w = it.w      end
            if it.h      and it.h      ~= 1  then ci.h = it.h      end
            citems[#citems + 1] = ci
        end
    end

    -- ── players ────────────────────────────────────────────────────────────
    -- charAvatar 省略，加载时从 charName 推导
    local cplayers = {}
    if rec.players then
        for _, pl in ipairs(rec.players) do
            local cp = { n = pl.name }
            if pl.isHuman  then cp.h  = 1 end
            if pl.isWinner then cp.wn = 1 end
            if pl.charName and pl.charName ~= "" then cp.cn = pl.charName end
            if pl.bid      and pl.bid      ~= 0  then cp.b  = pl.bid     end
            cplayers[#cplayers + 1] = cp
        end
    end

    -- ── roundBids：嵌套字典 → 数组套数组 ─────────────────────────────────
    local numPlayers = rec.players and #rec.players or 0
    local crb = nil
    if rec.roundBids then
        local maxRnd = 0
        for k in pairs(rec.roundBids) do
            local n = tonumber(k); if n and n > maxRnd then maxRnd = n end
        end
        if maxRnd > 0 then
            crb = {}
            for r = 1, maxRnd do
                local row = rec.roundBids[r] or rec.roundBids[tostring(r)] or {}
                local arr = {}
                for p = 1, numPlayers do
                    arr[p] = (row[p] or row[tostring(p)] or 0)
                end
                crb[r] = arr
            end
        end
    end

    -- ── roundProps：稀疏字典 → [r,p,id] 三元组列表 ─────────────────────────
    local crp = nil
    if rec.roundProps then
        for rk, row in pairs(rec.roundProps) do
            if type(row) == "table" then
                for pk, pu in pairs(row) do
                    if type(pu) == "table" and pu.id then
                        crp = crp or {}
                        crp[#crp + 1] = { tonumber(rk) or rk, tonumber(pk) or pk, pu.id }
                    end
                end
            end
        end
    end

    local out = {
        ts = rec.timestamp,
        w  = rec.isWin and 1 or 0,
        wn = rec.warehouseName,
        it = citems,
        tv = rec.totalValue,
        b  = rec.bid,
        pf = rec.profit,
        pl = cplayers,
    }
    if rec.charName and rec.charName ~= "" then out.cn = rec.charName end
    if crb then out.rb = crb end
    if crp then out.rp = crp end
    return out
end

local function decompressHistoryRecord(rec)
    -- 兼容旧格式：有 timestamp 字段则已是展开格式，直接返回
    if rec.timestamp ~= nil then return rec end

    local avatars   = GetCharAvatarByName()
    local propNames = GetPropNameById()

    -- ── items ──────────────────────────────────────────────────────────────
    local items = {}
    if rec.it then
        for _, ci in ipairs(rec.it) do
            items[#items + 1] = {
                name   = ci.n,
                rarity = RARITY_UNPACK[ci.r] or "white",
                image  = ci.i or "",
                value  = ci.v or 0,
                w      = ci.w or 1,
                h      = ci.h or 1,
            }
        end
    end

    -- ── players ────────────────────────────────────────────────────────────
    local players = {}
    if rec.pl then
        for _, cp in ipairs(rec.pl) do
            local cname = cp.cn or ""
            players[#players + 1] = {
                name       = cp.n,
                isHuman    = cp.h  == 1,
                isWinner   = cp.wn == 1,
                charName   = cname,
                charAvatar = avatars[cname] or "",
                bid        = cp.b or 0,
            }
        end
    end

    -- ── roundBids：数组套数组 → 嵌套数字键 table ──────────────────────────
    local roundBids = {}
    if rec.rb then
        for r, arr in ipairs(rec.rb) do
            if type(arr) == "table" then
                local row = {}
                for p, b in ipairs(arr) do row[p] = b end
                roundBids[r] = row
            end
        end
    end

    -- ── roundProps：三元组列表 → 嵌套 table ────────────────────────────────
    local roundProps = {}
    if rec.rp then
        for _, triplet in ipairs(rec.rp) do
            local r, p, pid = triplet[1], triplet[2], triplet[3]
            if r and p and pid then
                roundProps[r] = roundProps[r] or {}
                roundProps[r][p] = { id = pid, name = propNames[pid] or pid }
            end
        end
    end

    local charName = rec.cn or ""
    return {
        timestamp     = rec.ts,
        isWin         = rec.w == 1,
        warehouseName = rec.wn,
        charName      = charName,
        charAvatar    = avatars[charName] or "",
        items         = items,
        totalValue    = rec.tv or 0,
        bid           = rec.b  or 0,
        profit        = rec.pf or 0,
        players       = players,
        roundBids     = roundBids,
        roundProps    = roundProps,
    }
end

-- ============================================================================
-- 分组与分片
-- ============================================================================

local function splitIntoGroups()
    local core = {
        version = saveData.version,
        timestamp = os.time(),
        playTime = saveData.playTime,
        warehouseLevel = saveData.warehouseLevel or 1,
        tickets = saveData.tickets or {},
        characterCoins = saveData.characterCoins or 0,
        unlockedCharacters = saveData.unlockedCharacters or {},
        propItems = saveData.propItems or {},
        propDailyBuy = saveData.propDailyBuy or {},
    }

    local compressedItems = {}
    for i, item in ipairs(saveData.items) do
        compressedItems[i] = compressItem(item)
    end
    local items = { list = compressedItems }

    local stats = {}
    for k, v in pairs(saveData.stats) do
        stats[k] = v
    end

    local settings = {}
    for k, v in pairs(saveData.settings) do
        settings[k] = v
    end

    -- 历史记录：逐条压缩
    local rawHistory = saveData.gameHistory or {}
    local history = {}
    for i, rec in ipairs(rawHistory) do
        history[i] = compressHistoryRecord(rec)
    end

    return {
        core = core,
        items = items,
        stats = stats,
        settings = settings,
        history = history,
    }
end

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

    if groups.core then
        data.version = groups.core.version or CURRENT_VERSION
        data.timestamp = groups.core.timestamp or 0
        data.playTime = groups.core.playTime or 0
        data.warehouseLevel = groups.core.warehouseLevel or 1
        data.tickets = groups.core.tickets or {}
        data.characterCoins = groups.core.characterCoins or 0
        data.unlockedCharacters = groups.core.unlockedCharacters or {}
        data.propItems = groups.core.propItems or {}
        data.propDailyBuy = groups.core.propDailyBuy or {}
    end

    if groups.items and groups.items.list then
        for i, c in ipairs(groups.items.list) do
            data.items[i] = decompressItem(c)
        end
    end

    if groups.stats then
        for k, v in pairs(groups.stats) do
            data.stats[k] = v
        end
    end
    -- 补齐新字段默认值（兼容旧存档）
    data.stats.maxProfit   = data.stats.maxProfit   or 0
    data.stats.totalLoss   = data.stats.totalLoss   or 0
    data.stats.maxLoss     = data.stats.maxLoss     or 0
    data.stats.highestBid  = data.stats.highestBid  or 0
    data.stats.ticketGames = data.stats.ticketGames or 0
    data.stats.redItemsWon = data.stats.redItemsWon or 0

    data.settings = {
        bgmVolume = 100,
        sfxVolume = 100,
    }
    if groups.settings then
        for k, v in pairs(groups.settings) do
            data.settings[k] = v
        end
    end

    -- 历史记录：逐条解压（自动兼容旧格式/新格式）
    data.gameHistory = {}
    if groups.history and type(groups.history) == "table" then
        for i, rec in ipairs(groups.history) do
            data.gameHistory[i] = decompressHistoryRecord(rec)
        end
    end

    return data
end

local function encodeAndChunk(groupData)
    local json = cjson.encode(groupData)
    local len = #json
    if len <= CHUNK_SIZE then
        return { json }, CalcChecksum(json), len
    end
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
    saveData.stats = saveData.stats or {}
    saveData.items = saveData.items or {}
    saveData.warehouseLevel = saveData.warehouseLevel or 1
    saveData.settings = saveData.settings or {}
    saveData.settings.bgmVolume = saveData.settings.bgmVolume or 100
    saveData.settings.sfxVolume = saveData.settings.sfxVolume or 100
    if saveData.settings.glowEffect == nil then
        local platform = GetPlatform and GetPlatform() or ""
        local isMobile = (platform == "Android" or platform == "iOS" or platform == "Web")
        saveData.settings.glowEffect = not isMobile
    end
    saveData.tickets = saveData.tickets or {}
    saveData.characterCoins = saveData.characterCoins or 0
    saveData.unlockedCharacters = saveData.unlockedCharacters or {}
    saveData.propItems = saveData.propItems or {}
    saveData.gameHistory = saveData.gameHistory or {}
    print("[SaveSystem] Local load OK (" .. #saveData.items .. " items)")
    return true
end

-- ============================================================================
-- 版本迁移
-- ============================================================================

local MIGRATIONS = {
    -- v1 → v2: 用当前物品池价格更新已保存物品的 baseValue
    [1] = function(data)
        -- 加载所有物品池模块
        local pools = {
            require("Config.Warehouses.ItemPool"),
            require("Config.Warehouses.QuantumLab"),
            require("Config.Warehouses.BondedPort"),
            require("Config.Warehouses.DataCenter"),
        }
        -- 建立 name → value 查找表
        local priceMap = {}
        for _, pool in ipairs(pools) do
            if pool.categories then
                for _, cat in ipairs(pool.categories) do
                    if cat.items then
                        for _, item in ipairs(cat.items) do
                            if item.name and item.value then
                                priceMap[item.name] = item.value
                            end
                        end
                    end
                end
            end
        end
        -- 更新已保存物品的 baseValue
        local updated = 0
        if data.items then
            for _, item in ipairs(data.items) do
                local newPrice = priceMap[item.name]
                if newPrice and newPrice ~= item.baseValue then
                    item.baseValue = newPrice
                    updated = updated + 1
                end
            end
        end
        print("[SaveSystem] Migration v1→v2: updated " .. updated .. " item prices")
    end,

    -- v2 → v3: 将旧 port_1000w / port_5000w 门票兑换为深海打捞站 + 文化艺术区指定门票
    -- 兑换比例：旧门票总张数 n，各发 n×5 张新门票
    [2] = function(data)
        data.tickets = data.tickets or {}
        local old1000w = data.tickets["port_1000w"] or 0
        local old5000w = data.tickets["port_5000w"] or 0
        local n = old1000w + old5000w
        if n > 0 then
            local reward = n * 5
            data.tickets["ticket_deepsea"]  = (data.tickets["ticket_deepsea"]  or 0) + reward
            data.tickets["ticket_culture"]  = (data.tickets["ticket_culture"]  or 0) + reward
            data.tickets["port_1000w"] = nil
            data.tickets["port_5000w"] = nil
            print("[SaveSystem] Migration v2→v3: 旧门票 " .. n .. " 张 → 深海/文化各 " .. reward .. " 张")
        else
            print("[SaveSystem] Migration v2→v3: 无旧门票，跳过")
        end
    end,
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
-- SaveFramework 注册
-- ============================================================================

SaveFramework.Register(MODULE_NAME, {
    -- 必需的云端 key
    cloudKeys = {
        KEY_HEAD, KEY_CORE, KEY_ITEMS, KEY_STATS, KEY_SETTINGS, KEY_HISTORY,
    },
    -- 投机性预取：物品分片 key（玩家可能有 0-N 片）
    -- 10 片 × 8000 bytes ≈ 最多 ~700 件物品
    -- history 分片：100 条记录约 50-100KB，最多 ~15 片
    speculativeKeys = {
        "save_items_0", "save_items_1", "save_items_2", "save_items_3", "save_items_4",
        "save_items_5", "save_items_6", "save_items_7", "save_items_8", "save_items_9",
        "save_history_0", "save_history_1", "save_history_2", "save_history_3",
        "save_history_4", "save_history_5", "save_history_6", "save_history_7",
        "save_history_8", "save_history_9", "save_history_10", "save_history_11",
        "save_history_12", "save_history_13", "save_history_14",
    },

    -- 从 BatchGet 返回的 values 中恢复存档数据
    load = function(values, iscores)
        local head = values[KEY_HEAD]
        if not head then
            -- 云端无任何存档数据（head 不存在）：才能判定为新玩家
            -- 额外检查其他 cloudKeys，防止 head 因某些原因丢失但其他数据仍存在
            local hasAnyCloudKey = false
            for _, k in ipairs({ KEY_CORE, KEY_ITEMS, KEY_STATS, KEY_SETTINGS, KEY_HISTORY }) do
                if values[k] ~= nil then
                    hasAnyCloudKey = true
                    break
                end
            end
            if hasAnyCloudKey then
                -- head 丢了但其他 key 存在——数据损坏，拒绝加载，不设 saveConfirmed
                print("[SaveSystem] head key missing but other keys exist — possible data corruption, aborting")
                return
            end
            -- 确认是真正的新玩家
            print("[SaveSystem] No cloud save found (new player)")
            saveConfirmed = true
            saveLocal()
            return
        end

        -- head 可能是 table 或 string
        if type(head) == "string" then
            local ok2, parsed = pcall(cjson.decode, head)
            if ok2 then head = parsed end
        end

        if type(head) ~= "table" or not head.keys then
            -- head 损坏时不设 saveConfirmed，防止空数据覆盖云端真实存档
            print("[SaveSystem] Invalid head format, aborting load (cloud data may still exist)")
            return
        end

        -- 解析各组
        local groups = {}
        for groupName, info in pairs(head.keys) do
            local keyBase = "save_" .. groupName
            local json

            if info.chunks and info.chunks > 1 then
                -- 多片拼接
                local parts = {}
                local allFound = true
                for i = 0, info.chunks - 1 do
                    local part = values[keyBase .. "_" .. i]
                    if not part then
                        print("[SaveSystem] Missing chunk: " .. keyBase .. "_" .. i
                            .. " (need " .. info.chunks .. " chunks total)")
                        allFound = false
                        break
                    end
                    parts[#parts + 1] = part
                end
                if not allFound then
                    -- 分片不完整，拒绝加载，让 Standalone 提示重试
                    -- 不设 saveConfirmed，防止不完整数据覆盖云端存档
                    print("[SaveSystem] Incomplete chunks for group '" .. groupName .. "', aborting load")
                    return
                end
                -- 逐片校验（多片组 cs 是 table）
                if type(info.cs) == "table" then
                    for i, part in ipairs(parts) do
                        local expected = info.cs[i]
                        if expected and CalcChecksum(part) ~= expected then
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
                    -- 单片校验
                    if type(info.cs) == "number" then
                        if CalcChecksum(json) ~= info.cs then
                            print("[SaveSystem] Checksum mismatch for group '" .. groupName .. "', aborting load")
                            return
                        end
                    end
                    local ok3, parsed = pcall(cjson.decode, json)
                    if ok3 then
                        groups[groupName] = parsed
                    else
                        -- 关键分组解码失败时中止加载，防止用不完整数据（空物品等）覆盖云端
                        print("[SaveSystem] Decode failed for group '" .. groupName .. "', aborting load")
                        return
                    end
                end
            end
        end

        -- 合并
        saveData = mergeGroups(groups)
        saveData.tickets = saveData.tickets or {}
        saveData.characterCoins = saveData.characterCoins or 0
        saveData.unlockedCharacters = saveData.unlockedCharacters or {}
        saveData.gameHistory = saveData.gameHistory or {}

        -- 恢复累计游戏时长（从云端存档，不是从本次会话的 0 开始）
        playTime = saveData.playTime or 0

        runMigrations()
        saveConfirmed = true
        saveLocal()
        print("[SaveSystem] Cloud load OK (" .. #saveData.items .. " items, Games: "
            .. (saveData.stats.totalGames or 0) .. ")")
    end,

    -- 往 BatchSet 的 batch 上追加存档数据
    save = function(batch)
        saveData.timestamp = os.time()
        saveData.playTime = playTime

        local groups = splitIntoGroups()

        -- 消毒：清理 NaN / Inf / function，防止 cjson 编码崩溃导致本次保存静默放弃
        local sanitized = {}
        for groupName, groupData in pairs(groups) do
            sanitized[groupName] = SanitizeTable(groupData, groupName)
        end

        local headKeys = {}

        for groupName, groupData in pairs(sanitized) do
            local chunks, checksums, lengths = encodeAndChunk(groupData)
            local keyBase = "save_" .. groupName

            if #chunks == 1 then
                batch:Set(keyBase, chunks[1])
                headKeys[groupName] = {
                    cs = checksums,
                    len = lengths,
                }
            else
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

        local head = {
            format = 1,
            version = saveData.version,
            timestamp = os.time(),
            keys = headKeys,
        }
        batch:Set(KEY_HEAD, head)

        -- 同时写本地缓存
        saveLocal()
    end,

    -- 无云端数据时初始化默认值
    defaults = function()
        saveConfirmed = true
        saveLocal()
        print("[SaveSystem] Defaults applied (new player or cloud error)")
    end,

    -- 云端保存成功后的回调
    onSaved = function()
        print("[SaveSystem] Cloud save confirmed (" .. #saveData.items .. " items)")
        pcall(function()
            local okORP, ORP = pcall(require, "UI.OnlineRewardPanel")
            if okORP and ORP and ORP.SyncNow then ORP.SyncNow() end
        end)
    end,
})

-- ============================================================================
-- 公开接口（保持外部 API 完全不变）
-- ============================================================================

--- 初始化：注册已完成，此函数仅标记内部 initialized
--- 实际云端加载由 SaveFramework.Init 触发
---@param onReady function(success: boolean, isNewPlayer: boolean)|nil
function SaveSystem.Init(onReady)
    if initialized then
        if onReady then onReady(true, false) end
        return
    end

    -- SaveFramework.Init 已在 Standalone.lua 中统一调用
    -- 此处标记 SaveSystem 层面已就绪
    initialized = true
    local isNew = (#saveData.items == 0 and (saveData.stats.totalGames or 0) == 0)
    print("[SaveSystem] Init OK. Items: " .. #saveData.items
        .. ", Games: " .. (saveData.stats.totalGames or 0))
    if onReady then onReady(saveConfirmed, isNew) end
end

--- 常规保存 → 委托 SaveFramework 脏标记
function SaveSystem.Save()
    if not saveConfirmed then return end
    SaveFramework.MarkDirty(MODULE_NAME)
end

--- 立即保存 → 委托 SaveFramework
function SaveSystem.SaveNow()
    if not saveConfirmed then return end
    SaveFramework.MarkDirty(MODULE_NAME)
    -- 强制刷新在线时间，防止 30 秒同步窗口内的时间丢失
    pcall(function()
        local ok, ORP = pcall(require, "UI.OnlineRewardPanel")
        if ok and ORP and ORP.SyncNow then ORP.SyncNow() end
    end)
    SaveFramework.SaveNow("save_now")
end

--- 标记脏数据 → 委托 SaveFramework
function SaveSystem.MarkDirty()
    SaveFramework.MarkDirty(MODULE_NAME)
end

--- 将完整 save 数据写入外部 batch（用于与其他模块合并一次写入）
function SaveSystem.WriteToBatch(batch)
    saveData.timestamp = os.time()
    saveData.playTime = playTime

    local groups = splitIntoGroups()

    local sanitized = {}
    for groupName, groupData in pairs(groups) do
        sanitized[groupName] = SanitizeTable(groupData, groupName)
    end

    local headKeys = {}

    for groupName, groupData in pairs(sanitized) do
        local chunks, checksums, lengths = encodeAndChunk(groupData)
        local keyBase = "save_" .. groupName
        if #chunks == 1 then
            batch:Set(keyBase, chunks[1])
            headKeys[groupName] = { cs = checksums, len = lengths }
        else
            for i, chunk in ipairs(chunks) do
                batch:Set(keyBase .. "_" .. (i - 1), chunk)
            end
            headKeys[groupName] = { chunks = #chunks, cs = checksums, len = lengths }
        end
    end

    local head = {
        format = 1,
        version = saveData.version,
        timestamp = os.time(),
        keys = headKeys,
    }
    batch:Set(KEY_HEAD, head)
    -- 同步本地缓存
    saveLocal()
end

--- 每帧调用（仅跟踪 playTime，框架 Update 由 Standalone 调用）
function SaveSystem.Update(dt)
    if not initialized then return end
    playTime = playTime + dt
    -- 每 60 秒标一次脏，确保游戏时长被自动保存持久化
    if playTime - playTimeAtLastDirty >= PLAY_TIME_DIRTY_INTERVAL then
        playTimeAtLastDirty = playTime
        SaveFramework.MarkDirty(MODULE_NAME)
    end
    -- 注意：SaveFramework.Update(dt) 由 Standalone.lua 调用，这里不重复调用
end

--- 存档是否已加载
---@return boolean
function SaveSystem.IsReady()
    return initialized and saveConfirmed
end

--- 对局开始暂停 → 委托 SaveFramework
function SaveSystem.PauseForGame()
    SaveFramework.PauseForGame()
end

--- 对局结束恢复 → 委托 SaveFramework
function SaveSystem.ResumeAfterGame()
    SaveFramework.ResumeAfterGame()
end

-- ============================================================================
-- 业务接口（完全保留原逻辑，无改动）
-- ============================================================================

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
            gridX = item.gridX,
            gridY = item.gridY,
        }
    end
    saveData.stats.totalItemsWon = (saveData.stats.totalItemsWon or 0) + #warehouseItems
    -- 统计红色稀有度物品
    local redCount = 0
    for _, item in ipairs(warehouseItems) do
        if item.rarity == "red" then redCount = redCount + 1 end
    end
    -- 红色藏品总数由 RecordGameResult 在拍下仓库时统计，此处不重复计数
    print("[SaveSystem] Added " .. #warehouseItems .. " items. Total: " .. #saveData.items)
end

---使用门票参与了一场拍卖，统计 ticketGames
function SaveSystem.AddTicketGameStat()
    saveData.stats.ticketGames = (saveData.stats.ticketGames or 0) + 1
    print("[SaveSystem] ticketGames = " .. saveData.stats.ticketGames)
end

function SaveSystem.RemoveItems(itemsToRemove)
    local removeSet = {}
    for _, item in ipairs(itemsToRemove) do
        removeSet[item] = true
    end
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

-- ============================================================================
-- 周期统计辅助（日/周/月独立追踪，用于排行榜按时间段分榜）
-- ============================================================================

--- 获取指定周期的统计表，若周期 key 变化则自动重置
local function GetOrResetPeriodStats(key, currentPeriodKey)
    local s = saveData.stats[key]
    if not s or s.periodKey ~= currentPeriodKey then
        s = { periodKey=currentPeriodKey, profit=0, loss=0, maxProfit=0, maxLoss=0, red=0, wins=0, games=0 }
        saveData.stats[key] = s
    end
    return s
end

--- 将一局结果累加到周期统计
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

--- 获取指定时间段的统计数据（供 MoneyManager 上传排行榜用）
--- @param period string  "day" | "week" | "month"
--- @return table  { games, wins, profit, loss, maxProfit, maxLoss }
function SaveSystem.GetPeriodStats(period)
    local key, periodKey
    if period == "day" then
        key, periodKey = "dayStats",   os.date("%Y%m%d")
    elseif period == "week" then
        key, periodKey = "weekStats",  os.date("%Y%W")
    elseif period == "month" then
        key, periodKey = "monthStats", os.date("%Y%m")
    else
        return nil
    end
    -- 若当前周期 key 不符则返回空数据（今天还没有记录）
    local s = saveData.stats[key]
    if not s or s.periodKey ~= periodKey then
        return { games=0, wins=0, profit=0, loss=0, maxProfit=0, maxLoss=0 }
    end
    return s
end

---@param isWin boolean
---@param profit number
---@param myBid number|nil  本局玩家出价（赢局传实际付款额，输局传出价额）
---@param redCount number|nil  本局拍得的红色藏品数（赢局才有）
function SaveSystem.RecordGameResult(isWin, profit, myBid, redCount)
    saveData.stats.totalGames = (saveData.stats.totalGames or 0) + 1
    if isWin then
        saveData.stats.wins = (saveData.stats.wins or 0) + 1
    end
    if profit > 0 then
        saveData.stats.totalProfit = (saveData.stats.totalProfit or 0) + profit
        if profit > (saveData.stats.maxProfit or 0) then
            saveData.stats.maxProfit = profit
        end
    elseif profit < 0 then
        local loss = -profit  -- 存正数
        saveData.stats.totalLoss = (saveData.stats.totalLoss or 0) + loss
        if loss > (saveData.stats.maxLoss or 0) then
            saveData.stats.maxLoss = loss
        end
    end
    if myBid and myBid > (saveData.stats.highestBid or 0) then
        saveData.stats.highestBid = myBid
    end
    -- 周期统计（日/周/月独立数据，用于时间段排行榜）
    local today    = os.date("%Y%m%d")
    local thisWeek = os.date("%Y%W")
    local thisMonth= os.date("%Y%m")
    local ds = GetOrResetPeriodStats("dayStats",   today)
    local ws = GetOrResetPeriodStats("weekStats",  thisWeek)
    local ms = GetOrResetPeriodStats("monthStats", thisMonth)
    AccumulatePeriodStats(ds, isWin, profit)
    AccumulatePeriodStats(ws, isWin, profit)
    AccumulatePeriodStats(ms, isWin, profit)
    -- 红色藏品数：拍下仓库即计入，与后续是否放仓库/回收无关
    if redCount and redCount > 0 then
        saveData.stats.redItemsWon = (saveData.stats.redItemsWon or 0) + redCount
        ds.red = (ds.red or 0) + redCount
        ws.red = (ws.red or 0) + redCount
        ms.red = (ms.red or 0) + redCount
    end
    print("[SaveSystem] Game recorded. Total: " .. saveData.stats.totalGames
        .. ", Wins: " .. saveData.stats.wins
        .. ", MaxProfit: " .. (saveData.stats.maxProfit or 0)
        .. ", RedItems: " .. (saveData.stats.redItemsWon or 0))
end

--- 添加一条对局历史记录（最新在前，超过 MAX_HISTORY 时删除末尾）
---@param record table  { timestamp, isWin, warehouseName, charName, charAvatar,
---                        items, totalValue, bid, profit, players, roundBids }
function SaveSystem.AddGameHistory(record)
    if not saveData.gameHistory then saveData.gameHistory = {} end
    table.insert(saveData.gameHistory, 1, record)
    -- 超出上限时截断
    while #saveData.gameHistory > MAX_HISTORY do
        table.remove(saveData.gameHistory)
    end
    print("[SaveSystem] GameHistory added. Total: " .. #saveData.gameHistory)
end

--- 获取对局历史记录数组（最新在前）
---@return table
function SaveSystem.GetGameHistory()
    return saveData.gameHistory or {}
end

---@return table
function SaveSystem.GetItems()
    return saveData.items
end

---@return table
function SaveSystem.GetStats()
    return saveData.stats
end

---@return number
function SaveSystem.GetItemCount()
    return #saveData.items
end

---@return number
function SaveSystem.GetPlayTime()
    return playTime
end

-- ============================================================================
-- 仓库等级接口
-- ============================================================================

---@return number
function SaveSystem.GetWarehouseLevel()
    return saveData.warehouseLevel or 1
end

---@return number
function SaveSystem.GetWarehouseCapacity()
    return WarehouseUpgrade.GetCapacity(saveData.warehouseLevel or 1)
end

function SaveSystem.UpgradeWarehouse(currentGold, deductGoldFn)
    local level = saveData.warehouseLevel or 1
    if level >= WarehouseUpgrade.MAX_LEVEL then
        return false, "already_max"
    end

    local canUpgrade, details = WarehouseUpgrade.CheckUpgrade(level, currentGold)
    if not canUpgrade then
        return false, "not_enough"
    end

    local cost = WarehouseUpgrade.GetUpgradeCost(level)
    if deductGoldFn and cost then
        deductGoldFn(cost.gold)
    end

    saveData.warehouseLevel = level + 1
    print("[SaveSystem] Warehouse upgraded to Lv." .. saveData.warehouseLevel
        .. " (rows: " .. WarehouseUpgrade.GetRows(saveData.warehouseLevel)
        .. ", capacity: " .. WarehouseUpgrade.GetCapacity(saveData.warehouseLevel) .. ")")

    SaveSystem.SaveNow()
    return true
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

-- ============================================================================
-- 用户设置接口
-- ============================================================================

function SaveSystem.GetSettings()
    if not saveData.settings then
        saveData.settings = {
            bgmVolume = 100, sfxVolume = 100,
        }
    end
    return saveData.settings
end

function SaveSystem.UpdateSettings(patch)
    SaveSystem.GetSettings()
    for k, v in pairs(patch) do
        saveData.settings[k] = v
    end
    SaveSystem.MarkDirty()
end

-- ============================================================================
-- 门票/消耗道具
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
        -- skipSave=true 时调用方负责通过 WriteToBatch 写入，但仍标脏保底
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
-- 道具背包
-- ============================================================================

function SaveSystem.GetPropCount(propId)
    return (saveData.props and saveData.props[propId]) or 0
end

function SaveSystem.AddProp(propId, count)
    if not saveData.props then saveData.props = {} end
    saveData.props[propId] = math.max(0, (saveData.props[propId] or 0) + (count or 1))
    SaveFramework.MarkDirty(MODULE_NAME)
    print("[SaveSystem] Prop changed: " .. propId .. " +" .. (count or 1) .. " → " .. saveData.props[propId])
end

-- ============================================================================
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
-- 道具每日购买记录（用于限购）
-- ============================================================================

--- 获取今日某道具已购买次数
function SaveSystem.GetPropDailyBought(propId)
    local today = os.date("%Y-%m-%d")
    local rec = saveData.propDailyBuy
    if not rec or rec.date ~= today then return 0 end
    return rec[propId] or 0
end

--- 记录今日购买（count 通常为购买数量，默认1）
function SaveSystem.RecordPropDailyBuy(propId, count)
    local today = os.date("%Y-%m-%d")
    if not saveData.propDailyBuy or saveData.propDailyBuy.date ~= today then
        saveData.propDailyBuy = { date = today }
    end
    saveData.propDailyBuy[propId] = (saveData.propDailyBuy[propId] or 0) + (count or 1)
    SaveFramework.MarkDirty(MODULE_NAME)
end

-- ============================================================================
-- Debug 接口（绕过反作弊，仅供 DebugPanel 使用）
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

return SaveSystem
