local ChangeHistoryService = game:GetService('ChangeHistoryService')
local SelectionService = game:GetService('Selection')
local StudioSelection = game.Selection

local Theme = require(script.Parent.Theme)
local BuilderDebug = require(script.Parent.BuilderDebug)

local Builder = {}
Builder.__index = Builder

local FACE_NORMALS = {
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0),
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0),
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1),
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1),
}

local FACE_ORDER = {
	{'L', Enum.NormalId.Left},
	{'R', Enum.NormalId.Right},
	{'T', Enum.NormalId.Top},
	{'B', Enum.NormalId.Bottom},
	{'F', Enum.NormalId.Front},
	{'Bk', Enum.NormalId.Back},
}

local COLORS = {
	{Name = 'Dark Wood', Color = Color3.fromRGB(79, 60, 50)},
	{Name = 'Warm Wood', Color = Color3.fromRGB(86, 66, 54)},
	{Name = 'Paper', Color = Color3.fromRGB(254, 243, 187)},
}

local MATERIALS = {
	{Name = 'Wood Planks', Material = Enum.Material.WoodPlanks},
	{Name = 'Rubber', Material = Enum.Material.Rubber},
}

local MAX_ARRAY_COUNT = 200
local MAX_GRID_DIVISIONS = 64
local MIN_ARRAY_SCALE = 0.01
local MAX_ARRAY_SCALE = 100
local ATTACHMENT_AXIS_HALF_LENGTH = 512
local ATTACHMENT_AXIS_X_COLOR = Color3.fromRGB(235, 88, 88)
local ATTACHMENT_AXIS_Y_COLOR = Color3.fromRGB(92, 220, 120)

local function corner(Parent, Radius)
	local Corner = Instance.new('UICorner')
	Corner.CornerRadius = UDim.new(0, Radius or 5)
	Corner.Parent = Parent
	return Corner
end

local function stroke(Parent, Color, Transparency)
	local Stroke = Instance.new('UIStroke')
	Stroke.Thickness = 1
	Stroke.Color = Color or Theme.Color.FaceLight
	Stroke.Transparency = Transparency or 0
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Stroke.Parent = Parent
	return Stroke
end

local function label(Parent, Text, Height, Muted)
	local Label = Instance.new('TextLabel')
	Label.BackgroundTransparency = 1
	Label.Size = UDim2.new(1, 0, 0, Height or 20)
	Label.Text = Text or ''
	Label.TextColor3 = Muted and Theme.Color.TextMuted or Theme.Color.Text
	Label.TextSize = 13
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.FontFace = Muted and Theme.FontFace or Theme.FontFaceMedium
	Label.Parent = Parent
	return Label
end

local function button(Parent, Text, Width)
	local Button = Instance.new('TextButton')
	Button.AutoButtonColor = false
	Button.BackgroundColor3 = Theme.Color.FaceLight
	Button.Size = UDim2.new(Width or 1, Width and -3 or 0, 0, 30)
	Button.Text = Text
	Button.TextColor3 = Theme.Color.Text
	Button.TextSize = 13
	Button.FontFace = Theme.FontFaceMedium
	Button.Parent = Parent
	corner(Button, 5)
	stroke(Button, Theme.Color.AccentMuted, 0.35)

	Button.MouseEnter:Connect(function()
		Button.BackgroundColor3 = Theme.Color.AccentMuted
	end)
	Button.MouseLeave:Connect(function()
		Button.BackgroundColor3 = Theme.Color.FaceLight
	end)

	return Button
end

local function textBox(Parent, Text, Width)
	local Box = Instance.new('TextBox')
	Box.BackgroundColor3 = Theme.Color.PropertyValue
	Box.Size = UDim2.new(Width or 1, Width and -3 or 0, 0, 30)
	Box.ClearTextOnFocus = false
	Box.Text = Text or ''
	Box.PlaceholderColor3 = Theme.Color.TextMuted
	Box.TextColor3 = Theme.Color.Text
	Box.TextSize = 13
	Box.FontFace = Theme.FontFace
	Box.Parent = Parent
	corner(Box, 5)
	stroke(Box, Theme.Color.FaceLight, 0.2)
	return Box
end

local function row(Parent, Height)
	local Row = Instance.new('Frame')
	Row.BackgroundTransparency = 1
	Row.Size = UDim2.new(1, 0, 0, Height or 30)
	Row.Parent = Parent

	local Layout = Instance.new('UIListLayout')
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center
	Layout.Padding = UDim.new(0, 6)
	Layout.Parent = Row
	return Row
end

local function section(Parent, Title)
	local Section = Instance.new('Frame')
	Section.BackgroundColor3 = Theme.Color.FaceDark
	Section.AutomaticSize = Enum.AutomaticSize.Y
	Section.Size = UDim2.new(1, 0, 0, 0)
	Section.Parent = Parent
	corner(Section, 7)
	stroke(Section, Theme.Color.FaceLight, 0.35)

	local Padding = Instance.new('UIPadding')
	Padding.PaddingTop = UDim.new(0, 10)
	Padding.PaddingBottom = UDim.new(0, 10)
	Padding.PaddingLeft = UDim.new(0, 10)
	Padding.PaddingRight = UDim.new(0, 10)
	Padding.Parent = Section

	local Layout = Instance.new('UIListLayout')
	Layout.FillDirection = Enum.FillDirection.Vertical
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Layout.Padding = UDim.new(0, 7)
	Layout.Parent = Section

	local Header = label(Section, string.upper(Title), 20, false)
	Header.TextSize = 12
	Header.TextColor3 = Theme.Color.AccentSoft
	Header.FontFace = Theme.FontFaceBold

	return Section
end

local function isMovable(Object)
	return Object and (Object:IsA('BasePart') or Object:IsA('Model'))
end

local function firstBasePart(Object)
	if not Object then return nil end
	if Object:IsA('BasePart') then return Object end
	if Object:IsA('Model') then
		return Object.PrimaryPart or Object:FindFirstChildWhichIsA('BasePart', true)
	end
	return nil
end

local function attachmentGuideAnchor(Attachment)
	if not Attachment or not Attachment:IsA('Attachment') then return nil end
	local Parent = Attachment.Parent
	if Parent and Parent:IsA('BasePart') then return Parent end
	local Ancestor = Attachment:FindFirstAncestorWhichIsA('BasePart')
	if Ancestor then return Ancestor end

	-- Attachments used as module sockets are often parented to Terrain, a Folder,
	-- or a Model rather than directly to a BasePart. Handle adornments still need
	-- some BasePart as their coordinate-space anchor, so walk upward looking for
	-- any nearby geometry, then fall back to any workspace BasePart. The actual
	-- guide position/orientation still comes from Attachment.WorldCFrame.
	local Node = Parent
	while Node and Node ~= game do
		if Node.FindFirstChildWhichIsA then
			local DescendantPart = Node:FindFirstChildWhichIsA('BasePart', true)
			if DescendantPart then return DescendantPart end
		end
		Node = Node.Parent
	end
	return workspace:FindFirstChildWhichIsA('BasePart', true)
