--!strict
-- Converts exposed *solid* voxels into compact 3D cuboids.
-- Unlike six thin planes, each box fills a volume of real voxel cells:
-- its corners align exactly with the voxel grid and no shells overlap.
local Config = require(script.Parent.Config)
local Cuboids = {}

function Cuboids.forEachChunk(field, onChunk, cancelled: (() -> boolean)?, maxBoxes: number?)
    assert(field.Surface, "Call field:prepareSurface() before cuboid merging")
    local n = field.Count
    local step = Config.ChunkCells
    local voxel = field.VoxelSize
    -- Use the actual field bounds: planet and 2x-finer tree fields differ.
    local half = n * voxel * 0.5
    local total = 0

    for cx = 0, n - 1, step do
        for cy = 0, n - 1, step do
            for cz = 0, n - 1, step do
                if cancelled and cancelled() then error("GENERATION_CANCELLED", 0) end
                local nx = math.min(step, n - cx)
                local ny = math.min(step, n - cy)
                local nz = math.min(step, n - cz)
                local visited = buffer.create(nx * ny * nz)
                local boxes = {}
                local function localIndex(x, y, z)
                    return (x * ny + y) * nz + z
                end

                local function matches(x, y, z, material)
                    if x >= nx or y >= ny or z >= nz then return false end
                    if buffer.readu8(visited, localIndex(x, y, z)) ~= 0 then return false end
                    local wx, wy, wz = cx + x, cy + y, cz + z
                    return field:isSurface(wx, wy, wz) and field:material(wx, wy, wz) == material
                end

                for x = 0, nx - 1 do
                    for y = 0, ny - 1 do
                        for z = 0, nz - 1 do
                            if buffer.readu8(visited, localIndex(x, y, z)) == 0
                                and field:isSurface(cx + x, cy + y, cz + z) then
                                local material = field:material(cx + x, cy + y, cz + z)

                                -- Maximize Z run, then grow Y rectangle and X volume.
                                local dz = 1
                                while matches(x, y, z + dz, material) do dz += 1 end
                                local dy = 1
                                while y + dy < ny do
                                    local fits = true
                                    for zz = z, z + dz - 1 do
                                        if not matches(x, y + dy, zz, material) then fits = false; break end
                                    end
                                    if not fits then break end
                                    dy += 1
                                end
                                local dx = 1
                                while x + dx < nx do
                                    local fits = true
                                    for yy = y, y + dy - 1 do
                                        for zz = z, z + dz - 1 do
                                            if not matches(x + dx, yy, zz, material) then
                                                fits = false
                                                break
                                            end
                                        end
                                        if not fits then break end
                                    end
                                    if not fits then break end
                                    dx += 1
                                end

                                for xx = x, x + dx - 1 do
                                    for yy = y, y + dy - 1 do
                                        for zz = z, z + dz - 1 do
                                            buffer.writeu8(visited, localIndex(xx, yy, zz), 1)
                                        end
                                    end
                                end
                                table.insert(boxes, {
                                    position = Vector3.new(
                                        (cx + x + dx * 0.5) * voxel - half,
                                        (cy + y + dy * 0.5) * voxel - half,
                                        (cz + z + dz * 0.5) * voxel - half
                                    ),
                                    size = Vector3.new(dx * voxel, dy * voxel, dz * voxel),
                                    color = material,
                                })
                                total += 1
                                if total > (maxBoxes or Config.MaxFallbackParts) then
                                    error("FALLBACK_PART_BUDGET", 0)
                                end
                            end
                        end
                    end
                    if x % 8 == 7 then
                        if cancelled and cancelled() then error("GENERATION_CANCELLED", 0) end
                        task.wait()
                    end
                end
                if #boxes > 0 then onChunk(boxes, {cx, cy, cz}) end
            end
        end
    end
    return total
end

return Cuboids
