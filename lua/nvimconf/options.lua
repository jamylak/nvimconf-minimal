local opt = vim.opt
local is_nvim_012 = vim.fn.has("nvim-0.12") == 1

opt.ignorecase = true
opt.smartcase = true
opt.number = true
opt.mouse = ""
opt.swapfile = false
opt.backup = false
opt.writebackup = false
opt.updatetime = 200
opt.timeoutlen = 300
opt.splitbelow = true
opt.splitright = true
opt.cursorline = true
opt.signcolumn = "yes"

-- ui2 in 0.12 makes cmdheight=0 viable enough to hide the bottom bar
-- without falling back to the old press-enter message flow.
if is_nvim_012 then
  opt.laststatus = 0
  opt.cmdheight = 0
  opt.showmode = false
  opt.showcmd = false
  opt.ruler = false
  opt.shortmess:append("sSWcCq")
end

vim.opt.shadafile = "NONE"
