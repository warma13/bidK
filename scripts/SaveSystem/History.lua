-- ============================================================================
-- SaveSystem/History.lua - 对局历史记录（环形缓冲区，增量云端写入）
-- ============================================================================
-- 格式说明（压缩格式，标识：无 timestamp 字段，改用 ts）：
--   记录级：ts/w/wn/cn/it/tv/b/pf/pl/rb/rp
--   物品(it)：n/r/i/v/[w]/[h]   r=稀有度整数(0-5)，w=h=1时省略
--   玩家(pl)：n/[h]/[cn]/[b]/[wn]  默认值省略
--   roundBids(rb)：[[b1,b2,...], ...]  数组套数组替代嵌套字典
--   roundProps(rp)：[[r,p,id], ...]   稀疏三元组，省略 prop.name（可推导）
--   charAvatar 全部省略，运行时从 charName 反查 Config.Characters
-- ============================================================================

local SaveFramework = require("SaveFramework")

local History = {}

-- ============================================================================
-- 常量
-- ============================================================================

local KEY_HIST_HEAD = "save_hist_head"
local HIST_SLOTS    = 10   -- 环形缓冲区大小（对局保留条数）

History.KEY_HIST_HEAD = KEY_HIST_HEAD
History.HIST_SLOTS    = HIST_SLOTS

-- ============================================================================
-- 运行时状态
-- ============================================================================

-- histHead: 最新记录的 slot 索引（0-9），-1 表示缓冲区为空
-- histSlots[i]: slot i 的已解压记录（懒加载后填入，nil 表示未加载）
-- histLoaded: LoadHistory 是否已完成
-- histCount: 已写入记录总数（0-10）
local histHead   = -1
local histSlots  = {}
local histLoaded = false
local histCount  = 0

-- ============================================================================
-- 稀有度编解码
-- ============================================================================

local RARITY_PACK   = { white=0, green=1, blue=2, purple=3, gold=4, red=5 }
local RARITY_UNPACK = { [0]="white", [1]="green", [2]="blue", [3]="purple", [4]="gold", [5]="red" }

-- ============================================================================
-- 延迟初始化辅助
-- ============================================================================

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

-- ============================================================================
-- 压缩/解压历史记录
-- ============================================================================

local function CompressHistoryRecord(rec)
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

local function DecompressHistoryRecord(rec)
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
-- 公开接口
-- ============================================================================

--- 从启动 BatchGet 的返回值初始化 head 指针
---@param rawHistHeadValue any  values[KEY_HIST_HEAD]
function History.InitFromCloud(rawHistHeadValue)
    if rawHistHeadValue ~= nil then
        local n = tonumber(rawHistHeadValue)
        if n and n >= -1 and n < HIST_SLOTS then
            histHead  = n
            histCount = (n >= 0) and HIST_SLOTS or 0
        end
    end
end

--- 获取当前 head 指针值（供日志使用）
---@return number
function History.GetHead()
    return histHead
end

--- 获取当前有效记录数（0-HIST_SLOTS）
---@return number
function History.GetCount()
    return histCount
end

--- 添加一条历史记录（更新内存 + 增量写云端）
---@param record table  对局记录
---@param saveConfirmed boolean  是否已确认云端加载
function History.Add(record, saveConfirmed)
    local newHead = (histHead + 1) % HIST_SLOTS
    histHead = newHead

    if histCount < HIST_SLOTS then
        histCount = histCount + 1
    end

    histSlots[newHead] = record

    if saveConfirmed then
        local compressed = CompressHistoryRecord(record)
        local ok, json = pcall(cjson.encode, compressed)
        if ok then
            local slotKey = "save_hist_" .. newHead
            local headVal  = tostring(newHead)
            SaveFramework.DirectSave("history_" .. newHead, function(batch)
                batch:Set(slotKey, json)
                batch:Set(KEY_HIST_HEAD, headVal)
            end, { silent = true })
            print("[SaveSystem] GameHistory slot=" .. newHead .. " written, histCount=" .. histCount)
        else
            print("[SaveSystem] GameHistory compress failed: " .. tostring(json))
        end
    end
end

--- 获取历史记录数组（最新在前，来自内存缓存）
---@return table
function History.Get()
    if histHead < 0 or histCount == 0 then
        return {}
    end
    local result = {}
    for i = 0, histCount - 1 do
        local slotIdx = (histHead - i + HIST_SLOTS) % HIST_SLOTS
        local rec = histSlots[slotIdx]
        if rec then
            result[#result + 1] = rec
        end
    end
    return result
end

--- 懒加载历史记录（从云端拉取全部 slot，解压后存入内存缓存）
--- 只需调用一次；再次调用直接返回缓存。
---@param callback function(records: table)|nil
function History.Load(callback)
    if histLoaded then
        if callback then callback(History.Get()) end
        return
    end

    if histHead < 0 then
        histLoaded = true
        if callback then callback({}) end
        return
    end

    print("[SaveSystem] LoadHistory: fetching " .. (HIST_SLOTS + 1) .. " keys ...")

    local batch = clientCloud:BatchGet()
    batch:Key(KEY_HIST_HEAD)
    for i = 0, HIST_SLOTS - 1 do
        batch:Key("save_hist_" .. i)
    end

    batch:Fetch({
        ok = function(values)
            local rawHead = values[KEY_HIST_HEAD]
            if rawHead ~= nil then
                local n = tonumber(rawHead)
                if n and n >= -1 and n < HIST_SLOTS then
                    histHead = n
                end
            end

            local loadedCount = 0
            for i = 0, HIST_SLOTS - 1 do
                local json = values["save_hist_" .. i]
                if json and type(json) == "string" and #json > 0 then
                    local ok, parsed = pcall(cjson.decode, json)
                    if ok and parsed then
                        histSlots[i] = DecompressHistoryRecord(parsed)
                        loadedCount = loadedCount + 1
                    end
                elseif json and type(json) == "table" then
                    histSlots[i] = DecompressHistoryRecord(json)
                    loadedCount = loadedCount + 1
                end
            end

            histCount = loadedCount
            histLoaded = true

            local records = History.Get()
            print("[SaveSystem] LoadHistory done. slots=" .. loadedCount .. ", records=" .. #records)
            if callback then callback(records) end
        end,
        fail = function(err)
            print("[SaveSystem] LoadHistory BatchGet failed: " .. tostring(err))
            histLoaded = true
            if callback then callback(History.Get()) end
        end,
    })
end

return History
