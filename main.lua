
local inspect = require('inspect')

function love.load()
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
  glo.cellW = 50
  glo.cellH = 50
  glo.rooms = {
    { 2,2,2,2,2,2,2,2,2,2,2 },
    { 2,1,1,1,1,1,1,1,1,1,2 },
    { 2,1,1,1,1,1,1,1,1,1,2 },
    { 2,1,1,1,1,1,1,1,1,1,2 },
    { 2,1,1,1,1,1,1,1,1,1,2 },
    { 2,1,1,1,1,1,1,1,1,1,2 },
    { 2,1,1,1,1,1,1,1,1,1,2 },
    { 2,1,1,1,1,1,1,1,1,1,2 },
    { 2,2,2,2,2,2,2,2,2,2,2 },
  }
  local t, f = true, false
  glo.tiles = {
    { name="floor", pass=t, color={ 0x20,0x20,0x20,0xFF } },
    { name="wall",  pass=f, color={ 0xFF,0xFF,0xFF,0xFF } },
  }
  for id, tile in ipairs(glo.tiles) do
    tile.id = id
  end
  glo.viewX = 0
  glo.viewY = 0
end

function love.keypressed(k)
  if k == 'escape' or k == 'q' then
    love.event.quit()
  end
end

function love.mousepressed(x, y, button, istouch)
  if button == 1 then
    --advance()
  elseif button == 2 then
    -- Center at mouse click
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    glo.viewX = glo.viewX + (x - screenW / 2)
    glo.viewY = glo.viewY + (y - screenH / 2)
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
  for ri, rv in ipairs(glo.rooms) do
    local y = ri * glo.cellH
    for ci, cv in ipairs(rv) do
      local x = ci * glo.cellW
      tile = glo.tiles[cv]
      love.graphics.setColor(tile.color)
      love.graphics.rectangle("fill",
        x - glo.viewX, y - glo.viewY,
        glo.cellW, glo.cellH)
    end
  end
end

