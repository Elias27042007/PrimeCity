fx_version 'cerulean'
games { 'gta5' }

name 'rp_admin'
author 'RP Local Base'
description 'Admin-Menue mit Rollen- und Rechtesystem'
version '1.0.0'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/app.js'
}

shared_scripts {
  'config.lua',
  'shared.lua'
}

client_script 'client.lua'

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server.lua'
}
