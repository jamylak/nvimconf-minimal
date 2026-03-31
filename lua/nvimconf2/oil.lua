local M = {}

local loaded = false

local function notify_missing()
  vim.schedule(function()
    vim.notify('oil.nvim is missing. Run: git submodule update --init --recursive', vim.log.levels.ERROR)
  end)
end

local function load()
  if loaded then
    return true
  end

  local ok = pcall(vim.cmd, 'packadd oil.nvim')
  if not ok then
    notify_missing()
    return false
  end

  pcall(vim.api.nvim_del_user_command, 'Oil')

  require('oil').setup({
    default_file_explorer = true,
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
  vim.api.nvim_create_user_command('Oil', open_from_command, {
    nargs = '*',
    complete = 'dir',
    desc = 'Open Oil file browser',
  })

  vim.api.nvim_create_autocmd('BufEnter', {
    group = vim.api.nvim_create_augroup('nvimconf2.oil', { clear = true }),
    nested = true,
    once = true,
    callback = open_startup_directory,
  })
end

return M
