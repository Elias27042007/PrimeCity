local GarageCache = {}
local OpenSession = {}

local function hasColumn(tableName, columnName)
  local exists = MySQL.scalar.await(
    [=[SELECT 1
       FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE()
         AND TABLE_NAME = ?
         AND COLUMN_NAME = ?
       LIMIT 1]=],
    { tableName, columnName }
  )

  return exists ~= nil
end

local function ensureGaragesSchema()
  if not hasColumn('garages', 'blip_enabled') then
    MySQL.query.await('ALTER TABLE garages ADD COLUMN blip_enabled TINYINT(1) NOT NULL DEFAULT 1 AFTER enabled')
  end

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS garage_spawn_points (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      garage_id BIGINT UNSIGNED NOT NULL,
      pos_x DOUBLE NOT NULL,
      pos_y DOUBLE NOT NULL,
      pos_z DOUBLE NOT NULL,
      heading DOUBLE NOT NULL DEFAULT 0,
      sort_order INT UNSIGNED NOT NULL DEFAULT 0,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_gsp_garage (garage_id, sort_order, id),
      CONSTRAINT fk_gsp_garage FOREIGN KEY (garage_id) REFERENCES garages (id) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])
end

local function notify(source, ntype, title, message)
  TriggerClientEvent('rp:notify', source, {
    type = ntype,
    title = title,
    message = message
  })
end

local function toStoredFlag(value)
  if value == true then
    return 1
  end
  if value == false then
    return 0
  end

  local number = tonumber(value)
  if number then
    return number >= 1 and 1 or 0
  end

  local text = tostring(value or ''):lower()
  if text == 'true' then
    return 1
  end
  if text == 'false' then
    return 0
  end

  return 0
end

