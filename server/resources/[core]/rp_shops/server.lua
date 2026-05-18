local ShopCache = {}
local ShopItems = {}
local OpenSession = {}

local function getCharacterIdBySource(source)
  if exports.rp_core and exports.rp_core.GetCharacterId then
    return tonumber(exports.rp_core:GetCharacterId(source)) or nil
  end
  return nil
end

local function getSexByCharacterId(characterId)
  if not characterId then
    return 'm'
  end

  local row = MySQL.single.await('SELECT sex FROM character_identity WHERE character_id = ? LIMIT 1', { characterId })
  if not row then
    return 'm'
  end

  local sex = tostring(row.sex or ''):lower()
  return sex == 'f' and 'f' or 'm'
end

local function getStoredSkinByCharacterId(characterId)
  if not characterId then
    return nil
  end

  local row = MySQL.single.await('SELECT model, skin_json FROM character_skin WHERE character_id = ? LIMIT 1', { characterId })
  if not row then
    return nil
  end

  local decoded = {}
  local ok, parsed = pcall(json.decode, tostring(row.skin_json or '{}'))
  if ok and type(parsed) == 'table' then
    decoded = parsed
  end

  return {
    model = tostring(row.model or ''),
    sex = decoded.sex == 'f' and 'f' or 'm',
    components = type(decoded.components) == 'table' and decoded.components or {},
    props = type(decoded.props) == 'table' and decoded.props or {},
    overlays = type(decoded.overlays) == 'table' and decoded.overlays or {}
  }
end

local function notify(source, ntype, title, message)
  TriggerClientEvent('rp:notify', source, {
    type = ntype,
    title = title,
    message = message
  })
end

local function loadShops()
  ShopCache = {}
  ShopItems = {}

  local shops = MySQL.query.await(
    'SELECT id, label, shop_type, pos_x, pos_y, pos_z, COALESCE(blip_enabled, 1) AS blip_enabled FROM shops WHERE enabled = 1 ORDER BY id ASC'
  )

  for i = 1, #shops do
    local shop = shops[i]
    ShopCache[shop.id] = {
      id = shop.id,
      label = shop.label,
      type = shop.shop_type,
      x = tonumber(shop.pos_x),
      y = tonumber(shop.pos_y),
      z = tonumber(shop.pos_z),
      blipEnabled = (tonumber(shop.blip_enabled) or 1) == 1
    }
    ShopItems[shop.id] = {}
  end

  local items = MySQL.query.await(
    [=[SELECT s.id AS shop_id, ii.item_name, ii.label, si.price, si.currency
       FROM shop_items si
       INNER JOIN shops s ON s.id = si.shop_id
       INNER JOIN inventory_items ii ON ii.id = si.item_id
       WHERE si.enabled = 1 AND s.enabled = 1]=]
  )

  for i = 1, #items do
    local row = items[i]
    if ShopItems[row.shop_id] then
      ShopItems[row.shop_id][#ShopItems[row.shop_id] + 1] = {
        itemName = row.item_name,
        label = row.label,
        price = tonumber(row.price) or 0,
        currency = row.currency
      }
    end
  end
end

local function ensureShopsSchema()
  local hasBlipColumn = MySQL.scalar.await([[
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'shops'
      AND COLUMN_NAME = 'blip_enabled'
  ]]) or 0

  if tonumber(hasBlipColumn) <= 0 then
    MySQL.query.await('ALTER TABLE shops ADD COLUMN blip_enabled TINYINT(1) NOT NULL DEFAULT 1 AFTER enabled')
  end
end

