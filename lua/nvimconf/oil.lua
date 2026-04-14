local M = {}
local bootstrap = require('nvimconf.bootstrap')

local loaded = false

local function current_oil_path()
  local path = vim.fn.expand '%:p'
  if path:match '^oil://' then
    path = string.sub(path, 7)
  end
  return path
end

local function window_change_directory()
  local dir_path = vim.fn.fnamemodify(current_oil_path(), ':h')
  vim.cmd('lcd ' .. vim.fn.fnameescape(dir_path))
end

local function tab_change_directory()
  local dir_path = vim.fn.fnamemodify(current_oil_path(), ':h')
  vim.cmd('tcd ' .. vim.fn.fnameescape(dir_path))
end

local function set_global_keymaps()
  local map = vim.keymap.set
  local home = os.getenv 'HOME'
  local config_dir = vim.fn.stdpath 'config'

  map('n', '<leader>od', '<CMD>Oil ' .. home .. '/.config/dotfiles<CR>', { desc = '[O]pen [D]otfiles' })
  map('n', '<leader>ot', '<CMD>Oil /tmp<CR>', { desc = '[O]pen /[T]mp' })
  map('n', '<leader>oc', '<CMD>Oil ' .. config_dir .. '<CR>', { desc = '[O]pen [N]eovim Config' })
  map('n', '<leader>on', '<CMD>Oil ' .. bootstrap.plugins_dir .. '<CR>', { desc = '[O]pen [N]eovim Plugins Folder' })
  map('n', '<leader>op', '<CMD>Oil ' .. home .. '/proj<CR>', { desc = '[O]pen Projects' })
  map('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
  map('n', '<c-x><c-j>', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
end

local function load()
  if loaded then
    return true
  end

  local oil = bootstrap.require_plugin('oil', 'oil.nvim')
  if not oil then
    return false
  end

  pcall(vim.api.nvim_del_user_command, 'Oil')

  oil.setup({
    default_file_explorer = true,
    columns = {
      'icon',
      'size',
      'mtime',
    },
    keymaps = {
      ['<m-o>'] = function()
        vim.cmd 'Telescope oldfiles'
      end,
      ['<m-i>'] = function()
        vim.cmd 'Telescope find_files'
      end,
      ['cd'] = {
        callback = tab_change_directory,
        desc = 'Tab [C]hange [D]irectory',
        mode = 'n',
      },
      ['<leader>lc'] = {
        callback = window_change_directory,
        desc = '[T]ab [C]hange [D]irectory',
        mode = 'n',
      },
      ['<leader>tc'] = {
        callback = tab_change_directory,
        desc = '[T]ab [C]hange [D]irectory',
        mode = 'n',
      },
      ['<leader>p'] = {
        callback = function()
          local oil = require('oil')
          local filename = oil.get_cursor_entry().name
          local dir = oil.get_current_dir()
          oil.close()

          local img_clip = require('img-clip')
          img_clip.paste_image({}, dir .. filename)
        end,
        desc = 'Pase using imgclip',
        mode = 'n',
      },
      ['gp'] = {
        callback = function()
          if vim.tbl_contains(require('oil.config').columns, 'permissions') then
            require('oil').set_columns({ 'icon', 'size', 'mtime' })
          else
            require('oil').set_columns({ 'permissions', 'icon', 'size', 'mtime' })
          end
        end,
        desc = 'Toggle of file permissions',
      },
      ['<leader>c'] = {
        callback = function()
          if require('oil.config').view_options.sort[2][1] == 'mtime' then
            require('oil').set_sort({
              { 'type', 'asc' },
              { 'name', 'asc' },
            })
          else
            require('oil').set_sort({
              { 'type', 'desc' },
              { 'mtime', 'desc' },
            })
          end
        end,
        desc = '[C]hange sort order',
      },
    },
    view_options = { show_hidden = true },
  })

  loaded = true
  return true
end

local function current_buffer_is_directory()
  local path = vim.api.nvim_buf_get_name(0)
  return path ~= '' and vim.fn.isdirectory(path) == 1
end

local function open_startup_directory()
  if not current_buffer_is_directory() then
    return
  end
  local path = vim.api.nvim_buf_get_name(0)
  if not load() then
    return
  end
  if vim.bo.filetype ~= 'oil' then
    require('oil').open(path)
  end
end

local function open_from_command(opts)
  if not load() then
    return
  end

  vim.api.nvim_cmd({
    cmd = 'Oil',
    args = opts.fargs,
  }, {})
end

function M.setup()
  set_global_keymaps()

  vim.api.nvim_create_user_command('Oil', open_from_command, {
    nargs = '*',
    complete = 'dir',
    desc = 'Open Oil file browser',
  })

  vim.api.nvim_create_autocmd('BufEnter', {
    group = vim.api.nvim_create_augroup('nvimconf-minimal.oil', { clear = true }),
    nested = true,
    once = true,
    callback = open_startup_directory,
  })
end

return M
