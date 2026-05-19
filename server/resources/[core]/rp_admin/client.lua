local uiOpen = false
local uiMode = 'admin'
local trackedSuggestions = {}
local reviveInProgressUntil = 0
local isFrozenByAdmin = false
local noclipEnabled = false
local noclipSpeedIndex = 2
local noclipSpeeds = { 0.6, 1.2, 2.4, 4.5, 8.0 }
local noclipPlayerMap = {}
local nextNoclipMapRequestAt = 0
local adutyEnabled = false
local adutyPlayerMap = {}
local nextAdutyMapRequestAt = 0
local nameOverlayEnabled = false
local nameOverlayPlayerMap = {}
local nextNameOverlayMapRequestAt = 0
local adutySavedAppearance = nil
local adutyCurrentOutfit = nil
local reloadWeaponHashes = {
  `WEAPON_DAGGER`, `WEAPON_BAT`, `WEAPON_BOTTLE`, `WEAPON_CROWBAR`, `WEAPON_FLASHLIGHT`, `WEAPON_GOLFCLUB`,
  `WEAPON_HAMMER`, `WEAPON_HATCHET`, `WEAPON_KNUCKLE`, `WEAPON_KNIFE`, `WEAPON_MACHETE`, `WEAPON_SWITCHBLADE`,
  `WEAPON_NIGHTSTICK`, `WEAPON_WRENCH`, `WEAPON_BATTLEAXE`, `WEAPON_POOLCUE`, `WEAPON_STONE_HATCHET`,
  `WEAPON_PISTOL`, `WEAPON_PISTOL_MK2`, `WEAPON_COMBATPISTOL`, `WEAPON_APPISTOL`, `WEAPON_STUNGUN`,
  `WEAPON_PISTOL50`, `WEAPON_SNSPISTOL`, `WEAPON_SNSPISTOL_MK2`, `WEAPON_HEAVYPISTOL`, `WEAPON_VINTAGEPISTOL`,
  `WEAPON_FLAREGUN`, `WEAPON_MARKSMANPISTOL`, `WEAPON_REVOLVER`, `WEAPON_REVOLVER_MK2`, `WEAPON_DOUBLEACTION`,
  `WEAPON_RAYPISTOL`, `WEAPON_CERAMICPISTOL`, `WEAPON_NAVYREVOLVER`, `WEAPON_GADGETPISTOL`, `WEAPON_STUNGUN_MP`,
  `WEAPON_MICROSMG`, `WEAPON_SMG`, `WEAPON_SMG_MK2`, `WEAPON_ASSAULTSMG`, `WEAPON_COMBATPDW`,
  `WEAPON_MACHINEPISTOL`, `WEAPON_MINISMG`, `WEAPON_RAYCARBINE`,
  `WEAPON_PUMPSHOTGUN`, `WEAPON_PUMPSHOTGUN_MK2`, `WEAPON_SAWNOFFSHOTGUN`, `WEAPON_ASSAULTSHOTGUN`,
  `WEAPON_BULLPUPSHOTGUN`, `WEAPON_MUSKET`, `WEAPON_HEAVYSHOTGUN`, `WEAPON_DBSHOTGUN`, `WEAPON_AUTOSHOTGUN`,
  `WEAPON_ASSAULTRIFLE`, `WEAPON_ASSAULTRIFLE_MK2`, `WEAPON_CARBINERIFLE`, `WEAPON_CARBINERIFLE_MK2`,
  `WEAPON_ADVANCEDRIFLE`, `WEAPON_SPECIALCARBINE`, `WEAPON_SPECIALCARBINE_MK2`, `WEAPON_BULLPUPRIFLE`,
  `WEAPON_BULLPUPRIFLE_MK2`, `WEAPON_COMPACTRIFLE`, `WEAPON_MILITARYRIFLE`, `WEAPON_HEAVYRIFLE`, `WEAPON_TACTICALRIFLE`,
  `WEAPON_MG`, `WEAPON_COMBATMG`, `WEAPON_COMBATMG_MK2`, `WEAPON_GUSENBERG`,
  `WEAPON_SNIPERRIFLE`, `WEAPON_HEAVYSNIPER`, `WEAPON_HEAVYSNIPER_MK2`, `WEAPON_MARKSMANRIFLE`, `WEAPON_MARKSMANRIFLE_MK2`,
  `WEAPON_GRENADELAUNCHER`, `WEAPON_RPG`, `WEAPON_MINIGUN`, `WEAPON_FIREWORK`, `WEAPON_RAILGUN`,
  `WEAPON_HOMINGLAUNCHER`, `WEAPON_COMPACTLAUNCHER`, `WEAPON_RAYMINIGUN`,
  `WEAPON_GRENADE`, `WEAPON_BZGAS`, `WEAPON_MOLOTOV`, `WEAPON_STICKYBOMB`, `WEAPON_PROXMINE`,
  `WEAPON_SNOWBALL`, `WEAPON_PIPEBOMB`, `WEAPON_BALL`, `WEAPON_SMOKEGRENADE`, `WEAPON_FLARE`,
  `WEAPON_PETROLCAN`, `WEAPON_FIREEXTINGUISHER`, `WEAPON_HAZARDCAN`, `WEAPON_FERTILIZERCAN`
}

