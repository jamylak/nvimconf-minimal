local M = {}

local function shellescape(path)
  return vim.fn.shellescape(path)
end

local function current_buffer_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' then
    return vim.uv.cwd() or vim.fn.getcwd()
  end
  return vim.fn.fnamemodify(name, ':h')
end

local function default_target_path()
  local source = vim.api.nvim_buf_get_name(0)
  local base = source ~= '' and vim.fn.fnamemodify(source, ':t:r') or 'pasted-image'
  local dir = vim.fs.joinpath(current_buffer_dir(), 'assets')
  local stamp = os.date('%Y%m%d-%H%M%S')
  return vim.fs.joinpath(dir, string.format('%s-%s.png', base, stamp))
end

local function ensure_png_extension(path)
  local ext = vim.fn.fnamemodify(path, ':e')
  if ext == '' then
    return path .. '.png'
  end
  return path
end

local function is_absolute_path(path)
  return path:match('^/') ~= nil or path:match('^%a:[/\\]') ~= nil
end

local function clipboard_png_command(target)
  if vim.fn.executable('pngpaste') == 1 then
    return string.format('pngpaste %s', shellescape(target))
  end

  if vim.fn.executable('wl-paste') == 1 then
    return string.format('wl-paste --type image/png > %s', shellescape(target))
  end

  if vim.fn.executable('xclip') == 1 then
    return string.format('xclip -selection clipboard -t image/png -o > %s', shellescape(target))
  end

  return nil
end

local function relative_from_buffer(path)
  local base = current_buffer_dir()
  local relative = vim.fs.relpath(base, path)
  if relative and relative ~= '' then
    return relative
  end
  return vim.fn.fnamemodify(path, ':.')
end

local function prompt_target_path()
  local input = vim.fn.input('Image path: ', 'assets/')
  input = vim.trim(input)
  if input == '' then
    return default_target_path()
  end

  local target = input
  if not is_absolute_path(target) then
    target = vim.fs.joinpath(current_buffer_dir(), target)
  end
  return ensure_png_extension(target)
end

local function markdown_link(path)
  local file_name = vim.fn.fnamemodify(path, ':t:r')
  return string.format('![%s](%s)', file_name, relative_from_buffer(path))
end

local function insert_reference(path)
  local line = markdown_link(path)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))

  if vim.api.nvim_get_mode().mode:sub(1, 1) == 'i' then
    vim.api.nvim_put({ line }, 'c', true, true)
    return
  end

  local current = vim.api.nvim_get_current_line()
  local prefix = current:sub(1, col)
  local suffix = current:sub(col + 1)
  vim.api.nvim_set_current_line(prefix .. line .. suffix)
  vim.api.nvim_win_set_cursor(0, { row, col + #line })
end

local function notify_missing_backend()
  vim.notify(
    'Image paste requires pngpaste, wl-paste, or xclip with image/png clipboard support.',
    vim.log.levels.ERROR
  )
end

function M.paste_image(opts, target)
  opts = opts or {}
  target = target or prompt_target_path()
  target = ensure_png_extension(target)

  local command = clipboard_png_command(target)
  if not command then
    notify_missing_backend()
    return false
  end

  local dir = vim.fn.fnamemodify(target, ':h')
  vim.fn.mkdir(dir, 'p')

  local result = vim.fn.system(command)
  if vim.v.shell_error ~= 0 then
    local message = vim.trim(result)
    if message == '' then
      message = 'clipboard did not contain a PNG image'
    end
    vim.notify('Image paste failed: ' .. message, vim.log.levels.ERROR)
    return false
  end

  if not opts.skip_insert then
    insert_reference(target)
  end

  vim.notify('Pasted image to ' .. relative_from_buffer(target), vim.log.levels.INFO)
  return true
end

return M