end

local function selectedAttachments()
	local Result = {}
	local Seen = {}
	for _, Object in ipairs(StudioSelection:Get()) do
		if Object:IsA('Attachment') then
			if not Seen[Object] then
				Seen[Object] = true
				table.insert(Result, Object)
			end
		else
			for _, Descendant in ipairs(Object:GetDescendants()) do
				if Descendant:IsA('Attachment') and not Seen[Descendant] then
					Seen[Descendant] = true
					table.insert(Result, Descendant)
				end
			end
		end
	end
	return Result
end

local function getSelectionRoots()
	local Result = {}
	for _, Object in ipairs(SelectionService:Get()) do
		if isMovable(Object) then
			table.insert(Result, Object)
		end
	end
	return Result
end

local function getSingleSelection()
	local Roots = getSelectionRoots()
	if #Roots ~= 1 then
		return nil, 'Select exactly one Part or Model.'
	end
	return Roots[1]
end

local function getPivot(Object)
	if Object:IsA('BasePart') then
		return Object.CFrame
	end
	return Object:GetPivot()
end

local function getBoundingBox(Object)
	if Object:IsA('BasePart') then
		return Object.CFrame, Object.Size
	end
	return Object:GetBoundingBox()
end

local function translate(Object, Delta)
	Object:PivotTo(CFrame.new(Delta) * getPivot(Object))
end

local function collectParts()
	local Parts = {}
	local Seen = {}
	for _, Object in ipairs(SelectionService:Get()) do
		if Object:IsA('BasePart') and not Seen[Object] then
			Seen[Object] = true
			table.insert(Parts, Object)
		end
		for _, Descendant in ipairs(Object:GetDescendants()) do
			if Descendant:IsA('BasePart') and not Seen[Descendant] then
				Seen[Descendant] = true
				table.insert(Parts, Descendant)
			end
		end
	end
	return Parts
end

local function supportExtent(CFrameValue, Size, Normal)
	return math.abs(Normal:Dot(CFrameValue.RightVector)) * Size.X * 0.5
		+ math.abs(Normal:Dot(CFrameValue.UpVector)) * Size.Y * 0.5
		+ math.abs(Normal:Dot(CFrameValue.LookVector)) * Size.Z * 0.5
end

local function faceData(Part, Face)
	local LocalNormal = FACE_NORMALS[Face]
	if not LocalNormal then
		return nil
	end
	local Half = Part.Size * 0.5
	local LocalCenter = Vector3.new(LocalNormal.X * Half.X, LocalNormal.Y * Half.Y, LocalNormal.Z * Half.Z)
	return Part.CFrame:PointToWorldSpace(LocalCenter), Part.CFrame:VectorToWorldSpace(LocalNormal).Unit, LocalNormal
end

local function parseNumber(Box, Default)
	local Value = tonumber(Box.Text)
	if Value == nil then
		Value = Default or 0
		Box.Text = tostring(Value)
	end
	return Value
end

local function parseInteger(Box, Default, Minimum, Maximum)
	local Value = math.floor(parseNumber(Box, Default) + 0.5)
	Value = math.clamp(Value, Minimum or -math.huge, Maximum or math.huge)
	Box.Text = tostring(Value)
	return Value
end

local function componentMultiply(A, B)
	return Vector3.new(A.X * B.X, A.Y * B.Y, A.Z * B.Z)
end

local function scaledRelativeCFrame(Relative, Scale)
	local Position = Relative.Position
	return CFrame.new(Position.X * Scale.X, Position.Y * Scale.Y, Position.Z * Scale.Z) * Relative.Rotation
end

local function scaleObject(Object, Scale)
	local Pivot = getPivot(Object)
	if Object:IsA('BasePart') then
		Object.Size = componentMultiply(Object.Size, Scale)
		Object:PivotTo(Pivot)
		return
	end

	local Records = {}
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA('BasePart') then
			table.insert(Records, {
				Part = Descendant,
				Relative = Pivot:ToObjectSpace(Descendant.CFrame),
				Size = Descendant.Size,
			})
		end
	end
	for _, Record in ipairs(Records) do
		Record.Part.Size = componentMultiply(Record.Size, Scale)
		Record.Part.CFrame = Pivot * scaledRelativeCFrame(Record.Relative, Scale)
	end
end

local function setModelAttributes(Model, Values)
	for Name, Value in pairs(Values) do
		Model:SetAttribute(Name, Value)
	end
end

local function arrayPositions(StartPosition, EndPosition, Mode, Count, Spacing, IncludeStart, IncludeEnd)
	local Result = {}
	local Delta = EndPosition - StartPosition
	local Distance = Delta.Magnitude
	if Distance <= 1e-4 then
		return Result, 'Array endpoints are at the same position.'
	end

	if Mode == 'Spacing' then
		Spacing = math.max(0.01, Spacing)
		local Direction = Delta.Unit
		if IncludeStart then
			table.insert(Result, StartPosition)
		end

		local D = Spacing
		while D < Distance - 1e-4 and #Result < MAX_ARRAY_COUNT do
			table.insert(Result, StartPosition + Direction * D)
			D += Spacing
		end

		if IncludeEnd and #Result < MAX_ARRAY_COUNT then
			table.insert(Result, EndPosition)
		end
		return Result
	end

	Count = math.clamp(Count, 1, MAX_ARRAY_COUNT)
	for Index = 1, Count do
		local T
		if IncludeStart and IncludeEnd then
			T = Count == 1 and 0.5 or (Index - 1) / (Count - 1)
		elseif IncludeStart then
			T = (Index - 1) / Count
		elseif IncludeEnd then
			T = Index / Count
		else
			T = Index / (Count + 1)
		end
		table.insert(Result, StartPosition:Lerp(EndPosition, T))
	end
	return Result
end

function Builder.new(Plugin, Widget)
	local self = setmetatable({}, Builder)
	self.Plugin = Plugin
	self.Widget = Widget
	self.Mouse = Plugin:GetMouse()
	self.Connections = {}
	self.Debug = BuilderDebug.new()

	self.SurfaceTarget = nil
	self.SurfaceFace = Enum.NormalId.Top
	self.PairA = nil
	self.PairB = nil
	self.ArraySource = nil
	self.PickingSurface = false

	self.ArrayMode = 'Count'
	self.ArrayIncludeStart = false
	self.ArrayIncludeEnd = false
	self.GridOuterFrame = true

	self:_buildUI()
	self:_bind()
	self:_refreshSelection()
	return self
end

function Builder:_connect(Signal, Callback)
	local Connection = Signal:Connect(Callback)
	table.insert(self.Connections, Connection)
	return Connection
end

