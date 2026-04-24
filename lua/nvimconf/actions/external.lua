local M = {}

local function current_file_path()
  return vim.fn.expand '%:p'
end

local function current_file_or_cwd()
  local path = current_file_path()
  if path ~= '' then
    return vim.fn.fnamemodify(path, ':p')
  end

  return vim.fn.getcwd()
end

local function run_fish(command)
  vim.fn.system({ 'fish', '-c', command })
end

local function read_chooser_file(path)
  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  local lines = vim.fn.readfile(path)
  local selected_path = lines[1]
  if selected_path == nil or selected_path == '' then
    return nil
  end

  return vim.fn.fnamemodify(selected_path, ':p')
end

local function delete_file_if_exists(path)
  if vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
  end
end

local function close_tab_if_valid(tabpage)
  if not (tabpage and vim.api.nvim_tabpage_is_valid(tabpage)) then
    return
  end

  local current_tabpage = vim.api.nvim_get_current_tabpage()
  if current_tabpage ~= tabpage then
    vim.api.nvim_set_current_tabpage(tabpage)
  end

  vim.cmd.tabclose()
end

local function git_root_for_path(path)
  local probe_path = vim.fn.isdirectory(path) == 1 and path or vim.fn.fnamemodify(path, ':h')
  local result = vim.fn.system({ 'git', '-C', probe_path, 'rev-parse', '--show-toplevel' })

  if vim.v.shell_error ~= 0 then
    return nil
  end

  local git_root = vim.trim(result)
  if git_root == '' then
    return nil
  end

  return git_root
end

local function edit_selection_in_tab(tabpage, selected_path)
  if not (tabpage and vim.api.nvim_tabpage_is_valid(tabpage)) then
    return
  end

  vim.api.nvim_set_current_tabpage(tabpage)
  vim.cmd.edit(vim.fn.fnameescape(selected_path))

  local git_root = git_root_for_path(selected_path)
  if git_root ~= nil then
    vim.cmd.tcd(vim.fn.fnameescape(git_root))
  end
end

local function open_yazi_chooser(target_tabpage, start_path)
  local chooser_file = vim.fn.tempname()

  vim.cmd.tabnew()
  local yazi_tabpage = vim.api.nvim_get_current_tabpage()
  local terminal_buffer = vim.api.nvim_get_current_buf()

  vim.bo[terminal_buffer].bufhidden = 'wipe'
  vim.fn.termopen({ 'yazi', start_path, '--chooser-file=' .. chooser_file }, {
    on_exit = function()
      local selected_path = read_chooser_file(chooser_file)
      delete_file_if_exists(chooser_file)

      vim.schedule(function()
        close_tab_if_valid(yazi_tabpage)

        if selected_path ~= nil then
          edit_selection_in_tab(target_tabpage, selected_path)
        end
      end)
    end,
  })

  vim.cmd.startinsert()
end

function M.yazi_hsplit_current_file()
  run_fish('yazi_hsplit ' .. current_file_path())
end

function M.yazi_vsplit_current_file()
  run_fish('yazi_vsplit ' .. current_file_path())
end

function M.yazi_current_file_new_tab()
  run_fish('yazi_new_tab ' .. current_file_path())
end

function M.yazi_here()
  open_yazi_chooser(vim.api.nvim_get_current_tabpage(), current_file_or_cwd())
end

function M.yazi_new_tab()
  local start_path = current_file_or_cwd()
  vim.cmd.tabnew()
  open_yazi_chooser(vim.api.nvim_get_current_tabpage(), start_path)
end

function M.open_current_file_in_helix()
  local filename = current_file_path()
  if filename == '' then
    vim.notify('No file path for current buffer', vim.log.levels.WARN)
    return
  end

  run_fish(string.format('hx_new_tab %q %d', filename, vim.fn.line '.'))
end

function M.execute_visual_selection_as_lua()
  local save_cursor = vim.api.nvim_win_get_cursor(0)
  local start_line = vim.fn.getpos("'<")[2]
  local end_line = vim.fn.getpos("'>")[2]
  if start_line == 0 or end_line == 0 then
    vim.notify('No visual selection to execute', vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local chunk, err = load(table.concat(lines, '\n'))
  if not chunk then
    vim.notify(err or 'Error in selected Lua code', vim.log.levels.ERROR)
  else
    pcall(chunk)
  end

  local line_count = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, {
    math.min(math.max(save_cursor[1], 1), line_count),
    math.max(save_cursor[2], 0),
  })
end

return M
