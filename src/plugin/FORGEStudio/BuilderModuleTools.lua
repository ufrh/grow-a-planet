local StudioSelection = game.Selection

local Theme = require(script.Parent.Theme)

local BuilderModuleTools = {}

local ATTACHMENT_AXIS_HALF_LENGTH = 512
local ATTACHMENT_AXIS_COLORS = {
	X = Color3.fromRGB(235, 88, 88),
	Y = Color3.fromRGB(92, 220, 120),
	Z = Color3.fromRGB(88, 145, 235),
}

local function styleButton(Button)
	Button.AutoButtonColor = false
	Button.BackgroundColor3 = Theme.Color.FaceLight
	Button.TextColor3 = Theme.Color.Text
	Button.TextSize = 13
	Button.FontFace = Theme.FontFaceMedium

	local Corner = Instance.new('UICorner')
	Corner.CornerRadius = UDim.new(0, 5)
	Corner.Parent = Button

	local Stroke = Instance.new('UIStroke')
	Stroke.Thickness = 1
	Stroke.Color = Theme.Color.AccentMuted
	Stroke.Transparency = 0.35
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Stroke.Parent = Button

	Button.MouseEnter:Connect(function()
		Button.BackgroundColor3 = Theme.Color.AccentMuted
	end)
	Button.MouseLeave:Connect(function()
		Button.BackgroundColor3 = Theme.Color.FaceLight
	end)
end

local function makeButton(Parent, Name, Text, LayoutOrder)
	local Button = Instance.new('TextButton')
	Button.Name = Name
	Button.Size = UDim2.new(1, 0, 0, 30)
	Button.Text = Text
	Button.LayoutOrder = LayoutOrder or 0
	Button.Parent = Parent
	styleButton(Button)
	return Button
end

local function makeAxisToggleRow(Parent)
	local Row = Instance.new('Frame')
	Row.Name = 'FORGEBuilder_AttachmentAxisGuides'
	Row.BackgroundTransparency = 1
	Row.Size = UDim2.new(1, 0, 0, 30)
	Row.LayoutOrder = -106
	Row.Parent = Parent

	local Layout = Instance.new('UIListLayout')
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center
	Layout.Padding = UDim.new(0, 6)
	Layout.Parent = Row

	local Buttons = {}
	for Index, Axis in ipairs({'X', 'Y', 'Z'}) do
		local Button = Instance.new('TextButton')
		Button.Name = 'FORGEBuilder_AttachmentAxis_' .. Axis
		Button.Size = UDim2.new(1 / 3, -4, 1, 0)
		Button.LayoutOrder = Index
		Button.Text = '□ ' .. Axis
		Button.Parent = Row
		styleButton(Button)
		Buttons[Axis] = Button
	end

	return Row, Buttons
end

local function centerCFrame(Object)
	if Object:IsA('BasePart') then
		return Object.CFrame
	end
	if Object:IsA('Model') then
		local CFrameValue = Object:GetBoundingBox()
		return CFrameValue
	end
	return nil
end

local function isInsideModel(Object, Model)
	return Object == Model or Object:IsDescendantOf(Model)
end

local function findCommonParentModel(A, B, C)
	local Node = A.Parent
	while Node and Node ~= game do
		if Node:IsA('Model') and isInsideModel(B, Node) and isInsideModel(C, Node) then
			return Node
		end
		Node = Node.Parent
	end
	return nil
end

local function getOrCreateSocketRoot(Model)
	local Existing = Model:FindFirstChild('DoorwaySockets')
	if Existing then
		if not Existing:IsA('Folder') then
			error('model.DoorwaySockets already exists but is not a Folder.')
		end
		return Existing
	end

	local Root = Instance.new('Folder')
	Root.Name = 'DoorwaySockets'
	Root.Parent = Model
	return Root
end

local function createDoorSocket(Self)
	local Selected = StudioSelection:Get()
	if #Selected ~= 3 then
		Self:_setStatus('Select exactly 3 objects: pillar 1, pillar 2, then wall/depth reference.', false)
		return
	end

	local A, B, DepthReference = Selected[1], Selected[2], Selected[3]
	local ACFrame = centerCFrame(A)
	local BCFrame = centerCFrame(B)
	local DepthCFrame = centerCFrame(DepthReference)
	if not ACFrame or not BCFrame or not DepthCFrame then
		Self:_setStatus('Door socket selection must contain only Parts or Models.', false)
		return
	end

	local ParentModel = findCommonParentModel(A, B, DepthReference)
	if not ParentModel then
		Self:_setStatus('The 3 selected objects must share a parent Model.', false)
		return
	end

	local AP = ACFrame.Position
	local BP = BCFrame.Position
	local DP = DepthCFrame.Position
	local Position = Vector3.new(
		(AP.X + BP.X) * 0.5,
		(AP.Y + BP.Y) * 0.5,
		DP.Z
	)
	local WorldCFrame = CFrame.new(Position) * DepthCFrame.Rotation

	local Created
	Self:_record('Create Door Socket', function()
		local Root = getOrCreateSocketRoot(ParentModel)
		local Attachment = Instance.new('Attachment')
		Attachment.Name = 'DoorSocket'
		Attachment.Visible = true
		Attachment:SetAttribute('FORGEDoorwaySocket', true)
		Attachment.Parent = Root
		Attachment.WorldCFrame = WorldCFrame
		Created = Attachment
		StudioSelection:Set({Attachment})
	end)

	if Created then
		Self:_setStatus(string.format('DoorSocket created in %s.DoorwaySockets.', ParentModel.Name), true)
	end
