local ItemDefs = {}
local InventoryCache = {}
local OpenSessions = {}

local function notify(source, ntype, title, message)
  TriggerClientEvent('rp:notify', source, {
    type = ntype,
    title = title,
    message = message
  })
end

local function loadItemDefs()
  ItemDefs = {}
  local rows = MySQL.query.await('SELECT id, item_name, label, description, stackable, max_stack, weight, usable FROM inventory_items')
  for i = 1, #rows do
    local row = rows[i]
    ItemDefs[row.item_name] = {
      id = row.id,
      itemName = row.item_name,
      label = row.label,
      description = row.description,
      stackable = tonumber(row.stackable) == 1,
      maxStack = tonumber(row.max_stack) or 999,
      weight = tonumber(row.weight) or 0,
      usable = tonumber(row.usable) == 1
    }
  end
end

local function getCharacterId(source)
  return exports.rp_core:GetCharacterId(source)
end

local function ensureCache(source)
  if not InventoryCache[source] then
    InventoryCache[source] = {
      characterId = nil,
      items = {}
    }
  end
  return InventoryCache[source]
end

local function recalcWeight(cache)
  local weight = 0
  for _, row in pairs(cache.items) do
    local def = ItemDefs[row.itemName]
    if def then
      weight = weight + (def.weight * (row.quantity or 0))
    end
  end
  return weight
end

local function serializableInventory(cache)
  local list = {}
  for _, item in pairs(cache.items) do
    local def = ItemDefs[item.itemName]
    list[#list + 1] = {
      itemName = item.itemName,
      label = def and def.label or item.itemName,
      description = def and def.description or '',
      quantity = item.quantity,
      usable = def and def.usable or false,
      weight = def and def.weight or 0
    }
  end

  table.sort(list, function(a, b)
    return a.label < b.label
  end)

  return {
    items = list,
    maxWeight = RPInventoryConfig.defaultMaxWeight,
    currentWeight = recalcWeight(cache)
  }
end

local function pushInventory(source)
  if not OpenSessions[source] then return end
  local cache = InventoryCache[source]
  if not cache then return end
  TriggerClientEvent('rp:inventory:updateUI', source, serializableInventory(cache))
end

local function syncItemToDb(characterId, itemName, quantity)
  local def = ItemDefs[itemName]
  if not def then return false end

  if quantity <= 0 then
    MySQL.update.await(
      [=[DELETE ci FROM character_inventory ci
         INNER JOIN inventory_items ii ON ii.id = ci.item_id
         WHERE ci.character_id = ? AND ii.item_name = ?]=],
      { characterId, itemName }
    )
    return true
  end

  local exists = MySQL.scalar.await(
    [=[SELECT ci.id FROM character_inventory ci
       INNER JOIN inventory_items ii ON ii.id = ci.item_id
       WHERE ci.character_id = ? AND ii.item_name = ? LIMIT 1]=],
    { characterId, itemName }
  )

  if exists then
    MySQL.update.await(
      [=[UPDATE character_inventory ci
         INNER JOIN inventory_items ii ON ii.id = ci.item_id
         SET ci.quantity = ?
         WHERE ci.character_id = ? AND ii.item_name = ?]=],
      { quantity, characterId, itemName }
    )
  else
    MySQL.insert.await('INSERT INTO character_inventory (character_id, item_id, quantity) VALUES (?, ?, ?)', {
      characterId,
      def.id,
      quantity
    })
  end

  return true
end

local function addItem(source, itemName, quantity)
  quantity = math.floor(tonumber(quantity) or 0)
  if quantity <= 0 then return false, 'Ungültige Menge.' end

  local def = ItemDefs[itemName]
  if not def then return false, 'Unbekanntes Item.' end

  local cache = ensureCache(source)
  local charId = cache.characterId
  if not charId then return false, 'Charakter nicht geladen.' end

  local row = cache.items[itemName] or { itemName = itemName, quantity = 0 }
  local newQuantity = row.quantity + quantity
  if newQuantity > def.maxStack and def.stackable then
    return false, 'Maximalmenge erreicht.'
  end

  row.quantity = newQuantity
  cache.items[itemName] = row
  syncItemToDb(charId, itemName, row.quantity)
  pushInventory(source)
  return true
