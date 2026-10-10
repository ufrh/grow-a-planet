local Serializer = require(script.Parent.Serializer)
local StylePacks = require(script.Parent.StylePacks)
local ComponentPresets = require(script.Parent.ComponentPresets)
local Theme = require(script.Parent.Theme)

local Packaging = {}

Packaging.Schema = 'FORGE.UI.Project'
Packaging.Version = 1
Packaging.RuntimeAPI = '1.0.0'

local function Copy(Value)
	if type(Value) ~= 'table' then return Value end
	local Result = {}
	for Key, Child in pairs(Value) do
		if type(Child) ~= 'function' then Result[Copy(Key)] = Copy(Child) end
	end
	return Result
end

local function CopyStyleValue(Value, Seen)
	local ValueType = typeof(Value)
	if ValueType == 'Instance' or ValueType == 'function' or ValueType == 'RBXScriptConnection' then return nil end
	if ValueType ~= 'table' then return Value end

	Seen = Seen or {}
	if Seen[Value] then return nil end
	Seen[Value] = true

	local Result = {}
	for Key, Child in pairs(Value) do
		local CleanKey = CopyStyleValue(Key, Seen)
		local CleanValue = CopyStyleValue(Child, Seen)
		if CleanKey ~= nil and CleanValue ~= nil then Result[CleanKey] = CleanValue end
	end

	Seen[Value] = nil
	return Result
end

local function CaptureStylePack(Pack)
	local Result = {}
	for Key, Value in pairs(Pack or {}) do
		if Key ~= 'RuntimeTheme' then
			local Clean = CopyStyleValue(Value)
			if Clean ~= nil then Result[Key] = Clean end
		end
	end
	return Result
end

local PersistableTypes = {
	string = true,
	number = true,
	boolean = true,
	EnumItem = true,
	Color3 = true,
	Vector2 = true,
	Vector3 = true,
	UDim = true,
	UDim2 = true,
	Rect = true,
	NumberRange = true,
	BrickColor = true,
	CFrame = true,
	Font = true,
	ColorSequence = true,
	NumberSequence = true
}

local function SanitizePersistenceValue(Value, Seen)
	if Value == nil then return nil end

	local ValueType = typeof(Value)
	if ValueType ~= 'table' then return PersistableTypes[ValueType] and Value or nil end

	Seen = Seen or {}
	if Seen[Value] then return nil end
	Seen[Value] = true

	local Remove = {}
	for Key, Child in pairs(Value) do
		local KeyType = typeof(Key)
		local CleanKey = KeyType == 'table'
			and SanitizePersistenceValue(Key, Seen)
			or PersistableTypes[KeyType] and Key
			or nil
		local CleanValue = SanitizePersistenceValue(Child, Seen)

		if CleanKey == nil or CleanValue == nil or CleanKey ~= Key then
			table.insert(Remove, Key)
		elseif CleanValue ~= Child then
			Value[Key] = CleanValue
		end
	end

	for _, Key in ipairs(Remove) do Value[Key] = nil end
	Seen[Value] = nil
	return Value
end

local AssignRuntimeKeys

local function GetDocumentScreen(App)
	return App.DocumentScreen or App.Screens and App.Screens:GetCurrent() or nil
end

local function ReferencedComponents(App)
	local Result = {}
	if not App.Screens then return Result end

	local Owner = GetDocumentScreen(App)
	for _, ScreenName in ipairs(App.Screens:GetNames()) do
		local Roots = Owner == ScreenName and App.Document and App.Document:GetRoots()
			or App.Screens:GetStoredRoots(ScreenName)
		for _, Root in ipairs(Roots or {}) do
			local Name = Root:GetAttribute('FORGEComponentName')
			if type(Name) == 'string' and Name ~= '' then Result[Name] = true end

			for _, Descendant in ipairs(Root:GetDescendants()) do
				local ComponentName = Descendant:GetAttribute('FORGEComponentName')
				if type(ComponentName) == 'string' and ComponentName ~= '' then Result[ComponentName] = true end
			end
		end
	end

	return Result
end

local function CaptureComponents(App, IncludeBuiltIns)
	local Result = {}
	if not App.Components then return Result end
	local UsedBuiltIns = IncludeBuiltIns == false and {} or ReferencedComponents(App)

	for _, Name in ipairs(App.Components:GetNames()) do
		local Definition = App.Components:Get(Name)
		local Include = Definition and Definition.Source
			and (Definition.BuiltIn ~= true or IncludeBuiltIns ~= false and UsedBuiltIns[Name] == true)
		if Include then
			local Source = Serializer:SerializeInstance(Definition.Source)
			AssignRuntimeKeys({Source})

			local Entry = {
				Name = Name,
				BuiltIn = Definition.BuiltIn == true,
				Pack = Definition.Pack,
				Preset = Definition.Preset,
				Source = Source,
				Variants = {}
			}

			for Variant, Template in pairs(Definition.Variants or {}) do
				local VariantData = Serializer:SerializeInstance(Template)
				AssignRuntimeKeys({VariantData})
				Entry.Variants[Variant] = VariantData
			end

			Result[Name] = Entry
		end
	end

	return Result
