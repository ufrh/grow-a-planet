local Components = {}
Components.__index = Components

local function CleanTemplate(Root)
	local Clone = Root:Clone()
	Clone.Parent = nil

	for _, Attribute in ipairs({
		'FORGEStudioRoot',
		'FORGEZone',
		'FORGEScreenMargin',
		'FORGELocked',
		'FORGESnapTarget',
		'FORGEComponentName',
		'FORGEComponentSource',
		'FORGEComponentInstance',
		'FORGEComponentVariant',
		'FORGEComponentDetached',
		'FORGEInitialized'
	}) do
		Clone:SetAttribute(Attribute, nil)
	end

	for _, Descendant in ipairs(Clone:GetDescendants()) do
		if Descendant:GetAttribute('FORGESlotContent') == true then
			Descendant:Destroy()
		end
	end

	return Clone
end

local function DestroyDefinition(Definition)
	if not Definition then return end
	if Definition.Source then Definition.Source:Destroy() end
	for _, Variant in pairs(Definition.Variants or {}) do
		Variant:Destroy()
	end
end

function Components.new()
	local self = setmetatable({}, Components)
	self.Definitions = {}
	self.Changed = Instance.new('BindableEvent')
	return self
end

function Components:GetNames()
	local Names = {}
	for Name in pairs(self.Definitions) do table.insert(Names, Name) end
	table.sort(Names, function(A, B)
		return string.lower(A) < string.lower(B)
	end)
	return Names
end

function Components:Has(Name)
	return self.Definitions[Name] ~= nil
end

function Components:Get(Name)
	return self.Definitions[Name]
end

function Components:GetUniqueName(Base)
	Base = tostring(Base or 'Component')
	if not self:Has(Base) then return Base end

	local Index = 2
	while self:Has(Base .. tostring(Index)) do Index += 1 end
	return Base .. tostring(Index)
end

function Components:Create(Name, Root)
	if not Root then return nil end
	Name = self:GetUniqueName(Name or Root.Name)

	self.Definitions[Name] = {
		Name = Name,
		Source = CleanTemplate(Root),
		Variants = {},
		BuiltIn = false
	}

	self.Changed:Fire('Create', Name)
	return Name
end

function Components:InstallPreset(Name, Root, Variants, Metadata)
	if not Root then return false end
	Metadata = Metadata or {}

	local Existing = self.Definitions[Name]
	if Existing and not Existing.BuiltIn then return false end
	if Existing then DestroyDefinition(Existing) end

	local Definition = {
		Name = Name,
		Source = CleanTemplate(Root),
		Variants = {},
		BuiltIn = true,
		Pack = Metadata.Pack,
		Preset = Metadata.Preset or Name
	}

	for Variant, Template in pairs(Variants or {}) do
		Definition.Variants[Variant] = CleanTemplate(Template)
	end

	self.Definitions[Name] = Definition
	self.Changed:Fire('Preset', Name)
	return true
end

function Components:IsBuiltIn(Name)
	local Definition = self.Definitions[Name]
	return Definition and Definition.BuiltIn == true or false
end

function Components:GetMetadata(Name)
	local Definition = self.Definitions[Name]
	if not Definition then return nil end
	return {
		BuiltIn = Definition.BuiltIn == true,
		Pack = Definition.Pack,
		Preset = Definition.Preset
	}
end

function Components:GetCustomNames()
	local Names = {}
	for Name, Definition in pairs(self.Definitions) do
		if Definition.BuiltIn ~= true then table.insert(Names, Name) end
	end
	table.sort(Names, function(A, B)
		return string.lower(A) < string.lower(B)
	end)
	return Names
end

function Components:GetRuntimeStats()
	local ComponentsCount = 0
	local VariantsCount = 0

	for _, Definition in pairs(self.Definitions) do
		if Definition.BuiltIn ~= true then
			ComponentsCount += 1
			for _ in pairs(Definition.Variants or {}) do VariantsCount += 1 end
		end
	end

	return {
		Components = ComponentsCount,
		Variants = VariantsCount
	}
end

