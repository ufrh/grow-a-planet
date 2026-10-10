-- Prototype 0.5: 256-cell sphere and 2x-finer voxel tree previews.
-- All distances are in Roblox studs. Seeds are integers, shared across clients.
-- Quantized to 16 true grayscale steps for voxel-friendly geometry merging.
local palette = {}
for i = 0, 15 do
    local shade = math.round(255 * i / 15)
    palette[i + 1] = Color3.fromRGB(shade, shade, shade)
end

return {
    Seed = 4102026,
    Center = Vector3.new(0, 0, 0),
    Diameter = 16,
    -- Keep the 18-stud sampling box; double the former maximum detail.
    -- The visible planet is a sphere with a fixed 8-stud radius.
    SamplingDiameter = 18,
    MinSurfaceRadius = 8,
    MaxSurfaceRadius = 8,
    ChunkCells = 32,

    -- 256^3 / 128^3 / 64^3. Each successive LOD exactly halves resolution.
    CellCounts = {256, 128, 64},
    VoxelSizes = {18 / 256, 18 / 128, 18 / 64},
    NearDistance = 35,
    FarDistance = 68,
    LODHysteresis = 3,

    -- Parts fallback: ACTUAL solid cubes merged into 3D cuboids, never thin plates.
    -- If a tier needs too many Parts, fall back to the next coarser tier.
    MaxFallbackParts = 6500,

    Camera = {
        InitialDistance = 25,
        MinDistance = 13,
        MaxDistance = 100,
        FieldOfView = 55,
        OrbitSpeed = 0.005,
        AutoRotationSpeed = 0.035,
    },

    -- One octave of standard 3D Perlin noise, projected from sphere direction.
    -- 0 height = black, 1 height = white. Larger contrast reaches extremes.
    ColorNoiseScale = 2.0,
    ColorNoiseContrast = 1.9,

    Palette = palette,

    -- Test vegetation only; tree voxel widths are 1/2 of planet voxel
    -- widths at the same LOD. No rotated Parts, player, or growth gameplay.
    TestTrees = {
        Enabled = true,
        Count = 4,
        VoxelRatio = 0.5,
        GridCells = {80, 40, 20},
        MaxPartsPerTree = 2200,
        -- 2.8125 studs of world-aligned local bounds at every tree LOD.
        Colors = {
            Color3.fromRGB(107, 76, 51),  -- wood
            Color3.fromRGB(38, 98, 52),   -- deep foliage
            Color3.fromRGB(57, 128, 66),
            Color3.fromRGB(79, 156, 81),
            Color3.fromRGB(110, 174, 96),
        },
    },
}
