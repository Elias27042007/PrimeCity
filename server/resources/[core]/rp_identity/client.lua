local isOpen = false
local currentMode = 'create'

local function setUI(open, payload)
  isOpen = open
  if open then
    if type(payload) == 'table' and payload.mode == 'update' then
      currentMode = 'update'
    elseif type(payload) == 'table' and payload.mode == 'admin_create' then
      currentMode = 'admin_create'
    else
      currentMode = 'create'
    end
  else
    currentMode = 'create'
  end

  SetNuiFocus(open, open)
  SendNUIMessage({
    action = open and 'open' or 'close',
    data = payload
  })

  if open then
    TriggerEvent('rp:hud:toggle', false)
    FreezeEntityPosition(PlayerPedId(), true)
  else
    FreezeEntityPosition(PlayerPedId(), false)
  end
end

RegisterNetEvent('rp:identity:open', function(payload)
  setUI(true, payload)
end)

RegisterNUICallback('submitIdentity', function(data, cb)
  if not isOpen then
    cb({ ok = false, message = 'UI nicht aktiv.' })
    return
  end

  local firstName = tostring(data.firstName or '')
  local lastName = tostring(data.lastName or '')
  local dob = tostring(data.dateOfBirth or '')
  local sex = tostring(data.sex or '')
  local height = tonumber(data.height or 0)
  local nationality = tostring(data.nationality or '')

  if #firstName < RPIdentityConfig.minNameLength or #firstName > RPIdentityConfig.maxNameLength then
    cb({ ok = false, message = 'Vorname ist ungültig.' })
    return
  end

  if #lastName < RPIdentityConfig.minNameLength or #lastName > RPIdentityConfig.maxNameLength then
    cb({ ok = false, message = 'Nachname ist ungültig.' })
    return
  end

  if not dob:match('^%d%d%d%d%-%d%d%-%d%d$') then
    cb({ ok = false, message = 'Geburtsdatum muss YYYY-MM-DD sein.' })
    return
  end

  if sex ~= 'm' and sex ~= 'f' and sex ~= 'd' then
    cb({ ok = false, message = 'Geschlecht ist ungültig.' })
    return
  end

  if height < RPIdentityConfig.minHeight or height > RPIdentityConfig.maxHeight then
    cb({ ok = false, message = 'Größe außerhalb des erlaubten Bereichs.' })
    return
  end

  if #nationality < 2 or #nationality > RPIdentityConfig.maxNationalityLength then
    cb({ ok = false, message = 'Nationalität ist ungültig.' })
    return
  end

  local submitPayload = {
    firstName = firstName,
    lastName = lastName,
    dateOfBirth = dob,
    sex = sex,
    height = height,
    nationality = nationality
  }

  if currentMode == 'update' then
    TriggerServerEvent('rp:identity:update', submitPayload)
  elseif currentMode == 'admin_create' then
    TriggerServerEvent('rp:identity:adminSubmit', submitPayload)
  else
    TriggerServerEvent('rp:identity:create', submitPayload)
  end

  cb({ ok = true })
end)

RegisterNUICallback('cancelIdentity', function(_, cb)
  if not isOpen then
    cb({ ok = false })
    return
  end

  setUI(false)
  cb({ ok = true })
end)

RegisterNetEvent('rp:identity:close', function()
  setUI(false)
end)