end

local function GetScreenRoots(App, Name)
	if App.Screens and App.Document and GetDocumentScreen(App) == Name then
		return App.Document:GetRoots()
	end
	return App.Screens and App.Screens:GetStoredRoots(Name) or {}
end

local function GetScreenReference()
	local Reference = Theme.ReferenceSize or Vector2.new(1920, 1080)

	return {
		Width = Reference.X,
		Height = Reference.Y,
		Device = Theme.ReferenceDevice or 'Desktop 16:9',
		ScaleMode = Theme.ReferenceScaleMode or 'Fit',
		StrokeLODThreshold = tonumber(Theme.StrokeLODThreshold) or .5,
		StrokeLODBoost = tonumber(Theme.StrokeLODBoost) or 1
	}
end

local function BuildSiblingKeys(Items)
	local Counts, Seen, Keys = {}, {}, {}

	for _, Item in ipairs(Items or {}) do
		local Name = tostring(Item.Name)
		Counts[Name] = (Counts[Name] or 0) + 1
	end

	for Index, Item in ipairs(Items or {}) do
		local Name = tostring(Item.Name)
		Seen[Name] = (Seen[Name] or 0) + 1
		Keys[Index] = Counts[Name] > 1 and (Name .. '#' .. Seen[Name]) or Name
	end

	return Keys
end

AssignRuntimeKeys = function(Items)
	local Keys = BuildSiblingKeys(Items)

	for Index, Item in ipairs(Items or {}) do
		Item.RuntimeKey = Keys[Index]
		AssignRuntimeKeys(Item.Children)
	end

	return Keys
end

local function CaptureScreens(App, IncludeEditorAttributes)
	local Result = {}
	if not App.Screens then return Result end

	local SerializeOptions = {
		IncludeEditorAttributes = IncludeEditorAttributes == true,
		PruneGeneratedInternals = IncludeEditorAttributes == true,
		YieldEvery = 350,
		_State = {Count = 0}
	}

	for _, Name in ipairs(App.Screens:GetNames()) do
		local Entry = {
			Name = Name,
			Roots = {},
			Reference = GetScreenReference(App, Name)
		}

		local Roots = GetScreenRoots(App, Name)

		for _, Root in ipairs(Roots) do
			table.insert(Entry.Roots, Serializer:SerializeInstance(Root, SerializeOptions))
		end

		AssignRuntimeKeys(Entry.Roots)

		Result[Name] = Entry
	end

	return Result
end

local EditorAttributes = {
	'FORGEZone',
	'FORGEScreenMargin',
	'FORGELocked',
	'FORGESnapTarget',
	'FORGEComponentSource',
	'FORGEComponentInstance',
	'FORGEComponentDetached',
	'FORGEInitialized'
}

local function CaptureEditorTreeMetadata(Root, RootKey)
	local Result = {}

	local function Visit(Object, Path)
		local Entry = {}
		for _, Name in ipairs(EditorAttributes) do
			local Value = Object:GetAttribute(Name)
			if Value ~= nil then Entry[Name] = Value end
		end
		if next(Entry) then Result[Path] = Entry end

		local Children = Object:GetChildren()
		local Keys = BuildSiblingKeys(Children)
		for Index, Child in ipairs(Children) do
			Visit(Child, Path .. '/' .. Keys[Index])
		end
	end

	Visit(Root, RootKey or Root.Name)
	return Result
end

local function CaptureScreenViews(App)
	local Result = {}
	if not App.Screens then return Result end

	local Owner = GetDocumentScreen(App)
	for _, Name in ipairs(App.Screens:GetNames()) do
		if Owner == Name and App._GetCurrentView then
			Result[Name] = Copy(App:_GetCurrentView())
		else
			local Definition = App.Screens:Get(Name)
			Result[Name] = Copy(Definition and Definition.View or {})
		end
	end
	return Result
end

local function CaptureScreenMetadata(App)
	local Result = {}
	if not App.Screens then return Result end

	for _, Name in ipairs(App.Screens:GetNames()) do
		local Screen = {}
		local Roots = GetScreenRoots(App, Name)
		local RootKeys = BuildSiblingKeys(Roots)

		for Index, Root in ipairs(Roots) do
			for Path, Metadata in pairs(CaptureEditorTreeMetadata(Root, RootKeys[Index])) do
				Screen[Path] = Metadata
			end
		end

		Result[Name] = Screen
	end
	return Result
end

local function ApplyEditorTreeMetadata(Root, Metadata, RootKey)
	RootKey = RootKey or Root.Name

	local function Visit(Object, Path)
		local Entry = Metadata and Metadata[Path]
		if Entry then
			for Name, Value in pairs(Entry) do
				pcall(function() Object:SetAttribute(Name, Value) end)
			end
		end

		local Children = Object:GetChildren()
		local Keys = BuildSiblingKeys(Children)
		for Index, Child in ipairs(Children) do
			Visit(Child, Path .. '/' .. Keys[Index])
		end
	end

	Visit(Root, RootKey)
