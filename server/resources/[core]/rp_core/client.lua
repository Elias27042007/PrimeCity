local hasSignaledReady = false
local LocalCharacter = nil
local clockSync = {
  active = false,
  hour = 12,
  minute = 0,
  second = 0,
  lastUpdateAt = 0
}

local function signalReady()
  if hasSignaledReady then
    return
  end

  hasSignaledReady = true
  TriggerServerEvent('rp:core:playerReady')
end

CreateThread(function()
  while not NetworkIsSessionStarted() do
    Wait(250)
  end

  Wait(1500)
  signalReady()
end)

AddEventHandler('playerSpawned', function()
  signalReady()
end)

RegisterNetEvent('rp:core:setCharacterData', function(character)
  LocalCharacter = character
end)

RegisterNetEvent('rp:core:syncClock', function(payload)
  if type(payload) ~= 'table' then
    return
  end

  local hour = math.floor(tonumber(payload.hour) or -1)
  local minute = math.floor(tonumber(payload.minute) or -1)
  local second = math.floor(tonumber(payload.second) or -1)

  if hour < 0 or minute < 0 or second < 0 then
    return
  end

  clockSync.hour = hour % 24
  clockSync.minute = minute % 60
  clockSync.second = second % 60
  clockSync.lastUpdateAt = GetGameTimer()
  clockSync.active = true

  NetworkOverrideClockTime(clockSync.hour, clockSync.minute, clockSync.second)
end)

local function requestClockSync()
  TriggerServerEvent('rp:core:requestTimeSync')
end

CreateThread(function()
  while not NetworkIsSessionStarted() do
    Wait(250)
  end

  Wait(1000)
  requestClockSync()
end)

CreateThread(function()
  local interval = 60000
  if RPCoreConfig.timeSync and tonumber(RPCoreConfig.timeSync.clientResyncIntervalMs) then
    interval = math.max(5000, math.floor(tonumber(RPCoreConfig.timeSync.clientResyncIntervalMs)))
  end

  while true do
    Wait(interval)
    requestClockSync()
  end
end)

CreateThread(function()
  local interval = 250
  if RPCoreConfig.timeSync and tonumber(RPCoreConfig.timeSync.clientOverrideIntervalMs) then
    interval = math.max(50, math.floor(tonumber(RPCoreConfig.timeSync.clientOverrideIntervalMs)))
  end

  while true do
    Wait(interval)

    if clockSync.active then
      NetworkOverrideClockTime(clockSync.hour, clockSync.minute, clockSync.second)

      local staleMs = GetGameTimer() - (clockSync.lastUpdateAt or 0)
      if staleMs > 3500 then
        requestClockSync()
      end
    end
  end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  Wait(800)
  requestClockSync()
end)

exports('GetLocalCharacter', function()
  return LocalCharacter
end)
