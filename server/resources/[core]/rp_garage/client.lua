local pointsReady = false
local garageBlips = {}

CreateThread(function()
  Wait(2800)
  TriggerServerEvent('rp:garage:requestPoints')
end)

RegisterNetEvent('rp:garage:receivePoints', function(garages)
  if pointsReady then return end

  for i = 1, #garages do
    local g = garages[i]
    exports.rp_interactions:RegisterPoint({
      id = ('rp_garage_%s'):format(g.id),
      label = ('[E] %s'):format(g.label),
      coords = vector3(g.x + 0.0, g.y + 0.0, g.z + 0.0),
      distance = RPGarageConfig.drawDistance,
      interactDistance = RPGarageConfig.interactDistance,
      trigger = 'rp:garage:open',
      triggerType = 'client',
      args = { garageId = g.id }
    })

    if RPGarageConfig.blip and RPGarageConfig.blip.enabled then
      local blip = AddBlipForCoord(g.x + 0.0, g.y + 0.0, g.z + 0.0)
      SetBlipSprite(blip, RPGarageConfig.blip.sprite)
      SetBlipDisplay(blip, 4)
      SetBlipScale(blip, RPGarageConfig.blip.scale)
      SetBlipColour(blip, RPGarageConfig.blip.color)
      SetBlipAsShortRange(blip, RPGarageConfig.blip.shortRange == true)
      BeginTextCommandSetBlipName('STRING')
      AddTextComponentString(g.label or 'Garage')
      EndTextCommandSetBlipName(blip)
      garageBlips[#garageBlips + 1] = blip
    end
  end

  pointsReady = true
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

RegisterNUICallback('garage:storeVehicle', function(_, cb)
  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)

  if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
    vehicle = 0

    local pedCoords = GetEntityCoords(ped)
    local nearestVehicle = 0
    local nearestDistance = 30.0
    local allVehicles = GetGamePool('CVehicle')

    for i = 1, #allVehicles do
      local candidate = allVehicles[i]
      if candidate and candidate ~= 0 and DoesEntityExist(candidate) then
        local candidateCoords = GetEntityCoords(candidate)
        local distance = #(pedCoords - candidateCoords)
        if distance <= nearestDistance then
          nearestDistance = distance
          nearestVehicle = candidate
        end
      end
    end

    vehicle = nearestVehicle
  end

  if vehicle == 0 or not DoesEntityExist(vehicle) then
    cb({ ok = false, message = 'Kein Fahrzeug in deiner Nähe (30m) gefunden.' })
    return
  end

  local plate = GetVehicleNumberPlateText(vehicle)
  local state = exports.rp_vehicles:GetVehicleState(vehicle)
  local netId = NetworkGetNetworkIdFromEntity(vehicle)

  TriggerServerEvent('rp:garage:storeVehicle', {
    plate = tostring(plate or ''),
    state = state,
    netId = netId
  })

  cb({ ok = true })
end)
