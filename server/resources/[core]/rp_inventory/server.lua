local ItemDefs = {}
local InventoryCache = {}
local OpenSessions = {}
local WorldDrops = {}
local NextDropId = 1
local UsableHandlers = {}
local syncItemToDb
local WEAPON_ITEM_ICON_FILES = {
  weapon_bat = 'weapon_bat_49.png',
  weapon_carbinerifle_mk2 = 'weapon_carbinerifle_mk2_29.png',
  weapon_ceramicpistol = 'weapon_ceramicpistol_46.png',
  weapon_combat_knife = 'weapon_combat_knife_43.png',
  weapon_compactrifle = 'weapon_compactrifle_36.png',
  weapon_dagger = 'weapon_dagger_24.png',
  weapon_doubleaction = 'weapon_doubleaction_34.png',
  weapon_fireextinguisher = 'weapon_fireextinguisher_40.png',
  weapon_flashbang = 'weapon_flashbang_39.png',
  weapon_flashlight = 'weapon_flashlight_31.png',
  weapon_gadgetpistol = 'weapon_gadgetpistol_32.png',
  weapon_gas = 'weapon_gas_48.png',
  weapon_glock19 = 'weapon_glock19_28.png',
  weapon_goodnightbat = 'weapon_goodnightbat_41.png',
  weapon_knuckle = 'weapon_knuckle_23.png',
  weapon_m45a1 = 'weapon_m45a1_45.png',
  weapon_machete = 'weapon_machete_38.png',
  weapon_marksmanrifle_mk2 = 'weapon_marksmanrifle_mk2_26.png',
  weapon_microsmg = 'weapon_microsmg_42.png',
  weapon_navyrevolver = 'weapon_navyrevolver_33.png',
  weapon_nightstick = 'weapon_nightstick_47.png',
  weapon_pistol = 'weapon_pistol_35.png',
  weapon_pistol2 = 'weapon_pistol2_37.png',
  weapon_pistol_mk2 = 'weapon_pistol_mk2_27.png',
  weapon_pistol_mk2_2 = 'weapon_pistol_mk2_2_30.png',
  weapon_pistol_wm29 = 'weapon_pistol_WM29_44.png',
  weapon_revolver = 'weapon_revolver_9.png',
  weapon_revolver_mk2 = 'weapon_revolver_mk2_18.png',
  weapon_sawnoffshotgun = 'weapon_sawnoffshotgun_11.png',
  weapon_smg = 'weapon_smg_14.png',
  weapon_smokegrenade = 'weapon_smokegrenade_10.png',
  weapon_sniperrifle = 'weapon_sniperrifle_15.png',
  weapon_specialcarbine = 'weapon_specialcarbine_25.png',
  weapon_specialcarbine_mk2 = 'weapon_specialcarbine_mk2_12.png',
  weapon_stungun = 'weapon_stungun_20.png',
  weapon_stungun_blue = 'weapon_stungun_blue_22.png',
  weapon_stungun_red = 'weapon_stungun_red_21.png',
  weapon_stungun_yellow = 'weapon_stungun_yellow_13.png',
  weapon_switchblade = 'weapon_switchblade_8.png',
  weapon_switchblade2 = 'weapon_switchblade2_17.png',
  weapon_ump45 = 'weapon_ump45_16.png',
  weapon_vector = 'weapon_vector_7.png',
  weapon_vintagepistol = 'weapon_vintagepistol_19.png',
}
local CUSTOM_ITEM_ICON_FILES = {
  bargeld = 'sorted_money_1.png'
}

local function isWeaponItem(itemName)
  return WEAPON_ITEM_ICON_FILES[tostring(itemName or ''):lower()] ~= nil
end

local function toWeaponItemName(value)
  local itemName = tostring(value or ''):lower():gsub('%s+', '_')
  if itemName == '' then
    return ''
  end
  if itemName:sub(1, 7) ~= 'weapon_' then
    itemName = 'weapon_' .. itemName
  end
  if not itemName:match('^weapon_[%w_]+$') then
    return ''
  end
  return itemName
end

local function weaponItemLabel(itemName)
  local label = tostring(itemName or ''):lower():gsub('^weapon_', ''):gsub('_', ' ')
  if label == '' then
    label = 'Waffe'
  end
  label = label:gsub('(%S+)', function(part)
    return part:sub(1, 1):upper() .. part:sub(2)
  end)
  return label
end

