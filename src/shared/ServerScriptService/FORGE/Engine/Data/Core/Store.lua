-- Author -> lolokdev.
-- Last Edit -> September 15, 2026 1:22 PM CDT

local DataStoreService = game:GetService('DataStoreService')
local Players = game:GetService('Players')

local DefaultConfig = require(script.Parent.Parent.Config)
local Codec = require(script.Parent.Parent.Serialization.Codec)
local Sanitizer = require(script.Parent.Parent.Serialization.Sanitizer)
local Guard = require(script.Parent.Parent.Security.Guard)
local Reconcile = require(script.Parent.Parent.Security.Reconcile)
local DeepCopy = require(script.Parent.Parent.Util.DeepCopy)
local Path = require(script.Parent.Parent.Util.Path)
local Retry = require(script.Parent.Parent.Util.Retry)
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Signal = require(ReplicatedStorage.FORGE.Kernel.Core.Signal)
local Id = require(script.Parent.Parent.Util.Id)
local Profile = require(script.Parent.Profile)
local SessionLock = require(script.Parent.SessionLock)
local Migrations = require(script.Parent.Migrations)
local Autosave = require(script.Parent.Autosave)
local Versioning = require(script.Parent.Versioning)
local GlobalStore = require(script.Parent.Parent.Global.GlobalStore)
local Leaderboard = require(script.Parent.Parent.Global.Leaderboard)

