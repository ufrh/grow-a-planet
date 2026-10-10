local StylePacks = require(script.Parent.StylePacks)

local Presets = {}

local Names = {
	'Container',
	'Row',
	'Stack',
	'Spacer',
	'VerticalDivider',
	'HorizontalDivider',
	'Panel',
	'Button',
	'Slider',
	'ProgressBar',
	'Selector',
	'Scroller',
	'Navbar',
	'Header',
	'Subtext'
}

local Metadata = {
	Container = {Category = 'Layout', DisplayName = 'Container'},
	Row = {Category = 'Layout', DisplayName = 'Row'},
	Stack = {Category = 'Layout', DisplayName = 'Stack'},
	Spacer = {Category = 'Layout', DisplayName = 'Spacer'},
	VerticalDivider = {Category = 'Layout', DisplayName = 'Vertical Divider'},
	HorizontalDivider = {Category = 'Layout', DisplayName = 'Horizontal Divider'},
	Panel = {Category = 'RUCKUS', DisplayName = 'Panel'},
	Button = {Category = 'RUCKUS', DisplayName = 'Button'},
	Slider = {Category = 'RUCKUS', DisplayName = 'Slider'},
	ProgressBar = {Category = 'RUCKUS', DisplayName = 'Progress Bar'},
	Selector = {Category = 'RUCKUS', DisplayName = 'Selector'},
	Scroller = {Category = 'RUCKUS', DisplayName = 'Scroller'},
	Navbar = {Category = 'RUCKUS', DisplayName = 'Navbar'},
	Header = {Category = 'Typography', DisplayName = 'Header'},
	Subtext = {Category = 'Typography', DisplayName = 'Subtext'}
}

local function SafeSet(Object, Property, Value)
	pcall(function() Object[Property] = Value end)
end

local function Pack()
	return StylePacks:Get('RUCKUS')
end

local DividerTransparencyPresets = {
	None = nil,
	['Fade Ends'] = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(.14, .28),
		NumberSequenceKeypoint.new(.28, 0),
		NumberSequenceKeypoint.new(.72, 0),
		NumberSequenceKeypoint.new(.86, .28),
		NumberSequenceKeypoint.new(1, 1)
	}),
	['Soft Fade Ends'] = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(.22, .55),
		NumberSequenceKeypoint.new(.4, .08),
		NumberSequenceKeypoint.new(.6, .08),
		NumberSequenceKeypoint.new(.78, .55),
		NumberSequenceKeypoint.new(1, 1)
	}),
	['Fade Left'] = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(.18, .35),
		NumberSequenceKeypoint.new(.34, 0),
		NumberSequenceKeypoint.new(1, 0)
	}),
	['Fade Right'] = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(.66, 0),
		NumberSequenceKeypoint.new(.82, .35),
		NumberSequenceKeypoint.new(1, 1)
	})
}

local DividerTransparencyPresetNames = {
	'None',
	'Fade Ends',
	'Soft Fade Ends',
	'Fade Left',
	'Fade Right'
}

local function Mark(Object, Kind)
	Object:SetAttribute('FORGESimpleKind', Kind)
	Object:SetAttribute('FORGEStylePack', 'RUCKUS')
	Object:SetAttribute('FORGEStylePreset', Kind)
	return Object
end

local function NewText(Parent, Name, Value, Role)
	local Label = Instance.new('TextLabel')
	Label.Name = Name
	Label:SetAttribute('FORGEStyleInternal', true)
	Label.BackgroundTransparency = 1
	Label.BorderSizePixel = 0
	Label.Text = Value or ''
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextYAlignment = Enum.TextYAlignment.Center
	Label.Position = UDim2.fromScale(0, 0)
	Label.Size = UDim2.fromScale(1, 1)
	Label.ZIndex = Parent.ZIndex + 4
	Label:SetAttribute('FORGEInheritSecondary', true)
	Label.Parent = Parent
	StylePacks:ApplyTypography(Label, Role or 'Body', 'RUCKUS')
	return Label
end

local function InitializeTextAttributes(Root, Label, Role)
	local Token = StylePacks:GetTypography('RUCKUS', Role or 'Body')
	Root:SetAttribute('FORGETextRole', Role or 'Body')
	Root:SetAttribute('FORGETextWeight', Token and Token.Weight and Token.Weight.Name or 'Regular')
	Root:SetAttribute('FORGETextStyle', 'Normal')
	Root:SetAttribute('FORGETextSize', Label.TextSize)
	Root:SetAttribute('FORGETextTransparency', Label.TextTransparency)
	Root:SetAttribute('FORGETextXAlignment', Label.TextXAlignment.Name)
	Root:SetAttribute('FORGETextYAlignment', Label.TextYAlignment.Name)
	Root:SetAttribute('FORGETextWrapped', Label.TextWrapped)
	Root:SetAttribute('FORGETextScaled', Label.TextScaled)
	Root:SetAttribute('FORGERichText', Label.RichText)
	Root:SetAttribute('FORGELineHeight', Label.LineHeight)
	Root:SetAttribute('FORGETextStrokeColor', Label.TextStrokeColor3)
	Root:SetAttribute('FORGETextStrokeOpacity', 1 - Label.TextStrokeTransparency)
end

local function NewSurface(ClassName, Name, Size)
	local Root = Instance.new(ClassName)
	Root.Name = Name
	Root.Size = Size
	Root.BorderSizePixel = 0
	if Root:IsA('TextButton') then
		Root.Text = ''
		Root.AutoButtonColor = false
	end
	StylePacks:ApplySurface(Root, 'Regular', 'RUCKUS')
	return Root
end

local function SetSemanticDefaults(Root, Kind, Primary, Secondary, Satin, Shadow, Inset)
	local P = Pack()
	local ShadowData = P.Effect.Shadow
	Mark(Root, Kind)
	Root:SetAttribute('FORGEPrimaryColor', Primary or P.Color.Surface)
	Root:SetAttribute('FORGESecondaryColor', Secondary or P.Color.Text)
	Root:SetAttribute('FORGESatinVisible', Satin ~= false)
	Root:SetAttribute('FORGEInsetEnabled', true)
	Root:SetAttribute('FORGEShadowVisible', Shadow ~= false)
	Root:SetAttribute('FORGEShadowColor', ShadowData.Color)
	Root:SetAttribute('FORGEShadowOpacity', 1 - ShadowData.Transparency)
	Root:SetAttribute('FORGEShadowBlur', ShadowData.BlurRadius.Offset)
	Root:SetAttribute('FORGEInsetPixels', Inset or 2)
	Root:SetAttribute('FORGEStrokeThickness', P.Metric.Stroke or 1)
	Root:SetAttribute('FORGEAcceptChildren', false)
	return Root
end

local function MarkManagedLayoutTree(Object)
	local Current = Object
	while Current and Current:IsA('GuiObject') do
		Current:SetAttribute('FORGEManagedLayoutTree', true)
		Current = Current.Parent
	end
end

local function LayoutFrame(Name, Kind, Size)
	local Root = Instance.new('Frame')
	Root.Name = Name
	Root.BackgroundTransparency = 1
	Root.BorderSizePixel = 0
	Root.Size = Size
	Root.AutomaticSize = Enum.AutomaticSize.None
	Root:SetAttribute('FORGESimpleKind', Kind)
	Root:SetAttribute('FORGELayoutKind', Kind)
	Root:SetAttribute('FORGEAcceptChildren', true)
	Root:SetAttribute('FORGEGap', 8)
	Root:SetAttribute('FORGEPadding', 0)
	Root:SetAttribute('FORGEAutoWidth', Kind == 'Row' or Kind == 'Stack')
	Root:SetAttribute('FORGEAutoHeight', Kind == 'Row' or Kind == 'Stack')
	if Kind == 'Row' or Kind == 'Stack' then Root:SetAttribute('FORGEManagedLayoutTree', true) end
	return Root
end

local function RaiseTreeZIndex(Object, Minimum)
	if not Object or not Object:IsA('GuiObject') then return end

	local Lowest = Object.ZIndex
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA('GuiObject') then Lowest = math.min(Lowest, Descendant.ZIndex) end
	end

	local Delta = math.max((Minimum or 1) - Lowest, 0)
	if Delta <= 0 then return end

	Object.ZIndex += Delta
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA('GuiObject') then Descendant.ZIndex += Delta end
	end
end

local function GetContentZIndex(Root)
	if not Root or not Root:IsA('GuiObject') then return 1 end

	local Highest = Root.ZIndex
	for _, Descendant in ipairs(Root:GetDescendants()) do
		if Descendant:IsA('GuiObject')
			and Descendant:GetAttribute('FORGEStyleInternal') == true
		then
			Highest = math.max(Highest, Descendant.ZIndex)
		end
	end

	return Highest + 1
end

local function RaiseAuthoredChildren(Root)
	if not Root or not Root:IsA('GuiObject') then return end

	local Minimum = GetContentZIndex(Root)
	for _, Child in ipairs(Root:GetChildren()) do
		if Child:IsA('GuiObject')
			and Child:GetAttribute('FORGEStyleInternal') ~= true
		then
			RaiseTreeZIndex(Child, Minimum)
		end
	end
end

local function EnsureLayout(Root)
	local Kind = Root:GetAttribute('FORGELayoutKind')
	if Kind ~= 'Row' and Kind ~= 'Stack' then return end

	local Layout = Root:FindFirstChild('_FORGELayout')
	if not Layout then
		Layout = Instance.new('UIListLayout')
		Layout.Name = '_FORGELayout'
		Layout.SortOrder = Enum.SortOrder.LayoutOrder
		Layout.Parent = Root
	end

	Layout:SetAttribute('FORGEStyleInternal', true)
	Layout.FillDirection = Kind == 'Row' and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	Layout.Padding = UDim.new(0, Root:GetAttribute('FORGEGap') or 8)
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Layout.VerticalAlignment = Kind == 'Row' and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top

	pcall(function()
		Layout.HorizontalFlex = Enum.UIFlexAlignment.None
		Layout.VerticalFlex = Enum.UIFlexAlignment.None
	end)

	local Padding = Root:FindFirstChild('_FORGEPadding')
	if not Padding then
		Padding = Instance.new('UIPadding')
		Padding.Name = '_FORGEPadding'
		Padding.Parent = Root
	end
	Padding:SetAttribute('FORGEStyleInternal', true)

	local Value = math.max(0, tonumber(Root:GetAttribute('FORGEPadding')) or 0)
	Padding.PaddingLeft = UDim.new(0, Value)
	Padding.PaddingRight = UDim.new(0, Value)
	Padding.PaddingTop = UDim.new(0, Value)
	Padding.PaddingBottom = UDim.new(0, Value)

	local Children = {}
	for _, Child in ipairs(Root:GetChildren()) do
		if Child:IsA('GuiObject') and Child:GetAttribute('FORGEStyleInternal') ~= true then
			table.insert(Children, Child)
		end
	end

	if Root:GetAttribute('FORGELayoutOrderInitialized') ~= true then
		for Order, Child in ipairs(Children) do Child.LayoutOrder = Order end
		Root:SetAttribute('FORGELayoutOrderInitialized', true)
	end

	for _, Child in ipairs(Children) do
		Child.Position = UDim2.new()
		Child.AnchorPoint = Vector2.zero
		RaiseTreeZIndex(Child, Root.ZIndex + 1)

		if Kind == 'Row' and Child:GetAttribute('FORGESimpleKind') ~= 'Spacer' then
			local Flex = Child:FindFirstChild('_FORGEFlex')
			if Flex then Flex:Destroy() end
		end
	end
end


local function LegacyAutoAxis(Root, Axis)
	local Value = Root.AutomaticSize
	if Axis == 'X' then return Value == Enum.AutomaticSize.X or Value == Enum.AutomaticSize.XY end
	return Value == Enum.AutomaticSize.Y or Value == Enum.AutomaticSize.XY
end

local function MigrateAutoAxes(Root)
	if not Root or not Root:IsA('GuiObject') then return end

	local Width = Root:GetAttribute('FORGEAutoWidth')
	local Height = Root:GetAttribute('FORGEAutoHeight')
	local Legacy = Root:GetAttribute('FORGEAutoSize')
	local Kind = Root:GetAttribute('FORGELayoutKind')

	if Width == nil then
		Width = Legacy == true and (Kind == 'Row' or Kind == 'Stack') or LegacyAutoAxis(Root, 'X')
		Root:SetAttribute('FORGEAutoWidth', Width == true)
	end

	if Height == nil then
		Height = Legacy == true and (Kind == 'Row' or Kind == 'Stack') or LegacyAutoAxis(Root, 'Y')
		Root:SetAttribute('FORGEAutoHeight', Height == true)
	end

	Root:SetAttribute('FORGEAutoSize', nil)
	Root.AutomaticSize = Enum.AutomaticSize.None
