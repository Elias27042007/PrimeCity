CreateThread(function()
  Wait(1500)

  local dealership = RPVehiclesConfig and RPVehiclesConfig.dealership
  if not dealership or not dealership.enabled or not dealership.blip or not dealership.blip.enabled then
    return
  end

  local blip = AddBlipForCoord(dealership.location.x, dealership.location.y, dealership.location.z)
  SetBlipSprite(blip, dealership.blip.sprite)
  SetBlipDisplay(blip, 4)
  SetBlipScale(blip, dealership.blip.scale)
  SetBlipColour(blip, dealership.blip.color)
  SetBlipAsShortRange(blip, dealership.blip.shortRange == true)
  BeginTextCommandSetBlipName('STRING')
  AddTextComponentString(dealership.blip.label or 'Autohaus')
  EndTextCommandSetBlipName(blip)
end)

RegisterNetEvent('rp:vehicles:spawnOwnedVehicle', function(data)
  if type(data) ~= 'table' then
    return
  end

  local modelHash = GetHashKey(data.model)
  if not IsModelInCdimage(modelHash) then
    TriggerEvent('rp:notify', { type = 'error', title = 'Garage', message = 'Fahrzeugmodell nicht vorhanden.' })
    return
  end

  RequestModel(modelHash)
  local attempts = 0
  while not HasModelLoaded(modelHash) and attempts < 200 do
    attempts = attempts + 1
    Wait(10)
  end

  if not HasModelLoaded(modelHash) then
    TriggerEvent('rp:notify', { type = 'error', title = 'Garage', message = 'Fahrzeug konnte nicht geladen werden.' })
    return
  end

  local coords = data.spawn
  local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, coords.h, true, false)
  SetVehicleNumberPlateText(vehicle, data.plate or 'RPVEH')

  if data.props then
    SetVehicleEngineHealth(vehicle, tonumber(data.props.engineHealth) or 1000.0)
    SetVehicleBodyHealth(vehicle, tonumber(data.props.bodyHealth) or 1000.0)
    SetVehicleFuelLevel(vehicle, tonumber(data.props.fuel) or 100.0)
  end

  TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
  SetModelAsNoLongerNeeded(modelHash)
end)

exports('GetVehicleState', function(vehicle)
  if not DoesEntityExist(vehicle) then
    return nil
  end

  return {
    fuel = GetVehicleFuelLevel(vehicle),
    engineHealth = GetVehicleEngineHealth(vehicle),
    bodyHealth = GetVehicleBodyHealth(vehicle)
  }
end)
