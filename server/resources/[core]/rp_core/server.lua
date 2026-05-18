local PlayerState = {}
local RateLimits = {}
local ChatWarnCooldown = {}
local CoreSchemaEnsured = false

local function isDebug()
  return GetConvar('rp_debugMode', 'false') == 'true'
end

local function dprint(msg)
  if isDebug() then
    print(('[rp_core] %s'):format(msg))
  end
end

local function getIdentifierByPrefix(src, prefix)
  local identifiers = GetPlayerIdentifiers(src)
  for i = 1, #identifiers do
    if identifiers[i]:find(prefix, 1, true) == 1 then
      return identifiers[i]
    end
  end

  return nil
end

local function getPlayerIdentityMap(src)
  return {
    license = getIdentifierByPrefix(src, 'license:'),
    license2 = getIdentifierByPrefix(src, 'license2:'),
    fivem = getIdentifierByPrefix(src, 'fivem:'),
    steam = getIdentifierByPrefix(src, 'steam:'),
    discord = getIdentifierByPrefix(src, 'discord:'),
    ip = getIdentifierByPrefix(src, 'ip:')
  }
end

local function getPrimaryIdentifier(ids)
  local primary = ids.license or ids.license2 or ids.fivem or ids.steam or ids.discord
  if primary then
    return primary
  end

  if RPCoreConfig.identifiers and RPCoreConfig.identifiers.allowIpFallback then
    return ids.ip
  end

  return nil
end

local function hasUsersColumn(columnName)
  local count = MySQL.scalar.await([[
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = ?
  ]], { columnName })

  return (tonumber(count) or 0) > 0
end

local function ensureCoreUserSchema()
  if CoreSchemaEnsured then
    return
  end

  if not hasUsersColumn('profile_name') then
    MySQL.query.await('ALTER TABLE users ADD COLUMN profile_name VARCHAR(128) NULL AFTER discord_id')
  end

  if not hasUsersColumn('steam_name') then
    MySQL.query.await('ALTER TABLE users ADD COLUMN steam_name VARCHAR(128) NULL AFTER profile_name')
  end

  -- Backfill existing rows once so offline views can resolve profile names consistently.
  MySQL.query.await([[
    UPDATE users
    SET steam_name = profile_name
    WHERE (steam_name IS NULL OR steam_name = '')
      AND profile_name IS NOT NULL
      AND profile_name <> ''
  ]])

  CoreSchemaEnsured = true
end

local function generateCharacterCode(userId)
  return ('CH%06d-%04d'):format(userId, math.random(1000, 9999))
end

local function generateAccountNumber(characterId)
  return ('RP%09d'):format(characterId)
end

local function notify(source, ntype, title, message)
  TriggerClientEvent('rp:notify', source, {
    type = ntype,
    title = title,
    message = message
  })
end

local function startsWithSlashCommand(message)
  local text = tostring(message or ''):match('^%s*(.-)%s*$')
  if text == '' then
    return false
  end

  return text:sub(1, 1) == '/'
end

local function logAudit(eventType, userId, characterId, sourceName, details)
  MySQL.insert.await(
    [=[INSERT INTO audit_log (event_type, user_id, character_id, source, details)
       VALUES (?, ?, ?, ?, ?)]=],
    {
    eventType,
    userId,
    characterId,
    sourceName,
    RPCore.SafeJsonEncode(details or {}, '{}')
    }
  )
end

