--!strict
-- Tiny seeded trees on the sphere. NO Roblox Part is rotated.
-- Growth uses a radial vector mathematically; geometry is sampled onto a
-- fixed world-axis-aligned grid 2x finer than the planet at every LOD.
local Config = require(script.Parent.Config)
local Trees = {}

local Directions = {
    Vector3.new(-0.46, 0.32, 0.83),
    Vector3.new(-0.90, -0.06, 0.49),
    Vector3.new(0.24, 0.55, 0.82),
    Vector3.new(0.19, -0.59, 0.82),
}

local function index(x, y, z, count)
    return (x * count + y) * count + z
end

local function distSegment2(p: Vector3, a: Vector3, b: Vector3): number
    local ab = b - a
    local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
    local d = p - (a + ab * t)
    return d:Dot(d)
end

function Trees.make(seed: number, tier: number, treeIndex: number, cancelled: (() -> boolean)?)
    local setting = Config.TestTrees
    assert(treeIndex >= 1 and treeIndex <= math.min(setting.Count, #Directions), "Unknown test tree")
    local size = Config.VoxelSizes[tier] * setting.VoxelRatio
    local n = setting.GridCells[tier]
    assert(math.abs(n * size - setting.GridCells[1] * Config.VoxelSizes[1] * setting.VoxelRatio) < 0.000001,
        "Tree LOD bounds must keep the same physical extent")
    local rng = Random.new(seed + treeIndex * 91039)
    local dir = Directions[treeIndex]
    local up = (dir + Vector3.new(
        rng:NextNumber(-0.04, 0.04),
        rng:NextNumber(-0.04, 0.04),
        rng:NextNumber(-0.04, 0.04)
    )).Unit
    local tangent = up:Cross(Vector3.yAxis)
    if tangent.Magnitude < 0.15 then tangent = up:Cross(Vector3.xAxis) end
    tangent = tangent.Unit
    local bitangent = up:Cross(tangent).Unit

    -- Root is deliberately sunk slightly into the stepped block surface.
    local root = Config.Center + up * (Config.Diameter * 0.5 - 0.16)
    local centerApprox = root + up * 0.80

    -- Snap the tree's local grid onto the planet's global voxel lattice.
    -- The tree cells subdivide the planet cells exactly (two per axis).
    local planetBase = Config.Center - Vector3.new(
        Config.SamplingDiameter * 0.5,
        Config.SamplingDiameter * 0.5,
        Config.SamplingDiameter * 0.5
    )
    local function snap(value: number, base: number): number
        return base + math.round((value - base) / size) * size
    end
    local center = Vector3.new(
        snap(centerApprox.X, planetBase.X),
        snap(centerApprox.Y, planetBase.Y),
        snap(centerApprox.Z, planetBase.Z)
    )

    local height = rng:NextNumber(1.12, 1.42)
    local trunkTop = height * 0.82
    local canopyHeight = height * 1.02
    local canopyRadius = rng:NextNumber(0.37, 0.47)
    local branches = {}
    local blobs = {
        {x = 0, y = canopyHeight, z = 0, radius = canopyRadius},
    }

    for i = 1, 4 do
        local angle = (i - 1) * math.pi * 0.5 + rng:NextNumber(-0.34, 0.34)
        local dx = math.cos(angle)
        local dz = math.sin(angle)
        local branchHeight = trunkTop * rng:NextNumber(0.68, 0.92)
        local reach = rng:NextNumber(0.24, 0.40)
        local tipHeight = canopyHeight + rng:NextNumber(-0.20, 0.04)
        table.insert(branches, {
            a = Vector3.new(0, branchHeight, 0),
            b = Vector3.new(dx * reach, tipHeight, dz * reach),
        })
        table.insert(blobs, {
            x = dx * reach,
            y = tipHeight,
            z = dz * reach,
            radius = canopyRadius * rng:NextNumber(0.57, 0.74)
        })
    end

    local occupied = buffer.create(n * n * n)
    local materials = buffer.create(n * n * n)
    local chunkSize = Config.ChunkCells
    local chunkSide = math.ceil(n / chunkSize)
    local occupiedChunks = buffer.create(chunkSide * chunkSide * chunkSide)
    local woodCount, leafCount = 0, 0
    local noiseX = (seed % 7919) * 0.007 + treeIndex * 5.4
    local noiseY = (seed % 1009) * 0.013 + treeIndex * 2.8
    local noiseZ = (seed % 6079) * 0.011 + treeIndex * 9.1

    for x = 0, n - 1 do
        local gx = (x + 0.5 - n * 0.5) * size
        for y = 0, n - 1 do
            local gy = (y + 0.5 - n * 0.5) * size
            for z = 0, n - 1 do
                local gz = (z + 0.5 - n * 0.5) * size
                local world = center + Vector3.new(gx, gy, gz)
                local delta = world - root
                local h = delta:Dot(up)
                if h >= -0.20 and h <= height + canopyRadius + 0.16 then
                    local side = delta:Dot(tangent)
                    local forward = delta:Dot(bitangent)
                    -- Coordinates of a radial tree in an axis-aligned voxel grid.
                    local point = Vector3.new(side, h, forward)
                    local radial2 = side * side + forward * forward

                    local wood = false
                    if h <= trunkTop then
                        local thickness = math.max(0.105 - math.max(0, h) / height * 0.027, size * 0.85)
                        wood = radial2 <= thickness * thickness
                    end
                    if not wood and h > trunkTop * 0.54 then
                        for _, branch in ipairs(branches) do
                            if distSegment2(point, branch.a, branch.b) <= math.max(0.049, size * 0.55) ^ 2 then
                                wood = true
                                break
                            end
                        end
                    end

                    local leaves = false
                    if h > trunkTop * 0.66 then
                        for _, blob in ipairs(blobs) do
                            local dx = side - blob.x
                            local dy = (h - blob.y) * 1.10
                            local dz = forward - blob.z
                            if dx * dx + dy * dy + dz * dz <= blob.radius * blob.radius then
                                leaves = true
                                break
                            end
                        end
                    end

                    if wood or leaves then
                        local color = 1
                        if leaves then
                            local value = math.noise(world.X * 4.1 + noiseX,
                                world.Y * 4.1 + noiseY, world.Z * 4.1 + noiseZ)
                            color = math.clamp(math.floor((value * 0.8 + 0.5) * 4) + 2, 2, 5)
                            leafCount += 1
                        else
                            woodCount += 1
                        end

                        local offset = index(x, y, z, n)
                        buffer.writeu8(occupied, offset, 1)
                        buffer.writeu8(materials, offset, color)
                        local chunkX = math.floor(x / chunkSize)
                        local chunkY = math.floor(y / chunkSize)
                        local chunkZ = math.floor(z / chunkSize)
                        buffer.writeu8(occupiedChunks,
                            index(chunkX, chunkY, chunkZ, chunkSide), 1)
                    end
                end
            end
        end
        if x % 4 == 3 then
            if cancelled and cancelled() then error("GENERATION_CANCELLED", 0) end
            task.wait()
        end
    end

    local field = {
        Count = n,
        VoxelSize = size,
        Seed = seed,
        Center = center,
        Up = up,
        Root = root,
        Height = height,
        WoodCount = woodCount,
        LeafCount = leafCount,
        Samples = n * n * n,
        Occupied = occupied,
        Materials = materials,
        OccupiedChunks = occupiedChunks,
        ChunkSide = chunkSide,
        Surface = nil,
        SurfaceCubes = 0,
    }

    function field:isSolid(x, y, z)
        if x < 0 or y < 0 or z < 0 or x >= n or y >= n or z >= n then return false end
        return buffer.readu8(occupied, index(x, y, z, n)) == 1
    end

    function field:material(x, y, z)
        return buffer.readu8(materials, index(x, y, z, n))
    end

    function field:chunkMightHaveSurface(first, _last)
        local cx = math.floor(first[1] / chunkSize)
        local cy = math.floor(first[2] / chunkSize)
        local cz = math.floor(first[3] / chunkSize)
        return buffer.readu8(occupiedChunks, index(cx, cy, cz, chunkSide)) ~= 0
    end

    function field:prepareSurface(cancel)
        local surface = buffer.create(n * n * n)
        local count = 0
        for x = 0, n - 1 do
            for y = 0, n - 1 do
                for z = 0, n - 1 do
                    if self:isSolid(x, y, z)
                        and (not self:isSolid(x - 1, y, z) or not self:isSolid(x + 1, y, z)
                            or not self:isSolid(x, y - 1, z) or not self:isSolid(x, y + 1, z)
                            or not self:isSolid(x, y, z - 1) or not self:isSolid(x, y, z + 1)) then
                        buffer.writeu8(surface, index(x, y, z, n), 1)
                        count += 1
                    end
                end
            end
            if x % 4 == 3 then
                if cancel and cancel() then error("GENERATION_CANCELLED", 0) end
                task.wait()
            end
        end
        self.Surface = surface
        self.SurfaceCubes = count
    end

    function field:isSurface(x, y, z)
        if x < 0 or y < 0 or z < 0 or x >= n or y >= n or z >= n then return false end
        return buffer.readu8(self.Surface, index(x, y, z, n)) ~= 0
    end

    return field
end

return Trees
