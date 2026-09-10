local function encode(value)
    local kind = type(value)
    if kind == "nil" then return "null" end
    if kind == "boolean" then return tostring(value) end
    if kind == "number" then
        assert(value == value and math.abs(value) ~= math.huge, "JSON requires finite numbers")
        return tostring(value)
    end
    if kind == "string" then
        return '"' .. value:gsub('[%z\1-\31\\"]', function(character)
            if character == '"' then return '\\"' end
            if character == '\\' then return '\\\\' end
            return string.format("\\u%04x", character:byte())
        end) .. '"'
    end
    assert(kind == "table", "Unsupported JSON value")
    local parts = {}
    if #value > 0 then
        for _, item in ipairs(value) do parts[#parts + 1] = encode(item) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    for key, item in pairs(value) do parts[#parts + 1] = encode(tostring(key)) .. ":" .. encode(item) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

return encode
