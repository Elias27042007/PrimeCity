local isSpawned = false
local spawnInProgress = false
local lastFallRescueAt = 0

local function showLoading(label)
  SendNUIMessage({ action = 'show', label = label or 'Lade Daten ...' })
end

local function hideLoading()
  SendNUIMessage({ action = 'hide' })
  -- Ensure the native FiveM loading UI is closed if it is still visible.
  ShutdownLoadingScreen()
  ShutdownLoadingScreenNui()
end

local function normalizePedState()
  local player = PlayerId()
  local ped = PlayerPedId()

  SetPlayerInvincible(player, false)
  SetEntityInvincible(ped, false)
  SetEntityCanBeDamaged(ped, true)
  FreezeEntityPosition(ped, false)
  SetPedCanRagdoll(ped, true)
  ClearPedTasksImmediately(ped)
  ClearPedSecondaryTask(ped)

  if IsEntityDead(ped) or GetEntityHealth(ped) <= 101 then
    SetEntityHealth(ped, 200)
  end
end

local function enforcePvpState()
  local player = PlayerId()
  local ped = PlayerPedId()

  -- PvP/Friendly Fire aktiv halten, damit Spieler sich schlagen
  -- und mit Waffen treffen können.
  NetworkSetFriendlyFireOption(true)
  SetPlayerCanDoDriveBy(player, true)
  SetCanAttackFriendly(ped, true, false)
  SetEntityCanBeDamaged(ped, true)
  SetPlayerInvincible(player, false)
  SetEntityInvincible(ped, false)
  SetEveryoneIgnorePlayer(player, false)
  SetPoliceIgnorePlayer(player, false)
end

local function resolveGroundZ(x, y, fallbackZ)
  local groundZ = tonumber(fallbackZ) or 30.0
  local found = false

  for height = 1000.0, -50.0, -25.0 do
    local ok, gz = GetGroundZFor_3dCoord(x, y, height, false)
    if ok then
      groundZ = gz
      found = true
      break
    end
  end

  return groundZ, found
end

local function cleanupOldPedAfterResurrect(oldPed, newPed)
  if not oldPed or oldPed == 0 or oldPed == newPed then
    return
  end

  if not DoesEntityExist(oldPed) then
    return
  end

  -- Wenn GTA beim Resurrect intern einen neuen Player-Ped anlegt,
  -- bleibt der alte tote Ped manchmal als "Kopie" liegen.
  -- Diese Leiche wird hier entfernt.
  local owner = NetworkGetPlayerIndexFromPed(oldPed)
  if owner == -1 then
    SetEntityAsMissionEntity(oldPed, true, true)
    DeleteEntity(oldPed)
  end
end

local function resurrectLocalPlayerSafely(x, y, z, h)
  local oldPed = PlayerPedId()

  -- WICHTIG:
  -- leaveDeadPed = false verhindert, dass eine tote Kopie liegen bleibt.
  NetworkResurrectLocalPlayer(x, y, z, h, 0, false)

  local newPed = PlayerPedId()
  cleanupOldPedAfterResurrect(oldPed, newPed)
end

local function placePedSafely(ped, x, y, z, h)
  RequestCollisionAtCoord(x, y, z)
  local timeout = GetGameTimer() + 5000
  while GetGameTimer() < timeout do
    RequestCollisionAtCoord(x, y, z)
    if HasCollisionLoadedAroundEntity(ped) then
      break
    end
    Wait(0)
  end

  local groundZ, hasGround = resolveGroundZ(x, y, z)
  local targetZ = z
  if hasGround and targetZ < groundZ then
    targetZ = groundZ + 0.2
  end

  SetEntityCoordsNoOffset(ped, x, y, targetZ + RPSpawnConfig.safeZOffset, false, false, false)
  SetEntityHeading(ped, h)
  resurrectLocalPlayerSafely(x, y, targetZ + 0.1, h)
  SetEntityCoordsNoOffset(PlayerPedId(), x, y, targetZ + 0.1, false, false, false)

  -- Falls die Kollision kurz nachzieht, setze den Ped nochmal
  -- auf den Boden, damit kein Durchfallen entsteht.
  if hasGround then
    SetEntityCoordsNoOffset(ped, x, y, groundZ + 0.2, false, false, false)
  end
end

