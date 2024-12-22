return {get = function(bolt)
  local points = require("compass.points")
  local checkintervalmicros = 100000 -- tenth of a second
  local surfacemaybe, maybewidth, maybeheight = bolt.createsurfacefrompng("images.maybe")
  local surfacenope, nopewidth, nopeheight = bolt.createsurfacefrompng("images.nope")

  local function create (bolt)    
    local function onrender3d (this, event)
      this.renderviewproj = event:viewprojmatrix()
      this.hasrecentmatrices = true
    end

    local function onminimapterrain (this, event)
      local x, y = event:position()
      this.lastx = x
      this.lasty = y
      this.hasrecentposition = true
    end

    local function onrenderbigicon (this, event)
      if event:modelcount() == 1 and event:modelvertexcount(1) == 93 then
        this.lastrendercompasspoint = true
        return
      elseif this.lastrendercompasspoint and this.hasrecentposition and event:modelcount() == 1 and event:modelvertexcount(1) == 42 then
        this.arrowfound = true
        local t = bolt.time()
        if t >= this.nextchecktime then
          local transform = event:modelmodelmatrix(1)
          local x1, y1, _ = bolt.point(0, 6, 0):transform(transform):get()
          local x2, y2, _ = bolt.point(0, 6, 1):transform(transform):get()
          local arrowdirection = math.atan2(y2 - y1, x2 - x1)

          for i, point in pairs(this.pointlist) do
            local xdiff = (point.x + 0.5) - (this.lastx / 512.0)
            local ydiff = (point.z + 0.5) - (this.lasty / 512.0)
            local pointdirection = math.atan2(ydiff, xdiff)
            local pointdist = math.sqrt((xdiff * xdiff) + (ydiff * ydiff))
            -- 0.5236 radians is around 30 degrees, and 0.02 radians is a little over 1 degree
            if pointdist > 0.5 and math.abs(pointdirection - arrowdirection) < ((0.5236 / pointdist) + 0.02) then
              -- todo: probably don't do this based on minimap center, it's really inaccurate
              print(string.format("possible target at %d,%d (%.01f away)", point.x, point.z, pointdist))
            end
          end

          --print(string.format("angle: %.02f", (math.pi - arrowdirection) * 180.0 / math.pi))

          this.nextchecktime = this.nextchecktime + checkintervalmicros
          if this.nextchecktime < t then
            this.nextchecktime = t
          end
        end
      end
      this.lastrendercompasspoint = false
    end

    local function onswapbuffers (this, event)
      if this.hasrecentmatrices then
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
            else
              -- normal non-eliminated point
              scale = 0.75
              local imgradius = 16 * scale
              local imgsize = 32 * scale
              surfacemaybe:drawtoscreen(0, 0, maybewidth, maybeheight, px - imgradius, py - imgradius, imgsize, imgsize)
            end
          end
        end
      end

      this.hasrecentposition = false
      this.hasrecentmatrices = false
      this.renderviewproj = nil
      this.lastrendercompasspoint = false
      this.arrowfoundpreviousframe = this.arrowfound
      this.arrowfound = false
    end

    local function valid (this)
      return this.arrowfoundpreviousframe
    end

    return {
      pointlist = points.get(),
      nextchecktime = bolt.time(),
      hasrecentposition = false,
      hasrecentmatrices = false,
      lastrendercompasspoint = false,
      arrowfound = false,
      arrowfoundpreviousframe = false,

      onrender3d = onrender3d,
      onminimapterrain = onminimapterrain,
      onrenderbigicon = onrenderbigicon,
      onswapbuffers = onswapbuffers,
      valid = valid,
    }
  end
  return {create = create}
end}
