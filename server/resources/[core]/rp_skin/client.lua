local creating = false
local currentSex = 'm'
local currentMode = 'creator'
local creatorViewLockThreadRunning = false

local function clampInt(value, minValue, maxValue)
  value = math.floor(tonumber(value) or minValue)
  if value < minValue then value = minValue end
  if value > maxValue then value = maxValue end
  return value
end

local function loadModel(model)
  local hash = type(model) == 'string' and GetHashKey(model) or model
  if not IsModelInCdimage(hash) then
    return false
  end

  RequestModel(hash)
  local attempts = 0
  while not HasModelLoaded(hash) and attempts < 200 do
    attempts = attempts + 1
    Wait(10)
  end

  if not HasModelLoaded(hash) then
    return false
  end

  SetPlayerModel(PlayerId(), hash)
  SetModelAsNoLongerNeeded(hash)
  return true
end

local function ensureCreatorViewLockThread()
  if creatorViewLockThreadRunning then
    return
  end

  creatorViewLockThreadRunning = true

  CreateThread(function()
    while creating do
      -- Force stable third-person while the creator is open.
      SetFollowPedCamViewMode(0)
      DisableControlAction(0, 0, true)    -- Look left/right
      DisableControlAction(0, 1, true)    -- Look up/down
      DisableControlAction(0, 2, true)    -- Look up/down (alt)
      DisableControlAction(0, 24, true)   -- Attack
      DisableControlAction(0, 25, true)   -- Aim
      DisableControlAction(0, 241, true)  -- Mouse wheel up
      DisableControlAction(0, 242, true)  -- Mouse wheel down

      Wait(0)
    end

    creatorViewLockThreadRunning = false
  end)
end

local function getSkinDefaults(sex)
  local resolvedSex = (sex == 'f') and 'f' or 'm'

  return {
    sex = resolvedSex,
    components = {
      torso = 15,
      torsoTexture = 0,
      pants = 21,
      pantsTexture = 0,
      shoes = 34,
      shoesTexture = 0,
      hair = 0,
      hairTexture = 0,
      mask = 0,
      maskTexture = 0,
      chain = 0,
      chainTexture = 0
    },
    props = {
      hat = -1,
      hatTexture = 0,
      glasses = -1,
      glassesTexture = 0
    },
    overlays = {
      beard = -1,
      beardOpacity = 100,
      beardColor = 0,
      hairColor = 0,
      hairHighlight = 0
    }
  }
end

local function getComponentDrawableMax(ped, componentId)
  return math.max((GetNumberOfPedDrawableVariations(ped, componentId) or 1) - 1, 0)
end

local function getComponentTextureMax(ped, componentId, drawableId)
  return math.max((GetNumberOfPedTextureVariations(ped, componentId, drawableId) or 1) - 1, 0)
end

local function getPropDrawableMax(ped, propId)
  return math.max((GetNumberOfPedPropDrawableVariations(ped, propId) or 0) - 1, -1)
end

local function getPropTextureMax(ped, propId, drawableId)
  if drawableId < 0 then
    return 0
  end
  return math.max((GetNumberOfPedPropTextureVariations(ped, propId, drawableId) or 1) - 1, 0)
end

local function getHairColorMax()
  if GetNumHairColors then
    return math.max((GetNumHairColors() or 1) - 1, 0)
  end
  return 63
end

local function getBeardStyleMax()
  if GetNumHeadOverlayValues then
    return math.max((GetNumHeadOverlayValues(1) or 1) - 1, 0)
  end
  return 28
end

local function buildRangeData(skin)
  local ped = PlayerPedId()
  local componentSlots = RPSkinConfig.componentSlots or {}
  local propSlots = RPSkinConfig.propSlots or {}

  local ranges = {
    components = {},
    props = {},
    overlays = {
      beard = { min = -1, max = getBeardStyleMax() },
      beardOpacity = { min = 0, max = 100 },
      beardColor = { min = 0, max = getHairColorMax() },
      hairColor = { min = 0, max = getHairColorMax() },
      hairHighlight = { min = 0, max = getHairColorMax() }
    }
  }

  for key, slot in pairs(componentSlots) do
    local componentId = tonumber(slot.component) or 0
    local drawableMax = getComponentDrawableMax(ped, componentId)
    local drawableValue = clampInt((skin.components or {})[key], 0, drawableMax)

    ranges.components[key] = { min = 0, max = drawableMax }
    if slot.textureKey and slot.textureKey ~= '' then
      local textureMax = getComponentTextureMax(ped, componentId, drawableValue)
      ranges.components[slot.textureKey] = { min = 0, max = textureMax }
    end
  end

  for key, slot in pairs(propSlots) do
    local propId = tonumber(slot.prop) or 0
    local drawableMax = getPropDrawableMax(ped, propId)
    local drawableValue = clampInt((skin.props or {})[key], -1, drawableMax)

    ranges.props[key] = { min = -1, max = drawableMax }
    if slot.textureKey and slot.textureKey ~= '' then
      local textureMax = getPropTextureMax(ped, propId, drawableValue)
      ranges.props[slot.textureKey] = { min = 0, max = textureMax }
    end
  end

  return ranges
