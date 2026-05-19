local ItemDefs = {}
local InventoryCache = {}
local OpenSessions = {}
local WorldDrops = {}
local NextDropId = 1
local UsableHandlers = {}

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

local function itemIconPath(itemName)
  return ('icons/items/%s.png'):format(tostring(itemName or 'unknown'))
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
      weight = def and def.weight or 0,
      icon = itemIconPath(item.itemName)
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

local function getPlayerCoords(source)
  local ped = GetPlayerPed(source)
  if not ped or ped == 0 then
    return nil
  end

  return GetEntityCoords(ped)
end

local function isWithinDistance(sourceA, sourceB, maxDistance)
  local a = getPlayerCoords(sourceA)
  local b = getPlayerCoords(sourceB)
  if not a or not b then
    return false
  end

  return #(a - b) <= (tonumber(maxDistance) or 3.0)
end

local function serializeDrops()
  local list = {}
  for id, drop in pairs(WorldDrops) do
    local def = ItemDefs[drop.itemName]
    list[#list + 1] = {
      id = id,
      itemName = drop.itemName,
      label = def and def.label or drop.itemName,
      quantity = tonumber(drop.quantity) or 1,
      x = drop.x,
      y = drop.y,
      z = drop.z
    }
  end
  return list
end

local function pushDrops(target)
  local payload = serializeDrops()
  if target then
    TriggerClientEvent('rp:inventory:updateDrops', target, payload)
  else
    TriggerClientEvent('rp:inventory:updateDrops', -1, payload)
  end
end

local function createDrop(source, itemName, quantity)
  local coords = getPlayerCoords(source)
  if not coords then
    return false, 'Position konnte nicht gelesen werden.'
  end

  quantity = math.floor(tonumber(quantity) or 0)
  if quantity <= 0 then
    return false, 'Ungültige Menge.'
  end

  local dropId = NextDropId
  NextDropId = NextDropId + 1

  WorldDrops[dropId] = {
    itemName = itemName,
    quantity = quantity,
    x = coords.x + 0.0,
    y = coords.y + 0.0,
    z = coords.z + 0.0
  }

  pushDrops()
  return true, dropId
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
  if newQuantity > (tonumber(def.maxStack) or 999) then
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

local function useItem(source, itemName, quantity)
  local def = ItemDefs[itemName]
  if not def then return false, 'Item nicht gefunden.' end
  if not def.usable then return false, 'Item nicht nutzbar.' end

  quantity = math.floor(tonumber(quantity) or 1)
  if quantity <= 0 then
    return false, 'Ungültige Menge.'
  end

  local ok = removeItem(source, itemName, quantity)
  if not ok then
    return false, 'Item nicht vorhanden.'
  end

  local handler = UsableHandlers[itemName]
  if handler then
    local handlerOk, handlerError = pcall(handler, source, quantity, def)
    if not handlerOk then
      addItem(source, itemName, quantity)
      return false, ('Nutzung fehlgeschlagen: %s'):format(tostring(handlerError))
    end
  end

  TriggerEvent('rp:inventory:itemUsed', source, itemName, quantity)
  TriggerClientEvent('rp:inventory:itemUsed', source, itemName, quantity)

  if itemName == 'water' then
    notify(source, 'success', 'Inventar', ('Du hast %sx Wasser getrunken.'):format(quantity))
  elseif itemName == 'bread' then
    notify(source, 'success', 'Inventar', ('Du hast %sx Brot gegessen.'):format(quantity))
  else
    notify(source, 'info', 'Inventar', ('%sx %s wurde verwendet.'):format(quantity, def.label))
  end

  return true
end

local function giveItem(source, target, itemName, quantity)
  target = tonumber(target) or 0
  quantity = math.floor(tonumber(quantity) or 0)

  if target <= 0 then
    return false, 'Ungültiger Zielspieler.'
  end
  if not GetPlayerName(target) then
    return false, 'Zielspieler nicht gefunden.'
  end
  if source == target then
    return false, 'Du kannst dir selbst nichts geben.'
  end
  if quantity <= 0 then
    return false, 'Ungültige Menge.'
  end
  if not isWithinDistance(source, target, RPInventoryConfig.giveDistance or 4.0) then
    return false, 'Spieler ist nicht in deiner Nähe.'
  end

  local def = ItemDefs[itemName]
  if not def then
    return false, 'Item nicht gefunden.'
  end

  local ok, reason = removeItem(source, itemName, quantity)
  if not ok then
    return false, reason or 'Item konnte nicht entfernt werden.'
  end

  local added, addReason = addItem(target, itemName, quantity)
  if not added then
    addItem(source, itemName, quantity)
    return false, addReason or 'Item konnte nicht übergeben werden.'
  end

  notify(source, 'success', 'Inventar', ('Du hast %sx %s an %s gegeben.'):format(quantity, def.label, GetPlayerName(target)))
  notify(target, 'success', 'Inventar', ('Du hast %sx %s von %s erhalten.'):format(quantity, def.label, GetPlayerName(source)))
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
  pushDrops(src)
