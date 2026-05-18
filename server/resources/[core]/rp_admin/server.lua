RPAdminConfig = RPAdminConfig or {
  command = 'admin',
  ticketCommand = 'ticket',
  carCommand = 'car',
  deleteCommand = 'delete',
  healCommand = 'heal',
  reviveCommand = 'revive',
  repairCommand = 'repair',
  gotoCommand = 'goto',
  tpCommand = 'tp',
  tpmCommand = 'tpm',
  bringCommand = 'bring',
  freezeCommand = 'freeze',
  skinCommand = 'skin',
  identityCommand = 'identity',
  noclipCommand = 'noclip',
  nameCommand = 'name',
  adutyCommand = 'aduty',
  hudCommand = 'hud',
  giveMoneyCommand = 'givemoney',
  setMoneyCommand = 'setmoney',
  giveItemCommand = 'giveitem',
  setJobCommand = 'setjob',
  giveWeaponCommand = 'giveweapon',
  roleChangeKickCheckMs = 5000,
  maxListEntries = 200,
  defaultBanDurationHours = 24,
  maxBanDurationHours = 24 * 365,
  maxReasonLength = 220,
  maxTicketTitleLength = 120,
  maxTicketDescriptionLength = 1200,
  reviveCooldownMs = 5000,
  refreshCooldownMs = 1200,
  notifications = {
    title = 'Admin'
  }
}

RPAdminShared = RPAdminShared or {}
RPAdminShared.Trim = RPAdminShared.Trim or function(value)
  if type(value) ~= 'string' then
    return ''
  end
  return value:match('^%s*(.-)%s*$')
end

local RoleCache = {}
local LastAction = {}
local SearchFilter = {}
local PlayerListMode = {}
local ActiveRoleFingerprint = {}
local PendingRepairRequests = {}
local PendingDeleteRequests = {}
local PendingTpmRequests = {}
local PendingGiveWeaponRequests = {}
local FrozenPlayers = {}
local PanelOpenMode = {}
local AdutyStates = {}
local NameOverlayStates = {}
local SettingsDraft = {}
local refreshAdminPanels
local CAR_PERMISSION_KEY = 'vehicles.spawn.command'
local VEHICLE_DELETE_PERMISSION_KEY = 'vehicles.delete.command'
local GIVE_MONEY_PERMISSION_KEY = 'commands.givemoney'
local SET_MONEY_PERMISSION_KEY = 'commands.setmoney'
local GIVE_ITEM_PERMISSION_KEY = 'commands.giveitem'
local SET_JOB_PERMISSION_KEY = 'commands.setjob'
local GIVE_WEAPON_PERMISSION_KEY = 'commands.giveweapon'
local IDENTITY_PERMISSION_KEY = 'commands.identity'
local INFO_COMMAND_NAME = 'i'
local ID_COMMAND_NAME = 'id'
local RANK_COMMAND_NAME = 'rang'
local WEAPON_SUGGESTIONS = {
  'weapon_knife',
  'weapon_nightstick',
  'weapon_pistol',
  'weapon_combatpistol',
  'weapon_pistol50',
  'weapon_smg',
  'weapon_carbinerifle',
  'weapon_pumpshotgun',
  'weapon_mg',
  'weapon_sniperrifle',
  'weapon_grenade',
  'weapon_stungun'
}
local CommandAutocompleteCache = {
  items = { values = {}, expiresAt = 0 },
  jobs = { values = {}, expiresAt = 0 },
  jobGrades = { values = {}, expiresAt = 0 }
}

local function trim(value)
  return RPAdminShared.Trim(value)
end

local function normalizePlayerListMode(value)
  value = trim(value):lower()
  if value == 'offline' then
    return 'offline'
  end
  return 'live'
end

local function isNoTeamRole(roleName)
  roleName = trim(roleName):lower()
  return roleName == '' or roleName == 'none' or roleName == 'spieler' or roleName == 'player'
end

local function getCommandName(name, fallback)
  name = trim(name)
  if name == '' then
    return fallback
  end
  return name
end

local function getCommandCatalog()
  return {
    {
      name = getCommandName(RPAdminConfig.ticketCommand, 'ticket'),
      help = 'Öffnet das Ticket-Menü.',
      params = {},
      permission = nil
    },
    {
      name = INFO_COMMAND_NAME,
      help = 'Zeigt deine verfügbaren Befehle.',
      params = {},
      permission = nil
    },
    {
      name = ID_COMMAND_NAME,
      help = 'Zeigt deine Server-ID und eindeutige Spieler-ID.',
      params = {},
      permission = nil
    },
    {
      name = RANK_COMMAND_NAME,
      help = 'Zeigt deinen aktuellen Rang.',
      params = {},
      permission = nil
    },
    {
      name = getCommandName(RPAdminConfig.hudCommand, 'hud'),
      help = 'Öffnet den HUD-Editor.',
      params = {},
      permission = nil
    },
    {
      name = getCommandName(RPAdminConfig.command, 'admin'),
      help = 'Öffnet das Admin-Menü.',
      params = {},
      permission = 'admin.menu.open'
    },
    {
      name = getCommandName(RPAdminConfig.carCommand, 'car'),
      help = 'Spawnt ein Fahrzeug.',
      params = {
        { name = 'modell', help = 'z.B. adder' }
      },
      permission = CAR_PERMISSION_KEY
    },
    {
      name = getCommandName(RPAdminConfig.giveMoneyCommand, 'givemoney'),
      help = 'Gibt einem Spieler Geld.',
      params = {
        { name = 'id', help = 'Server-ID des Spielers' },
        { name = 'bar/bank', help = 'Kontotyp' },
        { name = 'menge', help = 'Betrag > 0' }
      },
      permission = GIVE_MONEY_PERMISSION_KEY
    },
    {
      name = getCommandName(RPAdminConfig.setMoneyCommand, 'setmoney'),
      help = 'Setzt den Kontostand eines Spielers.',
      params = {
        { name = 'id', help = 'Server-ID des Spielers' },
        { name = 'bar/bank', help = 'Kontotyp' },
        { name = 'stand', help = 'Neuer Kontostand >= 0' }
      },
      permission = SET_MONEY_PERMISSION_KEY
    },
    {
      name = getCommandName(RPAdminConfig.giveItemCommand, 'giveitem'),
      help = 'Gibt einem Spieler Items.',
      params = {
        { name = 'id', help = 'Server-ID des Spielers' },
        { name = 'item', help = 'Itemname' },
        { name = 'anzahl', help = 'Menge > 0' }
      },
      permission = GIVE_ITEM_PERMISSION_KEY
    },
    {
      name = getCommandName(RPAdminConfig.setJobCommand, 'setjob'),
      help = 'Setzt Job und Rang eines Spielers.',
      params = {
        { name = 'id', help = 'Server-ID des Spielers' },
        { name = 'job', help = 'Jobname' },
        { name = 'rang', help = 'Jobrang (Grade)' }
      },
      permission = SET_JOB_PERMISSION_KEY
    },
    {
      name = getCommandName(RPAdminConfig.giveWeaponCommand, 'giveweapon'),
      help = 'Gibt einem Spieler eine Waffe.',
      params = {
        { name = 'id', help = 'Server-ID des Spielers' },
        { name = 'modell', help = 'z.B. weapon_pistol' }
      },
      permission = GIVE_WEAPON_PERMISSION_KEY
    },
    {
      name = getCommandName(RPAdminConfig.deleteCommand, 'delete'),
      help = 'Löscht Fahrzeuge im Umkreis.',
      params = {
        { name = 'umkreis', help = 'Radius in Metern (optional, Standard 2)' }
      },
      permission = VEHICLE_DELETE_PERMISSION_KEY
    },
    {
      name = 'dv',
      help = 'Alias für /delete [umkreis].',
      params = {
        { name = 'umkreis', help = 'Radius in Metern (optional, Standard 2)' }
      },
      permission = VEHICLE_DELETE_PERMISSION_KEY
    },
    {
      name = getCommandName(RPAdminConfig.healCommand, 'heal'),
      help = 'Heilt dich selbst oder einen Spieler.',
      params = {
        { name = 'id', help = 'Server-ID des Spielers (optional)' }
      },
      permission = 'commands.heal'
    },
    {
      name = getCommandName(RPAdminConfig.reviveCommand, 'revive'),
      help = 'Revived dich selbst oder einen Spieler.',
      params = {
        { name = 'id', help = 'Server-ID des Spielers (optional)' }
      },
      permission = 'commands.revive'
    },
    {
      name = getCommandName(RPAdminConfig.repairCommand, 'repair'),
      help = 'Repariert dein Fahrzeug oder das eines Spielers.',
      params = {
        { name = 'id', help = 'Server-ID des Spielers (optional)' }
      },
      permission = 'commands.repair'
    },
    {
      name = getCommandName(RPAdminConfig.reloadCommand, 'reload'),
      help = 'Lädt alle Waffen von dir oder einem Spieler nach.',
      params = {
        { name = 'id', help = 'Server-ID des Spielers (optional)' }
      },
      permission = 'commands.reload'
    },
    {
      name = getCommandName(RPAdminConfig.gotoCommand, 'goto'),
      help = 'Teleportiert dich zu einem Spieler.',
      params = {
        { name = 'id', help = 'Server-ID des Zielspielers' }
      },
      permission = 'commands.tp'
    },
    {
      name = getCommandName(RPAdminConfig.tpCommand, 'tp'),
      help = 'Teleportiert dich zu Koordinaten.',
      params = {
        { name = 'x, y, z', help = 'z.B. 215.5, -810.2, 30.7 oder x y z' }
      },
      permission = 'commands.tp'
    },
    {
      name = getCommandName(RPAdminConfig.tpmCommand, 'tpm'),
      help = 'Teleportiert dich zu deinem Karten-Marker.',
      params = {},
      permission = 'commands.tpm'
    },
    {
      name = getCommandName(RPAdminConfig.bringCommand, 'bring'),
      help = 'Teleportiert einen Spieler zu dir.',
      params = {
        { name = 'id', help = 'Server-ID des Zielspielers' }
      },
      permission = 'commands.bring'
    },
    {
      name = getCommandName(RPAdminConfig.freezeCommand, 'freeze'),
      help = 'Friert einen Spieler ein oder taut ihn auf.',
      params = {
        { name = 'id', help = 'Server-ID des Zielspielers' }
      },
      permission = 'commands.freeze'
    },
    {
      name = getCommandName(RPAdminConfig.skinCommand, 'skin'),
      help = 'Öffnet den Skin-Creator für einen Spieler.',
      params = {
        { name = 'id', help = 'Server-ID des Zielspielers' }
      },
      permission = 'commands.skin'
    },
    {
      name = getCommandName(RPAdminConfig.identityCommand, 'identity'),
      help = 'Öffnet das Identity-Menü für einen Spieler.',
      params = {
        { name = 'id', help = 'Server-ID des Zielspielers' }
      },
      permission = IDENTITY_PERMISSION_KEY
    },
    {
      name = getCommandName(RPAdminConfig.noclipCommand, 'noclip'),
      help = 'Schaltet Noclip an/aus (Unsichtbar + Flugmodus).',
      params = {},
      permission = 'commands.noclip'
    },
    {
      name = getCommandName(RPAdminConfig.nameCommand, 'name'),
      help = 'Schaltet Nametags über Spielern an/aus.',
      params = {},
      permission = 'commands.name'
    },
    {
      name = getCommandName(RPAdminConfig.adutyCommand, 'aduty'),
      help = 'Schaltet den Admin-Dienstmodus an/aus.',
      params = {},
      permission = 'commands.aduty'
    }
  }
end

local function nowMs()
  return GetGameTimer()
end

local function safeJson(value)
  local ok, encoded = pcall(json.encode, value)
  if not ok then
    return '{}'
  end

  return encoded
end

local function notify(source, ntype, message)
  TriggerClientEvent('rp:notify', source, {
    type = ntype,
    title = RPAdminConfig.notifications.title,
    message = message
  })
end

local function canDo(source, actionKey, cooldownMs)
  if not source or source <= 0 then
    return false
  end

  if not LastAction[source] then
    LastAction[source] = {}
  end

  local now = nowMs()
  local nextAllowed = LastAction[source][actionKey] or 0
  if now < nextAllowed then
    return false, (nextAllowed - now)
  end

  LastAction[source][actionKey] = now + (cooldownMs or RPAdminConfig.refreshCooldownMs)
  return true, 0
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

local function getIdentityMap(src)
  return {
    license = getIdentifierByPrefix(src, 'license:'),
    license2 = getIdentifierByPrefix(src, 'license2:'),
    fivem = getIdentifierByPrefix(src, 'fivem:'),
    steam = getIdentifierByPrefix(src, 'steam:'),
    discord = getIdentifierByPrefix(src, 'discord:'),
    ip = getIdentifierByPrefix(src, 'ip:')
  }
end

local function getPrimaryIdentifier(identityMap)
  return identityMap.license or identityMap.license2 or identityMap.fivem or identityMap.steam or identityMap.discord or identityMap.ip
end

local function getUserIdFromSource(src)
  if not src or src <= 0 then
    return nil
  end

  local state = exports.rp_core:GetPlayerState(src)
  if state and state.userId then
    return tonumber(state.userId)
  end

  local ids = getIdentityMap(src)
  local primary = getPrimaryIdentifier(ids)
  if not primary then
    return nil
  end

  local row = MySQL.single.await('SELECT id FROM users WHERE license = ? LIMIT 1', { primary })
  return row and tonumber(row.id) or nil
end

local function getOnlineProfileNameByUserId(userId)
  userId = tonumber(userId)
  if not userId then
    return nil
  end

  local online = GetPlayers()
  for i = 1, #online do
    local src = tonumber(online[i])
    if src and getUserIdFromSource(src) == userId then
      local profileName = GetPlayerName(src)
      if profileName and profileName ~= '' then
        return profileName
      end
    end
  end

  return nil
end

local function getStoredSteamNameByUserId(userId)
  userId = tonumber(userId)
  if not userId or userId <= 0 then
    return ''
  end

  local stored = MySQL.scalar.await('SELECT steam_name FROM users WHERE id = ? LIMIT 1', { userId })
  return trim(stored)
end

local function getStoredProfileNameByUserId(userId)
  userId = tonumber(userId)
  if not userId or userId <= 0 then
    return ''
  end

  local stored = MySQL.scalar.await('SELECT profile_name FROM users WHERE id = ? LIMIT 1', { userId })
  return trim(stored)
end

local function resolveProfileName(userId, steamNameHint, profileNameHint, characterNameHint, identifierFallback)
  local onlineName = getOnlineProfileNameByUserId(userId)
  if onlineName and onlineName ~= '' then
    return onlineName
  end

  local hintedSteam = trim(steamNameHint)
  if hintedSteam ~= '' then
    return hintedSteam
  end

  local storedSteam = getStoredSteamNameByUserId(userId)
  if storedSteam ~= '' then
    return storedSteam
  end

  local hintedProfile = trim(profileNameHint)
  if hintedProfile ~= '' then
    return hintedProfile
  end

  local storedProfile = getStoredProfileNameByUserId(userId)
  if storedProfile ~= '' then
    return storedProfile
  end

  local characterName = trim(characterNameHint)
  if characterName ~= '' then
    return characterName
  end

  local fallback = trim(tostring(identifierFallback or ''))
  if fallback ~= '' then
    return fallback
  end

  if tonumber(userId) then
    return ('user:%s'):format(userId)
  end

  return 'Unbekannt'
end

local function trimIdentifier(value)
  local identifier = trim(tostring(value or ''))
  if identifier == '' then
    return ''
  end
  return identifier:gsub('^%w+:%s*', '')
end

local function pickIdentifierDisplay(steamId, fivemId, discordId, licenseId)
  local steam = trimIdentifier(steamId)
  if steam ~= '' then
    return steam
  end

  local fivem = trimIdentifier(fivemId)
  if fivem ~= '' then
    return fivem
  end

  local discord = trimIdentifier(discordId)
  if discord ~= '' then
    return discord
  end

  local license = trimIdentifier(licenseId)
  if license ~= '' then
    return license
  end

  return ''
end

local function getDirectRoleIdByUserId(userId)
  if not userId then
    return 0
  end

  local roleId = MySQL.scalar.await('SELECT role_id FROM admin_user_roles WHERE user_id = ? LIMIT 1', { userId })
  return tonumber(roleId) or 0
end

local function getRoleDataByUserId(userId)
  if not userId then
    return nil
  end

  if RoleCache[userId] then
    return RoleCache[userId]
  end

  local roleRow = MySQL.single.await([=[
    SELECT r.id, r.role_name, r.label, r.priority
    FROM admin_user_roles aur
    JOIN admin_roles r ON r.id = aur.role_id
    WHERE aur.user_id = ?
    LIMIT 1
  ]=], { userId })

  if not roleRow then
    RoleCache[userId] = false
    return nil
  end

  local permRows = MySQL.query.await([=[
    SELECT p.permission_key
    FROM admin_role_permissions arp
    JOIN admin_permissions p ON p.id = arp.permission_id
    WHERE arp.role_id = ? AND arp.allow = 1
  ]=], { roleRow.id })

  local permissions = {}
  for i = 1, #permRows do
    permissions[permRows[i].permission_key] = true
  end

  local payload = {
    roleId = roleRow.id,
    roleName = roleRow.role_name,
    roleLabel = roleRow.label,
    priority = tonumber(roleRow.priority) or 0,
    permissions = permissions
  }

  RoleCache[userId] = payload
  return payload
end

local function invalidateRoleCache(userId)
  if userId then
    RoleCache[tonumber(userId)] = nil
  end
end

local function refreshRoleCacheBySource(source)
  local userId = getUserIdFromSource(source)
  if userId then
    invalidateRoleCache(userId)
  end
end

local function invalidateAllRoleCaches()
  RoleCache = {}

  local online = GetPlayers()
  for i = 1, #online do
    local src = tonumber(online[i])
    ActiveRoleFingerprint[src] = nil
  end
end

local function hasPermission(source, permissionKey)
  if IsPlayerAceAllowed(source, 'rp.admin.bypass') then
    return true
  end

  local userId = getUserIdFromSource(source)
  if not userId then
    return false
  end

  local roleData = getRoleDataByUserId(userId)
  if not roleData then
    return false
  end

  return roleData.permissions[permissionKey] == true
end

