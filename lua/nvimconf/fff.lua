local M = {}
local bootstrap = require('nvimconf.bootstrap')
local picker_history = require('nvimconf.picker_history')
local picker_switch = require('nvimconf.picker_switch')
local setup_done = false

local function normalize_query(query)
  if type(query) ~= 'string' or query == '' then
    return nil
  end

  return query
end

local function same_directory(left, right)
  if not left or left == '' or not right or right == '' then
    return false
  end

  local left_real = vim.uv.fs_realpath(vim.fn.expand(left))
  local right_real = vim.uv.fs_realpath(vim.fn.expand(right))
  if left_real and right_real then
    return left_real == right_real
  end

  return vim.fs.normalize(vim.fn.expand(left)) == vim.fs.normalize(vim.fn.expand(right))
end

local open_file_picker
local live_grep

local function require_fff(module_name)
  local module = bootstrap.require_plugin(module_name, 'fff.nvim')
  if not module then
    return nil
  end

  return module
end

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
  local download = require_fff('fff.download')
  if not download then
    return false
  end
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
  if vim.in_fast_event() then
    vim.schedule(function()
      reopen(fn)
    end)
    return
  end

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
end

local function remember_file_picker(opts)
  opts = opts or {}

  local query = normalize_query(opts.query)
  local cwd = opts.cwd
  local title = opts.title

  picker_history.set(function()
    open_file_picker({
      query = query,
      cwd = cwd,
      title = title,
    })
  end)
end

local function remember_live_grep(query, cwd)
  query = normalize_query(query)

  picker_history.set(function()
    live_grep(query, cwd)
  end)
end

local function picker_input_query(state)
  if not state or not state.input_buf or not vim.api.nvim_buf_is_valid(state.input_buf) then
    return normalize_query(state and state.query or nil)
  end

  local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)
  local query = table.concat(lines, '')
  local prompt = state.config and state.config.prompt or ''
  if prompt ~= '' and vim.startswith(query, prompt) then
    query = query:sub(#prompt + 1)
  end

  return normalize_query(query)
end

open_file_picker = function(opts)
  opts = opts or {}

  local query = normalize_query(opts.query)
  local cwd = opts.cwd
  local title = opts.title

  remember_file_picker({
    query = query,
    cwd = cwd,
    title = title,
  })

  reopen(function()
    local fff = require('fff')
    local picker_opts = {}

    if cwd and cwd ~= '' then
      local config = require('fff.conf').get()
      if not same_directory(cwd, config.base_path) then
        local ok = fff.change_indexing_directory(cwd)
        if ok == false then
          return
        end
      end
      picker_opts.cwd = cwd
    end

    if title and title ~= '' then
      picker_opts.title = title
    end

    if query then
      picker_opts.query = query
    end

    fff.find_files(picker_opts)
  end)
end

-- Open the normal fff file picker.
local function find_files(query, cwd, title)
  open_file_picker({
    query = query,
    cwd = cwd,
    title = title,
  })
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
live_grep = function(query, cwd)
  query = normalize_query(query)

  remember_live_grep(query, cwd)

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
  find_files(nil, path, 'Files in ' .. vim.fn.fnamemodify(path, ':t'))
end

local function sync_picker_history()
  local ok, picker_ui = pcall(require, 'fff.picker_ui')
  if not ok or not picker_ui.state or not picker_ui.state.active then
    return
  end

  local state = picker_ui.state
  local cwd = state.config and state.config.base_path or vim.uv.cwd()
  local query = picker_input_query(state)

  if state.mode == 'grep' then
    remember_live_grep(query, cwd)
    return
  end

  remember_file_picker({
    query = query,
    cwd = cwd,
    title = state.config and state.config.title or nil,
  })
end

local function close_picker()
  local ok, picker_ui = pcall(require, 'fff.picker_ui')
  if ok and picker_ui.state and picker_ui.state.active then
    picker_ui.close()
  end
end

local function switch_from_picker(open_fn)
  picker_switch.open(open_fn)
end

local function feed_key_from_picker(key)
  vim.cmd.stopinsert()
  close_picker()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), 'm', false)
end

local function is_absolute_path(path)
  return path:sub(1, 1) == '/' or path:match('^%a:[/\\]') ~= nil or path:sub(1, 2) == '\\\\'
end

