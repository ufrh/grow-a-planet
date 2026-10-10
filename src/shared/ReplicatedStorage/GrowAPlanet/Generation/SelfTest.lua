-- Lightweight geometry invariants, run in Studio only.
local Mesher = require(script.Parent.GreedyMesher)
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

function SelfTest.run()
    verify(fake(16, {["7:7:7"] = true}), 6)
    -- Adjacent voxels straddling a chunk boundary must not produce
    -- duplicated faces between the two chunks.
    verify(fake(32, {["15:15:15"] = true, ["16:15:15"] = true}), 10)
    print("[Grow a Planet] Greedy voxel geometry self-test passed.")
end

return SelfTest
