--!strict
-- Dense occupancy is an inexpensive temporary *sampling mask*, not voxel Parts.
-- No interior geometry is built or retained after meshing.
local Config = require(script.Parent.Config)
local Field = {}
Field.__index = Field

local function index(x: number, y: number, z: number, count: number): number
    return (x * count + y) * count + z
end

local function heightAt(x: number, y: number, z: number, sx: number, sy: number, sz: number): number
    local broad = math.noise(x * 0.22 + sx, y * 0.22 + sy, z * 0.22 + sz)
    local detail = math.noise(x * 0.61 + sx * 1.7, y * 0.61 + sy * 1.7, z * 0.61 + sz * 1.7)
    local tiny = math.noise(x * 1.31 + sx * 2.3, y * 1.31 + sy * 2.3, z * 1.31 + sz * 2.3)
    return Config.HeightAmplitude * (broad * 0.9 + detail * 0.28 + tiny * 0.12)
end

local function materialAt(x: number, y: number, z: number, radius: number, seed: number): number
    local altitude = math.sqrt(x * x + y * y + z * z) - radius
    local latitude = math.abs(y) / radius
    local variation = ((math.floor(x * 5) * 73856093 + math.floor(y * 5) * 19349663 + math.floor(z * 5) * 83492791 + seed) % 17) / 170
    local value = altitude + latitude * 0.055 + variation
    if value > 0.37 then return 5 end
    if value > 0.15 then return 4 end
    if value > -0.1 then return 3 end
    if value > -0.32 then return 2 end
    return 1
end

function Field.new(seed: number, voxelSize: number, cancelled: (() -> boolean)?)
    local count = math.floor(Config.Diameter / voxelSize + 0.5)
    assert(count * voxelSize == Config.Diameter, "LOD size must divide the diameter exactly")

    local self = setmetatable({
        Count = count,
        VoxelSize = voxelSize,
        Seed = seed,
        Occupied = buffer.create(count * count * count),
        Materials = buffer.create(count * count * count),
        Samples = 0,
        Filled = 0,
    }, Field)

    local radius = Config.Diameter * 0.5
    local minRadius2 = (radius - Config.HeightAmplitude * 1.5) ^ 2
    local maxRadius2 = (radius + Config.HeightAmplitude * 1.5) ^ 2
    local sx = (seed % 1297) * 0.093 + 11.3
    local sy = (seed % 2143) * 0.071 + 48.1
    local sz = (seed % 3187) * 0.051 + 99.7

    for x = 0, count - 1 do
        local px = (x + 0.5) * voxelSize - radius
        for y = 0, count - 1 do
            local py = (y + 0.5) * voxelSize - radius
            for z = 0, count - 1 do
                local pz = (z + 0.5) * voxelSize - radius
                local distance2 = px * px + py * py + pz * pz
                local solid: boolean
                if distance2 <= minRadius2 then
                    solid = true
                elseif distance2 >= maxRadius2 then
                    solid = false
                else
                    local localRadius = radius + heightAt(px, py, pz, sx, sy, sz)
                    solid = distance2 <= localRadius * localRadius
                end
                local offset = index(x, y, z, count)
                if solid then
                    buffer.writeu8(self.Occupied, offset, 1)
                    -- Material only matters at an exposed boundary, but storing one
                    -- byte per cell makes the greedy mesher deterministic and cheap.
                    if distance2 >= minRadius2 then
                        buffer.writeu8(self.Materials, offset, materialAt(px, py, pz, radius, seed))
                    else
                        buffer.writeu8(self.Materials, offset, 1)
                    end
                    self.Filled += 1
                end
                self.Samples += 1
            end
        end
        -- Keep the UI/camera responsive during the 64^3 high-detail pass.
        if x % 4 == 3 then
            if cancelled and cancelled() then error("GENERATION_CANCELLED", 0) end
            task.wait()
        end
    end
    return self
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
