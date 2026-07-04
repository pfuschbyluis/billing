fx_version 'cerulean'
game 'gta5'

name 'esx_rechnungen'
author 'ESX Rechnungssystem'
description 'Deutsches Rechnungssystem für ESX Legacy mit ox_lib Menüs und Steuersystem'
version '2.0.0'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/menu_player.lua',
    'client/menu_create.lua',
    'client/menu_admin.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_lib'
}
