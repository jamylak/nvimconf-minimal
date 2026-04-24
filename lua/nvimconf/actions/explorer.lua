local M = {}

local function ensure_snacks_explorer()
  return require('nvimconf.snacks').ensure({
    picker = {},
    explorer = {},
  })
end

function M.toggle()
  local snacks = ensure_snacks_explorer()
  if not snacks then
    return
  end

  local previous_win = vim.api.nvim_get_current_win()
  local explorer = snacks.explorer({
    on_show = function()
      if vim.api.nvim_win_is_valid(previous_win) then
        vim.api.nvim_set_current_win(previous_win)
      end
    end,
  })
  if explorer then
    return
  end
end

return M
