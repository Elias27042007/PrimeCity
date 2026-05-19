local currentJob = {
  jobName = 'unemployed',
  label = 'Arbeitslos',
  grade = 0,
  gradeLabel = 'Einsteiger',
  salary = 0,
  onDuty = false
}
local dutyBlips = {}

CreateThread(function()
  Wait(2200)
  for i = 1, #RPJobsConfig.dutyPoints do
    local point = RPJobsConfig.dutyPoints[i]
    exports.rp_interactions:RegisterPoint({
      id = ('rp_jobs_%s'):format(point.id),
      label = point.label,
      coords = point.coords,
      distance = 16.0,
      interactDistance = 2.0,
      trigger = 'rp:jobs:toggleDuty',
      triggerType = 'server',
      args = { jobName = point.jobName }
    })

    if RPJobsConfig.blip and RPJobsConfig.blip.enabled then
      local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
      SetBlipSprite(blip, RPJobsConfig.blip.sprite)
      SetBlipDisplay(blip, 4)
      SetBlipScale(blip, RPJobsConfig.blip.scale)
      SetBlipColour(blip, RPJobsConfig.blip.color)
      SetBlipAsShortRange(blip, RPJobsConfig.blip.shortRange == true)
      BeginTextCommandSetBlipName('STRING')
      AddTextComponentString('Dienstpunkt')
      EndTextCommandSetBlipName(blip)
      dutyBlips[#dutyBlips + 1] = blip
    end
  end
end)

RegisterNetEvent('rp:jobs:update', function(jobData)
  if type(jobData) ~= 'table' then
    return
  end

  currentJob = jobData
  TriggerEvent('rp:hud:updateJob', currentJob)
end)

exports('GetJob', function()
  return currentJob
end)