local function doSpawn(coords)
  spawnInProgress = true
  local ped = PlayerPedId()
  local x = tonumber(coords.x) or -1037.66
  local y = tonumber(coords.y) or -2737.82
  local z = tonumber(coords.z) or 20.1693
  local h = tonumber(coords.h) or 327.0

  DoScreenFadeOut(RPSpawnConfig.fadeOutMs)
  while not IsScreenFadedOut() do Wait(50) end

  FreezeEntityPosition(ped, true)
  placePedSafely(ped, x, y, z, h)
  ClearPedTasksImmediately(ped)
  normalizePedState()
  enforcePvpState()

  Wait(250)
  DoScreenFadeIn(RPSpawnConfig.fadeInMs)
  FreezeEntityPosition(ped, false)
  normalizePedState()
  enforcePvpState()

  isSpawned = true
  spawnInProgress = false
end

RegisterNetEvent('rp:spawn:beginSpawnFlow', function(payload)
  -- Close default loading screens as soon as we begin our own transition.
  ShutdownLoadingScreen()
  ShutdownLoadingScreenNui()

  showLoading(payload and payload.transitionLabel or 'Charakter wird gespawnt ...')
  Wait(850)

  local coords = payload and payload.coords or {}
  doSpawn(coords)

  TriggerEvent('rp:hud:toggle', true)
  hideLoading()
end)

RegisterNetEvent('rp:spawn:forceRevive', function(data)
  if spawnInProgress then
    return
  end

  local ped = PlayerPedId()
  local coords = type(data) == 'table' and data.coords or nil

  if not coords then
    local pos = GetEntityCoords(ped)
    coords = {
      x = pos.x,
      y = pos.y,
      z = pos.z + 0.3,
      h = GetEntityHeading(ped)
    }
  end

  showLoading('Revive wird ausgeführt ...')
  doSpawn(coords)
  hideLoading()
end)

RegisterCommand(RPSpawnConfig.selfReviveCommand or 'selfrevive', function()
  TriggerServerEvent('rp:spawn:requestRevive')
end, false)

RegisterNetEvent('playerSpawned', function()
  if spawnInProgress then
    return
  end

  SetTimeout(500, function()
    normalizePedState()
    enforcePvpState()
    hideLoading()
  end)
end)

CreateThread(function()
  while true do
    Wait(250)
    enforcePvpState()
  end
end)

CreateThread(function()
  while true do
    Wait(RPSpawnConfig.saveIntervalMs)
    if isSpawned then
      local coords = GetEntityCoords(PlayerPedId())
      local heading = GetEntityHeading(PlayerPedId())
      TriggerServerEvent('rp:spawn:updatePosition', {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = heading
      })
    end
  end
end)

CreateThread(function()
  local cfg = RPSpawnConfig.fallProtection or {}
  if cfg.enabled ~= true then
    return
  end

  local zones = type(cfg.zones) == 'table' and cfg.zones or {}
  local checkInterval = tonumber(cfg.checkIntervalMs) or 350
  if checkInterval < 150 then
    checkInterval = 150
  end

  local cooldownMs = tonumber(cfg.cooldownMs) or 2500
  if cooldownMs < 500 then
    cooldownMs = 500
  end

  while true do
    Wait(checkInterval)

    if not isSpawned or spawnInProgress then
      goto continue
    end

    local now = GetGameTimer()
    if now - lastFallRescueAt < cooldownMs then
      goto continue
    end

    local ped = PlayerPedId()
    if ped == 0 then
      goto continue
    end

    local pos = GetEntityCoords(ped)

    for i = 1, #zones do
      local zone = zones[i]
      local center = zone.center
      if center and pos.z <= (tonumber(zone.minZ) or -1000.0) then
        local radius = tonumber(zone.radius) or 100.0
        if #(pos - center) <= radius then
          local safeZ = tonumber(zone.safeZ) or center.z
          local heading = GetEntityHeading(ped)

          FreezeEntityPosition(ped, true)
          placePedSafely(ped, center.x, center.y, safeZ, heading)
          ClearPedTasksImmediately(ped)
          SetEntityVelocity(ped, 0.0, 0.0, 0.0)
          FreezeEntityPosition(ped, false)

          TriggerEvent('rp:notify', {
            type = 'warning',
            title = 'Welt-Schutz',
            message = ('Kollision bei %s fehlte. Du wurdest sicher umgesetzt.'):format(tostring(zone.name or 'diesem Bereich'))
          })

          lastFallRescueAt = now
          break
        end
      end
    end

    ::continue::
  end
end)
