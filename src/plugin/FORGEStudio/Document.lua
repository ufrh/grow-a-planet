local Theme = require(script.Parent.Theme)

local Document = {}
Document.__index = Document

function Document.new()
	local self = setmetatable({}, Document)
	self.Roots = {}
	self.Changed = Instance.new('BindableEvent')
	return self
end

function Document:GetRoots()
	return self.Roots
end

function Document:IsRoot(Object)
	return table.find(self.Roots, Object) ~= nil
end

function Document:GetRoot(Object)
	if not Object then return nil end
	for _, Root in ipairs(self.Roots) do
		if Object == Root or Object:IsDescendantOf(Root) then return Root end
	end
	return nil
end

function Document:GetZone(Root)
	if not Root then return 'Center' end
	local Zone = Root:GetAttribute('FORGEZone')
	return Theme.ZoneAnchor[Zone] and Zone or 'Center'
end

function Document:SetZone(Root, Zone)
	if not Root or not Theme.ZoneAnchor[Zone] then return self end
	Root:SetAttribute('FORGEZone', Zone)
	self.Changed:Fire('Zone', Root)
	return self
end

function Document:GetScreenMargin(Root)
	if not Root then return Theme.Metric.ScreenMargin end
	local Margin = Root:GetAttribute('FORGEScreenMargin')
	return typeof(Margin) == 'number' and math.max(0, Margin) or Theme.Metric.ScreenMargin
end

function Document:SetScreenMargin(Root, Margin)
	if not Root then return self end
	Margin = tonumber(Margin)
	if not Margin then return self end
	Root:SetAttribute('FORGEScreenMargin', math.max(0, Margin))
	self.Changed:Fire('ScreenMargin', Root)
	return self
end

function Document:IsLocked(Root)
	return Root and Root:GetAttribute('FORGELocked') == true or false
end

function Document:SetLocked(Root, Value)
	if not Root then return self end
	Root:SetAttribute('FORGELocked', Value == true)
	self.Changed:Fire('Locked', Root)
	return self
end

function Document:AddRoot(Root, Zone)
	if not Root or self:IsRoot(Root) then return Root end
	table.insert(self.Roots, Root)
	Root:SetAttribute('FORGEStudioRoot', true)
	Root:SetAttribute('FORGEZone', Theme.ZoneAnchor[Zone] and Zone or 'Center')
	if Root:GetAttribute('FORGEScreenMargin') == nil then
		Root:SetAttribute('FORGEScreenMargin', Theme.Metric.ScreenMargin)
	end
	if Root:GetAttribute('FORGELocked') == nil then
		Root:SetAttribute('FORGELocked', false)
	end
	self.Changed:Fire('Roots', Root)
	return Root
end

function Document:ReplaceRoot(OldRoot, NewRoot)
	local Index = table.find(self.Roots, OldRoot)
	if not Index or not NewRoot then return false end

	self.Roots[Index] = NewRoot
	NewRoot:SetAttribute('FORGEStudioRoot', true)
	if NewRoot:GetAttribute('FORGEZone') == nil then
		NewRoot:SetAttribute('FORGEZone', self:GetZone(OldRoot))
	end
	if NewRoot:GetAttribute('FORGEScreenMargin') == nil then
		NewRoot:SetAttribute('FORGEScreenMargin', self:GetScreenMargin(OldRoot))
	end
	if NewRoot:GetAttribute('FORGELocked') == nil then
		NewRoot:SetAttribute('FORGELocked', self:IsLocked(OldRoot))
	end

	if OldRoot.Parent then OldRoot:Destroy() end
	self.Changed:Fire('Replace', NewRoot, OldRoot)
	return true
end

function Document:DetachRoot(Root, Silent)
	local Index = table.find(self.Roots, Root)
	if not Index then return false end
	table.remove(self.Roots, Index)
	Root:SetAttribute('FORGEStudioRoot', nil)
	if not Silent then self.Changed:Fire('Roots', Root) end
	return true
end

function Document:RemoveRoot(Root)
	if not self:DetachRoot(Root, true) then return false end
	if Root.Parent then Root:Destroy() end
	self.Changed:Fire('Roots')
	return true
end

function Document:Clear()
	for _, Root in ipairs(self.Roots) do
		if Root.Parent then Root:Destroy() end
	end
	table.clear(self.Roots)
	self.Changed:Fire('Roots')
	return self
end

function Document:Destroy()
	self.Changed:Destroy()
	for _, Root in ipairs(self.Roots) do
		if Root.Parent then Root:Destroy() end
	end
	table.clear(self.Roots)
end

return Document
