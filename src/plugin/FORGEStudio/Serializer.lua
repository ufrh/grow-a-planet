local Serializer = {}

local Properties = {
	'Active', 'AnchorPoint', 'AutomaticSize', 'BackgroundColor3', 'BackgroundTransparency',
	'BorderColor3', 'BorderMode', 'BorderSizePixel', 'ClipsDescendants', 'Interactable',
	'LayoutOrder', 'Position', 'Rotation', 'Selectable', 'SelectionOrder', 'Size',
	'SizeConstraint', 'Visible', 'ZIndex',
	'AutoButtonColor', 'Modal', 'Selected', 'Style',
	'AutoLocalize', 'ClearTextOnFocus', 'CursorPosition', 'FontFace', 'LineHeight',
	'MaxVisibleGraphemes', 'MultiLine', 'PlaceholderColor3', 'PlaceholderText', 'RichText',
	'Text', 'TextColor3', 'TextDirection', 'TextEditable', 'TextScaled', 'TextSize',
	'TextStrokeColor3', 'TextStrokeTransparency', 'TextTransparency', 'TextTruncate',
	'TextWrapped', 'TextXAlignment', 'TextYAlignment',
	'Image', 'ImageColor3', 'ImageRectOffset', 'ImageRectSize', 'ImageTransparency',
	'ResampleMode', 'ScaleType', 'SliceCenter', 'SliceScale', 'TileSize',
	'AutomaticCanvasSize', 'BottomImage', 'CanvasPosition', 'CanvasSize', 'ElasticBehavior',
	'HorizontalScrollBarInset', 'MidImage', 'ScrollBarImageColor3', 'ScrollBarImageTransparency',
	'ScrollBarThickness', 'ScrollingDirection', 'ScrollingEnabled', 'TopImage',
	'VerticalScrollBarInset', 'VerticalScrollBarPosition',
	'GroupColor3', 'GroupTransparency',
	'Video', 'Looped', 'Playing', 'TimePosition', 'Volume',
	'Ambient', 'ImageColor3', 'ImageTransparency', 'LightColor', 'LightDirection',
	'ApplyStrokeMode', 'Color', 'Enabled', 'LineJoinMode', 'Thickness', 'Transparency',
	'CornerRadius', 'Offset',
	'PaddingBottom', 'PaddingLeft', 'PaddingRight', 'PaddingTop',
	'FillDirection', 'HorizontalAlignment', 'Padding', 'SortOrder', 'VerticalAlignment',
	'Wraps',
	'CellPadding', 'CellSize', 'FillDirectionMaxCells', 'StartCorner',
	'AspectRatio', 'AspectType', 'DominantAxis',
	'MaxSize', 'MinSize', 'MaxTextSize', 'MinTextSize',
	'Scale',
	'Color3', 'BlurRadius'
}

local EditorOnlyAttributes = {
	FORGEStudioRoot = true,
	FORGEZone = true,
	FORGEScreenMargin = true,
	FORGELocked = true,
	FORGESnapTarget = true,
	FORGEComponentSource = true,
	FORGEComponentInstance = true,
	FORGEComponentDetached = true,
	FORGEInitialized = true,
	FORGEResponsive = true,
	FORGEResponsiveTree = true,
	FORGEResponsiveInternals = true,
	FORGEPositionModeX = true,
	FORGEPositionModeY = true,
	FORGESizeModeX = true,
	FORGESizeModeY = true,
	FORGELayoutCompX = true,
	FORGELayoutCompY = true,
	FORGELayoutOrderInitialized = true,
	FORGEAutoWidth = true,
	FORGEAutoHeight = true,
	FORGEAutoSize = true,
	FORGEManagedLayoutTree = true,
	FORGEManagedModifiers = true,
	FORGEAcceptChildren = true,
	FORGEInsertionTarget = true,
	FORGEFixedPixelGeometry = true,
	FORGETransparencyGradientPreset = true,
	FORGETransparencyGradientRotation = true,
	FORGETransparencyGradientSequence = true,
	FORGETransparencyGradientOriginalTransparency = true,
	FORGETransparencyGradientOriginalRotation = true
}

local ClassPropertyCache = {}
local ClassDefaultCache = {}

local function Equal(A, B)
	if typeof(A) ~= typeof(B) then return false end
	if typeof(A) == 'table' then return A == B end
	return A == B
end

local function PropertyProfile(ClassName)
	local Cached = ClassPropertyCache[ClassName]
	if Cached then return Cached, ClassDefaultCache[ClassName] end

	local Success, Probe = pcall(Instance.new, ClassName)
	if not Success or not Probe then
		ClassPropertyCache[ClassName] = {}
		ClassDefaultCache[ClassName] = {}
		return ClassPropertyCache[ClassName], ClassDefaultCache[ClassName]
	end

	local Supported = {}
	local Defaults = {}
	for _, Property in ipairs(Properties) do
		local OK, Value = pcall(function() return Probe[Property] end)
		if OK then
			table.insert(Supported, Property)
			Defaults[Property] = Value
		end
	end
	Probe:Destroy()

	ClassPropertyCache[ClassName] = Supported
	ClassDefaultCache[ClassName] = Defaults
	return Supported, Defaults