end

local function CaptureStyles()
	local Result = {
		Default = StylePacks.Default,
		Packs = {},
		Presets = {}
	}

	for _, PackName in ipairs(StylePacks:GetNames()) do
		Result.Packs[PackName] = CaptureStylePack(StylePacks:Get(PackName))
		Result.Presets[PackName] = ComponentPresets:GetNames(PackName)
	end

	return Result
end

function Packaging:Capture(App, Options)
	Options = Options or {}
	local Persistence = Options.Persistence == true

	local Data = {
		Schema = self.Schema,
		Version = self.Version,
		RuntimeAPI = self.RuntimeAPI,
		ActiveStylePack = App.ActiveStylePack or StylePacks.Default,
		StartScreen = App.Screens and App.Screens:GetStart() or nil,
		ScreenOrder = App.Screens and App.Screens:GetNames() or {},
		Screens = CaptureScreens(App, Persistence),
		Components = CaptureComponents(App, not Persistence),
		Animations = App.Animations and App.Animations:Capture() or {},
		Styles = Persistence and {} or CaptureStyles(),
		Editor = {
			CurrentScreen = GetDocumentScreen(App),
			ScreenViews = CaptureScreenViews(App),
			ScreenMetadata = Persistence and {} or CaptureScreenMetadata(App),
			MockData = App.MockData and App.MockData:Capture() or {},
			View = App._GetCurrentView and App:_GetCurrentView() or {},
			SelectedSurface = App.SelectedSurface,
			SelectedTypography = App.SelectedTypography,
			SelectedRarity = App.SelectedRarity
		}
	}

	return SanitizePersistenceValue(Data) or {}
end

function Packaging:RuntimeView(Data)
	return {
		Schema = Data.Schema,
		Version = Data.Version,
		RuntimeAPI = Data.RuntimeAPI,
		ActiveStylePack = Data.ActiveStylePack,
		StartScreen = Data.StartScreen,
		ScreenOrder = Copy(Data.ScreenOrder or {}),
		Screens = Data.Screens or {},
		Components = Data.Components or {},
		Animations = Data.Animations or {},
		Styles = Data.Styles or {}
	}
end

function Packaging:ToSource(Data)
	return 'return ' .. Serializer:ToSource(Data) .. '\n'
end

local function SafeName(Name)
	Name = tostring(Name or ''):gsub('[^%w_%- ]', '_'):gsub('%s+', '_')
	Name = Name:gsub('^_+', ''):gsub('_+$', '')
	return Name ~= '' and Name or 'Item'
end

local MAX_MODULE_SOURCE = 190000

local function WriteSource(Parent, Name, Source)
	if #Source > MAX_MODULE_SOURCE then
		return nil, string.format(
			'Generated source for %s is %d characters; maximum safe module size is %d',
			tostring(Name),
			#Source,
			MAX_MODULE_SOURCE
		)
	end

	local Module = Instance.new('ModuleScript')
	Module.Name = Name
	Module.Parent = Parent

	local Success, Error = pcall(function() Module.Source = Source end)
	if not Success then
		Module:Destroy()
		return nil, tostring(Error)
	end
	return Module
end

local function OrderedKeys(Map, Preferred)
	local Result, Seen = {}, {}

	for _, Name in ipairs(Preferred or {}) do
		if Map[Name] ~= nil and not Seen[Name] then
			Seen[Name] = true
			table.insert(Result, Name)
		end
	end

	local Remaining = {}
	for Name in pairs(Map or {}) do
		if not Seen[Name] then table.insert(Remaining, Name) end
	end
	table.sort(Remaining)
	for _, Name in ipairs(Remaining) do table.insert(Result, Name) end
	return Result
end



