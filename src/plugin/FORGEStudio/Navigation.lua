local Navigation = {}

Navigation.ActionTypes = {
	'None',
	'OpenScreen',
	'Back',
	'Show',
	'Hide',
	'Toggle'
}

Navigation.Transitions = {
	'None',
	'Fade',
	'SlideLeft',
	'SlideRight',
	'Scale'
}

local Attributes = {
	Type = 'FORGEActionType',
	Target = 'FORGEActionTarget',
	Transition = 'FORGEActionTransition',
	Duration = 'FORGEActionDuration'
}

function Navigation:Get(Object)
	if not Object then
		return {
			Type = 'None',
			Target = '',
			Transition = 'None',
			Duration = .2
		}
	end

	return {
		Type = Object:GetAttribute(Attributes.Type) or 'None',
		Target = Object:GetAttribute(Attributes.Target) or '',
		Transition = Object:GetAttribute(Attributes.Transition) or 'None',
		Duration = tonumber(Object:GetAttribute(Attributes.Duration)) or .2
	}
end

function Navigation:Set(Object, Action)
	if not Object then return false end
	Action = Action or {}

	local Type = table.find(self.ActionTypes, Action.Type) and Action.Type or 'None'
	local Transition = table.find(self.Transitions, Action.Transition) and Action.Transition or 'None'
	local Target = tostring(Action.Target or '')
	local Duration = math.max(0, tonumber(Action.Duration) or .2)

	Object:SetAttribute(Attributes.Type, Type ~= 'None' and Type or nil)
	Object:SetAttribute(Attributes.Target, Target ~= '' and Target or nil)
	Object:SetAttribute(Attributes.Transition, Transition ~= 'None' and Transition or nil)
	Object:SetAttribute(Attributes.Duration, Duration)

	return true
end

function Navigation:Clear(Object)
	if not Object then return false end
	for _, Attribute in pairs(Attributes) do Object:SetAttribute(Attribute, nil) end
	return true
end

function Navigation:Has(Object)
	return Object and Object:GetAttribute(Attributes.Type) ~= nil or false
end

function Navigation:RemapScreenTarget(Root, OldName, NewName)
	if not Root then return 0 end
	local Count = 0
	local Objects = {Root}
	for _, Descendant in ipairs(Root:GetDescendants()) do table.insert(Objects, Descendant) end

	for _, Object in ipairs(Objects) do
		if Object:GetAttribute(Attributes.Type) == 'OpenScreen'
			and Object:GetAttribute(Attributes.Target) == OldName then
			Object:SetAttribute(Attributes.Target, NewName)
			Count += 1
		end
	end

	return Count
end

return Navigation
