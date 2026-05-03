local M = {}
local bootstrap = require('nvimconf.bootstrap')

local log_commit_count = 50
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

local function ensure_theme()
  require('nvimconf.theme').ensure()
end

local function ensure_plenary()
  return bootstrap.require_plugin('plenary.path', 'plenary.nvim')
end

load = function()
  if loaded then
    return true
  end

  if not ensure_plenary() then
    return false
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
  ensure_theme()

  local diffview = ensure_diffview()
  if not diffview then
    return
  end

  diffview.open({})
end

local function diff_main(opts)
  ensure_theme()

  local diffview = ensure_diffview()
  if not diffview then
    return
  end

  local base = opts.args ~= '' and opts.args or 'origin/main'
  diffview.open({ base .. '..HEAD' })
end

local function log_current()
  ensure_theme()

  if not ensure_loaded() then
    return
  end

  local git = require('neogit.lib.git')
  local diffview = ensure_diffview()
  if not diffview then
    return
  end

  local function commits(offset)
    local args = { ('--max-count=%d'):format(log_commit_count) }
    if offset and offset > 0 then
      table.insert(args, ('--skip=%d'):format(offset))
    end

    return git.log.list(args, nil, nil, false, false)
  end

  require('neogit.buffers.log_view')
    .new(commits(), {}, nil, commits)
    :open()

  diffview.open({ 'HEAD^..HEAD' })
end

M.open_from_command = open_from_command
M.diff_worktree = diff_worktree
M.diff_main = diff_main
M.log_current = log_current

return M
