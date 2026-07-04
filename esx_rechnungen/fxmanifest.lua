fx_version 'cerulean'
game 'gta5'

name 'esx_rechnungen'
author 'ESX Rechnungssystem'
description 'Deutsches Rechnungssystem für ESX Legacy mit Custom-Menü und Steuersystem'
version '2.1.0'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/menu.css',
    'html/js/icons.js',
    'html/js/dialogs.js',
    'html/js/menu.js'
}

dependencies {
    'es_extended',
    'oxmysql'
}
