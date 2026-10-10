local SelectionService = game:GetService('Selection')

local GeneratorControlPoints = require(script.Parent.GeneratorControlPoints)
local Theme = require(script.Parent.Theme)

local BuilderGenerators = {}

local FACE_ORDER = {
	{'L', Enum.NormalId.Left},
	{'R', Enum.NormalId.Right},
	{'T', Enum.NormalId.Top},
	{'B', Enum.NormalId.Bottom},
	{'F', Enum.NormalId.Front},
	{'Bk', Enum.NormalId.Back},
}

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
	Button.MouseEnter:Connect(function() Button.BackgroundColor3 = Theme.Color.AccentMuted end)
	Button.MouseLeave:Connect(function() Button.BackgroundColor3 = Theme.Color.FaceLight end)
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

local function section(Parent, Title, LayoutOrder)
	local Section = Instance.new('Frame')
	Section.Name = 'FORGEBuilder_' .. Title:gsub('%W+', '')
	Section.BackgroundColor3 = Theme.Color.FaceDark
	Section.AutomaticSize = Enum.AutomaticSize.Y
	Section.Size = UDim2.new(1, 0, 0, 0)
	Section.LayoutOrder = LayoutOrder or 0
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

local function parseNumber(Box, Default, Minimum, Maximum)
	local Value = tonumber(Box.Text)
	if Value == nil then Value = Default or 0 end
	if Minimum ~= nil then Value = math.max(Minimum, Value) end
	if Maximum ~= nil then Value = math.min(Maximum, Value) end
	Box.Text = tostring(Value)
	return Value
end

local function parseInteger(Box, Default, Minimum, Maximum)
	local Value = math.floor(parseNumber(Box, Default, Minimum, Maximum) + 0.5)
	if Minimum ~= nil then Value = math.max(Minimum, Value) end
	if Maximum ~= nil then Value = math.min(Maximum, Value) end
	Box.Text = tostring(Value)
	return Value
end

local function firstBasePart(Object)
	if not Object then return nil end
	if Object:IsA('BasePart') then return Object end
	if Object:IsA('Model') then
		return Object.PrimaryPart or Object:FindFirstChildWhichIsA('BasePart', true)
	end
	return nil
end

local function getPivot(Object)
	if Object:IsA('BasePart') then return Object.CFrame end
	return Object:GetPivot()
end

local function selectionRoots()
	local Result = {}
	for _, Object in ipairs(SelectionService:Get()) do
		if Object:IsA('BasePart') or Object:IsA('Model') then table.insert(Result, Object) end
	end
	return Result
end

local function headingFrame(Position, Direction)
	local Flat = Vector3.new(Direction.X, 0, Direction.Z)
	if Flat.Magnitude <= 1e-4 then Flat = Vector3.new(0, 0, -1) end
	return CFrame.lookAt(Position, Position + Flat.Unit)
end

local function beamBox(Name, A, B, Width, Height)
	local Delta = B - A
	local Length = Delta.Magnitude
	if Length <= 1e-4 then return nil end
	return {
		Name = Name,
		CFrame = CFrame.lookAt((A + B) * 0.5, B),
		Size = Vector3.new(Width, Height, Length),
	}
end

local function clippedSlopeBeam(Name, A, B, Width, Height)
	local Delta = B - A
	local Length = Delta.Magnitude
	if Length <= 1e-4 then return nil end
	local Run = Vector3.new(Delta.X, 0, Delta.Z).Magnitude
	local Trim = 0
	if Run > 1e-4 then
		Trim = (Height * 0.5) * math.abs(Delta.Y) / Run
		Trim = math.min(Trim, Length * 0.45)
	end
	local Direction = Delta.Unit
	return beamBox(Name, A + Direction * Trim, B - Direction * Trim, Width, Height)
end

local function raisedSkirtBox(Name, A, B, Width, Height)
	local Delta = B - A
	local Length = Delta.Magnitude
	if Length <= 1e-4 then return nil end
	local BaseFrame = CFrame.lookAt((A + B) * 0.5, B)
	local Up = BaseFrame.UpVector
	local CenterA = A + Up * (Height * 0.5)
	local CenterB = B + Up * (Height * 0.5)
	local Run = Vector3.new(Delta.X, 0, Delta.Z).Magnitude
	local Trim = 0
	if Run > 1e-4 then
		-- The skirt grows upward from the stair edge instead of expanding downward.
		-- Trim the sloped centerline so the visible envelope still terminates on the
		-- exact vertical start/end planes of the stair flight.
		Trim = Height * math.abs(Delta.Y) / Run
		Trim = math.min(Trim, Length * 0.45)
	end
	local Direction = Delta.Unit
	return beamBox(Name, CenterA + Direction * Trim, CenterB - Direction * Trim, Width, Height)
end

local function appearanceFrom(Object)
	local Part = firstBasePart(Object)
	if not Part then
		return {
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(86, 66, 54),
			Transparency = 0,
			Reflectance = 0,
			CastShadow = true,
		}
	end
	return {
		Material = Part.Material,
		Color = Part.Color,
		Transparency = Part.Transparency,
		Reflectance = Part.Reflectance,
		CastShadow = Part.CastShadow,
	}
end

local function createPart(Model, Box, Appearance, Index)
	local Part = Instance.new('Part')
	Part.Name = (Box.Name or 'Piece') .. '_' .. string.format('%03d', Index)
	Part.Size = Box.Size
	Part.CFrame = Box.CFrame
	Part.Anchored = true
	Part.Material = Appearance.Material
	Part.Color = Appearance.Color
	Part.Transparency = Appearance.Transparency
	Part.Reflectance = Appearance.Reflectance
	Part.CastShadow = Appearance.CastShadow
	Part.CanCollide = true
	Part.CanQuery = true
	Part.CanTouch = true
	Part.TopSurface = Enum.SurfaceType.Smooth
	Part.BottomSurface = Enum.SurfaceType.Smooth
	Part:SetAttribute('FORGEBuilderGenerated', true)
	Part.Parent = Model
	return Part
end

local function clearGenerated(Model)
	for _, Child in ipairs(Model:GetChildren()) do
		if Child:GetAttribute('FORGEBuilderGenerated') == true then Child:Destroy() end
	end
end

