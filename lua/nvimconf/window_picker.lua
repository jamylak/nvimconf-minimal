local M = {}
local bootstrap = require('nvimconf.bootstrap')

local loaded = false

local function ensure_loaded()
  if loaded then
    return true
  end

  local nvim_window = bootstrap.require_plugin('nvim-window', 'nvim-window')
  if not nvim_window then
    return false
  end

  nvim_window.setup({
    chars = {
      'i',
      'o',
      '\r',
      'g',
      'j',
      'd',
      'e',
      'f',
      'h',
      'm',
      'n',
      'p',
      'q',
      'r',
      't',
      'u',
      'v',
      'w',
      'x',
      'y',
      'z',
    },
    disable_hint = false,
    disable_hint_if_less_than_n_windows = 3,
  })

  loaded = true
  return true
end

function M.pick()
  if not ensure_loaded() then
    return
  end

  require('nvim-window').pick()

  if vim.bo.buftype == 'terminal' then
    vim.cmd 'startinsert'
  end
end

function M.ensure_loaded_for_test()
  return ensure_loaded()
end

return M