local function reloadAllWeaponsForPed(ped)
  if ped == 0 or not DoesEntityExist(ped) then
    return
  end

  for i = 1, #reloadWeaponHashes do
    local weaponHash = reloadWeaponHashes[i]
    if HasPedGotWeapon(ped, weaponHash, false) then
      local hasMaxAmmo, maxAmmo = GetMaxAmmo(ped, weaponHash)
      local ammoToSet = tonumber(maxAmmo) or 0
      if not hasMaxAmmo or ammoToSet <= 0 then
        ammoToSet = 9999
      end

      SetPedAmmo(ped, weaponHash, ammoToSet)

      local maxClip = tonumber(GetMaxAmmoInClip(ped, weaponHash, true)) or 0
      if maxClip > 0 then
        SetAmmoInClip(ped, weaponHash, maxClip)
      end
    end
  end
end

local function captureCurrentAppearance(ped)
  local data = {
    model = GetEntityModel(ped),
    components = {},
    props = {}
  }

  for componentId = 0, 11 do
    data.components[componentId] = {
      drawable = GetPedDrawableVariation(ped, componentId),
      texture = GetPedTextureVariation(ped, componentId),
      palette = GetPedPaletteVariation(ped, componentId)
    }
  end

  for propId = 0, 7 do
    data.props[propId] = {
      drawable = GetPedPropIndex(ped, propId),
      texture = GetPedPropTextureIndex(ped, propId)
    }
  end

  return data
end

local function applyAppearance(ped, appearance)
  if type(appearance) ~= 'table' then
    return
  end

  for componentId = 0, 11 do
    local component = appearance.components and appearance.components[componentId]
    if component then
      SetPedComponentVariation(
        ped,
        componentId,
        tonumber(component.drawable) or 0,
        tonumber(component.texture) or 0,
        tonumber(component.palette) or 0
      )
    end
  end

  for propId = 0, 7 do
    local prop = appearance.props and appearance.props[propId]
    if prop then
      local drawable = tonumber(prop.drawable) or -1
      local texture = tonumber(prop.texture) or 0
      if drawable >= 0 then
        SetPedPropIndex(ped, propId, drawable, texture, true)
      else
        ClearPedProp(ped, propId)
      end
    end
  end
end

local function applyAdutyOutfit(ped, outfit)
  if type(outfit) ~= 'table' then
    return
  end

  local tshirt = math.max(0, math.floor(tonumber(outfit.tshirt) or 15))
  local top = math.max(0, math.floor(tonumber(outfit.top) or 15))
  local top2 = math.max(0, math.floor(tonumber(outfit.top2) or 0))
  local pants = math.max(0, math.floor(tonumber(outfit.pants) or 14))
  local pants2 = math.max(0, math.floor(tonumber(outfit.pants2) or 0))
  local shoes = math.max(0, math.floor(tonumber(outfit.shoes) or 34))
  local mask = math.floor(tonumber(outfit.mask) or -1)

  SetPedComponentVariation(ped, 8, tshirt, 0, 2)
  SetPedComponentVariation(ped, 11, top, top2, 2)
  SetPedComponentVariation(ped, 4, pants, pants2, 2)
  SetPedComponentVariation(ped, 6, shoes, 0, 2)

  if mask >= 0 then
    SetPedComponentVariation(ped, 1, mask, 0, 2)
  else
    SetPedComponentVariation(ped, 1, 0, 0, 2)
  end
end

local function setAdutyInvincibility(enabled)
  local ped = PlayerPedId()
  if ped == 0 or not DoesEntityExist(ped) then
    return
  end

  local active = enabled == true
  SetPlayerInvincible(PlayerId(), active)
  SetEntityInvincible(ped, active)
  SetEntityCanBeDamaged(ped, not active)
end

local function setUI(state)
  uiOpen = state == true
  SetNuiFocus(uiOpen, uiOpen)
  SendNUIMessage({ action = uiOpen and 'open' or 'close' })
  TriggerServerEvent('rp:admin:panelState', {
    open = uiOpen,
    mode = uiMode
  })
end

RegisterNetEvent('rp:admin:openPanel', function(payload)
  uiMode = 'admin'
  setUI(true)
  SendNUIMessage({ action = 'setData', data = payload })
end)

RegisterNetEvent('rp:admin:updatePanel', function(payload)
  if not uiOpen or uiMode ~= 'admin' then
    return
  end

  uiMode = 'admin'
  SendNUIMessage({ action = 'setData', data = payload })
end)

RegisterNetEvent('rp:admin:openTicketPanel', function(payload)
  uiMode = 'ticket'
  setUI(true)
  SendNUIMessage({ action = 'setData', data = payload })
end)

