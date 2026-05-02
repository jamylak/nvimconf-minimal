local M = {}

local close_order = {}
local close_by_name = {}

function M.register(name, close_fn)
  if type(name) ~= 'string' or type(close_fn) ~= 'function' then
    return
  end

  if not close_by_name[name] then
    close_order[#close_order + 1] = name
  end

  close_by_name[name] = close_fn
end

function M.close_current()
  for _, name in ipairs(close_order) do
    pcall(close_by_name[name])
  end
end

function M.open(open_fn)
  vim.cmd.stopinsert()
  M.close_current()
  open_fn()
end

return M
