--!strict
-- Every chunk is a colorized EditableMesh triangle MeshPart, or a group of
-- full solid cuboid Parts (never thin face planes).
local AssetService = game:GetService("AssetService")
local Config = require(script.Parent.Config)

local Renderer = {}

local function boundaries(faces)
    local minimum = Vector3.new(math.huge, math.huge, math.huge)
    local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, face in ipairs(faces) do
        for _, vertex in ipairs(face.vertices) do
            minimum = Vector3.new(math.min(minimum.X, vertex.X), math.min(minimum.Y, vertex.Y), math.min(minimum.Z, vertex.Z))
            maximum = Vector3.new(math.max(maximum.X, vertex.X), math.max(maximum.Y, vertex.Y), math.max(maximum.Z, vertex.Z))
        end
    end
    return minimum, maximum
end

function Renderer.meshSupported()
    -- Do not assume account/experience has enabled runtime EditableMesh APIs.
    local ok, editable = pcall(function()
        return AssetService:CreateEditableMesh()
    end)
    if ok and editable then
        editable:Destroy()
        return true
    end
    return false
end

-- Returns the EditableMesh so it can be disposed when changing LOD.
function Renderer.addMeshChunk(faces, chunkName, container, center)
    local editable = AssetService:CreateEditableMesh()
    if not editable then error("EditableMesh creation returned nil (budget or permission limit)") end

    local successful, result = pcall(function()
        local low, high = boundaries(faces)
        local localOrigin = (low + high) * 0.5

        local normals = {
            {editable:AddNormal(Vector3.xAxis), editable:AddNormal(-Vector3.xAxis)},
            {editable:AddNormal(Vector3.yAxis), editable:AddNormal(-Vector3.yAxis)},
            {editable:AddNormal(Vector3.zAxis), editable:AddNormal(-Vector3.zAxis)},
        }
        local colors = {}
        for i, color in ipairs(Config.Palette) do
            colors[i] = editable:AddColor(color, 1)
        end
        for _, face in ipairs(faces) do
            local ids = {}
            for i, pos in ipairs(face.vertices) do
                ids[i] = editable:AddVertex(pos - localOrigin)
            end
            -- Triangles work without the newer EditableMesh Quads Studio beta.
            -- Two triangles cover exactly the four corners of the cube face.
            local colorId = colors[face.color]
            local component = if face.axis == 1 then face.normal.X elseif face.axis == 2 then face.normal.Y else face.normal.Z
            local normalIndex = if component > 0 then 1 else 2
            local normalId = normals[face.axis][normalIndex]
            local a = editable:AddTriangle(ids[1], ids[2], ids[3])
            local b = editable:AddTriangle(ids[1], ids[3], ids[4])
            editable:SetFaceColors(a, {colorId, colorId, colorId})
            editable:SetFaceColors(b, {colorId, colorId, colorId})
            editable:SetFaceNormals(a, {normalId, normalId, normalId})
            editable:SetFaceNormals(b, {normalId, normalId, normalId})
        end

        local part = AssetService:CreateMeshPartAsync(
            Content.fromObject(editable),
            { CollisionFidelity = Enum.CollisionFidelity.Box }
        )
        part.Name = chunkName
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.Color = Color3.new(1, 1, 1)
        part.Material = Enum.Material.SmoothPlastic
        part.CFrame = CFrame.new(center + localOrigin)
        part.Parent = container
        return editable
    end)
    if not successful then
        editable:Destroy()
        error(result, 0)
    end
    return result
end

-- Each box fills an exact set of 3D surface voxel cells.
-- A Part's center and dimensions are integer voxel boundaries: no thin
-- overlapping sheets or misaligned corners anywhere on the planet.
function Renderer.addCubesChunk(boxes, chunkName, container, center)
    local group = Instance.new("Folder")
    group.Name = chunkName
    for i, cube in ipairs(boxes) do
        local part = Instance.new("Part")
        part.Name = "Voxel"
        part.Size = cube.size
        part.CFrame = CFrame.new(center + cube.position)
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Material = Enum.Material.SmoothPlastic
        part.Color = Config.Palette[cube.color]
        part.TopSurface = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        part.Parent = group
        if i % 200 == 0 then task.wait() end
    end
    group.Parent = container
end

return Renderer
