local M = {}

local image_opts = {
  image = {
    doc = {
      inline = true,
      float = true,
    },
  },
}

local function filetype_supported(buf)
  local ft = vim.bo[buf].filetype
  return ft == 'markdown' or ft == 'norg'
end

local function attach(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not filetype_supported(buf) then
    return
  end

  local snacks = require('nvimconf.snacks').ensure(image_opts)
  if not snacks then
    return
  end

  local image = require('snacks.image')
  image.setup()
  image.doc.attach(buf)
end

function M.setup()
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('nvimconf.markdown_images', { clear = true }),
    pattern = { 'markdown', 'norg' },
    callback = function(args)
      -- Let filetype plugins, Treesitter, and the first markdown render settle first.
      vim.schedule(function()
        attach(args.buf)
      end)
    end,
    desc = 'Attach Snacks image rendering after markdown buffers load',
  })
end

M.attach_buffer = attach

return M
