local bolt = require("bolt")
bolt.checkversion(1, 0)
local scans = require("scan.main").get(bolt)
local compasses = require("compass.main").get(bolt)
local knots = require("knot.main").get(bolt)
local puzzleboxbackgroundpixels = "\x9b\x9b\x9b\xff\x9b\x9b\x9b\xff\xa3\xa3\xa3\xff\xb2\xb2\xb2\xff\xab\xab\xab\xff\x9b\x9b\x9b\xff\x9b\x9b\x9b\xff\xa3\xa3\xa3\xff\xab\xab\xab\xff\xab\xab\xab\xff\xa3\xa3\xa3\xff\xa3\xa3\xa3\xff\x9b\x9b\x9b\xff\xa3\xa3\xa3\xff\xa3\xa3\xa3\xff\x9b\x9b\x9b\xff\x9b\x9b\x9b\xff\xb2\xb2\xb2\xff\xab\xab\xab\xff\xb2\xb2\xb2\xff\xab\xab\xab\xff\xab\xab\xab\xff\xa3\xa3\xa3\xff\xab\xab\xab\xff\xab\xab\xab\xff\xb2\xb2\xb2\xff\xb2\xb2\xb2\xff\xa3\xa3\xa3\xff\xa3\xa3\xa3\xff\xa3\xa3\xa3\xff\xa3\xa3\xa3\xff\xa3\xa3\xa3\xff\xab\xab\xab\xff\xab\xab\xab\xff\xab\xab\xab\xff\xab\xab\xab\xff\xab\xab\xab\xff\xab\xab\xab\xff\xab\xab\xab\xff\xab\xab\xab\xff\xa3\xa3\xa3\xff\xab\xab\xab\xff\xa3\xa3\xa3\xff\xab\xab\xab\xff\xa8\xa7\xa8\xff\xab\xab\xab\xff\xa3\xa3\xa3\xff\xa3\xa3\xa3\xff\xa3\xa3\xa3\xff\xab\xab\xab\xff\xab\xab\xab\xff\xa3\xa3\xa3\xff\xa3\xa3\xa3\xff\x9b\x9b\x9b\xff\x93\x93\x93\xff\x9b\x9b\x9b\xff\x93\x93\x93\xff\x93\x93\x93\xff\x8b\x8b\x8b\xff\x93\x93\x93\xff\x93\x93\x93\xff\x93\x93\x93\xff\x8b\x8b\x8b\xff\x8b\x8b\x8b\xff\x84\x84\x84\xff\x84\x84\x84\xff\x8b\x8b\x8b\xff\x8b\x8b\x8b\xff\x93\x93\x93\xff\x93\x93\x93\xff\x8b\x8b\x8b\xff\x84\x84\x84\xff\x84\x84\x84\xff\x8b\x8b\x8b\xff\x8b\x8b\x8b\xff\x8b\x8b\x8b\xff\x84\x84\x84\xff\x8b\x8b\x8b\xff\x93\x93\x93\xff\xa3\xa3\xa3\xff\x9b\x9b\x9b\xff\x9b\x9b\x9b\xff\x93\x93\x93\xff\x9b\x9b\x9b\xff\x93\x93\x93\xff\x93\x93\x93\xff\x8b\x8b\x8b\xff\x8b\x8b\x8b\xff\x93\x93\x93\xff\x93\x93\x93\xff\x8b\x8b\x8b\xff\x8b\x8b\x8b\xff\x93\x93\x93\xff\x8b\x8b\x8b\xff\x93\x93\x93\xff\x93\x93\x93\xff\x8b\x8b\x8b\xff\x84\x84\x84\xff\x8b\x8b\x8b\xff\x9b\x9b\x9b\xff\x93\x93\x93\xff\x93\x93\x93\xff\x8b\x8b\x8b\xff\x8b\x8b\x8b\xff\x93\x93\x93\xff\x9b\x9b\x9b\xff\x9b\x9b\x9b\xff\x93\x93\x93\xff\x9b\x9b\x9b\xff\x9b\x9b\x9b\xff\xa3\xa3\xa3\xff\xab\xab\xab\xff\xa3\xa3\xa3\xff\xa3\xa3\xa3\xff\xa8\xa7\xa8\xff\xab\xab\xab\xff\xab\xab\xab\xff\xb2\xb2\xb2\xff\xb2\xb2\xb2\xff\xb2\xb2\xb2\xff\xb2\xb2\xb2\xff\xbb\xba\xbb\xff\xbb\xba\xbb\xff\xc2\xc2\xc2\xff\xb2\xb2\xb2\xff\x9b\x9b\x9b\xff\xa3\xa3\xa3\xff\x9b\x9b\x9b\xff"

local validitygraceperiod = 300000 -- half a game tick
local lastvalid
local currentobject = nil

local lastrenderscroll = false
local lastrendercompasspoint = false

local function setobject (obj)
  lastvalid = bolt.time()
  currentobject = obj
end

bolt.onrendericon(function (event)
  if currentobject and currentobject.onrendericon then
    currentobject:onrendericon(event)
  end
end)

bolt.onrenderbigicon(function (event)
  if currentobject then
    if currentobject.onrenderbigicon then
      currentobject:onrenderbigicon(event)
    end
    return
  end

  if not lastrenderscroll and event:modelcount() == 1 and event:modelvertexcount(1) == 552 then
    -- the scroll object shown in the "minigames" UI element for some clue types
    local x0, y0, z0 = event:modelvertexpoint(1, 1):get()
    if x0 == -317 and y0 == 220 and z0 == 611 then
      lastrenderscroll = true
    end
  elseif lastrenderscroll and event:modelcount() == 1 and event:modelvertexcount(1) == 93 then
    -- compass point, drawn usually immediately after the scroll object above
    lastrendercompasspoint = true
    lastrenderscroll = false
  elseif lastrendercompasspoint and event:modelcount() == 1 and event:modelvertexcount(1) == 42 then
    -- compass clue arrow
    lastrendercompasspoint = false
    setobject(compasses.create(bolt))
  end
end)

bolt.onrender2d(function (event)
  if currentobject and currentobject.onrender2d then
    currentobject:onrender2d(event)
  end

  if lastrenderscroll then
    -- text on top of a scroll object in the UI
    local object = scans.trycreate(bolt, event)
    if object then setobject(object) end
    lastrenderscroll = false
    return
  end

  if currentobject then return end

  local vertexcount = event:vertexcount()
  local verticesperimage = event:verticesperimage()
  for i = 1, vertexcount, verticesperimage do
    local ax, ay, aw, ah, _, _ = event:vertexatlasdetails(i)
    if aw == 128 and ah == 128 and vertexcount >= i + 11 and event:texturecompare(ax, ay, puzzleboxbackgroundpixels) then
      -- puzzle box background
      local x2, y2 = event:vertexxy(i)
      local x, y = event:vertexxy(i + 2)
      if vertexcount >= i + (2 * verticesperimage) - 1 and knots.vertexisknotarrow(event, i + verticesperimage) then
        setobject(knots.create(event, i + verticesperimage, x, y, x2, y2))
      end
      break
    end
  end
end)

bolt.onrender3d(function (event)
  if currentobject and currentobject.onrender3d then
    currentobject:onrender3d(event)
  end
end)

bolt.onminimapterrain(function (event)
  if currentobject and currentobject.onminimapterrain then
    currentobject:onminimapterrain(event)
  end
end)

bolt.onswapbuffers(function (event)
  lastrenderscroll = false
  lastrendercompasspoint = false
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
