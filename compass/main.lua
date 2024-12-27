return {get = function(bolt)
  local points = require("compass.points")
  local checkintervalmicros = 100000 -- tenth of a second
  local surfacemaybe, maybewidth, maybeheight = bolt.createsurfacefrompng("images.maybe")
  local surfacenope, nopewidth, nopeheight = bolt.createsurfacefrompng("images.nope")
  local radians180 = math.pi
  local radians360 = 2 * radians180
  local radians1 = radians180 / 180.0
  local leniency = radians1 * 5.0

  local function create (bolt)    
    local function onrender3d (this, event)
      this.renderviewproj = event:viewprojmatrix()
      this.hasrecentmatrices = true
    end

    local function onrenderbigicon (this, event)
      if event:modelcount() == 1 and event:modelvertexcount(1) == 93 then
        this.lastrendercompasspoint = true
        return
      elseif this.lastrendercompasspoint and event:modelcount() == 1 and event:modelvertexcount(1) == 42 then
        this.arrowfound = true
        local t = bolt.time()
        if t >= this.nextchecktime then
          local transform = event:modelmodelmatrix(1)
          local x1, y1, _ = bolt.point(0, 6, 0):transform(transform):get()
          local x2, y2, _ = bolt.point(0, 6, 1):transform(transform):get()
          local arrowdirection = math.atan2(y2 - y1, x2 - x1)

          for i, point in pairs(this.pointlist) do
            local lastx, _, lastz = bolt.playerposition():get()
            local xdiff = (point.x + 0.5) - (lastx / 512.0)
            local ydiff = (point.z + 0.5) - (lastz / 512.0)
            local pointdirection = math.atan2(ydiff, xdiff)
            local pointdist = math.sqrt((xdiff * xdiff) + (ydiff * ydiff))
            local anglediff = math.abs(pointdirection - arrowdirection)
            if pointdist > 0.5 and anglediff < leniency or (radians360 - anglediff) < leniency then
              print(string.format("possible target at %d,%d (%.01f away) (angle diff is %.01f)", point.x, point.z, pointdist, anglediff * 180.0 / radians180))
            end
          end

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