end

local function AutoAxis(Root, Axis)
	MigrateAutoAxes(Root)
	return Root:GetAttribute(Axis == 'X' and 'FORGEAutoWidth' or 'FORGEAutoHeight') == true
end

local function AuthoredScope(Root)
	local Content
	if Root:GetAttribute('FORGESimpleKind') == 'Scroller' then
		Content = Root:FindFirstChild('Content', true)
	else
		Content = Root:FindFirstChild('Content')
	end

	if Content and Content:IsA('GuiObject') and Content:GetAttribute('FORGEInsertionTarget') == true then
		return Content
	end
	return Root
end

local function AuthoredChildren(Root)
	local Result = {}
	local Scope = AuthoredScope(Root)

	for _, Child in ipairs(Scope:GetChildren()) do
		if Child:IsA('GuiObject')
			and Child:GetAttribute('FORGEStyleInternal') ~= true
			and Child:GetAttribute('FORGEHierarchyInternal') ~= true
		then
			table.insert(Result, Child)
		end
	end

	table.sort(Result, function(A, B)
		if A.LayoutOrder == B.LayoutOrder then return A.Name < B.Name end
		return A.LayoutOrder < B.LayoutOrder
	end)
	return Result
end

local function AxisPixels(Value, ParentPixels)
	return math.max(0, Value.Scale * math.max(ParentPixels, 0) + Value.Offset)
end

local function CompAttribute(Axis)
	return Axis == 'X' and 'FORGELayoutCompX' or 'FORGELayoutCompY'
end

local function SemanticAxis(Object, Axis)
	local Value = Axis == 'X' and Object.Size.X or Object.Size.Y
	local Compensation = tonumber(Object:GetAttribute(CompAttribute(Axis))) or 0
	return Value.Scale, Value.Offset - Compensation
end

local function ObjectPixels(Object, ParentWidth, ParentHeight)
	return
		AxisPixels(Object.Size.X, ParentWidth),
		AxisPixels(Object.Size.Y, ParentHeight)
end

local function SemanticPixels(Object, Axis, Basis)
	local Scale, Offset = SemanticAxis(Object, Axis)
	return math.max(0, Scale * math.max(Basis, 0) + Offset)
end

local function SetCompensatedAxis(Object, Axis, Pixels, RawParentPixels)
	local Scale, Offset = SemanticAxis(Object, Axis)
	local ActualOffset = Pixels - Scale * math.max(RawParentPixels, 0)
	local Compensation = ActualOffset - Offset

	if Axis == 'X' then
		Object.Size = UDim2.new(Scale, ActualOffset, Object.Size.Y.Scale, Object.Size.Y.Offset)
	else
		Object.Size = UDim2.new(Object.Size.X.Scale, Object.Size.X.Offset, Scale, ActualOffset)
	end

	if math.abs(Compensation) < .001 then Object:SetAttribute(CompAttribute(Axis), nil)
	else Object:SetAttribute(CompAttribute(Axis), Compensation) end
end

local function ClearCompensation(Object, Axis)
	Object:SetAttribute(CompAttribute(Axis), nil)
end

local function FreezePercentAxis(Child, Axis, Basis)
	local Scale, Offset = SemanticAxis(Child, Axis)
	if math.abs(Scale) < .000001 then return end

	local Pixels = math.max(0, Scale * math.max(Basis, 0) + Offset)
	if Axis == 'X' then
		Child.Size = UDim2.new(0, Pixels, Child.Size.Y.Scale, Child.Size.Y.Offset)
	else
		Child.Size = UDim2.new(Child.Size.X.Scale, Child.Size.X.Offset, 0, Pixels)
	end
	ClearCompensation(Child, Axis)
end

local function SetAxisPixels(Root, Axis, Pixels)
	Pixels = math.max(0, math.floor(Pixels + .5))
	if Axis == 'X' then
		Root.Size = UDim2.new(0, Pixels, Root.Size.Y.Scale, Root.Size.Y.Offset)
	else
		Root.Size = UDim2.new(Root.Size.X.Scale, Root.Size.X.Offset, 0, Pixels)
	end
	ClearCompensation(Root, Axis)
end

local function CurrentParentPixels(Root)
	local Parent = Root.Parent
	if not Parent or not Parent:IsA('GuiObject') then
		return math.max(Root.AbsoluteSize.X, 1), math.max(Root.AbsoluteSize.Y, 1)
	end
	return math.max(Parent.AbsoluteSize.X, 1), math.max(Parent.AbsoluteSize.Y, 1)
end

local ResolveNode

local function ResolveFreeContainer(Root, Width, Height, AutoWidth, AutoHeight)
	local Padding = math.max(0, tonumber(Root:GetAttribute('FORGEPadding')) or 0)
	local Children = AuthoredChildren(Root)
	if #Children == 0 then return Width, Height end

	local InnerWidth = math.max(0, Width - Padding * 2)
	local InnerHeight = math.max(0, Height - Padding * 2)
	local MinX, MinY = 0, 0
	local MaxX, MaxY = 0, 0

	for _, Child in ipairs(Children) do
		if AutoWidth then FreezePercentAxis(Child, 'X', InnerWidth) end
		if AutoHeight then FreezePercentAxis(Child, 'Y', InnerHeight) end

		if not AutoAxis(Child, 'X') then
			SetCompensatedAxis(Child, 'X', SemanticPixels(Child, 'X', InnerWidth), Width)
		end
		if not AutoAxis(Child, 'Y') then
			SetCompensatedAxis(Child, 'Y', SemanticPixels(Child, 'Y', InnerHeight), Height)
		end

		ResolveNode(Child, Width, Height)

		local ChildWidth, ChildHeight = ObjectPixels(Child, Width, Height)
		local X = Child.Position.X.Scale * InnerWidth + Child.Position.X.Offset - Child.AnchorPoint.X * ChildWidth
		local Y = Child.Position.Y.Scale * InnerHeight + Child.Position.Y.Offset - Child.AnchorPoint.Y * ChildHeight
		MinX = math.min(MinX, X)
		MinY = math.min(MinY, Y)
		MaxX = math.max(MaxX, X + ChildWidth)
		MaxY = math.max(MaxY, Y + ChildHeight)
	end

	if AutoWidth then Width = math.max(1, MaxX - math.min(0, MinX) + Padding * 2) end
	if AutoHeight then Height = math.max(1, MaxY - math.min(0, MinY) + Padding * 2) end
	return Width, Height
end

local function MainAxisBasis(Children, Axis, Available, RawParentPixels)
	local FixedSpace = 0

	for _, Child in ipairs(Children) do
		if AutoAxis(Child, Axis) then
			local Value = Axis == 'X' and Child.Size.X or Child.Size.Y
			FixedSpace += AxisPixels(Value, RawParentPixels)
		else
			local _, Offset = SemanticAxis(Child, Axis)
			FixedSpace += Offset
		end
	end

	return math.max(0, Available - FixedSpace)
end

