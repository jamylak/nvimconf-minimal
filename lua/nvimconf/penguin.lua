local M = {}
local bootstrap = require('nvimconf.bootstrap')

local loaded = false

local function ensure_prompt_insert()
  vim.schedule(function()
    if vim.bo.filetype == 'penguin-prompt' then
      vim.cmd.startinsert()
    end
  end)
end

local function open_penguin()
  if not M.setup() then
    return false
  end

  require('penguin').open()
  ensure_prompt_insert()
  return true
end

function M.setup()
  if loaded then
    return true
  end

  local ok, penguin = pcall(require, 'penguin')
  if not ok then
    vim.schedule(function()
      local stat = vim.uv.fs_stat(bootstrap.penguin_dir)
      local message

      if not stat or stat.type ~= 'directory' then
        message = string.format(
          'penguin.nvim is unavailable. Expected local checkout at %s.',
          bootstrap.penguin_dir
        )
      else
        message = string.format('Failed to load penguin.nvim from %s: %s', bootstrap.penguin_dir, penguin)
      end

      vim.notify(message, vim.log.levels.ERROR)
    end)
    return false
  end

  penguin.setup({
    open_on_bare_enter = true,
  })
  loaded = true
  return true
end

M.open = open_penguin

return M
