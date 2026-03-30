local map = vim.keymap.set

local function write_current()
  vim.cmd.write()
end

map('n', '<leader>q', '<cmd>q!<CR>', { silent = true, desc = 'Quit' })
map('n', '<leader><leader>q', '<cmd>qall!<CR>', { silent = true, desc = 'Quit all' })
map('n', '<leader>Q', '<cmd>qall!<CR>', { silent = true, desc = 'Quit all' })
map('n', 'Q', '<cmd>qall!<CR>', { silent = true, desc = 'Quit all' })
map('n', '<leader>w', write_current, { silent = true, desc = 'Write' })

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

map('t', '<Esc><Esc>', '<C-\\><C-n>', { silent = true, desc = 'Escape terminal mode' })

map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Previous diagnostic' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Next diagnostic' })
map('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Diagnostic float' })
map('n', ']q', '<cmd>cnext<CR>', { silent = true, desc = 'Next quickfix' })
map('n', '[q', '<cmd>cprev<CR>', { silent = true, desc = 'Previous quickfix' })

vim.api.nvim_create_user_command('WQ', function()
  vim.cmd('wq!')
end, { desc = 'Write and quit' })

vim.api.nvim_create_user_command('Q', function()
  vim.cmd('qall!')
end, { desc = 'Quit all' })
