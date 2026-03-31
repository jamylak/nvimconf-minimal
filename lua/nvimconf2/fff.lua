local M = {}
local picker_history = require('nvimconf2.picker_history')

-- Clear cached fff modules so a failed pre-install load can be retried cleanly.
local function reset_modules()
  package.loaded['fff'] = nil
  package.loaded['fff.core'] = nil
  package.loaded['fff.fuzzy'] = nil
  package.loaded['fff.main'] = nil
  package.loaded['fff.picker_ui'] = nil
  package.loaded['fff.rust'] = nil
end

-- Wait for fff's callback-style async install/build helpers and return their result.
local function wait_for_async(fn)
  local done = false
  local ok_result = false
  local err_result = nil

  fn(function(ok, err)
    ok_result = ok
    err_result = err
    done = true
  end)

  local ok_wait, wait_err = vim.wait(1000 * 60 * 2, function() return done end, 100)
  if not ok_wait and wait_err == -2 then
    return false, 'timed out'
  end

  return ok_result, err_result
end

-- Find the vendored fff plugin directory from its runtime Lua files.
local function get_plugin_dir()
  local matches = vim.api.nvim_get_runtime_file('lua/fff/download.lua', false)
  if #matches == 0 then
    return nil
  end
  return vim.fn.fnamemodify(matches[1], ':h:h:h')
end

-- Prefer the plugin's tag name for release downloads; fall back to short commit SHA.
local function get_plugin_version(plugin_dir)
  if not plugin_dir then
    return nil
  end

  local result = vim.system({ 'git', 'describe', '--tags', '--always' }, {
    cwd = plugin_dir,
    text = true,
  }):wait()

  if result.code == 0 and result.stdout and result.stdout ~= '' then
    return vim.trim(result.stdout)
  end

  result = vim.system({ 'git', 'rev-parse', '--short', 'HEAD' }, {
    cwd = plugin_dir,
    text = true,
  }):wait()

  if result.code == 0 and result.stdout and result.stdout ~= '' then
    return vim.trim(result.stdout)
  end

  return nil
end

-- Install fff's native backend, first via release asset and then via local cargo build.
local function install_binary(download)
  local plugin_dir = get_plugin_dir()
  local version = get_plugin_version(plugin_dir)

  local ok_download, err_download = wait_for_async(function(cb)
    download.ensure_downloaded({
      force = true,
      version = version,
    }, cb)
  end)

  if ok_download then
    return true
  end

  vim.notify(
    'Error downloading binary: ' .. tostring(err_download or 'unknown error') .. '\nTrying cargo build --release',
    vim.log.levels.WARN
  )

  local ok_build, err_build = wait_for_async(download.build_binary)
  if not ok_build then
    return false, err_build
  end

  vim.notify('fff.nvim binary built successfully!', vim.log.levels.INFO)
  return true
end

-- Ensure the native backend exists before any fff UI code tries to require it.
local function ensure_binary()
  local download = require('fff.download')
  local binary_path = download.get_binary_path()
  local stat = vim.uv.fs_stat(binary_path)
  if stat and stat.type == 'file' then
    return true
  end

  vim.notify('Installing fff.nvim native backend...', vim.log.levels.INFO)

  local ok_install, err = install_binary(download)
  if not ok_install then
    vim.notify('fff.nvim install failed: ' .. tostring(err or 'unknown error'), vim.log.levels.ERROR)
    return false
  end

  reset_modules()
  return true
end

-- Reopen fff actions through one guarded entrypoint so install/startinsert behavior stays consistent.
local function reopen(fn)
  vim.schedule(function()
    if not ensure_binary() then
      return
    end

    local ok, picker_ui = pcall(require, 'fff.picker_ui')
    if ok and picker_ui.state and picker_ui.state.active then
      picker_ui.close()
    end

    fn()
    vim.schedule(function()
      if vim.bo.filetype == 'fff_input' then
        vim.cmd.startinsert()
      end
    end)
  end)
end

-- Open the normal fff file picker.
local function find_files()
  picker_history.set(find_files)
  reopen(function()
    require('fff').find_files()
  end)
end

-- Back the :FFFFind command, preserving fff's query-vs-directory behavior.
local function find_files_cmd(opts)
  local args = opts.args or ''
  picker_history.set(function()
    find_files_cmd({ args = args })
  end)

  reopen(function()
    local fff = require('fff')
    if args ~= '' then
      if vim.fn.isdirectory(args) == 1 then
        fff.find_files_in_dir(args)
      else
        fff.search_and_show(args)
      end
    else
      fff.find_files()
    end
  end)
end

-- Open fff live grep, optionally carrying over query/cwd from the picker.
local function live_grep(query, cwd)
  picker_history.set(function()
    live_grep(query, cwd)
  end)

  reopen(function()
    require('fff').live_grep({
      cwd = cwd,
      query = query or '',
      grep = {
        modes = { 'fuzzy', 'plain' },
      },
    })
  end)
end

local function find_files_in_dir(path)
  picker_history.set(function()
    find_files_in_dir(path)
  end)

  reopen(function()
    require('fff').find_files_in_dir(path)
  end)
end

local function close_picker()
  local ok, picker_ui = pcall(require, 'fff.picker_ui')
  if ok and picker_ui.state and picker_ui.state.active then
    picker_ui.close()
  end
end

-- Register user-facing commands, keymaps, and picker-local mappings.
function M.setup(enabled)
  if not enabled then
    return
  end

  pcall(vim.api.nvim_del_user_command, 'FFFFind')
  vim.api.nvim_create_user_command('FFFFind', find_files_cmd, {
    nargs = '?',
    complete = function(arg_lead)
      local dirs = vim.fn.glob(arg_lead .. '*', false, true)
      local results = {}
      for _, dir in ipairs(dirs) do
        if vim.fn.isdirectory(dir) == 1 then
          results[#results + 1] = dir
        end
      end
      return results
    end,
    desc = 'Find files with FFF',
  })

  vim.api.nvim_create_user_command('FFFGrep', function(opts)
    live_grep(opts.args ~= '' and opts.args or nil)
  end, {
    nargs = '?',
    desc = 'Open FFF live grep',
  })

  vim.api.nvim_create_user_command('FFFInstall', function()
    require('fff.download').download_or_build_binary()
  end, {
    desc = 'Download or build the fff.nvim binary',
  })

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'fff_input',
    callback = function(args)
      vim.keymap.set('i', '<m-u>', function()
        local picker_ui = require('fff.picker_ui')
        local query = picker_ui.state.query
        local cwd = picker_ui.state.config and picker_ui.state.config.base_path or vim.uv.cwd()

        vim.cmd.stopinsert()
        live_grep(query, cwd)
      end, { buffer = args.buf, noremap = true, silent = true, desc = 'FFF live grep' })

      vim.keymap.set('i', '<m-n>', function()
        vim.cmd.stopinsert()
        close_picker()
        vim.schedule(function()
          require('nvimconf2.project_picker').open()
        end)
      end, { buffer = args.buf, noremap = true, silent = true, desc = 'FFF project picker' })
    end,
  })

  vim.keymap.set('n', '<c-return>', find_files, { desc = 'Find files' })
  vim.keymap.set('n', '<m-u>', live_grep, { desc = 'Project grep' })
  vim.keymap.set('n', '<leader>f', find_files, { desc = 'Find files' })
end

M.close = close_picker
M.find_files = find_files
M.find_files_in_dir = find_files_in_dir
M.live_grep = live_grep

return M
