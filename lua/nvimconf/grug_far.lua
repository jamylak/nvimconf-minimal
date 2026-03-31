local M = {}

local loaded = false

local function ensure_loaded()
  if loaded then
    return true
  end

  local ok = pcall(vim.cmd, 'packadd grug-far.nvim')
  if not ok then
    vim.schedule(function()
      vim.notify('grug-far.nvim is missing. Run: git submodule update --init --recursive', vim.log.levels.ERROR)
    end)
    return false
  end

  require('grug-far').setup({
    keymaps = {
      qflist = { n = 'q' },
      close = { n = '<localleader>q' },
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
  require('grug-far').open(opts or {})
end

function M.setup()
  vim.keymap.set({ 'n', 'x' }, '<leader>S', function()
    open()
  end, { desc = 'Grug search' })

  vim.keymap.set('n', 'S', function()
    open()
  end, { desc = 'Grug search' })

  vim.keymap.set({ 'n', 'x', 'v' }, '<leader><leader>S', function()
    open({ visualSelectionUsage = 'operate-within-range' })
  end, { desc = 'Grug search within range' })
end

function M.ensure_loaded_for_test()
  return ensure_loaded()
end

return M
