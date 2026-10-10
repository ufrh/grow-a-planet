-- Prototype 0.3: spherical white planet with seed-based grayscale noise.
-- All distances are in Roblox studs. Seeds are integers, shared across clients.
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

    -- Color-only projected 3D noise. The sphere's geometry never changes.
    ColorNoiseScale = 2.4,
    ColorNoiseDetailScale = 5.8,
    ColorNoiseMicroScale = 11.5,

    -- White-dominant grayscale. Each voxel gets one of these colors.
    Palette = {
        Color3.fromRGB(255, 255, 255),
        Color3.fromRGB(250, 250, 250),
        Color3.fromRGB(242, 242, 242),
        Color3.fromRGB(231, 231, 231),
        Color3.fromRGB(216, 216, 216),
        Color3.fromRGB(198, 198, 198),
    },
}
