fx_version 'cerulean'
games { 'gta5' }

name 'rp_notifications'
author 'RP Local Base'
description 'Einheitliches Notification-System'
version '1.0.0'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/app.js'
}

shared_script 'shared.lua'
client_script 'client.lua'
server_script 'server.lua'
