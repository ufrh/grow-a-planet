-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 7:07 PM CDT

local Guard = require(script.Security.Guard)
local Store = require(script.Core.Store)
local Definition = require(script.Core.Definition)

local VAULT = {
	Stores = {},

	Config = require(script.Config),
	Rules = require(script.Security.Rules),
	Codec = require(script.Serialization.Codec);
}

Guard.AssertServer()

-- compareModules -> boolean
-- Sorts datastore definition modules by name for deterministic startup.
-- @param A, ModuleScript -> First datastore module.
-- @param B, ModuleScript -> Second datastore module.
local function compareModules(A: ModuleScript, B: ModuleScript)
	return A.Name < B.Name;
end

-- Store -> Store?
-- Creates a datastore from a clean definition or retrieves an existing store when no definition is supplied.
-- @param Name, string -> Logical VAULT store name.
-- @param StoreDefinition, table? -> Clean datastore definition.
function VAULT.Store(Name: string, StoreDefinition)
	assert(type(Name) == 'string' and Name ~= '', 'VAULT.Store requires a valid store name.')

	if StoreDefinition == nil then return VAULT.Stores[Name] end

	local Normalized = Definition.Normalize(Name, StoreDefinition)
	local Existing = VAULT.Stores[Normalized.Name]

	if Existing then
		if Normalized.AutoBind then Existing:BindPlayers() end

		return Existing;
	end

	local Created = Store.new(Normalized)

	VAULT.Stores[Normalized.Name] = Created

	if Normalized.AutoBind then Created:BindPlayers() end

	return Created;
end

-- CreateStore -> Store
-- Preserves the original VAULT API while routing definitions through the cleaner normalization layer.
-- @param StoreDefinition, table -> Legacy or clean datastore definition.
function VAULT.CreateStore(StoreDefinition)
	assert(type(StoreDefinition) == 'table', 'VAULT.CreateStore requires a definition table.')
	assert(type(StoreDefinition.Name) == 'string' and StoreDefinition.Name ~= '', 'VAULT.CreateStore requires Definition.Name.')

	return VAULT.Store(StoreDefinition.Name, StoreDefinition);
end

-- Load -> table
-- Loads every datastore definition ModuleScript inside a folder and returns them by logical store name.
-- @param Folder, Instance -> Folder containing datastore definition modules.
function VAULT.Load(Folder: Instance)
	assert(typeof(Folder) == 'Instance', 'VAULT.Load requires a Folder or Instance containing datastore modules.')

	local Modules = {}
	local Result = {}

	for _, Object in ipairs(Folder:GetChildren()) do
		if Object:IsA('ModuleScript') then table.insert(Modules, Object) end
	end

	table.sort(Modules, compareModules)

	for _, Module in ipairs(Modules) do
		local StoreDefinition = require(Module)

		assert(type(StoreDefinition) == 'table', 'VAULT datastore module ' .. Module:GetFullName() .. ' must return a table.')

		if StoreDefinition.Enabled == false then continue end

		local Name = StoreDefinition.Name or Module.Name
		local Created = VAULT.Store(Name, StoreDefinition)

		Result[Name] = Created
	end

	return Result;
end

-- GetStore -> Store?
-- Returns an already-created datastore by logical name.
-- @param Name, string -> Store name.
function VAULT.GetStore(Name: string)
	return VAULT.Stores[Name];
end

-- DestroyStore -> boolean
-- Shuts down and removes one named datastore.
-- @param Name, string -> Store name.
function VAULT.DestroyStore(Name: string)
	local Existing = VAULT.Stores[Name]

	if not Existing then return false end

	Existing:Destroy()
	VAULT.Stores[Name] = nil

	return true;
end

-- DestroyAll -> nil
-- Shuts down every VAULT datastore registered in the current server.
function VAULT.DestroyAll()
	local Names = {}

	for Name in pairs(VAULT.Stores) do table.insert(Names, Name) end
	for _, Name in ipairs(Names) do VAULT.DestroyStore(Name) end
end

return VAULT;
