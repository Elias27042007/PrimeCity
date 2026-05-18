local open = false

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

RegisterNUICallback('inventory:close', function(_, cb)
  open = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  TriggerServerEvent('rp:inventory:close')
  cb({ ok = true })
end)

RegisterNUICallback('inventory:useItem', function(data, cb)
  TriggerServerEvent('rp:inventory:useItem', tostring(data.itemName or ''))
  cb({ ok = true })
end)