end

local function Clone(Value)
	if type(Value) ~= 'table' then return Value end
	local Copy = {}
	for Key, Child in pairs(Value) do Copy[Clone(Key)] = Clone(Child) end
	return Copy
end

local function ReadProperty(Object, Property)
	local Success, Value = pcall(function() return Object[Property] end)
	if not Success then return nil, false end
	return Value, true
end

local function IsEditorOnlyAttribute(Name)
	if EditorOnlyAttributes[Name] == true then return true end
	if string.sub(Name, 1, 13) == 'FORGEModifier' then return true end
	return false
end

function Serializer:SerializeInstance(Object, Options)
	Options = Options or {}
	local State = Options._State
	if not State then
		State = {Count = 0}
		Options._State = State
	end
	State.Count += 1
	local YieldEvery = tonumber(Options.YieldEvery) or 0
	if YieldEvery > 0 and State.Count % YieldEvery == 0 then task.wait() end

	local Data = {
		Class = Object.ClassName,
		Name = Object.Name,
		Properties = {},
		Attributes = {},
		Children = {}
	}

	local Supported, Defaults = PropertyProfile(Object.ClassName)
	for _, Property in ipairs(Supported) do
		local Value, Success = ReadProperty(Object, Property)
		if Success and not Equal(Value, Defaults[Property]) then
			Data.Properties[Property] = Value
		end
	end

	for Name, Value in pairs(Object:GetAttributes()) do
		if Options.IncludeEditorAttributes == true or not IsEditorOnlyAttribute(Name) then
			Data.Attributes[Name] = Value
			local Prefix = 'FORGEBinding_'
			if string.sub(Name, 1, #Prefix) == Prefix then
				local Property = string.sub(Name, #Prefix + 1)
				local PropertyValue, Success = ReadProperty(Object, Property)
				if Success then Data.Properties[Property] = PropertyValue end
			end
		end
	end

	for _, Child in ipairs(Object:GetChildren()) do
		local StyleInternal = Child:GetAttribute('FORGEStyleInternal') == true
		local Skip = StyleInternal and (Child.Name == '_FORGEContent' or Child.Name == '_FORGEOverlay')

		if not Skip and StyleInternal and Child.Name == '_FORGEShine' then
			local SurfaceRoot = Object.Parent
			local Interactive = SurfaceRoot and SurfaceRoot:IsA('GuiButton')
			local Persistent = Child:GetAttribute('FORGEPersistentShine') == true
			Skip = not Interactive and not Persistent
		end

		if Options.PruneGeneratedInternals == true and StyleInternal then
			local Surface = Object:GetAttribute('FORGEStyleSurface')
			local LayoutKind = Object:GetAttribute('FORGELayoutKind')
			local Kind = Object:GetAttribute('FORGESimpleKind')

			if Surface and (
				Child.Name == '_FORGEBaseGradient'
				or Child.Name == '_FORGEMaterial'
				or Child.Name == '_FORGEInset'
				or Child.Name == '_FORGEShadow'
				or Child.Name == '_FORGECorner'
			) then
				Skip = true
			elseif LayoutKind and (Child.Name == '_FORGELayout' or Child.Name == '_FORGEPadding') then
				Skip = true
			elseif (Kind == 'Slider' or Kind == 'ProgressBar') and Child.Name == 'Track' then
				Skip = true
			end
		end

		if not Skip then table.insert(Data.Children, self:SerializeInstance(Child, Options)) end
	end

	return Data
end

function Serializer:DeserializeInstance(Data, Options)
	if type(Data) ~= 'table' or type(Data.Class) ~= 'string' then return nil end
	Options = Options or {}
	local State = Options._State
	if not State then
		State = {Count = 0}
		Options._State = State
	end
	State.Count += 1
	local YieldEvery = tonumber(Options.YieldEvery) or 0
	if YieldEvery > 0 and State.Count % YieldEvery == 0 then task.wait() end

	local Success, Object = pcall(Instance.new, Data.Class)
	if not Success or not Object then return nil end
	Object.Name = tostring(Data.Name or Data.Class)

	for Property, Value in pairs(Data.Properties or {}) do
		pcall(function() Object[Property] = Value end)
	end

	for Name, Value in pairs(Data.Attributes or {}) do
		pcall(function() Object:SetAttribute(Name, Value) end)
	end

	for _, ChildData in ipairs(Data.Children or {}) do
		local Child = self:DeserializeInstance(ChildData, Options)
		if Child then Child.Parent = Object end
	end

	return Object
end

function Serializer:Clone(Value)
	return Clone(Value)
end

local function IsArray(Value)
	local Count, Maximum = 0, 0
	for Key in pairs(Value) do
		if type(Key) ~= 'number' or Key < 1 or Key % 1 ~= 0 then return false end
		Count += 1
		Maximum = math.max(Maximum, Key)
	end
	return Count == Maximum
end

local function Number(Value)
	if Value ~= Value then return '0/0' end
	if Value == math.huge then return 'math.huge' end
	if Value == -math.huge then return '-math.huge' end
	return string.format('%.17g', Value)
end

local function Quote(Value)
	local Result = tostring(Value)
	Result = Result:gsub('\\', '\\\\')
	Result = Result:gsub(string.char(39), '\\' .. string.char(39))
	Result = Result:gsub('\a', '\\a')
	Result = Result:gsub('\b', '\\b')
	Result = Result:gsub('\f', '\\f')
	Result = Result:gsub('\n', '\\n')
	Result = Result:gsub('\r', '\\r')
	Result = Result:gsub('\t', '\\t')
	Result = Result:gsub('\v', '\\v')
	Result = Result:gsub('[%z\1-\8\14-\31]', function(Character)
		return string.format('\\%03d', string.byte(Character))
	end)
	return string.char(39) .. Result .. string.char(39)
end

local function EnumSource(Value)
	return tostring(Value)
end

local function SequenceSource(Name, Keypoints)
	local Parts = {}
	for _, Point in ipairs(Keypoints) do
		if Name == 'ColorSequence' then
			table.insert(Parts, string.format(
				'ColorSequenceKeypoint.new(%s, Color3.new(%s, %s, %s))',
				Number(Point.Time),
				Number(Point.Value.R),
				Number(Point.Value.G),
				Number(Point.Value.B)
			))
		else
			table.insert(Parts, string.format(
				'NumberSequenceKeypoint.new(%s, %s, %s)',
				Number(Point.Time),
				Number(Point.Value),
				Number(Point.Envelope)
			))
		end
	end
	return Name .. '.new({' .. table.concat(Parts, ', ') .. '})'
end

local function ValueSource(Value, Indent)
	local Type = typeof(Value)
	Indent = Indent or 0

	if Value == nil then return 'nil' end
	if Type == 'string' then return Quote(Value) end
	if Type == 'number' then return Number(Value) end
	if Type == 'boolean' then return Value and 'true' or 'false' end
	if Type == 'EnumItem' then return EnumSource(Value) end
	if Type == 'Color3' then
		return string.format('Color3.new(%s, %s, %s)', Number(Value.R), Number(Value.G), Number(Value.B))
	end
	if Type == 'Vector2' then
		return string.format('Vector2.new(%s, %s)', Number(Value.X), Number(Value.Y))
	end
	if Type == 'Vector3' then
		return string.format('Vector3.new(%s, %s, %s)', Number(Value.X), Number(Value.Y), Number(Value.Z))
	end
	if Type == 'UDim' then
		return string.format('UDim.new(%s, %s)', Number(Value.Scale), Number(Value.Offset))
	end
	if Type == 'UDim2' then
		return string.format(
			'UDim2.new(%s, %s, %s, %s)',
			Number(Value.X.Scale), Number(Value.X.Offset), Number(Value.Y.Scale), Number(Value.Y.Offset)
		)
	end
	if Type == 'Rect' then
		return string.format(
			'Rect.new(%s, %s, %s, %s)',
			Number(Value.Min.X), Number(Value.Min.Y), Number(Value.Max.X), Number(Value.Max.Y)
		)
	end
	if Type == 'NumberRange' then
		return string.format('NumberRange.new(%s, %s)', Number(Value.Min), Number(Value.Max))
	end
	if Type == 'ColorSequence' then return SequenceSource('ColorSequence', Value.Keypoints) end
	if Type == 'NumberSequence' then return SequenceSource('NumberSequence', Value.Keypoints) end
	if Type == 'Font' then
		return string.format(
			'Font.new(%s, %s, %s)',
			Quote(Value.Family),
			EnumSource(Value.Weight),
			EnumSource(Value.Style)
		)
	end
	if Type == 'BrickColor' then return 'BrickColor.new(' .. Quote(Value.Name) .. ')' end
	if Type == 'CFrame' then
		local Components = {Value:GetComponents()}
		local Parts = {}
		for _, Component in ipairs(Components) do table.insert(Parts, Number(Component)) end
		return 'CFrame.new(' .. table.concat(Parts, ', ') .. ')'
	end
	if Type ~= 'table' then return Quote(tostring(Value)) end

	local NextIndent = Indent + 1
	local Prefix = string.rep('\t', NextIndent)
	local ClosePrefix = string.rep('\t', Indent)
	local Parts = {}

	if IsArray(Value) then
		for Index = 1, #Value do
			table.insert(Parts, Prefix .. ValueSource(Value[Index], NextIndent))
		end
	else
		local Keys = {}
		for Key in pairs(Value) do table.insert(Keys, Key) end
		table.sort(Keys, function(A, B)
			local AT, BT = type(A), type(B)
			if AT ~= BT then return AT < BT end
			return tostring(A) < tostring(B)
		end)

		for _, Key in ipairs(Keys) do
			table.insert(
				Parts,
				Prefix .. '[' .. ValueSource(Key, NextIndent) .. '] = ' .. ValueSource(Value[Key], NextIndent)
			)
		end
	end

	if #Parts == 0 then return '{}' end
	return '{\n' .. table.concat(Parts, ',\n') .. '\n' .. ClosePrefix .. '}'
end

function Serializer:ToSource(Value)
	return ValueSource(Value, 0)
end

return Serializer
