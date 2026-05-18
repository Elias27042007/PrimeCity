local OpenSessions = {}

local function notify(source, ntype, title, message)
  TriggerClientEvent('rp:notify', source, {
    type = ntype,
    title = title,
    message = message
  })
end

local function canUse(source, key, cooldown)
  return exports.rp_core:CanUseRateLimitedAction(source, key, cooldown)
end

local function isNearBank(source, bankId)
  local ped = GetPlayerPed(source)
  if ped == 0 then return false end

  local coords = GetEntityCoords(ped)
  for i = 1, #RPBankConfig.banks do
    local bank = RPBankConfig.banks[i]
    if bank.id == bankId then
      local dist = #(coords - bank.coords)
      return dist <= (RPBankConfig.interactionDistance + 1.2)
    end
  end

  return false
end

local function fetchTransactions(characterId)
  return MySQL.query.await(
    [=[SELECT transaction_type, amount, balance_before, balance_after, target_account_number, reference, created_at
       FROM bank_transactions
       WHERE character_id = ?
       ORDER BY id DESC
       LIMIT 20]=],
    { characterId }
  )
end

local function fetchAccountNumber(characterId)
  local row = MySQL.single.await('SELECT account_number FROM bank_accounts WHERE character_id = ? LIMIT 1', { characterId })
  return row and row.account_number or 'N/A'
end

local function fetchUIData(source)
  local characterId = exports.rp_core:GetCharacterId(source)
  if not characterId then
    return nil
  end

  local cash = exports.rp_money:GetCash(source)
  local bank = exports.rp_money:GetBank(source)
  local accountNumber = fetchAccountNumber(characterId)
  local transactions = fetchTransactions(characterId)

  return {
    characterId = characterId,
    accountNumber = accountNumber,
    cash = cash,
    bank = bank,
    transactions = transactions
  }
end

local function isSessionValidAndNearBank(source)
  local session = OpenSessions[source]
  if not session then
    return false
  end

  if not isNearBank(source, session.bankId) then
    OpenSessions[source] = nil
    TriggerClientEvent('rp:bank:closeUI', source)
    notify(source, 'warning', 'Bank', 'Du hast den Bankbereich verlassen.')
    return false
  end

  return true
end

local function refreshUI(source)
  if not OpenSessions[source] then return end
  local data = fetchUIData(source)
  if not data then return end
  TriggerClientEvent('rp:bank:updateUI', source, data)
end

RegisterNetEvent('rp:bank:requestOpen', function(bankId)
  local src = source
  bankId = tostring(bankId or '')

  if not canUse(src, 'bank_open', 700) then
    notify(src, 'warning', 'Bank', 'Bitte warte einen Moment.')
    return
  end

  if bankId == '' or not isNearBank(src, bankId) then
    notify(src, 'error', 'Bank', 'Du bist nicht an einer Bankfiliale.')
    return
  end

  local data = fetchUIData(src)
  if not data then
    notify(src, 'error', 'Bank', 'Kontodaten nicht verfügbar.')
    return
  end

  OpenSessions[src] = {
    bankId = bankId,
    openedAt = os.time()
  }

  TriggerClientEvent('rp:bank:openUI', src, data)
end)

RegisterNetEvent('rp:bank:close', function()
  OpenSessions[source] = nil
end)

RegisterNetEvent('rp:bank:deposit', function(amount)
  local src = source
  if not isSessionValidAndNearBank(src) then return end
  if not canUse(src, 'bank_deposit', 900) then return end

  amount = tonumber(amount or 0)
  if not amount or amount <= 0 then
    notify(src, 'error', 'Bank', 'Ungültiger Betrag.')
    return
  end

  local removed = exports.rp_money:RemoveCash(src, amount)
  if not removed then
    notify(src, 'error', 'Bank', 'Nicht genug Bargeld.')
    return
  end

  local added = exports.rp_money:AddBank(src, amount, 'deposit', 'cash_deposit')
  if not added then
    exports.rp_money:AddCash(src, amount)
    notify(src, 'error', 'Bank', 'Einzahlung fehlgeschlagen. Betrag wurde erstattet.')
    return
  end

  notify(src, 'success', 'Bank', ('%d$ eingezahlt.'):format(math.floor(amount)))
  refreshUI(src)
end)

