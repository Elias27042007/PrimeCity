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

  local clean = {
    sex = (skin.sex == 'f') and 'f' or 'm',
    components = {
      torso = sanitizeInt(components.torso, 15, 255),
      torsoTexture = sanitizeInt(components.torsoTexture, 0, 255),
      pants = sanitizeInt(components.pants, 21, 255),
      pantsTexture = sanitizeInt(components.pantsTexture, 0, 255),
      shoes = sanitizeInt(components.shoes, 34, 255),
      shoesTexture = sanitizeInt(components.shoesTexture, 0, 255),
      hair = sanitizeInt(components.hair, 0, 255),
      hairTexture = sanitizeInt(components.hairTexture, 0, 255),
      mask = sanitizeInt(components.mask, 0, 255),
      maskTexture = sanitizeInt(components.maskTexture, 0, 255),
      chain = sanitizeInt(components.chain, 0, 255),
      chainTexture = sanitizeInt(components.chainTexture, 0, 255)
    },
    props = {
      hat = sanitizeInt(props.hat, -1, 255),
      hatTexture = sanitizeInt(props.hatTexture, 0, 255),
      glasses = sanitizeInt(props.glasses, -1, 255),
      glassesTexture = sanitizeInt(props.glassesTexture, 0, 255)
    },
    overlays = {
      beard = sanitizeInt(overlays.beard, -1, 255),
      beardOpacity = sanitizeInt(overlays.beardOpacity, 0, 100),
      beardColor = sanitizeInt(overlays.beardColor, 0, 63),
      hairColor = sanitizeInt(overlays.hairColor, 0, 63),
      hairHighlight = sanitizeInt(overlays.hairHighlight, 0, 63)
    }
  }

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
