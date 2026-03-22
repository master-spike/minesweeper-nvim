if vim.g.loaded_minesweeper_plugin ~= 1 then
  vim.g.loaded_minesweeper_plugin = 1
  require("minesweeper").setup()
end