local function cloneParams(params)
  local out = {}
  if type(params) ~= 'table' then
    return out
  end

  for i = 1, #params do
    local entry = params[i]
    if type(entry) == 'table' then
      local copy = {}
      for key, value in pairs(entry) do
        copy[key] = value
      end
      out[#out + 1] = copy
    end
  end

  return out
end

local function normalizeAutocompleteValues(values)
  local dedup = {}
  local out = {}
  for i = 1, #(values or {}) do
    local value = trim(tostring(values[i] or '')):lower()
    if value ~= '' and not dedup[value] then
      dedup[value] = true
      out[#out + 1] = value
    end
  end

  table.sort(out)
  return out
end

local function getCachedItemSuggestions()
  if CommandAutocompleteCache.items.expiresAt > os.time() then
    return CommandAutocompleteCache.items.values
  end

  local rows = MySQL.query.await('SELECT item_name FROM inventory_items ORDER BY item_name ASC LIMIT 500') or {}
  local values = {}
  for i = 1, #rows do
    values[#values + 1] = rows[i].item_name
  end

  values = normalizeAutocompleteValues(values)
  CommandAutocompleteCache.items.values = values
  CommandAutocompleteCache.items.expiresAt = os.time() + 45
  return values
end

local function getCachedJobSuggestions()
  if CommandAutocompleteCache.jobs.expiresAt > os.time() then
    return CommandAutocompleteCache.jobs.values
  end

  local rows = MySQL.query.await('SELECT job_name FROM jobs ORDER BY job_name ASC LIMIT 200') or {}
  local values = {}
  for i = 1, #rows do
    values[#values + 1] = rows[i].job_name
  end

  values = normalizeAutocompleteValues(values)
  CommandAutocompleteCache.jobs.values = values
  CommandAutocompleteCache.jobs.expiresAt = os.time() + 45
  return values
end

local function getCachedJobGradeSuggestions()
  if CommandAutocompleteCache.jobGrades.expiresAt > os.time() then
    return CommandAutocompleteCache.jobGrades.values
  end

  local rows = MySQL.query.await([=[
    SELECT j.job_name, jg.grade
    FROM jobs j
    INNER JOIN job_grades jg ON jg.job_id = j.id
    ORDER BY j.job_name ASC, jg.grade ASC
  ]=]) or {}

  local map = {}
  for i = 1, #rows do
    local jobName = trim(tostring(rows[i].job_name or '')):lower()
    local grade = tostring(math.floor(tonumber(rows[i].grade) or 0))
    if jobName ~= '' then
      map[jobName] = map[jobName] or {}
      map[jobName][#map[jobName] + 1] = grade
    end
  end

  for jobName, grades in pairs(map) do
    map[jobName] = normalizeAutocompleteValues(grades)
  end

  CommandAutocompleteCache.jobGrades.values = map
  CommandAutocompleteCache.jobGrades.expiresAt = os.time() + 45
  return map
end

local function applyCommandParamOptions(commandName, params)
  local normalizedCommand = trim(tostring(commandName or '')):lower()
  local out = cloneParams(params)

  if #out == 0 then
    return out
  end

  local giveMoneyCommand = trim(getCommandName(RPAdminConfig.giveMoneyCommand, 'givemoney')):lower()
  local setMoneyCommand = trim(getCommandName(RPAdminConfig.setMoneyCommand, 'setmoney')):lower()
  local giveItemCommand = trim(getCommandName(RPAdminConfig.giveItemCommand, 'giveitem')):lower()
  local setJobCommand = trim(getCommandName(RPAdminConfig.setJobCommand, 'setjob')):lower()
  local giveWeaponCommand = trim(getCommandName(RPAdminConfig.giveWeaponCommand, 'giveweapon')):lower()

  if normalizedCommand == giveMoneyCommand or normalizedCommand == setMoneyCommand then
    if out[2] then
      out[2].options = { 'bar', 'bank' }
    end
    return out
  end

  if normalizedCommand == giveItemCommand then
    if out[2] then
      out[2].options = getCachedItemSuggestions()
    end
    return out
  end

  if normalizedCommand == setJobCommand then
    if out[2] then
      out[2].options = getCachedJobSuggestions()
    end
    if out[3] then
      local gradeMap = getCachedJobGradeSuggestions()
      out[3].optionsByToken = gradeMap
    end
    return out
  end

  if normalizedCommand == giveWeaponCommand then
    if out[2] then
      out[2].options = WEAPON_SUGGESTIONS
    end
    return out
  end

  return out
end

local function getAllowedCommandSuggestions(source)
  local catalog = getCommandCatalog()
  local suggestions = {}
  local commandNames = {}

  for i = 1, #catalog do
    local entry = catalog[i]
    local allowed = (entry.permission == nil) or hasPermission(source, entry.permission)

    if allowed then
      local slashCommand = '/' .. entry.name
      suggestions[#suggestions + 1] = {
        name = slashCommand,
        help = entry.help or '',
        params = applyCommandParamOptions(entry.name, entry.params or {})
      }
      commandNames[#commandNames + 1] = slashCommand
    end
  end

  return suggestions, commandNames
end

local function pushCommandSuggestions(source)
  if not source or source <= 0 or not GetPlayerName(source) then
    return
  end

  local suggestions = getAllowedCommandSuggestions(source)
  TriggerClientEvent('rp:admin:updateCommandSuggestions', source, suggestions)
end

local function refreshAllCommandSuggestions()
  local players = GetPlayers()
  for i = 1, #players do
    local src = tonumber(players[i])
    if src then
      pushCommandSuggestions(src)
    end
  end
end

local function getViewerContext(source)
  local userId = getUserIdFromSource(source)
  local roleData = getRoleDataByUserId(userId)

  return {
    source = source,
    userId = userId,
    roleData = roleData
  }
end

local function isProjectLead(source)
  local ctx = getViewerContext(source)
  return ctx and ctx.roleData and ctx.roleData.roleName == 'projektleitung'
end

local function bootstrapFirstProjectLead(userId)
  if not userId then
    return false
  end

  local assignedCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM admin_user_roles')) or 0
  if assignedCount > 0 then
    return false
  end

  local role = MySQL.single.await('SELECT id FROM admin_roles WHERE role_name = ? LIMIT 1', { 'projektleitung' })
  if not role then
    return false
  end

  MySQL.query.await([[
    INSERT INTO admin_user_roles (user_id, role_id, assigned_by_user_id, assigned_note)
    VALUES (?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
      role_id = VALUES(role_id),
      assigned_by_user_id = VALUES(assigned_by_user_id),
      assigned_note = VALUES(assigned_note)
  ]], { userId, role.id, userId, 'Automatisch als erste Projektleitung gesetzt' })

  invalidateRoleCache(userId)
  return true
end

local function auditAction(actorUserId, actionKey, targetUserId, payload)
  MySQL.insert.await(
    'INSERT INTO admin_audit (actor_user_id, action_key, target_user_id, payload_json) VALUES (?, ?, ?, ?)',
    { actorUserId, actionKey, targetUserId, safeJson(payload or {}) }
  )
end

local function hasColumn(tableName, columnName)
  local count = MySQL.scalar.await([[
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = ?
      AND COLUMN_NAME = ?
  ]], { tableName, columnName })

  return (tonumber(count) or 0) > 0
end

local function ensureAdminSchema()
  local hasRolesTable = (tonumber(MySQL.scalar.await([[
    SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'admin_roles'
  ]])) or 0) > 0

  local hasPermsTable = (tonumber(MySQL.scalar.await([[
    SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'admin_permissions'
  ]])) or 0) > 0

  local incompatible = false
  if hasRolesTable and (not hasColumn('admin_roles', 'role_name') or not hasColumn('admin_roles', 'id')) then
    incompatible = true
  end

  if hasPermsTable and (not hasColumn('admin_permissions', 'permission_key') or not hasColumn('admin_permissions', 'id')) then
    incompatible = true
  end

  if incompatible then
    print('[rp_admin] Inkompatibles Admin-Schema erkannt, setze Admin-Tabellen neu auf...')
    MySQL.query.await('SET FOREIGN_KEY_CHECKS = 0')
    MySQL.query.await('DROP TABLE IF EXISTS admin_ticket_messages')
    MySQL.query.await('DROP TABLE IF EXISTS admin_tickets')
    MySQL.query.await('DROP TABLE IF EXISTS admin_bans')
    MySQL.query.await('DROP TABLE IF EXISTS admin_role_duty_outfits')
    MySQL.query.await('DROP TABLE IF EXISTS admin_user_roles')
    MySQL.query.await('DROP TABLE IF EXISTS admin_role_permissions')
    MySQL.query.await('DROP TABLE IF EXISTS admin_permissions')
    MySQL.query.await('DROP TABLE IF EXISTS admin_roles')
    MySQL.query.await('DROP TABLE IF EXISTS admin_audit')
    MySQL.query.await('SET FOREIGN_KEY_CHECKS = 1')
  end

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS admin_roles (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      role_name VARCHAR(32) NOT NULL,
      label VARCHAR(64) NOT NULL,
      priority INT UNSIGNED NOT NULL DEFAULT 0,
      is_system TINYINT(1) NOT NULL DEFAULT 1,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY ux_admin_roles_name (role_name),
      KEY idx_admin_roles_priority (priority)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS admin_permissions (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      permission_key VARCHAR(64) NOT NULL,
      label VARCHAR(96) NOT NULL,
      description VARCHAR(255) NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY ux_admin_permissions_key (permission_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS admin_role_permissions (
      role_id BIGINT UNSIGNED NOT NULL,
      permission_id BIGINT UNSIGNED NOT NULL,
      allow TINYINT(1) NOT NULL DEFAULT 1,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (role_id, permission_id),
      CONSTRAINT fk_admin_role_permissions_role FOREIGN KEY (role_id) REFERENCES admin_roles (id) ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT fk_admin_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES admin_permissions (id) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS admin_user_roles (
      user_id BIGINT UNSIGNED NOT NULL,
      role_id BIGINT UNSIGNED NOT NULL,
      assigned_by_user_id BIGINT UNSIGNED NULL,
      assigned_note VARCHAR(255) NULL,
      assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (user_id),
      KEY idx_admin_user_roles_role (role_id),
      KEY idx_admin_user_roles_assigned_by (assigned_by_user_id),
      CONSTRAINT fk_admin_user_roles_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT fk_admin_user_roles_role FOREIGN KEY (role_id) REFERENCES admin_roles (id) ON DELETE RESTRICT ON UPDATE CASCADE,
      CONSTRAINT fk_admin_user_roles_assigned_by FOREIGN KEY (assigned_by_user_id) REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS admin_role_duty_outfits (
      role_id BIGINT UNSIGNED NOT NULL,
      top_drawable INT NOT NULL DEFAULT 15,
      pants_drawable INT NOT NULL DEFAULT 14,
      shoes_drawable INT NOT NULL DEFAULT 34,
      hat_drawable INT NOT NULL DEFAULT -1,
      updated_by_user_id BIGINT UNSIGNED NULL,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (role_id),
      CONSTRAINT fk_admin_role_duty_outfits_role FOREIGN KEY (role_id) REFERENCES admin_roles (id) ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT fk_admin_role_duty_outfits_updated_by FOREIGN KEY (updated_by_user_id) REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS admin_bans (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      user_id BIGINT UNSIGNED NOT NULL,
      identifier_snapshot VARCHAR(128) NULL,
      reason VARCHAR(255) NOT NULL,
      banned_by_user_id BIGINT UNSIGNED NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      expires_at TIMESTAMP NULL DEFAULT NULL,
      active TINYINT(1) NOT NULL DEFAULT 1,
      revoked_by_user_id BIGINT UNSIGNED NULL,
      revoked_at TIMESTAMP NULL DEFAULT NULL,
      PRIMARY KEY (id),
      KEY idx_admin_bans_user_active (user_id, active),
      KEY idx_admin_bans_expires (expires_at),
      CONSTRAINT fk_admin_bans_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT fk_admin_bans_by_user FOREIGN KEY (banned_by_user_id) REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE,
      CONSTRAINT fk_admin_bans_revoked_by FOREIGN KEY (revoked_by_user_id) REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS admin_tickets (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      creator_user_id BIGINT UNSIGNED NOT NULL,
      creator_character_id BIGINT UNSIGNED NULL,
      title VARCHAR(128) NOT NULL,
      description TEXT NOT NULL,
      status ENUM('open','in_progress','closed') NOT NULL DEFAULT 'open',
      assigned_user_id BIGINT UNSIGNED NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      closed_at TIMESTAMP NULL DEFAULT NULL,
      PRIMARY KEY (id),
      KEY idx_admin_tickets_status (status),
      KEY idx_admin_tickets_creator (creator_user_id),
      CONSTRAINT fk_admin_tickets_creator FOREIGN KEY (creator_user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT fk_admin_tickets_character FOREIGN KEY (creator_character_id) REFERENCES characters (id) ON DELETE SET NULL ON UPDATE CASCADE,
      CONSTRAINT fk_admin_tickets_assigned FOREIGN KEY (assigned_user_id) REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS admin_ticket_messages (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      ticket_id BIGINT UNSIGNED NOT NULL,
      author_user_id BIGINT UNSIGNED NULL,
      message TEXT NOT NULL,
      is_internal TINYINT(1) NOT NULL DEFAULT 0,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_admin_ticket_messages_ticket (ticket_id, created_at),
      CONSTRAINT fk_admin_ticket_messages_ticket FOREIGN KEY (ticket_id) REFERENCES admin_tickets (id) ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT fk_admin_ticket_messages_author FOREIGN KEY (author_user_id) REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS admin_audit (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      actor_user_id BIGINT UNSIGNED NULL,
      action_key VARCHAR(64) NOT NULL,
      target_user_id BIGINT UNSIGNED NULL,
      payload_json JSON NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_admin_audit_actor (actor_user_id),
      KEY idx_admin_audit_action (action_key, created_at),
      CONSTRAINT fk_admin_audit_actor FOREIGN KEY (actor_user_id) REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE,
      CONSTRAINT fk_admin_audit_target FOREIGN KEY (target_user_id) REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  if not hasColumn('users', 'profile_name') then
    MySQL.query.await('ALTER TABLE users ADD COLUMN profile_name VARCHAR(128) NULL AFTER discord_id')
  end

  if not hasColumn('users', 'steam_name') then
    MySQL.query.await('ALTER TABLE users ADD COLUMN steam_name VARCHAR(128) NULL AFTER profile_name')
  end

  MySQL.query.await([[
    UPDATE users
    SET steam_name = profile_name
    WHERE (steam_name IS NULL OR steam_name = '')
      AND profile_name IS NOT NULL
      AND profile_name <> ''
  ]])
end

local function ensureShopSettingsSchema()
  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS shop_vehicles (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      shop_id BIGINT UNSIGNED NOT NULL,
      vehicle_id BIGINT UNSIGNED NOT NULL,
      price INT UNSIGNED NOT NULL,
      enabled TINYINT(1) NOT NULL DEFAULT 1,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY ux_shop_vehicles_shop_vehicle (shop_id, vehicle_id),
      KEY idx_shop_vehicles_shop_enabled (shop_id, enabled),
      CONSTRAINT fk_shop_vehicles_shop FOREIGN KEY (shop_id) REFERENCES shops (id) ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT fk_shop_vehicles_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE RESTRICT ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])
end

local function bootstrapAdminData()
  MySQL.query.await([[
    INSERT INTO admin_roles (role_name, label, priority)
    VALUES
      ('supporter', 'Supporter', 10),
      ('moderator', 'Moderator', 20),
      ('admin', 'Admin', 30),
      ('manager', 'Manager', 40),
      ('projektleitung', 'Projektleitung', 50)
    ON DUPLICATE KEY UPDATE
      label = VALUES(label),
      priority = VALUES(priority)
  ]])

  MySQL.query.await([[
    INSERT INTO admin_permissions (permission_key, label, description)
    VALUES
      ('admin.menu.open', 'Admin-Menü öffnen', 'Darf das Admin-Menü öffnen'),
      ('dashboard.view', 'Dashboard sehen', 'Darf Dashboard-Daten sehen'),
      ('players.view', 'Spieler sehen', 'Darf Spielerliste sehen'),
      ('players.kick', 'Spieler kicken', 'Darf Spieler kicken'),
      ('players.ban', 'Spieler bannen', 'Darf Spieler bannen'),
      ('vehicles.spawn.command', 'Fahrzeugspawn-Befehl', 'Darf /car <modell> ausführen'),
      ('vehicles.delete.command', 'Fahrzeuglösch-Befehl', 'Darf /delete [umkreis] ausführen'),
      ('commands.heal', 'Heal-Befehl', 'Darf /heal [id] ausführen'),
      ('commands.revive', 'Revive-Befehl', 'Darf /revive [id] ausführen'),
      ('commands.repair', 'Repair-Befehl', 'Darf /repair [id] ausführen'),
      ('commands.reload', 'Reload-Befehl', 'Darf /reload [id] ausführen'),
      ('commands.tp', 'Teleport-Befehle', 'Darf /goto [id] und /tp [x,y,z] ausführen'),
      ('commands.tpm', 'Teleport-zu-Marker-Befehl', 'Darf /tpm ausführen'),
      ('commands.bring', 'Bring-Befehl', 'Darf /bring [id] ausführen'),
      ('commands.freeze', 'Freeze-Befehl', 'Darf /freeze [id] ausführen'),
      ('commands.skin', 'Skin-Befehl', 'Darf /skin [id] ausführen'),
      ('commands.identity', 'Identity-Befehl', 'Darf /identity [id] ausführen'),
      ('commands.noclip', 'Noclip-Befehl', 'Darf /noclip ausführen'),
      ('commands.name', 'Nametag-Befehl', 'Darf /name ausführen'),
      ('commands.aduty', 'Admin-Duty-Befehl', 'Darf /aduty ausführen'),
      ('commands.givemoney', 'GiveMoney-Befehl', 'Darf /givemoney [id] [bar/bank] [menge] ausführen'),
      ('commands.setmoney', 'SetMoney-Befehl', 'Darf /setmoney [id] [bar/bank] [stand] ausführen'),
      ('commands.giveitem', 'GiveItem-Befehl', 'Darf /giveitem [id] [item] [anzahl] ausführen'),
      ('commands.setjob', 'SetJob-Befehl', 'Darf /setjob [id] [job] [rang] ausführen'),
      ('commands.giveweapon', 'GiveWeapon-Befehl', 'Darf /giveweapon [id] [modell] ausführen'),
      ('bans.view', 'Banns sehen', 'Darf Bannliste sehen'),
      ('bans.manage', 'Banns verwalten', 'Darf Banns aufheben'),
      ('tickets.view', 'Tickets sehen', 'Darf Tickets sehen'),
      ('tickets.manage', 'Tickets verwalten', 'Darf Tickets verwalten'),
      ('scripts.view', 'Scripts sehen', 'Darf Scriptliste sehen'),
      ('scripts.restart', 'Scripts restarten', 'Darf Ressourcen neu starten'),
      ('settings.view', 'Einstellungen sehen', 'Darf Einstellungen sehen'),
      ('settings.shops.manage', 'Shops verwalten', 'Darf Shops und Shop-Items bearbeiten'),
      ('rights.view', 'Rechte sehen', 'Darf Rechtebereich sehen'),
      ('rights.assign', 'Rechte vergeben', 'Darf Rollen vergeben')
    ON DUPLICATE KEY UPDATE
      label = VALUES(label),
      description = VALUES(description)
  ]])

  MySQL.query.await([[
    INSERT IGNORE INTO admin_role_permissions (role_id, permission_id, allow)
    SELECT r.id, p.id, 1
    FROM admin_roles r
    JOIN admin_permissions p ON (
      (r.role_name = 'supporter' AND p.permission_key IN ('admin.menu.open','dashboard.view','tickets.view','tickets.manage')) OR
      (r.role_name = 'moderator' AND p.permission_key IN ('admin.menu.open','dashboard.view','players.view','players.kick','bans.view','tickets.view','tickets.manage','commands.heal','commands.revive','commands.repair','commands.reload','commands.tp','commands.tpm','commands.name','commands.aduty','scripts.view','settings.view')) OR
      (r.role_name = 'admin' AND p.permission_key IN ('admin.menu.open','dashboard.view','players.view','players.kick','players.ban','vehicles.spawn.command','vehicles.delete.command','commands.heal','commands.revive','commands.repair','commands.reload','commands.tp','commands.tpm','commands.bring','commands.freeze','commands.skin','commands.identity','commands.noclip','commands.name','commands.aduty','commands.givemoney','commands.setmoney','commands.giveitem','commands.setjob','commands.giveweapon','bans.view','bans.manage','tickets.view','tickets.manage','scripts.view','scripts.restart','settings.view','settings.shops.manage')) OR
      (r.role_name = 'manager' AND p.permission_key IN ('admin.menu.open','dashboard.view','players.view','players.kick','players.ban','vehicles.spawn.command','vehicles.delete.command','commands.heal','commands.revive','commands.repair','commands.reload','commands.tp','commands.tpm','commands.bring','commands.freeze','commands.skin','commands.identity','commands.noclip','commands.name','commands.aduty','commands.givemoney','commands.setmoney','commands.giveitem','commands.setjob','commands.giveweapon','bans.view','bans.manage','tickets.view','tickets.manage','scripts.view','scripts.restart','settings.view','settings.shops.manage')) OR
      (r.role_name = 'projektleitung' AND p.permission_key IN ('admin.menu.open','dashboard.view','players.view','players.kick','players.ban','vehicles.spawn.command','vehicles.delete.command','commands.heal','commands.revive','commands.repair','commands.reload','commands.tp','commands.tpm','commands.bring','commands.freeze','commands.skin','commands.identity','commands.noclip','commands.name','commands.aduty','commands.givemoney','commands.setmoney','commands.giveitem','commands.setjob','commands.giveweapon','bans.view','bans.manage','tickets.view','tickets.manage','scripts.view','scripts.restart','settings.view','settings.shops.manage','rights.view','rights.assign'))
    )
  ]])

  MySQL.query.await([[
    INSERT IGNORE INTO admin_role_duty_outfits (role_id, top_drawable, pants_drawable, shoes_drawable, hat_drawable)
    SELECT r.id,
      CASE
        WHEN r.role_name = 'supporter' THEN 59
        WHEN r.role_name = 'moderator' THEN 179
        WHEN r.role_name = 'admin' THEN 287
        WHEN r.role_name = 'manager' THEN 315
        WHEN r.role_name = 'projektleitung' THEN 316
        ELSE 15
      END AS top_drawable,
      14 AS pants_drawable,
      34 AS shoes_drawable,
      -1 AS hat_drawable
    FROM admin_roles r
  ]])

end

local function fetchBanByIdentifier(identifier)
  if not identifier or identifier == '' then
    return nil
  end

  return MySQL.single.await([=[
    SELECT b.id, b.reason, b.expires_at, b.banned_by_user_id,
           ub.license AS banned_by_license,
           ub.fivem_id AS banned_by_fivem_id,
           ub.steam_id AS banned_by_steam_id,
           ub.discord_id AS banned_by_discord_id,
           ub.steam_name AS banned_by_steam_name,
           ub.profile_name AS banned_by_profile_name,
           (
             SELECT CONCAT(ci.first_name, ' ', ci.last_name)
             FROM characters c
             LEFT JOIN character_identity ci ON ci.character_id = c.id
             WHERE c.user_id = b.banned_by_user_id
               AND c.is_active = 1
             ORDER BY c.updated_at DESC
             LIMIT 1
           ) AS banned_by_character_name,
           (
             SELECT r.label
             FROM admin_user_roles aur
             JOIN admin_roles r ON r.id = aur.role_id
             WHERE aur.user_id = b.banned_by_user_id
             LIMIT 1
           ) AS banned_by_role_label
    FROM users u
    JOIN admin_bans b ON b.user_id = u.id
    LEFT JOIN users ub ON ub.id = b.banned_by_user_id
    WHERE u.license = ?
      AND b.active = 1
      AND (b.expires_at IS NULL OR b.expires_at > NOW())
    ORDER BY b.id DESC
    LIMIT 1
  ]=], { identifier })
end

local function buildLivePlayers(searchText)
  local players = {}
  local filter = trim(searchText):lower()
  local online = GetPlayers()

  for i = 1, #online do
    local src = tonumber(online[i])
    local userId = getUserIdFromSource(src)
    local roleData = userId and getRoleDataByUserId(userId) or nil
    local name = GetPlayerName(src) or 'Unbekannt'
    local identifiers = getIdentityMap(src)
    local characterName = exports.rp_core:GetCharacterName(src) or 'Nicht geladen'

    local row = {
      source = src,
      ping = GetPlayerPing(src),
      name = name,
      userId = userId,
      characterName = characterName,
      roleName = roleData and roleData.roleName or 'none',
      roleLabel = roleData and roleData.roleLabel or 'Kein Rang',
      identifiers = identifiers,
      online = true
    }

    local line = (('%s %s %s %s'):format(name, characterName, tostring(src), tostring(userId or ''))):lower()
    if filter == '' or line:find(filter, 1, true) then
      players[#players + 1] = row
    end
  end

  table.sort(players, function(a, b)
    return a.source < b.source
  end)

  return players
end

local function buildOfflinePlayers(searchText)
  local players = {}
  local filter = trim(searchText):lower()
  local onlineByUserId = {}
  local online = GetPlayers()

  for i = 1, #online do
    local src = tonumber(online[i])
    local userId = getUserIdFromSource(src)
    if userId then
      onlineByUserId[userId] = true
    end
  end

  local rows = MySQL.query.await([=[
    SELECT u.id AS user_id, u.steam_name, u.profile_name, u.license, u.fivem_id, u.steam_id, u.discord_id, u.last_seen_at,
           r.role_name, r.label AS role_label,
           (
             SELECT CONCAT(ci.first_name, ' ', ci.last_name)
             FROM characters c
             LEFT JOIN character_identity ci ON ci.character_id = c.id
             WHERE c.user_id = u.id
               AND c.is_active = 1
             ORDER BY c.updated_at DESC
             LIMIT 1
           ) AS active_character_name
    FROM users u
    LEFT JOIN admin_user_roles aur ON aur.user_id = u.id
    LEFT JOIN admin_roles r ON r.id = aur.role_id
    ORDER BY u.last_seen_at DESC, u.id DESC
    LIMIT ?
  ]=], { RPAdminConfig.maxListEntries * 10 }) or {}

  for i = 1, #rows do
    local row = rows[i]
    local userId = tonumber(row.user_id)
    if userId and not onlineByUserId[userId] then
      local identifierFallback = pickIdentifierDisplay(row.steam_id, row.fivem_id, row.discord_id, row.license)
      local name = resolveProfileName(userId, row.steam_name, row.profile_name, row.active_character_name, identifierFallback)
      local characterName = trim(row.active_character_name)
      if characterName == '' then
        characterName = 'Kein aktiver Charakter'
      end

      local playerRow = {
        source = 0,
        ping = '-',
        name = name,
        userId = userId,
        characterName = characterName,
        roleName = row.role_name or 'none',
        roleLabel = row.role_label or 'Kein Rang',
        identifiers = {
          license = row.license,
          fivem = row.fivem_id,
          steam = row.steam_id,
          discord = row.discord_id
        },
        online = false
      }

      local line = (('%s %s %s %s'):format(
        playerRow.name,
        playerRow.characterName,
        tostring(userId),
        identifierFallback
      )):lower()

      if filter == '' or line:find(filter, 1, true) then
        players[#players + 1] = playerRow
        if #players >= RPAdminConfig.maxListEntries then
          break
        end
      end
    end
  end

  return players
end

local function buildPlayers(searchText, mode)
  if normalizePlayerListMode(mode) == 'offline' then
    return buildOfflinePlayers(searchText)
  end

  return buildLivePlayers(searchText)
end

local function getSourceByUserId(userId)
  userId = tonumber(userId)
  if not userId then
    return nil
  end

  local online = GetPlayers()
  for i = 1, #online do
    local src = tonumber(online[i])
    if src and getUserIdFromSource(src) == userId then
      return src
    end
  end

  return nil
end

local function resolveProfileNameByUserId(userId, identifierFallback, characterName, profileNameHint, steamNameHint)
  return resolveProfileName(userId, steamNameHint, profileNameHint, characterName, identifierFallback)
end

local function fetchBans(limit)
  return MySQL.query.await([=[
    SELECT b.id, b.user_id, b.banned_by_user_id, b.reason, b.created_at, b.expires_at, b.active,
           ua.license,
           ua.fivem_id,
           ua.steam_id,
           ua.discord_id,
           ua.steam_name,
           ua.profile_name,
           ub.license AS banned_by_license,
           ub.fivem_id AS banned_by_fivem_id,
           ub.steam_id AS banned_by_steam_id,
           ub.discord_id AS banned_by_discord_id,
           ub.steam_name AS banned_by_steam_name_stored,
           ub.profile_name AS banned_by_profile_name_stored,
           ur.license AS revoked_by_license,
           (
             SELECT CONCAT(ci.first_name, ' ', ci.last_name)
             FROM characters c
             LEFT JOIN character_identity ci ON ci.character_id = c.id
             WHERE c.user_id = b.user_id
               AND c.is_active = 1
             ORDER BY c.updated_at DESC
             LIMIT 1
           ) AS banned_character_name,
           (
             SELECT CONCAT(ci2.first_name, ' ', ci2.last_name)
             FROM characters c2
             LEFT JOIN character_identity ci2 ON ci2.character_id = c2.id
             WHERE c2.user_id = b.banned_by_user_id
               AND c2.is_active = 1
             ORDER BY c2.updated_at DESC
             LIMIT 1
           ) AS banned_by_character_name
    FROM admin_bans b
    JOIN users ua ON ua.id = b.user_id
    LEFT JOIN users ub ON ub.id = b.banned_by_user_id
    LEFT JOIN users ur ON ur.id = b.revoked_by_user_id
    WHERE b.active = 1
      AND (b.expires_at IS NULL OR b.expires_at > NOW())
    ORDER BY b.id DESC
    LIMIT ?
  ]=], { limit or RPAdminConfig.maxListEntries })
end

local function enrichBanRuntime(bans)
  for i = 1, #bans do
    local ban = bans[i]
    local bannedIdentifier = pickIdentifierDisplay(ban.steam_id, ban.fivem_id, ban.discord_id, ban.license)
    local bannedByIdentifier = pickIdentifierDisplay(
      ban.banned_by_steam_id,
      ban.banned_by_fivem_id,
      ban.banned_by_discord_id,
      ban.banned_by_license
    )

    ban.banned_profile_name = resolveProfileNameByUserId(
      ban.user_id,
      bannedIdentifier,
      ban.banned_character_name,
      ban.profile_name,
      ban.steam_name
    )

    if tonumber(ban.banned_by_user_id) then
      ban.banned_by_profile_name = resolveProfileNameByUserId(
        ban.banned_by_user_id,
        bannedByIdentifier,
        ban.banned_by_character_name,
        ban.banned_by_profile_name_stored,
        ban.banned_by_steam_name_stored
      )
    else
      ban.banned_by_profile_name = 'System'
    end
  end

  return bans
end

local function fetchTickets(limit)
  return MySQL.query.await([=[
    SELECT t.id, t.creator_user_id, t.creator_character_id, t.title, t.description, t.status,
           t.assigned_user_id, t.created_at, t.updated_at, t.closed_at,
           ci.first_name AS creator_first_name, ci.last_name AS creator_last_name,
           uc.license AS creator_license,
           uc.fivem_id AS creator_fivem,
           uc.steam_id AS creator_steam,
           uc.discord_id AS creator_discord,
           ua.license AS assigned_license,
           ua.fivem_id AS assigned_fivem,
           ua.steam_id AS assigned_steam,
           ua.discord_id AS assigned_discord,
           (
             SELECT CONCAT(ci2.first_name, ' ', ci2.last_name)
             FROM characters c2
             LEFT JOIN character_identity ci2 ON ci2.character_id = c2.id
             WHERE c2.user_id = t.assigned_user_id
               AND c2.is_active = 1
             ORDER BY c2.updated_at DESC
             LIMIT 1
           ) AS assigned_character_name
    FROM admin_tickets t
    LEFT JOIN character_identity ci ON ci.character_id = t.creator_character_id
    LEFT JOIN users uc ON uc.id = t.creator_user_id
    LEFT JOIN users ua ON ua.id = t.assigned_user_id
    WHERE t.status <> 'closed'
    ORDER BY t.id DESC
    LIMIT ?
  ]=], { limit or RPAdminConfig.maxListEntries })
end

local function fetchUserTickets(userId, limit)
  return MySQL.query.await([=[
    SELECT t.id, t.creator_user_id, t.creator_character_id, t.title, t.description, t.status,
           t.assigned_user_id, t.created_at, t.updated_at, t.closed_at,
           ci.first_name AS creator_first_name, ci.last_name AS creator_last_name,
           ua.license AS assigned_license,
           ua.fivem_id AS assigned_fivem,
           ua.steam_id AS assigned_steam,
           ua.discord_id AS assigned_discord,
           (
             SELECT CONCAT(ci2.first_name, ' ', ci2.last_name)
             FROM characters c2
             LEFT JOIN character_identity ci2 ON ci2.character_id = c2.id
             WHERE c2.user_id = t.assigned_user_id
               AND c2.is_active = 1
             ORDER BY c2.updated_at DESC
             LIMIT 1
           ) AS assigned_character_name
    FROM admin_tickets t
    LEFT JOIN character_identity ci ON ci.character_id = t.creator_character_id
    LEFT JOIN users ua ON ua.id = t.assigned_user_id
    WHERE t.creator_user_id = ?
    ORDER BY t.id DESC
    LIMIT ?
  ]=], { userId, limit or 5 })
end

local function resolveCreatorIdentifier(ticket, creatorSource)
  if not ticket then
    return 'Unbekannt'
  end

  if creatorSource and creatorSource > 0 then
    local profileName = GetPlayerName(creatorSource)
    if profileName and profileName ~= '' then
      return profileName
    end
  end

  local creatorCharacter = trim((ticket.creator_first_name or '') .. ' ' .. (ticket.creator_last_name or ''))
  if creatorCharacter ~= '' then
    return creatorCharacter
  end

  return 'Unbekannt'
end

local function resolveAssignedIdentifier(ticket, assignedSource)
  if not ticket or not ticket.assigned_user_id then
    return 'Noch niemand'
  end

  -- Wenn der zuständige Bearbeiter online ist, nutze den Profilnamen
  -- (gleiches Verhalten wie im Dashboard via GetPlayerName).
  if assignedSource and assignedSource > 0 then
    local profileName = GetPlayerName(assignedSource)
    if profileName and profileName ~= '' then
      return profileName
    end
  end

  -- Offline-Fallback: technische Plattform-Identifier.
  local assignedCharacter = trim(ticket.assigned_character_name or '')
  if assignedCharacter ~= '' then
    return assignedCharacter
  end

  return 'Unbekannt'
end

local function enrichTicketRuntime(tickets)
  for i = 1, #tickets do
    local ticket = tickets[i]
    ticket.creator_source = getSourceByUserId(ticket.creator_user_id)
    ticket.assigned_source = getSourceByUserId(ticket.assigned_user_id)
    ticket.creator_name = resolveCreatorIdentifier(ticket, ticket.creator_source)
    ticket.assigned_name = resolveAssignedIdentifier(ticket, ticket.assigned_source)
  end

  return tickets
end

local function fetchRoleOverview()
  local roles = MySQL.query.await('SELECT id, role_name, label, priority FROM admin_roles ORDER BY priority ASC')
  local perms = MySQL.query.await('SELECT id, permission_key, label, description FROM admin_permissions ORDER BY permission_key ASC')
  local rpRows = MySQL.query.await([=[
    SELECT r.role_name, p.permission_key
    FROM admin_role_permissions arp
    JOIN admin_roles r ON r.id = arp.role_id
    JOIN admin_permissions p ON p.id = arp.permission_id
    WHERE arp.allow = 1
  ]=])

  local rolePermissions = {}
  for i = 1, #rpRows do
    local row = rpRows[i]
    if not rolePermissions[row.role_name] then
      rolePermissions[row.role_name] = {}
    end

    rolePermissions[row.role_name][#rolePermissions[row.role_name] + 1] = row.permission_key
  end

  local memberRows = MySQL.query.await([=[
    SELECT aur.user_id, r.role_name, r.label AS role_label, r.priority, u.license, u.fivem_id, u.steam_id, u.discord_id, u.steam_name, u.profile_name,
      (
        SELECT CONCAT(ci.first_name, ' ', ci.last_name)
        FROM characters c
        LEFT JOIN character_identity ci ON ci.character_id = c.id
        WHERE c.user_id = aur.user_id
          AND c.is_active = 1
        ORDER BY c.updated_at DESC
        LIMIT 1
      ) AS active_character_name
    FROM admin_user_roles aur
    JOIN admin_roles r ON r.id = aur.role_id
    JOIN users u ON u.id = aur.user_id
    ORDER BY r.priority ASC, aur.user_id ASC
  ]=])

  local roleMembers = {}
  for i = 1, #memberRows do
    local row = memberRows[i]
    local src = getSourceByUserId(row.user_id)
    local profileName = resolveProfileNameByUserId(
      row.user_id,
      pickIdentifierDisplay(row.steam_id, row.fivem_id, row.discord_id, row.license),
      row.active_character_name,
      row.profile_name,
      row.steam_name
    )

    roleMembers[#roleMembers + 1] = {
      userId = tonumber(row.user_id),
      roleName = row.role_name,
      roleLabel = row.role_label,
      profileName = profileName,
      source = src or 0,
      online = src ~= nil
    }
  end

  return roles, perms, rolePermissions, roleMembers
end

local function fetchRoleDutyOutfits()
  local rows = MySQL.query.await([=[
    SELECT r.role_name, r.label,
           COALESCE(o.top_drawable, 15) AS top_drawable,
           COALESCE(o.pants_drawable, 14) AS pants_drawable,
           COALESCE(o.shoes_drawable, 34) AS shoes_drawable,
           COALESCE(o.hat_drawable, -1) AS hat_drawable
    FROM admin_roles r
    LEFT JOIN admin_role_duty_outfits o ON o.role_id = r.id
    ORDER BY r.priority ASC
  ]=])

  local out = {}
  for i = 1, #rows do
    local row = rows[i]
    out[row.role_name] = {
      roleName = row.role_name,
      roleLabel = row.label,
      top = tonumber(row.top_drawable) or 15,
      pants = tonumber(row.pants_drawable) or 14,
      shoes = tonumber(row.shoes_drawable) or 34,
      hat = tonumber(row.hat_drawable) or -1
    }
  end

  return out
end

local function getDutyOutfitByRoleName(roleName)
  roleName = trim(roleName):lower()
  if roleName == '' then
    return nil
  end

  local row = MySQL.single.await([=[
    SELECT COALESCE(o.top_drawable, 15) AS top_drawable,
           COALESCE(o.pants_drawable, 14) AS pants_drawable,
           COALESCE(o.shoes_drawable, 34) AS shoes_drawable,
           COALESCE(o.hat_drawable, -1) AS hat_drawable
    FROM admin_roles r
    LEFT JOIN admin_role_duty_outfits o ON o.role_id = r.id
    WHERE r.role_name = ?
    LIMIT 1
  ]=], { roleName })

  if not row then
    return nil
  end

  return {
    top = tonumber(row.top_drawable) or 15,
    pants = tonumber(row.pants_drawable) or 14,
    shoes = tonumber(row.shoes_drawable) or 34,
    hat = tonumber(row.hat_drawable) or -1
  }
end

local function fetchResourceOverview()
  local list = {}
  local total = GetNumResources() or 0

  for i = 0, total - 1 do
    local name = GetResourceByFindIndex(i)
    if name and name ~= '' then
      list[#list + 1] = {
        name = name,
        state = GetResourceState(name) or 'unknown'
      }
    end
  end

  table.sort(list, function(a, b)
    return tostring(a.name):lower() < tostring(b.name):lower()
  end)

  return list
end

local function fetchShopSettingsData(source)
  local shops = MySQL.query.await([=[
    SELECT id, shop_code, label, shop_type, pos_x, pos_y, pos_z, heading, enabled,
           COALESCE(blip_enabled, 1) AS blip_enabled
    FROM shops
    ORDER BY id ASC
  ]=]) or {}

  local inventoryItems = MySQL.query.await([=[
    SELECT id, item_name, label
    FROM inventory_items
    ORDER BY label ASC
  ]=]) or {}

  local shopItems = MySQL.query.await([=[
    SELECT si.shop_id, si.item_id, si.price, si.currency, si.enabled,
           ii.item_name, ii.label
    FROM shop_items si
    INNER JOIN inventory_items ii ON ii.id = si.item_id
    ORDER BY si.shop_id ASC, ii.label ASC
  ]=]) or {}

  local vehicleCatalog = MySQL.query.await([=[
    SELECT id, model, label, price, category, enabled
    FROM vehicles
    ORDER BY label ASC
  ]=]) or {}

  local shopVehicles = MySQL.query.await([=[
    SELECT sv.shop_id, sv.vehicle_id, sv.price, sv.enabled,
           v.model, v.label, v.category
    FROM shop_vehicles sv
    INNER JOIN vehicles v ON v.id = sv.vehicle_id
    ORDER BY sv.shop_id ASC, v.label ASC
  ]=]) or {}

  local draft = SettingsDraft[source] or {}
  return {
    shops = shops,
    inventoryItems = inventoryItems,
    shopItems = shopItems,
    vehicleCatalog = vehicleCatalog,
    shopVehicles = shopVehicles,
    draftCoords = draft.coords or nil
  }
end

local function buildPanelPayload(source)
  local ctx = getViewerContext(source)
  if not ctx.userId or not ctx.roleData then
    return nil
  end

  local activeBans = MySQL.scalar.await('SELECT COUNT(*) FROM admin_bans WHERE active = 1 AND (expires_at IS NULL OR expires_at > NOW())') or 0
  local openTickets = MySQL.scalar.await("SELECT COUNT(*) FROM admin_tickets WHERE status <> 'closed'") or 0

  local playerListMode = normalizePlayerListMode(PlayerListMode[source] or 'live')
  local players = buildPlayers(SearchFilter[source] or '', playerListMode)
  local dashboardPlayers = buildLivePlayers('')
  local bans = enrichBanRuntime(fetchBans(100))
  local tickets = enrichTicketRuntime(fetchTickets(100))
  local roles, permissions, rolePermissions, roleMembers = fetchRoleOverview()
  local roleDutyOutfits = fetchRoleDutyOutfits()
  local resources = {}
  local settings = {
    shops = {},
    inventoryItems = {},
    shopItems = {},
    vehicleCatalog = {},
    shopVehicles = {},
    draftCoords = nil
  }

  if ctx.roleData.permissions['scripts.view'] == true then
    resources = fetchResourceOverview()
  end

  if ctx.roleData.permissions['settings.view'] == true then
    settings = fetchShopSettingsData(source)
  end

  return {
    viewer = {
      source = source,
      userId = ctx.userId,
      roleName = ctx.roleData.roleName,
      roleLabel = ctx.roleData.roleLabel,
      permissions = ctx.roleData.permissions
    },
    stats = {
      onlineCount = #GetPlayers(),
      activeBans = tonumber(activeBans) or 0,
      openTickets = tonumber(openTickets) or 0
    },
    dashboardPlayers = dashboardPlayers,
    players = players,
    bans = bans,
    tickets = tickets,
    roles = roles,
    permissionsCatalog = permissions,
    rolePermissions = rolePermissions,
    roleMembers = roleMembers,
    roleDutyOutfits = roleDutyOutfits,
    resources = resources,
    settings = settings,
    search = SearchFilter[source] or '',
    playerListMode = playerListMode
  }
end

local function buildTicketPanelPayload(source)
  local userId = getUserIdFromSource(source)
  if not userId then
    return nil
  end

  local characterName = exports.rp_core:GetCharacterName(source) or (GetPlayerName(source) or 'Spieler')
  local tickets = enrichTicketRuntime(fetchUserTickets(userId, 5))

  return {
    mode = 'ticket',
    viewer = {
      source = source,
      userId = userId,
      displayName = characterName
    },
    stats = {
      ownOpenTickets = tonumber(MySQL.scalar.await(
        "SELECT COUNT(*) FROM admin_tickets WHERE creator_user_id = ? AND status <> 'closed'",
        { userId }
      )) or 0
    },
    tickets = tickets
  }
end

local function pushPanel(source, open)
  local payload = buildPanelPayload(source)
  if not payload then
    notify(source, 'error', 'Kein gültiger Rang für Admin-Menü gefunden.')
    return
  end

  if open then
    TriggerClientEvent('rp:admin:openPanel', source, payload)
  else
    TriggerClientEvent('rp:admin:updatePanel', source, payload)
  end
end

local function pushTicketPanel(source, open)
  local payload = buildTicketPanelPayload(source)
  if not payload then
    notify(source, 'error', 'Ticketdaten konnten nicht geladen werden.')
    return
  end

  if open then
    TriggerClientEvent('rp:admin:openTicketPanel', source, payload)
  else
    TriggerClientEvent('rp:admin:updateTicketPanel', source, payload)
  end
end

local function refreshPlayerAccessState(targetSource, message)
  if not targetSource or targetSource <= 0 or not GetPlayerName(targetSource) then
    return
  end

  local targetUserId = getUserIdFromSource(targetSource)
  if targetUserId then
    invalidateRoleCache(targetUserId)
  end

  ActiveRoleFingerprint[targetSource] = nil
  pushCommandSuggestions(targetSource)

  local mode = PanelOpenMode[targetSource]
  if mode == 'admin' then
    if hasPermission(targetSource, 'admin.menu.open') then
      pushPanel(targetSource, false)
    else
      PanelOpenMode[targetSource] = nil
      TriggerClientEvent('rp:admin:forceClose', targetSource)
    end
  elseif mode == 'ticket' then
    pushTicketPanel(targetSource, false)
  end

  if type(message) == 'string' and message ~= '' then
    notify(targetSource, 'info', message)
  end
end

local function ensurePermission(source, permissionKey)
  if not hasPermission(source, permissionKey) then
    notify(source, 'error', 'Dafür fehlen dir Rechte.')
    return false
  end

  return true
end

local function getRolePriorityByUserId(userId)
  local roleData = getRoleDataByUserId(userId)
  return tonumber(roleData and roleData.priority) or 0
end

local function isHighestRolePriority(priority)
  local maxPriority = tonumber(MySQL.scalar.await('SELECT MAX(priority) FROM admin_roles')) or 0
  return priority >= maxPriority, maxPriority
end

local function canAffectTargetUserByHierarchy(actorSource, targetUserId, deniedMessage)
  if IsPlayerAceAllowed(actorSource, 'rp.admin.bypass') then
    return true
  end

  local actorUserId = getUserIdFromSource(actorSource)
  if not actorUserId then
    notify(actorSource, 'error', 'Dein Rang konnte nicht ermittelt werden.')
    return false
  end

  targetUserId = tonumber(targetUserId)
  if not targetUserId then
    return true
  end

  local actorPriority = getRolePriorityByUserId(actorUserId)
  local targetPriority = getRolePriorityByUserId(targetUserId)
  local actorIsHighestRole = isHighestRolePriority(actorPriority)

  if targetPriority > actorPriority or (targetPriority == actorPriority and not actorIsHighestRole) then
    notify(actorSource, 'error', deniedMessage or 'Du kannst keinen gleich hohen oder höheren Rang moderieren.')
    return false
  end

  return true
end

local function canAffectTargetByHierarchy(actorSource, targetSource, deniedMessage)
  local targetUserId = getUserIdFromSource(targetSource)
  return canAffectTargetUserByHierarchy(actorSource, targetUserId, deniedMessage)
end

local function setRoleForUser(actorSource, targetUserId, roleName)
  if not ensurePermission(actorSource, 'rights.assign') then
    return
  end

  targetUserId = tonumber(targetUserId)
  roleName = trim(roleName):lower()
  local actorUserId = getUserIdFromSource(actorSource)

  if not targetUserId or targetUserId <= 0 then
    notify(actorSource, 'error', 'Ungültige Ziel-User-ID.')
    return
  end

  local exists = MySQL.scalar.await('SELECT id FROM users WHERE id = ? LIMIT 1', { targetUserId })
  if not exists then
    notify(actorSource, 'error', 'Ziel-User nicht gefunden.')
    return
  end

  local newRole = nil
  local newRolePriority = 0

  if not isNoTeamRole(roleName) then
    newRole = MySQL.single.await('SELECT id, label, priority FROM admin_roles WHERE role_name = ? LIMIT 1', { roleName })
    if not newRole then
      notify(actorSource, 'error', 'Rang nicht gefunden.')
      return
    end
    newRolePriority = tonumber(newRole.priority) or 0
  end

  if not IsPlayerAceAllowed(actorSource, 'rp.admin.bypass') then
    local actorRoleData = actorUserId and getRoleDataByUserId(actorUserId) or nil
    local actorPriority = tonumber(actorRoleData and actorRoleData.priority) or 0
    local targetRoleData = getRoleDataByUserId(targetUserId)
    local targetPriority = tonumber(targetRoleData and targetRoleData.priority) or 0
    local actorIsHighestRole = isHighestRolePriority(actorPriority)

    if not actorRoleData then
      notify(actorSource, 'error', 'Dein Rang konnte nicht ermittelt werden.')
      return
    end

    if targetUserId ~= actorUserId then
      if targetPriority > actorPriority or (targetPriority == actorPriority and not actorIsHighestRole) then
        notify(actorSource, 'error', 'Du kannst keinen gleich hohen oder höheren Rang verändern.')
        return
      end

      if newRolePriority > actorPriority or (newRolePriority == actorPriority and not actorIsHighestRole) then
        notify(actorSource, 'error', 'Du kannst keinen gleich hohen oder höheren Rang vergeben.')
        return
      end
    else
      if newRolePriority > actorPriority then
        notify(actorSource, 'error', 'Du kannst dir selbst keinen höheren Rang geben.')
        return
      end
    end
  end

  if isNoTeamRole(roleName) then
    local removed = MySQL.update.await('DELETE FROM admin_user_roles WHERE user_id = ?', { targetUserId })
    invalidateRoleCache(targetUserId)
    auditAction(actorUserId, 'rights.remove', targetUserId, { roleName = 'none', changed = removed > 0 })
    notify(actorSource, 'success', 'Teamrang wurde entfernt (Spieler).')
  else
    MySQL.query.await([[
      INSERT INTO admin_user_roles (user_id, role_id, assigned_by_user_id, assigned_note)
      VALUES (?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        role_id = VALUES(role_id),
        assigned_by_user_id = VALUES(assigned_by_user_id),
        assigned_note = VALUES(assigned_note)
    ]], { targetUserId, newRole.id, actorUserId, ('gesetzt von source %s'):format(actorSource) })

    invalidateRoleCache(targetUserId)
    auditAction(actorUserId, 'rights.assign', targetUserId, { roleName = roleName })
    notify(actorSource, 'success', ('Rang "%s" wurde gesetzt.'):format(newRole.label))
  end

  local targetSource = getSourceByUserId(targetUserId)
  if targetSource then
    refreshPlayerAccessState(targetSource, 'Dein Admin-Rang wurde aktualisiert.')
  end

  pushCommandSuggestions(actorSource)
  refreshAdminPanels()
end

local function normalizeRoleNameFromLabel(label)
  local roleName = trim(tostring(label or '')):lower()
  roleName = roleName:gsub('ä', 'ae'):gsub('ö', 'oe'):gsub('ü', 'ue'):gsub('ß', 'ss')
  roleName = roleName:gsub('[^%w]+', '_')
  roleName = roleName:gsub('_+', '_')
  roleName = roleName:gsub('^_+', ''):gsub('_+$', '')
  if #roleName > 32 then
    roleName = roleName:sub(1, 32)
    roleName = roleName:gsub('_+$', '')
  end
  return roleName
end

local function createRole(actorSource, roleLabel, insertAfterRoleName)
  if not ensurePermission(actorSource, 'rights.assign') then
    return
  end

  local label = trim(tostring(roleLabel or ''))
  if label == '' then
    notify(actorSource, 'error', 'Rangname fehlt.')
    return
  end

  if #label > 48 then
    label = label:sub(1, 48)
  end

  local roleName = normalizeRoleNameFromLabel(label)
  if roleName == '' then
    notify(actorSource, 'error', 'Ungültiger Rangname.')
    return
  end

  if isNoTeamRole(roleName) then
    notify(actorSource, 'error', 'Der Rangname ist reserviert.')
    return
  end

  local exists = MySQL.scalar.await('SELECT id FROM admin_roles WHERE role_name = ? LIMIT 1', { roleName })
  if exists then
    notify(actorSource, 'error', ('Der Rang "%s" existiert bereits.'):format(roleName))
    return
  end

  local insertAfter = trim(tostring(insertAfterRoleName or '')):lower()
  if insertAfter == '' then
    insertAfter = '__bottom__'
  end

  local rolesDesc = MySQL.query.await('SELECT id, role_name, label, priority FROM admin_roles ORDER BY priority DESC, id ASC')
  local ordered = {}
  for i = 1, #rolesDesc do
    ordered[#ordered + 1] = rolesDesc[i]
  end

  local insertIndex = #ordered + 1
  if insertAfter == '__top__' then
    insertIndex = 1
  elseif insertAfter == '__bottom__' then
    insertIndex = #ordered + 1
  else
    local found = false
    for i = 1, #ordered do
      if ordered[i].role_name == insertAfter then
        insertIndex = i + 1
        found = true
        break
      end
    end

    if not found then
      notify(actorSource, 'error', 'Die gewählte Rang-Position ist ungültig.')
      return
    end
  end

  table.insert(ordered, insertIndex, {
    id = 0,
    role_name = roleName,
    label = label
  })

  local prioritiesByRoleName = {}
  for i = 1, #ordered do
    prioritiesByRoleName[ordered[i].role_name] = ((#ordered - i + 1) * 10)
  end

  local newPriority = tonumber(prioritiesByRoleName[roleName]) or 10

  if not IsPlayerAceAllowed(actorSource, 'rp.admin.bypass') then
    local actorUserId = getUserIdFromSource(actorSource)
    local actorRoleData = actorUserId and getRoleDataByUserId(actorUserId) or nil
    local actorPriority = tonumber(actorRoleData and actorRoleData.priority) or 0

    if not actorRoleData then
      notify(actorSource, 'error', 'Dein Rang konnte nicht ermittelt werden.')
      return
    end

    if newPriority >= actorPriority then
      notify(actorSource, 'error', 'Du kannst keinen gleich hohen oder höheren Rang erstellen.')
      return
    end
  end

  for i = 1, #rolesDesc do
    local roleRow = rolesDesc[i]
    local expectedPriority = tonumber(prioritiesByRoleName[roleRow.role_name]) or (tonumber(roleRow.priority) or 0)
    local currentPriority = tonumber(roleRow.priority) or 0
    if expectedPriority ~= currentPriority then
      MySQL.update.await('UPDATE admin_roles SET priority = ? WHERE id = ?', { expectedPriority, roleRow.id })
    end
  end

  MySQL.insert.await([[
    INSERT INTO admin_roles (role_name, label, priority, is_system)
    VALUES (?, ?, ?, 0)
  ]], { roleName, label, newPriority })

  invalidateAllRoleCaches()
  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'rights.create_role', nil, {
    roleName = roleName,
    label = label,
    priority = newPriority,
    insertAfter = insertAfter
  })

  notify(actorSource, 'success', ('Neuer Rang "%s" wurde erstellt.'):format(label))
  refreshAdminPanels()
end

local function deleteRole(actorSource, roleName)
  if not ensurePermission(actorSource, 'rights.assign') then
    return
  end

  roleName = trim(tostring(roleName or '')):lower()
  if roleName == '' then
    notify(actorSource, 'error', 'Rangname fehlt.')
    return
  end

  if isNoTeamRole(roleName) then
    notify(actorSource, 'error', 'Dieser Rang ist reserviert.')
    return
  end

  if roleName == 'projektleitung' then
    notify(actorSource, 'error', 'Projektleitung kann nicht gelöscht werden.')
    return
  end

  local role = MySQL.single.await('SELECT id, label FROM admin_roles WHERE role_name = ? LIMIT 1', { roleName })
  if not role then
    notify(actorSource, 'error', 'Rang nicht gefunden.')
    return
  end

  local assignedRows = MySQL.query.await('SELECT user_id FROM admin_user_roles WHERE role_id = ?', { role.id }) or {}
  local affectedUsers = {}
  for i = 1, #assignedRows do
    local userId = tonumber(assignedRows[i].user_id)
    if userId then
      affectedUsers[#affectedUsers + 1] = userId
    end
  end

  MySQL.update.await('DELETE FROM admin_user_roles WHERE role_id = ?', { role.id })
  local deleted = MySQL.update.await('DELETE FROM admin_roles WHERE id = ?', { role.id })
  if (tonumber(deleted) or 0) <= 0 then
    notify(actorSource, 'warning', 'Rang konnte nicht gelöscht werden.')
    return
  end

  invalidateAllRoleCaches()
  refreshAllCommandSuggestions()
  refreshAdminPanels()

  for i = 1, #affectedUsers do
    local targetUserId = affectedUsers[i]
    local targetSource = getSourceByUserId(targetUserId)
    if targetSource then
      refreshPlayerAccessState(targetSource, 'Dein Admin-Rang wurde entfernt.')
    end
  end

  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'rights.delete_role', nil, {
    roleName = roleName,
    affectedUsers = #affectedUsers
  })

  notify(actorSource, 'success', ('Rang "%s" wurde gelöscht.'):format(role.label))
end

local function setCarRolePermissions(actorSource, roleNames)
  if not ensurePermission(actorSource, 'rights.assign') then
    return
  end

  if type(roleNames) ~= 'table' then
    notify(actorSource, 'error', 'Ungültige Rollenliste.')
    return
  end

  local allowByRole = {}
  for i = 1, #roleNames do
    local roleName = trim(roleNames[i]):lower()
    if roleName ~= '' then
      allowByRole[roleName] = true
    end
  end

  local roles = MySQL.query.await('SELECT id, role_name, label FROM admin_roles ORDER BY priority ASC')
  local permission = MySQL.single.await('SELECT id FROM admin_permissions WHERE permission_key = ? LIMIT 1', { CAR_PERMISSION_KEY })
  if not permission then
    notify(actorSource, 'error', 'Permission für /car wurde nicht gefunden.')
    return
  end

  for i = 1, #roles do
    local role = roles[i]
    local allow = allowByRole[role.role_name] and 1 or 0
    MySQL.query.await([[
      INSERT INTO admin_role_permissions (role_id, permission_id, allow)
      VALUES (?, ?, ?)
      ON DUPLICATE KEY UPDATE
        allow = VALUES(allow)
    ]], { role.id, permission.id, allow })
  end

  invalidateAllRoleCaches()
  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'rights.set_car_roles', nil, { roles = roleNames })
  notify(actorSource, 'success', '/car-Berechtigungen wurden gespeichert.')
  refreshAllCommandSuggestions()
  refreshAdminPanels()
end

local function setRolePermissions(actorSource, roleName, permissionKeys)
  if not ensurePermission(actorSource, 'rights.assign') then
    return
  end

  roleName = trim(roleName):lower()
  if roleName == '' then
    notify(actorSource, 'error', 'Rangname fehlt.')
    return
  end

  if type(permissionKeys) ~= 'table' then
    notify(actorSource, 'error', 'Ungültige Permission-Liste.')
    return
  end

  local role = MySQL.single.await('SELECT id, label FROM admin_roles WHERE role_name = ? LIMIT 1', { roleName })
  if not role then
    notify(actorSource, 'error', 'Rang nicht gefunden.')
    return
  end

  local selected = {}
  for i = 1, #permissionKeys do
    local key = trim(permissionKeys[i])
    if key ~= '' then
      selected[key] = true
    end
  end

  local permissions = MySQL.query.await('SELECT id, permission_key FROM admin_permissions ORDER BY id ASC')
  for i = 1, #permissions do
    local perm = permissions[i]
    local allow = selected[perm.permission_key] and 1 or 0
    MySQL.query.await([[
      INSERT INTO admin_role_permissions (role_id, permission_id, allow)
      VALUES (?, ?, ?)
      ON DUPLICATE KEY UPDATE
        allow = VALUES(allow)
    ]], { role.id, perm.id, allow })
  end

  invalidateAllRoleCaches()
  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'rights.set_permissions', nil, {
    roleName = roleName,
    permissionCount = #permissionKeys
  })
  notify(actorSource, 'success', ('Berechtigungen für "%s" wurden gespeichert.'):format(role.label))
  refreshAllCommandSuggestions()
  refreshAdminPanels()
end

local function toDrawable(value, fallback, minValue, maxValue)
  local number = tonumber(value)
  if not number then
    return fallback
  end

  number = math.floor(number)
  if number < minValue then
    return minValue
  end
  if number > maxValue then
    return maxValue
  end
  return number
end

local function setRoleDutyOutfit(actorSource, roleName, values)
  if not ensurePermission(actorSource, 'rights.assign') then
    return
  end

  roleName = trim(roleName):lower()
  if roleName == '' then
    notify(actorSource, 'error', 'Rangname fehlt.')
    return
  end

  if type(values) ~= 'table' then
    notify(actorSource, 'error', 'Ungültige Outfitdaten.')
    return
  end

  local role = MySQL.single.await('SELECT id, label FROM admin_roles WHERE role_name = ? LIMIT 1', { roleName })
  if not role then
    notify(actorSource, 'error', 'Rang nicht gefunden.')
    return
  end

  local top = toDrawable(values.top, 15, 0, 500)
  local pants = toDrawable(values.pants, 14, 0, 500)
  local shoes = toDrawable(values.shoes, 34, 0, 500)
  local hat = toDrawable(values.hat, -1, -1, 250)
  local actorUserId = getUserIdFromSource(actorSource)

  MySQL.query.await([[
    INSERT INTO admin_role_duty_outfits (role_id, top_drawable, pants_drawable, shoes_drawable, hat_drawable, updated_by_user_id)
    VALUES (?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
      top_drawable = VALUES(top_drawable),
      pants_drawable = VALUES(pants_drawable),
      shoes_drawable = VALUES(shoes_drawable),
      hat_drawable = VALUES(hat_drawable),
      updated_by_user_id = VALUES(updated_by_user_id)
  ]], { role.id, top, pants, shoes, hat, actorUserId })

  auditAction(actorUserId, 'rights.set_duty_outfit', nil, {
    roleName = roleName,
    top = top,
    pants = pants,
    shoes = shoes,
    hat = hat
  })

  notify(actorSource, 'success', ('Admin-Duty-Outfit für "%s" wurde gespeichert.'):format(role.label))
  refreshAdminPanels()
end

local function restartResourceByName(actorSource, resourceName)
  if not ensurePermission(actorSource, 'scripts.restart') then
    return
  end

  resourceName = trim(resourceName):lower()
  if resourceName == '' then
    notify(actorSource, 'error', 'Scriptname fehlt.')
    return
  end

  if not resourceName:match('^[%w_%-%[%]]+$') then
    notify(actorSource, 'error', 'Ungültiger Scriptname.')
    return
  end

  local state = GetResourceState(resourceName)
  if not state or state == 'missing' or state == 'unknown' then
    notify(actorSource, 'error', 'Script nicht gefunden.')
    return
  end

  local wasStarted = (state == 'started' or state == 'starting')
  if wasStarted then
    StopResource(resourceName)
  end

  local started = StartResource(resourceName)
  if started ~= true then
    notify(actorSource, 'error', ('Script "%s" konnte nicht gestartet werden.'):format(resourceName))
    return
  end

  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'scripts.restart', actorUserId, { resource = resourceName })
  notify(actorSource, 'success', ('Script "%s" wird neu gestartet.'):format(resourceName))
end

local function setShopDraftCoordsFromPlayer(actorSource)
  if not ensurePermission(actorSource, 'settings.shops.manage') then
    return
  end

  local ped = GetPlayerPed(actorSource)
  if not ped or ped == 0 then
    notify(actorSource, 'error', 'Spielerposition konnte nicht gelesen werden.')
    return
  end

  local pos = GetEntityCoords(ped)
  local heading = GetEntityHeading(ped)
  SettingsDraft[actorSource] = SettingsDraft[actorSource] or {}
  SettingsDraft[actorSource].coords = {
    x = tonumber(pos.x) or 0.0,
    y = tonumber(pos.y) or 0.0,
    z = tonumber(pos.z) or 0.0,
    h = tonumber(heading) or 0.0
  }

  notify(actorSource, 'success', 'Aktuelle Position wurde als Shop-Koordinate übernommen.')
end

local function triggerShopReload()
  if GetResourceState('rp_shops') == 'started' then
    TriggerEvent('rp:shops:adminReload')
  end
end

local function createShopFromSettings(actorSource, data)
  if not ensurePermission(actorSource, 'settings.shops.manage') then
    return
  end

  data = type(data) == 'table' and data or {}
  local label = trim(tostring(data.label or ''))
  local shopCode = trim(tostring(data.shopCode or '')):lower()
  local shopType = trim(tostring(data.shopType or '24_7')):lower()
  local enabled = data.enabled ~= false
  local blipEnabled = data.blipEnabled ~= false

  if label == '' then
    if shopType == 'clothing' then
      label = 'Kleidungsshop'
    else
      notify(actorSource, 'error', 'Shop-Name fehlt.')
      return
    end
  end
  if #label > 64 then
    label = label:sub(1, 64)
  end

  if shopType ~= '24_7' and shopType ~= 'clothing' and shopType ~= 'vehicle' then
    notify(actorSource, 'error', 'Ungültiger Shop-Typ.')
    return
  end

  if shopCode == '' then
    shopCode = label:lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
  end
  if shopCode == '' then
    shopCode = ('shop_%s'):format(os.time())
  end
  if #shopCode > 32 then
    shopCode = shopCode:sub(1, 32)
  end

  local coords = type(data.coords) == 'table' and data.coords or nil
  local draft = SettingsDraft[actorSource] and SettingsDraft[actorSource].coords or nil
  local x = tonumber(coords and coords.x) or tonumber(draft and draft.x)
  local y = tonumber(coords and coords.y) or tonumber(draft and draft.y)
  local z = tonumber(coords and coords.z) or tonumber(draft and draft.z)
  local h = tonumber(coords and coords.h) or tonumber(draft and draft.h) or 0.0

  if not x or not y or not z then
    notify(actorSource, 'error', 'Koordinaten fehlen. Nutze zuerst "Aktuelle Position übernehmen".')
    return
  end

  if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 10000 then
    notify(actorSource, 'error', 'Koordinaten sind außerhalb des erlaubten Bereichs.')
    return
  end

  local exists = MySQL.scalar.await('SELECT id FROM shops WHERE shop_code = ? LIMIT 1', { shopCode })
  if exists then
    notify(actorSource, 'error', 'Shop-Code existiert bereits.')
    return
  end

  local newShopId = MySQL.insert.await([[
    INSERT INTO shops (shop_code, label, shop_type, pos_x, pos_y, pos_z, heading, enabled, blip_enabled)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  ]], {
    shopCode, label, shopType, x, y, z, h, enabled and 1 or 0, blipEnabled and 1 or 0
  })

  if shopType == 'vehicle' and type(data.vehicleEntries) == 'table' then
    for i = 1, #data.vehicleEntries do
      local entry = data.vehicleEntries[i]
      if type(entry) == 'table' then
        local vehicleId = tonumber(entry.vehicleId)
        local price = math.floor(tonumber(entry.price) or -1)
        if vehicleId and vehicleId > 0 and price >= 0 then
          local vehicleExists = MySQL.scalar.await('SELECT id FROM vehicles WHERE id = ? LIMIT 1', { vehicleId })
          if vehicleExists then
            MySQL.query.await([[
              INSERT INTO shop_vehicles (shop_id, vehicle_id, price, enabled)
              VALUES (?, ?, ?, 1)
              ON DUPLICATE KEY UPDATE
                price = VALUES(price),
                enabled = 1
            ]], { newShopId, vehicleId, price })
          end
        end
      end
    end
  end

  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'settings.shop_create', nil, {
    shopId = newShopId,
    shopCode = shopCode,
    shopType = shopType
  })

  triggerShopReload()
  notify(actorSource, 'success', ('Shop "%s" wurde erstellt.'):format(label))
end

local function addShopItemFromSettings(actorSource, data)
  if not ensurePermission(actorSource, 'settings.shops.manage') then
    return
  end

  data = type(data) == 'table' and data or {}
  local shopId = tonumber(data.shopId)
  local itemId = tonumber(data.itemId)
  local price = math.floor(tonumber(data.price) or -1)
  local currency = trim(tostring(data.currency or 'cash')):lower()

  if not shopId or shopId <= 0 then
    notify(actorSource, 'error', 'Ungültige Shop-ID.')
    return
  end
  if not itemId or itemId <= 0 then
    notify(actorSource, 'error', 'Ungültiges Item.')
    return
  end
  if price < 0 then
    notify(actorSource, 'error', 'Preis muss 0 oder größer sein.')
    return
  end
  if currency ~= 'cash' and currency ~= 'bank' then
    notify(actorSource, 'error', 'Ungültige Währung.')
    return
  end

  local shopExists = MySQL.scalar.await('SELECT id FROM shops WHERE id = ? LIMIT 1', { shopId })
  local itemExists = MySQL.scalar.await('SELECT id FROM inventory_items WHERE id = ? LIMIT 1', { itemId })
  if not shopExists then
    notify(actorSource, 'error', 'Shop nicht gefunden.')
    return
  end
  if not itemExists then
    notify(actorSource, 'error', 'Item nicht gefunden.')
    return
  end

  MySQL.query.await([[
    INSERT INTO shop_items (shop_id, item_id, price, currency, stock, enabled)
    VALUES (?, ?, ?, ?, NULL, 1)
    ON DUPLICATE KEY UPDATE
      price = VALUES(price),
      currency = VALUES(currency),
      enabled = 1
  ]], { shopId, itemId, price, currency })

  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'settings.shop_item_upsert', nil, {
    shopId = shopId,
    itemId = itemId,
    price = price,
    currency = currency
  })

  triggerShopReload()
  notify(actorSource, 'success', 'Shop-Item gespeichert.')
end

local function updateShopFromSettings(actorSource, data)
  if not ensurePermission(actorSource, 'settings.shops.manage') then
    return
  end

  data = type(data) == 'table' and data or {}
  local shopId = tonumber(data.shopId)
  if not shopId or shopId <= 0 then
    notify(actorSource, 'error', 'Ungültige Shop-ID.')
    return
  end

  local row = MySQL.single.await('SELECT id, shop_type, label FROM shops WHERE id = ? LIMIT 1', { shopId })
  if not row then
    notify(actorSource, 'error', 'Shop nicht gefunden.')
    return
  end

  local shopType = trim(tostring(row.shop_type or '')):lower()
  local label = trim(tostring(data.label or row.label or ''))
  local enabled = data.enabled ~= false
  local blipEnabled = data.blipEnabled ~= false
  local coords = type(data.coords) == 'table' and data.coords or nil
  local draft = SettingsDraft[actorSource] and SettingsDraft[actorSource].coords or nil
  local x = tonumber(coords and coords.x) or tonumber(draft and draft.x)
  local y = tonumber(coords and coords.y) or tonumber(draft and draft.y)
  local z = tonumber(coords and coords.z) or tonumber(draft and draft.z)
  local h = tonumber(coords and coords.h) or tonumber(draft and draft.h) or 0.0

  if not x or not y or not z then
    notify(actorSource, 'error', 'Koordinaten fehlen. Nutze zuerst "Aktuelle Position übernehmen".')
    return
  end

  if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 10000 then
    notify(actorSource, 'error', 'Koordinaten sind außerhalb des erlaubten Bereichs.')
    return
  end

  if label == '' then
    label = tostring(row.label or 'Shop')
  end
  if #label > 64 then
    label = label:sub(1, 64)
  end

  if shopType == 'clothing' then
    MySQL.query.await([[
      UPDATE shops
      SET pos_x = ?, pos_y = ?, pos_z = ?, heading = ?, enabled = ?
      WHERE id = ?
    ]], { x, y, z, h, enabled and 1 or 0, shopId })
  else
    MySQL.query.await([[
      UPDATE shops
      SET label = ?, pos_x = ?, pos_y = ?, pos_z = ?, heading = ?, enabled = ?, blip_enabled = ?
      WHERE id = ?
    ]], { label, x, y, z, h, enabled and 1 or 0, blipEnabled and 1 or 0, shopId })
  end

  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'settings.shop_update', nil, { shopId = shopId, shopType = shopType })
  triggerShopReload()
  notify(actorSource, 'success', ('Shop #%s wurde aktualisiert.'):format(shopId))
end

local function removeShopItemFromSettings(actorSource, data)
  if not ensurePermission(actorSource, 'settings.shops.manage') then
    return
  end

  data = type(data) == 'table' and data or {}
  local shopId = tonumber(data.shopId)
  local itemId = tonumber(data.itemId)
  if not shopId or shopId <= 0 or not itemId or itemId <= 0 then
    notify(actorSource, 'error', 'Ungültige Shop- oder Item-ID.')
    return
  end

  MySQL.update.await('DELETE FROM shop_items WHERE shop_id = ? AND item_id = ?', { shopId, itemId })
  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'settings.shop_item_remove', nil, { shopId = shopId, itemId = itemId })
  triggerShopReload()
  notify(actorSource, 'success', 'Shop-Item entfernt.')
end

local function addShopVehicleFromSettings(actorSource, data)
  if not ensurePermission(actorSource, 'settings.shops.manage') then
    return
  end

  data = type(data) == 'table' and data or {}
  local shopId = tonumber(data.shopId)
  local vehicleId = tonumber(data.vehicleId)
  local price = math.floor(tonumber(data.price) or -1)

  if not shopId or shopId <= 0 then
    notify(actorSource, 'error', 'Ungültige Shop-ID.')
    return
  end
  if not vehicleId or vehicleId <= 0 then
    notify(actorSource, 'error', 'Ungültige Fahrzeug-ID.')
    return
  end
  if price < 0 then
    notify(actorSource, 'error', 'Preis muss 0 oder größer sein.')
    return
  end

  local shop = MySQL.single.await('SELECT id, shop_type FROM shops WHERE id = ? LIMIT 1', { shopId })
  if not shop or tostring(shop.shop_type) ~= 'vehicle' then
    notify(actorSource, 'error', 'Shop ist kein Autohaus.')
    return
  end

  local vehicleExists = MySQL.scalar.await('SELECT id FROM vehicles WHERE id = ? LIMIT 1', { vehicleId })
  if not vehicleExists then
    notify(actorSource, 'error', 'Fahrzeug nicht gefunden.')
    return
  end

  MySQL.query.await([[
    INSERT INTO shop_vehicles (shop_id, vehicle_id, price, enabled)
    VALUES (?, ?, ?, 1)
    ON DUPLICATE KEY UPDATE
      price = VALUES(price),
      enabled = 1
  ]], { shopId, vehicleId, price })

  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'settings.shop_vehicle_upsert', nil, {
    shopId = shopId,
    vehicleId = vehicleId,
    price = price
  })

  notify(actorSource, 'success', 'Autohaus-Fahrzeug gespeichert.')
end

local function removeShopVehicleFromSettings(actorSource, data)
  if not ensurePermission(actorSource, 'settings.shops.manage') then
    return
  end

  data = type(data) == 'table' and data or {}
  local shopId = tonumber(data.shopId)
  local vehicleId = tonumber(data.vehicleId)
  if not shopId or shopId <= 0 or not vehicleId or vehicleId <= 0 then
    notify(actorSource, 'error', 'Ungültige Shop- oder Fahrzeug-ID.')
    return
  end

  MySQL.update.await('DELETE FROM shop_vehicles WHERE shop_id = ? AND vehicle_id = ?', { shopId, vehicleId })
  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'settings.shop_vehicle_remove', nil, { shopId = shopId, vehicleId = vehicleId })
  notify(actorSource, 'success', 'Autohaus-Fahrzeug entfernt.')
end

local function createBan(actorSource, targetSource, reason, durationHours, targetUserIdInput)
  if not ensurePermission(actorSource, 'players.ban') then
    return
  end

  targetSource = tonumber(targetSource)
  targetUserIdInput = tonumber(targetUserIdInput)
  reason = trim(reason)
  durationHours = tonumber(durationHours) or RPAdminConfig.defaultBanDurationHours

  local onlineTargetSource = nil
  if targetSource and targetSource > 0 and GetPlayerName(targetSource) then
    onlineTargetSource = targetSource
  elseif targetUserIdInput then
    local maybeOnlineSource = getSourceByUserId(targetUserIdInput)
    if maybeOnlineSource and GetPlayerName(maybeOnlineSource) then
      onlineTargetSource = maybeOnlineSource
    end
  end

  local targetUserId = nil
  local snapshot = nil

  if reason == '' then
    notify(actorSource, 'error', 'Grund ist erforderlich.')
    return
  end

  if #reason > RPAdminConfig.maxReasonLength then
    reason = reason:sub(1, RPAdminConfig.maxReasonLength)
  end

  durationHours = math.floor(math.max(0, math.min(durationHours, RPAdminConfig.maxBanDurationHours)))

  if onlineTargetSource then
    if not canAffectTargetByHierarchy(actorSource, onlineTargetSource, 'Du kannst keinen gleich hohen oder höheren Rang bannen.') then
      return
    end

    targetUserId = getUserIdFromSource(onlineTargetSource)
    if not targetUserId then
      notify(actorSource, 'error', 'Ziel-User nicht gefunden.')
      return
    end

    local ids = getIdentityMap(onlineTargetSource)
    snapshot = getPrimaryIdentifier(ids)
  else
    if not targetUserIdInput or targetUserIdInput <= 0 then
      notify(actorSource, 'error', 'Bitte einen gültigen Online- oder Offline-Spieler auswählen.')
      return
    end

    targetUserId = targetUserIdInput
    if not canAffectTargetUserByHierarchy(actorSource, targetUserId, 'Du kannst keinen gleich hohen oder höheren Rang bannen.') then
      return
    end

    local row = MySQL.single.await(
      'SELECT id, license, fivem_id, steam_id, discord_id FROM users WHERE id = ? LIMIT 1',
      { targetUserId }
    )
    if not row then
      notify(actorSource, 'error', 'Ziel-User nicht gefunden.')
      return
    end

    snapshot = row.license or row.fivem_id or row.steam_id or row.discord_id
  end

  if not targetUserId then
    notify(actorSource, 'error', 'Ziel-User nicht gefunden.')
    return
  end

  local actorUserId = getUserIdFromSource(actorSource)
  local expiresAt = nil

  if durationHours > 0 then
    expiresAt = os.date('!%Y-%m-%d %H:%M:%S', os.time() + (durationHours * 3600))
  end

  MySQL.insert.await([[
    INSERT INTO admin_bans (user_id, identifier_snapshot, reason, banned_by_user_id, expires_at, active)
    VALUES (?, ?, ?, ?, ?, 1)
  ]], { targetUserId, snapshot, reason, actorUserId, expiresAt })

  auditAction(actorUserId, 'players.ban', targetUserId, {
    reason = reason,
    durationHours = durationHours,
    expiresAt = expiresAt
  })

  if onlineTargetSource and GetPlayerName(onlineTargetSource) then
    DropPlayer(onlineTargetSource, ('Du wurdest gebannt: %s'):format(reason))
    notify(actorSource, 'success', 'Spieler wurde gebannt.')
  else
    notify(actorSource, 'success', 'Offline-Spieler wurde gebannt.')
  end
end

local function revokeBan(actorSource, banId)
  if not ensurePermission(actorSource, 'bans.manage') then
    return
  end

  banId = tonumber(banId)
  if not banId or banId <= 0 then
    notify(actorSource, 'error', 'Ungültige Bann-ID.')
    return
  end

  local actorUserId = getUserIdFromSource(actorSource)
  local changed = MySQL.update.await([[
    UPDATE admin_bans
    SET active = 0, revoked_by_user_id = ?, revoked_at = NOW()
    WHERE id = ? AND active = 1
  ]], { actorUserId, banId })

  if changed <= 0 then
    notify(actorSource, 'warning', 'Bann nicht gefunden oder bereits aufgehoben.')
    return
  end

  auditAction(actorUserId, 'bans.revoke', nil, { banId = banId })
  notify(actorSource, 'success', 'Bann wurde aufgehoben.')
end

local function kickPlayer(actorSource, targetSource, reason)
  if not ensurePermission(actorSource, 'players.kick') then
    return
  end

  targetSource = tonumber(targetSource)
  reason = trim(reason)

  if not targetSource or targetSource <= 0 or not GetPlayerName(targetSource) then
    notify(actorSource, 'error', 'Zielspieler nicht online.')
    return
  end

  if not canAffectTargetByHierarchy(actorSource, targetSource, 'Du kannst keinen gleich hohen oder höheren Rang kicken.') then
    return
  end

  if reason == '' then
    notify(actorSource, 'error', 'Beim Kick ist ein Grund erforderlich.')
    return
  end

  if #reason > RPAdminConfig.maxReasonLength then
    reason = reason:sub(1, RPAdminConfig.maxReasonLength)
  end

  local actorUserId = getUserIdFromSource(actorSource)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'players.kick', targetUserId, { reason = reason })

  DropPlayer(targetSource, ('Du wurdest gekickt: %s'):format(reason))
  notify(actorSource, 'success', 'Spieler wurde gekickt.')
end

local function notifyTicketTeam(createdBySource, title)
  local online = GetPlayers()
  local creatorName = exports.rp_core:GetCharacterName(createdBySource) or GetPlayerName(createdBySource) or ('Source %s'):format(createdBySource)
  local msg = ('Neues Ticket von %s: %s'):format(creatorName, title)

  for i = 1, #online do
    local src = tonumber(online[i])
    if src and hasPermission(src, 'tickets.view') then
      TriggerClientEvent('rp:notify', src, {
        type = 'info',
        title = 'Support',
        message = msg,
        duration = 6000,
        sound = 'ticket'
      })
    end
  end
end

refreshAdminPanels = function()
  local online = GetPlayers()
  for i = 1, #online do
    local src = tonumber(online[i])
    if src and PanelOpenMode[src] == 'admin' and hasPermission(src, 'admin.menu.open') then
      pushPanel(src, false)
    end
  end
end

local function createTicket(actorSource, title, description, allowPlayerPortal)
  if not allowPlayerPortal and not ensurePermission(actorSource, 'tickets.manage') then
    return nil
  end

  title = trim(title)
  description = trim(description)

  if description == '' then
    notify(actorSource, 'error', 'Bitte beschreibe dein Anliegen.')
    return
  end

  if title == '' then
    title = 'Support-Anfrage'
  end

  if #title > RPAdminConfig.maxTicketTitleLength then
    title = title:sub(1, RPAdminConfig.maxTicketTitleLength)
  end

  if #description > RPAdminConfig.maxTicketDescriptionLength then
    description = description:sub(1, RPAdminConfig.maxTicketDescriptionLength)
  end

  local userId = getUserIdFromSource(actorSource)
  local characterId = exports.rp_core:GetCharacterId(actorSource)
  if not userId then
    notify(actorSource, 'error', 'Dein Profil konnte nicht geladen werden.')
    return nil
  end

  local ticketId = MySQL.insert.await([[
    INSERT INTO admin_tickets (creator_user_id, creator_character_id, title, description, status)
    VALUES (?, ?, ?, ?, 'open')
  ]], { userId, characterId, title, description })

  MySQL.insert.await([[
    INSERT INTO admin_ticket_messages (ticket_id, author_user_id, message, is_internal)
    VALUES (?, ?, ?, 0)
  ]], { ticketId, userId, description })

  auditAction(userId, 'tickets.create', userId, { ticketId = ticketId, title = title })
  notify(actorSource, 'success', 'Ticket wurde erstellt. Das Team wurde informiert.')
  notifyTicketTeam(actorSource, title)
  refreshAdminPanels()
  return ticketId
end

local function pruneClosedTicketsForUser(userId)
  if not userId then
    return
  end

  MySQL.update.await([[
    DELETE FROM admin_tickets
    WHERE creator_user_id = ?
      AND status = 'closed'
      AND id NOT IN (
        SELECT id FROM (
          SELECT id
          FROM admin_tickets
          WHERE creator_user_id = ?
            AND status = 'closed'
          ORDER BY id DESC
          LIMIT 5
        ) keep_rows
      )
  ]], { userId, userId })
end

local function updateTicketStatus(actorSource, ticketId, status)
  if not ensurePermission(actorSource, 'tickets.manage') then
    return
  end

  ticketId = tonumber(ticketId)
  status = trim(status)
  if not ticketId or ticketId <= 0 then
    notify(actorSource, 'error', 'Ungültige Ticket-ID.')
    return
  end

  if status ~= 'open' and status ~= 'in_progress' and status ~= 'closed' then
    notify(actorSource, 'error', 'Ungültiger Ticketstatus.')
    return
  end

  local userId = getUserIdFromSource(actorSource)
  if status == 'closed' then
    local ticketRow = MySQL.single.await('SELECT creator_user_id FROM admin_tickets WHERE id = ? LIMIT 1', { ticketId })
    if not ticketRow then
      notify(actorSource, 'warning', 'Ticket nicht gefunden.')
      return
    end

    MySQL.update.await([[
      UPDATE admin_tickets
      SET status = 'closed',
          assigned_user_id = ?,
          closed_at = NOW()
      WHERE id = ?
    ]], { userId, ticketId })

    pruneClosedTicketsForUser(tonumber(ticketRow.creator_user_id))
    auditAction(userId, 'tickets.close', tonumber(ticketRow.creator_user_id), { ticketId = ticketId })
    notify(actorSource, 'success', 'Ticket wurde geschlossen.')
  else
    MySQL.update.await([[
      UPDATE admin_tickets
      SET status = ?,
          assigned_user_id = ?,
          closed_at = NULL
      WHERE id = ?
    ]], { status, userId, ticketId })

    auditAction(userId, 'tickets.update_status', nil, { ticketId = ticketId, status = status })
    notify(actorSource, 'success', 'Ticketstatus wurde aktualisiert.')
  end

  refreshAdminPanels()
end

local function claimTicket(actorSource, ticketId)
  if not ensurePermission(actorSource, 'tickets.manage') then
    return
  end

  ticketId = tonumber(ticketId)
  if not ticketId or ticketId <= 0 then
    notify(actorSource, 'error', 'Ungültige Ticket-ID.')
    return
  end

  local actorUserId = getUserIdFromSource(actorSource)
  local changed = MySQL.update.await([[
    UPDATE admin_tickets
    SET assigned_user_id = ?, status = 'in_progress'
    WHERE id = ?
  ]], { actorUserId, ticketId })

  if changed <= 0 then
    notify(actorSource, 'error', 'Ticket konnte nicht beansprucht werden.')
    return
  end

  auditAction(actorUserId, 'tickets.claim', nil, { ticketId = ticketId })
  notify(actorSource, 'success', 'Ticket wurde dir zugewiesen.')
  refreshAdminPanels()
end

local function getTicket(ticketId)
  return MySQL.single.await([[
    SELECT id, creator_user_id, title, status
    FROM admin_tickets
    WHERE id = ?
    LIMIT 1
  ]], { ticketId })
end

local function ticketActionTarget(actorSource, ticketId)
  ticketId = tonumber(ticketId)
  if not ticketId or ticketId <= 0 then
    notify(actorSource, 'error', 'Ungültige Ticket-ID.')
    return nil
  end

  local ticket = getTicket(ticketId)
  if not ticket then
    notify(actorSource, 'error', 'Ticket nicht gefunden.')
    return nil
  end

  local targetSource = getSourceByUserId(ticket.creator_user_id)
  if not targetSource then
    notify(actorSource, 'warning', 'Ticket-Ersteller ist aktuell offline.')
    return nil
  end

  return ticket, targetSource
end

local function getTargetSourceFromCommandArg(actorSource, inputId, usageLabel, allowSelfDefault)
  local rawInput = trim(tostring(inputId or ''))
  if rawInput == '' and allowSelfDefault then
    return actorSource
  end

  local targetSource = tonumber(rawInput)
  if not targetSource or targetSource <= 0 then
    notify(actorSource, 'error', ('Nutzung: %s [id]'):format(usageLabel))
    return nil
  end

  if not GetPlayerName(targetSource) then
    notify(actorSource, 'error', 'Spieler mit dieser ID ist nicht online.')
    return nil
  end

  return targetSource
end

local function getProfileNameBySource(src)
  if not src or src <= 0 then
    return 'Unbekannt'
  end

  local profileName = GetPlayerName(src)
  if profileName and profileName ~= '' then
    return profileName
  end

  local characterName = exports.rp_core:GetCharacterName(src)
  if characterName and characterName ~= '' then
    return characterName
  end

  return ('ID %s'):format(src)
end

local function getPlayerSexBySource(src)
  if not src or src <= 0 then
    return 'm'
  end

  local state = exports.rp_core:GetPlayerState(src)
  local characterId = state and tonumber(state.characterId) or nil
  if not characterId then
    return 'm'
  end

  local identity = MySQL.single.await('SELECT sex FROM character_identity WHERE character_id = ? LIMIT 1', { characterId })
  if not identity or trim(identity.sex or '') == '' then
    return 'm'
  end

  local sex = trim(identity.sex):lower()
  return sex == 'f' and 'f' or 'm'
end

local function getPlayerStoredSkinBySource(src)
  if not src or src <= 0 then
    return nil
  end

  local state = exports.rp_core:GetPlayerState(src)
  local characterId = state and tonumber(state.characterId) or nil
  if not characterId then
    return nil
  end

  local row = MySQL.single.await('SELECT model, skin_json FROM character_skin WHERE character_id = ? LIMIT 1', { characterId })
  if not row then
    return nil
  end

  local decoded = {}
  local ok, parsed = pcall(json.decode, tostring(row.skin_json or '{}'))
  if ok and type(parsed) == 'table' then
    decoded = parsed
  end

  local components = {}
  local props = {}
  local overlays = {}

  if type(decoded.components) == 'table' then
    components = decoded.components
  end
  if type(decoded.props) == 'table' then
    props = decoded.props
  end
  if type(decoded.overlays) == 'table' then
    overlays = decoded.overlays
  end

  return {
    model = tostring(row.model or ''),
    components = components,
    props = props,
    overlays = overlays
  }
end

local function buildNoclipPlayerMap()
  local out = {}
  local players = GetPlayers()

  for i = 1, #players do
    local src = tonumber(players[i])
    if src and src > 0 and GetPlayerName(src) then
      out[tostring(src)] = {
        source = src,
        userId = getUserIdFromSource(src),
        profileName = getProfileNameBySource(src)
      }
    end
  end

  return out
end

local function sendHealReviveNotifications(actorSource, targetSource, isRevive)
  local actorName = getProfileNameBySource(actorSource)
  local targetName = getProfileNameBySource(targetSource)
  local actionWord = isRevive and 'revived' or 'geheilt'
  local actorMessage = ('Du hast den Spieler: %s mit der ID: %s %s.'):format(targetName, targetSource, actionWord)
  local targetMessage = ('Du wurdest von %s %s.'):format(actorName, actionWord)

  notify(actorSource, 'success', actorMessage)

  if actorSource == targetSource then
    SetTimeout(120, function()
      if GetPlayerName(targetSource) then
        notify(targetSource, 'info', targetMessage)
      end
    end)
    return
  end

  notify(targetSource, 'info', targetMessage)
end

local function sendRepairNotifications(actorSource, targetSource)
  local actorName = getProfileNameBySource(actorSource)
  local targetName = getProfileNameBySource(targetSource)

  if actorSource == targetSource then
    notify(actorSource, 'success', 'Du hast dein Fahrzeug repariert.')
    SetTimeout(120, function()
      if GetPlayerName(targetSource) then
        notify(targetSource, 'info', ('Dein Fahrzeug wurde von %s repariert.'):format(actorName))
      end
    end)
    return
  end

  notify(actorSource, 'success', ('Du hast das Fahrzeug von Spieler: %s mit der ID: %s repariert.'):format(targetName, targetSource))
  notify(targetSource, 'info', ('Dein Fahrzeug wurde von %s repariert.'):format(actorName))
end

local function sendReloadNotifications(actorSource, targetSource)
  local actorName = getProfileNameBySource(actorSource)
  local targetName = getProfileNameBySource(targetSource)

  if actorSource == targetSource then
    notify(actorSource, 'success', 'Deine Waffen wurden vollständig nachgeladen.')
    SetTimeout(120, function()
      if GetPlayerName(targetSource) then
        notify(targetSource, 'info', ('Deine Waffen wurden von %s nachgeladen.'):format(actorName))
      end
    end)
    return
  end

  notify(actorSource, 'success', ('Du hast die Waffen von Spieler: %s mit der ID: %s vollständig nachgeladen.'):format(targetName, targetSource))
  notify(targetSource, 'info', ('Deine Waffen wurden von %s vollständig nachgeladen.'):format(actorName))
end

local function parseDeleteRadius(input)
  local raw = trim(tostring(input or ''))
  if raw == '' then
    return 2.0, nil
  end

  local radius = tonumber(raw)
  if not radius then
    return nil, 'Ungültiger Umkreis. Beispiel: /delete 5'
  end

  if radius <= 0 then
    return nil, 'Der Umkreis muss größer als 0 sein.'
  end

  if radius > 50.0 then
    return nil, 'Der maximale Umkreis ist 50 Meter.'
  end

  return radius, nil
end

local function parseMoneyAccountType(rawValue)
  local value = trim(tostring(rawValue or '')):lower()
  if value == 'bar' or value == 'cash' then
    return 'cash', 'Bargeld'
  end
  if value == 'bank' then
    return 'bank', 'Bank'
  end

  return nil, nil
end

local function parsePositiveInteger(rawValue)
  local value = math.floor(tonumber(rawValue) or -1)
  if value <= 0 then
    return nil
  end
  return value
end

local function parseNonNegativeInteger(rawValue)
  local value = math.floor(tonumber(rawValue) or -1)
  if value < 0 then
    return nil
  end
  return value
end

local function normalizeWeaponName(value)
  local weaponName = trim(tostring(value or '')):upper()
  if weaponName == '' then
    return ''
  end

  weaponName = weaponName:gsub('%s+', '_')
  if weaponName:sub(1, 7) ~= 'WEAPON_' then
    weaponName = 'WEAPON_' .. weaponName
  end

  if not weaponName:match('^WEAPON_[A-Z0-9_]+$') then
    return ''
  end

  return weaponName
end

local function parseTeleportCoordinates(args)
  if type(args) ~= 'table' then
    return nil, nil, nil, 'Nutzung: /tp x, y, z'
  end

  local raw = trim(table.concat(args, ' '))
  if raw == '' then
    return nil, nil, nil, 'Nutzung: /tp x, y, z'
  end

  local normalized = raw:gsub('%s*,%s*', ','):gsub('%s+', ' ')
  local x, y, z

  if normalized:find(',', 1, true) then
    local parts = {}
    for token in normalized:gmatch('[^,]+') do
      parts[#parts + 1] = trim(token)
    end

    if #parts ~= 3 then
      return nil, nil, nil, 'Ungültige Koordinaten. Beispiel: /tp 215.5, -810.2, 30.7'
    end

    x = tonumber(parts[1])
    y = tonumber(parts[2])
    z = tonumber(parts[3])
  else
    local parts = {}
    for token in normalized:gmatch('%S+') do
      parts[#parts + 1] = token
    end

    if #parts ~= 3 then
      return nil, nil, nil, 'Ungültige Koordinaten. Beispiel: /tp 215.5 -810.2 30.7'
    end

    x = tonumber(parts[1])
    y = tonumber(parts[2])
    z = tonumber(parts[3])
  end

  if not x or not y or not z then
    return nil, nil, nil, 'Ungültige Koordinaten. Beispiel: /tp 215.5, -810.2, 30.7'
  end

  return x, y, z, nil
end

local function ticketTeleport(actorSource, ticketId)
  if not ensurePermission(actorSource, 'tickets.manage') then
    return
  end

  local ticket, targetSource = ticketActionTarget(actorSource, ticketId)
  if not ticket then
    return
  end

  local targetPed = GetPlayerPed(targetSource)
  if not targetPed or targetPed == 0 then
    notify(actorSource, 'error', 'Spielerped nicht verfügbar.')
    return
  end

  local coords = GetEntityCoords(targetPed)
  local heading = GetEntityHeading(targetPed)
  TriggerClientEvent('rp:admin:teleport', actorSource, {
    x = coords.x,
    y = coords.y,
    z = coords.z + 0.75,
    h = heading
  })

  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'tickets.tp', ticket.creator_user_id, { ticketId = ticket.id, targetSource = targetSource })
  notify(actorSource, 'success', 'Teleport zum Ticket-Spieler ausgeführt.')
end

local function ticketHeal(actorSource, ticketId)
  if not ensurePermission(actorSource, 'tickets.manage') then
    return
  end

  local ticket, targetSource = ticketActionTarget(actorSource, ticketId)
  if not ticket then
    return
  end

  TriggerClientEvent('rp:admin:healPlayer', targetSource)
  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'tickets.heal', ticket.creator_user_id, { ticketId = ticket.id, targetSource = targetSource })
  sendHealReviveNotifications(actorSource, targetSource, false)
end

local function ticketRevive(actorSource, ticketId)
  if not ensurePermission(actorSource, 'tickets.manage') then
    return
  end

  local ticket, targetSource = ticketActionTarget(actorSource, ticketId)
  if not ticket then
    return
  end

  TriggerClientEvent('rp:admin:revivePlayer', targetSource)
  local actorUserId = getUserIdFromSource(actorSource)
  auditAction(actorUserId, 'tickets.revive', ticket.creator_user_id, { ticketId = ticket.id, targetSource = targetSource })
  sendHealReviveNotifications(actorSource, targetSource, true)
end

local function handleTicketPortalAction(source, payload)
  if not canDo(source, 'ticket_portal_action', 350) then
    return
  end

  local action = trim(payload.action)
  local data = type(payload.data) == 'table' and payload.data or {}

  if action == 'ticket.refresh' then
    pushTicketPanel(source, false)
    return
  end

  if action == 'ticket.create' then
    createTicket(source, data.title, data.description, true)
    pushTicketPanel(source, false)
    return
  end
end

local function handleNuiAction(source, payload)
  if trim(payload.mode) == 'ticket' then
    handleTicketPortalAction(source, payload)
    return
  end

  if not ensurePermission(source, 'admin.menu.open') then
    PanelOpenMode[source] = nil
    TriggerClientEvent('rp:admin:forceClose', source)
    return
  end

  if not canDo(source, 'admin_action', 250) then
    return
  end

  local action = trim(payload.action)
  local data = type(payload.data) == 'table' and payload.data or {}

  if action == 'refresh' then
    pushPanel(source, false)
    return
  end

  if action == 'players.search' then
    if not ensurePermission(source, 'players.view') then
      return
    end

    SearchFilter[source] = trim(data.query)
    pushPanel(source, false)
    return
  end

  if action == 'players.mode' then
    if not ensurePermission(source, 'players.view') then
      return
    end

    PlayerListMode[source] = normalizePlayerListMode(data.mode)
    pushPanel(source, false)
    return
  end

  if action == 'players.kick' then
    kickPlayer(source, data.targetSource, data.reason)
    pushPanel(source, false)
    return
  end

  if action == 'players.ban' then
    createBan(source, data.targetSource, data.reason, data.durationHours, data.targetUserId)
    pushPanel(source, false)
    return
  end

  if action == 'bans.revoke' then
    revokeBan(source, data.banId)
    pushPanel(source, false)
    return
  end

  if action == 'tickets.create' then
    notify(source, 'warning', 'Ticket-Erstellung im Adminpanel ist deaktiviert.')
    return
  end

  if action == 'tickets.status' then
    updateTicketStatus(source, data.ticketId, data.status)
    pushPanel(source, false)
    return
  end

  if action == 'tickets.claim' then
    claimTicket(source, data.ticketId)
    pushPanel(source, false)
    return
  end

  if action == 'tickets.tp' then
    ticketTeleport(source, data.ticketId)
    return
  end

  if action == 'tickets.heal' then
    ticketHeal(source, data.ticketId)
    return
  end

  if action == 'tickets.revive' then
    ticketRevive(source, data.ticketId)
    return
  end

  if action == 'rights.assignRole' then
    setRoleForUser(source, data.targetUserId, data.roleName)
    pushPanel(source, false)
    return
  end

  if action == 'rights.createRole' then
    createRole(source, data.label, data.insertAfterRoleName)
    pushPanel(source, false)
    return
  end

  if action == 'rights.deleteRole' then
    deleteRole(source, data.roleName)
    pushPanel(source, false)
    return
  end

  if action == 'rights.setCarRoles' then
    setCarRolePermissions(source, data.roleNames)
    pushPanel(source, false)
    return
  end

  if action == 'rights.setRolePermissions' then
    setRolePermissions(source, data.roleName, data.permissionKeys)
    pushPanel(source, false)
    return
  end

  if action == 'rights.setRoleDutyOutfit' then
    setRoleDutyOutfit(source, data.roleName, data.values)
    pushPanel(source, false)
    return
  end

  if action == 'scripts.restart' then
    restartResourceByName(source, data.resourceName)
    pushPanel(source, false)
    return
  end

  if action == 'settings.shops.useCurrentCoords' then
    setShopDraftCoordsFromPlayer(source)
    pushPanel(source, false)
    return
  end

  if action == 'settings.shops.create' then
    createShopFromSettings(source, data)
    pushPanel(source, false)
    return
  end

  if action == 'settings.shops.update' then
    updateShopFromSettings(source, data)
    pushPanel(source, false)
    return
  end

  if action == 'settings.shops.addItem' then
    addShopItemFromSettings(source, data)
    pushPanel(source, false)
    return
  end

  if action == 'settings.shops.removeItem' then
    removeShopItemFromSettings(source, data)
    pushPanel(source, false)
    return
  end

  if action == 'settings.shops.addVehicle' then
    addShopVehicleFromSettings(source, data)
    pushPanel(source, false)
    return
  end

  if action == 'settings.shops.removeVehicle' then
    removeShopVehicleFromSettings(source, data)
    pushPanel(source, false)
    return
  end
end

RegisterNetEvent('rp:admin:openRequested', function()
  local src = source
  refreshRoleCacheBySource(src)
  pushCommandSuggestions(src)

  if not hasPermission(src, 'admin.menu.open') then
    local userId = getUserIdFromSource(src)
    if bootstrapFirstProjectLead(userId) then
      notify(src, 'info', 'Erste Projektleitung wurde automatisch für diesen Account gesetzt.')
    end
  end

  if not ensurePermission(src, 'admin.menu.open') then
    return
  end

  PanelOpenMode[src] = 'admin'
  pushPanel(src, true)
end)

RegisterNetEvent('rp:admin:openTicketRequested', function()
  local src = source
  if not canDo(src, 'open_ticket_panel', 350) then
    return
  end

  pushCommandSuggestions(src)
  PanelOpenMode[src] = 'ticket'
  pushTicketPanel(src, true)
end)

RegisterNetEvent('rp:admin:panelState', function(payload)
  local src = source
  if not src or src <= 0 then
    return
  end

  if type(payload) ~= 'table' then
    return
  end

  if payload.open ~= true then
    PanelOpenMode[src] = nil
    return
  end

  local mode = trim(payload.mode)
  if mode ~= 'ticket' then
    mode = 'admin'
  end

  PanelOpenMode[src] = mode
end)

RegisterNetEvent('rp:admin:requestCommandSuggestions', function()
  local src = source
  pushCommandSuggestions(src)
end)

RegisterCommand(RPAdminConfig.command, function(source)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s im Spiel.'):format(RPAdminConfig.command))
    return
  end

  refreshRoleCacheBySource(source)
  pushCommandSuggestions(source)

  if not hasPermission(source, 'admin.menu.open') then
    local userId = getUserIdFromSource(source)
    if bootstrapFirstProjectLead(userId) then
      notify(source, 'info', 'Erste Projektleitung wurde automatisch für diesen Account gesetzt.')
    end
  end

  if not ensurePermission(source, 'admin.menu.open') then
    return
  end

  PanelOpenMode[source] = 'admin'
  pushPanel(source, true)
end, false)

RegisterCommand(RPAdminConfig.ticketCommand or 'ticket', function(source)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s im Spiel.'):format(RPAdminConfig.ticketCommand or 'ticket'))
    return
  end

  pushCommandSuggestions(source)
  PanelOpenMode[source] = 'ticket'
  pushTicketPanel(source, true)
end, false)

RegisterCommand(INFO_COMMAND_NAME, function(source)
  if source <= 0 then
    print('[rp_admin] Nutze den Befehl /i im Spiel.')
    return
  end

  local _, commandNames = getAllowedCommandSuggestions(source)
  local listText = table.concat(commandNames, ', ')
  if listText == '' then
    listText = 'Keine'
  end

  TriggerClientEvent('chat:addMessage', source, {
    color = { 80, 195, 255 },
    multiline = true,
    args = { 'Info', ('Verfügbare Befehle: %s'):format(listText) }
  })
end, false)

RegisterCommand('info', function(source)
  if source <= 0 then
    print('[rp_admin] Nutze den Befehl /info im Spiel.')
    return
  end

  local _, commandNames = getAllowedCommandSuggestions(source)
  local listText = table.concat(commandNames, ', ')
  if listText == '' then
    listText = 'Keine'
  end

  TriggerClientEvent('chat:addMessage', source, {
    color = { 80, 195, 255 },
    multiline = true,
    args = { 'Info', ('Verfügbare Befehle: %s'):format(listText) }
  })
end, false)

RegisterCommand(ID_COMMAND_NAME, function(source)
  if source <= 0 then
    print('[rp_admin] Nutze den Befehl /id im Spiel.')
    return
  end

  local userId = getUserIdFromSource(source)
  local uniqueId = userId and tostring(userId) or 'Nicht verfügbar'

  TriggerClientEvent('chat:addMessage', source, {
    color = { 80, 195, 255 },
    multiline = true,
    args = { 'Info', ('Server-ID: %s | Eindeutige Spieler-ID: %s'):format(tostring(source), uniqueId) }
  })
end, false)

RegisterCommand(RANK_COMMAND_NAME, function(source)
  if source <= 0 then
    print('[rp_admin] Nutze den Befehl /rang im Spiel.')
    return
  end

  local userId = getUserIdFromSource(source)
  local roleData = userId and getRoleDataByUserId(userId) or nil
  local rankLabel = (roleData and trim(roleData.roleLabel or '') ~= '') and roleData.roleLabel or 'Spieler'

  TriggerClientEvent('chat:addMessage', source, {
    color = { 80, 195, 255 },
    multiline = true,
    args = { 'Info', ('Dein aktueller Rang: %s'):format(rankLabel) }
  })
end, false)

local function handleDeleteCommand(source, args, commandName)
  commandName = trim(commandName or '')
  if commandName == '' then
    commandName = RPAdminConfig.deleteCommand or 'delete'
  end

  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s [umkreis] im Spiel.'):format(commandName))
    return
  end

  if not ensurePermission(source, VEHICLE_DELETE_PERMISSION_KEY) then
    return
  end

  if not canDo(source, 'vehicle.delete.command', 900) then
    return
  end

  local radius, radiusError = parseDeleteRadius(args and args[1])
  if not radius then
    notify(source, 'error', radiusError or 'Ungültiger Umkreis.')
    return
  end

  PendingDeleteRequests[source] = {
    radius = radius,
    expiresAt = nowMs() + 7000
  }

  TriggerClientEvent('rp:admin:deleteVehiclesInRadius', source, { radius = radius })
end

local function handleGiveMoneyCommand(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s <id> <bar|bank> <menge> im Spiel.'):format(RPAdminConfig.giveMoneyCommand or 'givemoney'))
    return
  end

  if not ensurePermission(source, GIVE_MONEY_PERMISSION_KEY) then
    return
  end

  if not canDo(source, 'command.givemoney', 450) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.giveMoneyCommand or 'givemoney'), false)
  if not targetSource then
    return
  end

  if not canAffectTargetByHierarchy(source, targetSource, 'Du kannst keinem gleich hohen oder höheren Rang Geld geben.') then
    return
  end

  local accountType, accountLabel = parseMoneyAccountType(args and args[2])
  if not accountType then
    notify(source, 'error', ('Nutzung: /%s <id> <bar|bank> <menge>'):format(RPAdminConfig.giveMoneyCommand or 'givemoney'))
    return
  end

  local amount = parsePositiveInteger(args and args[3])
  if not amount then
    notify(source, 'error', 'Ungültige Menge. Bitte gib eine Zahl > 0 an.')
    return
  end

  local success, reason
  if accountType == 'cash' then
    success, reason = exports.rp_money:AddCash(targetSource, amount)
  else
    success, reason = exports.rp_money:AddBank(targetSource, amount, 'admin', 'admin_givemoney')
  end

  if not success then
    notify(source, 'error', reason or 'Geld konnte nicht hinzugefügt werden.')
    return
  end

  local actorUserId = getUserIdFromSource(source)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.givemoney', targetUserId, {
    targetSource = targetSource,
    accountType = accountType,
    amount = amount
  })

  notify(source, 'success', ('%s$ %s wurden an %s (ID %s) gegeben.'):format(amount, accountLabel, getProfileNameBySource(targetSource), targetSource))
  notify(targetSource, 'info', ('Du hast %s$ %s erhalten.'):format(amount, accountLabel))
end

local function handleSetMoneyCommand(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s <id> <bar|bank> <stand> im Spiel.'):format(RPAdminConfig.setMoneyCommand or 'setmoney'))
    return
  end

  if not ensurePermission(source, SET_MONEY_PERMISSION_KEY) then
    return
  end

  if not canDo(source, 'command.setmoney', 450) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.setMoneyCommand or 'setmoney'), false)
  if not targetSource then
    return
  end

  if not canAffectTargetByHierarchy(source, targetSource, 'Du kannst den Kontostand von gleich hohen oder höheren Rängen nicht ändern.') then
    return
  end

  local accountType, accountLabel = parseMoneyAccountType(args and args[2])
  if not accountType then
    notify(source, 'error', ('Nutzung: /%s <id> <bar|bank> <stand>'):format(RPAdminConfig.setMoneyCommand or 'setmoney'))
    return
  end

  local targetValue = parseNonNegativeInteger(args and args[3])
  if targetValue == nil then
    notify(source, 'error', 'Ungültiger Kontostand. Bitte gib eine Zahl >= 0 an.')
    return
  end

  local currentValue = 0
  if accountType == 'cash' then
    currentValue = math.floor(tonumber(exports.rp_money:GetCash(targetSource)) or 0)
  else
    currentValue = math.floor(tonumber(exports.rp_money:GetBank(targetSource)) or 0)
  end

  local delta = targetValue - currentValue
  if delta ~= 0 then
    local success, reason
    if delta > 0 then
      if accountType == 'cash' then
        success, reason = exports.rp_money:AddCash(targetSource, delta)
      else
        success, reason = exports.rp_money:AddBank(targetSource, delta, 'admin', 'admin_setmoney_plus')
      end
    else
      local removeAmount = math.abs(delta)
      if accountType == 'cash' then
        success, reason = exports.rp_money:RemoveCash(targetSource, removeAmount)
      else
        success, reason = exports.rp_money:RemoveBank(targetSource, removeAmount, 'admin', 'admin_setmoney_minus')
      end
    end

    if not success then
      notify(source, 'error', reason or 'Kontostand konnte nicht gesetzt werden.')
      return
    end
  end

  local actorUserId = getUserIdFromSource(source)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.setmoney', targetUserId, {
    targetSource = targetSource,
    accountType = accountType,
    oldValue = currentValue,
    newValue = targetValue
  })

  notify(source, 'success', ('%s von %s (ID %s) wurde auf %s$ gesetzt.'):format(accountLabel, getProfileNameBySource(targetSource), targetSource, targetValue))
  notify(targetSource, 'info', ('Dein %s wurde auf %s$ gesetzt.'):format(accountLabel, targetValue))
end

local function handleGiveItemCommand(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s <id> <item> <anzahl> im Spiel.'):format(RPAdminConfig.giveItemCommand or 'giveitem'))
    return
  end

  if not ensurePermission(source, GIVE_ITEM_PERMISSION_KEY) then
    return
  end

  if not canDo(source, 'command.giveitem', 450) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.giveItemCommand or 'giveitem'), false)
  if not targetSource then
    return
  end

  if not canAffectTargetByHierarchy(source, targetSource, 'Du kannst gleich hohen oder höheren Rängen keine Items geben.') then
    return
  end

  local itemName = trim(tostring(args and args[2] or '')):lower()
  if itemName == '' then
    notify(source, 'error', ('Nutzung: /%s <id> <item> <anzahl>'):format(RPAdminConfig.giveItemCommand or 'giveitem'))
    return
  end

  local amount = parsePositiveInteger(args and args[3])
  if not amount then
    notify(source, 'error', 'Ungültige Menge. Bitte gib eine Zahl > 0 an.')
    return
  end

  local success, reason = exports.rp_inventory:AddItem(targetSource, itemName, amount)
  if not success then
    notify(source, 'error', reason or 'Item konnte nicht vergeben werden.')
    return
  end

  local actorUserId = getUserIdFromSource(source)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.giveitem', targetUserId, {
    targetSource = targetSource,
    itemName = itemName,
    amount = amount
  })

  notify(source, 'success', ('%sx %s wurde an %s (ID %s) gegeben.'):format(amount, itemName, getProfileNameBySource(targetSource), targetSource))
  notify(targetSource, 'info', ('Du hast %sx %s erhalten.'):format(amount, itemName))
end

local function handleSetJobCommand(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s <id> <job> <rang> im Spiel.'):format(RPAdminConfig.setJobCommand or 'setjob'))
    return
  end

  if not ensurePermission(source, SET_JOB_PERMISSION_KEY) then
    return
  end

  if not canDo(source, 'command.setjob', 450) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.setJobCommand or 'setjob'), false)
  if not targetSource then
    return
  end

  if not canAffectTargetByHierarchy(source, targetSource, 'Du kannst den Job von gleich hohen oder höheren Rängen nicht ändern.') then
    return
  end

  local jobName = trim(tostring(args and args[2] or '')):lower()
  if jobName == '' then
    notify(source, 'error', ('Nutzung: /%s <id> <job> <rang>'):format(RPAdminConfig.setJobCommand or 'setjob'))
    return
  end

  local grade = parseNonNegativeInteger(args and args[3])
  if grade == nil then
    notify(source, 'error', 'Ungültiger Jobrang. Bitte gib eine Zahl >= 0 an.')
    return
  end

  local success, reason, payload = exports.rp_jobs:SetJob(targetSource, jobName, grade)
  if not success then
    notify(source, 'error', reason or 'Job konnte nicht gesetzt werden.')
    return
  end

  local actorUserId = getUserIdFromSource(source)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.setjob', targetUserId, {
    targetSource = targetSource,
    jobName = payload and payload.jobName or jobName,
    grade = payload and payload.grade or grade
  })

  local resolvedLabel = (payload and payload.label) or jobName
  local resolvedGrade = (payload and payload.grade) or grade
  notify(source, 'success', ('Job von %s (ID %s) wurde auf %s (Rang %s) gesetzt.'):format(getProfileNameBySource(targetSource), targetSource, resolvedLabel, resolvedGrade))
  notify(targetSource, 'info', ('Dein Job wurde auf %s (Rang %s) gesetzt.'):format(resolvedLabel, resolvedGrade))
end

local function handleGiveWeaponCommand(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s <id> <modell> im Spiel.'):format(RPAdminConfig.giveWeaponCommand or 'giveweapon'))
    return
  end

  if not ensurePermission(source, GIVE_WEAPON_PERMISSION_KEY) then
    return
  end

  if not canDo(source, 'command.giveweapon', 450) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.giveWeaponCommand or 'giveweapon'), false)
  if not targetSource then
    return
  end

  if not canAffectTargetByHierarchy(source, targetSource, 'Du kannst gleich hohen oder höheren Rängen keine Waffen geben.') then
    return
  end

  local weaponName = normalizeWeaponName(args and args[2])
  if weaponName == '' then
    notify(source, 'error', ('Nutzung: /%s <id> <modell>'):format(RPAdminConfig.giveWeaponCommand or 'giveweapon'))
    return
  end

  PendingGiveWeaponRequests[targetSource] = {
    actorSource = source,
    weaponName = weaponName,
    expiresAt = nowMs() + 7000
  }

  TriggerClientEvent('rp:admin:giveWeapon', targetSource, {
    weaponName = weaponName
  })
end

RegisterCommand(RPAdminConfig.carCommand or 'car', function(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s <modell> im Spiel.'):format(RPAdminConfig.carCommand or 'car'))
    return
  end

  if not ensurePermission(source, CAR_PERMISSION_KEY) then
    return
  end

  if not canDo(source, 'car.spawn.command', 1200) then
    return
  end

  local modelName = trim((args and args[1]) or '')
  if modelName == '' then
    notify(source, 'error', ('Nutzung: /%s <fahrzeugmodell>'):format(RPAdminConfig.carCommand or 'car'))
    return
  end

  if not modelName:match('^[%w_%-]+$') then
    notify(source, 'error', 'Ungültiger Fahrzeugname.')
    return
  end

  TriggerClientEvent('rp:admin:spawnCar', source, modelName)
end, false)

RegisterCommand(RPAdminConfig.deleteCommand or 'delete', function(source, args)
  handleDeleteCommand(source, args, RPAdminConfig.deleteCommand or 'delete')
end, false)

RegisterCommand('dv', function(source, args)
  handleDeleteCommand(source, args, 'dv')
end, false)

RegisterCommand(RPAdminConfig.giveMoneyCommand or 'givemoney', function(source, args)
  handleGiveMoneyCommand(source, args)
end, false)

RegisterCommand(RPAdminConfig.setMoneyCommand or 'setmoney', function(source, args)
  handleSetMoneyCommand(source, args)
end, false)

RegisterCommand(RPAdminConfig.giveItemCommand or 'giveitem', function(source, args)
  handleGiveItemCommand(source, args)
end, false)

RegisterCommand(RPAdminConfig.setJobCommand or 'setjob', function(source, args)
  handleSetJobCommand(source, args)
end, false)

RegisterCommand(RPAdminConfig.giveWeaponCommand or 'giveweapon', function(source, args)
  handleGiveWeaponCommand(source, args)
end, false)

RegisterNetEvent('rp:admin:carSpawnResult', function(payload)
  local src = source
  if type(payload) ~= 'table' then
    return
  end

  if not hasPermission(src, CAR_PERMISSION_KEY) then
    return
  end

  local ok = payload.ok == true
  local message = trim(payload.message or '')
  if message == '' then
    message = ok and 'Fahrzeug wurde gespawnt.' or 'Fahrzeug konnte nicht gespawnt werden.'
  end

  notify(src, ok and 'success' or 'error', message)
end)

RegisterNetEvent('rp:admin:giveWeaponResult', function(payload)
  local targetSource = source
  local pending = PendingGiveWeaponRequests[targetSource]
  PendingGiveWeaponRequests[targetSource] = nil

  if not pending or pending.expiresAt < nowMs() then
    return
  end

  local actorSource = tonumber(pending.actorSource) or 0
  if actorSource <= 0 or not GetPlayerName(actorSource) then
    return
  end

  if not hasPermission(actorSource, GIVE_WEAPON_PERMISSION_KEY) then
    return
  end

  local ok = type(payload) == 'table' and payload.ok == true
  if not ok then
    local failMessage = 'Waffe konnte nicht vergeben werden.'
    if type(payload) == 'table' then
      local custom = trim(tostring(payload.message or ''))
      if custom ~= '' then
        failMessage = custom
      end
    end
    notify(actorSource, 'error', failMessage)
    return
  end

  local weaponName = pending.weaponName or 'WEAPON_UNARMED'
  local actorUserId = getUserIdFromSource(actorSource)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.giveweapon', targetUserId, {
    targetSource = targetSource,
    weaponName = weaponName
  })

  notify(actorSource, 'success', ('Waffe %s wurde an %s (ID %s) vergeben.'):format(weaponName, getProfileNameBySource(targetSource), targetSource))
  notify(targetSource, 'info', ('Du hast die Waffe %s erhalten.'):format(weaponName))
end)

