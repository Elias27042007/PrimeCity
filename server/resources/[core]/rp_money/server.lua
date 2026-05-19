local AccountsCache = {}
local ensureCharacterAccounts

local function validAmount(amount)
  amount = tonumber(amount)
  if not amount or amount <= 0 then
    return false
  end

  if amount > RPMoneyConfig.maxTransaction then
    return false
  end

  return true, math.floor(amount)
end

local function getCharacterId(source)
  return exports.rp_core:GetCharacterId(source)
end

local function inventoryResourceReady()
  return GetResourceState('rp_inventory') == 'started'
end

local function pushBalances(source)
  local cache = AccountsCache[source]
  if not cache then
    return
  end

  TriggerClientEvent('rp:money:updateBalances', source, {
    cash = cache.cash,
    bank = cache.bank
  })
end

local function fetchBankAccountRow(characterId)
  return MySQL.single.await('SELECT id, account_number FROM bank_accounts WHERE character_id = ? LIMIT 1', { characterId })
end

local function logBankTx(characterId, txType, amount, beforeBalance, afterBalance, targetAccount, reference, targetCharacterId)
  local bankAccount = fetchBankAccountRow(characterId)
  if not bankAccount then return end

  MySQL.insert.await(
    [=[INSERT INTO bank_transactions
       (bank_account_id, character_id, transaction_type, amount, balance_before, balance_after, target_account_number, target_character_id, reference)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]=],
    {
      bankAccount.id,
      characterId,
      txType,
      amount,
      beforeBalance,
      afterBalance,
      targetAccount,
      targetCharacterId,
      reference
    }
  )
end

local function setBalance(source, accountType, newValue)
  local charId = getCharacterId(source)
  if not charId then return false end

  local affected = MySQL.update.await(
    'UPDATE accounts SET balance = ? WHERE character_id = ? AND account_type = ?',
    { newValue, charId, accountType }
  )

  if affected < 1 then return false end

  AccountsCache[source][accountType] = newValue
  pushBalances(source)
  return true
end

local function setCashFromInventory(source, quantity)
  source = tonumber(source) or 0
  quantity = math.max(0, math.floor(tonumber(quantity) or 0))
  if source <= 0 then
    return false
  end

  if not AccountsCache[source] then
    local characterId = getCharacterId(source)
    if not characterId then
      return false
    end
    ensureCharacterAccounts(source, characterId)
  end

  return setBalance(source, 'cash', quantity)
end

ensureCharacterAccounts = function(source, characterId)
  local rows = MySQL.query.await('SELECT account_type, balance FROM accounts WHERE character_id = ?', { characterId })

  local cash = nil
  local bank = nil
  for i = 1, #rows do
    if rows[i].account_type == 'cash' then
      cash = tonumber(rows[i].balance) or 0
    elseif rows[i].account_type == 'bank' then
      bank = tonumber(rows[i].balance) or 0
    end
  end

  if cash == nil then
    MySQL.insert.await('INSERT INTO accounts (character_id, account_type, balance) VALUES (?, ?, 0)', { characterId, 'cash' })
    cash = 0
  end

  if bank == nil then
    MySQL.insert.await('INSERT INTO accounts (character_id, account_type, balance) VALUES (?, ?, 0)', { characterId, 'bank' })
    bank = 0
  end

  if not fetchBankAccountRow(characterId) then
    local accountNumber = ('RP%09d'):format(characterId)
    MySQL.insert.await('INSERT INTO bank_accounts (character_id, account_number) VALUES (?, ?)', { characterId, accountNumber })
  end

  AccountsCache[source] = {
    characterId = characterId,
    cash = cash,
    bank = bank
  }

  pushBalances(source)
end

AddEventHandler('rp:money:loadCharacterAccounts', function(source, characterId)
  ensureCharacterAccounts(source, characterId)
end)

local function getCash(source)
  if inventoryResourceReady() then
    local ok, quantity = pcall(function()
      return exports.rp_inventory:GetItemQuantity(source, 'bargeld')
    end)
    if ok and quantity ~= nil then
      local normalized = math.max(0, math.floor(tonumber(quantity) or 0))
      if AccountsCache[source] then
        AccountsCache[source].cash = normalized
      end
      return normalized
    end
  end

  local cache = AccountsCache[source]
  if not cache then return 0 end
  return cache.cash
end

