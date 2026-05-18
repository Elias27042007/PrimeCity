local VehicleCatalog = {}

local function loadCatalog()
  VehicleCatalog = {}
  local rows = MySQL.query.await('SELECT id, model, label, price, category FROM vehicles WHERE enabled = 1')
  for i = 1, #rows do
    local row = rows[i]
    VehicleCatalog[row.model] = {
      id = row.id,
      model = row.model,
      label = row.label,
      price = tonumber(row.price) or 0,
      category = row.category
    }
  end
end

local function generatePlate()
  local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  local nums = '0123456789'

  local function pick(str)
    local index = math.random(1, #str)
    return str:sub(index, index)
  end

  local plate = ('RP%s%s%s %s%s%s'):format(
    pick(chars), pick(chars), pick(chars),
    pick(nums), pick(nums), pick(nums)
  )

  return plate
end

local function getCharacterId(source)
  return exports.rp_core:GetCharacterId(source)
end

local function findGarageIdByCode(code)
  if not code or code == '' then return nil end
  return MySQL.scalar.await('SELECT id FROM garages WHERE garage_code = ? LIMIT 1', { code })
end

local function createOwnedVehicle(source, model, garageCode)
  local characterId = getCharacterId(source)
  if not characterId then
    return false, 'Charakter nicht geladen.'
  end

  local vehicleDef = VehicleCatalog[model]
  if not vehicleDef then
    return false, 'Fahrzeugmodell nicht vorhanden.'
  end

  local garageId = findGarageIdByCode(garageCode) or MySQL.scalar.await('SELECT id FROM garages ORDER BY id ASC LIMIT 1')
  if not garageId then
    return false, 'Keine Garage verfügbar.'
  end

  local plate = generatePlate()
  local tries = 0
  while MySQL.scalar.await('SELECT id FROM owned_vehicles WHERE plate = ? LIMIT 1', { plate }) and tries < 5 do
    plate = generatePlate()
    tries = tries + 1
  end

  local props = {
    fuel = 100.0,
    engineHealth = 1000.0,
    bodyHealth = 1000.0
  }

  MySQL.insert.await(
    [=[INSERT INTO owned_vehicles
       (character_id, vehicle_id, plate, props_json, stored, garage_id, fuel, engine_health, body_health)
       VALUES (?, ?, ?, ?, 1, ?, 100.0, 1000.0, 1000.0)]=],
    {
      characterId,
      vehicleDef.id,
      plate,
      json.encode(props),
      garageId
    }
  )

  return true, plate
end

RegisterCommand('buycar', function(source, args)
  if source <= 0 then return end

  local model = tostring(args[1] or '')
  if model == '' then
    TriggerClientEvent('rp:notify', source, {
      type = 'info',
      title = 'Fahrzeugkauf',
      message = 'Nutzung: /buycar <modell>'
    })
    return
  end

  local vehicleDef = VehicleCatalog[model]
  if not vehicleDef then
    TriggerClientEvent('rp:notify', source, { type = 'error', title = 'Fahrzeugkauf', message = 'Unbekanntes Modell.' })
    return
  end

  local ped = GetPlayerPed(source)
  local pos = GetEntityCoords(ped)
  if RPVehiclesConfig.dealership.enabled and #(pos - RPVehiclesConfig.dealership.location) > RPVehiclesConfig.dealership.radius then
    TriggerClientEvent('rp:notify', source, {
      type = 'error',
      title = 'Fahrzeugkauf',
      message = 'Du bist nicht am Autohaus.'
    })
    return
  end

  local removed = exports.rp_money:RemoveBank(source, vehicleDef.price, 'system', 'vehicle_purchase')
  if not removed then
    TriggerClientEvent('rp:notify', source, { type = 'error', title = 'Fahrzeugkauf', message = 'Nicht genug Bankguthaben.' })
    return
  end

  local ok, result = createOwnedVehicle(source, model, 'legion_garage')
  if not ok then
    exports.rp_money:AddBank(source, vehicleDef.price, 'system', 'vehicle_refund')
    TriggerClientEvent('rp:notify', source, { type = 'error', title = 'Fahrzeugkauf', message = result or 'Kauf fehlgeschlagen.' })
    return
  end

  TriggerClientEvent('rp:notify', source, {
    type = 'success',
    title = 'Fahrzeugkauf',
    message = ('%s gekauft. Kennzeichen: %s'):format(vehicleDef.label, result)
  })
end)

exports('CreateOwnedVehicle', createOwnedVehicle)
exports('GetCatalog', function()
  return VehicleCatalog
end)

AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  math.randomseed(os.time())
  loadCatalog()
end)
