local M = {}

local capabilities
local setup_done = false

-- Mirror Blink's advertised completion capabilities without eagerly loading blink.cmp at startup.
local function build_capabilities()
  return vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), {
    textDocument = {
      completion = {
        completionItem = {
          snippetSupport = true,
          commitCharactersSupport = false,
          documentationFormat = { 'markdown', 'plaintext' },
          deprecatedSupport = true,
          preselectSupport = false,
          tagSupport = { valueSet = { 1 } },
          insertReplaceSupport = true,
          resolveSupport = {
            properties = { 'documentation', 'detail', 'additionalTextEdits', 'command', 'data' },
          },
          insertTextModeSupport = {
            valueSet = { 1 },
          },
          labelDetailsSupport = true,
        },
        completionList = {
          itemDefaults = { 'commitCharacters', 'editRange', 'insertTextFormat', 'insertTextMode', 'data' },
        },
        contextSupport = true,
        insertTextMode = 1,
      },
    },
  })
end

-- Use project markers when present, otherwise fall back to the current file's directory.
local function default_root(bufnr, markers)
  local root = vim.fs.root(bufnr, markers)
  if root then
    return root
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= '' then
    return vim.fn.fnamemodify(name, ':p:h')
  end

  return vim.fn.getcwd()
end

-- Pick a nix formatter only when one is available so nixd formatting does not lie.
local function pick_nix_formatter()
  local candidates = {
    { 'nixfmt' },
    { 'nixfmt-rfc-style' },
    { 'alejandra' },
  }

  for _, cmd in ipairs(candidates) do
    if vim.fn.executable(cmd[1]) == 1 then
      return cmd
    end
  end
end

-- Keep LSP-only keymaps buffer-local and avoid Telescope dependencies entirely.
local function setup_lsp_keymaps()
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('nvimconf2-lsp-attach', { clear = true }),
    callback = function(event)
      local map = function(lhs, rhs, desc)
        vim.keymap.set('n', lhs, rhs, { buffer = event.buf, desc = 'LSP: ' .. desc })
      end

      map('gd', vim.lsp.buf.definition, 'Goto definition')
      map('gr', vim.lsp.buf.references, 'Goto references')
      map('gI', vim.lsp.buf.implementation, 'Goto implementation')
      map('gD', vim.lsp.buf.declaration, 'Goto declaration')
      map('K', vim.lsp.buf.hover, 'Hover')
      map('<leader>rn', vim.lsp.buf.rename, 'Rename')
      map('<leader>ca', vim.lsp.buf.code_action, 'Code action')

      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client.server_capabilities.documentHighlightProvider then
        local group = vim.api.nvim_create_augroup('nvimconf2-lsp-highlight-' .. event.buf, { clear = true })

        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          group = group,
          buffer = event.buf,
          callback = vim.lsp.buf.document_highlight,
        })

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          group = group,
          buffer = event.buf,
          callback = vim.lsp.buf.clear_references,
        })
      end
    end,
  })
end

