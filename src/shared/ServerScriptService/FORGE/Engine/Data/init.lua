local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Root = script

local Guard = require(Root.Security.Guard)
local Store = require(Root.Core.Store)
local Definition = require(Root.Core.Definition)
local GlobalStore = require(Root.Global.GlobalStore)
local Path = require(Root.Util.Path)
local DeepCopy = require(Root.Util.DeepCopy)

local Class = require(ReplicatedStorage.FORGE.Kernel.Core.Class)
local KernelState = require(ReplicatedStorage.FORGE.Kernel.Core.State)
local Types = require(ReplicatedStorage.FORGE.Kernel.Core.Types)

local Data = {
	Stores = {},
	Globals = {},
	Config = require(Root.Config),
	Rules = require(Root.Security.Rules),
	Codec = require(Root.Serialization.Codec),
	_ReplicationProfiles = setmetatable({}, {__mode = 'k'}),
	_ReplicationConnections = {}
}

Guard.AssertServer()

local Bridge = Class.Create('Service', {
	Name = '__FORGE_DATA',
	Priority = -10000
})

Bridge:CreateSignal('Changed')

local function compareModules(A: ModuleScript, B: ModuleScript)
	return A.Name < B.Name
end

local function defaultLimits()
	local Config = Data.Config.DataStore
	return {
		MaxDepth = Config.MaxDepth,
		MaxNodes = Config.MaxNodes,
		MaxStringLength = Config.MaxStringLength,
		MaxEncodedBytes = Config.MaxEncodedBytes
	}
end

