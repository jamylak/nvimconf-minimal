local M = {}
local bootstrap = require('nvimconf.bootstrap')

local function normalize_opts(opts)
  opts = opts or {}

  for _, value in pairs(opts) do
    if type(value) == 'table' and value.enabled == nil then
      value.enabled = true
    end
  end

  return opts
end

local function apply_after_setup(snacks, opts)
  opts = normalize_opts(opts)

  for key, value in pairs(opts) do
    local current = snacks.config[key]
    if type(current) == 'table' and type(value) == 'table' then
      snacks.config[key] = snacks.config.merge(current, value)
    else
      snacks.config[key] = value
    end
  end
end

function M.ensure(opts)
  local snacks = bootstrap.require_plugin('snacks', 'snacks.nvim')
  if not snacks then
    return nil
  end

  if snacks.did_setup then
    apply_after_setup(snacks, opts)
  else
    snacks.setup(normalize_opts(opts))
  end

  return snacks
end

return M
