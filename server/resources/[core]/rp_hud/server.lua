local function clamp(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function ensureMysqlReady()
  local tries = 0
  while (not MySQL) and tries < 200 do
    tries = tries + 1
    Wait(50)
  end

  if not MySQL then
    print('[rp_hud] ERROR: MySQL API konnte nicht geladen werden (oxmysql).')
    return false
  end

  if MySQL.ready and MySQL.ready.await then
    local ok, err = pcall(MySQL.ready.await)
    if not ok then
      print(('[rp_hud] ERROR: MySQL.ready fehlgeschlagen: %s'):format(tostring(err)))
      return false
    end
  end

  return true
end

local function getUserId(source)
  local state = exports.rp_core:GetPlayerState(source)
  if not state then
    return nil
  end
  return tonumber(state.userId)
end

local function saveLayoutForUserId(userId, payload)
  if type(payload) ~= 'table' then
    return
  end

  local x = clamp(tonumber(payload.x) or 0.18, 0.01, 0.99)
  local y = clamp(tonumber(payload.y) or 0.82, 0.01, 0.99)

  MySQL.query.await([[
    INSERT INTO user_hud_layouts (user_id, pos_x, pos_y)
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE
      pos_x = VALUES(pos_x),
      pos_y = VALUES(pos_y)
  ]], { userId, x, y })
end

local function ensureHudSchema()
  if not ensureMysqlReady() then
    return false
  end

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS user_hud_layouts (
      user_id BIGINT UNSIGNED NOT NULL,
      pos_x DECIMAL(7,6) NOT NULL DEFAULT 0.180000,
      pos_y DECIMAL(7,6) NOT NULL DEFAULT 0.820000,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (user_id),
      CONSTRAINT fk_user_hud_layouts_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]])

  return true
end

RegisterNetEvent('rp:hud:requestLayout', function()
  if not MySQL then
    return
  end

  local src = source
  local userId = getUserId(src)
  if not userId then
    return
  end

  local row = MySQL.single.await(
    'SELECT pos_x, pos_y FROM user_hud_layouts WHERE user_id = ? LIMIT 1',
    { userId }
  )

  if not row then
    return
  end

  TriggerClientEvent('rp:hud:applyLayout', src, {
    x = clamp(tonumber(row.pos_x) or 0.18, 0.01, 0.99),
    y = clamp(tonumber(row.pos_y) or 0.82, 0.01, 0.99)
  })
end)

RegisterNetEvent('rp:hud:saveLayout', function(payload)
  if not MySQL then
    return
  end

  local src = source
  local userId = getUserId(src)

  if type(payload) ~= 'table' then
    return
  end

  if not userId then
    local delayedPayload = {
      x = payload.x,
      y = payload.y
    }

    SetTimeout(1000, function()
      if not GetPlayerName(src) then
        return
      end

      local delayedUserId = getUserId(src)
      if not delayedUserId then
        return
      end

      saveLayoutForUserId(delayedUserId, delayedPayload)
    end)
    return
  end

  if not exports.rp_core:CanUseRateLimitedAction(src, 'hud_save_layout', 200) then
    return
  end

  saveLayoutForUserId(userId, payload)
end)

AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  CreateThread(function()
    ensureHudSchema()
  end)
end)
