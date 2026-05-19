RPSkinConfig = {
  defaultMaleModel = 'mp_m_freemode_01',
  defaultFemaleModel = 'mp_f_freemode_01',

  componentSlots = {
    tshirt = { component = 8, textureKey = 'tshirtTexture', default = 15 },
    arms = { component = 3, textureKey = 'armsTexture', default = 15 },
    torso = { component = 11, textureKey = 'torsoTexture', default = 15 },
    pants = { component = 4, textureKey = 'pantsTexture', default = 21 },
    shoes = { component = 6, textureKey = 'shoesTexture', default = 34 },
    hair = { component = 2, textureKey = 'hairTexture', default = 0 },
    mask = { component = 1, textureKey = 'maskTexture', default = 0 },
    chain = { component = 7, textureKey = 'chainTexture', default = 0 }
  },

  propSlots = {
    hat = { prop = 0, textureKey = 'hatTexture', default = -1 },
    glasses = { prop = 1, textureKey = 'glassesTexture', default = -1 }
  },

  overlaySlots = {
    beard = { overlay = 1, default = -1, max = 28, colorType = 1, colorKey = 'beardColor', opacityKey = 'beardOpacity' },
    eyebrows = { overlay = 2, default = -1, max = 33, colorType = 1, colorKey = 'eyebrowsColor', opacityKey = 'eyebrowsOpacity' }
  },

  colorSlots = {
    hairColor = { default = 0, max = 63 },
    hairHighlight = { default = 0, max = 63 }
  },

  featureSlots = {
    headBlendShapeFirst = { default = 21, min = 0, max = 45, type = 'headBlendParent' },
    headBlendShapeSecond = { default = 0, min = 0, max = 45, type = 'headBlendParent' },
    headBlendSkinFirst = { default = 21, min = 0, max = 45, type = 'headBlendParent' },
    headBlendSkinSecond = { default = 0, min = 0, max = 45, type = 'headBlendParent' },
    shapeVersion = { default = 2, min = 1, max = 2, type = 'meta' },
    faceShape = { default = 0, min = -100, max = 100, type = 'headBlendShapeMix' },
    eyes = { default = 0, min = -100, max = 100, type = 'faceFeature', index = 11 },
    eyeColor = { default = 0, min = 0, max = 30, type = 'eyeColor' },
    bodyShape = { default = 0, min = -100, max = 100, type = 'headBlendSkinMix' },
    eyebrows = { default = -1, min = -1, max = 33, type = 'overlay', index = 2, colorType = 1 },
    eyebrowsColor = { default = 0, min = 0, max = 63, type = 'overlayColor', overlay = 2, colorType = 1 }
  },

  camera = {
    rotateStep = 7,
    distance = 2.7,
    minDistance = 0.6,
    maxDistance = 9.5,
    zoomStep = 0.3,
    height = 1.15,
    targetHeight = -0.25,
    fov = 76.0,
    featureDistance = 0.9,
    featureMinDistance = 0.35,
    featureMaxDistance = 4.5,
    featureTargetHeight = 0.62,
    featureHeight = 0.74,
    featureFov = 54.0
  }
}
