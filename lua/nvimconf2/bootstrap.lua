local M = {}

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.go.loadplugins = false
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

vim.g.fff = {
  lazy_sync = true,
  keymaps = {
    close = { '<Esc>', '<C-c>' },
    select = { '<CR>', '<C-j>', '<C-m>' },
  },
}

M.fff_available = pcall(vim.cmd, 'packadd fff.nvim')

if not M.fff_available then
  vim.schedule(function()
    vim.notify('fff.nvim is missing. Run: git submodule update --init --recursive', vim.log.levels.ERROR)
  end)
end

return M
