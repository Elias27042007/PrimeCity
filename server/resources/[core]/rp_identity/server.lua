local LastSubmit = {}
local PendingIdentityEdits = {}
local PendingIdentityCreates = {}

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

local function getCurrentIdentity(source)
  local characterId = exports.rp_core:GetCharacterId(source)
  if not characterId then
    return nil, 'Kein aktiver Charakter.'
  end

  local row = MySQL.single.await(
    [=[SELECT COALESCE(ci.first_name, c.first_name) AS first_name,
               COALESCE(ci.last_name, c.last_name) AS last_name,
               COALESCE(ci.date_of_birth, c.date_of_birth) AS date_of_birth,
               COALESCE(ci.sex, c.sex) AS sex,
               COALESCE(ci.height_cm, c.height_cm) AS height_cm,
               COALESCE(ci.nationality, c.nationality) AS nationality
        FROM characters c
        LEFT JOIN character_identity ci ON ci.character_id = c.id
        WHERE c.id = ?
        LIMIT 1]=],
    { characterId }
  )

  if not row then
    return nil, 'Identität konnte nicht geladen werden.'
  end

  return {
    firstName = tostring(row.first_name or ''),
    lastName = tostring(row.last_name or ''),
    dateOfBirth = tostring(row.date_of_birth or ''),
    sex = tostring(row.sex or 'm'),
    height = tonumber(row.height_cm or 175) or 175,
    nationality = tostring(row.nationality or '')
  }
end

local function openIdentityEditor(targetSource, actorSource)
  targetSource = tonumber(targetSource) or 0
  actorSource = tonumber(actorSource) or 0

  if targetSource <= 0 or not GetPlayerName(targetSource) then
    return false, 'Zielspieler ist nicht online.'
  end

  local identity, err = getCurrentIdentity(targetSource)
  if not identity then
    return false, err or 'Identität konnte nicht geladen werden.'
  end

  PendingIdentityEdits[targetSource] = {
    actorSource = actorSource > 0 and actorSource or nil,
    expiresAt = GetGameTimer() + 180000
  }

  TriggerClientEvent('rp:identity:open', targetSource, {
    mode = 'update',
    identity = identity
  })

  return true, identity
end

local function openIdentityCreator(targetSource, actorSource)
  targetSource = tonumber(targetSource) or 0
  actorSource = tonumber(actorSource) or 0

  if targetSource <= 0 or not GetPlayerName(targetSource) then
    return false, 'Zielspieler ist nicht online.'
  end

  PendingIdentityCreates[targetSource] = {
    actorSource = actorSource > 0 and actorSource or nil,
    expiresAt = GetGameTimer() + 180000
  }

  TriggerClientEvent('rp:identity:open', targetSource, {
    mode = 'admin_create'
  })

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

RegisterNetEvent('rp:identity:update', function(data)
  local src = source
  if not canSubmit(src) then
    notify(src, 'warning', 'Bitte warten', 'Du sendest zu schnell.')
    return
  end

  local pending = PendingIdentityEdits[src]
  if not pending then
    notify(src, 'error', 'Identität', 'Keine aktive Identitätsänderung gefunden.')
    return
  end

  if (pending.expiresAt or 0) < GetGameTimer() then
    PendingIdentityEdits[src] = nil
    notify(src, 'error', 'Identität', 'Die Identitätsänderung ist abgelaufen. Bitte erneut öffnen.')
    return
  end

  local success, result = exports.rp_core:UpdateCharacterIdentity(src, data)
  if not success then
    notify(src, 'error', 'Identität', result or 'Aktualisierung fehlgeschlagen.')
    return
  end

  PendingIdentityEdits[src] = nil
  TriggerClientEvent('rp:identity:close', src)
  notify(src, 'success', 'Identität', ('%s wurde aktualisiert.'):format(result.fullName or 'Charakter'))
end)

RegisterNetEvent('rp:identity:adminSubmit', function(data)
  local src = source
  if not canSubmit(src) then
    notify(src, 'warning', 'Bitte warten', 'Du sendest zu schnell.')
    return
  end

  local pending = PendingIdentityCreates[src]
  if not pending then
    notify(src, 'error', 'Identität', 'Keine aktive Identitätsänderung gefunden.')
    return
  end

  if (pending.expiresAt or 0) < GetGameTimer() then
    PendingIdentityCreates[src] = nil
    notify(src, 'error', 'Identität', 'Die Identitätsänderung ist abgelaufen. Bitte erneut öffnen.')
    return
  end

  local characterId = exports.rp_core:GetCharacterId(src)
  local success, result

  if characterId then
    success, result = exports.rp_core:UpdateCharacterIdentity(src, data)
  else
    success, result = exports.rp_core:CreateCharacter(src, data)
  end

  if not success then
    notify(src, 'error', 'Identität', result or 'Aktualisierung fehlgeschlagen.')
    return
  end

  PendingIdentityCreates[src] = nil
  TriggerClientEvent('rp:identity:close', src)

  if characterId then
    notify(src, 'success', 'Identität', ('%s wurde aktualisiert.'):format(result.fullName or 'Charakter'))
  else
    notify(src, 'success', 'Charakter', ('%s wurde erstellt.'):format(result.fullName or 'Charakter'))
  end
end)

AddEventHandler('playerDropped', function()
  LastSubmit[source] = nil
  PendingIdentityEdits[source] = nil
  PendingIdentityCreates[source] = nil
end)

exports('OpenIdentityEditor', function(targetSource, actorSource)
  return openIdentityEditor(targetSource, actorSource)
end)

exports('OpenIdentityCreator', function(targetSource, actorSource)
  return openIdentityCreator(targetSource, actorSource)
end)
