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
  SetEntityAsMissionEntity(vehicle, true, true)
  SetVehicleOnGroundProperly(vehicle)
  SetVehicleModKit(vehicle, 0)

  local requestedPlate = tostring(data.plate or 'RPVEH'):upper():gsub('%s+', ' ')
  requestedPlate = requestedPlate:sub(1, 8)
  if requestedPlate == '' then
    requestedPlate = 'RPVEH'
  end

  local function trimPlate(text)
    return tostring(text or ''):gsub('^%s*(.-)%s*$', '%1')
  end

  SetVehicleNumberPlateTextIndex(vehicle, 0)
  SetVehicleNumberPlateText(vehicle, requestedPlate)

  -- Some addon/import vehicles reset plate text right after creation/warp.
  -- Re-apply a few ticks so the assigned plate is actually visible.
  CreateThread(function()
    local tries = 0
    while DoesEntityExist(vehicle) and tries < 25 do
      tries = tries + 1
      local currentPlate = trimPlate(GetVehicleNumberPlateText(vehicle))
      if currentPlate ~= requestedPlate then
        SetVehicleNumberPlateTextIndex(vehicle, 0)
        SetVehicleNumberPlateText(vehicle, requestedPlate)
      end
      Wait(120)
    end
  end)

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
