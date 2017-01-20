
local inspect = require('inspect')
local glo = {}

local CHAR_SIZE = 0.8

function love.load()
  local FONT_SIZE = 24
  local INFO_PANE_H = 200
  local VISIBLE_MARGIN_CELLS = 3
  local VIEW_DISTANCE = 20
  math.randomseed(1)
  -- Init global state
  glo.quitting = 0
  --local screenW = 1280
  --local screenH = 720
  -- Init video.
  --modeFlags = {fullscreen=true, fullscreentype="desktop"}
  --love.window.setMode(screenW, screenH, modeFlags)
  -- Set up the room
  glo.viewDistance = VIEW_DISTANCE
  local screenSz = { w = love.graphics.getWidth(),
                     h = love.graphics.getHeight() }
  glo.cellW = 50
  glo.cellH = 50
  glo.rooms = load_map()
  local t, f = true, false
  glo.tiles = {
    { name="wall",  pass=f, vis=f, color={0xFF,0xFF,0xFF} },
    { name="floor", pass=t, vis=t, color={0x40,0x40,0x40} },
    { name="grass", pass=t, vis=t, color={0x20,0x80,0x20} },
    { name="water", pass=f, vis=t, color={0x20,0x20,0x80} },
  }
  set_list_ids(glo.tiles)
  glo.visibleMarginCells = VISIBLE_MARGIN_CELLS
  glo.view = {
    x = 0,
    y = 0,
    w = screenSz.w,
    h = screenSz.h - INFO_PANE_H
  }
  glo.infoPane = {
    x = 0,
    y = screenSz.h - INFO_PANE_H,
    w = screenSz.w,
    h = INFO_PANE_H
  }
  -- Set up fonts.
  glo.infoFont = love.graphics.setNewFont(FONT_SIZE)
  local charLetterSz = 0.8 * CHAR_SIZE
  local charLetterBoxW = math.floor(charLetterSz * glo.cellW)
  local charLetterBoxH = math.floor(charLetterSz * glo.cellH)
  local tileFontMaxHeight = math.floor(0.8 * CHAR_SIZE * glo.cellH)
  local tileFontSize = 51
  repeat
    tileFontSize = tileFontSize - 1
    glo.tileFont = love.graphics.setNewFont(tileFontSize)
  until glo.tileFont:getHeight() <= charLetterBoxH
    and glo.tileFont:getWidth("M") <= charLetterBoxW
  print(string.format("Tile font size: %q. Letter box: %dx%d",
                      tileFontSize, charLetterBoxW, charLetterBoxH))
  -- Set up chars.
  glo.chars = {
    new_char(2, 2, "Player"),
    new_char(4, 4, "Goblin"),
    new_char(8, 8, "Smurf"),
  }
  glo.char_pos = {}
  for i, c in ipairs(glo.chars) do
    local key = string.format("%d,%d", c.r, c.c)
    glo.char_pos[key] = c
  end
  dump(glo.chars)
  glo.player = glo.chars[1]
  -- Ensure that we don't start up with the view over in one corner.
  recenter_view()
  glo.commands = {}
end

local NextCharID = 1

function new_char(r, c, name)
  local char = { id = NextCharID, r = r, c = c, name = name, alive = true }
  NextCharID = NextCharID + 1
  if name == "Player" then
    char.color = {0xFF,0x00,0x00}
    char.letter = "@"
    char.base = {
      hp = 100,
      speed = 50,
      attack = 50,
    }
  elseif name == "Goblin" then
    char.color = {0x00,0xFF,0x00}
    char.letter = "G"
    char.base = {
      hp = 60,
      speed = 50,
      attack = 40,
      aggression = 70,
    }
  elseif name == "Smurf" then
    char.color = {0x00,0x00,0xFF}
    char.letter = "S"
    char.base = {
      hp = 40,
      speed = 50,
      attack = 30,
      aggression = 30,
    }
  end
  -- Copy base stats to current stats.
  char.cur = {}
  for stat, statValue in pairs(char.base) do
    char.cur[stat] = statValue
  end
  return char
end

function set_list_ids(list)
  for id, item in ipairs(list) do
    item.id = id
  end
end

function get_tile(cellRC)
  local col = glo.rooms[cellRC.r]
  if col == nil then return nil end
  local tileID = col[cellRC.c]
  if tileID == nil then return nil end
  local tile = glo.tiles[tileID]
  return tile
end

function get_char(cellRC)
  local key = string.format("%d,%d", cellRC.r, cellRC.c)
  return glo.char_pos[key]
