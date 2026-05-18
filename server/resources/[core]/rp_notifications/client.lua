local uiOpen = false

local function sendNotify(payload)
  if type(payload) ~= 'table' then
    return
  end

  local ntype = tostring(payload.type or 'info')
  if not RPNotifications.Config.types[ntype] then
    ntype = 'info'
  end

  SendNUIMessage({
    action = 'notify',
    data = {
      type = ntype,
      title = tostring(payload.title or 'Info'),
      message = tostring(payload.message or ''),
      duration = tonumber(payload.duration) or RPNotifications.Config.defaultDuration,
      sound = payload.sound,
      playSound = payload.playSound == true
    }
  })

  if not uiOpen then
    uiOpen = true
  end
end

RegisterNetEvent('rp:notify', function(payload)
  sendNotify(payload)
end)

exports('Notify', function(payload)
  sendNotify(payload)
end)

RegisterNUICallback('ready', function(_, cb)
  cb({ ok = true })
end)