local Store = {} do
	Store.__index = Store
	Store.ClassName = 'Store'

	-- buildConfig -> table
	-- Creates one store-local configuration by applying definition overrides to framework defaults.
	-- @param Definition, table -> Store definition.
	local function buildConfig(Definition)
		local Result = {}

		for Key, Value in pairs(DefaultConfig.DataStore) do Result[Key] = Value end
		for Key, Value in pairs(Definition.Config or {}) do Result[Key] = Value end

		Result.Scope = Definition.Scope or Result.Scope
		Result.KeyPrefix = Definition.KeyPrefix or Result.KeyPrefix

		return Result;
	end

	-- trimReceipts -> nil
	-- Keeps persisted receipt history bounded by removing the oldest ids first.
	-- @param Receipts, table -> Receipt timestamp map.
	-- @param Maximum, number -> Maximum receipt ids retained.
	local function trimReceipts(Receipts, Maximum: number)
		local Count = 0

		for _ in pairs(Receipts) do Count += 1 end

		while Count > Maximum do
			local OldestKey
			local OldestTime = math.huge

			for Key, Timestamp in pairs(Receipts) do
				if Timestamp < OldestTime then OldestTime = Timestamp; OldestKey = Key end
			end

			if not OldestKey then break end

			Receipts[OldestKey] = nil
			Count -= 1
		end
	end

	-- copyInto -> nil
	-- Replaces one table's contents with a deep copy of another table.
	-- @param Target, table -> Destination table.
	-- @param Source, table -> Source table.
	local function copyInto(Target, Source)
		table.clear(Target)

		for Key, Value in pairs(Source) do Target[Key] = DeepCopy.Copy(Value) end
	end

	-- releaseDuringShutdown -> nil
	-- Releases one profile and decrements the shared shutdown counter.
	-- @param Self, Store -> Store shutting down.
	-- @param LoadedProfile, Profile -> Profile being released.
	-- @param State, table -> Shared shutdown counter.
	local function releaseDuringShutdown(Self, LoadedProfile, State)
		local Success, Released, Reason = pcall(LoadedProfile.Release, LoadedProfile)
		if not Success then
			warn('[FORGE.Data] Profile release failed during shutdown: ' .. tostring(Released))
		elseif Released ~= true then
			warn('[FORGE.Data] Profile did not release cleanly during shutdown: ' .. tostring(Reason))
		end
		State.Pending -= 1
	end

	-- new -> Store
	-- Creates a complete player-data store with locking, migration, validation, globals and leaderboards.
	-- @param Definition, table -> Store definition.
	function Store.new(Definition)
		Guard.AssertServer()

		assert(type(Definition) == 'table', 'VAULT store definition must be a table.')
		assert(type(Definition.Name) == 'string' and Definition.Name ~= '', 'VAULT store requires Name.')
		assert(type(Definition.Template) == 'table', 'VAULT store requires a table Template.')

		local this = setmetatable({}, Store)

		this.Name = Definition.Name
		this.DataStoreName = Definition.DataStoreName or Definition.Name
		this.SchemaVersion = Definition.SchemaVersion or 1
		this.Template = DeepCopy.Copy(Definition.Template)
		this.Rules = Definition.Rules or {}
		this.Migrations = Definition.Migrations or {}
		this.Replicate = Definition.Replicate or {}

		this.Config = buildConfig(Definition)
		this.Scope = this.Config.Scope

		this.Limits = {
			MaxDepth = this.Config.MaxDepth,
			MaxNodes = this.Config.MaxNodes,
			MaxStringLength = this.Config.MaxStringLength,
			MaxEncodedBytes = this.Config.MaxEncodedBytes;
		}

		this._DataStore = DataStoreService:GetDataStore(this.DataStoreName, this.Scope)
		this._ProfilesByUserId = {}
		this._LoadingByUserId = {}
		this._Connections = {}
		this._BoundPlayers = false
		this._ShutdownStarted = false

		this._Session = SessionLock.new(this.Config)
		this._Autosave = Autosave.new(this)
		this.Versions = Versioning.new(this._DataStore, this.Config)
		this.Global = GlobalStore.new(this.DataStoreName, this.Scope, this.Limits)
		this.Leaderboards = Leaderboard.new(this.DataStoreName, this.Scope)

		this.Loaded = Signal.new()
		this.Released = Signal.new()
		this.SaveFailed = Signal.new()
		this.LockLost = Signal.new()
		this.Corrupted = Signal.new()

		this._Autosave:Start()

		return this;
	end

	-- _Key -> string
	-- Builds the persistent key for one user id.
	-- @param UserId, number -> Roblox user id.
	function Store:_Key(UserId: number)
		return Id.PlayerKey(self.Config.KeyPrefix, UserId);
	end

	-- _CreateRecord -> table
	-- Creates a pristine persisted record from the current schema template.
	function Store:_CreateRecord()
		local Encoded = Codec.Encode(self.Template, self.Limits)

		Sanitizer.AssertSize(Encoded, self.Config.MaxEncodedBytes)

		local Now = os.time()

		return {
			_format = 1,
			_schema = self.SchemaVersion,
			_revision = 0,
			_createdAt = Now,
			_updatedAt = Now,
			_session = nil,
			_receipts = {},
			_data = Encoded;
		};
	end

	-- _ValidateData -> boolean, string?
	-- Validates a complete decoded profile tree against schema and rules.
	-- @param Data, table -> Profile data.
	function Store:_ValidateData(Data)
		return Guard.ValidateData(Data, self.Template, self.Rules, self.Config.StrictSchema);
	end

	-- _ValidatePathValue -> boolean, string?
	-- Validates one server-side profile write before it mutates memory.
	-- @param DataPath, string -> Dot-delimited profile path.
	-- @param Value, any -> Proposed value.
	function Store:_ValidatePathValue(DataPath: string, Value)
		return Guard.ValidatePathValue(DataPath, Value, self.Template, self.Rules, self.Config.StrictSchema);
	end

	-- _DecodeRecord -> table, table, boolean
	-- Decodes, migrates and reconciles one persisted record into runtime data and metadata.
	-- @param Record, table -> Persisted VAULT record.
	function Store:_DecodeRecord(Record)
		if type(Record) ~= 'table' or Record._data == nil then error('VAULT record is malformed or missing _data.') end

		local Data = Codec.Decode(Record._data, self.Limits)
		local StoredVersion = tonumber(Record._schema) or 1
		local Migrated, MigrationChanged = Migrations.Apply(Data, StoredVersion, self.SchemaVersion, self.Migrations)
		local ReconcileChanged = Reconcile.Apply(Migrated, self.Template, self.Config.PruneUnknown)
		local Accepted, Reason = self:_ValidateData(Migrated)

		if not Accepted then error('VAULT decoded data failed validation: ' .. tostring(Reason)) end

		local Meta = {
			Schema = self.SchemaVersion,
			StoredSchema = StoredVersion,
			Revision = tonumber(Record._revision) or 0,
			CreatedAt = tonumber(Record._createdAt) or os.time(),
			UpdatedAt = tonumber(Record._updatedAt) or os.time(),
			Receipts = type(Record._receipts) == 'table' and DeepCopy.Copy(Record._receipts) or {};
		}

		return Migrated, Meta, MigrationChanged or ReconcileChanged;
	end

	-- _PrepareData -> boolean, any
	-- Validates, serializes and size-checks runtime profile data for persistence.
	-- @param Data, table -> Decoded runtime profile data.
	function Store:_PrepareData(Data)
		local Accepted, Reason = self:_ValidateData(Data)

		if not Accepted then return false, Reason end

		local Success, Encoded = pcall(Codec.Encode, Data, self.Limits)

		if not Success then return false, tostring(Encoded) end

		local Sized, SizeResult = pcall(Sanitizer.AssertSize, Encoded, self.Config.MaxEncodedBytes)

		if not Sized then return false, tostring(SizeResult) end

		return true, Encoded;
	end

	-- _ReleaseLockOnly -> nil
	-- Clears this server's session lock without touching persisted user data.
	-- @param Key, string -> Datastore key.
	-- @param Token, string -> Session token being released.
	function Store:_ReleaseLockOnly(Key: string, Token: string)
		local function transform(Old)
			if type(Old) ~= 'table' then return Old end
			if type(Old._session) ~= 'table' or Old._session.token ~= Token then return Old end
			Old._session = nil
			return Old;
		end

		local function update()
			return self._DataStore:UpdateAsync(Key, transform);
		end

		Retry.Call(Enum.DataStoreRequestType.UpdateAsync, self.Config.SaveAttempts, self.Config.BaseRetryDelay, self.Config.MaxRetryDelay, self.Config.BudgetWaitTimeout, update)
	end

	function Store:_AcquireWrite(LoadedProfile)
		while LoadedProfile._Saving do task.wait(.03) end
		LoadedProfile._Saving = true
	end

	function Store:_ReleaseWrite(LoadedProfile)
		LoadedProfile._Saving = false
	end

	function Store:_HandleLockLost(LoadedProfile)
		if LoadedProfile._LockLost then return end
		LoadedProfile._LockLost = true
		LoadedProfile._Released = true
		self._ProfilesByUserId[LoadedProfile.UserId] = nil
		self.LockLost:Fire(LoadedProfile)
		LoadedProfile.Released:Fire('lock lost')
		if LoadedProfile.Player and LoadedProfile.Player.Parent and self.Config.KickOnLockLoss then LoadedProfile.Player:Kick('Your data session moved to another server. Please rejoin.') end
	end

	function Store:_SaveProfile(LoadedProfile, Releasing: boolean)
		if LoadedProfile._Released then return true end
		if LoadedProfile._LockLost then return false, 'session lock lost' end

		self:_AcquireWrite(LoadedProfile)

		if LoadedProfile._Released then
			self:_ReleaseWrite(LoadedProfile)
			return true;
		end

		if LoadedProfile._LockLost then
			self:_ReleaseWrite(LoadedProfile)
			return false, 'session lock lost';
		end

		local Prepared, Encoded = self:_PrepareData(LoadedProfile._Data)

		if not Prepared then
			self:_ReleaseWrite(LoadedProfile)
			self.SaveFailed:Fire(LoadedProfile, Encoded)
			return false, Encoded;
		end

		local Conflict = false
		local NewRevision = LoadedProfile._Meta.Revision
		local Now = os.time()

		local function transform(Old)
			if type(Old) ~= 'table' or type(Old._session) ~= 'table' or Old._session.token ~= LoadedProfile._Token then Conflict = true; return nil end
			NewRevision = (tonumber(Old._revision) or 0) + 1
			Old._format = 1
			Old._schema = self.SchemaVersion
			Old._revision = NewRevision
			Old._updatedAt = Now
			Old._receipts = DeepCopy.Copy(LoadedProfile._Receipts)
			Old._data = Encoded
			if Releasing then Old._session = nil else Old._session.heartbeat = Now end
			return Old;
		end

		local function update()
			return self._DataStore:UpdateAsync(LoadedProfile.Key, transform);
		end

		local Success, Result = Retry.Call(Enum.DataStoreRequestType.UpdateAsync, self.Config.SaveAttempts, self.Config.BaseRetryDelay, self.Config.MaxRetryDelay, self.Config.BudgetWaitTimeout, update)
		self:_ReleaseWrite(LoadedProfile)

		if Conflict then
			self:_HandleLockLost(LoadedProfile)
			return false, 'session lock lost';
		end

		if not Success or Result == nil then
			local Reason = Success and 'profile save aborted' or tostring(Result)
			self.SaveFailed:Fire(LoadedProfile, Reason)
			return false, Reason;
		end

		LoadedProfile._Meta.Revision = NewRevision
		LoadedProfile._Meta.UpdatedAt = Now
		LoadedProfile._Meta.Schema = self.SchemaVersion
		LoadedProfile._Dirty = false
		LoadedProfile._LastSave = os.clock()

		if Releasing then
			LoadedProfile._Released = true
			self._ProfilesByUserId[LoadedProfile.UserId] = nil
			self.Released:Fire(LoadedProfile)
			LoadedProfile.Released:Fire('released')
		end

		return true;
	end

	function Store:_CommitReceipt(LoadedProfile, ReceiptId: string, Callback)
		if type(Callback) ~= 'function' then return false, 'receipt callback must be a function' end
		if LoadedProfile:HasReceipt(ReceiptId) then return true, 'already processed' end

		self:_AcquireWrite(LoadedProfile)

		if LoadedProfile._Released then self:_ReleaseWrite(LoadedProfile); return false, 'profile is released' end
		if LoadedProfile._LockLost then self:_ReleaseWrite(LoadedProfile); return false, 'session lock lost' end
		if LoadedProfile:HasReceipt(ReceiptId) then self:_ReleaseWrite(LoadedProfile); return true, 'already processed' end

		local Draft = DeepCopy.Copy(LoadedProfile._Data)
		local Mutated, MutationResult = pcall(Callback, Draft)

		if not Mutated then self:_ReleaseWrite(LoadedProfile); return false, tostring(MutationResult) end
		if MutationResult == false then self:_ReleaseWrite(LoadedProfile); return false, 'receipt transaction aborted' end

		local Accepted, Reason = self:_ValidateData(Draft)
		if not Accepted then self:_ReleaseWrite(LoadedProfile); return false, Reason end

		local Prepared, Encoded = self:_PrepareData(Draft)
		if not Prepared then self:_ReleaseWrite(LoadedProfile); return false, Encoded end

		local Conflict = false
		local Already = false
		local Now = os.time()
		local NewReceipts = DeepCopy.Copy(LoadedProfile._Receipts)
		local NewRevision = LoadedProfile._Meta.Revision

		NewReceipts[ReceiptId] = Now
		trimReceipts(NewReceipts, self.Config.MaxReceiptIds)

		local function transform(Old)
			if type(Old) ~= 'table' or type(Old._session) ~= 'table' or Old._session.token ~= LoadedProfile._Token then Conflict = true; return nil end
			local ExistingReceipts = type(Old._receipts) == 'table' and Old._receipts or {}
			if ExistingReceipts[ReceiptId] ~= nil then Already = true; return Old end
			NewRevision = (tonumber(Old._revision) or 0) + 1
			Old._schema = self.SchemaVersion
			Old._revision = NewRevision
			Old._updatedAt = Now
			Old._receipts = DeepCopy.Copy(NewReceipts)
			Old._data = Encoded
			Old._session.heartbeat = Now
			return Old;
		end

		local function update()
			return self._DataStore:UpdateAsync(LoadedProfile.Key, transform);
		end

		local Success, Result = Retry.Call(Enum.DataStoreRequestType.UpdateAsync, self.Config.SaveAttempts, self.Config.BaseRetryDelay, self.Config.MaxRetryDelay, self.Config.BudgetWaitTimeout, update)

		if Conflict then
			self:_ReleaseWrite(LoadedProfile)
			self:_HandleLockLost(LoadedProfile)
			return false, 'session lock lost';
		end

		if not Success or Result == nil then
			self:_ReleaseWrite(LoadedProfile)
			return false, Success and 'receipt commit aborted' or tostring(Result);
		end

		local OldData = DeepCopy.Copy(LoadedProfile._Data)
		local EventData

		if Already then
			local Decoded, PersistedData, PersistedMeta = pcall(self._DecodeRecord, self, Result)
			if not Decoded then
				self:_ReleaseWrite(LoadedProfile)
				self.Corrupted:Fire(LoadedProfile.UserId, tostring(PersistedData), Result)
				return false, 'committed receipt could not be synchronized locally: ' .. tostring(PersistedData);
			end

			LoadedProfile._Data = PersistedData
			LoadedProfile._Meta = PersistedMeta
			LoadedProfile._Receipts = DeepCopy.Copy(PersistedMeta.Receipts or {})
			LoadedProfile._Dirty = false
			LoadedProfile._LastSave = os.clock()
			EventData = PersistedData
		else
			LoadedProfile._Data = Draft
			LoadedProfile._Receipts = NewReceipts
			LoadedProfile._Meta.Revision = NewRevision
			LoadedProfile._Meta.UpdatedAt = Now
			LoadedProfile._Meta.Schema = self.SchemaVersion
			LoadedProfile._Dirty = false
			LoadedProfile._LastSave = os.clock()
			EventData = Draft
		end

		self:_ReleaseWrite(LoadedProfile)
		LoadedProfile:_RecordAudit(Already and 'ReceiptSync' or 'Receipt', ReceiptId, OldData, EventData)
		LoadedProfile.Changed:Fire('*', DeepCopy.Copy(EventData), OldData)
		return true, Already and 'already processed' or 'processed';
	end

	function Store:LoadUserId(UserId: number, Player: Player?)
		if self._ShutdownStarted then return false, 'store is shutting down' end

		local Existing = self._ProfilesByUserId[UserId]
		if Existing then
			if Player then Existing.Player = Player end
			return true, Existing;
		end

		if self._LoadingByUserId[UserId] then
			local Deadline = os.clock() + self.Config.SessionLockLoadTimeout
			while self._LoadingByUserId[UserId] and os.clock() < Deadline do
				Existing = self._ProfilesByUserId[UserId]
				if Existing then
					if Player then Existing.Player = Player end
					return true, Existing;
				end
				if self._ShutdownStarted then return false, 'store is shutting down' end
				task.wait(.05)
			end

			Existing = self._ProfilesByUserId[UserId]
			if Existing then
				if Player then Existing.Player = Player end
				return true, Existing;
			end
			if self._LoadingByUserId[UserId] then return false, 'profile load already in progress' end
		end

		self._LoadingByUserId[UserId] = true
		local Result = table.pack(xpcall(function()
			local Key = self:_Key(UserId)
			local function createRecord() return self:_CreateRecord(); end
			local Locked, Record, Token = self._Session:Acquire(self._DataStore, Key, createRecord)
			if not Locked then return false, tostring(Record) end

			if self._ShutdownStarted then
				self:_ReleaseLockOnly(Key, Token)
				return false, 'store is shutting down';
			end

			local Decoded, Data, Meta, Changed = pcall(self._DecodeRecord, self, Record)
			if not Decoded then
				self.Corrupted:Fire(UserId, tostring(Data), Record)
				if not self.Config.RecoverCorruptData then
					self:_ReleaseLockOnly(Key, Token)
					return false, 'stored profile could not be decoded: ' .. tostring(Data);
				end
				Data = DeepCopy.Copy(self.Template)
				Meta = {Schema = self.SchemaVersion; StoredSchema = 0; Revision = tonumber(Record._revision) or 0; CreatedAt = tonumber(Record._createdAt) or os.time(); UpdatedAt = tonumber(Record._updatedAt) or os.time(); Receipts = type(Record._receipts) == 'table' and DeepCopy.Copy(Record._receipts) or {};}
				Changed = true
			end

			if self._ShutdownStarted then
				self:_ReleaseLockOnly(Key, Token)
				return false, 'store is shutting down';
			end

			local LoadedProfile = Profile.new(self, UserId, Key, Data, Meta, Token, Player)
			LoadedProfile._Dirty = Changed == true
			self._ProfilesByUserId[UserId] = LoadedProfile
			self._Autosave:Schedule(LoadedProfile)
			self.Loaded:Fire(LoadedProfile)
			return true, LoadedProfile;
		end, debug.traceback))

		self._LoadingByUserId[UserId] = nil
		if not Result[1] then return false, tostring(Result[2]) end
		return table.unpack(Result, 2, Result.n);
	end

	function Store:LoadPlayer(Player: Player)
		local Success, Result = self:LoadUserId(Player.UserId, Player)
		if Success and not Player.Parent then
			Result:Release()
			return false, 'player left during profile load';
		end
		return Success, Result;
	end

	function Store:GetProfile(PlayerOrUserId)
		local UserId = typeof(PlayerOrUserId) == 'Instance' and PlayerOrUserId.UserId or PlayerOrUserId
		return self._ProfilesByUserId[UserId];
	end

	function Store:WaitForProfile(PlayerOrUserId, Timeout: number?)
		local UserId = typeof(PlayerOrUserId) == 'Instance' and PlayerOrUserId.UserId or PlayerOrUserId
		local Deadline = os.clock() + (Timeout or self.Config.SessionLockLoadTimeout)
		repeat
			local LoadedProfile = self._ProfilesByUserId[UserId]
			if LoadedProfile then return LoadedProfile end
			if self._ShutdownStarted then return nil end
			task.wait(.05)
		until os.clock() >= Deadline
		return nil;
	end

	function Store:UpdateOffline(UserId: number, Callback)
		if self._ProfilesByUserId[UserId] or self._LoadingByUserId[UserId] then return false, 'profile is loaded or loading locally; mutate the loaded profile instead' end
		if self._ShutdownStarted then return false, 'store is shutting down' end
		if type(Callback) ~= 'function' then return false, 'offline update callback must be a function' end

		local Key = self:_Key(UserId)
		local Blocked = false
		local CallbackError

		local function transform(Old)
			local Record = Old or self:_CreateRecord()
			if Record._session and not self._Session:IsStale(Record._session) then Blocked = true; return nil end
			local Decoded, Data, Meta = pcall(self._DecodeRecord, self, Record)
			if not Decoded then CallbackError = tostring(Data); return nil end
			local Working = DeepCopy.Copy(Data)
			local Mutated, Result = pcall(Callback, Working)
			if not Mutated then CallbackError = tostring(Result); return nil end
			if type(Result) == 'table' then Working = Result end
			if Result == false then CallbackError = 'offline update aborted'; return nil end
			local Prepared, Encoded = self:_PrepareData(Working)
			if not Prepared then CallbackError = tostring(Encoded); return nil end
			local Now = os.time()
			Record._schema = self.SchemaVersion
			Record._revision = (tonumber(Record._revision) or Meta.Revision or 0) + 1
			Record._updatedAt = Now
			Record._session = nil
			Record._data = Encoded
			return Record;
		end

		local function update()
			return self._DataStore:UpdateAsync(Key, transform);
		end

		local Success, Result = Retry.Call(Enum.DataStoreRequestType.UpdateAsync, self.Config.SaveAttempts, self.Config.BaseRetryDelay, self.Config.MaxRetryDelay, self.Config.BudgetWaitTimeout, update)
		if Blocked then return false, 'profile is active in another server' end
		if CallbackError then return false, CallbackError end
		if not Success then return false, tostring(Result) end
		if Result == nil then return false, 'offline update aborted' end
		return true;
	end

	function Store:ListVersions(UserId: number, Limit: number?)
		return self.Versions:List(self:_Key(UserId), Limit);
	end

	function Store:RestoreVersion(UserId: number, Version: string)
		if self._ProfilesByUserId[UserId] or self._LoadingByUserId[UserId] then return false, 'profile must be offline before restoring a version' end
		if self._ShutdownStarted then return false, 'store is shutting down' end
		local Read, Record = self.Versions:Get(self:_Key(UserId), Version)
		if not Read then return false, tostring(Record) end
		local Decoded, Data = pcall(self._DecodeRecord, self, Record)
		if not Decoded then return false, tostring(Data) end
		local function restore(Draft)
			copyInto(Draft, Data)
			return Draft;
		end
		return self:UpdateOffline(UserId, restore);
	end

	function Store:WipeUserId(UserId: number, Confirmation: string)
		if self._ProfilesByUserId[UserId] or self._LoadingByUserId[UserId] then return false, 'profile must be offline before wiping' end
		if self._ShutdownStarted then return false, 'store is shutting down' end
		if Confirmation ~= 'WIPE:' .. tostring(UserId) then return false, 'invalid wipe confirmation' end
		if self.Scope == 'production' and not self.Config.AllowProductionWipes then return false, 'production wipes are disabled by configuration' end
		local function remove()
			return self._DataStore:RemoveAsync(self:_Key(UserId));
		end
		local Success, Result = Retry.Call(Enum.DataStoreRequestType.SetIncrementAsync, self.Config.SaveAttempts, self.Config.BaseRetryDelay, self.Config.MaxRetryDelay, self.Config.BudgetWaitTimeout, remove)
		if not Success then return false, tostring(Result) end
		return true;
	end

	function Store:BindPlayers()
		if self._BoundPlayers then return end
		self._BoundPlayers = true

		local function onAdded(Player)
			local Success, Result = self:LoadPlayer(Player)
			if not Success and Player.Parent and not self._ShutdownStarted and self.Config.KickOnLoadFailure then Player:Kick('Your data could not be loaded safely. Please rejoin.\n' .. tostring(Result)) end
		end

		local function onRemoving(Player)
			local LoadedProfile = self:GetProfile(Player)
			if LoadedProfile then LoadedProfile:Release() end
		end

		local function onClose()
			self:Shutdown()
		end

		table.insert(self._Connections, Players.PlayerAdded:Connect(onAdded))
		table.insert(self._Connections, Players.PlayerRemoving:Connect(onRemoving))
		for _, Player in ipairs(Players:GetPlayers()) do task.spawn(onAdded, Player) end
		game:BindToClose(onClose)
	end

	function Store:Shutdown()
		if self._ShutdownStarted then return end
		self._ShutdownStarted = true
		self._Autosave:Stop()
		local State = {Pending = 0;}
		for _, LoadedProfile in pairs(self._ProfilesByUserId) do
			State.Pending += 1
			task.spawn(releaseDuringShutdown, self, LoadedProfile, State)
		end
		local Deadline = os.clock() + self.Config.ShutdownTimeout
		while State.Pending > 0 and os.clock() < Deadline do task.wait(.05) end
	end

	function Store:Destroy()
		self:Shutdown()
		for _, Connection in ipairs(self._Connections) do Connection:Disconnect() end
		table.clear(self._Connections)
		table.clear(self._LoadingByUserId)
		self.Global:Destroy()
		self.Leaderboards:Destroy()
		self.Loaded:Destroy()
		self.Released:Destroy()
		self.SaveFailed:Destroy()
		self.LockLost:Destroy()
		self.Corrupted:Destroy()
	end
end

return Store;