local M = {}

local last_picker = nil

function M.set(opener)
  if type(opener) == 'function' then
    last_picker = opener
  end
end

function M.reopen()
  if not last_picker then
    vim.notify('No picker opened yet', vim.log.levels.INFO)
    return false
  end

  last_picker()
  return true
end

return M
