local open = false
local activeDrops = {}
local weaponItemModels = {
  weapon_bat = 'WEAPON_BAT',
  weapon_carbinerifle_mk2 = 'WEAPON_CARBINERIFLE_MK2',
  weapon_ceramicpistol = 'WEAPON_CERAMICPISTOL',
  weapon_combat_knife = 'WEAPON_KNIFE',
  weapon_compactrifle = 'WEAPON_COMPACTRIFLE',
  weapon_dagger = 'WEAPON_DAGGER',
  weapon_doubleaction = 'WEAPON_DOUBLEACTION',
  weapon_fireextinguisher = 'WEAPON_FIREEXTINGUISHER',
  weapon_flashbang = 'WEAPON_FLASHBANG',
  weapon_flashlight = 'WEAPON_FLASHLIGHT',
  weapon_gadgetpistol = 'WEAPON_GADGETPISTOL',
  weapon_gas = 'WEAPON_BZGAS',
  weapon_glock19 = 'WEAPON_GLOCK19',
  weapon_goodnightbat = 'WEAPON_GOODNIGHTBAT',
  weapon_knuckle = 'WEAPON_KNUCKLE',
  weapon_m45a1 = 'WEAPON_M45A1',
  weapon_machete = 'WEAPON_MACHETE',
  weapon_marksmanrifle_mk2 = 'WEAPON_MARKSMANRIFLE_MK2',
  weapon_microsmg = 'WEAPON_MICROSMG',
  weapon_navyrevolver = 'WEAPON_NAVYREVOLVER',
  weapon_nightstick = 'WEAPON_NIGHTSTICK',
  weapon_pistol = 'WEAPON_PISTOL',
  weapon_pistol2 = 'WEAPON_COMBATPISTOL',
  weapon_pistol_mk2 = 'WEAPON_PISTOL_MK2',
  weapon_pistol_mk2_2 = 'WEAPON_PISTOL_MK2',
  weapon_pistol_wm29 = 'WEAPON_PISTOL_WM29',
  weapon_revolver = 'WEAPON_REVOLVER',
  weapon_revolver_mk2 = 'WEAPON_REVOLVER_MK2',
  weapon_sawnoffshotgun = 'WEAPON_SAWNOFFSHOTGUN',
  weapon_smg = 'WEAPON_SMG',
  weapon_smokegrenade = 'WEAPON_SMOKEGRENADE',
  weapon_sniperrifle = 'WEAPON_SNIPERRIFLE',
  weapon_specialcarbine = 'WEAPON_SPECIALCARBINE',
  weapon_specialcarbine_mk2 = 'WEAPON_SPECIALCARBINE_MK2',
  weapon_stungun = 'WEAPON_STUNGUN',
  weapon_stungun_blue = 'WEAPON_STUNGUN',
  weapon_stungun_red = 'WEAPON_STUNGUN',
  weapon_stungun_yellow = 'WEAPON_STUNGUN',
  weapon_switchblade = 'WEAPON_SWITCHBLADE',
  weapon_switchblade2 = 'WEAPON_SWITCHBLADE',
  weapon_ump45 = 'WEAPON_UMP45',
  weapon_vector = 'WEAPON_VECTOR',
  weapon_vintagepistol = 'WEAPON_VINTAGEPISTOL'
}

local function notifyLocal(ntype, message)
  TriggerEvent('rp:notify', {
    type = ntype or 'info',
    title = 'Inventar',
    message = tostring(message or '')
  })
end

local function toWeaponModelFromItem(itemName)
  local key = tostring(itemName or ''):lower():gsub('%s+', '_')
  if key == '' then
    return nil
  end
  local mapped = weaponItemModels[key]
  if mapped and mapped ~= '' then
    return mapped
  end
  local value = key:upper()
  if value:sub(1, 7) ~= 'WEAPON_' then
    value = 'WEAPON_' .. value
  end
  if not value:match('^WEAPON_[A-Z0-9_]+$') then
    return nil
  end
  return value
end

local function closeInventoryUiIfOpen()
  if not open then
    return
  end

  open = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  TriggerServerEvent('rp:inventory:close')
end

