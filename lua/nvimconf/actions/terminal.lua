local M = {}

function M.open()
  vim.cmd 'term!'
  vim.cmd 'startinsert'
end

function M.new_tab()
  vim.cmd '-tabnew | term'
  vim.cmd 'startinsert'
end

function M.vertical()
  vim.cmd 'vsplit | term'
  vim.cmd 'startinsert'
end

function M.horizontal()
  vim.cmd 'split | term'
  vim.cmd 'startinsert'
end

local function find_terminal_buffer_number()
  local tabpage = vim.api.nvim_get_current_tabpage()
  local windows = vim.api.nvim_tabpage_list_wins(tabpage)

  for _, window in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(window)
    if vim.bo[buf].buftype == 'terminal' then
      return buf
    end
  end
end

local function scroll_buffer_to_bottom(buf_id)
  vim.api.nvim_buf_call(buf_id, function()
    vim.cmd 'normal! G'
  end)
end

function M.send_repeat(initial_command)
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
      M.send_repeat('python3 ' .. bufname .. ' \r')
    end, 220)
  else
    vim.cmd 'startinsert'
  end
end

function M.horizontal_split()
  vim.cmd ':split | term'
  vim.cmd 'startinsert'
end

function M.vertical_split()
  vim.cmd ':vsplit | term'
  vim.cmd 'startinsert'
end

function M.attach_tmux()
  vim.cmd 'new | term tmux a'
end

function M.setup()
  vim.api.nvim_create_autocmd('TermOpen', {
    pattern = '*',
    callback = function(args)
      local name = vim.api.nvim_buf_get_name(args.buf)
      if not name:match 'yazi' and not name:match 'lazygit' then
        vim.keymap.set('t', 'jk', '<C-\\><C-n>', { buffer = args.buf, silent = true })
        vim.keymap.set('t', 'ji', '<C-\\><C-n>', { buffer = args.buf, silent = true })
      end
    end,
  })
end

return M
