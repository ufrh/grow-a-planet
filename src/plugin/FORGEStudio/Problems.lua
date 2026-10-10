local Problems = {}

local SemanticAnimationProperties = {
	PrimaryColor = true,
	SecondaryColor = true,
	SatinVisible = true,
	ShadowVisible = true,
	ShadowColor = true,
	ShadowOpacity = true,
	ShadowBlur = true,
	InsetPixels = true,
	StrokeThickness = true,
	Value = true,
	TextSize = true,
	TextTransparency = true,
	LineHeight = true,
	TextStrokeColor = true,
	TextStrokeOpacity = true,
	ShadowSize = true,
	ShadowOffsetX = true,
	ShadowOffsetY = true,
	Gap = true,
	Padding = true
}

local function Add(Result, Severity, Code, Message, Context)
	local Entry = {
		Severity = Severity,
		Code = Code,
		Message = Message
	}
	for Key, Value in pairs(Context or {}) do Entry[Key] = Value end
	table.insert(Result, Entry)
end

local function ResolveData(Data, Path)
	local Current = Data
	for Part in tostring(Path or ''):gmatch('[^%.]+') do
		if type(Current) ~= 'table' then return nil end
		Current = Current[Part]
		if Current == nil then return nil end
	end
	return Current
end

local function ChildByName(Node, Name)
	for _, Child in ipairs(Node and Node.Children or {}) do
		if Child.Name == Name then return Child end
	end
end

local function ResolveRelative(Root, Path)
	if not Root then return nil end
	if Path == nil or Path == '' or Path == 'Root' then return Root end

	local Current = Root
	for Part in tostring(Path):gmatch('[^/]+') do
		Current = ChildByName(Current, Part)
		if not Current then return nil end
	end
	return Current
end

local function SiblingKeys(Items)
	local Counts, Seen, Keys = {}, {}, {}

	for _, Item in ipairs(Items or {}) do
		local Name = tostring(Item.Name)
		Counts[Name] = (Counts[Name] or 0) + 1
	end

	for Index, Item in ipairs(Items or {}) do
		local Name = tostring(Item.Name)
		Seen[Name] = (Seen[Name] or 0) + 1
		Keys[Index] = Item.RuntimeKey
			or (Counts[Name] > 1 and (Name .. '#' .. Seen[Name]) or Name)
	end

	return Keys
end

local function Walk(Node, Path, Callback, InSlot)
	if not Node then return end
	local Attributes = Node.Attributes or {}
	local SlotName = Attributes.FORGESlotName
	local IsSlot = type(SlotName) == 'string' and SlotName ~= ''
	Callback(Node, Path, InSlot == true)

	local Children = Node.Children or {}
	local Keys = SiblingKeys(Children)
	for Index, Child in ipairs(Children) do
		Walk(Child, Path .. '/' .. Keys[Index], Callback, InSlot == true or IsSlot)
	end
end

local function BuildPathMap(Screen)
	local Map, Duplicates = {}, {}
	local Roots = Screen and Screen.Roots or {}
	local Keys = SiblingKeys(Roots)

	for Index, Root in ipairs(Roots) do
		Walk(Root, Keys[Index], function(Node, Path)
			if Map[Path] then
				Duplicates[Path] = true
			else
				Map[Path] = Node
			end
		end)
	end
	return Map, Duplicates, Keys
end

local function HasValue(List, Value)
	for _, Item in ipairs(List or {}) do
		if Item == Value then return true end
	end
	return false
end

local function HasWritableProperty(Node, Property)
	if not Node or type(Property) ~= 'string' or Property == '' then return false end
	local Success, Object = pcall(Instance.new, tostring(Node.Class or ''))
	if not Success or not Object then return false end

	local Valid = pcall(function()
		local Value = Object[Property]
		Object[Property] = Value
	end)
	Object:Destroy()
	return Valid
end

