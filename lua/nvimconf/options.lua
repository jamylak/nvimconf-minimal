local opt = vim.opt

opt.ignorecase = true
opt.smartcase = true
opt.number = true
opt.swapfile = false
opt.updatetime = 200
opt.timeoutlen = 300
opt.splitbelow = true
opt.splitright = true
opt.cursorline = true
opt.signcolumn = "yes"

-- ui2 makes cmdheight=0 viable enough to hide the command area without
-- falling back to the old press-enter message flow.
opt.cmdheight = 0
