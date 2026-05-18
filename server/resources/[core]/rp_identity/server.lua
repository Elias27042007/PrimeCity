local LastSubmit = {}

local function notify(source, ntype, title, message)
  TriggerClientEvent('rp:notify', source, {
    type = ntype,
    title = title,
    message = message
  })
end

local function canSubmit(source)
  local now = GetGameTimer()
  local nextAt = LastSubmit[source] or 0
  if now < nextAt then
    return false
  end

  LastSubmit[source] = now + 2500
  return true
end

RegisterNetEvent('rp:identity:create', function(data)
  local src = source
  if not canSubmit(src) then
    notify(src, 'warning', 'Bitte warten', 'Du sendest zu schnell.')
    return
  end

  local success, result = exports.rp_core:CreateCharacter(src, data)
  if not success then
    notify(src, 'error', 'Charakter', result or 'Erstellung fehlgeschlagen.')
    return
  end

  TriggerClientEvent('rp:identity:close', src)
  notify(src, 'success', 'Charakter', ('%s wurde erstellt.'):format(result.fullName or 'Charakter'))
end)

AddEventHandler('playerDropped', function()
  LastSubmit[source] = nil
end)
