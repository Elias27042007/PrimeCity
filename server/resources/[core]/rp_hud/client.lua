local visible = true
local editing = false
local layoutApplied = false
local hudSuggestionActive = false
local hiddenByPauseMenu = false
local playerData = {
  fullName = 'Unbekannt',
  cash = 0,
  bank = 0,
  job = 'Arbeitslos',
  onDuty = false,
  time = '00:00'
}

local function pushHud()
  SendNUIMessage({
    action = 'updateHud',
    data = playerData
  })
end

local function setHudEditMode(state)
  editing = state == true
  SetNuiFocus(editing, editing)
  SetNuiFocusKeepInput(false)
  SendNUIMessage({
    action = 'setEditMode',
    data = { enabled = editing }
  })
end

local function applyHudVisibility()
  local shouldShow = visible and (not hiddenByPauseMenu)
  SendNUIMessage({ action = shouldShow and 'show' or 'hide' })
end

local function registerHudSuggestion()
  if hudSuggestionActive then
    return
  end

  TriggerEvent('chat:addSuggestion', '/hud', 'Öffnet den HUD-Editor.', {})
  hudSuggestionActive = true
end

local function unregisterHudSuggestion()
  if not hudSuggestionActive then
    return
  end

  TriggerEvent('chat:removeSuggestion', '/hud')
  hudSuggestionActive = false
end

RegisterNetEvent('rp:hud:toggle', function(state)
  visible = state == true
  applyHudVisibility()
end)

RegisterNetEvent('rp:hud:applyLayout', function(layout)
  if type(layout) ~= 'table' then
    return
  end

  layoutApplied = true
  SendNUIMessage({
    action = 'setLayout',
    data = {
      x = tonumber(layout.x),
      y = tonumber(layout.y)
    }
  })
end)

RegisterNetEvent('rp:hud:updateCharacter', function(character)
  if type(character) ~= 'table' then return end
  playerData.fullName = character.fullName or playerData.fullName
  pushHud()
end)

RegisterNetEvent('rp:hud:updateMoney', function(money)
  if type(money) ~= 'table' then return end
  playerData.cash = tonumber(money.cash) or playerData.cash
  playerData.bank = tonumber(money.bank) or playerData.bank
  pushHud()
end)

RegisterNetEvent('rp:hud:updateJob', function(job)
  if type(job) ~= 'table' then return end
  playerData.job = job.label or playerData.job
  playerData.onDuty = job.onDuty == true
  pushHud()
end)

RegisterNUICallback('hud:saveLayout', function(data, cb)
  TriggerServerEvent('rp:hud:saveLayout', data)
  cb({ ok = true })
end)

RegisterNUICallback('hud:exitEdit', function(data, cb)
  if type(data) == 'table' then
    TriggerServerEvent('rp:hud:saveLayout', data)
  end
  setHudEditMode(false)
  cb({ ok = true })
end)

RegisterCommand('hud', function()
  setHudEditMode(true)
end, false)

AddEventHandler('onClientResourceStart', function(resourceName)
  if resourceName == 'chat' then
    Wait(250)
    registerHudSuggestion()
    return
  end

  if resourceName ~= GetCurrentResourceName() then
    return
  end

  Wait(250)
  registerHudSuggestion()
end)

AddEventHandler('onClientResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  unregisterHudSuggestion()
end)

RegisterNetEvent('rp:core:setCharacterData', function()
  layoutApplied = false
  SetTimeout(400, function()
    TriggerServerEvent('rp:hud:requestLayout')
  end)
end)

CreateThread(function()
  Wait(2500)
  TriggerServerEvent('rp:hud:requestLayout')

  CreateThread(function()
    for _ = 1, 12 do
      Wait(1000)
      if layoutApplied then
        break
      end
      TriggerServerEvent('rp:hud:requestLayout')
    end
  end)

  while true do
    Wait(RPHudConfig.clockIntervalMs)
    local hour = GetClockHours()
    local minute = GetClockMinutes()
    playerData.time = ('%02d:%02d'):format(hour, minute)
    pushHud()
  end
end)

CreateThread(function()
  DisplayCash(false)
  DisplayRadar(true)

  while true do
    Wait(0)
    HideHudComponentThisFrame(3)
    HideHudComponentThisFrame(4)
    HideHudComponentThisFrame(13)
  end
end)

CreateThread(function()
  while true do
    Wait(120)
    local paused = IsPauseMenuActive()
    if paused ~= hiddenByPauseMenu then
      hiddenByPauseMenu = paused
      applyHudVisibility()
    end
  end
end)

CreateThread(function()
  while true do
    Wait(RPHudConfig.updateIntervalMs)

    if visible and (not hiddenByPauseMenu) then
      local ped = PlayerPedId()
      local vehicle = GetVehiclePedIsIn(ped, false)
      if vehicle ~= 0 then
        local speed = GetEntitySpeed(vehicle) * 3.6
        local gear = GetVehicleCurrentGear(vehicle)
        local engine = GetIsVehicleEngineRunning(vehicle)
        local fuel = RPHudConfig.showVehicleFuel and GetVehicleFuelLevel(vehicle) or nil

        SendNUIMessage({
          action = 'updateVehicle',
          data = {
            inVehicle = true,
            speed = math.floor(speed + 0.5),
            gear = gear,
            engine = engine,
            fuel = fuel
          }
        })
      else
        SendNUIMessage({
          action = 'updateVehicle',
          data = { inVehicle = false }
        })
      end
    else
      SendNUIMessage({
        action = 'updateVehicle',
        data = { inVehicle = false }
      })
    end
  end
end)
