local M = {}
local bootstrap = require('nvimconf.bootstrap')
local picker_switch = require('nvimconf.picker_switch')

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

local function close_penguin()
  local ok, penguin = pcall(require, 'penguin')
  if ok and type(penguin.close) == 'function' then
    penguin.close()
  end
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

  -- penguin.nvim owns its prompt UI, so add this config's picker switch keys
  -- when that prompt buffer appears. The actual transition still goes through
  -- picker_switch.open so penguin behaves like the in-repo pickers.
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'penguin-prompt',
    group = vim.api.nvim_create_augroup('nvimconf-minimal.penguin_picker_switch', { clear = true }),
    callback = function(args)
      local function map(lhs, open_fn, desc)
        vim.keymap.set({ 'i', 'n' }, lhs, function()
          picker_switch.open(open_fn)
        end, {
          buffer = args.buf,
          silent = true,
          nowait = true,
          desc = desc,
        })
      end

      map('<m-n>', function()
        require('nvimconf.project_picker').open()
      end, 'Switch project')
      map('<m-o>', function()
        require('nvimconf.oldfiles_picker').open()
      end, 'Oldfiles')
      map('<C-Return>', function()
        require('nvimconf.fff').find_files()
      end, 'Find files')
    end,
  })

  loaded = true
  return true
end

M.open = open_penguin
M.close = close_penguin
picker_switch.register('penguin', close_penguin)

return M
