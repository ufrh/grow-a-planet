-- Prototype 0.4: sphere with fully mapped black/white Perlin projection.
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
    -- Keep the exact 128^3 resolution and 18-stud sampling extent.
    -- The visible planet is a sphere with a fixed 8-stud radius.
    SamplingDiameter = 18,
    MinSurfaceRadius = 8,
    MaxSurfaceRadius = 8,
    ChunkCells = 32,

    -- 128^3 / 64^3 / 32^3 cubic cells. Cell edges are always exactly aligned.
    CellCounts = {128, 64, 32},
    VoxelSizes = {18 / 128, 18 / 64, 18 / 32},
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
}
