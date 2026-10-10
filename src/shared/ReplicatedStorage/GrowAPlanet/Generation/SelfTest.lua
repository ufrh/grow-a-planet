-- Lightweight geometry invariants, run in Studio only.
local Mesher = require(script.Parent.GreedyMesher)
local Cuboids = require(script.Parent.CuboidMesher)
local Config = require(script.Parent.Config)
local TreeGenerator = require(script.Parent.TreeGenerator)
local SelfTest = {}

local function fake(count, cells)
    local field = {Count = count, VoxelSize = 16 / count}
    function field:isSolid(x, y, z)
        return cells[string.format("%d:%d:%d", x, y, z)] == true
    end
    function field:material(_x, _y, _z)
        return 3
    end
    return field
end

local function verify(field, expected)
    local faces = 0
    Mesher.forEachChunk(field, function(quads)
        for _, quad in ipairs(quads) do
            faces += 1
            local v = quad.vertices
            local cross = (v[2] - v[1]):Cross(v[3] - v[1])
            assert(cross:Dot(quad.normal) > 0, "Incorrect exposed face winding")
            assert(quad.color == 3, "Surface material was lost")
        end
    end)
    assert(faces == expected, string.format("Expected %d external faces, got %d", expected, faces))
end

local function verifySolidCubes()
    local cells = {["7:7:7"] = true, ["7:7:8"] = true}
    local field = fake(16, cells)
    field.Surface = true
    field.VoxelSize = Config.VoxelSizes[3]
    function field:isSurface(x, y, z)
        return cells[string.format("%d:%d:%d", x, y, z)] == true
    end

    local count, volume = 0, 0
    Cuboids.forEachChunk(field, function(boxes)
        for _, box in ipairs(boxes) do
            count += 1
            volume += box.size.X * box.size.Y * box.size.Z
            assert(box.color == 3, "Solid cuboid palette mismatch")
            -- A box must cover exact whole cells; no offset face plates.
            local unit = field.VoxelSize
            assert(math.abs(box.size.X / unit - math.round(box.size.X / unit)) < 0.000001)
            assert(math.abs(box.size.Y / unit - math.round(box.size.Y / unit)) < 0.000001)
            assert(math.abs(box.size.Z / unit - math.round(box.size.Z / unit)) < 0.000001)
        end
    end)
    assert(count == 1, string.format("Two touching surface cubes must merge to one solid box; got %d", count))
    assert(math.abs(volume - 2 * field.VoxelSize ^ 3) < 0.00001, "Solid cuboid volume changed")
end

function SelfTest.run()
    assert(#Config.CellCounts == #Config.VoxelSizes, "LOD counts and sizes mismatch")
    assert(Config.CellCounts[1] == 256, "Highest planet LOD must be 256^3")
    assert(Config.TestTrees.VoxelRatio == 0.5, "Trees must use half-width planet voxels")
    for tier, count in ipairs(Config.CellCounts) do
        assert(math.abs(count * Config.VoxelSizes[tier] - Config.SamplingDiameter) < 0.000001)
        assert(math.abs(Config.TestTrees.GridCells[tier] * Config.VoxelSizes[tier]
            * Config.TestTrees.VoxelRatio - 2.8125) < 0.000001,
            "Tree grids must share a stable world-space extent across LODs")
    end
    assert(Config.MinSurfaceRadius == Config.Diameter * 0.5, "Sphere minimum radius must be fixed")
    assert(Config.MaxSurfaceRadius == Config.Diameter * 0.5, "Sphere maximum radius must be fixed")
    assert(#Config.Palette == 16, "Expected 16 black-to-white grayscale steps")
    assert(Config.Palette[1] == Color3.fromRGB(0, 0, 0), "Noise minima must map to true black")
    assert(Config.Palette[#Config.Palette] == Color3.fromRGB(255, 255, 255), "Noise maxima must map to true white")
    for i, color in ipairs(Config.Palette) do
        assert(color.R == color.G and color.G == color.B, "Palette must be strictly grayscale")
        if i > 1 then
            assert(color.R > Config.Palette[i - 1].R, "Grayscale heights must map monotonically")
        end
    end
    assert(Config.MaxSurfaceRadius + Config.VoxelSizes[1] < Config.SamplingDiameter * 0.5,
        "Sampling bounds must leave room for the largest surface cubes")

    verify(fake(16, {["7:7:7"] = true}), 6)
    -- Adjacent voxels straddling an actual 32-cell chunk boundary.
    verify(fake(33, {["31:31:31"] = true, ["32:31:31"] = true}), 10)
    verifySolidCubes()

    -- Geometry must remain unchanged when the seed changes. The pattern
    -- should vary only through palette indexes along the same outer shell.
    local Field = require(script.Parent.VoxelField)
    local a = Field.new(12345, Config.VoxelSizes[3])
    local b = Field.new(67890, Config.VoxelSizes[3])
    local differences = 0
    local lowestShade, highestShade = math.huge, -math.huge
    for x = 0, a.Count - 1 do
        for y = 0, a.Count - 1 do
            for z = 0, a.Count - 1 do
                local occupied = a:isSolid(x, y, z)
                assert(occupied == b:isSolid(x, y, z), "Seed changed the sphere's silhouette")
                if occupied then
                    local shade = a:material(x, y, z)
                    lowestShade = math.min(lowestShade, shade)
                    highestShade = math.max(highestShade, shade)
                    if shade ~= b:material(x, y, z) then differences += 1 end
                end
            end
        end
    end
    assert(differences > 0, "Different seeds should change only the surface color")
    assert(lowestShade < highestShade - 5, "Projected Perlin shades are insufficiently contrasted")

    -- A real vegetation field: bark, leaves, radial orientation and
    -- grid alignment are all tested without creating any Roblox Parts.
    local testTree = TreeGenerator.make(12345, 3, 1)
    assert(testTree.Count == Config.TestTrees.GridCells[3], "Tree LOD cell count mismatch")
    assert(testTree.VoxelSize == Config.VoxelSizes[3] * 0.5, "Trees must be twice as fine")
    assert(testTree.WoodCount > 0, "Test tree is missing a voxel trunk")
    assert(testTree.LeafCount > 0, "Test tree has no voxel canopy")
    assert(testTree.Up:Dot((testTree.Root - Config.Center).Unit) > 0.9999,
        "Tree growth is not radial to the sphere")
    print("[Grow a Planet] 256^3 sphere / 2x tree voxel grid geometry tests passed.")
end

return SelfTest
