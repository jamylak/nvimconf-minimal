local M = {}

local function current_file_dir()
  local file_path = vim.fn.expand '%:p'
  if file_path == '' then
    return (vim.uv or vim.loop).cwd()
  end
  return vim.fn.fnamemodify(file_path, ':h')
end

local function git_root()
  local result = vim.system({ 'git', 'rev-parse', '--show-toplevel' }, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify('Not inside a git repo', vim.log.levels.WARN)
    return nil
  end
  return vim.trim(result.stdout or '')
end

local function github_url()
  local root = git_root()
  if not root then
    return nil
  end

  local file = vim.fn.expand '%:p'
  if file == '' then
    vim.notify('No file path for current buffer', vim.log.levels.WARN)
    return nil
  end

  local rel_path = vim.fs.relpath(root, file)
  if not rel_path then
    vim.notify('Current file is outside git root', vim.log.levels.WARN)
    return nil
  end

  local remote = vim.system({ 'git', '-C', root, 'config', '--get', 'remote.origin.url' }, { text = true }):wait()
  local branch = vim.system({ 'git', '-C', root, 'rev-parse', '--abbrev-ref', 'HEAD' }, { text = true }):wait()
  if remote.code ~= 0 or branch.code ~= 0 then
    vim.notify('Failed to resolve git remote or branch', vim.log.levels.ERROR)
    return nil
  end

  local remote_url = vim.trim(remote.stdout or '')
  if remote_url:find 'git@' then
    remote_url = remote_url:gsub(':', '/'):gsub('git@', 'https://'):gsub('%.git$', '')
  elseif remote_url:find 'https://' then
    remote_url = remote_url:gsub('%.git$', '')
  end

  return string.format('%s/blob/%s/%s#L%d', remote_url, vim.trim(branch.stdout or ''), rel_path, vim.fn.line '.')
end

function M.change_dir_window()
  vim.cmd.lcd(vim.fn.fnameescape(current_file_dir()))
end

function M.change_dir_tab()
  vim.cmd.tcd(vim.fn.fnameescape(current_file_dir()))
end

function M.cd_to_git_root()
  local root = git_root()
  if root then
    vim.cmd.cd(vim.fn.fnameescape(root))
  end
end

function M.tcd_to_git_root()
  local root = git_root()
  if root then
    vim.cmd.tcd(vim.fn.fnameescape(root))
  end
end

function M.copy_github_url()
  local url = github_url()
  if url then
    vim.fn.setreg('+', url)
    vim.notify('GitHub URL copied', vim.log.levels.INFO)
  end
end

function M.launch_github_url()
  local url = github_url()
  if url then
    vim.fn.setreg('+', url)
    vim.system({ 'open', url }, { detach = true })
  end
end

return M
