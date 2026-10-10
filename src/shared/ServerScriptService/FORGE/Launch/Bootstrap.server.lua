-- Grow a Planet's FORGE server launch. No RUCKUS services, data schemas or matchmaking.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerForge = script.Parent.Parent
local NetworkRoot = ServerForge:WaitForChild("Kernel", 10):WaitForChild("Networking", 10)
local ServerBridge = require(NetworkRoot:WaitForChild("ServerBridge", 10))
local Bridge = ServerBridge.new()
Bridge:Start()

local Loaded, FORGE = xpcall(function()
    return require(ReplicatedStorage:WaitForChild("FORGE", 10))
end, debug.traceback)
if not Loaded then
    Bridge:SetBootError(FORGE)
    error("[Grow a Planet] FORGE failed to load: " .. tostring(FORGE))
end

local Roots = {}
local Services = ServerScriptService:FindFirstChild("Services")
if Services then table.insert(Roots, Services) end

local Started, StartError = xpcall(function()
    FORGE.Start({ Roots = Roots, Bridge = Bridge })
end, debug.traceback)
if not Started then
    Bridge:SetBootError(StartError)
    error("[Grow a Planet] FORGE failed to start: " .. tostring(StartError))
end

game:BindToClose(function()
    FORGE.Shutdown()
end)