RegisterNetEvent('rp:admin:updateTicketPanel', function(payload)
  if not uiOpen or uiMode ~= 'ticket' then
    return
  end

  uiMode = 'ticket'
  SendNUIMessage({ action = 'setData', data = payload })
end)

RegisterNetEvent('rp:admin:notifyUi', function(payload)
  SendNUIMessage({ action = 'notify', data = payload })
end)

RegisterNUICallback('admin:close', function(_, cb)
  setUI(false)
  cb({ ok = true })
end)

RegisterNUICallback('admin:action', function(data, cb)
  if type(data) ~= 'table' then
    cb({ ok = false, message = 'Ungültige Anfrage.' })
    return
  end

  data.mode = uiMode
  TriggerServerEvent('rp:admin:nuiAction', data)
  cb({ ok = true })
end)

RegisterNUICallback('admin:getPlayerCoords', function(_, cb)
  local ped = PlayerPedId()
  if ped == 0 or not DoesEntityExist(ped) then
    cb({ ok = false, message = 'Ped nicht gefunden.' })
    return
  end

  local pos = GetEntityCoords(ped)
  local heading = GetEntityHeading(ped)
  cb({
    ok = true,
    coords = {
      x = tonumber(pos.x) or 0.0,
      y = tonumber(pos.y) or 0.0,
      z = tonumber(pos.z) or 0.0,
      h = tonumber(heading) or 0.0
    }
  })
end)

RegisterNetEvent('rp:admin:forceClose', function()
  setUI(false)
end)

local function requestOpen()
  TriggerServerEvent('rp:admin:openRequested')
end

local function requestTicketOpen()
  TriggerServerEvent('rp:admin:openTicketRequested')
end

local function requestCommandSuggestions()
  TriggerServerEvent('rp:admin:requestCommandSuggestions')
end

local function setCommandSuggestions(suggestions)
  if GetRegisteredCommands then
    local commands = GetRegisteredCommands()
    for i = 1, #commands do
      local commandName = commands[i] and commands[i].name
      if type(commandName) == 'string' and commandName ~= '' then
        TriggerEvent('chat:removeSuggestion', '/' .. commandName)
      end
    end
  end

  local nextSuggestions = {}
  if type(suggestions) == 'table' then
    for i = 1, #suggestions do
      local entry = suggestions[i]
      if type(entry) == 'table' and type(entry.name) == 'string' and entry.name ~= '' then
        nextSuggestions[entry.name] = true
      end
    end
  end

  for name, _ in pairs(trackedSuggestions) do
    if not nextSuggestions[name] then
      TriggerEvent('chat:removeSuggestion', name)
      trackedSuggestions[name] = nil
    end
  end

  if type(suggestions) ~= 'table' then
    return
  end

  for i = 1, #suggestions do
    local entry = suggestions[i]
    if type(entry) == 'table' and type(entry.name) == 'string' and entry.name ~= '' then
      TriggerEvent('chat:addSuggestion', entry.name, entry.help or '', entry.params or {})
      trackedSuggestions[entry.name] = true
    end
  end
end

RegisterNetEvent('rp:admin:updateCommandSuggestions', function(suggestions)
  setCommandSuggestions(suggestions)
end)

local function notifyLocal(ntype, title, message)
  TriggerEvent('rp:notify', {
    type = ntype,
    title = title,
    message = message
  })
end

local function rotationToDirection(rot)
  local z = math.rad(rot.z)
  local x = math.rad(rot.x)
  local cosX = math.abs(math.cos(x))
  return vector3(-math.sin(z) * cosX, math.cos(z) * cosX, math.sin(x))
end

local function getNoclipBaseEntity()
  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)
  if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
    return vehicle
  end
  return ped
end

local function setNoclipState(enabled, skipServerNotify)
  noclipEnabled = enabled == true
  local ped = PlayerPedId()

  if noclipEnabled and IsPedInAnyVehicle(ped, false) then
    TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
  end

  local entity = getNoclipBaseEntity()
  SetEntityCollision(entity, not noclipEnabled, not noclipEnabled)
  FreezeEntityPosition(entity, false)
  SetEntityInvincible(entity, noclipEnabled)
  SetEntityVisible(entity, not noclipEnabled, false)
  SetEntityAlpha(entity, noclipEnabled and 0 or 255, false)

  -- Keep player ped visibility in sync too, so no stale invisible state remains.
  SetEntityVisible(ped, not noclipEnabled, false)
  SetEntityAlpha(ped, noclipEnabled and 0 or 255, false)
  if not noclipEnabled and ResetEntityAlpha then
    ResetEntityAlpha(ped)
  end

  if not noclipEnabled and isFrozenByAdmin then
    FreezeEntityPosition(PlayerPedId(), true)
  end

  if skipServerNotify ~= true then
    TriggerServerEvent('rp:admin:noclipStateChanged', { enabled = noclipEnabled })
  end
  if noclipEnabled then
    nextNoclipMapRequestAt = 0
  end
end

