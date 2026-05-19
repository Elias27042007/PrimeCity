local garageBlips = {}
local registeredPointIds = {}

local function clearGarageVisuals()
  for i = 1, #registeredPointIds do
    exports.rp_interactions:RemovePoint(registeredPointIds[i])
  end
  registeredPointIds = {}

  for i = 1, #garageBlips do
    local blip = garageBlips[i]
    if blip and DoesBlipExist(blip) then
      RemoveBlip(blip)
    end
  end
  garageBlips = {}
end

local function rebuildGarageVisuals(garages)
  clearGarageVisuals()

  for i = 1, #garages do
    local g = garages[i]
    local pointId = ('rp_garage_%s'):format(g.id)
    exports.rp_interactions:RegisterPoint({
      id = pointId,
      label = ('[E] %s'):format(g.label),
      coords = vector3(g.x + 0.0, g.y + 0.0, g.z + 0.0),
      distance = RPGarageConfig.drawDistance,
      interactDistance = RPGarageConfig.interactDistance,
      trigger = 'rp:garage:open',
      triggerType = 'client',
      args = { garageId = g.id }
    })
    registeredPointIds[#registeredPointIds + 1] = pointId

    local useBlip = (RPGarageConfig.blip and RPGarageConfig.blip.enabled) and (g.blipEnabled ~= false)
    if useBlip then
      local blip = AddBlipForCoord(g.x + 0.0, g.y + 0.0, g.z + 0.0)
      SetBlipSprite(blip, RPGarageConfig.blip.sprite)
      SetBlipDisplay(blip, 4)
      SetBlipScale(blip, RPGarageConfig.blip.scale)
      SetBlipColour(blip, RPGarageConfig.blip.color)
      SetBlipAsShortRange(blip, RPGarageConfig.blip.shortRange == true)
      BeginTextCommandSetBlipName('STRING')
      AddTextComponentString('Garage')
      EndTextCommandSetBlipName(blip)
      garageBlips[#garageBlips + 1] = blip
    end
  end
end

CreateThread(function()
  Wait(2800)
  TriggerServerEvent('rp:garage:requestPoints')
end)

RegisterNetEvent('rp:garage:receivePoints', function(garages)
  rebuildGarageVisuals(garages or {})
end)

RegisterNetEvent('rp:garage:open', function(args)
  TriggerServerEvent('rp:garage:requestOpen', args and args.garageId or 0)
end)

RegisterNetEvent('rp:garage:openUI', function(payload)
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'open', data = payload })
end)

RegisterNetEvent('rp:garage:closeUI', function()
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end)

RegisterNetEvent('rp:garage:storeSuccess', function(netId)
  if not netId then return end
  local vehicle = NetworkGetEntityFromNetworkId(netId)
  if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
    DeleteVehicle(vehicle)
  end
end)

RegisterNUICallback('garage:close', function(_, cb)
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  TriggerServerEvent('rp:garage:close')
  cb({ ok = true })
end)

RegisterNUICallback('garage:spawnVehicle', function(data, cb)
  TriggerServerEvent('rp:garage:spawnVehicle', tonumber(data.vehicleId or 0))
  cb({ ok = true })
end)

RegisterNUICallback('garage:storeVehicle', function(data, cb)
  local mode = type(data) == 'table' and tostring(data.mode or 'all') or 'all'
  local targetVehicleId = type(data) == 'table' and tonumber(data.vehicleId or 0) or 0
  local targetPlate = type(data) == 'table' and tostring(data.plate or '') or ''
  local searchRadius = 30.0

  local function normalizePlate(plate)
    return tostring(plate or ''):upper():gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1')
  end

  local function notifyLocal(message)
    TriggerEvent('rp:notify', {
      type = 'error',
      title = 'Garage',
      message = tostring(message or 'Einparken fehlgeschlagen.')
    })
  end

  local function buildEntry(vehicle)
    local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    if plate == '' then
      return nil
    end

    local state = exports.rp_vehicles:GetVehicleState(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    return {
      plate = plate,
      state = state,
      netId = netId
    }
  end

  local function getNearbyVehicles(radius)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local allVehicles = GetGamePool('CVehicle')
    local out = {}

    for i = 1, #allVehicles do
      local vehicle = allVehicles[i]
      if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        local coords = GetEntityCoords(vehicle)
        local distance = #(pedCoords - coords)
        if distance <= radius then
          out[#out + 1] = vehicle
        end
      end
    end

    return out
  end

  local entries = {}

  if mode == 'single' then
    local wantedPlate = normalizePlate(targetPlate)
    if wantedPlate == '' or targetVehicleId <= 0 then
      notifyLocal('Ungültiges Fahrzeug zum Einparken.')
      cb({ ok = false, message = 'Ungültiges Fahrzeug zum Einparken.' })
      return
    end

    local nearbyVehicles = getNearbyVehicles(searchRadius)
    local foundVehicle = 0

    for i = 1, #nearbyVehicles do
      local vehicle = nearbyVehicles[i]
      if normalizePlate(GetVehicleNumberPlateText(vehicle)) == wantedPlate then
        foundVehicle = vehicle
        break
      end
    end

    if foundVehicle == 0 then
      notifyLocal('Dieses Fahrzeug steht nicht in 30m Nähe.')
      cb({ ok = false, message = 'Dieses Fahrzeug steht nicht in 30m Nähe.' })
      return
    end

    local entry = buildEntry(foundVehicle)
    if not entry then
      notifyLocal('Kennzeichen konnte nicht gelesen werden.')
      cb({ ok = false, message = 'Kennzeichen konnte nicht gelesen werden.' })
      return
    end

    entries[1] = entry
  else
    local nearbyVehicles = getNearbyVehicles(searchRadius)
    for i = 1, #nearbyVehicles do
      local entry = buildEntry(nearbyVehicles[i])
      if entry then
        entries[#entries + 1] = entry
      end
    end

    if #entries == 0 then
      notifyLocal('Kein Fahrzeug in deiner Nähe (30m) gefunden.')
      cb({ ok = false, message = 'Kein Fahrzeug in deiner Nähe (30m) gefunden.' })
      return
    end
  end

  TriggerServerEvent('rp:garage:storeVehicle', {
    mode = mode,
    vehicleId = targetVehicleId,
    plate = normalizePlate(targetPlate),
    entries = entries
  })

  cb({ ok = true })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end
  clearGarageVisuals()
end)