RegisterNetEvent('rp:admin:deleteVehiclesResult', function(payload)
  local src = source
  local pending = PendingDeleteRequests[src]
  PendingDeleteRequests[src] = nil

  if not pending or pending.expiresAt < nowMs() then
    return
  end

  if not hasPermission(src, VEHICLE_DELETE_PERMISSION_KEY) then
    return
  end

  if type(payload) ~= 'table' then
    notify(src, 'error', 'Fahrzeuglöschung fehlgeschlagen (ungültige Antwort).')
    return
  end

  local deleted = math.max(0, math.floor(tonumber(payload.deleted) or 0))
  local skipped = math.max(0, math.floor(tonumber(payload.skipped) or 0))
  local radius = tonumber(payload.radius) or tonumber(pending.radius) or 2.0

  if deleted > 0 then
    notify(src, 'success', ('%s Fahrzeug(e) im Umkreis von %.1fm gelöscht.'):format(deleted, radius))
  elseif skipped > 0 then
    notify(src, 'warning', ('Keine Fahrzeuge gelöscht. %s Fahrzeug(e) waren belegt oder ohne Kontrolle.'):format(skipped))
  else
    notify(src, 'info', ('Keine Fahrzeuge im Umkreis von %.1fm gefunden.'):format(radius))
  end

  local actorUserId = getUserIdFromSource(src)
  auditAction(actorUserId, 'command.delete_vehicles', nil, {
    radius = radius,
    deleted = deleted,
    skipped = skipped
  })
end)