local function PrepareRuntimeTemplate(Template, ComponentName, Variant)
	local Clone = Template:Clone()
	Clone.Name = Variant
	Clone.Parent = nil
	Clone:SetAttribute('FORGEComponentName', ComponentName)
	Clone:SetAttribute('FORGEComponentVariant', Variant)
	Clone:SetAttribute('FORGERuntimeComponentTemplate', true)
	Clone:SetAttribute('FORGEComponentSource', nil)
	Clone:SetAttribute('FORGEComponentInstance', nil)
	Clone:SetAttribute('FORGEComponentDetached', nil)
	Clone:SetAttribute('FORGEStudioRoot', nil)
	Clone:SetAttribute('FORGEInitialized', nil)
	return Clone
end

function Components:PublishRuntimeLibrary(Parent, FolderName)
	if typeof(Parent) ~= 'Instance' then return nil, 'Runtime component library parent is unavailable' end
	FolderName = tostring(FolderName or 'FORGEComponents')
	if FolderName == '' then FolderName = 'FORGEComponents' end

	local Existing = Parent:FindFirstChild(FolderName)
	if Existing and (not Existing:IsA('Folder') or Existing:GetAttribute('FORGEGeneratedComponentLibrary') ~= true) then
		return nil, FolderName .. ' already exists and is not a generated FORGE component library'
	end

	local TempName = FolderName .. '_Building'
	local OldTemp = Parent:FindFirstChild(TempName)
	if OldTemp then OldTemp:Destroy() end

	local Library = Instance.new('Folder')
	Library.Name = TempName
	Library:SetAttribute('FORGEGeneratedComponentLibrary', true)
	Library:SetAttribute('FORGEComponentLibraryVersion', 1)
	Library.Parent = Parent

	local ComponentCount = 0
	local VariantCount = 0

	for _, Name in ipairs(self:GetCustomNames()) do
		local Definition = self.Definitions[Name]
		if Definition and Definition.Source then
			ComponentCount += 1

			local ComponentFolder = Instance.new('Folder')
			ComponentFolder.Name = Name
			ComponentFolder:SetAttribute('FORGEComponentDefinition', true)
			ComponentFolder:SetAttribute('FORGEComponentName', Name)
			ComponentFolder.Parent = Library

			local Default = PrepareRuntimeTemplate(Definition.Source, Name, 'Default')
			Default.Parent = ComponentFolder

			local VariantsFolder = Instance.new('Folder')
			VariantsFolder.Name = 'Variants'
			VariantsFolder.Parent = ComponentFolder

			local VariantNames = {}
			for Variant in pairs(Definition.Variants or {}) do table.insert(VariantNames, Variant) end
			table.sort(VariantNames, function(A, B)
				return string.lower(A) < string.lower(B)
			end)

			for _, Variant in ipairs(VariantNames) do
				local Template = Definition.Variants[Variant]
				if Template then
					local RuntimeTemplate = PrepareRuntimeTemplate(Template, Name, Variant)
					RuntimeTemplate.Parent = VariantsFolder
					VariantCount += 1
				end
			end

			ComponentFolder:SetAttribute('FORGEVariantCount', #VariantNames)
		end
	end

	Library:SetAttribute('FORGEComponentCount', ComponentCount)
	Library:SetAttribute('FORGEVariantCount', VariantCount)
	Library:SetAttribute('FORGELastComponentSync', os.time())

	if Existing then Existing:Destroy() end
	Library.Name = FolderName

	return Library, {
		Components = ComponentCount,
		Variants = VariantCount
	}
end

function Components:Update(Name, Root)
	local Definition = self.Definitions[Name]
	if not Definition or not Root or Definition.BuiltIn then return false end

	if Definition.Source then Definition.Source:Destroy() end
	Definition.Source = CleanTemplate(Root)
	self.Changed:Fire('Update', Name)
	return true
end

function Components:Remove(Name)
	local Definition = self.Definitions[Name]
	if not Definition or Definition.BuiltIn then return false end

	DestroyDefinition(Definition)
	self.Definitions[Name] = nil
	self.Changed:Fire('Remove', Name)
	return true
end

function Components:Instantiate(Name, Variant)
	local Definition = self.Definitions[Name]
	if not Definition then return nil end

	Variant = Variant or 'Default'
	local Template = Variant ~= 'Default' and Definition.Variants[Variant] or Definition.Source
	if not Template then
		Variant = 'Default'
		Template = Definition.Source
	end

	local Root = Template:Clone()
	Root:SetAttribute('FORGEComponentName', Name)
	Root:SetAttribute('FORGEComponentInstance', true)
	Root:SetAttribute('FORGEComponentSource', nil)
	Root:SetAttribute('FORGEComponentVariant', Variant)
	Root:SetAttribute('FORGEComponentDetached', nil)
	return Root
end

function Components:GetVariants(Name)
	local Definition = self.Definitions[Name]
	if not Definition then return {'Default'} end

	local Variants = {'Default'}
	for Variant in pairs(Definition.Variants) do table.insert(Variants, Variant) end
	table.sort(Variants, function(A, B)
		if A == 'Default' then return true end
		if B == 'Default' then return false end
		return string.lower(A) < string.lower(B)
	end)
	return Variants
end

function Components:SaveVariant(Name, Variant, Root)
	local Definition = self.Definitions[Name]
	if not Definition or not Root then return false end

	Variant = tostring(Variant or '')
	if Variant == '' or Variant == 'Default' then return false end

	if Definition.Variants[Variant] then Definition.Variants[Variant]:Destroy() end
	Definition.Variants[Variant] = CleanTemplate(Root)
	self.Changed:Fire('Variant', Name, Variant)
	return true
end

function Components:RenameVariant(Name, Variant, NewName)
	local Definition = self.Definitions[Name]
	if not Definition or Variant == 'Default' then return false end

	NewName = tostring(NewName or '')
	if NewName == '' or NewName == 'Default' or Definition.Variants[NewName] then return false end

	local Template = Definition.Variants[Variant]
	if not Template then return false end

	Definition.Variants[Variant] = nil
	Definition.Variants[NewName] = Template
	self.Changed:Fire('VariantRename', Name, Variant, NewName)
	return true
end

function Components:RemoveVariant(Name, Variant)
	local Definition = self.Definitions[Name]
	if not Definition or Variant == 'Default' then return false end

	local Template = Definition.Variants[Variant]
	if not Template then return false end
	Template:Destroy()
	Definition.Variants[Variant] = nil
	self.Changed:Fire('VariantRemove', Name, Variant)
	return true
end

function Components:GetTemplate(Name, Variant)
	local Definition = self.Definitions[Name]
	if not Definition then return nil end
	if Variant and Variant ~= 'Default' and Definition.Variants[Variant] then
		return Definition.Variants[Variant]
	end
	return Definition.Source
end

function Components:Capture()
	local State = {}

	for Name, Definition in pairs(self.Definitions) do
		if Definition.BuiltIn then continue end
		local Entry = {
			Name = Name,
			Source = Definition.Source:Clone(),
			Variants = {},
			BuiltIn = Definition.BuiltIn == true,
			Pack = Definition.Pack,
			Preset = Definition.Preset
		}
		Entry.Source.Parent = nil

		for Variant, Template in pairs(Definition.Variants) do
			local Clone = Template:Clone()
			Clone.Parent = nil
			Entry.Variants[Variant] = Clone
		end

		State[Name] = Entry
	end

	return State
end

function Components:DestroyState(State)
	for _, Definition in pairs(State or {}) do
		if Definition.Source then Definition.Source:Destroy() end
		for _, Variant in pairs(Definition.Variants or {}) do Variant:Destroy() end
	end
end

function Components:Restore(State, CloneState)
	for _, Definition in pairs(self.Definitions) do DestroyDefinition(Definition) end
	table.clear(self.Definitions)

	for Name, Entry in pairs(State or {}) do
		local Source = CloneState and Entry.Source:Clone() or Entry.Source
		Source.Parent = nil

		local Definition = {
			Name = Name,
			Source = Source,
			Variants = {},
			BuiltIn = Entry.BuiltIn == true,
			Pack = Entry.Pack,
			Preset = Entry.Preset
		}

		for Variant, Template in pairs(Entry.Variants or {}) do
			local Clone = CloneState and Template:Clone() or Template
			Clone.Parent = nil
			Definition.Variants[Variant] = Clone
		end

		self.Definitions[Name] = Definition
	end

	self.Changed:Fire('Restore')
	return self
end

function Components:Destroy()
	for _, Definition in pairs(self.Definitions) do DestroyDefinition(Definition) end
	table.clear(self.Definitions)
	self.Changed:Destroy()
end

return Components