end

local function removeItem(source, itemName, quantity)
  quantity = math.floor(tonumber(quantity) or 0)
  if quantity <= 0 then return false, 'Ungültige Menge.' end

  local cache = ensureCache(source)
  local row = cache.items[itemName]
  if not row or row.quantity < quantity then
    return false, 'Nicht genug Items.'
  end

  row.quantity = row.quantity - quantity
  if row.quantity <= 0 then
    cache.items[itemName] = nil
    syncItemToDb(cache.characterId, itemName, 0)
  else
    cache.items[itemName] = row
    syncItemToDb(cache.characterId, itemName, row.quantity)
  end

  pushInventory(source)
  return true
end

local function useItem(source, itemName)
  local def = ItemDefs[itemName]
  if not def then return false, 'Item nicht gefunden.' end
  if not def.usable then return false, 'Item nicht nutzbar.' end

  local ok = removeItem(source, itemName, 1)
  if not ok then
    return false, 'Item nicht vorhanden.'
  end

  if itemName == 'water' then
    notify(source, 'success', 'Inventar', 'Du hast Wasser getrunken.')
  elseif itemName == 'bread' then
    notify(source, 'success', 'Inventar', 'Du hast Brot gegessen.')
  else
    notify(source, 'info', 'Inventar', ('%s wurde verwendet.'):format(def.label))
  end

  return true
end

AddEventHandler('rp:inventory:loadCharacterInventory', function(source, characterId)
  local cache = ensureCache(source)
  cache.characterId = characterId
  cache.items = {}

  local rows = MySQL.query.await(
    [=[SELECT ii.item_name, ci.quantity
       FROM character_inventory ci
       INNER JOIN inventory_items ii ON ii.id = ci.item_id
       WHERE ci.character_id = ?]=],
    { characterId }
  )

  for i = 1, #rows do
    cache.items[rows[i].item_name] = {
      itemName = rows[i].item_name,
      quantity = tonumber(rows[i].quantity) or 0
    }
  end

  if not cache.items.id_card then
    addItem(source, 'id_card', 1)
  end
end)

RegisterNetEvent('rp:inventory:requestOpen', function()
  local src = source
  if not exports.rp_core:CanUseRateLimitedAction(src, 'inventory_open', 450) then
    return
  end

  local cache = ensureCache(src)
  if not cache.characterId then
    notify(src, 'error', 'Inventar', 'Inventar noch nicht geladen.')
    return
  end

  OpenSessions[src] = true
  TriggerClientEvent('rp:inventory:openUI', src, serializableInventory(cache))
end)

RegisterNetEvent('rp:inventory:close', function()
  OpenSessions[source] = nil
end)

RegisterNetEvent('rp:inventory:useItem', function(itemName)
  local src = source
  if not OpenSessions[src] then return end
  if not exports.rp_core:CanUseRateLimitedAction(src, 'inventory_use', 650) then return end

  itemName = tostring(itemName or '')
  if itemName == '' then return end

  local ok, reason = useItem(src, itemName)
  if not ok then
    notify(src, 'error', 'Inventar', reason)
  end
end)

exports('AddItem', addItem)
exports('RemoveItem', removeItem)
exports('UseItem', useItem)
exports('addItem', addItem)
exports('removeItem', removeItem)
exports('useItem', useItem)
exports('GetInventory', function(source)
  local cache = InventoryCache[source]
  return cache and cache.items or {}
end)

AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  loadItemDefs()
end)

AddEventHandler('playerDropped', function()
  InventoryCache[source] = nil
  OpenSessions[source] = nil
end)