RegisterCommand(RPAdminConfig.healCommand or 'heal', function(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s [id] im Spiel.'):format(RPAdminConfig.healCommand or 'heal'))
    return
  end

  if not ensurePermission(source, 'commands.heal') then
    return
  end

  if not canDo(source, 'command.heal', 500) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.healCommand or 'heal'), true)
  if not targetSource then
    return
  end

  TriggerClientEvent('rp:admin:healPlayer', targetSource)
  local actorUserId = getUserIdFromSource(source)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.heal', targetUserId, { targetSource = targetSource })
  sendHealReviveNotifications(source, targetSource, false)
end, false)

RegisterCommand(RPAdminConfig.reviveCommand or 'revive', function(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s [id] im Spiel.'):format(RPAdminConfig.reviveCommand or 'revive'))
    return
  end

  if not ensurePermission(source, 'commands.revive') then
    return
  end

  local reviveCooldownMs = tonumber(RPAdminConfig.reviveCooldownMs) or 5000
  if reviveCooldownMs < 1000 then
    reviveCooldownMs = 1000
  end

  local allowed, remainingMs = canDo(source, 'command.revive', reviveCooldownMs)
  if not allowed then
    local remainingSec = math.max(1, math.ceil((tonumber(remainingMs) or 0) / 1000))
    notify(source, 'warning', ('Revive-Cooldown aktiv. Bitte warte noch %s Sekunde(n).'):format(remainingSec))
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.reviveCommand or 'revive'), true)
  if not targetSource then
    return
  end

  TriggerClientEvent('rp:admin:revivePlayer', targetSource)
  local actorUserId = getUserIdFromSource(source)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.revive', targetUserId, { targetSource = targetSource })
  sendHealReviveNotifications(source, targetSource, true)
