RPCore = {}

function RPCore.Trim(value)
  if type(value) ~= 'string' then
    return ''
  end

  return value:match('^%s*(.-)%s*$')
end

function RPCore.Clamp(number, minValue, maxValue)
  number = tonumber(number) or minValue
  if number < minValue then return minValue end
  if number > maxValue then return maxValue end
  return number
end

function RPCore.SafeJsonDecode(value, fallback)
  if type(value) ~= 'string' then
    return fallback
  end

  local ok, data = pcall(json.decode, value)
  if not ok then
    return fallback
  end

  return data
end

function RPCore.SafeJsonEncode(value, fallback)
  local ok, data = pcall(json.encode, value)
  if not ok then
    return fallback or '{}'
  end

  return data
end