local function fetchOrCreateUser(src)
  ensureCoreUserSchema()

  local ids = getPlayerIdentityMap(src)
  local primaryIdentifier = getPrimaryIdentifier(ids)
  local profileName = tostring(GetPlayerName(src) or ''):match('^%s*(.-)%s*$')
  if not primaryIdentifier then
    return nil, nil, 'Kein nutzbarer Spieler-Identifier gefunden.'
  end

  if not ids.license then
    dprint(('Fallback-Identifier aktiv für Source %s: %s'):format(src, primaryIdentifier))
    if ids.ip and primaryIdentifier == ids.ip then
      print(('[rp_core] WARN: IP-Only Identifier für Source %s aktiv (%s). Nur für lokalen Testbetrieb empfohlen.'):format(src, primaryIdentifier))
    end
  end

  local row = MySQL.single.await('SELECT id FROM users WHERE license = ? LIMIT 1', { primaryIdentifier })
  if row and row.id then
    MySQL.update.await(
      'UPDATE users SET fivem_id = ?, steam_id = ?, discord_id = ?, profile_name = COALESCE(NULLIF(?, \'\'), profile_name), steam_name = COALESCE(NULLIF(?, \'\'), steam_name), last_seen_at = NOW() WHERE id = ?',
      { ids.fivem, ids.steam, ids.discord, profileName, profileName, row.id }
    )
    return row.id, ids
  end

  local userId = MySQL.insert.await(
    'INSERT INTO users (license, fivem_id, steam_id, discord_id, profile_name, steam_name) VALUES (?, ?, ?, ?, ?, ?)',
    { primaryIdentifier, ids.fivem, ids.steam, ids.discord, profileName ~= '' and profileName or nil, profileName ~= '' and profileName or nil }
  )

  return userId, ids
end

local function loadActiveCharacter(userId)
  return MySQL.single.await(
    [=[SELECT id, first_name, last_name, date_of_birth, sex, height_cm, nationality,
        last_pos_x, last_pos_y, last_pos_z, last_heading, is_new
       FROM characters
       WHERE user_id = ? AND is_active = 1
       ORDER BY updated_at DESC
       LIMIT 1]=],
    { userId }
  )
end

local function loadIdentity(characterId)
  return MySQL.single.await(
    'SELECT first_name, last_name, date_of_birth, sex, height_cm, nationality FROM character_identity WHERE character_id = ? LIMIT 1',
    { characterId }
  )
end

local function loadSkin(characterId)
  local row = MySQL.single.await('SELECT model, skin_json FROM character_skin WHERE character_id = ? LIMIT 1', { characterId })
  if not row then
    return nil
  end

  row.skin = RPCore.SafeJsonDecode(row.skin_json, {})
  return row
end

local function resolveSpawn(characterRow, isNew)
  if characterRow and characterRow.last_pos_x and characterRow.last_pos_y and characterRow.last_pos_z and not isNew then
    return {
      x = tonumber(characterRow.last_pos_x),
      y = tonumber(characterRow.last_pos_y),
      z = tonumber(characterRow.last_pos_z),
      h = tonumber(characterRow.last_heading) or RPCoreConfig.spawn.fallback.w
    }
  end

  local row = MySQL.single.await(
    'SELECT pos_x, pos_y, pos_z, heading FROM spawn_points WHERE enabled = 1 AND is_new_player = ? ORDER BY id ASC LIMIT 1',
    { isNew and 1 or 0 }
  )

  if row then
    return {
      x = tonumber(row.pos_x),
      y = tonumber(row.pos_y),
      z = tonumber(row.pos_z),
      h = tonumber(row.heading) or RPCoreConfig.spawn.fallback.w
    }
  end

  return {
    x = RPCoreConfig.spawn.fallback.x,
    y = RPCoreConfig.spawn.fallback.y,
    z = RPCoreConfig.spawn.fallback.z,
    h = RPCoreConfig.spawn.fallback.w
  }
end

local function setPlayerState(source, state)
  PlayerState[source] = state
end

local function getPlayerState(source)
  return PlayerState[source]
end

