local open = false
local activeDrops = {}

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

CreateThread(function()
  Wait(3000)
  TriggerServerEvent('rp:inventory:requestDrops')
end)

AddEventHandler('playerSpawned', function()
  Wait(1200)
  TriggerServerEvent('rp:inventory:requestDrops')
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
