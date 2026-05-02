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
local installed_plugins = {}
local loaded_plugins = {}

local function gh(repo)
  return 'https://github.com/' .. repo
end

local plugin_names = {
  'plenary.nvim',
  'nvim-dap',
  'nvim-nio',
  'nvim-dap-ui',
  'nvim-dap-disasm',
  'nvim-web-devicons',
  'fff.nvim',
  'blink.cmp',
  'grug-far.nvim',
  'nvim-window',
  'oil.nvim',
  'diffview.nvim',
  'neogit',
  'nvim-treesitter',
  'snacks.nvim',
}

M.plugins_dir = vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'pack', 'core', 'opt')
M.cplug_dir = vim.fn.expand('~/proj/cplug.nvim')
M.penguin_dir = vim.fn.expand('~/proj/penguin.nvim')

local function add_runtimepath(path, opts)
  opts = opts or {}

  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= 'directory' then
    return false
  end

  if opts.prepend then
    vim.opt.rtp:prepend(path)
  else
    vim.opt.rtp:append(path)
  end
  return true
end

-- Use the local checkout directly while iterating on cplug.nvim.
add_runtimepath(M.cplug_dir, { prepend = true })
-- Use the local checkout directly while iterating on penguin.nvim.
add_runtimepath(M.penguin_dir, { prepend = true })

local function specs()
  return {
    { src = gh('nvim-lua/plenary.nvim'), name = 'plenary.nvim' },
    { src = gh('mfussenegger/nvim-dap'), name = 'nvim-dap' },
    { src = gh('nvim-neotest/nvim-nio'), name = 'nvim-nio' },
    { src = gh('rcarriga/nvim-dap-ui'), name = 'nvim-dap-ui' },
    { src = gh('Jorenar/nvim-dap-disasm'), name = 'nvim-dap-disasm' },
    -- Uncomment this and remove the local runtimepath line above to use GitHub instead.
    -- { src = gh('jamylak/cplug.nvim'), name = 'cplug.nvim' },
    -- Uncomment this and remove the local runtimepath line above to use GitHub instead.
    -- { src = gh('jamylak/penguin.nvim'), name = 'penguin.nvim' },
    { src = gh('nvim-tree/nvim-web-devicons'), name = 'nvim-web-devicons' },
    { src = gh('dmtrKovalenko/fff.nvim'), name = 'fff.nvim' },
    { src = gh('Saghen/blink.cmp'), name = 'blink.cmp', version = vim.version.range('1') },
    { src = gh('MagicDuck/grug-far.nvim'), name = 'grug-far.nvim' },
    { src = gh('jamylak/nvim-window'), name = 'nvim-window', version = 'feature/disable-hints' },
    { src = gh('stevearc/oil.nvim'), name = 'oil.nvim' },
    { src = gh('sindrets/diffview.nvim'), name = 'diffview.nvim' },
    { src = gh('NeogitOrg/neogit'), name = 'neogit' },
    { src = gh('nvim-treesitter/nvim-treesitter'), name = 'nvim-treesitter' },
    { src = gh('folke/snacks.nvim'), name = 'snacks.nvim' },
  }
end

local function installed_specs()
  local installed = true

  for _, plugin_name in ipairs(plugin_names) do
    local path = vim.fs.joinpath(M.plugins_dir, plugin_name)
    local stat = vim.uv.fs_stat(path)
    if stat and stat.type == 'directory' then
      installed_plugins[plugin_name] = path
    else
      installed = false
    end
  end

  return installed
end

local ok_pack, pack_err = pcall(function()
  if installed_specs() then
    return
  end

  if not (vim.pack and type(vim.pack.add) == 'function') then
    error('nvimconf-minimal requires Neovim 0.12+ with vim.pack')
  end

  vim.pack.add(specs(), { confirm = false, load = false })
end)

if not ok_pack then
  vim.schedule(function()
    vim.notify('vim.pack failed to register plugins: ' .. tostring(pack_err), vim.log.levels.ERROR)
  end)
end

function M.load_plugin(plugin_name)
  if type(plugin_name) ~= 'string' or plugin_name == '' then
    return false
  end

  if loaded_plugins[plugin_name] then
    return true
  end

  if not installed_plugins[plugin_name] then
    return false
  end

  local ok_load = pcall(vim.cmd.packadd, plugin_name)
  if not ok_load then
    return false
  end

  loaded_plugins[plugin_name] = true
  return true
end

function M.require_plugin(module_name, plugin_name)
  local ok, mod = pcall(require, module_name)
  if ok then
    return mod
  end

  if plugin_name and M.load_plugin(plugin_name) then
    ok, mod = pcall(require, module_name)
    if ok then
      return mod
    end
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
