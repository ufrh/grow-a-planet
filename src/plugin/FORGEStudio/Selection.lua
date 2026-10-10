local Selection = {}
Selection.__index = Selection

function Selection.new(Document)
	local self = setmetatable({}, Selection)
	self.Document = Document
	self.Root = nil
	self.Roots = {}
	self.Child = nil
	self.Children = {}
	self.Changed = Instance.new('BindableEvent')
	return self
end

function Selection:_Fire()
	self.Changed:Fire(self.Root, self.Child, self.Roots, self.Children)
	return self
end

function Selection:GetRoots()
	return table.clone(self.Roots)
end

function Selection:GetChildren()
	return table.clone(self.Children)
end

function Selection:GetTargets()
	if #self.Children > 0 then return self:GetChildren() end
	return self:GetRoots()
end

function Selection:IsSelected(Root)
	return table.find(self.Roots, Root) ~= nil
end

function Selection:IsChildSelected(Child)
	return table.find(self.Children, Child) ~= nil
end

function Selection:Count()
	return #self.Roots
end

function Selection:ChildCount()
	return #self.Children
end

function Selection:SetRoots(Roots, Primary)
	local Next, Seen = {}, {}

	for _, Root in ipairs(Roots or {}) do
		if Root and self.Document:IsRoot(Root) and not Seen[Root] then
			Seen[Root] = true
			table.insert(Next, Root)
		end
	end

	if Primary and not Seen[Primary] then Primary = nil end
	Primary = Primary or Next[#Next]

	self.Roots = Next
	self.Root = Primary
	self.Child = nil
	self.Children = {}
	return self:_Fire()
end

function Selection:SelectRoot(Root, Additive)
	if Root and not self.Document:IsRoot(Root) then Root = self.Document:GetRoot(Root) end
	if not Root then return self:Clear() end

	if not Additive then
		if self.Root == Root and #self.Roots == 1 and self.Child == nil then return self end
		self.Roots = {Root}
		self.Root = Root
		self.Child = nil
		self.Children = {}
		return self:_Fire()
	end

	if not self:IsSelected(Root) then table.insert(self.Roots, Root) end
	self.Root = Root
	self.Child = nil
	self.Children = {}
	return self:_Fire()
end

function Selection:ToggleRoot(Root)
	if Root and not self.Document:IsRoot(Root) then Root = self.Document:GetRoot(Root) end
	if not Root then return self end

	local Index = table.find(self.Roots, Root)
	if Index then
		table.remove(self.Roots, Index)
		if self.Root == Root then self.Root = self.Roots[#self.Roots] end
	else
		table.insert(self.Roots, Root)
		self.Root = Root
	end

	self.Child = nil
	self.Children = {}
	return self:_Fire()
end

function Selection:SelectAllRoots()
	local Roots = self.Document:GetRoots()
	return self:SetRoots(Roots, Roots[#Roots])
end

function Selection:SetChildren(Children, Primary)
	local Root = Primary and self.Document:GetRoot(Primary) or nil
	if not Root then
		for _, Child in ipairs(Children or {}) do
			Root = Child and self.Document:GetRoot(Child) or nil
			if Root then break end
		end
	end
	if not Root then return self end

	local Next, Seen = {}, {}
	for _, Child in ipairs(Children or {}) do
		if Child and Child ~= Root and self.Document:GetRoot(Child) == Root and not Seen[Child] then
			Seen[Child] = true
			table.insert(Next, Child)
		end
	end

	if #Next == 0 then return self:SelectRoot(Root) end
	if Primary and not Seen[Primary] then Primary = nil end
	Primary = Primary or Next[#Next]

	self.Roots = {Root}
	self.Root = Root
	self.Children = Next
	self.Child = Primary
	return self:_Fire()
end

function Selection:SelectChild(Child, Additive)
	local Root = Child and self.Document:GetRoot(Child) or nil
	if not Root or Child == Root then return self end

	if Additive and self.Root == Root then
		if not self:IsChildSelected(Child) then table.insert(self.Children, Child) end
		self.Roots = {Root}
		self.Root = Root
		self.Child = Child
		return self:_Fire()
	end

	return self:SetChildren({Child}, Child)
end

function Selection:ToggleChild(Child)
	local Root = Child and self.Document:GetRoot(Child) or nil
	if not Root or Child == Root then return self end

	if self.Root ~= Root then return self:SetChildren({Child}, Child) end

	local Next = self:GetChildren()
	local Index = table.find(Next, Child)
	if Index then table.remove(Next, Index) else table.insert(Next, Child) end

	if #Next == 0 then return self:SelectRoot(Root) end
	local Primary = Child
	if Index then Primary = Next[#Next] end
	return self:SetChildren(Next, Primary)
end

function Selection:GetTarget()
	return self.Child or self.Root
end

function Selection:Clear()
	if not self.Root and not self.Child and #self.Roots == 0 and #self.Children == 0 then return self end
	self.Root = nil
	self.Roots = {}
	self.Child = nil
	self.Children = {}
	return self:_Fire()
end

function Selection:Destroy()
	self.Changed:Destroy()
end

return Selection
