fx_version 'cerulean'
games { 'gta5' }

name 'rp_identity'
author 'RP Local Base'
description 'Charakter- und Personalausweis-Erstellung'
version '1.0.0'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/app.js'
}

shared_scripts {
  'config.lua'
}

client_script 'client.lua'

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server.lua'
}