end

local function attachmentGuideAnchor(Attachment)
	if not Attachment or not Attachment:IsA('Attachment') then return nil end
	local Parent = Attachment.Parent
	if Parent and Parent:IsA('BasePart') then return Parent end
	local Ancestor = Attachment:FindFirstAncestorWhichIsA('BasePart')
	if Ancestor then return Ancestor end

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

local function installAttachmentAxisGuides(Self, Scroll)
	-- Builder.lua still owns the old combined X/Y helper. Keep its state disabled,
	-- but move its button out of the scrolling layout so this wrapper can expose
	-- independent X/Y/Z controls without the old control taking up space.
	if Self.AttachmentAxisGuidesButton then
		Self.AttachmentAxisGuidesEnabled = false
		Self.AttachmentAxisGuidesButton.Visible = false
		Self.AttachmentAxisGuidesButton.Size = UDim2.fromOffset(0, 0)
		Self.AttachmentAxisGuidesButton.Parent = Self.Root
	end

	Self.ModuleAttachmentAxisEnabled = {
		X = false,
		Y = false,
		Z = false,
	}
	Self.ModuleAttachmentAxisAlwaysOnTop = false
	Self.ModuleAttachmentAxisConnections = {}
	Self.ModuleAttachmentAxisRefreshQueued = false

	local _, AxisButtons = makeAxisToggleRow(Scroll)
	Self.AttachmentAxisXButton = AxisButtons.X
	Self.AttachmentAxisYButton = AxisButtons.Y
	Self.AttachmentAxisZButton = AxisButtons.Z
	Self.AttachmentAxisAlwaysOnTopButton = makeButton(
		Scroll,
		'FORGEBuilder_AttachmentAxisAlwaysOnTop',
		'□ Attachment Guides Always On Top',
		-105
	)

	local function anyAxisEnabled()
		return Self.ModuleAttachmentAxisEnabled.X
			or Self.ModuleAttachmentAxisEnabled.Y
			or Self.ModuleAttachmentAxisEnabled.Z
	end

	local function enabledAxisText()
		local Names = {}
		for _, Axis in ipairs({'X', 'Y', 'Z'}) do
			if Self.ModuleAttachmentAxisEnabled[Axis] then table.insert(Names, Axis) end
		end
		return #Names > 0 and table.concat(Names, '/') or 'none'
	end

	local function refreshButtons()
		for Axis, Button in pairs(AxisButtons) do
			Button.Text = (Self.ModuleAttachmentAxisEnabled[Axis] and '■ ' or '□ ') .. Axis
		end
		Self.AttachmentAxisAlwaysOnTopButton.Text =
			(Self.ModuleAttachmentAxisAlwaysOnTop and '■ ' or '□ ') .. 'Attachment Guides Always On Top'
	end

	local function disconnectGuideConnections()
		for _, Connection in ipairs(Self.ModuleAttachmentAxisConnections) do
			Connection:Disconnect()
		end
		table.clear(Self.ModuleAttachmentAxisConnections)
	end

	local drawGuides
	local function queueGuideRefresh()
		if Self.ModuleAttachmentAxisRefreshQueued then return end
		Self.ModuleAttachmentAxisRefreshQueued = true
		task.defer(function()
			Self.ModuleAttachmentAxisRefreshQueued = false
			if Self.Root and Self.Root.Parent and drawGuides then drawGuides() end
		end)
	end

	local function bindSelectedAttachments()
		disconnectGuideConnections()
		if not anyAxisEnabled() then return end
		for _, Attachment in ipairs(selectedAttachments()) do
			table.insert(Self.ModuleAttachmentAxisConnections, Attachment:GetPropertyChangedSignal('CFrame'):Connect(queueGuideRefresh))
			table.insert(Self.ModuleAttachmentAxisConnections, Attachment:GetPropertyChangedSignal('WorldCFrame'):Connect(queueGuideRefresh))
			table.insert(Self.ModuleAttachmentAxisConnections, Attachment.AncestryChanged:Connect(queueGuideRefresh))
			local Parent = Attachment.Parent
			if Parent and Parent:IsA('BasePart') then
				table.insert(Self.ModuleAttachmentAxisConnections, Parent:GetPropertyChangedSignal('CFrame'):Connect(queueGuideRefresh))
			end
		end
	end

	drawGuides = function()
		Self.Debug:Clear('AttachmentAlignmentAxes')
		refreshButtons()
		if not anyAxisEnabled() then return 0, 0 end

		local Attachments = selectedAttachments()
		local Drawn = 0
		for _, Attachment in ipairs(Attachments) do
			local Anchor = attachmentGuideAnchor(Attachment)
			if Anchor then
				local World = Attachment.WorldCFrame
				local Position = World.Position
				local AnyLine = false

				local function drawAxis(Axis, Direction)
					if not Self.ModuleAttachmentAxisEnabled[Axis] then return end
					local Extent = Direction * ATTACHMENT_AXIS_HALF_LENGTH
					local Line = Self.Debug:Line(
						'AttachmentAlignmentAxes',
						Anchor,
						Position - Extent,
						Position + Extent,
						ATTACHMENT_AXIS_COLORS[Axis],
						2,
						0.15,
						Self.ModuleAttachmentAxisAlwaysOnTop
					)
					AnyLine = AnyLine or Line ~= nil
				end

				drawAxis('X', World.RightVector)
				drawAxis('Y', World.UpVector)
				drawAxis('Z', World.LookVector)
				if AnyLine then Drawn += 1 end
			end
		end
		return #Attachments, Drawn
	end

	for Axis, Button in pairs(AxisButtons) do
		Self:_connect(Button.MouseButton1Click, function()
			Self.ModuleAttachmentAxisEnabled[Axis] = not Self.ModuleAttachmentAxisEnabled[Axis]
			bindSelectedAttachments()
			local SelectedCount, DrawnCount = drawGuides()
			if anyAxisEnabled() then
				if SelectedCount == 0 then
					Self:_setStatus(string.format('Attachment %s guide%s enabled. Select an Attachment.', enabledAxisText(), enabledAxisText():find('/') and 's' or ''), true)
				elseif DrawnCount == SelectedCount then
					Self:_setStatus(string.format('Attachment guides %s: %d attachment%s.', enabledAxisText(), SelectedCount, SelectedCount == 1 and '' or 's'), true)
				else
					Self:_setStatus(string.format('Attachment guides %s: found %d, drew %d.', enabledAxisText(), SelectedCount, DrawnCount), DrawnCount > 0)
				end
			else
				Self:_setStatus('Attachment axis guides disabled.', true)
			end
		end)
	end

	Self:_connect(Self.AttachmentAxisAlwaysOnTopButton.MouseButton1Click, function()
		Self.ModuleAttachmentAxisAlwaysOnTop = not Self.ModuleAttachmentAxisAlwaysOnTop
		drawGuides()
		Self:_setStatus(
			'Attachment guides Always On Top ' .. (Self.ModuleAttachmentAxisAlwaysOnTop and 'enabled.' or 'disabled.'),
			true
		)
	end)

	Self:_connect(StudioSelection.SelectionChanged, function()
		bindSelectedAttachments()
		drawGuides()
	end)

	Self:_connect(Self.ClearDebugButton.MouseButton1Click, function()
		task.defer(function()
			if anyAxisEnabled() then drawGuides() end
		end)
	end)

	Self:_connect(Self.Widget:GetPropertyChangedSignal('Enabled'), function()
		if Self.Widget.Enabled and anyAxisEnabled() then
			task.defer(function()
				bindSelectedAttachments()
				drawGuides()
			end)
		end
	end)

	local BaseDestroy = Self.Destroy
	Self.Destroy = function(Instance)
		disconnectGuideConnections()
		Self.Debug:Clear('AttachmentAlignmentAxes')
		BaseDestroy(Instance)
	end

	refreshButtons()
end

function BuilderModuleTools.wrap(Wrapped)
	local WrappedNew = Wrapped.new
	local Result = {}
	for Key, Value in pairs(Wrapped) do
		Result[Key] = Value
	end

	Result.new = function(...)
		local Self = WrappedNew(...)
		local Scroll = Self.Root and Self.Root:FindFirstChildWhichIsA('ScrollingFrame')
		if Scroll then
			installAttachmentAxisGuides(Self, Scroll)
			Self.CreateDoorSocketButton = makeButton(Scroll, 'FORGEBuilder_CreateDoorSocket', 'Create Door Socket From 3', -104)
			Self:_connect(Self.CreateDoorSocketButton.MouseButton1Click, function()
				createDoorSocket(Self)
			end)
		end
		return Self
	end

	return Result
end

return BuilderModuleTools