local function drawNoclipNametag(ped, text)
  local x, y, z = table.unpack(GetEntityCoords(ped))
  local onScreen, screenX, screenY = World3dToScreen2d(x, y, z + 1.1)
  if not onScreen then
    return
  end

  SetTextScale(0.30, 0.30)
  SetTextFont(4)
  SetTextProportional(true)
  SetTextColour(160, 220, 255, 220)
  SetTextCentre(true)
  SetTextOutline()
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName(text)
  EndTextCommandDisplayText(screenX, screenY)
end

-- Client-side command fallback:
-- Ensures /admin works reliably even if another resource overrides a server command.
RegisterCommand('admin', function()
  requestOpen()
end, false)

RegisterCommand('adminpanel', function()
  requestOpen()
end, false)

RegisterCommand('pcadmin', function()
  requestOpen()
end, false)

RegisterCommand('ticket', function()
  requestTicketOpen()
end, false)

AddEventHandler('onClientResourceStart', function(resourceName)
  if resourceName == 'chat' then
    Wait(400)
    requestCommandSuggestions()
    return
  end

  if resourceName ~= GetCurrentResourceName() then
    return
  end

  Wait(2000)
  requestCommandSuggestions()
end)

RegisterNetEvent('playerSpawned', function()
  Wait(1200)
  requestCommandSuggestions()
end)

RegisterNetEvent('rp:admin:teleport', function(coords)
  if type(coords) ~= 'table' then
    return
  end

  local ped = PlayerPedId()
  local x = tonumber(coords.x) or 0.0
  local y = tonumber(coords.y) or 0.0
  local z = tonumber(coords.z) or 72.0
  local h = tonumber(coords.h) or GetEntityHeading(ped)
  local snapToGround = coords.snapToGround == true

  if snapToGround then
    RequestCollisionAtCoord(x, y, z)
    local timeout = GetGameTimer() + 2500
    while GetGameTimer() < timeout do
      RequestCollisionAtCoord(x, y, z)
      if HasCollisionLoadedAroundEntity(ped) then
        break
      end
      Wait(0)
    end

    local foundGround = false
    local groundZ = z
    for height = 1000.0, 0.0, -25.0 do
      local ok, gz = GetGroundZFor_3dCoord(x, y, height, false)
      if ok then
        groundZ = gz + 1.0
        foundGround = true
        break
      end
    end

    if foundGround and z < groundZ then
      z = groundZ
    end
  end

  SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
  SetEntityHeading(ped, h)
end)

RegisterNetEvent('rp:admin:toggleNoclip', function()
  setNoclipState(not noclipEnabled)
end)

RegisterNetEvent('rp:admin:forceNoclipState', function(payload)
  local enabled = type(payload) == 'table' and payload.enabled == true
  setNoclipState(enabled, true)
end)

RegisterNetEvent('rp:admin:noclipPlayerMap', function(payload)
  if type(payload) ~= 'table' then
    noclipPlayerMap = {}
    return
  end

  noclipPlayerMap = payload
end)

RegisterNetEvent('rp:admin:setAdutyState', function(payload)
  local enabled = type(payload) == 'table' and payload.enabled == true
  local ped = PlayerPedId()

  if enabled then
    if noclipEnabled then
      setNoclipState(false)
    end

    if not adutySavedAppearance then
      adutySavedAppearance = captureCurrentAppearance(ped)
    end

    adutyCurrentOutfit = {
      tshirt = tonumber(payload.outfit and payload.outfit.tshirt) or 15,
      top = tonumber(payload.outfit and payload.outfit.top) or 15,
      top2 = tonumber(payload.outfit and payload.outfit.top2) or 0,
      pants = tonumber(payload.outfit and payload.outfit.pants) or 14,
      pants2 = tonumber(payload.outfit and payload.outfit.pants2) or 0,
      shoes = tonumber(payload.outfit and payload.outfit.shoes) or 34,
      mask = tonumber(payload.outfit and payload.outfit.mask) or -1
    }

    applyAdutyOutfit(ped, adutyCurrentOutfit)
    adutyEnabled = true
    setAdutyInvincibility(true)
    nextAdutyMapRequestAt = 0
    return
  end

  adutyEnabled = false
  if not noclipEnabled then
    setAdutyInvincibility(false)
  end
  adutyCurrentOutfit = nil
  if adutySavedAppearance then
    applyAppearance(ped, adutySavedAppearance)
  end
  adutySavedAppearance = nil
end)

RegisterNetEvent('rp:admin:adutyPlayerMap', function(payload)
  if type(payload) ~= 'table' then
    adutyPlayerMap = {}
    return
  end

  adutyPlayerMap = payload
end)

RegisterNetEvent('rp:admin:toggleNameOverlay', function()
  nameOverlayEnabled = not nameOverlayEnabled
  if nameOverlayEnabled then
    nextNameOverlayMapRequestAt = 0
  else
    nameOverlayPlayerMap = {}
  end

  TriggerServerEvent('rp:admin:nameOverlayStateChanged', { enabled = nameOverlayEnabled })
end)

