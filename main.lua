-- vim: ts=2 sts=2 sw=2 et smarttab

local inspect = require("inspect")
local glo = {}

local CHAR_SIZE = 0.8

function love.load()
  local gameData = load_game_data()
  local FONT_SIZE = 24
  local INFO_PANE_H = 200
  local VISIBLE_MARGIN_CELLS = 5
  local VIEW_DISTANCE = 5
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
  glo.rooms = gameData.map
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
  glo.chars = load_chars(gameData)
  --dump(glo.chars)
  glo.player = glo.chars[1]
  -- Ensure that we don't start up with the view over in one corner.
  recenter_view()
  glo.commands = {}  -- queue for commands issued by the user (i.e. input)
  glo.events = {}    -- queue for events to display to user
  glo.endTurn = false
end

------------------------------------------------------------
-- INPUT EVENTS

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

function love.keypressed(k)
  local arrow_keys = list_to_set({ "up", "down", "right", "left" })
  if k == "escape" or k == "q" then
    love.event.quit()
  elseif k == "space" then
    table.insert(glo.commands, { cmd="Pass" })
  elseif arrow_keys[k] then
    dest = { r = glo.player.r, c = glo.player.c }
    if     k == "left"  then dest.c = dest.c - 1
    elseif k == "right" then dest.c = dest.c + 1
    elseif k == "up"    then dest.r = dest.r - 1
    elseif k == "down"  then dest.r = dest.r + 1
    end
    table.insert(glo.commands, { cmd="Move", dest=dest })
  elseif k == "d" then
    glo.dumpedVisMtx = false -- dump debug info again
  end
end

local command_handlers = {
  Pass = function (cmd) return { new_event("EndTurn") } end,
  Move =
    function (cmd)
      local destChar = get_char(cmd.dest)
      if destChar then
        return { new_event("Attack", { actor = glo.player, target = destChar}),
                 new_event("EndTurn") }
      else
        return { new_event("Move", { actor = glo.player, dest = cmd.dest }),
                 new_event("EndTurn") }
      end
    end,
}

-- Translate commands into game events.
function generate_input_events()
  if table.getn(glo.commands) == 0 then return end
  -- Process pending commands.
  local commands = glo.commands
  glo.commands = {}
  for i, cmd in ipairs(commands) do
    local handler = assert(command_handlers[cmd.cmd], "Invalid command: "..cmd.cmd)
    local events = handler(cmd)
    if events then
      for _, e in ipairs(events) do
        table.insert(glo.events, e)
      end
    end
  end
end

------------------------------------------------------------
-- UPDATE

local displayText = {}

function love.update()

  generate_input_events()

  if table.getn(glo.events) > 0 then
    glo.commandText = ""
    glo.commandOutput = ""
    local events = glo.events
    glo.events = {}
    for _, e in ipairs(events) do
      local outcome = e:execute()
      glo.commandText = glo.commandText..outcome.output.." "
    end
  end

  -- Process NPC commands.
  if glo.endTurn then
    glo.endTurn = false
    repeat
      for i = 2, table.getn(glo.chars) do
        local char = glo.chars[i]
        if char.alive and check_stat(char.cur.speed) then
          char_ai_move(char)
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

function char_ai_move(char)
  glo.commandText = (glo.commandText or '(X)') .. string.format(" [%s]", char.name)
  local moves = nil
  if check_stat(char.cur.aggression) then
    -- Make an aggressive move.
    glo.commandText = glo.commandText .. "A:"
    if is_char_adjacent(char, glo.player) then
      -- NPC attacks player
      table.insert(glo.events, new_event("Attack", { actor = char, target = glo.player }))
    else
      -- NPC moves toward player.
      moves = choose_cell_in_direction(char, glo.player, true)
    end
  else
    -- Make a cowardly move. NPC moves away from player.
    glo.commandText = glo.commandText .. "C:"
    moves = choose_cell_in_direction(char, glo.player, false)
  end
  -- Make the first available move.
  if moves then
    --print(string.format("%s moves: (%d,%d) (%d,%d)",
    --                    char.name, moves[1].r, moves[1].c, moves[2].r, moves[2].c))
    for _, m in ipairs(moves) do
      --print("Tile: "..get_tile(m).name)
      --print("Char: "..(get_char(m) and get_char(m).name or "none"))
      if get_tile(m).pass and not get_char(m) then
        table.insert(glo.events, new_event("Move", { actor = char, dest = m }))
        break
      end
    end
  end
