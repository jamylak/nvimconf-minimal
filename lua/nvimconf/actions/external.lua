local M = {}

local function current_file_path()
  return vim.fn.expand '%:p'
end

local function run_fish(command)
  vim.fn.system({ 'fish', '-c', command })
end

function M.yazi_hsplit_current_file()
  run_fish('yazi_hsplit ' .. current_file_path())
end

function M.yazi_vsplit_current_file()
  run_fish('yazi_vsplit ' .. current_file_path())
end

function M.yazi_current_file_new_tab()
  run_fish('yazi_new_tab ' .. current_file_path())
end

function M.yazi_here()
  run_fish('yazi')
end

function M.yazi_new_tab()
  vim.cmd.tabnew()
  M.yazi_here()
end

function M.open_current_file_in_helix()
  local filename = current_file_path()
  if filename == '' then
    vim.notify('No file path for current buffer', vim.log.levels.WARN)
    return
  end

  run_fish(string.format('hx_new_tab %q %d', filename, vim.fn.line '.'))
end

function M.execute_visual_selection_as_lua()
  local save_cursor = vim.api.nvim_win_get_cursor(0)
  local start_line = vim.fn.getpos("'<")[2]
  local end_line = vim.fn.getpos("'>")[2]
  if start_line == 0 or end_line == 0 then
    vim.notify('No visual selection to execute', vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local chunk, err = load(table.concat(lines, '\n'))
  if not chunk then
    vim.notify(err or 'Error in selected Lua code', vim.log.levels.ERROR)
  else
    pcall(chunk)
  end

  local line_count = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, {
    math.min(math.max(save_cursor[1], 1), line_count),
    math.max(save_cursor[2], 0),
  })
end

return M