local function syncWeaponItemsToDb()
  for itemName in pairs(WEAPON_ITEM_ICON_FILES) do
    MySQL.query.await(
      [=[INSERT INTO inventory_items (item_name, label, description, stackable, max_stack, weight, usable)
         VALUES (?, ?, ?, 0, 1, 1700, 1)
         ON DUPLICATE KEY UPDATE
           label = VALUES(label),
           description = VALUES(description),
           stackable = 0,
           max_stack = 1,
           usable = 1]=],
      {
        itemName,
        weaponItemLabel(itemName),
        'Waffe als Inventar-Item'
      }
    )
  end
end

local function syncCoreItemsToDb()
  MySQL.query.await(
    [=[INSERT INTO inventory_items (item_name, label, description, stackable, max_stack, weight, usable)
       VALUES (?, ?, ?, 1, 1000000000, 0, 0)
       ON DUPLICATE KEY UPDATE
         label = VALUES(label),
         description = VALUES(description),
         stackable = VALUES(stackable),
         max_stack = VALUES(max_stack),
         weight = VALUES(weight),
         usable = VALUES(usable)]=],
    {
      'bargeld',
      'Bargeld',
      'Bargeld als physisches Inventar-Item'
    }
  )
end

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

local function resolveCharacterId(source, retries, delayMs)
  retries = math.max(0, math.floor(tonumber(retries) or 0))
  delayMs = math.max(0, math.floor(tonumber(delayMs) or 0))

  for attempt = 0, retries do
    local characterId = getCharacterId(source)
    if characterId and tonumber(characterId) and tonumber(characterId) > 0 then
      return tonumber(characterId)
    end

    local state = exports.rp_core:GetPlayerState(source)
    if type(state) == 'table' and tonumber(state.characterId) and tonumber(state.characterId) > 0 then
      return tonumber(state.characterId)
    end

    if attempt < retries and delayMs > 0 then
      Wait(delayMs)
    end
  end

  return nil
end

local function ensureCache(source)
  if not InventoryCache[source] then
    InventoryCache[source] = {
      characterId = nil,
      items = {},
      loaded = false
    }
  end
  return InventoryCache[source]
end

local function loadCharacterInventoryIntoCache(source, ensureIdCard)
  local cache = ensureCache(source)
  local characterId = resolveCharacterId(source, 15, 100)
  if not characterId then
    return nil, 'Charakter nicht geladen.'
  end

  if cache.loaded and cache.characterId == characterId then
    return cache
  end

  cache.characterId = characterId
  cache.items = {}

  local rows = MySQL.query.await(
    [=[SELECT ii.item_name, ci.quantity
       FROM character_inventory ci
       INNER JOIN inventory_items ii ON ii.id = ci.item_id
       WHERE ci.character_id = ?]=],
    { characterId }
  ) or {}

  for i = 1, #rows do
    cache.items[rows[i].item_name] = {
      itemName = rows[i].item_name,
      quantity = tonumber(rows[i].quantity) or 0
    }
  end

  if ensureIdCard and not cache.items.id_card and ItemDefs.id_card then
    cache.items.id_card = {
      itemName = 'id_card',
      quantity = 1
    }
    syncItemToDb(characterId, 'id_card', 1)
  end

  cache.loaded = true
  return cache
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
  local key = tostring(itemName or ''):lower()
  local iconFile = WEAPON_ITEM_ICON_FILES[key]
  if iconFile then
    return ('icons/items/%s'):format(iconFile)
  end
  local customIcon = CUSTOM_ITEM_ICON_FILES[key]
  if customIcon then
    return ('icons/items/%s'):format(customIcon)
  end
  return ('icons/items/%s.png'):format(tostring(itemName or 'unknown'))
end

