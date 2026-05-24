-- ============================================================================
-- RedeemCode.lua - 兑换码编解码模块
-- 算法：userId(32bit) XOR S1 | amountCode+serial(16bit) XOR S2 | checksum(16bit)
-- 输出格式：XXXXXXXX-XXXX-XXXX（16 位大写十六进制）
-- ============================================================================

local RedeemCode = {}

-- 密钥（混淆用）
local S1 = 0x5A3C7E1D
local S2 = 0x2F8B4D6A
local S3 = 0x71E9C3B5

-- 金额映射（amountCode → 金币数）
local AMOUNT_MAP = {
    [1] = 1250,                -- 1250
    [2] = 2500,                -- 2500
    [3] = 6250,                -- 6250
    [4] = 12500,               -- 1.25 万
    [5] = 25000,               -- 2.5 万
    [6] = 62500,               -- 6.25 万
    [7] = 125000,              -- 12.5 万
    [8] = 625000000000000,     -- 625 万亿
}

-- 反向映射（金币数 → amountCode）
local AMOUNT_REVERSE = {}
for k, v in pairs(AMOUNT_MAP) do
    AMOUNT_REVERSE[v] = k
end

-- ============================================================================
-- 内部：计算校验和
-- ============================================================================

---@param a integer 编码后的 userId 部分
---@param b integer 编码后的 amount+serial 部分
---@return integer checksum 16 位校验和
local function CalcChecksum(a, b)
    local raw = (a * 7 + b * 13 + S3) & 0xFFFFFFFF
    return (raw >> 16) & 0xFFFF
end

-- ============================================================================
-- 生成兑换码（开发者工具）
-- ============================================================================

--- 生成兑换码
---@param userId integer 目标用户 ID
---@param amount integer 金币数量（必须在 AMOUNT_MAP 中）
---@param serial integer 序号（0-63，同一用户不可重复）
---@return string|nil code 兑换码，失败返回 nil
---@return string|nil error 错误信息
function RedeemCode.Generate(userId, amount, serial)
    local amountCode = AMOUNT_REVERSE[amount]
    if not amountCode then
        return nil, "invalid amount, must be one of: 1250,2500,6250,12500,25000,62500,125000"
    end
    if serial < 0 or serial > 63 then
        return nil, "serial must be 0-63"
    end

    local a = (userId & 0xFFFFFFFF) ~ S1
    local b = ((amountCode << 6) | serial) ~ S2
    local checksum = CalcChecksum(a & 0xFFFFFFFF, b & 0xFFFF)

    return string.format("%08X-%04X-%04X", a & 0xFFFFFFFF, b & 0xFFFF, checksum)
end

-- ============================================================================
-- 验证并解码兑换码
-- ============================================================================

--- 验证兑换码
---@param code string 兑换码字符串
---@param currentUserId integer 当前登录用户 ID
---@return table|nil result { userId, amount, serial }
---@return string|nil error 错误码: "invalid_format", "invalid_code", "wrong_user", "invalid_amount"
function RedeemCode.Verify(code, currentUserId)
    -- 去除空格，统一大写
    code = code:gsub("%s+", ""):upper()

    -- 解析格式
    local aHex, bHex, cHex = code:match("^(%x%x%x%x%x%x%x%x)-(%x%x%x%x)-(%x%x%x%x)$")
    if not aHex then
        return nil, "invalid_format"
    end

    local a = tonumber(aHex, 16)
    local b = tonumber(bHex, 16)
    local checksum = tonumber(cHex, 16)

    -- 校验签名
    local expectedCheck = CalcChecksum(a, b)
    if checksum ~= expectedCheck then
        return nil, "invalid_code"
    end

    -- 解码
    local userId = (a ~ S1) & 0xFFFFFFFF
    local bDecoded = (b ~ S2) & 0xFFFF
    local amountCode = (bDecoded >> 6) & 0xF
    local serial = bDecoded & 0x3F

    -- 验证用户
    if userId ~= currentUserId then
        return nil, "wrong_user"
    end

    -- 验证金额
    local amount = AMOUNT_MAP[amountCode]
    if not amount then
        return nil, "invalid_amount"
    end

    return { userId = userId, amount = amount, serial = serial }
end

-- ============================================================================
-- 全服通用兑换码（每人限用一次，serial 32-63 保留给通用码）
-- ============================================================================

-- 通用码表：code → { amount, serial }
-- serial 从 32 开始，与用户码（0-31）互不冲突
local UNIVERSAL_CODES = {
    ["AUCTION-2M-GIFT"] = { amount = 2000000, serial = 32 },
    ["VIP-563807534"] = { amount = 1000000000, charCoins = 60, serial = 33, allowedUser = 563807534 },
    ["VIP-1713624917"] = { amount = 4000000000, pointTickets = 900, serial = 34, allowedUser = 1713624917 },
}

--- 验证全服通用码
---@param code string 兑换码字符串
---@param currentUserId integer|nil 当前用户 ID（用于 allowedUser 校验）
---@return table|nil result { amount, serial, universal=true, charCoins=number|nil }
---@return string|nil error 错误码: "not_universal", "wrong_user"
function RedeemCode.VerifyUniversal(code, currentUserId)
    code = code:gsub("%s+", ""):upper()
    local entry = UNIVERSAL_CODES[code]
    if not entry then
        return nil, "not_universal"
    end
    -- 用户限制校验
    if entry.allowedUser and currentUserId ~= entry.allowedUser then
        return nil, "wrong_user"
    end
    return {
        amount = entry.amount,
        serial = entry.serial,
        universal = true,
        charCoins = entry.charCoins,
        pointTickets = entry.pointTickets,
    }
end

-- ============================================================================
-- 云端已兑换记录（位掩码，最多 64 个序号）
-- ============================================================================

--- 检查序号是否已兑换
---@param redeemedBits integer 已兑换位掩码
---@param serial integer 序号
---@return boolean
function RedeemCode.IsRedeemed(redeemedBits, serial)
    return ((redeemedBits >> serial) & 1) == 1
end

--- 标记序号为已兑换
---@param redeemedBits integer 当前位掩码
---@param serial integer 序号
---@return integer 新的位掩码
function RedeemCode.MarkRedeemed(redeemedBits, serial)
    return redeemedBits | (1 << serial)
end

return RedeemCode
