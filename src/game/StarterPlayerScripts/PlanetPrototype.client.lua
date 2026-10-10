--!strict
-- Grow a Planet 0.5: seeded sphere + axis-aligned radial voxel tree previews.
-- No default Roblox character, no gameplay UI, no persistence.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Generation = ReplicatedStorage:WaitForChild("GrowAPlanet"):WaitForChild("Generation")
local Config = require(Generation:WaitForChild("Config"))
local Field = require(Generation:WaitForChild("VoxelField"))
local Mesher = require(Generation:WaitForChild("GreedyMesher"))
local CuboidMesher = require(Generation:WaitForChild("CuboidMesher"))
local TreeGenerator = require(Generation:WaitForChild("TreeGenerator"))
local Renderer = require(Generation:WaitForChild("Renderer"))

if RunService:IsStudio() then
    local ok, err = pcall(function()
        require(Generation:WaitForChild("SelfTest")).run()
    end)
    if not ok then warn("[Grow a Planet] Geometry self-test failed: " .. tostring(err)) end
end

while not Workspace.CurrentCamera do task.wait() end
local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = Config.Camera.FieldOfView

local planetFolder = Instance.new("Folder")
planetFolder.Name = "GeneratedPlanets"
planetFolder.Parent = Workspace

-- The overlay is intentionally hidden until F3; the default scene is only stars + planet.
local gui = Instance.new("ScreenGui")
gui.Name = "PlanetDebug"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Parent = Player:WaitForChild("PlayerGui")

local panel = Instance.new("TextLabel")
panel.Name = "Stats"
panel.Size = UDim2.fromOffset(375, 246)
panel.Position = UDim2.fromOffset(16, 16)
panel.BackgroundColor3 = Color3.fromRGB(15, 18, 29)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.TextColor3 = Color3.fromRGB(237, 231, 221)
panel.Font = Enum.Font.Code
panel.TextSize = 14
panel.TextXAlignment = Enum.TextXAlignment.Left
panel.TextYAlignment = Enum.TextYAlignment.Top
panel.TextWrapped = false
panel.Visible = false
panel.Text = "Planet generator starting..."
panel.Parent = gui

local inset = Instance.new("UIPadding")
inset.PaddingLeft = UDim.new(0, 12)
inset.PaddingTop = UDim.new(0, 10)
inset.Parent = panel

local yaw = math.rad(-30)
local pitch = math.rad(16)
local distance = Config.Camera.InitialDistance
local mouseDragging = false
local activeTouch: InputObject? = nil
local previousPinchScale: number? = nil
local mode = if Renderer.meshSupported() then "mesh" else "parts"
local fallbackFloor = 1
local forcedTier: number? = nil
local desiredTier: number? = nil
local desiredSeed = Config.Seed
local buildTicket = 0
local workerRunning = false
local active: any = nil
local status = "Initializing"

if mode == "parts" then
    warn("[Grow a Planet] EditableMesh unavailable; rendering full solid cube Parts with automatic safety LOD.")
end

local function dispose(result)
    if not result then return end
    result.folder:Destroy()
    for _, editable in ipairs(result.editables) do
        editable:Destroy()
    end
end

