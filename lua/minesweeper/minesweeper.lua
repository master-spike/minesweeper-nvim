local Game = require("minesweeper.game")
local ui = require("minesweeper.ui")

local M = {}

local defaults = {
	width = 16,
	height = 16,
	mines = 40,
}

local state = {
	config = vim.deepcopy(defaults),
	cursor = { row = 1, col = 1 },
	game = nil,
	buf = nil,
	win = nil,
	command_created = false,
}

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "Minesweeper" })
end

local function create_game()
	state.game = Game.new(state.config)
	state.cursor = { row = 1, col = 1 }
end

local function clamp_cursor()
	if not state.game then
		return
	end

	state.cursor.row = math.max(1, math.min(state.game.height, state.cursor.row))
	state.cursor.col = math.max(1, math.min(state.game.width, state.cursor.col))
end

local function ensure_game(reset)
	if reset or not state.game then
		create_game()
	end
end

local function rerender()
	if state.game then
		clamp_cursor()
		ui.open(state)
	end
end

function M.move(delta_row, delta_col)
	if not state.game then
		return
	end

	state.cursor.row = state.cursor.row + delta_row
	state.cursor.col = state.cursor.col + delta_col
	rerender()
end

function M.reveal()
	if not state.game then
		return
	end

	local changed, reason = state.game:reveal(state.cursor.row, state.cursor.col)
	rerender()

	if changed and reason == "mine" then
		notify("Boom. The board is still here if you want to inspect the damage.", vim.log.levels.WARN)
	elseif changed and reason == "won" then
		notify("You cleared the board.", vim.log.levels.INFO)
	end
end

function M.toggle_flag()
	if not state.game then
		return
	end

	state.game:toggle_flag(state.cursor.row, state.cursor.col)
	rerender()
end

function M.hide()
	ui.hide(state)
end

function M.reset()
	create_game()
	rerender()
end

function M.open(opts)
	M.setup()
	ensure_game(opts and opts.reset)
	rerender()
end

local function command_handler(command_opts)
	local arg = vim.trim(command_opts.args or "")

	if arg == "" then
		M.open()
		return
	end

	if arg == "reset" then
		M.open({ reset = true })
		return
	end

	notify("Unsupported argument: " .. arg .. ". Try :Minesweeper or :Minesweeper reset.", vim.log.levels.ERROR)
end

function M.setup(opts)
	state.config = vim.tbl_deep_extend("force", {}, state.config, opts or {})
	ui.setup_highlights()

	if state.command_created then
		return
	end

	vim.api.nvim_create_user_command("Minesweeper", command_handler, {
		nargs = "?",
		complete = function()
			return { "reset" }
		end,
		desc = "Open the Minesweeper floating window, or pass reset to start over",
	})

	state.command_created = true
end

state.actions = {
	move = function(delta_row, delta_col)
		M.move(delta_row, delta_col)
	end,
	reveal = function()
		M.reveal()
	end,
	flag = function()
		M.toggle_flag()
	end,
	hide = function()
		M.hide()
	end,
	reset = function()
		M.reset()
	end,
}

return M