RegisterNetEvent('rp:admin:forceNameOverlayState', function(payload)
  local enabled = type(payload) == 'table' and payload.enabled == true
  nameOverlayEnabled = enabled
  if enabled then
    nextNameOverlayMapRequestAt = 0
  else
    nameOverlayPlayerMap = {}
  end
end)

RegisterNetEvent('rp:admin:nameOverlayPlayerMap', function(payload)
  if type(payload) ~= 'table' then
    nameOverlayPlayerMap = {}
    return
  end

  nameOverlayPlayerMap = payload
end)

RegisterNetEvent('rp:admin:setFrozenState', function(payload)
  local frozen = false
  if type(payload) == 'table' then
    frozen = payload.frozen == true
  end

  isFrozenByAdmin = frozen
  local ped = PlayerPedId()
  FreezeEntityPosition(ped, frozen)
end)

RegisterNetEvent('rp:admin:requestTeleportToWaypoint', function()
  local waypoint = GetFirstBlipInfoId(8)
  if not waypoint or waypoint == 0 or not DoesBlipExist(waypoint) then
    TriggerServerEvent('rp:admin:tpmResult', {
      ok = false,
      message = 'Kein Wegpunkt gesetzt. Markiere zuerst einen Punkt auf der Karte.'
    })
    return
  end

  local coords = GetBlipInfoIdCoord(waypoint)
  local foundGround = false
  local groundZ = 0.0

  for height = 0.0, 1000.0, 50.0 do
    local ok, z = GetGroundZFor_3dCoord(coords.x, coords.y, height, false)
    if ok then
      groundZ = z + 1.0
      foundGround = true
      break
    end
  end

  if not foundGround then
    groundZ = coords.z + 1.0
  end

  TriggerServerEvent('rp:admin:tpmResult', {
    ok = true,
    x = coords.x,
    y = coords.y,
    z = groundZ
  })
end)

RegisterNetEvent('rp:admin:healPlayer', function()
  local ped = PlayerPedId()
  SetEntityHealth(ped, 200)
  ClearPedBloodDamage(ped)
end)

RegisterNetEvent('rp:admin:reloadWeapons', function()
  local ped = PlayerPedId()
  reloadAllWeaponsForPed(ped)
end)

RegisterNetEvent('rp:admin:giveWeapon', function(payload)
  local weaponName = ''
  if type(payload) == 'table' then
    weaponName = tostring(payload.weaponName or '')
  end

  weaponName = weaponName:upper():gsub('%s+', '_')
  if weaponName ~= '' and weaponName:sub(1, 7) ~= 'WEAPON_' then
    weaponName = 'WEAPON_' .. weaponName
  end

  if weaponName == '' or not weaponName:match('^WEAPON_[A-Z0-9_]+$') then
    TriggerServerEvent('rp:admin:giveWeaponResult', {
      ok = false,
      message = 'Ungültiges Waffenmodell.'
    })
    return
  end

  local weaponHash = GetHashKey(weaponName)
  if not IsWeaponValid(weaponHash) then
    TriggerServerEvent('rp:admin:giveWeaponResult', {
      ok = false,
      message = 'Waffenmodell nicht gefunden.'
    })
    return
  end

  local ped = PlayerPedId()
  GiveWeaponToPed(ped, weaponHash, 250, false, true)
  SetCurrentPedWeapon(ped, weaponHash, true)

  TriggerServerEvent('rp:admin:giveWeaponResult', {
    ok = true
  })
end)

RegisterNetEvent('rp:admin:revivePlayer', function()
  local now = GetGameTimer()
  if now < reviveInProgressUntil then
    return
  end
  reviveInProgressUntil = now + 3500

  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local heading = GetEntityHeading(ped)

  if GetResourceState('rp_spawn') == 'started' then
    TriggerEvent('rp:spawn:forceRevive', {
      coords = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = heading
      }
    })
    return
  end

  local oldPed = ped
  -- leaveDeadPed = false, damit keine tote 1:1-Kopie zurückbleibt.
  NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, 0, false)
  local newPed = PlayerPedId()
  if oldPed ~= 0 and oldPed ~= newPed and DoesEntityExist(oldPed) and NetworkGetPlayerIndexFromPed(oldPed) == -1 then
    SetEntityAsMissionEntity(oldPed, true, true)
    DeleteEntity(oldPed)
  end

  ped = PlayerPedId()
  ClearPedTasksImmediately(ped)
  ClearPedBloodDamage(ped)
  SetEntityHealth(ped, 200)
  FreezeEntityPosition(ped, isFrozenByAdmin)
end)

