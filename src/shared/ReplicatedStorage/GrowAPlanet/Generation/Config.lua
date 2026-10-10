-- Prototype 0.1: one deterministic microvoxel planet.
-- All distances are in Roblox studs. Seeds are integers, shared across clients.
return {
    Seed = 4102026,
    Center = Vector3.new(0, 0, 0),
    Diameter = 16,
    HeightAmplitude = 0.95,
    ChunkCells = 16,

    -- The highest level resolves 64 cells across the diameter.
    VoxelSizes = {0.25, 0.5, 1},
    NearDistance = 31,
    FarDistance = 55,
    LODHysteresis = 3,

    -- Part quads are much heavier than MeshParts. Never use fine LOD with them.
    FallbackLOD = 3,
    MaxFallbackQuads = 3000,

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
