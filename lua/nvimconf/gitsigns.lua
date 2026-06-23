local M = {}

local bootstrap = require("nvimconf.bootstrap")

local function is_normal_file_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buftype = vim.bo[bufnr].buftype
  if buftype ~= "" then
    return false
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= "" and vim.uv.fs_stat(name) ~= nil
end

local function setup_buffer_keymaps(bufnr)
  local gitsigns = require("gitsigns")

  local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.buffer = bufnr
    vim.keymap.set(mode, lhs, rhs, opts)
  end

  map("n", "]h", function()
    if vim.wo.diff then
      vim.cmd.normal({ "]c", bang = true })
    else
      gitsigns.nav_hunk("next")
    end
  end, { desc = "Next Hunk" })

  map("n", "[h", function()
    if vim.wo.diff then
      vim.cmd.normal({ "[c", bang = true })
    else
      gitsigns.nav_hunk("prev")
    end
  end, { desc = "Previous Hunk" })

  map("n", "]g", function()
    if vim.wo.diff then
      vim.cmd.normal({ "]c", bang = true })
    else
      gitsigns.nav_hunk("next")
    end
  end, { desc = "Next Hunk" })

  map("n", "[g", function()
    if vim.wo.diff then
      vim.cmd.normal({ "[c", bang = true })
    else
      gitsigns.nav_hunk("prev")
    end
  end, { desc = "Previous Hunk" })

  map("n", "<leader>hs", gitsigns.stage_hunk, { desc = "Stage Hunk" })
  map("n", "<leader>hr", gitsigns.reset_hunk, { desc = "Reset Hunk" })
  map("x", "<leader>hs", function()
    gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
  end, { desc = "Stage Hunk" })
  map("x", "<leader>hr", function()
    gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
  end, { desc = "Reset Hunk" })
  map("n", "<leader>hS", gitsigns.stage_buffer, { desc = "Stage Buffer" })
  map("n", "<leader>hu", gitsigns.undo_stage_hunk, { desc = "Undo Stage Hunk" })
  map("n", "<leader>hR", gitsigns.reset_buffer, { desc = "Reset Buffer" })
  map("n", "<leader>hp", gitsigns.preview_hunk, { desc = "Preview Hunk" })
  map("n", "<leader>hb", function()
    gitsigns.blame_line({ full = true })
  end, { desc = "Blame Line" })
  map("n", "<leader>hB", function()
    vim.cmd("Gitsigns blame")
    vim.cmd("wincmd p")
  end, { desc = "Blame" })
  map("n", "<leader>hd", gitsigns.diffthis, { desc = "Diff This" })
  map("n", "<leader>hD", function()
    gitsigns.diffthis("~")
  end, { desc = "Diff This ~" })
  map("n", "<leader>tb", gitsigns.toggle_current_line_blame, { desc = "Toggle Blame" })
  map("n", "<leader>td", gitsigns.toggle_deleted, { desc = "Gitsigns - Toggle Deleted" })
  map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Git Hunk" })
end

function M.setup()
  -- Use :packadd! so gitsigns/plugin/gitsigns.lua is not sourced. That file
  -- calls require("gitsigns").setup() with defaults, which would attach before
  -- our max_file_length/blame/untracked settings are applied.
  if not bootstrap.load_plugin("gitsigns.nvim", { plugin_scripts = false }) then
    return
  end

  local ok, gitsigns = pcall(require, "gitsigns")
  if not ok then
    return
  end

  gitsigns.setup({
    signs = {
      add = { text = "+" },
      change = { text = "~" },
      delete = { text = "_" },
      topdelete = { text = "^" },
      changedelete = { text = "~" },
      untracked = { text = "|" },
    },
    signs_staged = {
      add = { text = "+" },
      change = { text = "~" },
      delete = { text = "_" },
      topdelete = { text = "^" },
      changedelete = { text = "~" },
      untracked = { text = "|" },
    },
    attach_to_untracked = false,
    current_line_blame = true,
    current_line_blame_opts = {
      delay = 1000,
      ignore_whitespace = true,
      virt_text = true,
      virt_text_pos = "eol",
    },
    update_debounce = 150,
    max_file_length = 20000,
    on_attach = setup_buffer_keymaps,
  })

  if type(gitsigns.attach) == "function" then
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if is_normal_file_buffer(bufnr) then
        pcall(gitsigns.attach, { bufnr = bufnr, trigger = "nvimconf-minimal" })
      end
    end
  end
end

return M
