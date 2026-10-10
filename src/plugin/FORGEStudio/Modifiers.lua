local Modifiers = {}

Modifiers.Definitions = {
	Array = {
		DisplayName = 'Array',
		Description = 'Repeat an element without manually duplicating it.',
		Fields = {
			{Key = 'Count', Label = 'Count', Type = 'number', Default = 3, Min = 1, Max = 64},
			{Key = 'OffsetX', Label = 'Offset X', Type = 'number', Default = 24},
			{Key = 'OffsetY', Label = 'Offset Y', Type = 'number', Default = 0}
		}
	}
}

local Prefix = 'FORGEMod_'

local function Attribute(Name, Key)
	return Prefix .. Name .. '_' .. Key
end

local function RemoveInternal(Object)
	for _, Child in ipairs(Object:GetChildren()) do
		if Child:GetAttribute('FORGEModifierInternal') == true then
			Child:Destroy()
		else
			RemoveInternal(Child)
		end
	end
end

local function MarkGenerated(Object)
	Object:SetAttribute('FORGEModifierGenerated', true)
	Object:SetAttribute('FORGEStyleInternal', true)
	Object:SetAttribute('FORGEFixedPixelGeometry', true)

	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA('GuiObject') then
			Descendant:SetAttribute('FORGEModifierGenerated', true)
			Descendant:SetAttribute('FORGEFixedPixelGeometry', true)
		end
	end
end

function Modifiers:GetNames()
	local Result = {}
	for Name in pairs(self.Definitions) do table.insert(Result, Name) end
	table.sort(Result)
	return Result
end

function Modifiers:GetDefinition(Name)
	return self.Definitions[Name]
end

function Modifiers:Has(Object, Name)
	return Object and Object:GetAttribute(Attribute(Name, 'Enabled')) == true
end

function Modifiers:Add(Object, Name)
	local Definition = self.Definitions[Name]
	if not Object or not Definition then return false end

	Object:SetAttribute(Attribute(Name, 'Enabled'), true)
	local Current = Object
	while Current and Current:IsA('GuiObject') do
		Current:SetAttribute('FORGEManagedModifiers', true)
		Current = Current.Parent
	end
	for _, Field in ipairs(Definition.Fields or {}) do
		if Object:GetAttribute(Attribute(Name, Field.Key)) == nil then
			Object:SetAttribute(Attribute(Name, Field.Key), Field.Default)
		end
	end
	return true
end

function Modifiers:Remove(Object, Name)
	local Definition = self.Definitions[Name]
	if not Object or not Definition then return false end

	Object:SetAttribute(Attribute(Name, 'Enabled'), nil)
	for _, Field in ipairs(Definition.Fields or {}) do
		Object:SetAttribute(Attribute(Name, Field.Key), nil)
	end
	self:Apply(Object)
	return true
end

function Modifiers:GetValue(Object, Name, Key)
	local Definition = self.Definitions[Name]
	if not Object or not Definition then return nil end
	local Value = Object:GetAttribute(Attribute(Name, Key))
	if Value ~= nil then return Value end

	for _, Field in ipairs(Definition.Fields or {}) do
		if Field.Key == Key then return Field.Default end
	end
	return nil
end

function Modifiers:SetValue(Object, Name, Key, Value)
	local Definition = self.Definitions[Name]
	if not Object or not Definition then return false end

	for _, Field in ipairs(Definition.Fields or {}) do
		if Field.Key == Key then
			if Field.Type == 'number' then
				Value = tonumber(Value)
				if Value == nil then return false end
				if Field.Min then Value = math.max(Field.Min, Value) end
				if Field.Max then Value = math.min(Field.Max, Value) end
				if Key == 'Count' then Value = math.floor(Value + .5) end
			end
			Object:SetAttribute(Attribute(Name, Key), Value)
			return true
		end
	end
	return false
end

function Modifiers:Clear(Object)
	if not Object then return end
	for _, Child in ipairs(Object:GetChildren()) do
		if Child:GetAttribute('FORGEModifierInternal') == true then Child:Destroy() end
	end
end

