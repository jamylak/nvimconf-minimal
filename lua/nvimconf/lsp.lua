local M = {}

local lsp_filetypes = {
  'zig',
  'zir',
  'python',
  'c',
  'cpp',
  'objc',
  'objcpp',
  'cuda',
  'go',
  'gomod',
  'gowork',
  'gotmpl',
  'lua',
  'asm',
  'nasm',
  'masm',
  'gas',
  's',
  'vmasm',
  'fish',
  'xml',
  'xsd',
  'xsl',
  'xslt',
  'svg',
  'yaml',
  'yaml.docker-compose',
  'yaml.gitlab',
  'yaml.helm-values',
  'json',
  'jsonc',
  'html',
  'toml',
  'javascript',
  'javascriptreact',
  'typescript',
  'typescriptreact',
  'terraform',
  'hcl',
  'tf',
  'tfvars',
  'nix',
  'glsl',
  'vert',
  'frag',
  'geom',
  'comp',
  'tesc',
  'tese',
}

local function runtime()
  return require('nvimconf.lsp_runtime')
end

function M.setup()
  local group = vim.api.nvim_create_augroup('nvimconf-minimal-lsp-start', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = lsp_filetypes,
    callback = function(args)
      runtime().maybe_start(args.buf)
    end,
  })

  vim.api.nvim_create_user_command('LspStart', function()
    runtime().start_current_buf()
  end, { desc = 'Start LSP for current buffer' })

  vim.api.nvim_create_user_command('LspRestart', function()
    runtime().restart_current_buf()
  end, { desc = 'Restart LSP for current buffer' })

  vim.api.nvim_create_user_command('LspCheck', function()
    runtime().check_binaries()
  end, { desc = 'Check configured LSP binaries' })
end

return M