function Packaging:WriteRuntimeGui(Parent, Name, App, Data)
	if not Parent then return nil, 'Runtime UI parent is unavailable' end
	if not App or not App.Screens then return nil, 'FORGE Studio screens are unavailable' end

	Name = SafeName(Name or 'FORGEAutoUI')
	local Existing = Parent:FindFirstChild(Name)
	if Existing and (not Existing:IsA('ScreenGui') or Existing:GetAttribute('FORGEGeneratedRuntimeUI') ~= true) then
		return nil, Name .. ' already exists and is not generated FORGE runtime UI'
	end

	local TempName = Name .. '_Building'
	local OldTemp = Parent:FindFirstChild(TempName)
	if OldTemp then OldTemp:Destroy() end

	local Gui = Instance.new('ScreenGui')
	Gui.Name = TempName
	Gui.IgnoreGuiInset = true
	Gui.ResetOnSpawn = false
	Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function() Gui.ScreenInsets = Enum.ScreenInsets.None end)
	pcall(function() Gui.ClipToDeviceSafeArea = false end)
	Gui:SetAttribute('FORGEGeneratedRuntimeUI', true)
	Gui:SetAttribute('FORGEStartScreen', Data.StartScreen or '')
	Gui:SetAttribute('FORGELastSync', os.time())
	Gui.Parent = Parent

	for Order, ScreenName in ipairs(OrderedKeys(Data.Screens or {}, Data.ScreenOrder)) do
		local ScreenData = Data.Screens[ScreenName] or {}
		local Reference = ScreenData.Reference or GetScreenReference()
		local Width = math.max(tonumber(Reference.Width) or 1920, 1)
		local Height = math.max(tonumber(Reference.Height) or 1080, 1)

		local Screen = Instance.new('CanvasGroup')
		Screen.Name = SafeName(ScreenName)
		Screen.BackgroundTransparency = 1
		Screen.BorderSizePixel = 0
		Screen.Position = UDim2.fromScale(0, 0)
		Screen.Size = UDim2.fromScale(1, 1)
		Screen.Visible = ScreenName == Data.StartScreen
		Screen.ZIndex = 1
		Screen:SetAttribute('FORGEScreenName', ScreenName)
		Screen:SetAttribute('FORGEScreenOrder', Order)
		Screen:SetAttribute('FORGEReferenceWidth', Width)
		Screen:SetAttribute('FORGEReferenceHeight', Height)
		Screen:SetAttribute('FORGEReferenceScaleMode', Reference.ScaleMode or 'Fit')
		Screen:SetAttribute('FORGEStrokeLODThreshold', tonumber(Reference.StrokeLODThreshold) or .5)
		Screen:SetAttribute('FORGEStrokeLODBoost', tonumber(Reference.StrokeLODBoost) or 1)
		Screen.Parent = Gui

		local Canvas = Instance.new('CanvasGroup')
		Canvas.Name = '_FORGEResponsiveCanvas'
		Canvas.BackgroundTransparency = 1
		Canvas.BorderSizePixel = 0
		Canvas.Position = UDim2.fromOffset(0, 0)
		Canvas.Size = UDim2.fromOffset(Width, Height)
		Canvas.ClipsDescendants = false
		Canvas.Parent = Screen

		local Scale = Instance.new('UIScale')
		Scale.Name = '_FORGEResponsiveScale'
		Scale.Scale = 1
		Scale.Parent = Canvas

		for _, Root in ipairs(GetScreenRoots(App, ScreenName)) do
			local Clone = Root:Clone()
			Clone.Parent = Canvas
		end
	end

	local RuntimeScript = Instance.new('LocalScript')
	RuntimeScript.Name = '_FORGEResponsiveRuntime'
	RuntimeScript.Source = [[local ReplicatedStorage = game:GetService('ReplicatedStorage')
local FORGE = ReplicatedStorage:WaitForChild('FORGE')
local Responsive = require(FORGE:WaitForChild('Engine'):WaitForChild('UI'):WaitForChild('Responsive'))
local Gui = script.Parent
local Handles = {}

local function Bind(Screen)
	if not Screen:IsA('GuiObject') then return end
	local Canvas = Screen:FindFirstChild('_FORGEResponsiveCanvas')
	local Scale = Canvas and Canvas:FindFirstChild('_FORGEResponsiveScale')
	local Width = tonumber(Screen:GetAttribute('FORGEReferenceWidth'))
	local Height = tonumber(Screen:GetAttribute('FORGEReferenceHeight'))
	local StrokeLODThreshold = tonumber(Screen:GetAttribute('FORGEStrokeLODThreshold')) or .5
	local StrokeLODBoost = tonumber(Screen:GetAttribute('FORGEStrokeLODBoost')) or 1
	if not Canvas or not Scale or not Width or not Height then return end

	local Handle = Responsive.Bind(
		Screen,
		Canvas,
		Scale,
		{
			Width = Width,
			Height = Height,
			StrokeLODThreshold = StrokeLODThreshold,
			StrokeLODBoost = StrokeLODBoost
		},
		Screen:GetAttribute('FORGEReferenceScaleMode') or 'Fit'
	)
	table.insert(Handles, Handle)
end

for _, Screen in ipairs(Gui:GetChildren()) do Bind(Screen) end
Gui.ChildAdded:Connect(Bind)
]]
	RuntimeScript.Parent = Gui

	if Existing then Existing:Destroy() end
	Gui.Name = Name
	return Gui
end

local function DescriptorSource(Descriptor)
	return 'return ' .. Serializer:ToSource(Descriptor) .. '\n'
end