local function pushCharacterLoaded(source, character, identity)
  local name = ('%s %s'):format(character.first_name, character.last_name)

  local payload = {
    characterId = character.id,
    firstname = character.first_name,
    lastname = character.last_name,
    fullName = name,
    dateOfBirth = tostring(character.date_of_birth),
    sex = character.sex,
    height = character.height_cm,
    nationality = character.nationality,
    isNew = character.is_new == 1
  }

  if identity then
    payload.firstname = identity.first_name
    payload.lastname = identity.last_name
    payload.dateOfBirth = tostring(identity.date_of_birth)
    payload.sex = identity.sex
    payload.height = identity.height_cm
    payload.nationality = identity.nationality
    payload.fullName = ('%s %s'):format(identity.first_name, identity.last_name)
  end

  TriggerClientEvent('rp:core:setCharacterData', source, payload)
  TriggerClientEvent('rp:hud:updateCharacter', source, payload)
end

local function prepareCharacterDependencies(source, characterId)
  TriggerEvent('rp:money:loadCharacterAccounts', source, characterId)
  TriggerEvent('rp:inventory:loadCharacterInventory', source, characterId)
  TriggerEvent('rp:jobs:loadCharacterJob', source, characterId)
end

local function spawnCharacter(source, character, isNew)
  local skin = loadSkin(character.id)
  local openCreatorAfterSpawn = false
  local creatorSex = 'm'

  if skin then
    TriggerClientEvent('rp:skin:applyOrOpen', source, {
      isNew = false,
      model = skin.model,
      skin = skin.skin
    })
  else
    -- Fallback: always apply a basic freemode skin so spawn is never blocked.
    TriggerClientEvent('rp:skin:applyOrOpen', source, {
      isNew = false,
      model = 'mp_m_freemode_01',
      skin = {
        sex = 'm',
        components = {
          torso = 15,
          pants = 21,
          shoes = 34,
          hair = 0,
          torsoTexture = 0,
          pantsTexture = 0,
          shoesTexture = 0,
          hairTexture = 0,
          mask = 0,
          maskTexture = 0,
          chain = 0,
          chainTexture = 0
        },
        props = {
          hat = -1,
          hatTexture = 0,
          glasses = -1,
          glassesTexture = 0
        },
        overlays = {
          beard = -1,
          beardOpacity = 100,
          beardColor = 0,
          hairColor = 0,
          hairHighlight = 0
        }
      }
    })

    if isNew then
      openCreatorAfterSpawn = true
      creatorSex = 'm'
    end
  end

  local spawn = resolveSpawn(character, isNew)
  TriggerClientEvent('rp:spawn:beginSpawnFlow', source, {
    isNew = isNew,
    coords = spawn,
    transitionLabel = isNew and 'Neuer Charakter wird vorbereitet ...' or 'Charakter wird geladen ...'
  })

  if openCreatorAfterSpawn then
    SetTimeout(2500, function()
      if GetPlayerName(source) then
        TriggerClientEvent('rp:skin:openCreator', source, { sex = creatorSex, mode = 'creator' })
      end
    end)
  end
end

local function initializePlayer(source)
  local current = getPlayerState(source)
  if current and current.initializing then
    return
  end

  local state = current or {}
  state.initializing = true
  state.source = source
  setPlayerState(source, state)

  local ok, userId, ids, err = pcall(fetchOrCreateUser, source)
  if not ok then
    local identifierDump = table.concat(GetPlayerIdentifiers(source), ', ')
    print(('[rp_core] initializePlayer DB error for source %s: %s'):format(source, tostring(userId)))
    print(('[rp_core] source %s identifiers: %s'):format(source, identifierDump))
    notify(source, 'error', 'Verbindung', 'DB-Fehler beim Laden des Spielerprofils.')
    DropPlayer(source, 'Datenbankfehler beim Laden deines Spielerprofils.')
    return
  end

  if not userId then
    local identifierDump = table.concat(GetPlayerIdentifiers(source), ', ')
    print(('[rp_core] initializePlayer identifier error for source %s: %s'):format(source, tostring(err)))
    print(('[rp_core] source %s identifiers: %s'):format(source, identifierDump))
    notify(source, 'error', 'Verbindung', err or 'Konnte Spielerprofil nicht laden.')
    DropPlayer(source, 'Datenbankfehler beim Laden deines Spielerprofils.')
    return
  end

  state.userId = userId
  state.identifiers = ids

  local character = loadActiveCharacter(userId)
  if not character then
    state.needsIdentity = true
    state.initializing = false
    setPlayerState(source, state)
    TriggerClientEvent('rp:identity:open', source)
    notify(source, 'info', 'Willkommen', 'Bitte erstelle zuerst deinen Charakter.')
    return
  end

  state.characterId = character.id
  state.needsIdentity = false
  state.initializing = false
  state.loaded = true
  setPlayerState(source, state)

  local identity = loadIdentity(character.id)
  pushCharacterLoaded(source, character, identity)
  prepareCharacterDependencies(source, character.id)
  spawnCharacter(source, character, character.is_new == 1)

  notify(source, 'success', 'Charakter geladen', ('Willkommen zurück, %s %s.'):format(character.first_name, character.last_name))
  logAudit('player_loaded', userId, character.id, 'rp_core', { source = source })
