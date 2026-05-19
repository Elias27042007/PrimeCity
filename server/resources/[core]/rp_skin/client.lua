local creating = false
local currentSex = 'm'
local currentMode = 'creator'
local creatorViewLockThreadRunning = false
local creatorCam = nil
local creatorAnchor = nil
local creatorCameraYawOffset = 0.0
local creatorCameraDistance = nil
local cancelSnapshot = nil

local function clampInt(value, minValue, maxValue)
  value = math.floor(tonumber(value) or minValue)
  if value < minValue then value = minValue end
  if value > maxValue then value = maxValue end
  return value
end

local function deepCopyTable(value)
  if type(value) ~= 'table' then
    return value
  end

  local out = {}
  for key, entry in pairs(value) do
    out[key] = deepCopyTable(entry)
  end

  return out
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

local function destroyCreatorCamera()
  if creatorCam and DoesCamExist(creatorCam) then
    RenderScriptCams(false, true, 250, true, true)
    DestroyCam(creatorCam, false)
  end

  creatorCam = nil
  creatorAnchor = nil
  creatorCameraYawOffset = 0.0
  creatorCameraDistance = nil
  ClearFocus()
end

local function updateCreatorCamera()
  if not creating then
    return
  end

  local ped = PlayerPedId()
  if ped == 0 or not DoesEntityExist(ped) then
    return
  end

  if not creatorCam or not DoesCamExist(creatorCam) then
    creatorCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  end

  local cfg = RPSkinConfig.camera or {}
  local baseDistance = tonumber(cfg.distance) or 2.7
  if type(creatorCameraDistance) ~= 'number' then
    creatorCameraDistance = baseDistance
  end

  local distance = creatorCameraDistance
  local height = tonumber(cfg.height) or 1.15
  local targetHeight = tonumber(cfg.targetHeight) or -0.25
  local fov = tonumber(cfg.fov) or 76.0

  local heading = (creatorAnchor and creatorAnchor.heading) or GetEntityHeading(ped)
  local headingRad = math.rad(heading)
  local yawRad = math.rad(creatorCameraYawOffset or 0.0)

  local forwardX = -math.sin(headingRad)
  local forwardY = math.cos(headingRad)
  local rightX = math.cos(headingRad)
  local rightY = math.sin(headingRad)

  local forwardDistance = distance * math.cos(yawRad)
  local rightDistance = distance * math.sin(yawRad)

  local coords = GetEntityCoords(ped)
  local camX = coords.x + (forwardX * forwardDistance) + (rightX * rightDistance)
  local camY = coords.y + (forwardY * forwardDistance) + (rightY * rightDistance)
  local camZ = coords.z + height

  SetCamCoord(creatorCam, camX, camY, camZ)
  PointCamAtCoord(creatorCam, coords.x, coords.y, coords.z + targetHeight)
  SetCamFov(creatorCam, fov)
  SetFocusPosAndVel(coords.x, coords.y, coords.z + 0.5, 0.0, 0.0, 0.0)

  SetCamActive(creatorCam, true)
  RenderScriptCams(true, false, 0, true, true)
end

local function adjustCreatorCameraDistance(direction)
  local cfg = RPSkinConfig.camera or {}
  local baseDistance = tonumber(cfg.distance) or 2.7
  local zoomStep = tonumber(cfg.zoomStep) or 0.3
  local zoomMin = tonumber(cfg.minDistance) or 1.2
  local zoomMax = tonumber(cfg.maxDistance) or 9.5

  if type(creatorCameraDistance) ~= 'number' then
    creatorCameraDistance = baseDistance
  end

  local nextDistance = creatorCameraDistance + (zoomStep * (tonumber(direction) or 0))
  if nextDistance < zoomMin then
    nextDistance = zoomMin
  elseif nextDistance > zoomMax then
    nextDistance = zoomMax
  end

  creatorCameraDistance = nextDistance
  updateCreatorCamera()
end

local function setCreatorAnchorFromPed()
  local ped = PlayerPedId()
  if ped == 0 or not DoesEntityExist(ped) then
    return
  end

  local coords = GetEntityCoords(ped)
  creatorAnchor = {
    x = coords.x,
    y = coords.y,
    z = coords.z,
    heading = GetEntityHeading(ped)
  }
end