local function WriteDescriptorModule(Parent, Name, Descriptor, State)
	local Direct = DescriptorSource(Descriptor)
	if #Direct <= MAX_MODULE_SOURCE then return WriteSource(Parent, Name, Direct) end

	local Children = Descriptor.Children or {}
	if #Children == 0 then
		return nil, string.format(
			'Descriptor %s is too large to serialize (%d characters) and has no child tree to split',
			tostring(Name),
			#Direct
		)
	end

	local Shallow = Copy(Descriptor)
	Shallow.Children = {}
	local Refs = {}

	for Index, Child in ipairs(Children) do
		State.Counter += 1
		local ChildName = string.format('Node_%06d', State.Counter)
		local ChildModule, Error = WriteDescriptorModule(Parent, ChildName, Child, State)
		if not ChildModule then return nil, Error end
		Refs[Index] = ChildName
	end

	local Lines = {
		'local Data = ' .. Serializer:ToSource(Shallow),
		'Data.Children = {}'
	}
	for Index, ChildName in ipairs(Refs) do
		table.insert(
			Lines,
			'Data.Children[' .. tostring(Index) .. '] = require(script.Parent['
				.. Serializer:ToSource(ChildName) .. '])'
		)
	end
	table.insert(Lines, 'return Data')
	table.insert(Lines, '')

	return WriteSource(Parent, Name, table.concat(Lines, '\n'))
end

local function WriteScreenModule(ScreensFolder, ModuleName, ScreenData)
	local Base = Copy(ScreenData)
	local Roots = Base.Roots or {}
	Base.Roots = {}

	if #Roots == 0 then
		return WriteSource(ScreensFolder, ModuleName, 'return ' .. Serializer:ToSource(Base) .. '\n')
	end

	local Chunks = Instance.new('Folder')
	Chunks.Name = ModuleName .. '_Chunks'
	Chunks.Parent = ScreensFolder

	local State = {Counter = 0}
	local RootRefs = {}

	for Index, Root in ipairs(Roots) do
		local RootName = string.format('Root_%03d', Index)
		local RootModule, Error = WriteDescriptorModule(Chunks, RootName, Root, State)
		if not RootModule then
			Chunks:Destroy()
			return nil, Error
		end
		RootRefs[Index] = RootName
	end

	local Lines = {
		'local Data = ' .. Serializer:ToSource(Base),
		'Data.Roots = {}'
	}
	for Index, RootName in ipairs(RootRefs) do
		table.insert(
			Lines,
			'Data.Roots[' .. tostring(Index) .. '] = require(script.Parent['
				.. Serializer:ToSource(Chunks.Name) .. '][' .. Serializer:ToSource(RootName) .. '])'
		)
	end
	table.insert(Lines, 'return Data')
	table.insert(Lines, '')

	local Module, Error = WriteSource(ScreensFolder, ModuleName, table.concat(Lines, '\n'))
	if not Module then Chunks:Destroy() end
	return Module, Error
end

local function WriteScreenTemplate(TemplatesFolder, Name, ScreenData, Index)
	local Folder = Instance.new('Folder')
	Folder.Name = string.format('%03d_%s', Index, SafeName(Name))
	Folder:SetAttribute('FORGEScreenTemplate', true)
	Folder:SetAttribute('FORGEScreenName', Name)

	local Reference = ScreenData.Reference or {}
	if tonumber(Reference.Width) then Folder:SetAttribute('FORGEReferenceWidth', tonumber(Reference.Width)) end
	if tonumber(Reference.Height) then Folder:SetAttribute('FORGEReferenceHeight', tonumber(Reference.Height)) end
	if Reference.Device then Folder:SetAttribute('FORGEReferenceDevice', tostring(Reference.Device)) end
	if Reference.ScaleMode then Folder:SetAttribute('FORGEReferenceScaleMode', tostring(Reference.ScaleMode)) end
	if tonumber(Reference.StrokeLODThreshold) then Folder:SetAttribute('FORGEStrokeLODThreshold', tonumber(Reference.StrokeLODThreshold)) end
	if tonumber(Reference.StrokeLODBoost) then Folder:SetAttribute('FORGEStrokeLODBoost', tonumber(Reference.StrokeLODBoost)) end

	local DeserializeOptions = {YieldEvery = 350, _State = {Count = 0}}
	for _, RootData in ipairs(ScreenData.Roots or {}) do
		local Root = Serializer:DeserializeInstance(RootData, DeserializeOptions)
		if Root then Root.Parent = Folder end
	end

	Folder.Parent = TemplatesFolder
	return Folder
end