local function publicSet(Target, DataPath, Value)
	local Keys = Path.Split(DataPath)
	if #Keys == 0 then return end

	local Current = Target
	for Index = 1, #Keys - 1 do
		local Key = Keys[Index]
		if type(Current[Key]) ~= 'table' then Current[Key] = {} end
		Current = Current[Key]
	end

	Current[Keys[#Keys]] = DeepCopy.Copy(Value)
end

local function publicSnapshot(StoreObject, Profile)
	local Replicate = StoreObject.Replicate or {}
	if #Replicate == 0 then return {} end

	local Snapshot = Profile:Snapshot()
	for _, DataPath in ipairs(Replicate) do
		if DataPath == '*' then return Snapshot end
	end

	local Result = {}
	for _, DataPath in ipairs(Replicate) do
		local Value = Path.Get(Snapshot, DataPath)
		if Value ~= nil then publicSet(Result, DataPath, Value) end
	end

	return Result
end

local function publish(StoreObject, Profile)
	local Player = Profile.Player
	if not KernelState.Started then return end
	if not Player or not Player.Parent then return end
	if #(StoreObject.Replicate or {}) == 0 then return end

	Bridge:FireClient(Player, 'Changed', StoreObject.Name, publicSnapshot(StoreObject, Profile))
end

local function detachProfile(Profile)
	local Entry = Data._ReplicationProfiles[Profile]
	if not Entry then return end
	if Entry.Changed then Entry.Changed:Disconnect() end
	if Entry.Released then Entry.Released:Disconnect() end
	Data._ReplicationProfiles[Profile] = nil
end

local function attachProfile(StoreObject, Profile)
	if Data._ReplicationProfiles[Profile] or #(StoreObject.Replicate or {}) == 0 then return end

	local Entry = {}
	Entry.Changed = Profile.Changed:Connect(function()
		publish(StoreObject, Profile)
	end)
	Entry.Released = Profile.Released:Connect(function()
		detachProfile(Profile)
	end)

	Data._ReplicationProfiles[Profile] = Entry
	publish(StoreObject, Profile)
end

local function bindReplication(StoreObject)
	if #(StoreObject.Replicate or {}) == 0 then return end

	table.insert(Data._ReplicationConnections, StoreObject.Loaded:Connect(function(Profile)
		attachProfile(StoreObject, Profile)
	end))

	for _, Profile in pairs(StoreObject._ProfilesByUserId) do
		attachProfile(StoreObject, Profile)
	end
end

Bridge.Client.Get = function(Player, StoreName)
	StoreName = StoreName or 'Player'
	local StoreObject = Data.Stores[StoreName]
	if not StoreObject then return nil end
	if #(StoreObject.Replicate or {}) == 0 then return {} end

	local Profile = StoreObject:GetProfile(Player) or StoreObject:WaitForProfile(Player, 15)
	if not Profile then return nil end
	return publicSnapshot(StoreObject, Profile)
end

Bridge:ConfigureEndpoint('Get', {
	Rate = false,
	Schema = {
		Types.Optional(Types.String({MinLength = 1, MaxLength = 64}))
	}
})

function Data.Store(Name: string, StoreDefinition)
	assert(type(Name) == 'string' and Name ~= '', 'FORGE.Data.Store requires a valid store name.')
	if StoreDefinition == nil then return Data.Stores[Name] end

	local Normalized = Definition.Normalize(Name, StoreDefinition)
	local Existing = Data.Stores[Normalized.Name]

	if Existing then
		if Normalized.AutoBind then Existing:BindPlayers() end
		return Existing
	end

	local Created = Store.new(Normalized)
	Data.Stores[Normalized.Name] = Created
	bindReplication(Created)
	if Normalized.AutoBind then Created:BindPlayers() end
	return Created
end

function Data.CreateStore(StoreDefinition)
	assert(type(StoreDefinition) == 'table', 'FORGE.Data.CreateStore requires a definition table.')
	assert(type(StoreDefinition.Name) == 'string' and StoreDefinition.Name ~= '', 'FORGE.Data.CreateStore requires Definition.Name.')
	return Data.Store(StoreDefinition.Name, StoreDefinition)
end

function Data.Global(Name: string, Options)
	assert(type(Name) == 'string' and Name ~= '', 'FORGE.Data.Global requires a valid global store name.')
	local Existing = Data.Globals[Name]
	if Existing then return Existing end

	Options = type(Options) == 'table' and Options or {}
	local Scope = type(Options.Scope) == 'string' and Options.Scope ~= '' and Options.Scope or Data.Config.DataStore.Scope
	local Limits = type(Options.Limits) == 'table' and Options.Limits or defaultLimits()
	local Created = GlobalStore.new(Name, Scope, Limits)
	Data.Globals[Name] = Created
	return Created
end

function Data.GetGlobal(Name: string)
	return Data.Globals[Name]
end

function Data.DestroyGlobal(Name: string)
	local Existing = Data.Globals[Name]
	if not Existing then return false end
	Existing:Destroy()
	Data.Globals[Name] = nil
	return true
end

function Data.Load(Folder: Instance)
	assert(typeof(Folder) == 'Instance', 'FORGE.Data.Load requires a Folder or Instance containing datastore modules.')

	local Modules = {}
	local Result = {}

	for _, Object in ipairs(Folder:GetChildren()) do
		if Object:IsA('ModuleScript') then table.insert(Modules, Object) end
	end
	table.sort(Modules, compareModules)

	for _, Module in ipairs(Modules) do
		local StoreDefinition = require(Module)
		assert(type(StoreDefinition) == 'table', 'FORGE.Data datastore module ' .. Module:GetFullName() .. ' must return a table.')
		if StoreDefinition.Enabled == false then continue end

		local Name = StoreDefinition.Name or Module.Name
		local Created = Data.Store(Name, StoreDefinition)
		Result[Name] = Created
	end

	return Result
end

function Data.GetStore(Name: string)
	return Data.Stores[Name]
end

function Data.GetPublicSnapshot(Name: string, Player)
	local StoreObject = Data.Stores[Name]
	if not StoreObject then return nil end

	local Profile = StoreObject:GetProfile(Player)
	if not Profile then return nil end
	return publicSnapshot(StoreObject, Profile)
end

function Data.DestroyStore(Name: string)
	local Existing = Data.Stores[Name]
	if not Existing then return false end

	for Profile in pairs(Data._ReplicationProfiles) do
		if Profile.Store == Existing then detachProfile(Profile) end
	end

	Existing:Destroy()
	Data.Stores[Name] = nil
	return true
end

function Data.DestroyAll()
	local StoreNames = {}
	local GlobalNames = {}

	for Name in pairs(Data.Stores) do table.insert(StoreNames, Name) end
	for Name in pairs(Data.Globals) do table.insert(GlobalNames, Name) end
	for _, Name in ipairs(StoreNames) do Data.DestroyStore(Name) end
	for _, Name in ipairs(GlobalNames) do Data.DestroyGlobal(Name) end

	for _, Connection in ipairs(Data._ReplicationConnections) do Connection:Disconnect() end
	table.clear(Data._ReplicationConnections)
end

return Data
