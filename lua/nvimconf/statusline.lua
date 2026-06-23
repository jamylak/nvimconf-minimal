local M = {}

local mode_names = {
  n = "NORMAL",
  no = "OP",
  nov = "OP",
  noV = "OP",
  ["no\22"] = "OP",
  niI = "NORMAL",
  niR = "NORMAL",
  niV = "NORMAL",
  nt = "NORMAL",
  v = "VISUAL",
  V = "V-LINE",
  ["\22"] = "V-BLOCK",
  s = "SELECT",
  S = "S-LINE",
  ["\19"] = "S-BLOCK",
  i = "INSERT",
  ic = "INSERT",
  ix = "INSERT",
  R = "REPLACE",
  Rc = "REPLACE",
  Rx = "REPLACE",
  Rv = "V-REPLACE",
  Rvc = "V-REPLACE",
  Rvx = "V-REPLACE",
  c = "COMMAND",
  cv = "EX",
  ce = "EX",
  r = "PROMPT",
  rm = "MORE",
  ["r?"] = "CONFIRM",
  ["!"] = "SHELL",
  t = "TERMINAL",
}

local diagnostic_severities = {
  { vim.diagnostic.severity.ERROR, "E", "NvimconfStatusDiagnosticError" },
  { vim.diagnostic.severity.WARN, "W", "NvimconfStatusDiagnosticWarn" },
  { vim.diagnostic.severity.INFO, "I", "NvimconfStatusDiagnosticInfo" },
  { vim.diagnostic.severity.HINT, "H", "NvimconfStatusDiagnosticHint" },
}

local diagnostic_cache = {}
local file_meta_cache = {}

local excluded_filetypes = {
  fff_file_info = true,
  fff_input = true,
  fff_list = true,
  fff_preview = true,
}

local mode_highlights = {
  n = "NvimconfStatusModeNormal",
  no = "NvimconfStatusModeNormal",
  nov = "NvimconfStatusModeNormal",
  noV = "NvimconfStatusModeNormal",
  ["no\22"] = "NvimconfStatusModeNormal",
  niI = "NvimconfStatusModeNormal",
  niR = "NvimconfStatusModeNormal",
  niV = "NvimconfStatusModeNormal",
  nt = "NvimconfStatusModeNormal",
  v = "NvimconfStatusModeVisual",
  V = "NvimconfStatusModeVisual",
  ["\22"] = "NvimconfStatusModeVisual",
  s = "NvimconfStatusModeVisual",
  S = "NvimconfStatusModeVisual",
  ["\19"] = "NvimconfStatusModeVisual",
  i = "NvimconfStatusModeInsert",
  ic = "NvimconfStatusModeInsert",
  ix = "NvimconfStatusModeInsert",
  R = "NvimconfStatusModeReplace",
  Rc = "NvimconfStatusModeReplace",
  Rx = "NvimconfStatusModeReplace",
  Rv = "NvimconfStatusModeReplace",
  Rvc = "NvimconfStatusModeReplace",
  Rvx = "NvimconfStatusModeReplace",
  c = "NvimconfStatusModeCommand",
  cv = "NvimconfStatusModeCommand",
  ce = "NvimconfStatusModeCommand",
  r = "NvimconfStatusModeCommand",
  rm = "NvimconfStatusModeCommand",
  ["r?"] = "NvimconfStatusModeCommand",
  ["!"] = "NvimconfStatusModeCommand",
  t = "NvimconfStatusModeTerminal",
}

local filetype_icons = {
  c = "",
  cpp = "",
  css = "",
  fish = "",
  go = "",
  html = "",
  javascript = "",
  json = "",
  lua = "",
  make = "",
  markdown = "",
  nix = "",
  python = "",
  rust = "",
  sh = "",
  swift = "",
  toml = "",
  typescript = "",
  vim = "",
  yaml = "",
  zsh = "",
}

local extension_icons = {
  h = "",
  hpp = "",
  lock = "",
  md = "",
  txt = "",
}

local function escape(value)
  return tostring(value):gsub("%%", "%%%%")
end

local function hl(group)
  return "%#" .. group .. "#"
end

local function segment(group, value)
  if value == nil or value == "" then
    return ""
  end
  return hl(group) .. " " .. escape(value) .. " "
end

