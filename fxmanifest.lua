fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'futrdesigns'
description 'Optimized high-performance pause menu with modern purple theme'
version '1.0.0'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/assets/styles.css',
    'ui/assets/script.js'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}