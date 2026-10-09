fx_version 'cerulean'
games { 'gta5', 'rdr3' }
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'MineMalox, LuftigerLuca & C0kkie | lua dist by Hero Creative Studio'
version '1.0.3'
description 'YACA Voice Integration for FiveM & RedM'

dependencies {
    '/server:7290',
    '/onesync',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/script.js',
    'config/room_acoustics.json',
}

shared_scripts {
    'config/shared.lua',
    'config/towers.lua',
    'shared/enums.lua',
    'shared/constants.lua',
    'locales/en.lua',
    'locales/de.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/cache.lua',
    'client/utils.lua',
    'client/websocket.lua',
    'client/main.lua',
    'client/radio.lua',
    'client/towers.lua',
    'client/phone.lua',
    'client/megaphone.lua',
    'client/intercom.lua',
    'client/microphone.lua',
    'client/ghosting.lua',
    'client/bridge_saltychat.lua',
}

server_scripts {
    'config/server.lua',
    'server/utils.lua',
    'server/main.lua',
    'server/radio.lua',
    'server/phone.lua',
    'server/megaphone.lua',
    'server/ghosting.lua',
    'server/bridge_saltychat.lua',
}

provide 'saltychat'