end

local function normalizeSkinData(payload)
  local incoming = payload and payload.skin or payload or {}
  local defaults = getSkinDefaults(incoming.sex)

  local out = {
    sex = defaults.sex,
    components = {},
    props = {},
    overlays = {}
  }

  local componentSlots = RPSkinConfig.componentSlots or {}
  local propSlots = RPSkinConfig.propSlots or {}

  for key, slot in pairs(componentSlots) do
    out.components[key] = tonumber((incoming.components or {})[key]) or slot.default or defaults.components[key] or 0
    if slot.textureKey and slot.textureKey ~= '' then
      out.components[slot.textureKey] = tonumber((incoming.components or {})[slot.textureKey]) or defaults.components[slot.textureKey] or 0
    end
  end

  for key, slot in pairs(propSlots) do
    out.props[key] = tonumber((incoming.props or {})[key]) or slot.default or defaults.props[key] or -1
    if slot.textureKey and slot.textureKey ~= '' then
      out.props[slot.textureKey] = tonumber((incoming.props or {})[slot.textureKey]) or defaults.props[slot.textureKey] or 0
    end
  end

  out.overlays.beard = tonumber((incoming.overlays or {}).beard) or defaults.overlays.beard
  out.overlays.beardOpacity = tonumber((incoming.overlays or {}).beardOpacity) or defaults.overlays.beardOpacity
  out.overlays.beardColor = tonumber((incoming.overlays or {}).beardColor) or defaults.overlays.beardColor
  out.overlays.hairColor = tonumber((incoming.overlays or {}).hairColor) or defaults.overlays.hairColor
  out.overlays.hairHighlight = tonumber((incoming.overlays or {}).hairHighlight) or defaults.overlays.hairHighlight

  out.sex = (incoming.sex == 'f') and 'f' or 'm'

  return out
end

local function applySkinData(payload)
  local ped = PlayerPedId()
  local skin = normalizeSkinData(payload)

  local componentSlots = RPSkinConfig.componentSlots or {}
  for key, slot in pairs(componentSlots) do
    local componentId = tonumber(slot.component) or 0
    local drawableMax = getComponentDrawableMax(ped, componentId)
    local drawable = clampInt(skin.components[key], 0, drawableMax)

    local texture = 0
    if slot.textureKey and slot.textureKey ~= '' then
      local textureMax = getComponentTextureMax(ped, componentId, drawable)
      texture = clampInt(skin.components[slot.textureKey], 0, textureMax)
      skin.components[slot.textureKey] = texture
    end

    skin.components[key] = drawable
    SetPedComponentVariation(ped, componentId, drawable, texture, 2)
  end

  local propSlots = RPSkinConfig.propSlots or {}
  for key, slot in pairs(propSlots) do
    local propId = tonumber(slot.prop) or 0
    local drawableMax = getPropDrawableMax(ped, propId)
    local drawable = clampInt(skin.props[key], -1, drawableMax)

    local texture = 0
    if slot.textureKey and slot.textureKey ~= '' then
      local textureMax = getPropTextureMax(ped, propId, drawable)
      texture = clampInt(skin.props[slot.textureKey], 0, textureMax)
      skin.props[slot.textureKey] = texture
    end

    skin.props[key] = drawable

    if drawable < 0 then
      ClearPedProp(ped, propId)
    else
      SetPedPropIndex(ped, propId, drawable, texture, true)
    end
  end

  local beardMax = getBeardStyleMax()
  local beard = clampInt(skin.overlays.beard, -1, beardMax)
  local beardOpacity = clampInt(skin.overlays.beardOpacity, 0, 100) / 100.0
  local hairColorMax = getHairColorMax()
  local beardColor = clampInt(skin.overlays.beardColor, 0, hairColorMax)
  local hairColor = clampInt(skin.overlays.hairColor, 0, hairColorMax)
  local hairHighlight = clampInt(skin.overlays.hairHighlight, 0, hairColorMax)

  if beard < 0 then
    SetPedHeadOverlay(ped, 1, 255, 0.0)
  else
    SetPedHeadOverlay(ped, 1, beard, beardOpacity)
    SetPedHeadOverlayColor(ped, 1, 1, beardColor, beardColor)
  end

  SetPedHairColor(ped, hairColor, hairHighlight)

  skin.overlays.beard = beard
  skin.overlays.beardOpacity = clampInt(skin.overlays.beardOpacity, 0, 100)
  skin.overlays.beardColor = beardColor
  skin.overlays.hairColor = hairColor
  skin.overlays.hairHighlight = hairHighlight

  return skin