local function enforceCreatorAnchor()
  if not creatorAnchor then
    return
  end

  local ped = PlayerPedId()
  if ped == 0 or not DoesEntityExist(ped) then
    return
  end

  local coords = GetEntityCoords(ped)
  local dx = math.abs(coords.x - creatorAnchor.x)
  local dy = math.abs(coords.y - creatorAnchor.y)
  local dz = math.abs(coords.z - creatorAnchor.z)
  local currentHeading = GetEntityHeading(ped)
  local headingDiff = math.abs((((currentHeading - creatorAnchor.heading) + 540.0) % 360.0) - 180.0)

  if dx > 0.01 or dy > 0.01 or dz > 0.01 then
    SetEntityCoordsNoOffset(ped, creatorAnchor.x, creatorAnchor.y, creatorAnchor.z, false, false, false)
  end

  if headingDiff > 0.1 then
    SetEntityHeading(ped, creatorAnchor.heading)
  end
end

local function ensureCreatorViewLockThread()
  if creatorViewLockThreadRunning then
    return
  end

  creatorViewLockThreadRunning = true

  CreateThread(function()
    while creating do
      InvalidateIdleCam()
      InvalidateVehicleIdleCam()
      enforceCreatorAnchor()
      updateCreatorCamera()
      SetFollowPedCamViewMode(2)
      SetFollowVehicleCamViewMode(2)
      DisableControlAction(0, 80, true)
      DisableControlAction(0, 26, true)
      DisableControlAction(0, 0, true)
      DisableControlAction(0, 1, true)
      DisableControlAction(0, 2, true)
      DisableControlAction(0, 24, true)
      DisableControlAction(0, 25, true)
      DisableControlAction(0, 241, true)
      DisableControlAction(0, 242, true)

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
      tshirt = 15,
      tshirtTexture = 0,
      arms = 15,
      armsTexture = 0,
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
      eyebrows = -1,
      eyebrowsOpacity = 100,
      eyebrowsColor = 0,
      hairColor = 0,
      hairHighlight = 0
    },
    features = {
      headBlendShapeFirst = 21,
      headBlendShapeSecond = 0,
      headBlendSkinFirst = 21,
      headBlendSkinSecond = 0,
      faceShape = 50,
      eyes = 0,
      eyeColor = 0,
      bodyShape = 50,
      eyebrows = -1,
      eyebrowsColor = 0
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

local function getOverlayStyleMax(overlayIndex, fallback)
  if GetNumHeadOverlayValues then
    local nativeMax = math.max((GetNumHeadOverlayValues(overlayIndex) or 0) - 1, -1)
    if nativeMax >= 0 then
      return nativeMax
    end
  end

  return tonumber(fallback) or 30
end

local function getBeardStyleMax()
  local configMax = tonumber((((RPSkinConfig or {}).overlaySlots or {}).beard or {}).max)
  return getOverlayStyleMax(1, configMax or 28)
end

local function getEyebrowStyleMax()
  local configMax = tonumber((((RPSkinConfig or {}).overlaySlots or {}).eyebrows or {}).max)
  return getOverlayStyleMax(2, configMax or 33)
end

local function buildRangeData(skin)
  local ped = PlayerPedId()
  local componentSlots = RPSkinConfig.componentSlots or {}
  local propSlots = RPSkinConfig.propSlots or {}
  local featureSlots = RPSkinConfig.featureSlots or {}
  local incomingFeatures = type(incoming.features) == 'table' and incoming.features or {}
  local hasHeadBlendFields = incomingFeatures.headBlendShapeFirst ~= nil

  local ranges = {
    components = {},
    props = {},
    overlays = {
      beard = { min = -1, max = getBeardStyleMax() },
      beardOpacity = { min = 0, max = 100 },
      beardColor = { min = 0, max = getHairColorMax() },
      eyebrows = { min = -1, max = getEyebrowStyleMax() },
      eyebrowsOpacity = { min = 0, max = 100 },
      eyebrowsColor = { min = 0, max = getHairColorMax() }
    },
    features = {}
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

  for key, slot in pairs(featureSlots) do
    local minValue = tonumber(slot.min) or -100
    local maxValue = tonumber(slot.max) or 100

    if key == 'eyebrows' then
      maxValue = getEyebrowStyleMax()
    elseif key == 'eyebrowsColor' then
      maxValue = getHairColorMax()
    end

    ranges.features[key] = {
      min = minValue,
      max = maxValue
    }
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
    overlays = {},
    features = {}
  }

  local componentSlots = RPSkinConfig.componentSlots or {}
  local propSlots = RPSkinConfig.propSlots or {}
  local featureSlots = RPSkinConfig.featureSlots or {}

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
  out.overlays.eyebrows = tonumber((incoming.overlays or {}).eyebrows) or tonumber((incoming.features or {}).eyebrows) or defaults.overlays.eyebrows
  out.overlays.eyebrowsOpacity = tonumber((incoming.overlays or {}).eyebrowsOpacity) or defaults.overlays.eyebrowsOpacity
  out.overlays.eyebrowsColor = tonumber((incoming.overlays or {}).eyebrowsColor) or tonumber((incoming.features or {}).eyebrowsColor) or defaults.overlays.eyebrowsColor

  local incomingHairColor = tonumber((incoming.overlays or {}).hairColor)
  local incomingHairHighlight = tonumber((incoming.overlays or {}).hairHighlight)
  local hairTone = tonumber((incoming.components or {}).hairTexture)

  out.overlays.hairColor = incomingHairColor or hairTone or defaults.overlays.hairColor
  out.overlays.hairHighlight = incomingHairHighlight or hairTone or defaults.overlays.hairHighlight

  for key, slot in pairs(featureSlots) do
    local defaultValue = tonumber(slot.default)
    if defaultValue == nil then
      defaultValue = 0
    end

    local incomingValue = tonumber(incomingFeatures[key])
    if incomingValue == nil then
      if key == 'eyebrows' then
        incomingValue = tonumber((incoming.overlays or {}).eyebrows)
      elseif key == 'eyebrowsColor' then
        incomingValue = tonumber((incoming.overlays or {}).eyebrowsColor)
      end
    end

    if not hasHeadBlendFields and (key == 'faceShape' or key == 'bodyShape') and incomingValue ~= nil then
      incomingValue = math.floor(((incomingValue + 100) / 2) + 0.5)
    end

    out.features[key] = incomingValue or defaultValue
  end

  out.sex = (incoming.sex == 'f') and 'f' or 'm'

  return out
end

local function applySkinData(payload)
  local ped = PlayerPedId()
  local skin = normalizeSkinData(payload)
  local featureSlots = RPSkinConfig.featureSlots or {}

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

  local function clampFeatureValue(key, fallback)
    local slot = featureSlots[key] or {}
    local minValue = tonumber(slot.min) or -100
    local maxValue = tonumber(slot.max) or 100
    local defaultValue = tonumber(slot.default)
    if defaultValue == nil then
      defaultValue = minValue
    end

    local value = tonumber(skin.features[key])
    if value == nil then
      value = fallback
    end
    value = clampInt(value or defaultValue, minValue, maxValue)
    skin.features[key] = value
    return value
  end

  local headBlendShapeFirst = clampFeatureValue('headBlendShapeFirst', 21)
  local headBlendShapeSecond = clampFeatureValue('headBlendShapeSecond', 0)
  local headBlendSkinFirst = clampFeatureValue('headBlendSkinFirst', 21)
  local headBlendSkinSecond = clampFeatureValue('headBlendSkinSecond', 0)
  local headBlendShapeMix = clampFeatureValue('faceShape', 50) / 100.0
  local headBlendSkinMix = clampFeatureValue('bodyShape', 50) / 100.0

  SetPedHeadBlendData(
    ped,
    headBlendShapeFirst,
    headBlendShapeSecond,
    0,
    headBlendSkinFirst,
    headBlendSkinSecond,
    0,
    headBlendShapeMix,
    headBlendSkinMix,
    0.0,
    false
  )

  local beardMax = getBeardStyleMax()
  local beard = clampInt(skin.overlays.beard, -1, beardMax)
  local beardOpacityRaw = tonumber(skin.overlays.beardOpacity)
  if beard >= 0 and (not beardOpacityRaw or beardOpacityRaw <= 0) then
    beardOpacityRaw = 100
  end
  local beardOpacity = clampInt(beardOpacityRaw or 100, 0, 100) / 100.0

  local hairColorMax = getHairColorMax()
  local beardColor = clampInt(skin.overlays.beardColor, 0, hairColorMax)
  local hairTone = clampInt(skin.components.hairTexture or 0, 0, hairColorMax)
  local hairColor = hairTone
  local hairHighlight = hairTone

  if beard < 0 then
    SetPedHeadOverlay(ped, 1, 255, 0.0)
  else
    SetPedHeadOverlay(ped, 1, beard, beardOpacity)
    SetPedHeadOverlayColor(ped, 1, 1, beardColor, beardColor)
  end

  local eyebrowMax = getEyebrowStyleMax()
  local eyebrowStyle = clampInt(skin.features.eyebrows or skin.overlays.eyebrows or -1, -1, eyebrowMax)
  local eyebrowColor = clampInt(skin.features.eyebrowsColor or skin.overlays.eyebrowsColor or 0, 0, hairColorMax)

  if eyebrowStyle < 0 then
    SetPedHeadOverlay(ped, 2, 255, 0.0)
  else
    SetPedHeadOverlay(ped, 2, eyebrowStyle, 1.0)
    SetPedHeadOverlayColor(ped, 2, 1, eyebrowColor, eyebrowColor)
  end

  for key, slot in pairs(featureSlots) do
    local value = tonumber(skin.features[key])
    local minValue = tonumber(slot.min) or -100
    local maxValue = tonumber(slot.max) or 100
    local defaultValue = tonumber(slot.default)
    if defaultValue == nil then
      defaultValue = minValue
    end

    value = clampInt(value or defaultValue, minValue, maxValue)
    skin.features[key] = value

    if slot.type == 'faceFeature' then
      local normalized = value / 100.0
      SetPedFaceFeature(ped, tonumber(slot.index) or 0, normalized)
    elseif slot.type == 'eyeColor' then
      SetPedEyeColor(ped, value)
    end
  end

  SetPedHairColor(ped, hairColor, hairHighlight)

  skin.overlays.beard = beard
  skin.overlays.beardOpacity = clampInt(beardOpacityRaw or 100, 0, 100)
  skin.overlays.beardColor = beardColor
  skin.overlays.eyebrows = eyebrowStyle
  skin.overlays.eyebrowsOpacity = 100
  skin.overlays.eyebrowsColor = eyebrowColor
  skin.overlays.hairColor = hairColor
  skin.overlays.hairHighlight = hairHighlight
  skin.features.eyebrows = eyebrowStyle
  skin.features.eyebrowsColor = eyebrowColor

  return skin
end

local function captureCurrentSkinData(sexFallback)
  local ped = PlayerPedId()
  local captured = {
    sex = (sexFallback == 'f') and 'f' or 'm',
    components = {},
    props = {},
    overlays = {},
    features = {}
  }

  local componentSlots = RPSkinConfig.componentSlots or {}
  for key, slot in pairs(componentSlots) do
    local componentId = tonumber(slot.component) or 0
    captured.components[key] = GetPedDrawableVariation(ped, componentId)

    if slot.textureKey and slot.textureKey ~= '' then
      captured.components[slot.textureKey] = GetPedTextureVariation(ped, componentId)
    end
  end

  local propSlots = RPSkinConfig.propSlots or {}
  for key, slot in pairs(propSlots) do
    local propId = tonumber(slot.prop) or 0
    local drawable = GetPedPropIndex(ped, propId)
    if drawable == nil then
      drawable = -1
    end
    captured.props[key] = drawable

    if slot.textureKey and slot.textureKey ~= '' then
      if drawable and drawable >= 0 then
        captured.props[slot.textureKey] = GetPedPropTextureIndex(ped, propId)
      else
        captured.props[slot.textureKey] = 0
      end
    end
  end

  local hairColor = 0
  local hairHighlight = 0
  if GetPedHairColor then
    hairColor = tonumber(GetPedHairColor(ped)) or 0
  end
  if GetPedHairHighlightColor then
    hairHighlight = tonumber(GetPedHairHighlightColor(ped)) or 0
  else
    hairHighlight = hairColor
  end

  local beardValue = -1
  if GetPedHeadOverlayValue then
    local overlay = tonumber(GetPedHeadOverlayValue(ped, 1))
    if overlay ~= nil and overlay >= 0 and overlay < 255 then
      beardValue = overlay
    end
  end

  local eyebrowsValue = -1
  if GetPedHeadOverlayValue then
    local overlay = tonumber(GetPedHeadOverlayValue(ped, 2))
    if overlay ~= nil and overlay >= 0 and overlay < 255 then
      eyebrowsValue = overlay
    end
  end

  local eyeColor = 0
  if GetPedEyeColor then
    eyeColor = tonumber(GetPedEyeColor(ped)) or 0
  end

  captured.overlays.beard = beardValue
  captured.overlays.beardOpacity = 100
  captured.overlays.beardColor = hairColor
  captured.overlays.eyebrows = eyebrowsValue
  captured.overlays.eyebrowsOpacity = 100
  captured.overlays.eyebrowsColor = hairColor
  captured.overlays.hairColor = clampInt(captured.components.hairTexture or 0, 0, getHairColorMax())
  captured.overlays.hairHighlight = captured.overlays.hairColor

  captured.features.headBlendShapeFirst = 21
  captured.features.headBlendShapeSecond = 0
  captured.features.headBlendSkinFirst = 21
  captured.features.headBlendSkinSecond = 0
  captured.features.faceShape = 50
  captured.features.eyes = 0
  captured.features.eyeColor = eyeColor
  captured.features.bodyShape = 50
  captured.features.eyebrows = eyebrowsValue
  captured.features.eyebrowsColor = hairColor

  return captured
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
    overlays = defaults and defaults.overlays or {},
    features = defaults and defaults.features or {}
  })

  currentSex = initial.sex
  currentMode = tostring(defaults and defaults.mode or 'creator')
  creatorCameraYawOffset = 0.0
  creatorCameraDistance = tonumber((RPSkinConfig.camera or {}).distance) or 2.7

  if defaults and defaults.model and defaults.model ~= '' then
    loadModel(defaults.model)
  elseif currentSex == 'f' then
    loadModel(RPSkinConfig.defaultFemaleModel)
  else
    loadModel(RPSkinConfig.defaultMaleModel)
  end

  initial = applySkinData({ skin = initial })
  cancelSnapshot = deepCopyTable(initial)

  SetNuiFocus(true, true)
  pushOpenStateToNui(currentMode, initial)

  local ped = PlayerPedId()
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  SetEntityCollision(ped, true, true)
  SetFollowPedCamViewMode(2)
  SetFollowVehicleCamViewMode(2)
  setCreatorAnchorFromPed()
  updateCreatorCamera()
  ensureCreatorViewLockThread()
  TriggerEvent('rp:hud:toggle', false)