local function buildPlanet(tier, seed, ticket)
    local staging = Instance.new("Folder")
    staging.Name = string.format("Seed_%d_LOD_%d", seed, tier)
    local editables = {}
    local quads = 0
    local chunks = 0
    local surfaceCubes = 0
    local cuboids = 0
    local treeCount = 0
    local treeVoxelCount = 0
    local startedAt = os.clock()
    local currentMode = mode
    local sampleCount = 0

    local function checkCancelled()
        if buildTicket ~= ticket then error("GENERATION_CANCELLED", 0) end
    end

    local ok, failure = xpcall(function()
        local voxelSize = Config.VoxelSizes[tier]
        local field = Field.new(seed, voxelSize, function() return buildTicket ~= ticket end)
        checkCancelled()
        sampleCount = field.Samples

        if currentMode == "mesh" then
            -- A solid voxel volume is represented as only its visible cube
            -- faces; greedy triangles share exact grid corners.
            Mesher.forEachChunk(field, function(faces, chunk)
                checkCancelled()
                local name = string.format("Chunk_%d_%d_%d", chunk[1], chunk[2], chunk[3])
                local editable = Renderer.addMeshChunk(faces, name, staging, Config.Center)
                table.insert(editables, editable)
                quads += #faces
                chunks += 1
                if chunks % 2 == 0 then task.wait() end
            end)
        else
            -- The fallback builds ONLY real exposed solid voxel cubes.
            -- Compute a full-planet cuboid count before instancing any Parts,
            -- to avoid freezing the client with tens of thousands of objects.
            field:prepareSurface(function() return buildTicket ~= ticket end)
            checkCancelled()
            surfaceCubes = field.SurfaceCubes
            local pending = {}
            cuboids = CuboidMesher.forEachChunk(field, function(boxes, chunk)
                table.insert(pending, { boxes = boxes, chunk = chunk })
            end, function() return buildTicket ~= ticket end)
            checkCancelled()
            for _, record in ipairs(pending) do
                local chunk = record.chunk
                local name = string.format("Chunk_%d_%d_%d", chunk[1], chunk[2], chunk[3])
                Renderer.addCubesChunk(record.boxes, name, staging, Config.Center)
                chunks += 1
                checkCancelled()
            end
        end
        -- Visual test: axis-aligned cubes at 2x the planet resolution,
        -- assembled into radial trunks/branches/canopies at different angles.
        -- A tree failure must not make the existing planet disappear.
        if Config.TestTrees.Enabled then
            local treeRoot = Instance.new("Folder")
            treeRoot.Name = "RadialVoxelTreeTests"
            treeRoot.Parent = staging

            for index = 1, Config.TestTrees.Count do
                checkCancelled()
                local treeTier = tier
                local displayed = false
                while not displayed and treeTier <= #Config.VoxelSizes do
                    local treeFolder = Instance.new("Folder")
                    treeFolder.Name = "Tree_" .. index .. "_LOD_" .. treeTier
                    treeFolder.Parent = treeRoot
                    local previousEditables = #editables
                    local okTree, errorTree = pcall(function()
                        local field = TreeGenerator.make(seed, treeTier, index,
                            function() return buildTicket ~= ticket end)
                        checkCancelled()
                        assert(field.WoodCount > 0 and field.LeafCount > 0,
                            "Test tree has no wood or foliage")

                        local treeChunks = 0
                        if currentMode == "mesh" then
                            Mesher.forEachChunk(field, function(faces, chunk)
                                checkCancelled()
                                local name = string.format("Chunk_%d_%d_%d", chunk[1], chunk[2], chunk[3])
                                local editable = Renderer.addMeshChunk(faces, name,
                                    treeFolder, field.Center, Config.TestTrees.Colors)
                                table.insert(editables, editable)
                                treeChunks += 1
                                if treeChunks % 2 == 0 then task.wait() end
                            end)
                        else
                            field:prepareSurface(function() return buildTicket ~= ticket end)
                            checkCancelled()
                            local pending = {}
                            CuboidMesher.forEachChunk(field, function(boxes, chunk)
                                table.insert(pending, {boxes = boxes, chunk = chunk})
                            end, function() return buildTicket ~= ticket end,
                                Config.TestTrees.MaxPartsPerTree)

                            for _, record in ipairs(pending) do
                                checkCancelled()
                                local chunk = record.chunk
                                local name = string.format("Chunk_%d_%d_%d", chunk[1], chunk[2], chunk[3])
                                Renderer.addCubesChunk(record.boxes, name, treeFolder,
                                    field.Center, Config.TestTrees.Colors)
                                treeChunks += 1
                            end
                        end
                        checkCancelled()
                        assert(treeChunks > 0, "Tree renderer produced no visible chunks")
                        treeCount += 1
                        treeVoxelCount += field.WoodCount + field.LeafCount
                    end)

                    if okTree then
                        displayed = true
                    else
                        treeFolder:Destroy()
                        for i = #editables, previousEditables + 1, -1 do
                            editables[i]:Destroy()
                            table.remove(editables, i)
                        end
                        if buildTicket ~= ticket then error("GENERATION_CANCELLED", 0) end
                        if currentMode == "parts" and treeTier < #Config.VoxelSizes then
                            treeTier += 1
                        else
                            warn(string.format(
                                "[Grow a Planet] Test tree %d could not render at LOD %d: %s",
                                index, treeTier, tostring(errorTree)
                            ))
                            break
                        end
                    end
                end
            end
        end
        checkCancelled()
        if chunks == 0 then error("Planet generated zero surface chunks.") end
    end, debug.traceback)

    if not ok then
        staging:Destroy()
        for _, editable in ipairs(editables) do editable:Destroy() end
        error(failure, 0)
    end
    return {
        folder = staging,
        editables = editables,
        quads = quads,
        surfaceCubes = surfaceCubes,
        cuboids = cuboids,
        treeCount = treeCount,
        treeVoxelCount = treeVoxelCount,
        chunks = chunks,
        samples = sampleCount,
        seconds = os.clock() - startedAt,
        tier = tier,
        seed = seed,
        mode = currentMode,
    }
