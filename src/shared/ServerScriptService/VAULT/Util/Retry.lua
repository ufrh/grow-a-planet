-- Author -> lolokdev.
-- Last Edit -> September 13, 2026 6:43 PM CDT

local DataStoreService = game:GetService('DataStoreService')

local Retry = {}

-- waitForBudget -> boolean
-- Waits for one datastore request token while respecting a hard timeout.
-- @param RequestType, Enum.DataStoreRequestType? -> Roblox datastore request budget category.
-- @param Timeout, number -> Maximum wait duration in seconds.
local function waitForBudget(RequestType, Timeout: number)
	if not RequestType then return true end

	local Started = os.clock()

	while DataStoreService:GetRequestBudgetForRequestType(RequestType) < 1 do
		if os.clock() - Started >= Timeout then return false end

		task.wait(.1)
	end

	return true;
end

-- Call -> boolean, ...any
-- Runs one datastore operation with budget awareness and exponential backoff.
-- @param RequestType, Enum.DataStoreRequestType? -> Request budget category.
-- @param Attempts, number -> Maximum operation attempts.
-- @param BaseDelay, number -> Initial retry delay.
-- @param MaxDelay, number -> Maximum retry delay.
-- @param BudgetTimeout, number -> Maximum wait for each budget token.
-- @param Callback, function -> Operation callback.
function Retry.Call(RequestType, Attempts: number, BaseDelay: number, MaxDelay: number, BudgetTimeout: number, Callback)
	assert(type(Callback) == 'function', 'Retry callback must be a function.')

	local LastError = 'operation failed'

	for Attempt = 1, Attempts do
		if not waitForBudget(RequestType, BudgetTimeout) then
			LastError = 'datastore request budget timeout'
		else
			local Packed = table.pack(pcall(Callback))

			if Packed[1] then return true, table.unpack(Packed, 2, Packed.n) end

			LastError = tostring(Packed[2])
		end

		if Attempt < Attempts then
			local Delay = math.min(BaseDelay * (2 ^ (Attempt - 1)), MaxDelay)
			local Jitter = math.random() * math.min(Delay * .2, .5)

			task.wait(Delay + Jitter)
		end
	end

	return false, LastError;
end

return Retry;