end

------------------------------------------------------------
-- DISPLAY

function love.draw()
  local glo = glo
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  love.graphics.reset()
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.setBlendMode("alpha")
  --love.graphics.setBlendMode("alpha", "premultiplied")

  --local vis = compute_visibility()
  function return_true(cellRC) return true end
  local vis = {
    is_cell_visible = return_true
  }

  -- Draw the map
  local charsVisible = {}  -- Used for status display / legend.
  for ri, rv in ipairs(glo.rooms) do
    local y = ri * glo.cellH
    for ci, cv in ipairs(rv) do
      local x = ci * glo.cellW
      local effectiveX, effectiveY = x - glo.view.x, y - glo.view.y
      tile = glo.tiles[cv]
      love.graphics.setColor(tile.color)
      if vis:is_cell_visible({r=ri, c=ci}) then
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

function compute_visibility()

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

  local cellVisibilityMatrixOffset = { glo.player.r - center,
                                       glo.player.c - center }

  if not glo.dumpedVisMtx then print(string.format("CENTER: %d,%d", center, center)) end
  local colCount = 0
  function set_cell_visible(matrixCoords)
    local diffVec = { center - matrixCoords[1], center - matrixCoords[2] }
    local unitVec = nil
    if math.abs(diffVec[1]) > math.abs(diffVec[2]) then     unitVec = { sign(diffVec[1]), 0 }
    elseif math.abs(diffVec[1]) < math.abs(diffVec[2]) then unitVec = { 0, sign(diffVec[2]) }
    else                                            unitVec = { sign(diffVec[1]), sign(diffVec[2]) }
    end
    if not glo.dumpedVisMtx then
      io.write(string.format("(%02d,%02d; %02d,%02d) ",
        matrixCoords[1], matrixCoords[2], stepVec[1], stepVec[2]))
      colCount = colCount + 1
      if colCount == 4 then
        colCount = 0
        print('')
      end
    end
    if cellVisibilityMatrix[blockingCell[1]][blockingCell[2]] ~= 2 then
      return
    end
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
    for step = 1 - distance, distance do
      local stepCells = {
        {center - distance, center - distance + step},
        {center - distance + step, center + distance},
        {center + distance, center + distance - step},
        {center + distance - step, center - distance},
      }
      for _, c in ipairs(stepCells) do
        set_cell_visible(c)
      end
    end
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

  return {
    matrix = cellVisibilityMatrix,
    offset = cellVisibilityMatrixOffset,
    is_cell_visible = is_cell_visible,
  }

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

------------------------------------------------------------
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

function is_char_adjacent(referenceChar, adjacentChar)
  if not adjacentChar.alive then return false end
  for _, cellRC in ipairs(adjacent_cells(referenceChar)) do
    local cellChar = get_char(cellRC)
    if cellChar and adjacentChar.id == 1 then
      return true
    end
  end
  return false
end

function choose_cell_in_direction(fromCellRC, toCellRC, isDirectionToward)
  -- Generate list of moves that go in the desired direction.
  local diff = isDirectionToward
    and cell_diff(fromCellRC, toCellRC)
    or  cell_diff(toCellRC, fromCellRC)
  moves = {
    { r = fromCellRC.r, c = fromCellRC.c + sign(diff.c) },
    { r = fromCellRC.r + sign(diff.r), c = fromCellRC.c },
  }
  function swap()
    moves = { moves[2], moves[1] }
  end
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
  -- Return the suggested moves.
  return { moves[1], moves[2] }
end

function sign(x)
  if x < 0 then return -1
  elseif x > 0 then return 1
  else return 0
  end
end

function list_to_set(x)
  local s = {}
  for i,v in ipairs(x) do
    s[v] = true
  end
  return s
end

function copy_table(t)
  local u = {}
  for k, v in pairs(t) do
    u[k] = v
  end
  return u
end

------------------------------------------------------------
-- GAME LOGIC: GAME EVENTS

local eventFactories = { Attack = {}, Move = {}, Pass = {}, EndTurn = {} }

function new_event(eventType, eventParams)
  local eventFactory =
    assert(eventFactories[eventType], "Invalid event type: "..eventType)
  local event = assert(eventFactory.create(eventParams))
  return event
end

function eventFactories.EndTurn.create(params)
  local event = {}
  function event.execute()
    -- TODO: Enqueue NPC turn event.
    glo.endTurn = true
    return { output = "<END OF TURN>" }
  end
  return event
