local Screens = {}
Screens.__index = Screens

local function DestroyRoots(Roots)
	for _, Root in ipairs(Roots or {}) do Root:Destroy() end
end

local function CloneRoots(Roots)
	local Result = {}
	for Index, Root in ipairs(Roots or {}) do
		local Success, Clone = pcall(function()
			return Root:Clone()
		end)
		if not Success or not Clone then
			DestroyRoots(Result)
			error(
				'Failed to clone screen root '
					.. tostring(Root and Root.Name or Index)
					.. ': '
					.. tostring(Clone)
			)
		end
		Clone.Parent = nil
		table.insert(Result, Clone)
	end
	return Result
end

local function CloneCameraBounds(Bounds)
	if type(Bounds) ~= 'table' then return nil end
	return {
		Left = tonumber(Bounds.Left) or 0,
		Top = tonumber(Bounds.Top) or 0,
		Right = tonumber(Bounds.Right) or 1,
		Bottom = tonumber(Bounds.Bottom) or 1
	}
end

local function CloneView(View)
	return {
		DeviceIndex = View and View.DeviceIndex or 1,
		Zoom = View and View.Zoom or 1,
		Pan = View and View.Pan or Vector2.new(),
		CameraBounds = CloneCameraBounds(View and View.CameraBounds),
		CameraBoundsVisible = not View or View.CameraBoundsVisible ~= false
	}
end

function Screens.new()
	local self = setmetatable({}, Screens)
	self.Definitions = {}
	self.Order = {}
	self.Current = nil
	self.Start = nil
	self.Changed = Instance.new('BindableEvent')
	return self
end

function Screens:GetNames()
	return table.clone(self.Order)
end

function Screens:Has(Name)
	return self.Definitions[Name] ~= nil
end

function Screens:Get(Name)
	return self.Definitions[Name]
end

function Screens:GetCurrent()
	return self.Current
end

function Screens:GetStart()
	return self.Start
end

function Screens:GetUniqueName(Base)
	Base = tostring(Base or 'Screen')
	if not self:Has(Base) then return Base end

	local Index = 2
	while self:Has(Base .. tostring(Index)) do Index += 1 end
	return Base .. tostring(Index)
end

function Screens:Create(Name, Roots, View)
	Name = self:GetUniqueName(Name or 'Screen')
	self.Definitions[Name] = {
		Name = Name,
		Roots = CloneRoots(Roots),
		View = CloneView(View)
	}
	table.insert(self.Order, Name)

	if not self.Current then self.Current = Name end
	if not self.Start then self.Start = Name end

	self.Changed:Fire('Create', Name)
	return Name
end

function Screens:Save(Name, Roots, View)
	local Definition = self.Definitions[Name]
	if not Definition then return false, 'screen does not exist' end

	local NewRoots = CloneRoots(Roots)
	local OldRoots = Definition.Roots
	Definition.Roots = NewRoots
	Definition.View = CloneView(View)
	DestroyRoots(OldRoots)
	self.Changed:Fire('Save', Name)
	return true
end

function Screens:Load(Name)
	local Definition = self.Definitions[Name]
	if not Definition then return nil end

	return {
		Name = Name,
		Roots = CloneRoots(Definition.Roots),
		View = CloneView(Definition.View)
	}
end

function Screens:SetCurrent(Name)
	if not self:Has(Name) then return false end
	self.Current = Name
	self.Changed:Fire('Current', Name)
	return true
end

function Screens:SetStart(Name)
	if not self:Has(Name) then return false end
	self.Start = Name
	self.Changed:Fire('Start', Name)
	return true
end

function Screens:Rename(Name, NewName)
	local Definition = self.Definitions[Name]
	NewName = tostring(NewName or '')
	if not Definition or NewName == '' or self:Has(NewName) then return false end

	self.Definitions[Name] = nil
	Definition.Name = NewName
	self.Definitions[NewName] = Definition

	local Index = table.find(self.Order, Name)
	if Index then self.Order[Index] = NewName end
	if self.Current == Name then self.Current = NewName end
	if self.Start == Name then self.Start = NewName end

	self.Changed:Fire('Rename', Name, NewName)
	return true
end

function Screens:Duplicate(Name, NewName)
	local Definition = self.Definitions[Name]
	if not Definition then return nil end
	return self:Create(
		NewName or (Name .. ' Copy'),
		Definition.Roots,
		Definition.View
	)
end

function Screens:Remove(Name)
	local Definition = self.Definitions[Name]
	if not Definition or #self.Order <= 1 then return false end

	DestroyRoots(Definition.Roots)
	self.Definitions[Name] = nil

	local Index = table.find(self.Order, Name)
	if Index then table.remove(self.Order, Index) end

	if self.Current == Name then self.Current = self.Order[math.clamp(Index or 1, 1, #self.Order)] end
	if self.Start == Name then self.Start = self.Order[1] end

	self.Changed:Fire('Remove', Name)
	return true
end

function Screens:GetStoredRoots(Name)
	local Definition = self.Definitions[Name]
	return Definition and Definition.Roots or {}
end

function Screens:Capture(SkipRootsName)
	local State = {
		Definitions = {},
		Order = table.clone(self.Order),
		Current = self.Current,
		Start = self.Start
	}

	for Name, Definition in pairs(self.Definitions) do
		State.Definitions[Name] = {
			Name = Name,
			Roots = Name == SkipRootsName and {} or CloneRoots(Definition.Roots),
			View = CloneView(Definition.View)
		}
	end

	return State
end

function Screens:DestroyState(State)
	for _, Definition in pairs(State and State.Definitions or {}) do
		DestroyRoots(Definition.Roots)
	end
end

function Screens:Restore(State, CloneState)
	local Definitions = {}
	local Order = {}

	for _, Name in ipairs(State and State.Order or {}) do
		local Entry = State.Definitions[Name]
		if Entry then
			Definitions[Name] = {
				Name = Name,
				Roots = CloneState and CloneRoots(Entry.Roots) or Entry.Roots,
				View = CloneView(Entry.View)
			}
			table.insert(Order, Name)
		end
	end

	local Previous = self.Definitions
	self.Definitions = Definitions
	self.Order = Order
	self.Current = State and State.Current or self.Order[1]
	self.Start = State and State.Start or self.Order[1]

	for _, Definition in pairs(Previous) do DestroyRoots(Definition.Roots) end
	self.Changed:Fire('Restore')
	return self
end

function Screens:Destroy()
	for _, Definition in pairs(self.Definitions) do DestroyRoots(Definition.Roots) end
	table.clear(self.Definitions)
	table.clear(self.Order)
	self.Changed:Destroy()
end

return Screens
