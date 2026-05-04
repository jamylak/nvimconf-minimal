local bootstrap = require("nvimconf.bootstrap")

local function treesitter_install(method)
  return function()
    return require("nvimconf.treesitter_install")[method]()
  end
end

local function ensure_theme()
  require("nvimconf.theme").ensure()
end

require("nvimconf.options")

-- penguin.nvim has the real bare-Enter logic, but this config lazy-loads the
-- plugin, so the first <CR> needs a bootstrap mapping to reach it.
vim.keymap.set("n", "<CR>", function()
  return require("nvimconf.penguin").handle_bare_enter()
end, {
  desc = "Open penguin.nvim on bare Enter",
  expr = true,
  noremap = true,
  silent = true,
})

local function setup_fff()
  local fff = require("nvimconf.fff")
  fff.setup()
  return fff
end

local function fff_dir_complete(arg_lead)
  local dirs = vim.fn.glob(arg_lead .. "*", false, true)
  local results = {}
  for _, dir in ipairs(dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      results[#results + 1] = dir
    end
  end
  return results
end

vim.api.nvim_create_user_command("FFFFind", function(opts)
  setup_fff()
  if opts.args ~= "" then
    vim.cmd.FFFFind(opts.args)
  else
    vim.cmd.FFFFind()
  end
end, {
  nargs = "?",
  complete = fff_dir_complete,
  desc = "Find files with FFF",
})

vim.api.nvim_create_user_command("FFFGrep", function(opts)
  setup_fff().live_grep(opts.args ~= "" and opts.args or nil)
end, {
  nargs = "?",
  desc = "Open FFF live grep",
})

vim.api.nvim_create_user_command("FFFInstall", function()
  setup_fff()
  vim.cmd.FFFInstall()
end, {
  desc = "Download or build the fff.nvim binary",
})

local function setup_fff_keymaps()
  local function get_buffer_cwd()
    local path = vim.api.nvim_buf_get_name(0)
    if path:match("^oil://") then
      return path:sub(7)
    end
    return vim.fn.expand("%:p:h")
  end

  vim.keymap.set("n", "<c-return>", function()
    setup_fff().find_files()
  end, { desc = "Find files" })
  vim.keymap.set("n", "<m-u>", function()
    setup_fff().live_grep()
  end, { desc = "Project grep" })
  vim.keymap.set("n", "<leader>ff", function()
    setup_fff().find_files()
  end, { desc = "Find files" })
  vim.keymap.set("n", "<leader>fc", function()
    setup_fff().live_grep(vim.fn.expand("<cword>"))
  end, { desc = "Find current word" })
  vim.keymap.set("n", "<leader>fw", function()
    setup_fff().live_grep()
  end, { desc = "Project grep" })

  vim.keymap.set("n", "<leader>sf", function()
    setup_fff().find_files(nil, get_buffer_cwd())
  end, { desc = "Find files (cwd)" })
  vim.keymap.set("n", "<leader>sc", function()
    setup_fff().live_grep(vim.fn.expand("<cword>"), get_buffer_cwd())
  end, { desc = "Find current word (cwd)" })
  vim.keymap.set("n", "<leader>sw", function()
    setup_fff().live_grep(nil, get_buffer_cwd())
  end, { desc = "Project grep (cwd)" })
end

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("nvimconf-minimal.fff_keymaps", { clear = true }),
  once = true,
  callback = function()
    vim.schedule(setup_fff_keymaps)
  end,
  desc = "Install FFF keymaps after startup",
})

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
      -- Keep startup focused on the first frame, then install the broader
      -- launcher and editing keymaps one tick later.
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
  group = vim.api.nvim_create_augroup("nvimconf-minimal.theme", { clear = true }),
  once = true,
  callback = ensure_theme,
  desc = "Load theme on first real file buffer",
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
