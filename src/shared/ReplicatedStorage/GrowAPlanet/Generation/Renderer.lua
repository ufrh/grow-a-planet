--!strict
-- Every chunk is one colorized EditableMesh MeshPart, or a small group of
-- flat Parts if the user's experience cannot use Mesh & Image APIs.
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
            local faceId = editable:AddFace(ids)
            local colorId = colors[face.color]
            editable:SetFaceColors(faceId, {colorId, colorId, colorId, colorId})
            local component = if face.axis == 1 then face.normal.X elseif face.axis == 2 then face.normal.Y else face.normal.Z
            local normalIndex = if component > 0 then 1 else 2
            local normalId = normals[face.axis][normalIndex]
            editable:SetFaceNormals(faceId, {normalId, normalId, normalId, normalId})
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

function Renderer.addPartsChunk(faces, chunkName, container, center, totalCount)
    local group = Instance.new("Folder")
    group.Name = chunkName
    local thickness = 0.06
    for i, face in ipairs(faces) do
        totalCount += 1
        if totalCount > Config.MaxFallbackQuads then
            group:Destroy()
            error("Fallback part budget exceeded. Increase LOD size or the fallback budget.")
        end
        local vs = face.vertices
        local centerPoint = (vs[1] + vs[3]) * 0.5
        local difference = (vs[3] - vs[1])
        local size
        if face.axis == 1 then
            size = Vector3.new(thickness, math.abs(difference.Y), math.abs(difference.Z))
        elseif face.axis == 2 then
            size = Vector3.new(math.abs(difference.X), thickness, math.abs(difference.Z))
        else
            size = Vector3.new(math.abs(difference.X), math.abs(difference.Y), thickness)
        end
        local part = Instance.new("Part")
        part.Name = "Face"
        part.Size = size
        part.CFrame = CFrame.new(center + centerPoint)
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Material = Enum.Material.SmoothPlastic
        part.Color = Config.Palette[face.color]
        part.TopSurface = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        part.Parent = group
        if i % 256 == 0 then task.wait() end
    end
    group.Parent = container
    return totalCount
end

return Renderer
