local History = {}
History.__index = History

function History.new(Capture, Restore, Limit)
	local self = setmetatable({}, History)
	self.Capture = Capture
	self.Restore = Restore
	self.Limit = Limit or 80
	self.Stack = {}
	self.Index = 0
	self.Changed = Instance.new('BindableEvent')
	return self
end

function History:_DestroySnapshot(Snapshot)
	if not Snapshot then return end
	for _, Entry in ipairs(Snapshot.Roots or {}) do
		if Entry.Root then Entry.Root:Destroy() end
	end
	if Snapshot.Cleanup then Snapshot.Cleanup() end
end

function History:_Fire()
	self.Changed:Fire(self:CanUndo(), self:CanRedo())
end

function History:Reset(Label, Scope)
	for _, Snapshot in ipairs(self.Stack) do self:_DestroySnapshot(Snapshot) end
	table.clear(self.Stack)
	self.Index = 0
	self:Push(Label or 'Initial', Scope or 'Full')
	return self
end

function History:Push(Label, Scope)
	for Index = #self.Stack, self.Index + 1, -1 do
		self:_DestroySnapshot(self.Stack[Index])
		table.remove(self.Stack, Index)
	end

	local Snapshot = self.Capture(Label, Scope)
	Snapshot.Label = Label or 'Edit'
	Snapshot.Scope = Scope or 'Document'
	table.insert(self.Stack, Snapshot)
	self.Index = #self.Stack

	while #self.Stack > self.Limit do
		self:_DestroySnapshot(table.remove(self.Stack, 1))
		self.Index -= 1
	end

	self:_Fire()
	return self
end

function History:CanUndo()
	return self.Index > 1
end

function History:CanRedo()
	return self.Index < #self.Stack
end

function History:GetUndoLabel()
	if not self:CanUndo() then return nil end
	return self.Stack[self.Index].Label
end

function History:GetRedoLabel()
	if not self:CanRedo() then return nil end
	return self.Stack[self.Index + 1].Label
end

function History:Undo()
	if not self:CanUndo() then return false end
	local Target = self.Index - 1
	if self.Restore(self.Stack[Target]) == false then return false end
	self.Index = Target
	self:_Fire()
	return true
end

function History:Redo()
	if not self:CanRedo() then return false end
	local Target = self.Index + 1
	if self.Restore(self.Stack[Target]) == false then return false end
	self.Index = Target
	self:_Fire()
	return true
end

function History:Destroy()
	for _, Snapshot in ipairs(self.Stack) do self:_DestroySnapshot(Snapshot) end
	table.clear(self.Stack)
	self.Changed:Destroy()
end

return History