end

local function validateIdentity(data)
  if type(data) ~= 'table' then
    return false, 'Ungültige Daten.'
  end

  local firstName = RPCore.Trim(data.firstName)
  local lastName = RPCore.Trim(data.lastName)
  local nationality = RPCore.Trim(data.nationality)
  local dateOfBirth = RPCore.Trim(data.dateOfBirth)
  local sex = RPCore.Trim(data.sex):lower()
  local height = tonumber(data.height)

  if #firstName < RPCoreConfig.identity.minNameLength or #firstName > RPCoreConfig.identity.maxNameLength then
    return false, 'Vorname ist ungültig.'
  end

  if #lastName < RPCoreConfig.identity.minNameLength or #lastName > RPCoreConfig.identity.maxNameLength then
    return false, 'Nachname ist ungültig.'
  end

  if not dateOfBirth:match('^%d%d%d%d%-%d%d%-%d%d$') then
    return false, 'Geburtsdatum muss im Format YYYY-MM-DD sein.'
  end

  if sex ~= 'm' and sex ~= 'f' and sex ~= 'd' then
    return false, 'Geschlecht ist ungültig.'
  end

  if not height then
    return false, 'Größe ist ungültig.'
  end

  height = RPCore.Clamp(height, RPCoreConfig.identity.minHeight, RPCoreConfig.identity.maxHeight)

  if #nationality < 2 or #nationality > RPCoreConfig.identity.maxNationalityLength then
    return false, 'Nationalität ist ungültig.'
  end

  return true, {
    firstName = firstName,
    lastName = lastName,
    dateOfBirth = dateOfBirth,
    sex = sex,
    height = height,
    nationality = nationality
  }
end