end

local function launchWorker()
    if workerRunning then return end
    workerRunning = true
    task.spawn(function()
        while desiredTier do
            local ticket = buildTicket
            local tier = desiredTier
            local seed = desiredSeed
            status = string.format("Generating LOD %d...", tier)
            local ok, result = pcall(buildPlanet, tier, seed, ticket)

            if ok then
                if ticket == buildTicket then
                    result.folder.Parent = planetFolder
                    local old = active
                    active = result
                    dispose(old)
                    status = string.format("Ready (%.2fs)", result.seconds)
                    print(string.format(
                        "[Grow a Planet] Seed %d | %.5f-stud planet cells | %d logical grid cells | %d faces | %d surface cubes | %d cuboids | %d chunks | %d trees | %s | %.2fs",
                        seed, Config.VoxelSizes[tier], result.samples, result.quads,
                        result.surfaceCubes, result.cuboids, result.chunks, result.treeCount,
                        result.mode, result.seconds
                    ))
                else
                    dispose(result)
                end
            elseif ticket == buildTicket then
                local errorMessage = tostring(result)
                if mode == "mesh" then
                    -- A mesh may be creatable but fail when converted to a MeshPart
                    -- due to API entitlement or a device memory budget.
                    warn("[Grow a Planet] Mesh rendering failed; switching to safe Parts fallback: " .. errorMessage)
                    mode = "parts"
                    desiredTier = math.max(tier, fallbackFloor)
                    buildTicket += 1
                elseif mode == "parts"
                    and string.find(errorMessage, "FALLBACK_PART_BUDGET", 1, true)
                    and tier < #Config.VoxelSizes then
                    fallbackFloor = math.max(fallbackFloor, tier + 1)
                    desiredTier = fallbackFloor
                    buildTicket += 1
                    warn(string.format("[Grow a Planet] Too many solid cuboids for LOD %d; trying LOD %d.", tier, fallbackFloor))
                elseif not string.find(errorMessage, "GENERATION_CANCELLED", 1, true) then
                    warn("[Grow a Planet] Generation failed: " .. errorMessage)
                    status = "Generation failed (see Output)"
                    desiredTier = nil
                end
            end

            if ticket == buildTicket then break end
        end
        workerRunning = false
    end)
end

local function requestGeneration(tier, seed)
    local safeTier = if mode == "parts" then math.max(tier, fallbackFloor) else tier
    if desiredTier == safeTier and desiredSeed == seed then return end
    desiredTier = safeTier
    desiredSeed = seed
    buildTicket += 1
    launchWorker()
end

local function distanceTier()
    if forcedTier then return forcedTier end
    -- Hysteresis prevents rebuilding repeatedly when hovering around a boundary.
    local reference = if active then active.tier else nil
    local hysteresis = Config.LODHysteresis
    if reference == 1 then
        return if distance > Config.NearDistance + hysteresis then 2 else 1
    elseif reference == 2 then
        if distance < Config.NearDistance - hysteresis then return 1 end
        if distance > Config.FarDistance + hysteresis then return 3 end
        return 2
    elseif reference == 3 then
        return if distance < Config.FarDistance - hysteresis
            then (if distance < Config.NearDistance then 1 else 2)
            else 3
    end
    if distance < Config.NearDistance then return 1 end
    if distance < Config.FarDistance then return 2 end
    return 3
end

-- Show a cheap preview while the first high-res surface is being generated.
requestGeneration(3, Config.Seed)

local dragging = false
local function orbit(dx, dy)
    yaw -= dx * Config.Camera.OrbitSpeed
    pitch = math.clamp(pitch - dy * Config.Camera.OrbitSpeed, math.rad(-82), math.rad(82))
end

