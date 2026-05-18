fx_version 'cerulean'
games { 'gta5' }

name 'rp_vehicles'
author 'RP Local Base'
description 'Fahrzeugdaten und Besitzlogik'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server.lua'
}
