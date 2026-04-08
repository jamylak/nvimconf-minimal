local M = {}
local bootstrap = require('nvimconf.bootstrap')

local snacks_loaded = false

local function ensure_snacks_lazygit()
  local snacks = bootstrap.require_plugin('snacks', 'snacks.nvim')
  if not snacks then
    return nil
  end

  if not snacks_loaded then
    snacks.setup({
      lazygit = {},
    })
    snacks_loaded = true
  end

  return snacks
end

function M.open()
  if vim.fn.executable('lazygit') ~= 1 then
    vim.notify('lazygit is not installed', vim.log.levels.ERROR)
    return
  end

  local snacks = ensure_snacks_lazygit()
  if not snacks then
    return
  end

  snacks.lazygit()
end

return M
