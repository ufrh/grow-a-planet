--!strict
-- Greedy meshing of exposed voxel faces only. The virtual solid interior never
-- becomes geometry. Surfaces are split into chunks (no faces at shared seams).
local Config = require(script.Parent.Config)
local Mesher = {}

local function toLocal(x: number, y: number, z: number, n: number, size: number): Vector3
    local origin = n * 0.5
    return Vector3.new((x - origin) * size, (y - origin) * size, (z - origin) * size)
end

-- Emits: {vertices = {Vector3, Vector3, Vector3, Vector3}, color = palette index,
--         normal = unit Vector3, axis = 1..3}.
function Mesher.forEachChunk(field, onChunk)
    local n = field.Count
    local scale = field.VoxelSize
    local side = Config.ChunkCells
    local coords = {0, 0, 0}
    local point = {0, 0, 0}
    local mask = {}

    for cx = 0, n - 1, side do
        for cy = 0, n - 1, side do
            for cz = 0, n - 1, side do
                local first = {cx, cy, cz}
                local last = {math.min(cx + side, n), math.min(cy + side, n), math.min(cz + side, n)}
                local faces = {}

                for axis = 1, 3 do
                    local u = (axis % 3) + 1
                    local v = ((axis + 1) % 3) + 1
                    local width = last[u] - first[u]
                    local height = last[v] - first[v]

                    for slice = first[axis] - 1, last[axis] - 1 do
                        -- Face ownership: negative faces belong to the B cell;
                        -- positive faces belong to the A cell. This prevents
                        -- duplicated faces at chunk boundaries.
                        for j = 0, height - 1 do
                            coords[v] = first[v] + j
                            for i = 0, width - 1 do
                                coords[u] = first[u] + i
                                coords[axis] = slice
                                local ax, ay, az = coords[1], coords[2], coords[3]
                                local a = field:isSolid(ax, ay, az)
                                coords[axis] = slice + 1
                                local bx, by, bz = coords[1], coords[2], coords[3]
                                local b = field:isSolid(bx, by, bz)
                                local code = 0
                                if a and not b and slice >= first[axis] then
                                    code = field:material(ax, ay, az)
                                elseif b and not a and slice + 1 < last[axis] then
                                    code = -field:material(bx, by, bz)
                                end
                                mask[j * width + i + 1] = code
                            end
                        end

                        -- Maximal rectangles of equal signed material / normal.
                        for j = 0, height - 1 do
                            local i = 0
                            while i < width do
                                local offset = j * width + i + 1
                                local code = mask[offset]
                                if code == 0 then
                                    i += 1
                                else
                                    local w = 1
                                    while i + w < width and mask[offset + w] == code do w += 1 end
                                    local h = 1
                                    while j + h < height do
                                        local same = true
                                        for k = 0, w - 1 do
                                            if mask[(j + h) * width + i + k + 1] ~= code then
                                                same = false
                                                break
                                            end
                                        end
                                        if not same then break end
                                        h += 1
                                    end
                                    for yy = 0, h - 1 do
                                        for xx = 0, w - 1 do
                                            mask[(j + yy) * width + i + xx + 1] = 0
                                        end
                                    end

                                    point[axis] = slice + 1
                                    point[u] = first[u] + i
                                    point[v] = first[v] + j
                                    local p0 = toLocal(point[1], point[2], point[3], n, scale)
                                    point[u] += w
                                    local p1 = toLocal(point[1], point[2], point[3], n, scale)
                                    point[v] += h
                                    local p2 = toLocal(point[1], point[2], point[3], n, scale)
                                    point[u] -= w
                                    local p3 = toLocal(point[1], point[2], point[3], n, scale)
                                    local normal = if axis == 1 then Vector3.xAxis elseif axis == 2 then Vector3.yAxis else Vector3.zAxis
                                    local vertices = if code > 0 then {p0, p1, p2, p3} else {p0, p3, p2, p1}
                                    table.insert(faces, {
                                        vertices = vertices,
                                        color = math.abs(code),
                                        normal = normal * (if code > 0 then 1 else -1),
                                        axis = axis,
                                    })
                                    i += w
                                end
                            end
                        end
                    end
                end

                if #faces > 0 then
                    onChunk(faces, {cx, cy, cz})
                end
            end
        end
    end
end

return Mesher
