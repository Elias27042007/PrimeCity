fx_version 'cerulean'
games { 'gta5' }

name 'rp_core'
author 'RP Local Base'
description 'Core Join/Character/State System'
version '1.0.0'

shared_scripts {
  'config.lua',
  'shared.lua'
}

client_script 'client.lua'

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server.lua'
}