end

RegisterNetEvent('rp:skin:openCreator', function(defaults)
  openCreator(defaults)
end)

RegisterNetEvent('rp:skin:openCurrent', function(defaults)
  local payload = type(defaults) == 'table' and defaults or {}
  local liveSkin = captureCurrentSkinData(payload.sex or 'm')

  local finalPayload = {
    mode = payload.mode or 'skin',
    sex = liveSkin.sex,
    model = payload.model,
    components = liveSkin.components,
    props = liveSkin.props,
    overlays = liveSkin.overlays,
    features = liveSkin.features
  }

  if type(payload.overlays) == 'table' then
    for key, value in pairs(payload.overlays) do
      finalPayload.overlays[key] = value
    end
  end

  if type(payload.features) == 'table' then
    for key, value in pairs(payload.features) do
      finalPayload.features[key] = value
    end
  end

  openCreator(finalPayload)
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
    SetFollowPedCamViewMode(2)
    SetFollowVehicleCamViewMode(2)
    setCreatorAnchorFromPed()
    updateCreatorCamera()
  end

  local applied = applySkinData({
    skin = {
      sex = currentSex,
      components = data and data.components or {},
      props = data and data.props or {},
      overlays = data and data.overlays or {},
      features = data and data.features or {}
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

  local cfg = RPSkinConfig.camera or {}
  local step = tonumber(cfg.rotateStep) or 7.0
  local direction = tonumber(data and data.direction) or 0
  local delta = tonumber(data and data.delta)

  if not delta then
    delta = direction * step
  end

  creatorCameraYawOffset = (creatorCameraYawOffset + delta) % 360.0
  updateCreatorCamera()

  cb({ ok = true })
end)

RegisterNUICallback('zoomView', function(data, cb)
  if not creating then
    cb({ ok = false })
    return
  end

  local direction = tonumber(data and data.direction) or 0
  if direction ~= 0 then
    adjustCreatorCameraDistance(direction)
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
      overlays = data and data.overlays or {},
      features = data and data.features or {}
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

RegisterNUICallback('cancelSkin', function(_, cb)
  if not creating then
    cb({ ok = false })
    return
  end

  if type(cancelSnapshot) == 'table' then
    applySkinData({ skin = cancelSnapshot })
  end

  creating = false
  currentMode = 'creator'
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  destroyCreatorCamera()

  local ped = PlayerPedId()
  FreezeEntityPosition(ped, false)
  SetEntityInvincible(ped, false)
  SetFollowPedCamViewMode(2)
  SetFollowVehicleCamViewMode(2)
  cancelSnapshot = nil

  cb({ ok = true })
end)

RegisterNetEvent('rp:skin:closeCreator', function()
  creating = false
  currentMode = 'creator'
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  destroyCreatorCamera()

  local ped = PlayerPedId()
  FreezeEntityPosition(ped, false)
  SetEntityInvincible(ped, false)
  SetFollowPedCamViewMode(2)
  SetFollowVehicleCamViewMode(2)
  cancelSnapshot = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  creating = false
  destroyCreatorCamera()
  SetNuiFocus(false, false)
  cancelSnapshot = nil
end)
