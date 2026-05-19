local LastSave = {}

local function sanitizeInt(value, minValue, maxValue)
  value = math.floor(tonumber(value) or minValue)
  if value < minValue then value = minValue end
  if value > maxValue then value = maxValue end
  return value
end

local function notify(source, ntype, title, message)
  TriggerClientEvent('rp:notify', source, {
    type = ntype,
    title = title,
    message = message
  })
end

RegisterNetEvent('rp:skin:save', function(payload)
  local src = source

  local now = GetGameTimer()
  if LastSave[src] and now < LastSave[src] then
    notify(src, 'warning', 'Skin', 'Bitte warte kurz.')
    return
  end
  LastSave[src] = now + 2500

  if type(payload) ~= 'table' then
    notify(src, 'error', 'Skin', 'Ungültige Skin-Daten.')
    return
  end

  local skin = type(payload.skin) == 'table' and payload.skin or {}
  local components = type(skin.components) == 'table' and skin.components or {}
  local props = type(skin.props) == 'table' and skin.props or {}
  local overlays = type(skin.overlays) == 'table' and skin.overlays or {}
  local features = type(skin.features) == 'table' and skin.features or {}

  local clean = {
    sex = (skin.sex == 'f') and 'f' or 'm',
    components = {},
    props = {},
    overlays = {},
    features = {}
  }

  local componentSlots = RPSkinConfig and RPSkinConfig.componentSlots or {}
  for key, slot in pairs(componentSlots) do
    local defaultValue = tonumber(slot.default) or 0
    clean.components[key] = sanitizeInt(components[key], defaultValue, 255)

    local textureKey = tostring(slot.textureKey or '')
    if textureKey ~= '' then
      clean.components[textureKey] = sanitizeInt(components[textureKey], 0, 255)
    end
  end

  local propSlots = RPSkinConfig and RPSkinConfig.propSlots or {}
  for key, slot in pairs(propSlots) do
    local defaultValue = tonumber(slot.default)
    if defaultValue == nil then
      defaultValue = -1
    end
    clean.props[key] = sanitizeInt(props[key], defaultValue, 255)

    local textureKey = tostring(slot.textureKey or '')
    if textureKey ~= '' then
      clean.props[textureKey] = sanitizeInt(props[textureKey], 0, 255)
    end
  end

  clean.overlays.beard = sanitizeInt(overlays.beard, -1, 255)
  clean.overlays.beardOpacity = sanitizeInt(overlays.beardOpacity, 0, 100)
  clean.overlays.beardColor = sanitizeInt(overlays.beardColor, 0, 63)
  clean.overlays.eyebrows = sanitizeInt(overlays.eyebrows, -1, 255)
  clean.overlays.eyebrowsOpacity = sanitizeInt(overlays.eyebrowsOpacity, 0, 100)
  clean.overlays.eyebrowsColor = sanitizeInt(overlays.eyebrowsColor, 0, 63)
  clean.overlays.hairColor = sanitizeInt(overlays.hairColor, 0, 63)
  clean.overlays.hairHighlight = sanitizeInt(overlays.hairHighlight, 0, 63)

  local featureSlots = RPSkinConfig and RPSkinConfig.featureSlots or {}
  for key, slot in pairs(featureSlots) do
    local minValue = tonumber(slot.min) or -100
    local maxValue = tonumber(slot.max) or 100
    local defaultValue = tonumber(slot.default)
    if defaultValue == nil then
      defaultValue = minValue
    end
    clean.features[key] = sanitizeInt(features[key], defaultValue, maxValue)
  end

  local success, reason = exports.rp_core:FinalizeCharacterSetup(src, {
    model = payload.model,
    skin = clean
  })

  if not success then
    notify(src, 'error', 'Skin', reason or 'Speichern fehlgeschlagen.')
    return
  end

  TriggerClientEvent('rp:skin:closeCreator', src)

  local mode = tostring(payload.mode or 'creator')
  if mode == 'clothing' then
    notify(src, 'success', 'Kleidung', 'Kleidung wurde gespeichert.')
  else
    notify(src, 'success', 'Skin', 'Skin gespeichert.')
  end
end)

AddEventHandler('playerDropped', function()
  LastSave[source] = nil
end)
