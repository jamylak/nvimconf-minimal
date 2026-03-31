local M = {}

local ns = vim.api.nvim_create_namespace('nvimconf2.project_picker')

local state = {
  active = false,
  prompt = 'Project> ',
  prompt_buf = nil,
  prompt_win = nil,
  list_buf = nil,
  list_win = nil,
  entries = {},
  filtered = {},
  selected = 1,
  query = '',
}

local function normalize(path)
  if not path or path == '' then
    return ''
  end
  return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ':p'))
end

local function project_roots()
  local roots = {}
  local seen = {}

  local function add(path)
    local normalized = normalize(path)
    if normalized == '' or seen[normalized] then
      return
    end
    seen[normalized] = true
    if vim.fn.isdirectory(normalized) == 1 then
      roots[#roots + 1] = normalized
    end
  end

  add(vim.env.PROJECTS_DIR or '')
  add '~/proj'

  return roots
end

local function primary_project_root()
  local env_root = normalize(vim.env.PROJECTS_DIR or '')
  if env_root ~= '' then
    return env_root
  end
  return normalize '~/proj'
end

local function current_buffer_has_name()
  return vim.api.nvim_buf_get_name(0) ~= ''
end

local function switch_to_project_tab(path)
  local target = normalize(path)
  local target_prefix = target .. '/'

  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local tabnr = vim.api.nvim_tabpage_get_number(tab)
    local ok_cwd, tab_cwd = pcall(vim.fn.getcwd, -1, tabnr)
    if ok_cwd and normalize(tab_cwd) == target then
      vim.api.nvim_set_current_tabpage(tab)
      return true
    end

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local buf = vim.api.nvim_win_get_buf(win)
      local name = normalize(vim.api.nvim_buf_get_name(buf))
      if name ~= '' and vim.startswith(name, target_prefix) then
        vim.api.nvim_set_current_tabpage(tab)
        return true
      end
    end
  end

  return false
end

local function project_entries()
  local items = {}

  local function add(path, name)
    local expanded = normalize(path)
    local stat = vim.uv.fs_stat(expanded)
    if not stat or stat.type ~= 'directory' then
      return
    end

    items[#items + 1] = {
      path = expanded,
      name = name or vim.fn.fnamemodify(expanded, ':t'),
      sort_time = stat.mtime and stat.mtime.sec or 0,
      ordinal = (name or vim.fn.fnamemodify(expanded, ':t')) .. ' ' .. expanded,
    }
  end

  add('/tmp', '/tmp')

  for _, root in ipairs(project_roots()) do
    local scandir = vim.uv.fs_scandir(root)
    if scandir then
      while true do
        local name, entry_type = vim.uv.fs_scandir_next(scandir)
        if not name then
          break
        end
        if entry_type == 'directory' and name:sub(1, 1) ~= '.' then
          add(root .. '/' .. name, name)
        end
      end
    end
  end

  table.sort(items, function(a, b)
    if a.sort_time == b.sort_time then
      return a.path < b.path
    end
    return a.sort_time > b.sort_time
  end)

  return items
end

local function filter_entries(query)
  if query == '' then
    return vim.deepcopy(state.entries)
  end

  local lookup = {}
  local values = {}
  for _, entry in ipairs(state.entries) do
    lookup[entry.ordinal] = entry
    values[#values + 1] = entry.ordinal
  end

  local ok, matched = pcall(vim.fn.matchfuzzy, values, query)
  if not ok then
    matched = {}
    local lower_query = query:lower()
    for _, entry in ipairs(state.entries) do
      if entry.ordinal:lower():find(lower_query, 1, true) then
        matched[#matched + 1] = entry.ordinal
      end
    end
  end

  local filtered = {}
  for _, ordinal in ipairs(matched) do
    filtered[#filtered + 1] = lookup[ordinal]
  end
  return filtered
end

local function read_query()
  if not state.prompt_buf or not vim.api.nvim_buf_is_valid(state.prompt_buf) then
    return ''
  end

  local line = vim.api.nvim_buf_get_lines(state.prompt_buf, 0, 1, false)[1] or ''
  if vim.startswith(line, state.prompt) then
    return line:sub(#state.prompt + 1)
  end
  return line
end

local function set_prompt_text(text)
  if not state.prompt_buf or not vim.api.nvim_buf_is_valid(state.prompt_buf) then
    return
  end

  vim.api.nvim_buf_set_lines(state.prompt_buf, 0, -1, false, { text })

  if state.prompt_win and vim.api.nvim_win_is_valid(state.prompt_win) then
    vim.api.nvim_win_set_cursor(state.prompt_win, { 1, #text })
  end
end

local function render()
  if not state.list_buf or not vim.api.nvim_buf_is_valid(state.list_buf) then
    return
  end

  state.filtered = filter_entries(state.query)
  if #state.filtered == 0 then
    state.selected = 0
  elseif state.selected < 1 then
    state.selected = 1
  elseif state.selected > #state.filtered then
    state.selected = #state.filtered
  end

  local lines = {}
  if #state.filtered == 0 then
    lines[1] = '  No matching projects'
  else
    for index, entry in ipairs(state.filtered) do
      local prefix = index == state.selected and '> ' or '  '
      if entry.name == entry.path then
        lines[index] = prefix .. entry.path
      else
        lines[index] = prefix .. entry.name .. '  ' .. entry.path
      end
    end
  end

  vim.bo[state.list_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.list_buf, 0, -1, false, lines)
  vim.bo[state.list_buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(state.list_buf, ns, 0, -1)

  if #state.filtered == 0 then
    vim.api.nvim_buf_add_highlight(state.list_buf, ns, 'Comment', 0, 0, -1)
    return
  end

  for index, entry in ipairs(state.filtered) do
    local line_index = index - 1
    if index == state.selected then
      vim.api.nvim_buf_add_highlight(state.list_buf, ns, 'Visual', line_index, 0, -1)
    end

    local start_col = 2
    if entry.name == entry.path then
      vim.api.nvim_buf_add_highlight(state.list_buf, ns, 'Directory', line_index, start_col, -1)
    else
      vim.api.nvim_buf_add_highlight(state.list_buf, ns, 'Directory', line_index, start_col, start_col + #entry.name)
      vim.api.nvim_buf_add_highlight(state.list_buf, ns, 'Comment', line_index, start_col + #entry.name + 2, -1)
    end
  end
end

local function close()
  if not state.active then
    return
  end

  state.active = false

  local prompt_win = state.prompt_win
  local list_win = state.list_win
  local prompt_buf = state.prompt_buf
  local list_buf = state.list_buf

  state.prompt_buf = nil
  state.prompt_win = nil
  state.list_buf = nil
  state.list_win = nil
  state.entries = {}
  state.filtered = {}
  state.selected = 1
  state.query = ''

  if prompt_win and vim.api.nvim_win_is_valid(prompt_win) then
    vim.api.nvim_win_close(prompt_win, true)
  end
  if list_win and vim.api.nvim_win_is_valid(list_win) then
    vim.api.nvim_win_close(list_win, true)
  end
  if prompt_buf and vim.api.nvim_buf_is_valid(prompt_buf) then
    vim.api.nvim_buf_delete(prompt_buf, { force = true })
  end
  if list_buf and vim.api.nvim_buf_is_valid(list_buf) then
    vim.api.nvim_buf_delete(list_buf, { force = true })
  end
end

local function move_selection(delta)
  if #state.filtered == 0 then
    return
  end

  state.selected = state.selected + delta
  if state.selected < 1 then
    state.selected = #state.filtered
  elseif state.selected > #state.filtered then
    state.selected = 1
  end
  render()
end

local function open_project(path, reuse_existing)
  local project_path = normalize(path)
  if project_path == '' then
    return
  end

  if reuse_existing and switch_to_project_tab(project_path) then
    vim.cmd.tcd(vim.fn.fnameescape(project_path))
    require('nvimconf2.fff').find_files_in_dir(project_path)
    return
  end

  if current_buffer_has_name() then
    vim.cmd.tabnew()
  end

  vim.cmd.tcd(vim.fn.fnameescape(project_path))
  require('nvimconf2.fff').find_files_in_dir(project_path)
end

local function select_current(reuse_existing)
  local entry = state.filtered[state.selected]
  if not entry then
    return
  end

  close()
  open_project(entry.path, reuse_existing)
end

local function create_project()
  local query = vim.trim(state.query)
  if query == '' then
    return
  end

  local path = normalize(primary_project_root() .. '/' .. query)
  vim.fn.mkdir(path, 'p')
  close()
  open_project(path, false)
end

local function use_selected_name()
  local entry = state.filtered[state.selected]
  if not entry or entry.name == '/tmp' then
    return
  end

  state.query = entry.name
  set_prompt_text(state.query)
  render()
end

local function update_query()
  state.query = read_query()
  state.selected = 1
  render()
end

local function create_window(buf, opts)
  local win = vim.api.nvim_open_win(buf, opts.enter, {
    relative = 'editor',
    style = 'minimal',
    border = 'rounded',
    title = opts.title,
    title_pos = 'center',
    width = opts.width,
    height = opts.height,
    row = opts.row,
    col = opts.col,
  })

  vim.wo[win].winblend = 0
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  return win
end

function M.open()
  if state.active then
    if state.prompt_win and vim.api.nvim_win_is_valid(state.prompt_win) then
      vim.api.nvim_set_current_win(state.prompt_win)
      vim.cmd.startinsert()
    end
    return
  end

  state.entries = project_entries()
  state.filtered = vim.deepcopy(state.entries)
  state.selected = #state.filtered > 0 and 1 or 0
  state.query = ''
  state.active = true

  local width = math.min(math.max(54, math.floor(vim.o.columns * 0.52)), 96)
  local max_list_height = math.max(4, vim.o.lines - 8)
  local list_height = math.min(math.max(#state.entries, 1), math.max(8, math.floor(vim.o.lines * 0.4)), max_list_height)
  local total_height = list_height + 5
  local row = math.max(1, math.floor((vim.o.lines - total_height) / 2) - 1)
  local col = math.floor((vim.o.columns - width) / 2)

  state.prompt_buf = vim.api.nvim_create_buf(false, true)
  state.list_buf = vim.api.nvim_create_buf(false, true)

  vim.bo[state.prompt_buf].buftype = 'prompt'
  vim.bo[state.prompt_buf].bufhidden = 'wipe'
  vim.bo[state.prompt_buf].filetype = 'nvimconf2_project_picker'
  vim.fn.prompt_setprompt(state.prompt_buf, state.prompt)

  vim.bo[state.list_buf].bufhidden = 'wipe'
  vim.bo[state.list_buf].filetype = 'nvimconf2_project_picker'
  vim.bo[state.list_buf].modifiable = false

  state.prompt_win = create_window(state.prompt_buf, {
    enter = true,
    title = 'Projects',
    width = width,
    height = 1,
    row = row,
    col = col,
  })

  state.list_win = create_window(state.list_buf, {
    enter = false,
    title = 'Enter: open  Ctrl-J: reuse tab  Shift-Enter: mkdir ~/proj/<name>',
    width = width,
    height = list_height,
    row = row + 3,
    col = col,
  })

  vim.wo[state.list_win].cursorline = false
  set_prompt_text('')
  render()

  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, {
      buffer = state.prompt_buf,
      silent = true,
      nowait = true,
      desc = desc,
    })
  end

  map({ 'i', 'n' }, '<Esc>', close, 'Close project picker')
  map({ 'i', 'n' }, '<C-c>', close, 'Close project picker')
  map('n', 'q', close, 'Close project picker')
  map({ 'i', 'n' }, '<Down>', function() move_selection(1) end, 'Next project')
  map({ 'i', 'n' }, '<C-n>', function() move_selection(1) end, 'Next project')
  map({ 'i', 'n' }, '<Tab>', function() move_selection(1) end, 'Next project')
  map({ 'i', 'n' }, '<Up>', function() move_selection(-1) end, 'Previous project')
  map({ 'i', 'n' }, '<C-p>', function() move_selection(-1) end, 'Previous project')
  map({ 'i', 'n' }, '<S-Tab>', function() move_selection(-1) end, 'Previous project')
  map({ 'i', 'n' }, '<CR>', function() select_current(false) end, 'Open project')
  map({ 'i', 'n' }, '<C-j>', function() select_current(true) end, 'Reuse existing project tab')
  map({ 'i', 'n' }, '<S-CR>', create_project, 'Create project')
  map({ 'i', 'n' }, '<C-e>', use_selected_name, 'Use selected project name')

  local group = vim.api.nvim_create_augroup('nvimconf2.project_picker.' .. state.prompt_buf, { clear = true })
  vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChanged' }, {
    group = group,
    buffer = state.prompt_buf,
    callback = update_query,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    pattern = tostring(state.prompt_win),
    callback = function()
      vim.schedule(close)
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    pattern = tostring(state.list_win),
    callback = function()
      vim.schedule(close)
    end,
  })

  vim.cmd.startinsert()
end

function M.close()
  close()
end

function M.project_entries_for_test()
  return project_entries()
end

return M
