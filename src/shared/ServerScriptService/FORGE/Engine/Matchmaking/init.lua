-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 1:10 PM CDT


local Root = script

local Arrival = require(Root.Arrival)
local Config = require(Root.Config)
local Dispatcher = require(Root.Dispatcher)
local Queue = require(Root.Queue)
local Rating = require(Root.Rating)
local Storage = require(Root.Storage)
local Stats = require(Root.Stats)
local Teleport = require(Root.Teleport)

local Matchmaking


Matchmaking = {
	Config = Config,
	Rating = Rating,
	Arrival = Arrival,
	Queues = {};
} do
	local LookupStorage = Storage.new('__lookup', Config)

	local Runtime = {
		Config = Config,
		Dispatcher = Dispatcher.new(Config),
		Teleport = Teleport.new(Config);
	}

	local GlobalStats = Stats.new()
	Matchmaking.Stats = GlobalStats

	local Connections = {}
	local Extensions = {}
	local Started = false
	local Destroyed = false

	Matchmaking.Extensions = Extensions

	function Matchmaking.AttachExtension(Name, Extension)
		assert(type(Name) == 'string' and Name ~= '', 'FORGE.Matchmaking.AttachExtension requires a name.')
		assert(type(Extension) == 'table', 'FORGE.Matchmaking.AttachExtension requires an extension table.')
		assert(not Extensions[Name], 'FORGE matchmaking extension already exists: ' .. Name)
		Extensions[Name] = Extension
		if Started and type(Extension.Start) == 'function' then Extension:Start() end
		return Extension;
	end

	function Matchmaking.DetachExtension(Name)
		local Extension = Extensions[Name]
		if not Extension then return false end
		if type(Extension.Stop) == 'function' then Extension:Stop() end
		if type(Extension.Destroy) == 'function' then Extension:Destroy() end
		Extensions[Name] = nil
		if Matchmaking.Test == Extension then Matchmaking.Test = nil end
		return true;
	end

	-- containsUser -> boolean
	-- Returns whether one stored match explicitly contains a Roblox user id.
	-- @param Match, table -> Stored match record.
	-- @param UserId, number -> User id being checked.
	local function containsUser(Match, UserId: number)
		if type(Match) ~= 'table' or type(Match.Users) ~= 'table' then return false end
		for _, Existing in ipairs(Match.Users) do if Existing == UserId then return true end end
		return false;
	end

	-- onDispatch -> nil
	-- Routes one cross-server assignment hint into the matching local queue.
	-- @param Payload, table -> Assignment hint.
	local function onDispatch(Payload)
		if type(Payload) ~= 'table' or type(Payload.Queue) ~= 'string' then return end
		local Existing = Matchmaking.Queues[Payload.Queue]
		if Existing then Existing:OnDispatch(Payload) end
	end

	-- onTeleportFailed -> nil
	-- Routes exhausted teleport retries back into the queue that owns the assignment.
	-- @param Player, Player -> Failed player.
	-- @param Result, any -> Roblox teleport result.
	-- @param Message, string -> Failure message.
	-- @param Assignment, table -> Failed assignment.
	local function onTeleportFailed(Player, Result, Message, Assignment)
		if type(Assignment) ~= 'table' or type(Assignment.Queue) ~= 'string' then return end
		local Existing = Matchmaking.Queues[Assignment.Queue]
		if Existing then Existing:OnTeleportFailed(Player, Result, Message, Assignment) end
	end

	-- CreateQueue -> MatchmakingQueue
	-- Creates a named global queue with party tickets, stake/mode isolation, hidden-MMR expansion and reserved-server allocation.
	-- @param Name, string -> Logical queue name.
	-- @param Definition, table -> Queue configuration.
	function Matchmaking.CreateQueue(Name: string, Definition)
		assert(type(Name) == 'string' and Name ~= '', 'FORGE.Matchmaking.CreateQueue requires a queue name.')
		assert(not Matchmaking.Queues[Name], 'FORGE matchmaking queue already exists: ' .. Name)
		local Normalized = Queue.Normalize(Name, Definition, Config)
		local Created = Queue.new(Name, Normalized, Runtime)
		Matchmaking.Queues[Name] = Created
		if Normalized.TrackStats ~= false then GlobalStats:TrackQueue(Name, Created) end
		if Started then Created:Start() end
		return Created;
	end

	-- GetQueue -> MatchmakingQueue?
	-- Returns one named queue.
	-- @param Name, string -> Queue name.
	function Matchmaking.GetQueue(Name: string)
		return Matchmaking.Queues[Name];
	end

	-- RemoveQueue -> boolean
	-- Destroys one named queue and removes it from the runtime registry.
	-- @param Name, string -> Queue name.
	function Matchmaking.RemoveQueue(Name: string)
		local Existing = Matchmaking.Queues[Name]
		if not Existing then return false end
		GlobalStats:UntrackQueue(Name)
		Existing:Destroy()
		Matchmaking.Queues[Name] = nil
		return true;
	end

	-- GetArrival -> table?
	-- Returns validated FORGE matchmaking teleport data for one arriving player.
	-- @param Player, Player -> Arriving player.
	function Matchmaking.GetArrival(Player: Player)
		return Arrival.Get(Player);
	end

	-- GetTeam -> number?
	-- Returns one arriving player's assigned team number.
	-- @param Player, Player -> Arriving player.
	function Matchmaking.GetTeam(Player: Player)
		return Arrival.Team(Player);
	end

	-- GetCurrentMatch -> table?
	-- Resolves the server-only shared match record for one player arriving from FORGE matchmaking.
	-- @param Player, Player -> Arriving player.
	function Matchmaking.GetCurrentMatch(Player: Player)
		local Data = Arrival.Get(Player)
		if not Data then return nil end
		local Success, Match = LookupStorage:GetMatch(Data.MatchId)
		if not Success or type(Match) ~= 'table' or Match.Status ~= 'Ready' or Match.Queue ~= Data.Queue then return nil end
		if Data.Stake ~= nil and Match.Stake ~= Data.Stake then return nil end
		if Data.Mode ~= nil and Match.Mode ~= Data.Mode then return nil end
		if not containsUser(Match, Player.UserId) then return nil end
		if type(Match.Teams) == 'table' and tonumber(Match.Teams[tostring(Player.UserId)]) ~= tonumber(Data.Teams and Data.Teams[tostring(Player.UserId)]) then return nil end
		return Match;
	end

	-- GetMatch -> table?
	-- Reads one server-only shared match record without requiring the destination place to recreate its source queue.
	-- @param MatchId, string -> Match id.
	function Matchmaking.GetMatch(MatchId: string)
		local Success, Match = LookupStorage:GetMatch(MatchId)
		return Success and type(Match) == 'table' and Match.Status == 'Ready' and Match or nil;
	end

	-- GetQueueNames -> {string}
	-- Returns sorted logical queue names without exposing the runtime registry table.
	function Matchmaking.GetQueueNames()
		local Result = {}
		for Name in pairs(Matchmaking.Queues) do table.insert(Result, Name) end
		table.sort(Result)
		return Result;
	end

	-- HasQueue -> boolean
	-- Returns whether one named matchmaking queue exists.
	function Matchmaking.HasQueue(Name: string)
		return Matchmaking.Queues[Name] ~= nil;
	end

	-- CreateStandardQueue -> MatchmakingQueue
	-- Creates a common production queue while keeping MemoryStore, leases, dispatch, ticket storage and teleport infrastructure internal.
	function Matchmaking.CreateStandardQueue(Name: string, PlaceId: number, MinPlayers: number, TargetPlayers: number, MaxPlayers: number, TeamCount: number?, TeamSize: number?, Stake: string?, Mode: string?, AllowPartial: boolean?, MMREnabled: boolean?, MMRDefault: number?, MMRInitialRange: number?, MMRExpandPerSecond: number?, MMRMaxRange: number?)
		local StakeName = type(Stake) == 'string' and Stake ~= '' and Stake or 'default'
		local ModeName = type(Mode) == 'string' and Mode ~= '' and Mode or 'default'
		local Teams
		if (tonumber(TeamCount) or 0) > 0 and (tonumber(TeamSize) or 0) > 0 then Teams = {Count = math.floor(TeamCount); Size = math.floor(TeamSize);} end
		return Matchmaking.CreateQueue(Name, {
			PlaceId = math.floor(tonumber(PlaceId) or game.PlaceId);
			Players = {Min = math.floor(tonumber(MinPlayers) or 2); Target = math.floor(tonumber(TargetPlayers) or tonumber(MinPlayers) or 2); Max = math.floor(tonumber(MaxPlayers) or tonumber(TargetPlayers) or tonumber(MinPlayers) or 2);};
			Teams = Teams;
			Stakes = {StakeName;};
			DefaultStake = StakeName;
			Modes = {ModeName;};
			DefaultMode = ModeName;
			AllowPartial = AllowPartial == true;
			TrackStats = true;
			MMR = {
				Enabled = MMREnabled ~= false;
				Default = tonumber(MMRDefault) or 1000;
				InitialRange = math.max(tonumber(MMRInitialRange) or 100, 0);
				ExpandPerSecond = math.max(tonumber(MMRExpandPerSecond) or 10, 0);
				MaxRange = math.max(tonumber(MMRMaxRange) or 1000, tonumber(MMRInitialRange) or 100);
			};
		});
	end

	-- Join -> boolean, table?, string?
	-- Queues one player/party by logical queue name through the safe public queue API.
	function Matchmaking.Join(QueueName: string, Targets, Stake: string?, Mode: string?, Data, TTL: number?)
		local Existing = Matchmaking.GetQueue(QueueName)
		if not Existing then return false, nil, 'matchmaking queue does not exist: ' .. tostring(QueueName) end
		local Options = {
			Stake = type(Stake) == 'string' and Stake ~= '' and Stake or nil;
			Mode = type(Mode) == 'string' and Mode ~= '' and Mode or nil;
			Data = type(Data) == 'table' and Data or {};
			TTL = tonumber(TTL);
		}
		local Success, Result = Existing:Join(Targets, Options)
		if Success then return true, Result, nil end
		return false, nil, tostring(Result);
	end

	-- Leave -> boolean, string?
	-- Removes one player/ticket from a named queue.
	function Matchmaking.Leave(QueueName: string, Target, Reason: string?)
		local Existing = Matchmaking.GetQueue(QueueName)
		if not Existing then return false, 'matchmaking queue does not exist: ' .. tostring(QueueName) end
		return Existing:Leave(Target, Reason);
	end

	-- GetStatus -> table?
	-- Returns public queue membership/ticket/assignment state for one player.
	function Matchmaking.GetStatus(QueueName: string, Player: Player)
		local Existing = Matchmaking.GetQueue(QueueName)
		return Existing and Existing:GetStatus(Player) or nil;
	end

	-- IsQueued -> boolean
	-- Returns whether one player currently has queue status in the named queue.
	function Matchmaking.IsQueued(QueueName: string, Player: Player)
		return Matchmaking.GetStatus(QueueName, Player) ~= nil;
	end

	-- GetTicket -> table?
	-- Returns one ticket by player, user id or ticket id within a named queue.
	function Matchmaking.GetTicket(QueueName: string, Target)
		local Existing = Matchmaking.GetQueue(QueueName)
		return Existing and Existing:GetTicket(Target) or nil;
	end

	-- GetQueueSize -> number?
	-- Returns the approximate global queue size for one logical queue.
	function Matchmaking.GetQueueSize(QueueName: string)
		local Existing = Matchmaking.GetQueue(QueueName)
		return Existing and Existing:GetSize() or nil;
	end

	-- RetryTeleport -> boolean, string?
	-- Retries dispatch for one locally owned matched ticket without exposing TeleportService internals.
	function Matchmaking.RetryTeleport(QueueName: string, Target)
		local Existing = Matchmaking.GetQueue(QueueName)
		if not Existing then return false, 'matchmaking queue does not exist: ' .. tostring(QueueName) end
		return Existing:RetryTeleport(Target);
	end

	-- IsReservedServer -> boolean
	-- Returns whether this server is a reserved matchmaking destination.
	function Matchmaking.IsReservedServer()
		return Arrival.IsReservedServer();
	end

	-- GetStats -> table
	-- Returns the cached public universe/session/live matchmaking telemetry snapshot.
	function Matchmaking.GetStats()
		return GlobalStats:GetSnapshot();
	end

	-- RefreshStats -> table
	-- Forces a persistent telemetry refresh before returning the public snapshot.
	function Matchmaking.RefreshStats()
		return GlobalStats:Refresh();
	end

	-- Start -> nil
	-- Starts global assignment delivery, teleport retry handling, diagnostics and all queues created before FORGE startup.
	function Matchmaking.Start()
		assert(not Destroyed, 'FORGE.Matchmaking has been destroyed.')
		if Started then return end
		Started = true
		GlobalStats:Start()
		Runtime.Dispatcher:Start()
		Runtime.Teleport:Start()
		table.insert(Connections, Runtime.Dispatcher.Received:Connect(onDispatch))
		table.insert(Connections, Runtime.Teleport.Failed:Connect(onTeleportFailed))
		for _, Existing in pairs(Matchmaking.Queues) do Existing:Start() end
		for _, Extension in pairs(Extensions) do if type(Extension.Start) == 'function' then Extension:Start() end end
	end

	-- Stop -> nil
	-- Stops queue workers, diagnostics and assignment delivery without deleting queue definitions.
	function Matchmaking.Stop()
		if not Started then return end
		Started = false
		for _, Existing in pairs(Matchmaking.Queues) do Existing:Stop() end
		for _, Connection in ipairs(Connections) do Connection:Disconnect() end
		Connections = {}
		Runtime.Dispatcher:Stop()
		Runtime.Teleport:Stop()
		for _, Extension in pairs(Extensions) do if type(Extension.Stop) == 'function' then Extension:Stop() end end
		GlobalStats:Stop()
	end

	-- Destroy -> nil
	-- Fully tears down matchmaking queues, diagnostics, messaging, teleports and local signals.
	function Matchmaking.Destroy()
		if Destroyed then return end
		Matchmaking.Stop()
		for Name, Extension in pairs(Extensions) do
			if type(Extension.Destroy) == 'function' then Extension:Destroy() end
			Extensions[Name] = nil
		end
		Matchmaking.Test = nil
		local Names = {}
		for Name in pairs(Matchmaking.Queues) do table.insert(Names, Name) end
		for _, Name in ipairs(Names) do Matchmaking.RemoveQueue(Name) end
		Runtime.Dispatcher:Destroy()
		Runtime.Teleport:Destroy()
		GlobalStats:Destroy()
		Destroyed = true
	end
end

return Matchmaking;