local function loadGarages()
  GarageCache = {}
  local rows = MySQL.query.await(
    'SELECT id, label, pos_x, pos_y, pos_z, spawn_x, spawn_y, spawn_z, spawn_heading, COALESCE(blip_enabled, 1) AS blip_enabled FROM garages WHERE enabled = 1 ORDER BY id ASC'
  )
  local extraSpawnRows = MySQL.query.await(
    'SELECT id, garage_id, pos_x, pos_y, pos_z, heading FROM garage_spawn_points ORDER BY garage_id ASC, sort_order ASC, id ASC'
  ) or {}
  local extraSpawnsByGarage = {}

  for i = 1, #extraSpawnRows do
    local row = extraSpawnRows[i]
    local garageId = tonumber(row.garage_id) or 0
    if garageId > 0 then
      extraSpawnsByGarage[garageId] = extraSpawnsByGarage[garageId] or {}
      extraSpawnsByGarage[garageId][#extraSpawnsByGarage[garageId] + 1] = {
        id = tonumber(row.id) or 0,
        x = tonumber(row.pos_x) or 0.0,
        y = tonumber(row.pos_y) or 0.0,
        z = tonumber(row.pos_z) or 0.0,
        h = tonumber(row.heading) or 0.0
      }
    end
  end

  for i = 1, #rows do
    local r = rows[i]
    local garageId = tonumber(r.id) or 0
    local spawnPoints = {
      {
        id = 0,
        x = tonumber(r.spawn_x) or 0.0,
        y = tonumber(r.spawn_y) or 0.0,
        z = tonumber(r.spawn_z) or 0.0,
        h = tonumber(r.spawn_heading) or 0.0
      }
    }
    local extras = extraSpawnsByGarage[garageId] or {}
    for j = 1, #extras do
      spawnPoints[#spawnPoints + 1] = extras[j]
    end

    GarageCache[r.id] = {
      id = garageId,
      label = r.label,
      x = tonumber(r.pos_x),
      y = tonumber(r.pos_y),
      z = tonumber(r.pos_z),
      sx = tonumber(r.spawn_x),
      sy = tonumber(r.spawn_y),
      sz = tonumber(r.spawn_z),
      sh = tonumber(r.spawn_heading),
      spawnPoints = spawnPoints,
      blipEnabled = (tonumber(r.blip_enabled) or 1) == 1
    }
  end
end

local function getGaragesForClient()
  local list = {}
  for _, g in pairs(GarageCache) do
    list[#list + 1] = g
  end
  return list
end

local function isSpawnPointBlocked(point, radius)
  local checkRadius = tonumber(radius) or 2.7
  local vehicles = GetAllVehicles() or {}
  local target = vector3(tonumber(point.x) or 0.0, tonumber(point.y) or 0.0, tonumber(point.z) or 0.0)

  for i = 1, #vehicles do
    local veh = vehicles[i]
    if veh and veh ~= 0 and DoesEntityExist(veh) then
      local coords = GetEntityCoords(veh)
      if #(coords - target) <= checkRadius then
        return true
      end
    end
  end

  return false
end

local function pickAvailableSpawnPoint(garage)
  if type(garage) ~= 'table' or type(garage.spawnPoints) ~= 'table' then
    return nil, 0, 0
  end

  local total = #garage.spawnPoints
  if total <= 0 then
    return nil, 0, 0
  end

  local blocked = 0
  for i = 1, total do
    local point = garage.spawnPoints[i]
    if not isSpawnPointBlocked(point, 2.7) then
      return point, total, blocked
    end
    blocked = blocked + 1
  end

  return nil, total, blocked
end

local function isNearGarage(source, garageId)
  local garage = GarageCache[garageId]
  if not garage then return false end

  local ped = GetPlayerPed(source)
  if ped == 0 then return false end

  local coords = GetEntityCoords(ped)
  local dist = #(coords - vector3(garage.x, garage.y, garage.z))
  return dist <= (RPGarageConfig.interactDistance + 1.6)
end

local function fetchGarageVehicles(source, garageId)
  local characterId = exports.rp_core:GetCharacterId(source)
  if not characterId then return {} end

  return MySQL.query.await(
    [=[SELECT ov.id, ov.plate, ov.stored, ov.fuel, ov.engine_health, ov.body_health, v.model, v.label
       FROM owned_vehicles ov
       INNER JOIN vehicles v ON v.id = ov.vehicle_id
       WHERE ov.character_id = ?
       ORDER BY ov.id DESC]=],
    { characterId }
  )
end

local function openGarage(source, garageId)
  local garage = GarageCache[garageId]
  if not garage then
    notify(source, 'error', 'Garage', 'Garage nicht gefunden.')
    return
  end

  local vehicles = fetchGarageVehicles(source, garageId)

  OpenSession[source] = { garageId = garageId }

  TriggerClientEvent('rp:garage:openUI', source, {
    garageId = garageId,
    garageLabel = garage.label,
    vehicles = vehicles
  })
end

local function validateGarageSession(source)
  local session = OpenSession[source]
  if not session then
    return nil
  end

  if not isNearGarage(source, session.garageId) then
    OpenSession[source] = nil
    TriggerClientEvent('rp:garage:closeUI', source)
    notify(source, 'warning', 'Garage', 'Du hast den Garagenbereich verlassen.')
    return nil
  end

  return session
end

RegisterNetEvent('rp:garage:requestPoints', function()
  TriggerClientEvent('rp:garage:receivePoints', source, getGaragesForClient())
end)

RegisterNetEvent('rp:garage:requestOpen', function(garageId)
  local src = source
  garageId = tonumber(garageId) or 0

  if not exports.rp_core:CanUseRateLimitedAction(src, 'garage_open', 650) then
    return
  end

  if garageId <= 0 or not isNearGarage(src, garageId) then
    notify(src, 'error', 'Garage', 'Du bist nicht an einer Garage.')
    return
  end

  openGarage(src, garageId)
end)

RegisterNetEvent('rp:garage:close', function()
  OpenSession[source] = nil
end)

RegisterNetEvent('rp:garage:spawnVehicle', function(vehicleId)
  local src = source
  local session = validateGarageSession(src)
  if not session then return end
  if not exports.rp_core:CanUseRateLimitedAction(src, 'garage_spawn', 1200) then return end

  vehicleId = tonumber(vehicleId) or 0
  if vehicleId <= 0 then return end

  local characterId = exports.rp_core:GetCharacterId(src)
  local garage = GarageCache[session.garageId]
  if not characterId or not garage then return end
  local spawnPoint, spawnTotal = pickAvailableSpawnPoint(garage)
  if not spawnPoint then
    if (tonumber(spawnTotal) or 0) <= 1 then
      notify(src, 'error', 'Garage', 'Spawnpunkt ist aktuell blockiert (gesperrt).')
    else
      notify(src, 'error', 'Garage', 'Alle Spawnpunkte sind aktuell blockiert.')
    end
    return
  end

  local row = MySQL.single.await(
    [=[SELECT ov.id, ov.plate, ov.props_json, ov.stored, v.model
       FROM owned_vehicles ov
       INNER JOIN vehicles v ON v.id = ov.vehicle_id
       WHERE ov.id = ? AND ov.character_id = ? LIMIT 1]=],
    { vehicleId, characterId }
  )

  if not row then
    notify(src, 'error', 'Garage', 'Fahrzeug nicht gefunden.')
    return
  end

  if toStoredFlag(row.stored) ~= 1 then
    notify(src, 'error', 'Garage', 'Fahrzeug ist bereits ausgeparkt.')
    return
  end

  MySQL.update.await('UPDATE owned_vehicles SET stored = 0, garage_id = ? WHERE id = ?', {
    session.garageId,
    row.id
  })

  TriggerClientEvent('rp:vehicles:spawnOwnedVehicle', src, {
    model = row.model,
    plate = row.plate,
    props = json.decode(row.props_json or '{}'),
    spawn = {
      x = tonumber(spawnPoint.x) or garage.sx,
      y = tonumber(spawnPoint.y) or garage.sy,
      z = tonumber(spawnPoint.z) or garage.sz,
      h = tonumber(spawnPoint.h) or garage.sh
    }
  })

  notify(src, 'success', 'Garage', ('Fahrzeug %s ausgeparkt.'):format(row.plate))
  OpenSession[src] = nil
  TriggerClientEvent('rp:garage:closeUI', src)
end)

local function normalizePlate(value)
  return tostring(value or ''):upper():gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1')
end

local function extractPropsFromEntry(entry)
  local vehicleState = (type(entry) == 'table' and type(entry.state) == 'table') and entry.state or {}
  return {
    fuel = tonumber(vehicleState.fuel) or 100.0,
    engineHealth = tonumber(vehicleState.engineHealth) or 1000.0,
    bodyHealth = tonumber(vehicleState.bodyHealth) or 1000.0
  }
end

RegisterNetEvent('rp:garage:storeVehicle', function(data)
  local src = source
  local session = validateGarageSession(src)
  if not session then return end
  if not exports.rp_core:CanUseRateLimitedAction(src, 'garage_store', 1000) then return end

  if type(data) ~= 'table' then
    return
  end

  local characterId = exports.rp_core:GetCharacterId(src)
  if not characterId then return end

  local mode = tostring(data.mode or 'all')
  local entries = type(data.entries) == 'table' and data.entries or {}
  local entriesByPlate = {}

  for i = 1, #entries do
    local entry = entries[i]
    if type(entry) == 'table' then
      local plate = normalizePlate(entry.plate)
      if plate ~= '' and not entriesByPlate[plate] then
        entriesByPlate[plate] = entry
      end
    end
  end

  if mode == 'single' then
    local vehicleId = tonumber(data.vehicleId or 0) or 0
    local selectedPlate = normalizePlate(data.plate)
    local row

    if vehicleId > 0 then
      row = MySQL.single.await(
        'SELECT id, plate, stored FROM owned_vehicles WHERE id = ? AND character_id = ? LIMIT 1',
        { vehicleId, characterId }
      )
    elseif selectedPlate ~= '' then
      row = MySQL.single.await(
        'SELECT id, plate, stored FROM owned_vehicles WHERE plate = ? AND character_id = ? LIMIT 1',
        { selectedPlate, characterId }
      )
    end

    if not row then
      notify(src, 'error', 'Garage', 'Dieses Fahrzeug gehoert dir nicht.')
      return
    end

    if toStoredFlag(row.stored) == 1 then
      notify(src, 'error', 'Garage', 'Dieses Fahrzeug ist bereits eingeparkt.')
      openGarage(src, session.garageId)
      return
    end

    local rowPlate = normalizePlate(row.plate)
    local matchedEntry = entriesByPlate[rowPlate]
    if not matchedEntry then
      notify(src, 'error', 'Garage', 'Dieses Fahrzeug steht nicht in deiner Nähe (30m).')
      return
    end

    local props = extractPropsFromEntry(matchedEntry)

    MySQL.update.await(
      [=[UPDATE owned_vehicles
         SET stored = 1, garage_id = ?, props_json = ?, fuel = ?, engine_health = ?, body_health = ?
         WHERE id = ?]=],
      {
        session.garageId,
        json.encode(props),
        props.fuel,
        props.engineHealth,
        props.bodyHealth,
        row.id
      }
    )

    TriggerClientEvent('rp:garage:storeSuccess', src, tonumber(matchedEntry.netId))
    notify(src, 'success', 'Garage', ('Fahrzeug %s eingeparkt.'):format(rowPlate))
    openGarage(src, session.garageId)
    return
  end

  local rows = MySQL.query.await(
    'SELECT id, plate, stored FROM owned_vehicles WHERE character_id = ? AND stored = 0',
    { characterId }
  ) or {}

  if #rows == 0 then
    notify(src, 'error', 'Garage', 'Du hast keine ausgeparkten Fahrzeuge.')
    openGarage(src, session.garageId)
    return
  end

  local storedCount = 0
  for i = 1, #rows do
    local row = rows[i]
    local rowPlate = normalizePlate(row.plate)
    local matchedEntry = entriesByPlate[rowPlate]

    if matchedEntry then
      local props = extractPropsFromEntry(matchedEntry)
      MySQL.update.await(
        [=[UPDATE owned_vehicles
           SET stored = 1, garage_id = ?, props_json = ?, fuel = ?, engine_health = ?, body_health = ?
           WHERE id = ?]=],
        {
          session.garageId,
          json.encode(props),
          props.fuel,
          props.engineHealth,
          props.bodyHealth,
          row.id
        }
      )

      TriggerClientEvent('rp:garage:storeSuccess', src, tonumber(matchedEntry.netId))
      storedCount = storedCount + 1
    end
  end

  if storedCount <= 0 then
    notify(src, 'error', 'Garage', 'Keine deiner Fahrzeuge in 30m Nähe gefunden.')
    openGarage(src, session.garageId)
    return
  end

  notify(src, 'success', 'Garage', ('%s Fahrzeug(e) eingeparkt.'):format(storedCount))
  openGarage(src, session.garageId)
end)

AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end
  ensureGaragesSchema()
  loadGarages()
end)

RegisterNetEvent('rp:garage:adminReload', function()
  loadGarages()
  local players = GetPlayers()
  for i = 1, #players do
    local src = tonumber(players[i])
    if src then
      TriggerClientEvent('rp:garage:receivePoints', src, getGaragesForClient())
    end
  end
end)

AddEventHandler('playerDropped', function()
  OpenSession[source] = nil
end)
