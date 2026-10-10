local Workspace = game:GetService('Workspace')
local SelectionService = game:GetService('Selection')

local GeneratorControlPoints = {}
GeneratorControlPoints.__index = GeneratorControlPoints

local ATTRIBUTE_CONTROL_POINT = 'FORGEGeneratorControlPoint'
local ATTRIBUTE_ORDER = 'FORGEGeneratorPointOrder'
local ATTRIBUTE_DEBUG_LINE = 'FORGEGeneratorDebugLine'

local function findAnchor(Object)
	if not Object then return nil end
	if Object:IsA('BasePart') then return Object end
	if Object:IsA('Model') then
		return Object.PrimaryPart or Object:FindFirstChildWhichIsA('BasePart', true)
	end
	return nil
end

function GeneratorControlPoints.new(Mouse, Debug, Options)
	Options = Options or {}
	local self = setmetatable({}, GeneratorControlPoints)
	self.Mouse = Mouse
	self.Debug = Debug
	self.Channel = Options.Channel or 'GeneratorPoints'
	self.LineColor = Options.LineColor or Color3.fromRGB(122, 175, 255)
	self.Attachments = {}
	self.AttachmentConnections = {}
	self.Beams = {}
	self.Anchor = nil
	self.Connections = {}
	self.SelectedIndex = nil
	self.OnChanged = Options.OnChanged
	self.OnSelectionChanged = Options.OnSelectionChanged
	self.OnStatus = Options.OnStatus
	self.Destroyed = false
	self.SuppressSync = false

	self:_removeStaleDebugLines()
	self:_adoptExistingAttachments()

	table.insert(self.Connections, SelectionService.SelectionChanged:Connect(function()
		self:_syncSelection()
	end))

	return self
end

function GeneratorControlPoints:_status(Text, Good)
	if self.OnStatus then self.OnStatus(Text, Good) end
end

function GeneratorControlPoints:_selectionChanged()
	if self.OnSelectionChanged then
		self.OnSelectionChanged(self.SelectedIndex, self:GetSelectedPosition())
	end
end

function GeneratorControlPoints:_changed(RebuildLines)
	if RebuildLines then self:Draw() end
	if self.OnChanged then self.OnChanged(self:GetPoints()) end
	if self.OnSelectionChanged then
		self.OnSelectionChanged(self.SelectedIndex, self:GetSelectedPosition())
	end
end

function GeneratorControlPoints:_ensureAnchor(Target)
	local Anchor = findAnchor(Target)
	if Anchor then self.Anchor = Anchor end
	if self.Anchor and self.Anchor.Parent then return self.Anchor end
	return nil
end

function GeneratorControlPoints:_removeStaleDebugLines()
	for _, Child in ipairs(Workspace.Terrain:GetChildren()) do
		if Child:IsA('Beam') and Child:GetAttribute(ATTRIBUTE_DEBUG_LINE) == true then
			Child:Destroy()
		end
	end
end

function GeneratorControlPoints:_clearBeams()
	for _, Beam in ipairs(self.Beams) do
		if Beam.Parent then Beam:Destroy() end
	end
	table.clear(self.Beams)
end

function GeneratorControlPoints:_disconnectAttachment(Attachment)
	local List = self.AttachmentConnections[Attachment]
	if List then
		for _, Connection in ipairs(List) do Connection:Disconnect() end
		self.AttachmentConnections[Attachment] = nil
	end
end

function GeneratorControlPoints:_renumber()
	for Index, Attachment in ipairs(self.Attachments) do
		if Attachment and Attachment.Parent then
			Attachment.Name = string.format('FORGE_GeneratorPoint_%02d', Index)
			Attachment.Visible = true
			Attachment:SetAttribute(ATTRIBUTE_ORDER, Index)
		end
	end
end

function GeneratorControlPoints:_removeAttachmentReference(Attachment)
	for Index, Existing in ipairs(self.Attachments) do
		if Existing == Attachment then
			self:_disconnectAttachment(Attachment)
			table.remove(self.Attachments, Index)
			if self.SelectedIndex == Index then
				self.SelectedIndex = nil
			elseif self.SelectedIndex and self.SelectedIndex > Index then
				self.SelectedIndex -= 1
			end
			self:_renumber()
			self:_changed(true)
			return
		end
	end
end

