-- A deliberately small, dependency-free version of the `iS`/`aS` text object.
-- It is required only after one of those mappings is used.
local M = {}

local function is_keyword(char)
  return vim.fn.match(char, [[\k]]) == 0
end

local function is_separator(char)
  return char == "_" or char == "-"
end

local function is_upper(char)
  return char:match("%u") ~= nil
end

local function is_lower_or_digit(char)
  return char:match("[%l%d]") ~= nil
end

local function cursor_char_index(line, byte_col)
  return vim.fn.strchars(vim.fn.strpart(line, 0, byte_col)) + 1
end

local function byte_column(line, char_index)
  return vim.fn.byteidx(line, char_index - 1)
end

local function range_at_cursor()
  local row, byte_col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local chars = vim.fn.split(line, [[\zs]])
  local cursor = cursor_char_index(line, byte_col)

  if #chars == 0 then
    return
  end

  -- Treat the separator immediately beside a segment as part of the same word
  -- for locating its segment. This makes `ciS` useful with the cursor on `_`.
  if is_separator(chars[cursor]) then
    if chars[cursor + 1] and is_keyword(chars[cursor + 1]) then
      cursor = cursor + 1
    elseif chars[cursor - 1] and is_keyword(chars[cursor - 1]) then
      cursor = cursor - 1
    else
      return
    end
  end
  if not is_keyword(chars[cursor]) then
    return
  end

  local first, last = cursor, cursor
  while first > 1 and (is_keyword(chars[first - 1]) or is_separator(chars[first - 1])) do
    first = first - 1
  end
  while last < #chars and (is_keyword(chars[last + 1]) or is_separator(chars[last + 1])) do
    last = last + 1
  end

  local starts = {}
  for i = first, last do
    local char = chars[i]
    if is_keyword(char) and (i == first or is_separator(chars[i - 1])) then
      starts[#starts + 1] = i
    elseif is_keyword(char) and is_upper(char) and is_lower_or_digit(chars[i - 1]) then
      starts[#starts + 1] = i
    elseif is_keyword(char) and is_upper(char) and is_upper(chars[i - 1]) and chars[i + 1] and chars[i + 1]:match("%l") then
      starts[#starts + 1] = i
    end
  end

  for index, start in ipairs(starts) do
    local finish = (starts[index + 1] or (last + 1)) - 1
    while finish >= start and is_separator(chars[finish]) do
      finish = finish - 1
    end
    if cursor >= start and cursor <= finish then
      return row, byte_column(line, start), byte_column(line, finish) + #chars[finish], first, last
    end
  end
end

function M.select(outer)
  local row, start_col, end_col, token_start, token_end = range_at_cursor()
  if not row then
    return
  end

  local line = vim.api.nvim_get_current_line()
  local chars = vim.fn.split(line, [[\zs]])
  local start_index = cursor_char_index(line, start_col)
  local end_index = cursor_char_index(line, end_col - 1)

  -- Match nvim-various-textobjs' useful convention: `aS` takes a following
  -- separator when possible, otherwise the preceding one.
  if outer then
    if end_index < token_end and is_separator(chars[end_index + 1]) then
      end_col = byte_column(line, end_index + 2)
    elseif start_index > token_start and is_separator(chars[start_index - 1]) then
      start_col = byte_column(line, start_index - 1)
    end
  end

  vim.api.nvim_win_set_cursor(0, { row, start_col })
  vim.cmd.normal({ vim.fn.mode() == "v" and "o" or "v", bang = true })
  vim.api.nvim_win_set_cursor(0, { row, end_col - 1 })
end

return M
