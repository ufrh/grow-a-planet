local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

local RuntimeMatchmaking = script.Parent.Parent.Parent:WaitForChild('Engine'):WaitForChild('Matchmaking')
local Arrival = require(RuntimeMatchmaking.Arrival)
local LiveTransport = require(script.Parent.LiveTransport)
local SelfTest = require(script.Parent.SelfTest)
local Simulator = require(script.Parent.Simulator)

local Harness = {} do
	Harness.__index = Harness
	Harness.ClassName = 'MatchmakingHarness'

	-- new -> MatchmakingHarness
	-- Creates the optional isolated matchmaking lab using only modules present in the current FORGE tree.
	-- @param RuntimeConfig, table -> Matchmaking configuration.
	-- @param GlobalStats, MatchmakingGlobalStats -> Persistent real-game telemetry provider.
	function Harness.new(Matchmaking, RuntimeConfig, GlobalStats)
		local this = setmetatable({}, Harness)
		this.Matchmaking = Matchmaking
		this.Config = RuntimeConfig
		this.Stats = GlobalStats
		this.Simulator = Simulator.new(RuntimeConfig)
		this.Folder = nil
		this.Command = nil
		this.Update = nil
		this.Connection = nil
		this.PlayerConnection = nil
		this.Running = false
		this.Accumulator = 0
		this.LastSelfTest = nil
		this.LastProbe = nil
		this.DestinationOnly = false
		return this;
	end

	-- IsAvailable -> boolean
	-- Keeps the diagnostics transport available in Studio and published servers while command authorization remains player-specific.
	function Harness:IsAvailable()
		local Ruckus = ReplicatedStorage:FindFirstChild('RUCKUS')
		local Manifest = Ruckus and Ruckus:FindFirstChild('PlaceManifest')
		if Manifest and Manifest:IsA('ModuleScript') then
			local Success, Value = pcall(require, Manifest)
			if Success and type(Value) == 'table' and Value.Role ~= 'MainMenu' then return false end
		end
		if RunService:IsStudio() then return self.Config.Test.EnabledInStudio == true end
		return self.Config.Test.EnablePublishedDiagnostics ~= false;
	end

	-- _ConfiguredTester -> boolean
	-- Resolves explicit public-server diagnostics testers from config or the runtime game attribute.
	-- @param Player, Player -> Requesting player.
	function Harness:_ConfiguredTester(Player: Player)
		local AttributeId = tonumber(game:GetAttribute('FORGEMatchmakingTesterUserId'))
		if AttributeId and AttributeId > 0 and Player.UserId == AttributeId then return true end
		for _, UserId in ipairs(self.Config.Test.AuthorizedUserIds or {}) do if Player.UserId == tonumber(UserId) then return true end end
		return false;
	end

	-- _Authorized -> boolean
	-- Restricts diagnostics and pseudo matchmaking to Studio, the experience creator, explicit testers, private-server ownership or authenticated solo-test arrivals.
	-- @param Player, Player -> Requesting player.
	function Harness:_Authorized(Player: Player)
		if not Player or not Player.Parent then return false end
		if RunService:IsStudio() then return true end
		if self.Config.Test.AllowCreatorInLive ~= false and game.CreatorType == Enum.CreatorType.User and Player.UserId == game.CreatorId then return true end
		if self:_ConfiguredTester(Player) then return true end
		if game.PrivateServerOwnerId > 0 and Player.UserId == game.PrivateServerOwnerId then return true end
		if game.PrivateServerOwnerId == 0 and game.PrivateServerId ~= '' then
			local ArrivalData = Arrival.Get(Player)
			if type(ArrivalData) == 'table' and ArrivalData.Test == true and ArrivalData.TestType == 'SoloTransport' then return true end
		end
		local Allowed = LiveTransport.IsAuthorized(Player)
		return Allowed == true;
	end

	-- _HasAuthorizedPlayer -> boolean
	-- Returns whether this server currently contains anyone allowed to open the diagnostics bridge.
	function Harness:_HasAuthorizedPlayer()
		for _, Player in ipairs(Players:GetPlayers()) do if self:_Authorized(Player) then return true end end
		return false;
	end

	-- _EnsureBridge -> nil
	-- Creates the replicated diagnostics bridge only after an authorized player is actually present.
	function Harness:_EnsureBridge()
		if self.Folder and self.Folder.Parent then return end
		if not self:_HasAuthorizedPlayer() then return end
		self:_CreateBridge()
	end

	-- _Snapshot -> table
	-- Builds one complete UI-safe diagnostics snapshot personalized with authoritative solo-transport status for the requesting real player.
	-- @param Player, Player? -> Optional requesting player.
	function Harness:_Snapshot(Player: Player?)
		local Snapshot = self.Simulator:Snapshot()
		Snapshot.SelfTest = self.LastSelfTest
		Snapshot.ServiceProbe = self.LastProbe
		Snapshot.Environment = RunService:IsStudio() and 'STUDIO' or (game.PrivateServerId == '' and 'PUBLIC SERVER' or (game.PrivateServerOwnerId > 0 and 'PRIVATE SERVER' or 'RESERVED SERVER'))
		Snapshot.Real = self.Stats:GetSnapshot()
		if Player then
			-- lookup -> table?
			-- Resolves the authoritative destination match for one requesting player.
			-- @param Target, Player -> Arriving player.
			local function lookup(Target)
				return self.Matchmaking and self.Matchmaking.GetCurrentMatch and self.Matchmaking.GetCurrentMatch(Target) or nil;
			end
			Snapshot.SoloTransport = LiveTransport.GetStatus(Player, lookup)
		end
		return Snapshot;
	end

	-- _Push -> nil
	-- Sends personalized diagnostics snapshots to authorized connected test clients.
	function Harness:_Push()
		if not self.Update then return end
		for _, Player in ipairs(Players:GetPlayers()) do if self:_Authorized(Player) then self.Update:FireClient(Player, self:_Snapshot(Player)) end end
	end

	-- _RunSelfTest -> table
	-- Runs deterministic production-rule and allocation-pipeline tests and stores the latest report.
	function Harness:_RunSelfTest()
		self.LastSelfTest = SelfTest.Run()
		self.Simulator.Metrics:Log('SELF TEST • ' .. tostring(self.LastSelfTest.Passed) .. '/' .. tostring(self.LastSelfTest.Total) .. ' passed')
		for _, Item in ipairs(self.LastSelfTest.Tests) do if not Item.Passed then self.Simulator.Metrics:Log('TEST FAIL • ' .. Item.Name .. ' • ' .. Item.Message) end end
		return self.LastSelfTest;
	end

	-- _RunProbe -> table
	-- Runs opt-in external Roblox service probes and stores the latest report.
	function Harness:_RunProbe()
		self.LastProbe = SelfTest.Probe()
		self.Simulator.Metrics:Log('SERVICE PROBE • ' .. tostring(self.LastProbe.Passed) .. ' passed • ' .. tostring(self.LastProbe.Unavailable) .. ' unavailable')
		for _, Item in ipairs(self.LastProbe.Results) do if Item.Status ~= 'PASS' then self.Simulator.Metrics:Log('PROBE ' .. Item.Status .. ' • ' .. Item.Name .. ' • ' .. Item.Message) end end
		return self.LastProbe;
	end

	-- _GetSoloQueue -> MatchmakingQueue?
	-- Creates one isolated MemoryStoreQueue namespace using the exact production Ruckus queue definition so live testing cannot consume or delay real production tickets.
	function Harness:_GetSoloQueue()
		if not self.Matchmaking or not self.Matchmaking.GetQueue then return nil end
		local Name = 'Ruckus__SoloTransport'
		local Existing = self.Matchmaking.GetQueue(Name)
		if Existing then return Existing end
		local Base = self.Matchmaking.GetQueue('Ruckus')
		if not Base then return nil end
		local Definition = Base.Definition
		local Raw = {Destination = {PlaceId = Definition.PlaceId;}; Players = {Min = Definition.Players.Min; Target = Definition.Players.Target; Max = Definition.Players.Max;}; Teams = Definition.Teams and {Count = Definition.Teams.Count; Size = Definition.Teams.Size;} or nil; AllowPartial = Definition.AllowPartial; Stakes = table.clone(Definition.Stakes.List); DefaultStake = Definition.Stakes.Default; Modes = table.clone(Definition.Modes.List); DefaultMode = Definition.Modes.Default; MMR = {Enabled = Definition.MMR.Enabled; Default = Definition.MMR.Default; InitialRange = Definition.MMR.InitialRange; ExpandPerSecond = Definition.MMR.ExpandPerSecond; MaxRange = Definition.MMR.MaxRange; Resolve = Definition.MMR.Resolve;}; TicketTTL = Definition.TicketTTL; Worker = true; CanMatch = Definition.CanMatch; BuildGameplayData = Definition.BuildGameplayData; BuildMatchMetadata = Definition.BuildMatchMetadata; ResolvePriority = Definition.ResolvePriority; TrackStats = false;}
		return self.Matchmaking.CreateQueue(Name, Raw);
	end

	-- _Command -> any
	-- Executes one validated diagnostics command from the Studio panel.
	-- @param Player, Player -> Requesting Studio player.
	-- @param Name, string -> Command name.
	-- @param Payload, table? -> Command payload.
	function Harness:_Command(Player: Player, Name: string, Payload)
		if not self:IsAvailable() then return {Ok = false; Error = 'matchmaking test harness is disabled';} end
		if not self:_Authorized(Player) then return {Ok = false; Error = 'matchmaking test harness is not authorized for this player';} end
		Payload = type(Payload) == 'table' and Payload or {}
		if Name == 'Snapshot' then return {Ok = true; Snapshot = self:_Snapshot(Player);} end
		if Name == 'Spawn' then return {Ok = true; Created = self.Simulator:SpawnSingles(math.clamp(tonumber(Payload.Count) or 1, 1, 100), Payload.Stake, Payload.Mode); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Party' then return {Ok = true; Created = self.Simulator:SpawnParty(math.clamp(tonumber(Payload.Size) or 2, 1, self.Config.MaxPartySize), Payload.Stake, Payload.Mode); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Stress' then return {Ok = true; Created = self.Simulator:SpawnStress(100); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Cancel' then return {Ok = self.Simulator:CancelRandom(); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Auto' then return {Ok = true; Enabled = self.Simulator:SetAuto(Payload.Enabled == true); Snapshot = self:_Snapshot(Player);} end
		if Name == 'FailureRate' then return {Ok = true; Value = self.Simulator:SetFailureRate(tonumber(Payload.Value) or 0); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Profile' then return {Ok = self.Simulator:SetProfile(tostring(Payload.Name or '')); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Stake' then return {Ok = self.Simulator:SetStake(tostring(Payload.Name or '')); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Mode' then return {Ok = self.Simulator:SetMode(tostring(Payload.Name or '')); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Clear' then self.Simulator:Reset(); return {Ok = true; Snapshot = self:_Snapshot(Player);} end
		if Name == 'SelfTest' then return {Ok = true; Report = self:_RunSelfTest(); Snapshot = self:_Snapshot(Player);} end
		if Name == 'Probe' then return {Ok = true; Report = self:_RunProbe(); Snapshot = self:_Snapshot(Player);} end
		if Name == 'RefreshReal' then self.Stats:Refresh(); return {Ok = true; Snapshot = self:_Snapshot(Player);} end
		if Name == 'SoloTransport' then
			local QueueObject = self:_GetSoloQueue()
			if not QueueObject then return {Ok = false; Error = 'Ruckus production queue is not available in this place'; Snapshot = self:_Snapshot(Player);} end
			local Success, Result = LiveTransport.Start(QueueObject, Player, tostring(Payload.Stake or 'Standard'), tostring(Payload.Mode or 'FFA'))
			return {Ok = Success; Error = Success and nil or tostring(Result); SoloTransport = Success and Result or nil; Snapshot = self:_Snapshot(Player);};
		end
		if Name == 'SoloCancel' then
			local QueueObject = self:_GetSoloQueue()
			if not QueueObject then return {Ok = false; Error = 'Ruckus production queue is not available in this place'; Snapshot = self:_Snapshot(Player);} end
			local Success, Result = LiveTransport.Cancel(QueueObject, Player)
			return {Ok = Success; Error = Success and nil or tostring(Result); Snapshot = self:_Snapshot(Player);};
		end
		return {Ok = false; Error = 'unknown matchmaking test command: ' .. tostring(Name);};
	end

	-- _CreateBridge -> nil
	-- Creates the authorization-gated RemoteFunction/RemoteEvent pair used by the draggable diagnostics panel.
	function Harness:_CreateBridge()
		local ForgeRoot = ReplicatedStorage:WaitForChild('FORGE')
		local Existing = ForgeRoot:FindFirstChild('__MatchmakingTest')
		if Existing then Existing:Destroy() end
		local Folder = Instance.new('Folder')
		Folder.Name = '__MatchmakingTest'
		Folder.Parent = ForgeRoot
		local Command = Instance.new('RemoteFunction')
		Command.Name = 'Command'
		Command.Parent = Folder
		local Update = Instance.new('RemoteEvent')
		Update.Name = 'Update'
		Update.Parent = Folder

		-- onInvoke -> any
		-- Forwards one test-panel request into the environment-gated harness command router.
		-- @param Player, Player -> Requesting player.
		-- @param Name, string -> Command name.
		-- @param Payload, table? -> Command payload.
		local function onInvoke(Player, Name, Payload)
			return self:_Command(Player, Name, Payload);
		end

		Command.OnServerInvoke = onInvoke
		self.Folder = Folder
		self.Command = Command
		self.Update = Update
	end

	-- _Heartbeat -> nil
	-- Advances the synthetic clock and emits throttled diagnostics snapshots.
	-- @param Delta, number -> Heartbeat delta time.
	function Harness:_Heartbeat(Delta: number)
		if not self.Running then return end
		if not self.DestinationOnly then self.Simulator:Step(math.min(Delta, .5)) end
		self.Accumulator += Delta
		if self.Accumulator < self.Config.Test.UpdateInterval then return end
		self.Accumulator = 0
		self:_Push()
	end

	-- Start -> boolean
	-- Starts the authorization-gated diagnostics transport; published public servers stay dormant until a trusted tester joins.
	function Harness:Start()
		if self.Running then return true end
		if not self:IsAvailable() then return false end
		self.Running = true
		self.Accumulator = 0
		self.DestinationOnly = false
		self:_EnsureBridge()

		if RunService:IsStudio() and self.Folder then
			self:_RunSelfTest()
			self.Simulator:SpawnSingles(self.Config.Test.InitialPseudoPlayers)
		end

		-- onPlayerAdded -> nil
		-- Lazily opens the replicated diagnostics bridge when a trusted live tester joins a published server.
		-- @param Player, Player -> Joining player.
		local function onPlayerAdded(Player)
			if not self:_Authorized(Player) then return end
			self:_EnsureBridge()
			if self.Update then task.defer(function() if Player.Parent and self:_Authorized(Player) then self.Update:FireClient(Player, self:_Snapshot(Player)) end end) end
		end

		-- onHeartbeat -> nil
		-- Forwards RunService heartbeat into the isolated simulator only while the trusted diagnostics bridge exists.
		-- @param Delta, number -> Heartbeat delta time.
		local function onHeartbeat(Delta)
			if not self.Folder then return end
			self:_Heartbeat(Delta)
		end

		self.PlayerConnection = Players.PlayerAdded:Connect(onPlayerAdded)
		self.Connection = RunService.Heartbeat:Connect(onHeartbeat)
		return true;
	end

	-- Stop -> nil
	-- Stops simulator updates and removes the Studio diagnostics transport.
	function Harness:Stop()
		if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
		if self.PlayerConnection then self.PlayerConnection:Disconnect(); self.PlayerConnection = nil end
		if self.Folder then self.Folder:Destroy(); self.Folder = nil end
		self.Command = nil
		self.Update = nil
		self.Running = false
		self.DestinationOnly = false
	end

	-- Destroy -> nil
	-- Fully tears down the harness and clears synthetic state.
	function Harness:Destroy()
		self:Stop()
		self.Simulator:Reset()
		LiveTransport.Destroy()
	end
end

return Harness;
