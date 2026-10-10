--!strict
-- High-resolution sphere without allocating or scanning 256^3 interior voxels.
-- Occupancy is exact and analytic. Noise is sampled only on visible surfaces.
-- 256^3 is a logical grid; the renderer visits surface-intersecting chunks.
local Config = require(script.Parent.Config)
local Field = {}
Field.__index = Field

local function index(x: number, y: number, z: number, count: number): number
    return (x * count + y) * count + z
end

local function materialAt(nx: number, ny: number, nz: number, sx: number, sy: number, sz: number): number
    local height = math.noise(
        nx * Config.ColorNoiseScale + sx,
        ny * Config.ColorNoiseScale + sy,
        nz * Config.ColorNoiseScale + sz
    )
    local height01 = math.clamp(0.5 + height * Config.ColorNoiseContrast, 0, 1)
    return math.clamp(math.floor(height01 * (#Config.Palette - 1) + 0.5) + 1, 1, #Config.Palette)
end

function Field.new(seed: number, voxelSize: number, _cancelled: (() -> boolean)?)
    local n = math.floor(Config.SamplingDiameter / voxelSize + 0.5)
    assert(math.abs(n * voxelSize - Config.SamplingDiameter) < 0.000001,
        "Voxel size must divide sampling diameter")
    local half = Config.SamplingDiameter * 0.5
    local positions = table.create(n)
    local squared = table.create(n)
    for i = 0, n - 1 do
        local v = (i + 0.5) * voxelSize - half
        positions[i + 1] = v
        squared[i + 1] = v * v
    end
    local radius = Config.Diameter * 0.5

    return setmetatable({
        Count = n,
        VoxelSize = voxelSize,
        Seed = seed,
        Positions = positions,
        Squared = squared,
        Radius2 = radius * radius,
        ShellRadius2 = math.max(0, radius - voxelSize * 2) ^ 2,
        SX = (seed % 1297) * 0.093 + 11.3,
        SY = (seed % 2143) * 0.071 + 48.1,
        SZ = (seed % 3187) * 0.051 + 99.7,
        Surface = nil,
        SurfaceCubes = 0,
        -- Logical resolution, not the number of voxels instantiated.
        Samples = n * n * n,
    }, Field)
end

function Field:isSolid(x: number, y: number, z: number): boolean
    local n = self.Count
    if x < 0 or y < 0 or z < 0 or x >= n or y >= n or z >= n then
        return false
    end
    local s = self.Squared
    return s[x + 1] + s[y + 1] + s[z + 1] <= self.Radius2
end

function Field:material(x: number, y: number, z: number): number
    local s = self.Squared
    local d2 = s[x + 1] + s[y + 1] + s[z + 1]
    if d2 <= self.ShellRadius2 then return 1 end
    local inv = 1 / math.sqrt(d2)
    local p = self.Positions
    return materialAt(
        p[x + 1] * inv, p[y + 1] * inv, p[z + 1] * inv,
        self.SX, self.SY, self.SZ
    )
end

-- Reject whole 32^3 chunks where even the one-cell neighbor halo cannot
-- intersect the sphere boundary. This skips most of the 16.8M logical grid.
function Field:chunkMightHaveSurface(first, last): boolean
    local n = self.Count
    local pos = self.Positions
    local nearest, farthest = 0, 0
    for axis = 1, 3 do
        local low = pos[math.max(0, first[axis] - 1) + 1]
        local high = pos[math.min(n - 1, last[axis]) + 1]
        local small = if low > 0 then low elseif high < 0 then -high else 0
        local big = math.max(math.abs(low), math.abs(high))
        nearest += small * small
        farthest += big * big
    end
    return nearest <= self.Radius2 and farthest >= self.Radius2
end

-- Parts fallback only: store a bit for each exposed *solid* cube.
-- Scan two thin radial bands for each XY column, not the entire interior.
function Field:prepareSurface(cancelled: (() -> boolean)?)
    local n = self.Count
    local axis = self.Positions
    local squares = self.Squared
    local half = Config.SamplingDiameter * 0.5
    local size = self.VoxelSize
    local shellInner = math.max(0, Config.Diameter * 0.5 - size * 2)
    local inner2 = shellInner * shellInner
    local outer = Config.Diameter * 0.5 + size * 2
    local outer2 = outer * outer
    local exposed = buffer.create(n * n * n)
    local surfaceCubes = 0

    local function markBand(x, y, bottom, top)
        local first = math.max(0, math.ceil((bottom + half) / size - 0.5))
        local last = math.min(n - 1, math.floor((top + half) / size - 0.5))
        for z = first, last do
            local d2 = squares[x + 1] + squares[y + 1] + squares[z + 1]
            if d2 >= inner2 and d2 <= outer2 and self:isSolid(x, y, z)
                and (not self:isSolid(x - 1, y, z) or not self:isSolid(x + 1, y, z)
                    or not self:isSolid(x, y - 1, z) or not self:isSolid(x, y + 1, z)
                    or not self:isSolid(x, y, z - 1) or not self:isSolid(x, y, z + 1)) then
                buffer.writeu8(exposed, index(x, y, z, n), 1)
                surfaceCubes += 1
            end
        end
    end

    for x = 0, n - 1 do
        local x2 = squares[x + 1]
        if x2 <= outer2 then
            for y = 0, n - 1 do
                local xy2 = x2 + squares[y + 1]
                if xy2 <= outer2 then
                    local zOuter = math.sqrt(outer2 - xy2)
                    if xy2 < inner2 then
                        local zInner = math.sqrt(inner2 - xy2)
                        markBand(x, y, -zOuter, -zInner)
                        markBand(x, y, zInner, zOuter)
                    else
                        markBand(x, y, -zOuter, zOuter)
                    end
                end
            end
        end
        if x % 4 == 3 then
            if cancelled and cancelled() then error("GENERATION_CANCELLED", 0) end
            task.wait()
        end
    end
    self.Surface = exposed
    self.SurfaceCubes = surfaceCubes
end

function Field:isSurface(x: number, y: number, z: number): boolean
    local n = self.Count
    if x < 0 or y < 0 or z < 0 or x >= n or y >= n or z >= n then return false end
    return buffer.readu8(self.Surface, index(x, y, z, n)) == 1
end

return Field
