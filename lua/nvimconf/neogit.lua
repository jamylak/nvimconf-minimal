local M = {}
local bootstrap = require('nvimconf.bootstrap')

local loaded = false
local load

local function ensure_loaded()
  if not load() then
    return nil
  end

  return require('neogit')
end

local function ensure_diffview()
  return bootstrap.require_plugin('diffview', 'diffview.nvim')
end

load = function()
  if loaded then
    return true
  end

  local neogit = bootstrap.require_plugin('neogit', 'neogit')
  if not neogit then
    return false
  end

  pcall(vim.api.nvim_del_user_command, 'Neogit')

  neogit.setup({
    diff_viewer = 'diffview',
  })

  loaded = true
  return true
end

local function open_from_command(opts)
  local neogit = ensure_loaded()
  if not neogit then
    return
  end

  local args = require('neogit.lib.util').parse_command_args(opts.fargs)
  if opts.bang then
    args.kind = 'replace'
  end

  neogit.open(args)
end

local function diff_worktree()
  local diffview = ensure_diffview()
  if not diffview then
    return
  end

  diffview.open({})
end

local function diff_main(opts)
  local diffview = ensure_diffview()
  if not diffview then
    return
  end

  local base = opts.args ~= '' and opts.args or 'origin/main'
  diffview.open({ base .. '..HEAD' })
end

local function log_current()
  local neogit = ensure_loaded()
  if not neogit then
    return
  end

  local commits = require('neogit.lib.git').log.list({}, nil, nil, false, false)
  require('neogit.buffers.log_view').new(commits, {}):open()
  require('neogit.integrations.diffview').open('range', 'HEAD^..HEAD')
end

function M.setup()
  vim.api.nvim_create_user_command('Neogit', open_from_command, {
    nargs = '*',
    bang = true,
    complete = 'file',
    desc = 'Open Neogit',
  })

  vim.api.nvim_create_user_command('NeogitDiff', diff_worktree, {
    nargs = 0,
    desc = 'Open worktree diff in Neogit/Diffview',
  })

  vim.api.nvim_create_user_command('NeogitDiffMain', diff_main, {
    nargs = '?',
    complete = function()
      return { 'main', 'master', 'origin/main', 'origin/master' }
    end,
    desc = 'Open diff from main branch to HEAD',
  })

  vim.api.nvim_create_user_command('NeogitLog', log_current, {
    nargs = 0,
    desc = 'Open the log and last commit diff',
  })
end

return M
