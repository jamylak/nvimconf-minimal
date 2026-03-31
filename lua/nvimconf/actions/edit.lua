local M = {}

function M.write_current()
  vim.cmd.write()
end

function M.close_tab_or_quit()
  if #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd.tabclose()
  else
    vim.cmd.quit()
  end
end

function M.check_and_delete()
  local col = vim.fn.col '.'
  local line = vim.fn.getline '.'
  if col <= #line then
    return '<C-o>D'
  end
  return '<C-o>J'
end

function M.yank_to_clipboard()
  vim.fn.setreg('+', vim.fn.getreg '"')
end

return M
