local Bindings = {}

local Prefix = 'FORGEBinding_'

local function Split(Path)
	local Parts = {}
	for Part in tostring(Path or ''):gmatch('[^%.]+') do table.insert(Parts, Part) end
	return Parts
end

function Bindings:Get(Object, Property)
	if not Object or not Property then return nil end
	return Object:GetAttribute(Prefix .. Property)
end

function Bindings:Set(Object, Property, Path)
	if not Object or not Property then return false end
	Path = tostring(Path or '')
	Object:SetAttribute(Prefix .. Property, Path ~= '' and Path or nil)
	return true
end

function Bindings:Clear(Object, Property)
	if not Object or not Property then return false end
	Object:SetAttribute(Prefix .. Property, nil)
	return true
end

function Bindings:GetAll(Object)
	local Result = {}
	if not Object then return Result end

	for Name, Value in pairs(Object:GetAttributes()) do
		if string.sub(Name, 1, #Prefix) == Prefix then
			Result[string.sub(Name, #Prefix + 1)] = Value
		end
	end

	return Result
end

function Bindings:Resolve(Data, Path)
	local Current = Data
	for _, Part in ipairs(Split(Path)) do
		if typeof(Current) ~= 'table' then return nil end
		Current = Current[Part]
		if Current == nil then return nil end
	end
	return Current
end

function Bindings:Apply(Object, Property, Data)
	local Path = self:Get(Object, Property)
	if not Path then return false, nil end

	local Value = self:Resolve(Data, Path)
	if Value == nil then return false, nil end

	local Success, Current = pcall(function()
		return Object[Property]
	end)
	if not Success then return false, nil end

	local CurrentType = typeof(Current)
	local ValueType = typeof(Value)

	if CurrentType == 'string' and ValueType ~= 'string' then
		Value = tostring(Value)
	elseif CurrentType == 'number' and ValueType == 'string' then
		Value = tonumber(Value)
	elseif CurrentType == 'boolean' and ValueType == 'string' then
		local Lower = string.lower(Value)
		if Lower == 'true' or Lower == '1' then Value = true
		elseif Lower == 'false' or Lower == '0' then Value = false
		else Value = nil end
	end

	if Value == nil then return false, nil end

	local Applied = pcall(function()
		Object[Property] = Value
	end)

	return Applied, Value
end

function Bindings:ApplyTree(Root, Data)
	if not Root then return 0 end

	local Count = 0
	local Objects = {Root}
	for _, Descendant in ipairs(Root:GetDescendants()) do table.insert(Objects, Descendant) end

	for _, Object in ipairs(Objects) do
		for Property in pairs(self:GetAll(Object)) do
			if self:Apply(Object, Property, Data) then Count += 1 end
		end
	end

	return Count
end

return Bindings
