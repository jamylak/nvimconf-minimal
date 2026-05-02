local M = {}
local picker_history = require("nvimconf.picker_history")
local picker_switch = require("nvimconf.picker_switch")

local ns = vim.api.nvim_create_namespace("nvimconf-minimal.oldfiles_picker")

local state = {
	active = false,
	prompt = "Oldfiles> ",
	prompt_buf = nil,
	prompt_win = nil,
	list_buf = nil,
	list_win = nil,
	entries = {},
	filtered = {},
	selected = 1,
	query = "",
}

local function remember_open(query)
	local saved_query = query or ""
	picker_history.set(function()
		M.open(saved_query)
	end)
end

local function normalize(path)
	if not path or path == "" then
		return ""
	end
	return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
end

local function display_path(path)
	local home = normalize("~")
	if home ~= "" and vim.startswith(path, home .. "/") then
		return "~/" .. path:sub(#home + 2)
	end
	return path
end

local function oldfile_entries()
	local items = {}
	local seen = {}

	for _, path in ipairs(vim.v.oldfiles or {}) do
		local normalized = normalize(path)
		if normalized ~= "" and not seen[normalized] and vim.fn.filereadable(normalized) == 1 then
			seen[normalized] = true
			local label = display_path(normalized)
			items[#items + 1] = {
				path = normalized,
				label = label,
				name = vim.fn.fnamemodify(normalized, ":t"),
				ordinal = label .. " " .. normalized,
			}
		end
	end

	return items
end

local function filter_entries(query)
	if query == "" then
		return vim.deepcopy(state.entries)
	end

	local lookup = {}
	local values = {}
	for _, entry in ipairs(state.entries) do
		lookup[entry.ordinal] = entry
		values[#values + 1] = entry.ordinal
	end

	local ok, matched = pcall(vim.fn.matchfuzzy, values, query)
	if not ok then
		matched = {}
		local lower_query = query:lower()
		for _, entry in ipairs(state.entries) do
			if entry.ordinal:lower():find(lower_query, 1, true) then
				matched[#matched + 1] = entry.ordinal
			end
		end
	end

	local filtered = {}
	for _, ordinal in ipairs(matched) do
		filtered[#filtered + 1] = lookup[ordinal]
	end
	return filtered
end

local function read_query()
	if not state.prompt_buf or not vim.api.nvim_buf_is_valid(state.prompt_buf) then
		return ""
	end

	local line = vim.api.nvim_buf_get_lines(state.prompt_buf, 0, 1, false)[1] or ""
	if vim.startswith(line, state.prompt) then
		return line:sub(#state.prompt + 1)
	end
	return line
end

local function set_prompt_text(text)
	if not state.prompt_buf or not vim.api.nvim_buf_is_valid(state.prompt_buf) then
		return
	end

	vim.api.nvim_buf_set_lines(state.prompt_buf, 0, -1, false, { text })

	if state.prompt_win and vim.api.nvim_win_is_valid(state.prompt_win) then
		vim.api.nvim_win_set_cursor(state.prompt_win, { 1, #text })
	end
end

local function render()
	if not state.list_buf or not vim.api.nvim_buf_is_valid(state.list_buf) then
		return
	end

	state.filtered = filter_entries(state.query)
	if #state.filtered == 0 then
		state.selected = 0
	elseif state.selected < 1 then
		state.selected = 1
	elseif state.selected > #state.filtered then
		state.selected = #state.filtered
	end

	local lines = {}
	if #state.filtered == 0 then
		lines[1] = "  No matching oldfiles"
	else
		for index, entry in ipairs(state.filtered) do
			local prefix = index == state.selected and "> " or "  "
			lines[index] = prefix .. entry.label
		end
	end

	vim.bo[state.list_buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.list_buf, 0, -1, false, lines)
	vim.bo[state.list_buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(state.list_buf, ns, 0, -1)

	if #state.filtered == 0 then
		vim.api.nvim_buf_add_highlight(state.list_buf, ns, "Comment", 0, 0, -1)
		return
	end

	for index, entry in ipairs(state.filtered) do
		local line_index = index - 1
		if index == state.selected then
			vim.api.nvim_buf_add_highlight(state.list_buf, ns, "Visual", line_index, 0, -1)
		end

		local start_col = 2
		local name_start = entry.label:find(entry.name, 1, true)
		if name_start then
			vim.api.nvim_buf_add_highlight(
				state.list_buf,
				ns,
				"Directory",
				line_index,
				start_col,
				start_col + name_start - 1
			)
			vim.api.nvim_buf_add_highlight(
				state.list_buf,
				ns,
				"Normal",
				line_index,
				start_col + name_start - 1,
				start_col + name_start - 1 + #entry.name
			)
			vim.api.nvim_buf_add_highlight(
				state.list_buf,
				ns,
				"Comment",
				line_index,
				start_col + name_start - 1 + #entry.name,
				-1
			)
		else
			vim.api.nvim_buf_add_highlight(state.list_buf, ns, "Normal", line_index, start_col, -1)
		end
	end
end

local function close()
	if not state.active then
		return
	end

	state.active = false

	local prompt_win = state.prompt_win
	local list_win = state.list_win
	local prompt_buf = state.prompt_buf
	local list_buf = state.list_buf

	state.prompt_buf = nil
	state.prompt_win = nil
	state.list_buf = nil
	state.list_win = nil
	state.entries = {}
	state.filtered = {}
	state.selected = 1
	state.query = ""

	if prompt_win and vim.api.nvim_win_is_valid(prompt_win) then
		vim.api.nvim_win_close(prompt_win, true)
	end
	if list_win and vim.api.nvim_win_is_valid(list_win) then
		vim.api.nvim_win_close(list_win, true)
	end
	if prompt_buf and vim.api.nvim_buf_is_valid(prompt_buf) then
		vim.api.nvim_buf_delete(prompt_buf, { force = true })
	end
	if list_buf and vim.api.nvim_buf_is_valid(list_buf) then
		vim.api.nvim_buf_delete(list_buf, { force = true })
	end
end

local function switch_from_picker(open_fn)
	state.query = read_query()
	remember_open(state.query)
	picker_switch.open(open_fn)
end

local function reopen_last_picker()
	state.query = read_query()
	remember_open(state.query)
	require("nvimconf.picker_history").reopen()
end

local function move_selection(delta)
	if #state.filtered == 0 then
		return
	end

	state.selected = state.selected + delta
	if state.selected < 1 then
		state.selected = #state.filtered
	elseif state.selected > #state.filtered then
		state.selected = 1
	end
	render()
end

local function open_file(command)
	local entry = state.filtered[state.selected]
	if not entry then
		return
	end

	close()
	vim.cmd(command .. " " .. vim.fn.fnameescape(entry.path))
end

local function update_query()
	state.query = read_query()
	remember_open(state.query)
	state.selected = 1
	render()
end

local function create_window(buf, opts)
	local win = vim.api.nvim_open_win(buf, opts.enter, {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		title = opts.title,
		title_pos = "center",
		width = opts.width,
		height = opts.height,
		row = opts.row,
		col = opts.col,
	})

	vim.wo[win].winblend = 0
	vim.wo[win].wrap = false
	vim.wo[win].cursorline = false
	return win
end

function M.open(initial_query)
	remember_open(initial_query)

	if state.active then
		if state.prompt_win and vim.api.nvim_win_is_valid(state.prompt_win) then
			vim.api.nvim_set_current_win(state.prompt_win)
			vim.cmd.startinsert()
		end
		return
	end

	state.entries = oldfile_entries()
	state.query = initial_query or ""
	state.filtered = filter_entries(state.query)
	state.selected = #state.filtered > 0 and 1 or 0
	state.active = true

	local width = math.min(math.max(64, math.floor(vim.o.columns * 0.62)), 110)
	local max_list_height = math.max(4, vim.o.lines - 8)
	local list_height =
		math.min(math.max(#state.entries, 1), math.max(8, math.floor(vim.o.lines * 0.48)), max_list_height)
	local total_height = list_height + 5
	local row = math.max(1, math.floor((vim.o.lines - total_height) / 2) - 1)
	local col = math.floor((vim.o.columns - width) / 2)

	state.prompt_buf = vim.api.nvim_create_buf(false, true)
	state.list_buf = vim.api.nvim_create_buf(false, true)

	vim.bo[state.prompt_buf].buftype = "prompt"
	vim.bo[state.prompt_buf].bufhidden = "wipe"
	vim.bo[state.prompt_buf].filetype = "nvimconf-minimal_oldfiles_picker"
	vim.fn.prompt_setprompt(state.prompt_buf, state.prompt)

	vim.bo[state.list_buf].bufhidden = "wipe"
	vim.bo[state.list_buf].filetype = "nvimconf-minimal_oldfiles_picker"
	vim.bo[state.list_buf].modifiable = false

	state.prompt_win = create_window(state.prompt_buf, {
		enter = true,
		title = "Oldfiles",
		width = width,
		height = 1,
		row = row,
		col = col,
	})

	state.list_win = create_window(state.list_buf, {
		enter = false,
		title = "Enter: open  Ctrl-V: vsplit  Ctrl-S: split  Ctrl-T: tab",
		width = width,
		height = list_height,
		row = row + 3,
		col = col,
	})

	vim.wo[state.list_win].cursorline = false
	set_prompt_text(state.query)
	render()

	local function map(mode, lhs, rhs, desc)
		vim.keymap.set(mode, lhs, rhs, {
			buffer = state.prompt_buf,
			silent = true,
			nowait = true,
			desc = desc,
		})
	end

	map({ "i", "n" }, "<Esc>", close, "Close oldfiles picker")
	map({ "i", "n" }, "<C-c>", close, "Close oldfiles picker")
	map("n", "q", close, "Close oldfiles picker")
	map({ "i", "n" }, "<Down>", function()
		move_selection(1)
	end, "Next oldfile")
	map({ "i", "n" }, "<C-n>", function()
		move_selection(1)
	end, "Next oldfile")
	map({ "i", "n" }, "<Tab>", function()
		move_selection(1)
	end, "Next oldfile")
	map({ "i", "n" }, "<Up>", function()
		move_selection(-1)
	end, "Previous oldfile")
	map({ "i", "n" }, "<C-p>", function()
		move_selection(-1)
	end, "Previous oldfile")
	map({ "i", "n" }, "<S-Tab>", function()
		move_selection(-1)
	end, "Previous oldfile")
	map({ "i", "n" }, "<CR>", function()
		open_file("edit")
	end, "Open oldfile")
	map({ "i", "n" }, "<C-v>", function()
		open_file("vsplit")
	end, "Open oldfile in vertical split")
	map({ "i", "n" }, "<C-s>", function()
		open_file("split")
	end, "Open oldfile in split")
	map({ "i", "n" }, "<C-t>", function()
		open_file("tabedit")
	end, "Open oldfile in tab")
	map({ "i", "n" }, "<m-n>", function()
		switch_from_picker(function()
			require("nvimconf.project_picker").open()
		end)
	end, "Switch project")
	map({ "i", "n" }, "<m-o>", function()
		vim.cmd.startinsert()
	end, "Oldfiles")
	map({ "i", "n" }, "<m-space>", function()
		switch_from_picker(function()
			require("nvimconf.penguin").open()
		end)
	end, "Command history")
	map({ "i", "n" }, "<C-Return>", function()
		switch_from_picker(function()
			require("nvimconf.fff").find_files()
		end)
	end, "Find files")
	map({ "i", "n" }, "<m-cr>", reopen_last_picker, "Reopen last picker")
	map("i", "<C-w>", "<C-S-w>", "Delete word")

	local group = vim.api.nvim_create_augroup("nvimconf-minimal.oldfiles_picker." .. state.prompt_buf, { clear = true })
	vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
		group = group,
		buffer = state.prompt_buf,
		callback = update_query,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		pattern = tostring(state.prompt_win),
		callback = function()
			vim.schedule(close)
		end,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		pattern = tostring(state.list_win),
		callback = function()
			vim.schedule(close)
		end,
	})

	vim.cmd.startinsert()
end

function M.close()
	close()
end

function M.oldfile_entries_for_test()
	return oldfile_entries()
end

return M
