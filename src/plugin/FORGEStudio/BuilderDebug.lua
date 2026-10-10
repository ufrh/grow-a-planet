local CoreGui = game:GetService('CoreGui')
local SelectionService = game:GetService('Selection')
local Workspace = game:GetService('Workspace')

local BuilderDebug = {}
BuilderDebug.__index = BuilderDebug

local function findWorkspaceAnchor()
	return Workspace:FindFirstChildWhichIsA('BasePart', true)
end

local function findBasePart(Object)
	if not Object then return nil end
	if Object:IsA('BasePart') then return Object end
	if Object:IsA('Terrain') then
		-- HandleAdornments need a BasePart adornee. Terrain-backed attachments use
		-- any stable workspace part purely as a coordinate-space anchor; the
		-- adornment CFrame is still calculated from the requested world position.
		return findWorkspaceAnchor()
	end
	if Object:IsA('Attachment') then
		return findBasePart(Object.Parent)
	end
	if Object:IsA('Model') then
		if Object.PrimaryPart then return Object.PrimaryPart end
		return Object:FindFirstChildWhichIsA('BasePart', true)
	end
	return nil
end

local function isMovable(Object)
	return Object and (Object:IsA('BasePart') or Object:IsA('Model'))
end

local function getPivotPosition(Object)
	if not Object then return nil end
	if Object:IsA('BasePart') then
		return Object.Position
	end
	if Object:IsA('Model') then
		return Object:GetPivot().Position
	end
	return nil
end

local function localCFrame(Anchor, WorldCFrame)
	return Anchor.CFrame:ToObjectSpace(WorldCFrame)
end

function BuilderDebug.new()
	local self = setmetatable({}, BuilderDebug)
	self.Items = {}
	self.PairItems = {}
	self.PairConnections = {}
	self.PairA = nil
	self.PairB = nil
	self.PairSphereSequence = 0
	self.PairRefreshQueued = false
	self.Destroyed = false
	return self
end

function BuilderDebug:_track(Adornment, Channel)
	Adornment.Name = 'FORGEBuilderDebug_' .. tostring(Channel or 'General')
	Adornment.Parent = CoreGui
	self.Items[Adornment] = Channel or 'General'
	return Adornment
end

function BuilderDebug:_disconnectPairConnections()
	for _, Connection in ipairs(self.PairConnections) do
		Connection:Disconnect()
	end
	table.clear(self.PairConnections)
end

function BuilderDebug:_queuePairRefresh()
	if self.PairRefreshQueued or self.Destroyed then return end
	self.PairRefreshQueued = true
	task.defer(function()
		self.PairRefreshQueued = false
		if not self.Destroyed then
			self:_refreshPairDrawings()
		end
	end)
end

function BuilderDebug:_bindPairObject(Object)
	if not Object then return end

	local function watchPart(Part)
		if not Part:IsA('BasePart') then return end
		table.insert(self.PairConnections, Part:GetPropertyChangedSignal('CFrame'):Connect(function()
			self:_queuePairRefresh()
		end))
	end

	if Object:IsA('BasePart') then
		watchPart(Object)
	elseif Object:IsA('Model') then
		for _, Descendant in ipairs(Object:GetDescendants()) do
			watchPart(Descendant)
		end
		table.insert(self.PairConnections, Object.DescendantAdded:Connect(function(Descendant)
			if Descendant:IsA('BasePart') then
				watchPart(Descendant)
				self:_queuePairRefresh()
			end
		end))
	end

	table.insert(self.PairConnections, Object.AncestryChanged:Connect(function()
		self:_queuePairRefresh()
	end))
end

function BuilderDebug:_setPairObjects(PairA, PairB)
	if self.PairA == PairA and self.PairB == PairB then return end
	self:_disconnectPairConnections()
	self.PairA = PairA
	self.PairB = PairB
	self:_bindPairObject(PairA)
	self:_bindPairObject(PairB)
end

function BuilderDebug:_capturePairFromSelection(WorldStart, WorldFinish)
	local Selected = {}
	for _, Object in ipairs(SelectionService:Get()) do
		if isMovable(Object) then
			table.insert(Selected, Object)
		end
	end
	if #Selected ~= 2 then return end

	local P1 = getPivotPosition(Selected[1])
	local P2 = getPivotPosition(Selected[2])
	if not P1 or not P2 then return end

	local Direct = (P1 - WorldStart).Magnitude + (P2 - WorldFinish).Magnitude
	local Reversed = (P2 - WorldStart).Magnitude + (P1 - WorldFinish).Magnitude
	if math.min(Direct, Reversed) > 0.5 then return end

	if Direct <= Reversed then
		self:_setPairObjects(Selected[1], Selected[2])
	else
		self:_setPairObjects(Selected[2], Selected[1])
	end
end

