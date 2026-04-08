local M = {}

function M.setup()
  if vim.fn.has("nvim-0.12") == 0 then
    return
  end

  local ok, ui2 = pcall(require, "vim._core.ui2")
  if not ok then
    return
  end

  ui2.enable({
    enable = true,
    msg = {
      targets = "cmd",
      msg = {
        height = 0.25,
        timeout = 4000,
      },
      dialog = {
        height = 0.4,
      },
      pager = {
        height = 0.5,
      },
    },
  })
end

return M
