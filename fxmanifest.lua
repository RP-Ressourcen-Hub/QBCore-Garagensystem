fx_version 'cerulean'
game 'gta5'

description 'Advanced Garage System for QBCore Framework'
author 'YourName'
version '1.0.0'

shared_scripts {
    '@[standalone]/[framework_bridge]/shared/main.lua',
    'config/config.lua',
    'locales/*.lua',
    'shared/main.lua'
}

client_scripts {
    'client/main.lua',
    'client/functions.lua',
    'client/events.lua',
    'client/commands.lua'
}

server_scripts {
    'server/main.lua',
    'server/functions.lua',
    'server/events.lua',
    'server/commands.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/*.png',
    'html/img/*.jpg',
    'html/img/*.svg',
    'html/fonts/*.ttf'
}

lua54 'yes'

server_only 'no'

provides {
    'qb-garage',
    'qb-garages'
}

dependency '[standalone]/[framework_bridge]'