end)

RegisterNetEvent('rp:inventory:requestDrops', function()
  pushDrops(source)
end)

RegisterNetEvent('rp:inventory:close', function()
  OpenSessions[source] = nil
end)

RegisterNetEvent('rp:inventory:useItem', function(itemName, quantity)
  local src = source
  if not OpenSessions[src] then return end
  if not exports.rp_core:CanUseRateLimitedAction(src, 'inventory_use', 650) then return end

  itemName = tostring(itemName or '')
  if itemName == '' then return end

  local ok, reason = useItem(src, itemName, quantity)
  if not ok then
    notify(src, 'error', 'Inventar', reason)
  end
end)

RegisterNetEvent('rp:inventory:giveItem', function(payload)
  local src = source
  if not OpenSessions[src] then return end
  if not exports.rp_core:CanUseRateLimitedAction(src, 'inventory_give', 500) then return end
  if type(payload) ~= 'table' then return end

  local itemName = tostring(payload.itemName or '')
  local quantity = tonumber(payload.quantity or 1) or 1
  local targetId = tonumber(payload.targetId or 0) or 0

  if itemName == '' then
    notify(src, 'error', 'Inventar', 'Ungültiges Item.')
    return
  end

  local ok, reason = giveItem(src, targetId, itemName, quantity)
  if not ok then
    notify(src, 'error', 'Inventar', reason or 'Item konnte nicht übergeben werden.')
  end
end)

RegisterNetEvent('rp:inventory:dropItem', function(payload)
  local src = source
  if not OpenSessions[src] then return end
  if not exports.rp_core:CanUseRateLimitedAction(src, 'inventory_drop', 450) then return end
  if type(payload) ~= 'table' then return end

  local itemName = tostring(payload.itemName or '')
  local quantity = math.floor(tonumber(payload.quantity or 1) or 1)
  if itemName == '' then
    notify(src, 'error', 'Inventar', 'Ungültiges Item.')
    return
  end

  local def = ItemDefs[itemName]
  if not def then
    notify(src, 'error', 'Inventar', 'Item nicht gefunden.')
    return
  end

  local removed, removeReason = removeItem(src, itemName, quantity)
  if not removed then
    notify(src, 'error', 'Inventar', removeReason or 'Item konnte nicht gedroppt werden.')
    return
  end

  local created, createResult = createDrop(src, itemName, quantity)
  if not created then
    addItem(src, itemName, quantity)
    notify(src, 'error', 'Inventar', createResult or 'Drop konnte nicht erstellt werden.')
    return
  end

  notify(src, 'success', 'Inventar', ('Du hast %sx %s gedroppt.'):format(quantity, def.label))
end)

RegisterNetEvent('rp:inventory:pickupDrop', function(dropId)
  local src = source
  dropId = tonumber(dropId) or 0
  if dropId <= 0 then return end
  if not exports.rp_core:CanUseRateLimitedAction(src, 'inventory_pickup', 350) then return end

  local drop = WorldDrops[dropId]
  if not drop then
    return
  end

  local coords = getPlayerCoords(src)
  if not coords then
    return
  end

  local dist = #(coords - vector3(drop.x + 0.0, drop.y + 0.0, drop.z + 0.0))
  if dist > (RPInventoryConfig.pickupDistance or 2.2) then
    notify(src, 'error', 'Inventar', 'Du bist zu weit vom Item entfernt.')
    return
  end

  local added, reason = addItem(src, drop.itemName, drop.quantity)
  if not added then
    notify(src, 'error', 'Inventar', reason or 'Item konnte nicht aufgehoben werden.')
    return
  end

  WorldDrops[dropId] = nil
  pushDrops()
  local def = ItemDefs[drop.itemName]
  notify(src, 'success', 'Inventar', ('Du hast %sx %s aufgehoben.'):format(drop.quantity, (def and def.label) or drop.itemName))
end)

exports('AddItem', addItem)
exports('RemoveItem', removeItem)
exports('UseItem', useItem)
exports('addItem', addItem)
exports('removeItem', removeItem)
exports('useItem', useItem)
exports('RegisterUsableHandler', function(itemName, callback)
  if type(itemName) ~= 'string' or itemName == '' then
    return false
  end
  if type(callback) ~= 'function' then
    return false
  end

  UsableHandlers[itemName] = callback
  return true
end)
exports('GetInventory', function(source)
  local cache = InventoryCache[source]
  return cache and cache.items or {}
end)

AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  loadItemDefs()
  WorldDrops = {}
  NextDropId = 1
end)

AddEventHandler('playerDropped', function()
  InventoryCache[source] = nil
  OpenSessions[source] = nil
end)