local function storePoints(Model, Points)
	local Previous = Model:GetAttribute('GeneratorPointCount') or 0
	for Index = 1, math.max(Previous, #Points) do
		Model:SetAttribute(string.format('GeneratorPoint_%02d', Index), nil)
	end
	Model:SetAttribute('GeneratorPointCount', #Points)
	for Index, Point in ipairs(Points) do
		Model:SetAttribute(string.format('GeneratorPoint_%02d', Index), Point)
	end
end

local function loadPoints(Model)
	local Count = Model:GetAttribute('GeneratorPointCount')
	if typeof(Count) ~= 'number' then return nil end
	local Result = {}
	for Index = 1, Count do
		local Point = Model:GetAttribute(string.format('GeneratorPoint_%02d', Index))
		if typeof(Point) == 'Vector3' then table.insert(Result, Point) end
	end
	return #Result >= 2 and Result or nil
end

local function drawBoxes(Self, Channel, Boxes, Color)
	Self.Debug:Clear(Channel)
	local Anchor = Self.GeneratorPoints:GetAnchor() or Self.SurfaceTarget or firstBasePart(Self.PathEditModel)
	if not Anchor then return false end
	for _, Box in ipairs(Boxes) do
		Self.Debug:Box(Channel, Anchor, Box.CFrame, Box.Size, Color or Theme.Color.AccentSoft, 0.74)
	end
	return true
end

local function fenceSettings(Self)
	return {
		PostsPerSegment = parseInteger(Self.PathFencePosts, 8, 2, 64),
		Height = parseNumber(Self.PathFenceHeight, 2.5, 0.1, 50),
		PostWidth = parseNumber(Self.PathFencePostWidth, 0.18, 0.02, 10),
		PostDepth = parseNumber(Self.PathFencePostDepth, 0.18, 0.02, 10),
		RailThickness = parseNumber(Self.PathFenceRailThickness, 0.18, 0.02, 10),
		RailDepth = parseNumber(Self.PathFenceRailDepth, 0.22, 0.02, 10),
		Top = Self.PathFenceTop,
		Middle = Self.PathFenceMiddle,
		Bottom = Self.PathFenceBottom,
	}
end

local function fenceBoxes(Self)
	local Points = Self.GeneratorPoints:GetPoints()
	if #Points < 2 then return nil, nil, 'Add at least two surface control points.' end
	local Settings = fenceSettings(Self)
	local Boxes = {}

	for Segment = 1, #Points - 1 do
		local A, B = Points[Segment], Points[Segment + 1]
		local Delta = B - A
		if Delta.Magnitude > 1e-4 then
			local Flat = Vector3.new(Delta.X, 0, Delta.Z)
			local Direction = Flat.Magnitude > 1e-4 and Flat.Unit or Vector3.new(0, 0, -1)
			for Index = 1, Settings.PostsPerSegment do
				if Segment == 1 or Index > 1 then
					local Alpha = (Index - 1) / (Settings.PostsPerSegment - 1)
					local Base = A:Lerp(B, Alpha)
					table.insert(Boxes, {
						Name = 'FencePost',
						CFrame = headingFrame(Base + Vector3.new(0, Settings.Height * 0.5, 0), Direction),
						Size = Vector3.new(Settings.PostWidth, Settings.Height, Settings.PostDepth),
					})
				end
			end

			local function addRail(Name, HeightAlpha)
				local Rail = beamBox(
					Name,
					A + Vector3.new(0, Settings.Height * HeightAlpha, 0),
					B + Vector3.new(0, Settings.Height * HeightAlpha, 0),
					Settings.RailDepth,
					Settings.RailThickness
				)
				if Rail then table.insert(Boxes, Rail) end
			end
			if Settings.Bottom then addRail('FenceBottomRail', 0.12) end
			if Settings.Middle then addRail('FenceMiddleRail', 0.5) end
			if Settings.Top then addRail('FenceTopRail', 0.94) end
		end
	end
	return Boxes, Settings
end

local function stairSettings(Self)
	return {
		StepsPerFlight = parseInteger(Self.PathStairSteps, 12, 2, 64),
		Width = parseNumber(Self.PathStairWidth, 8, 0.25, 100),
		Thickness = parseNumber(Self.PathStairThickness, 0.5, 0.05, 20),
		Overhang = parseNumber(Self.PathStairOverhang, 0, 0, 20),
		LandingSize = parseNumber(Self.PathStairLandingSize, 8, 0.25, 100),
		Floating = Self.PathStairFloating,
		Railings = Self.PathStairRailings,
		RailHeight = parseNumber(Self.PathStairRailHeight, 3, 0.1, 20),
		RailThickness = parseNumber(Self.PathStairRailThickness, 0.18, 0.02, 5),
		RailPosts = parseInteger(Self.PathStairRailPosts, 5, 2, 32),
		RailInset = parseNumber(Self.PathStairRailInset, 0.08, 0, 20),
		SkirtHeight = parseNumber(Self.PathStairSkirtHeight, 1.25, 0.05, 20),
	}
end

local function addLanding(Boxes, Position, Direction, Settings, Name, Length)
	local Flat = Vector3.new(Direction.X, 0, Direction.Z)
	if Flat.Magnitude <= 1e-4 then Flat = Vector3.new(0, 0, -1) end
	local LandingLength = Length or Settings.LandingSize
	table.insert(Boxes, {
		Name = Name or 'Landing',
		CFrame = headingFrame(Position - Vector3.new(0, Settings.Thickness * 0.5, 0), Flat),
		Size = Vector3.new(Settings.Width, Settings.Thickness, LandingLength),
	})
end

local function landingDirection(Points, Index)
	local Point = Points[Index]
	if not Point then return Vector3.new(0, 0, -1) end
	local NextPoint = Points[Index + 1]
	if NextPoint then
		local NextFlat = Vector3.new(NextPoint.X - Point.X, 0, NextPoint.Z - Point.Z)
		if NextFlat.Magnitude > 1e-4 then return NextFlat.Unit end
	end
	local Previous = Points[Index - 1]
	if Previous then
		local PreviousFlat = Vector3.new(Point.X - Previous.X, 0, Point.Z - Previous.Z)
		if PreviousFlat.Magnitude > 1e-4 then return PreviousFlat.Unit end
	end
	return Vector3.new(0, 0, -1)
end

local function landingSupportAlong(Direction, LandingDirection, Settings)
	local Right = Vector3.new(-LandingDirection.Z, 0, LandingDirection.X)
	return math.abs(Direction:Dot(Right)) * Settings.Width * 0.5
		+ math.abs(Direction:Dot(LandingDirection)) * Settings.LandingSize * 0.5
end

local function segmentFlightEndpoints(Points, Segment, Settings)
	local RawA = Points[Segment]
	local RawB = Points[Segment + 1]
	local Flat = Vector3.new(RawB.X - RawA.X, 0, RawB.Z - RawA.Z)
	local Run = Flat.Magnitude
	if Run <= 1e-4 then return RawA, RawB end
	local Direction = Flat.Unit
	local StartTrim = 0
	local EndTrim = 0
	if Segment > 1 then
		StartTrim = landingSupportAlong(Direction, landingDirection(Points, Segment), Settings)
	end
	if Segment + 1 < #Points then
		EndTrim = landingSupportAlong(Direction, landingDirection(Points, Segment + 1), Settings)
	end
	local TotalTrim = StartTrim + EndTrim
	local MaxTrim = math.max(0, Run - 0.05)
	if TotalTrim > MaxTrim and TotalTrim > 1e-4 then
		local Scale = MaxTrim / TotalTrim
		StartTrim *= Scale
		EndTrim *= Scale
	end
	local AFlat = Vector3.new(RawA.X, 0, RawA.Z) + Direction * StartTrim
	local BFlat = Vector3.new(RawB.X, 0, RawB.Z) - Direction * EndTrim
	return Vector3.new(AFlat.X, RawA.Y, AFlat.Z), Vector3.new(BFlat.X, RawB.Y, BFlat.Z)
end

local function addFlightRailings(Boxes, A, B, Settings, FlightIndex)
	if not Settings.Railings then return end
	local Flat = Vector3.new(B.X - A.X, 0, B.Z - A.Z)
	if Flat.Magnitude <= 1e-4 then return end
	local Direction = Flat.Unit
	local Right = Vector3.new(-Direction.Z, 0, Direction.X)
	local SideDistance = math.max(0, Settings.Width * 0.5 - Settings.RailInset)
	local EndInset = math.min(Settings.RailThickness * 0.5, Flat.Magnitude * 0.25)

	for _, Side in ipairs({-1, 1}) do
		local SideName = Side < 0 and 'Left' or 'Right'
		local Offset = Right * SideDistance * Side
		local BaseA = A + Offset
		local BaseB = B + Offset

		local Skirt = raisedSkirtBox(
			string.format('Flight%d_%sSkirt', FlightIndex, SideName),
			BaseA,
			BaseB,
			Settings.RailThickness,
			Settings.SkirtHeight
		)
		if Skirt then table.insert(Boxes, Skirt) end

		local HandA = BaseA + Vector3.new(0, Settings.RailHeight, 0)
		local HandB = BaseB + Vector3.new(0, Settings.RailHeight, 0)
		local Handrail = clippedSlopeBeam(
			string.format('Flight%d_%sHandrail', FlightIndex, SideName),
			HandA,
			HandB,
			Settings.RailThickness,
			Settings.RailThickness
		)
		if Handrail then table.insert(Boxes, Handrail) end

		local PostBaseA = BaseA + Direction * EndInset
		local PostBaseB = BaseB - Direction * EndInset
		local PostTopA = HandA + Direction * EndInset
		local PostTopB = HandB - Direction * EndInset
		for Index = 1, Settings.RailPosts do
			local Alpha = (Index - 1) / (Settings.RailPosts - 1)
			local BasePoint = PostBaseA:Lerp(PostBaseB, Alpha)
			local TopPoint = PostTopA:Lerp(PostTopB, Alpha)
			local Height = math.max(0.05, TopPoint.Y - BasePoint.Y)
			table.insert(Boxes, {
				Name = string.format('Flight%d_%sPost', FlightIndex, SideName),
				CFrame = headingFrame((BasePoint + TopPoint) * 0.5, Direction),
				Size = Vector3.new(Settings.RailThickness, Height, Settings.RailThickness),
			})
		end
	end
end

local function stairBoxes(Self)
	local Points = Self.GeneratorPoints:GetPoints()
	if #Points < 2 then return nil, nil, 'Add at least two surface control points.' end
	local Settings = stairSettings(Self)
	local Boxes = {}
	local FlightCount = 0

	for Segment = 1, #Points - 1 do
		local A, B = segmentFlightEndpoints(Points, Segment, Settings)
		local Flat = Vector3.new(B.X - A.X, 0, B.Z - A.Z)
		local Run = Flat.Magnitude
		local Rise = B.Y - A.Y
		if Run > 0.01 then
			local Direction = Flat.Unit
			if math.abs(Rise) <= 0.05 then
				addLanding(Boxes, (A + B) * 0.5, Direction, Settings, 'PlatformSegment', Run)
			else
				FlightCount += 1
				local Low, High = A, B
				if B.Y < A.Y then Low, High = B, A end
				local FlightFlat = Vector3.new(High.X - Low.X, 0, High.Z - Low.Z)
				local FlightRun = FlightFlat.Magnitude
				local FlightDirection = FlightFlat.Unit
				local FlightRise = High.Y - Low.Y
				local StepRun = FlightRun / Settings.StepsPerFlight
				local StepRise = FlightRise / Settings.StepsPerFlight

				for Index = 1, Settings.StepsPerFlight do
					-- Overhang can overlap neighboring treads, but the first/last tread is
					-- clipped to the flight endpoint planes so the entire staircase stays flush.
					local StartDistance = math.max(0, StepRun * (Index - 1) - Settings.Overhang * 0.5)
					local EndDistance = math.min(FlightRun, StepRun * Index + Settings.Overhang * 0.5)
					local Depth = math.max(0.01, EndDistance - StartDistance)
					local Along = (StartDistance + EndDistance) * 0.5
					local CenterXZ = Vector3.new(Low.X, 0, Low.Z) + FlightDirection * Along
					local SizeY, CenterY
					if Settings.Floating then
						SizeY = Settings.Thickness
						CenterY = Low.Y + StepRise * Index - SizeY * 0.5
					else
						SizeY = StepRise * Index
						CenterY = Low.Y + SizeY * 0.5
					end
					table.insert(Boxes, {
						Name = string.format('Flight%d_Step', FlightCount),
						CFrame = headingFrame(Vector3.new(CenterXZ.X, CenterY, CenterXZ.Z), FlightDirection),
						Size = Vector3.new(Settings.Width, SizeY, Depth),
					})
				end

				addFlightRailings(Boxes, Low, High, Settings, FlightCount)
			end
		end
	end

	for Index = 2, #Points - 1 do
		local Point = Points[Index]
		local Direction = landingDirection(Points, Index)
		addLanding(Boxes, Point, Direction, Settings, 'TurnLanding_' .. Index, Settings.LandingSize)
	end

	return Boxes, Settings
end

local function previewFence(Self, Silent)
	local Boxes, _, Error = fenceBoxes(Self)
	if not Boxes then
		Self.Debug:Clear('PathFencePreview')
		if not Silent then Self:_setStatus(Error, false) end
		return
	end
	Self.ActivePathGenerator = 'Fence'
	drawBoxes(Self, 'PathFencePreview', Boxes, Theme.Color.AccentSoft)
	if not Silent then Self:_setStatus(string.format('Fence path preview: %d pieces.', #Boxes), true) end
end

local function previewStairs(Self, Silent)
	local Boxes, _, Error = stairBoxes(Self)
	if not Boxes then
		Self.Debug:Clear('PathStairPreview')
		if not Silent then Self:_setStatus(Error, false) end
		return
	end
	Self.ActivePathGenerator = 'Stairs'
	drawBoxes(Self, 'PathStairPreview', Boxes, Theme.Color.Accent)
	if not Silent then Self:_setStatus(string.format('Stair path preview: %d pieces.', #Boxes), true) end
end

local function clearOtherPreview(Self, Keep)
	if Keep ~= 'Fence' then Self.Debug:Clear('PathFencePreview') end
	if Keep ~= 'Stairs' then Self.Debug:Clear('PathStairPreview') end
end

local function clearGeneratorPreviews(Self)
	Self.ActivePathGenerator = nil
	Self.Debug:Clear('PathFencePreview')
	Self.Debug:Clear('PathStairPreview')
end

local function formatCoordinate(Value)
	if Value == nil then return '' end
	return string.format('%.4f', Value):gsub('0+$', ''):gsub('%.$', '')
end

local function refreshPointCoordinateUI(Self)
	if not Self.PathSelectedPoint or not Self.GeneratorPoints then return end
	local Index = Self.GeneratorPoints:GetSelectedIndex()
	local Position = Self.GeneratorPoints:GetSelectedPosition()
	if not Index or not Position then
		Self.PathSelectedPoint.Text = 'No attachment selected'
		Self.PathPointX.Text = ''
		Self.PathPointY.Text = ''
		Self.PathPointZ.Text = ''
		return
	end
	Self.PathSelectedPoint.Text = string.format('Point %d selected', Index)
	Self.PathPointX.Text = formatCoordinate(Position.X)
	Self.PathPointY.Text = formatCoordinate(Position.Y)
	Self.PathPointZ.Text = formatCoordinate(Position.Z)
end

local function refreshSurfaceUI(Self)
	if not Self.GeneratorSurfaceLabel then return end
	if Self.SurfaceTarget and Self.SurfaceTarget.Parent then
		Self.GeneratorSurfaceLabel.Text = string.format('%s · %s', Self.SurfaceTarget.Name, Self.SurfaceFace.Name)
	else
		Self.GeneratorSurfaceLabel.Text = 'No surface selected'
	end
end

local function updatePathStatus(Self)
	local Count = #Self.GeneratorPoints:GetPoints()
	local Selected = Self.GeneratorPoints:GetSelectedIndex()
	if Selected then
		Self.PathPointCount.Text = string.format('%d Terrain attachment%s · selected %d', Count, Count == 1 and '' or 's', Selected)
	else
		Self.PathPointCount.Text = string.format('%d Terrain attachment%s', Count, Count == 1 and '' or 's')
	end
	refreshPointCoordinateUI(Self)
	refreshSurfaceUI(Self)
end

local function applySelectedPointCoordinates(Self)
	local Position = Self.GeneratorPoints:GetSelectedPosition()
	if not Position then
		Self:_setStatus('Select a generator attachment first.', false)
		refreshPointCoordinateUI(Self)
		return
	end
	local X = tonumber(Self.PathPointX.Text) or Position.X
	local Y = tonumber(Self.PathPointY.Text) or Position.Y
	local Z = tonumber(Self.PathPointZ.Text) or Position.Z
	if Self.GeneratorPoints:SetSelectedPosition(Vector3.new(X, Y, Z)) then
		Self:_setStatus(string.format('Point %d position updated.', Self.GeneratorPoints:GetSelectedIndex()), true)
	end
	updatePathStatus(Self)
end

local function refreshActive(Self, Silent)
	updatePathStatus(Self)
	if Self.ActivePathGenerator == 'Fence' then
		previewFence(Self, Silent ~= false)
	elseif Self.ActivePathGenerator == 'Stairs' then
		previewStairs(Self, Silent ~= false)
	end
end

local function writeSettings(Model, Settings)
	for Name, Value in pairs(Settings) do Model:SetAttribute(Name, Value) end
end

local function generate(Self, TypeName, Boxes, Settings)
	local Points = Self.GeneratorPoints:GetPoints()
	local Model = Self.PathEditModel
	if not Model or not Model.Parent or Model:GetAttribute('FORGEBuilderType') ~= TypeName then
		Model = Instance.new('Model')
		Model.Name = TypeName == 'FencePath' and 'FORGE_FencePath' or 'FORGE_StairPath'
		Model.Parent = workspace
	end

	local Appearance = appearanceFrom(Model)
	clearGenerated(Model)
	Model:SetAttribute('FORGEBuilderType', TypeName)
	storePoints(Model, Points)
	writeSettings(Model, Settings)
	for Index, Box in ipairs(Boxes) do createPart(Model, Box, Appearance, Index) end
	Self.PathEditModel = Model
	SelectionService:Set({Model})
	return Model
end

local function generateFence(Self)
	local Boxes, Settings, Error = fenceBoxes(Self)
	if not Boxes then Self:_setStatus(Error, false) return end
	Self:_record('Generate Fence Path', function() generate(Self, 'FencePath', Boxes, Settings) end)
	clearGeneratorPreviews(Self)
	Self:_setStatus('Fence path generated. Preview cleared; Terrain attachments remain editable.', true)
end

local function generateStairs(Self)
	local Boxes, Settings, Error = stairBoxes(Self)
	if not Boxes then Self:_setStatus(Error, false) return end
	Self:_record('Generate Stair Path', function() generate(Self, 'StairsPath', Boxes, Settings) end)
	clearGeneratorPreviews(Self)
	Self:_setStatus('Multi-flight stairs generated. Preview cleared; Terrain attachments remain editable.', true)
end

local function boolAttribute(Model, Name, Default)
	local Value = Model:GetAttribute(Name)
	return typeof(Value) == 'boolean' and Value or Default
end

local function numberAttribute(Model, Name, Default)
	local Value = Model:GetAttribute(Name)
	return typeof(Value) == 'number' and Value or Default
end

local function loadGeneratedPath(Self)
	local Selected = SelectionService:Get()
	local Model = Selected[1]
	if not Model or not Model:IsA('Model') then
		Self:_setStatus('Select a generated FORGE fence/stair path.', false)
		return false
	end
	local TypeName = Model:GetAttribute('FORGEBuilderType')
	if TypeName ~= 'FencePath' and TypeName ~= 'StairsPath' then
		Self:_setStatus('Selected model is not an editable FORGE path.', false)
		return false
	end
	local Points = loadPoints(Model)
	if not Points then
		Self:_setStatus('Generated path has no stored control points.', false)
		return false
	end

	Self.PathEditModel = Model
	Self.GeneratorPoints:SetPoints(Points, firstBasePart(Model))
	if TypeName == 'FencePath' then
		Self.PathFencePosts.Text = tostring(numberAttribute(Model, 'PostsPerSegment', 8))
		Self.PathFenceHeight.Text = tostring(numberAttribute(Model, 'Height', 2.5))
		Self.PathFencePostWidth.Text = tostring(numberAttribute(Model, 'PostWidth', 0.18))
		Self.PathFencePostDepth.Text = tostring(numberAttribute(Model, 'PostDepth', 0.18))
		Self.PathFenceRailThickness.Text = tostring(numberAttribute(Model, 'RailThickness', 0.18))
		Self.PathFenceRailDepth.Text = tostring(numberAttribute(Model, 'RailDepth', 0.22))
		Self.PathFenceTop = boolAttribute(Model, 'Top', true)
		Self.PathFenceMiddle = boolAttribute(Model, 'Middle', false)
		Self.PathFenceBottom = boolAttribute(Model, 'Bottom', true)
		Self.ActivePathGenerator = 'Fence'
	else
		Self.PathStairSteps.Text = tostring(numberAttribute(Model, 'StepsPerFlight', 12))
		Self.PathStairWidth.Text = tostring(numberAttribute(Model, 'Width', 8))
		Self.PathStairThickness.Text = tostring(numberAttribute(Model, 'Thickness', 0.5))
		Self.PathStairOverhang.Text = tostring(numberAttribute(Model, 'Overhang', 0))
		Self.PathStairLandingSize.Text = tostring(numberAttribute(Model, 'LandingSize', 8))
		Self.PathStairFloating = boolAttribute(Model, 'Floating', false)
		Self.PathStairRailings = boolAttribute(Model, 'Railings', true)
		Self.PathStairRailHeight.Text = tostring(numberAttribute(Model, 'RailHeight', 3))
		Self.PathStairRailThickness.Text = tostring(numberAttribute(Model, 'RailThickness', 0.18))
		Self.PathStairRailPosts.Text = tostring(numberAttribute(Model, 'RailPosts', 5))
		Self.PathStairRailInset.Text = tostring(numberAttribute(Model, 'RailInset', 0.08))
		Self.PathStairSkirtHeight.Text = tostring(numberAttribute(Model, 'SkirtHeight', 1.25))
		Self.ActivePathGenerator = 'Stairs'
	end
	Self:_refreshGeneratorButtons()
	clearOtherPreview(Self, Self.ActivePathGenerator)
	refreshActive(Self, false)
	Self:_setStatus('Loaded generated path. Terrain attachments recreated and ready to move.', true)
	return true
end

local function duplicateSelection(Self, Delta)
	local Roots = selectionRoots()
	if #Roots == 0 then Self:_setStatus('Select one or more Parts/Models to duplicate.', false) return end
	Self:_record('Duplicate With Offset', function()
		local NewSelection = {}
		for _, Object in ipairs(Roots) do
			local Clone = Object:Clone()
			Clone.Name = Object.Name
			Clone.Parent = Object.Parent
			Clone:PivotTo(CFrame.new(Delta) * getPivot(Object))
			table.insert(NewSelection, Clone)
		end
		SelectionService:Set(NewSelection)
	end)
	Self.LastDuplicateDelta = Delta
end

local function disconnectList(List)
	for _, Connection in ipairs(List) do Connection:Disconnect() end
	table.clear(List)
end

local function scheduleBasePreviewRefresh(Self)
	if Self.GeneratorBaseRefreshQueued then return end
	Self.GeneratorBaseRefreshQueued = true
	task.defer(function()
		Self.GeneratorBaseRefreshQueued = false
		if not Self.Root or not Self.Root.Parent then return end
		if Self.ActiveBasePreview == 'Array' then
			Self:_previewArray()
		elseif Self.ActiveBasePreview == 'Grid' then
			Self:_previewGrid()
		end
	end)
end

local function bindMovable(Self, Object, List)
	if not Object then return end
	local function watch(Part)
		if not Part:IsA('BasePart') then return end
		table.insert(List, Part:GetPropertyChangedSignal('CFrame'):Connect(function() scheduleBasePreviewRefresh(Self) end))
		table.insert(List, Part:GetPropertyChangedSignal('Size'):Connect(function() scheduleBasePreviewRefresh(Self) end))
	end
	if Object:IsA('BasePart') then
		watch(Object)
	elseif Object:IsA('Model') then
		for _, Descendant in ipairs(Object:GetDescendants()) do watch(Descendant) end
		table.insert(List, Object.DescendantAdded:Connect(function(Descendant)
			if Descendant:IsA('BasePart') then watch(Descendant) scheduleBasePreviewRefresh(Self) end
		end))
	end
end

local function rebindPairWatch(Self)
	disconnectList(Self.GeneratorPairConnections)
	bindMovable(Self, Self.PairA, Self.GeneratorPairConnections)
	bindMovable(Self, Self.PairB, Self.GeneratorPairConnections)
end

local function rebindSurfaceWatch(Self)
	disconnectList(Self.GeneratorSurfaceConnections)
	bindMovable(Self, Self.SurfaceTarget, Self.GeneratorSurfaceConnections)
end

local function hideLegacySurfaceSection(Self, Scroll)
	for _, Child in ipairs(Scroll:GetChildren()) do
		if Child:IsA('Frame') then
			for _, Descendant in ipairs(Child:GetDescendants()) do
				if Descendant:IsA('TextLabel') and Descendant.Text == 'SURFACE CENTER / PLACEMENT' then
					Child.Visible = false
					break
				end
			end
		end
	end
end

local function installUI(Self)
	local Scroll = Self.Root:FindFirstChildWhichIsA('ScrollingFrame')
	if not Scroll then error('FORGE Builder scrolling root not found.') end

	for _, Descendant in ipairs(Self.Root:GetDescendants()) do
		if Descendant:IsA('TextLabel') and string.find(Descendant.Text, 'Q1 + Q2', 1, true) then
			Descendant.Text = 'surface · attachments · generators · placement · arrays'
			break
		end
	end

	if Self.SelectionLabel and Self.SelectionLabel.Parent then
		Self.SelectionLabel.Parent.LayoutOrder = -110
	end
	hideLegacySurfaceSection(Self, Scroll)

	local Surface = section(Scroll, 'Surface', -100)
	label(Surface, 'Select a face once, then Add Point places a Terrain attachment at its exact center.', 34, true).TextSize = 11
	Self.GeneratorSurfaceLabel = label(Surface, 'No surface selected', 20, true)
	local SurfaceCapture = row(Surface)
	Self.GeneratorPickSurface = button(SurfaceCapture, 'Pick Surface', 0.5)
	Self.GeneratorUseSelectedSurface = button(SurfaceCapture, 'Use Selected', 0.5)
	label(Surface, 'FACE', 16, true).TextSize = 10
	local SurfaceFaceRow = row(Surface)
	Self.GeneratorSurfaceFaceButtons = {}
	for _, Entry in ipairs(FACE_ORDER) do
		local FaceButton = button(SurfaceFaceRow, Entry[1], 1 / #FACE_ORDER)
		Self.GeneratorSurfaceFaceButtons[Entry[2]] = FaceButton
	end
	Self.PathAddPoint = button(Surface, 'Add Point At Surface Center')
	local SurfacePlaceRow = row(Surface)
	Self.GeneratorSurfaceCenterSelection = button(SurfacePlaceRow, 'Center Selection', 0.5)
	Self.GeneratorSurfaceFlushSelection = button(SurfacePlaceRow, 'Flush Selection', 0.5)

	local Path = section(Scroll, 'Control Points', -90)
	label(Path, 'Real Attachments under Terrain. Select/move them with normal Roblox Studio tools.', 32, true).TextSize = 11
	Self.PathPointCount = label(Path, '0 Terrain attachments', 18, true)
	Self.PathPointCount.TextSize = 11
	local PathActions = row(Path)
	Self.PathRemovePoint = button(PathActions, 'Remove Last', 0.5)
	Self.PathClearPoints = button(PathActions, 'Clear All', 0.5)
	Self.PathLoadSelected = button(Path, 'Load / Edit Selected Generated Path')

	label(Path, 'SELECTED ATTACHMENT POSITION', 16, true).TextSize = 10
	Self.PathSelectedPoint = label(Path, 'No attachment selected', 18, true)
	Self.PathSelectedPoint.TextSize = 11
	local AxisLabels = row(Path, 16)
	for _, Axis in ipairs({'X', 'Y', 'Z'}) do
		local AxisLabel = label(AxisLabels, Axis, 16, true)
		AxisLabel.Size = UDim2.new(1 / 3, -3, 0, 16)
		AxisLabel.TextXAlignment = Enum.TextXAlignment.Center
		AxisLabel.TextSize = 10
	end
	local CoordinateRow = row(Path)
	Self.PathPointX = textBox(CoordinateRow, '', 1 / 3)
	Self.PathPointY = textBox(CoordinateRow, '', 1 / 3)
	Self.PathPointZ = textBox(CoordinateRow, '', 1 / 3)
	Self.PathPointX.PlaceholderText = 'X'
	Self.PathPointY.PlaceholderText = 'Y'
	Self.PathPointZ.PlaceholderText = 'Z'

	local Fence = section(Scroll, 'Fence Generator', -80)
	label(Fence, 'Every consecutive Terrain attachment pair becomes one fence segment.', 24, true).TextSize = 11
	local FR1 = row(Fence)
	local L = label(FR1, 'Posts/seg', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathFencePosts = textBox(FR1, '8', 0.28)
	L = label(FR1, 'Height', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathFenceHeight = textBox(FR1, '2.5', 0.28)
	local FR2 = row(Fence)
	L = label(FR2, 'Post W', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathFencePostWidth = textBox(FR2, '0.18', 0.28)
	L = label(FR2, 'Post D', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathFencePostDepth = textBox(FR2, '0.18', 0.28)
	local FR3 = row(Fence)
	L = label(FR3, 'Rail T', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathFenceRailThickness = textBox(FR3, '0.18', 0.28)
	L = label(FR3, 'Rail D', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathFenceRailDepth = textBox(FR3, '0.22', 0.28)
	local FToggle = row(Fence)
	Self.PathFenceTopButton = button(FToggle, '■ Top', 0.34)
	Self.PathFenceMiddleButton = button(FToggle, '□ Mid', 0.33)
	Self.PathFenceBottomButton = button(FToggle, '■ Bottom', 0.33)
	local FActions = row(Fence)
	Self.PathFencePreview = button(FActions, 'Preview', 0.42)
	Self.PathFenceGenerate = button(FActions, 'Generate / Apply', 0.58)

	local Stairs = section(Scroll, 'Stair Generator', -70)
	label(Stairs, '2 points = one flight. 3+ points = directional flights with automatic landings.', 34, true).TextSize = 11
	local Presets = row(Stairs)
	Self.PathStairNormalPreset = button(Presets, 'Normal', 0.34)
	Self.PathStairWidePreset = button(Presets, 'Wide', 0.33)
	Self.PathStairFloatingPreset = button(Presets, 'Floating', 0.33)
	local SR1 = row(Stairs)
	L = label(SR1, 'Steps/flight', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathStairSteps = textBox(SR1, '12', 0.28)
	L = label(SR1, 'Width', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathStairWidth = textBox(SR1, '8', 0.28)
	local SR2 = row(Stairs)
	L = label(SR2, 'Tread T', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathStairThickness = textBox(SR2, '0.5', 0.28)
	L = label(SR2, 'Overhang', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathStairOverhang = textBox(SR2, '0', 0.28)
	local SR3 = row(Stairs)
	L = label(SR3, 'Landing', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathStairLandingSize = textBox(SR3, '8', 0.28)
	Self.PathStairStyleButton = button(SR3, 'Solid Blocks', 0.5)

	label(Stairs, 'RAILING / SIDE SKIRT', 16, true).TextSize = 10
	Self.PathStairRailButton = button(Stairs, 'Railings: On')
	local RR1 = row(Stairs)
	L = label(RR1, 'Rail H', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathStairRailHeight = textBox(RR1, '3', 0.28)
	L = label(RR1, 'Rail T', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathStairRailThickness = textBox(RR1, '0.18', 0.28)
	local RR2 = row(Stairs)
	L = label(RR2, 'Posts', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathStairRailPosts = textBox(RR2, '5', 0.28)
	L = label(RR2, 'Inset', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathStairRailInset = textBox(RR2, '0.08', 0.28)
	local RR3 = row(Stairs)
	L = label(RR3, 'Skirt H', 30, true); L.Size = UDim2.new(0.22, -3, 0, 30)
	Self.PathStairSkirtHeight = textBox(RR3, '1.25', 0.28)
	label(RR3, 'covers step blocks', 30, true).Size = UDim2.new(0.5, -3, 0, 30)
	local SActions = row(Stairs)
	Self.PathStairPreview = button(SActions, 'Preview', 0.42)
	Self.PathStairGenerate = button(SActions, 'Generate / Apply', 0.58)

	local Workflow = section(Scroll, 'Generated / Workflow', -60)
	local EditRow = row(Workflow)
	Self.EditGeneratedButton = button(EditRow, 'Edit Selected Generated', 0.7)
	Self.FinishEditButton = button(EditRow, 'Finish Edit', 0.3)
	label(Workflow, 'QUICK DUPLICATE OFFSET', 16, true).TextSize = 10
	local DupRow = row(Workflow)
	Self.DupX = textBox(DupRow, '0', 0.26)
	Self.DupY = textBox(DupRow, '0', 0.26)
	Self.DupZ = textBox(DupRow, '4', 0.26)
	Self.DuplicateButton = button(DupRow, 'Dup', 0.22)
	Self.RepeatDuplicateButton = button(Workflow, 'Repeat Last Duplicate Offset')
end

local function installConnections(Self)
	Self:_connect(Self.GeneratorPickSurface.MouseButton1Click, function()
		Self:_beginSurfacePick()
	end)
	Self:_connect(Self.GeneratorUseSelectedSurface.MouseButton1Click, function()
		Self:_captureSelectedSurfaceTarget()
		refreshSurfaceUI(Self)
		rebindSurfaceWatch(Self)
	end)
	for Face, FaceButton in pairs(Self.GeneratorSurfaceFaceButtons) do
		Self:_connect(FaceButton.MouseButton1Click, function()
			Self:_setFace(Face)
			refreshSurfaceUI(Self)
		end)
	end
	Self:_connect(Self.Mouse.Button1Down, function()
		if Self.PickingSurface then
			task.defer(function()
				refreshSurfaceUI(Self)
				rebindSurfaceWatch(Self)
			end)
		end
	end)
	Self:_connect(Self.PathAddPoint.MouseButton1Click, function()
		local Position, _, Error = Self:_surfacePosition(0)
		if not Position then
			Self:_setStatus(Error or 'Select a surface first.', false)
			return
		end
		local Index = Self.GeneratorPoints:AddPoint(Position, Self.SurfaceTarget)
		if Index then
			Self:_setStatus(string.format('Point %d added at the exact center of %s / %s.', Index, Self.SurfaceTarget.Name, Self.SurfaceFace.Name), true)
		end
	end)
	Self:_connect(Self.GeneratorSurfaceCenterSelection.MouseButton1Click, function()
		Self.SurfaceOffset.Text = '0'
		Self:_placeAtSurface(false)
	end)
	Self:_connect(Self.GeneratorSurfaceFlushSelection.MouseButton1Click, function()
		Self.SurfaceOffset.Text = '0'
		Self:_placeAtSurface(true)
	end)

	Self:_connect(Self.PathRemovePoint.MouseButton1Click, function() Self.GeneratorPoints:RemoveLast() end)
	Self:_connect(Self.PathClearPoints.MouseButton1Click, function()
		Self.GeneratorPoints:Clear()
		Self.PathEditModel = nil
		clearGeneratorPreviews(Self)
		updatePathStatus(Self)
	end)
	Self:_connect(Self.PathLoadSelected.MouseButton1Click, function() loadGeneratedPath(Self) end)

	for _, CoordinateBox in ipairs({Self.PathPointX, Self.PathPointY, Self.PathPointZ}) do
		Self:_connect(CoordinateBox.FocusLost, function()
			applySelectedPointCoordinates(Self)
		end)
	end

	local function fenceRefresh()
		Self.ActivePathGenerator = 'Fence'
		clearOtherPreview(Self, 'Fence')
		previewFence(Self, false)
	end
	for _, Box in ipairs({Self.PathFencePosts, Self.PathFenceHeight, Self.PathFencePostWidth, Self.PathFencePostDepth, Self.PathFenceRailThickness, Self.PathFenceRailDepth}) do
		Self:_connect(Box.FocusLost, fenceRefresh)
	end
	Self:_connect(Self.PathFenceTopButton.MouseButton1Click, function() Self.PathFenceTop = not Self.PathFenceTop Self:_refreshGeneratorButtons() fenceRefresh() end)
	Self:_connect(Self.PathFenceMiddleButton.MouseButton1Click, function() Self.PathFenceMiddle = not Self.PathFenceMiddle Self:_refreshGeneratorButtons() fenceRefresh() end)
	Self:_connect(Self.PathFenceBottomButton.MouseButton1Click, function() Self.PathFenceBottom = not Self.PathFenceBottom Self:_refreshGeneratorButtons() fenceRefresh() end)
	Self:_connect(Self.PathFencePreview.MouseButton1Click, fenceRefresh)
	Self:_connect(Self.PathFenceGenerate.MouseButton1Click, function() Self.ActivePathGenerator = 'Fence' generateFence(Self) end)

	local function stairRefresh()
		Self.ActivePathGenerator = 'Stairs'
		clearOtherPreview(Self, 'Stairs')
		previewStairs(Self, false)
	end
	for _, Box in ipairs({Self.PathStairSteps, Self.PathStairWidth, Self.PathStairThickness, Self.PathStairOverhang, Self.PathStairLandingSize, Self.PathStairRailHeight, Self.PathStairRailThickness, Self.PathStairRailPosts, Self.PathStairRailInset, Self.PathStairSkirtHeight}) do
		Self:_connect(Box.FocusLost, stairRefresh)
	end
	Self:_connect(Self.PathStairStyleButton.MouseButton1Click, function() Self.PathStairFloating = not Self.PathStairFloating Self:_refreshGeneratorButtons() stairRefresh() end)
	Self:_connect(Self.PathStairRailButton.MouseButton1Click, function() Self.PathStairRailings = not Self.PathStairRailings Self:_refreshGeneratorButtons() stairRefresh() end)
	Self:_connect(Self.PathStairPreview.MouseButton1Click, stairRefresh)
	Self:_connect(Self.PathStairGenerate.MouseButton1Click, function() Self.ActivePathGenerator = 'Stairs' generateStairs(Self) end)

	Self:_connect(Self.PathStairNormalPreset.MouseButton1Click, function()
		Self.PathStairSteps.Text, Self.PathStairWidth.Text, Self.PathStairThickness.Text, Self.PathStairOverhang.Text = '12', '8', '0.5', '0'
		Self.PathStairLandingSize.Text = '8'
		Self.PathStairFloating = false
		Self:_refreshGeneratorButtons()
		stairRefresh()
	end)
	Self:_connect(Self.PathStairWidePreset.MouseButton1Click, function()
		Self.PathStairSteps.Text, Self.PathStairWidth.Text, Self.PathStairThickness.Text, Self.PathStairOverhang.Text = '12', '12', '0.5', '0'
		Self.PathStairLandingSize.Text = '12'
		Self.PathStairFloating = false
		Self:_refreshGeneratorButtons()
		stairRefresh()
	end)
	Self:_connect(Self.PathStairFloatingPreset.MouseButton1Click, function()
		Self.PathStairSteps.Text, Self.PathStairWidth.Text, Self.PathStairThickness.Text, Self.PathStairOverhang.Text = '12', '8', '0.35', '0.15'
		Self.PathStairLandingSize.Text = '8'
		Self.PathStairFloating = true
		Self:_refreshGeneratorButtons()
		stairRefresh()
	end)

	Self:_connect(Self.EditGeneratedButton.MouseButton1Click, function() loadGeneratedPath(Self) end)
	Self:_connect(Self.FinishEditButton.MouseButton1Click, function()
		Self.PathEditModel = nil
		clearGeneratorPreviews(Self)
		Self:_setStatus('Generated path edit mode cleared. Terrain attachments remain available.', true)
	end)
	Self:_connect(Self.DuplicateButton.MouseButton1Click, function()
		duplicateSelection(Self, Vector3.new(parseNumber(Self.DupX, 0), parseNumber(Self.DupY, 0), parseNumber(Self.DupZ, 4)))
	end)
	Self:_connect(Self.RepeatDuplicateButton.MouseButton1Click, function()
		duplicateSelection(Self, Self.LastDuplicateDelta or Vector3.new(0, 0, 4))
	end)

	Self:_connect(Self.CapturePairButton.MouseButton1Click, function()
		task.defer(function() rebindPairWatch(Self) scheduleBasePreviewRefresh(Self) end)
	end)
	Self:_connect(Self.UseSelectedTargetButton.MouseButton1Click, function()
		task.defer(function() rebindSurfaceWatch(Self) scheduleBasePreviewRefresh(Self) end)
	end)
	for _, Button in ipairs({Self.ArrayPreviewButton, Self.ArrayModeButton, Self.ArrayStartButton, Self.ArrayEndButton}) do
		Self:_connect(Button.MouseButton1Click, function() Self.ActiveBasePreview = 'Array' end)
	end
	for _, Box in ipairs({Self.ArrayCount, Self.ArraySpacing}) do
		Self:_connect(Box.FocusLost, function() Self.ActiveBasePreview = 'Array' end)
	end
	Self:_connect(Self.ArrayGenerateButton.MouseButton1Click, function() Self.ActiveBasePreview = nil end)
	Self:_connect(Self.GridPreviewButton.MouseButton1Click, function() Self.ActiveBasePreview = 'Grid' rebindSurfaceWatch(Self) end)
	Self:_connect(Self.GridFrameButton.MouseButton1Click, function() Self.ActiveBasePreview = 'Grid' rebindSurfaceWatch(Self) end)
	for _, Box in ipairs({Self.GridColumns, Self.GridRows, Self.GridThickness, Self.GridDepth, Self.GridMargin, Self.GridOffset}) do
		Self:_connect(Box.FocusLost, function() Self.ActiveBasePreview = 'Grid' rebindSurfaceWatch(Self) end)
	end
	Self:_connect(Self.GridGenerateButton.MouseButton1Click, function() Self.ActiveBasePreview = nil end)

	Self:_connect(Self.ClearDebugButton.MouseButton1Click, function()
		task.defer(function()
			if Self.GeneratorPoints then Self.GeneratorPoints:Draw() end
			refreshActive(Self, true)
		end)
	end)
end

local function install(Self)
	Self.PathFenceTop = true
	Self.PathFenceMiddle = false
	Self.PathFenceBottom = true
	Self.PathStairFloating = false
	Self.PathStairRailings = true
	Self.PathEditModel = nil
	Self.ActivePathGenerator = nil
	Self.LastDuplicateDelta = Vector3.new(0, 0, 4)
	Self.ActiveBasePreview = nil
	Self.GeneratorPairConnections = {}
	Self.GeneratorSurfaceConnections = {}
	Self.GeneratorBaseRefreshQueued = false

	installUI(Self)

	Self.GeneratorPoints = GeneratorControlPoints.new(Self.Mouse, Self.Debug, {
		Channel = 'GeneratorControlPoints',
		LineColor = Theme.Color.AccentSoft,
		OnStatus = function(Text, Good) Self:_setStatus(Text, Good) end,
		OnChanged = function()
			if not Self.Root or not Self.Root.Parent then return end
			refreshActive(Self, true)
		end,
		OnSelectionChanged = function()
			if not Self.Root or not Self.Root.Parent then return end
			updatePathStatus(Self)
		end,
	})

	function Self:_refreshGeneratorButtons()
		self.PathFenceTopButton.Text = (self.PathFenceTop and '■ ' or '□ ') .. 'Top'
		self.PathFenceMiddleButton.Text = (self.PathFenceMiddle and '■ ' or '□ ') .. 'Mid'
		self.PathFenceBottomButton.Text = (self.PathFenceBottom and '■ ' or '□ ') .. 'Bottom'
		self.PathStairStyleButton.Text = self.PathStairFloating and 'Floating Treads' or 'Solid Blocks'
		self.PathStairRailButton.Text = self.PathStairRailings and 'Railings: On' or 'Railings: Off'
		refreshPointCoordinateUI(self)
		refreshSurfaceUI(self)
	end

	Self:_refreshGeneratorButtons()
	updatePathStatus(Self)
	installConnections(Self)
	rebindPairWatch(Self)
	rebindSurfaceWatch(Self)

	local BaseDestroy = Self.Destroy
	Self.Destroy = function(Instance)
		disconnectList(Instance.GeneratorPairConnections)
		disconnectList(Instance.GeneratorSurfaceConnections)
		if Instance.GeneratorPoints then Instance.GeneratorPoints:Destroy() end
		BaseDestroy(Instance)
	end
	return Self
end

function BuilderGenerators.wrap(BaseBuilder)
	local Wrapped = {}
	function Wrapped.new(Plugin, Widget, Options)
		local Self = BaseBuilder.new(Plugin, Widget, Options)
		return install(Self)
	end
	return Wrapped
end

BuilderGenerators.install = install

return BuilderGenerators
