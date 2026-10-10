local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Stats = game:GetService('Stats')
local UserInputService = game:GetService('UserInputService')

local FORGE = require(ReplicatedStorage:WaitForChild('FORGE'))

local DevPanelController = FORGE.Controller('FORGEDevPanelController', {
	Priority = 95,
})

local Player = Players.LocalPlayer
local HISTORY = 120
local SAMPLE_INTERVAL = 0.25
local ACTIVITY_WINDOW = 0.55

local function clampHistory(List, Value)
	table.insert(List, Value)
	while #List > HISTORY do table.remove(List, 1) end
end

local function round(Value, Digits)
	local Scale = 10 ^ (Digits or 0)
	return math.floor((tonumber(Value) or 0) * Scale + 0.5) / Scale
end

local function create(ClassName, Properties, Parent)
	local Object = Instance.new(ClassName)
	for Key, Value in pairs(Properties or {}) do Object[Key] = Value end
	Object.Parent = Parent
	return Object
end

local function textLabel(Text, Parent, Size)
	return create('TextLabel', {
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		Text = Text or '',
		TextColor3 = Color3.fromRGB(225, 229, 235),
		TextSize = Size or 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, Parent)
end

local function safePing()
	local Success, Value = pcall(function()
		return Player:GetNetworkPing() * 1000
	end)
	if Success and type(Value) == 'number' then return Value end

	Success, Value = pcall(function()
		local Item = Stats.Network.ServerStatsItem:FindFirstChild('Data Ping')
		return Item and Item:GetValue() or 0
	end)
	return Success and tonumber(Value) or 0
end

local function memorySnapshot()
	local Result = {Total = 0, Tags = {}}
	pcall(function() Result.Total = Stats:GetTotalMemoryUsageMb() end)
	for _, Tag in ipairs(Enum.DeveloperMemoryTag:GetEnumItems()) do
		local Success, Value = pcall(function()
			return Stats:GetMemoryUsageMbForTag(Tag)
		end)
		if Success and type(Value) == 'number' and Value > 0.01 then
			table.insert(Result.Tags, {Name = Tag.Name, Value = Value})
		end
	end
	table.sort(Result.Tags, function(A, B) return A.Value > B.Value end)
	return Result
end

local function clearChildren(Parent, KeepLayout)
	for _, Child in ipairs(Parent:GetChildren()) do
		if KeepLayout and (Child:IsA('UIListLayout') or Child:IsA('UIPadding')) then continue end
		Child:Destroy()
	end
end

local function graphLine(Parent, A, B, Thickness, Transparency)
	local Delta = B - A
	local Length = Delta.Magnitude
	if Length <= 0 then return end
	local Mid = (A + B) * 0.5
	local Line = create('Frame', {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(Mid.X, Mid.Y),
		Size = UDim2.fromOffset(Length, Thickness or 1),
		Rotation = math.deg(math.atan2(Delta.Y, Delta.X)),
		BackgroundColor3 = Color3.fromRGB(105, 117, 133),
		BackgroundTransparency = Transparency or 0.55,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, Parent)
	return Line
end

local function sparkline(Parent, Values, Maximum)
	clearChildren(Parent)
	if #Values < 2 then return end
	local Width = Parent.AbsoluteSize.X
	local Height = Parent.AbsoluteSize.Y
	if Width <= 4 or Height <= 4 then return end
	Maximum = math.max(Maximum or 1, 0.001)
	for Index = 2, #Values do
		local X0 = (Index - 2) / math.max(#Values - 1, 1) * Width
		local X1 = (Index - 1) / math.max(#Values - 1, 1) * Width
		local Y0 = Height - math.clamp(Values[Index - 1] / Maximum, 0, 1) * Height
		local Y1 = Height - math.clamp(Values[Index] / Maximum, 0, 1) * Height
		graphLine(Parent, Vector2.new(X0, Y0), Vector2.new(X1, Y1), 2, 0.1)
	end
end

function DevPanelController:Init()
	self.Gui = nil
	self.Window = nil
	self.Visible = false
	self.ActivePage = 'Overview'
	self.Pages = {}
	self.NavButtons = {}
	self.NodeFrames = {}
	self.EdgeFrames = {}
	self.LastActivityIndex = 0
	self.History = {FPS = {}, FrameMs = {}, Ping = {}, Memory = {}}
	self.LastRender = os.clock()
	self.FrameDelta = 1 / 60
	self.SampleAt = 0
	self.RenderConnection = nil
	self.InputConnection = nil
	self.CombatProvider = nil
end

function DevPanelController:_BuildMetricCard(Parent, Title)
	local Card = create('Frame', {
		BackgroundColor3 = Color3.fromRGB(26, 29, 35),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 210, 0, 92),
	}, Parent)
	local TitleLabel = textLabel(Title, Card, 11)
	TitleLabel.Position = UDim2.fromOffset(10, 8)
	TitleLabel.Size = UDim2.new(1, -20, 0, 16)
	local Value = textLabel('--', Card, 22)
	Value.Position = UDim2.fromOffset(10, 28)
	Value.Size = UDim2.new(1, -20, 0, 28)
	local Graph = create('Frame', {
		BackgroundColor3 = Color3.fromRGB(20, 22, 27),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 60),
		Size = UDim2.new(1, -20, 0, 23),
		ClipsDescendants = true,
	}, Card)
	return {Frame = Card, Value = Value, Graph = Graph}
end

function DevPanelController:_Build()
	local PlayerGui = Player:WaitForChild('PlayerGui')
	local Existing = PlayerGui:FindFirstChild('FORGEDevPanel')
	if Existing then Existing:Destroy() end

	local Gui = create('ScreenGui', {
		Name = 'FORGEDevPanel',
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10000,
		Enabled = false,
	}, PlayerGui)
	self.Gui = Gui

	local Window = create('Frame', {
		Name = 'Window',
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.88, 0.82),
		BackgroundColor3 = Color3.fromRGB(16, 18, 22),
		BorderSizePixel = 0,
	}, Gui)
	self.Window = Window

	local Header = create('Frame', {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Color3.fromRGB(22, 25, 30),
		BorderSizePixel = 0,
	}, Window)
	local Title = textLabel('FORGE // LIVE RUNTIME', Header, 17)
	Title.Position = UDim2.fromOffset(14, 11)
	Title.Size = UDim2.new(1, -180, 0, 22)
	local Hint = textLabel('F8  toggle', Header, 11)
	Hint.AnchorPoint = Vector2.new(1, 0)
	Hint.Position = UDim2.new(1, -14, 0, 14)
	Hint.Size = UDim2.fromOffset(90, 18)
	Hint.TextXAlignment = Enum.TextXAlignment.Right

	local Nav = create('Frame', {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(0, 148, 1, -42),
		BackgroundColor3 = Color3.fromRGB(20, 22, 27),
		BorderSizePixel = 0,
	}, Window)
	local NavLayout = create('UIListLayout', {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, Nav)
	create('UIPadding', {
		PaddingTop = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, Nav)

	local Content = create('Frame', {
		Position = UDim2.fromOffset(148, 42),
		Size = UDim2.new(1, -148, 1, -42),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, Window)
	self.Content = Content

	for Index, Name in ipairs({'Overview', 'Performance', 'Memory', 'Network', 'FORGE', 'Combat'}) do
		local Button = create('TextButton', {
			LayoutOrder = Index,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Color3.fromRGB(27, 30, 36),
			BorderSizePixel = 0,
			Font = Enum.Font.Code,
			Text = Name,
			TextColor3 = Color3.fromRGB(205, 211, 220),
			TextSize = 12,
			AutoButtonColor = true,
		}, Nav)
		Button.Activated:Connect(function() self:_SetPage(Name) end)
		self.NavButtons[Name] = Button

		local Page = create('Frame', {
			Name = Name,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
		}, Content)
		self.Pages[Name] = Page
	end

	self:_BuildOverview()
	self:_BuildPerformance()
	self:_BuildMemory()
	self:_BuildNetwork()
	self:_BuildForge()
	self:_BuildCombat()
	self:_SetPage('Overview')
end

function DevPanelController:_SetPage(Name)
	self.ActivePage = Name
	for PageName, Page in pairs(self.Pages) do
		Page.Visible = PageName == Name
	end
	for ButtonName, Button in pairs(self.NavButtons) do
		Button.BackgroundTransparency = ButtonName == Name and 0 or 0.45
	end
end

function DevPanelController:_BuildOverview()
	local Page = self.Pages.Overview
	local Grid = create('Frame', {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 0, 198),
		BackgroundTransparency = 1,
	}, Page)
	create('UIGridLayout', {
		CellSize = UDim2.fromOffset(210, 92),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, Grid)
	self.OverviewCards = {
		FPS = self:_BuildMetricCard(Grid, 'FPS'),
		Frame = self:_BuildMetricCard(Grid, 'FRAME MS'),
		Ping = self:_BuildMetricCard(Grid, 'PING MS'),
		Memory = self:_BuildMetricCard(Grid, 'MEMORY MB'),
	}
	local Summary = textLabel('', Page, 12)
	Summary.Position = UDim2.fromOffset(14, 224)
	Summary.Size = UDim2.new(1, -28, 1, -238)
	self.OverviewSummary = Summary
end

function DevPanelController:_BuildPerformance()
	local Page = self.Pages.Performance
	self.PerfText = textLabel('', Page, 12)
	self.PerfText.Position = UDim2.fromOffset(14, 14)
	self.PerfText.Size = UDim2.new(1, -28, 0, 80)
	self.PerfFPSGraph = create('Frame', {Position=UDim2.fromOffset(14,104),Size=UDim2.new(1,-28,0,150),BackgroundColor3=Color3.fromRGB(20,22,27),BorderSizePixel=0,ClipsDescendants=true}, Page)
	self.PerfFrameGraph = create('Frame', {Position=UDim2.fromOffset(14,268),Size=UDim2.new(1,-28,0,150),BackgroundColor3=Color3.fromRGB(20,22,27),BorderSizePixel=0,ClipsDescendants=true}, Page)
end

function DevPanelController:_BuildMemory()
	local Page = self.Pages.Memory
	self.MemoryText = textLabel('', Page, 12)
	self.MemoryText.Position = UDim2.fromOffset(14, 14)
	self.MemoryText.Size = UDim2.new(1, -28, 1, -28)
end

function DevPanelController:_BuildNetwork()
	local Page = self.Pages.Network
	self.NetworkText = textLabel('', Page, 12)
	self.NetworkText.Position = UDim2.fromOffset(14,14)
	self.NetworkText.Size = UDim2.new(1,-28,0,90)
	self.PingGraph = create('Frame', {Position=UDim2.fromOffset(14,112),Size=UDim2.new(1,-28,0,180),BackgroundColor3=Color3.fromRGB(20,22,27),BorderSizePixel=0,ClipsDescendants=true}, Page)
end

function DevPanelController:_BuildForge()
	local Page = self.Pages.FORGE
	self.ForgeHeader = textLabel('', Page, 12)
	self.ForgeHeader.Position = UDim2.fromOffset(14, 10)
	self.ForgeHeader.Size = UDim2.new(1, -28, 0, 44)
	self.NeuronCanvas = create('Frame', {
		Position = UDim2.fromOffset(14, 58),
		Size = UDim2.new(1, -28, 1, -72),
		BackgroundColor3 = Color3.fromRGB(12, 14, 18),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, Page)
end

function DevPanelController:_BuildCombat()
	local Page = self.Pages.Combat
	local Scroll = create('ScrollingFrame', {
		Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 1, -28),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, Page)
	self.CombatText = textLabel('Combat debug provider unavailable in this place.', Scroll, 12)
	self.CombatText.Size = UDim2.new(1, -12, 0, 0)
	self.CombatText.AutomaticSize, self.CombatText.TextWrapped = Enum.AutomaticSize.Y, true
end

function DevPanelController:_RebuildNeuronGraph(Snapshot)
	local Canvas = self.NeuronCanvas
	if not Canvas or Canvas.AbsoluteSize.X <= 20 then return end
	clearChildren(Canvas)
	table.clear(self.NodeFrames)
	table.clear(self.EdgeFrames)

	local Graph = Snapshot.Graph or {}
	local Names = {}
	local Kinds = {}
	for _, Node in ipairs(Graph) do
		table.insert(Names, Node.Name)
		Kinds[Node.Name] = Node.Kind or 'Component'
	end
	for _, Name in ipairs((Snapshot.Network and Snapshot.Network.ServiceNames) or {}) do
		if not Kinds[Name] then
			table.insert(Names, Name)
			Kinds[Name] = 'RemoteService'
		end
	end
	table.sort(Names)

	local W, H = Canvas.AbsoluteSize.X, Canvas.AbsoluteSize.Y
	local Center = Vector2.new(W * 0.5, H * 0.5)
	local RadiusX = math.max(80, W * 0.39)
	local RadiusY = math.max(60, H * 0.36)
	local Positions = {}

	for Index, Name in ipairs(Names) do
		local Angle = (#Names <= 1) and 0 or ((Index - 1) / #Names) * math.pi * 2
		local Pos = Center + Vector2.new(math.cos(Angle) * RadiusX, math.sin(Angle) * RadiusY)
		Positions[Name] = Pos
	end

	for _, Node in ipairs(Graph) do
		for _, Dependency in ipairs(Node.Requires or {}) do
			if Positions[Node.Name] and Positions[Dependency] then
				local Line = graphLine(Canvas, Positions[Node.Name], Positions[Dependency], 1, 0.72)
				if Line then
					Line.Name = Node.Name .. '->' .. Dependency
					self.EdgeFrames[Line.Name] = Line
				end
			end
		end
	end

	for _, Name in ipairs(Names) do
		local Pos = Positions[Name]
		local Node = create('Frame', {
			Name = Name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(Pos.X, Pos.Y),
			Size = UDim2.fromOffset(118, 34),
			BackgroundColor3 = Color3.fromRGB(35, 40, 49),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, Canvas)
		local Label = textLabel(Name, Node, 10)
		Label.Position = UDim2.fromOffset(6,4)
		Label.Size = UDim2.new(1,-12,0,14)
		local Kind = textLabel(Kinds[Name], Node, 8)
		Kind.Position = UDim2.fromOffset(6,19)
		Kind.Size = UDim2.new(1,-12,0,10)
		Kind.TextTransparency = 0.4
		self.NodeFrames[Name] = Node
	end
end

function DevPanelController:_PulseNeuronGraph(Snapshot)
	local Activity = Snapshot.Tooling and Snapshot.Tooling.Activity or {}
	for _, Node in pairs(self.NodeFrames) do
		Node.BackgroundTransparency = math.min(0.55, Node.BackgroundTransparency + 0.08)
	end
	for _, Edge in pairs(self.EdgeFrames) do
		Edge.BackgroundTransparency = math.min(0.82, Edge.BackgroundTransparency + 0.08)
	end

	local Now = os.clock()
	for Index = math.max(1, #Activity - 80), #Activity do
		local Entry = Activity[Index]
		if Entry and Now - (Entry.At or 0) <= ACTIVITY_WINDOW then
			local SourceNode = self.NodeFrames[Entry.Source]
			if SourceNode then SourceNode.BackgroundTransparency = 0 end

			local Target = Entry.Target
			if Target then
				for Name, Node in pairs(self.NodeFrames) do
					if string.find(Target, Name, 1, true) then
						Node.BackgroundTransparency = 0
						local Edge = self.EdgeFrames[Entry.Source .. '->' .. Name]
						if Edge then Edge.BackgroundTransparency = 0.05 end
					end
				end
			end
		end
	end
end

function DevPanelController:_Sample()
	local FrameMs = self.FrameDelta * 1000
	local FPS = self.FrameDelta > 0 and 1 / self.FrameDelta or 0
	local Ping = safePing()
	local Memory = memorySnapshot()

	clampHistory(self.History.FPS, FPS)
	clampHistory(self.History.FrameMs, FrameMs)
	clampHistory(self.History.Ping, Ping)
	clampHistory(self.History.Memory, Memory.Total)

	local Snapshot = FORGE.Diagnostics:Snapshot()
	self.LastSnapshot = Snapshot
	self.LastMemory = Memory

	if self.OverviewCards then
		self.OverviewCards.FPS.Value.Text = tostring(round(FPS, 0))
		self.OverviewCards.Frame.Value.Text = tostring(round(FrameMs, 1))
		self.OverviewCards.Ping.Value.Text = tostring(round(Ping, 0))
		self.OverviewCards.Memory.Value.Text = tostring(round(Memory.Total, 1))
		sparkline(self.OverviewCards.FPS.Graph, self.History.FPS, math.max(120, FPS))
		sparkline(self.OverviewCards.Frame.Graph, self.History.FrameMs, math.max(33, FrameMs))
		sparkline(self.OverviewCards.Ping.Graph, self.History.Ping, math.max(150, Ping))
		sparkline(self.OverviewCards.Memory.Graph, self.History.Memory, math.max(Memory.Total * 1.2, 1))
	end

	local Health = Snapshot.Health or {Healthy = true, Issues = {}}
	self.OverviewSummary.Text = string.format(
		'FORGE %s  |  %s/%s\nComponents: %d  |  Network services: %d  |  Health: %s\nActivity pulses buffered: %d  |  Trace spans: %d',
		tostring(Snapshot.Version),
		tostring(Snapshot.Context and Snapshot.Context.Environment or '?'),
		tostring(Snapshot.Context and Snapshot.Context.Side or '?'),
		#(Snapshot.Components or {}),
		Snapshot.Network and Snapshot.Network.Services or 0,
		Health.Healthy and 'OK' or ('ISSUES ' .. tostring(#(Health.Issues or {}))),
		#((Snapshot.Tooling and Snapshot.Tooling.Activity) or {}),
		#((Snapshot.Tooling and Snapshot.Tooling.Traces) or {})
	)

	self.PerfText.Text = string.format('FPS %.0f\nFrame %.2f ms\nSamples %d', FPS, FrameMs, #self.History.FPS)
	sparkline(self.PerfFPSGraph, self.History.FPS, 144)
	sparkline(self.PerfFrameGraph, self.History.FrameMs, 40)

	local MemoryLines = {string.format('TOTAL  %.2f MB', Memory.Total), ''}
	for Index, Entry in ipairs(Memory.Tags) do
		if Index > 24 then break end
		table.insert(MemoryLines, string.format('%-28s %8.2f MB', Entry.Name, Entry.Value))
	end
	self.MemoryText.Text = table.concat(MemoryLines, '\n')

	local Net = Snapshot.Network or {}
	local S = Net.Stats or {}
	self.NetworkText.Text = string.format(
		'Ping %.1f ms\nServices %d  |  RPC %d  |  Events %d  |  Inbound %d  |  Refreshes %d',
		Ping, Net.Services or 0, S.RPC or 0, S.Events or 0, S.Inbound or 0, S.Refreshes or 0
	)
	sparkline(self.PingGraph, self.History.Ping, math.max(200, Ping))

	self.ForgeHeader.Text = string.format(
		'NEURON VIEW  //  %d local components + %d remote services  //  live pulses < %.2fs',
		#(Snapshot.Components or {}), #(Net.ServiceNames or {}), ACTIVITY_WINDOW
	)

	if self.ActivePage == 'FORGE' then
		if next(self.NodeFrames) == nil then self:_RebuildNeuronGraph(Snapshot) end
		self:_PulseNeuronGraph(Snapshot)
	end

	local CombatProvider = FORGE:GetController('CombatDebugVisualizerController')
	if CombatProvider and CombatProvider.DevPanelSnapshot then
		local Combat = CombatProvider:DevPanelSnapshot()
		local Punch = Combat.Punch or {}
		local Body = Combat.Body or {}
		local Physics = Combat.Physics or {}
		local Lines = {
			'3D overlay: ' .. tostring(Combat.Enabled),
			('Body: %s | run %s | duck %s | lift %s | taunt %s'):format(tostring(Body.Action or '-'),
				tostring(Body.Run == true), tostring(Body.Duck == true), tostring(Body.Lift == true), tostring(Body.Taunt == true)),
			'Joints: ' .. tostring(Combat.Joints),
			'BallSockets: ' .. tostring(Combat.BallSockets),
			'IK targets: ' .. tostring(Combat.Targets) .. '  |  poles: ' .. tostring(Combat.Poles or 0),
			'Punch phase: ' .. tostring(Combat.PunchPhase or 'None'),
			'Punch side: ' .. tostring(Combat.PunchSide or '-'),
			'Hand error: ' .. tostring(round(Punch.HandError or 0, 3)) .. ' studs',
			('Alpha raw/eased: %.3f / %.3f  |  confirmed: %s'):format(Punch.PhaseAlpha or 0, Punch.EasedAlpha or 0, tostring(Punch.Confirmed)),
			('Speed target/hand/peak: %.2f / %.2f / %.2f studs/s'):format(
				Punch.TargetVelocity and Punch.TargetVelocity.Magnitude or 0,
				Punch.HandVelocity and Punch.HandVelocity.Magnitude or 0, Punch.PeakHandSpeed or 0),
			('IK weight: %.2f  |  muscle actual/intent: %.3f / %.3f'):format(Punch.Weight or 0, Punch.MuscleStrength or 0, Punch.DesiredMuscleStrength or 0),
			('Damping: %.2f  |  torque: %.0f  |  torso yaw: %.1f deg'):format(Punch.Damping or 0, Punch.MaxTorque or 0, Punch.TorsoYaw or 0),
			'Shoulder rotation: ' .. tostring(Punch.ShoulderRotation or '-'),
			'Impulse scheduled/actual: ' .. tostring(Punch.ReleaseScheduledAt or '-') .. ' / ' .. tostring(Punch.ReleaseImpulseAt or '-'),
			'Overlay colors: pink intent/trail, green hand/trail, orange error, cyan pole',
			'',
			'Hotkeys:',
			'  F8  FORGE panel',
			'  `  combat 3D overlay',
			'  1 body  2 joints  3 motion  5 feet  6 strikes',
			'  7 targets  8 grips  9 forces/contacts  0 overview',
			('Physics: %d bodies / %d colliders | mass %.1f | peak speed %.1f'):format(
				Physics.Bodies or 0, Physics.Colliders or 0, Physics.Mass or 0, Physics.PeakSpeed or 0),
			('Joints K/D %d/%d | worst %s %.1f deg | force drivers %d | probe hits %d'):format(
				Physics.Kinematic or 0, Physics.Dynamic or 0, Physics.ErrorJoint or '-', Physics.JointError or 0, Physics.ForceDrivers or 0, Physics.ProbeHits or 0),
		}
		for _, Side in ipairs({'Left', 'Right'}) do
			local Reach = Combat.Reach and Combat.Reach[Side] or {}
			table.insert(Lines, ('%s reach: %s | score/conf %.2f / %.2f | margin %.2f | error %.2f'):format(Side,
				tostring(Reach.SoftTarget or '-'), Reach.Score or 0, Reach.Confidence or 0, Reach.SwitchMargin or 0, Reach.ReachError or 0))
			table.insert(Lines, ('%s grip: %s | lift %s | error %.2f | force cap %.0f (tension unavailable)'):format(Side,
				tostring(Reach.GripTarget or '-'), tostring(Reach.Lift == true), Reach.GripError or 0, Reach.ForceLimit or 0))
			table.insert(Lines, Side .. ' server rejection: ' .. (Reach.Rejection or '-'))
		end
		self.CombatText.Text = table.concat(Lines, '\n')
	end
end

function DevPanelController:Start()
	if not FORGE.IsStudio then return end
	self:_Build()

	self.InputConnection = UserInputService.InputBegan:Connect(function(Input, Processed)
		if Processed then return end
		if Input.KeyCode == Enum.KeyCode.F8 then
			self.Visible = not self.Visible
			self.Gui.Enabled = self.Visible
			if self.Visible and self.ActivePage == 'FORGE' then
				table.clear(self.NodeFrames)
			end
		end
	end)

	self.RenderConnection = RunService.RenderStepped:Connect(function(DeltaTime)
		self.FrameDelta = self.FrameDelta * 0.85 + DeltaTime * 0.15
		if os.clock() >= self.SampleAt then
			self.SampleAt = os.clock() + SAMPLE_INTERVAL
			self:_Sample()
		end
	end)

	FORGE.Pulse('FORGEDevPanelController', 'Started', 'DevPanel')
end

function DevPanelController:Destroy()
	if self.InputConnection then self.InputConnection:Disconnect(); self.InputConnection = nil end
	if self.RenderConnection then self.RenderConnection:Disconnect(); self.RenderConnection = nil end
	if self.Gui then self.Gui:Destroy(); self.Gui = nil end
end

return DevPanelController
