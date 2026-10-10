local HttpService = game:GetService('HttpService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Signal = require(ReplicatedStorage.FORGE.Kernel.Core.Signal)

local Coordinator = require(script.Parent.Coordinator)
local Rating = require(script.Parent.Rating)
local Rules = require(script.Parent.Rules)
local Sanitizer = require(script.Parent.Sanitizer)
local Storage = require(script.Parent.Storage)
local Ticket = require(script.Parent.Ticket)

local Queue = {} do
	Queue.__index = Queue
	Queue.ClassName = 'MatchmakingQueue'

	local function normalizePlayers(Source, Teams, AllowPartial: boolean)
		Source = type(Source) == 'table' and Source or {}
		local TeamTarget = Teams and Teams.Count * Teams.Size or nil
		local Target = tonumber(Source.Target) or TeamTarget or tonumber(Source.Max) or tonumber(Source.Min) or 2
		local Min = tonumber(Source.Min) or (AllowPartial and math.max(2, math.floor(Target * .6)) or Target)
		local Max = tonumber(Source.Max) or Target
		assert(Min >= 1 and Min % 1 == 0, 'Matchmaking Players.Min must be a positive integer.')
		assert(Target >= Min and Target % 1 == 0, 'Matchmaking Players.Target must be an integer greater than or equal to Min.')
		assert(Max >= Target and Max % 1 == 0, 'Matchmaking Players.Max must be an integer greater than or equal to Target.')
		assert(Max <= 100, 'Matchmaking Players.Max cannot exceed 100.')
		return {Min = Min; Target = Target; Max = Max;};
	end

	local function normalizeTeams(Source)
		if Source == nil then return nil end
		assert(type(Source) == 'table', 'Matchmaking Teams must be a table.')
		local Count = tonumber(Source.Count)
		local Size = tonumber(Source.Size)
		assert(Count and Count >= 1 and Count % 1 == 0, 'Matchmaking Teams.Count must be a positive integer.')
		assert(Size and Size >= 1 and Size % 1 == 0, 'Matchmaking Teams.Size must be a positive integer.')
		return {Count = Count; Size = Size;};
	end

	local function normalizeMMR(Source)
		Source = type(Source) == 'table' and Source or {}
		local Enabled = Source.Enabled ~= false
		local Default = tonumber(Source.Default) or 1000
		local InitialRange = tonumber(Source.InitialRange) or 100
		local ExpandPerSecond = tonumber(Source.ExpandPerSecond) or 10
		local MaxRange = tonumber(Source.MaxRange) or math.max(InitialRange, 1000)
		assert(Default == Default and Default ~= math.huge and Default ~= -math.huge, 'Matchmaking MMR.Default must be finite.')
		assert(InitialRange >= 0 and ExpandPerSecond >= 0 and MaxRange >= InitialRange, 'Matchmaking MMR ranges are invalid.')
		if Source.Resolve ~= nil then assert(type(Source.Resolve) == 'function', 'Matchmaking MMR.Resolve must be a function.') end
		return {Enabled = Enabled; Default = Default; InitialRange = InitialRange; ExpandPerSecond = ExpandPerSecond; MaxRange = MaxRange; Resolve = Source.Resolve;};
	end

	local function normalizeStakes(Source, DefaultStake: string?)
		if Source == nil then return {List = {'default';}; Map = {default = 'default';}; Default = 'default';}; end
		assert(type(Source) == 'table' and #Source > 0, 'Matchmaking Stakes must be a non-empty array of strings.')
		local List = {}
		local Map = {}
		for _, Name in ipairs(Source) do
			assert(type(Name) == 'string' and Name ~= '', 'Matchmaking stake names must be non-empty strings.')
			local Key = string.lower(Name)
			assert(not Map[Key], 'Matchmaking Stakes contains a duplicate stake: ' .. Name)
			Map[Key] = Name
			table.insert(List, Name)
		end
		local Default
		if DefaultStake ~= nil then
			assert(type(DefaultStake) == 'string' and Map[string.lower(DefaultStake)], 'Matchmaking DefaultStake must exist in Stakes.')
			Default = Map[string.lower(DefaultStake)]
		elseif #List == 1 then
			Default = List[1]
		end
		return {List = List; Map = Map; Default = Default;};
	end

	local function normalizeModes(Source, DefaultMode: string?)
		if Source == nil then return {List = {'default';}; Map = {default = 'default';}; Default = 'default';}; end
		assert(type(Source) == 'table' and #Source > 0, 'Matchmaking Modes must be a non-empty array of strings.')
		local List = {}
		local Map = {}
		for _, Name in ipairs(Source) do
			assert(type(Name) == 'string' and Name ~= '', 'Matchmaking mode names must be non-empty strings.')
			local Key = string.lower(Name)
			assert(not Map[Key], 'Matchmaking Modes contains a duplicate mode: ' .. Name)
			Map[Key] = Name
			table.insert(List, Name)
		end
		local Default
		if DefaultMode ~= nil then assert(type(DefaultMode) == 'string' and Map[string.lower(DefaultMode)], 'Matchmaking DefaultMode must exist in Modes.'); Default = Map[string.lower(DefaultMode)] elseif #List == 1 then Default = List[1] end
		return {List = List; Map = Map; Default = Default;};
	end

	local function normalizeDestination(Definition)
		local Destination = type(Definition.Destination) == 'table' and Definition.Destination or {}
		local PlaceId = tonumber(Destination.PlaceId or Definition.PlaceId or Definition.DestinationPlaceId) or game.PlaceId
		assert(PlaceId >= 0 and PlaceId % 1 == 0, 'Matchmaking destination PlaceId must be a non-negative integer.')
		return PlaceId;
	end

	local function normalizeJoinOptions(StakeOrOptions, Data)
		if type(StakeOrOptions) == 'string' then return {Stake = StakeOrOptions; Data = Data or {};}; end
		if StakeOrOptions == nil then return {Data = Data or {};}; end
		assert(type(StakeOrOptions) == 'table', 'Matchmaking Join expects a stake string or options table.')
		local Result = table.clone(StakeOrOptions)
		if Data ~= nil and Result.Data == nil then Result.Data = Data end
		return Result;
	end

	function Queue.Normalize(Name: string, Definition, Config)
		assert(type(Definition) == 'table', 'FORGE.Matchmaking.CreateQueue requires a definition table.')
		local Teams = normalizeTeams(Definition.Teams)
		local AllowPartial = Definition.AllowPartial == true
		local PlayerRules = normalizePlayers(Definition.Players, Teams, AllowPartial)
		if Teams then assert(Teams.Count * Teams.Size >= PlayerRules.Target, 'Matchmaking Teams capacity is smaller than Players.Target.') end
		local TicketTTL = tonumber(Definition.TicketTTL) or Config.TicketTTL
		assert(TicketTTL >= 15 and TicketTTL <= 3600, 'Matchmaking TicketTTL must be between 15 and 3600 seconds.')
		local PreTeleportDelay = tonumber(Definition.PreTeleportDelay) or 0
		assert(PreTeleportDelay == PreTeleportDelay and PreTeleportDelay >= 0 and PreTeleportDelay < math.huge, 'Matchmaking PreTeleportDelay must be a finite non-negative number.')
		local StakeRules = normalizeStakes(Definition.Stakes, Definition.DefaultStake)
		local ModeRules = normalizeModes(Definition.Modes, Definition.DefaultMode)
		return {
			Name = Name;
			PlaceId = normalizeDestination(Definition);
			Players = PlayerRules;
			Teams = Teams;
			Stakes = StakeRules;
			Modes = ModeRules;
			MMR = normalizeMMR(Definition.MMR or Definition.Skill);
			Skill = normalizeMMR(Definition.MMR or Definition.Skill);
			TicketTTL = TicketTTL;
			PreTeleportDelay = PreTeleportDelay;
			AllowPartial = AllowPartial;
			Worker = Definition.Worker ~= false;
			TrackStats = Definition.TrackStats ~= false;
			CanMatch = Definition.CanMatch;
			BuildGameplayData = Definition.BuildGameplayData;
			BuildMatchMetadata = Definition.BuildMatchMetadata;
			ResolvePriority = Definition.ResolvePriority;
		};
	end

	function Queue.new(Name: string, Definition, Runtime)
		local this = setmetatable({}, Queue)
		this.Name = Name
		this.Definition = Definition
		this.Runtime = Runtime
		this.Config = Runtime.Config
		this.Storage = Runtime.StorageFactory and Runtime.StorageFactory(Name, Runtime.Config) or Storage.new(Name, Runtime.Config)
		this.Coordinator = Runtime.CoordinatorFactory and Runtime.CoordinatorFactory(this.Storage, Name, Runtime.Config) or Coordinator.new(this.Storage, Name, Runtime.Config)
		this.LocalTickets = {}
		this.Connections = {}
		this.Running = false
		this.RunSerial = 0
		this.NextLeaseRefresh = 0
		this.Queued = Signal.new()
		this.Cancelled = Signal.new()
		this.MatchFound = Signal.new()
		this.MatchCreated = Signal.new()
		this.Teleporting = Signal.new()
		this.TeleportFailed = Signal.new()
		this.Error = Signal.new()
		return this;
	end

	function Queue:_Now()
		local Clock = self.Runtime.Clock
		if Clock and type(Clock.Now) == 'function' then return Clock:Now() end
		return os.time();
	end

	function Queue:_GenerateMatchId()
		local Id = self.Runtime.Id
		if Id and type(Id.Next) == 'function' then return Id:Next('MATCH') end
		return HttpService:GenerateGUID(false);
	end

	function Queue:_ResolveStake(Value: string?)
		local Requested = Value or self.Definition.Stakes.Default
		assert(type(Requested) == 'string' and Requested ~= '', 'Matchmaking requires a selected stake.')
		local Canonical = self.Definition.Stakes.Map[string.lower(Requested)]
		assert(Canonical, 'Unknown matchmaking stake: ' .. Requested)
		return Canonical;
	end

	function Queue:_ResolveMode(Value: string?)
		local Requested = Value or self.Definition.Modes.Default
		assert(type(Requested) == 'string' and Requested ~= '', 'Matchmaking requires a selected mode.')
		local Canonical = self.Definition.Modes.Map[string.lower(Requested)]
		assert(Canonical, 'Unknown matchmaking mode: ' .. Requested)
		return Canonical;
	end

	function Queue:_ResolveMMRs(Targets, Stake: string, Mode: string)
		local Values = {}
		local ByUser = {}
		local Resolver = self.Definition.MMR.Resolve
		for _, Player in ipairs(Targets) do
			local Value = self.Definition.MMR.Default
			if Resolver then
				local Success, Result = pcall(Resolver, Player, Stake, Mode)
				assert(Success, 'Matchmaking MMR.Resolve failed: ' .. tostring(Result))
				assert(type(Result) == 'number', 'Matchmaking MMR.Resolve must return a number.')
				Value = Result
			end
			assert(Value == Value and Value ~= math.huge and Value ~= -math.huge, 'Matchmaking MMR must be finite.')
			ByUser[tostring(Player.UserId)] = Value
			table.insert(Values, Value)
		end
		return Rating.Average(Values), ByUser;
	end

	function Queue:_ResolvePriority(Targets, Stake: string, Mode: string)
		if not self.Definition.ResolvePriority then return 0 end
		local Success, Result = pcall(self.Definition.ResolvePriority, Targets, Stake, Mode)
		assert(Success and type(Result) == 'number', 'Matchmaking ResolvePriority must return a number.')
		return Result;
	end

	function Queue:_NormalizeTargets(Targets)
		if typeof(Targets) == 'Instance' and Targets:IsA('Player') then Targets = {Targets;} end
		assert(type(Targets) == 'table' and #Targets > 0, 'Matchmaking Join requires a Player or non-empty Player array.')
		assert(#Targets <= self.Config.MaxPartySize, 'Matchmaking party exceeds MaxPartySize.')
		if self.Definition.Teams then assert(#Targets <= self.Definition.Teams.Size, 'Matchmaking party is larger than one team.') end
		local Seen = {}
		local Result = {}
		for _, Player in ipairs(Targets) do
			assert(typeof(Player) == 'Instance' and Player:IsA('Player') and Player.Parent == Players, 'Matchmaking party contains a player outside this server.')
			assert(not Seen[Player.UserId], 'Matchmaking party contains a duplicate player.')
			Seen[Player.UserId] = true
			table.insert(Result, Player)
		end
		return Result;
	end

	function Queue:_ReleaseMemberships(TicketValue)
		if type(TicketValue) ~= 'table' or type(TicketValue.Users) ~= 'table' then return end
		for _, UserId in ipairs(TicketValue.Users) do self.Storage:ReleaseMembership(UserId, TicketValue.Id) end
	end

	function Queue:_RemoveLocal(TicketId: string)
		self.LocalTickets[TicketId] = nil
	end

	function Queue:Join(Targets, StakeOrOptions, Data)
		local Options = normalizeJoinOptions(StakeOrOptions, Data)
		local Party = self:_NormalizeTargets(Targets)
		local Stake = self:_ResolveStake(Options.Stake or Options.Pool)
		local Mode = self:_ResolveMode(Options.Mode)
		local MMR, MMRs = self:_ResolveMMRs(Party, Stake, Mode)
		local Resolved = {Stake = Stake; Mode = Mode; MMR = MMR; MMRs = MMRs; Priority = self:_ResolvePriority(Party, Stake, Mode); Data = Options.Data or Options.Metadata or {}; TTL = math.clamp(tonumber(Options.TTL) or self.Definition.TicketTTL, 15, self.Definition.TicketTTL); Test = Options.Test == true; TestType = Options.TestType; TestSessionId = Options.TestSessionId;}
		local TicketValue = Ticket.Create(self.Name, Party, Resolved, self.Definition, self.Config)
		local Claimed = {}
		for _, UserId in ipairs(TicketValue.Users) do
			local Success, Reason = self.Storage:ClaimMembership(UserId, TicketValue)
			if not Success then
				for _, ClaimedUserId in ipairs(Claimed) do self.Storage:ReleaseMembership(ClaimedUserId, TicketValue.Id) end
				return false, Reason or 'player is already queued';
			end
			table.insert(Claimed, UserId)
		end
		local Stored, StoreReason = self.Storage:SetTicket(TicketValue)
		if not Stored then self:_ReleaseMemberships(TicketValue); return false, tostring(StoreReason) end
		local Enqueued, QueueReason = self.Storage:Enqueue(TicketValue)
		if not Enqueued then self.Storage:RemoveTicket(TicketValue.Id); self:_ReleaseMemberships(TicketValue); return false, tostring(QueueReason) end
		self.LocalTickets[TicketValue.Id] = {Ticket = TicketValue; Players = Party; Assigned = false; Dispatched = false;}
		self.Queued:Fire(TicketValue)
		return true, TicketValue;
	end

	function Queue:JoinParty(Targets, StakeOrOptions, Data)
		return self:Join(Targets, StakeOrOptions, Data);
	end

	function Queue:InjectSyntheticTestTicket(UserId: number, Options)
		assert(type(Options) == 'table', 'Synthetic test ticket options must be a table.')
		local Stake = self:_ResolveStake(Options.Stake)
		local Mode = self:_ResolveMode(Options.Mode)
		local MMR = tonumber(Options.MMR) or self.Definition.MMR.Default
		assert(MMR == MMR and MMR ~= math.huge and MMR ~= -math.huge, 'Synthetic test MMR must be finite.')
		local TicketValue = Ticket.CreateSynthetic(self.Name, UserId, {Stake = Stake; Mode = Mode; MMR = MMR; Priority = tonumber(Options.Priority) or 0; Data = Options.Data or {}; TTL = math.clamp(tonumber(Options.TTL) or self.Definition.TicketTTL, 15, self.Definition.TicketTTL); TestSessionId = Options.TestSessionId;}, self.Definition, self.Config)
		local Claimed, ClaimReason = self.Storage:ClaimMembership(UserId, TicketValue)
		if not Claimed then return false, tostring(ClaimReason or 'synthetic membership claim failed') end
		local Stored, StoreReason = self.Storage:SetTicket(TicketValue)
		if not Stored then self.Storage:ReleaseMembership(UserId, TicketValue.Id); return false, tostring(StoreReason) end
		local Enqueued, QueueReason = self.Storage:Enqueue(TicketValue)
		if not Enqueued then self.Storage:RemoveTicket(TicketValue.Id); self.Storage:ReleaseMembership(UserId, TicketValue.Id); return false, tostring(QueueReason) end
		return true, TicketValue;
	end

	function Queue:_ResolveTicketId(Target)
		if type(Target) == 'string' then return Target end
		local UserId
		if typeof(Target) == 'Instance' and Target:IsA('Player') then UserId = Target.UserId elseif type(Target) == 'number' then UserId = Target end
		if not UserId then return nil end
		local Success, Membership = self.Storage:GetMembership(UserId)
		if not Success or type(Membership) ~= 'table' or Membership.Queue ~= self.Name then return nil end
		return Membership.TicketId;
	end

	function Queue:Leave(Target, Reason: string?)
		local TicketId = self:_ResolveTicketId(Target)
		if not TicketId then return false, 'player is not queued in this queue' end
		local Found, TicketValue = self.Storage:GetTicket(TicketId)
		if not Found or type(TicketValue) ~= 'table' then return false, 'ticket no longer exists' end
		if TicketValue.Status == 'Matched' then return false, 'ticket already matched' end
		local Cancelled, CancelReason = self.Storage:CancelTicket(TicketId, Reason or 'left queue')
		if not Cancelled then return false, CancelReason end
		self:_ReleaseMemberships(TicketValue)
		self:_RemoveLocal(TicketId)
		self.Cancelled:Fire(TicketValue, Reason or 'left queue')
		return true;
	end

	function Queue:GetTicket(Target)
		local TicketId = self:_ResolveTicketId(Target)
		if not TicketId then return nil end
		local Success, TicketValue = self.Storage:GetTicket(TicketId)
		return Success and TicketValue or nil;
	end

	function Queue:_PublicTicket(TicketValue)
		return {Id = TicketValue.Id; Queue = TicketValue.Queue; Stake = TicketValue.Stake or TicketValue.Pool; Mode = TicketValue.Mode; Users = table.clone(TicketValue.Users or {}); Size = TicketValue.Size; Priority = TicketValue.Priority; CreatedAt = TicketValue.CreatedAt; UpdatedAt = TicketValue.UpdatedAt; ExpiresAt = TicketValue.ExpiresAt; Status = TicketValue.Status;};
	end

	function Queue:GetStatus(Player: Player)
		local Success, Membership = self.Storage:GetMembership(Player.UserId)
		if not Success or type(Membership) ~= 'table' or Membership.Queue ~= self.Name then return nil end
		local TicketSuccess, TicketValue = self.Storage:GetTicket(Membership.TicketId)
		if not TicketSuccess or type(TicketValue) ~= 'table' then return nil end
		local AssignmentSuccess, Assignment = self.Storage:GetAssignment(Membership.TicketId)
		local StatusAssignment
		if AssignmentSuccess and type(Assignment) == 'table' then StatusAssignment = {MatchId = Assignment.MatchId; Queue = Assignment.Queue; TicketId = Assignment.TicketId; Stake = Assignment.Stake; Mode = Assignment.Mode; PlaceId = Assignment.PlaceId; Teams = Assignment.Teams; CreatedAt = Assignment.CreatedAt; ExpiresAt = Assignment.ExpiresAt;} end
		return {Membership = Membership; Ticket = self:_PublicTicket(TicketValue); Assignment = StatusAssignment;};
	end

	function Queue:GetSize()
		local Success, Size = self.Storage:GetQueueSize()
		return Success and Size or nil;
	end

	function Queue:_RollbackClaims(Selected, MatchId: string)
		for _, Record in ipairs(Selected) do self.Storage:RollbackTicket(Record.Ticket, MatchId) end
	end

	function Queue:_BuildMatchContext(MatchId: string, Selected, Stake: string, Mode: string, Teams)
		local Tickets = {}
		local Users = {}
		local RealUsers = {}
		local SyntheticUsers = {}
		local MMRs = {}
		local IsTest = false
		local TestType
		local TestSessionId
		for _, Record in ipairs(Selected) do
			local TicketValue = Record.Ticket
			table.insert(Tickets, TicketValue)
			if TicketValue.Test == true then IsTest = true; TestType = TestType or TicketValue.TestType; TestSessionId = TestSessionId or TicketValue.TestSessionId end
			for _, UserId in ipairs(TicketValue.Users) do
				table.insert(Users, UserId)
				if TicketValue.Synthetic == true then table.insert(SyntheticUsers, UserId) else table.insert(RealUsers, UserId) end
				local Key = tostring(UserId)
				MMRs[Key] = type(TicketValue.MMRs) == 'table' and TicketValue.MMRs[Key] or TicketValue.MMR or TicketValue.Skill or 0
			end
		end
		return {MatchId = MatchId; Queue = self.Name; Stake = Stake; Mode = Mode; PlaceId = self.Definition.PlaceId; Users = Users; RealUsers = RealUsers; SyntheticUsers = SyntheticUsers; Teams = Teams; Tickets = Tickets; MMR = Rating.WeightedAverage(Tickets); MMRs = MMRs; Test = IsTest; TestType = TestType; TestSessionId = TestSessionId;};
	end

	function Queue:_BuildGameplayData(Context)
		local Builder = self.Definition.BuildGameplayData
		local Result = {}
		if Builder then
			local Success, Value = pcall(Builder, Context)
			if not Success then error('BuildGameplayData failed: ' .. tostring(Value)) end
			Result = Sanitizer.Copy(Value or {}, self.Config)
		elseif self.Definition.BuildMatchMetadata then
			local Success, Value = pcall(self.Definition.BuildMatchMetadata, Context.Tickets)
			if not Success then error('BuildMatchMetadata failed: ' .. tostring(Value)) end
			Result = Sanitizer.Copy(Value or {}, self.Config)
		end
		if Context.Test == true then Result.__FORGE_TEST = {Type = Context.TestType; SessionId = Context.TestSessionId; RealUsers = table.clone(Context.RealUsers or {}); SyntheticUsers = table.clone(Context.SyntheticUsers or {}); TargetPlayers = #(Context.Users or {});}; end
		return Result;
	end

	function Queue:_CreateMatch(Selected)
		local MatchId = self:_GenerateMatchId()
		local Claimed = {}
		for _, Record in ipairs(Selected) do
			local Success, Reason = self.Storage:ClaimTicket(Record.Ticket, MatchId)
			if not Success then self:_RollbackClaims(Claimed, MatchId); return false, Reason or 'ticket claim failed' end
			table.insert(Claimed, Record)
		end
		local Teams = Rules.BalanceTeams(Selected, self.Definition)
		if not Teams then self:_RollbackClaims(Selected, MatchId); return false, 'team balancing failed' end
		local Reserved, AccessCode, PrivateServerId = self.Runtime.Teleport:Reserve(self.Definition.PlaceId)
		if not Reserved then self:_RollbackClaims(Selected, MatchId); return false, tostring(AccessCode) end
		local Stake = tostring(Selected[1].Ticket.Stake or Selected[1].Ticket.Pool or 'default')
		local Mode = tostring(Selected[1].Ticket.Mode or 'default')
		local Context = self:_BuildMatchContext(MatchId, Selected, Stake, Mode, Teams)
		local DataSuccess, GameplayData = pcall(Queue._BuildGameplayData, self, Context)
		if not DataSuccess then self:_RollbackClaims(Selected, MatchId); return false, tostring(GameplayData) end
		local Now = self:_Now()
		local Match = {Id = MatchId; Queue = self.Name; Stake = Stake; Mode = Mode; Status = 'Allocating'; PlaceId = self.Definition.PlaceId; AccessCode = AccessCode; PrivateServerId = PrivateServerId; Teams = Teams; MMR = Context.MMR; MMRs = Context.MMRs; GameplayData = GameplayData; Metadata = GameplayData; Tickets = {}; Users = Context.Users; RealUsers = Context.RealUsers; SyntheticUsers = Context.SyntheticUsers; Test = Context.Test == true; TestType = Context.TestType; TestSessionId = Context.TestSessionId; CreatedAt = Now; ExpiresAt = Now + self.Config.MatchTTL;}
		for _, Record in ipairs(Selected) do table.insert(Match.Tickets, Record.Ticket.Id) end
		local Stored, StoreReason = self.Storage:SetMatch(Match)
		if not Stored then self:_RollbackClaims(Selected, MatchId); return false, tostring(StoreReason) end
		local WrittenAssignments = {}
		for _, Record in ipairs(Selected) do
			local Assignment = {MatchId = MatchId; Queue = self.Name; Stake = Stake; Mode = Mode; TicketId = Record.Ticket.Id; PlaceId = Match.PlaceId; AccessCode = AccessCode; PrivateServerId = PrivateServerId; Teams = Teams; Test = Context.Test == true; TestType = Context.TestType; TestSessionId = Context.TestSessionId; CreatedAt = Now; ExpiresAt = Now + self.Config.AssignmentTTL;}
			local AssignmentStored, AssignmentReason = self.Storage:SetAssignment(Record.Ticket.Id, Assignment)
			if not AssignmentStored then
				for _, TicketId in ipairs(WrittenAssignments) do self.Storage:RemoveAssignment(TicketId) end
				self.Storage:RemoveMatch(MatchId)
				self:_RollbackClaims(Selected, MatchId)
				return false, tostring(AssignmentReason)
			end
			table.insert(WrittenAssignments, Record.Ticket.Id)
		end
		Match.Status = 'Ready'
		local Activated, ActivateReason = self.Storage:SetMatch(Match)
		if not Activated then
			for _, TicketId in ipairs(WrittenAssignments) do self.Storage:RemoveAssignment(TicketId) end
			self.Storage:RemoveMatch(MatchId)
			self:_RollbackClaims(Selected, MatchId)
			return false, tostring(ActivateReason)
		end
		for _, Record in ipairs(Selected) do self.Storage:RemoveReceipt(Record.Receipt) end
		self.Runtime.Dispatcher:Publish({Queue = self.Name; MatchId = MatchId; Stake = Stake; Mode = Mode; TicketIds = WrittenAssignments;})
		self.MatchCreated:Fire(Match, Context, Selected)
		return true, Match;
	end

	function Queue:_WorkerCycle()
		local Candidates = {}
		local Seen = {}
		local Now = self:_Now()
		for _ = 1, self.Config.ReadBatch do
			local Read, Item = self.Storage:ReadOne()
			if not Read then self.Error:Fire('queue read failed', Item); return end
			if not Item then break end
			if Seen[Item.TicketId] then self.Storage:RemoveReceipt(Item.Receipt); continue end
			Seen[Item.TicketId] = true
			local Found, TicketValue = self.Storage:GetTicket(Item.TicketId)
			if not Found then continue end
			if not Ticket.IsActive(TicketValue, self.Name, Now) then self.Storage:RemoveReceipt(Item.Receipt); continue end
			table.insert(Candidates, {Ticket = TicketValue; Receipt = Item.Receipt;})
		end
		local Selected = Rules.Select(Candidates, self.Definition, Now)
		if not Selected then return end
		local Success, Result = self:_CreateMatch(Selected)
		if not Success then self.Error:Fire('match allocation failed', Result, {Test = Selected[1] and Selected[1].Ticket and Selected[1].Ticket.Test == true; TestSessionId = Selected[1] and Selected[1].Ticket and Selected[1].Ticket.TestSessionId or nil;}) end
	end

	function Queue:_WorkerLoop(Serial)
		while self.Running and self.RunSerial == Serial do
			local Now = os.clock()
			if Now >= self.NextLeaseRefresh then self.Coordinator:TryAcquire(); self.NextLeaseRefresh = Now + self.Config.LeaseHeartbeat end
			if self.Coordinator:HasLease() then self:_WorkerCycle() end
			task.wait(self.Config.PollInterval)
		end
	end

	function Queue:_HandleAssignment(TicketId: string)
		local Local = self.LocalTickets[TicketId]
		if not Local or Local.Dispatched then return end
		local Success, Assignment = self.Storage:GetAssignment(TicketId)
		if not Success or type(Assignment) ~= 'table' or Assignment.Queue ~= self.Name then return end
		local MatchSuccess, Match = self.Storage:GetMatch(Assignment.MatchId)
		if not MatchSuccess or type(Match) ~= 'table' or Match.Status ~= 'Ready' or Match.Stake ~= Assignment.Stake or Match.Mode ~= Assignment.Mode then return end
		if not Local.Assigned then
			Local.Assigned = true
			self.MatchFound:Fire(Local.Ticket, Assignment, Match)
			local Delay = math.max(tonumber(self.Definition.PreTeleportDelay) or 0, 0)
			if Delay > 0 then Local.DispatchAt = self:_Now() + Delay end
		end
		if Local.DispatchAt and self:_Now() < Local.DispatchAt then return end
		local Sent, Reason = self.Runtime.Teleport:Send(Local.Players, Assignment)
		if not Sent then self.Error:Fire('teleport dispatch failed', Reason); return end
		Local.Dispatched = true
		Local.DispatchAt = nil
		self.Teleporting:Fire(Local.Ticket, Assignment, Match)
	end

	function Queue:_AssignmentLoop(Serial)
		while self.Running and self.RunSerial == Serial do
			for TicketId in pairs(self.LocalTickets) do self:_HandleAssignment(TicketId) end
			task.wait(self.Config.AssignmentPollInterval)
		end
	end

	function Queue:OnDispatch(Payload)
		if type(Payload) ~= 'table' or Payload.Queue ~= self.Name or type(Payload.TicketIds) ~= 'table' then return end
		for _, TicketId in ipairs(Payload.TicketIds) do if self.LocalTickets[TicketId] then task.spawn(Queue._HandleAssignment, self, TicketId) end end
	end

	function Queue:OnTeleportFailed(Player: Player, Result, Message: string, Assignment)
		if type(Assignment) ~= 'table' or Assignment.Queue ~= self.Name then return end
		self.TeleportFailed:Fire(Player, Result, Message, Assignment)
	end

	function Queue:RetryTeleport(Target)
		local TicketId = self:_ResolveTicketId(Target)
		if not TicketId then return false, 'local matched ticket was not found' end
		local Local = self.LocalTickets[TicketId]
		if not Local then return false, 'ticket is not owned by this source server' end
		Local.Dispatched = false
		self:_HandleAssignment(TicketId)
		return Local.Dispatched, Local.Dispatched and nil or 'teleport dispatch failed';
	end

	function Queue:_OnPlayerRemoving(Player: Player)
		local Success, Membership = self.Storage:GetMembership(Player.UserId)
		if not Success or type(Membership) ~= 'table' or Membership.Queue ~= self.Name then return end
		local Found, TicketValue = self.Storage:GetTicket(Membership.TicketId)
		if not Found or type(TicketValue) ~= 'table' then self.Storage:ReleaseMembership(Player.UserId, Membership.TicketId); return end
		if TicketValue.Status == 'Queued' then
			self:Leave(TicketValue.Id, 'player disconnected')
		else
			self.Storage:ReleaseMembership(Player.UserId, TicketValue.Id)
			local Local = self.LocalTickets[TicketValue.Id]
			if Local then
				for Index = #Local.Players, 1, -1 do if Local.Players[Index] == Player then table.remove(Local.Players, Index) end end
				if #Local.Players == 0 then self:_RemoveLocal(TicketValue.Id) end
			end
		end
	end

	function Queue:Start()
		if self.Running then return end
		self.Running = true
		self.RunSerial += 1
		local Serial = self.RunSerial
		local function onPlayerRemoving(Player)
			self:_OnPlayerRemoving(Player)
		end
		table.insert(self.Connections, Players.PlayerRemoving:Connect(onPlayerRemoving))
		task.spawn(Queue._AssignmentLoop, self, Serial)
		if self.Definition.Worker then task.spawn(Queue._WorkerLoop, self, Serial) end
	end

	function Queue:Stop()
		self.RunSerial += 1
		if not self.Running then return end
		self.Running = false
		self.Coordinator:Release()
		for _, Connection in ipairs(self.Connections) do Connection:Disconnect() end
		self.Connections = {}
	end

	function Queue:Destroy()
		self:Stop()
		self.Queued:Destroy()
		self.Cancelled:Destroy()
		self.MatchFound:Destroy()
		self.MatchCreated:Destroy()
		self.Teleporting:Destroy()
		self.TeleportFailed:Destroy()
		self.Error:Destroy()
		table.clear(self.LocalTickets)
	end
end

return Queue;