-- Hardcode the server list like your old config, but keep the runtime path lightweight.
local function servers()
  return {
    {
      name = 'zls',
      cmd = { 'zls' },
      filetypes = { 'zig', 'zir' },
      root_markers = { 'zls.json', 'build.zig', '.git' },
      install_hint = 'brew install zls',
    },
    {
      name = 'ty',
      cmd = { 'ty', 'server' },
      filetypes = { 'python' },
      root_markers = { 'ty.toml', 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.git' },
      install_hint = 'brew install ty',
    },
    {
      name = 'clangd',
      cmd = { 'clangd' },
      filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
      root_markers = {
        '.clangd',
        '.clang-tidy',
        '.clang-format',
        'compile_commands.json',
        'compile_flags.txt',
        'configure.ac',
        '.git',
      },
      install_hint = 'brew install llvm',
    },
    {
      name = 'gopls',
      cmd = { 'gopls' },
      filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
      root_markers = { 'go.work', 'go.mod', '.git' },
      install_hint = 'brew install gopls',
    },
    {
      name = 'lua_ls',
      cmd = { 'lua-language-server' },
      filetypes = { 'lua' },
      root_markers = {
        '.emmyrc.json',
        '.luarc.json',
        '.luarc.jsonc',
        '.luacheckrc',
        '.stylua.toml',
        'stylua.toml',
        'selene.toml',
        'selene.yml',
        '.git',
      },
      settings = {
        Lua = {
          completion = { callSnippet = 'Replace' },
        },
      },
      install_hint = 'brew install lua-language-server',
    },
    {
      name = 'asm_lsp',
      cmd = { 'asm-lsp' },
      filetypes = { 'asm', 'nasm', 'masm', 'gas', 's', 'vmasm' },
      root_markers = { '.asm-lsp.toml', '.git' },
      install_hint = 'brew install asm-lsp',
    },
    {
      name = 'fish_lsp',
      cmd = { 'fish-lsp', 'start' },
      filetypes = { 'fish' },
      root_markers = { 'config.fish', '.git' },
      install_hint = 'brew install fish-lsp',
    },
    {
      name = 'lemminx',
      cmd = { 'lemminx' },
      filetypes = { 'xml', 'xsd', 'xsl', 'xslt', 'svg' },
      root_markers = { '.git' },
      install_hint = 'brew install lemminx',
    },
    {
      name = 'yamlls',
      cmd = { 'yaml-language-server', '--stdio' },
      filetypes = { 'yaml', 'yaml.docker-compose', 'yaml.gitlab', 'yaml.helm-values' },
      root_markers = { '.git' },
      install_hint = 'npm i -g yaml-language-server',
    },
    {
      name = 'jsonls',
      cmd = { 'vscode-json-language-server', '--stdio' },
      filetypes = { 'json', 'jsonc' },
      root_markers = { '.git' },
      install_hint = 'npm i -g vscode-langservers-extracted',
    },
    {
      name = 'html',
      cmd = { 'vscode-html-language-server', '--stdio' },
      filetypes = { 'html' },
      root_markers = { '.git' },
      install_hint = 'npm i -g vscode-langservers-extracted',
    },
    {
      name = 'taplo',
      cmd = { 'taplo', 'lsp', 'stdio' },
      filetypes = { 'toml' },
      root_markers = { 'taplo.toml', '.git' },
      install_hint = 'brew install taplo',
    },
    {
      name = 'tsserver',
      cmd = { 'typescript-language-server', '--stdio' },
      filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
      root_markers = { 'package.json', 'tsconfig.json', 'jsconfig.json', '.git' },
      install_hint = 'npm i -g typescript typescript-language-server',
    },
    {
      name = 'terraformls',
      cmd = { 'terraform-ls', 'serve' },
      filetypes = { 'terraform', 'hcl', 'tf', 'tfvars' },
      root_markers = { '.terraform', '.git' },
      install_hint = 'brew install terraform-ls',
    },
    {
      name = 'nixd',
      cmd = { 'nixd' },
      filetypes = { 'nix' },
      root_markers = { 'flake.nix', 'default.nix', 'shell.nix', '.git' },
      install_hint = 'brew install nixd',
    },
    {
      name = 'glsl-lsp',
      cmd = { 'glslls' },
      filetypes = { 'glsl', 'vert', 'frag', 'geom', 'comp', 'tesc', 'tese' },
      root_markers = { '.git' },
      install_hint = 'cargo install glsl-lsp',
    },
  }
end

local function start_for_buf(bufnr)
  local ft = vim.bo[bufnr].filetype
  if ft == '' then
    return
  end

  for _, server in ipairs(servers()) do
    if vim.tbl_contains(server.filetypes, ft) then
      if vim.fn.executable(server.cmd[1]) ~= 1 then
        return
      end

      local settings = server.settings
      if server.name == 'nixd' then
        local nix_formatter = pick_nix_formatter()
        settings = nix_formatter and {
          nixd = {
            formatting = {
              command = nix_formatter,
            },
          },
        } or nil
      end

      vim.lsp.start({
        name = server.name,
        cmd = server.cmd,
        root_dir = default_root(bufnr, server.root_markers),
        settings = settings,
        capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {}),
      }, { bufnr = bufnr })
    end
  end
end

function M.setup()
  if setup_done then
    return
  end

  capabilities = build_capabilities()
  setup_lsp_keymaps()
  setup_done = true
end

function M.maybe_start(bufnr)
  M.setup()
  start_for_buf(bufnr)
end

function M.start_current_buf()
  M.maybe_start(vim.api.nvim_get_current_buf())
end

function M.restart_current_buf()
  M.setup()

  local bufnr = vim.api.nvim_get_current_buf()
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    client.stop()
  end
  vim.defer_fn(function()
    start_for_buf(bufnr)
  end, 100)
end

function M.check_binaries()
  local lines = { 'LSP binaries on PATH:' }

  for _, server in ipairs(servers()) do
    local ok = vim.fn.executable(server.cmd[1]) == 1
    local marker = ok and '✓' or '✗'
    local suffix = ok and '' or (' - ' .. server.install_hint)
    lines[#lines + 1] = string.format('%s %s (%s)%s', marker, server.name, server.cmd[1], suffix)
  end

  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO, { title = 'LspCheck', timeout = 6000 })
end

return M
