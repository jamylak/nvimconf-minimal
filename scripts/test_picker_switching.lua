vim.pack = { add = function() end }

local repo = vim.fn.getcwd()
package.path = repo .. '/lua/?.lua;' .. repo .. '/lua/?/init.lua;' .. package.path

local picker_filetypes = {
  fff_input = true,
  ['nvimconf-minimal_project_picker'] = true,
  ['nvimconf-minimal_oldfiles_picker'] = true,
  ['penguin-prompt'] = true,
}

local function close_filetype(filetype)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == filetype then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == filetype then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

local function open_prompt(filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].buftype = 'prompt'
  vim.bo[buf].filetype = filetype
  vim.cmd.startinsert()
  return buf
end

local fff_picker_ui = {
  state = {
    active = false,
    input_buf = nil,
    mode = 'files',
    query = '',
    config = {
      base_path = repo,
      prompt = '',
    },
    filtered_items = {},
    cursor = 1,
  },
}

function fff_picker_ui.close()
  fff_picker_ui.state.active = false
  close_filetype('fff_input')
end

package.preload['fff.picker_ui'] = function()
  return fff_picker_ui
end

package.preload['fff.download'] = function()
  return {
    get_binary_path = function()
      return repo .. '/scripts/test_picker_switching.lua'
    end,
  }
end

package.preload['fff.conf'] = function()
  return {
    get = function()
      return { base_path = repo }
    end,
  }
end

package.preload['fff'] = function()
  return {
    change_indexing_directory = function()
      return true
    end,
    find_files = function()
      local buf = open_prompt('fff_input')
      fff_picker_ui.state.active = true
      fff_picker_ui.state.input_buf = buf
      fff_picker_ui.state.mode = 'files'
    end,
    live_grep = function()
      local buf = open_prompt('fff_input')
      fff_picker_ui.state.active = true
      fff_picker_ui.state.input_buf = buf
      fff_picker_ui.state.mode = 'grep'
    end,
  }
end

local penguin = {}

function penguin.setup() end

function penguin.open()
  open_prompt('penguin-prompt')
end

function penguin.close()
  close_filetype('penguin-prompt')
end

package.preload['penguin'] = function()
  return penguin
end

local function fail(message)
  error(message, 0)
end