function BuilderDebug:_refreshPairDrawings()
	local PairA = self.PairA
	local PairB = self.PairB
	if not PairA or not PairB or not PairA.Parent or not PairB.Parent then return end

	local A = getPivotPosition(PairA)
	local B = getPivotPosition(PairB)
	if not A or not B then return end

	local Anchor = findBasePart(PairA) or findBasePart(PairB)
	if not Anchor then return end
	local Midpoint = (A + B) * 0.5

	local Line = self.PairItems.Line
	if Line and Line.Parent then
		local Delta = B - A
		local Length = Delta.Magnitude
		Line.Adornee = Anchor
		Line.Visible = Length > 1e-4
		if Length > 1e-4 then
			Line.CFrame = localCFrame(Anchor, CFrame.lookAt(A, B))
			Line.Length = Length
		end
	end

	local Start = self.PairItems.Start
	if Start and Start.Parent then
		Start.Adornee = Anchor
		Start.CFrame = localCFrame(Anchor, CFrame.new(A))
	end

	local Finish = self.PairItems.Finish
	if Finish and Finish.Parent then
		Finish.Adornee = Anchor
		Finish.CFrame = localCFrame(Anchor, CFrame.new(B))
	end

	local Mid = self.PairItems.Midpoint
	if Mid and Mid.Parent then
		Mid.Adornee = Anchor
		Mid.CFrame = localCFrame(Anchor, CFrame.new(Midpoint))
	end
end

function BuilderDebug:Clear(Channel)
	for Adornment, ItemChannel in pairs(self.Items) do
		if Channel == nil or ItemChannel == Channel then
			self.Items[Adornment] = nil
			Adornment:Destroy()
		end
	end

	if Channel == nil or Channel == 'Pair' then
		table.clear(self.PairItems)
		self.PairSphereSequence = 0
	end
end

function BuilderDebug:Sphere(Channel, AnchorObject, WorldPosition, Radius, Color, Transparency, AlwaysOnTop)
	local Anchor = findBasePart(AnchorObject)
	if not Anchor then return nil end

	local Adornment = Instance.new('SphereHandleAdornment')
	Adornment.Adornee = Anchor
	Adornment.CFrame = localCFrame(Anchor, CFrame.new(WorldPosition))
	Adornment.Radius = Radius or 0.2
	Adornment.Color3 = Color or Color3.new(1, 1, 1)
	Adornment.Transparency = Transparency == nil and 0.05 or Transparency
	Adornment.AlwaysOnTop = AlwaysOnTop ~= false
	Adornment.ZIndex = 10
	self:_track(Adornment, Channel)

	if Channel == 'Pair' then
		self.PairSphereSequence += 1
		if self.PairSphereSequence == 1 then
			self.PairItems.Start = Adornment
		elseif self.PairSphereSequence == 2 then
			self.PairItems.Finish = Adornment
		elseif self.PairSphereSequence == 3 then
			self.PairItems.Midpoint = Adornment
		end
		self:_refreshPairDrawings()
	end

	return Adornment
end

function BuilderDebug:Box(Channel, AnchorObject, WorldCFrame, Size, Color, Transparency, AlwaysOnTop)
	local Anchor = findBasePart(AnchorObject)
	if not Anchor then return nil end

	local Adornment = Instance.new('BoxHandleAdornment')
	Adornment.Adornee = Anchor
	Adornment.CFrame = localCFrame(Anchor, WorldCFrame)
	Adornment.Size = Size
	Adornment.Color3 = Color or Color3.new(1, 1, 1)
	Adornment.Transparency = Transparency == nil and 0.72 or Transparency
	Adornment.AlwaysOnTop = AlwaysOnTop ~= false
	Adornment.ZIndex = 8
	return self:_track(Adornment, Channel)
end

function BuilderDebug:Line(Channel, AnchorObject, WorldStart, WorldFinish, Color, Thickness, Transparency, AlwaysOnTop)
	local Anchor = findBasePart(AnchorObject)
	if not Anchor then return nil end
	local Delta = WorldFinish - WorldStart
	local Length = Delta.Magnitude
	if Length <= 1e-4 then return nil end

	if Channel == 'Pair' then
		self:_capturePairFromSelection(WorldStart, WorldFinish)
	end

	local Adornment = Instance.new('LineHandleAdornment')
	Adornment.Adornee = Anchor
	Adornment.CFrame = localCFrame(Anchor, CFrame.lookAt(WorldStart, WorldFinish))
	Adornment.Length = Length
	Adornment.Thickness = Thickness or 3
	Adornment.Color3 = Color or Color3.new(1, 1, 1)
	Adornment.Transparency = Transparency == nil and 0.05 or Transparency
	Adornment.AlwaysOnTop = AlwaysOnTop ~= false
	Adornment.ZIndex = 9
	self:_track(Adornment, Channel)

	if Channel == 'Pair' then
		self.PairItems.Line = Adornment
		self:_refreshPairDrawings()
	end

	return Adornment
end

function BuilderDebug:Destroy()
	self.Destroyed = true
	self:_disconnectPairConnections()
	self.PairA = nil
	self.PairB = nil
	self:Clear()
end

return BuilderDebug
