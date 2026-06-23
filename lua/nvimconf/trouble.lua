local M = {}

local bootstrap = require("nvimconf.bootstrap")
local setup_done = false

local function trouble_in_current_tab()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "trouble" then
      return true
    end
  end

  return false
end

local function ensure_trouble()
  bootstrap.load_plugin("nvim-web-devicons")
  local trouble = bootstrap.require_plugin("trouble", "trouble.nvim")
  if not trouble then
    return nil
  end

  if not setup_done then
    trouble.setup({
      warn_no_results = false,
      open_no_results = true,
    })
    setup_done = true
  end

  return trouble
end

function M.preset()
  local trouble = ensure_trouble()
  if not trouble then
    return
  end

  if trouble_in_current_tab() then
    trouble.close()
    trouble.close()
    return
  end

  trouble.open({ mode = "symbols", new = true, focus = false })
  trouble.open({ mode = "lsp", new = true, focus = false, win = { position = "bottom" } })
end

function M.trouble_and_explorer()
  require("nvimconf.actions.explorer").toggle()
  M.preset()
end

return M