RegisterNetEvent('rp:bank:withdraw', function(amount)
  local src = source
  if not isSessionValidAndNearBank(src) then return end
  if not canUse(src, 'bank_withdraw', 900) then return end

  amount = tonumber(amount or 0)
  if not amount or amount <= 0 then
    notify(src, 'error', 'Bank', 'Ungültiger Betrag.')
    return
  end

  local removed = exports.rp_money:RemoveBank(src, amount, 'withdraw', 'cash_withdraw')
  if not removed then
    notify(src, 'error', 'Bank', 'Nicht genug Guthaben.')
    return
  end

  local added = exports.rp_money:AddCash(src, amount)
  if not added then
    exports.rp_money:AddBank(src, amount, 'system', 'withdraw_refund')
    notify(src, 'error', 'Bank', 'Auszahlung fehlgeschlagen. Betrag wurde zurückgebucht.')
    return
  end

  notify(src, 'success', 'Bank', ('%d$ ausgezahlt.'):format(math.floor(amount)))
  refreshUI(src)
end)

local function findSourceByCharacterId(characterId)
  local players = GetPlayers()
  for i = 1, #players do
    local src = tonumber(players[i])
    if src then
      local cId = exports.rp_core:GetCharacterId(src)
      if cId and tonumber(cId) == tonumber(characterId) then
        return src
      end
    end
  end

  return nil
end

local function transferByServerId(source, targetSource, amount)
  if source == targetSource then
    return false, 'Transfer an dich selbst ist nicht erlaubt.'
  end

  local success, err = exports.rp_money:TransferBank(source, targetSource, amount, 'transfer_serverid')
  if not success then
    return false, err or 'Transfer fehlgeschlagen.'
  end

  notify(targetSource, 'info', 'Bank', ('Du hast %d$ erhalten.'):format(math.floor(amount)))
  return true
end

local function transferByAccount(source, accountNumber, amount)
  local ownChar = exports.rp_core:GetCharacterId(source)
  local ownAcc = fetchAccountNumber(ownChar)
  if accountNumber == ownAcc then
    return false, 'Transfer an eigenes Konto nicht erlaubt.'
  end

  local row = MySQL.single.await('SELECT character_id FROM bank_accounts WHERE account_number = ? LIMIT 1', { accountNumber })
  if not row or not row.character_id then
    return false, 'Zielkonto nicht gefunden.'
  end

  local targetSource = findSourceByCharacterId(row.character_id)
  if not targetSource then
    return false, 'Zielspieler ist offline.'
  end

  local success, err = exports.rp_money:TransferBank(source, targetSource, amount, 'transfer_account')
  if not success then
    return false, err or 'Transfer fehlgeschlagen.'
  end

  notify(targetSource, 'info', 'Bank', ('Du hast %d$ erhalten.'):format(math.floor(amount)))
  return true
end

RegisterNetEvent('rp:bank:transfer', function(data)
  local src = source
  if not isSessionValidAndNearBank(src) then return end
  if not canUse(src, 'bank_transfer', 1400) then return end

  if type(data) ~= 'table' then
    notify(src, 'error', 'Bank', 'Ungültige Anfrage.')
    return
  end

  local amount = tonumber(data.amount or 0)
  if not amount or amount <= 0 then
    notify(src, 'error', 'Bank', 'Ungültiger Betrag.')
    return
  end

  local mode = tostring(data.mode or 'serverid')
  local target = tostring(data.target or '')
  local success, reason = false, 'Transfer fehlgeschlagen.'

  if mode == 'serverid' then
    local targetSource = tonumber(target)
    if not targetSource or targetSource <= 0 then
      notify(src, 'error', 'Bank', 'Ungültige Server-ID.')
      return
    end

    success, reason = transferByServerId(src, targetSource, amount)
  elseif mode == 'account' then
    success, reason = transferByAccount(src, target, amount)
  else
    notify(src, 'error', 'Bank', 'Unbekannter Transfermodus.')
    return
  end

  if not success then
    notify(src, 'error', 'Bank', reason)
    return
  end

  notify(src, 'success', 'Bank', ('%d$ überwiesen.'):format(math.floor(amount)))
  refreshUI(src)
end)

AddEventHandler('playerDropped', function()
  OpenSessions[source] = nil
end)
