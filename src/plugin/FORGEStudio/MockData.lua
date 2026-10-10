local MockData = {}
MockData.__index = MockData

local function Clone(Value)
	if typeof(Value) ~= 'table' then return Value end
	local Copy = {}
	for Key, Child in pairs(Value) do Copy[Clone(Key)] = Clone(Child) end
	return Copy
end

local function Split(Path)
	local Parts = {}
	for Part in tostring(Path or ''):gmatch('[^%.]+') do table.insert(Parts, Part) end
	return Parts
end

function MockData.new()
	local self = setmetatable({}, MockData)
	self.Data = {
		Player = {
			DisplayName = 'Player',
			Username = 'player',
			UserId = 1,
			Level = 1,
			Rank = 'Rookie',
			Currency = 0,
			Online = true,
			Avatar = 'rbxthumb://type=AvatarHeadShot&id=1&w=420&h=420'
		},
		Party = {
			Count = 1,
			Max = 6,
			Leader = 'Player',
			Ready = 1,
			Member1 = {
				DisplayName = 'Player',
				Username = 'player',
				UserId = 1,
				Avatar = 'rbxthumb://type=AvatarHeadShot&id=1&w=420&h=420',
				Ready = true
			}
		},
		Match = {
			Mode = 'FFA',
			Map = 'Preview',
			Stake = 0,
			Pot = 0,
			TeamName = 'Solo',
			TimeLeft = 180,
			Players = 1
		}
	}
	self.Changed = Instance.new('BindableEvent')
	return self
end

function MockData:Get()
	return self.Data
end

function MockData:Resolve(Path)
	local Current = self.Data
	for _, Part in ipairs(Split(Path)) do
		if typeof(Current) ~= 'table' then return nil end
		Current = Current[Part]
		if Current == nil then return nil end
	end
	return Current
end

function MockData:Set(Path, Value)
	local Parts = Split(Path)
	if #Parts == 0 then return false end

	local Current = self.Data
	for Index = 1, #Parts - 1 do
		local Part = Parts[Index]
		if typeof(Current[Part]) ~= 'table' then Current[Part] = {} end
		Current = Current[Part]
	end

	Current[Parts[#Parts]] = Value
	self.Changed:Fire('Set', Path, Value)
	return true
end

function MockData:Remove(Path)
	local Parts = Split(Path)
	if #Parts == 0 then return false end

	local Current = self.Data
	for Index = 1, #Parts - 1 do
		Current = Current[Parts[Index]]
		if typeof(Current) ~= 'table' then return false end
	end

	Current[Parts[#Parts]] = nil
	self.Changed:Fire('Remove', Path)
	return true
end

function MockData:Capture()
	return Clone(self.Data)
end

function MockData:Restore(State)
	self.Data = Clone(State or {})
	self.Changed:Fire('Restore')
	return self
end

function MockData:Destroy()
	table.clear(self.Data)
	self.Changed:Destroy()
end

return MockData
