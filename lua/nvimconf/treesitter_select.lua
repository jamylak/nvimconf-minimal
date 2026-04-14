local M = {}
local breadcrumbs_by_buf = {}
local selected_node_by_buf = {}
local missing_parser_notified = {}
local esc_key = vim.keycode('<Esc>')

local function node_key(node)
  if not node then
    return
  end
  local start_row, start_col, end_row, end_col = node:range()
  return table.concat({ node:type(), start_row, start_col, end_row, end_col }, ':')
end

local function buf_breadcrumbs(bufnr)
  local state = breadcrumbs_by_buf[bufnr]
  if not state then
    state = {}
    breadcrumbs_by_buf[bufnr] = state
  end
  return state
end

local function set_selected_node(bufnr, node)
  selected_node_by_buf[bufnr] = node
end

local function selected_node(bufnr)
  return selected_node_by_buf[bufnr]
end

local function parser_available(bufnr)
  return pcall(vim.treesitter.get_parser, bufnr)
end

local function notify_missing_parser(bufnr)
  if missing_parser_notified[bufnr] then
    return
  end
  missing_parser_notified[bufnr] = true

  local filetype = vim.bo[bufnr].filetype
  local label = filetype ~= '' and filetype or 'current buffer'
  vim.schedule(function()
    vim.notify('Treesitter node select is unavailable: no parser for ' .. label, vim.log.levels.WARN)
  end)
end

local function maybe_start(bufnr)
  if not parser_available(bufnr) then
    notify_missing_parser(bufnr)
    return false
  end

  local ok = pcall(vim.treesitter.start, bufnr)
  if not ok then
    notify_missing_parser(bufnr)
    return false
  end

  return true
end

local function node_at_pos(bufnr, row, col)
  local ok, node = pcall(vim.treesitter.get_node, {
    bufnr = bufnr,
    pos = { row, col },
    ignore_injections = false,
  })
  if ok then
    return node
  end
end

local function node_at_cursor(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  return node_at_pos(bufnr, cursor[1] - 1, cursor[2])
end

local function node_range(node)
  local start_row, start_col, end_row, end_col = node:range()
  if end_col > 0 then
    end_col = end_col - 1
  elseif end_row > start_row then
    end_row = end_row - 1
    local line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1] or ''
    end_col = math.max(#line - 1, 0)
  end
  return start_row, start_col, end_row, end_col
end

local function in_visual_mode()
  local mode = vim.fn.mode()
  return mode == 'v' or mode == 'V' or mode == '\22'
end

local function set_visual_selection_from_normal(bufnr, node)
  local start_row, start_col, end_row, end_col = node_range(node)

  vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
  vim.cmd.normal({ args = { 'v' }, bang = true })
  vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col })

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if end_row + 1 > line_count then
    vim.api.nvim_win_set_cursor(0, { line_count, 0 })
  end
end

local function set_visual_selection_from_visual(bufnr, node)
  local start_row, start_col, end_row, end_col = node_range(node)

  vim.cmd.normal({ args = { esc_key }, bang = true })
  vim.api.nvim_buf_set_mark(bufnr, '<', start_row + 1, start_col, {})
  vim.api.nvim_buf_set_mark(bufnr, '>', end_row + 1, end_col, {})
  vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col })
  vim.cmd.normal({ args = { 'gv' }, bang = true })
end

local function set_visual_selection(bufnr, node)
  if in_visual_mode() then
    set_visual_selection_from_visual(bufnr, node)
  else
    set_visual_selection_from_normal(bufnr, node)
  end
end