local function format_size(bytes)
  if type(bytes) ~= "number" then
    return ""
  end

  if bytes < 1024 then
    return tostring(bytes) .. "B"
  end
  if bytes < 1024 * 1024 then
    return string.format("%.1fK", bytes / 1024)
  end
  if bytes < 1024 * 1024 * 1024 then
    return string.format("%.1fM", bytes / 1024 / 1024)
  end
  return string.format("%.1fG", bytes / 1024 / 1024 / 1024)
end

local function mode()
  return mode_names[vim.api.nvim_get_mode().mode] or "?"
end

local function mode_hl()
  return mode_highlights[vim.api.nvim_get_mode().mode] or "NvimconfStatusModeNormal"
end

local function statusline_win()
  local winid = tonumber(vim.g.statusline_winid) or vim.api.nvim_get_current_win()
  if vim.api.nvim_win_is_valid(winid) then
    return winid
  end
  return vim.api.nvim_get_current_win()
end

local function statusline_buf(winid)
  return vim.api.nvim_win_get_buf(winid)
end

local function is_transient_window(winid, bufnr)
  if vim.api.nvim_win_get_config(winid).relative ~= "" then
    return true
  end

  local buftype = vim.bo[bufnr].buftype
  if buftype ~= "" and buftype ~= "terminal" then
    return true
  end

  local filetype = vim.bo[bufnr].filetype
  return excluded_filetypes[filetype] or filetype:match("^fff_") ~= nil
end