end

function move_char(char, toCellRC)
  local oldKey = string.format("%d,%d", char.r, char.c)
  glo.char_pos[oldKey] = nil
  if toCellRC ~= nil then
    local newKey = string.format("%d,%d", toCellRC.r, toCellRC.c)
    glo.char_pos[newKey] = char
    char.r = toCellRC.r
    char.c = toCellRC.c
  end
end

function list_to_set(x)
  local s = {}
  for i,v in ipairs(x) do
    s[v] = true
  end
  return s
end

local arrow_keys = list_to_set({ "up", "down", "right", "left" })

function love.keypressed(k)
  if k == "escape" or k == "q" then
    love.event.quit()
  elseif k == "space" then
    table.insert(glo.commands, { cmd="pass" })
  elseif arrow_keys[k] then
    dest = { r = glo.player.r, c = glo.player.c }
    if     k == "left"  then dest.c = dest.c - 1
    elseif k == "right" then dest.c = dest.c + 1
    elseif k == "up"    then dest.r = dest.r - 1
    elseif k == "down"  then dest.r = dest.r + 1
    end
    table.insert(glo.commands, { cmd="move", dest=dest })
  end
end

function kill_char(char)
  -- TODO: drop loot
  move_char(char, nil) -- Remove char from the map.
  char.alive = false
end

function attack(attackChar, targetChar)
  local damage = 0
  if type(attackChar.cur.attack) == "table" then
    for i = 1, attackChar.cur.attack[1] do
      damage = damage + math.random(attackChar.cur.attack[2])
    end
  else
    damage = math.random(attackChar.cur.attack)
  end
  glo.commandOutput = glo.commandOutput .. string.format("[%s->%s: %d] ", attackChar.name, targetChar.name, damage)
  targetChar.cur.hp = targetChar.cur.hp - damage
  if targetChar.cur.hp < 0 then
    targetChar.cur.hp = 0
  end
  if targetChar.cur.hp == 0 then
    glo.commandOutput = glo.commandOutput .. string.format("(%s dies!) ", targetChar.name)
    kill_char(targetChar)
  end
  return damage
end