end, false)

RegisterCommand(RPAdminConfig.repairCommand or 'repair', function(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s [id] im Spiel.'):format(RPAdminConfig.repairCommand or 'repair'))
    return
  end

  if not ensurePermission(source, 'commands.repair') then
    return
  end

  if not canDo(source, 'command.repair', 500) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.repairCommand or 'repair'), true)
  if not targetSource then
    return
  end

  PendingRepairRequests[targetSource] = {
    actorSource = source,
    expiresAt = nowMs() + 7000
  }

  TriggerClientEvent('rp:admin:repairVehicle', targetSource, { actorSource = source })
end, false)

RegisterCommand(RPAdminConfig.reloadCommand or 'reload', function(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s [id] im Spiel.'):format(RPAdminConfig.reloadCommand or 'reload'))
    return
  end

  if not ensurePermission(source, 'commands.reload') then
    return
  end

  if not canDo(source, 'command.reload', 500) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.reloadCommand or 'reload'), true)
  if not targetSource then
    return
  end

  TriggerClientEvent('rp:admin:reloadWeapons', targetSource)

  local actorUserId = getUserIdFromSource(source)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.reload', targetUserId, { targetSource = targetSource })
  sendReloadNotifications(source, targetSource)
end, false)

RegisterCommand(RPAdminConfig.gotoCommand or 'goto', function(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s [id] im Spiel.'):format(RPAdminConfig.gotoCommand or 'goto'))
    return
  end

  if not ensurePermission(source, 'commands.tp') then
    return
  end

  if not canDo(source, 'command.tp', 500) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.gotoCommand or 'goto'), false)
  if not targetSource then
    return
  end

  local targetPed = GetPlayerPed(targetSource)
  if not targetPed or targetPed == 0 then
    notify(source, 'error', 'Spielerped nicht verfügbar.')
    return
  end

  local coords = GetEntityCoords(targetPed)
  local heading = GetEntityHeading(targetPed)
  TriggerClientEvent('rp:admin:teleport', source, {
    x = coords.x,
    y = coords.y,
    z = coords.z + 0.75,
    h = heading
  })

  local actorUserId = getUserIdFromSource(source)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.goto', targetUserId, { targetSource = targetSource })
  notify(source, 'success', ('Du wurdest zu %s (ID %s) teleportiert.'):format(getProfileNameBySource(targetSource), targetSource))
