
local inspect = require('inspect')

function love.load()
  local FONT_SIZE = 24
  math.randomseed(1)
  glo = {}
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
    { 1,1,1,1,1,1,1,1,1,1,1 },
    { 1,2,2,2,2,2,2,4,4,4,1 },
    { 1,2,2,2,2,2,2,4,4,4,1 },
    { 1,2,2,2,2,2,2,2,4,4,1 },
    { 1,2,2,2,2,2,2,2,2,4,1 },
    { 1,2,2,2,2,2,2,3,3,3,1 },
    { 1,2,2,2,2,2,3,3,3,3,1 },
    { 1,2,2,2,2,2,3,3,3,2,1 },
    { 1,1,1,1,1,1,1,1,1,1,1 },
  }
  local t, f = true, false
  glo.tiles = {
    { name="wall",  pass=f, color={ 0xFF,0xFF,0xFF,0xFF } },
    { name="floor", pass=t, color={ 0x20,0x20,0x20,0xFF } },
    { name="grass", pass=t, color={ 0x20,0xFF,0x20,0xFF } },
    { name="water", pass=f, color={ 0x20,0x20,0xFF,0xFF } },
  }
  for id, tile in ipairs(glo.tiles) do
    tile.id = id
  end
  glo.viewX = 0
  glo.viewY = 0
  glo.player = { r=2, c=2 }
  glo.infoFont = love.graphics.setNewFont(FONT_SIZE)
end

function draw_char(cellX, cellY, color)
  love.graphics.setColor(color)
  local charW = math.floor(glo.cellW / 2)
  local charH = math.floor(glo.cellH / 2)
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

function list_to_set(x)
  local s = {}
  for i,v in ipairs(x) do
    s[v] = true
  end
  return s
end

function love.keypressed(k)
  local arrows = list_to_set({ "up", "down", "right", "left" })
  if k == "escape" or k == "q" then
    love.event.quit()
  elseif arrows[k] then
    dest = { r = glo.player.r, c = glo.player.c }
    if     k == "left"  then dest.c = dest.c - 1
    elseif k == "right" then dest.c = dest.c + 1
    elseif k == "up"    then dest.r = dest.r - 1
    elseif k == "down"  then dest.r = dest.r + 1
    end
    if get_tile(dest).pass then
      glo.player = dest
      -- TODO: Recenter view if near edge.
    end
  end
end

function love.mousepressed(x, y, button, istouch)
  if button == 1 then
    --advance()
  elseif button == 2 then
    -- Center at mouse click
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    glo.viewX = glo.viewX + (x - math.floor(screenW / 2))
    glo.viewY = glo.viewY + (y - math.floor(screenH / 2))
  end
end

function love.quit()
  -- Return true here to abort quit.
  return false
end

function love.update()
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
      local effectiveX, effectiveY = x - glo.viewX, y - glo.viewY
      love.graphics.rectangle("fill",
        effectiveX, effectiveY,
        glo.cellW, glo.cellH)
      if ri == glo.player.r and ci == glo.player.c then
        draw_char(effectiveX, effectiveY, {0xFF,0x00,0x00,0xFF})
      end
    end
  end

  -- Compose info
  local mouseAbs = {
    x = love.mouse.getX() + glo.viewX,
    y = love.mouse.getY() + glo.viewY
  }
  local mouseCell = {
    r = math.floor(mouseAbs.y / glo.cellH),
    c = math.floor(mouseAbs.x / glo.cellW),
    tile = nil
  }
  mouseCell.tile = get_tile(mouseCell)
  local mouseInfo = string.format(
    "MouseAbs (%d,%d) MousePos (%d,%d)",
    mouseAbs.x, mouseAbs.y, love.mouse.getX(), love.mouse.getY())
  local tileInfo = ""
  if mouseCell.tile then tileInfo = string.format("Cell r%d c%d: %s", mouseCell.r, mouseCell.c, mouseCell.tile.name)
  else tileInfo = string.format("Cell r%d c%d: <NONE>", mouseCell.r, mouseCell.c)
  end
  local viewInfo = string.format("View: (%d,%d)", glo.viewX, glo.viewY)

  -- Display info
  local infoPaneTop = screenH - 200
  love.graphics.setFont(glo.infoFont)
  love.graphics.setColor({ 0,0,0,0xFF })
  love.graphics.rectangle("fill", 0, infoPaneTop, screenW, 200)
  love.graphics.setColor({ 0xFF,0xFF,0xFF,0xFF })
  local lineInfo = { x = 50, y = infoPaneTop + 50,
                     lineSkip = 1.2 * glo.infoFont:getHeight() }
  function println(text)
    love.graphics.print(text, lineInfo.x, lineInfo.y)
    lineInfo.y = lineInfo.y + lineInfo.lineSkip
  end
  println(mouseInfo, lineInfo)
  println(tileInfo, lineInfo)
  println(viewInfo, lineInfo)
end

