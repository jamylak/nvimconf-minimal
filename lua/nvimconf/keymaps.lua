local map = vim.keymap.set
local bootstrap = require("nvimconf.bootstrap")

local function call(module_name, method)
	return function(...)
		return require(module_name)[method](...)
	end
end

local function map_each(mode, lhs_list, rhs, opts)
	for _, lhs in ipairs(lhs_list) do
		map(mode, lhs, rhs, opts)
	end
end

local function setup_terminal_keymaps()
	vim.api.nvim_create_autocmd("TermOpen", {
		pattern = "*",
		callback = function(args)
			local name = vim.api.nvim_buf_get_name(args.buf)
			if not name:match("yazi") and not name:match("lazygit") then
				vim.keymap.set("t", "jk", "<C-\\><C-n>", { buffer = args.buf, silent = true })
				vim.keymap.set("t", "ji", "<C-\\><C-n>", { buffer = args.buf, silent = true })
			end
		end,
	})
end

local function pick_window()
	require("nvimconf.window_picker").pick()
end

local function open_project_picker()
	require("nvimconf.project_picker").open()
end

local function open_oldfiles_picker()
	require("nvimconf.oldfiles_picker").open()
end

local function reopen_last_picker()
	require("nvimconf.picker_history").reopen()
end

local function open_penguin()
	require("nvimconf.penguin").open()
end

local function call_diagnostic(method)
	return function()
		return vim.diagnostic[method]()
	end
end

local function resize_split(direction, amount)
	amount = amount or 3

	return function()
		local current_winnr = vim.fn.winnr()
		local left_winnr = vim.fn.winnr("h")
		local right_winnr = vim.fn.winnr("l")
		local up_winnr = vim.fn.winnr("k")
		local down_winnr = vim.fn.winnr("j")

		if direction == "h" then
			if left_winnr ~= current_winnr then
				vim.fn.win_move_separator(vim.fn.win_getid(left_winnr), -amount)
			elseif right_winnr ~= current_winnr then
				vim.fn.win_move_separator(0, -amount)
			end
		elseif direction == "j" then
			if down_winnr ~= current_winnr then
				vim.fn.win_move_statusline(0, amount)
			elseif up_winnr ~= current_winnr then
				vim.fn.win_move_statusline(vim.fn.win_getid(up_winnr), amount)
			end
		elseif direction == "k" then
			if up_winnr ~= current_winnr then
				vim.fn.win_move_statusline(vim.fn.win_getid(up_winnr), -amount)
			elseif down_winnr ~= current_winnr then
				vim.fn.win_move_statusline(0, -amount)
			end
		elseif direction == "l" then
			if right_winnr ~= current_winnr then
				vim.fn.win_move_separator(0, amount)
			elseif left_winnr ~= current_winnr then
				vim.fn.win_move_separator(vim.fn.win_getid(left_winnr), amount)
			end
		end
	end
end

local function search_prompt()
	vim.fn.feedkeys(vim.api.nvim_replace_termcodes("/", true, true, true), "n")
end

local edit = function(method)
	return call("nvimconf.actions.edit", method)
end

local git = function(method)
	return call("nvimconf.actions.git", method)
end

local lazygit = function(method)
	return call("nvimconf.actions.lazygit", method)
end

local external = function(method)
	return call("nvimconf.actions.external", method)
end

local explorer = function(method)
	return call("nvimconf.actions.explorer", method)
end

local terminal = function(method)
	return call("nvimconf.actions.terminal", method)
end

local treesitter_select = function(method)
	return call("nvimconf.treesitter_select", method)
end

setup_terminal_keymaps()

