local map = vim.keymap.set

local function write_current()
  vim.cmd.write()
end

local function terminal_new_tab()
  vim.cmd '-tabnew | term'
  vim.cmd 'startinsert'
end

local function terminal_vertical()
  vim.cmd 'vsplit | term'
  vim.cmd 'startinsert'
end

local function terminal_horizontal()
  vim.cmd 'split | term'
  vim.cmd 'startinsert'
end
local function send_terminal_repeat(initial_command)
  vim.cmd.write()

  local terminal_buffer = find_terminal_buffer_number()
  if terminal_buffer ~= nil then
    local ok, chan = pcall(vim.api.nvim_buf_get_var, terminal_buffer, 'terminal_job_id')
    if ok and chan then
      vim.fn.chansend(chan, initial_command or 'r\r')
      scroll_buffer_to_bottom(terminal_buffer)
    end
    return
  end

  local bufname = vim.api.nvim_buf_get_name(0)
  vim.cmd 'split | term'

  if bufname:match '%.py$' then
    vim.cmd 'wincmd p'
    vim.defer_fn(function()
      send_terminal_repeat('python3 ' .. bufname .. ' \r')
    end, 220)
  else
    vim.cmd 'startinsert'
  end
end

local function yank_to_clipboard()
  vim.fn.setreg('+', vim.fn.getreg '"')
end

local function git_root()
  local result = vim.system({ 'git', 'rev-parse', '--show-toplevel' }, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify('Not inside a git repo', vim.log.levels.WARN)
    return nil
  end
  return vim.trim(result.stdout or '')
end

local function cd_to_git_root()
  local root = git_root()
  if root then
    vim.cmd.cd(vim.fn.fnameescape(root))
  end
end

local function tcd_to_git_root()
  local root = git_root()
  if root then
    vim.cmd.tcd(vim.fn.fnameescape(root))
  end
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

local function copy_github_url()
  local url = github_url()
  if url then
    vim.fn.setreg('+', url)
    vim.notify('GitHub URL copied', vim.log.levels.INFO)
  end
end

local function launch_github_url()
  local url = github_url()
  if url then
    vim.fn.setreg('+', url)
    vim.system({ 'open', url }, { detach = true })
  end
end

map('n', '<leader>q', '<cmd>q!<CR>', { silent = true, desc = 'Quit' })
map('n', '<leader><leader>q', '<cmd>qall!<CR>', { silent = true, desc = 'Quit all' })
map('n', '<leader>Q', '<cmd>qall!<CR>', { silent = true, desc = 'Quit all' })
map('n', 'Q', '<cmd>qall!<CR>', { silent = true, desc = 'Quit all' })
map('n', '<leader>w', write_current, { silent = true, desc = 'Write' })

-- Cwd and repo helpers
map('n', 'cd', change_dir_tab, { desc = 'Tab cwd to current file dir' })
map('n', '<leader>tc', change_dir_tab, { desc = 'Tab cwd to current file dir' })
map('n', '<leader>lc', change_dir_window, { desc = 'Window cwd to current file dir' })
map('n', '<leader>v', tcd_to_git_root, { noremap = true, desc = 'Tab cwd to git root' })
map('n', '<leader>V', cd_to_git_root, { noremap = true, desc = 'Cwd to git root' })
map('n', '<m-v>', cd_to_git_root, { noremap = true, desc = 'Cwd to git root' })
map('n', '<leader><leader>G', copy_github_url, { desc = 'Copy GitHub URL' })
map('n', '<leader><leader>g', launch_github_url, { desc = 'Open GitHub URL' })
map('n', '<leader>bd', '<cmd>bd!<CR>', { silent = true, desc = 'Delete buffer' })
map('n', '[b', '<cmd>bprev<CR>', { silent = true, desc = 'Previous buffer' })
map('n', ']b', '<cmd>bnext<CR>', { silent = true, desc = 'Next buffer' })
map('n', 'L', '<cmd>b#<CR>', { silent = true, desc = 'Last buffer' })

map('n', '[t', '<cmd>tabprev<CR>', { silent = true, desc = 'Previous tab' })
map('n', ']t', '<cmd>tabnext<CR>', { silent = true, desc = 'Next tab' })
map('n', '<a-[>', '<cmd>tabprev<CR>', { silent = true, desc = 'Previous tab' })
map('n', '<a-]>', '<cmd>tabnext<CR>', { silent = true, desc = 'Next tab' })
map('i', '<a-[>', '<esc><cmd>tabprev<CR>', { silent = true, desc = 'Previous tab' })
map('i', '<a-]>', '<esc><cmd>tabnext<CR>', { silent = true, desc = 'Next tab' })
map('n', 'gy', '<cmd>tabnext<CR>', { silent = true, desc = 'Next tab' })

for _, mode in ipairs({ 'n', 'i', 't' }) do
  local prefix = mode == 'i' and '<Esc>' or mode == 't' and '<C-\\><C-n>' or ''
  map(mode, 'gko', prefix .. ':tabn 1<CR>', {})
  map(mode, 'gk<cr>', prefix .. ':tabn 2<CR>', {})
  map(mode, 'gk ', prefix .. ':tabn 3<CR>', {})
  map(mode, 'gkg', prefix .. ':tabn 4<CR>', {})
  map(mode, 'gkk', prefix .. ':tabn 5<CR>', {})
  map(mode, 'gkd', prefix .. ':tabn 6<CR>', {})
  map(mode, 'gke', prefix .. ':tabn 7<CR>', {})
end

for i = 1, 8 do
  map('n', '<a-' .. i .. '>', ':tabn ' .. i .. '<CR>', { silent = true, desc = 'Go to tab ' .. i })
  map('n', '<leader>t' .. i, ':tabn ' .. i .. '<CR>', { silent = true, desc = 'Go to tab ' .. i })
end

map('n', '<Esc>', '<cmd>nohlsearch<CR>', { silent = true, desc = 'Clear search highlight' })
map('n', '<C-s>', function()
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes('/', true, true, true), 'n')
end, { silent = true, noremap = true, desc = 'Search' })
map('n', '<C-f>', function()
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes('/', true, true, true), 'n')
end, { silent = true, noremap = true, desc = 'Search' })

