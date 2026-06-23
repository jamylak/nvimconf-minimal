local M = {}

local bootstrap = require("nvimconf.bootstrap")
local stubs_created = false

local function notify_unavailable(message)
  vim.schedule(function()
    vim.notify(message, vim.log.levels.ERROR)
  end)
end

local function ensure_loaded()
  if package.loaded["guh.pr"] then
    return true
  end

  -- if not vim.version.ge(vim.version(), { 0, 13, 0 }) then
  --   notify_unavailable("guh.nvim requires Neovim 0.13+.")
  --   return false
  -- end

  -- guh.nvim defines :Guh and :GuhComment from plugin/guh.lua when packadd runs.
  -- Drop these local stubs first so upstream command creation can succeed.
  pcall(vim.api.nvim_del_user_command, "Guh")
  pcall(vim.api.nvim_del_user_command, "GuhComment")

  if not bootstrap.load_plugin("guh.nvim") then
    notify_unavailable('guh.nvim is unavailable. Run :lua vim.pack.update({ "guh.nvim" }) and then :restart.')
    return false
  end

  return true
end

function M.open(opts)
  if ensure_loaded() then
    require("guh.pr").select(opts)
  end
end

function M.comment(opts)
  if ensure_loaded() then
    require("guh.pr").comment(opts)
  end
end

function M.setup()
  if stubs_created then
    return true
  end

  vim.api.nvim_create_user_command("Guh", function(opts)
    M.open(opts)
  end, {
    nargs = "?",
    desc = "Open guh.nvim",
  })

  vim.api.nvim_create_user_command("GuhComment", function(opts)
    M.comment(opts)
  end, {
    bang = true,
    range = true,
    desc = "Comment with guh.nvim",
  })

  stubs_created = true
  return true
end

return M