function GeneratorControlPoints:_bindAttachment(Attachment)
	self:_disconnectAttachment(Attachment)
	local Connections = {}
	self.AttachmentConnections[Attachment] = Connections

	-- Beams follow attachments automatically. Position changes only need to refresh
	-- generated previews and the coordinate readout.
	table.insert(Connections, Attachment:GetPropertyChangedSignal('Position'):Connect(function()
		if self.Destroyed or self.SuppressSync then return end
		self:_changed(false)
	end))
	table.insert(Connections, Attachment.AncestryChanged:Connect(function(_, Parent)
		if self.Destroyed or self.SuppressSync then return end
		if Parent ~= Workspace.Terrain then
			self:_removeAttachmentReference(Attachment)
		end
	end))
end

function GeneratorControlPoints:_createAttachment(Position)
	local Attachment = Instance.new('Attachment')
	Attachment.Visible = true
	Attachment:SetAttribute(ATTRIBUTE_CONTROL_POINT, true)
	Attachment.Parent = Workspace.Terrain
	Attachment.WorldPosition = Position
	self:_bindAttachment(Attachment)
	return Attachment
end

function GeneratorControlPoints:_adoptExistingAttachments()
	local Existing = {}
	for _, Child in ipairs(Workspace.Terrain:GetChildren()) do
		if Child:IsA('Attachment') and Child:GetAttribute(ATTRIBUTE_CONTROL_POINT) == true then
			table.insert(Existing, Child)
		end
	end
	table.sort(Existing, function(A, B)
		return (A:GetAttribute(ATTRIBUTE_ORDER) or math.huge) < (B:GetAttribute(ATTRIBUTE_ORDER) or math.huge)
	end)
	for _, Attachment in ipairs(Existing) do
		Attachment.Visible = true
		table.insert(self.Attachments, Attachment)
		self:_bindAttachment(Attachment)
	end
	self:_renumber()
	self:Draw()
end

function GeneratorControlPoints:_syncSelection()
	if self.Destroyed then return end
	local Selected = SelectionService:Get()
	local NewIndex = nil
	for _, Object in ipairs(Selected) do
		for Index, Attachment in ipairs(self.Attachments) do
			if Object == Attachment then
				NewIndex = Index
				break
			end
		end
		if NewIndex then break end
	end

	if NewIndex ~= self.SelectedIndex then
		self.SelectedIndex = NewIndex
		self:_selectionChanged()
	end
end

function GeneratorControlPoints:AddPoint(Position, AnchorObject)
	if typeof(Position) ~= 'Vector3' then
		self:_status('Select a surface before adding a generator point.', false)
		return nil
	end
	local Anchor = findAnchor(AnchorObject)
	if Anchor then self.Anchor = Anchor end
	local Attachment = self:_createAttachment(Position)
	table.insert(self.Attachments, Attachment)
	self:_renumber()
	self.SelectedIndex = #self.Attachments
	SelectionService:Set({Attachment})
	self:_changed(true)
	return self.SelectedIndex
end