for _, lhs in ipairs({ 'ji', 'jk' }) do
  map('i', lhs, '<Esc>', { silent = true, desc = 'Escape insert mode' })
end

map('i', '<C-k>', check_and_delete, { expr = true, noremap = true, desc = 'Delete right or join line' })
map('i', '<C-f>', '<Right>', { silent = true, desc = 'Right' })
map('i', '<C-a>', '<Home>', { silent = true, desc = 'Home' })
map('i', '<C-e>', '<End>', { silent = true, desc = 'End' })
map('i', '<C-b>', '<Left>', { silent = true, desc = 'Left' })
map('i', '<C-p>', '<Up>', { silent = true, desc = 'Up' })
map('i', '<C-n>', '<Down>', { silent = true, desc = 'Down' })
map('i', '<C-d>', '<Del>', { silent = true, desc = 'Delete char' })
map('i', '<A-b>', '<C-o>b', { silent = true, desc = 'Back word' })
map('i', '<A-f>', '<C-o>w', { silent = true, desc = 'Forward word' })
map('i', '<A-d>', '<C-o>dw', { silent = true, desc = 'Delete word' })
map('t', '<Esc><Esc>', '<C-\\><C-n>', { silent = true, desc = 'Escape terminal mode' })

-- Diagnostics and quickfix
map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Previous diagnostic' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Next diagnostic' })
map('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Diagnostic float' })
map('n', '<leader><C-q>', vim.diagnostic.setloclist, { desc = 'Diagnostic loclist' })
map('n', ']q', '<cmd>cnext<CR>', { silent = true, desc = 'Next quickfix' })
map('n', '[q', '<cmd>cprev<CR>', { silent = true, desc = 'Previous quickfix' })

-- Clipboard
map('v', '<S-y>', '"+y', { noremap = true, silent = true, desc = 'Yank to clipboard' })
map('n', '<leader>y', 'ggVG"+y', { noremap = true, silent = true, desc = 'Yank whole file' })

-- User commands
vim.api.nvim_create_user_command('WQ', function()
  vim.cmd('wq!')
end, { desc = 'Write and quit' })

vim.api.nvim_create_user_command('Q', function()
  vim.cmd('qall!')
end, { desc = 'Quit all' })