local function createCharacterForSource(source, identityData)
  local state = getPlayerState(source)
  if not state or not state.userId then
    return false, 'Spielerstatus nicht bereit.'
  end

  if not state.needsIdentity then
    return false, 'Charakter existiert bereits.'
  end

  local ok, validated = validateIdentity(identityData)
  if not ok then
    return false, validated
  end

  local code = generateCharacterCode(state.userId)

  local characterId = MySQL.insert.await(
    [=[INSERT INTO characters (user_id, slot, character_code, first_name, last_name, date_of_birth, sex, height_cm, nationality, is_new)
        VALUES (?, 1, ?, ?, ?, ?, ?, ?, ?, 1)]=],
    {
      state.userId,
      code,
      validated.firstName,
      validated.lastName,
      validated.dateOfBirth,
      validated.sex,
      validated.height,
      validated.nationality
    }
  )

  MySQL.insert.await(
    [=[INSERT INTO character_identity (character_id, first_name, last_name, date_of_birth, sex, height_cm, nationality)
        VALUES (?, ?, ?, ?, ?, ?, ?)]=],
    {
      characterId,
      validated.firstName,
      validated.lastName,
      validated.dateOfBirth,
      validated.sex,
      validated.height,
      validated.nationality
    }
  )

  MySQL.insert.await('INSERT INTO accounts (character_id, account_type, balance) VALUES (?, ?, ?)', {
    characterId,
    'cash',
    RPCoreConfig.money.startCash
  })

  MySQL.insert.await('INSERT INTO accounts (character_id, account_type, balance) VALUES (?, ?, ?)', {
    characterId,
    'bank',
    RPCoreConfig.money.startBank
  })

  MySQL.insert.await('INSERT INTO bank_accounts (character_id, account_number) VALUES (?, ?)', {
    characterId,
    generateAccountNumber(characterId)
  })

  local unemployedJobId = MySQL.scalar.await('SELECT id FROM jobs WHERE job_name = ? LIMIT 1', { 'unemployed' })
  local unemployedGradeId = MySQL.scalar.await(
    [=[SELECT jg.id
       FROM job_grades jg
       JOIN jobs j ON j.id = jg.job_id
       WHERE j.job_name = ? AND jg.grade = 0
       LIMIT 1]=],
    { 'unemployed' }
  )

  if unemployedJobId and unemployedGradeId then
    MySQL.insert.await('INSERT INTO character_jobs (character_id, job_id, grade_id, on_duty) VALUES (?, ?, ?, 0)', {
      characterId,
      unemployedJobId,
      unemployedGradeId
    })
  end

  state.needsIdentity = false
  state.characterId = characterId
  state.loaded = true
  setPlayerState(source, state)

  logAudit('character_created', state.userId, characterId, 'rp_core', validated)

  local charRow = MySQL.single.await('SELECT * FROM characters WHERE id = ? LIMIT 1', { characterId })
  pushCharacterLoaded(source, charRow)
  prepareCharacterDependencies(source, characterId)
  spawnCharacter(source, charRow, true)

  return true, {
    characterId = characterId,
    fullName = ('%s %s'):format(validated.firstName, validated.lastName)
  }
end

local function finalizeCharacterSetup(source, skinPayload)
  local state = getPlayerState(source)
  if not state or not state.characterId then
    return false, 'Kein Charakter geladen.'
  end

  local characterId = state.characterId
  local model = tostring(skinPayload and skinPayload.model or 'mp_m_freemode_01')
  local skin = type(skinPayload and skinPayload.skin) == 'table' and skinPayload.skin or {}

  local existing = MySQL.scalar.await('SELECT character_id FROM character_skin WHERE character_id = ? LIMIT 1', { characterId })
  if existing then
    MySQL.update.await('UPDATE character_skin SET model = ?, skin_json = ? WHERE character_id = ?', {
      model,
      RPCore.SafeJsonEncode(skin, '{}'),
      characterId
    })
  else
    MySQL.insert.await('INSERT INTO character_skin (character_id, model, skin_json) VALUES (?, ?, ?)', {
      characterId,
      model,
      RPCore.SafeJsonEncode(skin, '{}')
    })
  end

  MySQL.update.await('UPDATE characters SET is_new = 0 WHERE id = ?', { characterId })

  notify(source, 'success', 'Charakter', 'Charakter erfolgreich erstellt.')

  return true
end

local function savePosition(source, coords)
  local state = getPlayerState(source)
  if not state or not state.characterId then
    return false
  end

  local x = tonumber(coords.x)
  local y = tonumber(coords.y)
  local z = tonumber(coords.z)
  local h = tonumber(coords.h)

  if not x or not y or not z then
    return false
  end

  MySQL.update.await(
    'UPDATE characters SET last_pos_x = ?, last_pos_y = ?, last_pos_z = ?, last_heading = ? WHERE id = ?',
    { x, y, z, h or 0.0, state.characterId }
  )

  return true
end

