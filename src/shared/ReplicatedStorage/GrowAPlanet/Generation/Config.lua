-- Prototype 0.1: one deterministic microvoxel planet.
-- All distances are in Roblox studs. Seeds are integers, shared across clients.
return {
    Seed = 4102026,
    Center = Vector3.new(0, 0, 0),
    Diameter = 16,
    -- A 16-stud nominal planet needs a little empty air around its tallest
    -- voxel mountains. An 18-stud sampling box prevents cropped polar faces.
    SamplingDiameter = 18,
    MinSurfaceRadius = 7.65,
    MaxSurfaceRadius = 8.35,
    SurfaceRoughness = 0.65,
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

    -- Purely geological colors. The growth/traits system is NOT involved.
    Palette = {
        Color3.fromRGB(88, 70, 73),
        Color3.fromRGB(125, 95, 89),
        Color3.fromRGB(164, 127, 109),
        Color3.fromRGB(193, 165, 139),
        Color3.fromRGB(216, 200, 174),
    },
}