end

local function pushOpenStateToNui(mode, skin)
  local modeLabel = 'Character Creator'
  local subtitle = 'Grundauswahl für deinen Startlook.'

  if mode == 'skin' then
    modeLabel = 'Skin Menü'
    subtitle = 'Aussehen und Kleidung anpassen.'
  elseif mode == 'clothing' then
    modeLabel = 'Kleidungsshop'
    subtitle = 'Kleidung und Stil konfigurieren.'
  end

  SendNUIMessage({
    action = 'open',
    data = {
      mode = mode,
      title = modeLabel,
      subtitle = subtitle,
      skin = skin,
      ranges = buildRangeData(skin)
    }
  })
end

local function openCreator(defaults)
  creating = true

  local initial = normalizeSkinData({
    sex = defaults and defaults.sex or 'm',
    components = defaults and defaults.components or {},
    props = defaults and defaults.props or {},
    overlays = defaults and defaults.overlays or {}
  })

  currentSex = initial.sex
  currentMode = tostring(defaults and defaults.mode or 'creator')

  if defaults and defaults.model and defaults.model ~= '' then
    loadModel(defaults.model)
  elseif currentSex == 'f' then
    loadModel(RPSkinConfig.defaultFemaleModel)
  else
    loadModel(RPSkinConfig.defaultMaleModel)
  end

  initial = applySkinData({ skin = initial })

  SetNuiFocus(true, true)
  pushOpenStateToNui(currentMode, initial)

  local ped = PlayerPedId()
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  SetEntityCollision(ped, true, true)
  SetFollowPedCamViewMode(0)
  ensureCreatorViewLockThread()
  TriggerEvent('rp:hud:toggle', false)
end

RegisterNetEvent('rp:skin:openCreator', function(defaults)
  openCreator(defaults)
end)

RegisterNetEvent('rp:skin:applyOrOpen', function(data)
  if data and data.isNew then
    openCreator({ sex = data.sex or 'm', mode = 'creator' })
    return
  end

  if data and data.model then
    loadModel(data.model)
  end

  applySkinData(data or {})
end)

RegisterNUICallback('previewSkin', function(data, cb)
  if not creating then
    cb({ ok = false })
    return
  end

  local nextSex = (data and data.sex == 'f') and 'f' or 'm'
  if nextSex ~= currentSex then
    currentSex = nextSex
    if currentSex == 'f' then
      loadModel(RPSkinConfig.defaultFemaleModel)
    else
      loadModel(RPSkinConfig.defaultMaleModel)
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityCollision(ped, true, true)
    SetFollowPedCamViewMode(0)
  end

  local applied = applySkinData({
    skin = {
      sex = currentSex,
      components = data and data.components or {},
      props = data and data.props or {},
      overlays = data and data.overlays or {}
    }
  })

  cb({
    ok = true,
    skin = applied,
    ranges = buildRangeData(applied)
  })
end)

RegisterNUICallback('rotateView', function(data, cb)
  if not creating then
    cb({ ok = false })
    return
  end

  local delta = tonumber(data and data.delta) or 0.0
  if delta ~= 0.0 then
    local ped = PlayerPedId()
    SetEntityHeading(ped, (GetEntityHeading(ped) + delta) % 360.0)
    SetFollowPedCamViewMode(0)
  end

  cb({ ok = true })
end)

RegisterNUICallback('saveSkin', function(data, cb)
  if not creating then
    cb({ ok = false, message = 'Creator nicht offen.' })
    return
  end

  local clean = applySkinData({
    skin = {
      sex = (data and data.sex == 'f') and 'f' or 'm',
      components = data and data.components or {},
      props = data and data.props or {},
      overlays = data and data.overlays or {}
    }
  })

  local payload = {
    mode = currentMode,
    model = clean.sex == 'f' and RPSkinConfig.defaultFemaleModel or RPSkinConfig.defaultMaleModel,
    skin = clean
  }

  TriggerServerEvent('rp:skin:save', payload)
  cb({ ok = true })
end)

RegisterNetEvent('rp:skin:closeCreator', function()
  creating = false
  currentMode = 'creator'
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })

  local ped = PlayerPedId()
  FreezeEntityPosition(ped, false)
  SetEntityInvincible(ped, false)
  SetFollowPedCamViewMode(0)
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  creating = false
  SetNuiFocus(false, false)
end)