local function WriteComponentModule(ComponentsFolder, ModuleName, ComponentData)
	local Base = Copy(ComponentData)
	local Source = Base.Source
	local Variants = Base.Variants or {}
	Base.Source = nil
	Base.Variants = {}

	if not Source and next(Variants) == nil then
		return WriteSource(ComponentsFolder, ModuleName, 'return ' .. Serializer:ToSource(Base) .. '\n')
	end

	local Chunks = Instance.new('Folder')
	Chunks.Name = ModuleName .. '_Chunks'
	Chunks.Parent = ComponentsFolder
	local State = {Counter = 0}
	local SourceRef
	local VariantRefs = {}

	if Source then
		SourceRef = 'Source'
		local Module, Error = WriteDescriptorModule(Chunks, SourceRef, Source, State)
		if not Module then
			Chunks:Destroy()
			return nil, Error
		end
	end

	local VariantNames = {}
	for Name in pairs(Variants) do table.insert(VariantNames, Name) end
	table.sort(VariantNames)
	for Index, VariantName in ipairs(VariantNames) do
		local Ref = string.format('Variant_%03d', Index)
		local Module, Error = WriteDescriptorModule(Chunks, Ref, Variants[VariantName], State)
		if not Module then
			Chunks:Destroy()
			return nil, Error
		end
		VariantRefs[VariantName] = Ref
	end

	local Lines = {
		'local Data = ' .. Serializer:ToSource(Base),
		'Data.Variants = {}'
	}
	if SourceRef then
		table.insert(
			Lines,
			'Data.Source = require(script.Parent[' .. Serializer:ToSource(Chunks.Name)
				.. '][' .. Serializer:ToSource(SourceRef) .. '])'
		)
	end
	for _, VariantName in ipairs(VariantNames) do
		table.insert(
			Lines,
			'Data.Variants[' .. Serializer:ToSource(VariantName) .. '] = require(script.Parent['
				.. Serializer:ToSource(Chunks.Name) .. '][' .. Serializer:ToSource(VariantRefs[VariantName]) .. '])'
		)
	end
	table.insert(Lines, 'return Data')
	table.insert(Lines, '')

	local Module, Error = WriteSource(ComponentsFolder, ModuleName, table.concat(Lines, '\n'))
	if not Module then Chunks:Destroy() end
	return Module, Error
end

