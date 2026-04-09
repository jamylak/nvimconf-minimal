local M = {}
local bootstrap = require('nvimconf.bootstrap')

local loaded = false

function M.setup()
  if loaded then
    return true
  end

  local ok, cplug = pcall(require, 'cplug')
  if not ok then
    vim.schedule(function()
      local stat = vim.uv.fs_stat(bootstrap.cplug_dir)
      local message

      if not stat or stat.type ~= 'directory' then
        message = string.format(
          'cplug.nvim is unavailable. Expected local checkout at %s.',
          bootstrap.cplug_dir
        )
      else
        message = string.format('Failed to load cplug.nvim from %s: %s', bootstrap.cplug_dir, cplug)
      end

      vim.notify(
        message,
        vim.log.levels.ERROR
      )
    end)
    return false
  end

  cplug.setup()
  loaded = true
  return true
end

return M
