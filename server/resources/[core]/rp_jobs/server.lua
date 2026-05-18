local JobCache = {}

local function notify(source, ntype, title, message)
  TriggerClientEvent('rp:notify', source, {
    type = ntype,
    title = title,
    message = message
  })
end

local function pushJob(source)
  local job = JobCache[source]
  if job then
    TriggerClientEvent('rp:jobs:update', source, job)
  end
end

local function normalizeJobName(value)
  return tostring(value or ''):lower():match('^%s*(.-)%s*$')
end

AddEventHandler('rp:jobs:loadCharacterJob', function(source, characterId)
  local row = MySQL.single.await(
    [=[SELECT j.job_name, j.label, jg.grade, jg.grade_name, jg.salary, cj.on_duty
       FROM character_jobs cj
       INNER JOIN jobs j ON j.id = cj.job_id
       INNER JOIN job_grades jg ON jg.id = cj.grade_id
       WHERE cj.character_id = ? LIMIT 1]=],
    { characterId }
  )

  if not row then
    local unemployedJobId = MySQL.scalar.await('SELECT id FROM jobs WHERE job_name = ? LIMIT 1', { 'unemployed' })
    local unemployedGradeId = MySQL.scalar.await(
      [=[SELECT jg.id FROM job_grades jg
         JOIN jobs j ON j.id = jg.job_id
         WHERE j.job_name = ? AND jg.grade = 0 LIMIT 1]=],
      { 'unemployed' }
    )

    if unemployedJobId and unemployedGradeId then
      MySQL.insert.await('INSERT INTO character_jobs (character_id, job_id, grade_id, on_duty) VALUES (?, ?, ?, 0)', {
        characterId,
        unemployedJobId,
        unemployedGradeId
      })
    end

    row = {
      job_name = 'unemployed',
      label = 'Arbeitslos',
      grade = 0,
      grade_name = 'Einsteiger',
      salary = 250,
      on_duty = 0
    }
  end

  JobCache[source] = {
    characterId = characterId,
    jobName = row.job_name,
    label = row.label,
    grade = tonumber(row.grade) or 0,
    gradeLabel = row.grade_name,
    salary = tonumber(row.salary) or 0,
    onDuty = tonumber(row.on_duty) == 1
  }

  pushJob(source)
end)

RegisterNetEvent('rp:jobs:toggleDuty', function(args)
  local src = source
  if not exports.rp_core:CanUseRateLimitedAction(src, 'job_duty', 850) then
    return
  end

  local requested = tostring((args and args.jobName) or '')
  local job = JobCache[src]
  if not job then
    notify(src, 'error', 'Job', 'Jobdaten nicht geladen.')
    return
  end

  if requested == '' or requested ~= job.jobName then
    notify(src, 'error', 'Job', 'Du bist nicht für diesen Dienst eingeteilt.')
    return
  end

  job.onDuty = not job.onDuty
  MySQL.update.await('UPDATE character_jobs SET on_duty = ? WHERE character_id = ?', {
    job.onDuty and 1 or 0,
    job.characterId
  })

  pushJob(src)
  notify(src, 'success', 'Job', job.onDuty and 'Dienst gestartet.' or 'Dienst beendet.')
end)

CreateThread(function()
  while true do
    Wait(RPJobsConfig.paycheckIntervalMs)

    local players = GetPlayers()
    for i = 1, #players do
      local src = tonumber(players[i])
      local job = src and JobCache[src] or nil
      if job and job.onDuty and job.salary > 0 then
        exports.rp_money:AddBank(src, job.salary, 'system', 'paycheck')
        notify(src, 'success', 'Paycheck', ('Du hast %d$ Gehalt erhalten.'):format(job.salary))
      end
    end
  end
end)

local function setJob(source, jobName, grade)
  source = tonumber(source)
  if not source or source <= 0 then
    return false, 'Ungültige Spieler-ID.'
  end

  local cache = JobCache[source]
  if not cache or not cache.characterId then
    return false, 'Jobdaten nicht geladen.'
  end

  jobName = normalizeJobName(jobName)
  grade = math.floor(tonumber(grade) or -1)
  if jobName == '' then
    return false, 'Jobname fehlt.'
  end
  if grade < 0 then
    return false, 'Jobrang ist ungültig.'
  end

  local row = MySQL.single.await(
    [=[SELECT j.id AS job_id, j.job_name, j.label, jg.id AS grade_id, jg.grade, jg.grade_name, jg.salary
       FROM jobs j
       INNER JOIN job_grades jg ON jg.job_id = j.id
       WHERE j.job_name = ? AND jg.grade = ?
       LIMIT 1]=],
    { jobName, grade }
  )

  if not row then
    return false, 'Job oder Rang wurde nicht gefunden.'
  end

  local updated = MySQL.update.await(
    'UPDATE character_jobs SET job_id = ?, grade_id = ?, on_duty = 0 WHERE character_id = ?',
    { row.job_id, row.grade_id, cache.characterId }
  )

  if (tonumber(updated) or 0) <= 0 then
    MySQL.insert.await(
      'INSERT INTO character_jobs (character_id, job_id, grade_id, on_duty) VALUES (?, ?, ?, 0)',
      { cache.characterId, row.job_id, row.grade_id }
    )
  end

  JobCache[source] = {
    characterId = cache.characterId,
    jobName = row.job_name,
    label = row.label,
    grade = tonumber(row.grade) or 0,
    gradeLabel = row.grade_name,
    salary = tonumber(row.salary) or 0,
    onDuty = false
  }

  pushJob(source)
  return true, nil, JobCache[source]
end

exports('GetJob', function(source)
  return JobCache[source]
end)
exports('SetJob', setJob)
exports('setJob', setJob)

AddEventHandler('playerDropped', function()
  JobCache[source] = nil
end)