local function addCash(source, amount)
  local ok, normalized = validAmount(amount)
  if not ok then return false, 'Ungültiger Betrag.' end

  if inventoryResourceReady() then
    local added, reason = exports.rp_inventory:AddItem(source, 'bargeld', normalized)
    if not added then
      return false, reason or 'Bargeld konnte nicht hinzugefügt werden.'
    end
    return true
  end

  local cash = getCash(source)
  return setBalance(source, 'cash', cash + normalized)
end

local function removeCash(source, amount)
  local ok, normalized = validAmount(amount)
  if not ok then return false, 'Ungültiger Betrag.' end

  if inventoryResourceReady() then
    local removed, reason = exports.rp_inventory:RemoveItem(source, 'bargeld', normalized)
    if not removed then
      return false, reason or 'Nicht genug Bargeld.'
    end
    return true
  end

  local cash = getCash(source)
  if cash < normalized then
    return false, 'Nicht genug Bargeld.'
  end

  return setBalance(source, 'cash', cash - normalized)
end

local function getBank(source)
  local cache = AccountsCache[source]
  if not cache then return 0 end
  return cache.bank
end

local function addBank(source, amount, txType, reference)
  local ok, normalized = validAmount(amount)
  if not ok then return false, 'Ungültiger Betrag.' end

  local bank = getBank(source)
  local nextBalance = bank + normalized
  local success = setBalance(source, 'bank', nextBalance)
  if success then
    logBankTx(getCharacterId(source), txType or 'system', normalized, bank, nextBalance, nil, reference or 'system_credit', nil)
  end

  return success
end

local function removeBank(source, amount, txType, reference)
  local ok, normalized = validAmount(amount)
  if not ok then return false, 'Ungültiger Betrag.' end

  local bank = getBank(source)
  if bank < normalized then
    return false, 'Nicht genug Guthaben.'
  end

  local nextBalance = bank - normalized
  local success = setBalance(source, 'bank', nextBalance)
  if success then
    logBankTx(getCharacterId(source), txType or 'system', normalized, bank, nextBalance, nil, reference or 'system_debit', nil)
  end

  return success
end

local function transferBank(source, targetSource, amount, reference)
  local ok, normalized = validAmount(amount)
  if not ok then return false, 'Ungültiger Betrag.' end

  if source == targetSource then
    return false, 'Transfer an sich selbst nicht erlaubt.'
  end

  local senderBank = getBank(source)
  if senderBank < normalized then
    return false, 'Nicht genug Guthaben.'
  end

  local senderChar = getCharacterId(source)
  local targetChar = getCharacterId(targetSource)

  if not senderChar or not targetChar then
    return false, 'Charakterdaten fehlen.'
  end

  local targetAccount = fetchBankAccountRow(targetChar)
  if not targetAccount then
    return false, 'Zielkonto nicht gefunden.'
  end

  if not setBalance(source, 'bank', senderBank - normalized) then
    return false, 'Abbuchung fehlgeschlagen.'
  end

  local receiverBank = getBank(targetSource)
  if not setBalance(targetSource, 'bank', receiverBank + normalized) then
    setBalance(source, 'bank', senderBank)
    return false, 'Gutschrift fehlgeschlagen.'
  end

  logBankTx(senderChar, 'transfer_out', normalized, senderBank, senderBank - normalized, targetAccount.account_number, reference or 'transfer_out', targetChar)
  logBankTx(targetChar, 'transfer_in', normalized, receiverBank, receiverBank + normalized, nil, reference or 'transfer_in', senderChar)

  return true
end

exports('GetCash', getCash)
exports('AddCash', addCash)
exports('RemoveCash', removeCash)
exports('GetBank', getBank)
exports('AddBank', addBank)
exports('RemoveBank', removeBank)
exports('TransferBank', transferBank)
exports('getCash', getCash)
exports('addCash', addCash)
exports('removeCash', removeCash)
exports('getBank', getBank)
exports('addBank', addBank)
exports('removeBank', removeBank)
exports('transferBank', transferBank)
exports('SetCashFromInventory', setCashFromInventory)
exports('setCashFromInventory', setCashFromInventory)

AddEventHandler('rp:money:setCashFromInventory', function(targetSource, quantity)
  setCashFromInventory(targetSource, quantity)
end)

AddEventHandler('playerDropped', function()
  AccountsCache[source] = nil
end)
