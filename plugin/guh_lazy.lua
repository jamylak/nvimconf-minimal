vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("nvimconf-minimal.guh", { clear = true }),
  once = true,
  callback = function()
    vim.schedule(function()
      require("nvimconf.guh").setup()
    end)
  end,
  desc = "Install guh.nvim command stubs after startup",
})