function Packaging:WritePackage(Parent, Name, Data, Options)
	if not Parent then return nil, 'Export parent is unavailable' end
	Options = Options or {}
	local RuntimeOnly = Options.RuntimeOnly == true
	Name = SafeName(Name or 'FORGEUIProject')

	local Existing = Parent:FindFirstChild(Name)
	if Existing and (not Existing:IsA('Folder') or Existing:GetAttribute('FORGEGeneratedPackage') ~= true) then
		return nil, Name .. ' already exists and is not a generated FORGE package'
	end

	local TempName = Name .. '_Building'
	local OldTemp = Parent:FindFirstChild(TempName)
	if OldTemp then
		if OldTemp:IsA('Folder') and OldTemp:GetAttribute('FORGEGeneratedPackage') == true then
			OldTemp:Destroy()
		else
			return nil, TempName .. ' already exists and is not a generated FORGE package'
		end
	end

	local Package = Instance.new('Folder')
	Package.Name = TempName
	Package:SetAttribute('FORGEGeneratedPackage', true)
	Package:SetAttribute('FORGEProjectSchema', self.Schema)
	Package:SetAttribute('FORGEProjectVersion', self.Version)
	Package.Parent = Parent

	local ScreensFolder = Instance.new('Folder')
	ScreensFolder.Name = 'Screens'
	ScreensFolder.Parent = Package

	local ComponentsFolder = Instance.new('Folder')
	ComponentsFolder.Name = 'Components'
	ComponentsFolder.Parent = Package

	local TemplatesFolder = Instance.new('Folder')
	TemplatesFolder.Name = 'Templates'
	TemplatesFolder.Parent = Package

	local ScreenTemplatesFolder = Instance.new('Folder')
	ScreenTemplatesFolder.Name = 'Screens'
	ScreenTemplatesFolder.Parent = TemplatesFolder

	local RuntimeData = self:RuntimeView(Data)
	local ScreenModules, ComponentModules, ScreenTemplates = {}, {}, {}

	for Index, ScreenName in ipairs(OrderedKeys(RuntimeData.Screens, RuntimeData.ScreenOrder)) do
		local ScreenData = RuntimeData.Screens[ScreenName]
		local Template = WriteScreenTemplate(ScreenTemplatesFolder, ScreenName, ScreenData, Index)
		ScreenTemplates[ScreenName] = Template.Name

		if not RuntimeOnly then
			local ModuleName = string.format('%03d_%s', Index, SafeName(ScreenName))
			local Module, ScreenError = WriteScreenModule(ScreensFolder, ModuleName, ScreenData)
			if not Module then
				Package:Destroy()
				return nil, 'Screen ' .. tostring(ScreenName) .. ': ' .. tostring(ScreenError)
			end
			ScreenModules[ScreenName] = ModuleName
		end
	end

	for Index, ComponentName in ipairs(OrderedKeys(RuntimeData.Components)) do
		local ModuleName = string.format('%03d_%s', Index, SafeName(ComponentName))
		local Module, Error = WriteComponentModule(ComponentsFolder, ModuleName, RuntimeData.Components[ComponentName])
		if not Module then
			Package:Destroy()
			return nil, 'Component ' .. tostring(ComponentName) .. ': ' .. tostring(Error)
		end
		ComponentModules[ComponentName] = ModuleName
	end

	local Animations, Error = WriteSource(Package, 'Animations', self:ToSource(RuntimeData.Animations))
	if not Animations then
		Package:Destroy()
		return nil, 'Animations: ' .. tostring(Error)
	end

	local Styles
	Styles, Error = WriteSource(Package, 'Styles', self:ToSource(RuntimeData.Styles))
	if not Styles then
		Package:Destroy()
		return nil, 'Styles: ' .. tostring(Error)
	end

	local Editor
	if not RuntimeOnly then
		Editor, Error = WriteSource(Package, 'Editor', self:ToSource(Data.Editor or {}))
		if not Editor then
			Package:Destroy()
			return nil, 'Editor: ' .. tostring(Error)
		end
	end

	local RuntimeLines = {
		'local ScreenModules = ' .. Serializer:ToSource(ScreenModules),
		'local ComponentModules = ' .. Serializer:ToSource(ComponentModules),
		'local Data = {',
		'\tSchema = ' .. Serializer:ToSource(RuntimeData.Schema) .. ',',
		'\tVersion = ' .. Serializer:ToSource(RuntimeData.Version) .. ',',
		'\tRuntimeAPI = ' .. Serializer:ToSource(RuntimeData.RuntimeAPI) .. ',',
		'\tActiveStylePack = ' .. Serializer:ToSource(RuntimeData.ActiveStylePack) .. ',',
		'\tStartScreen = ' .. Serializer:ToSource(RuntimeData.StartScreen) .. ',',
		'\tScreenOrder = ' .. Serializer:ToSource(RuntimeData.ScreenOrder) .. ',',
		'\tScreenTemplates = ' .. Serializer:ToSource(ScreenTemplates) .. ',',
		'\tAnimations = require(script.Parent.Animations)',
		'}',
		'',
		'local StylesValue',
		'Data.Styles = setmetatable({}, {',
		'\t__index = function(_, Key)',
		'\t\tStylesValue = StylesValue or require(script.Parent.Styles)',
		'\t\treturn StylesValue[Key]',
		'\tend',
		'})',
		'',
		'Data.Screens = setmetatable({}, {',
		'\t__index = function(Current, Name)',
		'\t\tlocal ModuleName = ScreenModules[Name]',
		'\t\tif not ModuleName then return nil end',
		'\t\tlocal Value = require(script.Parent.Screens[ModuleName])',
		'\t\trawset(Current, Name, Value)',
		'\t\treturn Value',
		'\tend',
		'})',
		'',
		'Data.Components = setmetatable({}, {',
		'\t__index = function(Current, Name)',
		'\t\tlocal ModuleName = ComponentModules[Name]',
		'\t\tif not ModuleName then return nil end',
		'\t\tlocal Value = require(script.Parent.Components[ModuleName])',
		'\t\trawset(Current, Name, Value)',
		'\t\treturn Value',
		'\tend',
		'})',
		'',
		'return Data',
		''
	}
	local Runtime
	Runtime, Error = WriteSource(Package, 'Runtime', table.concat(RuntimeLines, '\n'))
	if not Runtime then
		Package:Destroy()
		return nil, 'Runtime manifest: ' .. tostring(Error)
	end

	local Project
	if not RuntimeOnly then
		local ProjectSource = table.concat({
			'local Data = table.clone(require(script.Parent.Runtime))',
			'Data.Editor = require(script.Parent.Editor)',
			'return Data',
			''
		}, '\n')

		Project, Error = WriteSource(Package, 'Project', ProjectSource)
		if not Project then
			Package:Destroy()
			return nil, 'Project manifest: ' .. tostring(Error)
		end
	end

	Runtime:SetAttribute('FORGEProjectSchema', self.Schema)
	Runtime:SetAttribute('FORGEProjectVersion', self.Version)
	Runtime:SetAttribute('FORGERuntimeOnly', true)
	if Project then
		Project:SetAttribute('FORGEProjectSchema', self.Schema)
		Project:SetAttribute('FORGEProjectVersion', self.Version)
	end
	Package:SetAttribute('FORGERuntimeOnly', RuntimeOnly)

	if Existing then Existing:Destroy() end
	Package.Name = Name
	return {
		Folder = Package,
		Runtime = Runtime,
		Project = Project
	}
end

function Packaging:ReadModule(Module)
	local PackageFolder
	if Module and Module:IsA('Folder') and Module:GetAttribute('FORGEGeneratedPackage') == true then
		PackageFolder = Module
		Module = Module:FindFirstChild('Project') or Module:FindFirstChild('Runtime')
	elseif Module and Module:IsA('ModuleScript') then
		local Parent = Module.Parent
		if Parent and Parent:IsA('Folder') and Parent:GetAttribute('FORGEGeneratedPackage') == true then
			PackageFolder = Parent
		end
	end
	if not Module or not Module:IsA('ModuleScript') then
		return nil, 'Select a generated package Folder, Project ModuleScript, or Runtime ModuleScript'
	end

	local Success, Data = pcall(require, Module)
	if not Success then return nil, tostring(Data) end
	if type(Data) ~= 'table' or Data.Schema ~= self.Schema then
		return nil, 'Selected module is not a FORGE UI project package'
	end

	-- Generated packages lazy-load screens/components through __index. Import and
	-- validation also iterate these maps with pairs(), which only sees values that
	-- have already been materialized. Hydrate the package here so older named
	-- exports remain fully importable across places.
	if type(Data.Screens) == 'table' then
		for _, Name in ipairs(Data.ScreenOrder or {}) do
			local _ = Data.Screens[Name]
		end
	end

	if PackageFolder and type(Data.Components) == 'table' then
		local ComponentsFolder = PackageFolder:FindFirstChild('Components')
		if ComponentsFolder then
			for _, Child in ipairs(ComponentsFolder:GetChildren()) do
				if Child:IsA('ModuleScript') then
					local Ok, Entry = pcall(require, Child)
					if Ok and type(Entry) == 'table' then
						local Name = tostring(Entry.Name or '')
						if Name ~= '' then Data.Components[Name] = Entry end
					end
				end
			end
		end
	end

	return Data