local function git_status(bufnr)
  local dict = vim.b[bufnr].gitsigns_status_dict
  if type(dict) ~= "table" then
    return ""
  end

  local parts = {}
  if dict.head and dict.head ~= "" then
    parts[#parts + 1] = " " .. dict.head
  end
  if (dict.added or 0) > 0 then
    parts[#parts + 1] = " " .. dict.added
  end
  if (dict.changed or 0) > 0 then
    parts[#parts + 1] = " " .. dict.changed
  end
  if (dict.removed or 0) > 0 then
    parts[#parts + 1] = " " .. dict.removed
  end

  return table.concat(parts, " ")
end

local function diagnostics(bufnr)
  local counts = diagnostic_cache[bufnr]
  if not counts then
    return ""
  end
  local parts = {}
  for _, item in ipairs(diagnostic_severities) do
    local count = counts[item[1]] or 0
    if count > 0 then
      parts[#parts + 1] = segment(item[3], item[2] .. count)
    end
  end

  return table.concat(parts)
end

local function file_label(bufnr)
  local meta = file_meta_cache[bufnr]
  if not meta then
    return ""
  end

  local parts = {}
  if meta.icon ~= "" then
    parts[#parts + 1] = meta.icon
  end
  if meta.type ~= "" then
    parts[#parts + 1] = meta.type
  end
  if meta.size ~= "" then
    parts[#parts + 1] = meta.size
  end

  return table.concat(parts, " ")
end

local function file_info(bufnr)
  local parts = {}
  if vim.bo[bufnr].fileencoding ~= "" then
    parts[#parts + 1] = vim.bo[bufnr].fileencoding
  elseif vim.o.encoding ~= "" then
    parts[#parts + 1] = vim.o.encoding
  end
  if vim.bo[bufnr].fileformat ~= "" then
    parts[#parts + 1] = vim.bo[bufnr].fileformat
  end
  return table.concat(parts, " ")
end

function M.active()
  local winid = statusline_win()
  local bufnr = statusline_buf(winid)
  if is_transient_window(winid, bufnr) then
    return "%#StatusLineNC#"
  end

  local git = git_status(bufnr)
  local diag = diagnostics(bufnr)
  local file = "%#NvimconfStatusFile# %f%m%r "
  local label = file_label(bufnr)
  local info = file_info(bufnr)

  local left = {
    segment(mode_hl(), mode()),
    segment("NvimconfStatusGit", git),
    diag,
    file,
  }

  local right = {
    segment("NvimconfStatusFiletype", label),
    segment("NvimconfStatusInfo", info),
    hl("NvimconfStatusPosition") .. " %3p%%  %l:%c ",
  }

  return table.concat(left) .. hl("StatusLine") .. "%=" .. table.concat(right)
end

function M.inactive()
  return "%#StatusLineNC# %f%m%r%= %3p%%  %l:%c "
end

local function refresh_diagnostics(bufnr)
  if not vim.diagnostic or not vim.diagnostic.count then
    diagnostic_cache[bufnr] = nil
    return
  end
  diagnostic_cache[bufnr] = vim.diagnostic.count(bufnr)
end

local function refresh_file_meta(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype
  local ext = name:match("%.([^.\\/]+)$") or ""
  local icon = filetype_icons[filetype] or extension_icons[ext] or ""
  local stat = name ~= "" and vim.uv.fs_stat(name) or nil

  file_meta_cache[bufnr] = {
    icon = icon,
    size = stat and stat.type == "file" and format_size(stat.size) or "",
    type = filetype ~= "" and filetype or (ext ~= "" and ext or "file"),
  }
end

local function suppress_transient_statusline(bufnr)
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_set_option_value("statusline", " ", { win = winid })
      vim.api.nvim_set_option_value("winbar", "", { win = winid })
    end
  end
end

local function set_highlights()
  local colors = {
    bg = "#16181a",
    bg_alt = "#1e2124",
    fg = "#ffffff",
    muted = "#7b8496",
    blue = "#5ea1ff",
    green = "#5eff6c",
    cyan = "#5ef1ff",
    red = "#ff6e5e",
    yellow = "#f1ff5e",
    magenta = "#ff5ef1",
    orange = "#ffbd5e",
    purple = "#bd5eff",
    black = "#000000",
  }

  local groups = {
    StatusLine = { fg = colors.fg, bg = colors.bg_alt },
    StatusLineNC = { fg = colors.muted, bg = colors.bg },
    NvimconfStatusModeNormal = { fg = colors.black, bg = colors.blue, bold = true },
    NvimconfStatusModeInsert = { fg = colors.black, bg = colors.green, bold = true },
    NvimconfStatusModeVisual = { fg = colors.black, bg = colors.magenta, bold = true },
    NvimconfStatusModeReplace = { fg = colors.black, bg = colors.red, bold = true },
    NvimconfStatusModeCommand = { fg = colors.black, bg = colors.orange, bold = true },
    NvimconfStatusModeTerminal = { fg = colors.black, bg = colors.purple, bold = true },
    NvimconfStatusGit = { fg = colors.cyan, bg = colors.bg_alt, bold = true },
    NvimconfStatusDiagnosticError = { fg = colors.red, bg = colors.bg_alt, bold = true },
    NvimconfStatusDiagnosticWarn = { fg = colors.yellow, bg = colors.bg_alt, bold = true },
    NvimconfStatusDiagnosticInfo = { fg = colors.blue, bg = colors.bg_alt, bold = true },
    NvimconfStatusDiagnosticHint = { fg = colors.cyan, bg = colors.bg_alt, bold = true },
    NvimconfStatusFile = { fg = colors.fg, bg = colors.bg_alt, bold = true },
    NvimconfStatusFiletype = { fg = colors.magenta, bg = colors.bg_alt, bold = true },
    NvimconfStatusInfo = { fg = colors.fg, bg = colors.bg_alt },
    NvimconfStatusPosition = { fg = colors.black, bg = colors.cyan, bold = true },
  }

  for group, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

function M.setup()
  _G.nvimconf_statusline_active = M.active
  _G.nvimconf_statusline_inactive = M.inactive
  set_highlights()

  vim.o.statusline = "%!v:lua.nvimconf_statusline_active()"
  vim.o.laststatus = 3

  local group = vim.api.nvim_create_augroup("nvimconf-minimal.statusline", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = set_highlights,
    desc = "Refresh statusline highlights",
  })

  vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufEnter" }, {
    group = group,
    callback = function(args)
      refresh_diagnostics(args.buf)
      if is_transient_window(statusline_win(), args.buf) then
        suppress_transient_statusline(args.buf)
      end
    end,
    desc = "Refresh cached statusline diagnostics",
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "BufFilePost", "FileType" }, {
    group = group,
    callback = function(args)
      refresh_file_meta(args.buf)
    end,
    desc = "Refresh cached statusline file metadata",
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "fff_*",
    callback = function(args)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(args.buf) then
          suppress_transient_statusline(args.buf)
        end
      end)
    end,
    desc = "Keep custom statusline out of fff picker windows",
  })

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      refresh_diagnostics(bufnr)
      refresh_file_meta(bufnr)
    end
  end

end

return M
