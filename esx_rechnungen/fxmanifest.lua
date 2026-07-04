fx_version 'cerulean'
game 'gta5'

name 'esx_rechnungen'
author 'ESX Rechnungssystem'
description 'Deutsches Rechnungssystem für ESX Legacy mit Custom-Menü und Steuersystem'
version '2.4.0'

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
    'html/css/billing.css',
    'html/css/invoice-form.css',
    'html/js/icons.js',
    'html/js/dialogs.js',
    'html/js/billing.js'
}

dependencies {
    'es_extended',
    'oxmysql'
}