end

local function RestoreComponents(App, Data)
	if not App.Components then return end
	local State = {}

	for Name, Entry in pairs(Data.Components or {}) do
		if Entry.BuiltIn ~= true and Entry.Source then
			local Source = Serializer:DeserializeInstance(Entry.Source)
			if Source then
				State[Name] = {
					Name = Name,
					Source = Source,
					Variants = {},
					BuiltIn = false,
					Pack = Entry.Pack,
					Preset = Entry.Preset
				}

				for Variant, TemplateData in pairs(Entry.Variants or {}) do
					local Template = Serializer:DeserializeInstance(TemplateData)
					if Template then State[Name].Variants[Variant] = Template end
				end
			end
		end
	end

	App.Components:Restore(State, false)
	if App._InstallStylePresets then App:_InstallStylePresets() end
end

local function RestoreScreens(App, Data)
	if not App.Screens then return end
	local State = {
		Definitions = {},
		Order = table.clone(Data.ScreenOrder or {}),
		Current = Data.Editor and Data.Editor.CurrentScreen or Data.StartScreen,
		Start = Data.StartScreen
	}

	local ScreenNames = {}
	local SeenScreens = {}
	for _, Name in ipairs(Data.ScreenOrder or {}) do
		if Data.Screens and Data.Screens[Name] and not SeenScreens[Name] then
			SeenScreens[Name] = true
			table.insert(ScreenNames, Name)
		end
	end
	for Name in pairs(Data.Screens or {}) do
		if not SeenScreens[Name] then
			SeenScreens[Name] = true
			table.insert(ScreenNames, Name)
		end
	end

	for _, Name in ipairs(ScreenNames) do
		local Entry = Data.Screens[Name]
		local Definition = {
			Name = Name,
			Roots = {},
			View = Copy(Data.Editor and Data.Editor.ScreenViews and Data.Editor.ScreenViews[Name] or Entry.View or {})
		}

		local RootKeys = {}
		do
			local Calculated = BuildSiblingKeys(Entry.Roots or {})
			for Index, RootData in ipairs(Entry.Roots or {}) do
				RootKeys[Index] = RootData.RuntimeKey or Calculated[Index]
			end
		end

		for Index, RootData in ipairs(Entry.Roots or {}) do
			local Root = Serializer:DeserializeInstance(RootData)
			if Root then
				ApplyEditorTreeMetadata(
					Root,
					Data.Editor and Data.Editor.ScreenMetadata and Data.Editor.ScreenMetadata[Name],
					RootKeys[Index]
				)
				table.insert(Definition.Roots, Root)
			end
		end

		State.Definitions[Name] = Definition
	end

	if #State.Order == 0 then
		for Name in pairs(State.Definitions) do table.insert(State.Order, Name) end
		table.sort(State.Order)
	end

	App.Screens:Restore(State, false)
end

function Packaging:Import(App, Data)
	if type(Data) ~= 'table' or Data.Schema ~= self.Schema then
		return false, 'Invalid FORGE UI project package'
	end
	if tonumber(Data.Version) ~= self.Version then
		return false, 'Unsupported FORGE UI project package version'
	end

	if App.InteractiveMode and App._SetInteractiveMode then App:_SetInteractiveMode(false) end
	if App._StopRuntimePreview then App:_StopRuntimePreview() end

	RestoreComponents(App, Data)
	if App.Animations then App.Animations:Restore(Copy(Data.Animations or {})) end
	if App.MockData then App.MockData:Restore(Copy(Data.Editor and Data.Editor.MockData or {})) end
	RestoreScreens(App, Data)

	App.ActiveStylePack = Data.ActiveStylePack or StylePacks.Default
	App.SelectedSurface = Data.Editor and Data.Editor.SelectedSurface or 'Regular'
	App.SelectedTypography = Data.Editor and Data.Editor.SelectedTypography or 'Body'
	App.SelectedRarity = Data.Editor and Data.Editor.SelectedRarity or 'Common'
	App.SelectedScreen = App.Screens and App.Screens:GetCurrent() or nil

	local Current = App.Screens and App.Screens:GetCurrent()
	if Current and App._LoadScreen then App:_LoadScreen(Current, {NoSave = true}) end
	if App.History then App.History:Reset('Import') end
	if App._RefreshAll then App:_RefreshAll() end
	return true
end

return Packaging
