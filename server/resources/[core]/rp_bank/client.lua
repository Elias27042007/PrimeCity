local uiOpen = false
local bankBlips = {}

local function registerBankPoints()
  for i = 1, #RPBankConfig.banks do
    local bank = RPBankConfig.banks[i]
    exports.rp_interactions:RegisterPoint({
      id = ('rp_bank_%s'):format(bank.id),
      label = bank.label,
      coords = bank.coords,
      distance = 18.0,
      interactDistance = RPBankConfig.interactionDistance,
      trigger = 'rp:bank:open',
      triggerType = 'client',
      args = { bankId = bank.id }
    })
  end
end

local function createBankBlips()
  if not RPBankConfig.blip or not RPBankConfig.blip.enabled then
    return
  end

  for i = 1, #RPBankConfig.banks do
    local bank = RPBankConfig.banks[i]
    local blip = AddBlipForCoord(bank.coords.x, bank.coords.y, bank.coords.z)
    SetBlipSprite(blip, RPBankConfig.blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, RPBankConfig.blip.scale)
    SetBlipColour(blip, RPBankConfig.blip.color)
    SetBlipAsShortRange(blip, RPBankConfig.blip.shortRange == true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Bank')
    EndTextCommandSetBlipName(blip)
    bankBlips[#bankBlips + 1] = blip
  end
end

CreateThread(function()
  Wait(2000)
  registerBankPoints()
  createBankBlips()
end)

RegisterNetEvent('rp:bank:open', function(args)
  TriggerServerEvent('rp:bank:requestOpen', args and args.bankId or nil)
end)

RegisterNetEvent('rp:bank:openUI', function(payload)
  uiOpen = true
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'open', data = payload })
end)

RegisterNetEvent('rp:bank:updateUI', function(payload)
  SendNUIMessage({ action = 'update', data = payload })
end)

RegisterNetEvent('rp:bank:closeUI', function()
  uiOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end)

RegisterNUICallback('bank:close', function(_, cb)
  uiOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  TriggerServerEvent('rp:bank:close')
  cb({ ok = true })
end)

RegisterNUICallback('bank:deposit', function(data, cb)
  TriggerServerEvent('rp:bank:deposit', tonumber(data.amount or 0))
  cb({ ok = true })
end)

RegisterNUICallback('bank:withdraw', function(data, cb)
  TriggerServerEvent('rp:bank:withdraw', tonumber(data.amount or 0))
  cb({ ok = true })
end)

RegisterNUICallback('bank:transfer', function(data, cb)
  TriggerServerEvent('rp:bank:transfer', {
    amount = tonumber(data.amount or 0),
    mode = tostring(data.mode or 'serverid'),
    target = tostring(data.target or '')
  })
  cb({ ok = true })
end)
