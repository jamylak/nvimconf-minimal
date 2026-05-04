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

local function log_commits()
  local git = require('neogit.lib.git')

  -- Keep Neogit's normal paged log fetcher intact, but do not call it until
  -- after Diffview has drawn. The first call is the expensive 50-commit load;
  -- later calls are used by the "+" mapping to fetch more history.
  return function(offset)
    local args = { ('--max-count=%d'):format(log_commit_count) }
    if offset and offset > 0 then
      table.insert(args, ('--skip=%d'):format(offset))
    end

    return git.log.list(args, nil, nil, false, false)
  end
end

local function open_log_tab(commits)
  -- This deliberately matches the old end state: Neogit's log view gets the
  -- same first page of commits and the same callback for loading more.
  require('neogit.buffers.log_view')
    .new(commits(), {}, nil, commits)
    :open()
end

local function restore_diff_tab(diff_tab)
  -- Opening the log steals focus because Neogit's log view is a tab buffer.
  -- Put the user back on the Diffview tab that appeared first.
  if diff_tab and vim.api.nvim_tabpage_is_valid(diff_tab) then
    pcall(vim.api.nvim_set_current_tabpage, diff_tab)
  end
end

local function move_log_before_diff(log_tab, diff_tab)
  -- The command should still settle as: tab 1 = log, tab 2 = last-commit diff.
  -- Since Diffview opens first now, the deferred log tab has to be moved back
  -- in front of the Diffview tab after it is created.
  if not (log_tab and vim.api.nvim_tabpage_is_valid(log_tab)) then
    return
  end

  if not (diff_tab and vim.api.nvim_tabpage_is_valid(diff_tab)) then
    return
  end

  -- Capture Diffview's current tab number before focusing the log tab. Tab
  -- numbers are positional, so this is the insertion point for :tabmove.
  local diff_tab_number = vim.api.nvim_tabpage_get_number(diff_tab)

  if pcall(vim.api.nvim_set_current_tabpage, log_tab) then
    vim.cmd.tabmove(math.max(diff_tab_number - 1, 0))
  end
end

local function log_current()
  ensure_theme()

  if not ensure_loaded() then
    return
  end

  local diffview = ensure_diffview()
  if not diffview then
    return
  end

  local commits = log_commits()

  -- First frame: show the useful last-commit diff immediately. The old version
  -- blocked here on git log parsing before opening Diffview.
  diffview.open({ 'HEAD^..HEAD' })

  local diff_tab = vim.api.nvim_get_current_tabpage()

  -- Second phase: build the log tab once the UI has had a chance to render the
  -- diff. This trades a later "everything is ready" time for a much faster
  -- visible first frame while preserving the final tab order and focus.
  vim.defer_fn(function()
    open_log_tab(commits)

    local log_tab = vim.api.nvim_get_current_tabpage()
    move_log_before_diff(log_tab, diff_tab)
    restore_diff_tab(diff_tab)
  end, 25)
end

M.open_from_command = open_from_command
M.diff_worktree = diff_worktree
M.diff_main = diff_main
M.log_current = log_current

return M
