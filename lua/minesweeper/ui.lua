local M = {}

local namespace = vim.api.nvim_create_namespace("minesweeper")

local symbols = {
	hidden = "󰧟",
	flagged = "󰈿",
	mine = "󰷚",
	empty = "·",
}

local number_highlights = {
	[1] = "MinesweeperNumber1",
	[2] = "MinesweeperNumber2",
	[3] = "MinesweeperNumber3",
	[4] = "MinesweeperNumber4",
	[5] = "MinesweeperNumber5",
	[6] = "MinesweeperNumber6",
	[7] = "MinesweeperNumber7",
	[8] = "MinesweeperNumber8",
}

local function ensure_buffer(state)
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		return
	end

	state.buf = vim.api.nvim_create_buf(false, true)
	state.keymaps_set = false

	vim.bo[state.buf].bufhidden = "hide"
	vim.bo[state.buf].buftype = "nofile"
	vim.bo[state.buf].filetype = "minesweeper"
	vim.bo[state.buf].modifiable = false
	vim.bo[state.buf].swapfile = false
end

local function board_status(game)
	if game.status == "won" then
		return "won"
	end

	if game.status == "lost" then
		return "lost"
	end

	if game.status == "playing" then
		return "playing"
	end

	return "ready"
end

local function header_lines(game)
	return {
		string.format(
			" Minesweeper  %-2dx%-2d  mines:%-2d  flags:%-2d  remaining:%-2d  status:%-8s ",
			game.width,
			game.height,
			game.mine_count,
			game:flag_count(),
			game:remaining_mines(),
			board_status(game)
		),
		" h/j/k/l move  <Enter> reveal  f flag  q hide  r reset ",
	}
end

local function cell_style(game, row, col)
	local cell = game:cell(row, col)

	if game.status == "lost" and cell.mine then
		if game.exploded and game.exploded.row == row and game.exploded.col == col then
			return symbols.mine, "MinesweeperExploded"
		end

		return symbols.mine, "MinesweeperMine"
	end

	if cell.flagged and not cell.revealed then
		return symbols.flagged, "MinesweeperFlag"
	end

	if not cell.revealed then
		return symbols.hidden, "MinesweeperHidden"
	end

	if cell.mine then
		return symbols.mine, "MinesweeperMine"
	end

	if cell.adjacent == 0 then
		return symbols.empty, "MinesweeperEmpty"
	end

	return tostring(cell.adjacent), number_highlights[cell.adjacent]
end

local function build_board_lines(state)
	local lines = header_lines(state.game)
	local highlights = {}

	for row = 1, state.game.height do
		local parts = {}
		local ranges = {}
		local byte_col = 0

		for col = 1, state.game.width do
			local symbol, highlight = cell_style(state.game, row, col)
			local selected = state.cursor.row == row and state.cursor.col == col
			local token = selected and ("[" .. symbol .. "]") or (" " .. symbol .. " ")

			parts[#parts + 1] = token
			ranges[#ranges + 1] = {
				group = selected and "MinesweeperCursor" or highlight,
				start_col = byte_col,
				end_col = byte_col + #token,
			}

			byte_col = byte_col + #token
		end

		lines[#lines + 1] = table.concat(parts)
		highlights[#highlights + 1] = ranges
	end

	return lines, highlights
end

local function float_config(lines)
	local width = 0

	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end

	local height = #lines

	return {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		width = width,
		height = height,
		row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1),
		col = math.max(1, math.floor((vim.o.columns - width) / 2)),
	}
end

local function ensure_window(state, lines)
	local config = float_config(lines)

	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_set_config(state.win, config)
		vim.api.nvim_win_set_buf(state.win, state.buf)
		return
	end

	state.win = vim.api.nvim_open_win(state.buf, true, config)
	vim.wo[state.win].cursorline = false
	vim.wo[state.win].foldcolumn = "0"
	vim.wo[state.win].list = false
	vim.wo[state.win].number = false
	vim.wo[state.win].relativenumber = false
	vim.wo[state.win].signcolumn = "no"
	vim.wo[state.win].spell = false
	vim.wo[state.win].wrap = false
	vim.wo[state.win].winfixbuf = true
end

local function ensure_keymaps(state)
	if state.keymaps_set then
		return
	end

	local options = { buffer = state.buf, nowait = true, silent = true }

	vim.keymap.set("n", "h", function()
		state.actions.move(0, -1)
	end, options)

	vim.keymap.set("n", "j", function()
		state.actions.move(1, 0)
	end, options)

	vim.keymap.set("n", "k", function()
		state.actions.move(-1, 0)
	end, options)

	vim.keymap.set("n", "l", function()
		state.actions.move(0, 1)
	end, options)

	vim.keymap.set("n", "<space>", function()
		state.actions.reveal()
	end, options)

	vim.keymap.set("n", "f", function()
		state.actions.flag()
	end, options)

	vim.keymap.set("n", "q", function()
		state.actions.hide()
	end, options)

	vim.keymap.set("n", "r", function()
		state.actions.reset()
	end, options)

	state.keymaps_set = true
end

function M.setup_highlights()
	if M.highlights_initialized then
		return
	end

	local set_hl = vim.api.nvim_set_hl

	set_hl(0, "MinesweeperHidden", { default = true, fg = "#5c6370" })
	set_hl(0, "MinesweeperFlag", { default = true, fg = "#e5c07b", bold = true })
	set_hl(0, "MinesweeperMine", { default = true, fg = "#e06c75", bold = true })
	set_hl(0, "MinesweeperExploded", { default = true, fg = "#ffffff", bg = "#e06c75", bold = true })
	set_hl(0, "MinesweeperEmpty", { default = true, fg = "#7f848e", bg = "#170e5e" })
	set_hl(0, "MinesweeperCursor", { default = true, fg = "#61afef", bold = true })
	set_hl(0, "MinesweeperNumber1", { default = true, fg = "#61afef", bg = "#170e5e", bold = true })
	set_hl(0, "MinesweeperNumber2", { default = true, fg = "#98c379", bg = "#170e5e", bold = true })
	set_hl(0, "MinesweeperNumber3", { default = true, fg = "#e06c75", bg = "#170e5e", bold = true })
	set_hl(0, "MinesweeperNumber4", { default = true, fg = "#c678dd", bg = "#170e5e", bold = true })
	set_hl(0, "MinesweeperNumber5", { default = true, fg = "#be5046", bg = "#170e5e", bold = true })
	set_hl(0, "MinesweeperNumber6", { default = true, fg = "#56b6c2", bg = "#170e5e", bold = true })
	set_hl(0, "MinesweeperNumber7", { default = true, fg = "#abb2bf", bg = "#170e5e", bold = true })
	set_hl(0, "MinesweeperNumber8", { default = true, fg = "#ffffff", bg = "#170e5e", bold = true })

	M.highlights_initialized = true
end

function M.open(state)
	ensure_buffer(state)
	ensure_keymaps(state)

	local lines, highlights = build_board_lines(state)

	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(state.buf, namespace, 0, -1)

	for row, ranges in ipairs(highlights) do
		for _, range in ipairs(ranges) do
			vim.api.nvim_buf_add_highlight(state.buf, namespace, range.group, row + 1, range.start_col, range.end_col)
		end
	end

	vim.bo[state.buf].modifiable = false

	ensure_window(state, lines)
end

function M.hide(state)
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end

	state.win = nil
end

return M