function GeneratorControlPoints:InsertPoint(Index, Position, AnchorObject)
	if typeof(Position) ~= 'Vector3' then return nil end
	local Anchor = findAnchor(AnchorObject)
	if Anchor then self.Anchor = Anchor end
	local InsertIndex = math.clamp(Index, 1, #self.Attachments + 1)
	local Attachment = self:_createAttachment(Position)
	table.insert(self.Attachments, InsertIndex, Attachment)
	self:_renumber()
	self.SelectedIndex = InsertIndex
	SelectionService:Set({Attachment})
	self:_changed(true)
	return InsertIndex
end

function GeneratorControlPoints:RemoveLast()
	local Attachment = self.Attachments[#self.Attachments]
	if not Attachment then return end
	self.SuppressSync = true
	self:_disconnectAttachment(Attachment)
	table.remove(self.Attachments)
	Attachment:Destroy()
	self.SuppressSync = false
	if #self.Attachments == 0 then
		self.SelectedIndex = nil
	elseif self.SelectedIndex and self.SelectedIndex > #self.Attachments then
		self.SelectedIndex = #self.Attachments
	end
	self:_renumber()
	self:_changed(true)
end

function GeneratorControlPoints:Clear()
	self.SelectedIndex = nil
	self.SuppressSync = true
	for _, Attachment in ipairs(self.Attachments) do
		self:_disconnectAttachment(Attachment)
		if Attachment.Parent then Attachment:Destroy() end
	end
	table.clear(self.Attachments)
	self.SuppressSync = false
	self:_clearBeams()
	self.Debug:Clear(self.Channel)
	if self.OnChanged then self.OnChanged({}) end
	if self.OnSelectionChanged then self.OnSelectionChanged(nil, nil) end
end

function GeneratorControlPoints:SetPoints(Positions, AnchorObject)
	self.SuppressSync = true
	for _, Attachment in ipairs(self.Attachments) do
		self:_disconnectAttachment(Attachment)
		if Attachment.Parent then Attachment:Destroy() end
	end
	table.clear(self.Attachments)
	self.SuppressSync = false

	local Anchor = findAnchor(AnchorObject)
	if Anchor then self.Anchor = Anchor end
	for _, Position in ipairs(Positions or {}) do
		if typeof(Position) == 'Vector3' then
			local Attachment = self:_createAttachment(Position)
			table.insert(self.Attachments, Attachment)
		end
	end
	self:_renumber()
	self.SelectedIndex = #self.Attachments > 0 and 1 or nil
	if self.SelectedIndex then SelectionService:Set({self.Attachments[self.SelectedIndex]}) end
	self:_changed(true)
end

function GeneratorControlPoints:GetPoints()
	local Result = {}
	for _, Attachment in ipairs(self.Attachments) do
		if Attachment.Parent then table.insert(Result, Attachment.WorldPosition) end
	end
	return Result
end

function GeneratorControlPoints:GetAnchor()
	return self:_ensureAnchor(nil)
end

function GeneratorControlPoints:GetSelectedIndex()
	return self.SelectedIndex
end

function GeneratorControlPoints:GetSelectedPosition()
	local Attachment = self.SelectedIndex and self.Attachments[self.SelectedIndex]
	return Attachment and Attachment.Parent and Attachment.WorldPosition or nil
end

function GeneratorControlPoints:SetSelectedIndex(Index)
	if Index == nil then
		self.SelectedIndex = nil
	elseif #self.Attachments > 0 then
		self.SelectedIndex = math.clamp(math.floor(tonumber(Index) or 1), 1, #self.Attachments)
	else
		self.SelectedIndex = nil
	end
	if self.SelectedIndex then SelectionService:Set({self.Attachments[self.SelectedIndex]}) end
	self:_selectionChanged()
	return self.SelectedIndex
end

function GeneratorControlPoints:SetSelectedPosition(Position)
	if typeof(Position) ~= 'Vector3' then return false end
	local Attachment = self.SelectedIndex and self.Attachments[self.SelectedIndex]
	if not Attachment or not Attachment.Parent then return false end
	self.SuppressSync = true
	Attachment.WorldPosition = Position
	self.SuppressSync = false
	self:_changed(false)
	return true
end

function GeneratorControlPoints:Draw()
	-- Remove legacy handle-adornment path lines from older versions.
	self.Debug:Clear(self.Channel)
	self:_clearBeams()
	if #self.Attachments < 2 then return end

	for Index = 2, #self.Attachments do
		local A = self.Attachments[Index - 1]
		local B = self.Attachments[Index]
		if A.Parent == Workspace.Terrain and B.Parent == Workspace.Terrain then
			local Beam = Instance.new('Beam')
			Beam.Name = string.format('FORGE_GeneratorLine_%02d', Index - 1)
			Beam:SetAttribute(ATTRIBUTE_DEBUG_LINE, true)
			Beam.Attachment0 = A
			Beam.Attachment1 = B
			Beam.Enabled = true
			Beam.FaceCamera = true
			Beam.Width0 = 0.055
			Beam.Width1 = 0.055
			Beam.Color = ColorSequence.new(self.LineColor)
			Beam.Transparency = NumberSequence.new(0)
			Beam.LightEmission = 0.65
			Beam.LightInfluence = 0
			Beam.Segments = 1
			Beam.Archivable = false
			Beam.Parent = Workspace.Terrain
			table.insert(self.Beams, Beam)
		end
	end
end

function GeneratorControlPoints:Destroy()
	self.Destroyed = true
	for _, Connection in ipairs(self.Connections) do Connection:Disconnect() end
	table.clear(self.Connections)
	for Attachment in pairs(self.AttachmentConnections) do self:_disconnectAttachment(Attachment) end
	self:_clearBeams()
	self.Debug:Clear(self.Channel)
	-- Control attachments intentionally remain under Terrain so a dev reload does
	-- not destroy the user's in-progress generator path.
	table.clear(self.Attachments)
end

return GeneratorControlPoints