function Modifiers:_ApplyArray(Object)
	local Count = math.clamp(math.floor(tonumber(self:GetValue(Object, 'Array', 'Count')) or 1), 1, 64)
	if Count <= 1 then return end

	local OffsetX = tonumber(self:GetValue(Object, 'Array', 'OffsetX')) or 0
	local OffsetY = tonumber(self:GetValue(Object, 'Array', 'OffsetY')) or 0
	local Template = Object:Clone()
	RemoveInternal(Template)
	Template:SetAttribute(Attribute('Array', 'Enabled'), nil)

	local Container = Instance.new('Frame')
	Container.Name = '_FORGEArrayModifier'
	Container.BackgroundTransparency = 1
	Container.BorderSizePixel = 0
	Container.Position = UDim2.new()
	Container.Size = UDim2.fromScale(1, 1)
	Container.ClipsDescendants = false
	Container.ZIndex = Object.ZIndex
	Container:SetAttribute('FORGEModifierInternal', true)
	Container:SetAttribute('FORGEStyleInternal', true)
	Container:SetAttribute('FORGEHierarchyInternal', true)
	Container:SetAttribute('FORGEFixedPixelGeometry', true)
	Container.Parent = Object

	for Index = 2, Count do
		local Copy = Template:Clone()
		Copy.Name = '_Array' .. tostring(Index)
		Copy.AnchorPoint = Vector2.zero
		Copy.Position = UDim2.fromOffset(OffsetX * (Index - 1), OffsetY * (Index - 1))
		Copy.Size = UDim2.fromScale(1, 1)
		Copy.LayoutOrder = Index
		MarkGenerated(Copy)
		Copy.Parent = Container
	end

	Template:Destroy()
end

local function HasModifierInternal(Object)
	for _, Child in ipairs(Object:GetChildren()) do
		if Child:GetAttribute('FORGEModifierInternal') == true then return true end
	end
	return false
end

local function HasModifier(Object)
	for Name in pairs(Modifiers.Definitions) do
		if Object:GetAttribute(Attribute(Name, 'Enabled')) == true then return true end
	end
	return false
end

function Modifiers:Apply(Object)
	if not Object or not Object:IsA('GuiObject') or Object:GetAttribute('FORGEModifierGenerated') == true then return false end
	local Enabled = HasModifier(Object)
	local HasInternal = HasModifierInternal(Object)
	if not Enabled and not HasInternal then return false end

	if HasInternal then self:Clear(Object) end
	if self:Has(Object, 'Array') then self:_ApplyArray(Object) end
	return true
end

function Modifiers:ApplyTree(Root)
	if not Root or not Root:IsA('GuiObject') then return false end

	local Managed = Root:GetAttribute('FORGEManagedModifiers')
	if Managed == false then return false end
	if Managed == nil then
		Managed = HasModifier(Root) or HasModifierInternal(Root)
		if not Managed then
			for _, Descendant in ipairs(Root:GetDescendants()) do
				if Descendant:IsA('GuiObject') and (HasModifier(Descendant) or HasModifierInternal(Descendant)) then
					Managed = true
					break
				end
			end
		end
		Root:SetAttribute('FORGEManagedModifiers', Managed == true)
		if not Managed then return false end
	end

	local function Visit(Object)
		if Object:GetAttribute('FORGEModifierGenerated') == true
			or Object:GetAttribute('FORGEModifierInternal') == true
			or Object:GetAttribute('FORGEStyleInternal') == true
			or Object:GetAttribute('FORGEHierarchyInternal') == true
		then return end

		local Children = {}
		for _, Child in ipairs(Object:GetChildren()) do
			if Child:IsA('GuiObject')
				and Child:GetAttribute('FORGEModifierGenerated') ~= true
				and Child:GetAttribute('FORGEModifierInternal') ~= true
				and Child:GetAttribute('FORGEStyleInternal') ~= true
				and Child:GetAttribute('FORGEHierarchyInternal') ~= true
			then table.insert(Children, Child) end
		end

		self:Apply(Object)
		for _, Child in ipairs(Children) do Visit(Child) end
	end

	Visit(Root)
	return true
end

return Modifiers
