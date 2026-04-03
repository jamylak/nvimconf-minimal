local M = {}

local function current_file_path()
  return vim.fn.expand '%:p'
end

local function current_file_dir()
  local file_path = current_file_path()
  if file_path == '' then
    return (vim.uv or vim.loop).cwd()
  end
  return vim.fn.fnamemodify(file_path, ':h')
end

local function git_root(path)
  local base_dir = path and path ~= '' and vim.fn.fnamemodify(path, ':h') or (vim.uv or vim.loop).cwd()
  local result = vim.system({ 'git', '-C', base_dir, 'rev-parse', '--show-toplevel' }, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify('Not inside a git repo', vim.log.levels.WARN)
    return nil
  end
  return vim.trim(result.stdout or '')
end

local function current_file_git_context()
  local file = current_file_path()
  if file == '' then
    vim.notify('No file path for current buffer', vim.log.levels.WARN)
    return nil
  end

  local root = git_root(file)
  if not root then
    return nil
  end

  local rel_path = vim.fs.relpath(root, file)
  if not rel_path then
    vim.notify('Current file is outside git root', vim.log.levels.WARN)
    return nil
  end

  return {
    file = file,
    root = root,
    rel_path = rel_path,
  }
end

local function hunk_target_lines(diff_text)
  local targets = {}

  for line in vim.gsplit(diff_text or '', '\n', { plain = true, trimempty = true }) do
    local start_line, line_count = line:match '^@@ %-%d+,?%d* %+(%d+),?(%d*) @@'
    if start_line then
      local target = tonumber(start_line)
      local count = tonumber(line_count) or 1
      if count == 0 then
        target = math.max(target, 1)
      end
      table.insert(targets, target)
    end
  end

  return targets
end

local function current_file_hunk_targets()
  local context = current_file_git_context()
  if not context then
    return nil
  end

  local tracked = vim.system({
    'git',
    '-C',
    context.root,
    'ls-files',
    '--error-unmatch',
    '--',
    context.rel_path,
  }, { text = true }):wait()

  if tracked.code ~= 0 then
    return { 1 }
  end

  local has_head = vim.system({
    'git',
    '-C',
    context.root,
    'rev-parse',
    '--verify',
    'HEAD',
  }, { text = true }):wait().code == 0

  local diff_cmd = {
    'git',
    '-C',
    context.root,
    'diff',
    '--no-ext-diff',
    '--unified=0',
  }

  if has_head then
    table.insert(diff_cmd, 'HEAD')
  else
    table.insert(diff_cmd, '--cached')
  end

  vim.list_extend(diff_cmd, { '--', context.rel_path })

  local diff = vim.system(diff_cmd, { text = true }):wait()
  if diff.code ~= 0 then
    vim.notify('Failed to read git diff for current file', vim.log.levels.ERROR)
    return nil
  end

  return hunk_target_lines(diff.stdout)
end

local function jump_to_hunk(direction)
  local targets = current_file_hunk_targets()
  if not targets then
    return
  end
  if #targets == 0 then
    vim.notify('No git changes in current file', vim.log.levels.INFO)
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(0)[1]

  if direction > 0 then
    for _, target in ipairs(targets) do
      if target > current_line then
        vim.api.nvim_win_set_cursor(0, { target, 0 })
        return
      end
    end
    vim.api.nvim_win_set_cursor(0, { targets[1], 0 })
    return
  end

  for index = #targets, 1, -1 do
    if targets[index] < current_line then
      vim.api.nvim_win_set_cursor(0, { targets[index], 0 })
      return
    end
  end

  vim.api.nvim_win_set_cursor(0, { targets[#targets], 0 })
end

local function github_url()
  local context = current_file_git_context()
  if not context then
    return nil
  end

  local remote = vim.system({ 'git', '-C', context.root, 'config', '--get', 'remote.origin.url' }, { text = true }):wait()
  local branch = vim.system({ 'git', '-C', context.root, 'rev-parse', '--abbrev-ref', 'HEAD' }, { text = true }):wait()
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

  return string.format('%s/blob/%s/%s#L%d', remote_url, vim.trim(branch.stdout or ''), context.rel_path, vim.fn.line '.')
end

function M.change_dir_window()
  vim.cmd.lcd(vim.fn.fnameescape(current_file_dir()))
end

function M.change_dir_tab()
  vim.cmd.tcd(vim.fn.fnameescape(current_file_dir()))
end

function M.cd_to_git_root()
  local root = git_root(current_file_path())
  if root then
    vim.cmd.cd(vim.fn.fnameescape(root))
  end
end

function M.tcd_to_git_root()
  local root = git_root(current_file_path())
  if root then
    vim.cmd.tcd(vim.fn.fnameescape(root))
  end
end

function M.goto_next_hunk()
  jump_to_hunk(1)
end

function M.goto_prev_hunk()
  jump_to_hunk(-1)
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