end, false)

RegisterCommand(RPAdminConfig.tpCommand or 'tp', function(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s x, y, z im Spiel.'):format(RPAdminConfig.tpCommand or 'tp'))
    return
  end

  if not ensurePermission(source, 'commands.tp') then
    return
  end

  if not canDo(source, 'command.tp_coords', 500) then
    return
  end

  local x, y, z, err = parseTeleportCoordinates(args)
  if not x or not y or not z then
    notify(source, 'error', err or 'Ungültige Koordinaten.')
    return
  end

  TriggerClientEvent('rp:admin:teleport', source, {
    x = x,
    y = y,
    z = z,
    h = 0.0,
    snapToGround = true
  })

  local actorUserId = getUserIdFromSource(source)
  auditAction(actorUserId, 'command.tp_coords', actorUserId, { x = x, y = y, z = z })
  notify(source, 'success', ('Teleportiert zu Koordinaten: %.2f, %.2f, %.2f'):format(x, y, z))
end, false)

RegisterCommand(RPAdminConfig.tpmCommand or 'tpm', function(source)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s im Spiel.'):format(RPAdminConfig.tpmCommand or 'tpm'))
    return
  end

  if not ensurePermission(source, 'commands.tpm') then
    return
  end

  if not canDo(source, 'command.tpm', 500) then
    return
  end

  PendingTpmRequests[source] = nowMs() + 7000
  TriggerClientEvent('rp:admin:requestTeleportToWaypoint', source)
end, false)

RegisterCommand(RPAdminConfig.bringCommand or 'bring', function(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s [id] im Spiel.'):format(RPAdminConfig.bringCommand or 'bring'))
    return
  end

  if not ensurePermission(source, 'commands.bring') then
    return
  end

  if not canDo(source, 'command.bring', 500) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.bringCommand or 'bring'), false)
  if not targetSource then
    return
  end

  if targetSource == source then
    notify(source, 'warning', 'Du kannst dich nicht selbst zu dir bringen.')
    return
  end

  local actorPed = GetPlayerPed(source)
  if not actorPed or actorPed == 0 then
    notify(source, 'error', 'Dein Spielerped ist nicht verfügbar.')
    return
  end

  local coords = GetEntityCoords(actorPed)
  local heading = GetEntityHeading(actorPed)
  TriggerClientEvent('rp:admin:teleport', targetSource, {
    x = coords.x + 1.0,
    y = coords.y,
    z = coords.z + 0.5,
    h = heading
  })

  local actorUserId = getUserIdFromSource(source)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.bring', targetUserId, { targetSource = targetSource })
  notify(source, 'success', ('Spieler %s (ID %s) wurde zu dir teleportiert.'):format(getProfileNameBySource(targetSource), targetSource))
  notify(targetSource, 'info', ('Du wurdest von %s zu ihm teleportiert.'):format(getProfileNameBySource(source)))
end, false)

