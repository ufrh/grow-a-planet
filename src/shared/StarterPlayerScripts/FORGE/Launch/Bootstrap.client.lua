-- Grow a Planet FORGE client launch. Controllers are optional during the prototype.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FORGE = require(ReplicatedStorage:WaitForChild("FORGE"))
local PlayerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local Controllers = PlayerScripts:WaitForChild("Controllers", 10)
local Roots = {}
if Controllers then table.insert(Roots, Controllers) end

FORGE.Start({ Roots = Roots })