function Builder:_setStatus(Text, Good)
	self.Status.Text = tostring(Text)
	self.Status.TextColor3 = Good == false and Theme.Color.Danger or (Good == true and Theme.Color.Success or Theme.Color.TextMuted)
end

function Builder:_record(Name, Callback)
	ChangeHistoryService:SetWaypoint('FORGE Builder - Before ' .. Name)
	local Success, Error = pcall(Callback)
	if Success then
		ChangeHistoryService:SetWaypoint('FORGE Builder - ' .. Name)
		self:_setStatus(Name .. ' complete.', true)
	else
		self:_setStatus(tostring(Error), false)
	end
end

function Builder:_refreshSelection()
	local Selected = SelectionService:Get()
	if #Selected == 0 then
		self.SelectionLabel.Text = 'Nothing selected'
	elseif #Selected == 1 then
		self.SelectionLabel.Text = 'Selected: ' .. Selected[1].Name
	else
		self.SelectionLabel.Text = string.format('%d objects selected', #Selected)
	end

	if self.SurfaceTarget and not self.SurfaceTarget.Parent then self.SurfaceTarget = nil end
	if self.PairA and not self.PairA.Parent then self.PairA = nil end
	if self.PairB and not self.PairB.Parent then self.PairB = nil end
	if self.ArraySource and not self.ArraySource.Parent then self.ArraySource = nil end
	self:_refreshTargets()
end

function Builder:_refreshTargets()
	if self.SurfaceTarget then
		self.SurfaceLabel.Text = string.format('%s · %s', self.SurfaceTarget.Name, self.SurfaceFace.Name)
	else
		self.SurfaceLabel.Text = 'No surface captured'
	end

	if self.PairA and self.PairB then
		self.PairLabel.Text = self.PairA.Name .. ' ↔ ' .. self.PairB.Name
	else
		self.PairLabel.Text = 'No pair captured'
	end

	if self.ArraySource then
		self.ArraySourceLabel.Text = 'Source: ' .. self.ArraySource.Name
	else
		self.ArraySourceLabel.Text = 'No array source captured'
	end

	self.ArrayModeButton.Text = self.ArrayMode == 'Count' and 'Mode: Even Count' or 'Mode: Fixed Spacing'
	self.ArrayStartButton.Text = (self.ArrayIncludeStart and '■ ' or '□ ') .. 'Include Start'
	self.ArrayEndButton.Text = (self.ArrayIncludeEnd and '■ ' or '□ ') .. 'Include End'
	self.GridFrameButton.Text = (self.GridOuterFrame and '■ ' or '□ ') .. 'Outer Frame'
end

function Builder:_captureSelectedSurfaceTarget()
	local Object, Error = getSingleSelection()
	if not Object or not Object:IsA('BasePart') then
		self:_setStatus(Error or 'Surface target must be a single BasePart.', false)
		return
	end
	self.SurfaceTarget = Object
	self:_refreshTargets()
	self:_showSurfaceDebug()
	self:_setStatus('Surface target captured.', true)
end

function Builder:_beginSurfacePick()
	self.PickingSurface = true
	self.Plugin:Activate(true)
	self:_setStatus('Click a face in the 3D viewport…')
end

function Builder:_captureMouseSurface()
	if not self.PickingSurface then return end
	local Target = self.Mouse.Target
	if Target and Target:IsA('BasePart') then
		self.SurfaceTarget = Target
		self.SurfaceFace = self.Mouse.TargetSurface
		self.PickingSurface = false
		self.Plugin:Deactivate()
		self:_refreshTargets()
		self:_showSurfaceDebug()
		self:_setStatus('Surface captured: ' .. Target.Name .. ' / ' .. self.SurfaceFace.Name, true)
	else
		self:_setStatus('Click a BasePart face.', false)
	end
end

function Builder:_setFace(Face)
	self.SurfaceFace = Face
	self:_refreshTargets()
	self:_showSurfaceDebug()
end

function Builder:_surfacePosition(Offset)
	local Target = self.SurfaceTarget
	if not Target or not Target.Parent or not Target:IsA('BasePart') then
		return nil, nil, 'Capture a BasePart surface first.'
	end
	local Center, Normal = faceData(Target, self.SurfaceFace)
	if not Center then
		return nil, nil, 'Invalid surface face.'
	end
	return Center + Normal * Offset, Normal
end

function Builder:_showSurfaceDebug()
	self.Debug:Clear('Surface')
	if not self.SurfaceTarget then return end
	local Offset = parseNumber(self.SurfaceOffset, 0)
	local Position, Normal = self:_surfacePosition(Offset)
	if not Position then return end
	self.Debug:Sphere('Surface', self.SurfaceTarget, Position, 0.18, Theme.Color.Accent, 0.02)
	self.Debug:Line('Surface', self.SurfaceTarget, Position, Position + Normal * 1.4, Theme.Color.AccentSoft, 3, 0.05)
end

function Builder:_placeAtSurface(Flush)
	local Object, Error = getSingleSelection()
	if not Object then
		self:_setStatus(Error, false)
		return
	end
	if Object == self.SurfaceTarget or (Object:IsA('Model') and self.SurfaceTarget and self.SurfaceTarget:IsDescendantOf(Object)) then
		self:_setStatus('Select the object to place, not the captured target.', false)
		return
	end

	local Offset = parseNumber(self.SurfaceOffset, 0)
	local Position, Normal, SurfaceError = self:_surfacePosition(Offset)
	if not Position then
		self:_setStatus(SurfaceError, false)
		return
	end

	self:_record(Flush and 'Place Flush' or 'Place At Surface Center', function()
		local BoxCFrame, BoxSize = getBoundingBox(Object)
		local Destination = Position
		if Flush then
			Destination += Normal * supportExtent(BoxCFrame, BoxSize, Normal)
		end
		translate(Object, Destination - BoxCFrame.Position)
	end)
end

function Builder:_capturePair()
	local Roots = getSelectionRoots()
	if #Roots ~= 2 then
		self:_setStatus('Select exactly two Parts or Models to capture a pair.', false)
		return
	end
	self.PairA = Roots[1]
	self.PairB = Roots[2]
	if not self.ArraySource or not self.ArraySource.Parent then
		self.ArraySource = self.PairA
	end
	self:_refreshTargets()
	self:_showPairDebug()
	self:_setStatus('Pair captured.', true)
end

function Builder:_pairMidpoint()
	if not self.PairA or not self.PairB or not self.PairA.Parent or not self.PairB.Parent then
		return nil, 'Capture two objects first.'
	end
	return (getPivot(self.PairA).Position + getPivot(self.PairB).Position) * 0.5
end

function Builder:_showPairDebug()
	self.Debug:Clear('Pair')
	if not self.PairA or not self.PairB then return end
	local Anchor = firstBasePart(self.PairA) and self.PairA or self.PairB
	if not firstBasePart(Anchor) then return end
	local A = getPivot(self.PairA).Position
	local B = getPivot(self.PairB).Position
	local M = (A + B) * 0.5
	self.Debug:Line('Pair', Anchor, A, B, Theme.Color.Guide, 3, 0.12)
	self.Debug:Sphere('Pair', Anchor, A, 0.12, Theme.Color.Guide, 0.04)
	self.Debug:Sphere('Pair', Anchor, B, 0.12, Theme.Color.Guide, 0.04)
	self.Debug:Sphere('Pair', Anchor, M, 0.2, Theme.Color.Accent, 0.02)
end

function Builder:_placeAtMidpoint()
	local Object, Error = getSingleSelection()
	if not Object then
		self:_setStatus(Error, false)
		return
	end
	if Object == self.PairA or Object == self.PairB then
		self:_setStatus('Capture the pair, then select a different object to place.', false)
		return
	end
	local Midpoint, MidError = self:_pairMidpoint()
	if not Midpoint then
		self:_setStatus(MidError, false)
		return
	end
	self:_record('Place At Midpoint', function()
		local BoxCFrame = getBoundingBox(Object)
		translate(Object, Midpoint - BoxCFrame.Position)
	end)
end

function Builder:_showMidpointDebug()
	local Midpoint, Error = self:_pairMidpoint()
	if not Midpoint then
		self:_setStatus(Error, false)
		return
	end
	self:_showPairDebug()
	self:_setStatus('Midpoint debug shown.', true)
end

function Builder:_captureArraySource()
	local Object, Error = getSingleSelection()
	if not Object then
		self:_setStatus(Error, false)
		return
	end
	self.ArraySource = Object
	self:_refreshTargets()
	self.Debug:Clear('Array')
	self:_setStatus('Array source captured.', true)
end

function Builder:_getArrayScale()
	local X = math.clamp(math.abs(parseNumber(self.ArrayScaleX, 1)), MIN_ARRAY_SCALE, MAX_ARRAY_SCALE)
	local Y = math.clamp(math.abs(parseNumber(self.ArrayScaleY, 1)), MIN_ARRAY_SCALE, MAX_ARRAY_SCALE)
	local Z = math.clamp(math.abs(parseNumber(self.ArrayScaleZ, 1)), MIN_ARRAY_SCALE, MAX_ARRAY_SCALE)
	self.ArrayScaleX.Text = string.format('%.4g', X)
	self.ArrayScaleY.Text = string.format('%.4g', Y)
	self.ArrayScaleZ.Text = string.format('%.4g', Z)
	return Vector3.new(X, Y, Z)
end

function Builder:_getArrayPositions()
	if not self.PairA or not self.PairB or not self.PairA.Parent or not self.PairB.Parent then
		return nil, 'Capture the two array endpoints first.'
	end
	if not self.ArraySource or not self.ArraySource.Parent then
		return nil, 'Capture an array source first.'
	end

	local Count = parseInteger(self.ArrayCount, 5, 1, MAX_ARRAY_COUNT)
	local Spacing = math.max(0.01, parseNumber(self.ArraySpacing, 2))
	self.ArraySpacing.Text = tostring(Spacing)
	return arrayPositions(
		getPivot(self.PairA).Position,
		getPivot(self.PairB).Position,
		self.ArrayMode,
		Count,
		Spacing,
		self.ArrayIncludeStart,
		self.ArrayIncludeEnd
	)
end

function Builder:_previewArray()
	self.ActiveBasePreview = 'Array'
	self.Debug:Clear('Array')
	local Positions, Error = self:_getArrayPositions()
	if not Positions then
		self:_setStatus(Error, false)
		return
	end
	if #Positions == 0 then
		self:_setStatus('No array positions fit these settings.', false)
		return
	end

	local Scale = self:_getArrayScale()
	local SourcePivot = getPivot(self.ArraySource)
	local BoxCFrame, BoxSize = getBoundingBox(self.ArraySource)
	local BoxFromPivot = SourcePivot:ToObjectSpace(BoxCFrame)
	local ScaledBoxFromPivot = scaledRelativeCFrame(BoxFromPivot, Scale)
	local ScaledBoxSize = componentMultiply(BoxSize, Scale)
	local Anchor = firstBasePart(self.PairA) and self.PairA or self.ArraySource
	if not firstBasePart(Anchor) then
		self:_setStatus('Array preview needs at least one BasePart.', false)
		return
	end

	for _, Position in ipairs(Positions) do
		local Pivot = CFrame.new(Position) * SourcePivot.Rotation
		self.Debug:Box('Array', Anchor, Pivot * ScaledBoxFromPivot, ScaledBoxSize, Theme.Color.Accent, 0.78)
	end
	self.Debug:Line('Array', Anchor, getPivot(self.PairA).Position, getPivot(self.PairB).Position, Theme.Color.Guide, 2, 0.25)
	local LayoutText = self.ArrayMode == 'Spacing' and string.format('%.4g-stud center spacing', math.max(0.01, parseNumber(self.ArraySpacing, 2))) or 'even count'
	self:_setStatus(string.format('Array preview: %d copies · %s.', #Positions, LayoutText), true)
end

function Builder:_generateArray()
	local Positions, Error = self:_getArrayPositions()
	if not Positions then
		self:_setStatus(Error, false)
		return
	end
	if #Positions == 0 then
		self:_setStatus('No array positions fit these settings.', false)
		return
	end

	local Source = self.ArraySource
	local SourcePivot = getPivot(Source)
	local Scale = self:_getArrayScale()
	local Spacing = math.max(0.01, parseNumber(self.ArraySpacing, 2))
	self:_record('Generate Linear Array', function()
		local Result = Instance.new('Model')
		Result.Name = 'FORGE_Array_' .. Source.Name
		Result.Parent = Source.Parent or workspace
		setModelAttributes(Result, {
			FORGEBuilderType = 'LinearArray',
			Mode = self.ArrayMode,
			Count = #Positions,
			Spacing = Spacing,
			ScaleX = Scale.X,
			ScaleY = Scale.Y,
			ScaleZ = Scale.Z,
			IncludeStart = self.ArrayIncludeStart,
			IncludeEnd = self.ArrayIncludeEnd,
		})

		for Index, Position in ipairs(Positions) do
			local Clone = Source:Clone()
			if not Clone then error('Array source could not be cloned.') end
			Clone.Name = Source.Name .. '_' .. string.format('%02d', Index)
			Clone.Parent = Result
			scaleObject(Clone, Scale)
			Clone:PivotTo(CFrame.new(Position) * SourcePivot.Rotation)
		end
		SelectionService:Set({Result})
	end)
	self.ActiveBasePreview = nil
	self.Debug:Clear('Array')
end

function Builder:_gridBasis()
	local Target = self.SurfaceTarget
	if not Target or not Target.Parent or not Target:IsA('BasePart') then
		return nil, 'Capture a BasePart surface first.'
	end

	local FaceCenter, Normal, LocalNormal = faceData(Target, self.SurfaceFace)
	if not FaceCenter then return nil, 'Invalid surface face.' end

	local U
	if math.abs(LocalNormal.X) > 0.5 then
		U = Target.CFrame.LookVector
	else
		U = Target.CFrame.RightVector
	end
	U = U.Unit
	local V = Normal:Cross(U).Unit
	local Width = supportExtent(Target.CFrame, Target.Size, U) * 2
	local Height = supportExtent(Target.CFrame, Target.Size, V) * 2

	return {
		Target = Target,
		Center = FaceCenter,
		Normal = Normal,
		U = U,
		V = V,
		Width = Width,
		Height = Height,
	}
end

function Builder:_gridBoxes()
	local Basis, Error = self:_gridBasis()
	if not Basis then return nil, nil, Error end

	local Columns = parseInteger(self.GridColumns, 6, 1, MAX_GRID_DIVISIONS)
	local Rows = parseInteger(self.GridRows, 4, 1, MAX_GRID_DIVISIONS)
	local Thickness = math.max(0.01, parseNumber(self.GridThickness, 0.2))
	local Depth = math.max(0.01, parseNumber(self.GridDepth, 0.25))
	local Margin = math.max(0, parseNumber(self.GridMargin, 0))
	local Offset = parseNumber(self.GridOffset, 0.01)

	self.GridThickness.Text = tostring(Thickness)
	self.GridDepth.Text = tostring(Depth)
	self.GridMargin.Text = tostring(Margin)
	self.GridOffset.Text = tostring(Offset)

	local Width = Basis.Width - Margin * 2
	local Height = Basis.Height - Margin * 2
	if Width <= Thickness or Height <= Thickness then
		return nil, nil, 'Grid margin/thickness leaves no usable surface.'
	end

	local SurfaceCenter = Basis.Center + Basis.Normal * (Offset + Depth * 0.5)
	local Frame = CFrame.fromMatrix(SurfaceCenter, Basis.U, Basis.V, Basis.Normal)
	local Boxes = {}

	local FirstColumn = self.GridOuterFrame and 0 or 1
	local LastColumn = self.GridOuterFrame and Columns or Columns - 1
	for Index = FirstColumn, LastColumn do
		if Index >= 0 and Index <= Columns then
			local Alpha = Index / Columns
			local X = -Width * 0.5 + Width * Alpha
			table.insert(Boxes, {
				CFrame = Frame * CFrame.new(X, 0, 0),
				Size = Vector3.new(Thickness, Height, Depth),
				Kind = 'Vertical',
			})
		end
	end

	local FirstRow = self.GridOuterFrame and 0 or 1
	local LastRow = self.GridOuterFrame and Rows or Rows - 1
	for Index = FirstRow, LastRow do
		if Index >= 0 and Index <= Rows then
			local Alpha = Index / Rows
			local Y = -Height * 0.5 + Height * Alpha
			table.insert(Boxes, {
				CFrame = Frame * CFrame.new(0, Y, 0),
				Size = Vector3.new(Width, Thickness, Depth),
				Kind = 'Horizontal',
			})
		end
	end

	return Boxes, Basis
end

function Builder:_previewGrid()
	self.Debug:Clear('Grid')
	local Boxes, Basis, Error = self:_gridBoxes()
	if not Boxes then
		self:_setStatus(Error, false)
		return
	end
	for _, Box in ipairs(Boxes) do
		self.Debug:Box('Grid', Basis.Target, Box.CFrame, Box.Size, Theme.Color.AccentSoft, 0.76)
	end
	self:_setStatus(string.format('Grid preview: %d bars.', #Boxes), true)
end

function Builder:_generateGrid()
	local Boxes, Basis, Error = self:_gridBoxes()
	if not Boxes then
		self:_setStatus(Error, false)
		return
	end
	local Target = Basis.Target
	self:_record('Generate Surface Grid', function()
		local Result = Instance.new('Model')
		Result.Name = 'FORGE_Grid_' .. Target.Name
		Result.Parent = Target.Parent or workspace
		setModelAttributes(Result, {
			FORGEBuilderType = 'SurfaceGrid',
			Columns = parseInteger(self.GridColumns, 6, 1, MAX_GRID_DIVISIONS),
			Rows = parseInteger(self.GridRows, 4, 1, MAX_GRID_DIVISIONS),
			OuterFrame = self.GridOuterFrame,
		})

		for Index, Box in ipairs(Boxes) do
			local Part = Instance.new('Part')
			Part.Name = Box.Kind .. '_' .. string.format('%02d', Index)
			Part.Anchored = true
			Part.Size = Box.Size
			Part.CFrame = Box.CFrame
			Part.Material = Target.Material
			Part.Color = Target.Color
			Part.Transparency = Target.Transparency
			Part.Reflectance = Target.Reflectance
			Part.CastShadow = Target.CastShadow
			Part.CanCollide = Target.CanCollide
			Part.CanQuery = Target.CanQuery
			Part.CanTouch = Target.CanTouch
			Part.TopSurface = Enum.SurfaceType.Smooth
			Part.BottomSurface = Enum.SurfaceType.Smooth
			Part.Parent = Result
		end
		SelectionService:Set({Result})
	end)
	self.Debug:Clear('Grid')
end

function Builder:_applyColor(Color)
	local Parts = collectParts()
	if #Parts == 0 then
		self:_setStatus('Select one or more parts/models first.', false)
		return
	end
	self:_record('Apply Color', function()
		for _, Part in ipairs(Parts) do
			Part.Color = Color
		end
	end)
end

function Builder:_applyMaterial(Material)
	local Parts = collectParts()
	if #Parts == 0 then
		self:_setStatus('Select one or more parts/models first.', false)
		return
	end
	self:_record('Apply Material', function()
		for _, Part in ipairs(Parts) do
			Part.Material = Material
		end
	end)
end

function Builder:_applyCustomColor()
	local R = math.clamp(math.floor(parseNumber(self.CustomR, 255) + 0.5), 0, 255)
	local G = math.clamp(math.floor(parseNumber(self.CustomG, 255) + 0.5), 0, 255)
	local B = math.clamp(math.floor(parseNumber(self.CustomB, 255) + 0.5), 0, 255)
	self.CustomR.Text = tostring(R)
	self.CustomG.Text = tostring(G)
	self.CustomB.Text = tostring(B)
	self:_applyColor(Color3.fromRGB(R, G, B))
end

function Builder:_buildUI()
	local Root = Instance.new('Frame')
	Root.Name = 'FORGEBuilder'
	Root.BackgroundColor3 = Theme.Color.Window
	Root.BorderSizePixel = 0
	Root.Size = UDim2.fromScale(1, 1)
	Root.Parent = self.Widget
	self.Root = Root

	local Header = Instance.new('Frame')
	Header.BackgroundColor3 = Theme.Color.FaceDarker
	Header.BorderSizePixel = 0
	Header.Size = UDim2.new(1, 0, 0, 54)
	Header.Parent = Root

	local Title = label(Header, 'FORGE BUILDER', 24, false)
	Title.Position = UDim2.fromOffset(12, 7)
	Title.Size = UDim2.new(1, -24, 0, 22)
	Title.TextSize = 15
	Title.FontFace = Theme.FontFaceBold

	local Subtitle = label(Header, 'Q1 + Q2 · placement · palette · arrays', 18, true)
	Subtitle.Position = UDim2.fromOffset(12, 29)
	Subtitle.Size = UDim2.new(1, -24, 0, 18)
	Subtitle.TextSize = 11

	local Scroll = Instance.new('ScrollingFrame')
	Scroll.BackgroundTransparency = 1
	Scroll.BorderSizePixel = 0
	Scroll.Position = UDim2.fromOffset(0, 54)
	Scroll.Size = UDim2.new(1, 0, 1, -86)
	Scroll.ScrollBarThickness = 5
	Scroll.ScrollBarImageColor3 = Theme.Color.AccentMuted
	Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Scroll.CanvasSize = UDim2.new()
	Scroll.Parent = Root

	local Padding = Instance.new('UIPadding')
	Padding.PaddingTop = UDim.new(0, 10)
	Padding.PaddingBottom = UDim.new(0, 12)
	Padding.PaddingLeft = UDim.new(0, 10)
	Padding.PaddingRight = UDim.new(0, 10)
	Padding.Parent = Scroll

	local Layout = Instance.new('UIListLayout')
	Layout.FillDirection = Enum.FillDirection.Vertical
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Layout.Padding = UDim.new(0, 10)
	Layout.Parent = Scroll

	local SelectionRow = row(Scroll)
	self.SelectionLabel = label(SelectionRow, 'Nothing selected', 30, true)
	self.SelectionLabel.Size = UDim2.new(0.68, -3, 0, 30)
	self.ClearDebugButton = button(SelectionRow, 'Clear Debug', 0.32)

	local Surface = section(Scroll, 'Surface Center / Placement')
	self.SurfaceLabel = label(Surface, 'No surface captured', 20, true)

	local CaptureRow = row(Surface)
	self.PickSurfaceButton = button(CaptureRow, 'Pick Surface', 0.5)
	self.UseSelectedTargetButton = button(CaptureRow, 'Use Selected', 0.5)

	local FaceLabel = label(Surface, 'FACE', 16, true)
	FaceLabel.TextSize = 10
	local FaceRow = row(Surface)
	for _, Entry in ipairs(FACE_ORDER) do
		local FaceButton = button(FaceRow, Entry[1], 1 / #FACE_ORDER)
		FaceButton.MouseButton1Click:Connect(function()
			self:_setFace(Entry[2])
		end)
	end

	local OffsetRow = row(Surface)
	local OffsetLabel = label(OffsetRow, 'Surface offset', 30, true)
	OffsetLabel.Size = UDim2.new(0.5, -3, 0, 30)
	self.SurfaceOffset = textBox(OffsetRow, '0', 0.5)
	self.SurfaceOffset.PlaceholderText = 'studs'

	local PlaceRow = row(Surface)
	self.CenterButton = button(PlaceRow, 'Center', 0.5)
	self.FlushButton = button(PlaceRow, 'Flush', 0.5)
	self.SurfaceMarkerButton = button(Surface, 'Show Surface Center Debug')

	local Pair = section(Scroll, 'Center Between Two')
	self.PairLabel = label(Pair, 'No pair captured', 20, true)
	self.CapturePairButton = button(Pair, 'Capture Selected Pair')
	local PairActions = row(Pair)
	self.MidpointButton = button(PairActions, 'Place At Midpoint', 0.65)
	self.MidpointMarkerButton = button(PairActions, 'Show Debug', 0.35)

	local Array = section(Scroll, 'Linear Array Between Two')
	label(Array, 'Uses the captured pair above as endpoints. Editing Count/Spacing switches layout mode automatically.', 32, true).TextSize = 11
	self.ArraySourceLabel = label(Array, 'No array source captured', 20, true)
	self.CaptureArraySourceButton = button(Array, 'Capture Selected Source')
	self.ArrayModeButton = button(Array, 'Mode: Even Count')

	local ArrayValueRow = row(Array)
	local CountLabel = label(ArrayValueRow, 'Count', 30, true)
	CountLabel.Size = UDim2.new(0.18, -3, 0, 30)
	self.ArrayCount = textBox(ArrayValueRow, '5', 0.27)
	local SpacingLabel = label(ArrayValueRow, 'Spacing', 30, true)
	SpacingLabel.Size = UDim2.new(0.23, -3, 0, 30)
	self.ArraySpacing = textBox(ArrayValueRow, '2', 0.32)
	self.ArraySpacing.PlaceholderText = 'center-to-center'

	label(Array, 'COPY SIZE MULTIPLIER', 16, true).TextSize = 10
	local ArrayScaleLabels = row(Array, 16)
	for _, Axis in ipairs({'X', 'Y', 'Z'}) do
		local AxisLabel = label(ArrayScaleLabels, Axis, 16, true)
		AxisLabel.Size = UDim2.new(1 / 3, -3, 0, 16)
		AxisLabel.TextXAlignment = Enum.TextXAlignment.Center
		AxisLabel.TextSize = 10
	end
	local ArrayScaleRow = row(Array)
	self.ArrayScaleX = textBox(ArrayScaleRow, '1', 1 / 3)
	self.ArrayScaleY = textBox(ArrayScaleRow, '1', 1 / 3)
	self.ArrayScaleZ = textBox(ArrayScaleRow, '1', 1 / 3)

	local ArrayToggleRow = row(Array)
	self.ArrayStartButton = button(ArrayToggleRow, '□ Include Start', 0.5)
	self.ArrayEndButton = button(ArrayToggleRow, '□ Include End', 0.5)

	local ArrayActions = row(Array)
	self.ArrayPreviewButton = button(ArrayActions, 'Preview', 0.42)
	self.ArrayGenerateButton = button(ArrayActions, 'Generate Array', 0.58)

	local Grid = section(Scroll, 'Surface Grid Array')
	label(Grid, 'Builds a real grid on the captured surface. Preview is debug-only.', 30, true).TextSize = 11

	local GridCountRow = row(Grid)
	local ColumnsLabel = label(GridCountRow, 'Columns', 30, true)
	ColumnsLabel.Size = UDim2.new(0.25, -3, 0, 30)
	self.GridColumns = textBox(GridCountRow, '6', 0.25)
	local RowsLabel = label(GridCountRow, 'Rows', 30, true)
	RowsLabel.Size = UDim2.new(0.25, -3, 0, 30)
	self.GridRows = textBox(GridCountRow, '4', 0.25)

	local GridSizeRow = row(Grid)
	local ThicknessLabel = label(GridSizeRow, 'Thickness', 30, true)
	ThicknessLabel.Size = UDim2.new(0.25, -3, 0, 30)
	self.GridThickness = textBox(GridSizeRow, '0.2', 0.25)
	local DepthLabel = label(GridSizeRow, 'Depth', 30, true)
	DepthLabel.Size = UDim2.new(0.25, -3, 0, 30)
	self.GridDepth = textBox(GridSizeRow, '0.25', 0.25)

	local GridInsetRow = row(Grid)
	local MarginLabel = label(GridInsetRow, 'Margin', 30, true)
	MarginLabel.Size = UDim2.new(0.25, -3, 0, 30)
	self.GridMargin = textBox(GridInsetRow, '0', 0.25)
	local GridOffsetLabel = label(GridInsetRow, 'Offset', 30, true)
	GridOffsetLabel.Size = UDim2.new(0.25, -3, 0, 30)
	self.GridOffset = textBox(GridInsetRow, '0.01', 0.25)

	self.GridFrameButton = button(Grid, '■ Outer Frame')
	local GridActions = row(Grid)
	self.GridPreviewButton = button(GridActions, 'Preview Grid', 0.45)
	self.GridGenerateButton = button(GridActions, 'Generate Grid', 0.55)

	local Palette = section(Scroll, 'Palette')
	label(Palette, 'COLORS', 16, true).TextSize = 10
	for _, Entry in ipairs(COLORS) do
		local Swatch = Instance.new('TextButton')
		Swatch.AutoButtonColor = false
		Swatch.BackgroundColor3 = Entry.Color
		Swatch.Size = UDim2.new(1, 0, 0, 34)
		Swatch.Text = Entry.Name .. string.format('   %d, %d, %d', math.floor(Entry.Color.R * 255 + 0.5), math.floor(Entry.Color.G * 255 + 0.5), math.floor(Entry.Color.B * 255 + 0.5))
		Swatch.TextColor3 = Entry.Color.R + Entry.Color.G + Entry.Color.B > 1.9 and Color3.fromRGB(35, 35, 35) or Color3.new(1, 1, 1)
		Swatch.TextSize = 12
		Swatch.FontFace = Theme.FontFaceMedium
		Swatch.Parent = Palette
		corner(Swatch, 5)
		stroke(Swatch, Theme.Color.Highlight, 0.55)
		Swatch.MouseButton1Click:Connect(function()
			self:_applyColor(Entry.Color)
		end)
	end

	label(Palette, 'CUSTOM RGB', 16, true).TextSize = 10
	local CustomRow = row(Palette)
	self.CustomR = textBox(CustomRow, '254', 0.22)
	self.CustomG = textBox(CustomRow, '243', 0.22)
	self.CustomB = textBox(CustomRow, '187', 0.22)
	self.CustomColorButton = button(CustomRow, 'Apply', 0.34)

	label(Palette, 'MATERIALS', 16, true).TextSize = 10
	local MaterialRow = row(Palette)
	for _, Entry in ipairs(MATERIALS) do
		local MaterialButton = button(MaterialRow, Entry.Name, 1 / #MATERIALS)
		MaterialButton.MouseButton1Click:Connect(function()
			self:_applyMaterial(Entry.Material)
		end)
	end

	local Footer = Instance.new('Frame')
	Footer.BackgroundColor3 = Theme.Color.FaceDarker
	Footer.BorderSizePixel = 0
	Footer.Position = UDim2.new(0, 0, 1, -32)
	Footer.Size = UDim2.new(1, 0, 0, 32)
	Footer.Parent = Root

	self.Status = label(Footer, 'Ready', 32, true)
	self.Status.Position = UDim2.fromOffset(10, 0)
	self.Status.Size = UDim2.new(1, -20, 1, 0)
	self.Status.TextSize = 11
end

function Builder:_bind()
	self:_connect(SelectionService.SelectionChanged, function()
		self:_refreshSelection()
	end)
	self:_connect(self.Mouse.Button1Down, function()
		self:_captureMouseSurface()
	end)
	self:_connect(self.Plugin.Deactivation, function()
		if self.PickingSurface then
			self.PickingSurface = false
			self:_setStatus('Surface picking cancelled.')
		end
	end)
	self:_connect(self.Widget:GetPropertyChangedSignal('Enabled'), function()
		if not self.Widget.Enabled then
			self.Debug:Clear()
		end
	end)

	self:_connect(self.ClearDebugButton.MouseButton1Click, function()
		self.Debug:Clear()
		self:_setStatus('Debug drawings cleared.', true)
	end)
	self:_connect(self.PickSurfaceButton.MouseButton1Click, function()
		self:_beginSurfacePick()
	end)
	self:_connect(self.UseSelectedTargetButton.MouseButton1Click, function()
		self:_captureSelectedSurfaceTarget()
	end)
	self:_connect(self.CenterButton.MouseButton1Click, function()
		self:_placeAtSurface(false)
	end)
	self:_connect(self.FlushButton.MouseButton1Click, function()
		self:_placeAtSurface(true)
	end)
	self:_connect(self.SurfaceMarkerButton.MouseButton1Click, function()
		self:_showSurfaceDebug()
		self:_setStatus('Surface center debug shown.', true)
	end)
	self:_connect(self.SurfaceOffset.FocusLost, function()
		self:_showSurfaceDebug()
	end)
	self:_connect(self.CapturePairButton.MouseButton1Click, function()
		self:_capturePair()
	end)
	self:_connect(self.MidpointButton.MouseButton1Click, function()
		self:_placeAtMidpoint()
	end)
	self:_connect(self.MidpointMarkerButton.MouseButton1Click, function()
		self:_showMidpointDebug()
	end)

	self:_connect(self.CaptureArraySourceButton.MouseButton1Click, function()
		self:_captureArraySource()
	end)
	self:_connect(self.ArrayModeButton.MouseButton1Click, function()
		self.ArrayMode = self.ArrayMode == 'Count' and 'Spacing' or 'Count'
		self:_refreshTargets()
		self:_previewArray()
	end)
	self:_connect(self.ArrayStartButton.MouseButton1Click, function()
		self.ArrayIncludeStart = not self.ArrayIncludeStart
		self:_refreshTargets()
		self:_previewArray()
	end)
	self:_connect(self.ArrayEndButton.MouseButton1Click, function()
		self.ArrayIncludeEnd = not self.ArrayIncludeEnd
		self:_refreshTargets()
		self:_previewArray()
	end)
	self:_connect(self.ArrayCount.FocusLost, function()
		self.ArrayMode = 'Count'
		self:_refreshTargets()
		self:_previewArray()
	end)
	self:_connect(self.ArraySpacing.FocusLost, function()
		self.ArrayMode = 'Spacing'
		self:_refreshTargets()
		self:_previewArray()
	end)
	for _, Box in ipairs({self.ArrayScaleX, self.ArrayScaleY, self.ArrayScaleZ}) do
		self:_connect(Box.FocusLost, function()
			self:_previewArray()
		end)
	end
	self:_connect(self.ArrayPreviewButton.MouseButton1Click, function() self:_previewArray() end)
	self:_connect(self.ArrayGenerateButton.MouseButton1Click, function() self:_generateArray() end)

	self:_connect(self.GridFrameButton.MouseButton1Click, function()
		self.GridOuterFrame = not self.GridOuterFrame
		self:_refreshTargets()
		self:_previewGrid()
	end)
	for _, Box in ipairs({self.GridColumns, self.GridRows, self.GridThickness, self.GridDepth, self.GridMargin, self.GridOffset}) do
		self:_connect(Box.FocusLost, function() self:_previewGrid() end)
	end
	self:_connect(self.GridPreviewButton.MouseButton1Click, function() self:_previewGrid() end)
	self:_connect(self.GridGenerateButton.MouseButton1Click, function() self:_generateGrid() end)

	self:_connect(self.CustomColorButton.MouseButton1Click, function()
		self:_applyCustomColor()
	end)
end

function Builder:Destroy()
	self.PickingSurface = false
	if self.Debug then self.Debug:Destroy() end
	for _, Connection in ipairs(self.Connections) do
		Connection:Disconnect()
	end
	table.clear(self.Connections)
	if self.Root then
		self.Root:Destroy()
	end
end

local BaseNew = Builder.new
Builder.new = function(Plugin, Widget)
	local self = BaseNew(Plugin, Widget)
	self.AttachmentAxisGuidesEnabled = false
	self.AttachmentAxisGuideConnections = {}
	self.AttachmentAxisGuideRefreshQueued = false

	local Scroll = self.Root:FindFirstChildWhichIsA('ScrollingFrame')
	if Scroll then
		self.AttachmentAxisGuidesButton = button(Scroll, '□ Attachment X/Y Guides')
		self.AttachmentAxisGuidesButton.LayoutOrder = -105
	end

	local function disconnectGuideConnections()
		for _, Connection in ipairs(self.AttachmentAxisGuideConnections) do
			Connection:Disconnect()
		end
		table.clear(self.AttachmentAxisGuideConnections)
	end

	local drawGuides
	local function queueGuideRefresh()
		if self.AttachmentAxisGuideRefreshQueued then return end
		self.AttachmentAxisGuideRefreshQueued = true
		task.defer(function()
			self.AttachmentAxisGuideRefreshQueued = false
			if self.Root and self.Root.Parent and drawGuides then drawGuides() end
		end)
	end

	local function bindSelectedAttachments()
		disconnectGuideConnections()
		if not self.AttachmentAxisGuidesEnabled then return end
		for _, Attachment in ipairs(selectedAttachments()) do
			table.insert(self.AttachmentAxisGuideConnections, Attachment:GetPropertyChangedSignal('CFrame'):Connect(queueGuideRefresh))
			table.insert(self.AttachmentAxisGuideConnections, Attachment:GetPropertyChangedSignal('WorldCFrame'):Connect(queueGuideRefresh))
			table.insert(self.AttachmentAxisGuideConnections, Attachment.AncestryChanged:Connect(queueGuideRefresh))
			local Parent = Attachment.Parent
			if Parent and Parent:IsA('BasePart') then
				table.insert(self.AttachmentAxisGuideConnections, Parent:GetPropertyChangedSignal('CFrame'):Connect(queueGuideRefresh))
			end
		end
	end

	drawGuides = function()
		self.Debug:Clear('AttachmentAxes')
		if self.AttachmentAxisGuidesButton then
			self.AttachmentAxisGuidesButton.Text = (self.AttachmentAxisGuidesEnabled and '■ ' or '□ ') .. 'Attachment X/Y Guides'
		end
		if not self.AttachmentAxisGuidesEnabled then return 0 end

		local Attachments = selectedAttachments()
		local Drawn = 0
		for _, Attachment in ipairs(Attachments) do
			local Anchor = attachmentGuideAnchor(Attachment)
			if Anchor then
				local World = Attachment.WorldCFrame
				local Position = World.Position
				local XAxis = World.RightVector * ATTACHMENT_AXIS_HALF_LENGTH
				local YAxis = World.UpVector * ATTACHMENT_AXIS_HALF_LENGTH
				local XLine = self.Debug:Line('AttachmentAxes', Anchor, Position - XAxis, Position + XAxis, ATTACHMENT_AXIS_X_COLOR, 2, 0.15, false)
				local YLine = self.Debug:Line('AttachmentAxes', Anchor, Position - YAxis, Position + YAxis, ATTACHMENT_AXIS_Y_COLOR, 2, 0.15, false)
				if XLine and YLine then Drawn += 1 end
			end
		end
		return #Attachments, Drawn
	end

	self:_connect(StudioSelection.SelectionChanged, function()
		bindSelectedAttachments()
		drawGuides()
	end)

	if self.AttachmentAxisGuidesButton then
		self:_connect(self.AttachmentAxisGuidesButton.MouseButton1Click, function()
			self.AttachmentAxisGuidesEnabled = not self.AttachmentAxisGuidesEnabled
			bindSelectedAttachments()
			local SelectedCount, DrawnCount = drawGuides()
			if self.AttachmentAxisGuidesEnabled then
				if SelectedCount == 0 then
					self:_setStatus('Attachment X/Y guides enabled. Select an Attachment.', true)
				elseif DrawnCount == SelectedCount then
					self:_setStatus(string.format('Attachment X/Y guides: %d attachment%s.', SelectedCount, SelectedCount == 1 and '' or 's'), true)
				else
					self:_setStatus(string.format('Found %d attachment%s; drew %d guide%s.', SelectedCount, SelectedCount == 1 and '' or 's', DrawnCount, DrawnCount == 1 and '' or 's'), DrawnCount > 0)
				end
			else
				self:_setStatus('Attachment X/Y guides disabled.', true)
			end
		end)
	end

	self:_connect(self.ClearDebugButton.MouseButton1Click, function()
		task.defer(function()
			if self.AttachmentAxisGuidesEnabled then drawGuides() end
		end)
	end)

	self:_connect(self.Widget:GetPropertyChangedSignal('Enabled'), function()
		if self.Widget.Enabled and self.AttachmentAxisGuidesEnabled then
			task.defer(function()
				bindSelectedAttachments()
				drawGuides()
			end)
		end
	end)

	local BaseDestroy = self.Destroy
	self.Destroy = function(Instance)
		disconnectGuideConnections()
		BaseDestroy(Instance)
	end

	return self
end

return Builder
