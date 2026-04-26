local M = {}

local function ensure_snacks_lazygit()
  return require('nvimconf.snacks').ensure({
    lazygit = {},
  })
end

function M.open()
  if vim.fn.executable('lazygit') ~= 1 then
    vim.notify('lazygit is not installed', vim.log.levels.ERROR)
    return
  end

  local snacks = ensure_snacks_lazygit()
  if not snacks then
    return
  end

  snacks.lazygit()
end

function M.log_file()
  if vim.fn.executable('lazygit') ~= 1 then
    vim.notify('lazygit is not installed', vim.log.levels.ERROR)
    return
  end

  local snacks = ensure_snacks_lazygit()
  if not snacks then
    return
  end

  snacks.lazygit.log_file()
end

return M