local function assert_equal(actual, expected, context)
  if actual ~= expected then
    fail(('%s: expected %s, got %s'):format(context, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function wait_for_filetype(filetype)
  local ok = vim.wait(500, function()
    local fallback_win = nil
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == filetype then
        if vim.bo[buf].buftype == 'prompt' then
          vim.api.nvim_set_current_win(win)
          return true
        end
        fallback_win = fallback_win or win
      end
    end
    if fallback_win then
      vim.api.nvim_set_current_win(fallback_win)
      return true
    end
    return false
  end, 10)
  if not ok then
    fail(('timed out waiting for %s, current filetype is %s'):format(filetype, vim.bo.filetype))
  end
end

local function picker_buffers()
  local found = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local filetype = vim.bo[buf].filetype
      if picker_filetypes[filetype] then
        found[filetype] = true
      end
    end
  end
  local filetypes = {}
  for filetype in pairs(found) do
    filetypes[#filetypes + 1] = filetype
  end
  table.sort(filetypes)
  return filetypes
end

local function assert_only_picker(filetype, context)
  wait_for_filetype(filetype)
  local found = picker_buffers()
  assert_equal(#found, 1, context .. ' picker family count')
  assert_equal(found[1], filetype, context .. ' active picker')
end

local function current_mapping(lhs)
  local aliases = {
    ['<C-Return>'] = '<C-CR>',
  }
  local buf = vim.api.nvim_get_current_buf()
  for _, mode in ipairs({ 'i', 'n' }) do
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
      if mapping.lhs == lhs or mapping.lhs == aliases[lhs] then
        return mapping.callback
      end
    end
  end
  fail(('missing %s mapping for %s'):format(lhs, vim.bo[buf].filetype))
end

local function press(lhs)
  if not picker_filetypes[vim.bo.filetype] then
    local found = picker_buffers()
    if #found == 1 then
      wait_for_filetype(found[1])
    end
  end
  local callback = current_mapping(lhs)
  if type(callback) ~= 'function' then
    fail(('mapping %s has no callback'):format(lhs))
  end
  callback()
end

local function close_all()
  require('nvimconf.picker_switch').close_current()
  fff_picker_ui.close()
end

do
  local picker_switch = require('nvimconf.picker_switch')
  local original_schedule = vim.schedule
  local schedule_count = 0
  local opened = false

  vim.schedule = function(fn)
    schedule_count = schedule_count + 1
    return original_schedule(fn)
  end

  picker_switch.open(function()
    opened = true
  end)

  vim.schedule = original_schedule
  assert_equal(opened, true, 'picker_switch.open is synchronous')
  assert_equal(schedule_count, 0, 'picker_switch.open schedule count')
end

vim.v.oldfiles = { repo .. '/README.md' }

require('nvimconf.fff').setup()
require('nvimconf.penguin').setup()

local project = require('nvimconf.project_picker')
local oldfiles = require('nvimconf.oldfiles_picker')
local fff = require('nvimconf.fff')
local nvimconf_penguin = require('nvimconf.penguin')

local cases = {
  {
    name = 'penguin -> oldfiles -> penguin -> files',
    start_filetype = 'penguin-prompt',
    start = function()
      nvimconf_penguin.open()
    end,
    steps = {
      { '<M-o>', 'nvimconf-minimal_oldfiles_picker' },
      { '<M-Space>', 'penguin-prompt' },
      { '<C-Return>', 'fff_input' },
    },
  },
  {
    name = 'penguin -> oldfiles -> penguin -> projects',
    start_filetype = 'penguin-prompt',
    start = function()
      nvimconf_penguin.open()
    end,
    steps = {
      { '<M-o>', 'nvimconf-minimal_oldfiles_picker' },
      { '<M-Space>', 'penguin-prompt' },
      { '<M-n>', 'nvimconf-minimal_project_picker' },
    },
  },
  {
    name = 'oldfiles -> projects -> oldfiles -> penguin',
    start_filetype = 'nvimconf-minimal_oldfiles_picker',
    start = function()
      oldfiles.open()
    end,
    steps = {
      { '<M-n>', 'nvimconf-minimal_project_picker' },
      { '<M-o>', 'nvimconf-minimal_oldfiles_picker' },
      { '<M-Space>', 'penguin-prompt' },
    },
  },
  {
    name = 'fff -> oldfiles -> projects',
    start_filetype = 'fff_input',
    start = function()
      fff.find_files()
    end,
    steps = {
      { '<M-o>', 'nvimconf-minimal_oldfiles_picker' },
      { '<M-n>', 'nvimconf-minimal_project_picker' },
    },
  },
  {
    name = 'fff -> penguin -> oldfiles',
    start_filetype = 'fff_input',
    start = function()
      fff.find_files()
    end,
    steps = {
      { '<M-Space>', 'penguin-prompt' },
      { '<M-o>', 'nvimconf-minimal_oldfiles_picker' },
    },
  },
  {
    name = 'projects -> penguin -> oldfiles',
    start_filetype = 'nvimconf-minimal_project_picker',
    start = function()
      project.open()
    end,
    steps = {
      { '<M-Space>', 'penguin-prompt' },
      { '<M-o>', 'nvimconf-minimal_oldfiles_picker' },
    },
  },
  {
    name = 'oldfiles -> files',
    start_filetype = 'nvimconf-minimal_oldfiles_picker',
    start = function()
      oldfiles.open()
    end,
    steps = {
      { '<C-Return>', 'fff_input' },
    },
  },
  {
    name = 'projects -> files',
    start_filetype = 'nvimconf-minimal_project_picker',
    start = function()
      project.open()
    end,
    steps = {
      { '<C-Return>', 'fff_input' },
    },
  },
}

for _, case in ipairs(cases) do
  close_all()
  case.start()
  assert_only_picker(case.start_filetype, case.name .. ' start')

  for _, step in ipairs(case.steps) do
    press(step[1])
    assert_only_picker(step[2], case.name .. ' via ' .. step[1])
  end
end

close_all()
print('picker switching tests passed')
