RPJobsConfig = {
  paycheckIntervalMs = 10 * 60 * 1000,
  blip = {
    enabled = true,
    sprite = 280,
    color = 46,
    scale = 0.75,
    shortRange = true
  },
  dutyPoints = {
    { id = 'duty_delivery', label = '[E] Dienstpunkt Lieferfahrer', jobName = 'delivery', coords = vector3(78.13, 111.22, 81.17) },
    { id = 'duty_garbage', label = '[E] Dienstpunkt Muellabfuhr', jobName = 'garbage', coords = vector3(-321.42, -1545.89, 31.02) },
    { id = 'duty_taxi', label = '[E] Dienstpunkt Taxi', jobName = 'taxi', coords = vector3(894.20, -179.01, 74.70) }
  }
}