end

function eventFactories.Pass.create(params)
  local event = {}
  function event.execute()
    return { output = "<PASS>" }
  end
  return event
end

function eventFactories.Attack.create(params)
  local event = { actor = params.actor, target = params.target }
  function event.execute()
    local att, tgt = event.actor, event.target
    local damage = math.random(att.cur.attack)
    tgt.cur.hp = tgt.cur.hp - damage
    if tgt.cur.hp < 0 then
      tgt.cur.hp = 0
    end
    local targetDied = (tgt.cur.hp == 0)
    if targetDied then
      kill_char(tgt)
    end
    return {
      output = string.format("%s attacks %s for %d points of damage.",
                             att.name, tgt.name, damage)
               .. (targetDied and string.format(" %s dies!", tgt.name) or "")
    , shorthand = string.format("A:%s,%s;%d", att.name, tgt.name, damage)
    }
  end
  return event
end

function eventFactories.Move.create(params)
  local event = { actor = params.actor, dest = params.dest }
  function event.execute()
    local act, dst = params.actor, params.dest
    if get_tile(dst).pass then
      move_char(act, dst)
      recenter_view()
      return {
        output = string.format("%s moves to (%d,%d).", act.name, dst.r, dst.c)
      , shorthand = string.format("M:%s;%d,%d", act.name, dst.r, dst.c)
      }
    else
      return {
        output = string.format("%s is unable to move to (%d,%d).", act.name, dst.r, dst.c)
      }
    end
  end
  return event
end

------------------------------------------------------------
-- GAME LOGIC: INIT

function load_chars(gameData)
  local NextCharID = 1
  function new_char(r, c, name)
    -- Initialize char with supplied info.
    local char = { id = NextCharID, r = r, c = c, name = name, alive = true }
    NextCharID = NextCharID + 1
    -- Get char archetype details from game data and add them to char object.
    local charArchetype =
      assert(gameData.charArchetypes[name], "Character archetype undefined: "..name)
    for k, v in pairs(charArchetype) do
      char[k] = v
    end
    -- Copy base stats to current stats.
    char.cur = {}
    for stat, statValue in pairs(char.base) do
      char.cur[stat] = statValue
    end
    return char
  end
  -- Load the chars specified by the game data.
  local chars = {}
  for i, c in ipairs(gameData.chars) do
    chars[i] = new_char(c[1], c[2], c[3])
  end
  -- Build a table from map locations to chars.
  chars.map = build_char_location_map(chars)
  return chars
end

function build_char_location_map(chars)
  local charLocationMap = {}
  for _, c in ipairs(chars) do
    local key = string.format("%d,%d", c.r, c.c)
    charLocationMap[key] = c
  end
  return charLocationMap
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
  return glo.chars.map[key]
end

function move_char(char, toCellRC)
  local oldKey = string.format("%d,%d", char.r, char.c)
  glo.chars.map[oldKey] = nil
  if toCellRC ~= nil then
    local newKey = string.format("%d,%d", toCellRC.r, toCellRC.c)
    glo.chars.map[newKey] = char
    char.r = toCellRC.r
    char.c = toCellRC.c
  end
end

function kill_char(char)
  -- TODO: drop loot
  move_char(char, nil) -- Remove char from the map.
  char.alive = false
end

function die(nTimes, nSides)
  local newDie = { times = nTimes, sides = nSides }
  function newDie.roll(self)
    local x = 0
    for i = 1, self.nTimes do
      x = x + math.random(self.nSides)
    end
    return x
  end
  return newDie
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

------------------------------------------------------------
-- GAME DATA

function load_game_data()
  return {

    map = {
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
    },

    chars = {
      { 2, 2, "Player" },
      { 4, 4, "Goblin" },
      { 8, 8, "Smurf" },
    },

    charArchetypes = {
      Player = {
        color = {0xFF,0x00,0x00},
        letter = "@",
        base = {
          hp = 100,
          speed = 50,
          attack = 50,
        },
      },
      Goblin = {
        color = {0x00,0xFF,0x00},
        letter = "G",
        base = {
          hp = 60,
          speed = 50,
          attack = 40,
          aggression = 70,
        },
      },
      Smurf = {
        color = {0x00,0x00,0xFF},
        letter = "S",
        base = {
          hp = 40,
          speed = 50,
          attack = 30,
          aggression = 30,
        },
      },
    },

  }
end