local function ValidateNode(Result, Data, Node, Context, PathMap)
	local Attributes = Node.Attributes or {}
	local Components = Data.Components or {}
	local Styles = Data.Styles or {}
	local Packs = Styles.Packs or {}

	local Success, Object = pcall(Instance.new, tostring(Node.Class or ''))
	if not Success then
		Add(Result, 'Error', 'RuntimeClass', 'Runtime cannot create class ' .. tostring(Node.Class), Context)
	elseif Object then
		Object:Destroy()
	end

	local ComponentName = Attributes.FORGEComponentName
	if ComponentName then
		local Definition = Components[ComponentName]
		if not Definition then
			Add(Result, 'Error', 'MissingComponent', 'Missing component definition: ' .. tostring(ComponentName), Context)
		else
			local Variant = Attributes.FORGEComponentVariant or 'Default'
			if Variant ~= 'Default' and not (Definition.Variants and Definition.Variants[Variant]) then
				Add(Result, 'Error', 'InvalidVariant', tostring(ComponentName) .. ' has no variant ' .. tostring(Variant), Context)
			end
		end
	end

	local PackName = Attributes.FORGEStylePack
	if PackName and not Packs[PackName] then
		Add(Result, 'Error', 'StylePack', 'Unavailable style pack: ' .. tostring(PackName), Context)
	end

	local Pack = PackName and Packs[PackName]
	local Surface = Attributes.FORGEStyleSurface
	if Surface and (not Pack or not Pack.Surfaces or not Pack.Surfaces[Surface]) then
		Add(Result, 'Error', 'Surface', 'Unavailable surface: ' .. tostring(PackName) .. '/' .. tostring(Surface), Context)
	end

	local Rarity = Attributes.FORGERarity
	if Rarity and (not Pack or not Pack.Rarities or not Pack.Rarities[Rarity]) then
		Add(Result, 'Error', 'Rarity', 'Unavailable rarity: ' .. tostring(PackName) .. '/' .. tostring(Rarity), Context)
	end

	local Preset = Attributes.FORGEStylePreset
	if Preset and (not PackName or not HasValue(Styles.Presets and Styles.Presets[PackName], Preset)) then
		Add(Result, 'Error', 'Preset', 'Unavailable preset: ' .. tostring(PackName) .. '/' .. tostring(Preset), Context)
	end

	local ActionType = Attributes.FORGEActionType
	local ActionTarget = Attributes.FORGEActionTarget
	if ActionType == 'OpenScreen' then
		if not Data.Screens or not Data.Screens[ActionTarget] then
			Add(Result, 'Error', 'OpenScreen', 'OpenScreen target does not exist: ' .. tostring(ActionTarget), Context)
		end
	elseif ActionType == 'Show' or ActionType == 'Hide' or ActionType == 'Toggle' then
		if not PathMap or not PathMap[ActionTarget] then
			Add(
				Result,
				Context.Component and 'Warning' or 'Error',
				'ObjectPath',
				ActionType .. ' target does not exist in this authored tree: ' .. tostring(ActionTarget),
				Context
			)
		end
	end

	for Name, BindingPath in pairs(Attributes) do
		local Prefix = 'FORGEBinding_'
		if string.sub(Name, 1, #Prefix) == Prefix then
			local Property = string.sub(Name, #Prefix + 1)
			if not HasWritableProperty(Node, Property) then
				Add(Result, 'Error', 'BindingProperty', 'Invalid binding target property: ' .. tostring(Property), Context)
			end

			local Mock = Data.Editor and Data.Editor.MockData
			if Mock and ResolveData(Mock, BindingPath) == nil then
				Add(Result, 'Warning', 'BindingPath', 'Binding path does not resolve in mock data: ' .. tostring(BindingPath), Context)
			end
		end
	end
end

local function ValidateSlots(Result, Root, Context)
	local Slots = {}
	Walk(Root, Root.RuntimeKey or tostring(Root.Name), function(Node, Path, InSlot)
		local Attributes = Node.Attributes or {}
		local SlotName = Attributes.FORGESlotName
		local NodeContext = {}
		for Key, Value in pairs(Context or {}) do NodeContext[Key] = Value end
		NodeContext.ObjectPath = Path

		if SlotName ~= nil then
			if type(SlotName) ~= 'string' or SlotName == '' then
				Add(Result, 'Error', 'MalformedSlot', 'Slot name is malformed', NodeContext)
			elseif Slots[SlotName] then
				Add(Result, 'Error', 'DuplicateSlot', 'Duplicate slot name: ' .. SlotName, NodeContext)
			else
				Slots[SlotName] = Path
			end
		end

		if Attributes.FORGESlotContent == true and not InSlot then
			Add(Result, 'Error', 'OrphanSlotContent', 'Slot content is not beneath a named slot', NodeContext)
		end
	end)
end

local function ValidateComponentTree(Result, Data, Name, Variant, Root)
	local PathMap = BuildPathMap({Roots = {Root}})
	ValidateSlots(Result, Root, {Component = Name, Variant = Variant})
	Walk(Root, Root.RuntimeKey or tostring(Root.Name), function(Node, Path)
		ValidateNode(Result, Data, Node, {
			Component = Name,
			Variant = Variant,
			ObjectPath = Path
		}, PathMap)
	end)
end

local function ValidateComponents(Result, Data)
	for Name, Definition in pairs(Data.Components or {}) do
		if not Definition.Source then
			Add(Result, 'Error', 'ComponentSource', 'Component has no source: ' .. tostring(Name), {Component = Name})
		else
			ValidateComponentTree(Result, Data, Name, 'Default', Definition.Source)
		end

		for Variant, Root in pairs(Definition.Variants or {}) do
			ValidateComponentTree(Result, Data, Name, Variant, Root)
		end
	end
end

local function AnimationCandidates(Data)
	local Roots = {}
	for ScreenName, Screen in pairs(Data.Screens or {}) do
		for _, Root in ipairs(Screen.Roots or {}) do
			table.insert(Roots, {Root = Root, Screen = ScreenName})
		end
	end

	for Name, Definition in pairs(Data.Components or {}) do
		if Definition.Source then table.insert(Roots, {Root = Definition.Source, Component = Name, Variant = 'Default'}) end
		for Variant, Root in pairs(Definition.Variants or {}) do
			table.insert(Roots, {Root = Root, Component = Name, Variant = Variant})
		end
	end
	return Roots
end

local function ValidateAnimations(Result, Data)
	local Candidates = AnimationCandidates(Data)

	for Name, Definition in pairs(Data.Animations or {}) do
		for Index, Track in ipairs(Definition.Tracks or {}) do
			local Resolved = {}
			for _, Candidate in ipairs(Candidates) do
				local Target = ResolveRelative(Candidate.Root, Track.TargetPath)
				if Target then table.insert(Resolved, {Target = Target, Context = Candidate}) end
			end

			if #Resolved == 0 then
				Add(Result, 'Error', 'AnimationTarget', 'Animation target path never resolves: ' .. tostring(Track.TargetPath), {
					Animation = Name,
					Track = Index
				})
			else
				local PropertyValid = false
				for _, Match in ipairs(Resolved) do
					if Track.PropertyKind == 'Semantic' then
						local Attributes = Match.Target.Attributes or {}
						if Attributes.FORGESimpleKind ~= nil and SemanticAnimationProperties[Track.Property] == true then
							PropertyValid = true
							break
						end
					elseif HasWritableProperty(Match.Target, Track.Property) then
						PropertyValid = true
						break
					end
				end

				if not PropertyValid then
					Add(Result, 'Error', 'AnimationProperty', 'Animation property is invalid for target: ' .. tostring(Track.Property), {
						Animation = Name,
						Track = Index
					})
				end
			end
		end
	end
end

function Problems:Validate(Data)
	local Result = {}
	if type(Data) ~= 'table' then
		Add(Result, 'Error', 'Package', 'No runtime export data exists')
		return Result
	end

	if Data.Schema ~= 'FORGE.UI.Project' then
		Add(Result, 'Error', 'PackageSchema', 'Runtime package schema is invalid: ' .. tostring(Data.Schema))
	end
	if tonumber(Data.Version) ~= 1 then
		Add(Result, 'Error', 'PackageVersion', 'Runtime package version is unsupported: ' .. tostring(Data.Version))
	end
	if Data.RuntimeAPI ~= '1.0.0' then
		Add(Result, 'Error', 'RuntimeAPI', 'Runtime package targets unavailable FORGE.UI API: ' .. tostring(Data.RuntimeAPI))
	end

	if not Data.StartScreen or not Data.Screens or not Data.Screens[Data.StartScreen] then
		Add(Result, 'Error', 'StartScreen', 'Start screen is missing or unavailable')
	end

	if not Data.Styles or not Data.Styles.Packs or not Data.Styles.Packs[Data.ActiveStylePack] then
		Add(Result, 'Error', 'ActiveStylePack', 'Active style pack is unavailable: ' .. tostring(Data.ActiveStylePack))
	end

	for ScreenName, Screen in pairs(Data.Screens or {}) do
		if #(Screen.Roots or {}) == 0 then
			Add(Result, 'Warning', 'EmptyScreen', 'Screen has no runtime roots', {Screen = ScreenName})
		end

		local PathMap, Duplicates, Keys = BuildPathMap(Screen)
		for Path in pairs(Duplicates) do
			Add(Result, 'Error', 'DuplicatePath', 'Runtime object path is ambiguous: ' .. tostring(Path), {
				Screen = ScreenName,
				ObjectPath = Path
			})
		end
		for Index, Root in ipairs(Screen.Roots or {}) do
			ValidateSlots(Result, Root, {Screen = ScreenName})
			Walk(Root, Keys[Index], function(Node, Path)
				ValidateNode(Result, Data, Node, {
					Screen = ScreenName,
					ObjectPath = Path
				}, PathMap)
			end)
		end
	end

	ValidateComponents(Result, Data)
	ValidateAnimations(Result, Data)

	for _, Name in ipairs(Data.ScreenOrder or {}) do
		if not Data.Screens or not Data.Screens[Name] then
			Add(Result, 'Error', 'ScreenOrder', 'Screen order references a missing screen: ' .. tostring(Name), {Screen = Name})
		end
	end

	for Name in pairs(Data.Screens or {}) do
		if not table.find(Data.ScreenOrder or {}, Name) then
			Add(Result, 'Warning', 'ScreenOrder', 'Screen is missing from deterministic screen order: ' .. tostring(Name), {Screen = Name})
		end
	end

	table.sort(Result, function(A, B)
		local Priority = {Error = 1, Warning = 2, Info = 3}
		local AP, BP = Priority[A.Severity] or 9, Priority[B.Severity] or 9
		if AP ~= BP then return AP < BP end
		if tostring(A.Screen or '') ~= tostring(B.Screen or '') then return tostring(A.Screen or '') < tostring(B.Screen or '') end
		if tostring(A.ObjectPath or '') ~= tostring(B.ObjectPath or '') then return tostring(A.ObjectPath or '') < tostring(B.ObjectPath or '') end
		return tostring(A.Code or '') < tostring(B.Code or '')
	end)

	return Result
end

function Problems:Count(Result)
	local Counts = {Error = 0, Warning = 0, Info = 0}
	for _, Entry in ipairs(Result or {}) do Counts[Entry.Severity] = (Counts[Entry.Severity] or 0) + 1 end
	return Counts
end

return Problems
