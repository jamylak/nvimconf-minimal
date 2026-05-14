local M = {}
local bootstrap = require('nvimconf.bootstrap')

local loaded = false

local function ensure_loaded()
  if loaded then
    return true
  end

  local grug_far = bootstrap.require_plugin('grug-far', 'grug-far.nvim')
  if not grug_far then
    return false
  end

  grug_far.setup({
    keymaps = {
      qflist = false,
      close = { n = 'q' },
    },
    prefills = {
      flags = '-i',
    },
  })

  loaded = true
  return true
end

local function open(opts)
  if not ensure_loaded() then
    return
  end
  return require('grug-far').open(opts or {})
end

M.open = open

function M.replace_current_word_in_file()
  local word = vim.fn.expand('<cword>')
  local file = vim.api.nvim_buf_get_name(0)

  if word == '' then
    vim.notify('No word under cursor', vim.log.levels.WARN)
    return
  end

  if file == '' then
    vim.notify('Current buffer has no file path', vim.log.levels.WARN)
    return
  end

  return open({
    startCursorRow = 2,
    startInInsertMode = true,
    prefills = {
      search = word,
      replacement = '',
      flags = '-i --fixed-strings',
      paths = file,
    },
  })
end

function M.ensure_loaded_for_test()
  return ensure_loaded()
end

return M
