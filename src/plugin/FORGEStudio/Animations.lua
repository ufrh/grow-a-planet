local Animations = {}
Animations.__index = Animations

local function CloneValue(Value)
	if typeof(Value) ~= 'table' then return Value end
	local Copy = {}
	for Key, Child in pairs(Value) do Copy[CloneValue(Key)] = CloneValue(Child) end
	return Copy
end

function Animations.new()
	local self = setmetatable({}, Animations)
	self.Definitions = {}
	self.Changed = Instance.new('BindableEvent')
	return self
end

function Animations:GetNames()
	local Names = {}
	for Name in pairs(self.Definitions) do table.insert(Names, Name) end
	table.sort(Names, function(A, B)
		return string.lower(A) < string.lower(B)
	end)
	return Names
end

function Animations:Get(Name)
	return self.Definitions[Name]
end

function Animations:Has(Name)
	return self.Definitions[Name] ~= nil
end

function Animations:GetUniqueName(Base)
	Base = tostring(Base or 'Animation')
	if not self:Has(Base) then return Base end

	local Index = 2
	while self:Has(Base .. tostring(Index)) do Index += 1 end
	return Base .. tostring(Index)
end

function Animations:Create(Name)
	Name = self:GetUniqueName(Name or 'Animation')
	self.Definitions[Name] = {
		Name = Name,
		Tracks = {},
		Loop = false,
		Reverse = false,
		Stagger = 0,
		Trigger = 'Manual',
		OwnerPath = nil,
		TriggerTargetPath = 'Root',
		PresetKind = nil,
		PresetSourcePath = nil,
		InheritEndFrom = nil
	}
	self.Changed:Fire('Create', Name)
	return Name
end

function Animations:Remove(Name)
	if not self.Definitions[Name] then return false end
	self.Definitions[Name] = nil
	for _, Definition in pairs(self.Definitions) do
		if Definition.InheritEndFrom == Name then Definition.InheritEndFrom = nil end
	end
	self.Changed:Fire('Remove', Name)
	return true
end

function Animations:Rename(Name, NewName)
	local Definition = self.Definitions[Name]
	NewName = tostring(NewName or '')
	if not Definition or NewName == '' or self.Definitions[NewName] then return false end

	self.Definitions[Name] = nil
	Definition.Name = NewName
	self.Definitions[NewName] = Definition
	for _, Other in pairs(self.Definitions) do
		if Other.InheritEndFrom == Name then Other.InheritEndFrom = NewName end
	end
	self.Changed:Fire('Rename', Name, NewName)
	return true
end

function Animations:SetOptions(Name, Options)
	local Definition = self.Definitions[Name]
	if not Definition then return false end

	for Key, Value in pairs(Options or {}) do
		Definition[Key] = Value
	end

	self.Changed:Fire('Options', Name)
	return true
end

function Animations:SetPreset(Name, Kind, SourcePath)
	local Definition = self.Definitions[Name]
	Kind = tostring(Kind or '')
	if not Definition or Kind == '' then return false end

	Definition.PresetKind = Kind
	Definition.PresetSourcePath = SourcePath or 'Root'
	Definition.OwnerPath = nil
	Definition.TriggerTargetPath = 'Root'
	self.Changed:Fire('Preset', Name, Kind)
	return true
end

function Animations:ClearPreset(Name)
	local Definition = self.Definitions[Name]
	if not Definition then return false end
	Definition.PresetKind = nil
	Definition.PresetSourcePath = nil
	self.Changed:Fire('PresetClear', Name)
	return true
end

function Animations:AddTrack(Name, Track)
	local Definition = self.Definitions[Name]
	if not Definition then return nil end

	local Entry = {
		TargetPath = tostring(Track.TargetPath or ''),
		Property = tostring(Track.Property or ''),
		PropertyKind = Track.PropertyKind == 'Semantic' and 'Semantic' or 'Native',
		From = Track.From,
		To = Track.To,
		FromExpression = Track.FromExpression,
		ToExpression = Track.ToExpression,
		Duration = tonumber(Track.Duration) or .2,
		Delay = tonumber(Track.Delay) or 0,
		EasingStyle = Track.EasingStyle or Enum.EasingStyle.Quad,
		EasingDirection = Track.EasingDirection or Enum.EasingDirection.Out
	}

	table.insert(Definition.Tracks, Entry)
	self.Changed:Fire('TrackAdd', Name, #Definition.Tracks)
	return #Definition.Tracks
end

function Animations:UpdateTrack(Name, Index, Track)
	local Definition = self.Definitions[Name]
	local Entry = Definition and Definition.Tracks[Index]
	if not Entry then return false end

	Track = Track or {}
	Entry.FromExpression = Track.FromExpression
	Entry.ToExpression = Track.ToExpression
	for Key, Value in pairs(Track) do Entry[Key] = Value end
	self.Changed:Fire('TrackUpdate', Name, Index)
	return true
end

function Animations:RemoveTrack(Name, Index)
	local Definition = self.Definitions[Name]
	if not Definition or not Definition.Tracks[Index] then return false end

	table.remove(Definition.Tracks, Index)
	self.Changed:Fire('TrackRemove', Name, Index)
	return true
end

function Animations:ReplaceTracks(Name, Tracks)
	local Definition = self.Definitions[Name]
	if not Definition then return false end

	Definition.Tracks = CloneValue(Tracks or {})
	for _, Track in ipairs(Definition.Tracks) do
		Track.TargetPath = tostring(Track.TargetPath or '')
		Track.Property = tostring(Track.Property or '')
		Track.PropertyKind = Track.PropertyKind == 'Semantic' and 'Semantic' or 'Native'
		Track.Duration = tonumber(Track.Duration) or .2
		Track.Delay = tonumber(Track.Delay) or 0
		Track.EasingStyle = Track.EasingStyle or Enum.EasingStyle.Quad
		Track.EasingDirection = Track.EasingDirection or Enum.EasingDirection.Out
	end

	self.Changed:Fire('TracksReplace', Name)
	return true
end

function Animations:Capture()
	return CloneValue(self.Definitions)
end

function Animations:Restore(State)
	self.Definitions = CloneValue(State or {})

	for Name, Definition in pairs(self.Definitions) do
		Definition.Name = Definition.Name or Name
		Definition.Tracks = Definition.Tracks or {}
		Definition.Loop = Definition.Loop == true
		Definition.Reverse = Definition.Reverse == true
		Definition.Stagger = tonumber(Definition.Stagger) or 0
		Definition.Trigger = Definition.Trigger or 'Manual'
		Definition.TriggerTargetPath = Definition.TriggerTargetPath or 'Root'
		Definition.PresetKind = Definition.PresetKind or nil
		Definition.PresetSourcePath = Definition.PresetSourcePath or nil
		Definition.InheritEndFrom = Definition.InheritEndFrom or nil
		for _, Track in ipairs(Definition.Tracks) do
			Track.PropertyKind = Track.PropertyKind == 'Semantic' and 'Semantic' or 'Native'
			Track.FromExpression = Track.FromExpression or nil
			Track.ToExpression = Track.ToExpression or nil
		end
	end

	self.Changed:Fire('Restore')
	return self
end

function Animations:Destroy()
	table.clear(self.Definitions)
	self.Changed:Destroy()
end

return Animations
