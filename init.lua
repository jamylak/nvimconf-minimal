local bootstrap = require('nvimconf2.bootstrap')

require('nvimconf2.options')
require('nvimconf2.keymaps')
require('nvimconf2.fff').setup(bootstrap.fff_available)
require('nvimconf2.blink').setup()
