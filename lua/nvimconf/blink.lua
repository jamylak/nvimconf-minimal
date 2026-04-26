local M = {}
local bootstrap = require('nvimconf.bootstrap')

local loaded = false

local function setup_blink()
  if loaded then
    return
  end

  local blink = bootstrap.require_plugin('blink.cmp', 'blink.cmp')
  if not blink then
    return
  end

  blink.setup({
    keymap = {
      preset = 'none',
      ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
      ['<C-e>'] = { 'hide', 'fallback' },
      ['<C-n>'] = { 'select_next', 'fallback' },
      ['<C-p>'] = { 'select_prev', 'fallback' },
      ['<C-y>'] = { 'select_and_accept', 'fallback' },
      ['<C-j>'] = { 'select_and_accept', 'fallback' },
    },
    fuzzy = {
      -- Important: prefer Blink's fast Rust matcher rather than the slower Lua fallback.
      implementation = 'prefer_rust',
      frecency = {
        enabled = false,
      },
      prebuilt_binaries = {
        -- Force the downloader to use the stable v1 release line even if the
        -- checked out plugin revision is not itself on a release tag yet.
        download = true,
        force_version = 'v1.*',
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