local function buildClockSyncPayload()
  local now = os.date('*t')
  return {
    hour = tonumber(now.hour) or 0,
    minute = tonumber(now.min) or 0,
    second = tonumber(now.sec) or 0
  }
end

local function pushClockSync(target)
  if not (RPCoreConfig.timeSync and RPCoreConfig.timeSync.enabled) then
    return
  end

  TriggerClientEvent('rp:core:syncClock', target or -1, buildClockSyncPayload())
end

RegisterNetEvent('rp:core:playerReady', function()
  local src = source
  if not src or src <= 0 then
    return
  end

  dprint(('playerReady empfangen für Source %s'):format(src))
  initializePlayer(src)
  pushClockSync(src)
end)

RegisterNetEvent('rp:core:requestTimeSync', function()
  local src = source
  if not src or src <= 0 then
    return
  end

  pushClockSync(src)
end)

AddEventHandler('chatMessage', function(source, _author, message)
  if not source or source <= 0 then
    return
  end

  if startsWithSlashCommand(message) then
    return
  end

  CancelEvent()

  local now = GetGameTimer()
  local nextWarn = ChatWarnCooldown[source] or 0
  if now < nextWarn then
    return
  end

  ChatWarnCooldown[source] = now + 2500
  notify(source, 'warning', 'Chat', 'Nur Befehle erlaubt. Nutze z.B. /i für deine verfügbaren Befehle.')
end)

AddEventHandler('playerDropped', function(reason)
  local src = source
  local state = getPlayerState(src)
  if state and state.characterId then
    logAudit('player_dropped', state.userId, state.characterId, 'rp_core', { reason = reason or 'unknown' })
  end

  PlayerState[src] = nil
  RateLimits[src] = nil
  ChatWarnCooldown[src] = nil
end)

CreateThread(function()
  if not (RPCoreConfig.timeSync and RPCoreConfig.timeSync.enabled) then
    return
  end

  local interval = tonumber(RPCoreConfig.timeSync.broadcastIntervalMs) or 30000
  if interval < 1000 then
    interval = 1000
  end

  while true do
    Wait(interval)
    pushClockSync(-1)
  end
end)

exports('GetPlayerState', function(source)
  return getPlayerState(source)
end)

exports('GetCharacterId', function(source)
  local state = getPlayerState(source)
  return state and state.characterId or nil
end)

exports('GetCharacterName', function(source)
  local state = getPlayerState(source)
  if not state or not state.characterId then
    return nil
  end

  local row = MySQL.single.await('SELECT first_name, last_name FROM characters WHERE id = ? LIMIT 1', { state.characterId })
  if not row then
    return nil
  end

  return ('%s %s'):format(row.first_name, row.last_name)
end)

exports('IsPlayerLoaded', function(source)
  local state = getPlayerState(source)
  return state and state.loaded == true
end)

exports('CreateCharacter', function(source, identityData)
  return createCharacterForSource(source, identityData)
end)

exports('FinalizeCharacterSetup', function(source, skinPayload)
  return finalizeCharacterSetup(source, skinPayload)
end)

exports('SavePlayerPosition', function(source, coords)
  return savePosition(source, coords)
end)

exports('CanUseRateLimitedAction', function(source, actionKey, cooldownMs)
  cooldownMs = tonumber(cooldownMs) or RPCoreConfig.ratelimit.defaultMs
  if not source or source <= 0 then
    return false
  end

  if not RateLimits[source] then
    RateLimits[source] = {}
  end

  local now = GetGameTimer()
  local nextAllowed = RateLimits[source][actionKey] or 0
  if now < nextAllowed then
    return false
  end

  RateLimits[source][actionKey] = now + cooldownMs
  return true
end)

exports('Audit', function(eventType, source, details)
  local state = getPlayerState(source)
  if not state then
    return
  end

  logAudit(eventType, state.userId, state.characterId, 'external', details)
end)

AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  ensureCoreUserSchema()
  math.randomseed(os.time())
  dprint('rp_core gestartet.')
end)