local function ResolveLinearLayout(Root, Kind, Width, Height, AutoWidth, AutoHeight)
	EnsureLayout(Root)

	local Padding = math.max(0, tonumber(Root:GetAttribute('FORGEPadding')) or 0)
	local Gap = math.max(0, tonumber(Root:GetAttribute('FORGEGap')) or 0)
	local Children = AuthoredChildren(Root)
	local GapTotal = math.max(#Children - 1, 0) * Gap

	local InnerWidth = math.max(0, Width - Padding * 2)
	local InnerHeight = math.max(0, Height - Padding * 2)
	local MainAvailable = Kind == 'Row'
		and math.max(0, InnerWidth - GapTotal)
		or math.max(0, InnerHeight - GapTotal)
	local MainAxis = Kind == 'Row' and 'X' or 'Y'
	local CrossAxis = Kind == 'Row' and 'Y' or 'X'
	local MainAuto = Kind == 'Row' and AutoWidth or AutoHeight
	local CrossAuto = Kind == 'Row' and AutoHeight or AutoWidth
	local RawMainPixels = Kind == 'Row' and Width or Height
	local CrossBasis = Kind == 'Row' and InnerHeight or InnerWidth

	for _, Child in ipairs(Children) do
		if AutoAxis(Child, MainAxis) then ResolveNode(Child, Width, Height) end
	end

	local MainBasis = MainAxisBasis(Children, MainAxis, MainAvailable, RawMainPixels)

	if MainAuto then
		for _, Child in ipairs(Children) do FreezePercentAxis(Child, MainAxis, MainBasis) end
		MainBasis = MainAxisBasis(Children, MainAxis, MainAvailable, RawMainPixels)
	end
	if CrossAuto then
		for _, Child in ipairs(Children) do FreezePercentAxis(Child, CrossAxis, CrossBasis) end
	end

	local TotalMain = 0
	local MaxCross = 0

	for _, Child in ipairs(Children) do
		if Kind == 'Row' then
			if not AutoAxis(Child, 'X') then
				SetCompensatedAxis(Child, 'X', SemanticPixels(Child, 'X', MainBasis), Width)
			end
			if not AutoAxis(Child, 'Y') then
				SetCompensatedAxis(Child, 'Y', SemanticPixels(Child, 'Y', CrossBasis), Height)
			end
		else
			if not AutoAxis(Child, 'X') then
				SetCompensatedAxis(Child, 'X', SemanticPixels(Child, 'X', CrossBasis), Width)
			end
			if not AutoAxis(Child, 'Y') then
				SetCompensatedAxis(Child, 'Y', SemanticPixels(Child, 'Y', MainBasis), Height)
			end
		end

		ResolveNode(Child, Width, Height)
		local ChildWidth, ChildHeight = ObjectPixels(Child, Width, Height)

		if Kind == 'Row' then
			TotalMain += ChildWidth
			MaxCross = math.max(MaxCross, ChildHeight)
		else
			TotalMain += ChildHeight
			MaxCross = math.max(MaxCross, ChildWidth)
		end
	end

	if #Children > 1 then TotalMain += GapTotal end

	if Kind == 'Row' then
		if AutoWidth then Width = math.max(1, TotalMain + Padding * 2) end
		if AutoHeight then Height = math.max(1, MaxCross + Padding * 2) end
	else
		if AutoWidth then Width = math.max(1, MaxCross + Padding * 2) end
		if AutoHeight then Height = math.max(1, TotalMain + Padding * 2) end
	end

	return Width, Height
end

ResolveNode = function(Root, ParentWidth, ParentHeight)
	if not Root or not Root:IsA('GuiObject') then return 0, 0 end

	MigrateAutoAxes(Root)
	local Width, Height = ObjectPixels(Root, ParentWidth, ParentHeight)
	Width = math.max(Width, 1)
	Height = math.max(Height, 1)

	local AutoWidth = AutoAxis(Root, 'X')
	local AutoHeight = AutoAxis(Root, 'Y')
	local Kind = Root:GetAttribute('FORGELayoutKind')

	if Kind == 'Row' or Kind == 'Stack' then
		Width, Height = ResolveLinearLayout(Root, Kind, Width, Height, AutoWidth, AutoHeight)
	elseif AutoWidth or AutoHeight then
		Width, Height = ResolveFreeContainer(Root, Width, Height, AutoWidth, AutoHeight)
	else
		for _, Child in ipairs(AuthoredChildren(Root)) do ResolveNode(Child, Width, Height) end
	end

	if AutoWidth then SetAxisPixels(Root, 'X', Width) end
	if AutoHeight then SetAxisPixels(Root, 'Y', Height) end
	return Width, Height
end

local function NeedsManagedLayout(Root)
	local Cached = Root:GetAttribute('FORGEManagedLayoutTree')
	if Cached ~= nil then return Cached == true end

	local function Managed(Object)
		if not Object:IsA('GuiObject') then return false end
		local Kind = Object:GetAttribute('FORGELayoutKind')
		if Kind == 'Row' or Kind == 'Stack' then return true end
		if Object:GetAttribute('FORGEAutoWidth') == true or Object:GetAttribute('FORGEAutoHeight') == true then return true end
		if Object:GetAttribute('FORGEAutoSize') == true then return true end
		return Object.AutomaticSize ~= Enum.AutomaticSize.None
	end

	local Result = Managed(Root)
	if not Result then
		for _, Descendant in ipairs(Root:GetDescendants()) do
			if Managed(Descendant) then
				Result = true
				break
			end
		end
	end

	Root:SetAttribute('FORGEManagedLayoutTree', Result)
	return Result
end

function Presets:ResolveLayouts(Root, ParentSize)
	if not Root or not Root:IsA('GuiObject') then return false end
	if not NeedsManagedLayout(Root) then return true end

	local ParentWidth, ParentHeight
	if typeof(ParentSize) == 'Vector2' then
		ParentWidth, ParentHeight = math.max(ParentSize.X, 1), math.max(ParentSize.Y, 1)
	else
		ParentWidth, ParentHeight = CurrentParentPixels(Root)
	end

	ResolveNode(Root, ParentWidth, ParentHeight)
	ResolveNode(Root, ParentWidth, ParentHeight)
	return true
end

local function EnsureSurfaceInternals(Root)
	local SurfaceName = Root:GetAttribute('FORGEStyleSurface')
	local InsetEnabled = Root:GetAttribute('FORGEInsetEnabled') ~= false
	if SurfaceName then
		local Material = Root:FindFirstChild('_FORGEMaterial')
		local Inset = Root:FindFirstChild('_FORGEInset')
		local Shadow = Root:FindFirstChild('_FORGEShadow')
		if not Material or (InsetEnabled and not Inset) or not Shadow then
			StylePacks:ApplySurface(Root, SurfaceName, Root:GetAttribute('FORGEStylePack') or 'RUCKUS')
		end
	end

	local Inset = Root:FindFirstChild('_FORGEInset')
	if not InsetEnabled then
		if Inset then Inset:Destroy() end
		Inset = nil
	end

	local Pixels = math.max(0, math.floor((tonumber(Root:GetAttribute('FORGEInsetPixels')) or 2) + .5))
	if Inset and Inset:IsA('GuiObject') then
		Inset.Position = UDim2.fromOffset(Pixels, Pixels)
		Inset.Size = UDim2.new(1, -Pixels * 2, 1, -Pixels * 2)
		Inset:SetAttribute('FORGEFixedPixelGeometry', nil)
	end

	local StrokeThickness = math.max(0, tonumber(Root:GetAttribute('FORGEStrokeThickness')) or Pack().Metric.Stroke or 1)
	for _, Descendant in ipairs(Root:GetDescendants()) do
		if Descendant:IsA('UIStroke') and Descendant:GetAttribute('FORGEAnimationIgnoreStroke') ~= true then
			Descendant.Thickness = StrokeThickness
		end
	end

	local Material = Root:FindFirstChild('_FORGEMaterial')
	local Satin = Material and Material:FindFirstChild('_FORGESatin')
	if Satin and Satin:IsA('GuiObject') then
		Satin.Visible = Root:GetAttribute('FORGESatinVisible') ~= false
	end

	local Shadow = Root:FindFirstChild('_FORGEShadow')
	if Shadow then
		SafeSet(Shadow, 'Enabled', Root:GetAttribute('FORGEShadowVisible') ~= false)
		SafeSet(Shadow, 'Color', Root:GetAttribute('FORGEShadowColor') or Color3.new(0, 0, 0))
		SafeSet(Shadow, 'Transparency', 1 - math.clamp(tonumber(Root:GetAttribute('FORGEShadowOpacity')) or .5, 0, 1))
		SafeSet(Shadow, 'BlurRadius', UDim.new(0, math.max(0, tonumber(Root:GetAttribute('FORGEShadowBlur')) or 20)))
	end
end

local function EnsureBar(Root)
	local Kind = Root:GetAttribute('FORGESimpleKind')
	if Kind ~= 'Slider' and Kind ~= 'ProgressBar' then return end

	local P = Pack()
	Root.BackgroundTransparency = 1
	Root.BorderSizePixel = 0
	Root.ClipsDescendants = false

	local Track = Root:FindFirstChild('Track')
	if not Track or not Track:IsA('Frame') then
		Track = Instance.new('Frame')
		Track.Name = 'Track'
		Track.Parent = Root
	end

	Track:SetAttribute('FORGEStyleInternal', true)
	Track.AnchorPoint = Vector2.new(.5, .5)
	Track.Position = UDim2.fromScale(.5, .5)
	Track.Size = UDim2.new(1, 0, 0, P.Metric.BarHeight)
	Track.BackgroundTransparency = 1
	Track.BorderSizePixel = 0
	Track.ClipsDescendants = false
	Track.ZIndex = Root.ZIndex + 4

	local Stroke = Track:FindFirstChild('Stroke')
	if not Stroke or not Stroke:IsA('UIStroke') then
		if Stroke then Stroke:Destroy() end
		Stroke = Instance.new('UIStroke')
		Stroke.Name = 'Stroke'
		Stroke.Parent = Track
	end
	Stroke.LineJoinMode = Enum.LineJoinMode.Miter
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Stroke.Thickness = P.Metric.Stroke
	Stroke:SetAttribute('FORGEInheritSecondary', true)

	local Inset = Track:FindFirstChild('Inset')
	if not Inset or not Inset:IsA('Frame') then
		if Inset then Inset:Destroy() end
		Inset = Instance.new('Frame')
		Inset.Name = 'Inset'
		Inset.Parent = Track
	end
	local InsetPixels = math.max(0, math.floor((tonumber(Root:GetAttribute('FORGEInsetPixels')) or P.Metric.BarInset or 2) + .5))
	Inset.BackgroundTransparency = 1
	Inset.BorderSizePixel = 0
	Inset.Position = UDim2.fromOffset(InsetPixels, InsetPixels)
	Inset.Size = UDim2.new(1, -InsetPixels * 2, 1, -InsetPixels * 2)
	Inset.ClipsDescendants = false
	Inset.ZIndex = Track.ZIndex + 1
	Inset:SetAttribute('FORGEFixedPixelGeometry', nil)

	local Fill = Root:FindFirstChild('Fill', true)
	if not Fill or not Fill:IsA('Frame') then
		Fill = Instance.new('Frame')
		Fill.Name = 'Fill'
	end
	Fill.Parent = Inset
	Fill.Position = UDim2.new()
	Fill.BorderSizePixel = 0
	Fill.ZIndex = Inset.ZIndex + 1

	local Glow = Fill:FindFirstChild('Glow')
	if not Glow or not Glow:IsA('UIShadow') then
		if Glow then Glow:Destroy() end
		Glow = Instance.new('UIShadow')
		Glow.Name = 'Glow'
		Glow.Parent = Fill
	end
	Glow.Transparency = P.Effect.BarGlow.Transparency
	Glow.BlurRadius = P.Effect.BarGlow.BlurRadius

	local Handle = Track:FindFirstChild('Handle')
	if Handle then Handle:Destroy() end
end

local function ApplySecondary(Root, Secondary)
	for _, Object in ipairs(Root:GetDescendants()) do
		if Object:GetAttribute('FORGEIgnoreSecondary') == true then
			continue
		end

		if Object:IsA('TextLabel') or Object:IsA('TextButton') or Object:IsA('TextBox') then
			Object.TextColor3 = Secondary
		elseif Object:IsA('UIStroke') then
			Object.Color = Secondary
			local Gradient = Object:FindFirstChildWhichIsA('UIGradient')
			if Gradient then Gradient.Color = ColorSequence.new(Secondary) end
		elseif Object:IsA('Frame') and Object:GetAttribute('FORGEInheritSecondary') == true then
			Object.BackgroundColor3 = Secondary
		elseif (Object:IsA('ImageLabel') or Object:IsA('ImageButton'))
			and Object:GetAttribute('FORGEInheritSecondary') == true then
			Object.ImageColor3 = Secondary
		end
	end
end

local function ApplyPrimary(Root, Primary)
	local Material = Root:FindFirstChild('_FORGEMaterial')
	local Satin = Material and Material:FindFirstChild('_FORGESatin')
	if Satin and Satin:IsA('ImageLabel') then Satin.ImageColor3 = Primary end
	local BaseGradient = Root:FindFirstChild('_FORGEBaseGradient')
	if BaseGradient and BaseGradient:IsA('UIGradient') then
		BaseGradient.Color = ColorSequence.new(Primary)
	end

	local Kind = Root:GetAttribute('FORGESimpleKind')
	if Kind ~= 'Header'
		and Kind ~= 'Subtext'
		and Kind ~= 'Slider'
		and Kind ~= 'ProgressBar'
		and Kind ~= 'VerticalDivider'
		and Kind ~= 'HorizontalDivider'
		and Root:GetAttribute('FORGELayoutKind') == nil
	then
		Root.BackgroundColor3 = Primary
	end

	local Fill = Root:FindFirstChild('Fill', true)
	if Fill and Fill:IsA('Frame') then
		Fill.BackgroundColor3 = Primary
		local Glow = Fill:FindFirstChild('Glow')
		if Glow and Glow:IsA('UIShadow') then Glow.Color = Primary end
	end
	local Handle = Root:FindFirstChild('Handle', true)
	if Handle and Handle:IsA('Frame') then Handle.BackgroundColor3 = Primary end
end

local function UpdateValue(Root)
	local Kind = Root:GetAttribute('FORGESimpleKind')
	local Value = math.clamp(tonumber(Root:GetAttribute('FORGEValue')) or 0, 0, 1)

	if Kind == 'Slider' or Kind == 'ProgressBar' then
		local Fill = Root:FindFirstChild('Fill', true)
		if Fill then Fill.Size = UDim2.new(Value, 0, 1, 0) end
	end
end

local function SplitItems(Value)
	local Items = {}
	for Item in tostring(Value or ''):gmatch('[^,]+') do
		Item = Item:match('^%s*(.-)%s*$')
		if Item ~= '' then table.insert(Items, Item) end
	end
	return Items
end

local function RebuildSelector(Root)
	local Options = SplitItems(Root:GetAttribute('FORGEItems') or 'OPTION 01, OPTION 02, OPTION 03')
	if #Options == 0 then Options = {'OPTION'} end
	local Index = math.clamp(math.floor(tonumber(Root:GetAttribute('FORGESelectedIndex')) or 1), 1, #Options)
	Root:SetAttribute('FORGESelectedIndex', Index)
	local Label = Root:FindFirstChild('Label')
	if Label then Label.Text = Options[Index] end
end

local function RebuildNavbar(Root)
	local Content = Root:FindFirstChild('Content')
	if not Content then return end

	for _, Child in ipairs(Content:GetChildren()) do
		if Child:IsA('GuiButton') then Child:Destroy() end
	end

	local Items = SplitItems(Root:GetAttribute('FORGEItems') or 'PLAY, PARTY, LOCKER')
	if #Items == 0 then Items = {'ITEM'} end
	local Selected = math.clamp(math.floor(tonumber(Root:GetAttribute('FORGESelectedIndex')) or 1), 1, #Items)
	Root:SetAttribute('FORGESelectedIndex', Selected)

	for Index, Name in ipairs(Items) do
		local Button = Instance.new('TextButton')
		Button.Name = 'Item' .. Index
		Button.AutoButtonColor = false
		Button.BackgroundTransparency = 1
		Button.BorderSizePixel = 0
		Button.Text = Name
		Button.TextXAlignment = Enum.TextXAlignment.Center
		Button.LayoutOrder = Index
		Button.Size = UDim2.new(1 / #Items, 0, 1, 0)
		Button:SetAttribute('FORGEInheritSecondary', true)
		Button.Parent = Content
		StylePacks:ApplyTypography(Button, Index == Selected and 'Strong' or 'Body', 'RUCKUS')

		if Index == Selected then
			local Line = Instance.new('Frame')
			Line.Name = 'Selected'
			Line.BorderSizePixel = 0
			Line.AnchorPoint = Vector2.new(.5, 1)
			Line.Position = UDim2.new(.5, 0, 1, -2)
			Line.Size = UDim2.new(.65, 0, 0, 2)
			Line:SetAttribute('FORGEInheritSecondary', true)
			Line.Parent = Button
		end
	end
end

local function ApplyTextControls(Root)
	local Role = Root:GetAttribute('FORGETextRole')
	if not Role then return end

	local Label = Root:FindFirstChild('Label')
	local Shadow = Root:FindFirstChild('Shadow')
	local PackData = Pack()
	local Weight = Enum.FontWeight[Root:GetAttribute('FORGETextWeight') or 'Regular'] or Enum.FontWeight.Regular
	local FontStyle = Enum.FontStyle[Root:GetAttribute('FORGETextStyle') or 'Normal'] or Enum.FontStyle.Normal
	local XAlignment = Enum.TextXAlignment[Root:GetAttribute('FORGETextXAlignment') or 'Left'] or Enum.TextXAlignment.Left
	local YAlignment = Enum.TextYAlignment[Root:GetAttribute('FORGETextYAlignment') or 'Center'] or Enum.TextYAlignment.Center
	local Size = math.max(1, tonumber(Root:GetAttribute('FORGETextSize')) or 14)
	local Transparency = math.clamp(tonumber(Root:GetAttribute('FORGETextTransparency')) or 0, 0, 1)
	local Wrapped = Root:GetAttribute('FORGETextWrapped') == true
	local Scaled = Root:GetAttribute('FORGETextScaled') == true
	local RichText = Root:GetAttribute('FORGERichText') == true
	local LineHeight = math.max(.1, tonumber(Root:GetAttribute('FORGELineHeight')) or 1)
	local StrokeColor = Root:GetAttribute('FORGETextStrokeColor') or Color3.new(0, 0, 0)
	local StrokeTransparency = 1 - math.clamp(tonumber(Root:GetAttribute('FORGETextStrokeOpacity')) or 0, 0, 1)

	local function Apply(Object)
		if not Object or not (Object:IsA('TextLabel') or Object:IsA('TextButton') or Object:IsA('TextBox')) then return end
		StylePacks:ApplyTypography(Object, Role, 'RUCKUS')
		SafeSet(Object, 'FontFace', Font.new(PackData.Asset.Rubik, Weight, FontStyle))
		Object.TextSize = Size
		Object.TextXAlignment = XAlignment
		Object.TextYAlignment = YAlignment
		Object.TextWrapped = Wrapped
		Object.TextScaled = Scaled
		Object.RichText = RichText
		Object.LineHeight = LineHeight
		Object.TextStrokeColor3 = StrokeColor
		Object.TextStrokeTransparency = StrokeTransparency
	end

	Apply(Label)
	Apply(Shadow)
	if Label then Label.TextTransparency = Transparency end
	if Shadow and Shadow:IsA('TextLabel') then
		Shadow.Position = UDim2.fromOffset(
			tonumber(Root:GetAttribute('FORGEShadowOffsetX')) or 1,
			tonumber(Root:GetAttribute('FORGEShadowOffsetY')) or 1
		)
	end
end

local ScrollerBindings = setmetatable({}, {__mode = 'k'})

local function ScrollerOwner(Object)
	local Current = Object
	while Current and Current:IsA('GuiObject') do
		local Kind = Current:GetAttribute('FORGESimpleKind')
		if Kind then return Kind == 'Scroller' and Current or nil end
		Current = Current.Parent
	end
	return nil
end

local function ScrollerNodes(Root)
	local Viewport = Root:FindFirstChild('Viewport')
	local Scroll = Viewport and Viewport:FindFirstChild('Scroll')
	local Content = Scroll and Scroll:FindFirstChild('Content')
	local Track = Root:FindFirstChild('_FORGEScrollBar')
	local Inset = Track and Track:FindFirstChild('Inset')
	local Fill = Inset and Inset:FindFirstChild('Fill')
	return Viewport, Scroll, Content, Track, Inset, Fill
end

local function EffectiveUIScale(Object)
	local Scale = 1
	local Current = Object
	while Current do
		if Current:IsA('GuiObject') then
			for _, Child in ipairs(Current:GetChildren()) do
				if Child:IsA('UIScale') then Scale *= Child.Scale end
			end
		end
		Current = Current.Parent
	end
	return math.max(Scale, .001)
end

local function ScrollerItemHeight(Root, Child)
	local Axis = Child.Size.Y
	local Stored = tonumber(Child:GetAttribute('FORGEScrollerItemHeight'))
	local Scale = EffectiveUIScale(Root)
	local LogicalRootHeight = math.max(Root.AbsoluteSize.Y / Scale, Root.Size.Y.Offset, 1)
	local Height

	if math.abs(Axis.Scale) < .000001 and Axis.Offset > 0 then
		Height = Axis.Offset
	elseif Axis.Scale > 2 and math.abs(Axis.Offset) < 1 then
		Height = Axis.Scale
	else
		Height = LogicalRootHeight * Axis.Scale + Axis.Offset
	end

	if Height <= 0 and Stored and Stored > 0 then Height = Stored end
	if Height <= 0 and Child.AbsoluteSize.Y > 0 then
		Height = Child.AbsoluteSize.Y / EffectiveUIScale(Child)
	end
	Height = math.max(1, math.floor(Height + .5))

	if Stored ~= Height then Child:SetAttribute('FORGEScrollerItemHeight', Height) end
	return Height
end

local function ApplyScrollerItemGeometry(Root, Child, Height, Order)
	Height = math.max(1, math.floor((tonumber(Height) or ScrollerItemHeight(Root, Child)) + .5))
	if Child:GetAttribute('FORGEScrollerItemHeight') ~= Height then
		Child:SetAttribute('FORGEScrollerItemHeight', Height)
	end
	Child.AnchorPoint = Vector2.zero
	Child.Position = UDim2.new()
	if Order then Child.LayoutOrder = Order end
	Child.Size = UDim2.new(1, 0, 0, Height)
	Child:SetAttribute('FORGESizeModeX', '%')
	Child:SetAttribute('FORGESizeModeY', 'px')
	RaiseTreeZIndex(Child, Root.ZIndex + 5)
	return Height
end

local function NormalizeScrollerItems(Root)
	local Content = AuthoredScope(Root)
	if not Content or not Content:IsA('GuiObject') then return end

	for Order, Child in ipairs(AuthoredChildren(Root)) do
		ApplyScrollerItemGeometry(Root, Child, nil, Order)
	end
end

local function ScrollerContentHeight(Root)
	local Children = AuthoredChildren(Root)
	local Height = 0

	for _, Child in ipairs(Children) do
		Height += ScrollerItemHeight(Root, Child)
	end

	local Gap = math.max(0, tonumber(Root:GetAttribute('FORGEGap')) or 0)
	local Padding = math.max(0, tonumber(Root:GetAttribute('FORGEPadding')) or 0)
	if #Children > 1 then Height += Gap * (#Children - 1) end
	return math.max(0, Height + Padding * 2)
end

local function ScrollerMetrics(Root)
	local _, Scroll, Content, Track, Inset, Fill = ScrollerNodes(Root)
	if not Scroll or not Content or not Track or not Inset or not Fill then return nil end

	local Scale = EffectiveUIScale(Scroll)
	local Viewport = Scroll.AbsoluteWindowSize.Y / Scale
	if Viewport <= 0 then Viewport = Scroll.AbsoluteSize.Y / Scale end
	Viewport = math.max(Viewport, 1)

	local ContentHeight = ScrollerContentHeight(Root)
	local DesiredCanvas = math.max(math.floor(ContentHeight + .5), 0)
	if Scroll.CanvasSize.Y.Scale ~= 0 or math.abs(Scroll.CanvasSize.Y.Offset - DesiredCanvas) > .5 then
		Scroll.CanvasSize = UDim2.fromOffset(0, DesiredCanvas)
	end

	local Canvas = math.max(ContentHeight, Viewport)
	local Inner = math.max(Inset.AbsoluteSize.Y / Scale, 0)
	if Inner <= 0 then
		local Pixels = math.max(0, tonumber(Root:GetAttribute('FORGEScrollBarInset')) or 2)
		Inner = math.max(Track.AbsoluteSize.Y / Scale - Pixels * 2, 0)
	end

	local Ratio = Canvas > 0 and math.clamp(Viewport / Canvas, 0, 1) or 1
	local MinThumb = math.min(math.max(tonumber(Root:GetAttribute('FORGEScrollBarMinThumb')) or 18, 1), Inner)
	local ThumbHeight = math.clamp(Inner * Ratio, MinThumb, Inner)
	if ContentHeight <= Viewport + 1 then ThumbHeight = Inner end

	return {
		Scroll = Scroll,
		Track = Track,
		Fill = Fill,
		Viewport = Viewport,
		Content = ContentHeight,
		Inner = Inner,
		Thumb = ThumbHeight,
		Travel = math.max(Inner - ThumbHeight, 0),
		MaxCanvas = math.max(ContentHeight - Viewport, 0)
	}
end

local function RefreshScrollerBar(Root, OverrideY)
	local Metrics = ScrollerMetrics(Root)
	if not Metrics then return nil end

	local CanvasY = OverrideY
	if CanvasY == nil then CanvasY = Metrics.Scroll.CanvasPosition.Y end
	CanvasY = math.clamp(CanvasY, 0, Metrics.MaxCanvas)

	local Alpha = Metrics.MaxCanvas > 0 and CanvasY / Metrics.MaxCanvas or 0
	Metrics.Track.Visible = true
	Metrics.Fill.AnchorPoint = Vector2.zero
	Metrics.Fill.Position = UDim2.fromOffset(0, math.floor(Metrics.Travel * Alpha + .5))
	Metrics.Fill.Size = UDim2.new(1, 0, 0, math.max(math.floor(Metrics.Thumb + .5), 0))
	return Metrics
end

local function DisconnectScrollerBinding(Root)
	local Current = ScrollerBindings[Root]
	if not Current then return end
	ScrollerBindings[Root] = nil
	for _, Connection in ipairs(Current.Connections or {}) do
		if Connection.Connected then Connection:Disconnect() end
	end
end

local function BindScroller(Root)
	local _, Scroll, Content = ScrollerNodes(Root)
	if not Scroll or not Content then return end

	local Current = ScrollerBindings[Root]
	if Current and Current.Scroll == Scroll and Current.Content == Content then return end
	if Current then DisconnectScrollerBinding(Root) end

	local Binding = {
		Scroll = Scroll,
		Content = Content,
		Connections = {}
	}
	ScrollerBindings[Root] = Binding

	local function Refresh()
		if Binding.RefreshQueued then return end
		Binding.RefreshQueued = true
		task.defer(function()
			Binding.RefreshQueued = false
			if Root.Parent then RefreshScrollerBar(Root) end
		end)
	end

	local Layout = Content:FindFirstChild('_FORGELayout')
	local Bin = Binding.Connections

	table.insert(Bin, Scroll:GetPropertyChangedSignal('CanvasPosition'):Connect(Refresh))
	table.insert(Bin, Scroll:GetPropertyChangedSignal('AbsoluteWindowSize'):Connect(Refresh))
	table.insert(Bin, Scroll:GetPropertyChangedSignal('AbsoluteSize'):Connect(Refresh))
	table.insert(Bin, Content:GetPropertyChangedSignal('AbsoluteSize'):Connect(Refresh))
	if Layout and Layout:IsA('UIListLayout') then
		table.insert(Bin, Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(Refresh))
	end
	table.insert(Bin, Root.Destroying:Connect(function()
		DisconnectScrollerBinding(Root)
	end))
end

local function EnsureScroller(Root)
	if Root:GetAttribute('FORGESimpleKind') ~= 'Scroller' then return end

	local P = Pack()
	local Width = math.max(4, math.floor((tonumber(Root:GetAttribute('FORGEScrollBarWidth')) or P.Metric.BarHeight or 10) + .5))
	local Gap = math.max(0, math.floor((tonumber(Root:GetAttribute('FORGEScrollBarGap')) or 6) + .5))
	local InsetPixels = math.max(0, math.floor((tonumber(Root:GetAttribute('FORGEScrollBarInset')) or P.Metric.BarInset or 2) + .5))
	local EdgeInset = math.max(0, math.floor((tonumber(Root:GetAttribute('FORGEScrollBarEdgeInset')) or P.Metric.Inset or 3) + .5))
	local CanvasInset = math.max(0, math.floor((tonumber(Root:GetAttribute('FORGEScrollCanvasInset')) or 2) + .5))
	local CanvasTopInset = math.max(0, math.floor((tonumber(Root:GetAttribute('FORGEScrollCanvasTopInset')) or 1) + .5))
	local BarVerticalInset = math.max(0, math.floor((tonumber(Root:GetAttribute('FORGEScrollBarVerticalInset')) or 3) + .5))
	local MinThumb = math.max(1, math.floor((tonumber(Root:GetAttribute('FORGEScrollBarMinThumb')) or 18) + .5))
	local Secondary = Root:GetAttribute('FORGESecondaryColor') or P.Color.Text

	Root:SetAttribute('FORGEScrollBarWidth', Width)
	Root:SetAttribute('FORGEScrollBarGap', Gap)
	Root:SetAttribute('FORGEScrollBarInset', InsetPixels)
	Root:SetAttribute('FORGEScrollBarEdgeInset', EdgeInset)
	Root:SetAttribute('FORGEScrollCanvasInset', CanvasInset)
	Root:SetAttribute('FORGEScrollCanvasTopInset', CanvasTopInset)
	Root:SetAttribute('FORGEScrollBarVerticalInset', BarVerticalInset)
	Root:SetAttribute('FORGEScrollBarMinThumb', MinThumb)
	Root.ClipsDescendants = false

	if Root:IsA('ScrollingFrame') then
		Root.CanvasPosition = Vector2.zero
		Root.CanvasSize = UDim2.new()
		Root.AutomaticCanvasSize = Enum.AutomaticSize.None
		Root.ScrollBarThickness = 0
		Root.ScrollBarImageTransparency = 1
		Root.ScrollingEnabled = false
		Root.Active = false
	end

	local ExistingContent = Root:FindFirstChild('Content', true)
	local Viewport = Root:FindFirstChild('Viewport')
	if not Viewport or not Viewport:IsA('Frame') then
		if Viewport then Viewport:Destroy() end
		Viewport = Instance.new('Frame')
		Viewport.Name = 'Viewport'
		Viewport.Parent = Root
	end

	Viewport:SetAttribute('FORGEStyleInternal', true)
	Viewport:SetAttribute('FORGEHierarchyInternal', true)
	Viewport:SetAttribute('FORGEFixedPixelGeometry', true)
	Viewport.BackgroundTransparency = 1
	Viewport.BorderSizePixel = 0
	Viewport.Position = UDim2.fromOffset(
		EdgeInset + CanvasInset,
		EdgeInset + CanvasInset + CanvasTopInset
	)
	Viewport.Size = UDim2.new(
		1,
		-(Width + Gap + EdgeInset * 2 + CanvasInset * 2),
		1,
		-(EdgeInset * 2 + CanvasInset * 2 + CanvasTopInset)
	)
	Viewport.ClipsDescendants = true
	Viewport.Active = false
	Viewport.ZIndex = Root.ZIndex + 4

	local Scroll = Viewport:FindFirstChild('Scroll')
	if not Scroll or not Scroll:IsA('ScrollingFrame') then
		if Scroll then Scroll:Destroy() end
		Scroll = Instance.new('ScrollingFrame')
		Scroll.Name = 'Scroll'
		Scroll.Parent = Viewport
	end

	Scroll:SetAttribute('FORGEStyleInternal', true)
	Scroll:SetAttribute('FORGEHierarchyInternal', true)
	Scroll.BackgroundTransparency = 1
	Scroll.BorderSizePixel = 0
	Scroll.Position = UDim2.new()
	Scroll.Size = UDim2.fromScale(1, 1)
	Scroll.CanvasSize = UDim2.new()
	Scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	Scroll.ScrollBarThickness = 0
	Scroll.ScrollBarImageTransparency = 1
	Scroll.VerticalScrollBarInset = Enum.ScrollBarInset.None
	Scroll.ScrollingEnabled = true
	Scroll.Active = true
	pcall(function() Scroll.Interactable = true end)
	Scroll.ClipsDescendants = false
	Scroll.ZIndex = Viewport.ZIndex

	local Content = Scroll:FindFirstChild('Content')
	if not Content and ExistingContent and ExistingContent ~= Scroll and not ExistingContent:IsDescendantOf(Scroll) then
		Content = ExistingContent
		Content.Parent = Scroll
	end
	if not Content or not Content:IsA('Frame') then
		if Content then Content:Destroy() end
		Content = Instance.new('Frame')
		Content.Name = 'Content'
		Content.Parent = Scroll
	end

	Content:SetAttribute('FORGEInsertionTarget', true)
	Content:SetAttribute('FORGEHierarchyInternal', true)
	Content.BackgroundTransparency = 1
	Content.BorderSizePixel = 0
	Content.Position = UDim2.new()
	Content.Size = UDim2.new(1, 0, 0, 0)
	Content.AutomaticSize = Enum.AutomaticSize.Y
	Content.ZIndex = Scroll.ZIndex

	local Layout = Content:FindFirstChild('_FORGELayout')
	if not Layout or not Layout:IsA('UIListLayout') then
		if Layout then Layout:Destroy() end
		Layout = Instance.new('UIListLayout')
		Layout.Name = '_FORGELayout'
		Layout.Parent = Content
	end
	Layout:SetAttribute('FORGEStyleInternal', true)
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.Padding = UDim.new(0, math.max(0, tonumber(Root:GetAttribute('FORGEGap')) or 0))

	local Padding = Content:FindFirstChild('_FORGEPadding')
	if not Padding or not Padding:IsA('UIPadding') then
		if Padding then Padding:Destroy() end
		Padding = Instance.new('UIPadding')
		Padding.Name = '_FORGEPadding'
		Padding.Parent = Content
	end
	Padding:SetAttribute('FORGEStyleInternal', true)
	local PaddingValue = math.max(0, tonumber(Root:GetAttribute('FORGEPadding')) or 0)
	Padding.PaddingLeft = UDim.new(0, PaddingValue)
	Padding.PaddingRight = UDim.new(0, PaddingValue)
	Padding.PaddingTop = UDim.new(0, PaddingValue)
	Padding.PaddingBottom = UDim.new(0, PaddingValue)

	local Track = Root:FindFirstChild('_FORGEScrollBar', true)
	if not Track or not Track:IsA('Frame') then
		if Track then Track:Destroy() end
		Track = Instance.new('Frame')
		Track.Name = '_FORGEScrollBar'
	end
	Track.Parent = Root
	Track:SetAttribute('FORGEStyleInternal', true)
	Track:SetAttribute('FORGEHierarchyInternal', true)
	Track:SetAttribute('FORGEFixedPixelGeometry', true)
	Track.AnchorPoint = Vector2.new(1, 0)
	Track.Position = UDim2.new(
		1,
		-(EdgeInset + CanvasInset),
		0,
		EdgeInset + BarVerticalInset
	)
	Track.Size = UDim2.new(
		0,
		Width,
		1,
		-(EdgeInset * 2 + BarVerticalInset * 2)
	)
	Track.BackgroundTransparency = 1
	Track.BorderSizePixel = 0
	Track.ClipsDescendants = false
	Track.Active = false
	Track.Visible = true
	Track.ZIndex = Root.ZIndex + 8

	local Stroke = Track:FindFirstChild('Stroke')
	if not Stroke or not Stroke:IsA('UIStroke') then
		if Stroke then Stroke:Destroy() end
		Stroke = Instance.new('UIStroke')
		Stroke.Name = 'Stroke'
		Stroke.Parent = Track
	end
	Stroke.LineJoinMode = Enum.LineJoinMode.Miter
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Stroke.Thickness = tonumber(Root:GetAttribute('FORGEStrokeThickness')) or P.Metric.Stroke or 1
	Stroke.Color = Secondary
	Stroke:SetAttribute('FORGEInheritSecondary', true)

	local Inset = Track:FindFirstChild('Inset')
	if not Inset or not Inset:IsA('Frame') then
		if Inset then Inset:Destroy() end
		Inset = Instance.new('Frame')
		Inset.Name = 'Inset'
		Inset.Parent = Track
	end
	Inset:SetAttribute('FORGEStyleInternal', true)
	Inset:SetAttribute('FORGEHierarchyInternal', true)
	Inset:SetAttribute('FORGEFixedPixelGeometry', nil)
	Inset.Position = UDim2.fromOffset(InsetPixels, InsetPixels)
	Inset.Size = UDim2.new(1, -InsetPixels * 2, 1, -InsetPixels * 2)
	Inset.BackgroundTransparency = 1
	Inset.BorderSizePixel = 0
	Inset.ClipsDescendants = true
	Inset.ZIndex = Track.ZIndex + 1

	local Fill = Inset:FindFirstChild('Fill')
	if not Fill or not Fill:IsA('Frame') then
		if Fill then Fill:Destroy() end
		Fill = Instance.new('Frame')
		Fill.Name = 'Fill'
		Fill.Parent = Inset
	end
	Fill:SetAttribute('FORGEStyleInternal', true)
	Fill:SetAttribute('FORGEHierarchyInternal', true)
	Fill:SetAttribute('FORGEFixedPixelGeometry', true)
	Fill:SetAttribute('FORGEInheritSecondary', true)
	Fill.BackgroundColor3 = Secondary
	Fill.BorderSizePixel = 0
	Fill.ZIndex = Inset.ZIndex + 1

	local Glow = Fill:FindFirstChild('Glow')
	if not Glow or not Glow:IsA('UIShadow') then
		if Glow then Glow:Destroy() end
		Glow = Instance.new('UIShadow')
		Glow.Name = 'Glow'
		Glow.Parent = Fill
	end
	Glow.Color = Secondary
	Glow.Transparency = P.Effect.BarGlow.Transparency
	Glow.BlurRadius = P.Effect.BarGlow.BlurRadius

	NormalizeScrollerItems(Root)
	BindScroller(Root)
	RefreshScrollerBar(Root)
end

function Presets:ActivateTree(Root)
	if not Root then return false end
	local function Visit(Object)
		if Object:IsA('GuiObject') and Object:GetAttribute('FORGESimpleKind') == 'Scroller' then
			BindScroller(Object)
			RefreshScrollerBar(Object)
		end
		for _, Child in ipairs(Object:GetChildren()) do Visit(Child) end
	end
	Visit(Root)
	return true
end

function Presets:RefreshScroller(Root)
	if not Root or Root:GetAttribute('FORGESimpleKind') ~= 'Scroller' then return false end
	RefreshScrollerBar(Root)
	return true
end

function Presets:ScrollScroller(Root, Direction)
	if not Root or Root:GetAttribute('FORGESimpleKind') ~= 'Scroller' then return false end
	BindScroller(Root)

	local Metrics = RefreshScrollerBar(Root)
	if not Metrics or Metrics.MaxCanvas <= 1 then return false end

	local Current = math.clamp(Metrics.Scroll.CanvasPosition.Y, 0, Metrics.MaxCanvas)
	local Step = math.max(24, math.min(72, Metrics.Viewport * .22))
	local Y = math.clamp(Current - Direction * Step, 0, Metrics.MaxCanvas)

	Metrics.Scroll.CanvasPosition = Vector2.new(Metrics.Scroll.CanvasPosition.X, Y)
	RefreshScrollerBar(Root, Y)
	return true
end

function Presets:SetScrollerItemHeight(Object, Height)
	if not Object or not Object:IsA('GuiObject') then return false end
	local Owner = ScrollerOwner(Object.Parent)
	if not Owner or Object.Parent ~= self:GetInsertionTarget(Owner) then return false end

	ApplyScrollerItemGeometry(Owner, Object, Height)
	RefreshScrollerBar(Owner)
	return true
end

function Presets:ApplySemantic(Root)
	if not Root or not Root:IsA('GuiObject') then return false end

	local Kind = Root:GetAttribute('FORGESimpleKind')
	if not Kind then return false end

	if Root:GetAttribute('FORGELayoutKind') then
		EnsureLayout(Root)
		return true
	end

	local Primary = Root:GetAttribute('FORGEPrimaryColor') or Pack().Color.Surface
	local Secondary = Root:GetAttribute('FORGESecondaryColor') or Pack().Color.Text

	EnsureBar(Root)
	EnsureScroller(Root)
	EnsureSurfaceInternals(Root)
	ApplyPrimary(Root, Primary)
	ApplySecondary(Root, Secondary)
	ApplyTextControls(Root)

	if Kind == 'VerticalDivider' or Kind == 'HorizontalDivider' then
		Root.BackgroundTransparency = 1
		Root.BorderSizePixel = 0
		Root.ClipsDescendants = false
		local Line = Root:FindFirstChild('Line')
		if not Line or not Line:IsA('Frame') then
			if Line then Line:Destroy() end
			Line = Instance.new('Frame')
			Line.Name = 'Line'
			Line:SetAttribute('FORGEStyleInternal', true)
			Line:SetAttribute('FORGEHierarchyInternal', true)
			Line:SetAttribute('FORGEInheritSecondary', true)
			Line.Parent = Root
		end

		local Thickness = math.max(1, tonumber(Root:GetAttribute('FORGEDividerThickness')) or 2)
		if Kind == 'VerticalDivider' then
			Line.AnchorPoint = Vector2.new(.5, 0)
			Line.Position = UDim2.fromScale(.5, 0)
			Line.Size = UDim2.new(0, Thickness, 1, 0)
		else
			Line.AnchorPoint = Vector2.new(0, .5)
			Line.Position = UDim2.fromScale(0, .5)
			Line.Size = UDim2.new(1, 0, 0, Thickness)
		end

		Line.BackgroundColor3 = Secondary
		Line.BorderSizePixel = 0
		Line.ZIndex = Root.ZIndex + 1
		Line.Active = false

		local FadePreset = tostring(Root:GetAttribute('FORGEDividerTransparencyPreset') or 'None')
		local FadeSequence = DividerTransparencyPresets[FadePreset]
		local Gradient = Line:FindFirstChild('_FORGEDividerTransparencyGradient')
		if Kind == 'HorizontalDivider' and FadeSequence then
			if not Gradient or not Gradient:IsA('UIGradient') then
				if Gradient then Gradient:Destroy() end
				Gradient = Instance.new('UIGradient')
				Gradient.Name = '_FORGEDividerTransparencyGradient'
				Gradient:SetAttribute('FORGEStyleInternal', true)
				Gradient:SetAttribute('FORGEHierarchyInternal', true)
				Gradient.Parent = Line
			end
			Gradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
			Gradient.Transparency = FadeSequence
			Gradient.Rotation = 0
			Gradient.Offset = Vector2.zero
		elseif Gradient then
			Gradient:Destroy()
		end
	end
	UpdateValue(Root)
	RaiseAuthoredChildren(Root)

	if Kind == 'Selector' then RebuildSelector(Root) end
	if Kind == 'Navbar' then RebuildNavbar(Root) ApplySecondary(Root, Secondary) end

	local Shadow = Root:FindFirstChild('Shadow')
	if Shadow and Shadow:IsA('TextLabel') then
		Shadow.Visible = Root:GetAttribute('FORGEShadowVisible') ~= false
		Shadow.TextColor3 = Root:GetAttribute('FORGEShadowColor') or Color3.new(0, 0, 0)
		Shadow.TextTransparency = 1 - math.clamp(tonumber(Root:GetAttribute('FORGEShadowOpacity')) or .8, 0, 1)
	end

	return true
end

local Builders = {}

Builders.Container = function()
	return LayoutFrame('Container', 'Container', UDim2.fromOffset(420, 260))
end

Builders.Row = function()
	local Root = LayoutFrame('Row', 'Row', UDim2.fromOffset(420, 48))
	EnsureLayout(Root)
	return Root
end

Builders.Stack = function()
	local Root = LayoutFrame('Stack', 'Stack', UDim2.fromOffset(420, 48))
	EnsureLayout(Root)
	return Root
end

Builders.Spacer = function()
	local Root = LayoutFrame('Spacer', 'Spacer', UDim2.fromOffset(24, 24))
	Root:SetAttribute('FORGEAcceptChildren', false)
	Root:SetAttribute('FORGEAutoSize', false)
	local Flex = Instance.new('UIFlexItem')
	Flex.Name = '_FORGEFlex'
	Flex:SetAttribute('FORGEStyleInternal', true)
	pcall(function() Flex.FlexMode = Enum.UIFlexMode.Fill end)
	Flex.Parent = Root
	return Root
end

Builders.VerticalDivider = function()
	local P = Pack()
	local Root = Instance.new('Frame')
	Root.Name = 'VerticalDivider'
	Root.Size = UDim2.fromOffset(18, 180)
	Root.BackgroundTransparency = 1
	Root.BorderSizePixel = 0
	Root.ClipsDescendants = false
	Mark(Root, 'VerticalDivider')
	Root:SetAttribute('FORGESecondaryColor', P.Color.Ivory)
	Root:SetAttribute('FORGEDividerThickness', 2)
	Root:SetAttribute('FORGEAcceptChildren', false)

	-- The root is deliberately much wider than the visible line. FORGE Studio
	-- hit-tests the transparent root, so this gives a comfortable 18px grab area
	-- while runtime still renders only the thin centered divider.
	local Line = Instance.new('Frame')
	Line.Name = 'Line'
	Line.AnchorPoint = Vector2.new(.5, 0)
	Line.Position = UDim2.fromScale(.5, 0)
	Line.Size = UDim2.new(0, 2, 1, 0)
	Line.BackgroundColor3 = P.Color.Ivory
	Line.BorderSizePixel = 0
	Line.ZIndex = Root.ZIndex + 1
	Line.Active = false
	Line:SetAttribute('FORGEStyleInternal', true)
	Line:SetAttribute('FORGEHierarchyInternal', true)
	Line:SetAttribute('FORGEInheritSecondary', true)
	Line.Parent = Root

	Presets:ApplySemantic(Root)
	return Root
end

Builders.HorizontalDivider = function()
	local P = Pack()
	local Root = Instance.new('Frame')
	Root.Name = 'HorizontalDivider'
	Root.Size = UDim2.fromOffset(180, 18)
	Root.BackgroundTransparency = 1
	Root.BorderSizePixel = 0
	Root.ClipsDescendants = false
	Mark(Root, 'HorizontalDivider')
	Root:SetAttribute('FORGESecondaryColor', P.Color.Ivory)
	Root:SetAttribute('FORGEDividerThickness', 2)
	Root:SetAttribute('FORGEDividerTransparencyPreset', 'None')
	Root:SetAttribute('FORGEAcceptChildren', false)

	-- Same usability trick as the vertical divider: the transparent root is
	-- intentionally taller than the visible line, giving it an 18px grab zone.
	local Line = Instance.new('Frame')
	Line.Name = 'Line'
	Line.AnchorPoint = Vector2.new(0, .5)
	Line.Position = UDim2.fromScale(0, .5)
	Line.Size = UDim2.new(1, 0, 0, 2)
	Line.BackgroundColor3 = P.Color.Ivory
	Line.BorderSizePixel = 0
	Line.ZIndex = Root.ZIndex + 1
	Line.Active = false
	Line:SetAttribute('FORGEStyleInternal', true)
	Line:SetAttribute('FORGEHierarchyInternal', true)
	Line:SetAttribute('FORGEInheritSecondary', true)
	Line.Parent = Root

	Presets:ApplySemantic(Root)
	return Root
end

Builders.Panel = function()
	local Root = NewSurface('Frame', 'Panel', UDim2.fromOffset(420, 240))
	SetSemanticDefaults(Root, 'Panel')
	Root:SetAttribute('FORGEAcceptChildren', true)
	Presets:ApplySemantic(Root)
	return Root
end

Builders.Button = function()
	local Root = NewSurface('TextButton', 'Button', UDim2.fromOffset(220, 48))
	SetSemanticDefaults(Root, 'Button')
	local Label = NewText(Root, 'Label', 'BUTTON', 'Strong')
	Label.TextXAlignment = Enum.TextXAlignment.Center
	Root:SetAttribute('FORGEText', 'BUTTON')
	InitializeTextAttributes(Root, Label, 'Strong')
	Root:SetAttribute('FORGETextXAlignment', 'Center')
	Presets:ApplySemantic(Root)
	return Root
end

local function BarRoot(Name, Kind, Size, Value)
	local P = Pack()
	local Root = Instance.new('Frame')
	Root.Name = Name
	Root.BackgroundTransparency = 1
	Root.BorderSizePixel = 0
	Root.Size = Size
	Root.ClipsDescendants = false
	SetSemanticDefaults(Root, Kind, P.Color.Ivory, P.Color.Ivory, false, false, P.Metric.BarInset)
	Root:SetAttribute('FORGEValue', Value)

	local Track = Instance.new('Frame')
	Track.Name = 'Track'
	Track.AnchorPoint = Vector2.new(.5, .5)
	Track.Position = UDim2.fromScale(.5, .5)
	Track.Size = UDim2.new(1, 0, 0, P.Metric.BarHeight)
	Track.BackgroundTransparency = 1
	Track.BorderSizePixel = 0
	Track:SetAttribute('FORGEStyleInternal', true)
	Track.ClipsDescendants = false
	Track.ZIndex = Root.ZIndex + 4
	Track.Parent = Root

	local TrackStroke = Instance.new('UIStroke')
	TrackStroke.Name = 'Stroke'
	TrackStroke.LineJoinMode = Enum.LineJoinMode.Miter
	TrackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	TrackStroke.Thickness = P.Metric.Stroke
	TrackStroke.Color = P.Color.Ivory
	TrackStroke:SetAttribute('FORGEInheritSecondary', true)
	TrackStroke.Parent = Track

	local Inset = Instance.new('Frame')
	Inset.Name = 'Inset'
	Inset.BackgroundTransparency = 1
	Inset.BorderSizePixel = 0
	Inset.Position = UDim2.fromOffset(P.Metric.BarInset, P.Metric.BarInset)
	Inset.Size = UDim2.new(1, -P.Metric.BarInset * 2, 1, -P.Metric.BarInset * 2)
	Inset.ClipsDescendants = false
	Inset.ZIndex = Track.ZIndex + 1
	Inset.Parent = Track

	local Fill = Instance.new('Frame')
	Fill.Name = 'Fill'
	Fill.BackgroundColor3 = P.Color.Ivory
	Fill.BorderSizePixel = 0
	Fill.Size = UDim2.new(Value, 0, 1, 0)
	Fill.ZIndex = Inset.ZIndex + 1
	Fill.Parent = Inset

	local Glow = Instance.new('UIShadow')
	Glow.Name = 'Glow'
	Glow.Color = P.Effect.BarGlow.Color
	Glow.Transparency = P.Effect.BarGlow.Transparency
	Glow.BlurRadius = P.Effect.BarGlow.BlurRadius
	Glow.Parent = Fill

	Presets:ApplySemantic(Root)
	return Root
end

Builders.Slider = function()
	return BarRoot('Slider', 'Slider', UDim2.fromOffset(300, 34), .5)
end

Builders.ProgressBar = function()
	return BarRoot('ProgressBar', 'ProgressBar', UDim2.fromOffset(320, 24), .65)
end

Builders.Selector = function()
	local Root = NewSurface('TextButton', 'Selector', UDim2.fromOffset(260, 42))
	SetSemanticDefaults(Root, 'Selector')
	Root:SetAttribute('FORGEItems', 'OPTION 01, OPTION 02, OPTION 03')
	Root:SetAttribute('FORGESelectedIndex', 1)

	local Label = NewText(Root, 'Label', 'OPTION 01', 'Strong')
	Label.Position = UDim2.fromOffset(10, 0)
	Label.Size = UDim2.new(1, -40, 1, 0)

	local Arrow = NewText(Root, 'Arrow', '>', 'Strong')
	Arrow.AnchorPoint = Vector2.new(1, 0)
	Arrow.Position = UDim2.new(1, -8, 0, 0)
	Arrow.Size = UDim2.fromOffset(24, 42)
	Arrow.TextXAlignment = Enum.TextXAlignment.Center

	Presets:ApplySemantic(Root)
	return Root
end

Builders.Scroller = function()
	local Root = NewSurface('Frame', 'Scroller', UDim2.fromOffset(420, 260))
	SetSemanticDefaults(Root, 'Scroller')
	-- Scrollers are structural containers by default: transparent body, no satin
	-- or shadow, with the RUCKUS inset stroke and scrollbar providing the chrome.
	Root.BackgroundTransparency = 1
	Root:SetAttribute('FORGESatinVisible', false)
	Root:SetAttribute('FORGEShadowVisible', false)
	Root:SetAttribute('FORGEAcceptChildren', true)
	Root:SetAttribute('FORGEGap', 6)
	Root:SetAttribute('FORGEPadding', 8)
	Root:SetAttribute('FORGEScrollBarWidth', Pack().Metric.BarHeight or 10)
	Root:SetAttribute('FORGEScrollBarInset', Pack().Metric.BarInset or 2)
	Root:SetAttribute('FORGEScrollBarGap', 6)
	Root:SetAttribute('FORGEScrollBarEdgeInset', Pack().Metric.Inset or 3)
	Root:SetAttribute('FORGEScrollCanvasInset', 2)
	Root:SetAttribute('FORGEScrollCanvasTopInset', 1)
	Root:SetAttribute('FORGEScrollBarVerticalInset', 3)
	Root:SetAttribute('FORGEScrollBarMinThumb', 18)
	Presets:ApplySemantic(Root)
	return Root
end

Builders.Navbar = function()
	local Root = NewSurface('Frame', 'Navbar', UDim2.fromOffset(420, 48))
	SetSemanticDefaults(Root, 'Navbar')
	Root:SetAttribute('FORGEItems', 'PLAY, PARTY, LOCKER')
	Root:SetAttribute('FORGESelectedIndex', 1)

	local Content = Instance.new('Frame')
	Content.Name = 'Content'
	Content.BackgroundTransparency = 1
	Content.BorderSizePixel = 0
	Content.Position = UDim2.fromOffset(6, 4)
	Content.Size = UDim2.new(1, -12, 1, -8)
	Content.ZIndex = Root.ZIndex + 4
	Content:SetAttribute('FORGEStyleInternal', true)
	Content.Parent = Root

	local Layout = Instance.new('UIListLayout')
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center
	Layout.Parent = Content

	Presets:ApplySemantic(Root)
	return Root
end

local function TextRoot(Kind, Value, Role, ShadowVisible)
	local Root = Instance.new('Frame')
	Root.Name = Kind
	Root.BackgroundTransparency = 1
	Root.BorderSizePixel = 0
	Root.Size = UDim2.fromOffset(300, Kind == 'Header' and 34 or 26)
	Mark(Root, Kind)
	Root:SetAttribute('FORGESecondaryColor', Pack().Color.Text)
	Root:SetAttribute('FORGEShadowVisible', ShadowVisible == true)
	Root:SetAttribute('FORGEShadowColor', Color3.new(0, 0, 0))
	Root:SetAttribute('FORGEShadowOpacity', .8)
	Root:SetAttribute('FORGEShadowBlur', 0)
	Root:SetAttribute('FORGEShadowOffsetX', 1)
	Root:SetAttribute('FORGEShadowOffsetY', 1)
	Root:SetAttribute('FORGEText', Value)

	local Shadow = NewText(Root, 'Shadow', Value, Role)
	Shadow.Position = UDim2.fromOffset(1, 1)
	Shadow.TextColor3 = Color3.new(0, 0, 0)
	Shadow.TextTransparency = .2
	Shadow.ZIndex = Root.ZIndex + 1
	Shadow:SetAttribute('FORGEIgnoreSecondary', true)

	local Label = NewText(Root, 'Label', Value, Role)
	Label.ZIndex = Root.ZIndex + 2
	InitializeTextAttributes(Root, Label, Role)
	Presets:ApplySemantic(Root)
	return Root
end

Builders.Header = function()
	return TextRoot('Header', 'HEADER', 'Header', true)
end

Builders.Subtext = function()
	return TextRoot('Subtext', 'SUBTEXT', 'Body', false)
end

local Schemas = {
	VerticalDivider = {
		{'Divider', {
			{'SecondaryColor', 'Color', 'Color3'},
			{'DividerThickness', 'Thickness', 'number'}
		}},
		{'Layout', {
			{'PositionX', 'X', 'axis-position'},
			{'PositionY', 'Y', 'axis-position'},
			{'Width', 'Grab Width', 'axis-size'},
			{'Height', 'Height', 'axis-size'},
			{'Visible', 'Visible', 'boolean'},
			{'ZIndex', 'Layer', 'number'}
		}}
	},
	HorizontalDivider = {
		{'Divider', {
			{'SecondaryColor', 'Color', 'Color3'},
			{'DividerThickness', 'Thickness', 'number'},
			{'DividerTransparencyPreset', 'Transparency Fade', 'choice', DividerTransparencyPresetNames}
		}},
		{'Layout', {
			{'PositionX', 'X', 'axis-position'},
			{'PositionY', 'Y', 'axis-position'},
			{'Width', 'Width', 'axis-size'},
			{'Height', 'Grab Height', 'axis-size'},
			{'Visible', 'Visible', 'boolean'},
			{'ZIndex', 'Layer', 'number'}
		}}
	},
	Container = {
		{'Layout', {
			{'PositionX', 'X', 'axis-position'},
			{'PositionY', 'Y', 'axis-position'},
			{'Width', 'Width', 'axis-size'},
			{'Height', 'Height', 'axis-size'},
			{'BackgroundTransparency', 'Background Transparency', 'number'},
			{'Visible', 'Visible', 'boolean'}
		}}
	},
	Row = {
		{'Layout', {
			{'Gap', 'Gap', 'number'},
			{'Padding', 'Padding', 'number'},
			{'PositionX', 'X', 'axis-position'},
			{'PositionY', 'Y', 'axis-position'},
			{'Width', 'Width', 'axis-size'},
			{'Height', 'Height', 'axis-size'},
			{'BackgroundTransparency', 'Background Transparency', 'number'}
		}}
	},
	Stack = {
		{'Layout', {
			{'Gap', 'Gap', 'number'},
			{'Padding', 'Padding', 'number'},
			{'PositionX', 'X', 'axis-position'},
			{'PositionY', 'Y', 'axis-position'},
			{'Width', 'Width', 'axis-size'},
			{'Height', 'Height', 'axis-size'},
			{'BackgroundTransparency', 'Background Transparency', 'number'}
		}}
	},
	Spacer = {
		{'Layout', {
			{'Width', 'Width', 'axis-size'},
			{'Height', 'Height', 'axis-size'},
			{'BackgroundTransparency', 'Background Transparency', 'number'}
		}}
	}
}

local TextControls = {
	{'TextRole', 'Preset', 'choice', {'Hero', 'Header', 'Subtext', 'Body', 'Strong', 'Caption'}},
	{'TextWeight', 'Weight', 'choice', {'Light', 'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Heavy'}},
	{'TextStyle', 'Style', 'choice', {'Normal', 'Italic'}},
	{'TextSize', 'Size', 'number'},
	{'TextTransparency', 'Transparency', 'number'},
	{'TextXAlignment', 'Horizontal Align', 'choice', {'Left', 'Center', 'Right'}},
	{'TextYAlignment', 'Vertical Align', 'choice', {'Top', 'Center', 'Bottom'}},
	{'TextWrapped', 'Wrapped', 'boolean'},
	{'TextScaled', 'Scaled', 'boolean'},
	{'RichText', 'Rich Text', 'boolean'},
	{'LineHeight', 'Line Height', 'number'},
	{'TextStrokeColor', 'Stroke Color', 'Color3'},
	{'TextStrokeOpacity', 'Stroke Opacity', 'number'}
}

local function VisualSchema(Content, Functional)
	local Result = {}
	if Content then table.insert(Result, {'Content', Content}) end
	if Functional then table.insert(Result, {'Function', Functional}) end
	table.insert(Result, {'Colors', {
		{'PrimaryColor', 'Primary', 'Color3'},
		{'SecondaryColor', 'Secondary', 'Color3'}
	}})
	table.insert(Result, {'Surface', {
		{'BackgroundTransparency', 'Background Transparency', 'number'},
		{'SatinVisible', 'Satin', 'boolean'},
		{'InsetEnabled', 'Inset Enabled', 'boolean'},
		{'InsetPixels', 'Inset', 'number'},
		{'StrokeThickness', 'Stroke', 'number'}
	}})
	table.insert(Result, {'Shadow', {
		{'ShadowVisible', 'Enabled', 'boolean'},
		{'ShadowColor', 'Color', 'Color3'},
		{'ShadowOpacity', 'Opacity', 'number'},
		{'ShadowBlur', 'Blur', 'number'}
	}})
	table.insert(Result, {'Layout', {
		{'PositionX', 'X', 'axis-position'},
		{'PositionY', 'Y', 'axis-position'},
		{'Width', 'Width', 'axis-size'},
		{'Height', 'Height', 'axis-size'},
		{'Visible', 'Visible', 'boolean'},
		{'Rotation', 'Rotation', 'number'},
		{'ZIndex', 'Layer', 'number'}
	}})
	return Result
end

Schemas.Panel = VisualSchema()
Schemas.Button = VisualSchema({{'Text', 'Text', 'string'}})
table.insert(Schemas.Button, 2, {'Typography', TextControls})
Schemas.Slider = VisualSchema(nil, {{'Value', 'Value', 'number'}})

do
	local Schema = VisualSchema(nil, {{'Value', 'Progress', 'number'}})

	for _, Section in ipairs(Schema) do
		if Section[1] == 'Surface' then
			for Index = #Section[2], 1, -1 do
				if Section[2][Index][1] == 'InsetPixels' then
					table.remove(Section[2], Index)
				end
			end
			break
		end
	end

	table.insert(Schema, 2, {'Bar', {
		{'InsetPixels', 'Inset', 'number'}
	}})

	Schemas.ProgressBar = Schema
end
Schemas.Selector = VisualSchema({
	{'Items', 'Items', 'string'},
	{'SelectedIndex', 'Selected', 'number'}
})
Schemas.Scroller = VisualSchema(nil, {
	{'Gap', 'Gap', 'number'},
	{'Padding', 'Padding', 'number'}
})
Schemas.Navbar = VisualSchema({
	{'Items', 'Items', 'string'},
	{'SelectedIndex', 'Selected', 'number'}
})
Schemas.Header = {
	{'Content', {{'Text', 'Text', 'string'}}},
	{'Typography', TextControls},
	{'Colors', {{'SecondaryColor', 'Color', 'Color3'}}},
	{'Shadow', {
		{'ShadowVisible', 'Enabled', 'boolean'},
		{'ShadowColor', 'Color', 'Color3'},
		{'ShadowOpacity', 'Opacity', 'number'},
		{'ShadowSize', 'Size (px)', 'number'},
		{'ShadowOffsetX', 'Offset X (px)', 'number'},
		{'ShadowOffsetY', 'Offset Y (px)', 'number'}
	}},
	{'Layout', {
		{'PositionX', 'X', 'axis-position'},
		{'PositionY', 'Y', 'axis-position'},
		{'Width', 'Width', 'axis-size'},
		{'Height', 'Height', 'axis-size'},
		{'BackgroundTransparency', 'Background Transparency', 'number'},
		{'Visible', 'Visible', 'boolean'},
		{'ZIndex', 'Layer', 'number'}
	}}
}
Schemas.Subtext = {
	{'Content', {{'Text', 'Text', 'string'}}},
	{'Typography', TextControls},
	{'Colors', {{'SecondaryColor', 'Color', 'Color3'}}},
	{'Shadow', {
		{'ShadowVisible', 'Enabled', 'boolean'},
		{'ShadowColor', 'Color', 'Color3'},
		{'ShadowOpacity', 'Opacity', 'number'},
		{'ShadowSize', 'Size (px)', 'number'},
		{'ShadowOffsetX', 'Offset X (px)', 'number'},
		{'ShadowOffsetY', 'Offset Y (px)', 'number'}
	}},
	{'Layout', {
		{'PositionX', 'X', 'axis-position'},
		{'PositionY', 'Y', 'axis-position'},
		{'Width', 'Width', 'axis-size'},
		{'Height', 'Height', 'axis-size'},
		{'BackgroundTransparency', 'Background Transparency', 'number'},
		{'Visible', 'Visible', 'boolean'},
		{'ZIndex', 'Layer', 'number'}
	}}
}

function Presets:IsAutoAxis(Object, Axis)
	if not Object or not Object:IsA('GuiObject') then return false end
	return AutoAxis(Object, Axis)
end

function Presets:SetAutoAxis(Object, Axis, Enabled)
	if not Object or not Object:IsA('GuiObject') then return false end
	MigrateAutoAxes(Object)
	Object:SetAttribute(Axis == 'X' and 'FORGEAutoWidth' or 'FORGEAutoHeight', Enabled == true)
	Object.AutomaticSize = Enum.AutomaticSize.None
	if Enabled == true then MarkManagedLayoutTree(Object) end
	return true
end

function Presets:GetNames(PackName)
	if PackName ~= 'RUCKUS' then return {} end
	return table.clone(Names)
end

function Presets:GetMetadata(PackName, Name)
	if PackName ~= 'RUCKUS' then return {Category = 'Generic'} end
	local Data = Metadata[Name]
	if not Data then return {Category = 'RUCKUS'} end
	local Result = table.clone(Data)
	Result.Exact = true
	Result.Simple = true
	return Result
end

function Presets:Build(PackName, Name)
	if PackName ~= 'RUCKUS' then return nil end
	local Builder = Builders[Name]
	if not Builder then return nil end
	local Root = Builder()
	Root:SetAttribute('FORGEStylePack', 'RUCKUS')
	Root:SetAttribute('FORGEStylePreset', Name)
	Root:SetAttribute('FORGEStyleExact', true)
	return Root
end

function Presets:GetVariants()
	return {}
end

function Presets:IsSemantic(Object)
	return Object and Object:IsA('GuiObject') and Object:GetAttribute('FORGESimpleKind') ~= nil
end

function Presets:GetSemanticSchema(Object)
	local Kind = Object and Object:GetAttribute('FORGESimpleKind')
	return Kind and Schemas[Kind] or nil
end

function Presets:GetSemanticValue(Object, Key)
	if not Object then return nil end

	if Key == 'Position' or Key == 'Size' or Key == 'Visible' or Key == 'Rotation' or Key == 'ZIndex' then
		return Object[Key]
	elseif Key == 'PositionX' then
		return Object.Position.X
	elseif Key == 'PositionY' then
		return Object.Position.Y
	elseif Key == 'Width' then
		return Object.Size.X
	elseif Key == 'Height' then
		return Object.Size.Y
	elseif Key == 'BackgroundTransparency' then
		return Object.BackgroundTransparency
	elseif Key == 'PrimaryColor' then
		return Object:GetAttribute('FORGEPrimaryColor')
	elseif Key == 'SecondaryColor' then
		return Object:GetAttribute('FORGESecondaryColor')
	elseif Key == 'SatinVisible' then
		return Object:GetAttribute('FORGESatinVisible') ~= false
	elseif Key == 'InsetEnabled' then
		return Object:GetAttribute('FORGEInsetEnabled') ~= false
	elseif Key == 'DividerThickness' then
		return tonumber(Object:GetAttribute('FORGEDividerThickness')) or 2
	elseif Key == 'DividerTransparencyPreset' then
		return tostring(Object:GetAttribute('FORGEDividerTransparencyPreset') or 'None')
	elseif Key == 'ShadowVisible' then
		return Object:GetAttribute('FORGEShadowVisible') ~= false
	elseif Key == 'ShadowColor' then
		return Object:GetAttribute('FORGEShadowColor') or Color3.new(0, 0, 0)
	elseif Key == 'ShadowOpacity' then
		return Object:GetAttribute('FORGEShadowOpacity') or .5
	elseif Key == 'ShadowBlur' then
		return Object:GetAttribute('FORGEShadowBlur') or 20
	elseif Key == 'InsetPixels' then
		return Object:GetAttribute('FORGEInsetPixels') or 2
	elseif Key == 'StrokeThickness' then
		return Object:GetAttribute('FORGEStrokeThickness') or Pack().Metric.Stroke or 1
	elseif Key == 'Value' then
		return Object:GetAttribute('FORGEValue') or 0
	elseif Key == 'Text' then
		return Object:GetAttribute('FORGEText') or ''
	elseif Key == 'TextRole' then
		return Object:GetAttribute('FORGETextRole') or 'Body'
	elseif Key == 'TextWeight' then
		return Object:GetAttribute('FORGETextWeight') or 'Regular'
	elseif Key == 'TextStyle' then
		return Object:GetAttribute('FORGETextStyle') or 'Normal'
	elseif Key == 'TextSize' then
		return Object:GetAttribute('FORGETextSize') or 14
	elseif Key == 'TextTransparency' then
		return Object:GetAttribute('FORGETextTransparency') or 0
	elseif Key == 'TextXAlignment' then
		return Object:GetAttribute('FORGETextXAlignment') or 'Left'
	elseif Key == 'TextYAlignment' then
		return Object:GetAttribute('FORGETextYAlignment') or 'Center'
	elseif Key == 'TextWrapped' then
		return Object:GetAttribute('FORGETextWrapped') == true
	elseif Key == 'TextScaled' then
		return Object:GetAttribute('FORGETextScaled') == true
	elseif Key == 'RichText' then
		return Object:GetAttribute('FORGERichText') == true
	elseif Key == 'LineHeight' then
		return Object:GetAttribute('FORGELineHeight') or 1
	elseif Key == 'TextStrokeColor' then
		return Object:GetAttribute('FORGETextStrokeColor') or Color3.new(0, 0, 0)
	elseif Key == 'TextStrokeOpacity' then
		return Object:GetAttribute('FORGETextStrokeOpacity') or 0
	elseif Key == 'ShadowSize' then
		local X = math.abs(tonumber(Object:GetAttribute('FORGEShadowOffsetX')) or 1)
		local Y = math.abs(tonumber(Object:GetAttribute('FORGEShadowOffsetY')) or 1)
		return math.max(X, Y)
	elseif Key == 'ShadowOffsetX' then
		return Object:GetAttribute('FORGEShadowOffsetX') or 1
	elseif Key == 'ShadowOffsetY' then
		return Object:GetAttribute('FORGEShadowOffsetY') or 1
	elseif Key == 'Items' then
		return Object:GetAttribute('FORGEItems') or ''
	elseif Key == 'SelectedIndex' then
		return Object:GetAttribute('FORGESelectedIndex') or 1
	elseif Key == 'Gap' then
		return Object:GetAttribute('FORGEGap') or 0
	elseif Key == 'Padding' then
		return Object:GetAttribute('FORGEPadding') or 0
	elseif Key == 'AutoSize' then
		return Object:GetAttribute('FORGEAutoSize') ~= false
	end
	return nil
end

function Presets:SetSemanticValue(Object, Key, Value)
	if not Object then return false end

	if Key == 'Position' or Key == 'Size' or Key == 'Visible' or Key == 'Rotation' or Key == 'ZIndex' then
		Object[Key] = Value
	elseif Key == 'BackgroundTransparency' then
		Object.BackgroundTransparency = math.clamp(tonumber(Value) or 0, 0, 1)
	elseif Key == 'PrimaryColor' then
		Object:SetAttribute('FORGEPrimaryColor', Value)
	elseif Key == 'SecondaryColor' then
		Object:SetAttribute('FORGESecondaryColor', Value)
	elseif Key == 'SatinVisible' then
		Object:SetAttribute('FORGESatinVisible', Value == true)
	elseif Key == 'InsetEnabled' then
		Object:SetAttribute('FORGEInsetEnabled', Value == true)
	elseif Key == 'DividerThickness' then
		Object:SetAttribute('FORGEDividerThickness', math.max(1, tonumber(Value) or 1))
	elseif Key == 'DividerTransparencyPreset' then
		local Preset = tostring(Value or 'None')
		if Preset ~= 'None' and DividerTransparencyPresets[Preset] == nil then Preset = 'None' end
		Object:SetAttribute('FORGEDividerTransparencyPreset', Preset)
	elseif Key == 'ShadowVisible' then
		Object:SetAttribute('FORGEShadowVisible', Value == true)
	elseif Key == 'ShadowColor' then
		Object:SetAttribute('FORGEShadowColor', Value)
	elseif Key == 'ShadowOpacity' then
		Object:SetAttribute('FORGEShadowOpacity', math.clamp(tonumber(Value) or 0, 0, 1))
	elseif Key == 'ShadowBlur' then
		Object:SetAttribute('FORGEShadowBlur', math.max(0, tonumber(Value) or 0))
	elseif Key == 'InsetPixels' then
		Object:SetAttribute('FORGEInsetPixels', math.max(0, math.floor((tonumber(Value) or 0) + .5)))
	elseif Key == 'StrokeThickness' then
		Object:SetAttribute('FORGEStrokeThickness', math.max(0, tonumber(Value) or 0))
	elseif Key == 'Value' then
		Object:SetAttribute('FORGEValue', math.clamp(tonumber(Value) or 0, 0, 1))
	elseif Key == 'Text' then
		Object:SetAttribute('FORGEText', tostring(Value or ''))
		local Label = Object:FindFirstChild('Label')
		local Shadow = Object:FindFirstChild('Shadow')
		if Label and Label:IsA('TextLabel') then Label.Text = tostring(Value or '') end
		if Shadow and Shadow:IsA('TextLabel') then Shadow.Text = tostring(Value or '') end
	elseif Key == 'TextRole' then
		Object:SetAttribute('FORGETextRole', tostring(Value or 'Body'))
	elseif Key == 'TextWeight' then
		Object:SetAttribute('FORGETextWeight', tostring(Value or 'Regular'))
	elseif Key == 'TextStyle' then
		Object:SetAttribute('FORGETextStyle', tostring(Value or 'Normal'))
	elseif Key == 'TextSize' then
		Object:SetAttribute('FORGETextSize', math.max(1, tonumber(Value) or 14))
	elseif Key == 'TextTransparency' then
		Object:SetAttribute('FORGETextTransparency', math.clamp(tonumber(Value) or 0, 0, 1))
	elseif Key == 'TextXAlignment' then
		Object:SetAttribute('FORGETextXAlignment', tostring(Value or 'Left'))
	elseif Key == 'TextYAlignment' then
		Object:SetAttribute('FORGETextYAlignment', tostring(Value or 'Center'))
	elseif Key == 'TextWrapped' then
		Object:SetAttribute('FORGETextWrapped', Value == true)
	elseif Key == 'TextScaled' then
		Object:SetAttribute('FORGETextScaled', Value == true)
	elseif Key == 'RichText' then
		Object:SetAttribute('FORGERichText', Value == true)
	elseif Key == 'LineHeight' then
		Object:SetAttribute('FORGELineHeight', math.max(.1, tonumber(Value) or 1))
	elseif Key == 'TextStrokeColor' then
		Object:SetAttribute('FORGETextStrokeColor', Value)
	elseif Key == 'TextStrokeOpacity' then
		Object:SetAttribute('FORGETextStrokeOpacity', math.clamp(tonumber(Value) or 0, 0, 1))
	elseif Key == 'ShadowSize' then
		local Size = tonumber(Value) or 0
		Object:SetAttribute('FORGEShadowOffsetX', Size)
		Object:SetAttribute('FORGEShadowOffsetY', Size)
	elseif Key == 'ShadowOffsetX' then
		Object:SetAttribute('FORGEShadowOffsetX', tonumber(Value) or 0)
	elseif Key == 'ShadowOffsetY' then
		Object:SetAttribute('FORGEShadowOffsetY', tonumber(Value) or 0)
	elseif Key == 'Items' then
		Object:SetAttribute('FORGEItems', tostring(Value or ''))
	elseif Key == 'SelectedIndex' then
		Object:SetAttribute('FORGESelectedIndex', math.max(1, math.floor(tonumber(Value) or 1)))
	elseif Key == 'Gap' then
		Object:SetAttribute('FORGEGap', math.max(0, tonumber(Value) or 0))
	elseif Key == 'Padding' then
		Object:SetAttribute('FORGEPadding', math.max(0, tonumber(Value) or 0))
	elseif Key == 'AutoSize' then
		Object:SetAttribute('FORGEAutoSize', Value == true)
		if Value == true then MarkManagedLayoutTree(Object) end
	else
		return false
	end

	self:ApplySemantic(Object)
	return true
end

function Presets:GetInsertionTarget(Object)
	if not Object then return nil end

	local Target
	if Object:GetAttribute('FORGESimpleKind') == 'Scroller' then
		Target = Object:FindFirstChild('Content', true)
	else
		Target = Object:FindFirstChild('Content')
	end

	if Target and Target:GetAttribute('FORGEInsertionTarget') == true then return Target end
	return Object
end

function Presets:CanAcceptChildren(Object)
	return Object and Object:IsA('GuiObject') and Object:GetAttribute('FORGEAcceptChildren') == true
end

local function NextLayoutOrder(Parent, Child)
	local Highest = 0
	for _, Sibling in ipairs(Parent:GetChildren()) do
		if Sibling ~= Child
			and Sibling:IsA('GuiObject')
			and Sibling:GetAttribute('FORGEStyleInternal') ~= true
		then
			Highest = math.max(Highest, Sibling.LayoutOrder)
		end
	end
	return Highest + 1
end

function Presets:AdoptChild(Parent, Child)
	if not Parent or not Child or not Child:IsA('GuiObject') then return end

	local Owner = ScrollerOwner(Parent)
	if not Owner and Parent:GetAttribute('FORGESimpleKind') then Owner = Parent end
	if Owner then RaiseTreeZIndex(Child, GetContentZIndex(Owner)) end

	local Kind = Parent:GetAttribute('FORGELayoutKind')
	if Kind == 'Row' or Kind == 'Stack' then MarkManagedLayoutTree(Parent) end
	if Kind == 'Row' then
		Child.Position = UDim2.new()
		Child.AnchorPoint = Vector2.zero
		Child.LayoutOrder = NextLayoutOrder(Parent, Child)
		RaiseTreeZIndex(Child, Parent.ZIndex + 1)
		local Flex = Child:FindFirstChild('_FORGEFlex')
		if Flex and Flex:GetAttribute('FORGEStyleInternal') == true then Flex:Destroy() end
	elseif Kind == 'Stack' then
		Child.Position = UDim2.new()
		Child.AnchorPoint = Vector2.zero
		Child.LayoutOrder = NextLayoutOrder(Parent, Child)
		RaiseTreeZIndex(Child, Parent.ZIndex + 1)
	elseif Owner and Owner:GetAttribute('FORGESimpleKind') == 'Scroller'
		and Child.Parent == self:GetInsertionTarget(Owner)
	then
		ApplyScrollerItemGeometry(
			Owner,
			Child,
			nil,
			NextLayoutOrder(self:GetInsertionTarget(Owner), Child)
		)
		RefreshScrollerBar(Owner)
	end

	local Root = Parent
	while Root and not Root:GetAttribute('FORGESimpleKind') do Root = Root.Parent end
	if Root then self:ApplySemantic(Root) end
end

return Presets
