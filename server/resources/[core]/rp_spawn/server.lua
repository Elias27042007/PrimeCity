local LastSave = {}

local function validCoord(coords)
  if type(coords) ~= 'table' then return false end
  local x = tonumber(coords.x)
  local y = tonumber(coords.y)
  local z = tonumber(coords.z)
  if not x or not y or not z then
    return false
  end

  if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 10000 then
    return false
  end

  return true
end

RegisterNetEvent('rp:spawn:updatePosition', function(coords)
  local src = source
  local now = GetGameTimer()
  if LastSave[src] and now < LastSave[src] then
    return
  end

  LastSave[src] = now + 5000

  if not validCoord(coords) then
    return
  end

  exports.rp_core:SavePlayerPosition(src, coords)
end)

RegisterNetEvent('rp:spawn:requestRevive', function()
  local src = source
  if not src or src <= 0 then
    return
  end

  if not exports.rp_core:IsPlayerLoaded(src) then
    TriggerClientEvent('rp:notify', src, {
      type = 'error',
      title = 'Revive',
      message = 'Spielerdaten sind noch nicht geladen.'
    })
    return
  end

  if not exports.rp_core:CanUseRateLimitedAction(src, 'spawn_revive', 10000) then
    TriggerClientEvent('rp:notify', src, {
      type = 'warning',
      title = 'Revive',
      message = 'Bitte kurz warten, bevor du erneut revivest.'
    })
    return
  end

  TriggerClientEvent('rp:spawn:forceRevive', src, {})
end)

AddEventHandler('playerDropped', function()
  LastSave[source] = nil
end)
