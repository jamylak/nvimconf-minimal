local M = {}

-- Shared picker-to-picker transition coordinator.
--
-- Every picker wrapper registers its cheap, idempotent close function here when
-- the module is loaded. A switch then follows one rule:
--
--   1. leave insert mode for the current prompt mapping,
--   2. close every known picker UI,
--   3. open the requested picker immediately.
--
-- The immediate open is deliberate. Do not replace it with vim.schedule unless
-- you also accept an extra event-loop tick before the next picker appears.
-- scripts/test_picker_switching.lua asserts this stays synchronous.
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
  -- Closing all registered pickers avoids needing to know which picker owns the
  -- current prompt buffer. Each close callback is expected to be a no-op when
  -- its picker is inactive.
  for _, name in ipairs(close_order) do
    pcall(close_by_name[name])
  end
end

function M.open(open_fn)
  vim.cmd.stopinsert()
  M.close_current()
  -- Keep switch latency on the hot path to the close work plus the target
  -- picker's own open work. The target picker is responsible for startinsert.
  open_fn()
end

return M
