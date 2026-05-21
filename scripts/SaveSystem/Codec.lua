-- ============================================================================
-- SaveSystem/Codec.lua - 编解码、校验与分片
-- ============================================================================

local Codec = {}

-- ============================================================================
-- 数据消毒：递归清理 NaN / Inf / function / userdata，防止 cjson 编码崩溃
-- ============================================================================

function Codec.SanitizeTable(t, path, visited)
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
            out[k] = Codec.SanitizeTable(v, path .. "." .. tostring(k), visited)
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

function Codec.CalcChecksum(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash << 5) + hash + string.byte(str, i)) & 0xFFFFFFFF
    end
    return hash
end

-- ============================================================================
-- 数据压缩：存档物品用短 key 节省空间
-- ============================================================================

-- 只压缩运行时唯一字段；rarity/w/h/category/image/desc 由 Config.GetItemByName 在 load 时恢复
local ITEM_FIELD_MAP = {
    name      = "n",
    baseValue = "v",
    wonAt     = "t",
    gridX     = "gx",
    gridY     = "gy",
}

local ITEM_FIELD_REVERSE = {}
for long, short in pairs(ITEM_FIELD_MAP) do
    ITEM_FIELD_REVERSE[short] = long
end

function Codec.CompressItem(item)
    local c = {}
    for long, short in pairs(ITEM_FIELD_MAP) do
        local val = item[long]
        if val ~= nil and val ~= "" and val ~= 0 then
            c[short] = val
        end
    end
    return c
end

function Codec.DecompressItem(c)
    local item = {}
    for short, long in pairs(ITEM_FIELD_REVERSE) do
        item[long] = c[short]
    end
    item.baseValue = item.baseValue or 0
    -- 注意：rarity/w/h/category/image/desc 由 SaveSystem load 回调从 Config 恢复，此处不设默认值
    return item
end

-- ============================================================================
-- 分片编码
-- ============================================================================

local CHUNK_SIZE = 8000  -- 单 key 最大字节数（留余量）

function Codec.EncodeAndChunk(groupData)
    local json = cjson.encode(groupData)
    local len = #json
    if len <= CHUNK_SIZE then
        return { json }, Codec.CalcChecksum(json), len
    end
    local chunks = {}
    for i = 1, len, CHUNK_SIZE do
        chunks[#chunks + 1] = json:sub(i, math.min(i + CHUNK_SIZE - 1, len))
    end
    local checksums = {}
    local lengths = {}
    for i, chunk in ipairs(chunks) do
        checksums[i] = Codec.CalcChecksum(chunk)
        lengths[i] = #chunk
    end
    return chunks, checksums, lengths
end

return Codec
