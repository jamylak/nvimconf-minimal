local M = {}

local snacks_loaded = false

local function ensure_snacks_lazygit()
  local repo_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h:h')
  if not vim.tbl_contains(vim.opt.packpath:get(), repo_root) then
    vim.opt.packpath:prepend(repo_root)
  end

  local ok = pcall(vim.cmd, 'packadd snacks.nvim')
  if not ok then
    vim.notify('snacks.nvim is missing', vim.log.levels.ERROR)
    return nil
  end

  local snacks = require 'snacks'
  if not snacks_loaded then
    snacks.setup({
      lazygit = {},
    })
    snacks_loaded = true
  end

  return snacks
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

return M