local function visual_bounds(bufnr)
  local start
  local finish

  if in_visual_mode() then
    start = vim.fn.getpos('v')
    finish = vim.fn.getcurpos()
  else
    local start_mark = vim.api.nvim_buf_get_mark(bufnr, '<')
    local finish_mark = vim.api.nvim_buf_get_mark(bufnr, '>')
    start = { 0, start_mark[1], start_mark[2] + 1, 0 }
    finish = { 0, finish_mark[1], finish_mark[2] + 1, 0 }
  end

  local start_row = math.max(start[2] - 1, 0)
  local start_col = math.max(start[3] - 1, 0)
  local end_row = math.max(finish[2] - 1, 0)
  local end_col = math.max(finish[3] - 1, 0)

  if end_row < start_row or (end_row == start_row and end_col < start_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  return start_row, start_col, end_row, end_col
end

local function smallest_common_ancestor(a, b)
  local ancestors = {}
  while a do
    ancestors[a:id()] = a
    a = a:parent()
  end

  while b do
    local match = ancestors[b:id()]
    if match then
      return match
    end
    b = b:parent()
  end
end

local function visual_node(bufnr)
  local start_row, start_col, end_row, end_col = visual_bounds(bufnr)
  local first = node_at_pos(bufnr, start_row, start_col)
  local last = node_at_pos(bufnr, end_row, end_col)

  if not first then
    return
  end
  if not last or first:id() == last:id() then
    return first
  end

  return smallest_common_ancestor(first, last) or first
end

local function normalized_node(node)
  while node do
    local parent = node:parent()
    if not parent or parent:named_child_count() ~= 1 then
      return node
    end
    node = parent
  end
end

local function first_interesting_child(node)
  while node do
    local count = node:named_child_count()
    if count >= 2 then
      return node:named_child(0)
    end
    if count == 0 then
      return
    end
    node = node:named_child(0)
  end
end

local function remember_path(bufnr, node)
  local child = node
  local parent = child and child:parent() or nil
  local breadcrumbs = buf_breadcrumbs(bufnr)

  while parent and child do
    breadcrumbs[node_key(parent)] = node_key(child)
    child = parent
    parent = parent:parent()
  end
end

local function remembered_child(bufnr, parent)
  local child_key = buf_breadcrumbs(bufnr)[node_key(parent)]
  if not child_key then
    return
  end

  for index = 0, parent:named_child_count() - 1 do
    local child = parent:named_child(index)
    if child and node_key(child) == child_key then
      return child
    end
  end
end

local function current_node()
  local bufnr = vim.api.nvim_get_current_buf()
  if not maybe_start(bufnr) then
    return
  end
  return normalized_node(node_at_cursor(bufnr))
end

local function current_visual_node()
  local bufnr = vim.api.nvim_get_current_buf()
  if not maybe_start(bufnr) then
    return
  end
  local selected = selected_node(bufnr)
  if selected then
    return selected
  end
  return normalized_node(visual_node(bufnr))
end

local function select_node(node)
  if not node then
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  remember_path(bufnr, node)
  set_selected_node(bufnr, node)
  set_visual_selection(bufnr, node)
end

local function move_visual_selection(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local node = current_visual_node()
  if not node then
    return
  end

  local target
  if direction == 'parent' then
    target = node:parent()
    if target then
      buf_breadcrumbs(bufnr)[node_key(target)] = node_key(node)
    end
  elseif direction == 'child' then
    target = remembered_child(bufnr, node) or first_interesting_child(node)
  elseif direction == 'next' then
    target = node:next_named_sibling()
  elseif direction == 'prev' then
    target = node:prev_named_sibling()
  end

  select_node(target)
end

function M.select_current_node()
  select_node(current_node())
end

function M.select_parent_node()
  local node = current_node()
  if not node then
    return
  end

  local parent = node:parent() or node
  if parent and parent ~= node then
    buf_breadcrumbs(vim.api.nvim_get_current_buf())[node_key(parent)] = node_key(node)
  end
  select_node(parent)
end

function M.select_parent_visual()
  move_visual_selection('parent')
end

function M.select_child_visual()
  move_visual_selection('child')
end

function M.select_next_sibling()
  move_visual_selection('next')
end

function M.select_prev_sibling()
  move_visual_selection('prev')
end

vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'BufLeave' }, {
  group = vim.api.nvim_create_augroup('nvimconf-minimal.treesitter_select', { clear = true }),
  callback = function(args)
    selected_node_by_buf[args.buf] = nil
    missing_parser_notified[args.buf] = nil
  end,
})

return M