local function collectWeaponItemsFromCache(cache)
  local owned = {}
  if type(cache) ~= 'table' or type(cache.items) ~= 'table' then
    return owned
  end

  for itemName, row in pairs(cache.items) do
    if isWeaponItem(itemName) and (tonumber(row and row.quantity) or 0) > 0 then
      owned[#owned + 1] = tostring(itemName):lower()
    end
  end

  table.sort(owned)
  return owned
end

local function pushWeaponSync(source, cache)
  source = tonumber(source) or 0
  if source <= 0 then
    return
  end

  if not GetPlayerName(source) then
    return
  end

  local resolvedCache = cache or InventoryCache[source]
  local items = collectWeaponItemsFromCache(resolvedCache)
  TriggerClientEvent('rp:inventory:syncWeapons', source, { items = items })
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
      usable = (def and def.usable) or isWeaponItem(item.itemName),
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

syncItemToDb = function(characterId, itemName, quantity)
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

  local cache, loadReason = loadCharacterInventoryIntoCache(source, true)
  if not cache then
    return false, loadReason or 'Charakter nicht geladen.'
  end

  local charId = cache.characterId

  local row = cache.items[itemName] or { itemName = itemName, quantity = 0 }
  local newQuantity = row.quantity + quantity
  if newQuantity > (tonumber(def.maxStack) or 999) then
    return false, 'Maximalmenge erreicht.'
  end

  row.quantity = newQuantity
  cache.items[itemName] = row
  syncItemToDb(charId, itemName, row.quantity)
  pushInventory(source)
  if isWeaponItem(itemName) then
    pushWeaponSync(source, cache)
  end
  return true
end

local function removeItem(source, itemName, quantity)
  quantity = math.floor(tonumber(quantity) or 0)
  if quantity <= 0 then return false, 'Ungültige Menge.' end

  local cache, loadReason = loadCharacterInventoryIntoCache(source, true)
  if not cache then
    return false, loadReason or 'Charakter nicht geladen.'
  end

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
  if isWeaponItem(itemName) then
    pushWeaponSync(source, cache)
  end
  return true
end

local function useItem(source, itemName, quantity)
  local def = ItemDefs[itemName]
  if not def then return false, 'Item nicht gefunden.' end
  if not def.usable and not isWeaponItem(itemName) then return false, 'Item nicht nutzbar.' end

  quantity = math.floor(tonumber(quantity) or 1)
  if quantity <= 0 then
    return false, 'Ungültige Menge.'
  end

  local consumeItem = not isWeaponItem(itemName)
  if consumeItem then
    local ok = removeItem(source, itemName, quantity)
    if not ok then
      return false, 'Item nicht vorhanden.'
    end
  end

  local handler = UsableHandlers[itemName]
  if handler then
    local handlerOk, handlerError = pcall(handler, source, quantity, def)
    if not handlerOk then
      if consumeItem then
        addItem(source, itemName, quantity)
      end
      return false, ('Nutzung fehlgeschlagen: %s'):format(tostring(handlerError))
    end
  end

  TriggerEvent('rp:inventory:itemUsed', source, itemName, quantity)
  TriggerClientEvent('rp:inventory:itemUsed', source, itemName, quantity)

  if itemName == 'water' then
    notify(source, 'success', 'Inventar', ('Du hast %sx Wasser getrunken.'):format(quantity))
  elseif itemName == 'bread' then
    notify(source, 'success', 'Inventar', ('Du hast %sx Brot gegessen.'):format(quantity))
  elseif isWeaponItem(itemName) then
    notify(source, 'success', 'Inventar', ('%s ausgerüstet.'):format(def.label))
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
  local cache, reason = loadCharacterInventoryIntoCache(source, true)
  if not cache then
    print(('[rp_inventory] loadCharacterInventory fehlgeschlagen für %s: %s'):format(tostring(source), tostring(reason)))
    return
  end
  pushWeaponSync(source, cache)
end)

RegisterNetEvent('rp:inventory:requestOpen', function()
  local src = source
  if not exports.rp_core:CanUseRateLimitedAction(src, 'inventory_open', 450) then
    return
  end

  local cache, reason = loadCharacterInventoryIntoCache(src, true)
  if not cache then
    notify(src, 'error', 'Inventar', 'Inventar noch nicht geladen.')
    if reason and reason ~= '' then
      print(('[rp_inventory] requestOpen blockiert für %s: %s'):format(tostring(src), tostring(reason)))
    end
    return
  end

  OpenSessions[src] = true
  TriggerClientEvent('rp:inventory:openUI', src, serializableInventory(cache))
  pushWeaponSync(src, cache)
  pushDrops(src)
end)

RegisterNetEvent('rp:inventory:requestWeaponSync', function()
  local src = source
  local cache = InventoryCache[src]
  if not cache then
    cache = select(1, loadCharacterInventoryIntoCache(src, true))
  end
  if cache then
    pushWeaponSync(src, cache)
  end
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
exports('IsAllowedWeaponItem', function(itemName)
  itemName = toWeaponItemName(itemName)
  if itemName == '' then
    return false
  end
  return isWeaponItem(itemName)
end)
exports('GetAllowedWeaponItems', function()
  local out = {}
  for itemName in pairs(WEAPON_ITEM_ICON_FILES) do
    out[#out + 1] = itemName
  end
  table.sort(out)
  return out
end)
exports('GetInventory', function(source)
  local cache = InventoryCache[source]
  return cache and cache.items or {}
end)

AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  syncWeaponItemsToDb()
  syncCoreItemsToDb()
  loadItemDefs()
  WorldDrops = {}
  NextDropId = 1
end)

AddEventHandler('playerDropped', function()
  InventoryCache[source] = nil
  OpenSessions[source] = nil
end)
