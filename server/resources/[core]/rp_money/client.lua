local balances = {
  cash = 0,
  bank = 0
}

RegisterNetEvent('rp:money:updateBalances', function(payload)
  if type(payload) ~= 'table' then
    return
  end

  balances.cash = tonumber(payload.cash) or balances.cash
  balances.bank = tonumber(payload.bank) or balances.bank

  TriggerEvent('rp:hud:updateMoney', balances)
end)

exports('GetBalances', function()
  return balances
end)