-- Commands
map("n", "<leader>m", "<cmd>make<CR>", { silent = true, desc = "Run make" })
map("n", "<leader>q", "<cmd>q!<CR>", { silent = true, desc = "Quit" })
map_each("n", { "<leader><leader>q", "<leader>Q", "Q" }, "<cmd>qall!<CR>", {
	silent = true,
	desc = "Quit all",
})
map("n", "<leader>w", edit("write_current"), { silent = true, desc = "Write" })
map("n", "<leader>p", function()
	require("nvimconf.image_paste").paste_image()
end, { silent = true, desc = "Paste image from clipboard" })
map("n", "<leader>i", explorer("toggle"), { silent = true, desc = "Open file explorer" })
map("n", "<leader>od", "<CMD>Oil " .. os.getenv("HOME") .. "/.config/dotfiles<CR>", { desc = "[O]pen [D]otfiles" })
map("n", "<leader>j", "<CMD>Oil<CR>", { desc = "Oil" })
map("n", "<leader>ot", "<CMD>Oil /tmp<CR>", { desc = "[O]pen /[T]mp" })
map("n", "<leader>oc", "<CMD>Oil " .. vim.fn.stdpath("config") .. "<CR>", { desc = "[O]pen [N]eovim Config" })
map("n", "<leader>on", "<CMD>Oil " .. bootstrap.plugins_dir .. "<CR>", { desc = "[O]pen [N]eovim Plugins Folder" })
map("n", "<leader>op", "<CMD>Oil " .. os.getenv("HOME") .. "/proj<CR>", { desc = "[O]pen Projects" })
map("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
map("n", "<c-x><c-j>", "<CMD>Oil<CR>", { desc = "Open parent directory" })

-- Splits
map_each("n", { "\\", "<leader>K" }, "<cmd>split<CR>", { silent = true, desc = "Horizontal split" })
map_each("n", { "|", "<leader>k" }, "<cmd>vsplit<CR>", { silent = true, desc = "Vertical split" })
map("n", "<leader>\\", external("yazi_hsplit_current_file"), { silent = true, desc = "Yazi horizontal split" })
map("n", "<leader>|", external("yazi_vsplit_current_file"), { silent = true, desc = "Yazi vertical split" })
map("n", "<leader>I", external("yazi_current_file_new_tab"), { silent = true, desc = "Yazi new tab" })

-- Comments
map("n", "<C-c>", "gcc", { remap = true, silent = true, desc = "Toggle line comment" })
map_each("x", { "<leader>c", "<C-c>" }, "gc", { remap = true, silent = true, desc = "Toggle comment" })

-- Cwd and repo helpers
map_each("n", { "cd", "<leader>tc" }, git("change_dir_tab"), { desc = "Tab cwd to current file dir" })
map("n", "<leader>lc", git("change_dir_window"), { desc = "Window cwd to current file dir" })
map("n", "<leader>v", git("tcd_to_git_root"), { noremap = true, desc = "Tab cwd to git root" })
map("n", "<leader>V", git("cd_to_git_root"), { noremap = true, desc = "Cwd to git root" })
map("n", "gh", git("goto_next_hunk"), { desc = "Next git change" })
map("n", "<leader><leader>G", git("copy_github_url"), { desc = "Copy GitHub URL" })
map("n", "<leader><leader>g", git("launch_github_url"), { desc = "Open GitHub URL" })

-- External helpers
map("n", "<leader><leader>y", '<cmd>let @+ = expand("%:p")<CR>', {
	noremap = true,
	silent = true,
	desc = "Yank file path",
})
map_each("n", { "<leader>Y", "<leader>H", "<leader><leader>Y" }, external("open_current_file_in_helix"), {
	desc = "Open current file in helix",
})
map("v", "<leader><leader>r", external("execute_visual_selection_as_lua"), {
	noremap = true,
	desc = "Execute Lua selection",
})
map("n", "<leader><leader>s", "<cmd>source %<CR>", { noremap = true, desc = "Source current Lua file" })
map("n", "<A-y>", external("yazi_here"), { noremap = true, silent = true, desc = "Open yazi" })
map("n", "<C-y>", external("yazi_new_tab"), { noremap = true, silent = true, desc = "Open yazi in new tab" })
map("n", "<C-g>", lazygit("open"), { noremap = true, silent = true, desc = "Open lazygit" })
map("n", "<m-b>", lazygit("log_file"), { noremap = true, silent = true, desc = "Lazygit file log" })
map({ "n", "x" }, "<leader>S", function()
	require("nvimconf.grug_far").open()
end, { desc = "Grug search" })
map("n", "S", function()
	require("nvimconf.grug_far").open()
end, { desc = "Grug search" })
map({ "n", "x", "v" }, "<leader><leader>S", function()
	require("nvimconf.grug_far").open({ visualSelectionUsage = "operate-within-range" })
end, { desc = "Grug search within range" })

-- Windows and buffers
map("n", "gj", pick_window, { silent = true, desc = "Jump to window" })
map("i", "gj", function()
	vim.cmd.stopinsert()
	pick_window()
end, { silent = true, desc = "Jump to window" })
map("v", "gj", function()
	vim.cmd.normal({ args = { "<Esc>" }, bang = true })
	pick_window()
end, { silent = true, desc = "Jump to window" })
map("t", "gj", function()
	vim.cmd.stopinsert()
	pick_window()
end, { silent = true, desc = "Jump to window" })

map_each("n", { "<a-d>", "m" }, "<C-W><C-W>", { silent = true, desc = "Next window" })
map("n", "M", "<C-W>W", { silent = true, desc = "Previous window" })
map("n", "qw", "<C-W><C-O>", { silent = true, desc = "Only window" })
map("n", "<a-h>", resize_split("h"), { silent = true, desc = "Resize split left" })
map("n", "<a-j>", resize_split("j"), { silent = true, desc = "Resize split down" })
map("n", "<a-k>", resize_split("k"), { silent = true, desc = "Resize split up" })
map("n", "<a-l>", resize_split("l"), { silent = true, desc = "Resize split right" })
map("n", "<m-n>", open_project_picker, { silent = true, desc = "Switch project" })
map("n", "<m-o>", open_oldfiles_picker, { silent = true, desc = "Oldfiles" })
map("n", "<m-cr>", reopen_last_picker, { silent = true, desc = "Reopen last picker" })
map("n", "<m-space>", open_penguin, { silent = true, desc = "Command history" })
map("n", "<leader>bd", "<cmd>bd!<CR>", { silent = true, desc = "Delete buffer" })
map_each("n", { "sb", "sj" }, "<cmd>b#<CR>", { silent = true, desc = "Swap buffer" })
map("n", "sk", "<cmd>tabnext#<CR>", { silent = true, desc = "Swap tab" })
map("n", "qj", "<C-W>p", { silent = true, desc = "Previous window" })
map("n", "[b", "<cmd>bprev<CR>", { silent = true, desc = "Previous buffer" })
map("n", "]b", "<cmd>bnext<CR>", { silent = true, desc = "Next buffer" })

-- Tabs
map_each("n", { "[t", "<a-[>" }, "<cmd>tabprev<CR>", { silent = true, desc = "Previous tab" })
map_each("n", { "]t", "<a-]>", "gy" }, "<cmd>tabnext<CR>", { silent = true, desc = "Next tab" })
map("i", "<a-[>", "<esc><cmd>tabprev<CR>", { silent = true, desc = "Previous tab" })
map("i", "<a-]>", "<esc><cmd>tabnext<CR>", { silent = true, desc = "Next tab" })

local gk_tabs = {
	{ "gko", 1 },
	{ "gk<cr>", 2 },
	{ "gk ", 3 },
	{ "gkg", 4 },
	{ "gkk", 5 },
	{ "gkd", 6 },
	{ "gke", 7 },
}

for _, mode in ipairs({ "n", "i", "t" }) do
	local prefix = mode == "i" and "<Esc>" or mode == "t" and "<C-\\><C-n>" or ""
	for _, spec in ipairs(gk_tabs) do
		map(mode, spec[1], prefix .. ":tabn " .. spec[2] .. "<CR>", {})
	end
end

for i = 1, 8 do
	map("n", "<a-" .. i .. ">", ":tabn " .. i .. "<CR>", { silent = true, desc = "Go to tab " .. i })
	map("n", "<leader>t" .. i, ":tabn " .. i .. "<CR>", { silent = true, desc = "Go to tab " .. i })
end

map("n", "<a-0>", ":tabn 1<CR>", { silent = true, desc = "First tab" })
map("n", "<a-9>", ":tabn $<CR>", { silent = true, desc = "Last tab" })
map("n", "<a-w>", edit("close_tab_or_quit"), { silent = true, desc = "Close tab or quit" })
map("n", "<a-q>", "<cmd>q!<CR>", { silent = true, desc = "Quit" })
map("n", "<leader>tr", ":tabclose<CR>", { silent = true, desc = "Tab remove" })
map("n", "<leader>tl", ":tablast<CR>", { silent = true, desc = "Tab last" })
map("n", "<leader>tf", ":tabfirst<CR>", { silent = true, desc = "Tab first" })
map("n", "<leader>to", ":tabonly<CR>", { silent = true, desc = "Tab only" })
map("n", "<leader>tb", "<C-W>T", { silent = true, desc = "Window to tab" })
map("n", "<t", ":tabmove-1<CR>", { silent = true, desc = "Move tab left" })
map("n", ">t", ":tabmove+1<CR>", { silent = true, desc = "Move tab right" })
map("n", "<T", ":tabmove 0<CR>", { silent = true, desc = "Move tab far left" })
map("n", ">T", ":tabmove $<CR>", { silent = true, desc = "Move tab far right" })

-- Motions and edits
map_each("n", { "qk", "<C-e>" }, "$", { silent = true, desc = "End of line" })
map("v", "<C-e>", "$", { silent = true, desc = "End of line" })
map_each({ "n", "v" }, { "<C-a>" }, "0", { silent = true, desc = "Start of line" })
map_each({ "n", "v" }, { "ge" }, "G", { silent = true, desc = "Go to end of file" })
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { silent = true, desc = "Clear search highlight" })
map_each("n", { "<C-s>", "<C-f>" }, search_prompt, { silent = true, noremap = true, desc = "Search" })
map("n", "<C-b>", "?", { silent = true, noremap = true, desc = "Search backward" })

