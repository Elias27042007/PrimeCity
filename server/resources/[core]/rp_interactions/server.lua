exports('RegisterPointForPlayer', function(target, data)
  if not target or target <= 0 then return end
  TriggerClientEvent('rp:interactions:registerPoint', target, data)
end)

exports('RemovePointForPlayer', function(target, pointId)
  if not target or target <= 0 then return end
  TriggerClientEvent('rp:interactions:removePoint', target, pointId)
end)
