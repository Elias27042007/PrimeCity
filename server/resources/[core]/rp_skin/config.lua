RPSkinConfig = {
  defaultMaleModel = 'mp_m_freemode_01',
  defaultFemaleModel = 'mp_f_freemode_01',

  componentSlots = {
    tshirt = { component = 8, textureKey = 'tshirtTexture', default = 15 },
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
    beard = { overlay = 1, default = -1, max = 28, colorType = 1, colorKey = 'beardColor', opacityKey = 'beardOpacity' }
  },

  colorSlots = {
    hairColor = { default = 0, max = 63 },
    hairHighlight = { default = 0, max = 63 }
  },

  camera = {
    rotateStep = 7,
    distance = 8.2,
    height = 1.05,
    targetHeight = -0.15,
    fov = 72.0
  }
}
