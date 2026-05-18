RPCoreConfig = {
  locale = 'de',
  identifiers = {
    allowIpFallback = true
  },
  identity = {
    minNameLength = 2,
    maxNameLength = 24,
    minHeight = 120,
    maxHeight = 230,
    maxNationalityLength = 32
  },
  money = {
    startCash = 500,
    startBank = 2500
  },
  spawn = {
    fallback = vector4(-1037.66, -2737.82, 20.1693, 327.0)
  },
  save = {
    positionIntervalMs = 30000
  },
  timeSync = {
    enabled = true,
    broadcastIntervalMs = 1000,
    clientOverrideIntervalMs = 250,
    clientResyncIntervalMs = 15000
  },
  ratelimit = {
    defaultMs = 1200
  }
}
