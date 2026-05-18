fx_version 'cerulean'
games { 'gta5' }

name 'rp_spawn'
author 'RP Local Base'
description 'Spawn- und Positionsspeichersystem'
version '1.0.0'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/app.js'
}

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'
