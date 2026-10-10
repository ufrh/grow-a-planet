local Autosave = {} do
	Autosave.__index = Autosave
	Autosave.ClassName = 'Autosave'

	local function scheduleSave(Self, Profile, Serial)
		if Self.InFlight[Profile] then return end
		Self.InFlight[Profile] = true

		task.spawn(function()
			local Success = false
			if not Profile._Released and not Profile._LockLost then
				local Completed, Saved = pcall(Self.Store._SaveProfile, Self.Store, Profile, false)
				Success = Completed and Saved == true
				if not Completed then warn('[FORGE.Data:Autosave] ' .. tostring(Saved)) end
			end

			Self.InFlight[Profile] = nil
			if not Self.Running or Self.RunSerial ~= Serial or Profile._Released or Profile._LockLost then return end
			if Success then Self:Schedule(Profile) else Self:ScheduleRetry(Profile) end
		end)
	end

	local function runLoop(Self, Serial)
		while Self.Running and Self.RunSerial == Serial do
			local Now = os.clock()

			for _, Profile in pairs(Self.Store._ProfilesByUserId) do
				if not Profile._Released and not Profile._LockLost and not Self.InFlight[Profile] and Now >= Profile._NextAutosave then
					scheduleSave(Self, Profile, Serial)
				end
			end

			task.wait(1)
		end
	end

	function Autosave.new(Store)
		local this = setmetatable({}, Autosave)
		this.Store = Store
		this.Running = false
		this.RunSerial = 0
		this.InFlight = setmetatable({}, {__mode = 'k'})
		return this;
	end

	function Autosave:Schedule(Profile)
		local Base = math.max(tonumber(self.Store.Config.AutosaveInterval) or 60, 1)
		local Jitter = math.max(tonumber(self.Store.Config.AutosaveJitter) or 0, 0)
		local Offset = Jitter > 0 and math.random() * Jitter or 0
		Profile._NextAutosave = os.clock() + Base + Offset
	end

	function Autosave:ScheduleRetry(Profile)
		local LockTimeout = math.max(tonumber(self.Store.Config.SessionLockTimeout) or 120, 4)
		local RetryInterval = tonumber(self.Store.Config.AutosaveRetryInterval)
		RetryInterval = math.max(RetryInterval or math.min(10, LockTimeout * .2), 1)
		RetryInterval = math.min(RetryInterval, math.max(LockTimeout * .4, 1))
		Profile._NextAutosave = os.clock() + RetryInterval
	end

	function Autosave:Start()
		if self.Running then return end
		self.Running = true
		self.RunSerial += 1
		task.spawn(runLoop, self, self.RunSerial)
	end

	function Autosave:Stop()
		self.RunSerial += 1
		self.Running = false
	end
end

return Autosave;