local function equipWeaponWithRetry(ped, weaponHash, ammo)
  ammo = math.max(1, math.floor(tonumber(ammo) or 1))

  for _ = 1, 12 do
    GiveWeaponToPed(ped, weaponHash, ammo, false, true)
    SetPedAmmo(ped, weaponHash, ammo)
    SetAmmoInClip(ped, weaponHash, math.max(1, math.min(ammo, 250)))
    SetPedCanSwitchWeapon(ped, true)
    SetCurrentPedWeapon(ped, weaponHash, true)

    if HasPedGotWeapon(ped, weaponHash, false) then
      return true
    end

    Wait(120)
  end

  return HasPedGotWeapon(ped, weaponHash, false)
end

local function syncWeaponsFromInventory(payload)
  local ped = PlayerPedId()
  if ped == 0 or not DoesEntityExist(ped) then
    return
  end

  local owned = {}
  if type(payload) == 'table' and type(payload.items) == 'table' then
    for i = 1, #payload.items do
      local itemName = tostring(payload.items[i] or ''):lower()
      if itemName ~= '' then
        owned[itemName] = true
      end
    end
  end

  for itemName, modelName in pairs(weaponItemModels) do
    local weaponHash = GetHashKey(modelName)
    local shouldOwn = owned[itemName] == true
    local hasWeapon = HasPedGotWeapon(ped, weaponHash, false)

    if shouldOwn and not hasWeapon then
      GiveWeaponToPed(ped, weaponHash, 250, false, false)
      SetPedAmmo(ped, weaponHash, math.max(GetAmmoInPedWeapon(ped, weaponHash), 250))
    elseif (not shouldOwn) and hasWeapon then
      RemoveWeaponFromPed(ped, weaponHash)
    end
  end

  SetPedCanSwitchWeapon(ped, true)
end

local function normalizeDrops(payload)
  activeDrops = {}
  if type(payload) ~= 'table' then
    return
  end

  for i = 1, #payload do
    local entry = payload[i]
    if type(entry) == 'table' and tonumber(entry.id) then
      activeDrops[tonumber(entry.id)] = {
        id = tonumber(entry.id),
        label = tostring(entry.label or entry.itemName or 'Item'),
        quantity = math.floor(tonumber(entry.quantity) or 1),
        coords = vector3(tonumber(entry.x) or 0.0, tonumber(entry.y) or 0.0, tonumber(entry.z) or 0.0)
      }
    end
  end
end

RegisterCommand('+rp_inventory_open', function()
  if open then return end
  TriggerServerEvent('rp:inventory:requestOpen')
end, false)

RegisterCommand('-rp_inventory_open', function()
  -- Required counterpart for FiveM key mapping commands starting with '+'.
end, false)

RegisterKeyMapping('+rp_inventory_open', 'RP Inventar öffnen', 'keyboard', 'F2')

RegisterNetEvent('rp:inventory:openUI', function(payload)
  open = true
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'open', data = payload })
end)

RegisterNetEvent('rp:inventory:updateUI', function(payload)
  SendNUIMessage({ action = 'update', data = payload })
end)

RegisterNetEvent('rp:inventory:closeUI', function()
  open = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end)

RegisterNetEvent('rp:inventory:updateDrops', function(payload)
  normalizeDrops(payload)
end)

RegisterNetEvent('rp:inventory:syncWeapons', function(payload)
  syncWeaponsFromInventory(payload)
end)

RegisterNetEvent('rp:inventory:itemUsed', function(itemName, quantity)
  itemName = tostring(itemName or ''):lower()
  if itemName:sub(1, 7) ~= 'weapon_' then
    return
  end

  closeInventoryUiIfOpen()

  local modelName = toWeaponModelFromItem(itemName)
  if not modelName then
    notifyLocal('error', 'Ungültiges Waffen-Item.')
    return
  end

  local weaponHash = GetHashKey(modelName)
  local ped = PlayerPedId()
  local ammo = math.max(1, math.floor(tonumber(quantity) or 1))
  if ammo < 30 then
    ammo = 250
  end

  local equipped = equipWeaponWithRetry(ped, weaponHash, ammo)
  if not equipped then
    notifyLocal('error', ('Waffenmodell konnte nicht ausgerüstet werden: %s'):format(modelName))
    return
  end

  notifyLocal('success', ('Waffe ausgerüstet: %s'):format(modelName))
end)