local function getShopsForClient()
  local list = {}
  for _, shop in pairs(ShopCache) do
    list[#list + 1] = shop
  end
  return list
end

local function isNearShop(source, shopId)
  local shop = ShopCache[shopId]
  if not shop then return false end

  local ped = GetPlayerPed(source)
  if ped == 0 then return false end

  local coords = GetEntityCoords(ped)
  local dist = #(coords - vector3(shop.x, shop.y, shop.z))
  return dist <= (RPShopsConfig.interactDistance + 1.2)
end

local function openShop(source, shopId)
  local shop = ShopCache[shopId]
  if not shop then
    notify(source, 'error', 'Shop', 'Shop nicht gefunden.')
    return
  end

  if tostring(shop.type or '') == 'clothing' then
    if GetResourceState('rp_skin') ~= 'started' then
      notify(source, 'error', 'Kleidung', 'Kleidungsmenü ist aktuell nicht verfügbar.')
      return
    end

    local characterId = getCharacterIdBySource(source)
    local sex = getSexByCharacterId(characterId)
    local stored = getStoredSkinByCharacterId(characterId)

    TriggerClientEvent('rp:skin:openCreator', source, {
      mode = 'clothing',
      sex = stored and stored.sex or sex,
      model = stored and stored.model or nil,
      components = stored and stored.components or {},
      props = stored and stored.props or {},
      overlays = stored and stored.overlays or {}
    })
    return
  end

  local items = ShopItems[shopId] or {}
  local payload = {
    shopId = shop.id,
    shopLabel = shop.label,
    shopType = shop.type,
    cash = exports.rp_money:GetCash(source),
    bank = exports.rp_money:GetBank(source),
    items = items
  }

  OpenSession[source] = {
    shopId = shopId
  }

  TriggerClientEvent('rp:shops:openUI', source, payload)
end

local function validateOpenShopSession(source)
  local session = OpenSession[source]
  if not session then
    return nil
  end

  if not isNearShop(source, session.shopId) then
    OpenSession[source] = nil
    TriggerClientEvent('rp:shops:closeUI', source)
    notify(source, 'warning', 'Shop', 'Du hast den Shopbereich verlassen.')
    return nil
  end

  return session
end

RegisterNetEvent('rp:shops:requestPoints', function()
  TriggerClientEvent('rp:shops:receivePoints', source, getShopsForClient())
end)

RegisterNetEvent('rp:shops:requestOpen', function(shopId)
  local src = source
  shopId = tonumber(shopId) or 0

  if not exports.rp_core:CanUseRateLimitedAction(src, 'shop_open', 700) then
    return
  end

  if shopId <= 0 or not isNearShop(src, shopId) then
    notify(src, 'error', 'Shop', 'Du bist nicht am Shop.')
    return
  end

  openShop(src, shopId)
end)

RegisterNetEvent('rp:shops:close', function()
  OpenSession[source] = nil
end)

RegisterNetEvent('rp:shops:buyItem', function(data)
  local src = source
  local session = validateOpenShopSession(src)
  if not session then return end

  if not exports.rp_core:CanUseRateLimitedAction(src, 'shop_buy', 900) then
    return
  end

  if type(data) ~= 'table' then
    notify(src, 'error', 'Shop', 'Ungültige Anfrage.')
    return
  end

  local itemName = tostring(data.itemName or '')
  local quantity = math.floor(tonumber(data.quantity) or 0)
  local payType = tostring(data.payType or 'cash')
  if quantity < 1 or quantity > 100 then
    notify(src, 'error', 'Shop', 'Ungültige Menge.')
    return
  end

  if payType ~= 'cash' and payType ~= 'bank' then
    notify(src, 'error', 'Shop', 'Ungültige Zahlungsart.')
    return
  end

  local shopItems = ShopItems[session.shopId] or {}
  local selected = nil

  for i = 1, #shopItems do
    if shopItems[i].itemName == itemName then
      selected = shopItems[i]
      break
    end
  end

  if not selected then
    notify(src, 'error', 'Shop', 'Item nicht verfügbar.')
    return
  end

  local totalPrice = selected.price * quantity
  local removedMoney = false

  if payType == 'cash' then
    removedMoney = exports.rp_money:RemoveCash(src, totalPrice)
  else
    removedMoney = exports.rp_money:RemoveBank(src, totalPrice, 'system', 'shop_purchase')
  end

  if not removedMoney then
    notify(src, 'error', 'Shop', 'Nicht genug Geld.')
    return
  end

  local added, reason = exports.rp_inventory:AddItem(src, itemName, quantity)
  if not added then
    if payType == 'cash' then
      exports.rp_money:AddCash(src, totalPrice)
    else
      exports.rp_money:AddBank(src, totalPrice, 'system', 'shop_refund')
    end
    notify(src, 'error', 'Shop', reason or 'Kauf fehlgeschlagen.')
    return
  end

  notify(src, 'success', 'Shop', ('%dx %s gekauft für %d$.'):format(quantity, selected.label, totalPrice))

  local shop = ShopCache[session.shopId]
  MySQL.insert.await(
    'INSERT INTO audit_log (event_type, character_id, source, details) VALUES (?, ?, ?, ?)',
    {
      'shop_purchase',
      exports.rp_core:GetCharacterId(src),
      'rp_shops',
      json.encode({ shopId = session.shopId, shopLabel = shop and shop.label or 'unknown', item = itemName, qty = quantity, price = totalPrice, payType = payType })
    }
  )

  openShop(src, session.shopId)
end)

AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  ensureShopsSchema()
  loadShops()
end)

RegisterNetEvent('rp:shops:adminReload', function()
  loadShops()
  local players = GetPlayers()
  for i = 1, #players do
    local src = tonumber(players[i])
    if src then
      TriggerClientEvent('rp:shops:receivePoints', src, getShopsForClient())
    end
  end
end)

AddEventHandler('playerDropped', function()
  OpenSession[source] = nil
end)
