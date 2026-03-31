local M = {}

M.favorite_languages = {
  "lua",
  "vim",
  "vimdoc",
  "query",
  "markdown",
  "markdown_inline",
  "bash",
  "fish",
  "c",
  "cpp",
  "python",
  "rust",
  "go",
  "json",
  "yaml",
  "toml",
  "glsl",
}

local install_started = false
local notified_missing_tools = false

local function has_tool(bin)
  return bin and bin ~= "" and vim.fn.executable(bin) == 1
end

local function has_compiler()
  local candidates = { "cc", "clang", "gcc", "zig" }
  if has_tool(vim.env.CC) then
    return true
  end
  for _, candidate in ipairs(candidates) do
    if has_tool(candidate) then
      return true
    end
  end
  return false
end

local function prerequisites_ok()
  local missing = {}

  if not has_tool("curl") then
    missing[#missing + 1] = "curl"
  end
  if not has_tool("tar") then
    missing[#missing + 1] = "tar"
  end
  if not has_compiler() then
    missing[#missing + 1] = "C compiler"
  end

  if #missing == 0 then
    return true
  end

  if not notified_missing_tools then
    notified_missing_tools = true
    vim.schedule(function()
      vim.notify(
        "Treesitter parser install unavailable. Missing: " .. table.concat(missing, ", "),
        vim.log.levels.WARN
      )
    end)
  end

  return false
end

local function parser_installed(lang)
  return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", true) > 0
end

local function load_nvim_treesitter()
  local ok = pcall(vim.cmd, "packadd nvim-treesitter")
  if not ok then
    vim.schedule(function()
      vim.notify("nvim-treesitter is missing. Run: git submodule update --init --recursive", vim.log.levels.ERROR)
    end)
    return nil
  end

  local ok_require, ts = pcall(require, "nvim-treesitter")
  if not ok_require then
    vim.schedule(function()
      vim.notify("Failed to load nvim-treesitter", vim.log.levels.ERROR)
    end)
    return nil
  end

  return ts
end

local function available_favorites(ts)
  local available = {}
  for _, lang in ipairs(ts.get_available() or {}) do
    available[lang] = true
  end

  local filtered = {}
  for _, lang in ipairs(M.favorite_languages) do
    if available[lang] then
      filtered[#filtered + 1] = lang
    end
  end

  return filtered
end

local function missing_languages(ts)
  local missing = {}
  for _, lang in ipairs(available_favorites(ts)) do
    if not parser_installed(lang) then
      missing[#missing + 1] = lang
    end
  end
  return missing
end

local function notify_start(action, languages)
  vim.schedule(function()
    vim.notify(
      string.format("Treesitter %s started: %s", action, table.concat(languages, ", ")),
      vim.log.levels.INFO
    )
  end)
end

function M.install_favorites()
  if not prerequisites_ok() then
    return false
  end

  local ts = load_nvim_treesitter()
  if not ts then
    return false
  end

  local missing = missing_languages(ts)
  if #missing == 0 then
    vim.notify("Treesitter favorites already installed", vim.log.levels.INFO)
    return true
  end

  notify_start("install", missing)
  ts.install(missing, { summary = true })
  return true
end

function M.update_favorites()
  if not prerequisites_ok() then
    return false
  end

  local ts = load_nvim_treesitter()
  if not ts then
    return false
  end

  local languages = available_favorites(ts)
  if #languages == 0 then
    vim.notify("No favorite Treesitter parsers available", vim.log.levels.WARN)
    return false
  end

  notify_start("update", languages)
  ts.update(languages, { summary = true })
  return true
end

function M.ensure_favorites()
  if install_started or not prerequisites_ok() then
    return false
  end

  local ts = load_nvim_treesitter()
  if not ts then
    return false
  end

  local missing = missing_languages(ts)
  if #missing == 0 then
    return true
  end

  install_started = true
  notify_start("install", missing)
  ts.install(missing, { summary = true })
  return true
end

return M
