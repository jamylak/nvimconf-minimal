local M = {}

local function call(module_name, method)
  local ok, module = pcall(require, module_name)
  if ok and type(module[method]) == 'function' then
    pcall(module[method])
  end
end

function M.close_current()
  call('nvimconf.fff', 'close')
  call('nvimconf.project_picker', 'close')
  call('nvimconf.oldfiles_picker', 'close')
  call('nvimconf.penguin', 'close')
end

function M.open(open_fn)
  vim.cmd.stopinsert()
  M.close_current()
  vim.schedule(open_fn)
end

return M
