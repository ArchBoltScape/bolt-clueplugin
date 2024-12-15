return {get = function(bolt)
  local points = require("scan.points")

  local vs = bolt.createvertexshader(
    "layout(location=0) in highp vec2 pos;"..
    "out highp vec2 vpos;"..
    "void main() {"..
      "vpos = pos;"..
      "gl_Position = vec4(pos, 0.0, 1.0);"..
    "}"
  )
  local fs = bolt.createfragmentshader(
    "in highp vec2 vpos;"..
    "out highp vec4 col;"..
    "layout(location=0) uniform float factor;"..
    "void main() {"..
      "float angle = (atan(vpos.y, vpos.x) / radians(360)) + 0.25;"..
      "angle = mix(angle + 1.0, angle, step(0.0, angle));"..
      "float distfactor = 1.0 - ((abs(1.0 - (length(vpos) / 0.85)) * 25.0) - 1.5);"..
      "float anglefactor = step(angle, clamp(factor, 0.0, 1.0));"..
      "col = vec4(74.0 / 255.0, 1.0, 80.0 / 255.0, distfactor * anglefactor);"..
    "}"
  )
  local program = bolt.createshaderprogram(vs, fs)
  -- triangle 1: (-1,-1), (1,-1), (1,1)
  -- triangle 2: (-1,-1), (1,1), (-1,1)
  local shaderbuffer = bolt.createshaderbuffer("\xFF\xFF\x01\xFF\x01\x01\xFF\xFF\x01\x01\xFF\x01")
  -- layout(location=0), width of each number is 1, they're signed, they're not floats, there are 2 per attribute
  -- (because it's a vec2), offset from the start is 0 bytes, and stride between each attribute is 2 bytes.
  program:setattribute(0, 1, true, false, 2, 0, 2)

  local checkinvertalmicros = 100000 -- a tenth of a second
  local statechangegraceperiod = 1200000 -- two game ticks
  local zeropoint = bolt.point(0, 0, 0)
  local surfacemaybe, maybewidth, maybeheight = bolt.createsurfacefrompng("images.maybe")
  local surfacenope, nopewidth, nopeheight = bolt.createsurfacefrompng("images.nope")

  -- checks if the first vertex's model position matches the one shared by all 3 ring models.
  -- assumes there is at least one vertex
  local function modelmatchesrings (event)
    local x, y, z = event:vertexpoint(1):get()
    return x == 220 and y == 36 and z == 128
  end

  local vertexcases3d = {
    [576] = 1,
    [864] = 2,
    [1728] = 3,
  }

  return {create = function (bolt, location)
    pointlist, scanrange = points.get(location)
    surfacenope:setalpha(0.75)
    return {
      modelfound = false,
      renderviewproj = nil,
      lastringx = nil,
      lastringz = nil,
      checkframe = false,
      nextchecktime = bolt.time(),
      pointlist = pointlist,
      scanrange = scanrange,
      surfacemaybeloading = bolt.createsurface(maybewidth, maybeheight),

      onrender3d = function (this, event)
        local vertexcount = event:vertexcount()
        local modeltype = vertexcases3d[vertexcount]
        if modeltype then
          if not modelmatchesrings(event) then return end
          this.renderviewproj = event:viewprojmatrix()
          this.modelfound = true
          if not this.checkframe then return end
    
          surfacemaybe:setalpha((modeltype == 3) and 0.8 or 1)
          local ringworldpoint = zeropoint:transform(event:modelmatrix())
          local x, y, z = ringworldpoint:get()
          this.lastringx = x / 512.0
          this.lastringz = z / 512.0
          local time = bolt.time()
          
          for i, point in pairs(this.pointlist) do
            local dist = math.max(math.abs(point.x + 0.5 - this.lastringx), math.abs(point.z + 0.5 - this.lastringz))
            local disttype -- number of rings we'd expect to have right now if this was the correct dig spot
            if dist <= (this.scanrange + 0.5) then
              disttype = 3
            elseif dist <= ((this.scanrange * 2) + 0.5) then
              disttype = 2
            else
              disttype = 1
            end
            -- checking for state changes, states are as follows:
            -- -1: eliminated
            -- 0:  one-ring distance, one-ring model
            -- 1:  two-ring distance, two-ring model
            -- 2:  three-ring distance, three-ring model
            -- 3:  point is closer than model suggests
            -- 4:  point is further than model suggests
            if (point.state < 0) then goto continue end
            local state = ({
              [1] = {
                [1] = 0,
                [2] = 4,
                [3] = 4,
              },
              [2] = {
                [1] = 3,
                [2] = 1,
                [3] = 4,
              },
              [3] = {
                [1] = 3,
                [2] = 3,
                [3] = 2,
              },
            })[disttype][modeltype]
            if point.state ~= state then
              point.state = state
              point.laststatechange = time
            elseif (state >= 3) and (time - point.laststatechange >= statechangegraceperiod) then
              point.state = -1
              point.laststatechange = time
            end
            ::continue::
          end
        end
      end,

      onswapbuffers = function (this, event)
        local t = bolt.time()
        if this.checkframe then
          this.modelfound = false
          this.checkframe = false
        else
          if t >= this.nextchecktime then
            this.checkframe = true
            this.nextchecktime = this.nextchecktime + checkinvertalmicros
            if this.nextchecktime < t then
              -- prevents us from falling behind and doing loads of checks in a row while
              -- nextchecktime catches up to the real time
              this.nextchecktime = t
            end
          end
        end

        if not this.renderviewproj then return end

        local gx, gy, gw, gh = bolt.gameviewxywh()
        for i, point in pairs(this.pointlist) do
          local p = bolt.point((point.x + 0.5) * 512.0, point.y, (point.z + 0.5) * 512.0)
          local px, py, pdist = p:transform(this.renderviewproj):aspixels()
          if pdist > 0.0 and pdist <= 1.0 and px >= gx and py >= gy and px <= (gx + gw) and py <= (gy + gh) then
            if point.state < 0 then
              -- eliminated point
              local scale = 0.6
              local imgradius = 16 * scale
              local imgsize = 32 * scale
              surfacenope:drawtoscreen(0, 0, nopewidth, nopeheight, px - imgradius, py - imgradius, imgsize, imgsize)
            elseif (point.state == 1 or point.state == 2 or point.state == 3) and (t - point.laststatechange) <= (statechangegraceperiod * 1.5) then
              -- "loading" point
              local scale = 1
              local imgradius = 16 * scale
              local imgsize = 32 * scale
              this.surfacemaybeloading:clear()
              surfacemaybe:drawtosurface(this.surfacemaybeloading, 0, 0, maybewidth, maybeheight, 0, 0, maybewidth, maybeheight)
              program:setuniform1f(0, (t - point.laststatechange) / statechangegraceperiod)
              program:drawtosurface(this.surfacemaybeloading, shaderbuffer, 6)
              this.surfacemaybeloading:drawtoscreen(0, 0, maybewidth, maybeheight, px - imgradius, py - imgradius, imgsize, imgsize)
            else
              -- normal non-eliminated point
              scale = 0.75
              local imgradius = 16 * scale
              local imgsize = 32 * scale
              surfacemaybe:drawtoscreen(0, 0, maybewidth, maybeheight, px - imgradius, py - imgradius, imgsize, imgsize)
            end
          end
        end
      end,

      valid = function (this)
        return this.modelfound
      end
    }
  end}
end}