local function zoom(amount)
    distance = math.clamp(distance + amount, Config.Camera.MinDistance, Config.Camera.MaxDistance)
end

UserInputService.InputBegan:Connect(function(input, handled)
    if handled then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
        mouseDragging = true
        dragging = true
    elseif input.UserInputType == Enum.UserInputType.Touch and not activeTouch then
        activeTouch = input
        dragging = true
    elseif input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.F3 then
            panel.Visible = not panel.Visible
        elseif input.KeyCode == Enum.KeyCode.R then
            local newSeed = Random.new():NextInteger(1, 2000000000)
            requestGeneration(distanceTier(), newSeed)
        elseif input.KeyCode == Enum.KeyCode.One then
            forcedTier = 1
            requestGeneration(1, desiredSeed)
        elseif input.KeyCode == Enum.KeyCode.Two then
            forcedTier = 2
            requestGeneration(2, desiredSeed)
        elseif input.KeyCode == Enum.KeyCode.Three then
            forcedTier = 3
            requestGeneration(3, desiredSeed)
        elseif input.KeyCode == Enum.KeyCode.Zero then
            forcedTier = nil
            requestGeneration(distanceTier(), desiredSeed)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
        mouseDragging = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        dragging = mouseDragging or activeTouch ~= nil
    elseif input == activeTouch then
        activeTouch = nil
        dragging = mouseDragging
    end
end)

UserInputService.InputChanged:Connect(function(input, handled)
    if handled then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement and mouseDragging then
        orbit(input.Delta.X, input.Delta.Y)
    elseif input.UserInputType == Enum.UserInputType.MouseWheel then
        zoom(-input.Position.Z * 2.8)
    elseif input == activeTouch then
        orbit(input.Delta.X, input.Delta.Y)
    end
end)

UserInputService.TouchPinch:Connect(function(_, scale, _, state, handled)
    if handled then return end
    if state == Enum.UserInputState.Begin then
        previousPinchScale = scale
    elseif state == Enum.UserInputState.Change and previousPinchScale and scale > 0 then
        zoom(distance * (previousPinchScale / scale - 1))
        previousPinchScale = scale
    else
        previousPinchScale = nil
    end
end)

local lodTimer = 0
local debugTimer = 0
local previewPending = true
RunService:BindToRenderStep("GrowAPlanetOrbitCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not dragging then yaw += Config.Camera.AutoRotationSpeed * dt end
    local cp = math.cos(pitch)
    local position = Config.Center + Vector3.new(
        math.sin(yaw) * cp * distance,
        math.sin(pitch) * distance,
        math.cos(yaw) * cp * distance
    )
    camera = Workspace.CurrentCamera or camera
    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfView = Config.Camera.FieldOfView
    camera.CFrame = CFrame.lookAt(position, Config.Center)
    camera.Focus = CFrame.new(Config.Center)

    lodTimer += dt
    if lodTimer >= 0.4 then
        lodTimer = 0
        if active then
            if previewPending then
                previewPending = false
                requestGeneration(distanceTier(), desiredSeed)
            else
                requestGeneration(distanceTier(), desiredSeed)
            end
        end
    end

    debugTimer += dt
    if panel.Visible and debugTimer >= 0.35 then
        debugTimer = 0
        local current = active
        panel.Text = string.format(
            "GROW A PLANET — PROTOTYPE 0.5\nSeed: %d\nLOD: %s  Cell: %s studs\nRenderer: %s\nChunks: %d  Faces: %d\nSurface cubes: %d  Boxes: %d\nTrees: %d  Tree voxels: %d\nTree cell: %.5f studs\nRadius: %.2f—%.2f\nCamera distance: %.1f\nStatus: %s\n\nDrag: orbit  Scroll/pinch: zoom\nR: new seed  1/2/3: LOD  0: auto",
            desiredSeed,
            current and tostring(current.tier) or "-",
            current and tostring(Config.VoxelSizes[current.tier]) or "-",
            mode,
            current and current.chunks or 0,
            current and current.quads or 0,
            current and current.surfaceCubes or 0,
            current and current.cuboids or 0,
            current and current.treeCount or 0,
            current and current.treeVoxelCount or 0,
            current and Config.VoxelSizes[current.tier] * Config.TestTrees.VoxelRatio or 0,
            Config.MinSurfaceRadius, Config.MaxSurfaceRadius,
            distance,
            status
        )
    end
end)
