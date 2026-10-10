--!strict
-- Dense occupancy is an inexpensive temporary *sampling mask*, not voxel Parts.
-- No interior geometry is built or retained after meshing.
local Config = require(script.Parent.Config)
local Field = {}
Field.__index = Field

local function index(x: number, y: number, z: number, count: number): number
    return (x * count + y) * count + z
end

-- Three layers of deterministic 3D noise sampled in unit-sphere direction,
-- so color wraps around the planet seamlessly (no polar/equirectangular seam).
local function materialAt(nx: number, ny: number, nz: number, sx: number, sy: number, sz: number): number
    local broad = math.noise(
        nx * Config.ColorNoiseScale + sx,
        ny * Config.ColorNoiseScale + sy,
        nz * Config.ColorNoiseScale + sz
    )
    local detail = math.noise(
        nx * Config.ColorNoiseDetailScale + sx * 1.7,
        ny * Config.ColorNoiseDetailScale + sy * 1.7,
        nz * Config.ColorNoiseDetailScale + sz * 1.7
    )
    local micro = math.noise(
        nx * Config.ColorNoiseMicroScale + sx * 2.3,
        ny * Config.ColorNoiseMicroScale + sy * 2.3,
        nz * Config.ColorNoiseMicroScale + sz * 2.3
    )

    local value = math.clamp(0.5 + broad * 0.22 + detail * 0.10 + micro * 0.04, 0, 0.9999)
    return math.clamp(math.floor(value * #Config.Palette) + 1, 1, #Config.Palette)
end

function Field.new(seed: number, voxelSize: number, cancelled: (() -> boolean)?)
    local count = math.floor(Config.SamplingDiameter / voxelSize + 0.5)
    assert(math.abs(count * voxelSize - Config.SamplingDiameter) < 0.000001,
        "Cell size must exactly divide the sampling extent")

    local self = setmetatable({
        Count = count,
        VoxelSize = voxelSize,
        Seed = seed,
        Occupied = buffer.create(count * count * count),
        Materials = buffer.create(count * count * count),
        Surface = nil,
        Samples = 0,
        Filled = 0,
    }, Field)

    local radius = Config.Diameter * 0.5
    local radius2 = radius * radius
    -- Only sample color near the surface; deep interior never renders.
    local shellRadius = math.max(0, radius - voxelSize * 2)
    local shellRadius2 = shellRadius * shellRadius
    local sx = (seed % 1297) * 0.093 + 11.3
    local sy = (seed % 2143) * 0.071 + 48.1
    local sz = (seed % 3187) * 0.051 + 99.7

    for x = 0, count - 1 do
        local px = (x + 0.5) * voxelSize - Config.SamplingDiameter * 0.5
        for y = 0, count - 1 do
            local py = (y + 0.5) * voxelSize - Config.SamplingDiameter * 0.5
            for z = 0, count - 1 do
                local pz = (z + 0.5) * voxelSize - Config.SamplingDiameter * 0.5
                local distance2 = px * px + py * py + pz * pz
                -- Geometry depends ONLY on distance, never on noise or seed.
                local solid = distance2 <= radius2
                local offset = index(x, y, z, count)
                if solid then
                    buffer.writeu8(self.Occupied, offset, 1)
                    -- Project grayscale noise onto unit-sphere direction.
                    -- Every visible cube (including stepped side faces) gets a
                    -- color, while buried cells retain the default white.
                    if distance2 >= shellRadius2 then
                        local magnitude = math.sqrt(distance2)
                        local nx, ny, nz = px / magnitude, py / magnitude, pz / magnitude
                        buffer.writeu8(self.Materials, offset, materialAt(nx, ny, nz, sx, sy, sz))
                    else
                        buffer.writeu8(self.Materials, offset, 1)
                    end
                    self.Filled += 1
                end
                self.Samples += 1
            end
        end
        -- Yield during high resolution passes; the initial volume is 128^3.
        if x % 4 == 3 then
            if cancelled and cancelled() then error("GENERATION_CANCELLED", 0) end
            task.wait()
        end
    end
    return self
end


-- Exposed cubes make up a one-cell-thick *solid* outer shell.
-- This is prepared only for the Parts fallback; the mesh path goes directly
-- from occupancy to surface triangles and uses no extra surface buffer.
function Field:prepareSurface(cancelled: (() -> boolean)?)
    local n = self.Count
    local size = self.VoxelSize
    local half = Config.SamplingDiameter * 0.5
    local inner = math.max(0, Config.MinSurfaceRadius - size * 2)
    local outer = Config.MaxSurfaceRadius + size * 2
    local inner2, outer2 = inner * inner, outer * outer
    local exposed = buffer.create(n * n * n)
    local surfaceCount = 0

    for x = 0, n - 1 do
        local px = (x + 0.5) * size - half
        for y = 0, n - 1 do
            local py = (y + 0.5) * size - half
            for z = 0, n - 1 do
                local pz = (z + 0.5) * size - half
                local distance2 = px * px + py * py + pz * pz
                if distance2 >= inner2 and distance2 <= outer2
                    and self:isSolid(x, y, z)
                    and (not self:isSolid(x - 1, y, z) or not self:isSolid(x + 1, y, z)
                        or not self:isSolid(x, y - 1, z) or not self:isSolid(x, y + 1, z)
                        or not self:isSolid(x, y, z - 1) or not self:isSolid(x, y, z + 1)) then
                    buffer.writeu8(exposed, index(x, y, z, n), 1)
                    surfaceCount += 1
                end
            end
        end
        if x % 4 == 3 then
            if cancelled and cancelled() then error("GENERATION_CANCELLED", 0) end
            task.wait()
        end
    end

    self.Surface = exposed
    self.SurfaceCubes = surfaceCount
end

function Field:isSurface(x: number, y: number, z: number): boolean
    if x < 0 or y < 0 or z < 0 or x >= self.Count or y >= self.Count or z >= self.Count then return false end
    return buffer.readu8(self.Surface, index(x, y, z, self.Count)) == 1
end

function Field:isSolid(x: number, y: number, z: number): boolean
    local n = self.Count
    if x < 0 or y < 0 or z < 0 or x >= n or y >= n or z >= n then return false end
    return buffer.readu8(self.Occupied, index(x, y, z, n)) == 1
end

function Field:material(x: number, y: number, z: number): number
    return buffer.readu8(self.Materials, index(x, y, z, self.Count))
end

return Field
