local points = {}

local function draw3DText(coords, text)
  local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
  if not onScreen then return end

  SetTextScale(0.32, 0.32)
  SetTextFont(4)
  SetTextProportional(1)
  SetTextColour(235, 240, 255, 220)
  SetTextEntry('STRING')
  SetTextCentre(1)
  AddTextComponentString(text)
  DrawText(x, y)
end

local function registerPoint(data)
  if type(data) ~= 'table' or not data.id or not data.coords then
    return false
  end

  points[data.id] = {
    id = data.id,
    label = data.label or RPInteractions.Config.prompt,
    coords = data.coords,
    distance = tonumber(data.distance) or RPInteractions.Config.drawDistance,
    interactDistance = tonumber(data.interactDistance) or RPInteractions.Config.interactDistance,
    trigger = tostring(data.trigger or ''),
    triggerType = tostring(data.triggerType or 'client'),
    args = data.args
  }

  return true
end

exports('RegisterPoint', function(data)
  return registerPoint(data)
end)

exports('RemovePoint', function(id)
  points[id] = nil
end)

RegisterNetEvent('rp:interactions:registerPoint', function(data)
  registerPoint(data)
end)

RegisterNetEvent('rp:interactions:removePoint', function(id)
  points[id] = nil
end)

CreateThread(function()
  while true do
    local sleep = 1200
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)

    for _, point in pairs(points) do
      local dist = #(pcoords - point.coords)
      if dist <= point.distance then
        sleep = 5
        DrawMarker(
          RPInteractions.Config.marker.type,
          point.coords.x,
          point.coords.y,
          point.coords.z - 1.0,
          0.0, 0.0, 0.0,
          0.0, 0.0, 0.0,
          RPInteractions.Config.marker.scale.x,
          RPInteractions.Config.marker.scale.y,
          RPInteractions.Config.marker.scale.z,
          RPInteractions.Config.marker.color.r,
          RPInteractions.Config.marker.color.g,
          RPInteractions.Config.marker.color.b,
          RPInteractions.Config.marker.color.a,
          false,
          false,
          2,
          false,
          nil,
          nil,
          false
        )

        if dist <= point.interactDistance then
          draw3DText(point.coords + vector3(0.0, 0.0, 1.0), point.label)

          if IsControlJustReleased(0, RPInteractions.Config.keyCode) and point.trigger ~= '' then
            if point.triggerType == 'server' then
              TriggerServerEvent(point.trigger, point.args)
            else
              TriggerEvent(point.trigger, point.args)
            end
          end
        end
      end
    end

    Wait(sleep)
  end
end)
