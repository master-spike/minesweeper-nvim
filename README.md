# minesweeper.nvim

A small floating-window Minesweeper plugin for Neovim.

## Current MVP status

The plugin now has the initial playable scaffold:

- `:Minesweeper` opens a floating window
- `:Minesweeper reset` starts a fresh board
- `h`, `j`, `k`, `l` move the selection
- `<space>` reveals a square
- `f` toggles a flag
- `q` hides the window without destroying the current game session

The current session lives in Lua module state, so reopening `:Minesweeper`
restores the same board until you reset it.

## Installation

Install with your preferred plugin manager, then call `setup()`.

### `lazy.nvim`

```lua
{
  "master-spike/minesweeper-nvim",
  config = function()
    require("minesweeper").setup()
  end,
}
```

### Manual setup

If you manage plugins yourself, place the repository on your `runtimepath` and
call:

```lua
require("minesweeper").setup()
```

## Usage

Run:

```vim
:Minesweeper
```

Use `:Minesweeper reset` to start a fresh board.

## Notes

- A Nerd Font is recommended for the hidden, flag, and mine glyphs.
- The default board is intermediate-sized: `16x16` with `40` mines.
- This is still early-stage and can be expanded with configuration, timers, and
  difficulty presets later.