local function create_file_from_picker_query()
  local ok, picker_ui = pcall(require, 'fff.picker_ui')
  if not ok or not picker_ui.state or not picker_ui.state.active then
    return
  end

  if picker_ui.state.mode == 'grep' then
    vim.notify('Create file is only available in the fff file picker', vim.log.levels.WARN)
    return
  end

  local query = vim.trim(picker_ui.state.query or '')
  if query == '' then
    return
  end

  local base_path = picker_ui.state.config and picker_ui.state.config.base_path or vim.uv.cwd()
  local path = query
  if not is_absolute_path(path) then
    path = vim.fs.joinpath(base_path, path)
  end
  path = vim.fs.normalize(path)

  local parent = vim.fs.dirname(path)
  if parent and parent ~= '' then
    local mkdir_ok, mkdir_err = pcall(vim.fn.mkdir, parent, 'p')
    if not mkdir_ok then
      vim.notify('Failed to create parent directory: ' .. tostring(mkdir_err), vim.log.levels.ERROR)
      return
    end
  end

  if vim.fn.filereadable(path) == 0 then
    local write_ok, write_err = pcall(vim.fn.writefile, {}, path, 'b')
    if not write_ok or write_err ~= 0 then
      vim.notify('Failed to create file: ' .. path, vim.log.levels.ERROR)
      return
    end
  end

  vim.cmd.stopinsert()
  close_picker()
  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function open_oil_from_picker()
  local ok, picker_ui = pcall(require, 'fff.picker_ui')
  if not ok or not picker_ui.state or not picker_ui.state.active then
    return
  end

  local item = picker_ui.state.filtered_items[picker_ui.state.cursor]
  if not item or not item.path then
    return
  end

  local path = item.path
  switch_from_picker(function()
    require('nvimconf.oil').open_at_file(path)
  end)
end

local function define_user_commands()
  pcall(vim.api.nvim_del_user_command, 'FFFFind')
  pcall(vim.api.nvim_del_user_command, 'FFFGrep')
  pcall(vim.api.nvim_del_user_command, 'FFFInstall')

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
    local download = require_fff('fff.download')
    if not download then
      return
    end
    download.download_or_build_binary()
  end, {
    desc = 'Download or build the fff.nvim binary',
  })
end

-- Register user-facing commands, keymaps, and picker-local mappings.
function M.setup()
  if setup_done then
    return
  end

  define_user_commands()
  vim.api.nvim_create_autocmd('VimEnter', {
    group = vim.api.nvim_create_augroup('nvimconf-minimal.fff_commands', { clear = true }),
    once = true,
    callback = define_user_commands,
    desc = 'Reapply nvimconf FFF commands after plugin startup scripts run',
  })

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'fff_input',
    callback = function(args)
      sync_picker_history()

      local function buffer_map(lhs, rhs, desc)
        vim.keymap.set('i', lhs, rhs, {
          buffer = args.buf,
          noremap = true,
          silent = true,
          nowait = true,
          desc = desc,
        })
      end

      buffer_map('<m-u>', function()
        local picker_ui = require('fff.picker_ui')
        local query = picker_input_query(picker_ui.state)
        local cwd = picker_ui.state.config and picker_ui.state.config.base_path or vim.uv.cwd()

        vim.cmd.stopinsert()
        live_grep(query, cwd)
      end, 'FFF live grep')

      buffer_map('<m-n>', function()
        switch_from_picker(function()
          require('nvimconf.project_picker').open()
        end)
      end, 'FFF project picker')

      buffer_map('<m-o>', function()
        switch_from_picker(function()
          require('nvimconf.oldfiles_picker').open()
        end)
      end, 'FFF oldfiles picker')

      local function open_penguin_from_fff()
        switch_from_picker(function()
          require('nvimconf.penguin').open()
        end)
      end

      buffer_map('<m-cr>', function()
        sync_picker_history()
        switch_from_picker(function()
          require('nvimconf.picker_history').reopen()
        end)
      end, 'Reopen last picker')
      buffer_map('<m-space>', open_penguin_from_fff, 'FFF command history')
      buffer_map('<esc><cr>', open_penguin_from_fff, 'FFF command history (Esc Enter fallback)')
      buffer_map('<esc><c-m>', open_penguin_from_fff, 'FFF command history (Esc Ctrl-M fallback)')
      buffer_map('<c-g>', function()
        feed_key_from_picker('<c-g>')
      end, 'Close FFF and open lazygit')
      buffer_map('<c-o>', open_oil_from_picker, 'Open Oil at selected file')
      buffer_map('<S-CR>', create_file_from_picker_query, 'FFF create file from query')

      local group = vim.api.nvim_create_augroup('nvimconf-minimal.fff_history.' .. args.buf, { clear = true })
      vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChanged' }, {
        group = group,
        buffer = args.buf,
        callback = sync_picker_history,
      })
    end,
  })

  vim.keymap.set('n', '<c-return>', find_files, { desc = 'Find files' })
  vim.keymap.set('n', '<m-u>', live_grep, { desc = 'Project grep' })
  vim.keymap.set('n', '<leader>f', find_files, { desc = 'Find files' })
  vim.keymap.set('n', '<leader>ff', find_files, { desc = 'Find files' })
  vim.keymap.set('n', '<leader>fw', live_grep, { desc = 'Project grep' })
  setup_done = true
end

M.close = close_picker
M.find_files = find_files
M.find_files_in_dir = find_files_in_dir
M.live_grep = live_grep
picker_switch.register('fff', close_picker)

return M
