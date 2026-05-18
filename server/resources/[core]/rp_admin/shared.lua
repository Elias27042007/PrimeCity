RPAdminShared = {}

RPAdminShared.RoleNames = {
  'supporter',
  'moderator',
  'admin',
  'manager',
  'projektleitung'
}

RPAdminShared.PermissionKeys = {
  'admin.menu.open',
  'dashboard.view',
  'players.view',
  'players.kick',
  'players.ban',
  'vehicles.spawn.command',
  'vehicles.delete.command',
  'commands.heal',
  'commands.revive',
  'commands.repair',
  'commands.reload',
  'commands.tp',
  'commands.tpm',
  'commands.bring',
  'commands.freeze',
  'commands.skin',
  'commands.noclip',
  'commands.name',
  'commands.aduty',
  'bans.view',
  'bans.manage',
  'tickets.view',
  'tickets.manage',
  'scripts.view',
  'scripts.restart',
  'settings.view',
  'settings.shops.manage',
  'rights.view',
  'rights.assign'
}

function RPAdminShared.Trim(value)
  if type(value) ~= 'string' then
    return ''
  end

  return value:match('^%s*(.-)%s*$')
end
