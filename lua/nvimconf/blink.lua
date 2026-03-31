local M = {}

local loaded = false

local function setup_blink()
  if loaded then
    return
  end

  -- Important: keep the blink.cmp submodule on a real release tag if you want
  -- the fast Rust fuzzy matcher to resolve via prebuilt binaries cleanly.
  local ok = pcall(vim.cmd, 'packadd blink.cmp')
  if not ok then
    vim.schedule(function()
      vim.notify('blink.cmp is missing. Run: git submodule update --init --recursive', vim.log.levels.ERROR)
    end)
    return
  end

  require('blink.cmp').setup({
    keymap = {
      preset = 'none',
      ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
      ['<C-e>'] = { 'hide' },
      ['<C-n>'] = { 'select_next', 'fallback' },
      ['<C-p>'] = { 'select_prev', 'fallback' },
      ['<C-y>'] = { 'select_and_accept' },
      ['<C-j>'] = { 'select_and_accept', 'fallback' },
    },
    fuzzy = {
      -- Important: prefer Blink's fast Rust matcher rather than the slower Lua fallback.
      implementation = 'prefer_rust',
      frecency = {
        enabled = false,
      },
      prebuilt_binaries = {
        -- Important: allow Blink to fetch its release-matched Rust fuzzy binary automatically.
        download = true,
      },
    },
    snippets = {
      preset = 'default',
    },
    completion = {
      list = {
        selection = {
          preselect = false,
          auto_insert = false,
        },
      },
      documentation = {
        auto_show = false,
      },
    },
    sources = {
      -- Important: keep this small, but include LSP once language servers are attached.
      default = { 'lsp', 'path', 'buffer' },
    },
    signature = {
      enabled = false,
    },
  })

  loaded = true
end

function M.setup()
  vim.api.nvim_create_autocmd('InsertEnter', {
    once = true,
    callback = setup_blink,
    desc = 'Load blink.cmp on first insert',
  })
end

return M