function recenter_view()
  local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
  -- Box around player that should remain visible. (View shifts to keep it in view.)
  local playerVisibleBox = {
    x = (glo.player.c - glo.visibleMarginCells) * glo.cellW,
    y = (glo.player.r - glo.visibleMarginCells) * glo.cellH,
    w = (1 + 2 * glo.visibleMarginCells) * glo.cellW,
    h = (1 + 2 * glo.visibleMarginCells) * glo.cellH,
  }
  -- First check right and bottom edges.
  -- (By putting these first, if the view box is larger than the screen
  -- then we'll align to the left and top edges since they are done last.)
  if box_right_x(playerVisibleBox) > box_right_x(glo.view) then
    glo.view.x = box_right_x(playerVisibleBox) - glo.view.w
  end
  if box_bottom_y(playerVisibleBox) > box_bottom_y(glo.view) then
    glo.view.y = box_bottom_y(playerVisibleBox) - glo.view.h
  end
  -- Then check left and top edges.
  if playerVisibleBox.x < glo.view.x then
    glo.view.x = playerVisibleBox.x
  end
  if playerVisibleBox.y < glo.view.y then
    glo.view.y = playerVisibleBox.y
  end
end

function love.mousepressed(x, y, button, istouch)
  if button == 1 then
  elseif button == 2 then
    -- Center at mouse click
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    glo.view.x = glo.view.x + (x - math.floor(screenW / 2))
    glo.view.y = glo.view.y + (y - math.floor(screenH / 2))
  end
end

function love.quit()
  -- Return true here to abort quit.
  return false
end

local displayText = {}

function love.update()

  local playerMadeMove = false

  -- Process pending commands.
  for i, cmd in ipairs(glo.commands) do
    if not playerMadeMove then
      playerMadeMove = true
      glo.commandOutput = ""
    end
    if cmd.cmd == "pass" then
      glo.commandText = "CMD: Pass"
    elseif cmd.cmd == "move" then
      local destChar = get_char(cmd.dest)
      if destChar then
        -- attack destChar
        glo.commandText = string.format("CMD: Attack char %s", destChar.name)
        attack(glo.player, destChar)
      elseif get_tile(cmd.dest).pass then
        -- move to dest
        move_char(glo.player, cmd.dest)
        recenter_view()
        glo.commandText = string.format("CMD: Move to r%d c%d", cmd.dest.r, cmd.dest.c)
      end
    end
  end

  -- Clear commands queue.
  glo.commands = {}

  -- Process NPC commands.
  if playerMadeMove then
    repeat
      for i = 2, table.getn(glo.chars) do
        local char = glo.chars[i]
        if char.alive then
          if check_stat(char.cur.speed) then
            glo.commandText = (glo.commandText or '(X)') .. string.format(" [%s]", char.name)
            local moves = nil
            if check_stat(char.cur.aggression) then
              -- Make an aggressive move.
              glo.commandText = glo.commandText .. "A:"
              local madeAttack = false
              for _, cellRC in ipairs(adjacent_cells(char)) do
                local cellChar = get_char(cellRC)
                if cellChar and cellChar.id == 1 then
                  -- NPC attacks player
                  glo.commandText = glo.commandText .. "attack"
                  local dam = attack(char, glo.player)
                  glo.commandText = glo.commandText .. dam .. "hp"
                  break
                end
              end
              if not madeAttack then
                -- NPC moves toward player.
                -- Generate list of moves that go toward the player.
                local diff = cell_diff(char, glo.player)
                moves = {
                  { r = char.r, c = char.c + sign(diff.c) },
                  { r = char.r + sign(diff.r), c = char.c },
                }
                function swap() moves = { moves[2], moves[1] } end
                if math.abs(diff.c) > math.abs(diff.r) then
                  -- keep default priority
                elseif math.abs(diff.c) < math.abs(diff.r) then
                  -- swap priority
                  swap()
                else
                  -- randomly swap priority
                  if chance(1, 2) then
                    swap()
                  end
                end
              end
            else
              -- Make a cowardly move. NPC moves away from player.
              glo.commandText = glo.commandText .. "C:"
              -- Generate list of moves that go away from the player.
              local diff = cell_diff(glo.player, char)
              moves = {
                { r = char.r, c = char.c + sign(diff.c) },
                { r = char.r + sign(diff.r), c = char.c },
              }
              function swap() moves = { moves[2], moves[1] } end
              if math.abs(diff.c) > math.abs(diff.r) then
                -- keep default priority
              elseif math.abs(diff.c) < math.abs(diff.r) then
                -- swap priority
                swap()
              else
                -- randomly swap priority
                if math.random(2) <= 1 then
                  swap()
                end
              end
            end
            -- Make the first available move.
            if moves then
              for _, m in ipairs(moves) do
                if get_tile(m).pass and not get_char(m) then
                  move_char(char, m)
                  break
                end
              end
            end
          end
        end
      end
    until check_stat(glo.player.cur.speed)
  end

  -- Compose displayText
  local mouseAbs = {
    x = love.mouse.getX() + glo.view.x,
    y = love.mouse.getY() + glo.view.y
  }
  local mouseCell = {
    r = math.floor(mouseAbs.y / glo.cellH),
    c = math.floor(mouseAbs.x / glo.cellW),
    tile = nil
  }
  mouseCell.tile = get_tile(mouseCell)
  local charInfo = ""
  for _, char in ipairs(glo.chars) do
    if char.cur.hp == 0 then
      charInfo = charInfo .. string.format("[%s -/%d] ", char.name, char.base.hp)
    else
      charInfo = charInfo .. string.format("[%s %d/%d] ", char.name, char.cur.hp, char.base.hp)
    end
  end
  local viewInfo = string.format(
    "View: (%d,%d) MouseAbs (%d,%d) MousePos (%d,%d)",
    glo.view.x, glo.view.y, mouseAbs.x, mouseAbs.y, love.mouse.getX(), love.mouse.getY())
  if mouseCell.tile then viewInfo = viewInfo .. string.format(" Cell r%d c%d: %s", mouseCell.r, mouseCell.c, mouseCell.tile.name)
  else viewInfo = viewInfo .. string.format(" Cell r%d c%d: ---", mouseCell.r, mouseCell.c)
  end
  local charUnderMouse = get_char(mouseCell)
  if charUnderMouse then viewInfo = displayText[1] .. "(" .. charUnderMouse.name .. ")" end
  displayText[1] = charInfo
  displayText[2] = glo.commandText or ''
  displayText[3] = glo.commandOutput or ''
  displayText[4] = viewInfo
end

function love.draw()
  local glo = glo
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  love.graphics.reset()
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.setBlendMode("alpha")
  --love.graphics.setBlendMode("alpha", "premultiplied")

  -- TODO: VISIBILITY

  -- Used for status display / legend.
  local charsVisible = {}
  -- Allocate matrix to show which cells are visible.
  local cellVisibilityMatrix = {}
  for r = 1, 2 * glo.viewDistance + 1 do
    local row = {}
    for c = 1, 2 * glo.viewDistance + 1 do
      row[c] = 0
    end
    table.insert(cellVisibilityMatrix, row)
  end
  -- Mark the spot where the player is standing as visible.
  local center = glo.viewDistance + 1
  cellVisibilityMatrix[center][center] = 2

  local cellVisibilityMatrixOffset = { glo.player.r - glo.viewDistance,
                                       glo.player.c - glo.viewDistance }

  function set_cell_visible(matrixCoords, depMatrixCoords)
    local visible = false
    for _,d in ipairs(depMatrixCoords) do
      if cellVisibilityMatrix[d[1]][d[2]] == 2 then
        visible = true
        break
      end
    end
    if not visible then return end
    local cellR = cellVisibilityMatrixOffset[1] + matrixCoords[1]
    local cellC = cellVisibilityMatrixOffset[2] + matrixCoords[2]
    local c = get_tile({r=cellR, c=cellC})
    if c then
      if c.vis then
        cellVisibilityMatrix[matrixCoords[1]][matrixCoords[2]] = 2
      else
        cellVisibilityMatrix[matrixCoords[1]][matrixCoords[2]] = 1
      end
    end
  end

  function is_cell_visible(cellRC)
    local matrixCoordR = cellRC.r - cellVisibilityMatrixOffset[1]
    local matrixCoordC = cellRC.c - cellVisibilityMatrixOffset[2]
    return 0 < ( cellVisibilityMatrix[matrixCoordR]
                 and cellVisibilityMatrix[matrixCoordR][matrixCoordC]
                 or 0 )
  end

  for distance = 1, glo.viewDistance do
    -- Deal with everything except the corners first.
    for step = center - distance + 1, center + distance - 1 do
      set_cell_visible({step, center + distance}, { {step, center + distance - 1} })
      set_cell_visible({step, center - distance}, { {step, center - distance + 1} })
      set_cell_visible({center + distance, step}, { {center + distance - 1, step} })
      set_cell_visible({center - distance, step}, { {center - distance + 1, step} })
    end
    -- Now the corners.
    set_cell_visible({center - distance, center - distance}, { {center - distance + 1, center - distance},
                                                               {center - distance + 1, center - distance + 1},
                                                               {center - distance, center - distance + 1} })
    set_cell_visible({center - distance, center + distance}, { {center - distance + 1, center + distance},
                                                               {center - distance + 1, center + distance - 1},
                                                               {center - distance, center + distance - 1} })
    set_cell_visible({center + distance, center + distance}, { {center + distance - 1, center + distance},
                                                               {center + distance - 1, center + distance - 1},
                                                               {center + distance, center + distance - 1} })
    set_cell_visible({center + distance, center - distance}, { {center + distance - 1, center - distance},
                                                               {center + distance - 1, center - distance + 1},
                                                               {center + distance, center - distance + 1} })
  end

  if not glo.dumpedVisMtx then -- DUMP ONCE
    glo.dumpedVisMtx = true
    for r = 1, table.getn(cellVisibilityMatrix) do
      for c = 1, table.getn(cellVisibilityMatrix) do
        io.write(string.format("%d", cellVisibilityMatrix[r][c]))
      end
      print('')
    end
  end

  -- Draw the map
  local charsVisible = {}  -- Used for status display / legend.
  for ri, rv in ipairs(glo.rooms) do
    local y = ri * glo.cellH
    for ci, cv in ipairs(rv) do
      local x = ci * glo.cellW
      local effectiveX, effectiveY = x - glo.view.x, y - glo.view.y
      tile = glo.tiles[cv]
      love.graphics.setColor(tile.color)
      if is_cell_visible({r=ri, c=ci}) then
        love.graphics.rectangle("fill",
          effectiveX, effectiveY,
          glo.cellW, glo.cellH)
        local charHere = get_char({r=ri,c=ci})
        if charHere then
          draw_char(effectiveX, effectiveY, charHere)
          table.insert(charsVisible, charHere)
        end
      end
    end
  end

  -- Display displayText
  local infoPaneTop = screenH - 200
  love.graphics.setFont(glo.infoFont)
  love.graphics.setColor({ 0,0,0,0xFF })
  love.graphics.rectangle("fill", 0, infoPaneTop, screenW, 200)
  love.graphics.setColor({ 0xFF,0xFF,0xFF,0xFF })
  local infoTextPadding = 10
  local infoTextX, infoTextY = infoTextPadding, infoPaneTop + infoTextPadding
  local lineSkip = 1.2 * glo.infoFont:getHeight()
  for i, text in ipairs(displayText) do
    love.graphics.print(text, infoTextX, infoTextY)
    infoTextY = infoTextY + lineSkip
  end
end

function draw_char(cellX, cellY, char)
  -- Rectangle
  love.graphics.setColor(char.color)
  local charW = math.floor(glo.cellW * CHAR_SIZE)
  local charH = math.floor(glo.cellH * CHAR_SIZE)
  local charRelX = math.floor((glo.cellW - charW) / 2)
  local charRelY = math.floor((glo.cellH - charH) / 2)
  local charEffX = cellX + charRelX
  local charEffY = cellY + charRelY
  love.graphics.rectangle("fill", charEffX, charEffY, charW, charH)
  -- Letter
  love.graphics.setFont(glo.tileFont)
  love.graphics.setColor({0xFF,0xFF,0xFF})
  local letterOffsetX = math.floor((glo.cellW - glo.tileFont:getWidth(char.letter)) / 2)
  local letterOffsetY = math.floor((glo.cellH - glo.tileFont:getHeight()) / 2)
  love.graphics.print(char.letter, cellX + letterOffsetX, cellY + letterOffsetY)
end

--------------------
-- UTILITY FUNCTIONS

function dump(x)
  print(inspect(x))
end

function chance(chancesToHappen, outOfTotalChances)
  return math.random(outOfTotalChances) <= chancesToHappen
end

function check_stat(stat)
  return chance(stat, 100)
end

-- Vector (r/c) to travel from cell1 to cell2.
function cell_diff(cell1, cell2)
  return { r = cell2.r - cell1.r, c = cell2.c - cell1.c }
end

-- Vector (x/y) to travel from pt1 to pt2.
function point_diff(pt1, pt2)
  return { x = pt2.x - pt1.x, y = pt2.y - pt1.y }
end

-- Right edge of a box (exclusive coordinate).
function box_right_x(box)
  return box.x + box.w
end

-- Bottom edge of a box (exclusive coordinate).
function box_bottom_y(box)
  return box.y + box.h
end

-- Convert box x/y coordinates from view-relative to absolute.
function box_rel_to_abs(box)
  return { x = box.x + view.x, y = box.y + view.y,
           w = box.w, h = box.h }
end

-- Convert box x/y coordinates from absolute to view-relative.
function box_abs_to_rel(box)
  return { x = box.x - view.x, y = box.y - view.y,
           w = box.w, h = box.h }
end

function adjacent_cells(cellRC)
  return { { r = cellRC.r-1, c = cellRC.c },   { r = cellRC.r+1, c = cellRC.c },
           { r = cellRC.r,   c = cellRC.c-1 }, { r = cellRC.r,   c = cellRC.c+1 } }
end

function sign(x)
  if x < 0 then return -1
  elseif x > 0 then return 1
  else return 0
  end
end

function load_map()
  return {
    { 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 },
    { 1,2,2,2,2,2,2,2,2,2,2,2,4,4,4,1 },
    { 1,2,2,2,2,2,2,2,2,2,2,2,4,4,4,1 },
    { 1,2,2,2,2,2,2,2,2,2,2,2,2,4,4,1 },
    { 1,2,2,2,2,2,2,2,2,2,2,2,2,2,4,1 },
    { 1,2,2,2,2,2,2,2,2,2,2,2,3,3,3,1 },
    { 1,2,2,2,2,2,2,2,2,2,2,3,3,3,3,1 },
    { 1,2,2,2,2,2,2,2,2,2,2,3,3,3,2,1 },
    { 1,2,2,2,2,2,2,2,2,2,2,3,3,3,2,1 },
    { 1,2,2,2,2,2,2,2,2,2,2,3,3,3,2,1 },
    { 1,2,2,2,2,2,2,2,2,2,2,3,3,3,2,1 },
    { 1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1 },
    { 1,1,1,1,1,1,2,2,2,2,2,2,1,1,1,1 },
    { 1,1,1,1,1,2,2,2,2,2,2,2,1,1,1,1 },
    { 1,1,1,1,1,2,2,2,2,2,2,2,1,1,1,1 },
    { 1,1,1,1,1,1,2,2,2,2,2,1,1,1,1,1 },
    { 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 },
  }
end

