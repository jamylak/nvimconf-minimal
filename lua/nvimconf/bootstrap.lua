local M = {}

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
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

local missing_notified = {}

local function gh(repo)
  return 'https://github.com/' .. repo
end

M.plugins_dir = vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'pack', 'core', 'opt')

local function specs()
  return {
    { src = gh('dmtrKovalenko/fff.nvim'), name = 'fff.nvim' },
    { src = gh('Saghen/blink.cmp'), name = 'blink.cmp', version = vim.version.range('1') },
    { src = gh('MagicDuck/grug-far.nvim'), name = 'grug-far.nvim' },
    { src = gh('jamylak/nvim-window'), name = 'nvim-window', version = 'feature/disable-hints' },
    { src = gh('stevearc/oil.nvim'), name = 'oil.nvim' },
    { src = gh('nvim-treesitter/nvim-treesitter'), name = 'nvim-treesitter' },
    { src = gh('folke/snacks.nvim'), name = 'snacks.nvim' },
  }
end

if not (vim.pack and type(vim.pack.add) == 'function') then
  error('nvimconf2 requires Neovim 0.12+ with vim.pack')
end

local ok_pack, pack_err = pcall(function()
  vim.pack.add(specs(), { confirm = false, load = false })
end)

if not ok_pack then
  vim.schedule(function()
    vim.notify('vim.pack failed to register plugins: ' .. tostring(pack_err), vim.log.levels.ERROR)
  end)
end

function M.require_plugin(module_name, plugin_name)
  local ok, mod = pcall(require, module_name)
  if ok then
    return mod
  end

  local key = plugin_name or module_name
  if not missing_notified[key] then
    missing_notified[key] = true
    vim.schedule(function()
      vim.notify(
        string.format(
          '%s is unavailable. Run :lua vim.pack.update({ %q }) and then :restart.',
          key,
          key
        ),
        vim.log.levels.ERROR
      )
    end)
  end

  return nil
end

return M
