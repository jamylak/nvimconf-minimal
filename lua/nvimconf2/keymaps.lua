local map = vim.keymap.set

local edit = require('nvimconf2.actions.edit')
local git = require('nvimconf2.actions.git')
local external = require('nvimconf2.actions.external')
local terminal = require('nvimconf2.actions.terminal')

terminal.setup()

-- Commands
map('n', '<leader>m', '<cmd>make<CR>', { silent = true, desc = 'Run make' })
map('n', '<leader>q', '<cmd>q!<CR>', { silent = true, desc = 'Quit' })
map('n', '<leader><leader>q', '<cmd>qall!<CR>', { silent = true, desc = 'Quit all' })
map('n', '<leader>Q', '<cmd>qall!<CR>', { silent = true, desc = 'Quit all' })
map('n', 'Q', '<cmd>qall!<CR>', { silent = true, desc = 'Quit all' })
map('n', '<leader>w', edit.write_current, { silent = true, desc = 'Write' })

-- Splits
map('n', '\\', '<cmd>split<CR>', { silent = true, desc = 'Horizontal split' })
map('n', '|', '<cmd>vsplit<CR>', { silent = true, desc = 'Vertical split' })
map('n', '<leader>K', '<cmd>split<CR>', { silent = true, desc = 'Horizontal split' })
map('n', '<leader>k', '<cmd>vsplit<CR>', { silent = true, desc = 'Vertical split' })
map('n', '<leader>\\', external.yazi_hsplit_current_file, { silent = true, desc = 'Yazi horizontal split' })
map('n', '<leader>|', external.yazi_vsplit_current_file, { silent = true, desc = 'Yazi vertical split' })
map('n', '<leader>I', external.yazi_current_file_new_tab, { silent = true, desc = 'Yazi new tab' })

-- Cwd and repo helpers
map('n', 'cd', git.change_dir_tab, { desc = 'Tab cwd to current file dir' })
map('n', '<leader>tc', git.change_dir_tab, { desc = 'Tab cwd to current file dir' })
map('n', '<leader>lc', git.change_dir_window, { desc = 'Window cwd to current file dir' })
map('n', '<leader>v', git.tcd_to_git_root, { noremap = true, desc = 'Tab cwd to git root' })
map('n', '<leader>V', git.cd_to_git_root, { noremap = true, desc = 'Cwd to git root' })
map('n', '<m-v>', git.cd_to_git_root, { noremap = true, desc = 'Cwd to git root' })
map('n', '<leader>bc', git.cd_to_git_root, { noremap = true, desc = 'Cwd to git root' })
map('n', '<leader><leader>G', git.copy_github_url, { desc = 'Copy GitHub URL' })
map('n', '<leader><leader>g', git.launch_github_url, { desc = 'Open GitHub URL' })

-- External helpers
map('n', '<leader><leader>y', '<cmd>let @+ = expand("%:p")<CR>', { noremap = true, silent = true, desc = 'Yank file path' })
map('n', '<leader>Y', external.open_current_file_in_helix, { desc = 'Open current file in helix' })
map('n', '<leader>H', external.open_current_file_in_helix, { desc = 'Open current file in helix' })
map('n', '<leader><leader>Y', external.open_current_file_in_helix, { desc = 'Open current file in helix' })
map('v', '<leader><leader>r', external.execute_visual_selection_as_lua, { noremap = true, desc = 'Execute Lua selection' })
map('n', '<leader><leader>s', '<cmd>source %<CR>', { noremap = true, desc = 'Source current Lua file' })
map('n', '<A-y>', external.yazi_here, { noremap = true, silent = true, desc = 'Open yazi' })
map('n', '<C-y>', external.yazi_new_tab, { noremap = true, silent = true, desc = 'Open yazi in new tab' })

-- Windows and buffers
map('n', '<a-d>', '<C-W><C-W>', { silent = true, desc = 'Next window' })
map('n', 'm', '<C-W><C-W>', { silent = true, desc = 'Next window' })
map('n', 'M', '<C-W>W', { silent = true, desc = 'Previous window' })
map('n', 'gw', '<C-W><C-W>', { silent = true, desc = 'Next window' })
map('n', 'qw', '<C-W><C-O>', { silent = true, desc = 'Only window' })
map('n', '<leader>bd', '<cmd>bd!<CR>', { silent = true, desc = 'Delete buffer' })
map('n', 'sb', '<cmd>b#<CR>', { silent = true, desc = 'Swap buffer' })
map('n', 'sj', '<cmd>b#<CR>', { silent = true, desc = 'Swap buffer' })
map('n', 'sk', '<cmd>tabnext#<CR>', { silent = true, desc = 'Swap tab' })
map('n', 'qj', '<C-W>p', { silent = true, desc = 'Previous window' })
map('n', '[b', '<cmd>bprev<CR>', { silent = true, desc = 'Previous buffer' })
map('n', ']b', '<cmd>bnext<CR>', { silent = true, desc = 'Next buffer' })
map('n', 'L', '<cmd>b#<CR>', { silent = true, desc = 'Last buffer' })

-- Tabs
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