RegisterCommand(RPAdminConfig.freezeCommand or 'freeze', function(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s [id] im Spiel.'):format(RPAdminConfig.freezeCommand or 'freeze'))
    return
  end

  if not ensurePermission(source, 'commands.freeze') then
    return
  end

  if not canDo(source, 'command.freeze', 350) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.freezeCommand or 'freeze'), false)
  if not targetSource then
    return
  end

  local willFreeze = not (FrozenPlayers[targetSource] == true)
  FrozenPlayers[targetSource] = willFreeze
  TriggerClientEvent('rp:admin:setFrozenState', targetSource, {
    frozen = willFreeze
  })

  local actorUserId = getUserIdFromSource(source)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, willFreeze and 'command.freeze' or 'command.unfreeze', targetUserId, {
    targetSource = targetSource,
    frozen = willFreeze
  })

  if willFreeze then
    notify(source, 'success', ('Spieler %s (ID %s) wurde eingefroren.'):format(getProfileNameBySource(targetSource), targetSource))
    notify(targetSource, 'warning', ('Du wurdest von %s eingefroren.'):format(getProfileNameBySource(source)))
  else
    notify(source, 'success', ('Spieler %s (ID %s) wurde entfroren.'):format(getProfileNameBySource(targetSource), targetSource))
    notify(targetSource, 'info', ('Du wurdest von %s entfroren.'):format(getProfileNameBySource(source)))
  end
