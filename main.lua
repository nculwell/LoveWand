
local inspect = require('inspect')
local glo = {}

local CHAR_SIZE = 0.8

function love.load()
  local FONT_SIZE = 24
  local INFO_PANE_H = 200
  local VISIBLE_MARGIN_CELLS = 3
  math.randomseed(1)
  -- Init global state
  glo.quitting = 0
  --local screenW = 1280
  --local screenH = 720
  -- Init video.
  --modeFlags = {fullscreen=true, fullscreentype="desktop"}
  --love.window.setMode(screenW, screenH, modeFlags)
  -- Set up the room
  local screenSz = { w = love.graphics.getWidth(),
                     h = love.graphics.getHeight() }
  glo.cellW = 50
  glo.cellH = 50
  glo.rooms = {
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
    { 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 },
  }
  local t, f = true, false
  glo.tiles = {
    { name="wall",  pass=f, color={0xFF,0xFF,0xFF} },
    { name="floor", pass=t, color={0x40,0x40,0x40} },
    { name="grass", pass=t, color={0x20,0x80,0x20} },
    { name="water", pass=f, color={0x20,0x20,0x80} },
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
  glo.chars = {
    { r=2, c=2, color={0xFF,0x00,0x00}, name = "player" },
    { r=4, c=4, color={0x00,0xFF,0x00}, name = "goblin" },
    { r=8, c=8, color={0x00,0x00,0xFF}, name = "smurf" },
  }
  set_list_ids(glo.chars)
  glo.char_pos = {}
  for i, c in ipairs(glo.chars) do
    local key = string.format("%d,%d", c.r, c.c)
    glo.char_pos[key] = c
  end
  glo.player = glo.chars[1]
  glo.infoFont = love.graphics.setNewFont(FONT_SIZE)
  -- Ensure that we don't start up with the view over in one corner.
  recenter_view()
end

function set_list_ids(list)
  for id, item in ipairs(list) do
    item.id = id
  end
end

function draw_char(cellX, cellY, color)
  love.graphics.setColor(color)
  local charW = math.floor(glo.cellW * CHAR_SIZE)
  local charH = math.floor(glo.cellH * CHAR_SIZE)
  local charRelX = math.floor((glo.cellW - charW) / 2)
  local charRelY = math.floor((glo.cellH - charH) / 2)
  local charEffX = cellX + charRelX
  local charEffY = cellY + charRelY
  love.graphics.rectangle("fill", charEffX, charEffY, charW, charH)
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
  --for i, char in ipairs(glo.chars) do
  --  if char.r == cellRC.r and char.c == cellRC.c then
  --    return char
  --  end
  --end
  --return nil
end

function move_char(char, toCellRC)
  local oldKey = string.format("%d,%d", char.r, char.c)
  local newKey = string.format("%d,%d", toCellRC.r, toCellRC.c)
  glo.char_pos[oldKey] = nil
  glo.char_pos[newKey] = char
  char.r = toCellRC.r
  char.c = toCellRC.c
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
  elseif arrow_keys[k] then
    dest = { r = glo.player.r, c = glo.player.c }
    if     k == "left"  then dest.c = dest.c - 1
    elseif k == "right" then dest.c = dest.c + 1
    elseif k == "up"    then dest.r = dest.r - 1
    elseif k == "down"  then dest.r = dest.r + 1
    end
    if get_tile(dest).pass and not get_char(dest) then
      move_char(glo.player, dest)
      recenter_view()
    end
  end
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
  print('(RECENTER)')
  dump(playerVisibleBox)
  dump(glo.view)
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
  dump(glo.view)
end

function love.mousepressed(x, y, button, istouch)
  if button == 1 then
    --advance()
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
  displayText[1] = string.format(
    "View: (%d,%d) MouseAbs (%d,%d) MousePos (%d,%d)",
    glo.view.x, glo.view.y, mouseAbs.x, mouseAbs.y, love.mouse.getX(), love.mouse.getY())
  if mouseCell.tile then displayText[2] = string.format("Cell r%d c%d: %s", mouseCell.r, mouseCell.c, mouseCell.tile.name)
  else displayText[2] = string.format("Cell r%d c%d: ---", mouseCell.r, mouseCell.c)
  end
  local charName = "---"
  local charUnderMouse = get_char(mouseCell)
  if charUnderMouse then charName = charUnderMouse.name end
  displayText[3] = string.format("Char: %s", charName)
end

function love.draw()
  local glo = glo
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  love.graphics.reset()
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.setBlendMode("alpha")
  --love.graphics.setBlendMode("alpha", "premultiplied")

  -- Draw the map
  for ri, rv in ipairs(glo.rooms) do
    local y = ri * glo.cellH
    for ci, cv in ipairs(rv) do
      local x = ci * glo.cellW
      tile = glo.tiles[cv]
      love.graphics.setColor(tile.color)
      local effectiveX, effectiveY = x - glo.view.x, y - glo.view.y
      love.graphics.rectangle("fill",
        effectiveX, effectiveY,
        glo.cellW, glo.cellH)
      local charHere = get_char({r=ri,c=ci})
      if charHere then
        draw_char(effectiveX, effectiveY, charHere.color)
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

--------------------
-- UTILITY FUNCTIONS

function dump(x)
  print(inspect(x))
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

