-- Run with:
-- nvim --headless -u NONE -i NONE --cmd 'set rtp^=.' --cmd 'set noswapfile' -l scripts/test_subword_textobj.lua

local repo = vim.fn.getcwd()
package.path = repo .. '/lua/?.lua;' .. repo .. '/lua/?/init.lua;' .. package.path

local failures = {}

local function assert_equal(actual, expected, context)
  if actual ~= expected then
    error(('%s: expected %s, got %s'):format(context, vim.inspect(expected), vim.inspect(actual)), 0)
  end
end

local function set_buffer(text, cursor_col)
  vim.cmd('enew!')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { text })
  vim.api.nvim_win_set_cursor(0, { 1, cursor_col })
end

local function run(name, test)
  local ok, err = xpcall(test, debug.traceback)
  if not ok then
    failures[#failures + 1] = ('%s\n%s'):format(name, err)
  end
  if vim.fn.mode() ~= 'n' then
    vim.cmd('normal! <Esc>')
  end
end

local function expect_edit(keys, text, cursor_col, expected)
  set_buffer(text, cursor_col)
  vim.cmd('normal ' .. keys)
  assert_equal(vim.api.nvim_get_current_line(), expected, keys)
end

local function expect_yank(keys, text, cursor_col, expected)
  set_buffer(text, cursor_col)
  vim.fn.setreg('"', '')
  vim.cmd('normal ' .. keys)
  assert_equal(vim.fn.getreg('"'), expected, keys)
end

local function expect_visual(keys, text, cursor_col, expected)
  set_buffer(text, cursor_col)
  vim.cmd('normal ' .. keys)
  assert_equal(vim.fn.mode(), 'v', keys .. ' mode')
  assert_equal(vim.fn.getregion(vim.fn.getpos('.'), vim.fn.getpos('v'), { type = 'v' })[1], expected, keys .. ' selection')
end

-- Load the same mappings the config installs after VimEnter; do not map the
-- keys specially for this test.
require('nvimconf.keymaps')

-- `viS` and `vaS`: the exact user-facing Visual forms.
run('viS selects an inner camelCase segment', function()
  expect_visual('viS', 'someCamelCase', 4, 'Camel')
end)
run('vaS selects an outer snake_case segment', function()
  expect_visual('vaS', 'foo_bar_baz', 4, 'bar_')
end)

-- Inner and outer variants through the common operators. These also cover
-- camelCase and the trailing/leading separator behavior of `aS`.
run('ciS changes one camelCase segment', function()
  expect_edit('ciSX', 'someCamelCase', 4, 'someXCase')
end)
run('caS changes a snake_case segment and its trailing separator', function()
  expect_edit('caSX', 'foo_bar_baz', 4, 'foo_Xbaz')
end)
run('diS deletes one kebab-case segment', function()
  expect_edit('diS', 'foo-bar-baz', 4, 'foo--baz')
end)
run('daS deletes the final snake_case segment and its leading separator', function()
  expect_edit('daS', 'foo_bar_baz', 8, 'foo_bar')
end)
run('yiS yanks only the inner segment', function()
  expect_yank('yiS', 'foo_bar_baz', 4, 'bar')
end)
run('yaS yanks the outer segment and separator', function()
  expect_yank('yaS', 'foo_bar_baz', 4, 'bar_')
end)

if #failures > 0 then
  error(('subword text-object failures (%d):\n\n%s'):format(#failures, table.concat(failures, '\n\n')), 0)
end
