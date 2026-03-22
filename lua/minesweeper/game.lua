local Game = {}
Game.__index = Game

local function create_cell()
  return {
    mine = false,
    revealed = false,
    flagged = false,
    adjacent = 0,
  }
end

local function neighbors(height, width, row, col)
  local positions = {}

  for delta_row = -1, 1 do
    for delta_col = -1, 1 do
      if not (delta_row == 0 and delta_col == 0) then
        local next_row = row + delta_row
        local next_col = col + delta_col

        if next_row >= 1 and next_row <= height and next_col >= 1 and next_col <= width then
          positions[#positions + 1] = { row = next_row, col = next_col }
        end
      end
    end
  end

  return positions
end

function Game.new(opts)
  local self = setmetatable({}, Game)

  self.width = opts.width or 9
  self.height = opts.height or 9
  self.mine_count = math.min(opts.mines or 10, (self.width * self.height) - 1)
  self.generated = false
  self.status = "ready"
  self.revealed_count = 0
  self.exploded = nil
  self.board = {}

  for row = 1, self.height do
    self.board[row] = {}

    for col = 1, self.width do
      self.board[row][col] = create_cell()
    end
  end

  return self
end

function Game:cell(row, col)
  if self.board[row] then
    return self.board[row][col]
  end
end

function Game:flag_count()
  local total = 0

  for row = 1, self.height do
    for col = 1, self.width do
      if self.board[row][col].flagged then
        total = total + 1
      end
    end
  end

  return total
end

function Game:remaining_mines()
  return math.max(0, self.mine_count - self:flag_count())
end

function Game:is_over()
  return self.status == "won" or self.status == "lost"
end

function Game:_shuffle_positions(positions)
  for index = #positions, 2, -1 do
    local swap_index = math.random(index)
    positions[index], positions[swap_index] = positions[swap_index], positions[index]
  end
end

function Game:_calculate_adjacency()
  for row = 1, self.height do
    for col = 1, self.width do
      local cell = self.board[row][col]

      if cell.mine then
        cell.adjacent = -1
      else
        local adjacent = 0

        for _, position in ipairs(neighbors(self.height, self.width, row, col)) do
          if self.board[position.row][position.col].mine then
            adjacent = adjacent + 1
          end
        end

        cell.adjacent = adjacent
      end
    end
  end
end

function Game:_generate(safe_row, safe_col)
  local positions = {}

  for row = 1, self.height do
    for col = 1, self.width do
      if not (row == safe_row and col == safe_col) then
        positions[#positions + 1] = { row = row, col = col }
      end
    end
  end

  self:_shuffle_positions(positions)

  for index = 1, self.mine_count do
    local position = positions[index]
    self.board[position.row][position.col].mine = true
  end

  self:_calculate_adjacency()
  self.generated = true
end

function Game:_reveal_mines()
  for row = 1, self.height do
    for col = 1, self.width do
      local cell = self.board[row][col]

      if cell.mine then
        cell.revealed = true
      end
    end
  end
end

function Game:_mark_won()
  self.status = "won"

  for row = 1, self.height do
    for col = 1, self.width do
      local cell = self.board[row][col]

      if cell.mine then
        cell.flagged = true
      end
    end
  end
end

function Game:_check_win()
  local safe_cells = (self.width * self.height) - self.mine_count
  return self.revealed_count >= safe_cells
end

function Game:_flood_reveal(start_row, start_col)
  local queue = { { row = start_row, col = start_col } }

  while #queue > 0 do
    local position = table.remove(queue)
    local cell = self:cell(position.row, position.col)

    if cell and not cell.revealed and not cell.flagged and not cell.mine then
      cell.revealed = true
      self.revealed_count = self.revealed_count + 1

      if cell.adjacent == 0 then
        for _, neighbor in ipairs(neighbors(self.height, self.width, position.row, position.col)) do
          local neighbor_cell = self:cell(neighbor.row, neighbor.col)

          if neighbor_cell and not neighbor_cell.revealed and not neighbor_cell.mine then
            queue[#queue + 1] = neighbor
          end
        end
      end
    end
  end
end

function Game:toggle_flag(row, col)
  if self:is_over() then
    return false, "game-over"
  end

  local cell = self:cell(row, col)

  if not cell or cell.revealed then
    return false, "invalid-cell"
  end

  cell.flagged = not cell.flagged

  if self.status == "ready" then
    self.status = "playing"
  end

  return true, cell.flagged and "flagged" or "unflagged"
end

function Game:reveal(row, col)
  if self:is_over() then
    return false, "game-over"
  end

  local cell = self:cell(row, col)

  if not cell then
    return false, "invalid-cell"
  end

  if cell.flagged or cell.revealed then
    return false, "blocked"
  end

  if not self.generated then
    self:_generate(row, col)
  end

  cell = self:cell(row, col)
  self.status = "playing"

  if cell.mine then
    cell.revealed = true
    self.exploded = { row = row, col = col }
    self.status = "lost"
    self:_reveal_mines()
    return true, "mine"
  end

  self:_flood_reveal(row, col)

  if self:_check_win() then
    self:_mark_won()
    return true, "won"
  end

  return true, "revealed"
end

return Game
