local function notifyPlayer(source, payload)
  if not source or source <= 0 then
    return
  end

  TriggerClientEvent('rp:notify', source, payload)
end

exports('Notify', function(source, payload)
  notifyPlayer(source, payload)
end)

AddEventHandler('rp:notify:server', function(sourceId, payload)
  notifyPlayer(sourceId, payload)
end)
