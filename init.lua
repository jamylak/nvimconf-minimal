local bootstrap = require("nvimconf.bootstrap")

local function treesitter_install(method)
  return function()
    return require("nvimconf.treesitter_install")[method]()
  end
end

require("nvimconf.options")
require("nvimconf.ui").setup()
require("nvimconf.theme").apply()
require("nvimconf.oil").setup()
require("nvimconf.keymaps")
require("nvimconf.fff").setup(bootstrap.fff_available)
require("nvimconf.grug_far").setup()
require("nvimconf.lsp").setup()
require("nvimconf.blink").setup()

vim.api.nvim_create_user_command(
  "TSInstallFavorites",
  treesitter_install("install_favorites"),
  { desc = "Install favorite Treesitter parsers" }
)

vim.api.nvim_create_user_command(
  "TSUpdateFavorites",
  treesitter_install("update_favorites"),
  { desc = "Update favorite Treesitter parsers" }
)

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("nvimconf2.treesitter_install", { clear = true }),
  once = true,
  callback = function()
    if #vim.api.nvim_list_uis() == 0 then
      return
    end
    -- 🌳✨ Install missing favorite parsers after the first frame so startup stays fast.
    vim.schedule(treesitter_install("ensure_favorites"))
  end,
})