RegisterNetEvent('rp:admin:repairVehicle', function(payload)
  local actorSource = 0
  if type(payload) == 'table' then
    actorSource = tonumber(payload.actorSource) or 0
  end

  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)
  if vehicle == 0 then
    TriggerServerEvent('rp:admin:repairResult', {
      ok = false,
      actorSource = actorSource,
      message = 'Fahrzeug konnte nicht repariert werden. Der Spieler sitzt in keinem Fahrzeug.'
    })
    return
  end

  SetVehicleFixed(vehicle)
  SetVehicleDeformationFixed(vehicle)
  SetVehicleEngineHealth(vehicle, 1000.0)
  SetVehicleBodyHealth(vehicle, 1000.0)
  SetVehiclePetrolTankHealth(vehicle, 1000.0)
  SetVehicleUndriveable(vehicle, false)
  SetVehicleDirtLevel(vehicle, 0.0)

  TriggerServerEvent('rp:admin:repairResult', {
    ok = true,
    actorSource = actorSource
  })
end)

RegisterNetEvent('rp:admin:spawnCar', function(modelName)
  modelName = tostring(modelName or ''):lower()
  if modelName == '' then
    TriggerServerEvent('rp:admin:carSpawnResult', { ok = false, message = 'Kein Fahrzeugmodell angegeben.' })
    return
  end

  local modelHash = GetHashKey(modelName)
  if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
    TriggerServerEvent('rp:admin:carSpawnResult', { ok = false, message = 'Fahrzeugmodell wurde nicht gefunden.' })
    return
  end

  RequestModel(modelHash)
  local timeout = GetGameTimer() + 8000
  while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
    Wait(50)
  end

  if not HasModelLoaded(modelHash) then
    TriggerServerEvent('rp:admin:carSpawnResult', { ok = false, message = 'Modell konnte nicht geladen werden.' })
    return
  end

  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local heading = GetEntityHeading(ped)

  local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z + 0.3, heading, true, false)
  if vehicle == 0 then
    SetModelAsNoLongerNeeded(modelHash)
    TriggerServerEvent('rp:admin:carSpawnResult', { ok = false, message = 'Fahrzeug konnte nicht erstellt werden.' })
    return
  end

  SetVehicleOnGroundProperly(vehicle)
  SetEntityAsMissionEntity(vehicle, true, true)
  SetPedIntoVehicle(ped, vehicle, -1)
  SetModelAsNoLongerNeeded(modelHash)

  TriggerServerEvent('rp:admin:carSpawnResult', {
    ok = true,
    message = ('Fahrzeug "%s" gespawnt.'):format(modelName)
  })
end)

local function requestEntityControl(entity, timeoutMs)
  timeoutMs = tonumber(timeoutMs) or 300
  if not DoesEntityExist(entity) then
    return false
  end

  local deadline = GetGameTimer() + timeoutMs
  NetworkRequestControlOfEntity(entity)
  while not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
    Wait(0)
    NetworkRequestControlOfEntity(entity)
  end

  return NetworkHasControlOfEntity(entity)
end

local function vehicleHasPlayerOccupant(vehicle)
  if not DoesEntityExist(vehicle) then
    return false
  end

  local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
  for seat = -1, maxSeats do
    local ped = GetPedInVehicleSeat(vehicle, seat)
    if ped and ped ~= 0 and IsPedAPlayer(ped) then
      return true
    end
  end

  return false
end

local function vehicleHasOtherPlayerOccupant(vehicle, selfPed)
  if not DoesEntityExist(vehicle) then
    return false
  end

  local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
  for seat = -1, maxSeats do
    local ped = GetPedInVehicleSeat(vehicle, seat)
    if ped and ped ~= 0 and IsPedAPlayer(ped) and ped ~= selfPed then
      return true
    end
  end

  return false
end

local function tryDeleteVehicleEntity(vehicle, controlTimeoutMs)
  if vehicle == 0 or not DoesEntityExist(vehicle) then
    return false
  end

  if not requestEntityControl(vehicle, controlTimeoutMs or 500) then
    return false
  end

  SetEntityAsMissionEntity(vehicle, true, true)

  -- Mehrere Löschpfade, weil je nach Fahrzeugzustand ein einzelner Call
  -- nicht immer sofort greift.
  DeleteVehicle(vehicle)
  if DoesEntityExist(vehicle) then
    DeleteEntity(vehicle)
  end

  if DoesEntityExist(vehicle) then
    SetEntityAsNoLongerNeeded(vehicle)
    DeleteVehicle(vehicle)
  end

  return not DoesEntityExist(vehicle)
end

