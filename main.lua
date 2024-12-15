local bolt = require("bolt")
bolt.checkversion(1, 0)
local scans = require("scan.main").get(bolt)

local validitygraceperiod = 300000 -- half a game tick
local lastvalid
local currentobject = nil

local function setobject (obj)
  lastvalid = bolt.time()
  currentobject = obj
end

bolt.onrenderbigicon(function (event)
  if currentobject then
    if currentobject.onrenderbigicon then
      currentobject:onrenderbigicon(event)
    end
    return
  end
  if event:modelcount() ~= 1 then return end
  if event:modelvertexcount(1) ~= 552 then return end
  local x0, y0, z0 = event:modelvertexpoint(1, 1):get()
  if x0 ~= -317 or y0 ~= 220 or z0 ~= 611 then return end
  setobject(scans.create(bolt, "ardougne")) -- todo: actually read the text on the scroll using an onrender2d event
  -- or alternatively, if the next event is a 93-vertex bigicon followed by a 42-vertex bigicon, the 42 is an arrow of a
  -- compass clue, and the direction from (0,6,0) to (0,6,1) after model matrix should(?) give the direction it's pointing.
end)

bolt.onrender3d(function (event)
  if currentobject and currentobject.onrender3d then
    currentobject:onrender3d(event)
  end
end)

bolt.onswapbuffers(function (event)
  if not currentobject then return end
  if currentobject.onswapbuffers then
    currentobject:onswapbuffers(event)
  end
  local t = bolt.time()
  if currentobject:valid() then
    lastvalid = t
  elseif t > (lastvalid + validitygraceperiod) then
    currentobject = nil
  end
end)
