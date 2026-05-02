local bootstrap = require("nvimconf.bootstrap")

local function treesitter_install(method)
  return function()
    return require("nvimconf.treesitter_install")[method]()
  end
end

require("nvimconf.options")
require("nvimconf.theme").apply()
require("nvimconf.fff").setup()

-- Keep only the picker hot-path maps on the first frame. The rest of the
-- keymap file is deferred until VimEnter so empty startup does not pay for the
-- full mapping set up front.
vim.keymap.set("n", "<m-n>", function()
  require("nvimconf.project_picker").open()
end, { silent = true, desc = "Switch project" })

vim.keymap.set("n", "<m-o>", function()
  require("nvimconf.oldfiles_picker").open()
end, { silent = true, desc = "Oldfiles" })

vim.keymap.set("n", "<m-cr>", function()
  require("nvimconf.picker_history").reopen()
end, { silent = true, desc = "Reopen last picker" })

vim.api.nvim_create_user_command("ProjectPicker", function()
  require("nvimconf.project_picker").open()
end, { desc = "Project Picker" })

vim.api.nvim_create_user_command("Oldfiles", function(opts)
  require("nvimconf.oldfiles_picker").open(opts.args ~= "" and opts.args or nil)
end, {
  nargs = "?",
  desc = "Open oldfiles picker",
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("nvimconf-minimal.cplug", { clear = true }),
  once = true,
  callback = function()
    -- Comments are not needed for the first frame, so load cplug after startup.
    vim.schedule(function()
      require("nvimconf.cplug").setup()
    end)
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("nvimconf-minimal.ui", { clear = true }),
  once = true,
  callback = function()
    vim.schedule(function()
      -- Most mappings are not needed to reach the first frame or open the core
      -- pickers, so load them one tick later to trim cold-start latency.
      require("nvimconf.keymaps")
      require("nvimconf.ui").setup()
    end)
  end,
})

vim.api.nvim_create_user_command("Oil", function(opts)
  require("nvimconf.oil").open_from_command(opts)
end, {
  nargs = "*",
  complete = "dir",
  desc = "Open Oil file browser",
})

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("nvimconf-minimal.oil", { clear = true }),
  nested = true,
  once = true,
  callback = function()
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" or vim.fn.isdirectory(path) ~= 1 then
      return
    end
    require("nvimconf.oil").open_startup_directory()
  end,
})

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  group = vim.api.nvim_create_augroup("nvimconf-minimal.lsp", { clear = true }),
  once = true,
  callback = function()
    require("nvimconf.lsp").setup()
  end,
  desc = "Load LSP wiring on first real file buffer",
})

vim.api.nvim_create_user_command("Neogit", function(opts)
  require("nvimconf.neogit").open_from_command(opts)
end, {
  nargs = "*",
  bang = true,
  complete = "file",
  desc = "Open Neogit",
})

vim.api.nvim_create_user_command("NeogitDiff", function()
  require("nvimconf.neogit").diff_worktree()
end, {
  nargs = 0,
  desc = "Open worktree diff in Neogit/Diffview",
})

vim.api.nvim_create_user_command("NeogitDiffMain", function(opts)
  require("nvimconf.neogit").diff_main(opts)
end, {
  nargs = "?",
  complete = function()
    return { "main", "master", "origin/main", "origin/master" }
  end,
  desc = "Open diff from main branch to HEAD",
})

vim.api.nvim_create_user_command("NeogitLog", function()
  require("nvimconf.neogit").log_current()
end, {
  nargs = 0,
  desc = "Open the log and last commit diff",
})

vim.api.nvim_create_autocmd("InsertEnter", {
  group = vim.api.nvim_create_augroup("nvimconf-minimal.blink", { clear = true }),
  once = true,
  callback = function()
    require("nvimconf.blink").load()
  end,
  desc = "Load blink.cmp on first insert",
})

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("nvimconf-minimal.markdown_images", { clear = true }),
  pattern = { "markdown", "norg" },
  callback = function(args)
    vim.schedule(function()
      require("nvimconf.markdown_images").attach_buffer(args.buf)
    end)
  end,
  desc = "Attach Snacks image rendering after markdown buffers load",
})

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
  group = vim.api.nvim_create_augroup("nvimconf-minimal.treesitter_install", { clear = true }),
  once = true,
  callback = function()
    if #vim.api.nvim_list_uis() == 0 then
      return
    end
    -- 🌳✨ Install missing favorite parsers after the first frame so startup stays fast.
    vim.schedule(treesitter_install("ensure_favorites"))
  end,
})