RegisterNetEvent('rp:admin:deleteVehiclesInRadius', function(payload)
  local radius = 2.0
  if type(payload) == 'table' then
    radius = tonumber(payload.radius) or radius
  end

  if radius <= 0 then
    radius = 2.0
  elseif radius > 50.0 then
    radius = 50.0
  end

  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local currentVehicle = GetVehiclePedIsIn(ped, false)
  local radiusSq = radius * radius
  local deleted = 0
  local skipped = 0
  local vehicles = GetGamePool('CVehicle')

  -- Eigenes Fahrzeug im Umkreis zuerst behandeln.
  if currentVehicle ~= 0 and DoesEntityExist(currentVehicle) then
    local vCoords = GetEntityCoords(currentVehicle)
    local dx = vCoords.x - coords.x
    local dy = vCoords.y - coords.y
    local dz = vCoords.z - coords.z
    local distSq = (dx * dx) + (dy * dy) + (dz * dz)

    if distSq <= radiusSq then
      if vehicleHasOtherPlayerOccupant(currentVehicle, ped) then
        skipped = skipped + 1
      else
        TaskLeaveVehicle(ped, currentVehicle, 4160)
        local leaveTimeout = GetGameTimer() + 1000
        while GetVehiclePedIsIn(ped, false) == currentVehicle and GetGameTimer() < leaveTimeout do
          Wait(0)
        end

        if GetVehiclePedIsIn(ped, false) == currentVehicle then
          local exitPos = GetOffsetFromEntityInWorldCoords(currentVehicle, 2.2, 0.0, 0.4)
          SetEntityCoordsNoOffset(ped, exitPos.x, exitPos.y, exitPos.z, false, false, false)
          Wait(50)
        end

        if tryDeleteVehicleEntity(currentVehicle, 700) then
          deleted = deleted + 1
          currentVehicle = 0
          coords = GetEntityCoords(ped)
        else
          skipped = skipped + 1
        end
      end
    end
  end

  for i = 1, #vehicles do
    local vehicle = vehicles[i]
    if vehicle ~= 0 and DoesEntityExist(vehicle) and vehicle ~= currentVehicle then
      local vCoords = GetEntityCoords(vehicle)
      local dx = vCoords.x - coords.x
      local dy = vCoords.y - coords.y
      local dz = vCoords.z - coords.z
      local distSq = (dx * dx) + (dy * dy) + (dz * dz)

      if distSq <= radiusSq then
        if vehicleHasOtherPlayerOccupant(vehicle, ped) then
          skipped = skipped + 1
        elseif vehicleHasPlayerOccupant(vehicle) then
          skipped = skipped + 1
        elseif tryDeleteVehicleEntity(vehicle, 500) then
          deleted = deleted + 1
        else
          skipped = skipped + 1
        end
      end
    end
  end

  TriggerServerEvent('rp:admin:deleteVehiclesResult', {
    radius = radius,
    deleted = deleted,
    skipped = skipped
  })
end)

CreateThread(function()
  while true do
    if isFrozenByAdmin then
      local ped = PlayerPedId()
      if not IsEntityPositionFrozen(ped) then
        FreezeEntityPosition(ped, true)
      end
      DisableControlAction(0, 30, true) -- MoveLeftRight
      DisableControlAction(0, 31, true) -- MoveUpDown
      DisableControlAction(0, 21, true) -- Sprint
      DisableControlAction(0, 22, true) -- Jump
      DisableControlAction(0, 24, true) -- Attack
      DisableControlAction(0, 25, true) -- Aim
      DisableControlAction(0, 75, true) -- Exit vehicle
      DisableControlAction(0, 140, true) -- Melee light
      DisableControlAction(0, 141, true) -- Melee heavy
      DisableControlAction(0, 142, true) -- Melee alternate
      DisableControlAction(0, 257, true) -- Attack 2
      DisableControlAction(0, 263, true) -- Melee attack
      Wait(0)
    else
      Wait(500)
    end
  end
end)

