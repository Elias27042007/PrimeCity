fx_version 'cerulean'
games { 'gta5' }

name 'rp_hud'
author 'RP Local Base'
description 'Modernes HUD für RP'
version '1.0.0'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/app.js'
}

shared_script 'config.lua'
client_script 'client.lua'
server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server.lua'
}

dependency 'oxmysql'
dependency 'rp_core'
