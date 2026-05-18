local M = {}
local bootstrap = require('nvimconf.bootstrap')

local loaded = false
local stubs_created = false

local cplug_keymaps = {
  compile_debug = { '<leader>c', '<leader>gj' },
  toggle_ui = '<leader>gg',
  layout_picker = '<leader>gl',
  continue = { '<leader>gc', '<leader><leader>c' },
  terminate = '<leader>gx',
  step_over = '<leader>gn',
  step_into = '<leader>gi',
  step_out = '<leader>go',
  toggle_breakpoint = '<leader>gb',
  run_to_cursor = '<leader>gr',
  restart = '<leader>gq',
  evaluate = '<leader>ge',
}

local function normalize_keymaps(binding)
  if type(binding) == 'string' then
    return { binding }
  end

  if vim.islist(binding) then
    local result = {}

    for _, lhs in ipairs(binding) do
      if type(lhs) == 'string' and lhs ~= '' then
        table.insert(result, lhs)
      end
    end

    return result
  end

  return {}
end

local function notify_unavailable(message)
  vim.schedule(function()
    vim.notify(message, vim.log.levels.ERROR)
  end)
end

local function load_cplug()
  if loaded then
    return package.loaded.cplug
  end

  bootstrap.load_plugin('nvim-dap')
  bootstrap.load_plugin('nvim-nio')
  bootstrap.load_plugin('nvim-dap-ui')
  bootstrap.load_plugin('nvim-dap-disasm')

  -- This config sometimes develops against a local cplug checkout. Keep it off
  -- runtimepath until a cplug command or keymap is actually invoked.
  bootstrap.ensure_local_runtimepath('cplug.nvim', bootstrap.cplug_dir)

  local ok, cplug = pcall(require, 'cplug')
  if not ok then
    local stat = vim.uv.fs_stat(bootstrap.cplug_dir)
    local message

    if not stat or stat.type ~= 'directory' then
      message = string.format(
        'cplug.nvim is unavailable. Expected local checkout at %s.',
        bootstrap.cplug_dir
      )
    else
      message = string.format('Failed to load cplug.nvim from %s: %s', bootstrap.cplug_dir, cplug)
    end

    notify_unavailable(message)
    return nil
  end

  cplug.setup({
    create_commands = false,
    default_keymaps = false,
  })
  loaded = true
  return cplug
end

local function run(action)
  return function(...)
    local cplug = load_cplug()
    if not cplug then
      return nil
    end

    return cplug[action](...)
  end
end

local function map_action(binding, action, desc)
  for _, lhs in ipairs(normalize_keymaps(binding)) do
    vim.keymap.set('n', lhs, run(action), { desc = desc })
  end
end

local function create_command(name, action, opts)
  vim.api.nvim_create_user_command(name, function(command_opts)
    local cplug = load_cplug()
    if not cplug then
      return
    end

    cplug[action](command_opts.args)
  end, opts)
end

function M.setup()
  if stubs_created then
    return true
  end

  map_action(cplug_keymaps.compile_debug, 'compile_and_debug', 'Compile and debug project')
  map_action(cplug_keymaps.toggle_ui, 'toggle_ui', 'Toggle debug UI')
  map_action(cplug_keymaps.layout_picker, 'select_layout', 'Select debug UI layout')
  map_action(cplug_keymaps.continue, 'continue', 'Continue debug session')
  map_action(cplug_keymaps.terminate, 'terminate', 'Terminate debug session')
  map_action(cplug_keymaps.step_over, 'step_over', 'Step over')
  map_action(cplug_keymaps.step_into, 'step_into', 'Step into')
  map_action(cplug_keymaps.step_out, 'step_out', 'Step out')
  map_action(cplug_keymaps.toggle_breakpoint, 'toggle_breakpoint', 'Toggle breakpoint')
  map_action(cplug_keymaps.run_to_cursor, 'run_to_cursor', 'Run to cursor')
  map_action(cplug_keymaps.restart, 'restart', 'Restart debug session')
  map_action(cplug_keymaps.evaluate, 'evaluate', 'Evaluate expression at cursor')

  create_command('CPlugCompileDebug', 'compile_and_debug', {
    desc = 'Compile the current project in debug mode and start debugging',
  })
  create_command('CPlugAttach', 'attach', {
    desc = 'Attach to an existing debug target using the selected attach config',
  })
  create_command('CPlugGenerateAttach', 'generate_attach_config', {
    desc = 'Generate or update an attach configuration for the current project',
  })
  create_command('CPlugCMakeConfigure', 'cmake_configure', {
    desc = 'Configure the current CMake project in debug mode',
  })
  create_command('CPlugCMakeBuildOnce', 'cmake_build_once', {
    desc = 'Build the current CMake project once in debug mode',
  })
  create_command('CPlugCMakeBuildAndRun', 'cmake_build_and_run', {
    desc = 'Build and run the current CMake project in debug mode',
  })
  create_command('CPlugCMakeRun', 'cmake_run', {
    desc = 'Run the current CMake project without rebuilding',
  })
  vim.api.nvim_create_user_command('CPlugLayout', function(opts)
    local cplug = load_cplug()
    if not cplug then
      return
    end

    if opts.args == '' then
      cplug.select_layout()
      return
    end

    cplug.set_layout(opts.args)
  end, {
    nargs = '?',
    complete = function()
      local cplug = load_cplug()
      if not cplug then
        return {}
      end

      return cplug.layout_names(true)
    end,
    desc = 'Switch the managed DAP UI layout or open the layout picker',
  })

  stubs_created = true
  return true
end

return M
