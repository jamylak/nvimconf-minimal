local M = {}
local bootstrap = require('nvimconf.bootstrap')
local late_setup_done = {}

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

local function late_setup(snacks, opts)
  if not snacks.did_setup then
    return
  end

  local names = {}
  local seen = {}

  local function add(name)
    if opts[name] ~= nil and not seen[name] then
      names[#names + 1] = name
      seen[name] = true
    end
  end

  -- Preserve known dependencies when enabling modules after setup.
  add('picker')
  add('explorer')

  for name in pairs(opts) do
    add(name)
  end

  for _, name in ipairs(names) do
    local config = snacks.config[name]
    if config and config.enabled and not late_setup_done[name] then
      local ok, mod = pcall(function()
        return snacks[name]
      end)
      if ok and type(mod) == 'table' and type(mod.setup) == 'function' then
        mod.setup()
        late_setup_done[name] = true
      end
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
    late_setup(snacks, opts)
  else
    snacks.setup(normalize_opts(opts))
  end

  return snacks
end

return M