CreateThread(function()
  while true do
    if noclipEnabled then
      local now = GetGameTimer()
      if now >= nextNoclipMapRequestAt then
        nextNoclipMapRequestAt = now + 4000
        TriggerServerEvent('rp:admin:noclipRequestPlayerMap')
      end

      local entity = getNoclipBaseEntity()
      local ped = PlayerPedId()
      local camRot = GetGameplayCamRot(2)
      local forward = rotationToDirection(camRot)
      local right = vector3(forward.y, -forward.x, 0.0)
      local move = vector3(0.0, 0.0, 0.0)

      if IsControlJustPressed(0, 241) then
        noclipSpeedIndex = math.min(#noclipSpeeds, noclipSpeedIndex + 1)
      elseif IsControlJustPressed(0, 242) then
        noclipSpeedIndex = math.max(1, noclipSpeedIndex - 1)
      end

      local speed = noclipSpeeds[noclipSpeedIndex]
      if IsControlPressed(0, 21) then
        speed = speed * 2.8
      end

      if IsControlPressed(0, 32) then move = move + forward end -- W
      if IsControlPressed(0, 33) then move = move - forward end -- S
      if IsControlPressed(0, 35) then move = move + right end -- D
      if IsControlPressed(0, 34) then move = move - right end -- A
      if IsControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end -- SPACE
      if IsControlPressed(0, 36) then move = move - vector3(0.0, 0.0, 1.0) end -- CTRL

      local pos = GetEntityCoords(entity)
      local nextPos = pos + (move * speed)

      SetEntityVelocity(entity, 0.0, 0.0, 0.0)
      SetEntityCoordsNoOffset(entity, nextPos.x, nextPos.y, nextPos.z, false, false, false)
      SetEntityCollision(entity, false, false)
      SetEntityInvincible(entity, true)
      SetEntityVisible(entity, false, false)
      SetEntityAlpha(entity, 0, false)
      SetEntityHeading(entity, camRot.z)

      DisableControlAction(0, 24, true) -- Attack
      DisableControlAction(0, 25, true) -- Aim
      DisableControlAction(0, 37, true) -- Weapon wheel
      DisableControlAction(0, 44, true) -- Cover
      DisableControlAction(0, 75, true) -- Exit vehicle
      DisableControlAction(0, 140, true) -- Melee light
      DisableControlAction(0, 141, true) -- Melee heavy
      DisableControlAction(0, 142, true) -- Melee alternate

      local myPos = GetEntityCoords(ped)
      local activePlayers = GetActivePlayers()
      for i = 1, #activePlayers do
        local player = activePlayers[i]
        if player ~= PlayerId() then
          local targetPed = GetPlayerPed(player)
          if targetPed ~= 0 and DoesEntityExist(targetPed) then
            local dist = #(myPos - GetEntityCoords(targetPed))
            if dist <= 100.0 then
              local serverId = GetPlayerServerId(player)
              local info = noclipPlayerMap[tostring(serverId)] or {}
              local profileName = tostring(info.profileName or GetPlayerName(player) or ('Spieler ' .. tostring(serverId)))
              local userId = tostring(info.userId or '?')
              drawNoclipNametag(targetPed, ('%s (%s | %s)'):format(profileName, tostring(serverId), userId))
            end
          end
        end
      end

      Wait(0)
    else
      Wait(400)
    end
  end
end)

CreateThread(function()
  while true do
    if nameOverlayEnabled and not noclipEnabled and not adutyEnabled then
      local now = GetGameTimer()
      if now >= nextNameOverlayMapRequestAt then
        nextNameOverlayMapRequestAt = now + 4000
        TriggerServerEvent('rp:admin:nameOverlayRequestPlayerMap')
      end

      local ped = PlayerPedId()
      local myPos = GetEntityCoords(ped)
      local activePlayers = GetActivePlayers()
      for i = 1, #activePlayers do
        local player = activePlayers[i]
        if player ~= PlayerId() then
          local targetPed = GetPlayerPed(player)
          if targetPed ~= 0 and DoesEntityExist(targetPed) then
            local dist = #(myPos - GetEntityCoords(targetPed))
            if dist <= 100.0 then
              local serverId = GetPlayerServerId(player)
              local info = nameOverlayPlayerMap[tostring(serverId)] or {}
              local profileName = tostring(info.profileName or GetPlayerName(player) or ('Spieler ' .. tostring(serverId)))
              local userId = tostring(info.userId or '?')
              drawNoclipNametag(targetPed, ('%s (%s | %s)'):format(profileName, tostring(serverId), userId))
            end
          end
        end
      end

      Wait(0)
    else
      Wait(500)
    end
  end
end)

CreateThread(function()
  while true do
    if adutyEnabled then
      setAdutyInvincibility(true)

      local now = GetGameTimer()
      if now >= nextAdutyMapRequestAt then
        nextAdutyMapRequestAt = now + 4000
        TriggerServerEvent('rp:admin:adutyRequestPlayerMap')
      end

      local ped = PlayerPedId()
      local myPos = GetEntityCoords(ped)
      local activePlayers = GetActivePlayers()
      for i = 1, #activePlayers do
        local player = activePlayers[i]
        if player ~= PlayerId() then
          local targetPed = GetPlayerPed(player)
          if targetPed ~= 0 and DoesEntityExist(targetPed) then
            local dist = #(myPos - GetEntityCoords(targetPed))
            if dist <= 100.0 then
              local serverId = GetPlayerServerId(player)
              local info = adutyPlayerMap[tostring(serverId)] or {}
              local profileName = tostring(info.profileName or GetPlayerName(player) or ('Spieler ' .. tostring(serverId)))
              local userId = tostring(info.userId or '?')
              drawNoclipNametag(targetPed, ('%s (%s | %s)'):format(profileName, tostring(serverId), userId))
            end
          end
        end
      end

      Wait(0)
    else
      Wait(500)
    end
  end
end)

RegisterNetEvent('playerSpawned', function()
  local ped = PlayerPedId()
  if not noclipEnabled then
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    if ResetEntityAlpha then
      ResetEntityAlpha(ped)
    end
  end

  if not adutyEnabled then
    return
  end

  Wait(350)
  ped = PlayerPedId()
  setAdutyInvincibility(true)
  if adutyCurrentOutfit then
    applyAdutyOutfit(ped, adutyCurrentOutfit)
  end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  if noclipEnabled then
    local entity = getNoclipBaseEntity()
    SetEntityCollision(entity, true, true)
    SetEntityInvincible(entity, false)
    SetEntityVisible(entity, true, false)
    SetEntityAlpha(entity, 255, false)
    noclipEnabled = false
  end

  if adutyEnabled and adutySavedAppearance then
    local ped = PlayerPedId()
    applyAppearance(ped, adutySavedAppearance)
  end

  if adutyEnabled and not noclipEnabled then
    setAdutyInvincibility(false)
  end
end)