map("n", "[<Space>", "O<Esc>j", { silent = true, desc = "Line above" })
map("n", "]<Space>", "o<Esc>k", { silent = true, desc = "Line below" })
map("n", "<C-j>", "<cmd>m .+1<CR>==", { silent = true, desc = "Move line down" })
map("n", "<C-k>", "<cmd>m .-2<CR>==", { silent = true, desc = "Move line up" })
map_each("n", { "qp", "<C-p>" }, "yyp", { silent = true, desc = "Duplicate line" })
map("v", "q", "$h", { silent = true, desc = "End of line" })
map("x", "<C-j>", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move selection down" })
map("x", "<C-k>", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move selection up" })
map("x", "<C-p>", function()
	local cmd = vim.fn.mode() == "V" and "y'>vo<esc>pO<esc>j" or "y']o<esc>pO<esc>j"
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(cmd, true, true, true), "n", true)
end, { noremap = true, desc = "Duplicate selection" })
map_each("n", { "qd", "dq" }, "dd", { silent = true, desc = "Delete line" })
map("n", "qy", "yy", { silent = true, desc = "Yank line" })
map("n", "qm", "v$", { silent = true, desc = "Visual to EOL" })
map("n", "<C-;>", "g;", { silent = true, desc = "Previous change" })
map("n", "<C-,>", "g,", { silent = true, desc = "Next change" })
map("n", "qn", treesitter_select("select_current_node"), { silent = true, desc = "Treesitter select current node" })
map("n", "vn", treesitter_select("select_current_node"), { silent = true, nowait = true, desc = "Treesitter select current node" })
map("n", "qh", treesitter_select("select_parent_node"), { silent = true, desc = "Treesitter select parent node" })
map("n", "vx", treesitter_select("select_parent_node"), { silent = true, desc = "Treesitter select parent node" })

-- Insert mode
map_each("i", { "ji", "jk", "<C-Return>" }, "<Esc>", { silent = true, desc = "Escape insert mode" })

map("i", "<C-k>", edit("check_and_delete"), { expr = true, noremap = true, desc = "Delete right or join line" })
map("i", "<C-y>", "<C-r>+", { silent = true, desc = "Paste clipboard" })
map("i", "<a-m>", "<C-r>+", { silent = true, desc = "Paste clipboard" })
map_each({ "n", "v" }, { "<a-m>" }, '"+p', { silent = true, desc = "Paste clipboard" })
map("i", "<C-f>", "<Right>", { silent = true, desc = "Right" })
map("i", "<C-a>", "<Home>", { silent = true, desc = "Home" })
map("i", "<C-e>", "<End>", { silent = true, desc = "End" })
map("i", "<C-b>", "<Left>", { silent = true, desc = "Left" })
map("i", "<C-p>", "<Up>", { silent = true, desc = "Up" })
map("i", "<C-n>", "<Down>", { silent = true, desc = "Down" })
map("i", "<C-d>", "<Del>", { silent = true, desc = "Delete char" })
map("i", "<A-b>", "<C-o>b", { silent = true, desc = "Back word" })
map("i", "<A-f>", "<C-o>w", { silent = true, desc = "Forward word" })
map("i", "<A-d>", "<C-o>dw", { silent = true, desc = "Delete word" })
map("i", "<C-/>", "<C-o>u", { silent = true, desc = "Undo" })
map("i", "<C-S-/>", "<C-o><C-r>", { silent = true, desc = "Redo" })
map("i", "<C-v>", "<PageDown>", { silent = true, desc = "Page down" })
map("i", "<A-S-[>", "<C-o>{", { silent = true, desc = "Prev paragraph" })
map("i", "<A-S-]>", "<C-o>}", { silent = true, desc = "Next paragraph" })
map("i", "<A-S-,>", "<C-o>go", { silent = true, desc = "Insert new line below" })
map("i", "<A-S-.>", "<Esc>G$a", { silent = true, desc = "End of file insert" })
map("i", "<m-n>", function()
	vim.cmd.stopinsert()
	open_project_picker()
end, { silent = true, desc = "Switch project" })
map("i", "<m-o>", function()
	vim.cmd.stopinsert()
	open_oldfiles_picker()
end, { silent = true, desc = "Oldfiles" })
map("i", "<m-cr>", function()
	vim.cmd.stopinsert()
	reopen_last_picker()
end, { silent = true, desc = "Reopen last picker" })
map("i", "<m-space>", function()
	vim.cmd.stopinsert()
	open_penguin()
end, { silent = true, desc = "Command history" })

-- Terminal
map("t", "<Esc><Esc>", "<C-\\><C-n>", { silent = true, desc = "Escape terminal mode" })
map("t", "<m-n>", function()
	vim.cmd.stopinsert()
	open_project_picker()
end, { silent = true, desc = "Switch project" })
map("t", "<m-o>", function()
	vim.cmd.stopinsert()
	open_oldfiles_picker()
end, { silent = true, desc = "Oldfiles" })
map("t", "<m-cr>", function()
	vim.cmd.stopinsert()
	reopen_last_picker()
end, { silent = true, desc = "Reopen last picker" })
map("t", "<m-space>", function()
	vim.cmd.stopinsert()
	open_penguin()
end, { silent = true, desc = "Command history" })
map("n", "<leader>tn", ":tabnew<CR>", { silent = true, desc = "New tab" })
map("n", "<a-t>", ":split<CR><C-w>T", { silent = true, desc = "New tab" })
map("n", "<c-t>", ":tabnew<CR>", { silent = true, desc = "New tab" })
map("n", "<leader>te", terminal("open"), { desc = "Terminal" })
map("n", "<S-CR>", terminal("new_tab"), { desc = "Terminal new tab" })
map_each("n", { "<leader>tv", "<leader>tj" }, terminal("vertical"), { desc = "Terminal vertical" })
map("n", "<leader>th", terminal("horizontal"), { desc = "Terminal horizontal" })
map("n", "<leader>n", terminal("send_repeat"), { desc = "Send repeat to terminal" })

-- Diagnostics and quickfix
map("n", "[d", call_diagnostic("goto_prev"), { desc = "Previous diagnostic" })
map("n", "]d", call_diagnostic("goto_next"), { desc = "Next diagnostic" })
map("n", "<leader>e", call_diagnostic("open_float"), { desc = "Diagnostic float" })
map("n", "<leader><C-q>", call_diagnostic("setloclist"), { desc = "Diagnostic loclist" })
map("n", "]q", "<cmd>cnext<CR>", { silent = true, desc = "Next quickfix" })
map("n", "[q", "<cmd>cprev<CR>", { silent = true, desc = "Previous quickfix" })

-- Clipboard
map("v", "<S-y>", '"+y', { noremap = true, silent = true, desc = "Yank to clipboard" })
map("n", "<leader>y", 'ggVG"+y', { noremap = true, silent = true, desc = "Yank whole file" })
map("x", "J", treesitter_select("select_next_sibling"), { silent = true, desc = "Treesitter select next sibling" })
map("x", "K", treesitter_select("select_prev_sibling"), { silent = true, desc = "Treesitter select previous sibling" })
map("x", "H", treesitter_select("select_parent_visual"), { silent = true, desc = "Treesitter select parent" })
map("x", "L", treesitter_select("select_child_visual"), { silent = true, desc = "Treesitter select child" })

-- User commands
vim.api.nvim_create_user_command("WQ", function()
	vim.cmd("wq!")
end, { desc = "Write and quit" })
vim.api.nvim_create_user_command("Q", function()
	vim.cmd("qall!")
end, { desc = "Quit all" })

vim.api.nvim_create_user_command('LeftMargin', function()
  vim.cmd('vnew')
  vim.cmd('wincmd H')
  vim.cmd('vertical resize 30')
  vim.cmd('wincmd W')
end, { desc = 'Create an empty vertical split to the left of the current window' })

return {}
