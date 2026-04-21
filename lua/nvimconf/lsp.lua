local M = {}
local setup_done = false
local activation_done = false
local activation_scheduled = false

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

local function resolve_root(bufnr, markers)
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

local function root_dir(cmd, markers)
  return function(bufnr, on_dir)
    if vim.fn.executable(cmd[1]) ~= 1 then
      return
    end

    on_dir(resolve_root(bufnr, markers))
  end
end

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

local function nixd_settings()
  local formatter = pick_nix_formatter()
  if not formatter then
    return nil
  end

  return {
    nixd = {
      formatting = {
        command = formatter,
      },
    },
  }
end

local servers = {
  {
    name = 'zls',
    cmd = { 'zls' },
    filetypes = { 'zig', 'zir' },
    root_markers = { 'zls.json', 'build.zig', '.git' },
  },
  {
    name = 'ty',
    cmd = { 'ty', 'server' },
    filetypes = { 'python' },
    root_markers = { 'ty.toml', 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.git' },
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
  },
  {
    name = 'gopls',
    cmd = { 'gopls' },
    filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
    root_markers = { 'go.work', 'go.mod', '.git' },
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
  },
  {
    name = 'asm_lsp',
    cmd = { 'asm-lsp' },
    filetypes = { 'asm', 'nasm', 'masm', 'gas', 's', 'vmasm' },
    root_markers = { '.asm-lsp.toml', '.git' },
  },
  {
    name = 'fish_lsp',
    cmd = { 'fish-lsp', 'start' },
    filetypes = { 'fish' },
    root_markers = { 'config.fish', '.git' },
  },
  {
    name = 'lemminx',
    cmd = { 'lemminx' },
    filetypes = { 'xml', 'xsd', 'xsl', 'xslt', 'svg' },
    root_markers = { '.git' },
  },
  {
    name = 'yamlls',
    cmd = { 'yaml-language-server', '--stdio' },
    filetypes = { 'yaml', 'yaml.docker-compose', 'yaml.gitlab', 'yaml.helm-values' },
    root_markers = { '.git' },
  },
  {
    name = 'jsonls',
    cmd = { 'vscode-json-language-server', '--stdio' },
    filetypes = { 'json', 'jsonc' },
    root_markers = { '.git' },
  },
  {
    name = 'html',
    cmd = { 'vscode-html-language-server', '--stdio' },
    filetypes = { 'html' },
    root_markers = { '.git' },
  },
  {
    name = 'taplo',
    cmd = { 'taplo', 'lsp', 'stdio' },
    filetypes = { 'toml' },
    root_markers = { 'taplo.toml', '.git' },
  },
  {
    name = 'tsserver',
    cmd = { 'typescript-language-server', '--stdio' },
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    root_markers = { 'package.json', 'tsconfig.json', 'jsconfig.json', '.git' },
  },
  {
    name = 'terraformls',
    cmd = { 'terraform-ls', 'serve' },
    filetypes = { 'terraform', 'hcl', 'tf', 'tfvars' },
    root_markers = { '.terraform', '.git' },
  },
  {
    name = 'nixd',
    cmd = { 'nixd' },
    filetypes = { 'nix' },
    root_markers = { 'flake.nix', 'default.nix', 'shell.nix', '.git' },
    settings = nixd_settings,
  },
  {
    name = 'glsl-lsp',
    cmd = { 'glslls' },
    filetypes = { 'glsl', 'vert', 'frag', 'geom', 'comp', 'tesc', 'tese' },
    root_markers = { '.git' },
  },
}

local function prompt_workspace_symbols()
  local query = vim.fn.input('Workspace symbols: ', vim.fn.expand('<cword>'))
  if query == nil or query == '' then
    return
  end

  vim.lsp.buf.workspace_symbol(query)
end

local function setup_lsp_keymaps()
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('nvimconf-minimal-lsp-attach', { clear = true }),
    callback = function(event)
      local map = function(lhs, rhs, desc)
        vim.keymap.set('n', lhs, rhs, { buffer = event.buf, desc = 'LSP: ' .. desc })
      end

      map('gd', vim.lsp.buf.definition, 'Goto definition')
      map('gr', vim.lsp.buf.references, 'Goto references')
      map('gI', vim.lsp.buf.implementation, 'Goto implementation')
      map('gD', vim.lsp.buf.declaration, 'Goto declaration')
      map('<leader>D', vim.lsp.buf.type_definition, 'Type definition')
      map('<leader>d', vim.lsp.buf.document_symbol, 'Document symbols')
      map('<leader>ss', prompt_workspace_symbols, 'Workspace symbols')
      map('<leader>sd', prompt_workspace_symbols, 'Workspace symbols')
      map('K', vim.lsp.buf.hover, 'Hover')
      map('<leader>rn', vim.lsp.buf.rename, 'Rename')
      map('<leader>lr', vim.lsp.buf.rename, 'Rename')
      map('<leader>ca', vim.lsp.buf.code_action, 'Code action')
    end,
  })
end

local function config_names_for_filetype(filetype)
  local names = {}

  for _, server in ipairs(servers) do
    if vim.tbl_contains(server.filetypes, filetype) then
      names[#names + 1] = server.name
    end
  end

  return names
end

local function activate_native_lsp()
  if activation_done then
    return
  end

  vim.lsp.config('*', {
    capabilities = build_capabilities(),
  })

  local enabled = {}

  for _, server in ipairs(servers) do
    vim.lsp.config(server.name, {
      cmd = server.cmd,
      filetypes = server.filetypes,
      root_dir = root_dir(server.cmd, server.root_markers),
      settings = type(server.settings) == 'function' and server.settings() or server.settings,
    })
    enabled[#enabled + 1] = server.name
  end

  vim.lsp.enable(enabled)
  activation_done = true
end

local function schedule_lsp_activation()
  if activation_scheduled then
    return
  end

  activation_scheduled = true
  vim.api.nvim_create_autocmd('VimEnter', {
    group = vim.api.nvim_create_augroup('nvimconf-minimal-lsp-enable', { clear = true }),
    once = true,
    callback = function()
      -- Push native LSP activation until after startup work so the editor is responsive first.
      vim.schedule(activate_native_lsp)
    end,
  })
end

local function setup_commands()
  vim.api.nvim_create_user_command('LspStart', function()
    activate_native_lsp()

    local filetype = vim.bo.filetype
    local names = config_names_for_filetype(filetype)

    if filetype == '' or vim.tbl_isempty(names) then
      vim.notify('No configured LSP for filetype: ' .. (filetype == '' and '<none>' or filetype), vim.log.levels.WARN)
      return
    end

    vim.lsp.enable(names)
  end, { desc = 'Start LSP for current buffer' })

  vim.api.nvim_create_user_command('LspRestart', function()
    vim.cmd('lsp restart')
  end, { desc = 'Restart LSP for current buffer' })

  vim.api.nvim_create_user_command('LspCheck', function()
    vim.cmd('checkhealth vim.lsp')
  end, { desc = 'Check configured LSP binaries' })
end

function M.setup()
  if setup_done then
    return
  end
  setup_lsp_keymaps()
  setup_commands()
  schedule_lsp_activation()
  setup_done = true
end

return M
