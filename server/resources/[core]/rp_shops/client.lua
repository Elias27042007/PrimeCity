local registered = false
local shopBlips = {}

local function getShopBlipGroupLabel(shop)
  local shopType = tostring(shop and shop.type or ''):lower()
  if shopType == '24_7' then
    return '24/7 Shop'
  end
  if shopType == 'clothing' then
    return 'Kleidung'
  end
  if shopType == 'vehicle' then
    return 'Autohaus'
  end
  return 'Shop'
end

local function registerShopPoints(shops)
  for i = 1, #shops do
    local shop = shops[i]
    exports.rp_interactions:RegisterPoint({
      id = ('rp_shop_%s'):format(shop.id),
      label = ('[E] %s'):format(shop.label),
      coords = vector3(shop.x + 0.0, shop.y + 0.0, shop.z + 0.0),
      distance = RPShopsConfig.drawDistance,
      interactDistance = RPShopsConfig.interactDistance,
      trigger = 'rp:shops:open',
      triggerType = 'client',
      args = { shopId = shop.id }
    })
  end

  registered = true
end

local function createShopBlips(shops)
  if not RPShopsConfig.blip or not RPShopsConfig.blip.enabled then
    return
  end

  for i = 1, #shops do
    local shop = shops[i]
    if shop.blipEnabled == false then
      goto continue
    end

    local blip = AddBlipForCoord(shop.x + 0.0, shop.y + 0.0, shop.z + 0.0)
    SetBlipSprite(blip, RPShopsConfig.blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, RPShopsConfig.blip.scale)
    SetBlipColour(blip, RPShopsConfig.blip.color)
    SetBlipAsShortRange(blip, RPShopsConfig.blip.shortRange == true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(getShopBlipGroupLabel(shop))
    EndTextCommandSetBlipName(blip)
    shopBlips[#shopBlips + 1] = blip

    ::continue::
  end
end

CreateThread(function()
  Wait(2500)
  TriggerServerEvent('rp:shops:requestPoints')
end)

RegisterNetEvent('rp:shops:receivePoints', function(shops)
  if registered then return end
  registerShopPoints(shops or {})
  createShopBlips(shops or {})
end)

RegisterNetEvent('rp:shops:open', function(args)
  TriggerServerEvent('rp:shops:requestOpen', args and args.shopId or 0)
end)

RegisterNetEvent('rp:shops:openUI', function(payload)
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'open', data = payload })
end)

RegisterNetEvent('rp:shops:closeUI', function()
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end)

RegisterNUICallback('shop:close', function(_, cb)
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  TriggerServerEvent('rp:shops:close')
  cb({ ok = true })
end)

RegisterNUICallback('shop:buy', function(data, cb)
  TriggerServerEvent('rp:shops:buyItem', {
    itemName = tostring(data.itemName or ''),
    quantity = tonumber(data.quantity or 1),
    payType = tostring(data.payType or 'cash')
  })
  cb({ ok = true })
end)
