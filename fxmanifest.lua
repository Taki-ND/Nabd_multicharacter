fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Nabd'
description 'Nabd-Multicharacter'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js'
}

dependencies {
    'qb-core',
    'oxmysql'
}
