local bootstrap = require("nvimconf2.bootstrap")

local function treesitter_install(method)
  return function()
    return require("nvimconf2.treesitter_install")[method]()
  end
end

require("nvimconf2.options")
require("nvimconf2.theme").apply()
require("nvimconf2.oil").setup()
require("nvimconf2.keymaps")
require("nvimconf2.fff").setup(bootstrap.fff_available)
require("nvimconf2.grug_far").setup()
require("nvimconf2.lsp").setup()
require("nvimconf2.blink").setup()

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