end, false)

RegisterCommand(RPAdminConfig.skinCommand or 'skin', function(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s [id] im Spiel.'):format(RPAdminConfig.skinCommand or 'skin'))
    return
  end

  if not ensurePermission(source, 'commands.skin') then
    return
  end

  if not canDo(source, 'command.skin', 500) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.skinCommand or 'skin'), true)
  if not targetSource then
    return
  end

  if GetResourceState('rp_skin') ~= 'started' then
    notify(source, 'error', 'rp_skin ist nicht gestartet.')
    return
  end

  local sex = getPlayerSexBySource(targetSource)
  local storedSkin = getPlayerStoredSkinBySource(targetSource)
  local creatorPayload = {
    mode = 'skin',
    sex = sex,
    model = storedSkin and storedSkin.model or nil,
    components = (storedSkin and storedSkin.components) or {},
    props = (storedSkin and storedSkin.props) or {},
    overlays = (storedSkin and storedSkin.overlays) or {}
  }

  TriggerClientEvent('rp:skin:openCurrent', targetSource, creatorPayload)

  local actorUserId = getUserIdFromSource(source)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.skin', targetUserId, { targetSource = targetSource, sex = sex })

  notify(source, 'success', ('Skin-Menü für %s (ID %s) geöffnet.'):format(getProfileNameBySource(targetSource), targetSource))
  notify(targetSource, 'info', ('%s hat dein Skin-Menü geöffnet.'):format(getProfileNameBySource(source)))
end, false)

RegisterCommand(RPAdminConfig.identityCommand or 'identity', function(source, args)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s [id] im Spiel.'):format(RPAdminConfig.identityCommand or 'identity'))
    return
  end

  if not ensurePermission(source, IDENTITY_PERMISSION_KEY) then
    return
  end

  if not canDo(source, 'command.identity', 500) then
    return
  end

  local targetSource = getTargetSourceFromCommandArg(source, args and args[1], ('/%s'):format(RPAdminConfig.identityCommand or 'identity'), false)
  if not targetSource then
    return
  end

  if not canAffectTargetByHierarchy(source, targetSource, 'Du kannst die Identität von gleich hohen oder höheren Rängen nicht ändern.') then
    return
  end

  if GetResourceState('rp_identity') ~= 'started' then
    notify(source, 'error', 'rp_identity ist nicht gestartet.')
    return
  end

  local success, result = exports.rp_identity:OpenIdentityCreator(targetSource, source)
  if not success then
    notify(source, 'error', tostring(result or 'Identity-Menü konnte nicht geöffnet werden.'))
    return
  end

  local actorUserId = getUserIdFromSource(source)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.identity', targetUserId, { targetSource = targetSource })

  notify(source, 'success', ('Identity-Menü für %s (ID %s) geöffnet.'):format(getProfileNameBySource(targetSource), targetSource))
  notify(targetSource, 'info', ('%s hat dein Identity-Menü geöffnet.'):format(getProfileNameBySource(source)))
end, false)

RegisterCommand(RPAdminConfig.noclipCommand or 'noclip', function(source)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s im Spiel.'):format(RPAdminConfig.noclipCommand or 'noclip'))
    return
  end

  if not ensurePermission(source, 'commands.noclip') then
    return
  end

  if not canDo(source, 'command.noclip', 250) then
    return
  end

  TriggerClientEvent('rp:admin:toggleNoclip', source)
  TriggerClientEvent('rp:admin:noclipPlayerMap', source, buildNoclipPlayerMap())
end, false)

RegisterNetEvent('rp:admin:noclipStateChanged', function(payload)
  local src = source
  if not hasPermission(src, 'commands.noclip') then
    TriggerClientEvent('rp:admin:forceNoclipState', src, { enabled = false })
    return
  end

  local enabled = type(payload) == 'table' and payload.enabled == true
  local actorUserId = getUserIdFromSource(src)
  auditAction(actorUserId, enabled and 'command.noclip_on' or 'command.noclip_off', actorUserId, {})
  notify(src, 'info', enabled and 'Noclip aktiviert.' or 'Noclip deaktiviert.')
end)

RegisterNetEvent('rp:admin:noclipRequestPlayerMap', function()
  local src = source
  if not hasPermission(src, 'commands.noclip') then
    return
  end

  if not canDo(src, 'command.noclip_map', 250) then
    return
  end

  TriggerClientEvent('rp:admin:noclipPlayerMap', src, buildNoclipPlayerMap())
end)

RegisterCommand(RPAdminConfig.nameCommand or 'name', function(source)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s im Spiel.'):format(RPAdminConfig.nameCommand or 'name'))
    return
  end

  if not ensurePermission(source, 'commands.name') then
    return
  end

  if not canDo(source, 'command.name', 250) then
    return
  end

  TriggerClientEvent('rp:admin:toggleNameOverlay', source)
  TriggerClientEvent('rp:admin:nameOverlayPlayerMap', source, buildNoclipPlayerMap())
end, false)

RegisterNetEvent('rp:admin:nameOverlayStateChanged', function(payload)
  local src = source
  if not hasPermission(src, 'commands.name') then
    NameOverlayStates[src] = nil
    TriggerClientEvent('rp:admin:forceNameOverlayState', src, { enabled = false })
    return
  end

  local enabled = type(payload) == 'table' and payload.enabled == true
  NameOverlayStates[src] = enabled and true or nil

  local actorUserId = getUserIdFromSource(src)
  auditAction(actorUserId, enabled and 'command.name_on' or 'command.name_off', actorUserId, {})
  notify(src, 'info', enabled and 'Nametags aktiviert.' or 'Nametags deaktiviert.')
end)

RegisterNetEvent('rp:admin:nameOverlayRequestPlayerMap', function()
  local src = source
  if not hasPermission(src, 'commands.name') then
    return
  end

  if NameOverlayStates[src] ~= true then
    return
  end

  if not canDo(src, 'command.name_map', 250) then
    return
  end

  TriggerClientEvent('rp:admin:nameOverlayPlayerMap', src, buildNoclipPlayerMap())
end)

RegisterCommand(RPAdminConfig.adutyCommand or 'aduty', function(source)
  if source <= 0 then
    print(('[rp_admin] Nutze den Befehl /%s im Spiel.'):format(RPAdminConfig.adutyCommand or 'aduty'))
    return
  end

  if not ensurePermission(source, 'commands.aduty') then
    return
  end

  if not canDo(source, 'command.aduty', 350) then
    return
  end

  local willEnable = not (AdutyStates[source] == true)
  local outfit = nil

  if willEnable then
    local userId = getUserIdFromSource(source)
    local roleData = userId and getRoleDataByUserId(userId) or nil
    local roleName = roleData and trim(roleData.roleName or '') or ''
    if roleName == '' or roleName == 'none' or roleName == 'spieler' then
      notify(source, 'error', 'Du brauchst einen Teamrang für /aduty.')
      return
    end

    outfit = getDutyOutfitByRoleName(roleName)
    if not outfit then
      notify(source, 'error', 'Kein Admin-Duty-Outfit für deinen Rang gefunden.')
      return
    end
  end

  AdutyStates[source] = willEnable
  TriggerClientEvent('rp:admin:setAdutyState', source, {
    enabled = willEnable,
    outfit = outfit
  })

  if willEnable then
    TriggerClientEvent('rp:admin:adutyPlayerMap', source, buildNoclipPlayerMap())
  end

  local actorUserId = getUserIdFromSource(source)
  auditAction(actorUserId, willEnable and 'command.aduty_on' or 'command.aduty_off', actorUserId, {})
  notify(source, 'info', willEnable and 'Admin-Dienst aktiviert.' or 'Admin-Dienst deaktiviert.')
end, false)

RegisterNetEvent('rp:admin:adutyRequestPlayerMap', function()
  local src = source
  if not hasPermission(src, 'commands.aduty') then
    return
  end

  if AdutyStates[src] ~= true then
    return
  end

  if not canDo(src, 'command.aduty_map', 250) then
    return
  end

  TriggerClientEvent('rp:admin:adutyPlayerMap', src, buildNoclipPlayerMap())
end)

RegisterNetEvent('rp:admin:repairResult', function(payload)
  local targetSource = source
  local pending = PendingRepairRequests[targetSource]
  PendingRepairRequests[targetSource] = nil

  if not pending or pending.expiresAt < nowMs() then
    return
  end

  local actorSource = tonumber(pending.actorSource) or 0
  if actorSource <= 0 or not GetPlayerName(actorSource) then
    return
  end

  if not hasPermission(actorSource, 'commands.repair') then
    return
  end

  local ok = type(payload) == 'table' and payload.ok == true
  if not ok then
    local failMessage = 'Fahrzeug konnte nicht repariert werden. Der Spieler sitzt in keinem Fahrzeug.'
    if type(payload) == 'table' then
      local customMessage = trim(tostring(payload.message or ''))
      if customMessage ~= '' then
        failMessage = customMessage
      end
    end
    notify(actorSource, 'error', failMessage)
    return
  end

  local actorUserId = getUserIdFromSource(actorSource)
  local targetUserId = getUserIdFromSource(targetSource)
  auditAction(actorUserId, 'command.repair', targetUserId, { targetSource = targetSource })
  sendRepairNotifications(actorSource, targetSource)
end)

RegisterNetEvent('rp:admin:tpmResult', function(payload)
  local src = source
  local pendingUntil = PendingTpmRequests[src]
  PendingTpmRequests[src] = nil

  if not pendingUntil or pendingUntil < nowMs() then
    return
  end

  if not hasPermission(src, 'commands.tpm') then
    return
  end

  if type(payload) ~= 'table' or payload.ok ~= true then
    local message = 'Teleport zum Marker fehlgeschlagen.'
    if type(payload) == 'table' then
      local custom = trim(tostring(payload.message or ''))
      if custom ~= '' then
        message = custom
      end
    end
    notify(src, 'error', message)
    return
  end

  local x = tonumber(payload.x)
  local y = tonumber(payload.y)
  local z = tonumber(payload.z)
  if not x or not y or not z then
    notify(src, 'error', 'Ungültige Marker-Koordinaten erhalten.')
    return
  end

  TriggerClientEvent('rp:admin:teleport', src, {
    x = x,
    y = y,
    z = z,
    h = 0.0
  })

  local actorUserId = getUserIdFromSource(src)
  auditAction(actorUserId, 'command.tpm', actorUserId, { x = x, y = y, z = z })
  notify(src, 'success', 'Du wurdest zu deinem Marker teleportiert.')
end)

RegisterNetEvent('rp:admin:nuiAction', function(payload)
  local src = source
  if type(payload) ~= 'table' then
    return
  end

  handleNuiAction(src, payload)
end)

AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
  local src = source
  deferrals.defer()
  Wait(0)

  local ids = getIdentityMap(src)
  local primary = getPrimaryIdentifier(ids)
  if not primary then
    deferrals.done('Verbindung abgelehnt: Kein Identifier gefunden.')
    return
  end

  local ban = fetchBanByIdentifier(primary)
  if not ban then
    deferrals.done()
    return
  end

  local bannedByName = 'System'
  local bannedByRole = 'System'

  local bannedByUserId = tonumber(ban.banned_by_user_id)
  if bannedByUserId then
    local bannedByIdentifier = pickIdentifierDisplay(
      ban.banned_by_steam_id,
      ban.banned_by_fivem_id,
      ban.banned_by_discord_id,
      ban.banned_by_license
    )

    bannedByName = resolveProfileNameByUserId(
      bannedByUserId,
      bannedByIdentifier,
      ban.banned_by_character_name,
      ban.banned_by_profile_name,
      ban.banned_by_steam_name
    )

    if bannedByName == '' then
      bannedByName = ('user:%s'):format(bannedByUserId)
    end

    local roleLabel = trim(ban.banned_by_role_label or '')
    bannedByRole = roleLabel ~= '' and roleLabel or 'Unbekannter Rang'
  end

  deferrals.done(
    ('Du bist gebannt. Ban-ID: #%s | Grund: %s | Gebannt von: %s (%s)')
      :format(tostring(ban.id or '?'), tostring(ban.reason or 'Kein Grund'), bannedByName, bannedByRole)
  )
end)

AddEventHandler('playerDropped', function()
  local src = source
  local userId = getUserIdFromSource(src)
  invalidateRoleCache(userId)
  ActiveRoleFingerprint[src] = nil
  LastAction[src] = nil
  SearchFilter[src] = nil
  PlayerListMode[src] = nil
  PendingRepairRequests[src] = nil
  PendingDeleteRequests[src] = nil
  PendingTpmRequests[src] = nil
  PendingGiveWeaponRequests[src] = nil
  FrozenPlayers[src] = nil
  AdutyStates[src] = nil
  NameOverlayStates[src] = nil
  SettingsDraft[src] = nil
  PanelOpenMode[src] = nil
end)

AddEventHandler('playerJoining', function()
  local src = source
  SetTimeout(2500, function()
    pushCommandSuggestions(src)
  end)
end)

exports('HasPermission', function(source, permissionKey)
  return hasPermission(source, permissionKey)
end)

exports('GetRoleBySource', function(source)
  local userId = getUserIdFromSource(source)
  return getRoleDataByUserId(userId)
end)

AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  ensureAdminSchema()
  ensureShopSettingsSchema()
  bootstrapAdminData()
  print('[rp_admin] Admin-System gestartet.')
  SetTimeout(2000, function()
    refreshAllCommandSuggestions()
  end)
end)

CreateThread(function()
  local checkMs = tonumber(RPAdminConfig.roleChangeKickCheckMs) or 5000
  if checkMs < 1000 then
    checkMs = 1000
  end

  while true do
    Wait(checkMs)

    local players = GetPlayers()
    for i = 1, #players do
      local src = tonumber(players[i])
      if src and GetPlayerName(src) then
        local userId = getUserIdFromSource(src)
        if userId then
          local currentRoleId = getDirectRoleIdByUserId(userId)
          local fp = ActiveRoleFingerprint[src]

          if not fp or fp.userId ~= userId then
            ActiveRoleFingerprint[src] = {
              userId = userId,
              roleId = currentRoleId
            }
          elseif fp.roleId ~= currentRoleId then
            invalidateRoleCache(userId)
            refreshPlayerAccessState(src, 'Dein Admin-Rang wurde in der Datenbank geändert.')
          end
        end
      end
    end
  end
end)