CreateThread(function()
  Wait(3000)
  TriggerServerEvent('rp:inventory:requestDrops')
  TriggerServerEvent('rp:inventory:requestWeaponSync')
end)

AddEventHandler('playerSpawned', function()
  Wait(1200)
  TriggerServerEvent('rp:inventory:requestDrops')
  TriggerServerEvent('rp:inventory:requestWeaponSync')
end)

RegisterNUICallback('inventory:close', function(_, cb)
  open = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  TriggerServerEvent('rp:inventory:close')
  cb({ ok = true })
end)

RegisterNUICallback('inventory:useItem', function(data, cb)
  TriggerServerEvent('rp:inventory:useItem', tostring(data.itemName or ''), tonumber(data.quantity or 1) or 1)
  cb({ ok = true })
end)

RegisterNUICallback('inventory:giveItem', function(data, cb)
  TriggerServerEvent('rp:inventory:giveItem', {
    itemName = tostring(data.itemName or ''),
    quantity = tonumber(data.quantity or 1) or 1,
    targetId = tonumber(data.targetId or 0) or 0
  })
  cb({ ok = true })
end)

RegisterNUICallback('inventory:dropItem', function(data, cb)
  TriggerServerEvent('rp:inventory:dropItem', {
    itemName = tostring(data.itemName or ''),
    quantity = tonumber(data.quantity or 1) or 1
  })
  cb({ ok = true })
end)

RegisterNUICallback('inventory:getNearbyPlayers', function(_, cb)
  local me = PlayerPedId()
  local myCoords = GetEntityCoords(me)
  local result = {}

  for _, player in ipairs(GetActivePlayers()) do
    if player ~= PlayerId() then
      local ped = GetPlayerPed(player)
      if ped and ped ~= 0 and DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local distance = #(myCoords - coords)
        if distance <= (RPInventoryConfig.giveDistance or 4.0) then
          result[#result + 1] = {
            id = GetPlayerServerId(player),
            name = GetPlayerName(player) or ('Spieler %s'):format(GetPlayerServerId(player)),
            distance = math.floor((distance * 10.0) + 0.5) / 10.0
          }
        end
      end
    end
  end

  table.sort(result, function(a, b)
    return (a.distance or 0) < (b.distance or 0)
  end)

  cb({
    ok = true,
    players = result
  })
end)

CreateThread(function()
  while true do
    local sleep = 900
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local nearestId = nil
    local nearestDist = 9999.0

    for dropId, drop in pairs(activeDrops) do
      local dist = #(coords - drop.coords)
      if dist <= (RPInventoryConfig.dropRenderDistance or 22.0) then
        sleep = 5
        DrawMarker(
          2,
          drop.coords.x,
          drop.coords.y,
          drop.coords.z + 0.18,
          0.0, 0.0, 0.0,
          0.0, 0.0, 0.0,
          0.2, 0.2, 0.2,
          57, 208, 255, 185,
          false,
          true,
          2,
          false,
          nil,
          nil,
          false
        )

        if dist <= (RPInventoryConfig.pickupDistance or 2.2) and dist < nearestDist then
          nearestDist = dist
          nearestId = dropId
        end
      end
    end

    if nearestId then
      local drop = activeDrops[nearestId]
      if drop then
        SetTextScale(0.32, 0.32)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(235, 240, 255, 220)
        SetTextEntry('STRING')
        SetTextCentre(1)
        AddTextComponentString(('[E] %sx %s aufheben'):format(drop.quantity, drop.label))
        local onScreen, x, y = World3dToScreen2d(drop.coords.x, drop.coords.y, drop.coords.z + 0.38)
        if onScreen then
          DrawText(x, y)
        end

        if IsControlJustReleased(0, 38) then
          TriggerServerEvent('rp:inventory:pickupDrop', nearestId)
        end
      end
    end

    Wait(sleep)
  end
end)
