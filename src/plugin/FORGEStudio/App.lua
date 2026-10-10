local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local StarterGui = game:GetService('StarterGui')
local GuiService = game:GetService('GuiService')
local StudioSelection = game:GetService('Selection')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')

local Theme = require(script.Parent.Theme)
local Document = require(script.Parent.Document)
local Selection = require(script.Parent.Selection)
local Widgets = require(script.Parent.Widgets)
local ComponentsModule = script.Parent:FindFirstChild('Components')
	or script.Parent.Parent:FindFirstChild('Components')
local Components = ComponentsModule and require(ComponentsModule)
local AnimationsModule = script.Parent:FindFirstChild('Animations')
	or script.Parent.Parent:FindFirstChild('Animations')
local BindingsModule = script.Parent:FindFirstChild('Bindings')
	or script.Parent.Parent:FindFirstChild('Bindings')
local MockDataModule = script.Parent:FindFirstChild('MockData')
	or script.Parent.Parent:FindFirstChild('MockData')
local ScreensModule = script.Parent:FindFirstChild('Screens')
	or script.Parent.Parent:FindFirstChild('Screens')
local NavigationModule = script.Parent:FindFirstChild('Navigation')
	or script.Parent.Parent:FindFirstChild('Navigation')
local StylePacksModule = script.Parent:FindFirstChild('StylePacks')
	or script.Parent.Parent:FindFirstChild('StylePacks')
local ComponentPresetsModule = script.Parent:FindFirstChild('ComponentPresets')
	or script.Parent.Parent:FindFirstChild('ComponentPresets')
local ModifiersModule = script.Parent:FindFirstChild('Modifiers')
	or script.Parent.Parent:FindFirstChild('Modifiers')
local Animations = AnimationsModule and require(AnimationsModule)
local Bindings = BindingsModule and require(BindingsModule)
local MockData = MockDataModule and require(MockDataModule)
local Screens = ScreensModule and require(ScreensModule)
local Navigation = NavigationModule and require(NavigationModule)
local StylePacks = StylePacksModule and require(StylePacksModule)
local ComponentPresets = ComponentPresetsModule and require(ComponentPresetsModule)
local Modifiers = ModifiersModule and require(ModifiersModule)
local PackagingModule = script.Parent:FindFirstChild('Packaging')
	or script.Parent.Parent:FindFirstChild('Packaging')
local ProblemsModule = script.Parent:FindFirstChild('Problems')
	or script.Parent.Parent:FindFirstChild('Problems')
local PersistenceModule = script.Parent:FindFirstChild('Persistence')
	or script.Parent.Parent:FindFirstChild('Persistence')
local Packaging = PackagingModule and require(PackagingModule)
local Problems = ProblemsModule and require(ProblemsModule)
local Persistence = PersistenceModule and require(PersistenceModule)
local HistoryModule = script.Parent:FindFirstChild('History')
local History

if HistoryModule then
	History = require(HistoryModule)
else
	History = {}
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

	function History:Reset(Label)
		for _, Snapshot in ipairs(self.Stack) do self:_DestroySnapshot(Snapshot) end
		table.clear(self.Stack)
		self.Index = 0
		self:Push(Label or 'Initial')
		return self
	end

	function History:Push(Label)
		for Index = #self.Stack, self.Index + 1, -1 do
			self:_DestroySnapshot(self.Stack[Index])
			table.remove(self.Stack, Index)
		end

		local Snapshot = self.Capture()
		Snapshot.Label = Label or 'Edit'
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
end

local App = {}
App.__index = App

local Properties = {
	'Name',
	'Position',
	'Size',
	'AnchorPoint',
	'BackgroundColor3',
	'BackgroundTransparency',
	'BorderSizePixel',
	'Visible',
	'ZIndex',
	'Rotation',
	'ClipsDescendants',
	'LayoutOrder',
	'Text',
	'TextColor3',
	'TextTransparency',
	'TextSize',
	'Image',
	'ImageColor3',
	'ImageTransparency',
	'Color',
	'Transparency',
	'Thickness',
	'CornerRadius',
	'PaddingLeft',
	'PaddingRight',
	'PaddingTop',
	'PaddingBottom',
	'Offset'
}

local InsertItems = {
	{Class = 'Frame', Category = 'Basic', Label = 'Frame'},
	{Class = 'TextLabel', Category = 'Basic', Label = 'Text'},
	{Class = 'ImageLabel', Category = 'Basic', Label = 'Image'}
}

local AnimationNativeProperties = {
	'Position',
	'Size',
	'AnchorPoint',
	'Rotation',
	'BackgroundColor3',
	'BackgroundTransparency',
	'Visible',
	'ZIndex',
	'TextColor3',
	'TextTransparency',
	'TextSize',
	'ImageColor3',
	'ImageTransparency',
	'GroupTransparency',
	'CanvasPosition',
	'ScrollBarImageColor3',
	'ScrollBarImageTransparency'
}
local function Clear(Container, Preserve)
	for _, Child in ipairs(Container:GetChildren()) do
		if not Preserve[Child] then Child:Destroy() end
	end
end

local function Round(Value)
	return math.floor(Value + .5)
end

local function Quantize(Value, Step)
	Step = tonumber(Step) or 0
	if Step <= 0 then return Value end
	return math.floor(Value / Step + .5) * Step
end

local function ColorToHex(Color)
	return string.format(
		'#%02X%02X%02X',
		Round(math.clamp(Color.R, 0, 1) * 255),
		Round(math.clamp(Color.G, 0, 1) * 255),
		Round(math.clamp(Color.B, 0, 1) * 255)
	)
end

local function HexToColor(Value)
	local Hex = tostring(Value or ''):gsub('#', ''):gsub('%s+', '')
	if #Hex == 3 then
		Hex = Hex:sub(1, 1):rep(2) .. Hex:sub(2, 2):rep(2) .. Hex:sub(3, 3):rep(2)
	end
	if #Hex ~= 6 or not Hex:match('^[%da-fA-F]+$') then return nil end
	return Color3.fromRGB(
		tonumber(Hex:sub(1, 2), 16),
		tonumber(Hex:sub(3, 4), 16),
		tonumber(Hex:sub(5, 6), 16)
	)
end

local function SplitNumbers(Text)
	local Values = {}
	for Number in tostring(Text):gmatch('[-+]?%d*%.?%d+') do
		table.insert(Values, tonumber(Number))
	end
	return Values
end

local function Format(Value)
	local Type = typeof(Value)
	if Type == 'Color3' then
		return string.format('%d, %d, %d', Round(Value.R * 255), Round(Value.G * 255), Round(Value.B * 255))
	elseif Type == 'Vector2' then
		return string.format('%.3f, %.3f', Value.X, Value.Y)
	elseif Type == 'UDim' then
		return string.format('%.3f, %d', Value.Scale, Value.Offset)
	elseif Type == 'UDim2' then
		return string.format('%.3f, %d, %.3f, %d', Value.X.Scale, Value.X.Offset, Value.Y.Scale, Value.Y.Offset)
	elseif Type == 'boolean' then
		return Value and 'true' or 'false'
	elseif Type == 'number' then
		return string.format('%.3f', Value):gsub('0+$', ''):gsub('%.$', '')
	end
	return tostring(Value)
end

local function Parse(Text, Original)
	local Type = typeof(Original)
	if Type == 'string' then
		return Text
	elseif Type == 'number' then
		return tonumber(Text)
	elseif Type == 'boolean' then
		local Lower = string.lower(Text)
		if Lower == 'true' or Lower == '1' then return true end
		if Lower == 'false' or Lower == '0' then return false end
	elseif Type == 'Color3' then
		local N = SplitNumbers(Text)
		if #N >= 3 then return Color3.fromRGB(math.clamp(N[1], 0, 255), math.clamp(N[2], 0, 255), math.clamp(N[3], 0, 255)) end
	elseif Type == 'Vector2' then
		local N = SplitNumbers(Text)
		if #N >= 2 then return Vector2.new(N[1], N[2]) end
	elseif Type == 'UDim' then
		local N = SplitNumbers(Text)
		if #N >= 2 then return UDim.new(N[1], N[2]) end
	elseif Type == 'UDim2' then
		local N = SplitNumbers(Text)
		if #N >= 4 then return UDim2.new(N[1], N[2], N[3], N[4]) end
	end
	return nil
end

local TransparencyGradientPresetOrder = {
	'None',
	'Fade Out',
	'Fade In',
	'Soft Fade Out',
	'Soft Fade In',
	'Center Visible',
	'Center Transparent'
}

local TransparencyGradientPresets = {
	['Fade Out'] = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	}),
	['Fade In'] = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0)
	}),
	['Soft Fade Out'] = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(.55, .08),
		NumberSequenceKeypoint.new(1, 1)
	}),
	['Soft Fade In'] = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(.45, .08),
		NumberSequenceKeypoint.new(1, 0)
	}),
	['Center Visible'] = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(.18, .42),
		NumberSequenceKeypoint.new(.5, 0),
		NumberSequenceKeypoint.new(.82, .42),
		NumberSequenceKeypoint.new(1, 1)
	}),
	['Center Transparent'] = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(.22, .08),
		NumberSequenceKeypoint.new(.5, 1),
		NumberSequenceKeypoint.new(.78, .08),
		NumberSequenceKeypoint.new(1, 0)
	})
}

local function SupportsTransparencyGradient(Object)
	return Object ~= nil and (
		Object:IsA('Frame')
		or Object:IsA('ImageLabel')
		or Object:IsA('ImageButton')
	)
end

local function Supports(Object, Property)
	return pcall(function()
		local _ = Object[Property]
	end)
end

local function LerpAnimationValue(A, B, Alpha)
	Alpha = math.clamp(Alpha, 0, 1)
	local Type = typeof(A)
	if Type ~= typeof(B) then return Alpha >= 1 and B or A end
	if Type == 'number' then return A + (B - A) * Alpha end
	if Type == 'Color3' then return A:Lerp(B, Alpha) end
	if Type == 'Vector2' then return A:Lerp(B, Alpha) end
	if Type == 'Vector3' then return A:Lerp(B, Alpha) end
	if Type == 'CFrame' then return A:Lerp(B, Alpha) end
	if Type == 'UDim' then
		return UDim.new(
			A.Scale + (B.Scale - A.Scale) * Alpha,
			A.Offset + (B.Offset - A.Offset) * Alpha
		)
	end
	if Type == 'UDim2' then
		return UDim2.new(
			A.X.Scale + (B.X.Scale - A.X.Scale) * Alpha,
			A.X.Offset + (B.X.Offset - A.X.Offset) * Alpha,
			A.Y.Scale + (B.Y.Scale - A.Y.Scale) * Alpha,
			A.Y.Offset + (B.Y.Offset - A.Y.Offset) * Alpha
		)
	end
	return Alpha >= 1 and B or A
end

local function ParseAnimationExpression(Text)
	local Value = tostring(Text or ''):match('^%s*(.-)%s*$')
	local Lower = string.lower(Value)
	if Lower == 'current' then return 'Current' end
	if Lower == 'default' or Lower == 'base' then return 'Default' end
	if Value:match('^[%+%-]?%d*%.?%d+%%$') then return Value end
	if Lower:match('^[%+%-]?%d*%.?%d+px$') then return Lower end
	return nil
end

local function ScaleAnimationValue(Base, Factor)
	local Type = typeof(Base)
	if Type == 'number' then return Base * Factor end
	if Type == 'Color3' then
		return Color3.new(
			math.clamp(Base.R * Factor, 0, 1),
			math.clamp(Base.G * Factor, 0, 1),
			math.clamp(Base.B * Factor, 0, 1)
		)
	end
	if Type == 'Vector2' then return Base * Factor end
	if Type == 'Vector3' then return Base * Factor end
	if Type == 'UDim' then return UDim.new(Base.Scale * Factor, Base.Offset * Factor) end
	if Type == 'UDim2' then
		return UDim2.new(
			Base.X.Scale * Factor,
			Base.X.Offset * Factor,
			Base.Y.Scale * Factor,
			Base.Y.Offset * Factor
		)
	end
	return nil
end

local function AddAnimationPixels(Base, Delta)
	local Type = typeof(Base)
	if Type == 'number' then return Base + Delta end
	if Type == 'Vector2' then return Base + Vector2.new(Delta, Delta) end
	if Type == 'Vector3' then return Base + Vector3.new(Delta, Delta, Delta) end
	if Type == 'UDim' then return UDim.new(Base.Scale, Base.Offset + Delta) end
	if Type == 'UDim2' then
		return UDim2.new(
			Base.X.Scale,
			Base.X.Offset + Delta,
			Base.Y.Scale,
			Base.Y.Offset + Delta
		)
	end
	return nil
end

local function ResolveAnimationEndpoint(DefaultBase, CurrentBase, Fallback, Expression)
	if not Expression or Expression == '' then return Fallback, true end
	if Expression == 'Current' then return CurrentBase, CurrentBase ~= nil end
	if Expression == 'Default' then return DefaultBase, DefaultBase ~= nil end

	local Percent = tostring(Expression):match('^([%+%-]?%d*%.?%d+)%%$')
	if Percent then
		local Result = ScaleAnimationValue(DefaultBase, 1 + (tonumber(Percent) or 0) / 100)
		return Result, Result ~= nil
	end

	local Pixels = string.lower(tostring(Expression)):match('^([%+%-]?%d*%.?%d+)px$')
	if Pixels then
		local Result = AddAnimationPixels(DefaultBase, tonumber(Pixels) or 0)
		return Result, Result ~= nil
	end

	return nil, false
end

local function FormatAnimationEndpoint(Value, Expression)
	return Expression or Format(Value)
end

function App.new(Plugin, Widget, Options)
	for _, Child in ipairs(Widget:GetChildren()) do
		if Child:IsA('GuiObject') and Child.Name == 'FORGEStudio' then Child:Destroy() end
	end

	pcall(function()
		Widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	end)

	local self = setmetatable({}, App)
	self.Plugin = Plugin
	self.Widget = Widget
	self.Options = Options or {}
	self.ReloadDev = self.Options.ReloadDev
	self.DevMode = self.Options.DevMode == true
	self.Document = Document.new()
	self.Selection = Selection.new(self.Document)
	self.Components = Components and Components.new() or nil
	self.Animations = Animations and Animations.new() or nil
	self.Bindings = Bindings
	self.MockData = MockData and MockData.new() or nil
	self.Screens = Screens and Screens.new() or nil
	self.Navigation = Navigation
	self.StylePacks = StylePacks
	self.ComponentPresets = ComponentPresets
	self.Modifiers = Modifiers
	self.Packaging = Packaging
	self.Problems = Problems
	self.Persistence = Persistence
	self.LastPackage = nil
	self.SaveGeneration = 0
	self.SaveDirtyVersion = 0
	self.SaveCommittedVersion = 0
	self.SaveTimerScheduled = false
	self.SaveInterval = 8
	self.SaveMaxDeferral = 120
	self.SaveDirtySince = nil
	self.SaveLastEditAt = 0
	self.SaveState = 'Unsaved'
	self.SaveDetail = 'No project save yet'
	self.LastSavedAt = nil
	self.SavingProject = false
	self.LastProblems = {}
	self.RuntimePreview = nil
	self.AutoRuntimePackageName = 'FORGEAutoProject'
	self.AutoRuntimeGuiName = 'FORGEAutoUI'
	self.RuntimeSyncState = 'Unsynced'
	self.RuntimeSyncDetail = 'No runtime snapshot'
	self.RuntimeSyncGeneration = 0
	self.LastPackageGeneration = -1
	self.RuntimeSyncing = false
	self.Destroyed = false
	self.ActiveStylePack = StylePacks and StylePacks.Default or 'Generic'
	self.SelectedSurface = 'Regular'
	self.SelectedTypography = 'Body'
	self.SelectedRarity = 'Common'
	self.Connections = {}
	self.RootConnections = {}
	self.RootRows = {}
	self.ChildRows = {}
	self.CollapsedChildren = setmetatable({}, {__mode = 'k'})
	self.ZoneGuidesVisible = true
	self.CameraBounds = nil
	self.CameraBoundsVisible = true
	self.SnapEnabled = false
	self.SnapIncrement = 5
	self.ShiftHeld = false
	self.ControlHeld = false
	self.Drag = nil
	self.PanDrag = nil
	self.HierarchyDrag = nil
	self.RootDrag = nil
	self.SuppressNextRootClick = false
	self.InsertContextPoint = nil
	self.InsertTargetOverride = nil
	self.RootContextTarget = nil
	self.RootContextPoint = nil
	self.ColorPropertyIndex = 1
	self.ColorPropertyOverride = nil
	self.ColorSemanticOverride = nil
	self.ColorRecent = {}
	do
		local Success, Saved = pcall(function()
			return Plugin:GetSetting('FORGEStudioRecentColors')
		end)
		if Success and type(Saved) == 'table' then
			for _, Value in ipairs(Saved) do
				local Color = HexToColor(Value)
				if Color then table.insert(self.ColorRecent, Color) end
				if #self.ColorRecent >= 8 then break end
			end
		end
	end
	self.ColorPickerDragging = nil
	self.ColorPickerDragStart = nil
	self.ColorPickerDragChanged = false
	self.SelectedComponent = nil
	self.SelectedVariant = 'Default'
	self.ComponentLibraryState = 'Unsynced'
	self.ComponentLibraryDetail = 'Runtime library has not been generated yet'
	self.ComponentLibraryGeneration = 0
	self.ComponentLibrarySyncing = false
	self.SelectedAnimation = nil
	self.SelectedTrack = nil
	self.AnimationTargetPath = 'Root'
	self.AnimationPropertyKind = 'Native'
	self.AnimationEasingStyle = Enum.EasingStyle.Quad
	self.AnimationEasingDirection = Enum.EasingDirection.Out
	self.AnimationScrubTime = 0
	self.AnimationTimelineDragging = false
	self.AnimationPreview = {
		Tweens = {},
		Originals = {},
		Connection = nil,
		Playing = false
	}
	self.BindingMode = 'Binding'
	self.SelectedBindingProperty = nil
	self.BindingAutoPreview = false
	self.BindingPreview = {
		Originals = {}
	}
	self.SelectedMockPath = nil
	self.MockDataType = 'String'
	self.SelectedScreen = nil
	self.DocumentScreen = nil
	self.FlowSourceObject = nil
	self.FlowActionType = 'None'
	self.FlowTransition = 'None'
	self.FlowDirty = false
	self.InteractiveMode = false
	self.Transitioning = false
	self.TransitionGeneration = 0
	self.PreviewOriginScreen = nil
	self.PreviewStack = {}
	self.InteractiveConnections = {}
	self.InteractiveAnimationSessions = {}
	self.InteractiveOriginals = {}
	self.TransitionTweens = {}
	self.PluginMouse = nil
	self.WidgetFocused = false
	self.TextEntryFocus = nil
	self.ShortcutKeysDown = {}
	self.ShortcutSurfaces = setmetatable({}, {__mode = 'k'})
	self.RefreshSuspended = false
	self.LastDragLayoutResolveAt = 0
	self.DragLayoutInterval = 1 / 30
	self.LastShortcutAction = nil
	self.LastShortcutAt = 0
	self.Clipboard = nil
	self.SecondaryBoxes = {}
	self.RootSelectionAnchor = nil
	self.ChildSelectionAnchor = nil
	self.RootDisplayOrder = {}
	self.ChildDisplayOrder = {}
	self.DeviceIndex = 1
	self.DeviceFitScale = 1
	self.Zoom = 1
	self.Pan = Vector2.new()
	self.PreviewScale = 1
	self.ResponsiveScale = 1
	self.ResponsiveLogicalSize = Theme.ReferenceSize or Vector2.new(1920, 1080)
	self.StrokeLODState = setmetatable({}, {__mode = 'k'})
	self.Restoring = false
	self.History = History.new(function(_, Scope)
		return self:_CaptureSnapshot(false, Scope)
	end, function(Snapshot)
		self:_RestoreSnapshot(Snapshot)
	end, 12)
	self:_Build()
	self:_Bind()
	self:_RefreshInsertPalette()

	if self.Options.Session then
		self:_RestoreSession(self.Options.Session)
	elseif not self:_RestorePersistentProject() then
		self:_Seed()
	end

	local Exports = ReplicatedStorage:FindFirstChild('FORGEExports')
	local LegacyAuto = Exports and Exports:FindFirstChild(self.AutoRuntimePackageName or 'FORGEAutoProject')
	if LegacyAuto and LegacyAuto:IsA('Folder') and LegacyAuto:GetAttribute('FORGEGeneratedPackage') == true then
		LegacyAuto:Destroy()
	end

	self:_EnsureScreens()
	self:_InstallStylePresets()
	self:_QueueComponentLibrarySync('Initial')
	self.History:Reset('Initial')
	return self
end

local function IsShiftInput(Input)
	return Input.KeyCode == Enum.KeyCode.LeftShift
		or Input.KeyCode == Enum.KeyCode.RightShift
end

local function IsControlInput(Input)
	return Input.KeyCode == Enum.KeyCode.LeftControl
		or Input.KeyCode == Enum.KeyCode.RightControl
end

local function IsShiftMouseKey(Key)
	local Lower = string.lower(tostring(Key or ''))
	if Lower == 'shift' or Lower == 'leftshift' or Lower == 'rightshift' then return true end

	local Numeric = tonumber(Lower)
	if Numeric == Enum.KeyCode.LeftShift.Value or Numeric == Enum.KeyCode.RightShift.Value then return true end

	local Byte
	pcall(function() Byte = string.byte(Lower) end)
	if Byte == Enum.KeyCode.LeftShift.Value or Byte == Enum.KeyCode.RightShift.Value then return true end

	local Codepoint
	pcall(function() Codepoint = utf8.codepoint(Lower) end)
	return Codepoint == Enum.KeyCode.LeftShift.Value or Codepoint == Enum.KeyCode.RightShift.Value
end

local function IsControlMouseKey(Key)
	local Lower = string.lower(tostring(Key or ''))
	return Lower == 'ctrl'
		or Lower == 'control'
		or Lower == 'leftcontrol'
		or Lower == 'rightcontrol'
end

function App:_Connect(Signal, Callback)
	local Connection = Signal:Connect(Callback)
	table.insert(self.Connections, Connection)
	return Connection
end

function App:_ShortcutContextActive()
	if not self.Root or not self.Root.Parent then return false end
	if not self.Widget or self.Widget.Enabled == false then return false end
	if self.TextEntryFocus and self.TextEntryFocus.Parent then return false end
	return true
end

function App:_RunShortcut(Action, Callback)
	local Now = os.clock()
	if self.LastShortcutAction == Action and Now - self.LastShortcutAt < .08 then return false end
	self.LastShortcutAction = Action
	self.LastShortcutAt = Now
	Callback()
	return true
end

function App:_WithRefreshSuspended(Callback)
	local Previous = self.RefreshSuspended
	self.RefreshSuspended = true
	local Result = table.pack(pcall(Callback))
	self.RefreshSuspended = Previous
	if not Result[1] then error(Result[2]) end
	return table.unpack(Result, 2, Result.n)
end

function App:_BindTextEntry(Object)
	if not Object or not Object:IsA('TextBox') then return end

	Object.Focused:Connect(function()
		self.WidgetFocused = true
		self.TextEntryFocus = Object
	end)

	Object.FocusLost:Connect(function()
		if self.TextEntryFocus == Object then self.TextEntryFocus = nil end
	end)
end

function App:_BindShortcutSurface(Object)
	if not Object or not Object:IsA('GuiObject') or self.ShortcutSurfaces[Object] then return end
	self.ShortcutSurfaces[Object] = true

	if Object:IsA('TextBox') then self:_BindTextEntry(Object) end

	Object.InputBegan:Connect(function(Input)
		self.WidgetFocused = true
		if Input.UserInputType ~= Enum.UserInputType.Keyboard then return end

		local Key = Input.KeyCode
		if Key == Enum.KeyCode.Unknown or self.ShortcutKeysDown[Key] then return end
		self.ShortcutKeysDown[Key] = true
		self:_HandleKeyboard(Input, false)
	end)

	Object.InputEnded:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		self.ShortcutKeysDown[Input.KeyCode] = nil
		self:_UpdateModifierInput(Input, false)
	end)
end

function App:_BindShortcutTree()
	self.Root.Active = true
	self:_BindShortcutSurface(self.Root)

	for _, Descendant in ipairs(self.Root:GetDescendants()) do
		if Descendant:IsA('GuiObject') then self:_BindShortcutSurface(Descendant) end
	end

	self:_Connect(self.Root.DescendantAdded, function(Descendant)
		if Descendant:IsA('GuiObject') then self:_BindShortcutSurface(Descendant) end
	end)
end

function App:_Build()
	local Root = Instance.new('Frame')
	Root.Name = 'FORGEStudio'
	Root.Size = UDim2.fromScale(1, 1)
	Root.Parent = self.Widget
	Widgets.Flat(Root, Theme.Color.FaceDarker)
	self.Root = Root

	local Menu = Instance.new('Frame')
	Menu.Name = 'Menu'
	Menu.Size = UDim2.new(1, 0, 0, Theme.Metric.MenuHeight)
	Menu.ZIndex = 2
	Menu.Parent = Root
	Widgets.Flat(Menu, Theme.Color.Window)
	Widgets.Bevel(Menu, true)
	self.AppBar = Menu

	local Brand = Widgets.Label(Menu, 'FORGE Studio', 13, true)
	Brand.Position = UDim2.fromOffset(12, 0)
	Brand.Size = UDim2.fromOffset(150, Theme.Metric.MenuHeight)
	Brand.TextXAlignment = Enum.TextXAlignment.Left
	Brand.TextColor3 = Theme.Color.Text

	local MenuX = 165
	local function MenuTool(TextValue, Width)
		local Button = Widgets.Button(Menu, TextValue)
		Button.Position = UDim2.fromOffset(MenuX, 4)
		Button.Size = UDim2.fromOffset(Width, 24)
		Button.ZIndex = Menu.ZIndex + 4
		MenuX += Width + 4
		return Button
	end

	self.StyleButton = MenuTool('Style', 52)
	self.AnimateButton = MenuTool('Animate', 68)
	self.BindingsButton = MenuTool('Bindings', 70)
	self.MockDataButton = MenuTool('Data', 48)
	self.ScreensButton = MenuTool('Screens', 64)
	self.FlowButton = MenuTool('Flow', 46)
	self.PackageButton = MenuTool('Build', 48)
	self.ProblemsButton = MenuTool('Problems', 68)

	if self.ReloadDev then
		self.ReloadDevButton = Widgets.Button(Menu, 'Reload')
		self.ReloadDevButton.AnchorPoint = Vector2.new(1, .5)
		self.ReloadDevButton.Position = UDim2.new(1, -8, .5, 0)
		self.ReloadDevButton.Size = UDim2.fromOffset(64, 24)
	end

	local Toolbar = Instance.new('Frame')
	Toolbar.Name = 'Toolbar'
	Toolbar.Position = UDim2.fromOffset(0, Theme.Metric.MenuHeight)
	Toolbar.Size = UDim2.new(1, 0, 0, Theme.Metric.ToolbarHeight)
	Toolbar.ZIndex = 2
	Toolbar.Parent = Root
	Widgets.Flat(Toolbar, Theme.Color.FaceDark)
	self.CommandBar = Toolbar

	local ToolX = 8
	local function Tool(TextValue, Width)
		local Button = Widgets.Button(Toolbar, TextValue)
		Button.Position = UDim2.fromOffset(ToolX, 7)
		Button.Size = UDim2.fromOffset(Width, 28)
		Button.ZIndex = Toolbar.ZIndex + 4
		ToolX += Width + 5
		return Button
	end

	local function Gap(Width)
		ToolX += Width or 8
	end

	local function HiddenTool()
		local Button = Widgets.Button(Toolbar, '')
		Button.Visible = false
		Button.Size = UDim2.fromOffset(0, 0)
		return Button
	end

	self.UndoButton = Tool('Undo', 48)
	self.RedoButton = Tool('Redo', 48)
	Gap(4)
	self.InsertButton = Tool('+ Insert', 72)
	self.ComponentsButton = Tool('Components', 88)
	Gap(6)

	self.CopyButton = HiddenTool()
	self.CutButton = HiddenTool()
	self.PasteButton = HiddenTool()
	self.DuplicateButton = HiddenTool()
	self.DeleteButton = HiddenTool()
	self.AddFrameButton = HiddenTool()
	self.AddTextButton = HiddenTool()
	self.AddChildButton = HiddenTool()
	self.AlignLeftButton = HiddenTool()
	self.AlignCenterXButton = HiddenTool()
	self.AlignRightButton = HiddenTool()
	self.AlignTopButton = HiddenTool()
	self.AlignCenterYButton = HiddenTool()
	self.AlignBottomButton = HiddenTool()
	self.DistributeHButton = HiddenTool()
	self.DistributeVButton = HiddenTool()
	self.EqualWidthButton = HiddenTool()
	self.EqualHeightButton = HiddenTool()
	self.EqualSizeButton = HiddenTool()

	self.DeviceButton = Widgets.DropdownButton(Toolbar, '')
	self.DeviceButton.Position = UDim2.fromOffset(ToolX, 7)
	self.DeviceButton.Size = UDim2.fromOffset(142, 28)
	self.DeviceButton.ZIndex = Toolbar.ZIndex + 4
	ToolX += 147

	self.ZoomOutButton = Tool('-', 30)
	self.ZoomLabel = Tool('100%', 52)
	self.ZoomInButton = Tool('+', 30)
	self.FitButton = Tool('Fit', 40)
	Gap(5)

	self.ZoneGuideButton = Tool('Guides', 58)
	self.CameraBoundsButton = Tool('Bounds', 62)
	self.SnapButton = Tool('Anchor', 58)

	local SnapLabel = Widgets.Label(Toolbar, 'Grid', 9, true)
	SnapLabel.Position = UDim2.fromOffset(ToolX, 7)
	SnapLabel.Size = UDim2.fromOffset(28, 28)
	SnapLabel.TextColor3 = Theme.Color.TextMuted
	ToolX += 30

	self.SnapStepBox = Widgets.TextBox(Toolbar, '5')
	self.SnapStepBox.Position = UDim2.fromOffset(ToolX, 7)
	self.SnapStepBox.Size = UDim2.fromOffset(48, 28)
	self.SnapStepBox.PlaceholderText = 'Off'
	self.SnapStepBox.ZIndex = Toolbar.ZIndex + 4

	local SnapUnit = Widgets.Label(Toolbar, 'px', 9, false)
	SnapUnit.Position = UDim2.fromOffset(ToolX + 50, 7)
	SnapUnit.Size = UDim2.fromOffset(20, 28)
	SnapUnit.TextColor3 = Theme.Color.TextMuted

	self.RuntimePreviewButton = Widgets.Button(Toolbar, 'Runtime')
	self.RuntimePreviewButton.AnchorPoint = Vector2.new(1, .5)
	self.RuntimePreviewButton.Position = UDim2.new(1, -8, .5, 0)
	self.RuntimePreviewButton.Size = UDim2.fromOffset(72, 28)
	self.RuntimePreviewButton.ZIndex = Toolbar.ZIndex + 4

	self.PreviewModeButton = Widgets.Button(Toolbar, 'Play UI')
	self.PreviewModeButton.AnchorPoint = Vector2.new(1, .5)
	self.PreviewModeButton.Position = UDim2.new(1, -85, .5, 0)
	self.PreviewModeButton.Size = UDim2.fromOffset(72, 28)
	self.PreviewModeButton.ZIndex = Toolbar.ZIndex + 4

	self.PreviewExitButton = Widgets.Button(Root, 'EXIT PREVIEW')
	self.PreviewExitButton.AnchorPoint = Vector2.new(.5, 0)
	self.PreviewExitButton.Position = UDim2.new(.5, 0, 0, Theme.Metric.MenuHeight + Theme.Metric.ToolbarHeight + 8)
	self.PreviewExitButton.Size = UDim2.fromOffset(126, 30)
	self.PreviewExitButton.ZIndex = 100000
	self.PreviewExitButton.Visible = false

	local Status = Instance.new('Frame')
	Status.Name = 'Status'
	Status.Position = UDim2.new(0, 0, 1, -Theme.Metric.StatusHeight)
	Status.Size = UDim2.new(1, 0, 0, Theme.Metric.StatusHeight)
	Status.ZIndex = 2
	Status.Parent = Root
	Widgets.Surface(Status, 'Header')
	self.StatusBar = Status

	self.StatusLabel = Widgets.Label(Status, 'Ready', 10, false)
	self.StatusLabel.Position = UDim2.fromOffset(5, 0)
	self.StatusLabel.Size = UDim2.new(1, -10, 1, 0)
	self.StatusLabel.TextColor3 = Theme.Color.TextMuted

	local Content = Instance.new('Frame')
	Content.Name = 'Workspace'
	Content.Position = UDim2.fromOffset(0, Theme.Metric.MenuHeight + Theme.Metric.ToolbarHeight)
	Content.Size = UDim2.new(1, 0, 1, -(Theme.Metric.MenuHeight + Theme.Metric.ToolbarHeight + Theme.Metric.StatusHeight))
	Content.ZIndex = 1
	Content.Parent = Root
	Widgets.Flat(Content, Theme.Color.FaceDarker)
	self.Content = Content

	local Left = Instance.new('Frame')
	Left.Name = 'LeftDock'
	Left.Size = UDim2.new(0, Theme.Metric.LeftWidth, 1, 0)
	Left.ZIndex = 50
	Left.ClipsDescendants = true
	Left.Parent = Content
	Widgets.Flat(Left, Theme.Color.FaceDarker)

	local Center = Instance.new('Frame')
	Center.Name = 'Center'
	Center.Position = UDim2.fromOffset(Theme.Metric.LeftWidth + Theme.Metric.Splitter, 0)
	Center.Size = UDim2.new(1, -(Theme.Metric.LeftWidth + Theme.Metric.RightWidth + Theme.Metric.Splitter * 2), 1, 0)
	Center.ZIndex = 10
	Center.ClipsDescendants = true
	Center.Parent = Content
	Widgets.Flat(Center, Theme.Color.Workspace)

	local Right = Instance.new('Frame')
	Right.Name = 'RightDock'
	Right.AnchorPoint = Vector2.new(1, 0)
	Right.Position = UDim2.new(1, 0, 0, 0)
	Right.Size = UDim2.new(0, Theme.Metric.RightWidth, 1, 0)
	Right.ZIndex = 50
	Right.ClipsDescendants = true
	Right.Parent = Content
	Widgets.Flat(Right, Theme.Color.FaceDarker)

	local LeftDivider = Instance.new('Frame')
	LeftDivider.BackgroundColor3 = Theme.Color.AccentMuted
	LeftDivider.BackgroundTransparency = .58
	LeftDivider.BorderSizePixel = 0
	LeftDivider.Position = UDim2.fromOffset(Theme.Metric.LeftWidth, 0)
	LeftDivider.Size = UDim2.new(0, Theme.Metric.Splitter, 1, 0)
	LeftDivider.ZIndex = 60
	LeftDivider.Parent = Content

	local RightDivider = Instance.new('Frame')
	RightDivider.BackgroundColor3 = Theme.Color.AccentMuted
	RightDivider.BackgroundTransparency = .58
	RightDivider.BorderSizePixel = 0
	RightDivider.AnchorPoint = Vector2.new(1, 0)
	RightDivider.Position = UDim2.new(1, -Theme.Metric.RightWidth, 0, 0)
	RightDivider.Size = UDim2.new(0, Theme.Metric.Splitter, 1, 0)
	RightDivider.ZIndex = 60
	RightDivider.Parent = Content

	self:_BuildExplorer(Left)
	self:_BuildChildren(Left)
	self:_BuildPreview(Center)
	self:_BuildColor(Right)
	self:_BuildProperties(Right)
	Widgets.SetActive(self.ZoneGuideButton, true)
	Widgets.SetActive(self.CameraBoundsButton, false)

	local PopupDismissLayer = Instance.new('TextButton')
	PopupDismissLayer.Name = 'PopupDismissLayer'
	PopupDismissLayer.AutoButtonColor = false
	PopupDismissLayer.BackgroundTransparency = 1
	PopupDismissLayer.BorderSizePixel = 0
	PopupDismissLayer.Text = ''
	PopupDismissLayer.Size = UDim2.fromScale(1, 1)
	PopupDismissLayer.Visible = false
	PopupDismissLayer.Active = true
	PopupDismissLayer.ZIndex = 19990
	PopupDismissLayer.Parent = Root
	self.PopupDismissLayer = PopupDismissLayer

	local DragCapture = Instance.new('TextButton')
	DragCapture.Name = 'HierarchyDragCapture'
	DragCapture.AutoButtonColor = false
	DragCapture.BackgroundTransparency = 1
	DragCapture.BorderSizePixel = 0
	DragCapture.Text = ''
	DragCapture.Size = UDim2.fromScale(1, 1)
	DragCapture.Visible = false
	DragCapture.Active = true
	DragCapture.ZIndex = 30000
	DragCapture.Parent = Root
	self.DragCapture = DragCapture

	self:_BuildZonePopup()
	self:_BuildDevicePopup()
	self:_BuildInsertPopup()
	self:_BuildRootContextPopup()
	self:_BuildComponentsPopup()
	self:_BuildStylePopup()
	self:_BuildAnimationPopup()
	self:_BuildBindingsPopup()
	self:_BuildMockDataPopup()
	self:_BuildScreensPopup()
	self:_BuildFlowPopup()
	self:_BuildProblemsPopup()
	self:_BuildPackagePopup()
	self:_BuildChoicePopup()
end
function App:_BuildExplorer(Parent)
	local Panel, Body = Widgets.Panel(Parent, 'Explorer')
	Panel.Size = UDim2.new(1, 0, Theme.Metric.ExplorerRatio, -Theme.Metric.Splitter / 2)
	self.ExplorerPanel = Panel

	self.ExplorerSearch = Widgets.TextBox(Body, '')
	self.ExplorerSearch.PlaceholderText = 'Search layers'
	self.ExplorerSearch.Position = UDim2.fromOffset(3, 3)
	self.ExplorerSearch.Size = UDim2.new(1, -6, 0, Theme.Metric.SearchHeight)

	local Scroll, Layout = Widgets.Scroll(Body)
	Scroll.Position = UDim2.fromOffset(3, Theme.Metric.SearchHeight + 6)
	Scroll.Size = UDim2.new(1, -6, 1, -(Theme.Metric.SearchHeight + 35))
	self.RootList = Scroll
	self.RootLayout = Layout

	local ZoneBar = Instance.new('Frame')
	ZoneBar.Position = UDim2.new(0, 3, 1, -26)
	ZoneBar.Size = UDim2.new(1, -6, 0, 23)
	ZoneBar.ZIndex = Body.ZIndex + 2
	ZoneBar.Parent = Body
	Widgets.Surface(ZoneBar, 'Header')

	local ZoneLabel = Widgets.Label(ZoneBar, 'ZONE', 9, true)
	ZoneLabel.Position = UDim2.fromOffset(5, 0)
	ZoneLabel.Size = UDim2.fromOffset(38, 23)
	ZoneLabel.TextColor3 = Theme.Color.TextMuted

	self.ZoneButton = Widgets.DropdownButton(ZoneBar, '-')
	self.ZoneButton.Position = UDim2.fromOffset(43, 2)
	self.ZoneButton.Size = UDim2.new(1, -45, 0, 19)
end
function App:_BuildChildren(Parent)
	local Panel, Body = Widgets.Panel(Parent, 'Hierarchy')
	Panel.Position = UDim2.new(0, 0, Theme.Metric.ExplorerRatio, Theme.Metric.Splitter / 2)
	Panel.Size = UDim2.new(1, 0, 1 - Theme.Metric.ExplorerRatio, -Theme.Metric.Splitter / 2)
	self.ChildrenPanel = Panel

	self.ChildrenSearch = Widgets.TextBox(Body, '')
	self.ChildrenSearch.PlaceholderText = 'Search hierarchy'
	self.ChildrenSearch.Position = UDim2.fromOffset(6, 6)
	self.ChildrenSearch.Size = UDim2.new(1, -12, 0, Theme.Metric.SearchHeight)

	local Hint = Widgets.Label(Body, 'Drag to reorder | arrows collapse | pencil renames', 9, false)
	Hint.Position = UDim2.fromOffset(8, Theme.Metric.SearchHeight + 8)
	Hint.Size = UDim2.new(1, -16, 0, 18)
	Hint.TextColor3 = Theme.Color.TextMuted

	local Scroll, Layout = Widgets.Scroll(Body)
	Scroll.Position = UDim2.fromOffset(6, Theme.Metric.SearchHeight + 29)
	Scroll.Size = UDim2.new(1, -12, 1, -(Theme.Metric.SearchHeight + 35))
	self.ChildList = Scroll
	self.ChildLayout = Layout
end
function App:_BuildPreview(Parent)
	local Panel, Body, Title = Widgets.Panel(Parent, 'Preview')
	Panel.Size = UDim2.fromScale(1, 1)
	self.PreviewPanel = Panel
	self.PreviewBody = Body
	self.CanvasContextLabel = Title
	Panel.ClipsDescendants = true
	Body.ClipsDescendants = true
	Widgets.Flat(Body, Theme.Color.Workspace)

	local Host = Instance.new('Frame')
	Host.Name = 'DeviceHost'
	Host.AnchorPoint = Vector2.new(.5, .5)
	Host.Position = UDim2.fromScale(.5, .5)
	Host.BackgroundTransparency = 1
	Host.BorderSizePixel = 0
	Host.ClipsDescendants = false
	Host.ZIndex = Panel.ZIndex + 2
	Host.Parent = Body
	self.DeviceHost = Host

	local Device = Instance.new('CanvasGroup')
	Device.Name = 'Screen'
	Device.GroupTransparency = 0
	Device.BackgroundColor3 = Theme.Color.Canvas
	Device.BorderSizePixel = 0
	Device.ClipsDescendants = false
	Device.Position = UDim2.fromOffset(0, 0)
	Device.ZIndex = Host.ZIndex + 1
	Device.Parent = Host
	self.Device = Device

	local DeviceStroke = Instance.new('UIStroke')
	DeviceStroke.Name = 'PreviewStroke'
	DeviceStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	DeviceStroke.LineJoinMode = Enum.LineJoinMode.Miter
	DeviceStroke.Color = Theme.Color.AccentMuted
	DeviceStroke.Transparency = .35
	DeviceStroke.Thickness = 2
	DeviceStroke.Parent = Device
	self.DeviceStroke = DeviceStroke

	local PreviewBaseZ = Device.ZIndex

	local DeviceScale = Instance.new('UIScale')
	DeviceScale.Scale = 1
	DeviceScale.Parent = Device
	self.DeviceScale = DeviceScale

	local AuthoringLayer = Instance.new('CanvasGroup')
	AuthoringLayer.Name = 'AuthoringLayer'
	AuthoringLayer.BackgroundTransparency = 1
	AuthoringLayer.BorderSizePixel = 0
	AuthoringLayer.Size = UDim2.fromScale(1, 1)
	AuthoringLayer.ZIndex = PreviewBaseZ + 10
	AuthoringLayer.GroupTransparency = 0
	AuthoringLayer.ClipsDescendants = false
	AuthoringLayer.Active = false
	AuthoringLayer.Parent = Device
	self.AuthoringLayer = AuthoringLayer

	local ResponsiveScale = Instance.new('UIScale')
	ResponsiveScale.Name = '_FORGEResponsiveScale'
	ResponsiveScale.Scale = 1
	ResponsiveScale.Parent = AuthoringLayer
	self.ResponsiveScaleObject = ResponsiveScale

	local Guides = Instance.new('Frame')
	Guides.Name = 'ZoneGuides'
	Guides.BackgroundTransparency = 1
	Guides.BorderSizePixel = 0
	Guides.Size = UDim2.fromScale(1, 1)
	Guides.ZIndex = PreviewBaseZ + 1
	Guides.Active = false
	Guides.Parent = Device
	self.ZoneGuides = Guides
	self.ZoneLines = {}

	for Index, Scale in ipairs({1 / 3, 2 / 3}) do
		local V = Instance.new('Frame')
		V.Name = 'Vertical' .. tostring(Index)
		V.BackgroundColor3 = Theme.Color.Guide
		V.BackgroundTransparency = .45
		V.BorderSizePixel = 0
		V.Position = UDim2.new(Scale, -1, 0, 0)
		V.Size = UDim2.new(0, 2, 1, 0)
		V.ZIndex = PreviewBaseZ + 1
		V.Active = false
		V.Parent = Guides
		table.insert(self.ZoneLines, {Object = V, Axis = 'X', Scale = Scale})

		local H = Instance.new('Frame')
		H.Name = 'Horizontal' .. tostring(Index)
		H.BackgroundColor3 = Theme.Color.Guide
		H.BackgroundTransparency = .45
		H.BorderSizePixel = 0
		H.Position = UDim2.new(0, 0, Scale, -1)
		H.Size = UDim2.new(1, 0, 0, 2)
		H.ZIndex = PreviewBaseZ + 1
		H.Active = false
		H.Parent = Guides
		table.insert(self.ZoneLines, {Object = H, Axis = 'Y', Scale = Scale})
	end

	local Abbr = {'TL', 'TC', 'TR', 'CL', 'C', 'CR', 'BL', 'BC', 'BR'}
	for Index, Name in ipairs(Abbr) do
		local Column = (Index - 1) % 3
		local Row = math.floor((Index - 1) / 3)
		local Label = Widgets.Label(Guides, Name, 9, false)
		Label.TextColor3 = Theme.Color.Guide
		Label.TextTransparency = .25
		Label.TextXAlignment = Enum.TextXAlignment.Center
		Label.Position = UDim2.new(Column / 3, 0, Row / 3, 0)
		Label.Size = UDim2.new(1 / 3, 0, 1 / 3, 0)
		Label.ZIndex = PreviewBaseZ + 1
		Label.Active = false
	end

	local CameraBoundsGuide = Instance.new('Frame')
	CameraBoundsGuide.Name = 'CameraBoundsGuide'
	CameraBoundsGuide.BackgroundTransparency = 1
	CameraBoundsGuide.BorderSizePixel = 0
	CameraBoundsGuide.Size = UDim2.fromScale(1, 1)
	CameraBoundsGuide.Visible = false
	CameraBoundsGuide.Active = false
	CameraBoundsGuide.ZIndex = PreviewBaseZ + 80
	CameraBoundsGuide.Parent = Device
	self.CameraBoundsGuide = CameraBoundsGuide
	self.CameraBoundsLines = {}

	for _, Name in ipairs({'Top', 'Right', 'Bottom', 'Left'}) do
		local Line = Instance.new('Frame')
		Line.Name = Name
		Line.BackgroundColor3 = Theme.Color.Guide
		Line.BackgroundTransparency = .08
		Line.BorderSizePixel = 0
		Line.ZIndex = CameraBoundsGuide.ZIndex
		Line.Active = false
		Line.Parent = CameraBoundsGuide
		self.CameraBoundsLines[Name] = Line
	end

	local SnapGuides = Instance.new('Frame')
	SnapGuides.Name = 'SnapGuides'
	SnapGuides.BackgroundTransparency = 1
	SnapGuides.BorderSizePixel = 0
	SnapGuides.Size = UDim2.fromScale(1, 1)
	SnapGuides.Visible = false
	SnapGuides.Active = false
	SnapGuides.ZIndex = PreviewBaseZ + 90
	SnapGuides.Parent = Device
	self.SnapGuides = SnapGuides

	self.SnapMarginLines = {}
	for _, Name in ipairs({'Top', 'Right', 'Bottom', 'Left'}) do
		local Line = Instance.new('Frame')
		Line.Name = Name
		Line.BackgroundColor3 = Theme.Color.Selection
		Line.BackgroundTransparency = .58
		Line.BorderSizePixel = 0
		Line.ZIndex = SnapGuides.ZIndex
		Line.Active = false
		Line.Parent = SnapGuides
		self.SnapMarginLines[Name] = Line
	end

	self.SnapMarkers = {}
	for _, Zone in ipairs(Theme.Zones) do
		local Marker = Instance.new('Frame')
		Marker.Name = Zone
		Marker.AnchorPoint = Vector2.new(.5, .5)
		Marker.Size = UDim2.fromOffset(7, 7)
		Marker.BackgroundColor3 = Theme.Color.Handle
		Marker.BorderColor3 = Theme.Color.Selection
		Marker.BorderSizePixel = 1
		Marker.ZIndex = SnapGuides.ZIndex + 1
		Marker.Active = false
		Marker.Parent = SnapGuides
		self.SnapMarkers[Zone] = Marker
	end

	local Interaction = Instance.new('TextButton')
	Interaction.Name = 'Interaction'
	Interaction.Text = ''
	Interaction.AutoButtonColor = false
	Interaction.BackgroundTransparency = 1
	Interaction.BorderSizePixel = 0
	Interaction.Size = UDim2.fromScale(1, 1)
	Interaction.ZIndex = PreviewBaseZ + 100
	Interaction.Parent = Device
	self.Interaction = Interaction

	self.SelectionLines = {}
	for _, Name in ipairs({'Top', 'Right', 'Bottom', 'Left'}) do
		local Line = Instance.new('Frame')
		Line.Name = Name
		Line.BackgroundColor3 = Theme.Color.HandleBorder
		Line.BorderSizePixel = 0
		Line.Visible = false
		Line.Active = false
		Line.ZIndex = PreviewBaseZ + 120
		Line.Parent = Device
		self.SelectionLines[Name] = Line
	end

	local Handles = {
		NW = Vector2.new(0, 0),
		N = Vector2.new(.5, 0),
		NE = Vector2.new(1, 0),
		E = Vector2.new(1, .5),
		SE = Vector2.new(1, 1),
		S = Vector2.new(.5, 1),
		SW = Vector2.new(0, 1),
		W = Vector2.new(0, .5)
	}

	self.Handles = {}
	for Name, Point in pairs(Handles) do
		local Handle = Instance.new('TextButton')
		Handle.Name = Name
		Handle.Text = ''
		Handle.AutoButtonColor = false
		Handle.AnchorPoint = Vector2.new(.5, .5)
		Handle.BackgroundTransparency = 1
		Handle.BorderSizePixel = 0
		Handle.Visible = false
		Handle.ZIndex = PreviewBaseZ + 122
		Handle.Parent = Device

		local Visual = Instance.new('Frame')
		Visual.Name = 'Visual'
		Visual.AnchorPoint = Vector2.new(.5, .5)
		Visual.Position = UDim2.fromScale(.5, .5)
		Visual.BackgroundColor3 = Theme.Color.Handle
		Visual.BorderColor3 = Theme.Color.HandleBorder
		Visual.BorderSizePixel = 1
		Visual.ZIndex = Handle.ZIndex + 1
		Visual.Active = false
		Visual.Parent = Handle

		self.Handles[Name] = {
			Object = Handle,
			Visual = Visual,
			Point = Point
		}
	end

	self:_FitDevice()
end

function App:_BuildColor(Parent)
	local Panel, Body = Widgets.Panel(Parent, 'Color')
	Panel.Size = UDim2.new(1, 0, 0, Theme.Metric.ColorPanelHeight)
	self.ColorPanel = Panel

	self.ColorTargetButton = Widgets.DropdownButton(Body, 'No color property')
	self.ColorTargetButton.Position = UDim2.fromOffset(3, 3)
	self.ColorTargetButton.Size = UDim2.new(1, -6, 0, 24)

	local SV = Instance.new('Frame')
	SV.Name = 'SV'
	SV.BackgroundColor3 = Color3.fromHSV(0, 1, 1)
	SV.BorderSizePixel = 0
	SV.Position = UDim2.fromOffset(3, 31)
	SV.Size = UDim2.new(1, -6, 0, 108)
	SV.ClipsDescendants = true
	SV.Parent = Body
	Widgets.Bevel(SV, true)
	self.ColorSV = SV

	local White = Instance.new('Frame')
	White.Name = 'White'
	White.BackgroundColor3 = Color3.new(1, 1, 1)
	White.BorderSizePixel = 0
	White.Size = UDim2.fromScale(1, 1)
	White.Parent = SV
	local WhiteGradient = Instance.new('UIGradient')
	WhiteGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	WhiteGradient.Parent = White

	local Black = Instance.new('Frame')
	Black.Name = 'Black'
	Black.BackgroundColor3 = Color3.new(0, 0, 0)
	Black.BorderSizePixel = 0
	Black.Size = UDim2.fromScale(1, 1)
	Black.Parent = SV
	local BlackGradient = Instance.new('UIGradient')
	BlackGradient.Rotation = 90
	BlackGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0)
	})
	BlackGradient.Parent = Black

	self.ColorSVHit = Instance.new('TextButton')
	self.ColorSVHit.Name = 'Hit'
	self.ColorSVHit.Text = ''
	self.ColorSVHit.AutoButtonColor = false
	self.ColorSVHit.BackgroundTransparency = 1
	self.ColorSVHit.BorderSizePixel = 0
	self.ColorSVHit.Size = UDim2.fromScale(1, 1)
	self.ColorSVHit.ZIndex = SV.ZIndex + 5
	self.ColorSVHit.Parent = SV

	local SVPointerShadow = Instance.new('Frame')
	SVPointerShadow.AnchorPoint = Vector2.new(.5, .5)
	SVPointerShadow.BackgroundTransparency = 1
	SVPointerShadow.BorderColor3 = Color3.new(0, 0, 0)
	SVPointerShadow.BorderSizePixel = 2
	SVPointerShadow.Size = UDim2.fromOffset(13, 13)
	SVPointerShadow.ZIndex = self.ColorSVHit.ZIndex + 1
	SVPointerShadow.Parent = SV
	self.ColorSVPointerShadow = SVPointerShadow

	self.ColorSVPointer = Instance.new('Frame')
	self.ColorSVPointer.AnchorPoint = Vector2.new(.5, .5)
	self.ColorSVPointer.BackgroundTransparency = 1
	self.ColorSVPointer.BorderColor3 = Color3.new(1, 1, 1)
	self.ColorSVPointer.BorderSizePixel = 2
	self.ColorSVPointer.Size = UDim2.fromOffset(9, 9)
	self.ColorSVPointer.ZIndex = SVPointerShadow.ZIndex + 1
	self.ColorSVPointer.Parent = SV

	local Hue = Instance.new('Frame')
	Hue.Name = 'Hue'
	Hue.BorderSizePixel = 0
	Hue.Position = UDim2.fromOffset(3, 145)
	Hue.Size = UDim2.new(1, -6, 0, 14)
	Hue.Parent = Body
	Widgets.Bevel(Hue, true)
	self.ColorHue = Hue

	local HueGradient = Instance.new('UIGradient')
	HueGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
		ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
		ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
		ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
		ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
		ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1))
	})
	HueGradient.Parent = Hue

	self.ColorHueHit = Instance.new('TextButton')
	self.ColorHueHit.Name = 'Hit'
	self.ColorHueHit.Text = ''
	self.ColorHueHit.AutoButtonColor = false
	self.ColorHueHit.BackgroundTransparency = 1
	self.ColorHueHit.BorderSizePixel = 0
	self.ColorHueHit.Size = UDim2.fromScale(1, 1)
	self.ColorHueHit.ZIndex = Hue.ZIndex + 2
	self.ColorHueHit.Parent = Hue

	self.ColorHuePointer = Instance.new('Frame')
	self.ColorHuePointer.AnchorPoint = Vector2.new(.5, .5)
	self.ColorHuePointer.BackgroundColor3 = Color3.new(1, 1, 1)
	self.ColorHuePointer.BorderColor3 = Color3.new(0, 0, 0)
	self.ColorHuePointer.BorderSizePixel = 1
	self.ColorHuePointer.Size = UDim2.new(0, 3, 1, 6)
	self.ColorHuePointer.ZIndex = self.ColorHueHit.ZIndex + 1
	self.ColorHuePointer.Parent = Hue

	local BeforeLabel = Widgets.Label(Body, 'BEFORE', 9, true)
	BeforeLabel.Position = UDim2.fromOffset(3, 165)
	BeforeLabel.Size = UDim2.fromOffset(66, 12)
	BeforeLabel.TextColor3 = Theme.Color.TextMuted

	local CurrentLabel = Widgets.Label(Body, 'CURRENT', 9, true)
	CurrentLabel.Position = UDim2.fromOffset(75, 165)
	CurrentLabel.Size = UDim2.fromOffset(66, 12)
	CurrentLabel.TextColor3 = Theme.Color.TextMuted

	local HexLabel = Widgets.Label(Body, 'HEX', 9, true)
	HexLabel.Position = UDim2.fromOffset(149, 165)
	HexLabel.Size = UDim2.new(1, -152, 0, 12)
	HexLabel.TextColor3 = Theme.Color.TextMuted

	self.ColorPreviousPreview = Instance.new('TextButton')
	self.ColorPreviousPreview.Name = 'Before'
	self.ColorPreviousPreview.Text = ''
	self.ColorPreviousPreview.AutoButtonColor = false
	self.ColorPreviousPreview.BorderSizePixel = 0
	self.ColorPreviousPreview.Position = UDim2.fromOffset(3, 178)
	self.ColorPreviousPreview.Size = UDim2.fromOffset(66, 26)
	self.ColorPreviousPreview.Parent = Body
	Widgets.Bevel(self.ColorPreviousPreview, true)

	self.ColorPreview = Instance.new('Frame')
	self.ColorPreview.Name = 'Current'
	self.ColorPreview.BackgroundColor3 = Theme.Color.PropertyValue
	self.ColorPreview.BorderSizePixel = 0
	self.ColorPreview.Position = UDim2.fromOffset(75, 178)
	self.ColorPreview.Size = UDim2.fromOffset(66, 26)
	self.ColorPreview.Parent = Body
	Widgets.Bevel(self.ColorPreview, true)

	self.ColorHexBox = Widgets.TextBox(Body, '#FFFFFF')
	self.ColorHexBox.Position = UDim2.fromOffset(149, 178)
	self.ColorHexBox.Size = UDim2.new(1, -152, 0, 26)

	local function ChannelRow(Y, GroupName, Names)
		local Group = Widgets.Label(Body, GroupName, 9, true)
		Group.Position = UDim2.fromOffset(3, Y)
		Group.Size = UDim2.fromOffset(30, 22)
		Group.TextColor3 = Theme.Color.TextMuted

		local Boxes = {}
		for Index, Name in ipairs(Names) do
			local X = 36 + (Index - 1) * 99
			local Label = Widgets.Label(Body, Name, 9, true)
			Label.Position = UDim2.fromOffset(X, Y)
			Label.Size = UDim2.fromOffset(14, 22)
			Label.TextColor3 = Theme.Color.TextMuted

			local Box = Widgets.TextBox(Body, '0')
			Box.Position = UDim2.fromOffset(X + 16, Y)
			Box.Size = UDim2.new(0, 77, 0, 22)
			Boxes[Index] = Box
		end
		return Boxes
	end

	self.ColorBoxes = ChannelRow(211, 'RGB', {'R', 'G', 'B'})
	self.ColorHSVBoxes = ChannelRow(236, 'HSV', {'H', 'S', 'V'})

	local RecentLabel = Widgets.Label(Body, 'RECENT', 9, true)
	RecentLabel.Position = UDim2.fromOffset(3, 263)
	RecentLabel.Size = UDim2.fromOffset(60, 12)
	RecentLabel.TextColor3 = Theme.Color.TextMuted

	local Recent = Instance.new('Frame')
	Recent.Name = 'Recent'
	Recent.BackgroundTransparency = 1
	Recent.BorderSizePixel = 0
	Recent.Position = UDim2.fromOffset(3, 277)
	Recent.Size = UDim2.new(1, -6, 0, 18)
	Recent.ZIndex = Body.ZIndex + 1
	Recent.Parent = Body
	self.ColorRecentButtons = {}

	for Index = 1, 8 do
		local Slot = Index
		local Button = Instance.new('TextButton')
		Button.Text = ''
		Button.AutoButtonColor = false
		Button.BackgroundColor3 = Theme.Color.FaceDark
		Button.BackgroundTransparency = 1
		Button.BorderSizePixel = 0
		Button.Position = UDim2.new((Index - 1) / 8, 1, 0, 0)
		Button.Size = UDim2.new(1 / 8, -3, 1, 0)
		Button.Visible = false
		Button.ZIndex = Recent.ZIndex + 1
		Button.Parent = Recent
		Widgets.Bevel(Button, true)
		Button.MouseButton1Click:Connect(function()
			local Color = self.ColorRecent and self.ColorRecent[Slot]
			if Color then self:_SetSelectedColor(Color) end
		end)
		self.ColorRecentButtons[Slot] = Button
	end

	local PaletteLabel = Widgets.Label(Body, 'PALETTE', 9, true)
	PaletteLabel.Position = UDim2.fromOffset(3, 296)
	PaletteLabel.Size = UDim2.fromOffset(60, 12)
	PaletteLabel.TextColor3 = Theme.Color.TextMuted

	local Swatches = Instance.new('Frame')
	Swatches.Name = 'Palette'
	Swatches.BackgroundTransparency = 1
	Swatches.BorderSizePixel = 0
	Swatches.Position = UDim2.fromOffset(3, 310)
	Swatches.Size = UDim2.new(1, -6, 0, 28)
	Swatches.ZIndex = Body.ZIndex + 1
	Swatches.Parent = Body

	local Columns = 12
	for Index, Color in ipairs(Theme.ClassicColors) do
		local Column = (Index - 1) % Columns
		local Row = math.floor((Index - 1) / Columns)
		local Button = Instance.new('TextButton')
		Button.Text = ''
		Button.AutoButtonColor = false
		Button.BackgroundColor3 = Color
		Button.BorderSizePixel = 0
		Button.ZIndex = Swatches.ZIndex + 1
		Button.Position = UDim2.new(Column / Columns, 1, Row / 2, 1)
		Button.Size = UDim2.new(1 / Columns, -3, 1 / 2, -3)
		Button.Parent = Swatches
		Widgets.Bevel(Button, true)
		Button.MouseButton1Click:Connect(function()
			self:_SetSelectedColor(Color)
		end)
	end

	self:_RefreshColorRecents()
end
function App:_BuildProperties(Parent)
	local Panel, Body, Title = Widgets.Panel(Parent, 'Properties')
	Panel.Position = UDim2.fromOffset(0, Theme.Metric.ColorPanelHeight + Theme.Metric.Splitter)
	Panel.Size = UDim2.new(1, 0, 1, -(Theme.Metric.ColorPanelHeight + Theme.Metric.Splitter))
	self.PropertiesPanel = Panel
	self.PropertiesTitle = Title

	self.PropertiesSearch = Widgets.TextBox(Body, '')
	self.PropertiesSearch.PlaceholderText = 'Search properties'
	self.PropertiesSearch.Position = UDim2.fromOffset(3, 3)
	self.PropertiesSearch.Size = UDim2.new(1, -6, 0, Theme.Metric.SearchHeight)

	local Scroll, Layout = Widgets.Scroll(Body)
	Scroll.Position = UDim2.fromOffset(3, Theme.Metric.SearchHeight + 6)
	Scroll.Size = UDim2.new(1, -6, 1, -(Theme.Metric.SearchHeight + 9))
	self.PropertiesList = Scroll
	self.PropertiesLayout = Layout
end
function App:_BuildChoicePopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'ChoicePopup'
	Popup.Visible = false
	Popup.ZIndex = 30000
	Popup.Parent = self.Root
	Widgets.Surface(Popup, 'Panel')
	self.ChoicePopup = Popup

	local Scroll, Layout = Widgets.Scroll(Popup)
	Scroll.Position = UDim2.fromOffset(3, 3)
	Scroll.Size = UDim2.new(1, -6, 1, -6)
	Scroll.ZIndex = Popup.ZIndex + 1
	Layout.Padding = UDim.new(0, 2)
	self.ChoiceList = Scroll
	self.ChoiceLayout = Layout
end

function App:_HideChoicePopup()
	if self.ChoicePopup then self.ChoicePopup.Visible = false end
	self.ChoiceAnchor = nil
end

function App:_ShowChoicePopup(Button, Items, Current, Callback, Formatter)
	if not Button or not self.ChoicePopup or not self.ChoiceList then return end
	Items = Items or {}

	if self.ChoicePopup.Visible and self.ChoiceAnchor == Button then
		self:_HideChoicePopup()
		return
	end

	for _, Child in ipairs(self.ChoiceList:GetChildren()) do
		if Child ~= self.ChoiceLayout then Child:Destroy() end
	end

	local Height = math.clamp(#Items * 27 + 8, 35, 280)
	local Width = math.max(Button.AbsoluteSize.X, 170)
	self.ChoicePopup.Size = UDim2.fromOffset(Width, Height)

	for Index, Item in ipairs(Items) do
		local Label = Formatter and Formatter(Item, Index) or tostring(Item)
		local IsSelected = Item == Current or Label == tostring(Current)
		local Choice = Widgets.Button(self.ChoiceList, (IsSelected and '[x] ' or '    ') .. Label)
		Choice.Size = UDim2.new(1, -2, 0, 25)
		Choice.LayoutOrder = Index
		Choice.ZIndex = self.ChoicePopup.ZIndex + 2
		Choice.TextXAlignment = Enum.TextXAlignment.Left

		Choice.MouseButton1Click:Connect(function()
			self:_HideChoicePopup()
			if Callback then Callback(Item, Index) end
		end)
	end

	local Absolute = Button.AbsolutePosition - self.Root.AbsolutePosition
	local X = math.clamp(Absolute.X, 0, math.max(0, self.Root.AbsoluteSize.X - Width))
	local Y = Absolute.Y + Button.AbsoluteSize.Y + 3
	if Y + Height > self.Root.AbsoluteSize.Y then
		Y = math.max(0, Absolute.Y - Height - 3)
	end

	self.ChoicePopup.Position = UDim2.fromOffset(X, Y)
	self.ChoicePopup.Visible = true
	self.ChoiceAnchor = Button
end

function App:_BuildZonePopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'ZonePopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(142, #Theme.Zones * 19 + 2)
	Popup.Visible = false
	Popup.ZIndex = 20000
	Popup.Parent = self.Root
	self.ZonePopup = Popup

	for Index, Zone in ipairs(Theme.Zones) do
		local Button = Widgets.Button(Popup, Zone)
		Button.Position = UDim2.fromOffset(1, 1 + (Index - 1) * 19)
		Button.Size = UDim2.new(1, -2, 0, 19)
		Button.ZIndex = Popup.ZIndex + 1
		Button.MouseButton1Click:Connect(function()
			self:_SetSelectedZone(Zone)
			Popup.Visible = false
		end)
	end
end

function App:_BuildDevicePopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'DevicePopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(170, #Theme.Devices * 21 + 2)
	Popup.Visible = false
	Popup.ZIndex = 20000
	Popup.Parent = self.Root
	self.DevicePopup = Popup

	for Index, Device in ipairs(Theme.Devices) do
		local Label = Device.Name .. '   ' .. Device.Width .. 'x' .. Device.Height
		if Device.Dynamic == 'StudioViewport' then
			local Camera = workspace.CurrentCamera
			local Size = Camera and Camera.ViewportSize or Vector2.new(Device.Width, Device.Height)
			Label = string.format('%s   %dx%d', Device.Name, math.floor(Size.X + .5), math.floor(Size.Y + .5))
		end
		local Button = Widgets.Button(Popup, Label)
		Button.Position = UDim2.fromOffset(1, 1 + (Index - 1) * 21)
		Button.Size = UDim2.new(1, -2, 0, 21)
		Button.ZIndex = Popup.ZIndex + 1
		Button.MouseButton1Click:Connect(function()
			self.DeviceIndex = Index
			self.Zoom = 1
			self.Pan = Vector2.new()
			Popup.Visible = false
			self:_FitDevice()
		end)
	end
end

function App:_BuildInsertPopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'InsertPopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(248, 360)
	Popup.ClipsDescendants = true
	Popup.Visible = false
	Popup.ZIndex = 20000
	Popup.Parent = self.Root
	self.InsertPopup = Popup

	local Title = Widgets.Label(Popup, 'Insert Object', 11, true)
	Title.Position = UDim2.fromOffset(6, 3)
	Title.Size = UDim2.new(1, -12, 0, 18)
	Title.ZIndex = Popup.ZIndex + 1
	self.InsertTitle = Title

	self.InsertSearch = Widgets.TextBox(Popup, '')
	self.InsertSearch.PlaceholderText = 'Search'
	self.InsertSearch.Position = UDim2.fromOffset(5, 24)
	self.InsertSearch.Size = UDim2.new(1, -10, 0, 21)
	self.InsertSearch.ZIndex = Popup.ZIndex + 1

	self.InsertPackButton = Widgets.DropdownButton(Popup, 'RUCKUS')
	self.InsertPackButton.Visible = false
	self.InsertPackButton.Size = UDim2.fromOffset(0, 0)

	local Scroll, Layout = Widgets.Scroll(Popup)
	Scroll.Position = UDim2.fromOffset(5, 49)
	Scroll.Size = UDim2.new(1, -10, 1, -54)
	Scroll.ZIndex = Popup.ZIndex + 1
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	self.InsertList = Scroll
	self.InsertLayout = Layout
end

function App:_BuildRootContextPopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'RootContextPopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(184, 186)
	Popup.Visible = false
	Popup.ZIndex = 21000
	Popup.Parent = self.Root
	self.RootContextPopup = Popup

	local Items = {
		{'Insert Child', 'RootContextInsertButton'},
		{'Duplicate', 'RootContextDuplicateButton'},
		{'Copy', 'RootContextCopyButton'},
		{'Cut', 'RootContextCutButton'},
		{'Hide', 'RootContextVisibleButton'},
		{'Lock', 'RootContextLockButton'},
		{'Delete', 'RootContextDeleteButton'}
	}

	for Index, Entry in ipairs(Items) do
		local Button = Widgets.Button(Popup, Entry[1])
		Button.Position = UDim2.fromOffset(5, 5 + (Index - 1) * 25)
		Button.Size = UDim2.new(1, -10, 0, 22)
		Button.TextXAlignment = Enum.TextXAlignment.Left
		Button:SetAttribute('FORGETextInsetLeft', 8)
		Button.ZIndex = Popup.ZIndex + 2
		self[Entry[2]] = Button
	end
end

function App:_BuildComponentsPopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'ComponentsPopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(360, 552)
	Popup.Visible = false
	Popup.ZIndex = 20000
	Popup.Parent = self.Root
	self.ComponentsPopup = Popup

	local Title = Widgets.Label(Popup, 'Component Library', 11, true)
	Title.Position = UDim2.fromOffset(6, 3)
	Title.Size = UDim2.new(1, -12, 0, 18)
	Title.ZIndex = Popup.ZIndex + 1

	local Subtitle = Widgets.Label(Popup, 'Register once  •  reuse in Designer  •  publish for runtime', 9, false)
	Subtitle.TextColor3 = Theme.Color.TextMuted
	Subtitle.Position = UDim2.fromOffset(6, 21)
	Subtitle.Size = UDim2.new(1, -12, 0, 15)
	Subtitle.ZIndex = Popup.ZIndex + 1

	self.ComponentSearch = Widgets.TextBox(Popup, '')
	self.ComponentSearch.PlaceholderText = 'Search component library'
	self.ComponentSearch.Position = UDim2.fromOffset(5, 39)
	self.ComponentSearch.Size = UDim2.new(1, -10, 0, 21)
	self.ComponentSearch.ZIndex = Popup.ZIndex + 1

	local Scroll, Layout = Widgets.Scroll(Popup)
	Scroll.Position = UDim2.fromOffset(5, 64)
	Scroll.Size = UDim2.new(1, -10, 0, 122)
	Scroll.ZIndex = Popup.ZIndex + 1
	self.ComponentList = Scroll
	self.ComponentLayout = Layout

	self.ComponentInfoLabel = Widgets.Label(Popup, 'No component selected', 9, false)
	self.ComponentInfoLabel.TextColor3 = Theme.Color.TextMuted
	self.ComponentInfoLabel.Position = UDim2.fromOffset(6, 190)
	self.ComponentInfoLabel.Size = UDim2.new(1, -12, 0, 17)
	self.ComponentInfoLabel.ZIndex = Popup.ZIndex + 1

	local NameLabel = Widgets.Label(Popup, 'NAME', 9, true)
	NameLabel.TextColor3 = Theme.Color.TextMuted
	NameLabel.Position = UDim2.fromOffset(6, 212)
	NameLabel.Size = UDim2.fromOffset(42, 20)
	NameLabel.ZIndex = Popup.ZIndex + 1

	self.ComponentNameBox = Widgets.TextBox(Popup, '')
	self.ComponentNameBox.PlaceholderText = 'PartyMember'
	self.ComponentNameBox.Position = UDim2.fromOffset(50, 212)
	self.ComponentNameBox.Size = UDim2.new(1, -56, 0, 20)
	self.ComponentNameBox.ZIndex = Popup.ZIndex + 1

	self.ComponentCreateButton = Widgets.Button(Popup, 'REGISTER SELECTION')
	self.ComponentCreateButton.Position = UDim2.fromOffset(5, 237)
	self.ComponentCreateButton.Size = UDim2.new(1, -10, 0, 23)
	self.ComponentCreateButton.ZIndex = Popup.ZIndex + 1

	self.ComponentInstanceButton = Widgets.Button(Popup, 'Insert')
	self.ComponentInstanceButton.Position = UDim2.fromOffset(5, 264)
	self.ComponentInstanceButton.Size = UDim2.fromOffset(72, 23)
	self.ComponentInstanceButton.ZIndex = Popup.ZIndex + 1

	self.ComponentUpdateButton = Widgets.Button(Popup, 'Update Source')
	self.ComponentUpdateButton.Position = UDim2.fromOffset(80, 264)
	self.ComponentUpdateButton.Size = UDim2.fromOffset(92, 23)
	self.ComponentUpdateButton.ZIndex = Popup.ZIndex + 1

	self.ComponentDetachButton = Widgets.Button(Popup, 'Detach')
	self.ComponentDetachButton.Position = UDim2.fromOffset(175, 264)
	self.ComponentDetachButton.Size = UDim2.fromOffset(72, 23)
	self.ComponentDetachButton.ZIndex = Popup.ZIndex + 1

	self.ComponentDeleteButton = Widgets.Button(Popup, 'Delete')
	self.ComponentDeleteButton.Position = UDim2.fromOffset(250, 264)
	self.ComponentDeleteButton.Size = UDim2.new(1, -255, 0, 23)
	self.ComponentDeleteButton.ZIndex = Popup.ZIndex + 1

	local VariantHeader = Widgets.Label(Popup, 'STATE / VARIANT', 9, true)
	VariantHeader.TextColor3 = Theme.Color.TextMuted
	VariantHeader.Position = UDim2.fromOffset(6, 294)
	VariantHeader.Size = UDim2.new(1, -12, 0, 18)
	VariantHeader.ZIndex = Popup.ZIndex + 1

	self.VariantButton = Widgets.DropdownButton(Popup, 'State: Default')
	self.VariantButton.Position = UDim2.fromOffset(5, 314)
	self.VariantButton.Size = UDim2.new(1, -10, 0, 21)
	self.VariantButton.ZIndex = Popup.ZIndex + 1

	self.VariantNameBox = Widgets.TextBox(Popup, '')
	self.VariantNameBox.PlaceholderText = 'New state name'
	self.VariantNameBox.Position = UDim2.fromOffset(5, 339)
	self.VariantNameBox.Size = UDim2.new(1, -10, 0, 21)
	self.VariantNameBox.ZIndex = Popup.ZIndex + 1

	self.VariantSaveButton = Widgets.Button(Popup, 'Save')
	self.VariantSaveButton.Position = UDim2.fromOffset(5, 364)
	self.VariantSaveButton.Size = UDim2.fromOffset(55, 23)
	self.VariantSaveButton.ZIndex = Popup.ZIndex + 1

	self.VariantRenameButton = Widgets.Button(Popup, 'Rename')
	self.VariantRenameButton.Position = UDim2.fromOffset(63, 364)
	self.VariantRenameButton.Size = UDim2.fromOffset(65, 23)
	self.VariantRenameButton.ZIndex = Popup.ZIndex + 1

	self.VariantDeleteButton = Widgets.Button(Popup, 'Delete')
	self.VariantDeleteButton.Position = UDim2.fromOffset(131, 364)
	self.VariantDeleteButton.Size = UDim2.fromOffset(58, 23)
	self.VariantDeleteButton.ZIndex = Popup.ZIndex + 1

	self.VariantApplyButton = Widgets.Button(Popup, 'Preview / Apply')
	self.VariantApplyButton.Position = UDim2.fromOffset(192, 364)
	self.VariantApplyButton.Size = UDim2.new(1, -197, 0, 23)
	self.VariantApplyButton.ZIndex = Popup.ZIndex + 1

	local SlotHeader = Widgets.Label(Popup, 'CONTENT SLOT', 9, true)
	SlotHeader.TextColor3 = Theme.Color.TextMuted
	SlotHeader.Position = UDim2.fromOffset(6, 394)
	SlotHeader.Size = UDim2.new(1, -12, 0, 18)
	SlotHeader.ZIndex = Popup.ZIndex + 1

	self.SlotNameBox = Widgets.TextBox(Popup, '')
	self.SlotNameBox.PlaceholderText = 'Slot name (ex: Content)'
	self.SlotNameBox.Position = UDim2.fromOffset(5, 414)
	self.SlotNameBox.Size = UDim2.new(1, -10, 0, 21)
	self.SlotNameBox.ZIndex = Popup.ZIndex + 1

	self.SlotMarkButton = Widgets.Button(Popup, 'Mark Selected Child')
	self.SlotMarkButton.Position = UDim2.fromOffset(5, 439)
	self.SlotMarkButton.Size = UDim2.new(.62, -7, 0, 23)
	self.SlotMarkButton.ZIndex = Popup.ZIndex + 1

	self.SlotClearButton = Widgets.Button(Popup, 'Clear Slot')
	self.SlotClearButton.Position = UDim2.new(.62, 0, 0, 439)
	self.SlotClearButton.Size = UDim2.new(.38, -5, 0, 23)
	self.SlotClearButton.ZIndex = Popup.ZIndex + 1

	local RuntimeHeader = Widgets.Label(Popup, 'RUNTIME LIBRARY', 9, true)
	RuntimeHeader.TextColor3 = Theme.Color.TextMuted
	RuntimeHeader.Position = UDim2.fromOffset(6, 469)
	RuntimeHeader.Size = UDim2.new(1, -12, 0, 18)
	RuntimeHeader.ZIndex = Popup.ZIndex + 1

	self.ComponentLibraryStatusLabel = Widgets.Label(
		Popup,
		'ReplicatedStorage.FORGEComponents\nUnsynced',
		9,
		false
	)
	self.ComponentLibraryStatusLabel.TextColor3 = Theme.Color.TextMuted
	self.ComponentLibraryStatusLabel.Position = UDim2.fromOffset(6, 489)
	self.ComponentLibraryStatusLabel.Size = UDim2.new(1, -12, 0, 29)
	self.ComponentLibraryStatusLabel.TextWrapped = true
	self.ComponentLibraryStatusLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.ComponentLibraryStatusLabel.ZIndex = Popup.ZIndex + 1

	self.ComponentLibrarySyncButton = Widgets.Button(Popup, 'Sync Runtime Library')
	self.ComponentLibrarySyncButton.Position = UDim2.fromOffset(5, 522)
	self.ComponentLibrarySyncButton.Size = UDim2.new(.62, -7, 0, 23)
	self.ComponentLibrarySyncButton.ZIndex = Popup.ZIndex + 1

	self.ComponentLibraryRevealButton = Widgets.Button(Popup, 'Reveal Folder')
	self.ComponentLibraryRevealButton.Position = UDim2.new(.62, 0, 0, 522)
	self.ComponentLibraryRevealButton.Size = UDim2.new(.38, -5, 0, 23)
	self.ComponentLibraryRevealButton.ZIndex = Popup.ZIndex + 1
end

function App:_BuildStylePopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'StylePopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(330, 360)
	Popup.Visible = false
	Popup.ZIndex = 20000
	Popup.Parent = self.Root
	self.StylePopup = Popup

	local Title = Widgets.Label(Popup, 'Style Pack', 11, true)
	Title.Position = UDim2.fromOffset(6, 3)
	Title.Size = UDim2.new(1, -12, 0, 18)
	Title.ZIndex = Popup.ZIndex + 1

	self.StylePackButton = Widgets.DropdownButton(Popup, 'Pack: RUCKUS')
	self.StylePackButton.Position = UDim2.fromOffset(5, 25)
	self.StylePackButton.Size = UDim2.new(1, -10, 0, 23)
	self.StylePackButton.ZIndex = Popup.ZIndex + 1

	local SurfaceLabel = Widgets.Label(Popup, 'Surface', 10, true)
	SurfaceLabel.Position = UDim2.fromOffset(6, 55)
	SurfaceLabel.Size = UDim2.fromOffset(70, 18)
	SurfaceLabel.ZIndex = Popup.ZIndex + 1

	self.StyleSurfaceButton = Widgets.DropdownButton(Popup, 'Regular')
	self.StyleSurfaceButton.Position = UDim2.fromOffset(5, 75)
	self.StyleSurfaceButton.Size = UDim2.new(1, -96, 0, 22)
	self.StyleSurfaceButton.ZIndex = Popup.ZIndex + 1

	self.StyleApplySurfaceButton = Widgets.Button(Popup, 'Apply')
	self.StyleApplySurfaceButton.Position = UDim2.new(1, -86, 0, 75)
	self.StyleApplySurfaceButton.Size = UDim2.fromOffset(81, 22)
	self.StyleApplySurfaceButton.ZIndex = Popup.ZIndex + 1

	local TypeLabel = Widgets.Label(Popup, 'Typography', 10, true)
	TypeLabel.Position = UDim2.fromOffset(6, 104)
	TypeLabel.Size = UDim2.fromOffset(80, 18)
	TypeLabel.ZIndex = Popup.ZIndex + 1

	self.StyleTypographyButton = Widgets.DropdownButton(Popup, 'Body')
	self.StyleTypographyButton.Position = UDim2.fromOffset(5, 124)
	self.StyleTypographyButton.Size = UDim2.new(1, -96, 0, 22)
	self.StyleTypographyButton.ZIndex = Popup.ZIndex + 1

	self.StyleApplyTypographyButton = Widgets.Button(Popup, 'Apply')
	self.StyleApplyTypographyButton.Position = UDim2.new(1, -86, 0, 124)
	self.StyleApplyTypographyButton.Size = UDim2.fromOffset(81, 22)
	self.StyleApplyTypographyButton.ZIndex = Popup.ZIndex + 1

	local RarityLabel = Widgets.Label(Popup, 'Rarity', 10, true)
	RarityLabel.Position = UDim2.fromOffset(6, 153)
	RarityLabel.Size = UDim2.fromOffset(70, 18)
	RarityLabel.ZIndex = Popup.ZIndex + 1

	self.StyleRarityButton = Widgets.DropdownButton(Popup, 'Common')
	self.StyleRarityButton.Position = UDim2.fromOffset(5, 173)
	self.StyleRarityButton.Size = UDim2.new(1, -96, 0, 22)
	self.StyleRarityButton.ZIndex = Popup.ZIndex + 1

	self.StyleApplyRarityButton = Widgets.Button(Popup, 'Apply')
	self.StyleApplyRarityButton.Position = UDim2.new(1, -86, 0, 173)
	self.StyleApplyRarityButton.Size = UDim2.fromOffset(81, 22)
	self.StyleApplyRarityButton.ZIndex = Popup.ZIndex + 1

	local PaletteLabel = Widgets.Label(Popup, 'Palette', 10, true)
	PaletteLabel.Position = UDim2.fromOffset(6, 202)
	PaletteLabel.Size = UDim2.fromOffset(70, 18)
	PaletteLabel.ZIndex = Popup.ZIndex + 1

	local Palette = Instance.new('Frame')
	Palette.BackgroundTransparency = 1
	Palette.BorderSizePixel = 0
	Palette.Position = UDim2.fromOffset(5, 223)
	Palette.Size = UDim2.new(1, -10, 0, 48)
	Palette.ZIndex = Popup.ZIndex + 1
	Palette.Parent = Popup

	self.StyleSwatches = {}
	for Index, Name in ipairs({'Base', 'Ivory', 'Warm', 'Accent', 'Danger', 'Success', 'Gold', 'Silver'}) do
		local Button = Instance.new('TextButton')
		Button.Name = Name
		Button.Text = ''
		Button.AutoButtonColor = false
		Button.BorderColor3 = Theme.Color.FaceDarker
		Button.BorderSizePixel = 1
		Button.Position = UDim2.new((Index - 1) / 8, 1, 0, 0)
		Button.Size = UDim2.new(1 / 8, -3, 1, 0)
		Button.ZIndex = Palette.ZIndex + 1
		Button.Parent = Palette
		self.StyleSwatches[Name] = Button
	end

	self.StyleInfoLabel = Widgets.Label(Popup, '', 9, false)
	self.StyleInfoLabel.TextColor3 = Theme.Color.TextMuted
	self.StyleInfoLabel.Position = UDim2.fromOffset(6, 280)
	self.StyleInfoLabel.Size = UDim2.new(1, -12, 0, 70)
	self.StyleInfoLabel.TextWrapped = true
	self.StyleInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.StyleInfoLabel.ZIndex = Popup.ZIndex + 1
end

function App:_BuildAnimationPopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'AnimationPopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(650, 580)
	Popup.Visible = false
	Popup.ZIndex = 20000
	Popup.Parent = self.Root
	self.AnimationPopup = Popup

	local Title = Widgets.Label(Popup, 'Animation Designer', 12, true)
	Title.Position = UDim2.fromOffset(8, 4)
	Title.Size = UDim2.new(1, -16, 0, 18)
	Title.ZIndex = Popup.ZIndex + 1

	self.AnimationSearch = Widgets.TextBox(Popup, '')
	self.AnimationSearch.PlaceholderText = 'Search animations'
	self.AnimationSearch.Position = UDim2.fromOffset(8, 28)
	self.AnimationSearch.Size = UDim2.fromOffset(182, 24)
	self.AnimationSearch.ZIndex = Popup.ZIndex + 1

	local AnimationScroll, AnimationLayout = Widgets.Scroll(Popup)
	AnimationScroll.Position = UDim2.fromOffset(8, 57)
	AnimationScroll.Size = UDim2.fromOffset(182, 170)
	AnimationScroll.ZIndex = Popup.ZIndex + 1
	self.AnimationList = AnimationScroll
	self.AnimationLayout = AnimationLayout

	self.AnimationNameBox = Widgets.TextBox(Popup, '')
	self.AnimationNameBox.PlaceholderText = 'Animation name'
	self.AnimationNameBox.Position = UDim2.fromOffset(8, 233)
	self.AnimationNameBox.Size = UDim2.fromOffset(182, 24)
	self.AnimationNameBox.ZIndex = Popup.ZIndex + 1

	self.AnimationCreateButton = Widgets.Button(Popup, 'Create')
	self.AnimationCreateButton.Position = UDim2.fromOffset(8, 262)
	self.AnimationCreateButton.Size = UDim2.fromOffset(56, 23)
	self.AnimationCreateButton.ZIndex = Popup.ZIndex + 1

	self.AnimationRenameButton = Widgets.Button(Popup, 'Rename')
	self.AnimationRenameButton.Position = UDim2.fromOffset(68, 262)
	self.AnimationRenameButton.Size = UDim2.fromOffset(59, 23)
	self.AnimationRenameButton.ZIndex = Popup.ZIndex + 1

	self.AnimationDeleteButton = Widgets.Button(Popup, 'Delete')
	self.AnimationDeleteButton.Position = UDim2.fromOffset(131, 262)
	self.AnimationDeleteButton.Size = UDim2.fromOffset(59, 23)
	self.AnimationDeleteButton.ZIndex = Popup.ZIndex + 1

	self.AnimationLoopButton = Widgets.Button(Popup, 'Loop: Off')
	self.AnimationLoopButton.Position = UDim2.fromOffset(8, 291)
	self.AnimationLoopButton.Size = UDim2.fromOffset(84, 23)
	self.AnimationLoopButton.ZIndex = Popup.ZIndex + 1

	self.AnimationReverseButton = Widgets.Button(Popup, 'Yoyo: Off')
	self.AnimationReverseButton.Position = UDim2.fromOffset(97, 291)
	self.AnimationReverseButton.Size = UDim2.fromOffset(93, 23)
	self.AnimationReverseButton.ZIndex = Popup.ZIndex + 1

	local StaggerLabel = Widgets.Label(Popup, 'Stagger', 9, true)
	StaggerLabel.Position = UDim2.fromOffset(8, 320)
	StaggerLabel.Size = UDim2.fromOffset(54, 22)
	StaggerLabel.TextColor3 = Theme.Color.TextMuted
	StaggerLabel.ZIndex = Popup.ZIndex + 1

	self.AnimationStaggerBox = Widgets.TextBox(Popup, '0')
	self.AnimationStaggerBox.Position = UDim2.fromOffset(66, 320)
	self.AnimationStaggerBox.Size = UDim2.fromOffset(124, 22)
	self.AnimationStaggerBox.ZIndex = Popup.ZIndex + 1

	self.AnimationPresetLabel = Widgets.Label(Popup, 'Preset: none', 9, false)
	self.AnimationPresetLabel.Position = UDim2.fromOffset(8, 349)
	self.AnimationPresetLabel.Size = UDim2.fromOffset(182, 18)
	self.AnimationPresetLabel.TextColor3 = Theme.Color.TextMuted
	self.AnimationPresetLabel.TextTruncate = Enum.TextTruncate.AtEnd
	self.AnimationPresetLabel.ZIndex = Popup.ZIndex + 1

	self.AnimationPresetButton = Widgets.Button(Popup, 'Make Preset')
	self.AnimationPresetButton.Position = UDim2.fromOffset(8, 371)
	self.AnimationPresetButton.Size = UDim2.fromOffset(88, 23)
	self.AnimationPresetButton.ZIndex = Popup.ZIndex + 1

	self.AnimationPresetClearButton = Widgets.Button(Popup, 'Clear Preset')
	self.AnimationPresetClearButton.Position = UDim2.fromOffset(101, 371)
	self.AnimationPresetClearButton.Size = UDim2.fromOffset(89, 23)
	self.AnimationPresetClearButton.ZIndex = Popup.ZIndex + 1

	self.AnimationInheritEndButton = Widgets.Button(Popup, 'Inherit End...')
	self.AnimationInheritEndButton.Position = UDim2.fromOffset(8, 401)
	self.AnimationInheritEndButton.Size = UDim2.fromOffset(182, 23)
	self.AnimationInheritEndButton.ZIndex = Popup.ZIndex + 1

	self.AnimationReverseFromButton = Widgets.Button(Popup, 'Reverse From...')
	self.AnimationReverseFromButton.Position = UDim2.fromOffset(8, 429)
	self.AnimationReverseFromButton.Size = UDim2.fromOffset(182, 23)
	self.AnimationReverseFromButton.ZIndex = Popup.ZIndex + 1

	local TrackHeader = Widgets.Label(Popup, 'Tracks', 10, true)
	TrackHeader.Position = UDim2.fromOffset(202, 28)
	TrackHeader.Size = UDim2.fromOffset(430, 18)
	TrackHeader.ZIndex = Popup.ZIndex + 1

	local TrackScroll, TrackLayout = Widgets.Scroll(Popup)
	TrackScroll.Position = UDim2.fromOffset(202, 49)
	TrackScroll.Size = UDim2.fromOffset(440, 142)
	TrackScroll.ZIndex = Popup.ZIndex + 1
	self.AnimationTrackList = TrackScroll
	self.AnimationTrackLayout = TrackLayout

	local TriggerLabel = Widgets.Label(Popup, 'Trigger', 9, true)
	TriggerLabel.Position = UDim2.fromOffset(202, 198)
	TriggerLabel.Size = UDim2.fromOffset(40, 24)
	TriggerLabel.TextColor3 = Theme.Color.TextMuted
	TriggerLabel.ZIndex = Popup.ZIndex + 1

	self.AnimationTriggerButtons = {}
	local TriggerX = 244
	for _, Trigger in ipairs({'Manual', 'Hover', 'HoverEnd', 'Press', 'Release', 'Click'}) do
		local Width = Trigger == 'HoverEnd' and 60
			or Trigger == 'Release' and 52
			or Trigger == 'Manual' and 50
			or 44
		local Button = Widgets.Button(Popup, Trigger)
		Button.Position = UDim2.fromOffset(TriggerX, 198)
		Button.Size = UDim2.fromOffset(Width, 24)
		Button.ZIndex = Popup.ZIndex + 1
		self.AnimationTriggerButtons[Trigger] = Button
		TriggerX += Width + 3
	end

	self.AnimationTriggerLabel = Widgets.Label(Popup, 'Trigger target: Root', 9, false)
	self.AnimationTriggerLabel.Position = UDim2.fromOffset(202, 224)
	self.AnimationTriggerLabel.Size = UDim2.fromOffset(320, 22)
	self.AnimationTriggerLabel.TextColor3 = Theme.Color.TextMuted
	self.AnimationTriggerLabel.TextTruncate = Enum.TextTruncate.AtEnd
	self.AnimationTriggerLabel.ZIndex = Popup.ZIndex + 1

	self.AnimationTriggerTargetButton = Widgets.Button(Popup, 'Bind Selected')
	self.AnimationTriggerTargetButton.Position = UDim2.fromOffset(530, 224)
	self.AnimationTriggerTargetButton.Size = UDim2.fromOffset(107, 22)
	self.AnimationTriggerTargetButton.ZIndex = Popup.ZIndex + 1

	self.AnimationTargetLabel = Widgets.Label(Popup, 'Target: (select object)', 10, false)
	self.AnimationTargetLabel.Position = UDim2.fromOffset(202, 251)
	self.AnimationTargetLabel.Size = UDim2.fromOffset(300, 22)
	self.AnimationTargetLabel.TextTruncate = Enum.TextTruncate.AtEnd
	self.AnimationTargetLabel.ZIndex = Popup.ZIndex + 1

	self.AnimationTargetButton = Widgets.Button(Popup, 'Use Selection')
	self.AnimationTargetButton.Position = UDim2.fromOffset(507, 251)
	self.AnimationTargetButton.Size = UDim2.fromOffset(130, 22)
	self.AnimationTargetButton.ZIndex = Popup.ZIndex + 1

	self.AnimationPropertyKindButton = Widgets.DropdownButton(Popup, 'Native')
	self.AnimationPropertyKindButton.Position = UDim2.fromOffset(202, 279)
	self.AnimationPropertyKindButton.Size = UDim2.fromOffset(92, 24)
	self.AnimationPropertyKindButton.ZIndex = Popup.ZIndex + 1

	self.AnimationPropertyBox = Widgets.TextBox(Popup, '')
	self.AnimationPropertyBox.PlaceholderText = 'Property'
	self.AnimationPropertyBox.Position = UDim2.fromOffset(299, 279)
	self.AnimationPropertyBox.Size = UDim2.fromOffset(218, 24)
	self.AnimationPropertyBox.ZIndex = Popup.ZIndex + 1

	self.AnimationPropertyPickButton = Widgets.Button(Popup, 'Pick')
	self.AnimationPropertyPickButton.Position = UDim2.fromOffset(522, 279)
	self.AnimationPropertyPickButton.Size = UDim2.fromOffset(115, 24)
	self.AnimationPropertyPickButton.ZIndex = Popup.ZIndex + 1

	self.AnimationFromBox = Widgets.TextBox(Popup, '')
	self.AnimationFromBox.PlaceholderText = 'From / Current / Default / +10%'
	self.AnimationFromBox.Position = UDim2.fromOffset(202, 309)
	self.AnimationFromBox.Size = UDim2.fromOffset(164, 24)
	self.AnimationFromBox.ZIndex = Popup.ZIndex + 1

	self.AnimationFromCurrentButton = Widgets.Button(Popup, 'From Current')
	self.AnimationFromCurrentButton.Position = UDim2.fromOffset(371, 309)
	self.AnimationFromCurrentButton.Size = UDim2.fromOffset(96, 24)
	self.AnimationFromCurrentButton.ZIndex = Popup.ZIndex + 1

	self.AnimationToBox = Widgets.TextBox(Popup, '')
	self.AnimationToBox.PlaceholderText = 'To / Default / +10% / -4px'
	self.AnimationToBox.Position = UDim2.fromOffset(472, 309)
	self.AnimationToBox.Size = UDim2.fromOffset(165, 24)
	self.AnimationToBox.ZIndex = Popup.ZIndex + 1

	self.AnimationToCurrentButton = Widgets.Button(Popup, 'To Current')
	self.AnimationToCurrentButton.Position = UDim2.fromOffset(541, 337)
	self.AnimationToCurrentButton.Size = UDim2.fromOffset(96, 24)
	self.AnimationToCurrentButton.ZIndex = Popup.ZIndex + 1

	self.AnimationDurationBox = Widgets.TextBox(Popup, '.2')
	self.AnimationDurationBox.PlaceholderText = 'Duration'
	self.AnimationDurationBox.Position = UDim2.fromOffset(202, 337)
	self.AnimationDurationBox.Size = UDim2.fromOffset(76, 24)
	self.AnimationDurationBox.ZIndex = Popup.ZIndex + 1

	self.AnimationDelayBox = Widgets.TextBox(Popup, '0')
	self.AnimationDelayBox.PlaceholderText = 'Delay'
	self.AnimationDelayBox.Position = UDim2.fromOffset(283, 337)
	self.AnimationDelayBox.Size = UDim2.fromOffset(66, 24)
	self.AnimationDelayBox.ZIndex = Popup.ZIndex + 1

	self.AnimationEasingButton = Widgets.DropdownButton(Popup, 'Quad')
	self.AnimationEasingButton.Position = UDim2.fromOffset(354, 337)
	self.AnimationEasingButton.Size = UDim2.fromOffset(100, 24)
	self.AnimationEasingButton.ZIndex = Popup.ZIndex + 1

	self.AnimationDirectionButton = Widgets.DropdownButton(Popup, 'Out')
	self.AnimationDirectionButton.Position = UDim2.fromOffset(459, 337)
	self.AnimationDirectionButton.Size = UDim2.fromOffset(77, 24)
	self.AnimationDirectionButton.ZIndex = Popup.ZIndex + 1

	self.AnimationAddTrackButton = Widgets.Button(Popup, 'Add Track')
	self.AnimationAddTrackButton.Position = UDim2.fromOffset(202, 367)
	self.AnimationAddTrackButton.Size = UDim2.fromOffset(78, 24)
	self.AnimationAddTrackButton.ZIndex = Popup.ZIndex + 1

	self.AnimationUpdateTrackButton = Widgets.Button(Popup, 'Update')
	self.AnimationUpdateTrackButton.Position = UDim2.fromOffset(285, 367)
	self.AnimationUpdateTrackButton.Size = UDim2.fromOffset(70, 24)
	self.AnimationUpdateTrackButton.ZIndex = Popup.ZIndex + 1

	self.AnimationDeleteTrackButton = Widgets.Button(Popup, 'Delete')
	self.AnimationDeleteTrackButton.Position = UDim2.fromOffset(360, 367)
	self.AnimationDeleteTrackButton.Size = UDim2.fromOffset(67, 24)
	self.AnimationDeleteTrackButton.ZIndex = Popup.ZIndex + 1

	self.AnimationCaptureButton = Widgets.Button(Popup, 'Current -> Both')
	self.AnimationCaptureButton.Position = UDim2.fromOffset(432, 367)
	self.AnimationCaptureButton.Size = UDim2.fromOffset(110, 24)
	self.AnimationCaptureButton.ZIndex = Popup.ZIndex + 1

	local TimelineLabel = Widgets.Label(Popup, 'Timeline', 10, true)
	TimelineLabel.Position = UDim2.fromOffset(8, 399)
	TimelineLabel.Size = UDim2.fromOffset(100, 18)
	TimelineLabel.ZIndex = Popup.ZIndex + 1

	self.AnimationLengthLabel = Widgets.Label(Popup, '0.00s', 9, false)
	self.AnimationLengthLabel.Position = UDim2.new(1, -100, 0, 399)
	self.AnimationLengthLabel.Size = UDim2.fromOffset(92, 18)
	self.AnimationLengthLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.AnimationLengthLabel.TextColor3 = Theme.Color.TextMuted
	self.AnimationLengthLabel.ZIndex = Popup.ZIndex + 1

	self.AnimationTimeline = Widgets.Button(Popup, '')
	self.AnimationTimeline.Position = UDim2.fromOffset(8, 421)
	self.AnimationTimeline.Size = UDim2.new(1, -16, 0, 28)
	self.AnimationTimeline.ZIndex = Popup.ZIndex + 1

	local Fill = Instance.new('Frame')
	Fill.Name = 'Fill'
	Fill.BackgroundColor3 = Theme.Color.Selection
	Fill.BackgroundTransparency = .45
	Fill.BorderSizePixel = 0
	Fill.Size = UDim2.fromScale(0, 1)
	Fill.ZIndex = self.AnimationTimeline.ZIndex + 2
	Fill.Parent = self.AnimationTimeline
	self.AnimationTimelineFill = Fill

	local Playhead = Instance.new('Frame')
	Playhead.Name = 'Playhead'
	Playhead.BackgroundColor3 = Theme.Color.Highlight
	Playhead.BorderSizePixel = 0
	Playhead.AnchorPoint = Vector2.new(.5, 0)
	Playhead.Position = UDim2.fromScale(0, 0)
	Playhead.Size = UDim2.fromOffset(2, 28)
	Playhead.ZIndex = self.AnimationTimeline.ZIndex + 3
	Playhead.Parent = self.AnimationTimeline
	self.AnimationTimelinePlayhead = Playhead

	self.AnimationTimeBox = Widgets.TextBox(Popup, '0')
	self.AnimationTimeBox.Position = UDim2.fromOffset(8, 456)
	self.AnimationTimeBox.Size = UDim2.fromOffset(76, 24)
	self.AnimationTimeBox.ZIndex = Popup.ZIndex + 1

	self.AnimationPlayButton = Widgets.Button(Popup, 'Play')
	self.AnimationPlayButton.Position = UDim2.fromOffset(90, 456)
	self.AnimationPlayButton.Size = UDim2.fromOffset(62, 24)
	self.AnimationPlayButton.ZIndex = Popup.ZIndex + 1

	self.AnimationStopButton = Widgets.Button(Popup, 'Stop')
	self.AnimationStopButton.Position = UDim2.fromOffset(157, 456)
	self.AnimationStopButton.Size = UDim2.fromOffset(62, 24)
	self.AnimationStopButton.ZIndex = Popup.ZIndex + 1

	self.AnimationResetButton = Widgets.Button(Popup, 'Reset')
	self.AnimationResetButton.Position = UDim2.fromOffset(224, 456)
	self.AnimationResetButton.Size = UDim2.fromOffset(62, 24)
	self.AnimationResetButton.ZIndex = Popup.ZIndex + 1

	self.AnimationInfoLabel = Widgets.Label(Popup, 'No animation selected', 9, false)
	self.AnimationInfoLabel.TextColor3 = Theme.Color.TextMuted
	self.AnimationInfoLabel.Position = UDim2.fromOffset(8, 488)
	self.AnimationInfoLabel.Size = UDim2.new(1, -16, 0, 84)
	self.AnimationInfoLabel.TextWrapped = true
	self.AnimationInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.AnimationInfoLabel.ZIndex = Popup.ZIndex + 1
end


function App:_BuildBindingsPopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'BindingsPopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(330, 360)
	Popup.Visible = false
	Popup.ZIndex = 20000
	Popup.Parent = self.Root
	self.BindingsPopup = Popup

	local Title = Widgets.Label(Popup, 'Bindings', 11, true)
	Title.Position = UDim2.fromOffset(6, 3)
	Title.Size = UDim2.new(1, -12, 0, 18)
	Title.ZIndex = Popup.ZIndex + 1

	self.BindingTargetLabel = Widgets.Label(Popup, 'Target: (select object)', 10, false)
	self.BindingTargetLabel.Position = UDim2.fromOffset(6, 24)
	self.BindingTargetLabel.Size = UDim2.new(1, -12, 0, 18)
	self.BindingTargetLabel.ZIndex = Popup.ZIndex + 1

	local Scroll, Layout = Widgets.Scroll(Popup)
	Scroll.Position = UDim2.fromOffset(5, 45)
	Scroll.Size = UDim2.new(1, -10, 0, 105)
	Scroll.ZIndex = Popup.ZIndex + 1
	self.BindingList = Scroll
	self.BindingLayout = Layout

	self.BindingModeButton = Widgets.DropdownButton(Popup, 'Mode: Binding')
	self.BindingModeButton.Position = UDim2.fromOffset(5, 155)
	self.BindingModeButton.Size = UDim2.fromOffset(104, 21)
	self.BindingModeButton.ZIndex = Popup.ZIndex + 1

	self.BindingPropertyBox = Widgets.TextBox(Popup, '')
	self.BindingPropertyBox.PlaceholderText = 'Property'
	self.BindingPropertyBox.Position = UDim2.fromOffset(112, 155)
	self.BindingPropertyBox.Size = UDim2.new(1, -117, 0, 21)
	self.BindingPropertyBox.ZIndex = Popup.ZIndex + 1

	self.BindingPathBox = Widgets.TextBox(Popup, '')
	self.BindingPathBox.PlaceholderText = 'Data path, e.g. Player.DisplayName'
	self.BindingPathBox.Position = UDim2.fromOffset(5, 180)
	self.BindingPathBox.Size = UDim2.new(1, -10, 0, 21)
	self.BindingPathBox.ZIndex = Popup.ZIndex + 1

	self.BindingResolvedLabel = Widgets.Label(Popup, 'Resolved: -', 10, false)
	self.BindingResolvedLabel.Position = UDim2.fromOffset(6, 205)
	self.BindingResolvedLabel.Size = UDim2.new(1, -12, 0, 18)
	self.BindingResolvedLabel.ZIndex = Popup.ZIndex + 1

	self.BindingSetButton = Widgets.Button(Popup, 'Set')
	self.BindingSetButton.Position = UDim2.fromOffset(5, 228)
	self.BindingSetButton.Size = UDim2.fromOffset(52, 21)
	self.BindingSetButton.ZIndex = Popup.ZIndex + 1

	self.BindingClearButton = Widgets.Button(Popup, 'Clear')
	self.BindingClearButton.Position = UDim2.fromOffset(60, 228)
	self.BindingClearButton.Size = UDim2.fromOffset(52, 21)
	self.BindingClearButton.ZIndex = Popup.ZIndex + 1

	self.BindingApplyButton = Widgets.Button(Popup, 'Preview Target')
	self.BindingApplyButton.Position = UDim2.fromOffset(115, 228)
	self.BindingApplyButton.Size = UDim2.fromOffset(92, 21)
	self.BindingApplyButton.ZIndex = Popup.ZIndex + 1

	self.BindingApplyAllButton = Widgets.Button(Popup, 'Preview All')
	self.BindingApplyAllButton.Position = UDim2.fromOffset(210, 228)
	self.BindingApplyAllButton.Size = UDim2.fromOffset(72, 21)
	self.BindingApplyAllButton.ZIndex = Popup.ZIndex + 1

	self.BindingResetButton = Widgets.Button(Popup, 'Reset')
	self.BindingResetButton.Position = UDim2.fromOffset(285, 228)
	self.BindingResetButton.Size = UDim2.fromOffset(40, 21)
	self.BindingResetButton.ZIndex = Popup.ZIndex + 1

	self.BindingAutoButton = Widgets.Button(Popup, 'Auto Preview: Off')
	self.BindingAutoButton.Position = UDim2.fromOffset(5, 255)
	self.BindingAutoButton.Size = UDim2.fromOffset(118, 21)
	self.BindingAutoButton.ZIndex = Popup.ZIndex + 1

	self.BindingInfoLabel = Widgets.Label(Popup, 'Bindings are stored on the selected object.', 9, false)
	self.BindingInfoLabel.TextColor3 = Theme.Color.TextMuted
	self.BindingInfoLabel.Position = UDim2.fromOffset(6, 283)
	self.BindingInfoLabel.Size = UDim2.new(1, -12, 0, 65)
	self.BindingInfoLabel.TextWrapped = true
	self.BindingInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.BindingInfoLabel.ZIndex = Popup.ZIndex + 1
end

function App:_BuildMockDataPopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'MockDataPopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(330, 390)
	Popup.Visible = false
	Popup.ZIndex = 20000
	Popup.Parent = self.Root
	self.MockDataPopup = Popup

	local Title = Widgets.Label(Popup, 'Mock Data', 11, true)
	Title.Position = UDim2.fromOffset(6, 3)
	Title.Size = UDim2.new(1, -12, 0, 18)
	Title.ZIndex = Popup.ZIndex + 1

	self.MockDataSearch = Widgets.TextBox(Popup, '')
	self.MockDataSearch.PlaceholderText = 'Search data paths'
	self.MockDataSearch.Position = UDim2.fromOffset(5, 24)
	self.MockDataSearch.Size = UDim2.new(1, -10, 0, 21)
	self.MockDataSearch.ZIndex = Popup.ZIndex + 1

	local Scroll, Layout = Widgets.Scroll(Popup)
	Scroll.Position = UDim2.fromOffset(5, 49)
	Scroll.Size = UDim2.new(1, -10, 0, 190)
	Scroll.ZIndex = Popup.ZIndex + 1
	self.MockDataList = Scroll
	self.MockDataLayout = Layout

	self.MockDataPathBox = Widgets.TextBox(Popup, '')
	self.MockDataPathBox.PlaceholderText = 'Path, e.g. Player.DisplayName'
	self.MockDataPathBox.Position = UDim2.fromOffset(5, 244)
	self.MockDataPathBox.Size = UDim2.new(1, -10, 0, 21)
	self.MockDataPathBox.ZIndex = Popup.ZIndex + 1

	self.MockDataValueBox = Widgets.TextBox(Popup, '')
	self.MockDataValueBox.PlaceholderText = 'Value'
	self.MockDataValueBox.Position = UDim2.fromOffset(5, 269)
	self.MockDataValueBox.Size = UDim2.new(1, -10, 0, 21)
	self.MockDataValueBox.ZIndex = Popup.ZIndex + 1

	self.MockDataTypeButton = Widgets.DropdownButton(Popup, 'Type: String')
	self.MockDataTypeButton.Position = UDim2.fromOffset(5, 294)
	self.MockDataTypeButton.Size = UDim2.fromOffset(92, 21)
	self.MockDataTypeButton.ZIndex = Popup.ZIndex + 1

	self.MockDataSetButton = Widgets.Button(Popup, 'Set')
	self.MockDataSetButton.Position = UDim2.fromOffset(100, 294)
	self.MockDataSetButton.Size = UDim2.fromOffset(52, 21)
	self.MockDataSetButton.ZIndex = Popup.ZIndex + 1

	self.MockDataDeleteButton = Widgets.Button(Popup, 'Delete')
	self.MockDataDeleteButton.Position = UDim2.fromOffset(155, 294)
	self.MockDataDeleteButton.Size = UDim2.fromOffset(58, 21)
	self.MockDataDeleteButton.ZIndex = Popup.ZIndex + 1

	self.MockDataPreviewButton = Widgets.Button(Popup, 'Preview All')
	self.MockDataPreviewButton.Position = UDim2.fromOffset(216, 294)
	self.MockDataPreviewButton.Size = UDim2.fromOffset(74, 21)
	self.MockDataPreviewButton.ZIndex = Popup.ZIndex + 1

	self.MockDataResetButton = Widgets.Button(Popup, 'Reset')
	self.MockDataResetButton.Position = UDim2.fromOffset(293, 294)
	self.MockDataResetButton.Size = UDim2.fromOffset(32, 21)
	self.MockDataResetButton.ZIndex = Popup.ZIndex + 1

	self.MockDataInfoLabel = Widgets.Label(Popup, 'Edit preview-only data. Bindings resolve against these paths.', 9, false)
	self.MockDataInfoLabel.TextColor3 = Theme.Color.TextMuted
	self.MockDataInfoLabel.Position = UDim2.fromOffset(6, 323)
	self.MockDataInfoLabel.Size = UDim2.new(1, -12, 0, 58)
	self.MockDataInfoLabel.TextWrapped = true
	self.MockDataInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.MockDataInfoLabel.ZIndex = Popup.ZIndex + 1
end

function App:_BuildScreensPopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'ScreensPopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(320, 360)
	Popup.Visible = false
	Popup.ZIndex = 20000
	Popup.Parent = self.Root
	self.ScreensPopup = Popup

	local Title = Widgets.Label(Popup, 'Screens', 11, true)
	Title.Position = UDim2.fromOffset(6, 3)
	Title.Size = UDim2.new(1, -12, 0, 18)
	Title.ZIndex = Popup.ZIndex + 1

	self.ScreenSearch = Widgets.TextBox(Popup, '')
	self.ScreenSearch.PlaceholderText = 'Search screens'
	self.ScreenSearch.Position = UDim2.fromOffset(5, 24)
	self.ScreenSearch.Size = UDim2.new(1, -10, 0, 21)
	self.ScreenSearch.ZIndex = Popup.ZIndex + 1

	local Scroll, Layout = Widgets.Scroll(Popup)
	Scroll.Position = UDim2.fromOffset(5, 49)
	Scroll.Size = UDim2.new(1, -10, 0, 170)
	Scroll.ZIndex = Popup.ZIndex + 1
	self.ScreenList = Scroll
	self.ScreenLayout = Layout

	self.ScreenNameBox = Widgets.TextBox(Popup, '')
	self.ScreenNameBox.PlaceholderText = 'Screen name'
	self.ScreenNameBox.Position = UDim2.fromOffset(5, 224)
	self.ScreenNameBox.Size = UDim2.new(1, -10, 0, 21)
	self.ScreenNameBox.ZIndex = Popup.ZIndex + 1

	self.ScreenNewButton = Widgets.Button(Popup, 'New')
	self.ScreenNewButton.Position = UDim2.fromOffset(5, 249)
	self.ScreenNewButton.Size = UDim2.fromOffset(48, 21)
	self.ScreenNewButton.ZIndex = Popup.ZIndex + 1

	self.ScreenOpenButton = Widgets.Button(Popup, 'Open')
	self.ScreenOpenButton.Position = UDim2.fromOffset(56, 249)
	self.ScreenOpenButton.Size = UDim2.fromOffset(48, 21)
	self.ScreenOpenButton.ZIndex = Popup.ZIndex + 1

	self.ScreenRenameButton = Widgets.Button(Popup, 'Rename')
	self.ScreenRenameButton.Position = UDim2.fromOffset(107, 249)
	self.ScreenRenameButton.Size = UDim2.fromOffset(58, 21)
	self.ScreenRenameButton.ZIndex = Popup.ZIndex + 1

	self.ScreenDuplicateButton = Widgets.Button(Popup, 'Duplicate')
	self.ScreenDuplicateButton.Position = UDim2.fromOffset(168, 249)
	self.ScreenDuplicateButton.Size = UDim2.fromOffset(66, 21)
	self.ScreenDuplicateButton.ZIndex = Popup.ZIndex + 1

	self.ScreenDeleteButton = Widgets.Button(Popup, 'Delete')
	self.ScreenDeleteButton.Position = UDim2.fromOffset(237, 249)
	self.ScreenDeleteButton.Size = UDim2.fromOffset(48, 21)
	self.ScreenDeleteButton.ZIndex = Popup.ZIndex + 1

	self.ScreenStartButton = Widgets.Button(Popup, 'Set Start')
	self.ScreenStartButton.Position = UDim2.fromOffset(5, 274)
	self.ScreenStartButton.Size = UDim2.fromOffset(72, 21)
	self.ScreenStartButton.ZIndex = Popup.ZIndex + 1

	self.ScreenInfoLabel = Widgets.Label(Popup, 'No screen selected', 9, false)
	self.ScreenInfoLabel.TextColor3 = Theme.Color.TextMuted
	self.ScreenInfoLabel.Position = UDim2.fromOffset(6, 302)
	self.ScreenInfoLabel.Size = UDim2.new(1, -12, 0, 48)
	self.ScreenInfoLabel.TextWrapped = true
	self.ScreenInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.ScreenInfoLabel.ZIndex = Popup.ZIndex + 1
end

function App:_BuildFlowPopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'FlowPopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(330, 330)
	Popup.Visible = false
	Popup.ZIndex = 20000
	Popup.Parent = self.Root
	self.FlowPopup = Popup

	local Title = Widgets.Label(Popup, 'Flow / Action', 11, true)
	Title.Position = UDim2.fromOffset(6, 3)
	Title.Size = UDim2.new(1, -12, 0, 18)
	Title.ZIndex = Popup.ZIndex + 1

	self.FlowObjectLabel = Widgets.Label(Popup, 'Object: (select a button)', 10, false)
	self.FlowObjectLabel.Position = UDim2.fromOffset(6, 25)
	self.FlowObjectLabel.Size = UDim2.new(1, -12, 0, 18)
	self.FlowObjectLabel.ZIndex = Popup.ZIndex + 1

	self.FlowActionButton = Widgets.DropdownButton(Popup, 'Action: None')
	self.FlowActionButton.Position = UDim2.fromOffset(5, 49)
	self.FlowActionButton.Size = UDim2.new(1, -10, 0, 23)
	self.FlowActionButton.ZIndex = Popup.ZIndex + 1

	local TargetLabel = Widgets.Label(Popup, 'Target', 10, false)
	TargetLabel.Position = UDim2.fromOffset(6, 78)
	TargetLabel.Size = UDim2.fromOffset(55, 18)
	TargetLabel.ZIndex = Popup.ZIndex + 1

	self.FlowTargetBox = Widgets.TextBox(Popup, '')
	self.FlowTargetBox.PlaceholderText = 'Screen name or Root/Child path'
	self.FlowTargetBox.Position = UDim2.fromOffset(5, 98)
	self.FlowTargetBox.Size = UDim2.new(1, -10, 0, 21)
	self.FlowTargetBox.ZIndex = Popup.ZIndex + 1

	self.FlowUseScreenButton = Widgets.Button(Popup, 'Use Selected Screen')
	self.FlowUseScreenButton.Position = UDim2.fromOffset(5, 123)
	self.FlowUseScreenButton.Size = UDim2.fromOffset(120, 21)
	self.FlowUseScreenButton.ZIndex = Popup.ZIndex + 1

	self.FlowUseObjectButton = Widgets.Button(Popup, 'Use Selected Object')
	self.FlowUseObjectButton.Position = UDim2.fromOffset(128, 123)
	self.FlowUseObjectButton.Size = UDim2.fromOffset(112, 21)
	self.FlowUseObjectButton.ZIndex = Popup.ZIndex + 1

	self.FlowCaptureSourceButton = Widgets.Button(Popup, 'Set Source')
	self.FlowCaptureSourceButton.Position = UDim2.fromOffset(243, 123)
	self.FlowCaptureSourceButton.Size = UDim2.new(1, -248, 0, 21)
	self.FlowCaptureSourceButton.ZIndex = Popup.ZIndex + 1

	self.FlowTransitionButton = Widgets.DropdownButton(Popup, 'Transition: None')
	self.FlowTransitionButton.Position = UDim2.fromOffset(5, 151)
	self.FlowTransitionButton.Size = UDim2.fromOffset(148, 21)
	self.FlowTransitionButton.ZIndex = Popup.ZIndex + 1

	self.FlowDurationBox = Widgets.TextBox(Popup, '.2')
	self.FlowDurationBox.PlaceholderText = 'Duration'
	self.FlowDurationBox.Position = UDim2.fromOffset(156, 151)
	self.FlowDurationBox.Size = UDim2.new(1, -161, 0, 21)
	self.FlowDurationBox.ZIndex = Popup.ZIndex + 1

	self.FlowSetButton = Widgets.Button(Popup, 'Set Action')
	self.FlowSetButton.Position = UDim2.fromOffset(5, 180)
	self.FlowSetButton.Size = UDim2.fromOffset(78, 23)
	self.FlowSetButton.ZIndex = Popup.ZIndex + 1

	self.FlowClearButton = Widgets.Button(Popup, 'Clear')
	self.FlowClearButton.Position = UDim2.fromOffset(86, 180)
	self.FlowClearButton.Size = UDim2.fromOffset(54, 23)
	self.FlowClearButton.ZIndex = Popup.ZIndex + 1

	self.FlowTestButton = Widgets.Button(Popup, 'Test')
	self.FlowTestButton.Position = UDim2.fromOffset(143, 180)
	self.FlowTestButton.Size = UDim2.fromOffset(54, 23)
	self.FlowTestButton.ZIndex = Popup.ZIndex + 1

	self.FlowInfoLabel = Widgets.Label(Popup, 'Actions execute in Interactive Preview.', 9, false)
	self.FlowInfoLabel.TextColor3 = Theme.Color.TextMuted
	self.FlowInfoLabel.Position = UDim2.fromOffset(6, 212)
	self.FlowInfoLabel.Size = UDim2.new(1, -12, 0, 106)
	self.FlowInfoLabel.TextWrapped = true
	self.FlowInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.FlowInfoLabel.ZIndex = Popup.ZIndex + 1
end

function App:_BuildProblemsPopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'ProblemsPopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(470, 380)
	Popup.Visible = false
	Popup.ZIndex = 20000
	Popup.Parent = self.Root
	self.ProblemsPopup = Popup

	local Title = Widgets.Label(Popup, 'Problems / Validation', 11, true)
	Title.Position = UDim2.fromOffset(6, 3)
	Title.Size = UDim2.new(1, -12, 0, 18)
	Title.ZIndex = Popup.ZIndex + 1

	self.ProblemsValidateButton = Widgets.Button(Popup, 'Validate Runtime Package')
	self.ProblemsValidateButton.Position = UDim2.fromOffset(5, 25)
	self.ProblemsValidateButton.Size = UDim2.fromOffset(146, 23)
	self.ProblemsValidateButton.ZIndex = Popup.ZIndex + 1

	self.ProblemsSummaryLabel = Widgets.Label(Popup, 'Not validated', 10, false)
	self.ProblemsSummaryLabel.Position = UDim2.fromOffset(159, 26)
	self.ProblemsSummaryLabel.Size = UDim2.new(1, -164, 0, 21)
	self.ProblemsSummaryLabel.ZIndex = Popup.ZIndex + 1

	local Scroll, Layout = Widgets.Scroll(Popup)
	Scroll.Position = UDim2.fromOffset(5, 53)
	Scroll.Size = UDim2.new(1, -10, 1, -58)
	Scroll.ZIndex = Popup.ZIndex + 1
	self.ProblemsList = Scroll
	self.ProblemsLayout = Layout
end

function App:_BuildPackagePopup()
	local Popup = Instance.new('Frame')
	Popup.Name = 'PackagePopup'
	Widgets.Surface(Popup, 'Panel')
	Popup.Size = UDim2.fromOffset(540, 440)
	Popup.Visible = false
	Popup.ZIndex = 20000
	Popup.Parent = self.Root
	self.PackagePopup = Popup

	local Title = Widgets.Label(Popup, 'Runtime Package', 11, true)
	Title.Position = UDim2.fromOffset(6, 3)
	Title.Size = UDim2.new(1, -12, 0, 18)
	Title.ZIndex = Popup.ZIndex + 1

	self.PackageNameBox = Widgets.TextBox(Popup, 'RUCKUSUIProject')
	self.PackageNameBox.PlaceholderText = 'Named export'
	self.PackageNameBox.Position = UDim2.fromOffset(5, 25)
	self.PackageNameBox.Size = UDim2.fromOffset(110, 23)
	self.PackageNameBox.ZIndex = Popup.ZIndex + 1

	self.PackageSyncButton = Widgets.Button(Popup, 'Sync Now')
	self.PackageSyncButton.Position = UDim2.fromOffset(118, 25)
	self.PackageSyncButton.Size = UDim2.fromOffset(60, 23)
	self.PackageSyncButton.ZIndex = Popup.ZIndex + 1

	self.PackageValidateButton = Widgets.Button(Popup, 'Validate')
	self.PackageValidateButton.Position = UDim2.fromOffset(181, 25)
	self.PackageValidateButton.Size = UDim2.fromOffset(60, 23)
	self.PackageValidateButton.ZIndex = Popup.ZIndex + 1

	self.PackageExportButton = Widgets.Button(Popup, 'Export')
	self.PackageExportButton.Position = UDim2.fromOffset(244, 25)
	self.PackageExportButton.Size = UDim2.fromOffset(72, 23)
	self.PackageExportButton.ZIndex = Popup.ZIndex + 1

	self.PackageImportButton = Widgets.Button(Popup, 'Import')
	self.PackageImportButton.Position = UDim2.fromOffset(319, 25)
	self.PackageImportButton.Size = UDim2.fromOffset(82, 23)
	self.PackageImportButton.ZIndex = Popup.ZIndex + 1

	self.PackageRuntimeButton = Widgets.Button(Popup, 'UI Preview')
	self.PackageRuntimeButton.Position = UDim2.fromOffset(404, 25)
	self.PackageRuntimeButton.Size = UDim2.fromOffset(62, 23)
	self.PackageRuntimeButton.ZIndex = Popup.ZIndex + 1

	self.PackageFrameworkButton = Widgets.Button(Popup, 'Framework')
	self.PackageFrameworkButton.Position = UDim2.fromOffset(469, 25)
	self.PackageFrameworkButton.Size = UDim2.new(1, -474, 0, 23)
	self.PackageFrameworkButton.ZIndex = Popup.ZIndex + 1

	self.PackageSaveButton = Widgets.Button(Popup, 'Save')
	self.PackageSaveButton.Position = UDim2.fromOffset(5, 53)
	self.PackageSaveButton.Size = UDim2.fromOffset(58, 23)
	self.PackageSaveButton.ZIndex = Popup.ZIndex + 1

	self.PackageRecoverButton = Widgets.Button(Popup, 'Recover')
	self.PackageRecoverButton.Position = UDim2.fromOffset(66, 53)
	self.PackageRecoverButton.Size = UDim2.fromOffset(68, 23)
	self.PackageRecoverButton.ZIndex = Popup.ZIndex + 1

	self.PackageSaveStatusLabel = Widgets.Label(Popup, 'Project: Unsaved', 9, false)
	self.PackageSaveStatusLabel.TextColor3 = Theme.Color.TextMuted
	self.PackageSaveStatusLabel.Position = UDim2.fromOffset(140, 55)
	self.PackageSaveStatusLabel.Size = UDim2.new(1, -145, 0, 19)
	self.PackageSaveStatusLabel.ZIndex = Popup.ZIndex + 1

	self.PackageInfoLabel = Widgets.Label(Popup, 'Runtime auto-sync keeps the last valid project ready for Play. Named export is optional.', 9, false)
	self.PackageInfoLabel.TextColor3 = Theme.Color.TextMuted
	self.PackageInfoLabel.Position = UDim2.fromOffset(6, 82)
	self.PackageInfoLabel.Size = UDim2.new(1, -12, 0, 34)
	self.PackageInfoLabel.TextWrapped = true
	self.PackageInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.PackageInfoLabel.ZIndex = Popup.ZIndex + 1

	self.PackageSourceBox = Widgets.TextBox(Popup, '')
	self.PackageSourceBox.ClearTextOnFocus = false
	self.PackageSourceBox.MultiLine = true
	self.PackageSourceBox.TextEditable = false
	self.PackageSourceBox.TextXAlignment = Enum.TextXAlignment.Left
	self.PackageSourceBox.TextYAlignment = Enum.TextYAlignment.Top
	self.PackageSourceBox.TextSize = 10
	self.PackageSourceBox.Position = UDim2.fromOffset(5, 120)
	self.PackageSourceBox.Size = UDim2.new(1, -10, 1, -125)
	self.PackageSourceBox.ZIndex = Popup.ZIndex + 1
end

function App:_GetDevice()
	local Definition = Theme.Devices[self.DeviceIndex] or Theme.Devices[1]
	if Definition.Dynamic == 'StudioViewport' then
		local Camera = workspace.CurrentCamera
		local Size = Camera and Camera.ViewportSize or Vector2.new(Definition.Width, Definition.Height)
		return {
			Name = Definition.Name,
			Width = math.max(1, math.floor(Size.X + .5)),
			Height = math.max(1, math.floor(Size.Y + .5)),
			Dynamic = Definition.Dynamic
		}
	end
	return Definition
end

function App:_GetDeviceSize()
	local Device = self:_GetDevice()
	return Vector2.new(Device.Width, Device.Height)
end

function App:_ApplyStrokeLOD()
	if not self.AuthoringLayer then return end

	local Threshold = tonumber(Theme.StrokeLODThreshold) or .5
	local Boost = math.max(tonumber(Theme.StrokeLODBoost) or 1, 0)
	local ResponsiveScale = self:_GetResponsiveScale()
	local PreviewScale = math.max(tonumber(self.PreviewScale) or 1, .001)
	local EffectiveScale = ResponsiveScale * PreviewScale
	local Active = EffectiveScale < Threshold

	for _, Descendant in ipairs(self.AuthoringLayer:GetDescendants()) do
		if Descendant:IsA('UIStroke') then
			local State = self.StrokeLODState[Descendant]
			if not State then
				State = {
					Base = Descendant.Thickness,
					Applied = Descendant.Thickness
				}
				self.StrokeLODState[Descendant] = State
			elseif math.abs(Descendant.Thickness - State.Applied) > .0001 then
				State.Base = Descendant.Thickness
			end

			local Target = State.Base + (Active and Boost or 0)
			if math.abs(Descendant.Thickness - Target) > .0001 then
				Descendant.Thickness = Target
			end
			State.Applied = Target
		end
	end
end

function App:_FitDevice()
	if not self.PreviewBody then return end
	local Available = self.PreviewBody.AbsoluteSize
	if Available.X <= 0 or Available.Y <= 0 then return end

	local Device = self:_GetDevice()
	local AvailableX = math.max(Available.X - 32, 32)
	local AvailableY = math.max(Available.Y - 32, 18)
	local FitScale = math.min(AvailableX / Device.Width, AvailableY / Device.Height)
	local PreviewScale = math.max(.01, FitScale * self.Zoom)
	local Reference = Theme.ReferenceSize or Vector2.new(1920, 1080)
	local ResponsiveScale = math.max(math.min(
		Device.Width / math.max(Reference.X, 1),
		Device.Height / math.max(Reference.Y, 1)
	), .001)
	local LogicalSize = Vector2.new(
		Device.Width / ResponsiveScale,
		Device.Height / ResponsiveScale
	)

	self.DeviceFitScale = PreviewScale
	self.PreviewScale = PreviewScale
	self.ResponsiveScale = ResponsiveScale
	self.ResponsiveLogicalSize = LogicalSize
	self.Device.Size = UDim2.fromOffset(Device.Width, Device.Height)
	self.DeviceScale.Scale = PreviewScale
	self.AuthoringLayer.Size = UDim2.fromOffset(LogicalSize.X, LogicalSize.Y)
	self.AuthoringLayer.Position = UDim2.fromOffset(0, 0)
	if self.ResponsiveScaleObject then self.ResponsiveScaleObject.Scale = ResponsiveScale end
	self:_ApplyStrokeLOD()
	self.DeviceHost.Size = UDim2.fromOffset(
		Round(Device.Width * PreviewScale),
		Round(Device.Height * PreviewScale)
	)
	self.DeviceHost.Position = UDim2.new(.5, self.Pan.X, .5, self.Pan.Y)
	if self.DeviceStroke then self.DeviceStroke.Thickness = 2 / math.max(PreviewScale, .01) end

	self:_UpdateZoneGuides()
	self:_UpdateCameraBoundsGuide()
	self:_UpdateSelectionBox()
	self:_UpdateSnapGuides()
	self:_UpdatePreviewToolbar()
	self:_UpdateStatus()
end

function App:_UpdateZoneGuides()
	if not self.ZoneLines then return end
	local Thickness = 2 / math.max(self.DeviceFitScale or self.PreviewScale, .01)

	for _, Entry in ipairs(self.ZoneLines) do
		local Line = Entry.Object
		if Line and Line.Parent then
			if Entry.Axis == 'X' then
				Line.Position = UDim2.new(Entry.Scale, -Thickness / 2, 0, 0)
				Line.Size = UDim2.new(0, Thickness, 1, 0)
			else
				Line.Position = UDim2.new(0, 0, Entry.Scale, -Thickness / 2)
				Line.Size = UDim2.new(1, 0, 0, Thickness)
			end
		end
	end
end

function App:_UpdateCameraBoundsGuide()
	if not self.CameraBoundsGuide or not self.CameraBoundsLines then return end

	local Bounds = self.CameraBounds
	local Visible = Bounds ~= nil and self.CameraBoundsVisible ~= false and not self.InteractiveMode
	self.CameraBoundsGuide.Visible = Visible
	if self.CameraBoundsButton then Widgets.SetActive(self.CameraBoundsButton, Visible) end
	if not Visible then return end

	local Left = math.clamp(tonumber(Bounds.Left) or 0, 0, 1)
	local Top = math.clamp(tonumber(Bounds.Top) or 0, 0, 1)
	local Right = math.clamp(tonumber(Bounds.Right) or 1, Left, 1)
	local Bottom = math.clamp(tonumber(Bounds.Bottom) or 1, Top, 1)
	local Thickness = 2 / math.max(self.PreviewScale, .01)
	local Width = math.max(0, Right - Left)
	local Height = math.max(0, Bottom - Top)

	self.CameraBoundsLines.Top.Position = UDim2.new(Left, 0, Top, -Thickness / 2)
	self.CameraBoundsLines.Top.Size = UDim2.new(Width, 0, 0, Thickness)

	self.CameraBoundsLines.Right.Position = UDim2.new(Right, -Thickness / 2, Top, 0)
	self.CameraBoundsLines.Right.Size = UDim2.new(0, Thickness, Height, 0)

	self.CameraBoundsLines.Bottom.Position = UDim2.new(Left, 0, Bottom, -Thickness / 2)
	self.CameraBoundsLines.Bottom.Size = UDim2.new(Width, 0, 0, Thickness)

	self.CameraBoundsLines.Left.Position = UDim2.new(Left, -Thickness / 2, Top, 0)
	self.CameraBoundsLines.Left.Size = UDim2.new(0, Thickness, Height, 0)
end

function App:_CaptureCameraBoundsFromStudioSelection()
	local Targets = StudioSelection:Get()
	if #Targets ~= 4 then
		self:SetStatus('Ctrl-select exactly 4 camera-blocking frames in Studio Explorer')
		return false
	end

	local ScreenGui
	for Index, Target in ipairs(Targets) do
		if not Target:IsA('GuiObject') then
			self:SetStatus('Camera bounds require 4 GuiObjects selected in Studio Explorer')
			return false
		end

		local TargetScreen = Target:FindFirstAncestorWhichIsA('ScreenGui')
		if Index == 1 then
			ScreenGui = TargetScreen
		elseif TargetScreen ~= ScreenGui then
			self:SetStatus('The 4 camera-blocking frames must belong to the same ScreenGui')
			return false
		end
	end

	local CanvasPosition, CanvasSize
	if ScreenGui then
		local Camera = workspace.CurrentCamera
		if not Camera or Camera.ViewportSize.X <= 0 or Camera.ViewportSize.Y <= 0 then
			self:SetStatus('Studio viewport is unavailable for camera bounds')
			return false
		end

		CanvasPosition = Vector2.new()
		CanvasSize = Camera.ViewportSize
		if not ScreenGui.IgnoreGuiInset then
			local Success, TopLeft, BottomRight = pcall(function()
				return GuiService:GetGuiInset()
			end)
			if Success then
				CanvasPosition = TopLeft
				CanvasSize = Vector2.new(
					math.max(1, CanvasSize.X - TopLeft.X - BottomRight.X),
					math.max(1, CanvasSize.Y - TopLeft.Y - BottomRight.Y)
				)
			end
		end
	else
		local Common = Targets[1].Parent
		while Common and not Common:IsA('GuiObject') do Common = Common.Parent end
		while Common do
			local Shared = true
			for Index = 2, #Targets do
				if not Targets[Index]:IsDescendantOf(Common) then
					Shared = false
					break
				end
			end
			if Shared then break end
			Common = Common.Parent
			while Common and not Common:IsA('GuiObject') do Common = Common.Parent end
		end

		if not Common or Common.AbsoluteSize.X <= 0 or Common.AbsoluteSize.Y <= 0 then
			self:SetStatus('The selected frames need a shared ScreenGui or GuiObject canvas')
			return false
		end

		CanvasPosition = Common.AbsolutePosition
		CanvasSize = Common.AbsoluteSize
	end

	local Rects = {}
	for _, Target in ipairs(Targets) do
		local Position = Target.AbsolutePosition - CanvasPosition
		local Size = Target.AbsoluteSize
		table.insert(Rects, {
			Left = Position.X,
			Top = Position.Y,
			Width = Size.X,
			Height = Size.Y,
			CenterX = Position.X + Size.X / 2,
			CenterY = Position.Y + Size.Y / 2
		})
	end

	local Best, BestScore
	for LeftIndex = 1, 4 do
		for RightIndex = 1, 4 do
			if RightIndex ~= LeftIndex then
				for TopIndex = 1, 4 do
					if TopIndex ~= LeftIndex and TopIndex ~= RightIndex then
						for BottomIndex = 1, 4 do
							if BottomIndex ~= LeftIndex and BottomIndex ~= RightIndex and BottomIndex ~= TopIndex then
								local Score =
									Rects[LeftIndex].CenterX
									+ (CanvasSize.X - Rects[RightIndex].CenterX)
									+ Rects[TopIndex].CenterY
									+ (CanvasSize.Y - Rects[BottomIndex].CenterY)

								if not BestScore or Score < BestScore then
									BestScore = Score
									Best = {
										Left = LeftIndex,
										Right = RightIndex,
										Top = TopIndex,
										Bottom = BottomIndex
									}
								end
							end
						end
					end
				end
			end
		end
	end

	if not Best then return false end

	local LeftRect = Rects[Best.Left]
	local RightRect = Rects[Best.Right]
	local TopRect = Rects[Best.Top]
	local BottomRect = Rects[Best.Bottom]
	local Left = math.clamp(LeftRect.Left + LeftRect.Width, 0, CanvasSize.X)
	local Right = math.clamp(RightRect.Left, 0, CanvasSize.X)
	local Top = math.clamp(TopRect.Top + TopRect.Height, 0, CanvasSize.Y)
	local Bottom = math.clamp(BottomRect.Top, 0, CanvasSize.Y)

	if Right - Left < 2 or Bottom - Top < 2 then
		self:SetStatus('Could not resolve an inner rectangle from those 4 Studio frames')
		return false
	end

	self.CameraBounds = {
		Left = Left / CanvasSize.X,
		Top = Top / CanvasSize.Y,
		Right = Right / CanvasSize.X,
		Bottom = Bottom / CanvasSize.Y
	}
	self.CameraBoundsVisible = true
	self:_UpdateCameraBoundsGuide()
	self:_RecordHistory('Camera Bounds')
	self:SetStatus('Camera bounds captured from Studio Explorer selection')
	return true
end

function App:_SetZoom(Value)
	self.Zoom = math.clamp(Value, Theme.Metric.ZoomMin, Theme.Metric.ZoomMax)
	self:_FitDevice()
end

function App:_UpdatePreviewToolbar()
	if not self.DeviceButton then return end
	local Device = self:_GetDevice()
	self.DeviceButton.Text = Device.Name
	self.ZoomLabel.Text = tostring(Round(self.Zoom * 100)) .. '%'
	if self.CanvasContextLabel then
		local Screen = self.DocumentScreen or self.Screens and self.Screens:GetCurrent() or 'Main'
		self.CanvasContextLabel.Text = (self.InteractiveMode and 'LIVE UI  |  ' or 'CANVAS  |  ')
			.. string.upper(tostring(Screen or 'Main'))
	end
end

function App:_Bind()
	self:_BindShortcutTree()

	self:_Connect(self.Widget.WindowFocused, function()
		self.WidgetFocused = true
	end)

	self:_Connect(self.Widget.WindowFocusReleased, function()
		self.WidgetFocused = false
		self.TextEntryFocus = nil
		table.clear(self.ShortcutKeysDown)
		self.ShiftHeld = false
		self.ControlHeld = false
		self:_RefreshSnapState()
	end)

	self:_Connect(self.PreviewBody:GetPropertyChangedSignal('AbsoluteSize'), function()
		self:_FitDevice()
	end)

	self:_Connect(self.PreviewBody.InputBegan, function(Input)
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		local Point = Vector2.new(Input.Position.X, Input.Position.Y)
		local Position, Size = self.Device.AbsolutePosition, self.Device.AbsoluteSize
		local Inside = Point.X >= Position.X and Point.X <= Position.X + Size.X
			and Point.Y >= Position.Y and Point.Y <= Position.Y + Size.Y
		if not Inside then self.Selection:Clear() end
	end)

	self:_Connect(self.Selection.Changed.Event, function()
		if self.Restoring or self.RefreshSuspended then return end

		local Target = self.Selection:GetTarget()
		local Component = self:_GetComponentName(Target)
		if Component and self.Components and self.Components:Has(Component) then
			self.SelectedComponent = Component
			self.SelectedVariant = Target:GetAttribute('FORGEComponentVariant') or 'Default'
		end

		if self.AnimationTargetLabel and not self.SelectedTrack then
			local _, Path = self:_GetAnimationTarget()
			self.AnimationTargetPath = Path or 'Root'
			self.AnimationTargetLabel.Text = 'Target: ' .. (Path or '(select object)')
		end

		self:_RefreshAll()
	end)

	self:_Connect(self.Document.Changed.Event, function()
		if self.Restoring or self.RefreshSuspended then return end
		self:_RefreshAll()
		self:_QueuePersistentSave('Document Edit')
	end)

	self:_Connect(self.History.Changed.Event, function()
		self:_UpdateHistoryButtons()
	end)

	self:_Connect(self.ExplorerSearch:GetPropertyChangedSignal('Text'), function()
		self:_RefreshRoots()
	end)

	self:_Connect(self.ChildrenSearch:GetPropertyChangedSignal('Text'), function()
		self:_RefreshChildren()
	end)

	self:_Connect(self.PropertiesSearch:GetPropertyChangedSignal('Text'), function()
		self:_RefreshProperties()
	end)

	self:_Connect(self.UndoButton.MouseButton1Click, function() self:_Undo() end)
	self:_Connect(self.RedoButton.MouseButton1Click, function() self:_Redo() end)
	self:_Connect(self.CopyButton.MouseButton1Click, function() self:_Copy() end)
	self:_Connect(self.CutButton.MouseButton1Click, function() self:_Cut() end)
	self:_Connect(self.PasteButton.MouseButton1Click, function() self:_Paste() end)
	self:_Connect(self.DuplicateButton.MouseButton1Click, function() self:_Duplicate() end)
	self:_Connect(self.AddFrameButton.MouseButton1Click, function() self:_CreateRoot('Frame') end)
	self:_Connect(self.AddTextButton.MouseButton1Click, function() self:_CreateRoot('TextLabel') end)
	self:_Connect(self.AddChildButton.MouseButton1Click, function() self:_CreateChild() end)
	self:_Connect(self.DeleteButton.MouseButton1Click, function() self:_DeleteSelected() end)

	self:_Connect(self.ZoneGuideButton.MouseButton1Click, function()
		self.ZoneGuidesVisible = not self.ZoneGuidesVisible
		self.ZoneGuides.Visible = self.ZoneGuidesVisible
		Widgets.SetActive(self.ZoneGuideButton, self.ZoneGuidesVisible)
	end)

	self:_Connect(self.CameraBoundsButton.MouseButton1Click, function()
		local StudioTargets = StudioSelection:Get()
		if #StudioTargets > 0 then
			self:_CaptureCameraBoundsFromStudioSelection()
			return
		end

		if not self.CameraBounds then
			self:SetStatus('Ctrl-select the 4 camera-blocking frames in Studio Explorer, then click Bounds')
			return
		end

		self.CameraBoundsVisible = not self.CameraBoundsVisible
		self:_UpdateCameraBoundsGuide()
		Widgets.SetActive(self.CameraBoundsButton, self.CameraBoundsVisible)
		self:_RecordHistory('Camera Bounds Visibility')
	end)

	self:_Connect(self.CameraBoundsButton.MouseButton2Click, function()
		if not self.CameraBounds then return end
		self.CameraBounds = nil
		self.CameraBoundsVisible = true
		self:_UpdateCameraBoundsGuide()
		Widgets.SetActive(self.CameraBoundsButton, false)
		self:_RecordHistory('Camera Bounds Clear')
		self:SetStatus('Camera bounds cleared')
	end)

	self:_Connect(self.SnapButton.MouseButton1Click, function()
		self.SnapEnabled = not self.SnapEnabled
		Widgets.SetActive(self.SnapButton, self.SnapEnabled)
		self:_RefreshSnapState()
	end)

	self:_Connect(self.SnapStepBox.FocusLost, function()
		local Text = string.lower((self.SnapStepBox.Text or ''):gsub('%s+', ''))
		local Value = (Text == '' or Text == 'off' or Text == 'none') and 0 or tonumber(Text)
		if Value == nil then
			self.SnapStepBox.Text = self.SnapIncrement > 0 and tostring(self.SnapIncrement) or 'Off'
			return
		end
		self.SnapIncrement = math.max(0, math.floor(Value + .5))
		self.SnapStepBox.Text = self.SnapIncrement > 0 and tostring(self.SnapIncrement) or 'Off'
		self:SetStatus(self.SnapIncrement > 0 and ('Grid snap: ' .. self.SnapIncrement .. 'px') or 'Grid snap off')
	end)

	self:_Connect(self.InsertButton.MouseButton1Click, function()
		self.InsertContextPoint = nil
		self.InsertTargetOverride = nil
		self:_RefreshInsertPalette()
		self:_TogglePopup(self.InsertButton, self.InsertPopup)
	end)

	local function DismissInsert()
		self:_CloseInsertPopup()
		Widgets.SetActive(self.InsertButton, false)
	end

	self:_Connect(self.PopupDismissLayer.MouseButton1Click, DismissInsert)
	self:_Connect(self.PopupDismissLayer.InputBegan, function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton2 then DismissInsert() end
	end)

	self:_Connect(self.DragCapture.MouseMoved, function(X, Y)
		local Mouse = Vector2.new(X, Y)
		if self.HierarchyDrag then self:_UpdateHierarchyDrag(Mouse) end
		if self.RootDrag then self:_UpdateRootDrag(Mouse) end
	end)

	local function FinishHierarchyCapture()
		if self.RootDrag then self:_EndRootDrag() end
		if self.HierarchyDrag then self:_EndHierarchyDrag() end
		self.DragCapture.Visible = false
	end

	self:_Connect(self.DragCapture.MouseButton1Up, FinishHierarchyCapture)
	self:_Connect(self.DragCapture.InputEnded, function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then FinishHierarchyCapture() end
	end)

	self:_Connect(self.RootContextInsertButton.MouseButton1Click, function()
		local Target = self.RootContextTarget
		local Point = self.RootContextPoint
		if self.RootContextPopup then self.RootContextPopup.Visible = false end
		if Target and Target.Parent then
			self:_OpenInsertForTarget(
				Target,
				Point and Point.X or self.Root.AbsolutePosition.X + 8,
				Point and Point.Y or self.Root.AbsolutePosition.Y + 8
			)
		end
	end)

	self:_Connect(self.RootContextDuplicateButton.MouseButton1Click, function()
		if self.RootContextPopup then self.RootContextPopup.Visible = false end
		self:_Duplicate()
	end)

	self:_Connect(self.RootContextCopyButton.MouseButton1Click, function()
		if self.RootContextPopup then self.RootContextPopup.Visible = false end
		self:_Copy()
	end)

	self:_Connect(self.RootContextCutButton.MouseButton1Click, function()
		if self.RootContextPopup then self.RootContextPopup.Visible = false end
		self:_Cut()
	end)

	self:_Connect(self.RootContextVisibleButton.MouseButton1Click, function()
		local Target = self.RootContextTarget
		if Target and Target.Parent then
			Target.Visible = not Target.Visible
			self:_RecordHistory('Toggle Visibility')
			self:_RefreshAll()
		end
		if self.RootContextPopup then self.RootContextPopup.Visible = false end
	end)

	self:_Connect(self.RootContextLockButton.MouseButton1Click, function()
		local Target = self.RootContextTarget
		if Target and Target.Parent then
			self.Document:SetLocked(Target, not self.Document:IsLocked(Target))
			self:_RecordHistory('Toggle Lock')
			self:_RefreshAll()
		end
		if self.RootContextPopup then self.RootContextPopup.Visible = false end
	end)

	self:_Connect(self.RootContextDeleteButton.MouseButton1Click, function()
		if self.RootContextPopup then self.RootContextPopup.Visible = false end
		self:_DeleteSelected()
	end)

	self:_Connect(self.ComponentsButton.MouseButton1Click, function()
		self:_RefreshComponents()
		self:_TogglePopup(self.ComponentsButton, self.ComponentsPopup)
	end)

	self:_Connect(self.StyleButton.MouseButton1Click, function()
		self:_RefreshStyle()
		self:_TogglePopup(self.StyleButton, self.StylePopup)
	end)

	self:_Connect(self.ProblemsButton.MouseButton1Click, function()
		self:_RefreshProblems()
		self:_TogglePopup(self.ProblemsButton, self.ProblemsPopup)
	end)

	self:_Connect(self.PackageButton.MouseButton1Click, function()
		self:_RefreshPackage()
		self:_TogglePopup(self.PackageButton, self.PackagePopup)
	end)

	self:_Connect(self.StylePackButton.MouseButton1Click, function()
		if not self.StylePacks then return end
		self:_ShowChoicePopup(self.StylePackButton, self.StylePacks:GetNames(), self.ActiveStylePack, function(Name)
			self.ActiveStylePack = Name
			self.SelectedSurface = 'Regular'
			self.SelectedRarity = self.StylePacks:GetRarityNames(Name)[1] or self.SelectedRarity
			self:_InstallStylePresets()
			self:_RefreshStyle()
			self:_RefreshComponents()
			self:_RefreshInsertPalette()
			self:_RecordHistory('Set Style Pack')
		end)
	end)

	self:_Connect(self.StyleSurfaceButton.MouseButton1Click, function()
		if not self.StylePacks then return end
		self:_ShowChoicePopup(
			self.StyleSurfaceButton,
			self.StylePacks:GetSurfaceNames(self.ActiveStylePack),
			self.SelectedSurface,
			function(Name)
				self.SelectedSurface = Name
				self:_RefreshStyle()
			end
		)
	end)

	self:_Connect(self.StyleApplySurfaceButton.MouseButton1Click, function()
		self:_ApplyStyleSurface()
	end)

	self:_Connect(self.StyleTypographyButton.MouseButton1Click, function()
		if not self.StylePacks then return end
		local Pack = self.StylePacks:Get(self.ActiveStylePack)
		local Names = {}
		for Name in pairs(Pack.Typography or {}) do table.insert(Names, Name) end
		table.sort(Names)
		self:_ShowChoicePopup(self.StyleTypographyButton, Names, self.SelectedTypography, function(Name)
			self.SelectedTypography = Name
			self:_RefreshStyle()
		end)
	end)

	self:_Connect(self.StyleApplyTypographyButton.MouseButton1Click, function()
		self:_ApplyStyleTypography()
	end)

	self:_Connect(self.StyleRarityButton.MouseButton1Click, function()
		if not self.StylePacks then return end
		self:_ShowChoicePopup(
			self.StyleRarityButton,
			self.StylePacks:GetRarityNames(self.ActiveStylePack),
			self.SelectedRarity,
			function(Name)
				self.SelectedRarity = Name
				self:_RefreshStyle()
			end
		)
	end)

	self:_Connect(self.StyleApplyRarityButton.MouseButton1Click, function()
		self:_ApplyStyleRarity()
	end)

	for Name, Button in pairs(self.StyleSwatches or {}) do
		self:_Connect(Button.MouseButton1Click, function()
			if not self.StylePacks then return end
			local Pack = self.StylePacks:Get(self.ActiveStylePack)
			local Color = Pack.Color and Pack.Color[Name]
			if Color then self:_SetSelectedColor(Color) end
		end)
	end

	self:_Connect(self.AnimateButton.MouseButton1Click, function()
		self:_RefreshAnimations()
		self:_TogglePopup(self.AnimateButton, self.AnimationPopup)
	end)

	self:_Connect(self.BindingsButton.MouseButton1Click, function()
		self:_RefreshBindings()
		self:_TogglePopup(self.BindingsButton, self.BindingsPopup)
	end)

	self:_Connect(self.MockDataButton.MouseButton1Click, function()
		self:_RefreshMockData()
		self:_TogglePopup(self.MockDataButton, self.MockDataPopup)
	end)

	self:_Connect(self.ScreensButton.MouseButton1Click, function()
		self:_RefreshScreens()
		self:_TogglePopup(self.ScreensButton, self.ScreensPopup)
	end)

	self:_Connect(self.FlowButton.MouseButton1Click, function()
		local Selected = self.Selection:GetTarget()
		if Selected and Selected:IsA('GuiButton') then
			self.FlowSourceObject = Selected
			self.FlowDirty = false
		end
		self:_RefreshFlow()
		self:_TogglePopup(self.FlowButton, self.FlowPopup)
	end)

	self:_Connect(self.PreviewModeButton.MouseButton1Click, function()
		if self.InteractiveMode then self:_ExitInteractiveMode()
		else self:_SetInteractiveMode(true) end
	end)

	local function ExitPreview()
		self:_ExitInteractiveMode()
	end

	self:_Connect(self.PreviewExitButton.MouseButton1Down, ExitPreview)
	self:_Connect(self.PreviewExitButton.MouseButton1Click, ExitPreview)

	self:_Connect(self.RuntimePreviewButton.MouseButton1Click, function()
		self:_ToggleRuntimePreview()
	end)

	self:_Connect(self.ProblemsValidateButton.MouseButton1Click, function()
		self:_ValidateRuntimePackage()
	end)

	self:_Connect(self.PackageSyncButton.MouseButton1Click, function()
		self:_SyncAutoRuntime('Manual Sync')
	end)

	self:_Connect(self.PackageSaveButton.MouseButton1Click, function()
		self:_SavePersistentProject('Manual Save')
	end)

	self:_Connect(self.PackageRecoverButton.MouseButton1Click, function()
		self:_RecoverPreviousProject()
	end)

	self:_Connect(self.PackageValidateButton.MouseButton1Click, function()
		self:_ValidateRuntimePackage()
	end)

	self:_Connect(self.PackageExportButton.MouseButton1Click, function()
		self:_ExportRuntimePackage()
	end)

	self:_Connect(self.PackageImportButton.MouseButton1Click, function()
		self:_ImportRuntimePackage()
	end)

	self:_Connect(self.PackageRuntimeButton.MouseButton1Click, function()
		self:_ToggleRuntimePreview()
	end)

	self:_Connect(self.PackageFrameworkButton.MouseButton1Click, function()
		self:_RefreshFrameworkInspector()
	end)

	self:_Connect(self.FlowCaptureSourceButton.MouseButton1Click, function()
		self:_CaptureFlowSource()
	end)

	self:_Connect(self.FlowActionButton.MouseButton1Click, function()
		if not self.Navigation then return end
		self:_ShowChoicePopup(self.FlowActionButton, self.Navigation.ActionTypes, self.FlowActionType, function(Value)
			self.FlowActionType = Value
			self.FlowDirty = true
			self:_RefreshFlow()
		end)
	end)

	self:_Connect(self.FlowUseScreenButton.MouseButton1Click, function()
		self:_UseSelectedScreenTarget()
	end)

	self:_Connect(self.FlowUseObjectButton.MouseButton1Click, function()
		self:_UseSelectedObjectTarget()
	end)

	self:_Connect(self.FlowTransitionButton.MouseButton1Click, function()
		if not self.Navigation then return end
		self:_ShowChoicePopup(self.FlowTransitionButton, self.Navigation.Transitions, self.FlowTransition, function(Value)
			self.FlowTransition = Value
			self.FlowDirty = true
			self:_RefreshFlow()
		end)
	end)

	self:_Connect(self.FlowTargetBox.FocusLost, function()
		self.FlowDirty = true
	end)

	self:_Connect(self.FlowDurationBox.FocusLost, function()
		self.FlowDirty = true
	end)

	self:_Connect(self.FlowSetButton.MouseButton1Click, function()
		self:_SetFlowAction()
	end)

	self:_Connect(self.FlowClearButton.MouseButton1Click, function()
		self:_ClearFlowAction()
	end)

	self:_Connect(self.FlowTestButton.MouseButton1Click, function()
		self:_TestFlowAction()
	end)

	self:_Connect(self.ScreenSearch:GetPropertyChangedSignal('Text'), function()
		self:_RefreshScreens()
	end)

	self:_Connect(self.ScreenNewButton.MouseButton1Click, function()
		self:_CreateScreen()
	end)

	self:_Connect(self.ScreenOpenButton.MouseButton1Click, function()
		self:_OpenSelectedScreen()
	end)

	self:_Connect(self.ScreenRenameButton.MouseButton1Click, function()
		self:_RenameScreen()
	end)

	self:_Connect(self.ScreenDuplicateButton.MouseButton1Click, function()
		self:_DuplicateScreen()
	end)

	self:_Connect(self.ScreenDeleteButton.MouseButton1Click, function()
		self:_DeleteScreen()
	end)

	self:_Connect(self.ScreenStartButton.MouseButton1Click, function()
		self:_SetStartScreen()
	end)

	self:_Connect(self.BindingModeButton.MouseButton1Click, function()
		self:_ShowChoicePopup(self.BindingModeButton, {'Binding', 'Static'}, self.BindingMode, function(Value)
			self.BindingMode = Value
			self:_RefreshBindings()
		end)
	end)

	self:_Connect(self.BindingSetButton.MouseButton1Click, function()
		self:_SetBinding()
	end)

	self:_Connect(self.BindingClearButton.MouseButton1Click, function()
		self:_ClearBinding()
	end)

	self:_Connect(self.BindingApplyButton.MouseButton1Click, function()
		self:_ApplyBindingPreview(false)
	end)

	self:_Connect(self.BindingApplyAllButton.MouseButton1Click, function()
		self:_ApplyBindingPreview(true)
	end)

	self:_Connect(self.BindingResetButton.MouseButton1Click, function()
		self:_ResetBindingPreview()
		self:SetStatus('Binding preview reset')
	end)

	self:_Connect(self.BindingAutoButton.MouseButton1Click, function()
		self:_ToggleBindingAuto()
	end)

	self:_Connect(self.BindingPathBox:GetPropertyChangedSignal('Text'), function()
		self:_RefreshBindings()
	end)

	self:_Connect(self.MockDataSearch:GetPropertyChangedSignal('Text'), function()
		self:_RefreshMockData()
	end)

	self:_Connect(self.MockDataTypeButton.MouseButton1Click, function()
		self:_ShowChoicePopup(self.MockDataTypeButton, {'String', 'Number', 'Boolean', 'Color3'}, self.MockDataType, function(Value)
			self.MockDataType = Value
			self:_RefreshMockData()
		end)
	end)

	self:_Connect(self.MockDataSetButton.MouseButton1Click, function()
		self:_SetMockData()
	end)

	self:_Connect(self.MockDataDeleteButton.MouseButton1Click, function()
		self:_DeleteMockData()
	end)

	self:_Connect(self.MockDataPreviewButton.MouseButton1Click, function()
		self:_ApplyBindingPreview(true)
	end)

	self:_Connect(self.MockDataResetButton.MouseButton1Click, function()
		self:_ResetBindingPreview()
		self:SetStatus('Mock-data preview reset')
	end)

	self:_Connect(self.AnimationSearch:GetPropertyChangedSignal('Text'), function()
		self:_RefreshAnimations()
	end)

	self:_Connect(self.AnimationCreateButton.MouseButton1Click, function()
		self:_CreateAnimation()
	end)

	self:_Connect(self.AnimationRenameButton.MouseButton1Click, function()
		self:_RenameAnimation()
	end)

	self:_Connect(self.AnimationDeleteButton.MouseButton1Click, function()
		self:_DeleteAnimation()
	end)

	self:_Connect(self.AnimationLoopButton.MouseButton1Click, function()
		self:_ToggleAnimationOption('Loop')
	end)

	self:_Connect(self.AnimationReverseButton.MouseButton1Click, function()
		self:_ToggleAnimationOption('Reverse')
	end)

	self:_Connect(self.AnimationStaggerBox.FocusLost, function()
		self:_CommitAnimationStagger()
	end)

	self:_Connect(self.AnimationEasingButton.MouseButton1Click, function()
		local Items = {
			Enum.EasingStyle.Linear, Enum.EasingStyle.Sine, Enum.EasingStyle.Quad,
			Enum.EasingStyle.Cubic, Enum.EasingStyle.Quart, Enum.EasingStyle.Quint,
			Enum.EasingStyle.Back, Enum.EasingStyle.Bounce, Enum.EasingStyle.Elastic,
			Enum.EasingStyle.Circular, Enum.EasingStyle.Exponential
		}
		self:_ShowChoicePopup(self.AnimationEasingButton, Items, self.AnimationEasingStyle, function(Value)
			self.AnimationEasingStyle = Value
			self.AnimationEasingButton.Text = Value.Name
		end, function(Value)
			return Value.Name
		end)
	end)

	self:_Connect(self.AnimationDirectionButton.MouseButton1Click, function()
		local Items = {Enum.EasingDirection.Out, Enum.EasingDirection.In, Enum.EasingDirection.InOut}
		self:_ShowChoicePopup(self.AnimationDirectionButton, Items, self.AnimationEasingDirection, function(Value)
			self.AnimationEasingDirection = Value
			self.AnimationDirectionButton.Text = Value.Name
		end, function(Value)
			return Value.Name
		end)
	end)

	self:_Connect(self.AnimationTargetButton.MouseButton1Click, function()
		self:_UseSelectedAnimationTarget()
	end)

	self:_Connect(self.AnimationPropertyKindButton.MouseButton1Click, function()
		self:_ShowChoicePopup(self.AnimationPropertyKindButton, {'Native', 'Custom'}, self.AnimationPropertyKind == 'Semantic' and 'Custom' or 'Native', function(Value)
			self.AnimationPropertyKind = Value == 'Custom' and 'Semantic' or 'Native'
			self.AnimationPropertyKindButton.Text = Value
		end)
	end)

	self:_Connect(self.AnimationPropertyPickButton.MouseButton1Click, function()
		self:_PickAnimationProperty()
	end)

	self:_Connect(self.AnimationFromCurrentButton.MouseButton1Click, function()
		self:_UseAnimationCurrent('From')
	end)

	self:_Connect(self.AnimationToCurrentButton.MouseButton1Click, function()
		self:_UseAnimationCurrent('To')
	end)

	self:_Connect(self.AnimationCaptureButton.MouseButton1Click, function()
		self:_UseAnimationCurrent('Both')
	end)

	for Trigger, Button in pairs(self.AnimationTriggerButtons or {}) do
		self:_Connect(Button.MouseButton1Click, function()
			self:_SetAnimationTrigger(Trigger)
		end)
	end

	self:_Connect(self.AnimationTriggerTargetButton.MouseButton1Click, function()
		self:_BindAnimationTriggerTarget()
	end)

	self:_Connect(self.AnimationPresetButton.MouseButton1Click, function()
		self:_MakeAnimationPreset()
	end)

	self:_Connect(self.AnimationPresetClearButton.MouseButton1Click, function()
		self:_ClearAnimationPreset()
	end)

	self:_Connect(self.AnimationInheritEndButton.MouseButton1Click, function()
		self:_ChooseAnimationInheritance(self.AnimationInheritEndButton, function(Name)
			self:_InheritAnimationEnd(Name)
		end, true)
	end)

	self:_Connect(self.AnimationReverseFromButton.MouseButton1Click, function()
		self:_ChooseAnimationInheritance(self.AnimationReverseFromButton, function(Name)
			self:_ReverseAnimationFrom(Name)
		end)
	end)

	self:_Connect(self.AnimationTimeline.MouseButton1Down, function(X)
		self.AnimationTimelineDragging = true
		self:_UpdateAnimationTimelineFromMouse(X)
	end)

	self:_Connect(self.AnimationTimeline.MouseMoved, function(X)
		if self.AnimationTimelineDragging then self:_UpdateAnimationTimelineFromMouse(X) end
	end)

	self:_Connect(self.AnimationTimeline.MouseButton1Up, function()
		self.AnimationTimelineDragging = false
	end)

	self:_Connect(self.AnimationTimeline.InputEnded, function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then self.AnimationTimelineDragging = false end
	end)

	self:_Connect(self.AnimationTimeBox.FocusLost, function()
		self:_SetAnimationScrub(tonumber(self.AnimationTimeBox.Text) or 0)
	end)

	self:_Connect(self.AnimationAddTrackButton.MouseButton1Click, function()
		self:_AddAnimationTrack()
	end)

	self:_Connect(self.AnimationUpdateTrackButton.MouseButton1Click, function()
		self:_UpdateAnimationTrack()
	end)

	self:_Connect(self.AnimationDeleteTrackButton.MouseButton1Click, function()
		self:_DeleteAnimationTrack()
	end)

	self:_Connect(self.AnimationPlayButton.MouseButton1Click, function()
		self:_PlayAnimationPreview()
	end)

	self:_Connect(self.AnimationStopButton.MouseButton1Click, function()
		self:_StopAnimationPreview(false)
		self:SetStatus('Animation preview stopped at ' .. Format(self.AnimationScrubTime or 0) .. 's')
	end)

	self:_Connect(self.AnimationResetButton.MouseButton1Click, function()
		self:_StopAnimationPreview(true)
		self:SetStatus('Animation preview reset')
	end)

	self:_Connect(self.InsertSearch:GetPropertyChangedSignal('Text'), function()
		self:_RefreshInsertPalette()
	end)

	self:_Connect(self.InsertPackButton.MouseButton1Click, function()
		self:_CycleStylePack()
	end)

	self:_Connect(self.ComponentSearch:GetPropertyChangedSignal('Text'), function()
		self:_RefreshComponents()
	end)

	if self.Components and self.Components.Changed then
		self:_Connect(self.Components.Changed.Event, function(Action)
			if self.Destroyed then return end
			if Action ~= 'Preset' then self:_QueueComponentLibrarySync(Action or 'Component Edit') end
			if self.ComponentsPopup and self.ComponentsPopup.Visible then self:_RefreshComponents() end
		end)
	end

	self:_Connect(self.ComponentLibrarySyncButton.MouseButton1Click, function()
		self:_SyncComponentLibrary('Manual Sync')
	end)

	self:_Connect(self.ComponentLibraryRevealButton.MouseButton1Click, function()
		self:_RevealComponentLibrary()
	end)

	self:_Connect(self.ComponentCreateButton.MouseButton1Click, function()
		self:_CreateComponentFromSelection()
	end)

	self:_Connect(self.ComponentUpdateButton.MouseButton1Click, function()
		self:_UpdateComponentFromSelection()
	end)

	self:_Connect(self.ComponentInstanceButton.MouseButton1Click, function()
		self:_InstantiateComponent()
	end)

	self:_Connect(self.ComponentDetachButton.MouseButton1Click, function()
		self:_DetachComponent()
	end)

	self:_Connect(self.ComponentDeleteButton.MouseButton1Click, function()
		self:_DeleteComponent()
	end)

	self:_Connect(self.VariantButton.MouseButton1Click, function()
		if not self.Components or not self.SelectedComponent then return end
		local Variants = self.Components:GetVariants(self.SelectedComponent)
		self:_ShowChoicePopup(self.VariantButton, Variants, self.SelectedVariant, function(Value)
			self.SelectedVariant = Value
			if self.VariantNameBox then self.VariantNameBox.Text = Value == 'Default' and '' or Value end
			self:_RefreshComponents()
		end)
	end)

	self:_Connect(self.VariantSaveButton.MouseButton1Click, function()
		self:_SaveVariant()
	end)

	self:_Connect(self.VariantRenameButton.MouseButton1Click, function()
		self:_RenameVariant()
	end)

	self:_Connect(self.VariantDeleteButton.MouseButton1Click, function()
		self:_DeleteVariant()
	end)

	self:_Connect(self.VariantApplyButton.MouseButton1Click, function()
		self:_ApplyVariant()
	end)

	self:_Connect(self.SlotMarkButton.MouseButton1Click, function()
		self:_MarkSlot()
	end)

	self:_Connect(self.SlotClearButton.MouseButton1Click, function()
		self:_ClearSlot()
	end)

	if self.ReloadDevButton then
		self:_Connect(self.ReloadDevButton.MouseButton1Click, function()
			self.StatusLabel.Text = 'Reloading development source...'
			task.defer(self.ReloadDev)
		end)
	end

	self:_Connect(self.AlignLeftButton.MouseButton1Click, function() self:_Align('Left') end)
	self:_Connect(self.AlignCenterXButton.MouseButton1Click, function() self:_Align('CenterX') end)
	self:_Connect(self.AlignRightButton.MouseButton1Click, function() self:_Align('Right') end)
	self:_Connect(self.AlignTopButton.MouseButton1Click, function() self:_Align('Top') end)
	self:_Connect(self.AlignCenterYButton.MouseButton1Click, function() self:_Align('CenterY') end)
	self:_Connect(self.AlignBottomButton.MouseButton1Click, function() self:_Align('Bottom') end)
	self:_Connect(self.DistributeHButton.MouseButton1Click, function() self:_Distribute('Horizontal') end)
	self:_Connect(self.DistributeVButton.MouseButton1Click, function() self:_Distribute('Vertical') end)
	self:_Connect(self.EqualWidthButton.MouseButton1Click, function() self:_Equalize('Width') end)
	self:_Connect(self.EqualHeightButton.MouseButton1Click, function() self:_Equalize('Height') end)
	self:_Connect(self.EqualSizeButton.MouseButton1Click, function() self:_Equalize('Size') end)

	self:_Connect(self.DeviceButton.MouseButton1Click, function()
		local Current = self:_GetDevice()
		self:_ShowChoicePopup(self.DeviceButton, Theme.Devices, Current, function(_, Index)
			self.DeviceIndex = Index
			self.Zoom = 1
			self.Pan = Vector2.new()
			self:_FitDevice()
			self:_UpdateStatus()
			self:_RecordHistory('Set Preview Device')
		end, function(Device)
			if Device.Dynamic == 'StudioViewport' then
				local Camera = workspace.CurrentCamera
				local Size = Camera and Camera.ViewportSize or Vector2.new(Device.Width, Device.Height)
				return string.format('%s  |  %dx%d', Device.Name, math.floor(Size.X + .5), math.floor(Size.Y + .5))
			end
			return Device.Name .. '  |  ' .. Device.Width .. 'x' .. Device.Height
		end)
	end)

	self:_Connect(self.ZoomOutButton.MouseButton1Click, function()
		self:_SetZoom(self.Zoom - Theme.Metric.ZoomStep)
	end)

	self:_Connect(self.ZoomInButton.MouseButton1Click, function()
		self:_SetZoom(self.Zoom + Theme.Metric.ZoomStep)
	end)

	self:_Connect(self.ZoomLabel.MouseButton1Click, function()
		self:_SetZoom(1)
	end)

	self:_Connect(self.FitButton.MouseButton1Click, function()
		self.Zoom = 1
		self.Pan = Vector2.new()
		self:_FitDevice()
	end)

	local function BindStudioViewport()
		if self.StudioViewportConnection then
			self.StudioViewportConnection:Disconnect()
			self.StudioViewportConnection = nil
		end
		local Camera = workspace.CurrentCamera
		if not Camera then return end
		self.StudioViewportConnection = Camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
			local Definition = Theme.Devices[self.DeviceIndex]
			if Definition and Definition.Dynamic == 'StudioViewport' then
				self:_FitDevice()
				self:_UpdateStatus()
			end
		end)
	end
	BindStudioViewport()
	self:_Connect(workspace:GetPropertyChangedSignal('CurrentCamera'), BindStudioViewport)

	self:_Connect(self.ZoneButton.MouseButton1Click, function()
		if not self.Selection.Root then return end
		local Current = self.Document:GetZone(self.Selection.Root)
		self:_ShowChoicePopup(self.ZoneButton, Theme.Zones, Current, function(Zone)
			self:_SetSelectedZone(Zone)
		end)
	end)

	self:_Connect(self.ColorTargetButton.MouseButton1Click, function()
		local Properties = self:_GetColorProperties()
		if #Properties == 0 then return end
		local Current = self:_GetColorProperty()
		self:_ShowChoicePopup(self.ColorTargetButton, Properties, Current, function(Property)
			if string.sub(Property, 1, 1) == '@' then
				self.ColorSemanticOverride = {
					Object = self.Selection:GetTarget(),
					Key = string.sub(Property, 2),
					Label = string.sub(Property, 2) == 'PrimaryColor' and 'Primary' or 'Secondary'
				}
				self.ColorPropertyOverride = nil
			else
				self.ColorSemanticOverride = nil
				self.ColorPropertyOverride = Property
			end
			self.ColorPropertyIndex = table.find(Properties, Property) or 1
			self:_RefreshColor()
		end, function(Property)
			if Property == '@PrimaryColor' then return 'Primary' end
			if Property == '@SecondaryColor' then return 'Secondary' end
			if Property == '@ShadowColor' then return 'Shadow' end
			if Property == '@TextStrokeColor' then return 'Text Stroke' end
			return tostring(Property)
		end)
	end)

	self:_Connect(self.ColorSVHit.MouseButton1Down, function(X, Y)
		if self:_BeginColorPickerDrag('SV') then self:_PickSV(X, Y) end
	end)
	self:_Connect(self.ColorHueHit.MouseButton1Down, function(X, Y)
		if self:_BeginColorPickerDrag('Hue') then self:_PickHue(X, Y) end
	end)
	self:_Connect(self.ColorSVHit.MouseButton1Up, function()
		if self.ColorPickerDragging == 'SV' then self:_FinishColorPickerDrag() end
	end)
	self:_Connect(self.ColorHueHit.MouseButton1Up, function()
		if self.ColorPickerDragging == 'Hue' then self:_FinishColorPickerDrag() end
	end)
	self:_Connect(self.ColorPreviousPreview.MouseButton1Click, function()
		if self.ColorPrevious then self:_SetSelectedColor(self.ColorPrevious) end
	end)
	self:_Connect(self.ColorHexBox.FocusLost, function()
		local Color = HexToColor(self.ColorHexBox.Text)
		if Color then self:_SetSelectedColor(Color) else self:_RefreshColor() end
	end)

	local function CommitRGB()
		local R = tonumber(self.ColorBoxes[1].Text)
		local G = tonumber(self.ColorBoxes[2].Text)
		local B = tonumber(self.ColorBoxes[3].Text)
		if R and G and B then
			self:_SetSelectedColor(Color3.fromRGB(
				math.clamp(R, 0, 255),
				math.clamp(G, 0, 255),
				math.clamp(B, 0, 255)
			))
		else
			self:_RefreshColor()
		end
	end
	for _, Box in ipairs(self.ColorBoxes) do
		self:_Connect(Box.FocusLost, CommitRGB)
	end

	local function CommitHSV()
		local H = tonumber(self.ColorHSVBoxes[1].Text)
		local S = tonumber(self.ColorHSVBoxes[2].Text)
		local V = tonumber(self.ColorHSVBoxes[3].Text)
		if H and S and V then
			H = (H % 360) / 360
			S = math.clamp(S, 0, 100) / 100
			V = math.clamp(V, 0, 100) / 100
			self:_SetSelectedColor(Color3.fromHSV(H, S, V))
		else
			self:_RefreshColor()
		end
	end
	for _, Box in ipairs(self.ColorHSVBoxes) do
		self:_Connect(Box.FocusLost, CommitHSV)
	end

	self:_Connect(self.Interaction.InputBegan, function(Input)
		self.WidgetFocused = true
		self:_UpdateModifierInput(Input, true)
		if Input.UserInputType == Enum.UserInputType.MouseButton3 then
			self.PanDrag = {
				Mouse = Vector2.new(Input.Position.X, Input.Position.Y),
				Pan = self.Pan
			}
		end
	end)

	self:_Connect(self.Interaction.InputEnded, function(Input)
		self:_UpdateModifierInput(Input, false)
		if Input.UserInputType == Enum.UserInputType.MouseButton3 then self.PanDrag = nil end
	end)

	self:_Connect(self.Interaction.MouseButton2Click, function(X, Y)
		if not self.InteractiveMode then self:_OpenInsertContext(X, Y) end
	end)

	self:_Connect(UserInputService.InputChanged, function(Input)
		if self.ColorPickerDragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
			if self.ColorPickerDragging == 'SV' then
				self:_PickSV(Input.Position.X, Input.Position.Y)
			elseif self.ColorPickerDragging == 'Hue' then
				self:_PickHue(Input.Position.X, Input.Position.Y)
			end
			return
		end

		if Input.UserInputType ~= Enum.UserInputType.MouseWheel or self.InteractiveMode then return end
		local Mouse = UserInputService:GetMouseLocation()
		local DevicePosition, DeviceSize = self.Device.AbsolutePosition, self.Device.AbsoluteSize
		if Mouse.X < DevicePosition.X or Mouse.X > DevicePosition.X + DeviceSize.X
			or Mouse.Y < DevicePosition.Y or Mouse.Y > DevicePosition.Y + DeviceSize.Y
		then return end

		local Direction = Input.Position.Z >= 0 and 1 or -1
		if self:_ScrollScrollerAt(Vector2.new(Mouse.X, Mouse.Y), Direction) then return end
		self:_SetZoom(self.Zoom + Theme.Metric.ZoomStep * Direction)
	end)

	self:_Connect(UserInputService.InputEnded, function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 and self.ColorPickerDragging then
			self:_FinishColorPickerDrag()
		end
	end)

	self:_Connect(self.Interaction.MouseButton1Down, function(X, Y)
		local MousePosition = Vector2.new(X, Y)
		local Child = self.Selection.Child
		if Child and Child.Parent then
			local Left, Top, Width, Height = self:_GetObjectCanvasRect(Child)
			local DevicePoint = (MousePosition - self.Device.AbsolutePosition) / math.max(self.PreviewScale, .01)
			if DevicePoint.X >= Left and DevicePoint.X <= Left + Width
				and DevicePoint.Y >= Top and DevicePoint.Y <= Top + Height
			then
				if not self.Document:IsLocked(self.Selection.Root) then self:_BeginDrag('Move', MousePosition) end
				return
			end
		end

		local Root = self:_HitTestRoot(MousePosition)
		if not Root then
			self.Selection:Clear()
			return
		end

		if self:_IsControlHeld() then
			self.Selection:ToggleRoot(Root)
			return
		end

		if self.Selection:IsSelected(Root) and self.Selection:Count() > 1 then
			self.Selection:SelectRoot(Root, true)
		else
			self.Selection:SelectRoot(Root)
		end

		if not self.Document:IsLocked(Root) then self:_BeginDrag('Move', MousePosition) end
	end)

	self:_Connect(self.Interaction.MouseMoved, function(X, Y)
		local MousePosition = Vector2.new(X, Y)
		self:_UpdateDrag(MousePosition)
		self:_UpdatePan(MousePosition)
	end)

	self:_Connect(self.Interaction.MouseButton1Up, function()
		self:_EndDrag()
	end)

	for Name, Handle in pairs(self.Handles) do
		self:_Connect(Handle.Object.InputBegan, function(Input)
			self:_UpdateModifierInput(Input, true)
		end)
		self:_Connect(Handle.Object.InputEnded, function(Input)
			self:_UpdateModifierInput(Input, false)
		end)
		self:_Connect(Handle.Object.MouseButton1Down, function(X, Y)
			local Root = self.Selection.Root
			if Root and self.Selection:GetTarget() and not self.Document:IsLocked(Root) then
				self:_BeginDrag(Name, Vector2.new(X, Y))
			end
		end)
		self:_Connect(Handle.Object.MouseMoved, function(X, Y)
			self:_UpdateDrag(Vector2.new(X, Y))
		end)
		self:_Connect(Handle.Object.MouseButton1Up, function()
			self:_EndDrag()
		end)
	end
end

function App:_UpdateModifierInput(Input, Began)
	if IsShiftInput(Input) then
		self.ShiftHeld = Began
		self:_RefreshSnapState()
	elseif IsControlInput(Input) then
		self.ControlHeld = Began
	end
end

function App:_HandlePluginKey(Key, Began)
	local Value = string.lower(tostring(Key or ''))

	if IsShiftMouseKey(Key) then
		self.ShiftHeld = Began
		self:_RefreshSnapState()
		return
	end

	if IsControlMouseKey(Key) then
		self.ControlHeld = Began
		return
	end

	if not Began or not self:_ShortcutContextActive() then return end

	if self.InteractiveMode then
		if Value == 'escape' or Value == 'p' then
			self:_RunShortcut('PreviewOff', function() self:_ExitInteractiveMode() end)
		end
		return
	end

	local Ctrl = self:_IsControlHeld()
	local Shift = self:_IsShiftHeld()

	if Ctrl then
		if Value == 'z' then
			self:_RunShortcut(Shift and 'Redo' or 'Undo', function()
				if Shift then self:_Redo() else self:_Undo() end
			end)
		elseif Value == 'y' then self:_RunShortcut('Redo', function() self:_Redo() end)
		elseif Value == 'c' then self:_RunShortcut('Copy', function() self:_Copy() end)
		elseif Value == 'v' then self:_RunShortcut('Paste', function() self:_Paste() end)
		elseif Value == 'x' then self:_RunShortcut('Cut', function() self:_Cut() end)
		elseif Value == 'd' then self:_RunShortcut('Duplicate', function() self:_Duplicate() end)
		elseif Value == 'a' then self:_RunShortcut('SelectAll', function() self.Selection:SelectAllRoots() end)
		end
		return
	end

	if Shift and Value == 's' then
		self:_RunShortcut('Save', function() self:_SavePersistentProject('Shift+S') end)
	elseif Shift and Value == 'd' then
		self:_RunShortcut('Duplicate', function() self:_Duplicate() end)
	elseif Shift and Value == 'a' then
		self:_RunShortcut('Insert', function()
			self.InsertContextPoint = nil
			self.InsertTargetOverride = nil
			self:_RefreshInsertPalette()
			self:_TogglePopup(self.InsertButton, self.InsertPopup)
		end)
	elseif Value == 'delete' or Value == 'backspace' then
		self:_RunShortcut('Delete', function() self:_DeleteSelected() end)
	elseif Value == 'p' then
		self:_RunShortcut('Preview', function() self:_SetInteractiveMode(not self.InteractiveMode) end)
	elseif Value == 'f' then
		self:_RunShortcut('FrameView', function()
			self.Zoom = 1
			self.Pan = Vector2.new()
			self:_FitDevice()
		end)
	elseif Value == 'escape' then
		self:_RunShortcut('Escape', function()
			self:_CloseInsertPopup()
			self:_HideChoicePopup()
		end)
	elseif Value == 'left' or Value == 'right' or Value == 'up' or Value == 'down' then
		local BaseStep = self.SnapIncrement > 0 and self.SnapIncrement or Theme.Metric.Nudge
		local Step = Shift and BaseStep * 10 or BaseStep
		self:_RunShortcut('Nudge:' .. Value, function()
			if Value == 'left' then self:_Nudge(-Step, 0)
			elseif Value == 'right' then self:_Nudge(Step, 0)
			elseif Value == 'up' then self:_Nudge(0, -Step)
			elseif Value == 'down' then self:_Nudge(0, Step) end
		end)
	end
end

function App:_HandleKeyboard(Input, _Processed)
	self:_UpdateModifierInput(Input, true)
	if not self:_ShortcutContextActive() then return end

	local Key = Input.KeyCode
	if Key == Enum.KeyCode.Unknown then return end

	if self.InteractiveMode then
		if Key == Enum.KeyCode.Escape or Key == Enum.KeyCode.P then
			self:_RunShortcut('PreviewOff', function() self:_ExitInteractiveMode() end)
		end
		return
	end

	local Ctrl = self:_IsControlHeld()
	local Shift = self:_IsShiftHeld()

	if Ctrl then
		if Key == Enum.KeyCode.S then
			self:_RunShortcut('Save', function() self:_SavePersistentProject('Ctrl+S') end)
			return
		elseif Key == Enum.KeyCode.Z then
			self:_RunShortcut(Shift and 'Redo' or 'Undo', function()
				if Shift then self:_Redo() else self:_Undo() end
			end)
			return
		elseif Key == Enum.KeyCode.Y then self:_RunShortcut('Redo', function() self:_Redo() end) return
		elseif Key == Enum.KeyCode.C then self:_RunShortcut('Copy', function() self:_Copy() end) return
		elseif Key == Enum.KeyCode.V then self:_RunShortcut('Paste', function() self:_Paste() end) return
		elseif Key == Enum.KeyCode.X then self:_RunShortcut('Cut', function() self:_Cut() end) return
		elseif Key == Enum.KeyCode.D then self:_RunShortcut('Duplicate', function() self:_Duplicate() end) return
		elseif Key == Enum.KeyCode.A then self:_RunShortcut('SelectAll', function() self.Selection:SelectAllRoots() end) return
		end
	end

	if Shift and Key == Enum.KeyCode.S then
		self:_RunShortcut('Save', function() self:_SavePersistentProject('Shift+S') end)
		return
	end

	if Shift and Key == Enum.KeyCode.D then
		self:_RunShortcut('Duplicate', function() self:_Duplicate() end)
		return
	end

	if Shift and Key == Enum.KeyCode.A then
		self:_RunShortcut('Insert', function()
			self.InsertContextPoint = nil
			self.InsertTargetOverride = nil
			self:_RefreshInsertPalette()
			self:_TogglePopup(self.InsertButton, self.InsertPopup)
		end)
		return
	end

	if Key == Enum.KeyCode.P then
		self:_RunShortcut('Preview', function() self:_SetInteractiveMode(not self.InteractiveMode) end)
		return
	end

	if Key == Enum.KeyCode.F then
		self:_RunShortcut('FrameView', function()
			self.Zoom = 1
			self.Pan = Vector2.new()
			self:_FitDevice()
		end)
		return
	end

	if Key == Enum.KeyCode.Escape then
		self:_RunShortcut('Escape', function()
			self:_CloseInsertPopup()
			self:_HideChoicePopup()
		end)
		return
	end

	if Key == Enum.KeyCode.Delete or Key == Enum.KeyCode.Backspace then
		self:_RunShortcut('Delete', function() self:_DeleteSelected() end)
		return
	end

	local BaseStep = self.SnapIncrement > 0 and self.SnapIncrement or Theme.Metric.Nudge
	local Step = Shift and BaseStep * 10 or BaseStep
	if Key == Enum.KeyCode.Left then self:_RunShortcut('Nudge:Left', function() self:_Nudge(-Step, 0) end)
	elseif Key == Enum.KeyCode.Right then self:_RunShortcut('Nudge:Right', function() self:_Nudge(Step, 0) end)
	elseif Key == Enum.KeyCode.Up then self:_RunShortcut('Nudge:Up', function() self:_Nudge(0, -Step) end)
	elseif Key == Enum.KeyCode.Down then self:_RunShortcut('Nudge:Down', function() self:_Nudge(0, Step) end)
	end
end

function App:_UpdatePan(MousePosition)
	local Drag = self.PanDrag
	if not Drag then return end
	self.Pan = Drag.Pan + (MousePosition - Drag.Mouse)
	self:_FitDevice()
end

function App:_Seed()
	local Root = Instance.new('Frame')
	Root.Name = 'MainPanel'
	Root.Size = UDim2.fromOffset(280, 150)
	Root.BackgroundColor3 = Color3.fromRGB(163, 162, 165)
	Root.BorderColor3 = Color3.fromRGB(64, 64, 64)
	Root.BorderSizePixel = 1

	local Title = Instance.new('TextLabel')
	Title.Name = 'Title'
	Title.BackgroundColor3 = Color3.fromRGB(212, 208, 200)
	Title.BorderSizePixel = 0
	Title.Position = UDim2.fromOffset(8, 8)
	Title.Size = UDim2.new(1, -16, 0, 24)
	Title.Font = Theme.FontBold
	Title.Text = 'RUCKUS UI'
	Title.TextColor3 = Theme.Color.Text
	Title.TextSize = 13
	Title.Parent = Root

	local Button = Instance.new('TextButton')
	Button.Name = 'ActionButton'
	Button.AutoButtonColor = false
	Button.BackgroundColor3 = Theme.Color.Face
	Button.BorderColor3 = Theme.Color.FaceDark
	Button.Position = UDim2.new(.5, -55, 1, -38)
	Button.Size = UDim2.fromOffset(110, 24)
	Button.Font = Theme.Font
	Button.Text = 'BUTTON'
	Button.TextColor3 = Theme.Color.Text
	Button.TextSize = 11
	Button.Parent = Root

	self:_AddRoot(Root, 'Center')
end

function App:_InstallStylePresets()
	if not self.Components or not self.StylePacks or not self.ComponentPresets then return end

	for _, PackName in ipairs(self.StylePacks:GetNames()) do
		for _, PresetName in ipairs(self.ComponentPresets:GetNames(PackName)) do
			local Source = self.ComponentPresets:Build(PackName, PresetName)
			if Source then
				local Variants = self.ComponentPresets:GetVariants(PackName, PresetName, Source)
				self.Components:InstallPreset(
					PackName .. '/' .. PresetName,
					Source,
					Variants,
					{Pack = PackName, Preset = PresetName}
				)

				Source:Destroy()
				for _, Variant in pairs(Variants) do Variant:Destroy() end
			end
		end
	end
end

function App:_GetCurrentView()
	local Bounds = self.CameraBounds
	return {
		DeviceIndex = self.DeviceIndex,
		Zoom = self.Zoom,
		Pan = self.Pan,
		CameraBounds = Bounds and {
			Left = Bounds.Left,
			Top = Bounds.Top,
			Right = Bounds.Right,
			Bottom = Bounds.Bottom
		} or nil,
		CameraBoundsVisible = self.CameraBoundsVisible ~= false
	}
end

function App:_EnsureScreens()
	if not self.Screens then return end

	if #self.Screens:GetNames() == 0 then
		local Name = self.Screens:Create('Main', self.Document:GetRoots(), self:_GetCurrentView())
		self.Screens:SetCurrent(Name)
		self.Screens:SetStart(Name)
	elseif not self.Screens:GetCurrent() then
		self.Screens:SetCurrent(self.Screens:GetNames()[1])
	end

	local Current = self.Screens:GetCurrent()
	if not self.DocumentScreen or not self.Screens:Has(self.DocumentScreen) then
		self.DocumentScreen = Current
	end
	if self.DocumentScreen and self.Screens:Has(self.DocumentScreen) then
		self.Screens:SetCurrent(self.DocumentScreen)
	end

	if not self.SelectedScreen or not self.Screens:Has(self.SelectedScreen) then
		self.SelectedScreen = self.DocumentScreen or Current
	end
end

function App:_CaptureChildPath(Root, Child)
	if not Root or not Child then return nil end
	local Path = {}
	local Current = Child

	while Current and Current ~= Root do
		local Parent = Current.Parent
		if not Parent then return nil end
		local Index = table.find(Parent:GetChildren(), Current)
		if not Index then return nil end
		table.insert(Path, 1, Index)
		Current = Parent
	end

	return Current == Root and Path or nil
end

function App:_ResolveChildPath(Root, Path)
	local Current = Root
	for _, Index in ipairs(Path or {}) do
		Current = Current and Current:GetChildren()[Index]
		if not Current then return nil end
	end
	return Current
end

function App:_AnimationPropertyKey(Property, Kind)
	return Kind == 'Semantic' and ('@' .. Property) or Property
end

function App:_GetAnimationProperty(Target, Property, Kind)
	if not Target or Property == '' then return false, nil end
	if Kind == 'Semantic' then
		if not self.ComponentPresets or not self.ComponentPresets:IsSemantic(Target) then return false, nil end
		local Value = self.ComponentPresets:GetSemanticValue(Target, Property)
		return Value ~= nil, Value
	end

	local Success, Value = pcall(function() return Target[Property] end)
	return Success, Value
end

function App:_SetAnimationProperty(Target, Property, Kind, Value)
	if not Target or Property == '' then return false end
	if Kind == 'Semantic' then
		return self.ComponentPresets
			and self.ComponentPresets:IsSemantic(Target)
			and self.ComponentPresets:SetSemanticValue(Target, Property, Value)
			or false
	end

	return pcall(function() Target[Property] = Value end)
end

function App:_CaptureAnimationOriginal(Target, Property, Kind)
	local Key = self:_AnimationPropertyKey(Property, Kind)
	self.AnimationPreview.Originals[Target] = self.AnimationPreview.Originals[Target] or {}
	if self.AnimationPreview.Originals[Target][Key] ~= nil then return end

	local Success, Value = self:_GetAnimationProperty(Target, Property, Kind)
	if Success then self.AnimationPreview.Originals[Target][Key] = Value end
end

function App:_ApplyAnimationPreviewBaseline()
	for Target, Properties in pairs(self.AnimationPreview.Originals or {}) do
		if Target and Target.Parent then
			for Key, Value in pairs(Properties) do
				local Semantic = string.sub(Key, 1, 1) == '@'
				self:_SetAnimationProperty(
					Target,
					Semantic and string.sub(Key, 2) or Key,
					Semantic and 'Semantic' or 'Native',
					Value
				)
			end
		end
	end
end

function App:_RestoreAnimationOriginals()
	self:_ApplyAnimationPreviewBaseline()
	table.clear(self.AnimationPreview.Originals)
end

function App:_CaptureAnimationDefinitionOriginals(Definition, Owner, Seen)
	if not Definition or not Owner then return end
	Seen = Seen or {}
	local Key = Definition.Name or tostring(Definition)
	if Seen[Key] then return end
	Seen[Key] = true

	if Definition.InheritEndFrom and self.Animations then
		self:_CaptureAnimationDefinitionOriginals(self.Animations:Get(Definition.InheritEndFrom), Owner, Seen)
	end

	for _, Track in ipairs(Definition.Tracks or {}) do
		local Target = self:_ResolveRelativeObjectPath(Owner, Track.TargetPath)
		if Target then self:_CaptureAnimationOriginal(Target, Track.Property, Track.PropertyKind or 'Native') end
	end
end

function App:_ApplyAnimationEndPose(Name, Owner, Seen)
	if not self.Animations or not Name or not Owner then return false end
	Seen = Seen or {}
	if Seen[Name] then return false end
	Seen[Name] = true

	local Definition = self.Animations:Get(Name)
	if not Definition then return false end
	if Definition.InheritEndFrom then self:_ApplyAnimationEndPose(Definition.InheritEndFrom, Owner, Seen) end

	for _, Track in ipairs(Definition.Tracks or {}) do
		local Target = self:_ResolveRelativeObjectPath(Owner, Track.TargetPath)
		if Target then
			local Kind = Track.PropertyKind or 'Native'
			local Key = self:_AnimationPropertyKey(Track.Property, Kind)
			local DefaultBase = self.AnimationPreview.Originals[Target] and self.AnimationPreview.Originals[Target][Key]
			local Success, CurrentBase = self:_GetAnimationProperty(Target, Track.Property, Kind)
			if DefaultBase ~= nil and Success then
				local Value, OK = ResolveAnimationEndpoint(DefaultBase, CurrentBase, Track.To, Track.ToExpression)
				if OK then self:_SetAnimationProperty(Target, Track.Property, Kind, Value) end
			end
		end
	end
	return true
end

function App:_StopAnimationPreview(Restore)
	local Preview = self.AnimationPreview
	if not Preview then return end

	if Preview.Connection then
		Preview.Connection:Disconnect()
		Preview.Connection = nil
	end

	for _, Tween in ipairs(Preview.Tweens or {}) do pcall(function() Tween:Cancel() end) end
	table.clear(Preview.Tweens)
	Preview.Playing = false

	if Restore then
		self:_RestoreAnimationOriginals()
		self.AnimationScrubTime = 0
		self:_UpdateAnimationTimelineVisual()
	end
end

function App:_GetAnimationLength(Definition)
	local Length = 0
	if not Definition then return Length end
	for Index, Track in ipairs(Definition.Tracks or {}) do
		local Start = math.max(0, tonumber(Track.Delay) or 0) + math.max(0, tonumber(Definition.Stagger) or 0) * (Index - 1)
		Length = math.max(Length, Start + math.max(0, tonumber(Track.Duration) or 0))
	end
	return Length
end

function App:_PrepareAnimationPreview(Definition)
	local Owner = self:_GetAnimationOwner(Definition)
	if not Owner or not Definition then return false end
	self:_CaptureAnimationDefinitionOriginals(Definition, Owner)
	return true
end

function App:_ApplyAnimationTime(Definition, Time)
	local Owner = self:_GetAnimationOwner(Definition)
	if not Owner or not Definition then return false end

	self:_ApplyAnimationPreviewBaseline()
	if Definition.InheritEndFrom then self:_ApplyAnimationEndPose(Definition.InheritEndFrom, Owner) end

	local Stagger = math.max(0, tonumber(Definition.Stagger) or 0)
	for Index, Track in ipairs(Definition.Tracks or {}) do
		local Target = self:_ResolveRelativeObjectPath(Owner, Track.TargetPath)
		if Target then
			local Kind = Track.PropertyKind or 'Native'
			local Key = self:_AnimationPropertyKey(Track.Property, Kind)
			local DefaultBase = self.AnimationPreview.Originals[Target] and self.AnimationPreview.Originals[Target][Key]
			local Success, CurrentBase = self:_GetAnimationProperty(Target, Track.Property, Kind)

			if DefaultBase ~= nil and Success then
				local From, FromOK = ResolveAnimationEndpoint(DefaultBase, CurrentBase, Track.From, Track.FromExpression)
				local To, ToOK = ResolveAnimationEndpoint(DefaultBase, CurrentBase, Track.To, Track.ToExpression)
				if FromOK and ToOK then
					local Start = math.max(0, tonumber(Track.Delay) or 0) + Stagger * (Index - 1)
					local Duration = math.max(0, tonumber(Track.Duration) or 0)
					local Alpha = Duration <= 0 and (Time >= Start and 1 or 0)
						or math.clamp((Time - Start) / Duration, 0, 1)
					local Eased = TweenService:GetValue(
						Alpha,
						Track.EasingStyle or Enum.EasingStyle.Quad,
						Track.EasingDirection or Enum.EasingDirection.Out
					)
					self:_SetAnimationProperty(Target, Track.Property, Kind, LerpAnimationValue(From, To, Eased))
				end
			end
		end
	end
	return true
end

function App:_UpdateAnimationTimelineVisual()
	if not self.AnimationTimeline then return end
	local Definition = self.SelectedAnimation and self.Animations and self.Animations:Get(self.SelectedAnimation)
	local Length = math.max(self:_GetAnimationLength(Definition), .0001)
	local Alpha = math.clamp((self.AnimationScrubTime or 0) / Length, 0, 1)
	if self.AnimationTimelineFill then self.AnimationTimelineFill.Size = UDim2.fromScale(Alpha, 1) end
	if self.AnimationTimelinePlayhead then self.AnimationTimelinePlayhead.Position = UDim2.fromScale(Alpha, 0) end
	if self.AnimationTimeBox then self.AnimationTimeBox.Text = Format(self.AnimationScrubTime or 0) end
	if self.AnimationLengthLabel then self.AnimationLengthLabel.Text = string.format('%.2fs', self:_GetAnimationLength(Definition)) end
end

function App:_SetAnimationScrub(Time)
	local Definition = self.SelectedAnimation and self.Animations and self.Animations:Get(self.SelectedAnimation)
	if not Definition then return end
	self:_StopAnimationPreview(false)
	if not self:_PrepareAnimationPreview(Definition) then return end
	local Length = self:_GetAnimationLength(Definition)
	self.AnimationScrubTime = math.clamp(tonumber(Time) or 0, 0, math.max(Length, 0))
	self:_ApplyAnimationTime(Definition, self.AnimationScrubTime)
	self:_UpdateAnimationTimelineVisual()
end

function App:_UpdateAnimationTimelineFromMouse(X)
	if not self.AnimationTimeline then return end
	local Width = math.max(self.AnimationTimeline.AbsoluteSize.X, 1)
	local Alpha = math.clamp((X - self.AnimationTimeline.AbsolutePosition.X) / Width, 0, 1)
	local Definition = self.SelectedAnimation and self.Animations and self.Animations:Get(self.SelectedAnimation)
	self:_SetAnimationScrub(self:_GetAnimationLength(Definition) * Alpha)
end


function App:_CaptureSnapshot(IncludeView, Scope)
	Scope = Scope or 'Document'
	local Snapshot = {
		Roots = {},
		SelectedRoots = {},
		PrimaryRoot = nil,
		SelectedChildPath = nil,
		SelectedChildPaths = {},
		PrimaryChildPath = nil,
		SelectedComponent = self.SelectedComponent,
		SelectedVariant = self.SelectedVariant,
		SelectedAnimation = self.SelectedAnimation,
		SelectedTrack = self.SelectedTrack,
		SelectedBindingProperty = self.SelectedBindingProperty,
		SelectedMockPath = self.SelectedMockPath,
		SelectedScreen = self.SelectedScreen,
		DocumentScreen = self.DocumentScreen or self.Screens and self.Screens:GetCurrent() or nil,
		BindingAutoPreview = self.BindingAutoPreview,
		MockDataType = self.MockDataType,
		ActiveStylePack = self.ActiveStylePack,
		SelectedSurface = self.SelectedSurface,
		SelectedTypography = self.SelectedTypography,
		SelectedRarity = self.SelectedRarity
	}

	for Index, Root in ipairs(self.Document:GetRoots()) do
		local Clone = Root:Clone()
		Clone.Parent = nil

		local function RestorePreviewValues(Originals)
			for Object, Properties in pairs(Originals or {}) do
				if Object == Root or Object:IsDescendantOf(Root) then
					local CloneObject = Clone
					if Object ~= Root then
						local Path = self:_CaptureChildPath(Root, Object)
						CloneObject = Path and self:_ResolveChildPath(Clone, Path) or nil
					end

					if CloneObject then
						for Property, Value in pairs(Properties) do
							local Semantic = string.sub(Property, 1, 1) == '@'
							self:_SetAnimationProperty(
								CloneObject,
								Semantic and string.sub(Property, 2) or Property,
								Semantic and 'Semantic' or 'Native',
								Value
							)
						end
					end
				end
			end
		end

		RestorePreviewValues(self.AnimationPreview and self.AnimationPreview.Originals)
		RestorePreviewValues(self.BindingPreview and self.BindingPreview.Originals)
		table.insert(Snapshot.Roots, {
			Root = Clone,
			Zone = self.Document:GetZone(Root)
		})

		if self.Selection.IsSelected and self.Selection:IsSelected(Root) then
			table.insert(Snapshot.SelectedRoots, Index)
		elseif Root == self.Selection.Root then
			table.insert(Snapshot.SelectedRoots, Index)
		end

		if Root == self.Selection.Root then Snapshot.PrimaryRoot = Index end
	end

	if self.Selection.Root and self.Selection.Child then
		Snapshot.SelectedChildPath = self:_CaptureChildPath(self.Selection.Root, self.Selection.Child)
		Snapshot.PrimaryChildPath = Snapshot.SelectedChildPath
		for _, Child in ipairs(self.Selection:GetChildren()) do
			local Path = self:_CaptureChildPath(self.Selection.Root, Child)
			if Path then table.insert(Snapshot.SelectedChildPaths, Path) end
		end
	end

	local CaptureFull = Scope == 'Full'
	if self.Components and (CaptureFull or Scope == 'Components') then
		Snapshot.Components = self.Components:Capture()
	end

	if self.Animations and (CaptureFull or Scope == 'Animations') then
		Snapshot.Animations = self.Animations:Capture()
	end
	if self.MockData and (CaptureFull or Scope == 'MockData') then
		Snapshot.MockData = self.MockData:Capture()
	end

	local ScreenState
	if self.Screens and (CaptureFull or Scope == 'Screens') then
		local Current = self.DocumentScreen or self.Screens:GetCurrent()
		ScreenState = self.Screens:Capture(Current)
		ScreenState.Current = Current
		if Current and ScreenState.Definitions[Current] then
			ScreenState.Definitions[Current].View = self:_GetCurrentView()
		end
		Snapshot.Screens = ScreenState
	end

	local ComponentState = Snapshot.Components
	if ComponentState or ScreenState then
		Snapshot.Cleanup = function()
			if ComponentState and self.Components then self.Components:DestroyState(ComponentState) end
			if ScreenState and self.Screens then self.Screens:DestroyState(ScreenState) end
		end
	end

	if IncludeView then
		Snapshot.View = {
			DeviceIndex = self.DeviceIndex,
			Zoom = self.Zoom,
			Pan = self.Pan,
			ZoneGuidesVisible = self.ZoneGuidesVisible,
			CameraBounds = self:_GetCurrentView().CameraBounds,
			CameraBoundsVisible = self.CameraBoundsVisible ~= false,
			SnapEnabled = self.SnapEnabled,
			SnapIncrement = self.SnapIncrement
		}
	end

	return Snapshot
end

function App:_ClearCurrentDocument()
	for _, Root in ipairs(self.Document:GetRoots()) do
		self:_UnregisterRoot(Root)
	end
	self.Selection:Clear()
	self.Document:Clear()
end

function App:_LoadState(State, CloneRoots)
	local SnapshotScreen = State.DocumentScreen
	local CurrentScreen = self.DocumentScreen or self.Screens and self.Screens:GetCurrent() or nil
	if not State.Screens
		and SnapshotScreen
		and CurrentScreen
		and SnapshotScreen ~= CurrentScreen
	then
		warn(
			'[FORGE Studio] Refused cross-screen history restore from '
				.. tostring(SnapshotScreen)
				.. ' into '
				.. tostring(CurrentScreen)
		)
		return false
	end

	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()
	self.Restoring = true
	self:_ClearCurrentDocument()

	if self.Components and State.Components then
		self.Components:Restore(State.Components, CloneRoots)
	end
	if self.Animations and State.Animations then self.Animations:Restore(State.Animations) end
	if self.MockData and State.MockData then self.MockData:Restore(State.MockData) end
	if self.Screens and State.Screens then self.Screens:Restore(State.Screens, CloneRoots) end

	local OwnerScreen = SnapshotScreen
		or State.Screens and self.Screens and self.Screens:GetCurrent()
		or self.DocumentScreen
		or self.Screens and self.Screens:GetCurrent()
	if self.Screens and OwnerScreen and self.Screens:Has(OwnerScreen) then
		self.Screens:SetCurrent(OwnerScreen)
		self.DocumentScreen = OwnerScreen
	end

	self.ActiveStylePack = State.ActiveStylePack or self.ActiveStylePack
	self.SelectedSurface = State.SelectedSurface or self.SelectedSurface
	self.SelectedTypography = State.SelectedTypography or self.SelectedTypography
	self.SelectedRarity = State.SelectedRarity or self.SelectedRarity
	self:_InstallStylePresets()
	self.SelectedComponent = State.SelectedComponent
	self.SelectedVariant = State.SelectedVariant or 'Default'
	self.SelectedAnimation = State.SelectedAnimation
	self.SelectedTrack = State.SelectedTrack
	self.SelectedBindingProperty = State.SelectedBindingProperty
	self.SelectedMockPath = State.SelectedMockPath
	self.SelectedScreen = State.SelectedScreen
	self.BindingAutoPreview = State.BindingAutoPreview == true
	self.MockDataType = State.MockDataType or self.MockDataType or 'String'

	local Restored = {}
	for Index, Entry in ipairs(State.Roots or {}) do
		local Root = CloneRoots and Entry.Root:Clone() or Entry.Root
		Root.Parent = self.AuthoringLayer or self.Device
		self.Document:AddRoot(Root, Entry.Zone or Root:GetAttribute('FORGEZone') or 'Center')
		self:_RegisterRoot(Root)
		self:_RepairSemanticTree(Root)
		Restored[Index] = Root
	end

	if self.Screens then
		local Owner = self.DocumentScreen or self.Screens:GetCurrent()
		local Definition = Owner and self.Screens:Get(Owner)
		if Owner and Definition then
			self.Screens:Save(Owner, self.Document:GetRoots(), Definition.View)
		end
	end

	if State.View then
		self.DeviceIndex = math.clamp(State.View.DeviceIndex or 1, 1, #Theme.Devices)
		self.Zoom = State.View.Zoom or 1
		self.Pan = State.View.Pan or Vector2.new()
		self.ZoneGuidesVisible = State.View.ZoneGuidesVisible ~= false
		self.CameraBounds = State.View.CameraBounds
		self.CameraBoundsVisible = State.View.CameraBoundsVisible ~= false
		self.SnapEnabled = State.View.SnapEnabled == true
		self.SnapIncrement = math.max(0, tonumber(State.View.SnapIncrement) or self.SnapIncrement or 5)
	end

	local Selected = {}
	for _, Index in ipairs(State.SelectedRoots or {}) do
		if Restored[Index] then table.insert(Selected, Restored[Index]) end
	end

	local Primary = Restored[State.PrimaryRoot or 0]
	if self.Selection.SetRoots and #Selected > 0 then
		self.Selection:SetRoots(Selected, Primary)
	elseif Primary then
		self.Selection:SelectRoot(Primary)
	end

	if Primary then
		local Paths = State.SelectedChildPaths
		if not Paths or #Paths == 0 then Paths = State.SelectedChildPath and {State.SelectedChildPath} or {} end
		local Children = {}
		for _, Path in ipairs(Paths) do
			local Child = self:_ResolveChildPath(Primary, Path)
			if Child and Child ~= Primary then table.insert(Children, Child) end
		end
		if #Children > 0 then
			local PrimaryPath = State.PrimaryChildPath or State.SelectedChildPath
			local PrimaryChild = PrimaryPath and self:_ResolveChildPath(Primary, PrimaryPath) or Children[#Children]
			self.Selection:SetChildren(Children, PrimaryChild)
		end
	end

	self.Restoring = false
	self:_FitDevice()
	if self.ZoneGuides then self.ZoneGuides.Visible = self.ZoneGuidesVisible end
	if self.ZoneGuideButton then Widgets.SetActive(self.ZoneGuideButton, self.ZoneGuidesVisible) end
	self:_UpdateCameraBoundsGuide()
	if self.SnapButton then Widgets.SetActive(self.SnapButton, self.SnapEnabled) end
	if self.SnapStepBox then self.SnapStepBox.Text = self.SnapIncrement > 0 and tostring(self.SnapIncrement) or 'Off' end
	self:_RefreshAll()
	if self.BindingAutoPreview then self:_ApplyBindingPreview(true) end
	return true
end

function App:_RestoreSnapshot(Snapshot)
	return self:_LoadState(Snapshot, true)
end

function App:_RestoreSession(Session)
	self:_LoadState(Session, false)
end

function App:CreateReloadSession()
	if self.InteractiveMode then self:_SetInteractiveMode(false) end
	self:_StopRuntimePreview()
	self:_SaveCurrentScreen()
	return self:_CaptureSnapshot(true)
end

function App:_SetProjectSaveState(State, Detail)
	self.SaveState = State or 'Unsaved'
	self.SaveDetail = Detail or ''
	if self.PackagePopup and self.PackagePopup.Visible then self:_RefreshPackage() end
	if self.StatusLabel then self:_UpdateStatus() end
end

function App:_RestorePersistentProject()
	if not self.Persistence or not self.Packaging then return false end

	local Data, Manifest = self.Persistence:Load(self.Plugin)
	if not Data then return false end

	local Success, Error = self.Packaging:Import(self, Data)
	if not Success then
		self:_SetProjectSaveState('Save Invalid', tostring(Error))
		return false
	end

	self.LastPackage = nil
	self.LastPackageGeneration = -1
	self.LastProblems = {}
	self.LastSavedAt = Manifest and Manifest.SavedAt or os.time()
	self.SaveDirtyVersion = 0
	self.SaveCommittedVersion = 0

	local Stamp = os.date('%H:%M:%S', self.LastSavedAt)
	if Manifest and Manifest.Recovered then
		self:_SetProjectSaveState('Recovered', 'backup restored ' .. Stamp)
		self:SetStatus('Recovered the previous valid FORGE UI autosave')
	else
		self:_SetProjectSaveState('Saved', 'restored ' .. Stamp)
		self:SetStatus('Restored saved FORGE UI project')
	end
	return true
end

function App:_RecoverPreviousProject()
	if not self.Persistence or not self.Packaging or not self.Persistence.LoadPrevious then
		self:SetStatus('Previous project recovery is unavailable')
		return false
	end

	local Data, Manifest = self.Persistence:LoadPrevious(self.Plugin)
	if not Data then
		self:SetStatus('No previous project backup could be recovered: ' .. tostring(Manifest))
		return false
	end

	local Safety = self:_CaptureSnapshot(true, 'Full')
	local function DestroySafety()
		for _, Entry in ipairs(Safety.Roots or {}) do
			if Entry.Root then Entry.Root:Destroy() end
		end
		if Safety.Cleanup then Safety.Cleanup() end
	end

	local Called, Success, Error = pcall(function()
		return self.Packaging:Import(self, Data)
	end)
	if not Called or not Success then
		pcall(function()
			self:_LoadState(Safety, true)
		end)
		DestroySafety()
		local Detail = not Called and Success or Error or 'unknown recovery failure'
		self:SetStatus('Previous project recovery failed: ' .. tostring(Detail))
		return false
	end

	DestroySafety()
	self.LastPackage = nil
	self.LastPackageGeneration = -1
	self.LastProblems = {}
	self.LastSavedAt = Manifest and Manifest.SavedAt or self.LastSavedAt
	self:_QueuePersistentSave('Recovered Previous Save', 1)
	self:_SetProjectSaveState('Recovered', 'previous A/B project slot loaded • autosave pending')
	self:SetStatus('Recovered previous FORGE UI project backup')
	self:_RefreshAll()
	return true
end

function App:_SavePersistentProject(Label, Silent, TargetVersion)
	if self.Destroyed or self.SavingProject then return false end
	if not self.Persistence or not self.Packaging then
		if not Silent then self:SetStatus('Project save unavailable') end
		return false
	end

	if not self.InteractiveMode and not self:_SaveCurrentScreen() then
		self:_SetProjectSaveState('Save Failed', 'current screen checkpoint failed')
		if not Silent then self:SetStatus('Project save blocked: current screen could not be checkpointed') end
		return false
	end

	self.SavingProject = true
	TargetVersion = tonumber(TargetVersion) or self.SaveDirtyVersion

	local CaptureStartedAt = os.clock()
	local Captured, Data = pcall(function()
		return self.Packaging:Capture(self, {Persistence = true})
	end)
	local CaptureSeconds = os.clock() - CaptureStartedAt

	if Captured and self.Screens then
		local Owner = self.DocumentScreen or self.Screens:GetCurrent()
		local ScreenData = type(Data) == 'table' and Data.Screens
		for _, Name in ipairs(self.Screens:GetNames()) do
			local SourceRoots = Name == Owner and self.Document:GetRoots() or self.Screens:GetStoredRoots(Name)
			local Entry = ScreenData and ScreenData[Name]
			if not Entry or type(Entry.Roots) ~= 'table' or #Entry.Roots ~= #SourceRoots then
				Captured = false
				Data = string.format(
					'screen capture validation failed for %s: expected %d root%s, captured %s',
					tostring(Name),
					#SourceRoots,
					#SourceRoots == 1 and '' or 's',
					Entry and type(Entry.Roots) == 'table' and tostring(#Entry.Roots) or 'missing'
				)
				break
			end
		end
	end

	if not Captured then
		self.SavingProject = false
		self:_SetProjectSaveState('Save Failed', tostring(Data))
		if not Silent then self:SetStatus('Project save failed: ' .. tostring(Data)) end
		return false
	end

	local CallSuccess, Success, Result = pcall(function()
		return self.Persistence:Save(self.Plugin, Data)
	end)
	self.SavingProject = false

	if not CallSuccess then
		local Detail = 'persistence error: ' .. tostring(Success)
		self:_SetProjectSaveState('Save Failed', Detail)
		warn('[FORGE Studio] Project save failed: ' .. Detail)
		if not Silent then self:SetStatus('Project save failed: ' .. Detail) end
		return false
	end

	if not Success then
		local Detail = tostring(Result or 'unknown persistence failure')
		self:_SetProjectSaveState('Save Failed', Detail)
		warn('[FORGE Studio] Project save failed: ' .. Detail)
		if not Silent then self:SetStatus('Project save failed: ' .. Detail) end
		return false
	end

	self.SaveCommittedVersion = math.max(self.SaveCommittedVersion, TargetVersion)
	self.LastSavedAt = Result and Result.SavedAt or os.time()

	local Bytes = Result and tonumber(Result.Bytes) or 0
	local EncodeSeconds = Result and tonumber(Result.EncodeSeconds) or 0
	local WriteSeconds = Result and tonumber(Result.WriteSeconds) or 0
	local TotalSeconds = CaptureSeconds + EncodeSeconds + WriteSeconds
	local SizeText = Bytes >= 1024 * 1024
		and string.format('%.2f MB', Bytes / 1024 / 1024)
		or string.format('%.0f KB', Bytes / 1024)
	local Detail = string.format(
		'%s • %s • %s • %.2fs',
		tostring(Label or 'Save'),
		os.date('%H:%M:%S', self.LastSavedAt),
		SizeText,
		TotalSeconds
	)
	local HasNewerEdits = self.SaveCommittedVersion < self.SaveDirtyVersion
	if HasNewerEdits then
		self:_SetProjectSaveState('Unsaved', 'Newer edits after checkpoint • Shift+S to save')
	else
		self:_SetProjectSaveState('Saved', Detail)
		self.SaveDirtySince = nil
	end

	if not Silent then
		self:SetStatus(
			HasNewerEdits
				and ('Checkpoint saved in ' .. string.format('%.2fs', TotalSeconds) .. ' • newer edits unsaved')
				or ('Saved ' .. SizeText .. ' in ' .. string.format('%.2fs', TotalSeconds))
		)
	end
	return true
end

function App:_IsActivelyEditing()
	return self.Drag ~= nil
		or self.ColorPickerDragging ~= nil
		or self.PanDrag ~= nil
		or self.HierarchyDrag ~= nil
		or self.RootDrag ~= nil
		or self.AnimationTimelineDragging == true
		or self.SavingProject == true
end

function App:_SchedulePersistentSave(Label, Delay)
	if self.Destroyed or RunService:IsRunning() or self.SaveTimerScheduled then return end

	self.SaveTimerScheduled = true
	task.delay(Delay or self.SaveInterval, function()
		self.SaveTimerScheduled = false
		if self.Destroyed or RunService:IsRunning() then return end
		if self.SaveCommittedVersion >= self.SaveDirtyVersion then
			self.SaveDirtySince = nil
			return
		end

		local Now = os.clock()
		local IdleFor = Now - (self.SaveLastEditAt or 0)
		local DirtyFor = self.SaveDirtySince and (Now - self.SaveDirtySince) or 0
		local Active = self:_IsActivelyEditing()

		if Active or (IdleFor < self.SaveInterval and DirtyFor < self.SaveMaxDeferral) then
			self:_SetProjectSaveState('Pending', 'waiting for idle')
			self:_SchedulePersistentSave(Label or 'Autosave', math.max(.35, self.SaveInterval - math.min(IdleFor, self.SaveInterval)))
			return
		end

		local TargetVersion = self.SaveDirtyVersion
		self:_SetProjectSaveState('Saving', tostring(Label or 'Autosave'))
		local Success = self:_SavePersistentProject(Label or 'Autosave', true, TargetVersion)

		if self.Destroyed or RunService:IsRunning() then return end
		if Success and self.SaveCommittedVersion >= self.SaveDirtyVersion then
			self.SaveDirtySince = nil
		elseif not Success or self.SaveCommittedVersion < self.SaveDirtyVersion then
			self:_SchedulePersistentSave(Success and 'Autosave' or 'Autosave Retry', Success and self.SaveInterval or 2)
		end
	end)
end

function App:_QueuePersistentSave(Label, Delay)
	if self.Destroyed or RunService:IsRunning() then return end

	self.SaveGeneration += 1
	self.SaveDirtyVersion += 1
	self.SaveLastEditAt = os.clock()
	self.SaveDirtySince = self.SaveDirtySince or self.SaveLastEditAt
	self:_SetProjectSaveState('Unsaved', tostring(Label or 'Edit') .. ' • autosave pending')
	self:_SchedulePersistentSave(Label or 'Autosave', Delay or self.SaveInterval)
end

function App:_GetAutoRuntimePackage()
	local Folder = ReplicatedStorage:FindFirstChild('FORGEExports')
	if not Folder or not Folder:IsA('Folder') then return nil end

	local Package = Folder:FindFirstChild(self.AutoRuntimePackageName or 'FORGEAutoProject')
	if not Package or not Package:IsA('Folder') or Package:GetAttribute('FORGEGeneratedPackage') ~= true then
		return nil
	end
	return Package
end

function App:_SetRuntimeSyncState(State, Detail)
	self.RuntimeSyncState = State or 'Unsynced'
	self.RuntimeSyncDetail = Detail or ''
	if self.PackageInfoLabel then self:_RefreshPackage() end
	if self.StatusLabel then self:_UpdateStatus() end
end

function App:_RestoreAutoRuntimePackage()
	if not self.Packaging then return false end
	local Package = self:_GetAutoRuntimePackage()
	if not Package then return false end

	local Data, Error = self.Packaging:ReadModule(Package)
	if not Data then
		self:_SetRuntimeSyncState('Snapshot Invalid', tostring(Error))
		return false
	end

	if self.Problems then
		local ValidationSuccess, Result = pcall(function()
			return self.Problems:Validate(Data)
		end)
		if not ValidationSuccess then
			self:_SetRuntimeSyncState('Snapshot Invalid', tostring(Result))
			return false
		end

		local Counts = self.Problems:Count(Result)
		if Counts.Error > 0 then
			self.LastProblems = Result
			self:_RefreshProblems()
			self:_SetRuntimeSyncState(
				'Snapshot Invalid',
				string.format('%d runtime error%s in saved snapshot', Counts.Error, Counts.Error == 1 and '' or 's')
			)
			return false
		end
	end

	if Package:GetAttribute('FORGERuntimeOnly') == true then
		self.LastPackage = Data
		self.LastProblems = {}
		self:_SetRuntimeSyncState('Runtime Synced', 'Runtime snapshot is ready for Play')
		return false
	end

	local Success, ImportError = self.Packaging:Import(self, Data)
	if not Success then
		self:_SetRuntimeSyncState('Snapshot Invalid', tostring(ImportError))
		return false
	end

	self.LastPackage = Data
	self.LastProblems = {}
	self:_SetRuntimeSyncState('Runtime Synced', 'Restored last valid snapshot')
	return true
end

function App:_SyncAutoRuntime(Label)
	if self.Destroyed or self.RuntimeSyncing or RunService:IsRunning() then return false end
	if not self.Packaging or not self.Problems then
		self:_SetRuntimeSyncState('Sync Unavailable', 'Packaging or validation module unavailable')
		return false
	end

	self.RuntimeSyncing = true
	local Data = self.LastPackage
	local CaptureSuccess = Data ~= nil and self.LastPackageGeneration == self.RuntimeSyncGeneration

	if not CaptureSuccess then
		CaptureSuccess, Data = pcall(function()
			return self.Packaging:Capture(self)
		end)
		if CaptureSuccess then
			self.LastPackage = Data
			self.LastPackageGeneration = self.RuntimeSyncGeneration
		end
	end

	if not CaptureSuccess then
		self.RuntimeSyncing = false
		self:_SetRuntimeSyncState('Sync Failed', tostring(Data))
		return false
	end

	local ValidateSuccess, Result = pcall(function()
		return self.Problems:Validate(Data)
	end)

	if not ValidateSuccess then
		self.RuntimeSyncing = false
		self:_SetRuntimeSyncState('Validation Failed', tostring(Result))
		return false
	end

	local Counts = self.Problems:Count(Result)
	self.LastPackage = Data
	self.LastProblems = Result
	self:_RefreshProblems()

	if Counts.Error > 0 then
		self.RuntimeSyncing = false
		self:_SetRuntimeSyncState(
			'Validation Failed',
			string.format('%d error%s; runtime UI was not updated', Counts.Error, Counts.Error == 1 and '' or 's')
		)
		return false
	end

	local RuntimeParent = StarterGui
	local RuntimeTargetName = 'StarterGui'

	do
		local Ruckus = ReplicatedStorage:FindFirstChild('RUCKUS')
		local Manifest = Ruckus and Ruckus:FindFirstChild('PlaceManifest')
		if Manifest and Manifest:IsA('ModuleScript') then
			local Success, PlaceData = pcall(require, Manifest)
			if Success and type(PlaceData) == 'table' and PlaceData.Role == 'Central' then
				RuntimeParent = ReplicatedStorage
				RuntimeTargetName = 'ReplicatedStorage'
			end
		end
	end

	local Gui, Error = self.Packaging:WriteRuntimeGui(
		RuntimeParent,
		self.AutoRuntimeGuiName or 'FORGEAutoUI',
		self,
		Data
	)

	if not Gui then
		self.RuntimeSyncing = false
		self:_SetRuntimeSyncState('Sync Failed', tostring(Error))
		self:SetStatus('Runtime sync failed: ' .. tostring(Error))
		warn('[FORGE Studio] Runtime sync failed: ' .. tostring(Error))
		return false
	end

	-- Central has CharacterAutoLoads disabled. Its baked runtime UI lives in
	-- ReplicatedStorage and is injected directly into PlayerGui by the Central
	-- client bootstrap, preserving this exact generated tree and responsive
	-- geometry instead of relying on Roblox's StarterGui spawn copy.
	if RuntimeParent ~= StarterGui then
		local OldStarter = StarterGui:FindFirstChild(self.AutoRuntimeGuiName or 'FORGEAutoUI')
		if OldStarter and OldStarter:IsA('ScreenGui') and OldStarter:GetAttribute('FORGEGeneratedRuntimeUI') == true then
			OldStarter:Destroy()
		end
	end

	Gui:SetAttribute('FORGELastSyncLabel', tostring(Label or 'Edit'))

	local Exports = ReplicatedStorage:FindFirstChild('FORGEExports')
	local Legacy = Exports and Exports:FindFirstChild(self.AutoRuntimePackageName or 'FORGEAutoProject')
	if Legacy and Legacy:IsA('Folder') and Legacy:GetAttribute('FORGEGeneratedPackage') == true then
		Legacy:Destroy()
	end

	self.RuntimeSyncing = false
	self:_SetRuntimeSyncState(
		'Runtime Synced',
		string.format(
			'%d screen%s baked to %s',
			#(Data.ScreenOrder or {}),
			#(Data.ScreenOrder or {}) == 1 and '' or 's',
			RuntimeTargetName
		)
	)
	self:SetStatus('Runtime UI synced to ' .. RuntimeTargetName)
	return true
end

function App:_QueueAutoRuntimeSync(Label)
	if self.Destroyed or RunService:IsRunning() then return end
	self.RuntimeSyncGeneration += 1
	local Generation = self.RuntimeSyncGeneration
	self:_SetRuntimeSyncState('Unsynced', tostring(Label or 'Edit') .. ' pending')

	task.delay(3.25, function()
		if self.Destroyed or Generation ~= self.RuntimeSyncGeneration then return end
		self:_SyncAutoRuntime(Label)
	end)
end

function App:_MarkRuntimeDirty(Label)
	if self.Destroyed or RunService:IsRunning() then return end
	self.RuntimeSyncGeneration += 1
	self:_SetRuntimeSyncState('Unsynced', tostring(Label or 'Edit') .. ' pending manual sync')
end

function App:_HistoryScope(Label)
	Label = tostring(Label or 'Edit')

	if string.find(Label, 'Screen', 1, true)
		or string.find(Label, 'Camera Bounds', 1, true)
		or Label == 'Set Preview Device'
	then return 'Screens' end

	if string.find(Label, 'Animation', 1, true) then return 'Animations' end

	if string.find(Label, 'Component', 1, true)
		or string.find(Label, 'Variant', 1, true)
	then return 'Components' end

	if string.find(Label, 'Mock Data', 1, true) then return 'MockData' end
	if Label == 'Set Style Pack' then return 'Full' end
	return 'Document'
end

function App:_RecordHistory(Label)
	if self.Restoring then return end
	Label = Label or 'Edit'
	self.History:Push(Label, self:_HistoryScope(Label))
	self:_MarkRuntimeDirty(Label)
	self:_QueuePersistentSave(Label)
end

function App:_Undo()
	if self.History:Undo() then
		self:_MarkRuntimeDirty('Undo')
		self:_QueuePersistentSave('Undo')
		self:SetStatus('Undo')
	end
end

function App:_Redo()
	if self.History:Redo() then
		self:_MarkRuntimeDirty('Redo')
		self:_QueuePersistentSave('Redo')
		self:SetStatus('Redo')
	end
end

function App:_UpdateHistoryButtons()
	if not self.UndoButton then return end
	self.UndoButton.TextTransparency = self.History:CanUndo() and 0 or .5
	self.RedoButton.TextTransparency = self.History:CanRedo() and 0 or .5
end

function App:SetStatus(Text)
	if self.StatusLabel then self.StatusLabel.Text = tostring(Text or '') end
	return self
end

function App:_GetRelativeObjectPath(Root, Object)
	if not Root or not Object then return nil end
	if Object == Root then return 'Root' end
	if not Object:IsDescendantOf(Root) then return nil end

	local Parts = {}
	local Current = Object
	while Current and Current ~= Root do
		table.insert(Parts, 1, Current.Name)
		Current = Current.Parent
	end

	return Current == Root and table.concat(Parts, '/') or nil
end

function App:_ResolveRelativeObjectPath(Root, Path)
	if not Root or not Path or Path == 'Root' or Path == '' then return Root end

	local Current = Root
	for Part in tostring(Path):gmatch('[^/]+') do
		Current = Current and Current:FindFirstChild(Part)
		if not Current then return nil end
	end
	return Current
end

function App:_GetAnimationPresetKind(Object)
	if not Object or not Object:IsA('GuiObject') then return nil end
	return Object:GetAttribute('FORGESimpleKind')
		or Object:GetAttribute('FORGELayoutKind')
end

function App:_GetAnimationOwner(Definition)
	local Root = self.Selection.Root
	if not Root then return nil end
	if not Definition or not Definition.PresetKind then return Root end

	local Target = self.Selection:GetTarget()
	if Target and self:_GetAnimationPresetKind(Target) == Definition.PresetKind then return Target end
	if self:_GetAnimationPresetKind(Root) == Definition.PresetKind then return Root end

	for _, Descendant in ipairs(Root:GetDescendants()) do
		if Descendant:IsA('GuiObject') and self:_GetAnimationPresetKind(Descendant) == Definition.PresetKind then
			return Descendant
		end
	end
	return nil
end

function App:_ResolveAnimationTrackTarget(Definition, Path)
	local Owner = self:_GetAnimationOwner(Definition)
	return Owner and self:_ResolveRelativeObjectPath(Owner, Path) or nil
end

function App:_GetAnimationTarget()
	local Root = self.Selection.Root
	if not Root then return nil, nil end

	local Definition = self.SelectedAnimation and self.Animations and self.Animations:Get(self.SelectedAnimation)
	local Owner = self:_GetAnimationOwner(Definition) or Root
	local Target = self.Selection.Child or Root

	if Target == Owner or Target:IsDescendantOf(Owner) then
		return Target, self:_GetRelativeObjectPath(Owner, Target)
	end
	return Target, nil
end

function App:_MakeAnimationPreset()
	if not self.Animations or not self.SelectedAnimation then return end
	local Definition = self.Animations:Get(self.SelectedAnimation)
	local DocumentRoot = self.Selection.Root
	local Source = self.Selection:GetTarget()
	local Kind = self:_GetAnimationPresetKind(Source)
	if not Definition or not DocumentRoot or not Source or not Kind then
		self:SetStatus('Select a FORGE component to create a type preset')
		return
	end

	local SourcePath = self:_GetRelativeObjectPath(DocumentRoot, Source)
	if not SourcePath then
		self:SetStatus('Preset source must belong to the selected root')
		return
	end

	local Rebased = {}
	for Index, Track in ipairs(Definition.Tracks or {}) do
		local Target = Definition.PresetKind
			and self:_ResolveAnimationTrackTarget(Definition, Track.TargetPath)
			or self:_ResolveRelativeObjectPath(DocumentRoot, Track.TargetPath)

		if not Target or (Target ~= Source and not Target:IsDescendantOf(Source)) then
			self:SetStatus('Every preset track must target the selected ' .. Kind .. ' or one of its children')
			return
		end

		local Path = self:_GetRelativeObjectPath(Source, Target)
		if not Path then return end
		Rebased[Index] = Path

		if not Track.FromExpression then
			local Success, Current = self:_GetAnimationProperty(Target, Track.Property, Track.PropertyKind or 'Native')
			if Success and Current == Track.From then Track.FromExpression = 'Current' end
		end
	end

	for Index, Path in pairs(Rebased) do Definition.Tracks[Index].TargetPath = Path end
	self.Animations:SetPreset(self.SelectedAnimation, Kind, SourcePath)
	self.AnimationTargetPath = 'Root'
	self.SelectedTrack = nil
	self:_RecordHistory('Create ' .. Kind .. ' Animation Preset')
	self:_RefreshAnimations()
	self:SetStatus(self.SelectedAnimation .. ' now applies to every ' .. Kind)
end

function App:_ClearAnimationPreset()
	if not self.Animations or not self.SelectedAnimation then return end
	local Definition = self.Animations:Get(self.SelectedAnimation)
	local DocumentRoot = self.Selection.Root
	if not Definition or not Definition.PresetKind then return end
	if not DocumentRoot then return end

	local Source = self:_ResolveRelativeObjectPath(DocumentRoot, Definition.PresetSourcePath or 'Root')
	if not Source then
		self:SetStatus('Select the original screen/root before clearing this preset')
		return
	end

	for _, Track in ipairs(Definition.Tracks or {}) do
		local Target = self:_ResolveRelativeObjectPath(Source, Track.TargetPath)
		local Path = Target and self:_GetRelativeObjectPath(DocumentRoot, Target)
		if Path then Track.TargetPath = Path end
	end

	local SourcePath = self:_GetRelativeObjectPath(DocumentRoot, Source) or 'Root'
	self.Animations:ClearPreset(self.SelectedAnimation)
	self.Animations:SetOptions(self.SelectedAnimation, {
		OwnerPath = DocumentRoot.Name,
		TriggerTargetPath = SourcePath
	})
	self.AnimationTargetPath = SourcePath
	self.SelectedTrack = nil
	self:_RecordHistory('Clear Animation Preset')
	self:_RefreshAnimations()
	self:SetStatus('Animation preset cleared')
end

local function AnimationTrackIdentity(Track)
	return table.concat({
		tostring(Track.TargetPath or ''),
		tostring(Track.PropertyKind or 'Native'),
		tostring(Track.Property or '')
	}, '\31')
end

local function FormatAnimationPercent(Value)
	local Rounded = math.abs(Value) < .0000005 and 0 or Value
	local Text = string.format('%.6f', Rounded):gsub('0+$', ''):gsub('%.$', '')
	if Rounded >= 0 then Text = '+' .. Text end
	return Text .. '%'
end

local function ReverseAnimationRelativeExpression(Expression)
	if not Expression or Expression == '' or Expression == 'Current' then return nil end

	local Percent = tostring(Expression):match('^([%+%-]?%d*%.?%d+)%%$')
	if Percent then
		local Factor = 1 + (tonumber(Percent) or 0) / 100
		if math.abs(Factor) < .000001 then return nil end
		return FormatAnimationPercent((1 / Factor - 1) * 100)
	end

	local Pixels = string.lower(tostring(Expression)):match('^([%+%-]?%d*%.?%d+)px$')
	if Pixels then
		local Value = -(tonumber(Pixels) or 0)
		local Text = tostring(Value)
		if Value >= 0 then Text = '+' .. Text end
		return Text .. 'px'
	end

	return nil
end

function App:_GetAnimationInheritanceSources()
	if not self.Animations then return {} end
	local Result = {}
	for _, Name in ipairs(self.Animations:GetNames()) do
		if Name ~= self.SelectedAnimation then table.insert(Result, Name) end
	end
	return Result
end

function App:_ChooseAnimationInheritance(Button, Callback, IncludeNone)
	if not self.Animations or not self.SelectedAnimation then
		self:SetStatus('Create or select the destination animation first')
		return
	end

	local Sources = self:_GetAnimationInheritanceSources()
	if IncludeNone then table.insert(Sources, 1, 'None') end
	if #Sources == 0 then
		self:SetStatus('Create another animation to inherit from')
		return
	end

	self:_ShowChoicePopup(Button, Sources, nil, function(Name)
		Callback(Name)
	end)
end

function App:_InheritAnimationEnd(SourceName)
	if not self.Animations or not self.SelectedAnimation then return end
	local Destination = self.Animations:Get(self.SelectedAnimation)
	if not Destination then return end

	if SourceName == 'None' then
		Destination.InheritEndFrom = nil
		self:_RecordHistory('Clear Animation End Inheritance')
		self:_RefreshAnimations()
		self:SetStatus(self.SelectedAnimation .. ' no longer inherits a starting pose')
		return
	end

	if not self.Animations:Get(SourceName) then return end
	local Seen, Cursor = {}, SourceName
	while Cursor do
		if Cursor == self.SelectedAnimation then
			self:SetStatus('Animation inheritance cannot form a cycle')
			return
		end
		if Seen[Cursor] then break end
		Seen[Cursor] = true
		local Definition = self.Animations:Get(Cursor)
		Cursor = Definition and Definition.InheritEndFrom or nil
	end

	Destination.InheritEndFrom = SourceName
	self.SelectedTrack = nil
	self:_RecordHistory('Inherit Animation End')
	self:_RefreshAnimations()
	self:SetStatus(self.SelectedAnimation .. ' starts from the complete end pose of ' .. SourceName)
end

function App:_ReverseAnimationFrom(SourceName)
	if not self.Animations or not self.SelectedAnimation then return end
	local Source = self.Animations:Get(SourceName)
	local Destination = self.Animations:Get(self.SelectedAnimation)
	if not Source or not Destination then return end

	local Tracks = {}
	for _, SourceTrack in ipairs(Source.Tracks or {}) do
		table.insert(Tracks, {
			TargetPath = SourceTrack.TargetPath,
			Property = SourceTrack.Property,
			PropertyKind = SourceTrack.PropertyKind,
			From = SourceTrack.To,
			FromExpression = 'Current',
			To = SourceTrack.From,
			ToExpression = SourceTrack.FromExpression == 'Current' and 'Default' or SourceTrack.FromExpression,
			Duration = SourceTrack.Duration,
			Delay = SourceTrack.Delay,
			EasingStyle = SourceTrack.EasingStyle,
			EasingDirection = SourceTrack.EasingDirection
		})
	end

	if #Tracks == 0 then
		self:SetStatus(SourceName .. ' has no tracks to reverse')
		return
	end

	if not self.Animations:ReplaceTracks(self.SelectedAnimation, Tracks) then return end
	Destination.InheritEndFrom = nil
	self.Animations:SetOptions(self.SelectedAnimation, {Stagger = Source.Stagger or 0})
	self.SelectedTrack = nil
	self.AnimationTargetPath = 'Root'
	self:_RecordHistory('Reverse Animation From')
	self:_RefreshAnimations()
	self:SetStatus(self.SelectedAnimation .. ' reverses ' .. SourceName .. ' back toward its default pose')
end


function App:_GetAnimationPropertyChoices(Target)
	local Result, Seen = {}, {}

	local function Add(Kind, Property, Label)
		local Key = Kind .. ':' .. Property
		if Seen[Key] then return end
		Seen[Key] = true
		table.insert(Result, {Kind = Kind, Property = Property, Label = Label or (Kind .. ' / ' .. Property)})
	end

	for _, Property in ipairs(AnimationNativeProperties) do
		if Target and Supports(Target, Property) then Add('Native', Property, 'Native / ' .. Property) end
	end

	if Target and self.ComponentPresets and self.ComponentPresets:IsSemantic(Target) then
		for _, Section in ipairs(self.ComponentPresets:GetSemanticSchema(Target) or {}) do
			for _, Field in ipairs(Section[2] or {}) do
				local Key, Label, Type = Field[1], Field[2], Field[3]
				if Type == 'number' or Type == 'Color3' or Type == 'boolean' then
					local Success = self.ComponentPresets:GetSemanticValue(Target, Key) ~= nil
					if Success then Add('Semantic', Key, 'Custom / ' .. tostring(Section[1]) .. ' / ' .. tostring(Label)) end
				end
			end
		end
	end

	table.sort(Result, function(A, B) return A.Label < B.Label end)
	return Result
end

function App:_PickAnimationProperty()
	local Definition = self.SelectedAnimation and self.Animations and self.Animations:Get(self.SelectedAnimation)
	local Target = self:_ResolveAnimationTrackTarget(Definition, self.AnimationTargetPath)
	if not Target then Target = self.Selection:GetTarget() end
	local Choices = self:_GetAnimationPropertyChoices(Target)
	if #Choices == 0 then
		self:SetStatus('No animatable properties on the current target')
		return
	end

	self:_ShowChoicePopup(self.AnimationPropertyPickButton, Choices, nil, function(Choice)
		self.AnimationPropertyKind = Choice.Kind
		self.AnimationPropertyKindButton.Text = Choice.Kind == 'Semantic' and 'Custom' or 'Native'
		self.AnimationPropertyBox.Text = Choice.Property
		local Success, Value = self:_GetAnimationProperty(Target, Choice.Property, Choice.Kind)
		if Success then
			self.AnimationFromBox.Text = Format(Value)
			self.AnimationToBox.Text = Format(Value)
		end
	end, function(Choice)
		return Choice.Label
	end)
end

function App:_UseSelectedAnimationTarget()
	local _, Path = self:_GetAnimationTarget()
	if not Path then return end
	self.AnimationTargetPath = Path
	self.AnimationTargetLabel.Text = 'Target: ' .. Path
	self:_RefreshAnimations()
end

function App:_UseAnimationCurrent(Which)
	local Definition = self.SelectedAnimation and self.Animations and self.Animations:Get(self.SelectedAnimation)
	local Target = self:_ResolveAnimationTrackTarget(Definition, self.AnimationTargetPath)
	if not Target then return end

	local Success, Value = self:_GetAnimationProperty(Target, self.AnimationPropertyBox.Text, self.AnimationPropertyKind)
	if not Success then
		self:SetStatus('Property is not available on the animation target')
		return
	end

	if Which == 'From' then self.AnimationFromBox.Text = Format(Value)
	elseif Which == 'To' then self.AnimationToBox.Text = Format(Value)
	else
		self.AnimationFromBox.Text = Format(Value)
		self.AnimationToBox.Text = Format(Value)
	end
end

function App:_SetAnimationTrigger(EventName)
	if not self.Animations or not self.SelectedAnimation then
		self:SetStatus('Select an animation before setting its trigger')
		return false
	end

	if not self.AnimationTriggerButtons or not self.AnimationTriggerButtons[EventName] then return false end
	if not self.Animations:SetOptions(self.SelectedAnimation, {Trigger = EventName}) then return false end

	self:_RecordHistory('Set Animation Trigger')
	self:_RefreshAnimations()
	self:SetStatus('Animation trigger: ' .. EventName)
	return true
end

function App:_BindAnimationTriggerTarget()
	if not self.Animations or not self.SelectedAnimation then return end
	local Root = self.Selection.Root
	local _, Path = self:_GetAnimationTarget()
	if not Root or not Path then return end

	self.Animations:SetOptions(self.SelectedAnimation, {
		OwnerPath = Root.Name,
		TriggerTargetPath = Path
	})
	self:_RecordHistory('Bind Animation Trigger')
	self:_RefreshAnimations()
end

function App:_RefreshAnimations()
	if not self.AnimationList then return end
	Clear(self.AnimationList, {[self.AnimationLayout] = true})
	Clear(self.AnimationTrackList, {[self.AnimationTrackLayout] = true})

	if not self.Animations then
		self.AnimationInfoLabel.Text = 'Animations module unavailable'
		return
	end

	if self.SelectedAnimation and not self.Animations:Has(self.SelectedAnimation) then
		self.SelectedAnimation = nil
		self.SelectedTrack = nil
	end

	local Query = string.lower(self.AnimationSearch and self.AnimationSearch.Text or '')
	local Order = 0

	for _, Name in ipairs(self.Animations:GetNames()) do
		if Query == '' or string.find(string.lower(Name), Query, 1, true) then
			Order += 1
			local Definition = self.Animations:Get(Name)
			local DisplayName = Definition and Definition.PresetKind
				and (Name .. '  |  ' .. Definition.PresetKind .. ' preset')
				or Name
			local Row = Widgets.TreeRow(self.AnimationList, DisplayName, 0)
			Row.Object.LayoutOrder = Order
			Row.Object.ZIndex = self.AnimationPopup.ZIndex + 2
			Row.Label.ZIndex = Row.Object.ZIndex + 1
			Row.Icon.ZIndex = Row.Object.ZIndex + 1
			Widgets.SetTreeRowSelected(Row, self.SelectedAnimation == Name, true)
			Row.Object.MouseButton1Click:Connect(function()
				self:_StopAnimationPreview(true)
				self.SelectedAnimation = Name
				self.SelectedTrack = nil
				self.AnimationScrubTime = 0
				self.AnimationNameBox.Text = Name
				self:_RefreshAnimations()
			end)
		end
	end

	local Definition = self.SelectedAnimation and self.Animations:Get(self.SelectedAnimation)
	if not Definition then
		self.AnimationInfoLabel.Text = 'Create or select an animation.'
		self.AnimationLoopButton.Text = 'Loop: Off'
		self.AnimationReverseButton.Text = 'Yoyo: Off'
		for Trigger, Button in pairs(self.AnimationTriggerButtons or {}) do
			Widgets.SetActive(Button, Trigger == 'Manual')
		end
		self.AnimationTriggerLabel.Text = 'Trigger target: Root'
		self.AnimationPresetLabel.Text = 'Preset: none'
		self.AnimationPresetButton.Text = 'Make Preset'
		self.AnimationPresetClearButton.Visible = false
		self.AnimationTriggerTargetButton.Visible = true
		self.AnimationInheritEndButton.Text = 'Inherit End...'
		self.AnimationInheritEndButton.TextTransparency = .55
		self.AnimationReverseFromButton.TextTransparency = .55
		self:_UpdateAnimationTimelineVisual()
		return
	end

	self.AnimationNameBox.Text = self.SelectedAnimation
	self.AnimationInheritEndButton.TextTransparency = 0
	self.AnimationReverseFromButton.TextTransparency = 0
	self.AnimationInheritEndButton.Text = Definition.InheritEndFrom
		and ('Inherits: ' .. Definition.InheritEndFrom)
		or 'Inherit End...'
	self.AnimationLoopButton.Text = 'Loop: ' .. (Definition.Loop and 'On' or 'Off')
	self.AnimationReverseButton.Text = 'Yoyo: ' .. (Definition.Reverse and 'On' or 'Off')
	self.AnimationStaggerBox.Text = Format(Definition.Stagger or 0)
	local ActiveTrigger = tostring(Definition.Trigger or 'Manual')
	for Trigger, Button in pairs(self.AnimationTriggerButtons or {}) do
		Widgets.SetActive(Button, Trigger == ActiveTrigger)
	end
	if Definition.PresetKind then
		self.AnimationTriggerLabel.Text = 'Applies automatically to every ' .. Definition.PresetKind
		self.AnimationPresetLabel.Text = 'Preset: ' .. Definition.PresetKind
		self.AnimationPresetButton.Text = 'Update Preset'
		self.AnimationPresetClearButton.Visible = true
		self.AnimationTriggerTargetButton.Visible = false
	else
		self.AnimationTriggerLabel.Text = 'Trigger target: ' .. tostring(Definition.OwnerPath or '(root)') .. ' / ' .. tostring(Definition.TriggerTargetPath or 'Root')
		self.AnimationPresetLabel.Text = 'Preset: none'
		self.AnimationPresetButton.Text = 'Make Preset'
		self.AnimationPresetClearButton.Visible = false
		self.AnimationTriggerTargetButton.Visible = true
	end

	for Index, Track in ipairs(Definition.Tracks) do
		local Kind = Track.PropertyKind == 'Semantic' and 'CUSTOM' or 'NATIVE'
		local Start = math.max(0, tonumber(Track.Delay) or 0) + math.max(0, tonumber(Definition.Stagger) or 0) * (Index - 1)
		local Finish = Start + math.max(0, tonumber(Track.Duration) or 0)
		local FromText = FormatAnimationEndpoint(Track.From, Track.FromExpression)
		local ToText = FormatAnimationEndpoint(Track.To, Track.ToExpression)
		local Text = string.format('%02d  [%s]  %s.%s   %s -> %s   %.2f-%.2fs', Index, Kind, Track.TargetPath == 'Root' and 'Root' or Track.TargetPath, Track.Property, FromText, ToText, Start, Finish)
		local Row = Widgets.TreeRow(self.AnimationTrackList, Text, 0)
		Row.Object.LayoutOrder = Index
		Row.Object.ZIndex = self.AnimationPopup.ZIndex + 2
		Row.Label.ZIndex = Row.Object.ZIndex + 1
		Row.Icon.ZIndex = Row.Object.ZIndex + 1
		Widgets.SetTreeRowSelected(Row, self.SelectedTrack == Index, true)
		Row.Object.MouseButton1Click:Connect(function() self:_SelectAnimationTrack(Index) end)
	end

	local Length = self:_GetAnimationLength(Definition)
	self.AnimationInfoLabel.Text = string.format(
		'%d track%s | %.2fs | %s trigger | %s%s\nCurrent = live start. Default/Base and %%/px values always use the authored default.',
		#Definition.Tracks,
		#Definition.Tracks == 1 and '' or 's',
		Length,
		tostring(Definition.Trigger or 'Manual'),
		Definition.PresetKind and ('all ' .. Definition.PresetKind) or ('owner ' .. tostring(Definition.OwnerPath or '(unbound)')),
		Definition.InheritEndFrom and (' | starts from ' .. Definition.InheritEndFrom .. ' end') or ''
	)
	self:_UpdateAnimationTimelineVisual()
end


function App:_CreateAnimation()
	if not self.Animations then return end
	local Name = self.AnimationNameBox.Text
	if Name == '' then Name = 'Animation' end

	Name = self.Animations:Create(Name)
	local Root, Path = self.Selection.Root, select(2, self:_GetAnimationTarget())
	if Root then
		self.Animations:SetOptions(Name, {
			OwnerPath = Root.Name,
			TriggerTargetPath = Path or 'Root'
		})
	end
	self.SelectedAnimation = Name
	self.SelectedTrack = nil
	self.AnimationNameBox.Text = Name
	self:_RecordHistory('Create Animation')
	self:_RefreshAnimations()
end

function App:_RenameAnimation()
	if not self.Animations or not self.SelectedAnimation then return end
	local NewName = self.AnimationNameBox.Text
	if NewName == '' or NewName == self.SelectedAnimation then return end

	local Old = self.SelectedAnimation
	if self.Animations:Rename(Old, NewName) then
		self.SelectedAnimation = NewName
		self:_RecordHistory('Rename Animation')
		self:_RefreshAnimations()
	end
end

function App:_DeleteAnimation()
	if not self.Animations or not self.SelectedAnimation then return end
	self:_StopAnimationPreview(true)
	if self.Animations:Remove(self.SelectedAnimation) then
		self.SelectedAnimation = nil
		self.SelectedTrack = nil
		self:_RecordHistory('Delete Animation')
		self:_RefreshAnimations()
	end
end

function App:_SelectAnimationTrack(Index)
	local Definition = self.SelectedAnimation and self.Animations and self.Animations:Get(self.SelectedAnimation)
	local Track = Definition and Definition.Tracks[Index]
	if not Track then return end

	self.SelectedTrack = Index
	self.AnimationTargetPath = Track.TargetPath
	self.AnimationPropertyKind = Track.PropertyKind == 'Semantic' and 'Semantic' or 'Native'
	self.AnimationPropertyKindButton.Text = self.AnimationPropertyKind == 'Semantic' and 'Custom' or 'Native'
	self.AnimationPropertyBox.Text = Track.Property
	self.AnimationFromBox.Text = FormatAnimationEndpoint(Track.From, Track.FromExpression)
	self.AnimationToBox.Text = FormatAnimationEndpoint(Track.To, Track.ToExpression)
	self.AnimationDurationBox.Text = Format(Track.Duration)
	self.AnimationDelayBox.Text = Format(Track.Delay)
	self.AnimationEasingStyle = Track.EasingStyle or Enum.EasingStyle.Quad
	self.AnimationEasingDirection = Track.EasingDirection or Enum.EasingDirection.Out
	self.AnimationEasingButton.Text = self.AnimationEasingStyle.Name
	self.AnimationDirectionButton.Text = self.AnimationEasingDirection.Name
	self.AnimationTargetLabel.Text = 'Target: ' .. tostring(Track.TargetPath)
	self:_RefreshAnimations()
end

function App:_CycleAnimationEasing()
	local Items = {
		Enum.EasingStyle.Linear,
		Enum.EasingStyle.Sine,
		Enum.EasingStyle.Quad,
		Enum.EasingStyle.Cubic,
		Enum.EasingStyle.Quart,
		Enum.EasingStyle.Quint,
		Enum.EasingStyle.Back,
		Enum.EasingStyle.Bounce,
		Enum.EasingStyle.Elastic,
		Enum.EasingStyle.Circular,
		Enum.EasingStyle.Exponential
	}
	local Index = table.find(Items, self.AnimationEasingStyle) or 0
	self.AnimationEasingStyle = Items[Index % #Items + 1]
	self.AnimationEasingButton.Text = self.AnimationEasingStyle.Name
end

function App:_CycleAnimationDirection()
	local Items = {
		Enum.EasingDirection.Out,
		Enum.EasingDirection.In,
		Enum.EasingDirection.InOut
	}
	local Index = table.find(Items, self.AnimationEasingDirection) or 0
	self.AnimationEasingDirection = Items[Index % #Items + 1]
	self.AnimationDirectionButton.Text = self.AnimationEasingDirection.Name
end

function App:_CaptureAnimationCurrent()
	local Root = self.Selection.Root
	local Target = Root and self:_ResolveRelativeObjectPath(Root, self.AnimationTargetPath)
	if not Root or not Target then return end

	local Property = self.AnimationPropertyBox.Text
	if Property == '' then
		self:SetStatus('Pick a property first')
		return
	end

	local Success, Value = self:_GetAnimationProperty(Target, Property, self.AnimationPropertyKind)
	if not Success then
		self:SetStatus(Property .. ' is not available on ' .. Target.ClassName)
		return
	end

	self.AnimationFromBox.Text = Format(Value)
	self.AnimationToBox.Text = Format(Value)
end


function App:_ReadAnimationTrackForm(Existing)
	local Definition = self.SelectedAnimation and self.Animations and self.Animations:Get(self.SelectedAnimation)
	local Owner = self:_GetAnimationOwner(Definition)
	if not Owner then return nil end

	local Path = self.AnimationTargetPath or (Existing and Existing.TargetPath) or 'Root'
	local Target = self:_ResolveRelativeObjectPath(Owner, Path)
	local Property = self.AnimationPropertyBox.Text
	local Kind = self.AnimationPropertyKind or (Existing and Existing.PropertyKind) or 'Native'
	if not Target or Property == '' then return nil end

	local Success, Current = self:_GetAnimationProperty(Target, Property, Kind)
	if not Success then return nil end

	local FromExpression = ParseAnimationExpression(self.AnimationFromBox.Text)
	local ToExpression = ParseAnimationExpression(self.AnimationToBox.Text)
	local From = FromExpression and Current or Parse(self.AnimationFromBox.Text, Current)
	local To = ToExpression and Current or Parse(self.AnimationToBox.Text, Current)
	if From == nil or To == nil then return nil end

	local _, FromOK = ResolveAnimationEndpoint(Current, Current, From, FromExpression)
	local _, ToOK = ResolveAnimationEndpoint(Current, Current, To, ToExpression)
	if not FromOK or not ToOK then
		self:SetStatus('Relative value is not supported for this property type')
		return nil
	end

	return {
		TargetPath = Path,
		Property = Property,
		PropertyKind = Kind,
		From = From,
		To = To,
		FromExpression = FromExpression,
		ToExpression = ToExpression,
		Duration = math.max(0, tonumber(self.AnimationDurationBox.Text) or .2),
		Delay = math.max(0, tonumber(self.AnimationDelayBox.Text) or 0),
		EasingStyle = self.AnimationEasingStyle,
		EasingDirection = self.AnimationEasingDirection
	}
end


function App:_AddAnimationTrack()
	if not self.Animations or not self.SelectedAnimation then return end

	local _, Path = self:_GetAnimationTarget()
	if Path then
		self.AnimationTargetPath = Path
		self.AnimationTargetLabel.Text = 'Target: ' .. Path
	end

	local Track = self:_ReadAnimationTrackForm()
	if not Track then
		self:SetStatus('Animation track fields are invalid')
		return
	end

	self.SelectedTrack = self.Animations:AddTrack(self.SelectedAnimation, Track)
	self:_RecordHistory('Add Animation Track')
	self:_RefreshAnimations()
end

function App:_UpdateAnimationTrack()
	if not self.Animations or not self.SelectedAnimation or not self.SelectedTrack then return end

	local Definition = self.Animations:Get(self.SelectedAnimation)
	local Existing = Definition and Definition.Tracks[self.SelectedTrack]
	local Track = Existing and self:_ReadAnimationTrackForm(Existing)
	if not Track then return end

	if self.Animations:UpdateTrack(self.SelectedAnimation, self.SelectedTrack, Track) then
		self:_RecordHistory('Update Animation Track')
		self:_RefreshAnimations()
	end
end

function App:_DeleteAnimationTrack()
	if not self.Animations or not self.SelectedAnimation or not self.SelectedTrack then return end
	if self.Animations:RemoveTrack(self.SelectedAnimation, self.SelectedTrack) then
		self.SelectedTrack = nil
		self:_RecordHistory('Delete Animation Track')
		self:_RefreshAnimations()
	end
end

function App:_ToggleAnimationOption(Key)
	if not self.Animations or not self.SelectedAnimation then return end
	local Definition = self.Animations:Get(self.SelectedAnimation)
	if not Definition then return end

	self.Animations:SetOptions(self.SelectedAnimation, {
		[Key] = not Definition[Key]
	})
	self:_RecordHistory('Set Animation ' .. Key)
	self:_RefreshAnimations()
end

function App:_CommitAnimationStagger()
	if not self.Animations or not self.SelectedAnimation then return end
	local Value = math.max(0, tonumber(self.AnimationStaggerBox.Text) or 0)
	self.Animations:SetOptions(self.SelectedAnimation, {Stagger = Value})
	self:_RecordHistory('Set Animation Stagger')
	self:_RefreshAnimations()
end

function App:_PlayAnimationPreview()
	if not self.Animations or not self.SelectedAnimation then return end
	local Definition = self.Animations:Get(self.SelectedAnimation)
	if not self.Selection.Root or not Definition then
		self:SetStatus('Select an animation owner root')
		return
	end

	self:_StopAnimationPreview(true)
	if not self:_PrepareAnimationPreview(Definition) then return end

	local Length = self:_GetAnimationLength(Definition)
	if Length <= 0 then
		self:_ApplyAnimationTime(Definition, 0)
		return
	end

	local Preview = self.AnimationPreview
	Preview.Playing = true
	local Started = os.clock()
	local Cycle = Definition.Reverse and Length * 2 or Length

	Preview.Connection = RunService.Heartbeat:Connect(function()
		if not Preview.Playing then return end
		local Elapsed = os.clock() - Started
		local Time = Elapsed

		if Definition.Loop then
			Time = Cycle > 0 and Elapsed % Cycle or 0
		elseif Time >= Cycle then
			Time = Cycle
		end

		local ForwardTime = Definition.Reverse and Time > Length and math.max(0, Length - (Time - Length)) or math.min(Time, Length)
		self.AnimationScrubTime = ForwardTime
		self:_ApplyAnimationTime(Definition, ForwardTime)
		self:_UpdateAnimationTimelineVisual()

		if not Definition.Loop and Elapsed >= Cycle then
			Preview.Connection:Disconnect()
			Preview.Connection = nil
			Preview.Playing = false
			self:SetStatus('Animation preview complete')
		end
	end)

	self:SetStatus('Previewing animation: ' .. self.SelectedAnimation)
end


function App:_CloseInsertPopup()
	if self.InsertPopup then self.InsertPopup.Visible = false end
	if self.PopupDismissLayer then self.PopupDismissLayer.Visible = false end
	self.InsertContextPoint = nil
	self.InsertTargetOverride = nil
end

function App:_ShowPopupAt(Popup, X, Y)
	if not Popup then return end
	if self.ChoicePopup and Popup ~= self.ChoicePopup then self:_HideChoicePopup() end

	for _, Other in ipairs({
		self.InsertPopup, self.ComponentsPopup, self.StylePopup, self.AnimationPopup,
		self.BindingsPopup, self.MockDataPopup, self.ScreensPopup, self.FlowPopup,
		self.ProblemsPopup, self.PackagePopup, self.RootContextPopup
	}) do
		if Other and Other ~= Popup then
			Other.Visible = false
			if Other == self.InsertPopup and self.PopupDismissLayer then self.PopupDismissLayer.Visible = false end
		end
	end

	local Width = Popup.AbsoluteSize.X > 0 and Popup.AbsoluteSize.X or Popup.Size.X.Offset
	local Height = Popup.AbsoluteSize.Y > 0 and Popup.AbsoluteSize.Y or Popup.Size.Y.Offset
	X = math.clamp(X or 0, 0, math.max(0, self.Root.AbsoluteSize.X - Width))
	Y = math.clamp(Y or 0, 0, math.max(0, self.Root.AbsoluteSize.Y - Height))
	Popup.Position = UDim2.fromOffset(X, Y)
	Popup.Visible = true
	if Popup == self.InsertPopup and self.PopupDismissLayer then self.PopupDismissLayer.Visible = true end
end

function App:_OpenInsertForTarget(Target, X, Y)
	if not Target or not self:_CanHierarchyParent(Target) then return end
	self.InsertContextPoint = nil
	self.InsertTargetOverride = Target

	if self.InsertSearch then self.InsertSearch.Text = '' end
	self:_RefreshInsertPalette()

	local RootPosition = self.Root.AbsolutePosition
	self:_ShowPopupAt(
		self.InsertPopup,
		(X or RootPosition.X + 8) - RootPosition.X + 4,
		(Y or RootPosition.Y + Theme.Metric.MenuHeight + Theme.Metric.ToolbarHeight + 8) - RootPosition.Y + 4
	)

	if self.InsertSearch then pcall(function() self.InsertSearch:CaptureFocus() end) end
end

function App:_ShowRootContext(Root, X, Y)
	if not Root or not self.Document:IsRoot(Root) then return end
	if not self.Selection:IsSelected(Root) then self.Selection:SelectRoot(Root) end

	self.RootContextTarget = Root
	self.RootContextPoint = Vector2.new(X, Y)
	self.RootContextInsertButton.Visible = self:_CanHierarchyParent(Root)
	self.RootContextVisibleButton.Text = Root.Visible and 'Hide' or 'Show'
	self.RootContextLockButton.Text = self.Document:IsLocked(Root) and 'Unlock' or 'Lock'

	local RootPosition = self.Root.AbsolutePosition
	self:_ShowPopupAt(self.RootContextPopup, X - RootPosition.X + 4, Y - RootPosition.Y + 4)
end

function App:_ScrollScrollerAt(Mouse, Direction)
	if not Mouse then return false end

	local BestRoot, BestScroll, BestZ
	for _, Root in ipairs(self.Document:GetRoots()) do
		local Candidates = {Root}
		for _, Descendant in ipairs(Root:GetDescendants()) do
			if Descendant:IsA('GuiObject') then table.insert(Candidates, Descendant) end
		end

		for _, Candidate in ipairs(Candidates) do
			if Candidate:GetAttribute('FORGESimpleKind') == 'Scroller' and Candidate.Visible then
				local Viewport = Candidate:FindFirstChild('Viewport')
				local Scroll = Viewport and Viewport:FindFirstChild('Scroll')
				if Viewport and Scroll and Scroll:IsA('ScrollingFrame') then
					local Position, Size = Viewport.AbsolutePosition, Viewport.AbsoluteSize
					local Inside = Mouse.X >= Position.X
						and Mouse.X <= Position.X + Size.X
						and Mouse.Y >= Position.Y
						and Mouse.Y <= Position.Y + Size.Y

					if Inside then
						local Z = Candidate.ZIndex
						if not BestZ or Z >= BestZ then
							BestRoot, BestScroll, BestZ = Candidate, Scroll, Z
						end
					end
				end
			end
		end
	end

	if not BestScroll then return false end
	if self.ComponentPresets and self.ComponentPresets.ScrollScroller then
		return self.ComponentPresets:ScrollScroller(BestRoot, Direction)
	end
	return false
end

function App:_OpenInsertContext(X, Y)
	self.InsertTargetOverride = nil

	if type(X) ~= 'number' or type(Y) ~= 'number' then
		local Mouse = UserInputService:GetMouseLocation()
		X, Y = Mouse.X, Mouse.Y
	end

	local RootPosition = self.Root.AbsolutePosition
	local LocalX = X - RootPosition.X
	local LocalY = Y - RootPosition.Y
	local DevicePosition = self.Device.AbsolutePosition
	local Scale = math.max(self.PreviewScale, .01)
	self.InsertContextPoint = Vector2.new(
		(X - DevicePosition.X) / Scale,
		(Y - DevicePosition.Y) / Scale
	)
	self:_RefreshInsertPalette()
	self:_ShowPopupAt(self.InsertPopup, LocalX + 4, LocalY + 4)
	if self.InsertSearch then
		self.InsertSearch.Text = ''
		pcall(function() self.InsertSearch:CaptureFocus() end)
	end
end

function App:_TogglePopup(Button, Popup)
	if not Button or not Popup then return end

	if self.ChoicePopup and Popup ~= self.ChoicePopup then self:_HideChoicePopup() end

	local Pairs = {
		{self.InsertPopup, self.InsertButton},
		{self.ComponentsPopup, self.ComponentsButton},
		{self.StylePopup, self.StyleButton},
		{self.AnimationPopup, self.AnimateButton},
		{self.BindingsPopup, self.BindingsButton},
		{self.MockDataPopup, self.MockDataButton},
		{self.ScreensPopup, self.ScreensButton},
		{self.FlowPopup, self.FlowButton},
		{self.ProblemsPopup, self.ProblemsButton},
		{self.PackagePopup, self.PackageButton},
		{self.RootContextPopup, nil}
	}

	for _, Entry in ipairs(Pairs) do
		local Other, OtherButton = Entry[1], Entry[2]
		if Other and Other ~= Popup then
			Other.Visible = false
			Widgets.SetActive(OtherButton, false)
		end
	end

	if Popup.Visible then
		if Popup == self.InsertPopup then self:_CloseInsertPopup()
		else Popup.Visible = false end
		Widgets.SetActive(Button, false)
		return
	end

	local Absolute = Button.AbsolutePosition - self.Root.AbsolutePosition
	local X = math.clamp(Absolute.X, 0, math.max(0, self.Root.AbsoluteSize.X - Popup.AbsoluteSize.X))
	local Y = Absolute.Y + Button.AbsoluteSize.Y

	if Y + Popup.AbsoluteSize.Y > self.Root.AbsoluteSize.Y then
		Y = math.max(0, Absolute.Y - Popup.AbsoluteSize.Y)
	end

	Popup.Position = UDim2.fromOffset(X, Y)
	Popup.Visible = true
	if Popup == self.InsertPopup and self.PopupDismissLayer then self.PopupDismissLayer.Visible = true end
	Widgets.SetActive(Button, true)
end
function App:_InsertStylePreset(PackName, PresetName)
	if not self.Components then return end
	local ComponentName = PackName .. '/' .. PresetName

	if not self.Components:Has(ComponentName) then
		self:_InstallStylePresets()
	end

	if not self.Components:Has(ComponentName) then
		self:SetStatus('Style preset unavailable: ' .. ComponentName)
		return
	end

	self.SelectedComponent = ComponentName
	self.SelectedVariant = 'Default'
	self:_InstantiateComponent()
end

function App:_RefreshInsertPalette()
	if not self.InsertList then return end

	Clear(self.InsertList, {[self.InsertLayout] = true})
	local Query = string.lower(self.InsertSearch and self.InsertSearch.Text or '')
	local Order = 0
	local PresetNames = self.ComponentPresets and self.ComponentPresets:GetNames(self.ActiveStylePack) or {}

	if self.InsertTitle then
		self.InsertTitle.Text = self.InsertTargetOverride
			and ('Insert into ' .. self.InsertTargetOverride.Name)
			or 'Insert'
	end
	if self.InsertPackButton then self.InsertPackButton.Text = 'Pack: ' .. tostring(self.ActiveStylePack) end

	if self.ComponentPresets then
		local LastCategory
		for _, PresetName in ipairs(PresetNames) do
			local Meta = self.ComponentPresets:GetMetadata(self.ActiveStylePack, PresetName) or {}
			local Category = tostring(Meta.Category or self.ActiveStylePack)
			local Haystack = string.lower(PresetName .. ' ' .. Category .. ' ' .. tostring(Meta.Description or ''))

			if Query == '' or string.find(Haystack, Query, 1, true) then
				if Category ~= LastCategory then
					Order += 1
					local Header = Widgets.Label(self.InsertList, Category, 10, true)
					Header.TextColor3 = Theme.Color.TextMuted
					Header.Size = UDim2.new(1, -8, 0, Theme.Metric.RowHeight)
					Header.LayoutOrder = Order
					Header.ZIndex = self.InsertPopup.ZIndex + 2
					LastCategory = Category
				end

				Order += 1
				local Label = Meta.DisplayName or PresetName
				local Button = Widgets.Button(self.InsertList, Label)
				Button.Size = UDim2.new(1, -8, 0, Theme.Metric.RowHeight)
				Button.LayoutOrder = Order
				Button.TextXAlignment = Enum.TextXAlignment.Left
				Button.ZIndex = self.InsertPopup.ZIndex + 2
				Button.MouseButton1Click:Connect(function()
					self:_InsertStylePreset(self.ActiveStylePack, PresetName)
				end)
			end
		end
	end

	local LastNativeCategory
	for _, Entry in ipairs(InsertItems) do
		local Haystack = string.lower(Entry.Class .. ' ' .. Entry.Category .. ' roblox native')
		if Query == '' or string.find(Haystack, Query, 1, true) then
			if Entry.Category ~= LastNativeCategory then
				Order += 1
				local Header = Widgets.Label(self.InsertList, Entry.Category, 10, true)
				Header.TextColor3 = Theme.Color.TextMuted
				Header.Size = UDim2.new(1, -8, 0, Theme.Metric.RowHeight)
				Header.LayoutOrder = Order
				Header.ZIndex = self.InsertPopup.ZIndex + 2
				LastNativeCategory = Entry.Category
			end

			Order += 1
			local Button = Widgets.Button(self.InsertList, Entry.Label or Entry.Class)
			Button.Size = UDim2.new(1, -8, 0, Theme.Metric.RowHeight)
			Button.LayoutOrder = Order
			Button.TextXAlignment = Enum.TextXAlignment.Left
			Button.ZIndex = self.InsertPopup.ZIndex + 2
			Button.MouseButton1Click:Connect(function()
				self:_InsertClass(Entry.Class)
			end)
		end
	end
end

function App:_ConfigureInsertedObject(Object)
	if Object:IsA('GuiObject') then
		Object.Name = Object.ClassName
		Object.Size = UDim2.fromOffset(180, 60)
		Object.BorderSizePixel = 0
	end

	if Object:IsA('Frame') then
		Object.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		Object.BackgroundTransparency = .15
	elseif Object:IsA('TextLabel') then
		Object.Name = 'Text'
		Object.BackgroundTransparency = 1
		Object.Text = 'TEXT'
		Object.TextColor3 = Theme.Color.Text
		Object.TextSize = 14
		Object.Font = Theme.Font
		Object.TextXAlignment = Enum.TextXAlignment.Left
	elseif Object:IsA('ImageLabel') then
		Object.Name = 'Image'
		Object.BackgroundTransparency = 1
		Object.Image = ''
	end
end

function App:_ResolveInsertionTarget()
	local Target = self.InsertTargetOverride or self.Selection:GetTarget()
	if not Target then return nil, nil end

	if not Target:IsA('GuiObject') then
		Target = Target.Parent and Target.Parent:IsA('GuiObject') and Target.Parent or nil
	end
	if not Target then return nil, nil end

	if Target:GetAttribute('FORGEInsertionTarget') == true then
		return Target, Target.Parent
	end

	if self.ComponentPresets and self.ComponentPresets:CanAcceptChildren(Target) then
		return self.ComponentPresets:GetInsertionTarget(Target), Target
	end

	if Target:IsA('GuiObject') then return Target, Target end

	return nil, nil
end

function App:_PlaceInsertedObject(Object, Label)
	if not Object or not Object:IsA('GuiObject') then return false end

	local Target, Owner = self:_ResolveInsertionTarget()
	if Target then
		local Root = self.Document:GetRoot(Target)
		if Root and self.Document:IsLocked(Root) then
			Object:Destroy()
			return false
		end

		local Success = pcall(function() Object.Parent = Target end)
		if not Success then
			Object:Destroy()
			self:SetStatus((Label or Object.Name) .. ' cannot be parented here')
			return false
		end

		if self.ComponentPresets then
			self.ComponentPresets:AdoptChild(Owner or Target, Object)
		end

		self.Selection:SelectChild(Object)
		self:_CloseInsertPopup()
		self:_RecordHistory('Insert ' .. (Label or Object.Name))
		self:_RefreshAll()
		return true
	end

	self:_AddRoot(Object, 'Center')
	if self.InsertContextPoint then
		local _, _, Width, Height = self:_GetRect(Object)
		self:_SetRect(
			Object,
			self.InsertContextPoint.X - Width / 2,
			self.InsertContextPoint.Y - Height / 2,
			Width,
			Height
		)
	end
	self:_CloseInsertPopup()
	self:_RecordHistory('Insert ' .. (Label or Object.Name))
	return true
end
function App:_InsertClass(ClassName)
	local Success, Object = pcall(function()
		return Instance.new(ClassName)
	end)

	if not Success or not Object then
		self:SetStatus('Could not create ' .. tostring(ClassName))
		return
	end

	self:_ConfigureInsertedObject(Object)
	if not Object:IsA('GuiObject') then
		Object:Destroy()
		return
	end

	self:_PlaceInsertedObject(Object, Object.Name)
end
function App:_CycleVariant()
	if not self.Components or not self.SelectedComponent then return end

	local Variants = self.Components:GetVariants(self.SelectedComponent)
	if #Variants == 0 then return end

	local Index = table.find(Variants, self.SelectedVariant) or 0
	self.SelectedVariant = Variants[Index % #Variants + 1]
	if self.VariantNameBox then
		self.VariantNameBox.Text = self.SelectedVariant == 'Default' and '' or self.SelectedVariant
	end
	self:_RefreshComponents()
end

function App:_SetComponentLibraryState(State, Detail)
	self.ComponentLibraryState = tostring(State or 'Unsynced')
	self.ComponentLibraryDetail = tostring(Detail or '')

	if self.ComponentLibraryStatusLabel then
		self.ComponentLibraryStatusLabel.Text = string.format(
			'ReplicatedStorage.FORGEComponents\n%s%s',
			self.ComponentLibraryState,
			self.ComponentLibraryDetail ~= '' and ('  •  ' .. self.ComponentLibraryDetail) or ''
		)
	end
end

function App:_SyncComponentLibrary(Label)
	if self.Destroyed or self.ComponentLibrarySyncing then return false end
	if RunService:IsRunning() then
		self:_SetComponentLibraryState('Paused', 'stop Play/Test before publishing')
		return false
	end
	if not self.Components or not self.Components.PublishRuntimeLibrary then
		self:_SetComponentLibraryState('Unavailable', 'update Components module')
		return false
	end

	self.ComponentLibrarySyncing = true
	local Success, LibraryOrError, Stats = pcall(function()
		local Library, PublishStats = self.Components:PublishRuntimeLibrary(ReplicatedStorage, 'FORGEComponents')
		if not Library then error(PublishStats) end
		return Library, PublishStats
	end)
	self.ComponentLibrarySyncing = false

	if not Success then
		self:_SetComponentLibraryState('Sync failed', tostring(LibraryOrError))
		self:SetStatus('Component library sync failed: ' .. tostring(LibraryOrError))
		return false
	end

	Stats = Stats or self.Components:GetRuntimeStats()
	self:_SetComponentLibraryState(
		'Synced',
		string.format(
			'%d component%s  •  %d variant%s',
			tonumber(Stats.Components) or 0,
			tonumber(Stats.Components) == 1 and '' or 's',
			tonumber(Stats.Variants) or 0,
			tonumber(Stats.Variants) == 1 and '' or 's'
		)
	)
	self:SetStatus('Runtime component library synced' .. (Label and ('  |  ' .. tostring(Label)) or ''))
	return true
end

function App:_QueueComponentLibrarySync(Label)
	if self.Destroyed or RunService:IsRunning() then return end
	self.ComponentLibraryGeneration += 1
	local Generation = self.ComponentLibraryGeneration
	self:_SetComponentLibraryState('Pending', tostring(Label or 'Component edit'))

	task.delay(.35, function()
		if self.Destroyed or Generation ~= self.ComponentLibraryGeneration then return end
		self:_SyncComponentLibrary(Label)
	end)
end

function App:_RevealComponentLibrary()
	local Library = ReplicatedStorage:FindFirstChild('FORGEComponents')
	if not Library then
		if not self:_SyncComponentLibrary('Reveal') then return false end
		Library = ReplicatedStorage:FindFirstChild('FORGEComponents')
	end

	if Library then
		StudioSelection:Set({Library})
		self:SetStatus('Selected ReplicatedStorage.FORGEComponents')
		return true
	end
	return false
end

function App:_RefreshComponents()
	if not self.ComponentList then return end

	Clear(self.ComponentList, {[self.ComponentLayout] = true})

	if self.ComponentLibraryStatusLabel then
		local Library = ReplicatedStorage:FindFirstChild('FORGEComponents')
		if Library and Library:IsA('Folder') and Library:GetAttribute('FORGEGeneratedComponentLibrary') == true then
			local ComponentsCount = tonumber(Library:GetAttribute('FORGEComponentCount')) or 0
			local VariantsCount = tonumber(Library:GetAttribute('FORGEVariantCount')) or 0
			if self.ComponentLibraryState ~= 'Pending' and self.ComponentLibraryState ~= 'Sync failed' then
				self:_SetComponentLibraryState(
					'Synced',
					string.format(
						'%d component%s  •  %d variant%s',
						ComponentsCount,
						ComponentsCount == 1 and '' or 's',
						VariantsCount,
						VariantsCount == 1 and '' or 's'
					)
				)
			end
		else
			self:_SetComponentLibraryState(
				self.ComponentLibraryState == 'Pending' and 'Pending' or 'Unsynced',
				self.ComponentLibraryState == 'Pending' and self.ComponentLibraryDetail or 'runtime library not generated'
			)
		end
	end

	if not self.Components then
		local Label = Widgets.Label(self.ComponentList, '(update plugin for Q2)', 11, false)
		Label.TextColor3 = Theme.Color.TextMuted
		Label.Size = UDim2.new(1, 0, 0, Theme.Metric.RowHeight)
		self.ComponentInfoLabel.Text = 'Components module unavailable'
		return
	end

	if self.SelectedComponent and not self.Components:Has(self.SelectedComponent) then
		self.SelectedComponent = nil
		self.SelectedVariant = 'Default'
	end

	local SelectedMeta = self.SelectedComponent and self.Components:GetMetadata(self.SelectedComponent)
	if SelectedMeta and SelectedMeta.BuiltIn and SelectedMeta.Pack ~= self.ActiveStylePack then
		self.SelectedComponent = nil
		self.SelectedVariant = 'Default'
	end

	local Query = string.lower(self.ComponentSearch and self.ComponentSearch.Text or '')
	local Order = 0

	for _, Name in ipairs(self.Components:GetNames()) do
		local Metadata = self.Components:GetMetadata(Name) or {}
		local Visible = not Metadata.BuiltIn or Metadata.Pack == self.ActiveStylePack
		local DisplayName = Metadata.BuiltIn
			and ((Metadata.Preset or Name) .. '  [' .. tostring(Metadata.Pack or 'Built-in') .. ']')
			or Name
		local Haystack = string.lower(
			Name .. ' ' .. DisplayName .. ' ' .. tostring(Metadata.Pack or '') .. ' ' .. tostring(Metadata.Preset or '')
		)

		if Visible and (Query == '' or string.find(Haystack, Query, 1, true)) then
			Order += 1
			local Row = Widgets.TreeRow(self.ComponentList, DisplayName, 0)
			Row.Object.LayoutOrder = Order
			Row.Object.ZIndex = self.ComponentsPopup.ZIndex + 2
			Row.Label.ZIndex = Row.Object.ZIndex + 1
			Row.Icon.ZIndex = Row.Object.ZIndex + 1
			Widgets.SetTreeRowSelected(Row, self.SelectedComponent == Name, true)

			local Count = 0
			for _, Root in ipairs(self.Document:GetRoots()) do
				if Root:GetAttribute('FORGEComponentInstance') == true
					and self:_GetComponentName(Root) == Name then
					Count += 1
				end
			end

			local CountLabel = Widgets.Label(Row.Object, tostring(Count), 9, false)
			CountLabel.TextColor3 = self.SelectedComponent == Name and Theme.Color.SelectionText or Theme.Color.TextMuted
			CountLabel.TextXAlignment = Enum.TextXAlignment.Right
			CountLabel.Position = UDim2.new(1, -28, 0, 0)
			CountLabel.Size = UDim2.fromOffset(24, Theme.Metric.RowHeight)
			CountLabel.ZIndex = Row.Object.ZIndex + 1

			Row.Object.MouseButton1Click:Connect(function()
				self.SelectedComponent = Name
				self.SelectedVariant = 'Default'
				self.ComponentNameBox.Text = Metadata.BuiltIn and (Metadata.Preset or Name) or Name
				self.VariantNameBox.Text = ''
				self:_RefreshComponents()
			end)
		end
	end

	local Name = self.SelectedComponent
	if not Name then
		local Target = self.Selection:GetTarget()
		self.ComponentInfoLabel.Text = Target
			and ('Ready to register ' .. Target.Name .. ' as a reusable component')
			or 'Select one UI object to register as a component'
		self.VariantButton.Text = 'State: Default'
		return
	end

	local Metadata = self.Components:GetMetadata(Name) or {}
	self.ComponentNameBox.Text = Metadata.BuiltIn and (Metadata.Preset or Name) or Name
	local Variants = self.Components:GetVariants(Name)
	if not table.find(Variants, self.SelectedVariant) then self.SelectedVariant = 'Default' end
	self.VariantButton.Text = 'State: ' .. self.SelectedVariant

	local InstanceCount = 0
	local SourceCount = 0
	for _, Root in ipairs(self.Document:GetRoots()) do
		local Objects = {Root}
		for _, Descendant in ipairs(Root:GetDescendants()) do
			if Descendant:IsA('GuiObject') then table.insert(Objects, Descendant) end
		end
		for _, Object in ipairs(Objects) do
			if self:_GetComponentName(Object) == Name then
				if Object:GetAttribute('FORGEComponentSource') == true then SourceCount += 1 end
				if Object:GetAttribute('FORGEComponentInstance') == true then InstanceCount += 1 end
			end
		end
	end

	if Metadata.BuiltIn then
		self.ComponentInfoLabel.Text = string.format(
			'%s built-in  |  %d instance%s  |  %d state%s',
			tostring(Metadata.Pack or 'Style'),
			InstanceCount,
			InstanceCount == 1 and '' or 's',
			#Variants,
			#Variants == 1 and '' or 's'
		)
	else
		self.ComponentInfoLabel.Text = string.format(
			'%d source  |  %d instance%s  |  %d state%s',
			SourceCount,
			InstanceCount,
			InstanceCount == 1 and '' or 's',
			#Variants,
			#Variants == 1 and '' or 's'
		)
	end
end

function App:_GetBindingTarget()
	return self.Selection.Child or self.Selection.Root
end

function App:_ResetBindingPreview()
	local Preview = self.BindingPreview
	if not Preview then return end

	for Object, Properties in pairs(Preview.Originals or {}) do
		if Object and Object.Parent then
			for Property, Value in pairs(Properties) do
				pcall(function() Object[Property] = Value end)
			end
		end
	end

	table.clear(Preview.Originals)
end

function App:_CaptureBindingOriginal(Object, Property)
	if not Object or not Property then return end
	local Preview = self.BindingPreview
	Preview.Originals[Object] = Preview.Originals[Object] or {}

	if Preview.Originals[Object][Property] ~= nil then return end

	local Success, Value = pcall(function() return Object[Property] end)
	if Success then Preview.Originals[Object][Property] = Value end
end

function App:_ApplyBindingsToObject(Object)
	if not self.Bindings or not self.MockData or not Object then return 0 end
	local Count = 0
	local Data = self.MockData:Get()

	for Property in pairs(self.Bindings:GetAll(Object)) do
		self:_CaptureBindingOriginal(Object, Property)
		if self.Bindings:Apply(Object, Property, Data) then Count += 1 end
	end

	return Count
end

function App:_ApplyBindingsToTree(Root)
	if not Root then return 0 end
	local Count = self:_ApplyBindingsToObject(Root)
	for _, Descendant in ipairs(Root:GetDescendants()) do
		Count += self:_ApplyBindingsToObject(Descendant)
	end
	return Count
end

function App:_ApplyBindingPreview(All)
	self:_ResetBindingPreview()

	local Count = 0
	if All then
		for _, Root in ipairs(self.Document:GetRoots()) do
			Count += self:_ApplyBindingsToTree(Root)
		end
	else
		local Target = self:_GetBindingTarget()
		Count = self:_ApplyBindingsToObject(Target)
	end

	self:SetStatus('Binding preview applied: ' .. tostring(Count))
	self:_RefreshBindings()
end

function App:_RefreshBindings()
	if not self.BindingList then return end
	Clear(self.BindingList, {[self.BindingLayout] = true})

	local Target = self:_GetBindingTarget()
	if not Target then
		self.BindingTargetLabel.Text = 'Target: (select object)'
		self.BindingInfoLabel.Text = 'Select a root or child to author bindings.'
		return
	end

	local Root = self.Document:GetRoot(Target)
	local Path = Root and self:_GetRelativeObjectPath(Root, Target) or Target.Name
	self.BindingTargetLabel.Text = 'Target: ' .. tostring(Path)

	local All = self.Bindings and self.Bindings:GetAll(Target) or {}
	local Properties = {}
	for Property in pairs(All) do table.insert(Properties, Property) end
	table.sort(Properties)

	for Index, Property in ipairs(Properties) do
		local DataPath = All[Property]
		local Row = Widgets.TreeRow(self.BindingList, Property .. '  <-  ' .. tostring(DataPath), 0)
		Row.Object.LayoutOrder = Index
		Row.Object.ZIndex = self.BindingsPopup.ZIndex + 2
		Row.Label.ZIndex = Row.Object.ZIndex + 1
		Row.Icon.ZIndex = Row.Object.ZIndex + 1
		Widgets.SetTreeRowSelected(Row, self.SelectedBindingProperty == Property, true)
		Row.Object.MouseButton1Click:Connect(function()
			self.SelectedBindingProperty = Property
			self.BindingMode = 'Binding'
			self.BindingPropertyBox.Text = Property
			self.BindingPathBox.Text = tostring(DataPath)
			self:_RefreshBindings()
		end)
	end

	self.BindingModeButton.Text = 'Mode: ' .. self.BindingMode

	local Property = self.BindingPropertyBox.Text
	local DataPath = self.BindingPathBox.Text
	local Resolved = self.MockData and self.MockData:Resolve(DataPath) or nil
	self.BindingResolvedLabel.Text = 'Resolved: ' .. (Resolved == nil and '-' or Format(Resolved))
	self.BindingAutoButton.Text = 'Auto Preview: ' .. (self.BindingAutoPreview and 'On' or 'Off')
	self.BindingInfoLabel.Text = string.format(
		'%d binding%s on %s. Property field: %s',
		#Properties,
		#Properties == 1 and '' or 's',
		Target.Name,
		Property ~= '' and Property or '(none)'
	)
end

function App:_CycleBindingMode()
	self.BindingMode = self.BindingMode == 'Binding' and 'Static' or 'Binding'
	self:_RefreshBindings()
end

function App:_SetBinding()
	if not self.Bindings then return end
	local Target = self:_GetBindingTarget()
	local Property = self.BindingPropertyBox.Text
	if not Target or Property == '' then return end

	local Success = pcall(function() local _ = Target[Property] end)
	if not Success then
		self:SetStatus(Property .. ' is not valid on ' .. Target.ClassName)
		return
	end

	if self.BindingMode == 'Static' then
		self.Bindings:Clear(Target, Property)
	else
		local Path = self.BindingPathBox.Text
		if Path == '' then return end
		self.Bindings:Set(Target, Property, Path)
	end

	self.SelectedBindingProperty = Property
	self:_RecordHistory(self.BindingMode == 'Static' and 'Clear Binding' or 'Set Binding')
	if self.BindingAutoPreview then self:_ApplyBindingPreview(true) end
	self:_RefreshBindings()
	self:_RefreshProperties()
end

function App:_ClearBinding()
	if not self.Bindings then return end
	local Target = self:_GetBindingTarget()
	local Property = self.BindingPropertyBox.Text
	if not Target or Property == '' then return end

	if self.Bindings:Clear(Target, Property) then
		self.SelectedBindingProperty = nil
		self.BindingMode = 'Static'
		self:_RecordHistory('Clear Binding')
		self:_ResetBindingPreview()
		self:_RefreshBindings()
		self:_RefreshProperties()
	end
end

function App:_ToggleBindingAuto()
	self.BindingAutoPreview = not self.BindingAutoPreview
	if self.BindingAutoPreview then
		self:_ApplyBindingPreview(true)
	else
		self:_ResetBindingPreview()
	end
	self:_RefreshBindings()
end

function App:_FlattenMockData()
	local Rows = {}

	local function Walk(Value, Prefix)
		if typeof(Value) ~= 'table' then
			table.insert(Rows, {
				Path = Prefix,
				Value = Value
			})
			return
		end

		local Keys = {}
		for Key in pairs(Value) do table.insert(Keys, Key) end
		table.sort(Keys, function(A, B) return tostring(A) < tostring(B) end)

		for _, Key in ipairs(Keys) do
			local Path = Prefix == '' and tostring(Key) or Prefix .. '.' .. tostring(Key)
			Walk(Value[Key], Path)
		end
	end

	if self.MockData then Walk(self.MockData:Get(), '') end
	return Rows
end

function App:_RefreshMockData()
	if not self.MockDataList then return end
	Clear(self.MockDataList, {[self.MockDataLayout] = true})

	if not self.MockData then
		self.MockDataInfoLabel.Text = 'MockData module unavailable'
		return
	end

	local Query = string.lower(self.MockDataSearch.Text or '')
	local Rows = self:_FlattenMockData()
	local Order = 0

	for _, Entry in ipairs(Rows) do
		local Haystack = string.lower(Entry.Path .. ' ' .. Format(Entry.Value))
		if Query == '' or string.find(Haystack, Query, 1, true) then
			Order += 1
			local Row = Widgets.TreeRow(self.MockDataList, Entry.Path .. ' = ' .. Format(Entry.Value), 0)
			Row.Object.LayoutOrder = Order
			Row.Object.ZIndex = self.MockDataPopup.ZIndex + 2
			Row.Label.ZIndex = Row.Object.ZIndex + 1
			Row.Icon.ZIndex = Row.Object.ZIndex + 1
			Widgets.SetTreeRowSelected(Row, self.SelectedMockPath == Entry.Path, true)
			Row.Object.MouseButton1Click:Connect(function()
				self.SelectedMockPath = Entry.Path
				self.MockDataPathBox.Text = Entry.Path
				self.MockDataValueBox.Text = Format(Entry.Value)

				local Type = typeof(Entry.Value)
				self.MockDataType = Type == 'number' and 'Number'
					or Type == 'boolean' and 'Boolean'
					or Type == 'Color3' and 'Color3'
					or 'String'
				self:_RefreshMockData()
			end)
		end
	end

	self.MockDataTypeButton.Text = 'Type: ' .. self.MockDataType
	self.MockDataInfoLabel.Text = string.format(
		'%d value%s  |  selected: %s',
		#Rows,
		#Rows == 1 and '' or 's',
		self.SelectedMockPath or '(none)'
	)
end

function App:_CycleMockDataType()
	local Types = {'String', 'Number', 'Boolean', 'Color3'}
	local Index = table.find(Types, self.MockDataType) or 0
	self.MockDataType = Types[Index % #Types + 1]
	self:_RefreshMockData()
end

function App:_ParseMockValue(Text)
	if self.MockDataType == 'Number' then return tonumber(Text) end
	if self.MockDataType == 'Boolean' then
		local Lower = string.lower(Text)
		if Lower == 'true' or Lower == '1' then return true end
		if Lower == 'false' or Lower == '0' then return false end
		return nil
	end
	if self.MockDataType == 'Color3' then
		local N = SplitNumbers(Text)
		if #N >= 3 then
			return Color3.fromRGB(
				math.clamp(N[1], 0, 255),
				math.clamp(N[2], 0, 255),
				math.clamp(N[3], 0, 255)
			)
		end
		return nil
	end
	return Text
end

function App:_SetMockData()
	if not self.MockData then return end
	local Path = self.MockDataPathBox.Text
	if Path == '' then return end

	local Value = self:_ParseMockValue(self.MockDataValueBox.Text)
	if Value == nil then
		self:SetStatus('Invalid ' .. self.MockDataType .. ' mock value')
		return
	end

	self.MockData:Set(Path, Value)
	self.SelectedMockPath = Path
	self:_RecordHistory('Set Mock Data')
	if self.BindingAutoPreview then self:_ApplyBindingPreview(true) end
	self:_RefreshMockData()
	self:_RefreshBindings()
end

function App:_DeleteMockData()
	if not self.MockData then return end
	local Path = self.MockDataPathBox.Text
	if Path == '' then return end

	if self.MockData:Remove(Path) then
		self.SelectedMockPath = nil
		self:_RecordHistory('Delete Mock Data')
		if self.BindingAutoPreview then self:_ApplyBindingPreview(true) end
		self:_RefreshMockData()
		self:_RefreshBindings()
	end
end

function App:_SaveCurrentScreen()
	if not self.Screens or self.InteractiveMode then return true end
	local Owner = self.DocumentScreen or self.Screens:GetCurrent()
	if not Owner then return true end
	if not self.Screens:Has(Owner) then
		self:SetStatus('SCREEN SAVE FAILED: canvas owner no longer exists')
		return false
	end

	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()

	local Roots = self.Document:GetRoots()
	for _, Root in ipairs(Roots) do
		local Left, Top, Width, Height = self:_GetRect(Root)
		self:_SetRect(Root, Left, Top, Width, Height)
	end

	local Success, Saved, Error = pcall(function()
		return self.Screens:Save(Owner, Roots, self:_GetCurrentView())
	end)
	if not Success or not Saved then
		local Detail = not Success and Saved or Error or 'unknown screen save failure'
		warn('[FORGE Studio] Screen checkpoint failed for ' .. tostring(Owner) .. ': ' .. tostring(Detail))
		self:SetStatus('SCREEN SAVE FAILED: ' .. tostring(Owner))
		return false
	end

	local Stored = self.Screens:GetStoredRoots(Owner)
	if #Stored ~= #Roots then
		warn(string.format(
			'[FORGE Studio] Screen checkpoint validation failed for %s: expected %d roots, stored %d',
			tostring(Owner),
			#Roots,
			#Stored
		))
		self:SetStatus('SCREEN SAVE FAILED VALIDATION: ' .. tostring(Owner))
		return false
	end

	if self.Screens:GetCurrent() ~= Owner then self.Screens:SetCurrent(Owner) end
	return true
end

function App:_LoadScreen(Name, Options)
	if not self.Screens or not self.Screens:Has(Name) then return false end
	Options = Options or {}
	local PreviousScreen = self.DocumentScreen or self.Screens:GetCurrent()

	if not Options.NoSave and not self.InteractiveMode then
		if not self:_SaveCurrentScreen() then
			self:SetStatus('Screen switch cancelled because the current screen could not be saved')
			return false
		end
	end
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()

	local LoadSuccess, Loaded = pcall(function()
		return self.Screens:Load(Name)
	end)
	if not LoadSuccess or not Loaded then
		warn('[FORGE Studio] Screen load failed for ' .. tostring(Name) .. ': ' .. tostring(Loaded))
		self:SetStatus('SCREEN LOAD FAILED: ' .. tostring(Name))
		return false
	end

	local PreviousRestoring = self.Restoring
	self.Restoring = true
	self:_ClearCurrentDocument()

	for _, Root in ipairs(Loaded.Roots) do
		Root.Parent = self.AuthoringLayer or self.Device
		self.Document:AddRoot(Root, Root:GetAttribute('FORGEZone') or 'Center')
		self:_RepairSemanticTree(Root)
		self:_RegisterRoot(Root)
		if self.ComponentPresets and self.ComponentPresets.ActivateTree then
			self.ComponentPresets:ActivateTree(Root)
		end
	end

	self.Screens:SetCurrent(Name)
	self.DocumentScreen = Name
	self.SelectedScreen = Name

	local View = Loaded.View or {}
	self.DeviceIndex = math.clamp(View.DeviceIndex or self.DeviceIndex or 1, 1, #Theme.Devices)
	self.Zoom = View.Zoom or 1
	self.Pan = View.Pan or Vector2.new()
	self.CameraBounds = View.CameraBounds
	self.CameraBoundsVisible = View.CameraBoundsVisible ~= false
	self.Selection:Clear()
	self.Restoring = PreviousRestoring

	self:_FitDevice()
	self:_RefreshAll()

	if self.BindingAutoPreview or self.InteractiveMode then self:_ApplyBindingPreview(true) end
	if self.InteractiveMode then self:_BindInteractiveActions() end
	if not self.InteractiveMode and (PreviousScreen ~= Name or Options.ForceHistoryReset) and self.History then
		self.History:Reset('Screen ' .. tostring(Name), 'Document')
	end
	if not Options.NoSave and not self.InteractiveMode then self:_QueuePersistentSave('Screen Switch', 1) end
	return true
end

function App:_CreateScreen()
	if not self.Screens then return end
	if not self:_SaveCurrentScreen() then return end

	local Name = self.ScreenNameBox and self.ScreenNameBox.Text or ''
	if Name == '' then Name = 'Screen' end
	local View = self:_GetCurrentView()
	View.CameraBounds = nil
	View.CameraBoundsVisible = true
	Name = self.Screens:Create(Name, {}, View)

	self.SelectedScreen = Name
	if not self:_LoadScreen(Name, {NoSave = true, ForceHistoryReset = true}) then return end
	self:_RecordHistory('Create Screen')
	self:_RefreshScreens()
end

function App:_OpenSelectedScreen()
	if not self.SelectedScreen then return end
	self:_LoadScreen(self.SelectedScreen)
end

function App:_RemapScreenActions(OldName, NewName)
	if not self.Navigation or not self.Screens then return end

	if self.Components then
		for _, ComponentName in ipairs(self.Components:GetNames()) do
			local Definition = self.Components:Get(ComponentName)
			if Definition then
				if Definition.Source then
					self.Navigation:RemapScreenTarget(Definition.Source, OldName, NewName)
				end
				for _, Variant in pairs(Definition.Variants or {}) do
					self.Navigation:RemapScreenTarget(Variant, OldName, NewName)
				end
			end
		end
	end

	for _, Name in ipairs(self.Screens:GetNames()) do
		for _, Root in ipairs(self.Screens:GetStoredRoots(Name)) do
			self.Navigation:RemapScreenTarget(Root, OldName, NewName)
		end
	end

	for _, Root in ipairs(self.Document:GetRoots()) do
		self.Navigation:RemapScreenTarget(Root, OldName, NewName)
	end
end

function App:_RenameScreen()
	if not self.Screens or not self.SelectedScreen then return end
	local NewName = self.ScreenNameBox.Text
	if NewName == '' or NewName == self.SelectedScreen then return end

	if not self:_SaveCurrentScreen() then return end
	local OldName = self.SelectedScreen
	local RenamedOwner = self.DocumentScreen == OldName
	if self.Screens:Rename(OldName, NewName) then
		self:_RemapScreenActions(OldName, NewName)
		if RenamedOwner then
			self.DocumentScreen = NewName
			self.Screens:SetCurrent(NewName)
			if self.History then self.History:Reset('Screen ' .. tostring(NewName), 'Document') end
		end
		self.SelectedScreen = NewName
		self.ScreenNameBox.Text = NewName
		self:_RecordHistory('Rename Screen')
		self:_RefreshScreens()
		self:_RefreshFlow()
	else
		self:SetStatus('Could not rename screen to ' .. tostring(NewName))
	end
end

function App:_DuplicateScreen()
	if not self.Screens or not self.SelectedScreen then return end
	if not self:_SaveCurrentScreen() then return end

	local Requested = self.ScreenNameBox.Text
	if Requested == '' or Requested == self.SelectedScreen then
		Requested = self.SelectedScreen .. ' Copy'
	end

	local Name = self.Screens:Duplicate(self.SelectedScreen, Requested)
	if Name then
		self.SelectedScreen = Name
		self.ScreenNameBox.Text = Name
		self:_RecordHistory('Duplicate Screen')
		self:_RefreshScreens()
	end
end

function App:_DeleteScreen()
	if not self.Screens or not self.SelectedScreen then return end
	if #self.Screens:GetNames() <= 1 then
		self:SetStatus('A project must keep at least one screen')
		return
	end

	local Name = self.SelectedScreen
	local WasDocument = self.DocumentScreen == Name

	if WasDocument then
		self:_StopAnimationPreview(true)
		self:_ResetBindingPreview()
	end

	if self.Screens:Remove(Name) then
		self.SelectedScreen = self.Screens:GetCurrent()
		if WasDocument then
			self.DocumentScreen = nil
			self:_LoadScreen(self.Screens:GetCurrent(), {NoSave = true, ForceHistoryReset = true})
		end
		self:_RecordHistory('Delete Screen')
		self:_RefreshScreens()
	end
end

function App:_SetStartScreen()
	if not self.Screens or not self.SelectedScreen then return end
	if self.Screens:SetStart(self.SelectedScreen) then
		self:_RecordHistory('Set Start Screen')
		self:_RefreshScreens()
	end
end

function App:_RefreshScreens()
	if not self.ScreenList then return end
	Clear(self.ScreenList, {[self.ScreenLayout] = true})

	if not self.Screens then
		self.ScreenInfoLabel.Text = 'Screens module unavailable'
		return
	end

	local Names = self.Screens:GetNames()
	if self.SelectedScreen and not self.Screens:Has(self.SelectedScreen) then self.SelectedScreen = nil end
	if not self.SelectedScreen then self.SelectedScreen = self.Screens:GetCurrent() or Names[1] end

	local Query = string.lower(self.ScreenSearch and self.ScreenSearch.Text or '')
	local Current = self.Screens:GetCurrent()
	local Start = self.Screens:GetStart()
	local Order = 0

	for _, Name in ipairs(Names) do
		if Query == '' or string.find(string.lower(Name), Query, 1, true) then
			Order += 1
			local Marker = ''
			if Name == Current then Marker ..= ' [CURRENT]' end
			if Name == Start then Marker ..= ' [START]' end

			local Row = Widgets.TreeRow(self.ScreenList, Name .. Marker, 0)
			Row.Object.LayoutOrder = Order
			Row.Object.ZIndex = self.ScreensPopup.ZIndex + 2
			Row.Label.ZIndex = Row.Object.ZIndex + 1
			Row.Icon.ZIndex = Row.Object.ZIndex + 1
			Widgets.SetTreeRowSelected(Row, self.SelectedScreen == Name, Name == Current)

			Row.Object.MouseButton1Click:Connect(function()
				self.SelectedScreen = Name
				self.ScreenNameBox.Text = Name
				self:_RefreshScreens()
			end)
		end
	end

	local Selected = self.SelectedScreen and self.Screens:Get(self.SelectedScreen)
	if not Selected then
		self.ScreenInfoLabel.Text = 'No screen selected'
		return
	end

	self.ScreenNameBox.Text = self.SelectedScreen
	local View = Selected.View or {}
	local Device = Theme.Devices[math.clamp(View.DeviceIndex or 1, 1, #Theme.Devices)] or Theme.Devices[1]
	self.ScreenInfoLabel.Text = string.format(
		'%s%s%s\n%s  %dx%d  |  Zoom %d%%  |  %d screen%s',
		self.SelectedScreen,
		self.SelectedScreen == Current and '  [CURRENT]' or '',
		self.SelectedScreen == Start and '  [START]' or '',
		Device.Name,
		Device.Width,
		Device.Height,
		Round((View.Zoom or 1) * 100),
		#Names,
		#Names == 1 and '' or 's'
	)
end

function App:_GetSiblingKeys(Items)
	local Counts, Seen, Keys = {}, {}, {}

	for _, Item in ipairs(Items or {}) do
		Counts[Item.Name] = (Counts[Item.Name] or 0) + 1
	end

	for Index, Item in ipairs(Items or {}) do
		Seen[Item.Name] = (Seen[Item.Name] or 0) + 1
		Keys[Index] = Counts[Item.Name] > 1
			and (Item.Name .. '#' .. Seen[Item.Name])
			or Item.Name
	end

	return Keys
end

function App:_GetDocumentRootKeys()
	local Roots = self.Document:GetRoots()
	return Roots, self:_GetSiblingKeys(Roots)
end

function App:_GetDocumentObjectPath(Object)
	if not Object then return nil end
	local Root = self.Document:GetRoot(Object)
	if not Root then return nil end

	local Roots, RootKeys = self:_GetDocumentRootKeys()
	local RootIndex = table.find(Roots, Root)
	local RootKey = RootIndex and RootKeys[RootIndex] or Root.Name
	if Object == Root then return RootKey end

	local Parts = {RootKey}
	local Chain = {}
	local Current = Object

	while Current and Current ~= Root do
		local Parent = Current.Parent
		if not Parent then return nil end

		local Siblings = Parent:GetChildren()
		local Keys = self:_GetSiblingKeys(Siblings)
		local Index = table.find(Siblings, Current)
		if not Index then return nil end

		table.insert(Chain, 1, Keys[Index])
		Current = Parent
	end

	if Current ~= Root then return nil end
	for _, Part in ipairs(Chain) do table.insert(Parts, Part) end
	return table.concat(Parts, '/')
end

function App:_ResolveDocumentObjectPath(Path)
	if not Path or Path == '' then return nil end

	local Parts = {}
	for Part in tostring(Path):gmatch('[^/]+') do table.insert(Parts, Part) end
	if #Parts == 0 then return nil end

	local Roots, RootKeys = self:_GetDocumentRootKeys()
	local Current

	for Index, Candidate in ipairs(Roots) do
		if RootKeys[Index] == Parts[1] then
			Current = Candidate
			break
		end
	end
	if not Current then return nil end

	for PartIndex = 2, #Parts do
		local Children = Current:GetChildren()
		local Keys = self:_GetSiblingKeys(Children)
		local Next

		for Index, Child in ipairs(Children) do
			if Keys[Index] == Parts[PartIndex] then
				Next = Child
				break
			end
		end

		if not Next then return nil end
		Current = Next
	end

	return Current
end

function App:_CaptureFlowSource()
	local Target = self.Selection:GetTarget()
	if not Target or not Target:IsA('GuiButton') then
		self:SetStatus('Select a TextButton or ImageButton as the flow source')
		return false
	end

	self.FlowSourceObject = Target
	self.FlowDirty = false
	local Action = self.Navigation and self.Navigation:Get(Target) or nil
	self.FlowActionType = Action and Action.Type or 'None'
	self.FlowTransition = Action and Action.Transition or 'None'
	self:_RefreshFlow()
	return true
end

function App:_RefreshFlow()
	if not self.FlowObjectLabel then return end

	local Source = self.FlowSourceObject
	if Source and not Source.Parent then Source = nil end
	if Source and not self.Document:GetRoot(Source) then Source = nil end
	self.FlowSourceObject = Source

	if not Source then
		local Selected = self.Selection:GetTarget()
		if Selected and Selected:IsA('GuiButton') then
			Source = Selected
			self.FlowSourceObject = Selected
		end
	end

	if not Source then
		self.FlowObjectLabel.Text = 'Object: (select a button)'
		self.FlowActionButton.Text = 'Action: ' .. self.FlowActionType
		self.FlowTransitionButton.Text = 'Transition: ' .. self.FlowTransition
		self.FlowInfoLabel.Text = 'Select a TextButton or ImageButton, then Set Source.'
		return
	end

	local Action = self.Navigation and self.Navigation:Get(Source) or {
		Type = 'None',
		Target = '',
		Transition = 'None',
		Duration = .2
	}

	if not self.FlowDirty then
		self.FlowActionType = Action.Type
		self.FlowTransition = Action.Transition
		self.FlowTargetBox.Text = Action.Target or ''
		self.FlowDurationBox.Text = Format(Action.Duration or .2)
	end

	self.FlowObjectLabel.Text = 'Object: ' .. (self:_GetDocumentObjectPath(Source) or Source.Name)
	self.FlowActionButton.Text = 'Action: ' .. self.FlowActionType
	self.FlowTransitionButton.Text = 'Transition: ' .. self.FlowTransition

	local Requirement = self.FlowActionType == 'OpenScreen' and 'Target = screen'
		or self.FlowActionType == 'Back' and 'Target ignored'
		or (self.FlowActionType == 'Show' or self.FlowActionType == 'Hide' or self.FlowActionType == 'Toggle')
			and 'Target = Root/Child path'
		or 'No action'

	self.FlowInfoLabel.Text = string.format(
		'%s\n%s\n%s',
		Requirement,
		'Transitions apply to OpenScreen / Back.',
		'Use Interactive Preview to click through the flow.'
	)
end

function App:_CycleFlowAction()
	if not self.Navigation then return end
	local Items = self.Navigation.ActionTypes
	local Index = table.find(Items, self.FlowActionType) or 0
	self.FlowActionType = Items[Index % #Items + 1]
	self.FlowDirty = true
	self.FlowActionButton.Text = 'Action: ' .. self.FlowActionType
end

function App:_CycleFlowTransition()
	if not self.Navigation then return end
	local Items = self.Navigation.Transitions
	local Index = table.find(Items, self.FlowTransition) or 0
	self.FlowTransition = Items[Index % #Items + 1]
	self.FlowDirty = true
	self.FlowTransitionButton.Text = 'Transition: ' .. self.FlowTransition
end

function App:_UseSelectedScreenTarget()
	if not self.SelectedScreen then return end
	self.FlowTargetBox.Text = self.SelectedScreen
	self.FlowDirty = true
end

function App:_UseSelectedObjectTarget()
	local Target = self.Selection:GetTarget()
	local Path = self:_GetDocumentObjectPath(Target)
	if not Path then
		self:SetStatus('Select a target object in the current screen')
		return
	end
	self.FlowTargetBox.Text = Path
	self.FlowDirty = true
end

function App:_SetFlowAction()
	if not self.Navigation then return end
	local Source = self.FlowSourceObject
	if not Source or not Source.Parent or not Source:IsA('GuiButton') then
		if not self:_CaptureFlowSource() then return end
		Source = self.FlowSourceObject
	end

	local Action = {
		Type = self.FlowActionType,
		Target = self.FlowTargetBox.Text,
		Transition = self.FlowTransition,
		Duration = math.max(0, tonumber(self.FlowDurationBox.Text) or .2)
	}

	if Action.Type == 'OpenScreen' and (not self.Screens or not self.Screens:Has(Action.Target)) then
		self:SetStatus('OpenScreen target does not exist: ' .. tostring(Action.Target))
		return
	end

	if (Action.Type == 'Show' or Action.Type == 'Hide' or Action.Type == 'Toggle')
		and not self:_ResolveDocumentObjectPath(Action.Target) then
		self:SetStatus('Object target does not exist: ' .. tostring(Action.Target))
		return
	end

	if self.Navigation:Set(Source, Action) then
		self.FlowDirty = false
		self:_RecordHistory('Set Flow Action')
		self:_RefreshFlow()
		self:_RefreshChildren()
		self:_RefreshProperties()
	end
end

function App:_ClearFlowAction()
	local Source = self.FlowSourceObject
	if not self.Navigation or not Source then return end

	if self.Navigation:Clear(Source) then
		self.FlowActionType = 'None'
		self.FlowTransition = 'None'
		self.FlowDirty = false
		self.FlowTargetBox.Text = ''
		self:_RecordHistory('Clear Flow Action')
		self:_RefreshFlow()
		self:_RefreshChildren()
		self:_RefreshProperties()
	end
end

function App:_CancelInteractiveAnimation(Owner)
	local Session = self.InteractiveAnimationSessions and self.InteractiveAnimationSessions[Owner]
	if not Session then return false end
	Session.Cancelled = true
	self.InteractiveAnimationSessions[Owner] = nil
	return true
end

function App:_CancelAllInteractiveAnimations()
	for Owner, Session in pairs(self.InteractiveAnimationSessions or {}) do
		Session.Cancelled = true
		self.InteractiveAnimationSessions[Owner] = nil
	end
end

function App:_StopScreenTransition()
	self.TransitionGeneration += 1
	self.Transitioning = false

	for _, Tween in ipairs(self.TransitionTweens or {}) do
		pcall(function() Tween:Cancel() end)
	end
	table.clear(self.TransitionTweens)
end

function App:_ClearInteractiveConnections()
	for _, Connection in ipairs(self.InteractiveConnections) do Connection:Disconnect() end
	table.clear(self.InteractiveConnections)
	self:_CancelAllInteractiveAnimations()
	table.clear(self.InteractiveOriginals)
end

function App:_CaptureInteractiveOriginal(Owner, Target, Property, Kind)
	if not Owner or not Target then return nil end
	local Key = self:_AnimationPropertyKey(Property, Kind)
	self.InteractiveOriginals[Owner] = self.InteractiveOriginals[Owner] or {}
	self.InteractiveOriginals[Owner][Target] = self.InteractiveOriginals[Owner][Target] or {}

	local Existing = self.InteractiveOriginals[Owner][Target][Key]
	if Existing ~= nil then return Existing end

	local Success, Value = self:_GetAnimationProperty(Target, Property, Kind)
	if Success then self.InteractiveOriginals[Owner][Target][Key] = Value end
	return Success and Value or nil
end

function App:_GetInteractiveOriginal(Owner, Target, Property, Kind)
	local Key = self:_AnimationPropertyKey(Property, Kind)
	local OwnerState = self.InteractiveOriginals[Owner]
	local TargetState = OwnerState and OwnerState[Target]
	local Value = TargetState and TargetState[Key]
	if Value ~= nil then return Value end
	return self:_CaptureInteractiveOriginal(Owner, Target, Property, Kind)
end

function App:_CaptureInteractiveAnimationBaselines(Definition, Owner, Seen)
	if not Definition or not Owner then return end
	Seen = Seen or {}
	local Key = Definition.Name or tostring(Definition)
	if Seen[Key] then return end
	Seen[Key] = true

	if Definition.InheritEndFrom and self.Animations then
		self:_CaptureInteractiveAnimationBaselines(self.Animations:Get(Definition.InheritEndFrom), Owner, Seen)
	end

	for _, Track in ipairs(Definition.Tracks or {}) do
		local Target = self:_ResolveRelativeObjectPath(Owner, Track.TargetPath)
		if Target then self:_CaptureInteractiveOriginal(Owner, Target, Track.Property, Track.PropertyKind or 'Native') end
	end
end

function App:_RestoreInteractiveOwnerBaseline(Owner)
	local OwnerState = self.InteractiveOriginals[Owner]
	if not OwnerState then return end

	for Target, Properties in pairs(OwnerState) do
		if Target and Target.Parent then
			for Key, Value in pairs(Properties) do
				local Semantic = string.sub(Key, 1, 1) == '@'
				self:_SetAnimationProperty(
					Target,
					Semantic and string.sub(Key, 2) or Key,
					Semantic and 'Semantic' or 'Native',
					Value
				)
			end
		end
	end
end

function App:_ApplyInteractiveAnimationEndPose(Name, Owner, Seen)
	if not self.Animations or not Name or not Owner then return false end
	Seen = Seen or {}
	if Seen[Name] then return false end
	Seen[Name] = true

	local Definition = self.Animations:Get(Name)
	if not Definition then return false end
	if Definition.InheritEndFrom then self:_ApplyInteractiveAnimationEndPose(Definition.InheritEndFrom, Owner, Seen) end

	for _, Track in ipairs(Definition.Tracks or {}) do
		local Target = self:_ResolveRelativeObjectPath(Owner, Track.TargetPath)
		if Target then
			local Kind = Track.PropertyKind or 'Native'
			local DefaultBase = self:_GetInteractiveOriginal(Owner, Target, Track.Property, Kind)
			local Success, CurrentBase = self:_GetAnimationProperty(Target, Track.Property, Kind)
			if DefaultBase ~= nil and Success then
				local Value, OK = ResolveAnimationEndpoint(DefaultBase, CurrentBase, Track.To, Track.ToExpression)
				if OK then self:_SetAnimationProperty(Target, Track.Property, Kind, Value) end
			end
		end
	end
	return true
end

function App:_InteractiveAnimationEvent(Trigger)
	if Trigger == 'Hover' then return 'MouseEnter' end
	if Trigger == 'HoverEnd' then return 'MouseLeave' end
	if Trigger == 'Press' then return 'Press' end
	if Trigger == 'Release' then return 'Release' end
	if Trigger == 'Click' then return 'Click' end
	return nil
end

function App:_PlayInteractiveAnimation(Name, Owner, SessionKey)
	if not self.InteractiveMode or not self.Animations or not Owner or not Owner.Parent then return false end
	local Definition = self.Animations:Get(Name)
	if not Definition then return false end

	SessionKey = SessionKey or Owner
	self:_CancelInteractiveAnimation(SessionKey)
	self:_CaptureInteractiveAnimationBaselines(Definition, Owner)

	if Definition.InheritEndFrom then
		self:_RestoreInteractiveOwnerBaseline(Owner)
		self:_ApplyInteractiveAnimationEndPose(Definition.InheritEndFrom, Owner)
	end

	local Session = {
		Cancelled = false,
		Name = Name,
		Owner = Owner,
		Key = SessionKey,
		Remaining = #(Definition.Tracks or {})
	}
	self.InteractiveAnimationSessions[SessionKey] = Session
	if Session.Remaining <= 0 then
		self.InteractiveAnimationSessions[SessionKey] = nil
		return Definition.InheritEndFrom ~= nil
	end

	local Stagger = math.max(0, tonumber(Definition.Stagger) or 0)
	local function Complete()
		Session.Remaining -= 1
		if Session.Remaining <= 0 and self.InteractiveAnimationSessions[SessionKey] == Session then
			self.InteractiveAnimationSessions[SessionKey] = nil
		end
	end

	for Index, Track in ipairs(Definition.Tracks or {}) do
		task.spawn(function()
			local Target = self:_ResolveRelativeObjectPath(Owner, Track.TargetPath)
			if not Target then Complete() return end

			local Kind = Track.PropertyKind or 'Native'
			local DefaultBase = self:_GetInteractiveOriginal(Owner, Target, Track.Property, Kind)
			local Success, CurrentBase = self:_GetAnimationProperty(Target, Track.Property, Kind)
			if DefaultBase == nil or not Success then Complete() return end

			local ForwardFrom, FromOK = ResolveAnimationEndpoint(DefaultBase, CurrentBase, Track.From, Track.FromExpression)
			local ForwardTo, ToOK = ResolveAnimationEndpoint(DefaultBase, CurrentBase, Track.To, Track.ToExpression)
			if not FromOK or not ToOK then Complete() return end

			local Delay = math.max(0, tonumber(Track.Delay) or 0) + Stagger * (Index - 1)
			if Delay > 0 then task.wait(Delay) end
			if Session.Cancelled or not self.InteractiveMode or not Target.Parent then Complete() return end

			local Duration = math.max(0, tonumber(Track.Duration) or 0)
			local Style = Track.EasingStyle or Enum.EasingStyle.Quad
			local Direction = Track.EasingDirection or Enum.EasingDirection.Out

			local function SetValue(Value)
				if Session.Cancelled or not Target.Parent then return false end
				return self:_SetAnimationProperty(Target, Track.Property, Kind, Value)
			end

			local function TweenValues(From, To)
				if Duration <= 0 then
					SetValue(To)
					return
				end

				local Started = os.clock()
				while not Session.Cancelled and self.InteractiveMode and Target.Parent do
					local Alpha = math.clamp((os.clock() - Started) / Duration, 0, 1)
					local Eased = TweenService:GetValue(Alpha, Style, Direction)
					SetValue(LerpAnimationValue(From, To, Eased))
					if Alpha >= 1 then break end
					RunService.Heartbeat:Wait()
				end
			end

			repeat
				SetValue(ForwardFrom)
				TweenValues(ForwardFrom, ForwardTo)
				if Definition.Reverse and not Session.Cancelled then TweenValues(ForwardTo, ForwardFrom) end
			until Session.Cancelled or not self.InteractiveMode or not Definition.Loop

			Complete()
		end)
	end

	return true
end


function App:_ConnectInteractiveAnimation(Object, EventName, Name, Owner)
	if not Object or not Object:IsA('GuiObject') then return false end
	Object.Active = true

	local function Play()
		if self.InteractiveMode then self:_PlayInteractiveAnimation(Name, Owner, Object) end
	end

	local Connection
	if EventName == 'MouseEnter' then
		Connection = Object.MouseEnter:Connect(Play)
	elseif EventName == 'MouseLeave' then
		Connection = Object.MouseLeave:Connect(Play)
	elseif EventName == 'Press' then
		Connection = Object.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then Play() end
		end)
	elseif EventName == 'Release' then
		Connection = Object.InputEnded:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then Play() end
		end)
	elseif EventName == 'Click' then
		if Object:IsA('GuiButton') then
			Connection = Object.Activated:Connect(Play)
		else
			Connection = Object.InputEnded:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 then Play() end
			end)
		end
	end

	if Connection then
		table.insert(self.InteractiveConnections, Connection)
		return true
	end
	return false
end

function App:_BindInteractiveAnimations()
	if not self.InteractiveMode or not self.Animations then return 0 end
	local Count = 0

	for _, Root in ipairs(self.Document:GetRoots()) do
		local Objects = {Root}
		for _, Descendant in ipairs(Root:GetDescendants()) do
			if Descendant:IsA('GuiObject') then table.insert(Objects, Descendant) end
		end

		for _, Object in ipairs(Objects) do
			for _, Name in ipairs(self.Animations:GetNames()) do
				local Definition = self.Animations:Get(Name)
				local EventName = Definition and self:_InteractiveAnimationEvent(Definition.Trigger)
				if not EventName then continue end

				if Definition.PresetKind then
					local Kind = self:_GetAnimationPresetKind(Object)
					if Kind == Definition.PresetKind then
						self:_CaptureInteractiveAnimationBaselines(Definition, Object)
						if self:_ConnectInteractiveAnimation(Object, EventName, Name, Object) then Count += 1 end
					end
				else
					local OwnerPath = Definition.OwnerPath
					if not OwnerPath then continue end

					local Relative = Definition.TriggerTargetPath or 'Root'
					local TriggerPath = OwnerPath
					if Relative ~= '' and Relative ~= 'Root' then TriggerPath ..= '/' .. Relative end

					if self:_GetDocumentObjectPath(Object) == TriggerPath then
						local Owner = self:_ResolveDocumentObjectPath(OwnerPath)
						if Owner then
							self:_CaptureInteractiveAnimationBaselines(Definition, Owner)
							if self:_ConnectInteractiveAnimation(Object, EventName, Name, Owner) then Count += 1 end
						end
					end
				end
			end
		end
	end

	return Count
end

function App:_BindInteractiveActions()
	self:_ClearInteractiveConnections()
	if not self.InteractiveMode then return end

	local NavigationCount = 0
	if self.Navigation then
		for _, Root in ipairs(self.Document:GetRoots()) do
			local Objects = {Root}
			for _, Descendant in ipairs(Root:GetDescendants()) do table.insert(Objects, Descendant) end

			for _, Object in ipairs(Objects) do
				if Object:IsA('GuiButton') and self.Navigation:Has(Object) then
					Object.Active = true
					local Connection = Object.Activated:Connect(function()
						local Action = self.Navigation:Get(Object)
						task.spawn(function()
							self:_ExecuteNavigationAction(Object, Action)
						end)
					end)
					table.insert(self.InteractiveConnections, Connection)
					NavigationCount += 1
				end
			end
		end
	end

	local AnimationCount = self:_BindInteractiveAnimations()
	self:SetStatus(string.format(
		'LIVE UI Preview   %d animation trigger%s   %d action%s   Esc / P / EXIT PREVIEW',
		AnimationCount,
		AnimationCount == 1 and '' or 's',
		NavigationCount,
		NavigationCount == 1 and '' or 's'
	))
end


function App:_SetInteractiveMode(Value, StartScreen)
	Value = Value == true
	if self.InteractiveMode == Value then return end

	if Value then
		if not self.Screens then return end
		self:_StopRuntimePreview()
		self:_SaveCurrentScreen()
		self.PreviewOriginScreen = self.DocumentScreen or self.Screens:GetCurrent()
		table.clear(self.PreviewStack)
		self.InteractiveMode = true
		self.Selection:Clear()
		self.Interaction.Visible = false
		self.ZoneGuides.Visible = false
		if self.CameraBoundsGuide then self.CameraBoundsGuide.Visible = false end
		if self.SnapGuides then self.SnapGuides.Visible = false end

		for _, Popup in ipairs({
			self.InsertPopup,
			self.ComponentsPopup,
			self.AnimationPopup,
			self.BindingsPopup,
			self.MockDataPopup,
			self.ScreensPopup,
			self.FlowPopup,
			self.ProblemsPopup,
			self.PackagePopup
		}) do
			if Popup then Popup.Visible = false end
		end

		self.PreviewModeButton.Text = 'Exit'
		Widgets.SetActive(self.PreviewModeButton, true)
		self.PreviewExitButton.Visible = true

		local Target = StartScreen or self.Screens:GetStart() or self.PreviewOriginScreen
		self:_LoadScreen(Target, {NoSave = true})
		return
	end

	local Origin = self.PreviewOriginScreen

	self.InteractiveMode = false
	self.Interaction.Visible = true
	self.ZoneGuides.Visible = self.ZoneGuidesVisible
	self:_UpdateCameraBoundsGuide()
	if self.SnapGuides then self.SnapGuides.Visible = self.SnapEnabled or self:_IsShiftHeld() end
	self.PreviewModeButton.Text = 'Play UI'
	Widgets.SetActive(self.PreviewModeButton, false)
	self.PreviewExitButton.Visible = false
	table.clear(self.PreviewStack)
	table.clear(self.ShortcutKeysDown)
	self.ShiftHeld = false
	self.ControlHeld = false

	local Errors = {}
	local function Safe(Label, Callback)
		local Success, Error = pcall(Callback)
		if not Success then table.insert(Errors, Label .. ': ' .. tostring(Error)) end
	end

	Safe('transition cleanup', function() self:_StopScreenTransition() end)
	Safe('interactive connection cleanup', function() self:_ClearInteractiveConnections() end)
	Safe('animation cleanup', function() self:_StopAnimationPreview(true) end)
	Safe('binding cleanup', function() self:_ResetBindingPreview() end)

	if Origin and self.Screens and self.Screens:Has(Origin) then
		Safe('screen restore', function() self:_LoadScreen(Origin, {NoSave = true}) end)
	end

	self.PreviewOriginScreen = nil

	Safe('selection refresh', function() self:_UpdateSelectionBox() end)
	Safe('toolbar refresh', function() self:_UpdatePreviewToolbar() end)
	Safe('screen panel refresh', function() self:_RefreshScreens() end)
	Safe('flow panel refresh', function() self:_RefreshFlow() end)

	if #Errors > 0 then
		self:SetStatus('Returned to Edit mode  |  cleanup warning: ' .. Errors[1])
	else
		self:SetStatus('Returned to Edit mode')
	end
end

function App:_ExitInteractiveMode()
	if not self.InteractiveMode then return false end
	self:_SetInteractiveMode(false)
	return not self.InteractiveMode
end


function App:_TestFlowAction()
	local Source = self.FlowSourceObject
	if not Source or not Source.Parent then return end
	local Path = self:_GetDocumentObjectPath(Source)
	local Current = self.DocumentScreen or self.Screens and self.Screens:GetCurrent()

	if not self.InteractiveMode then
		self:_SetInteractiveMode(true, Current)
	end

	local PreviewSource = self:_ResolveDocumentObjectPath(Path)
	if PreviewSource then
		local Action = self.Navigation:Get(PreviewSource)
		task.spawn(function()
			self:_ExecuteNavigationAction(PreviewSource, Action)
		end)
	end
end

function App:_GetStyleTargets()
	local Children = self.Selection.GetChildren and self.Selection:GetChildren() or {}
	if #Children > 0 then return Children end
	return self.Selection:GetRoots()
end

function App:_RefreshStyle()
	if not self.StylePackButton then return end
	if not self.StylePacks then
		self.StyleInfoLabel.Text = 'Style packs unavailable'
		return
	end

	local Pack = self.StylePacks:Get(self.ActiveStylePack)
	if self.Device then self.Device.BackgroundColor3 = Theme.Color.Canvas end
	local Surfaces = self.StylePacks:GetSurfaceNames(self.ActiveStylePack)
	local Rarities = self.StylePacks:GetRarityNames(self.ActiveStylePack)

	if not table.find(Surfaces, self.SelectedSurface) then self.SelectedSurface = Surfaces[1] or 'Regular' end
	if #Rarities > 0 and not table.find(Rarities, self.SelectedRarity) then self.SelectedRarity = Rarities[1] end

	self.StylePackButton.Text = 'Pack: ' .. self.ActiveStylePack
	self.StyleSurfaceButton.Text = self.SelectedSurface
	self.StyleTypographyButton.Text = self.SelectedTypography
	self.StyleRarityButton.Text = self.SelectedRarity or '-'
	self.StyleRarityButton.TextTransparency = #Rarities > 0 and 0 or .5
	self.StyleApplyRarityButton.TextTransparency = #Rarities > 0 and 0 or .5

	for Name, Button in pairs(self.StyleSwatches or {}) do
		local Color = Pack.Color and Pack.Color[Name]
		Button.Visible = Color ~= nil
		if Color then Button.BackgroundColor3 = Color end
	end

	local Target = self.Selection:GetTarget()
	local TargetPack = Target and Target:GetAttribute('FORGEStylePack')
	local TargetSurface = Target and Target:GetAttribute('FORGEStyleSurface')
	local TargetPreset = Target and Target:GetAttribute('FORGEStylePreset')
	self.StyleInfoLabel.Text = string.format(
		'Default pack: %s\nTarget: %s%s%s',
		self.ActiveStylePack,
		Target and Target.Name or '(none)',
		TargetPack and ('  |  ' .. TargetPack) or '',
		TargetSurface and ('/' .. TargetSurface) or TargetPreset and ('  |  ' .. TargetPreset) or ''
	)
end

function App:_CycleStylePack()
	if not self.StylePacks then return end
	local Names = self.StylePacks:GetNames()
	local Index = table.find(Names, self.ActiveStylePack) or 0
	self.ActiveStylePack = Names[Index % #Names + 1]
	self.SelectedSurface = 'Regular'
	self.SelectedRarity = self.StylePacks:GetRarityNames(self.ActiveStylePack)[1] or self.SelectedRarity
	self:_InstallStylePresets()
	self:_RefreshStyle()
	self:_RefreshComponents()
	self:_RefreshInsertPalette()
	self:_RecordHistory('Set Style Pack')
end

function App:_CycleStyleSurface()
	if not self.StylePacks then return end
	local Names = self.StylePacks:GetSurfaceNames(self.ActiveStylePack)
	if #Names == 0 then return end
	local Index = table.find(Names, self.SelectedSurface) or 0
	self.SelectedSurface = Names[Index % #Names + 1]
	self:_RefreshStyle()
end

function App:_CycleStyleTypography()
	local Roles = {'Body', 'Strong', 'Header', 'Caption'}
	local Index = table.find(Roles, self.SelectedTypography) or 0
	self.SelectedTypography = Roles[Index % #Roles + 1]
	self:_RefreshStyle()
end

function App:_CycleStyleRarity()
	if not self.StylePacks then return end
	local Names = self.StylePacks:GetRarityNames(self.ActiveStylePack)
	if #Names == 0 then return end
	local Index = table.find(Names, self.SelectedRarity) or 0
	self.SelectedRarity = Names[Index % #Names + 1]
	self:_RefreshStyle()
end

function App:_ApplyStyleSurface()
	if not self.StylePacks then return end
	local Changed = false

	for _, Target in ipairs(self:_GetStyleTargets()) do
		if Target:IsA('GuiObject') then
			local Root = self.Document:GetRoot(Target)
			local Exact = Root and Root:GetAttribute('FORGEStyleExact') == true
			if Exact and self.ActiveStylePack == 'RUCKUS' then
				self:SetStatus('Exact RUCKUS presets preserve their authored surface.')
			elseif not Root or not self.Document:IsLocked(Root) then
				Changed = self.StylePacks:ApplySurface(
					Target,
					self.SelectedSurface,
					self.ActiveStylePack
				) or Changed
			end
		end
	end

	if Changed then
		self:_RecordHistory('Apply Style Surface')
		self:_RefreshAll()
	end
end

function App:_ApplyStyleTypography()
	if not self.StylePacks then return end
	local Changed = false

	for _, Target in ipairs(self:_GetStyleTargets()) do
		local Root = self.Document:GetRoot(Target)
		if not Root or not self.Document:IsLocked(Root) then
			Changed = self.StylePacks:ApplyTypography(
				Target,
				self.SelectedTypography,
				self.ActiveStylePack
			) or Changed
		end
	end

	if Changed then
		self:_RecordHistory('Apply Typography')
		self:_RefreshAll()
	end
end

function App:_ApplyStyleRarity()
	if not self.StylePacks then return end
	local Changed = false

	for _, Target in ipairs(self:_GetStyleTargets()) do
		local Root = self.Document:GetRoot(Target)
		if not Root or not self.Document:IsLocked(Root) then
			Changed = self.StylePacks:ApplyRarity(
				Target,
				self.SelectedRarity,
				self.ActiveStylePack
			) or Changed
		end
	end

	if Changed then
		self:_RecordHistory('Apply Rarity')
		self:_RefreshAll()
	end
end

function App:_GetComponentName(Root)
	return Root and Root:GetAttribute('FORGEComponentName') or nil
end

function App:_FindSlot(Root, Name)
	if not Root or not Name then return nil end
	if Root:GetAttribute('FORGESlotName') == Name then return Root end

	for _, Descendant in ipairs(Root:GetDescendants()) do
		if Descendant:GetAttribute('FORGESlotName') == Name then return Descendant end
	end

	return nil
end

function App:_ExtractSlotContent(Root)
	local Content = {}
	local Objects = {Root}
	for _, Descendant in ipairs(Root:GetDescendants()) do table.insert(Objects, Descendant) end

	for _, Object in ipairs(Objects) do
		local Slot = Object:GetAttribute('FORGESlotName')
		if Slot then
			Content[Slot] = Content[Slot] or {}
			for _, Child in ipairs(Object:GetChildren()) do
				if Child:GetAttribute('FORGESlotContent') == true then
					Child.Parent = nil
					table.insert(Content[Slot], Child)
				end
			end
		end
	end

	return Content
end

function App:_RestoreSlotContent(Root, Content)
	for Slot, Children in pairs(Content or {}) do
		local Target = self:_FindSlot(Root, Slot) or Root
		for _, Child in ipairs(Children) do Child.Parent = Target end
	end
end

function App:_ReplaceRootFromTemplate(OldRoot, Template, Name, Variant)
	if not OldRoot or not Template then return nil end

	local Left, Top, Width, Height = self:_GetRect(OldRoot)
	local Zone = self.Document:GetZone(OldRoot)
	local Margin = self.Document:GetScreenMargin(OldRoot)
	local Locked = self.Document:IsLocked(OldRoot)
	local OldName = OldRoot.Name
	local SlotContent = self:_ExtractSlotContent(OldRoot)

	local Root = Template:Clone()
	Root.Name = OldName
	Root.Parent = self.AuthoringLayer or self.Device
	Root:SetAttribute('FORGEComponentName', Name)
	Root:SetAttribute('FORGEComponentInstance', true)
	Root:SetAttribute('FORGEComponentSource', nil)
	Root:SetAttribute('FORGEComponentVariant', Variant or 'Default')
	Root:SetAttribute('FORGEComponentDetached', nil)
	Root:SetAttribute('FORGEZone', Zone)
	Root:SetAttribute('FORGEScreenMargin', Margin)
	Root:SetAttribute('FORGELocked', Locked)
	Root:SetAttribute('FORGEInitialized', true)

	self:_RestoreSlotContent(Root, SlotContent)
	self:_UnregisterRoot(OldRoot)

	if not self.Document:ReplaceRoot(OldRoot, Root) then
		Root:Destroy()
		return nil
	end

	self:_RegisterRoot(Root)
	self:_SetRect(Root, Left, Top, Width, Height)
	return Root
end

function App:_RemapSelection(Map)
	local Roots = {}

	for _, Root in ipairs(self.Selection:GetRoots()) do
		local Resolved = Map[Root] or Root
		if self.Document:IsRoot(Resolved) then table.insert(Roots, Resolved) end
	end

	local Primary = Map[self.Selection.Root] or self.Selection.Root
	if #Roots > 0 then
		self.Selection:SetRoots(Roots, Primary)
	else
		self.Selection:Clear()
	end
end

function App:_SyncComponentInstances(Name)
	if not self.Components or not Name then return end

	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()
	local Map = {}
	local Roots = table.clone(self.Document:GetRoots())
	local PreviousRestoring = self.Restoring
	self.Restoring = true

	for _, Root in ipairs(Roots) do
		if Root:GetAttribute('FORGEComponentInstance') == true
			and self:_GetComponentName(Root) == Name then
			local Variant = Root:GetAttribute('FORGEComponentVariant') or 'Default'
			local Template = self.Components:GetTemplate(Name, Variant)

			if not Template then
				Variant = 'Default'
				Template = self.Components:GetTemplate(Name, Variant)
			end

			local NewRoot = self:_ReplaceRootFromTemplate(Root, Template, Name, Variant)
			if NewRoot then Map[Root] = NewRoot end
		end
	end

	self.Restoring = PreviousRestoring
	if next(Map) then self:_RemapSelection(Map) end
end

function App:_CreateComponentFromSelection()
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()
	if not self.Components then
		self:SetStatus('Components module unavailable - update FORGE Studio')
		return
	end

	local Targets = self.Selection:GetTargets()
	if #Targets ~= 1 then
		self:SetStatus(#Targets == 0
			and 'Select one UI object before registering a component'
			or 'Register Component requires exactly one selected UI object')
		return
	end

	local Target = Targets[1]
	if not Target or not Target:IsA('GuiObject') then
		self:SetStatus('Selected object cannot be registered as a UI component')
		return
	end

	local ExistingName = self:_GetComponentName(Target)
	local ExistingMeta = ExistingName and self.Components:GetMetadata(ExistingName) or nil
	if ExistingName and self.Components:Has(ExistingName) and not (ExistingMeta and ExistingMeta.BuiltIn) then
		self.SelectedComponent = ExistingName
		self.SelectedVariant = Target:GetAttribute('FORGEComponentVariant') or 'Default'
		self:SetStatus(Target:GetAttribute('FORGEComponentSource') == true
			and ('Already registered as ' .. ExistingName .. ' - use Update Source')
			or ('Already belongs to component ' .. ExistingName))
		self:_RefreshComponents()
		return
	end

	-- Built-in style components (Panel, Button, etc.) are valid building blocks for
	-- custom game components. Registering one promotes the selected object into a
	-- brand-new custom definition instead of treating the built-in preset as the
	-- component being registered.
	local Requested = self.ComponentNameBox and self.ComponentNameBox.Text or Target.Name
	if Requested == ''
		or (ExistingMeta and ExistingMeta.BuiltIn and (
			Requested == ExistingName
			or Requested == tostring(ExistingMeta.Preset or '')
		))
	then
		Requested = Target.Name
	end

	local Name = self.Components:Create(Requested, Target)
	if not Name then
		self:SetStatus('Component registration failed')
		return
	end

	Target:SetAttribute('FORGEComponentName', Name)
	Target:SetAttribute('FORGEComponentSource', true)
	Target:SetAttribute('FORGEComponentInstance', nil)
	Target:SetAttribute('FORGEComponentVariant', 'Default')
	Target:SetAttribute('FORGEComponentDetached', nil)

	local StatePair = Target:GetAttribute('FORGEStyleStatePair')
	if StatePair and self.ComponentPresets then
		local Hover = self.ComponentPresets:Build('RUCKUS', StatePair)
		if Hover then
			self.Components:SaveVariant(Name, 'Hover', Hover)
			Hover:Destroy()
		end
	end

	self.SelectedComponent = Name
	self.SelectedVariant = 'Default'
	if self.ComponentNameBox then self.ComponentNameBox.Text = Name end
	self:SetStatus('Registered standalone component ' .. Name .. '  |  ReplicatedStorage.FORGEComponents queued')
	self:_RecordHistory('Create Component')
	self:_RefreshAll()
	self:_RefreshComponents()
end

function App:_UpdateComponentFromSelection()
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()
	if not self.Components then return end
	if self.SelectedComponent and self.Components:IsBuiltIn(self.SelectedComponent) then
		self:SetStatus('Built-in style components are read-only. Detach or create a custom component.')
		return
	end

	local Target = self.Selection:GetTarget()
	if not Target or Target:GetAttribute('FORGEComponentSource') ~= true then
		self:SetStatus('Select the registered component source before updating it')
		return
	end

	local Name = self:_GetComponentName(Target)
	if not Name or not self.Components:Has(Name) then
		self:SetStatus('Selected source is not registered in the component library')
		return
	end
	if not self.Components:Update(Name, Target) then
		self:SetStatus('Component source update failed')
		return
	end

	self:_SyncComponentInstances(Name)
	self.SelectedComponent = Name
	self.SelectedVariant = 'Default'
	self:SetStatus('Updated component source ' .. Name .. '  |  runtime library queued')
	self:_RecordHistory('Update Component')
	self:_RefreshAll()
	self:_RefreshComponents()
end

function App:_InstantiateComponent()
	if not self.Components or not self.SelectedComponent then return end

	local Variant = self.SelectedVariant or 'Default'
	local Root = self.Components:Instantiate(self.SelectedComponent, Variant)
	if not Root then return end

	Root:SetAttribute('FORGEInitialized', nil)
	self:_PlaceInsertedObject(Root, self.SelectedComponent)
	self:_RefreshComponents()
end
function App:_DetachComponent()
	local Changed = false

	for _, Target in ipairs(self.Selection:GetTargets()) do
		if Target:GetAttribute('FORGEComponentInstance') == true then
			Target:SetAttribute('FORGEComponentInstance', nil)
			Target:SetAttribute('FORGEComponentSource', nil)
			Target:SetAttribute('FORGEComponentVariant', nil)
			Target:SetAttribute('FORGEComponentDetached', true)
			Changed = true
		end
	end

	if Changed then
		self:_RecordHistory('Detach Component')
		self:_RefreshAll()
		self:_RefreshComponents()
	end
end

function App:_DeleteComponent()
	if not self.Components or not self.SelectedComponent then return end

	local Name = self.SelectedComponent
	if not self.Components:Has(Name) then return end
	if self.Components:IsBuiltIn(Name) then
		self:SetStatus('Built-in style components cannot be deleted.')
		return
	end

	for _, Root in ipairs(self.Document:GetRoots()) do
		local Objects = {Root}
		for _, Descendant in ipairs(Root:GetDescendants()) do
			if Descendant:IsA('GuiObject') then table.insert(Objects, Descendant) end
		end
		for _, Object in ipairs(Objects) do
			if self:_GetComponentName(Object) == Name then
				Object:SetAttribute('FORGEComponentSource', nil)
				Object:SetAttribute('FORGEComponentInstance', nil)
				Object:SetAttribute('FORGEComponentVariant', nil)
				Object:SetAttribute('FORGEComponentDetached', true)
				Object:SetAttribute('FORGEComponentName', nil)
			end
		end
	end

	self.Components:Remove(Name)
	self.SelectedComponent = nil
	self.SelectedVariant = 'Default'
	self:_RecordHistory('Delete Component')
	self:_RefreshAll()
	self:_RefreshComponents()
end

function App:_GetVariantInput()
	if not self.VariantNameBox then return nil end
	local Name = self.VariantNameBox.Text
	return Name ~= '' and Name or nil
end

function App:_SaveVariant()
	if self.Components and self.SelectedComponent and self.Components:IsBuiltIn(self.SelectedComponent) then
		self:SetStatus('Built-in component states are read-only.')
		return
	end
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()
	if not self.Components or not self.SelectedComponent then return end

	local Root = self.Selection.Root
	local Variant = self:_GetVariantInput()
	if not Root or not Variant then return end
	if self:_GetComponentName(Root) ~= self.SelectedComponent then return end

	if self.Components:SaveVariant(self.SelectedComponent, Variant, Root) then
		self.SelectedVariant = Variant
		self:_RecordHistory('Save Variant')
		self:_RefreshComponents()
	end
end

function App:_RenameVariant()
	if self.Components and self.SelectedComponent and self.Components:IsBuiltIn(self.SelectedComponent) then
		self:SetStatus('Built-in component states are read-only.')
		return
	end
	if not self.Components or not self.SelectedComponent then return end

	local Current = self.SelectedVariant
	local NewName = self:_GetVariantInput()
	if not Current or Current == 'Default' or not NewName then return end

	if self.Components:RenameVariant(self.SelectedComponent, Current, NewName) then
		for _, Root in ipairs(self.Document:GetRoots()) do
			if self:_GetComponentName(Root) == self.SelectedComponent
				and Root:GetAttribute('FORGEComponentVariant') == Current then
				Root:SetAttribute('FORGEComponentVariant', NewName)
			end
		end

		self.SelectedVariant = NewName
		self:_RecordHistory('Rename Variant')
		self:_RefreshAll()
		self:_RefreshComponents()
	end
end

function App:_DeleteVariant()
	if self.Components and self.SelectedComponent and self.Components:IsBuiltIn(self.SelectedComponent) then
		self:SetStatus('Built-in component states are read-only.')
		return
	end
	if not self.Components or not self.SelectedComponent then return end
	local Variant = self.SelectedVariant
	if not Variant or Variant == 'Default' then return end

	for _, Root in ipairs(self.Document:GetRoots()) do
		if self:_GetComponentName(Root) == self.SelectedComponent
			and Root:GetAttribute('FORGEComponentVariant') == Variant then
			Root:SetAttribute('FORGEComponentVariant', 'Default')
		end
	end

	if self.Components:RemoveVariant(self.SelectedComponent, Variant) then
		self.SelectedVariant = 'Default'
		self:_SyncComponentInstances(self.SelectedComponent)
		self:_RecordHistory('Delete Variant')
		self:_RefreshAll()
		self:_RefreshComponents()
	end
end

function App:_ApplyVariant()
	if not self.Components or not self.SelectedComponent then return end

	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()

	local Variant = self.SelectedVariant or 'Default'
	local Template = self.Components:GetTemplate(self.SelectedComponent, Variant)
	if not Template then return end

	local Map = {}
	local PreviousRestoring = self.Restoring
	self.Restoring = true

	for _, Root in ipairs(self.Selection:GetRoots()) do
		if Root:GetAttribute('FORGEComponentInstance') == true
			and self:_GetComponentName(Root) == self.SelectedComponent then
			local NewRoot = self:_ReplaceRootFromTemplate(
				Root,
				Template,
				self.SelectedComponent,
				Variant
			)
			if NewRoot then Map[Root] = NewRoot end
		end
	end

	self.Restoring = PreviousRestoring

	if next(Map) then
		self:_RemapSelection(Map)
		self:_RecordHistory('Apply Variant')
		self:_RefreshAll()
	end
end

function App:_MarkSlot()
	local Target = self.Selection.Child
	if not Target then return end

	local Name = self.SlotNameBox and self.SlotNameBox.Text or ''
	if Name == '' then Name = Target.Name end

	Target:SetAttribute('FORGESlotName', Name)
	self:_RecordHistory('Mark Slot')
	self:_RefreshChildren()
	self:_RefreshProperties()
	self:_RefreshComponents()
end

function App:_ClearSlot()
	local Target = self.Selection.Child
	if not Target or Target:GetAttribute('FORGESlotName') == nil then return end

	Target:SetAttribute('FORGESlotName', nil)
	self:_RecordHistory('Clear Slot')
	self:_RefreshChildren()
	self:_RefreshProperties()
	self:_RefreshComponents()
end

function App:_CreateRoot(ClassName)
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()
	local Root = Instance.new(ClassName)
	Root.Name = ClassName == 'TextLabel' and 'TextRoot' or 'FrameRoot'
	Root.Size = UDim2.fromOffset(
		ClassName == 'TextLabel' and 300 or 360,
		ClassName == 'TextLabel' and 60 or 180
	)
	Root.BackgroundColor3 = Theme.Color.FaceLight
	Root.BorderColor3 = Theme.Color.FaceDark
	Root.BorderSizePixel = 1

	if Root:IsA('TextLabel') then
		Root.Font = Theme.FontBold
		Root.Text = 'TEXT'
		Root.TextColor3 = Theme.Color.Text
		Root.TextSize = 18
	end

	self:_AddRoot(Root, 'Center')
	self:_RecordHistory('Insert ' .. ClassName)
end

function App:_CreateChild()
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()
	local Root = self.Selection.Root
	if not Root or self.Document:IsLocked(Root) then return end

	local Parent = self.Selection.Child
	if not Parent or not Parent:IsA('GuiObject') then Parent = Root end

	local Child = Instance.new('Frame')
	Child.Name = 'Frame'
	Child.BackgroundColor3 = Theme.Color.Face
	Child.BorderColor3 = Theme.Color.FaceDark
	Child.BorderSizePixel = 1
	Child.Position = UDim2.fromOffset(10, 10)
	Child.Size = UDim2.fromOffset(120, 60)
	Child.Parent = Parent
	self.Selection:SelectChild(Child)
	self:_RecordHistory('Insert Child')
end

function App:_NormalizeLegacyRootGeometry(Root)
	if not Root or not Root:IsA('GuiObject') then return end

	local DeviceSize = self:_GetDeviceSize()
	local Width = Root.Size.X.Scale * DeviceSize.X + Root.Size.X.Offset
	local Height = Root.Size.Y.Scale * DeviceSize.Y + Root.Size.Y.Offset
	local AnchorX = Root.Position.X.Scale * DeviceSize.X + Root.Position.X.Offset
	local AnchorY = Root.Position.Y.Scale * DeviceSize.Y + Root.Position.Y.Offset
	local Left = AnchorX - Root.AnchorPoint.X * Width
	local Top = AnchorY - Root.AnchorPoint.Y * Height
	local Zone = self:_InferRootZone(Left, Top, Width, Height, DeviceSize)
	local Anchor = Theme.ZoneAnchor[Zone] or Root.AnchorPoint

	Root:SetAttribute('FORGEZone', Zone)
	Root.AnchorPoint = Anchor
	Root.Size = UDim2.fromOffset(Round(Width), Round(Height))
	Root.Position = UDim2.new(
		Anchor.X,
		Round(Left + Anchor.X * Width - Anchor.X * DeviceSize.X),
		Anchor.Y,
		Round(Top + Anchor.Y * Height - Anchor.Y * DeviceSize.Y)
	)

	Root:SetAttribute('FORGEResponsive', nil)
	Root:SetAttribute('FORGEResponsiveTree', nil)
	Root:SetAttribute('FORGEResponsiveInternals', nil)
	Root:SetAttribute('FORGEPositionModeX', nil)
	Root:SetAttribute('FORGEPositionModeY', nil)
	Root:SetAttribute('FORGESizeModeX', nil)
	Root:SetAttribute('FORGESizeModeY', nil)
end

function App:_AddRoot(Root, Zone)
	Root.Parent = self.AuthoringLayer or self.Device
	self.Document:AddRoot(Root, Zone)

	if Root:GetAttribute('FORGEInitialized') ~= true then
		local Anchor = Theme.ZoneAnchor[Zone] or Theme.ZoneAnchor.Center
		Root.AnchorPoint = Anchor
		Root.Position = UDim2.new(Anchor.X, 0, Anchor.Y, 0)
		Root:SetAttribute('FORGEInitialized', true)
	end

	self:_RegisterRoot(Root)
	self.Selection:SelectRoot(Root)
end

function App:_RegisterRoot(Root)
	self:_NormalizeLegacyRootGeometry(Root)

	local Bin = {}
	self.RootConnections[Root] = Bin
	local HierarchyRefreshQueued = false

	local function QueueHierarchyRefresh()
		if HierarchyRefreshQueued then return end
		HierarchyRefreshQueued = true
		task.defer(function()
			HierarchyRefreshQueued = false
			if self.Destroyed or self.Restoring or not Root.Parent then return end
			if self.Selection.Root == Root then self:_RefreshChildren() end
		end)
	end

	table.insert(Bin, Root.DescendantAdded:Connect(function(Descendant)
		if self.Restoring or self.RefreshSuspended then return end

		if Descendant:IsA('UIStroke') then
			task.defer(function()
				if not self.Destroyed and Descendant.Parent then self:_ApplyStrokeLOD() end
			end)
		end

		local Internal = Descendant:GetAttribute('FORGEStyleInternal') == true
			or Descendant:GetAttribute('FORGEHierarchyInternal') == true
			or Descendant:GetAttribute('FORGEModifierGenerated') == true
			or Descendant:GetAttribute('FORGEModifierInternal') == true

		if not Internal then
			Root:SetAttribute('FORGEManagedLayoutTree', nil)
			Root:SetAttribute('FORGEManagedModifiers', nil)
			QueueHierarchyRefresh()
		end
	end))

	table.insert(Bin, Root.DescendantRemoving:Connect(function(Descendant)
		if self.Restoring or self.RefreshSuspended then return end

		local Internal = Descendant:GetAttribute('FORGEStyleInternal') == true
			or Descendant:GetAttribute('FORGEHierarchyInternal') == true
			or Descendant:GetAttribute('FORGEModifierGenerated') == true
			or Descendant:GetAttribute('FORGEModifierInternal') == true

		if not Internal then
			Root:SetAttribute('FORGEManagedLayoutTree', nil)
			Root:SetAttribute('FORGEManagedModifiers', nil)
			QueueHierarchyRefresh()
		end
	end))

	self:_ApplyStrokeLOD()
end

function App:_UnregisterRoot(Root)
	local Bin = self.RootConnections[Root]
	if not Bin then return end
	for _, Connection in ipairs(Bin) do Connection:Disconnect() end
	self.RootConnections[Root] = nil
end

function App:_NormalizeDuplicatedComponentRoot(Root)
	if not Root then return end

	if Root:GetAttribute('FORGEComponentSource') == true then
		Root:SetAttribute('FORGEComponentSource', nil)
		Root:SetAttribute('FORGEComponentInstance', true)
		Root:SetAttribute('FORGEComponentVariant', 'Default')
		Root:SetAttribute('FORGEComponentDetached', nil)
	end
end

function App:_ClearClipboard()
	if not self.Clipboard then return end
	if self.Clipboard.Object then self.Clipboard.Object:Destroy() end
	for _, Entry in ipairs(self.Clipboard.Children or {}) do
		if Entry.Object then Entry.Object:Destroy() end
	end
	for _, Entry in ipairs(self.Clipboard.Roots or {}) do
		if Entry.Root then Entry.Root:Destroy() end
	end
	self.Clipboard = nil
end

local function IsLayoutManagedChild(Object)
	local Parent = Object and Object.Parent
	if not Parent or not Parent:IsA('GuiObject') then return false end

	local Kind = Parent:GetAttribute('FORGELayoutKind')
	if Kind == 'Row' or Kind == 'Stack' then return true end
	if Parent:GetAttribute('FORGEInsertionTarget') ~= true then return false end

	local Current = Parent.Parent
	while Current and Current:IsA('GuiObject') do
		local Simple = Current:GetAttribute('FORGESimpleKind')
		if Simple then return Simple == 'Scroller' end
		Current = Current.Parent
	end
	return false
end

function App:_Copy()
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()
	local Target = self.Selection:GetTarget()
	if not Target then return end
	self:_ClearClipboard()

	if self.Selection.Child then
		local Root = self.Selection.Root
		local Entries = {}

		for _, Original in ipairs(self:_GetTopLevelSelectedChildren()) do
			local Clone = Original:Clone()
			Clone.Parent = nil
			table.insert(Entries, {
				Object = Clone,
				ParentPath = self:_CaptureChildPath(Root, Original.Parent)
			})
		end

		if #Entries > 0 then
			self.Clipboard = {
				Mode = 'Children',
				Children = Entries
			}
			self:SetStatus('Copied ' .. tostring(#Entries) .. ' child' .. (#Entries == 1 and '' or 'ren'))
		end
		return
	end

	local Entries = {}
	for _, Root in ipairs(self.Selection:GetRoots()) do
		local Clone = Root:Clone()
		Clone.Parent = nil
		local Left, Top, Width, Height = self:_GetRect(Root)
		table.insert(Entries, {
			Root = Clone,
			Zone = self.Document:GetZone(Root),
			Rect = {Left, Top, Width, Height}
		})
	end

	if #Entries > 0 then
		self.Clipboard = {
			Mode = 'Roots',
			Roots = Entries
		}
		self:SetStatus('Copied ' .. tostring(#Entries) .. ' root' .. (#Entries == 1 and '' or 's'))
	end
end

function App:_Paste()
	if not self.Clipboard then return end

	if self.Clipboard.Mode == 'Children' then
		local Root = self.Selection.Root
		if not Root or self.Document:IsLocked(Root) then return end

		local Added = {}
		for _, Entry in ipairs(self.Clipboard.Children or {}) do
			local Parent = self:_ResolveChildPath(Root, Entry.ParentPath) or Root
			local Owner = Parent
			if Owner:GetAttribute('FORGEHierarchyInternal') == true and Owner.Parent then Owner = Owner.Parent end

			local Clone = Entry.Object:Clone()
			Clone:SetAttribute('FORGEScrollerItemHeight', nil)
			Clone.Parent = Parent
			if self.ComponentPresets then self.ComponentPresets:AdoptChild(Owner, Clone) end

			if Clone:IsA('GuiObject') and not IsLayoutManagedChild(Clone) then
				local Position = Clone.Position
				Clone.Position = UDim2.new(
					Position.X.Scale,
					Position.X.Offset + Theme.Metric.DuplicateOffset,
					Position.Y.Scale,
					Position.Y.Offset + Theme.Metric.DuplicateOffset
				)
			end
			table.insert(Added, Clone)
		end

		if #Added > 0 then
			self.Selection:SetChildren(Added, Added[#Added])
			if self.ComponentPresets and self.ComponentPresets.ResolveLayouts then self:_ResolveLayoutsForRoot(Root) end
			self:_RecordHistory('Paste Children')
			self:_RefreshAll()
		end
		return
	end

	if self.Clipboard.Mode == 'Roots' then
		local Added = {}

		for _, Entry in ipairs(self.Clipboard.Roots or {}) do
			local Root = Entry.Root:Clone()
			self:_NormalizeDuplicatedComponentRoot(Root)
			Root:SetAttribute('FORGESnapTarget', nil)
			Root.Parent = self.AuthoringLayer or self.Device
			self.Document:AddRoot(Root, Entry.Zone)
			self:_RegisterRoot(Root)

			local Rect = Entry.Rect
			self:_SetRect(
				Root,
				Rect[1] + Theme.Metric.DuplicateOffset,
				Rect[2] + Theme.Metric.DuplicateOffset,
				Rect[3],
				Rect[4]
			)

			table.insert(Added, Root)
		end

		if #Added > 0 then
			self.Selection:SetRoots(Added, Added[#Added])
			self:_RecordHistory('Paste Roots')
		end
	end
end

function App:_Cut()
	if not self.Selection:GetTarget() then return end
	self:_Copy()
	self:_DeleteSelected('Cut')
end

function App:_RefreshAfterDuplicate(RootsChanged)
	if RootsChanged then self:_RefreshRoots() end
	self:_RefreshChildren()
	self:_RefreshProperties()
	self:_RefreshColor()
	self:_UpdateSelectionBox()
	self:_UpdatePreviewToolbar()
	self:_UpdateHistoryButtons()
	self:_UpdateStatus()
end

function App:_RefreshSelectionDetails(ResolveRoot)
	local Root = self.Selection.Root
	if ResolveRoot and Root then
		if self.ComponentPresets and self.ComponentPresets.ResolveLayouts then self:_ResolveLayoutsForRoot(Root) end
		if self.Modifiers and self.Modifiers.ApplyTree then self.Modifiers:ApplyTree(Root) end
	end

	self:_RefreshProperties()
	self:_RefreshColor()
	self:_UpdateSelectionBox()
	self:_UpdatePreviewToolbar()
	self:_UpdateHistoryButtons()
	self:_UpdateStatus()
end

function App:_Duplicate()
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()

	if self.Selection.Child then
		local Root = self.Selection.Root
		if not Root or self.Document:IsLocked(Root) then return end

		local Added = self:_WithRefreshSuspended(function()
			local Result = {}
			for _, Original in ipairs(self:_GetTopLevelSelectedChildren()) do
				local Clone = Original:Clone()
				Clone:SetAttribute('FORGEScrollerItemHeight', nil)
				Clone.Parent = Original.Parent
				if self.ComponentPresets then
					self.ComponentPresets:AdoptChild(Original.Parent, Clone)
					if self.ComponentPresets.ActivateTree then self.ComponentPresets:ActivateTree(Clone) end
				end

				if Clone:IsA('GuiObject') and not IsLayoutManagedChild(Clone) then
					local Position = Clone.Position
					Clone.Position = UDim2.new(
						Position.X.Scale,
						Position.X.Offset + Theme.Metric.DuplicateOffset,
						Position.Y.Scale,
						Position.Y.Offset + Theme.Metric.DuplicateOffset
					)
				end
				table.insert(Result, Clone)
			end

			if #Result > 0 then self.Selection:SetChildren(Result, Result[#Result]) end
			return Result
		end)

		if #Added > 0 then
			if self.ComponentPresets and self.ComponentPresets.ResolveLayouts then self:_ResolveLayoutsForRoot(Root) end
			self:_RecordHistory('Duplicate Children')
			self:_RefreshAfterDuplicate(false)
		end
		return
	end

	local Added = self:_WithRefreshSuspended(function()
		local Result = {}
		for _, Original in ipairs(self.Selection:GetRoots()) do
			local Clone = Original:Clone()
			self:_NormalizeDuplicatedComponentRoot(Clone)
			Clone:SetAttribute('FORGESnapTarget', nil)
			Clone.Parent = self.AuthoringLayer or self.Device
			self.Document:AddRoot(Clone, self.Document:GetZone(Original))
			self:_RegisterRoot(Clone)
			if self.ComponentPresets and self.ComponentPresets.ActivateTree then
				self.ComponentPresets:ActivateTree(Clone)
			end

			local Left, Top, Width, Height = self:_GetRect(Original)
			self:_SetRect(
				Clone,
				Left + Theme.Metric.DuplicateOffset,
				Top + Theme.Metric.DuplicateOffset,
				Width,
				Height
			)
			table.insert(Result, Clone)
		end

		if #Result > 0 then self.Selection:SetRoots(Result, Result[#Result]) end
		return Result
	end)

	if #Added > 0 then
		if self.ComponentPresets and self.ComponentPresets.ResolveLayouts then
			for _, Root in ipairs(Added) do self:_ResolveLayoutsForRoot(Root) end
		end
		self:_RecordHistory('Duplicate Roots')
		self:_RefreshAfterDuplicate(true)
	end
end

function App:_DeleteSelected(Label)
	local Root = self.Selection.Root
	if not Root then return end

	if self.Selection.Child then
		if self.Document:IsLocked(Root) then return end
		local Children = self:_GetTopLevelSelectedChildren()
		self.Selection:SelectRoot(Root)
		for _, Child in ipairs(Children) do
			if Child.Parent then Child:Destroy() end
		end
		if self.ComponentPresets and self.ComponentPresets.ResolveLayouts then self:_ResolveLayoutsForRoot(Root) end
		if #Children > 0 then self:_RecordHistory(Label or 'Delete Children') end
		self:_RefreshAll()
		return
	end

	local Removed = false
	local Roots = self.Selection:GetRoots()
	self.Selection:Clear()

	for _, Selected in ipairs(Roots) do
		if not self.Document:IsLocked(Selected) then
			self:_UnregisterRoot(Selected)
			self.Document:RemoveRoot(Selected)
			Removed = true
		end
	end

	if Removed then self:_RecordHistory(Label or 'Delete Roots') end
end

local function ResolveAxis(Value, Parent)
	return Value.Scale * Parent + Value.Offset
end

function App:_InferRootZone(Left, Top, Width, Height, CanvasSize)
	CanvasSize = CanvasSize or self:_GetResponsiveLogicalSize()
	local CanvasWidth = math.max(CanvasSize.X, 1)
	local CanvasHeight = math.max(CanvasSize.Y, 1)
	local CenterX = Left + Width / 2
	local CenterY = Top + Height / 2

	local Column = CenterX < CanvasWidth / 3 and 1
		or CenterX > CanvasWidth * 2 / 3 and 3
		or 2
	local Row = CenterY < CanvasHeight / 3 and 1
		or CenterY > CanvasHeight * 2 / 3 and 3
		or 2

	local Zones = {
		{'TopLeft', 'TopCenter', 'TopRight'},
		{'CenterLeft', 'Center', 'CenterRight'},
		{'BottomLeft', 'BottomCenter', 'BottomRight'}
	}
	return Zones[Row][Column]
end

function App:_GetResponsiveScale()
	return math.max(tonumber(self.ResponsiveScale) or 1, .001)
end

function App:_GetResponsiveLogicalSize()
	if typeof(self.ResponsiveLogicalSize) == 'Vector2' then return self.ResponsiveLogicalSize end
	local DeviceSize = self:_GetDeviceSize()
	local Scale = self:_GetResponsiveScale()
	return Vector2.new(DeviceSize.X / Scale, DeviceSize.Y / Scale)
end

function App:_GetLogicalSize(Object)
	if not Object or Object == self.Device or Object == self.AuthoringLayer then
		return self:_GetResponsiveLogicalSize()
	end

	local Parent = Object.Parent
	local ParentSize = self:_GetLogicalSize(Parent)
	if not Object:IsA('GuiObject') then return ParentSize end

	return Vector2.new(
		ResolveAxis(Object.Size.X, ParentSize.X),
		ResolveAxis(Object.Size.Y, ParentSize.Y)
	)
end

function App:_SetRootZone(Root, Zone)
	if not Root or not Theme.ZoneAnchor[Zone] then return end
	local Left, Top, Width, Height = self:_GetRect(Root)
	Root:SetAttribute('FORGESnapTarget', nil)
	self:_SetRect(Root, Left, Top, Width, Height, Zone)
end

function App:_SetSelectedZone(Zone)
	local Changed = false

	for _, Root in ipairs(self.Selection:GetRoots()) do
		if not self.Document:IsLocked(Root) then
			self:_SetRootZone(Root, Zone)
			Changed = true
		end
	end

	if Changed then
		self:_RecordHistory('Set Zone')
		self:_RefreshAll()
	end
end

local function AutoAxisEnabled(Object, Axis, Presets)
	if Presets and Presets.IsAutoAxis then return Presets:IsAutoAxis(Object, Axis) end
	local Attribute = Object:GetAttribute(Axis == 'X' and 'FORGEAutoWidth' or 'FORGEAutoHeight')
	if Attribute ~= nil then return Attribute == true end
	local Value = Object.AutomaticSize
	if Axis == 'X' then return Value == Enum.AutomaticSize.X or Value == Enum.AutomaticSize.XY end
	return Value == Enum.AutomaticSize.Y or Value == Enum.AutomaticSize.XY
end

local function SetAutoAxis(Object, Axis, Enabled, Presets)
	if Presets and Presets.SetAutoAxis then return Presets:SetAutoAxis(Object, Axis, Enabled) end
	Object:SetAttribute(Axis == 'X' and 'FORGEAutoWidth' or 'FORGEAutoHeight', Enabled == true)
	Object.AutomaticSize = Enum.AutomaticSize.None
	return true
end

function App:_GetAxisEditorState(Object, Key)
	local IsX = Key == 'PositionX' or Key == 'Width'
	local IsSize = Key == 'Width' or Key == 'Height'
	local Axis = IsX and 'X' or 'Y'
	local ParentSize = self:_GetLogicalSize(Object.Parent)
	local ParentAxis = math.max(IsX and ParentSize.X or ParentSize.Y, 1)
	local UDimValue = IsSize and Object.Size[Axis] or Object.Position[Axis]

	if IsSize and AutoAxisEnabled(Object, Axis, self.ComponentPresets) then return '', 'Auto' end
	local Compensation = IsSize and tonumber(Object:GetAttribute(Axis == 'X' and 'FORGELayoutCompX' or 'FORGELayoutCompY')) or nil
	if math.abs(UDimValue.Scale) > .00001 and (UDimValue.Offset == 0 or Compensation ~= nil) then
		return Format(UDimValue.Scale * 100), '%'
	end
	return Format(UDimValue.Scale * ParentAxis + UDimValue.Offset), 'px'
end

function App:_SetAxisEditorState(Object, Key, Value, Mode)
	if not Object or not Object:IsA('GuiObject') then return false end
	local IsX = Key == 'PositionX' or Key == 'Width'
	local IsSize = Key == 'Width' or Key == 'Height'
	local Axis = IsX and 'X' or 'Y'
	local Numeric = tonumber(Value) or 0

	if IsSize then
		SetAutoAxis(Object, Axis, Mode == 'Auto', self.ComponentPresets)
		Object:SetAttribute(Axis == 'X' and 'FORGELayoutCompX' or 'FORGELayoutCompY', nil)
		Object:SetAttribute(Axis == 'X' and 'FORGESizeModeX' or 'FORGESizeModeY', Mode)
	else
		Object:SetAttribute(Axis == 'X' and 'FORGEPositionModeX' or 'FORGEPositionModeY', Mode)
	end
	if Mode == 'Auto' then return true end

	local U = Mode == '%' and UDim.new(Numeric / 100, 0) or UDim.new(0, Numeric)
	if Key == 'PositionX' then Object.Position = UDim2.new(U.Scale, U.Offset, Object.Position.Y.Scale, Object.Position.Y.Offset)
	elseif Key == 'PositionY' then Object.Position = UDim2.new(Object.Position.X.Scale, Object.Position.X.Offset, U.Scale, U.Offset)
	elseif Key == 'Width' then Object.Size = UDim2.new(U.Scale, U.Offset, Object.Size.Y.Scale, Object.Size.Y.Offset)
	elseif Key == 'Height' then Object.Size = UDim2.new(Object.Size.X.Scale, Object.Size.X.Offset, U.Scale, U.Offset)
	else return false end
	return true
end

function App:_GetObjectCanvasRect(Object)
	if not Object or not Object:IsA('GuiObject') then return nil end

	local Scale = math.max(self.PreviewScale, .01)
	local Origin = self.Device.AbsolutePosition
	local Position = Object.AbsolutePosition
	local Size = Object.AbsoluteSize

	return
		(Position.X - Origin.X) / Scale,
		(Position.Y - Origin.Y) / Scale,
		Size.X / Scale,
		Size.Y / Scale
end

function App:_SetObjectCanvasPosition(Object, Left, Top)
	if self.Document:IsRoot(Object) then
		local _, _, Width, Height = self:_GetRect(Object)
		self:_SetRect(Object, Left, Top, Width, Height)
		return
	end

	local Parent = Object.Parent
	if not Parent or not Parent:IsA('GuiObject') then return end
	local ParentLeft, ParentTop, ParentWidth, ParentHeight = self:_GetObjectCanvasRect(Parent)
	local _, _, Width, Height = self:_GetObjectCanvasRect(Object)
	local LocalLeft, LocalTop = Left - ParentLeft, Top - ParentTop
	local AnchorX = LocalLeft + Object.AnchorPoint.X * Width
	local AnchorY = LocalTop + Object.AnchorPoint.Y * Height
	local ModeX = Object:GetAttribute('FORGEPositionModeX') or '%'
	local ModeY = Object:GetAttribute('FORGEPositionModeY') or '%'
	local ResponsiveScale = self:_GetResponsiveScale()

	Object.Position = UDim2.new(
		ModeX == '%' and AnchorX / math.max(ParentWidth, 1) or 0,
		ModeX == '%' and 0 or AnchorX / ResponsiveScale,
		ModeY == '%' and AnchorY / math.max(ParentHeight, 1) or 0,
		ModeY == '%' and 0 or AnchorY / ResponsiveScale
	)
	Object:SetAttribute('FORGEPositionModeX', ModeX)
	Object:SetAttribute('FORGEPositionModeY', ModeY)
end

function App:_SetObjectCanvasRect(Object, Left, Top, Width, Height)
	if self.Document:IsRoot(Object) then
		self:_SetRect(Object, Left, Top, Width, Height)
		return
	end

	Width = math.max(Theme.Metric.MinObjectSize, Width)
	Height = math.max(Theme.Metric.MinObjectSize, Height)
	local Parent = Object.Parent
	if not Parent or not Parent:IsA('GuiObject') then return end

	local ResponsiveScale = self:_GetResponsiveScale()
	if self.ComponentPresets
		and self.ComponentPresets.SetScrollerItemHeight
		and self.ComponentPresets:SetScrollerItemHeight(Object, Height / ResponsiveScale)
	then
		return
	end
	local ParentLeft, ParentTop, ParentWidth, ParentHeight = self:_GetObjectCanvasRect(Parent)
	local LocalLeft, LocalTop = Left - ParentLeft, Top - ParentTop
	local AnchorX = LocalLeft + Object.AnchorPoint.X * Width
	local AnchorY = LocalTop + Object.AnchorPoint.Y * Height
	local PositionModeX = Object:GetAttribute('FORGEPositionModeX') or '%'
	local PositionModeY = Object:GetAttribute('FORGEPositionModeY') or '%'
	local SizeModeX = Object:GetAttribute('FORGESizeModeX') or '%'
	local SizeModeY = Object:GetAttribute('FORGESizeModeY') or '%'

	Object.Size = UDim2.new(
		SizeModeX == '%' and Width / math.max(ParentWidth, 1) or 0,
		SizeModeX == '%' and 0 or Width / ResponsiveScale,
		SizeModeY == '%' and Height / math.max(ParentHeight, 1) or 0,
		SizeModeY == '%' and 0 or Height / ResponsiveScale
	)
	Object.Position = UDim2.new(
		PositionModeX == '%' and AnchorX / math.max(ParentWidth, 1) or 0,
		PositionModeX == '%' and 0 or AnchorX / ResponsiveScale,
		PositionModeY == '%' and AnchorY / math.max(ParentHeight, 1) or 0,
		PositionModeY == '%' and 0 or AnchorY / ResponsiveScale
	)
	Object:SetAttribute('FORGEPositionModeX', PositionModeX)
	Object:SetAttribute('FORGEPositionModeY', PositionModeY)
	Object:SetAttribute('FORGESizeModeX', SizeModeX)
	Object:SetAttribute('FORGESizeModeY', SizeModeY)
end

function App:_GetRect(Root)
	local LogicalSize = self:_GetResponsiveLogicalSize()
	local ResponsiveScale = self:_GetResponsiveScale()
	local Width = ResolveAxis(Root.Size.X, LogicalSize.X) * ResponsiveScale
	local Height = ResolveAxis(Root.Size.Y, LogicalSize.Y) * ResponsiveScale
	local AnchorX = ResolveAxis(Root.Position.X, LogicalSize.X) * ResponsiveScale
	local AnchorY = ResolveAxis(Root.Position.Y, LogicalSize.Y) * ResponsiveScale
	local Left = AnchorX - Root.AnchorPoint.X * Width
	local Top = AnchorY - Root.AnchorPoint.Y * Height
	return Left, Top, Width, Height
end

function App:_SetRect(Root, Left, Top, Width, Height, ZoneOverride)
	Width = math.max(Theme.Metric.MinObjectSize, Width)
	Height = math.max(Theme.Metric.MinObjectSize, Height)

	local LogicalSize = self:_GetResponsiveLogicalSize()
	local Zone = ZoneOverride or self:_InferRootZone(Left, Top, Width, Height, LogicalSize)
	local Anchor = Theme.ZoneAnchor[Zone] or Root.AnchorPoint
	local ResponsiveScale = self:_GetResponsiveScale()
	local LogicalWidth = Width / ResponsiveScale
	local LogicalHeight = Height / ResponsiveScale
	local LogicalAnchorX = (Left + Anchor.X * Width) / ResponsiveScale
	local LogicalAnchorY = (Top + Anchor.Y * Height) / ResponsiveScale

	Root:SetAttribute('FORGEZone', Zone)
	Root.AnchorPoint = Anchor
	Root.Size = UDim2.fromOffset(Round(LogicalWidth), Round(LogicalHeight))
	Root.Position = UDim2.new(
		Anchor.X,
		Round(LogicalAnchorX - Anchor.X * LogicalSize.X),
		Anchor.Y,
		Round(LogicalAnchorY - Anchor.Y * LogicalSize.Y)
	)
	Root:SetAttribute('FORGEResponsive', nil)
	Root:SetAttribute('FORGEResponsiveTree', nil)
	self:_UpdateSelectionBox()
end

function App:_HitTestRoot(Mouse)
	local Best
	local BestZ = -math.huge
	local BestOrder = -math.huge

	for Index, Root in ipairs(self.Document:GetRoots()) do
		if Root.Visible then
			local Position = Root.AbsolutePosition
			local Size = Root.AbsoluteSize
			local Inside = Mouse.X >= Position.X
				and Mouse.Y >= Position.Y
				and Mouse.X <= Position.X + Size.X
				and Mouse.Y <= Position.Y + Size.Y

			if Inside then
				local Z = Root.ZIndex
				if Z > BestZ or (Z == BestZ and Index > BestOrder) then
					Best = Root
					BestZ = Z
					BestOrder = Index
				end
			end
		end
	end

	return Best
end

function App:_SetSnapHeld(Value)
	self.ShiftHeld = Value == true
	self:_RefreshSnapState()
end

function App:_RefreshSnapState()
	local Active = self:_IsSnapHeld()
		and self.Drag ~= nil
		and self.Drag.Mode == 'Move'

	if self.SnapGuides then
		self.SnapGuides.Visible = Active
		if Active then self:_UpdateSnapGuides() end
	end

	if self.StatusLabel and Active then
		local Target = self.Selection:GetTarget()
		local _, _, _, _, _, Context = self:_GetSnapContext(Target)
		self.StatusLabel.Text = Target
			and ('SNAP   ' .. Target.Name .. ' -> ' .. (Context and Context.Name or 'Canvas'))
			or 'SNAP'
	elseif self.StatusLabel then
		self:_UpdateStatus()
	end
end

function App:_GetSnapContext(Target)
	if not Target or self.Document:IsRoot(Target) then
		local Size = self:_GetDeviceSize()
		local Root = self.Selection.Root
		local Margin = Root and self.Document:GetScreenMargin(Root) or Theme.Metric.ScreenMargin
		local Bounds = self.CameraBounds

		if Bounds and self.CameraBoundsVisible ~= false then
			local Left = math.clamp(tonumber(Bounds.Left) or 0, 0, 1) * Size.X
			local Top = math.clamp(tonumber(Bounds.Top) or 0, 0, 1) * Size.Y
			local Right = math.clamp(tonumber(Bounds.Right) or 1, 0, 1) * Size.X
			local Bottom = math.clamp(tonumber(Bounds.Bottom) or 1, 0, 1) * Size.Y
			return Left, Top, math.max(0, Right - Left), math.max(0, Bottom - Top), 0, self.CameraBoundsGuide or self.Device
		end

		return 0, 0, Size.X, Size.Y, Margin, self.Device
	end

	local Parent = Target.Parent
	if Parent and Parent:GetAttribute('FORGEHierarchyInternal') == true then Parent = Parent.Parent end
	if not Parent or not Parent:IsA('GuiObject') then
		local Size = self:_GetDeviceSize()
		return 0, 0, Size.X, Size.Y, Theme.Metric.ScreenMargin, self.Device
	end

	local Left, Top, Width, Height = self:_GetObjectCanvasRect(Parent)
	local Margin = tonumber(Parent:GetAttribute('FORGEPadding')) or 8
	return Left, Top, Width, Height, Margin, Parent
end

function App:_UpdateSnapGuides()
	if not self.SnapGuides or not self.SnapMarkers then return end

	local Target = self.Drag and self.Drag.Target or self.Selection:GetTarget()
	local Root = Target and self.Document:GetRoot(Target) or self.Selection.Root
	self.SnapGuides.Parent = self.Device

	local Left, Top, Width, Height, Margin = self:_GetSnapContext(Target)
	local MarginX = math.clamp(Margin, 0, Width / 2)
	local MarginY = math.clamp(Margin, 0, Height / 2)
	local Thickness = 2 / math.max(self.PreviewScale, .01)

	self.SnapMarginLines.Top.Position = UDim2.fromOffset(Left + MarginX, Top + MarginY - Thickness / 2)
	self.SnapMarginLines.Top.Size = UDim2.fromOffset(math.max(0, Width - MarginX * 2), Thickness)

	self.SnapMarginLines.Right.Position = UDim2.fromOffset(Left + Width - MarginX - Thickness / 2, Top + MarginY)
	self.SnapMarginLines.Right.Size = UDim2.fromOffset(Thickness, math.max(0, Height - MarginY * 2))

	self.SnapMarginLines.Bottom.Position = UDim2.fromOffset(Left + MarginX, Top + Height - MarginY - Thickness / 2)
	self.SnapMarginLines.Bottom.Size = UDim2.fromOffset(math.max(0, Width - MarginX * 2), Thickness)

	self.SnapMarginLines.Left.Position = UDim2.fromOffset(Left + MarginX - Thickness / 2, Top + MarginY)
	self.SnapMarginLines.Left.Size = UDim2.fromOffset(Thickness, math.max(0, Height - MarginY * 2))

	for Zone, Marker in pairs(self.SnapMarkers) do
		local Anchor = Theme.ZoneAnchor[Zone]
		local X = Left + (Anchor.X == 0 and MarginX or Anchor.X == 1 and Width - MarginX or Width / 2)
		local Y = Top + (Anchor.Y == 0 and MarginY or Anchor.Y == 1 and Height - MarginY or Height / 2)
		Marker.Position = UDim2.fromOffset(Round(X), Round(Y))
		local MarkerSize = 7 / math.max(self.PreviewScale, .01)
		Marker.Size = UDim2.fromOffset(MarkerSize, MarkerSize)
	end
end

function App:_IsControlHeld()
	if self.ControlHeld == true
		or self.ShortcutKeysDown[Enum.KeyCode.LeftControl] == true
		or self.ShortcutKeysDown[Enum.KeyCode.RightControl] == true
	then
		return true
	end

	local Success, Held = pcall(function()
		return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	end)
	return Success and Held == true
end

function App:_IsShiftHeld()
	if self.ShiftHeld == true
		or self.ShortcutKeysDown[Enum.KeyCode.LeftShift] == true
		or self.ShortcutKeysDown[Enum.KeyCode.RightShift] == true
	then
		return true
	end

	local Success, Held = pcall(function()
		return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	end)
	return Success and Held == true
end

function App:_IsSnapHeld()
	return self.SnapEnabled or self:_IsShiftHeld()
end

function App:_GetSnapPosition(Target, Zone, Width, Height)
	local Anchor = Theme.ZoneAnchor[Zone]
	if not Anchor then return nil end

	local ContextLeft, ContextTop, ContextWidth, ContextHeight, Margin = self:_GetSnapContext(Target)
	local MaxX = math.max(0, ContextWidth - Width)
	local MaxY = math.max(0, ContextHeight - Height)
	local MarginX = math.clamp(Margin, 0, MaxX / 2)
	local MarginY = math.clamp(Margin, 0, MaxY / 2)

	local Left = ContextLeft + (Anchor.X == 0 and MarginX
		or Anchor.X == 1 and MaxX - MarginX
		or MaxX / 2)
	local Top = ContextTop + (Anchor.Y == 0 and MarginY
		or Anchor.Y == 1 and MaxY - MarginY
		or MaxY / 2)

	return Left, Top
end

function App:_SnapMove(Root, Left, Top, Width, Height)
	local BestZone, BestLeft, BestTop
	local BestDistance = math.huge

	for _, Zone in ipairs(Theme.Zones) do
		local SnapLeft, SnapTop = self:_GetSnapPosition(Root, Zone, Width, Height)
		if SnapLeft and SnapTop then
			local DX, DY = Left - SnapLeft, Top - SnapTop
			local Distance = DX * DX + DY * DY
			if Distance < BestDistance then
				BestDistance = Distance
				BestZone = Zone
				BestLeft = SnapLeft
				BestTop = SnapTop
			end
		end
	end

	return BestLeft or Left, BestTop or Top, BestZone
end

function App:_BeginDrag(Mode, Mouse)
	if self.Drag then return end
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()
	local Root = self.Selection.Root
	local Target = self.Selection:GetTarget()
	if not Root or not Target or not Mouse then return end

	local Left, Top, Width, Height
	if self.Document:IsRoot(Target) then Left, Top, Width, Height = self:_GetRect(Target)
	else Left, Top, Width, Height = self:_GetObjectCanvasRect(Target) end

	local Drag = {
		Mode = Mode,
		Root = Root,
		Target = Target,
		Mouse = Mouse,
		Left = Left,
		Top = Top,
		Width = Width,
		Height = Height,
		Changed = false,
		Items = {}
	}

	if Mode == 'Move' then
		if self.Selection.Child then
			for _, Child in ipairs(self:_GetTopLevelSelectedChildren()) do
				if Child:IsA('GuiObject') then
					local L, T, W, H = self:_GetObjectCanvasRect(Child)
					table.insert(Drag.Items, {Root = Child, Left = L, Top = T, Width = W, Height = H})
				end
			end
		else
			for _, Selected in ipairs(self.Selection:GetRoots()) do
				if not self.Document:IsLocked(Selected) then
					local L, T, W, H = self:_GetRect(Selected)
					table.insert(Drag.Items, {Root = Selected, Left = L, Top = T, Width = W, Height = H})
				end
			end
		end
	end

	self.Drag = Drag
	self:_RefreshSnapState()
end

function App:_ResolveDragLayout(Root, Force)
	if not Root or not Root.Parent then return end
	if not self.ComponentPresets or not self.ComponentPresets.ResolveLayouts then return end

	local Now = os.clock()
	if not Force and Now - (self.LastDragLayoutResolveAt or 0) < (self.DragLayoutInterval or 1 / 30) then return end
	self.LastDragLayoutResolveAt = Now
	self:_ResolveLayoutsForRoot(Root)
end

function App:_UpdateDrag(Mouse)
	local Drag = self.Drag
	if not Drag or not Drag.Root.Parent or not Mouse then return end

	local Delta = (Mouse - Drag.Mouse) / math.max(self.PreviewScale, .01)
	local Mode = Drag.Mode

	if Mode == 'Move' then
		local DX, DY = Delta.X, Delta.Y
		local PrimaryLeft = Drag.Left + DX
		local PrimaryTop = Drag.Top + DY

		if self.SnapIncrement > 0 then
			local ContextLeft, ContextTop = self:_GetSnapContext(Drag.Target)
			PrimaryLeft = ContextLeft + Quantize(PrimaryLeft - ContextLeft, self.SnapIncrement)
			PrimaryTop = ContextTop + Quantize(PrimaryTop - ContextTop, self.SnapIncrement)
			DX = PrimaryLeft - Drag.Left
			DY = PrimaryTop - Drag.Top
		end

		if self:_IsSnapHeld() then
			for _, Item in ipairs(Drag.Items) do Item.Root:SetAttribute('FORGESnapTarget', nil) end
			local Zone
			local SnapLeft, SnapTop
			SnapLeft, SnapTop, Zone = self:_SnapMove(
				Drag.Target,
				PrimaryLeft,
				PrimaryTop,
				Drag.Width,
				Drag.Height
			)
			DX = SnapLeft - Drag.Left
			DY = SnapTop - Drag.Top
			if Zone then
				Drag.SnapZone = Zone
				if self.Document:IsRoot(Drag.Target) then Drag.Target:SetAttribute('FORGEZone', Zone) end
				Drag.Target:SetAttribute('FORGESnapTarget', Zone)
			end
		else
			Drag.SnapZone = nil
			for _, Item in ipairs(Drag.Items) do Item.Root:SetAttribute('FORGESnapTarget', nil) end
		end

		for _, Item in ipairs(Drag.Items) do
			if self.Document:IsRoot(Item.Root) then
				self:_SetRect(Item.Root, Item.Left + DX, Item.Top + DY, Item.Width, Item.Height)
			else
				self:_SetObjectCanvasPosition(Item.Root, Item.Left + DX, Item.Top + DY)
			end
		end

		self:_ResolveDragLayout(Drag.Root, false)
		self:_UpdateSelectionBox()
		Drag.Changed = Drag.Changed or math.abs(DX) > .01 or math.abs(DY) > .01
		return
	end

	local Left, Top = Drag.Left, Drag.Top
	local Right, Bottom = Drag.Left + Drag.Width, Drag.Top + Drag.Height

	if string.find(Mode, 'W', 1, true) then Left += Delta.X end
	if string.find(Mode, 'E', 1, true) then Right += Delta.X end
	if string.find(Mode, 'N', 1, true) then Top += Delta.Y end
	if string.find(Mode, 'S', 1, true) then Bottom += Delta.Y end

	if self.SnapIncrement > 0 then
		local ContextLeft, ContextTop = self:_GetSnapContext(Drag.Target)
		if string.find(Mode, 'W', 1, true) then Left = ContextLeft + Quantize(Left - ContextLeft, self.SnapIncrement) end
		if string.find(Mode, 'E', 1, true) then Right = ContextLeft + Quantize(Right - ContextLeft, self.SnapIncrement) end
		if string.find(Mode, 'N', 1, true) then Top = ContextTop + Quantize(Top - ContextTop, self.SnapIncrement) end
		if string.find(Mode, 'S', 1, true) then Bottom = ContextTop + Quantize(Bottom - ContextTop, self.SnapIncrement) end
	end

	if Right - Left < Theme.Metric.MinObjectSize then
		if string.find(Mode, 'W', 1, true) then
			Left = Right - Theme.Metric.MinObjectSize
		else
			Right = Left + Theme.Metric.MinObjectSize
		end
	end

	if Bottom - Top < Theme.Metric.MinObjectSize then
		if string.find(Mode, 'N', 1, true) then
			Top = Bottom - Theme.Metric.MinObjectSize
		else
			Bottom = Top + Theme.Metric.MinObjectSize
		end
	end

	if not self.Document:IsRoot(Drag.Target) then
		if string.find(Mode, 'W', 1, true) or string.find(Mode, 'E', 1, true) then
			SetAutoAxis(Drag.Target, 'X', false, self.ComponentPresets)
			Drag.Target:SetAttribute('FORGELayoutCompX', nil)
		end
		if string.find(Mode, 'N', 1, true) or string.find(Mode, 'S', 1, true) then
			SetAutoAxis(Drag.Target, 'Y', false, self.ComponentPresets)
			Drag.Target:SetAttribute('FORGELayoutCompY', nil)
		end
	end

	self:_SetObjectCanvasRect(Drag.Target, Left, Top, Right - Left, Bottom - Top)
	self:_ResolveDragLayout(Drag.Root, false)
	self:_UpdateSelectionBox()
	Drag.Changed = true
end

function App:_EndDrag()
	if not self.Drag then return end
	local Drag = self.Drag
	self.Drag = nil

	if self.SnapGuides then self.SnapGuides.Visible = false end
	if Drag.SnapZone and Drag.Target and self.Document:IsRoot(Drag.Target) and Drag.Target.Parent then
		self.Document:SetZone(Drag.Target, Drag.SnapZone)
	end

	if Drag.Changed then
		self:_ResolveDragLayout(Drag.Root, true)
		if self.Modifiers and self.Modifiers.ApplyTree then self.Modifiers:ApplyTree(Drag.Root) end
		self:_RecordHistory(Drag.Mode == 'Move' and 'Move' or 'Resize')
	end

	self:_RefreshProperties()
	self:_UpdateStatus()
end

function App:_Nudge(DX, DY)
	if self.Selection.Child then
		local Root = self.Selection.Root
		if not Root or self.Document:IsLocked(Root) then return end

		local Changed = false
		for _, Child in ipairs(self:_GetTopLevelSelectedChildren()) do
			if Child:IsA('GuiObject') then
				local Position = Child.Position
				Child.Position = UDim2.new(
					Position.X.Scale,
					Position.X.Offset + DX,
					Position.Y.Scale,
					Position.Y.Offset + DY
				)
				Changed = true
			end
		end

		if Changed then
			self:_RecordHistory('Nudge Children')
			self:_RefreshAll()
		end
		return
	end

	local Changed = false
	for _, Root in ipairs(self.Selection:GetRoots()) do
		if not self.Document:IsLocked(Root) then
			local Left, Top, Width, Height = self:_GetRect(Root)
			Root:SetAttribute('FORGESnapTarget', nil)
			self:_SetRect(Root, Left + DX, Top + DY, Width, Height)
			Changed = true
		end
	end

	if Changed then self:_RecordHistory('Nudge') end
end

function App:_GetSelectionBounds(Roots)
	local MinX, MinY = math.huge, math.huge
	local MaxX, MaxY = -math.huge, -math.huge

	for _, Root in ipairs(Roots) do
		local Left, Top, Width, Height = self:_GetRect(Root)
		MinX = math.min(MinX, Left)
		MinY = math.min(MinY, Top)
		MaxX = math.max(MaxX, Left + Width)
		MaxY = math.max(MaxY, Top + Height)
	end

	if MinX == math.huge then return nil end
	return MinX, MinY, MaxX, MaxY
end

function App:_Align(Mode)
	local Roots = self.Selection:GetRoots()
	if #Roots < 2 then return end

	local MinX, MinY, MaxX, MaxY = self:_GetSelectionBounds(Roots)
	if not MinX then return end

	local Changed = false
	for _, Root in ipairs(Roots) do
		if not self.Document:IsLocked(Root) then
			local Left, Top, Width, Height = self:_GetRect(Root)

			if Mode == 'Left' then Left = MinX
			elseif Mode == 'CenterX' then Left = (MinX + MaxX - Width) / 2
			elseif Mode == 'Right' then Left = MaxX - Width
			elseif Mode == 'Top' then Top = MinY
			elseif Mode == 'CenterY' then Top = (MinY + MaxY - Height) / 2
			elseif Mode == 'Bottom' then Top = MaxY - Height
			end

			Root:SetAttribute('FORGESnapTarget', nil)
			self:_SetRect(Root, Left, Top, Width, Height)
			Changed = true
		end
	end

	if Changed then self:_RecordHistory('Align ' .. Mode) end
end

function App:_Distribute(Direction)
	local Roots = {}

	for _, Root in ipairs(self.Selection:GetRoots()) do
		if not self.Document:IsLocked(Root) then table.insert(Roots, Root) end
	end

	if #Roots < 3 then return end

	table.sort(Roots, function(A, B)
		local AL, AT = self:_GetRect(A)
		local BL, BT = self:_GetRect(B)
		if Direction == 'Horizontal' then return AL < BL end
		return AT < BT
	end)

	if Direction == 'Horizontal' then
		local FirstLeft = self:_GetRect(Roots[1])
		local LastLeft, _, LastWidth = self:_GetRect(Roots[#Roots])
		local TotalWidth = 0

		for _, Root in ipairs(Roots) do
			local _, _, Width = self:_GetRect(Root)
			TotalWidth += Width
		end

		local Space = ((LastLeft + LastWidth) - FirstLeft - TotalWidth) / (#Roots - 1)
		local Cursor = FirstLeft

		for _, Root in ipairs(Roots) do
			local _, Top, Width, Height = self:_GetRect(Root)
			Root:SetAttribute('FORGESnapTarget', nil)
			self:_SetRect(Root, Cursor, Top, Width, Height)
			Cursor += Width + Space
		end
	else
		local _, FirstTop = self:_GetRect(Roots[1])
		local _, LastTop, _, LastHeight = self:_GetRect(Roots[#Roots])
		local TotalHeight = 0

		for _, Root in ipairs(Roots) do
			local _, _, _, Height = self:_GetRect(Root)
			TotalHeight += Height
		end

		local Space = ((LastTop + LastHeight) - FirstTop - TotalHeight) / (#Roots - 1)
		local Cursor = FirstTop

		for _, Root in ipairs(Roots) do
			local Left, _, Width, Height = self:_GetRect(Root)
			Root:SetAttribute('FORGESnapTarget', nil)
			self:_SetRect(Root, Left, Cursor, Width, Height)
			Cursor += Height + Space
		end
	end

	self:_RecordHistory('Distribute ' .. Direction)
end

function App:_Equalize(Mode)
	local Primary = self.Selection.Root
	local Roots = self.Selection:GetRoots()
	if not Primary or #Roots < 2 then return end

	local _, _, PrimaryWidth, PrimaryHeight = self:_GetRect(Primary)
	local Changed = false

	for _, Root in ipairs(Roots) do
		if Root ~= Primary and not self.Document:IsLocked(Root) then
			local Left, Top, Width, Height = self:_GetRect(Root)

			if Mode == 'Width' or Mode == 'Size' then Width = PrimaryWidth end
			if Mode == 'Height' or Mode == 'Size' then Height = PrimaryHeight end

			Root:SetAttribute('FORGESnapTarget', nil)
			self:_SetRect(Root, Left, Top, Width, Height)
			Changed = true
		end
	end

	if Changed then self:_RecordHistory('Equal ' .. Mode) end
end

function App:_ClearSecondaryBoxes()
	for _, Box in ipairs(self.SecondaryBoxes) do Box:Destroy() end
	table.clear(self.SecondaryBoxes)
end

function App:_UpdateSelectionBox()
	if not self.SelectionLines or not self.Handles then return end
	self:_ClearSecondaryBoxes()

	local Root = self.Selection.Root
	local Target = self.Selection:GetTarget()
	local Visible = not self.InteractiveMode and Target ~= nil and Target.Parent ~= nil

	for _, Line in pairs(self.SelectionLines) do
		Line.Parent = self.Device
		Line.Visible = Visible
	end
	for _, Handle in pairs(self.Handles) do
		Handle.Object.Parent = self.Device
		Handle.Object.Visible = Visible and Root ~= nil and not self.Document:IsLocked(Root)
	end

	if self.InteractiveMode then return end

	local SelectedChildren = self.Selection.GetChildren and self.Selection:GetChildren() or {}
	for _, Selected in ipairs(SelectedChildren) do
		if Selected ~= Target and Selected.Parent and Selected:IsA('GuiObject') then
			local Left, Top, Width, Height = self:_GetObjectCanvasRect(Selected)
			local Box = Instance.new('Frame')
			Box.BackgroundTransparency = 1
			Box.BorderSizePixel = 0
			Box.Position = UDim2.fromOffset(Round(Left), Round(Top))
			Box.Size = UDim2.fromOffset(Round(Width), Round(Height))
			Box.Active = false
			Box.ZIndex = 10019
			Box.Parent = self.Device

			local Stroke = Instance.new('UIStroke')
			Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			Stroke.LineJoinMode = Enum.LineJoinMode.Miter
			Stroke.Color = Theme.Color.SelectionSecondary
			Stroke.Thickness = 2 / math.max(self.PreviewScale, .01)
			Stroke.Parent = Box
			table.insert(self.SecondaryBoxes, Box)
		end
	end

	for _, Selected in ipairs(self.Selection:GetRoots()) do
		if #SelectedChildren == 0 and Selected ~= Root and Selected.Parent then
			local Left, Top, Width, Height = self:_GetRect(Selected)
			local Box = Instance.new('Frame')
			Box.BackgroundTransparency = 1
			Box.BorderSizePixel = 0
			Box.Position = UDim2.fromOffset(Round(Left), Round(Top))
			Box.Size = UDim2.fromOffset(Round(Width), Round(Height))
			Box.Active = false
			Box.ZIndex = 10019
			Box.Parent = self.Device

			local Stroke = Instance.new('UIStroke')
			Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			Stroke.LineJoinMode = Enum.LineJoinMode.Miter
			Stroke.Color = Theme.Color.SelectionSecondary
			Stroke.Thickness = 2 / math.max(self.PreviewScale, .01)
			Stroke.Parent = Box
			table.insert(self.SecondaryBoxes, Box)
		end
	end

	if not Visible then return end

	local X, Y, W, H
	if self.Document:IsRoot(Target) then X, Y, W, H = self:_GetRect(Target)
	else X, Y, W, H = self:_GetObjectCanvasRect(Target) end
	X, Y, W, H = Round(X), Round(Y), Round(W), Round(H)
	local Scale = math.max(self.PreviewScale, .01)
	local Thickness = 2 / Scale

	self.SelectionLines.Top.Position = UDim2.fromOffset(X, Y)
	self.SelectionLines.Top.Size = UDim2.fromOffset(W, Thickness)

	self.SelectionLines.Right.Position = UDim2.fromOffset(X + W - Thickness, Y)
	self.SelectionLines.Right.Size = UDim2.fromOffset(Thickness, H)

	self.SelectionLines.Bottom.Position = UDim2.fromOffset(X, Y + H - Thickness)
	self.SelectionLines.Bottom.Size = UDim2.fromOffset(W, Thickness)

	self.SelectionLines.Left.Position = UDim2.fromOffset(X, Y)
	self.SelectionLines.Left.Size = UDim2.fromOffset(Thickness, H)

	local Hitbox = Theme.Metric.HandleHitbox / Scale
	local Visual = Theme.Metric.Handle / Scale

	for _, Handle in pairs(self.Handles) do
		Handle.Object.Size = UDim2.fromOffset(Hitbox, Hitbox)
		Handle.Visual.Size = UDim2.fromOffset(Visual, Visual)
		Handle.Object.Position = UDim2.fromOffset(
			X + W * Handle.Point.X,
			Y + H * Handle.Point.Y
		)
	end
end

function App:_RootMatchesSearch(Root)
	local Query = string.lower(self.ExplorerSearch.Text or '')
	if Query == '' then return true end
	local Haystack = string.lower(Root.Name .. ' ' .. self.Document:GetZone(Root))
	return string.find(Haystack, Query, 1, true) ~= nil
end

local function SelectionRange(Order, Anchor, Target)
	local A = table.find(Order, Anchor)
	local B = table.find(Order, Target)
	if not A or not B then return {Target} end

	local Result = {}
	local First, Last = math.min(A, B), math.max(A, B)
	for Index = First, Last do table.insert(Result, Order[Index]) end
	return Result
end

local function UnionSelection(Base, Added)
	local Result, Seen = {}, {}
	for _, Item in ipairs(Base or {}) do
		if Item and not Seen[Item] then
			Seen[Item] = true
			table.insert(Result, Item)
		end
	end
	for _, Item in ipairs(Added or {}) do
		if Item and not Seen[Item] then
			Seen[Item] = true
			table.insert(Result, Item)
		end
	end
	return Result
end

function App:_SelectExplorerRoot(Root)
	local Ctrl, Shift = self:_IsControlHeld(), self:_IsShiftHeld()
	local Order = self.RootDisplayOrder or {}

	if Shift then
		local Anchor = self.RootSelectionAnchor or self.Selection.Root or Root
		local Range = SelectionRange(Order, Anchor, Root)
		if Ctrl then Range = UnionSelection(self.Selection:GetRoots(), Range) end
		self.Selection:SetRoots(Range, Root)
	else
		if Ctrl then self.Selection:ToggleRoot(Root) else self.Selection:SelectRoot(Root) end
		self.RootSelectionAnchor = Root
	end

	self.ChildSelectionAnchor = nil
end

function App:_SelectHierarchyChild(Child)
	local Ctrl, Shift = self:_IsControlHeld(), self:_IsShiftHeld()
	local Order = self.ChildDisplayOrder or {}

	if Shift then
		local Anchor = self.ChildSelectionAnchor or self.Selection.Child or Child
		local Range = SelectionRange(Order, Anchor, Child)
		if Ctrl then Range = UnionSelection(self.Selection:GetChildren(), Range) end
		self.Selection:SetChildren(Range, Child)
	else
		if Ctrl then self.Selection:ToggleChild(Child) else self.Selection:SelectChild(Child) end
		self.ChildSelectionAnchor = Child
	end
end

function App:_GetTopLevelSelectedChildren()
	local Children = self.Selection.GetChildren and self.Selection:GetChildren() or {}
	if #Children == 0 then return {} end

	local Selected, Result = {}, {}
	for _, Child in ipairs(Children) do Selected[Child] = true end

	for _, Child in ipairs(Children) do
		local Parent = Child.Parent
		local Nested = false
		while Parent and Parent ~= self.Selection.Root do
			if Selected[Parent] then
				Nested = true
				break
			end
			Parent = Parent.Parent
		end
		if not Nested then table.insert(Result, Child) end
	end

	return Result
end

function App:_RefreshRoots()
	local Preserve = {[self.RootLayout] = true}
	Clear(self.RootList, Preserve)
	table.clear(self.RootRows)
	table.clear(self.RootDisplayOrder)

	local Order = 0
	for _, Root in ipairs(self.Document:GetRoots()) do
		if self:_RootMatchesSearch(Root) then
			Order += 1
			local Row = Widgets.TreeRow(self.RootList, Root.Name, 0)
			Row.Object.LayoutOrder = Order
			table.insert(self.RootDisplayOrder, Root)

			local Zone = Widgets.Label(Row.Object, self.Document:GetZone(Root), 9, false)
			Zone.TextColor3 = Theme.Color.TextMuted
			Zone.TextXAlignment = Enum.TextXAlignment.Right
			Zone.Position = UDim2.new(1, -137, 0, 0)
			Zone.Size = UDim2.fromOffset(52, Theme.Metric.RowHeight)

			local RenameButton = Widgets.SmallButton(Row.Object, '✎')
			RenameButton.Position = UDim2.new(1, -82, 0, 1)
			RenameButton.Size = UDim2.fromOffset(19, Theme.Metric.RowHeight - 2)

			local InsertButton = Widgets.SmallButton(Row.Object, '+')
			InsertButton.Position = UDim2.new(1, -61, 0, 1)
			InsertButton.Size = UDim2.fromOffset(19, Theme.Metric.RowHeight - 2)

			local VisibleButton = Widgets.SmallButton(Row.Object, Root.Visible and 'V' or '-')
			VisibleButton.Position = UDim2.new(1, -40, 0, 1)
			VisibleButton.Size = UDim2.fromOffset(19, Theme.Metric.RowHeight - 2)

			local LockButton = Widgets.SmallButton(Row.Object, self.Document:IsLocked(Root) and 'L' or 'U')
			LockButton.Position = UDim2.new(1, -20, 0, 1)
			LockButton.Size = UDim2.fromOffset(19, Theme.Metric.RowHeight - 2)

			Row.Label.Size = UDim2.new(1, -166, 1, 0)
			Widgets.SetTreeRowSelected(
				Row,
				self.Selection:IsSelected(Root),
				self.Selection.Root == Root
			)

			Row.Object.MouseButton1Down:Connect(function(X, Y)
				if self:_IsShiftHeld() or self:_IsControlHeld() then
					self:_SelectExplorerRoot(Root)
					return
				end
				if self.Document:IsLocked(Root) then
					self:_SelectExplorerRoot(Root)
					return
				end
				self:_BeginRootDrag(Root, Vector2.new(X, Y))
			end)

			Row.Object.InputBegan:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton2 then
					self:_ShowRootContext(Root, Input.Position.X, Input.Position.Y)
				end
			end)

			Row.Icon.MouseButton1Click:Connect(function()
				self:_SelectExplorerRoot(Root)
			end)

			RenameButton.MouseButton1Click:Connect(function()
				self:_BeginHierarchyRename(Root, Row, '', 0, 146)
			end)

			InsertButton.MouseButton1Down:Connect(function(X, Y)
				self:_OpenInsertForTarget(Root, X, Y)
			end)

			VisibleButton.MouseButton1Click:Connect(function()
				Root.Visible = not Root.Visible
				self:_RecordHistory('Toggle Visibility')
				self:_RefreshRoots()
			end)

			LockButton.MouseButton1Click:Connect(function()
				self.Document:SetLocked(Root, not self.Document:IsLocked(Root))
				self:_RecordHistory('Toggle Lock')
				self:_RefreshAll()
			end)

			self.RootRows[Root] = Row
		end
	end

	local ChildCount = self.Selection.ChildCount and self.Selection:ChildCount() or 0
	if ChildCount > 1 then
		self.ZoneButton.Text = tostring(ChildCount) .. ' children selected'
	elseif self.Selection:Count() > 1 then
		self.ZoneButton.Text = tostring(self.Selection:Count()) .. ' selected'
	else
		self.ZoneButton.Text = self.Selection.Root and self.Document:GetZone(self.Selection.Root) or '-'
	end
end

function App:_ClearRootDrop()
	for _, Row in pairs(self.RootRows or {}) do Widgets.SetTreeRowDrop(Row, nil) end
end

function App:_BeginRootDrag(Root, Mouse)
	if not Root or not Mouse or self.Document:IsLocked(Root) then return end
	self.RootDrag = {
		Root = Root,
		Start = Mouse,
		Active = false,
		Target = nil
	}
	if self.DragCapture then self.DragCapture.Visible = true end
end

function App:_UpdateRootDrag(Mouse)
	local Drag = self.RootDrag
	if not Drag or not Mouse then return end

	if not Drag.Active then
		if (Mouse - Drag.Start).Magnitude < 4 then return end
		Drag.Active = true
	end

	self:_ClearRootDrop()
	local Target
	for Root, Row in pairs(self.RootRows or {}) do
		if Root ~= Drag.Root and self:_CanHierarchyParent(Root) then
			local Object = Row.Object
			local Position, Size = Object.AbsolutePosition, Object.AbsoluteSize
			if Mouse.X >= Position.X and Mouse.X <= Position.X + Size.X
				and Mouse.Y >= Position.Y and Mouse.Y <= Position.Y + Size.Y
			then
				Target = Root
				Widgets.SetTreeRowDrop(Row, 'Into')
				break
			end
		end
	end
	Drag.Target = Target
end

function App:_ReparentRootInto(Root, Owner)
	if not Root or not Owner
		or not self.Document:IsRoot(Root)
		or not self.Document:IsRoot(Owner)
		or Root == Owner
		or self.Document:IsLocked(Root)
		or self.Document:IsLocked(Owner)
		or not self:_CanHierarchyParent(Owner)
	then return false end

	local Left, Top = self:_GetObjectCanvasRect(Root)
	local Target = self.ComponentPresets and self.ComponentPresets:GetInsertionTarget(Owner) or Owner
	if not Target or not Target:IsA('GuiObject') then return false end

	if not self.Document:DetachRoot(Root, true) then return false end
	Root:SetAttribute('FORGEZone', nil)
	Root:SetAttribute('FORGEScreenMargin', nil)
	Root:SetAttribute('FORGELocked', nil)
	Root.Parent = Target

	if self.ComponentPresets then self.ComponentPresets:AdoptChild(Owner, Root) end
	if Owner:GetAttribute('FORGELayoutKind') == nil and Owner:GetAttribute('FORGESimpleKind') ~= 'Scroller' then
		self:_SetObjectCanvasPosition(Root, Left, Top)
	end

	self.Selection:SetChildren({Root}, Root)
	return true
end

function App:_EndRootDrag()
	local Drag = self.RootDrag
	self.RootDrag = nil
	self:_ClearRootDrop()
	if self.DragCapture and not self.HierarchyDrag then self.DragCapture.Visible = false end
	if not Drag then return end

	if not Drag.Active then
		if Drag.Root and Drag.Root.Parent then self:_SelectExplorerRoot(Drag.Root) end
		return
	end

	if not Drag.Target then return end
	local Changed = self:_WithRefreshSuspended(function()
		return self:_ReparentRootInto(Drag.Root, Drag.Target)
	end)

	if Changed then
		self:_RecordHistory('Parent Root')
		self:_RefreshAll()
	end
end

function App:_ClearHierarchyDrop()
	for _, Row in pairs(self.ChildRows or {}) do Widgets.SetTreeRowDrop(Row, nil) end
end

function App:_HierarchyOwner(Object)
	local Parent = Object and Object.Parent
	while Parent and Parent:GetAttribute('FORGEHierarchyInternal') == true do
		Parent = Parent.Parent
	end
	return Parent
end

function App:_HierarchySiblings(Owner)
	if not Owner then return {} end
	local Parent = self.ComponentPresets and self.ComponentPresets:GetInsertionTarget(Owner) or Owner
	return self:_VisibleHierarchyChildren(Parent)
end

function App:_RenumberHierarchy(Owner, Ordered)
	for Index, Child in ipairs(Ordered or {}) do Child.LayoutOrder = Index end
	if Owner and Owner:GetAttribute('FORGELayoutKind') then
		Owner:SetAttribute('FORGELayoutOrderInitialized', true)
	end
end

function App:_ReorderHierarchyChild(Child, Target, After)
	if not Child or not Target or Child == Target or Target:IsDescendantOf(Child) then return false end
	local Owner = self:_HierarchyOwner(Target)
	if not Owner or not self:_CanHierarchyParent(Owner) then return false end

	local Parent = self.ComponentPresets and self.ComponentPresets:GetInsertionTarget(Owner) or Owner
	if not Parent then return false end
	if Child.Parent ~= Parent then Child.Parent = Parent end

	local Ordered = self:_VisibleHierarchyChildren(Parent)
	local Current = table.find(Ordered, Child)
	if Current then table.remove(Ordered, Current) end
	local Index = table.find(Ordered, Target)
	if not Index then return false end
	table.insert(Ordered, Index + (After and 1 or 0), Child)
	self:_RenumberHierarchy(Owner, Ordered)
	if self.ComponentPresets then self.ComponentPresets:AdoptChild(Owner, Child) end
	return true
end

function App:_BeginHierarchyDrag(Child, Mouse)
	if not Child or not Mouse then return end
	self.HierarchyDrag = {
		Child = Child,
		Start = Mouse,
		Mouse = Mouse,
		Active = false,
		Target = nil,
		Mode = nil
	}
	if self.DragCapture then self.DragCapture.Visible = true end
end

function App:_UpdateHierarchyDrag(Mouse)
	local Drag = self.HierarchyDrag
	if not Drag or not Mouse then return end
	Drag.Mouse = Mouse

	if not Drag.Active then
		if (Mouse - Drag.Start).Magnitude < 4 then return end
		Drag.Active = true
	end

	self:_ClearHierarchyDrop()
	local Target, Mode
	for Child, Row in pairs(self.ChildRows or {}) do
		local Object = Row.Object
		if Object and Object.Parent and Child ~= Drag.Child and not Child:IsDescendantOf(Drag.Child) then
			local Position, Size = Object.AbsolutePosition, Object.AbsoluteSize
			if Mouse.X >= Position.X and Mouse.X <= Position.X + Size.X
				and Mouse.Y >= Position.Y and Mouse.Y <= Position.Y + Size.Y
			then
				Target = Child
				local Y = (Mouse.Y - Position.Y) / math.max(Size.Y, 1)
				if Y > .27 and Y < .73 and self:_CanHierarchyParent(Child) then Mode = 'Into'
				elseif Y < .5 then Mode = 'Before'
				else Mode = 'After' end
				Widgets.SetTreeRowDrop(Row, Mode)
				break
			end
		end
	end

	Drag.Target = Target
	Drag.Mode = Mode
end

function App:_EndHierarchyDrag()
	local Drag = self.HierarchyDrag
	self.HierarchyDrag = nil
	self:_ClearHierarchyDrop()
	if self.DragCapture and not self.RootDrag then self.DragCapture.Visible = false end
	if not Drag then return end

	local Child = Drag.Child
	if not Child or not Child.Parent then return end

	if not Drag.Active then
		self:_SelectHierarchyChild(Child)
		return
	end

	local Target, Mode = Drag.Target, Drag.Mode
	local Changed = self:_WithRefreshSuspended(function()
		if Target and Mode == 'Into' then
			return self:_ReparentChild(Child, Target, {NoHistory = true, NoRefresh = true, NoSelect = true})
		elseif Target and (Mode == 'Before' or Mode == 'After') then
			return self:_ReorderHierarchyChild(Child, Target, Mode == 'After')
		elseif not Target and self.Selection.Root and Child ~= self.Selection.Root then
			return self:_ReparentChild(Child, self.Selection.Root, {NoHistory = true, NoRefresh = true, NoSelect = true})
		end
		return false
	end)

	if Changed then
		self:_WithRefreshSuspended(function() self.Selection:SelectChild(Child) end)
		self:_ResolveLayoutsForRoot(self.Selection.Root)
		self:_RecordHistory('Move Hierarchy')
		self:_RefreshAll()
	end
end

function App:_CanHierarchyParent(Object)
	if not Object or not Object:IsA('GuiObject') then return false end
	if Object:GetAttribute('FORGEStyleInternal') == true
		or Object:GetAttribute('FORGEHierarchyInternal') == true
		or Object:GetAttribute('FORGEModifierGenerated') == true
	then return false end
	return true
end

function App:_IsHierarchyInternalObject(Object)
	if not Object then return false end
	if Object:GetAttribute('FORGEStyleInternal') == true
		or Object:GetAttribute('FORGEHierarchyInternal') == true
		or Object:GetAttribute('FORGEModifierGenerated') == true
		or Object:GetAttribute('FORGEModifierInternal') == true
	then return true end

	local Name = tostring(Object.Name or '')
	if string.sub(Name, 1, 6) == '_FORGE' then return true end
	return false
end

function App:_VisibleHierarchyChildren(Parent)
	local Result = {}
	if not Parent then return Result end

	local function Collect(Container)
		for _, Child in ipairs(Container:GetChildren()) do
			if Child:IsA('GuiObject') then
				if self:_IsHierarchyInternalObject(Child) then
					Collect(Child)
				else
					table.insert(Result, Child)
				end
			end
		end
	end

	if self.ComponentPresets and self.ComponentPresets:CanAcceptChildren(Parent) then
		Parent = self.ComponentPresets:GetInsertionTarget(Parent) or Parent
	end
	Collect(Parent)

	table.sort(Result, function(A, B)
		if A.LayoutOrder == B.LayoutOrder then return A.Name < B.Name end
		return A.LayoutOrder < B.LayoutOrder
	end)
	return Result
end

function App:_ReparentChild(Child, Owner, Options)
	Options = Options or {}
	if not Child or not Owner or Child == Owner or Owner:IsDescendantOf(Child) then return false end
	local SourceRoot = self.Document:GetRoot(Child)
	local TargetRoot = self.Document:GetRoot(Owner)
	if not SourceRoot or not TargetRoot
		or self.Document:IsLocked(SourceRoot)
		or self.Document:IsLocked(TargetRoot)
		or not self:_CanHierarchyParent(Owner)
	then return false end

	local Left, Top = self:_GetObjectCanvasRect(Child)
	local Target = self.ComponentPresets and self.ComponentPresets:GetInsertionTarget(Owner) or Owner
	if not Target or not Target:IsA('GuiObject') then return false end

	Child.Parent = Target
	if self.ComponentPresets then self.ComponentPresets:AdoptChild(Owner, Child) end
	if Owner:GetAttribute('FORGELayoutKind') == nil and Owner:GetAttribute('FORGESimpleKind') ~= 'Scroller' then
		self:_SetObjectCanvasPosition(Child, Left, Top)
	end
	if not Options.NoSelect then self.Selection:SelectChild(Child) end
	if not Options.NoHistory then self:_RecordHistory('Reparent Child') end
	if not Options.NoRefresh then self:_RefreshAll() end
	return true
end

function App:_IndentSelectedChild()
	local Child = self.Selection.Child
	if not Child then return end
	local Siblings = self:_VisibleHierarchyChildren(Child.Parent)
	local Index = table.find(Siblings, Child)
	if not Index then return end
	for I = Index - 1, 1, -1 do
		if self:_CanHierarchyParent(Siblings[I]) then
			self:_ReparentChild(Child, Siblings[I])
			return
		end
	end
end

function App:_OutdentSelectedChild()
	local Child = self.Selection.Child
	if not Child then return end
	local Parent = Child.Parent
	if Parent and Parent:GetAttribute('FORGEHierarchyInternal') == true then Parent = Parent.Parent end
	if not Parent or Parent == self.Selection.Root then return end
	local Grandparent = Parent.Parent
	if Grandparent and Grandparent:GetAttribute('FORGEHierarchyInternal') == true then Grandparent = Grandparent.Parent end
	if not Grandparent or not Grandparent:IsDescendantOf(self.Selection.Root) and Grandparent ~= self.Selection.Root then return end
	self:_ReparentChild(Child, Grandparent)
end

function App:_MoveSelectedChild(Direction)
	local Child = self.Selection.Child
	if not Child then return end
	local Parent = Child.Parent
	local Siblings = self:_VisibleHierarchyChildren(Parent)
	local Index = table.find(Siblings, Child)
	local Other = Index and Siblings[Index + Direction]
	if not Other then return end
	local Order = Child.LayoutOrder
	Child.LayoutOrder = Other.LayoutOrder
	Other.LayoutOrder = Order
	if Child.LayoutOrder == Other.LayoutOrder then
		Child.LayoutOrder = Index + Direction
		Other.LayoutOrder = Index
	end
	self:_RecordHistory(Direction < 0 and 'Move Child Up' or 'Move Child Down')
	self:_RefreshChildren()
end

function App:_ChildMatchesSearch(Child)
	local Query = string.lower(self.ChildrenSearch.Text or '')
	if Query == '' then return true end
	local Slot = Child:GetAttribute('FORGESlotName') or ''
	local Kind = Child:GetAttribute('FORGESimpleKind') or Child.ClassName
	local Haystack = string.lower(Child.Name .. ' ' .. Slot .. ' ' .. tostring(Kind))
	return string.find(Haystack, Query, 1, true) ~= nil
end

function App:_HierarchyBranchMatches(Child)
	if self:_ChildMatchesSearch(Child) then return true end
	for _, Descendant in ipairs(self:_VisibleHierarchyChildren(Child)) do
		if self:_HierarchyBranchMatches(Descendant) then return true end
	end
	return false
end

function App:_SetHierarchyCollapsed(Object, Value)
	if not Object then return end
	if Value then self.CollapsedChildren[Object] = true
	else self.CollapsedChildren[Object] = nil end
	self:_RefreshChildren()
end

function App:_RenameHierarchyObject(Object, Value)
	if not Object or not Object.Parent then return false end
	local Root = self.Document:GetRoot(Object)
	if Root and self.Document:IsLocked(Root) then return false end

	Value = tostring(Value or ''):match('^%s*(.-)%s*$') or ''
	if Value == '' or Value == Object.Name then return false end

	Object.Name = Value
	self:_RecordHistory('Rename Object')
	if self.Document:IsRoot(Object) then self:_RefreshRoots() end
	self:_RefreshChildren()
	self:_RefreshProperties()
	return true
end

function App:_BeginHierarchyRename(Object, Row, Suffix, Depth, RightReserve)
	if not Object or not Row or not Row.Object or not Row.Object.Parent then return end
	local Root = self.Document:GetRoot(Object)
	if Root and self.Document:IsLocked(Root) then return end

	local Existing = Row.Object:FindFirstChild('_FORGERenameBox')
	if Existing then
		pcall(function() Existing:CaptureFocus() end)
		return
	end

	Row.Label.Visible = false
	local Box = Widgets.TextBox(Row.Object, Object.Name)
	Box.Name = '_FORGERenameBox'
	Box.Position = UDim2.fromOffset(18 + (Depth or 0) * 13, 2)
	Box.Size = UDim2.new(1, -(RightReserve or 72) - (Depth or 0) * 13, 1, -4)
	Box.ZIndex = Row.Object.ZIndex + 8
	Box.ClearTextOnFocus = false
	Box:CaptureFocus()
	Box.CursorPosition = #Box.Text + 1

	local Finished = false
	local function Finish(Commit)
		if Finished then return end
		Finished = true
		local Value = Box.Text
		if Box.Parent then Box:Destroy() end
		if Row.Label.Parent then Row.Label.Visible = true end
		if Commit then self:_RenameHierarchyObject(Object, Value) end
	end

	Box.FocusLost:Connect(function(EnterPressed)
		Finish(EnterPressed or Box.Text ~= Object.Name)
	end)
	Box.InputBegan:Connect(function(Input)
		if Input.KeyCode == Enum.KeyCode.Escape then Finish(false) end
	end)
end

function App:_RefreshChildren()
	local Preserve = {[self.ChildLayout] = true}
	Clear(self.ChildList, Preserve)
	table.clear(self.ChildRows)
	table.clear(self.ChildDisplayOrder)

	local Root = self.Selection.Root
	if not Root then
		local Empty = Widgets.Label(self.ChildList, '(select a root)', 11, false)
		Empty.TextColor3 = Theme.Color.TextMuted
		Empty.Size = UDim2.new(1, 0, 0, Theme.Metric.RowHeight)
		return
	end

	if self.Selection:Count() > 1 then
		local Empty = Widgets.Label(self.ChildList, '(multiple roots selected)', 11, false)
		Empty.TextColor3 = Theme.Color.TextMuted
		Empty.Size = UDim2.new(1, 0, 0, Theme.Metric.RowHeight)
		return
	end

	local Searching = (self.ChildrenSearch.Text or '') ~= ''
	local Order = 0

	local function AddChildren(Parent, Depth)
		for _, Child in ipairs(self:_VisibleHierarchyChildren(Parent)) do
			local BranchMatches = not Searching or self:_HierarchyBranchMatches(Child)
			if not BranchMatches then continue end

			local Children = self:_VisibleHierarchyChildren(Child)
			local HasChildren = #Children > 0
			local Collapsed = self.CollapsedChildren[Child] == true and not Searching
			local ShowRow = not Searching or self:_ChildMatchesSearch(Child) or HasChildren

			if ShowRow then
				Order += 1
				local Slot = Child:GetAttribute('FORGESlotName')
				local IsContent = Child:GetAttribute('FORGESlotContent') == true
				local Kind = Child:GetAttribute('FORGESimpleKind')
				local Suffix = Slot and ('  |  ' .. Slot)
					or IsContent and '  |  content'
					or Kind and ('  |  ' .. tostring(Kind))
					or ''
				local Row = Widgets.TreeRow(self.ChildList, Child.Name .. Suffix, Depth)
				Row.Object.LayoutOrder = Order
				table.insert(self.ChildDisplayOrder, Child)
				Widgets.SetTreeRowSelected(
					Row,
					self.Selection.IsChildSelected and self.Selection:IsChildSelected(Child),
					self.Selection.Child == Child
				)

				if HasChildren then
					Row.Icon.BackgroundTransparency = 1
					Row.Icon.Position = UDim2.fromOffset(3 + Depth * 13, 5)
					Row.Icon.Size = UDim2.fromOffset(12, 12)
					Row.Icon.Text = Collapsed and '›' or '⌄'
					Row.Icon.TextColor3 = Theme.Color.TextMuted
					Row.Icon.TextSize = 12
					Row.Icon.MouseButton1Click:Connect(function()
						self:_SetHierarchyCollapsed(Child, not Collapsed)
					end)
				else
					Row.Icon.Text = ''
					Row.Icon.AutoButtonColor = false
				end

				local RenameButton = Widgets.SmallButton(Row.Object, '✎')
				RenameButton.AnchorPoint = Vector2.new(1, .5)
				RenameButton.Position = UDim2.new(1, -25, .5, 0)
				RenameButton.Size = UDim2.fromOffset(20, Theme.Metric.RowHeight - 4)
				RenameButton.MouseButton1Click:Connect(function()
					self:_BeginHierarchyRename(Child, Row, Suffix, Depth, 76)
				end)

				local InsertButton = Widgets.SmallButton(Row.Object, '+')
				InsertButton.AnchorPoint = Vector2.new(1, .5)
				InsertButton.Position = UDim2.new(1, -3, .5, 0)
				InsertButton.Size = UDim2.fromOffset(20, Theme.Metric.RowHeight - 4)
				InsertButton.MouseButton1Down:Connect(function(X, Y)
					self:_OpenInsertForTarget(Child, X, Y)
				end)

				Row.Label.Size = UDim2.new(1, -76 - Depth * 13, 1, 0)
				Row.Object.MouseButton1Down:Connect(function(X, Y)
					if self:_IsShiftHeld() or self:_IsControlHeld() then
						self:_SelectHierarchyChild(Child)
						return
					end
					self:_BeginHierarchyDrag(Child, Vector2.new(X, Y))
				end)
				self.ChildRows[Child] = Row
			end

			if HasChildren and not Collapsed then AddChildren(Child, Depth + 1) end
		end
	end

	AddChildren(Root, 0)
end

function App:_GetPropertyTargets(Property)
	local Children = self.Selection.GetChildren and self.Selection:GetChildren() or {}
	if #Children > 0 then
		if Property == 'Name' then return self.Selection.Child and {self.Selection.Child} or {} end
		return Children
	end

	if self.Selection:Count() <= 1 or Property == 'Name' then
		return self.Selection.Root and {self.Selection.Root} or {}
	end

	return self.Selection:GetRoots()
end

function App:_ApplyProperty(Property, Value, Label)
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()
	local Changed = false

	for _, Target in ipairs(self:_GetPropertyTargets(Property)) do
		local Root = self.Document:GetRoot(Target)
		if not Root or not self.Document:IsLocked(Root) then
			if Root and Property == 'Position' then Root:SetAttribute('FORGESnapTarget', nil) end
			local Success = pcall(function()
				Target[Property] = Value
			end)
			Changed = Changed or Success
		end
	end

	if Changed then
		self:_RecordHistory(Label or ('Set ' .. Property))
		if Property == 'Name' then
			self:_RefreshAll()
		else
			self:_RefreshSelectionDetails(Property == 'Position' or Property == 'Size' or Property == 'AutomaticSize')
		end
	end

	return Changed
end

function App:_ShowEnumDropdown(Button, Property, Value)
	local Success, Items = pcall(function()
		return Value.EnumType:GetEnumItems()
	end)
	if not Success or not Items or #Items == 0 then return end

	self:_ShowChoicePopup(Button, Items, Value, function(Item)
		self:_ApplyProperty(Property, Item)
	end, function(Item)
		return tostring(Item):match('%.([^%.]+)$') or tostring(Item)
	end)
end
function App:_FindTransparencyGradient(Object)
	if not Object then return nil, false end

	local Owned = Object:FindFirstChild('_FORGETransparencyGradient')
	if Owned and Owned:IsA('UIGradient') then return Owned, true end

	local Base = Object:FindFirstChild('_FORGEBaseGradient')
	if Base and Base:IsA('UIGradient') then return Base, false end

	for _, Child in ipairs(Object:GetChildren()) do
		if Child:IsA('UIGradient') then return Child, false end
	end
	return nil, false
end

function App:_EnsureTransparencyGradient(Object)
	local Gradient, Owned = self:_FindTransparencyGradient(Object)
	if Gradient then return Gradient, Owned end

	Gradient = Instance.new('UIGradient')
	Gradient.Name = '_FORGETransparencyGradient'
	Gradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
	Gradient.Transparency = NumberSequence.new(0)
	Gradient.Rotation = 0
	Gradient:SetAttribute('FORGEStyleInternal', true)
	Gradient:SetAttribute('FORGEHierarchyInternal', true)
	Gradient.Parent = Object
	return Gradient, true
end

function App:_ApplyTransparencyGradientToObject(Object, Preset)
	if not SupportsTransparencyGradient(Object) then return false end
	Preset = tostring(Preset or 'None')
	local ExistingPreset = Object:GetAttribute('FORGETransparencyGradientPreset') or 'None'
	local Gradient, Owned = self:_FindTransparencyGradient(Object)

	if Preset == 'None' then
		if ExistingPreset == 'None' and not (Gradient and Owned) then return false end

		if Gradient then
			if Owned then
				Gradient:Destroy()
			else
				local OriginalTransparency = Object:GetAttribute('FORGETransparencyGradientOriginalTransparency')
				local OriginalRotation = Object:GetAttribute('FORGETransparencyGradientOriginalRotation')
				Gradient.Transparency = typeof(OriginalTransparency) == 'NumberSequence'
					and OriginalTransparency
					or NumberSequence.new(0)
				if type(OriginalRotation) == 'number' then Gradient.Rotation = OriginalRotation end
			end
		end

		Object:SetAttribute('FORGETransparencyGradientPreset', nil)
		Object:SetAttribute('FORGETransparencyGradientRotation', nil)
		Object:SetAttribute('FORGETransparencyGradientSequence', nil)
		Object:SetAttribute('FORGETransparencyGradientOriginalTransparency', nil)
		Object:SetAttribute('FORGETransparencyGradientOriginalRotation', nil)
		return true
	end

	local Sequence = TransparencyGradientPresets[Preset]
	if not Sequence then return false end

	Gradient, Owned = self:_EnsureTransparencyGradient(Object)
	if not Gradient then return false end

	if ExistingPreset == 'None' and not Owned then
		pcall(function()
			Object:SetAttribute('FORGETransparencyGradientOriginalTransparency', Gradient.Transparency)
		end)
		Object:SetAttribute('FORGETransparencyGradientOriginalRotation', Gradient.Rotation)
	end

	local Rotation = tonumber(Object:GetAttribute('FORGETransparencyGradientRotation'))
	if Rotation == nil then Rotation = Gradient.Rotation end

	Gradient.Transparency = Sequence
	Gradient.Rotation = Rotation
	Object:SetAttribute('FORGETransparencyGradientPreset', Preset)
	Object:SetAttribute('FORGETransparencyGradientRotation', Rotation)
	pcall(function()
		Object:SetAttribute('FORGETransparencyGradientSequence', Sequence)
	end)
	return ExistingPreset ~= Preset or Gradient.Transparency ~= Sequence
end

function App:_ApplyTransparencyGradientPreset(Preset)
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()

	local Changed = false
	for _, Object in ipairs(self:_GetPropertyTargets('TransparencyGradient')) do
		if SupportsTransparencyGradient(Object) then
			local Root = self.Document:GetRoot(Object)
			if not Root or not self.Document:IsLocked(Root) then
				Changed = self:_ApplyTransparencyGradientToObject(Object, Preset) or Changed
			end
		end
	end

	if Changed then
		self:_RecordHistory('Set Transparency Gradient')
		self:_RefreshSelectionDetails(false)
	end
	return Changed
end

function App:_SetTransparencyGradientRotation(Value)
	Value = tonumber(Value)
	if Value == nil then return false end

	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()

	local Changed = false
	for _, Object in ipairs(self:_GetPropertyTargets('TransparencyGradientRotation')) do
		if SupportsTransparencyGradient(Object)
			and (Object:GetAttribute('FORGETransparencyGradientPreset') or 'None') ~= 'None'
		then
			local Root = self.Document:GetRoot(Object)
			if not Root or not self.Document:IsLocked(Root) then
				local Gradient = self:_FindTransparencyGradient(Object)
				if Gradient then
					Gradient.Rotation = Value
					Object:SetAttribute('FORGETransparencyGradientRotation', Value)
					Changed = true
				end
			end
		end
	end

	if Changed then
		self:_RecordHistory('Set Transparency Gradient Rotation')
		self:_RefreshSelectionDetails(false)
	end
	return Changed
end

function App:_AppendTransparencyGradientProperties(Target, LayoutOrder, Query)
	if not SupportsTransparencyGradient(Target) then return LayoutOrder end

	local function Matches(Value)
		return Query == '' or string.find(string.lower(Value), Query, 1, true) ~= nil
	end

	local ShowPreset = Matches('transparency gradient preset fade')
	local Preset = Target:GetAttribute('FORGETransparencyGradientPreset') or 'None'
	local ShowRotation = Preset ~= 'None' and Matches('transparency gradient rotation degrees')
	if not ShowPreset and not ShowRotation then return LayoutOrder end

	local Header = Widgets.SectionRow(self.PropertiesList, 'Transparency Gradient')
	Header.LayoutOrder = LayoutOrder
	LayoutOrder += 1

	if ShowPreset then
		local Row = Instance.new('Frame')
		Row.BackgroundTransparency = 1
		Row.BorderSizePixel = 0
		Row.Size = UDim2.new(1, 0, 0, Theme.Metric.RowHeight)
		Row.LayoutOrder = LayoutOrder
		Row.Parent = self.PropertiesList

		local Label = Widgets.Label(Row, 'Preset', 11, false)
		Label.Position = UDim2.fromOffset(8, 0)
		Label.Size = UDim2.new(.42, -10, 1, 0)
		Label.TextColor3 = Theme.Color.TextMuted

		local Button = Widgets.DropdownButton(Row, Preset)
		Button.Position = UDim2.new(.42, 1, 0, 0)
		Button.Size = UDim2.new(.58, -1, 1, 0)
		Button.MouseButton1Click:Connect(function()
			self:_ShowChoicePopup(Button, TransparencyGradientPresetOrder, Preset, function(NewPreset)
				self:_ApplyTransparencyGradientPreset(NewPreset)
			end)
		end)
		LayoutOrder += 1
	end

	if ShowRotation then
		local Rotation = tonumber(Target:GetAttribute('FORGETransparencyGradientRotation'))
		local Gradient = self:_FindTransparencyGradient(Target)
		if Rotation == nil and Gradient then Rotation = Gradient.Rotation end
		Rotation = Rotation or 0

		local Row, Box = Widgets.PropertyRow(self.PropertiesList, 'Rotation', Format(Rotation))
		Row.LayoutOrder = LayoutOrder
		Box.FocusLost:Connect(function()
			local Number = tonumber(Box.Text)
			if Number ~= nil then
				self:_SetTransparencyGradientRotation(Number)
			else
				self:_RefreshProperties()
			end
		end)
		LayoutOrder += 1
	end

	return LayoutOrder
end

function App:_SetStyledInsetEnabled(Value)
	Value = Value == true
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()

	local Changed = false
	for _, Object in ipairs(self:_GetPropertyTargets('InsetEnabled')) do
		if Object:IsA('GuiObject') and Object:GetAttribute('FORGEStyleSurface') then
			local Root = self.Document:GetRoot(Object)
			if not Root or not self.Document:IsLocked(Root) then
				if Object:GetAttribute('FORGEInsetEnabled') ~= Value then
					Object:SetAttribute('FORGEInsetEnabled', Value)
					local SurfaceName = Object:GetAttribute('FORGEStyleSurface')
					local PackName = Object:GetAttribute('FORGEStylePack') or self.ActiveStylePack
					if self.ComponentPresets and self.ComponentPresets:IsSemantic(Object) then
						self.ComponentPresets:ApplySemantic(Object)
					elseif self.StylePacks then
						self.StylePacks:ApplySurface(Object, SurfaceName, PackName)
					end
					Changed = true
				end
			end
		end
	end

	if Changed then
		self:_RecordHistory(Value and 'Enable Inset' or 'Disable Inset')
		self:_RefreshSelectionDetails(false)
	end
	return Changed
end

function App:_AppendStyledSurfaceProperties(Target, LayoutOrder, Query)
	if not Target or not Target:IsA('GuiObject') or not Target:GetAttribute('FORGEStyleSurface') then return LayoutOrder end
	if self.ComponentPresets and self.ComponentPresets:IsSemantic(Target) then return LayoutOrder end

	local Search = string.lower(Query or '')
	if Search ~= '' and not string.find('surface inset enabled outline border', Search, 1, true) then return LayoutOrder end

	local Header = Widgets.SectionRow(self.PropertiesList, 'Surface')
	Header.LayoutOrder = LayoutOrder
	LayoutOrder += 1

	local Enabled = Target:GetAttribute('FORGEInsetEnabled') ~= false
	local Row, Button = Widgets.PropertyBoolean(self.PropertiesList, 'Inset Enabled', Enabled)
	Row.LayoutOrder = LayoutOrder
	Button.MouseButton1Click:Connect(function()
		self:_SetStyledInsetEnabled(not Enabled)
	end)
	return LayoutOrder + 1
end

function App:_AppendModifierProperties(Target, LayoutOrder, Query)
	if not self.Modifiers or not Target or not Target:IsA('GuiObject') then return LayoutOrder end

	local function Matches(Value)
		return Query == '' or string.find(string.lower(Value), Query, 1, true) ~= nil
	end

	local Active = {}
	for _, Name in ipairs(self.Modifiers:GetNames()) do
		if self.Modifiers:Has(Target, Name) then table.insert(Active, Name) end
	end

	if #Active == 0 and not Matches('modifier array') then return LayoutOrder end

	local Header = Widgets.SectionRow(self.PropertiesList, 'Modifiers')
	Header.LayoutOrder = LayoutOrder
	LayoutOrder += 1

	local AddRow = Instance.new('Frame')
	AddRow.BackgroundTransparency = 1
	AddRow.BorderSizePixel = 0
	AddRow.Size = UDim2.new(1, 0, 0, Theme.Metric.RowHeight + 4)
	AddRow.LayoutOrder = LayoutOrder
	AddRow.Parent = self.PropertiesList
	local Add = Widgets.Button(AddRow, '+ Add Modifier')
	Add.Position = UDim2.fromOffset(4, 2)
	Add.Size = UDim2.new(1, -8, 1, -4)
	Add.TextXAlignment = Enum.TextXAlignment.Left
	Add:SetAttribute('FORGETextInsetLeft', 10)
	Add.MouseButton1Click:Connect(function()
		local Names = self.Modifiers:GetNames()
		self:_ShowChoicePopup(Add, Names, nil, function(Name)
			if self.Modifiers:Add(Target, Name) then
				self.Modifiers:Apply(Target)
				self:_RecordHistory('Add ' .. Name .. ' Modifier')
				self:_RefreshAll()
			end
		end)
	end)
	LayoutOrder += 1

	for _, Name in ipairs(Active) do
		local Definition = self.Modifiers:GetDefinition(Name)
		if Definition and Matches(Name .. ' modifier ' .. tostring(Definition.Description or '')) then
			local TitleRow = Instance.new('Frame')
			TitleRow.BackgroundColor3 = Theme.Color.PropertyName
			TitleRow.BorderSizePixel = 0
			TitleRow.Size = UDim2.new(1, 0, 0, Theme.Metric.RowHeight + 4)
			TitleRow.LayoutOrder = LayoutOrder
			TitleRow.Parent = self.PropertiesList

			local Label = Widgets.Label(TitleRow, 'MOD  ' .. tostring(Definition.DisplayName or Name), 11, true)
			Label.Position = UDim2.fromOffset(8, 0)
			Label.Size = UDim2.new(1, -74, 1, 0)
			Label.TextColor3 = Theme.Color.Text

			local Remove = Widgets.SmallButton(TitleRow, 'Remove')
			Remove.AnchorPoint = Vector2.new(1, .5)
			Remove.Position = UDim2.new(1, -4, .5, 0)
			Remove.Size = UDim2.fromOffset(58, Theme.Metric.RowHeight - 4)
			Remove.MouseButton1Click:Connect(function()
				if self.Modifiers:Remove(Target, Name) then
					self:_RecordHistory('Remove ' .. Name .. ' Modifier')
					self:_RefreshAll()
				end
			end)
			LayoutOrder += 1

			for _, Field in ipairs(Definition.Fields or {}) do
				if Matches(Field.Label or Field.Key) then
					local Value = self.Modifiers:GetValue(Target, Name, Field.Key)
					local Row, Box = Widgets.PropertyRow(self.PropertiesList, Field.Label or Field.Key, Format(Value))
					Row.LayoutOrder = LayoutOrder
					Box.FocusLost:Connect(function()
						local NewValue = Field.Type == 'number' and tonumber(Box.Text) or Box.Text
						if NewValue ~= nil and self.Modifiers:SetValue(Target, Name, Field.Key, NewValue) then
							self.Modifiers:Apply(Target)
							self:_RecordHistory('Set ' .. Name .. ' ' .. Field.Key)
							self:_RefreshAll()
						else
							Box.Text = Format(self.Modifiers:GetValue(Target, Name, Field.Key))
						end
					end)
					LayoutOrder += 1
				end
			end
		end
	end

	return LayoutOrder
end

function App:_RefreshProperties()
	local Preserve = {[self.PropertiesLayout] = true}
	Clear(self.PropertiesList, Preserve)

	local Target = self.Selection:GetTarget()
	if not Target then
		self.PropertiesTitle.Text = 'Properties'
		return
	end

	local Kind = self.ComponentPresets
		and self.ComponentPresets:IsSemantic(Target)
		and Target:GetAttribute('FORGESimpleKind')
		or nil

	self.PropertiesTitle.Text = self.Selection:Count() > 1 and not self.Selection.Child
		and ('Properties | ' .. tostring(self.Selection:Count()) .. ' selected')
		or ('Properties | ' .. tostring(Kind or Target.Name))

	local LayoutOrder = 1
	local Query = string.lower(self.PropertiesSearch.Text or '')

	local function Matches(Name)
		return Query == '' or string.find(string.lower(Name), Query, 1, true) ~= nil
	end

	local function AddSection(Name)
		local Row = Widgets.SectionRow(self.PropertiesList, Name)
		Row.LayoutOrder = LayoutOrder
		LayoutOrder += 1
	end

	local function CommitSemantic(Key, Value, Label)
		if not self.ComponentPresets then return end
		local Root = self.Document:GetRoot(Target)
		if Root and self.Document:IsLocked(Root) then return end

		if self.ComponentPresets:SetSemanticValue(Target, Key, Value) then
			if Key == 'Position' and Root then Root:SetAttribute('FORGESnapTarget', nil) end
			self:_RecordHistory(Label or ('Set ' .. Key))
			self:_RefreshSelectionDetails(
				Key == 'Position' or Key == 'Size' or Key == 'Width' or Key == 'Height'
					or Key == 'Gap' or Key == 'Padding' or Key == 'AutoSize'
			)
		end
	end

	local function AddSemanticField(Descriptor)
		local Key, Label, Type = Descriptor[1], Descriptor[2], Descriptor[3]
		if not Matches(Label) then return end

		if Type == 'axis-position' or Type == 'axis-size' then
			local ValueText, Mode = self:_GetAxisEditorState(Target, Key)
			local Row, Box, Unit = Widgets.PropertyAxis(self.PropertiesList, Label, ValueText, Mode)
			Row.LayoutOrder = LayoutOrder
			local Modes = Type == 'axis-size' and {'px', '%', 'Auto'} or {'px', '%'}
			Unit.MouseButton1Click:Connect(function()
				self:_ShowChoicePopup(Unit, Modes, Mode, function(NewMode)
					local CurrentText = Box.Text
					if Mode == 'Auto' and NewMode ~= 'Auto' then
						local ParentSize = self:_GetLogicalSize(Target.Parent)
						local _, _, CurrentWidth, CurrentHeight = self:_GetObjectCanvasRect(Target)
						local IsX = Key == 'Width'
						local CurrentPixels = IsX and CurrentWidth or CurrentHeight
						if NewMode == '%' then
							local ParentAxis = math.max(IsX and ParentSize.X or ParentSize.Y, 1)
							CurrentText = tostring(CurrentPixels / ParentAxis * 100)
						else
							CurrentText = tostring(CurrentPixels)
						end
					end
					if self:_SetAxisEditorState(Target, Key, CurrentText, NewMode) then
						self:_RecordHistory('Set ' .. Label)
						self:_RefreshAll()
					end
				end)
			end)
			Box.FocusLost:Connect(function()
				local Number = tonumber(Box.Text)
				if Mode == 'Auto' or Number ~= nil then
					if self:_SetAxisEditorState(Target, Key, Number or 0, Mode) then
						self:_RecordHistory('Set ' .. Label)
						self:_RefreshAll()
					end
				else
					self:_RefreshProperties()
				end
			end)
			LayoutOrder += 1
			return
		end

		local Value = self.ComponentPresets:GetSemanticValue(Target, Key)
		if Value == nil then return end

		if Type == 'choice' then
			local Options = Descriptor[4] or {}
			local Row = Instance.new('Frame')
			Row.BackgroundTransparency = 1
			Row.BorderSizePixel = 0
			Row.Size = UDim2.new(1, 0, 0, Theme.Metric.RowHeight)
			Row.LayoutOrder = LayoutOrder
			Row.Parent = self.PropertiesList
			local NameLabel = Widgets.Label(Row, Label, 11, false)
			NameLabel.Position = UDim2.fromOffset(8, 0)
			NameLabel.Size = UDim2.new(.42, -10, 1, 0)
			NameLabel.TextColor3 = Theme.Color.TextMuted
			local Button = Widgets.DropdownButton(Row, tostring(Value))
			Button.Position = UDim2.new(.42, 1, 0, 0)
			Button.Size = UDim2.new(.58, -1, 1, 0)
			Button.MouseButton1Click:Connect(function()
				self:_ShowChoicePopup(Button, Options, Value, function(NewValue)
					CommitSemantic(Key, NewValue, 'Set ' .. Label)
				end)
			end)
		elseif Type == 'boolean' then
			local Row, Button = Widgets.PropertyBoolean(self.PropertiesList, Label, Value)
			Row.LayoutOrder = LayoutOrder
			Button.MouseButton1Click:Connect(function()
				CommitSemantic(Key, not Value, 'Set ' .. Label)
			end)
		elseif Type == 'Color3' then
			local Row, Box, Swatch = Widgets.PropertyColor(self.PropertiesList, Label, Value, Format(Value))
			Row.LayoutOrder = LayoutOrder

			Swatch.MouseButton1Click:Connect(function()
				self.ColorSemanticOverride = {Object = Target, Key = Key, Label = Label}
				self.ColorPropertyOverride = nil
				self:_RefreshColor()
			end)

			Box.FocusLost:Connect(function()
				local Parsed = Parse(Box.Text, Value)
				if Parsed then CommitSemantic(Key, Parsed, 'Set ' .. Label)
				else Box.Text = Format(self.ComponentPresets:GetSemanticValue(Target, Key)) end
			end)
		else
			local Row, Box = Widgets.PropertyRow(self.PropertiesList, Label, Format(Value))
			Row.LayoutOrder = LayoutOrder

			Box.FocusLost:Connect(function()
				local Parsed
				if Type == 'string' then
					Parsed = Box.Text
				elseif Type == 'number' then
					Parsed = tonumber(Box.Text)
				elseif Type == 'UDim2' then
					Parsed = Parse(Box.Text, Value)
				else
					Parsed = Parse(Box.Text, Value)
				end

				if Parsed ~= nil then CommitSemantic(Key, Parsed, 'Set ' .. Label)
				else Box.Text = Format(self.ComponentPresets:GetSemanticValue(Target, Key)) end
			end)
		end

		LayoutOrder += 1
	end

	if Kind then
		local Schema = self.ComponentPresets:GetSemanticSchema(Target) or {}
		for _, Section in ipairs(Schema) do
			local VisibleFields = {}
			for _, Descriptor in ipairs(Section[2] or {}) do
				if Matches(Descriptor[2]) then table.insert(VisibleFields, Descriptor) end
			end

			if #VisibleFields > 0 then
				AddSection(Section[1])
				for _, Descriptor in ipairs(VisibleFields) do AddSemanticField(Descriptor) end
			end
		end
		LayoutOrder = self:_AppendTransparencyGradientProperties(Target, LayoutOrder, Query)
		LayoutOrder = self:_AppendModifierProperties(Target, LayoutOrder, Query)
		return
	end

	local Groups = {
		{'Layout', {'Position', 'Size', 'AnchorPoint', 'Visible', 'Rotation', 'ZIndex'}},
		{'Appearance', {'BackgroundColor3', 'BackgroundTransparency', 'ClipsDescendants'}},
		{'Text', {'Text', 'TextColor3', 'TextTransparency', 'TextSize', 'TextXAlignment', 'TextYAlignment'}},
		{'Image', {'Image', 'ImageColor3', 'ImageTransparency', 'ScaleType'}}
	}

	local function SupportsVisual(Property)
		if Property == 'Text' or Property == 'TextColor3' or Property == 'TextTransparency'
			or Property == 'TextSize' or Property == 'TextXAlignment' or Property == 'TextYAlignment' then
			return Target:IsA('TextLabel') or Target:IsA('TextButton') or Target:IsA('TextBox')
		end

		if Property == 'Image' or Property == 'ImageColor3' or Property == 'ImageTransparency' or Property == 'ScaleType' then
			return Target:IsA('ImageLabel') or Target:IsA('ImageButton')
		end

		if Property == 'BackgroundColor3' or Property == 'BackgroundTransparency' or Property == 'ClipsDescendants'
			or Property == 'Position' or Property == 'Size' or Property == 'AnchorPoint'
			or Property == 'Visible' or Property == 'Rotation' or Property == 'ZIndex' then
			return Target:IsA('GuiObject')
		end

		return false
	end

	for _, Group in ipairs(Groups) do
		local Fields = {}
		for _, Property in ipairs(Group[2]) do
			if Matches(Property) and SupportsVisual(Property) then table.insert(Fields, Property) end
		end
		if #Fields == 0 then continue end

		AddSection(Group[1])
		for _, Property in ipairs(Fields) do
			local Success, Value = pcall(function() return Target[Property] end)
			if not Success then continue end

			local Type = typeof(Value)
			if Type == 'boolean' then
				local Row, Button = Widgets.PropertyBoolean(self.PropertiesList, Property, Value)
				Row.LayoutOrder = LayoutOrder
				Button.MouseButton1Click:Connect(function()
					self:_ApplyProperty(Property, not Value)
				end)
			elseif Type == 'Color3' then
				local Row, Box, Swatch = Widgets.PropertyColor(self.PropertiesList, Property, Value, Format(Value))
				Row.LayoutOrder = LayoutOrder
				Swatch.MouseButton1Click:Connect(function()
					self.ColorSemanticOverride = nil
					self.ColorPropertyOverride = Property
					self:_RefreshColor()
				end)
				Box.FocusLost:Connect(function()
					local Parsed = Parse(Box.Text, Value)
					if Parsed then self:_ApplyProperty(Property, Parsed)
					else Box.Text = Format(Target[Property]) end
				end)
			elseif Type == 'EnumItem' then
				local Row, Button = Widgets.PropertyEnum(self.PropertiesList, Property, Value)
				Row.LayoutOrder = LayoutOrder
				Button.MouseButton1Click:Connect(function()
					self:_ShowEnumDropdown(Button, Property, Value)
				end)
			else
				local Row, Box = Widgets.PropertyRow(self.PropertiesList, Property, Format(Value))
				Row.LayoutOrder = LayoutOrder
				Box.FocusLost:Connect(function()
					local Parsed = Type == 'string' and Box.Text or Parse(Box.Text, Value)
					if Parsed ~= nil then self:_ApplyProperty(Property, Parsed)
					else Box.Text = Format(Target[Property]) end
				end)
			end
			LayoutOrder += 1
		end
	end

	LayoutOrder = self:_AppendStyledSurfaceProperties(Target, LayoutOrder, Query)
	LayoutOrder = self:_AppendTransparencyGradientProperties(Target, LayoutOrder, Query)
	LayoutOrder = self:_AppendModifierProperties(Target, LayoutOrder, Query)
end
function App:_GetColorProperties()
	local Target = self.Selection:GetTarget()
	if not Target then return {} end

	if self.ComponentPresets and self.ComponentPresets:IsSemantic(Target) then
		local Result = {}
		if Target:GetAttribute('FORGEPrimaryColor') ~= nil then table.insert(Result, '@PrimaryColor') end
		if Target:GetAttribute('FORGESecondaryColor') ~= nil then table.insert(Result, '@SecondaryColor') end
		if Target:GetAttribute('FORGEShadowColor') ~= nil then table.insert(Result, '@ShadowColor') end
		if Target:GetAttribute('FORGETextStrokeColor') ~= nil then table.insert(Result, '@TextStrokeColor') end
		return Result
	end

	local Order = {'BackgroundColor3', 'TextColor3', 'ImageColor3'}
	if Target:IsA('TextLabel') or Target:IsA('TextButton') or Target:IsA('TextBox') then
		Order = {'TextColor3', 'BackgroundColor3'}
	elseif Target:IsA('ImageLabel') or Target:IsA('ImageButton') then
		Order = {'ImageColor3', 'BackgroundColor3'}
	end

	local Result = {}
	for _, Property in ipairs(Order) do
		local Success, Value = pcall(function() return Target[Property] end)
		if Success and typeof(Value) == 'Color3' then table.insert(Result, Property) end
	end
	return Result
end

function App:_GetColorProperty()
	local Properties = self:_GetColorProperties()
	if #Properties == 0 then return nil end

	if self.ColorSemanticOverride then
		local Target = self.Selection:GetTarget()
		local Property = '@' .. tostring(self.ColorSemanticOverride.Key)
		if self.ColorSemanticOverride.Object == Target and table.find(Properties, Property) then
			return Property
		end
	end

	if self.ColorPropertyOverride and table.find(Properties, self.ColorPropertyOverride) then
		return self.ColorPropertyOverride
	end

	self.ColorPropertyIndex = math.clamp(self.ColorPropertyIndex, 1, #Properties)
	return Properties[self.ColorPropertyIndex]
end

function App:_GetSelectedColorInfo()
	local Target = self.Selection:GetTarget()
	local Property = self:_GetColorProperty()
	if not Target or not Property then return nil end

	local Color
	local Label = Property
	if string.sub(Property, 1, 1) == '@' and self.ComponentPresets then
		local Key = string.sub(Property, 2)
		Color = self.ComponentPresets:GetSemanticValue(Target, Key)
		Label = Key == 'PrimaryColor' and 'Primary'
			or Key == 'SecondaryColor' and 'Secondary'
			or Key == 'ShadowColor' and 'Shadow'
			or Key == 'TextStrokeColor' and 'Text Stroke'
			or Key
	else
		local Success, Value = pcall(function() return Target[Property] end)
		if Success then Color = Value end
	end

	if typeof(Color) ~= 'Color3' then return nil end
	return Target, Property, Color, Label
end

function App:_RefreshColorRecents()
	if not self.ColorRecentButtons then return end
	for Index, Button in ipairs(self.ColorRecentButtons) do
		local Color = self.ColorRecent and self.ColorRecent[Index]
		Button.Visible = Color ~= nil
		if Color then
			Button.BackgroundTransparency = 0
			Button.BackgroundColor3 = Color
		else
			Button.BackgroundTransparency = 1
		end
	end
end

function App:_SaveRecentColors()
	if not self.Plugin then return end
	local Saved = {}
	for Index, Color in ipairs(self.ColorRecent or {}) do
		Saved[Index] = ColorToHex(Color)
	end
	pcall(function()
		self.Plugin:SetSetting('FORGEStudioRecentColors', Saved)
	end)
end

function App:_PushRecentColor(Color)
	if typeof(Color) ~= 'Color3' then return end
	self.ColorRecent = self.ColorRecent or {}
	local Hex = ColorToHex(Color)

	for Index = #self.ColorRecent, 1, -1 do
		if ColorToHex(self.ColorRecent[Index]) == Hex then
			table.remove(self.ColorRecent, Index)
		end
	end

	table.insert(self.ColorRecent, 1, Color)
	while #self.ColorRecent > 8 do table.remove(self.ColorRecent) end
	self:_RefreshColorRecents()
	self:_SaveRecentColors()
end

function App:_RefreshColor()
	local Target, Property, Color, Label = self:_GetSelectedColorInfo()
	if not Target then
		self.ColorTargetButton.Text = 'No color'
		self.ColorPreview.BackgroundColor3 = Theme.Color.Window
		self.ColorPreviousPreview.BackgroundColor3 = Theme.Color.Window
		self.ColorHexBox.Text = '-'
		for _, Box in ipairs(self.ColorBoxes or {}) do Box.Text = '-' end
		for _, Box in ipairs(self.ColorHSVBoxes or {}) do Box.Text = '-' end
		self:_RefreshColorRecents()
		return
	end

	if self.ColorPropertyObject ~= Target or self.ColorPropertyName ~= Property then
		self.ColorPropertyObject = Target
		self.ColorPropertyName = Property
		self.ColorPrevious = Color
	end

	local H, S, V = Color:ToHSV()
	self.ColorHueValue = H
	self.ColorTargetButton.Text = Label
	self.ColorPreview.BackgroundColor3 = Color
	self.ColorPreviousPreview.BackgroundColor3 = self.ColorPrevious or Color
	self.ColorSV.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
	self.ColorSVPointer.Position = UDim2.fromScale(S, 1 - V)
	if self.ColorSVPointerShadow then self.ColorSVPointerShadow.Position = UDim2.fromScale(S, 1 - V) end
	self.ColorHuePointer.Position = UDim2.fromScale(H, .5)
	self.ColorHexBox.Text = ColorToHex(Color)
	self.ColorBoxes[1].Text = tostring(Round(Color.R * 255))
	self.ColorBoxes[2].Text = tostring(Round(Color.G * 255))
	self.ColorBoxes[3].Text = tostring(Round(Color.B * 255))
	self.ColorHSVBoxes[1].Text = tostring(Round(H * 360) % 360)
	self.ColorHSVBoxes[2].Text = tostring(Round(S * 100))
	self.ColorHSVBoxes[3].Text = tostring(Round(V * 100))
	self:_RefreshColorRecents()
end

function App:_SetSelectedColor(Color, PreviewOnly)
	if typeof(Color) ~= 'Color3' then return false end
	local Target, Property = self:_GetSelectedColorInfo()
	if not Target or not Property then return false end

	local Changed = false
	if string.sub(Property, 1, 1) == '@' and self.ComponentPresets then
		local Key = string.sub(Property, 2)
		Changed = self.ComponentPresets:SetSemanticValue(Target, Key, Color) == true
		if Changed and not PreviewOnly then self:_RecordHistory('Set ' .. Key) end
	else
		if PreviewOnly then
			for _, Candidate in ipairs(self:_GetPropertyTargets(Property)) do
				local Root = self.Document:GetRoot(Candidate)
				if not Root or not self.Document:IsLocked(Root) then
					local Success = pcall(function() Candidate[Property] = Color end)
					Changed = Changed or Success
				end
			end
		else
			Changed = self:_ApplyProperty(Property, Color, 'Set ' .. Property) == true
		end
	end

	if Changed then
		if PreviewOnly and self.ColorPickerDragging and self.ColorPickerDragStart then
			self.ColorPickerDragChanged = ColorToHex(Color) ~= ColorToHex(self.ColorPickerDragStart)
		elseif not PreviewOnly then
			self:_PushRecentColor(Color)
		end
		self:_RefreshColor()
	end
	return Changed
end

function App:_BeginColorPickerDrag(Kind)
	local _, _, Color = self:_GetSelectedColorInfo()
	if not Color then return false end
	self.ColorPickerDragging = Kind
	self.ColorPickerDragStart = Color
	self.ColorPickerDragChanged = false
	return true
end

function App:_FinishColorPickerDrag()
	if not self.ColorPickerDragging then return end
	local WasChanged = self.ColorPickerDragChanged == true
	self.ColorPickerDragging = nil
	self.ColorPickerDragStart = nil
	self.ColorPickerDragChanged = false

	if WasChanged then
		local _, Property, Color = self:_GetSelectedColorInfo()
		if Property and Color then
			local Label = string.sub(Property, 1, 1) == '@' and string.sub(Property, 2) or Property
			self:_RecordHistory('Set ' .. Label)
			self:_PushRecentColor(Color)
		end
	end
	self:_RefreshColor()
end

function App:_PickSV(X, Y)
	if not self.ColorSV then return end
	local Position, Size = self.ColorSV.AbsolutePosition, self.ColorSV.AbsoluteSize
	local S = math.clamp((X - Position.X) / math.max(Size.X, 1), 0, 1)
	local V = 1 - math.clamp((Y - Position.Y) / math.max(Size.Y, 1), 0, 1)
	self:_SetSelectedColor(Color3.fromHSV(self.ColorHueValue or 0, S, V), true)
end

function App:_PickHue(X, _)
	if not self.ColorHue then return end
	local Position, Size = self.ColorHue.AbsolutePosition, self.ColorHue.AbsoluteSize
	local H = math.clamp((X - Position.X) / math.max(Size.X, 1), 0, 1)
	local _, _, Current = self:_GetSelectedColorInfo()
	if not Current then return end
	local _, S, V = Current:ToHSV()
	self.ColorHueValue = H
	self:_SetSelectedColor(Color3.fromHSV(H, S, V), true)
end
function App:_UpdateStatus()
	if self.SaveState == 'Save Failed' then
		local Detail = tostring(self.SaveDetail or '')
		self.StatusLabel.Text = Detail ~= ''
			and ('SAVE FAILED: ' .. Detail)
			or 'SAVE FAILED: unknown persistence failure'
		return
	end

	local Root = self.Selection.Root
	local Child = self.Selection.Child
	local Count = self.Selection:Count()
	local Screen = self.DocumentScreen or self.Screens and self.Screens:GetCurrent()
	local ScreenText = Screen and ('   Screen: ' .. Screen) or ''
	local RuntimeText = '   Runtime: ' .. tostring(self.RuntimeSyncState or 'Unsynced')
	local SaveText = '   Save: ' .. tostring(self.SaveState or 'Unsaved')
	if self.SaveState == 'Save Failed' and self.SaveDetail and self.SaveDetail ~= '' then
		SaveText ..= ' (' .. string.sub(tostring(self.SaveDetail), 1, 90) .. ')'
	elseif self.LastSavedAt then
		SaveText ..= ' ' .. os.date('%H:%M:%S', self.LastSavedAt)
	end

	if not Root then
		self.StatusLabel.Text = string.format(
			'%d root object%s   %s   %d%%',
			#self.Document:GetRoots(),
			#self.Document:GetRoots() == 1 and '' or 's',
			self:_GetDevice().Name,
			Round(self.Zoom * 100)
		) .. ScreenText .. RuntimeText .. SaveText
		return
	end

	if Count > 1 then
		self.StatusLabel.Text = string.format(
			'%d roots selected   Primary: %s   %s   %d%%',
			Count,
			Root.Name,
			self:_GetDevice().Name,
			Round(self.Zoom * 100)
		) .. ScreenText .. RuntimeText .. SaveText
		return
	end

	local Text = 'Root: ' .. Root.Name .. '   Zone: ' .. self.Document:GetZone(Root)
	if Child then Text ..= '   Child: ' .. Child.Name end
	Text ..= '   ' .. self:_GetDevice().Name .. '   ' .. tostring(Round(self.Zoom * 100)) .. '%' .. ScreenText .. RuntimeText .. SaveText
	self.StatusLabel.Text = Text
end

function App:_CaptureRuntimePackage()
	if not self.Packaging then
		self:SetStatus('Runtime packaging module unavailable')
		return nil
	end

	local Success, Data = pcall(function()
		return self.Packaging:Capture(self)
	end)
	if not Success then
		self:SetStatus('Runtime package failed: ' .. tostring(Data))
		return nil
	end

	self.LastPackage = Data
	return Data
end

function App:_ValidateRuntimePackage()
	local Data = self:_CaptureRuntimePackage()
	if not Data or not self.Problems then return nil end

	local Success, Result = pcall(function()
		return self.Problems:Validate(Data)
	end)
	if not Success then
		self:SetStatus('Validation failed: ' .. tostring(Result))
		return nil
	end

	self.LastProblems = Result
	self:_RefreshProblems()
	self:_RefreshPackage()

	local Counts = self.Problems:Count(Result)
	self:SetStatus(string.format(
		'Runtime validation: %d error%s, %d warning%s',
		Counts.Error,
		Counts.Error == 1 and '' or 's',
		Counts.Warning,
		Counts.Warning == 1 and '' or 's'
	))
	return Result, Counts
end

function App:_NavigateProblem(Problem)
	if not Problem then return end

	if Problem.Screen and self.Screens and self.Screens:Has(Problem.Screen) then
		self:_LoadScreen(Problem.Screen)
		local Target = Problem.ObjectPath and self:_ResolveDocumentObjectPath(Problem.ObjectPath)
		if Target then
			local Root = self.Document:GetRoot(Target)
			if Root then
				self.Selection:SelectRoot(Root)
				if Target ~= Root then self.Selection:SelectChild(Target) end
			end
		end
	elseif Problem.Component and self.Components and self.Components:Has(Problem.Component) then
		self.SelectedComponent = Problem.Component
		self.SelectedVariant = Problem.Variant or 'Default'
		self:_RefreshComponents()
		self:_TogglePopup(self.ComponentsButton, self.ComponentsPopup)
	elseif Problem.Animation and self.Animations and self.Animations:Has(Problem.Animation) then
		self.SelectedAnimation = Problem.Animation
		self.SelectedTrack = Problem.Track
		self:_RefreshAnimations()
		self:_TogglePopup(self.AnimateButton, self.AnimationPopup)
	end
end

function App:_RefreshProblems()
	if not self.ProblemsList then return end
	Clear(self.ProblemsList, {[self.ProblemsLayout] = true})

	local Counts = self.Problems and self.Problems:Count(self.LastProblems or {})
		or {Error = 0, Warning = 0, Info = 0}
	self.ProblemsSummaryLabel.Text = string.format(
		'%d Error%s   %d Warning%s   %d Info',
		Counts.Error,
		Counts.Error == 1 and '' or 's',
		Counts.Warning,
		Counts.Warning == 1 and '' or 's',
		Counts.Info
	)

	if #(self.LastProblems or {}) == 0 then
		local Label = Widgets.Label(self.ProblemsList, 'No problems. Validate to refresh.', 10, false)
		Label.Size = UDim2.new(1, -4, 0, 24)
		Label.LayoutOrder = 1
		Label.ZIndex = self.ProblemsPopup.ZIndex + 2
		return
	end

	for Index, Problem in ipairs(self.LastProblems) do
		local Context = Problem.Screen and (' [' .. Problem.Screen .. ']')
			or Problem.Component and (' [' .. Problem.Component .. ']')
			or Problem.Animation and (' [' .. Problem.Animation .. ']')
			or ''
		local Button = Widgets.Button(
			self.ProblemsList,
			string.format('%s  %s%s  %s', Problem.Severity, Problem.Code, Context, Problem.Message)
		)
		Button.Size = UDim2.new(1, -2, 0, 24)
		Button.LayoutOrder = Index
		Button.TextXAlignment = Enum.TextXAlignment.Left
		Button.ZIndex = self.ProblemsPopup.ZIndex + 2
		Button.MouseButton1Click:Connect(function()
			self:_NavigateProblem(Problem)
		end)
	end
end

function App:_RefreshFrameworkInspector()
	if not self.PackageSourceBox then return end

	local FORGEModule = ReplicatedStorage:FindFirstChild('FORGE')
	if not FORGEModule then
		self.PackageSourceBox.Text = 'Framework Inspector\n\nReplicatedStorage.FORGE was not found.'
		self:SetStatus('FORGE framework not found')
		return
	end

	if not RunService:IsRunning() then
		self.PackageSourceBox.Text = table.concat({
			'Framework Inspector',
			'',
			'Start Studio Play/Test to inspect the live FORGE runtime.',
			'The inspector reads FORGE.Inspect() directly and does not maintain separate state.'
		}, '\n')
		self:SetStatus('Framework Inspector ready for Play/Test')
		return
	end

	local Success, FORGE = pcall(require, FORGEModule)
	if not Success or type(FORGE) ~= 'table' or type(FORGE.Inspect) ~= 'function' then
		self.PackageSourceBox.Text = 'Framework Inspector\n\nUnable to load FORGE:\n' .. tostring(FORGE)
		self:SetStatus('Framework Inspector failed to load FORGE')
		return
	end

	local InspectSuccess, Snapshot = pcall(FORGE.Inspect)
	if not InspectSuccess or type(Snapshot) ~= 'table' then
		self.PackageSourceBox.Text = 'Framework Inspector\n\nFORGE.Inspect failed:\n' .. tostring(Snapshot)
		self:SetStatus('Framework Inspector failed')
		return
	end

	local Lines = {
		string.format('FORGE %s  |  %s/%s  |  %s',
			tostring(Snapshot.Version),
			tostring(Snapshot.Context and Snapshot.Context.Environment or '?'),
			tostring(Snapshot.Context and Snapshot.Context.Side or '?'),
			Snapshot.Health and Snapshot.Health.Healthy and 'HEALTHY' or 'ISSUES'
		),
		''
	}

	table.insert(Lines, string.format(
		'Components: %d  |  Network: %s  |  Services: %d  |  Routes: %d',
		#(Snapshot.Components or {}),
		Snapshot.Network and Snapshot.Network.Active and 'online' or 'offline',
		Snapshot.Network and tonumber(Snapshot.Network.Services) or 0,
		Snapshot.Network and tonumber(Snapshot.Network.Routes) or 0
	))

	local Stats = Snapshot.Network and Snapshot.Network.Stats or {}
	local StatParts = {}
	for Key, Value in pairs(Stats) do table.insert(StatParts, tostring(Key) .. '=' .. tostring(Value)) end
	table.sort(StatParts)
	if #StatParts > 0 then table.insert(Lines, 'Network stats: ' .. table.concat(StatParts, '  ')) end

	table.insert(Lines, '')
	table.insert(Lines, 'COMPONENTS')
	for _, Component in ipairs(Snapshot.Components or {}) do
		local Status = Component.Failed and 'FAILED'
			or Component.Started and 'STARTED'
			or Component.Initialized and 'INIT'
			or 'REGISTERED'
		table.insert(Lines, string.format(
			'  %-10s %-28s %s',
			tostring(Component.Kind),
			tostring(Component.Name),
			Status
		))
	end

	table.insert(Lines, '')
	table.insert(Lines, 'DEPENDENCIES')
	for _, Node in ipairs(Snapshot.Graph or {}) do
		local Requires = #(Node.Requires or {}) > 0 and table.concat(Node.Requires, ', ') or '-'
		table.insert(Lines, string.format('  %s -> %s', tostring(Node.Name), Requires))
	end

	local Tooling = Snapshot.Tooling or {}
	local MetricNames = {}
	for Name in pairs(Tooling.Metrics or {}) do table.insert(MetricNames, Name) end
	table.sort(MetricNames)

	table.insert(Lines, '')
	table.insert(Lines, 'METRICS')
	if #MetricNames == 0 then
		table.insert(Lines, '  -')
	else
		for _, Name in ipairs(MetricNames) do
			local Metric = Tooling.Metrics[Name]
			table.insert(Lines, string.format(
				'  %s  value=%s count=%s avg=%.3f',
				Name,
				tostring(Metric.Value),
				tostring(Metric.Count),
				tonumber(Metric.Average) or 0
			))
		end
	end

	local TestNames = {}
	for Name in pairs(Tooling.Tests or {}) do table.insert(TestNames, Name) end
	table.sort(TestNames)

	table.insert(Lines, '')
	table.insert(Lines, 'TESTS')
	if #TestNames == 0 then
		table.insert(Lines, '  -')
	else
		for _, Name in ipairs(TestNames) do
			local Definition = Tooling.Tests[Name]
			local Last = Definition.Last
			table.insert(Lines, string.format(
				'  %s  %s',
				Name,
				not Last and 'NOT RUN'
					or Last.Passed and 'PASS'
					or 'FAIL'
			))
		end
	end

	table.insert(Lines, '')
	table.insert(Lines, string.format('Recent traces: %d', #(Tooling.Traces or {})))

	for _, Issue in ipairs(Snapshot.Health and Snapshot.Health.Issues or {}) do
		table.insert(Lines, string.format(
			'  %s %s: %s',
			tostring(Issue.Severity),
			tostring(Issue.Code),
			tostring(Issue.Message)
		))
	end

	self.PackageSourceBox.Text = table.concat(Lines, '\n')
	self:SetStatus('Framework Inspector refreshed')
end

function App:_RefreshPackage()
	if not self.PackageInfoLabel then return end

	if self.PackageSaveStatusLabel then
		local Detail = tostring(self.SaveDetail or '')
		self.PackageSaveStatusLabel.Text = 'Project: ' .. tostring(self.SaveState or 'Unsaved')
			.. (Detail ~= '' and ('  •  ' .. Detail) or '')
	end
	local Counts = self.Problems and self.Problems:Count(self.LastProblems or {})
		or {Error = 0, Warning = 0, Info = 0}

	if self.RuntimePreview then
		self.PackageRuntimeButton.Text = 'Stop Runtime'
		self.RuntimePreviewButton.Text = 'Stop RT'
		Widgets.SetActive(self.RuntimePreviewButton, true)
	else
		self.PackageRuntimeButton.Text = 'UI Preview'
		self.RuntimePreviewButton.Text = 'Runtime'
		Widgets.SetActive(self.RuntimePreviewButton, false)
	end

	if self.LastPackage then
		self.PackageInfoLabel.Text = string.format(
			'%s v%d  |  FORGE.UI %s  |  %d screen%s  |  %d error%s, %d warning%s  |  %s\n%s',
			tostring(self.LastPackage.Schema),
			tonumber(self.LastPackage.Version) or 0,
			tostring(self.LastPackage.RuntimeAPI),
			#(self.LastPackage.ScreenOrder or {}),
			#(self.LastPackage.ScreenOrder or {}) == 1 and '' or 's',
			Counts.Error,
			Counts.Error == 1 and '' or 's',
			Counts.Warning,
			Counts.Warning == 1 and '' or 's',
			tostring(self.RuntimeSyncState or 'Unsynced'),
			tostring(self.RuntimeSyncDetail or '')
		)
	else
		self.PackageInfoLabel.Text = tostring(self.RuntimeSyncState or 'Unsynced') .. '\n' .. tostring(self.RuntimeSyncDetail or 'No runtime snapshot')
	end
end

function App:_ExportRuntimePackage()
	local Result, Counts = self:_ValidateRuntimePackage()
	if not Result or not Counts then return false end
	if Counts.Error > 0 then
		self:SetStatus('Export blocked by runtime validation errors')
		return false
	end

	local Folder = ReplicatedStorage:FindFirstChild('FORGEExports')
	if Folder and not Folder:IsA('Folder') then
		self:SetStatus('ReplicatedStorage.FORGEExports is not a Folder')
		return false
	end
	if not Folder then
		Folder = Instance.new('Folder')
		Folder.Name = 'FORGEExports'
		Folder.Parent = ReplicatedStorage
	end

	local Package, Error = self.Packaging:WritePackage(
		Folder,
		self.PackageNameBox and self.PackageNameBox.Text or 'RUCKUSUIProject',
		self.LastPackage
	)

	if not Package then
		self:SetStatus('Package export failed: ' .. tostring(Error))
		return false
	end

	if self.PackageSourceBox then
		local Success, Source = pcall(function() return Package.Runtime.Source end)
		self.PackageSourceBox.Text = Success and Source or ''
	end
	StudioSelection:Set({Package.Folder})
	self:SetStatus('Exported runtime + authoring package to ' .. Package.Folder:GetFullName())
	return true
end

function App:_ImportRuntimePackage()
	if not self.Packaging then return false end
	local Selected = StudioSelection:Get()
	local Module = Selected and Selected[1]
	local Data, Error = self.Packaging:ReadModule(Module)
	if not Data then
		self:SetStatus('Import failed: ' .. tostring(Error))
		return false
	end

	local Success, ImportError = self.Packaging:Import(self, Data)
	if not Success then
		self:SetStatus('Import failed: ' .. tostring(ImportError))
		return false
	end

	self.LastPackage = Data
	self.LastProblems = {}
	self:_ValidateRuntimePackage()
	self:_QueueAutoRuntimeSync('Import')
	self:_QueuePersistentSave('Import')
	self:SetStatus('Imported FORGE UI project package')
	return true
end

function App:_StopRuntimePreview()
	local Runtime = self.RuntimePreview
	self.RuntimePreview = nil
	if Runtime then pcall(function() Runtime:Destroy() end) end
	self:_RefreshPackage()
	return Runtime ~= nil
end

function App:_StartRuntimePreview()
	if self.RuntimePreview then return true end
	if self.InteractiveMode then self:_SetInteractiveMode(false) end
	local Result, Counts = self:_ValidateRuntimePackage()
	if not Result or not Counts or Counts.Error > 0 then
		if Counts and Counts.Error > 0 then self:SetStatus('Runtime Preview blocked by validation errors') end
		return false
	end

	if not Players.LocalPlayer then
		self:SetStatus('Runtime Preview requires a Studio Play/Test client; the generated package is valid for runtime')
		return false
	end

	local FORGE = ReplicatedStorage:FindFirstChild('FORGE')
	local EngineFolder = FORGE and FORGE:FindFirstChild('Engine')
	local UIModule = EngineFolder and EngineFolder:FindFirstChild('UI')
	local ProjectRuntimeModule = UIModule and UIModule:FindFirstChild('ProjectRuntime')
	if not UIModule or not ProjectRuntimeModule then
		self:SetStatus('FORGE.UI ProjectRuntime is unavailable in this place')
		return false
	end

	local Success, RuntimeOrError = pcall(function()
		local UI = require(UIModule)
		local ProjectRuntime = require(ProjectRuntimeModule)
		local RuntimeData = self.Packaging:RuntimeView(self.LastPackage)
		local Runtime = ProjectRuntime.new(UI, RuntimeData, {
			Data = self.MockData and self.MockData:Get() or {},
			Layer = 'FORGEStudioRuntimePreview',
			ZOrder = 10000
		})
		assert(Runtime:Mount(), 'Start screen could not mount')
		return Runtime
	end)

	if not Success then
		self:SetStatus('Runtime Preview failed: ' .. tostring(RuntimeOrError))
		return false
	end

	self.RuntimePreview = RuntimeOrError
	self:_RefreshPackage()
	self:SetStatus('True Runtime Preview mounted through FORGE.UI')
	return true
end

function App:_ToggleRuntimePreview()
	if self.RuntimePreview then
		self:_StopRuntimePreview()
		self:SetStatus('Runtime Preview stopped')
		return
	end
	self:_StartRuntimePreview()
end

function App:_ResolveLayoutsForRoot(Root)
	if not Root or not self.ComponentPresets or not self.ComponentPresets.ResolveLayouts then return end
	self.ComponentPresets:ResolveLayouts(Root, self:_GetLogicalSize(Root.Parent))
end

function App:_RepairSemanticTree(Root)
	if not Root or not self.ComponentPresets then return end

	local function CaptureAppearance(Object)
		local State = {
			Visible = Object.Visible,
			BackgroundTransparency = Object.BackgroundTransparency
		}
		if Object:IsA('TextLabel') or Object:IsA('TextButton') or Object:IsA('TextBox') then
			State.TextTransparency = Object.TextTransparency
		end
		if Object:IsA('ImageLabel') or Object:IsA('ImageButton') then
			State.ImageTransparency = Object.ImageTransparency
		end
		if Object:IsA('CanvasGroup') then
			State.GroupTransparency = Object.GroupTransparency
		end
		return State
	end

	local function RestoreAppearance(Object, State)
		if not Object or not State then return end
		Object.Visible = State.Visible
		Object.BackgroundTransparency = State.BackgroundTransparency
		if State.TextTransparency ~= nil then Object.TextTransparency = State.TextTransparency end
		if State.ImageTransparency ~= nil then Object.ImageTransparency = State.ImageTransparency end
		if State.GroupTransparency ~= nil then Object.GroupTransparency = State.GroupTransparency end
	end

	local function Repair(Object)
		if Object:IsA('GuiObject') then
			local Appearance = CaptureAppearance(Object)

			if self.ComponentPresets:IsSemantic(Object) then
				self.ComponentPresets:ApplySemantic(Object)
			elseif Object:GetAttribute('FORGEStyleSurface') and self.StylePacks then
				self.StylePacks:ApplySurface(
					Object,
					Object:GetAttribute('FORGEStyleSurface'),
					Object:GetAttribute('FORGEStylePack') or self.ActiveStylePack,
					{PreserveAppearance = true}
				)
			end

			-- Generated style internals may be recreated above, but authored
			-- transparency/visibility always wins over style defaults.
			RestoreAppearance(Object, Appearance)
		end

		for _, Child in ipairs(Object:GetChildren()) do
			if Child:IsA('GuiObject') then Repair(Child) end
		end
	end

	Repair(Root)
	if self.ComponentPresets.ResolveLayouts then self:_ResolveLayoutsForRoot(Root) end
end

function App:_RefreshAll()
	if self.RefreshSuspended then return end

	local ActiveRoot = self.Selection.Root
	if ActiveRoot then
		if self.ComponentPresets and self.ComponentPresets.ResolveLayouts then self:_ResolveLayoutsForRoot(ActiveRoot) end
		if self.Modifiers and self.Modifiers.ApplyTree then self.Modifiers:ApplyTree(ActiveRoot) end
	end

	self:_RefreshRoots()
	self:_RefreshChildren()
	self:_RefreshProperties()
	self:_RefreshColor()

	if self.InsertPopup and self.InsertPopup.Visible then self:_RefreshInsertPalette() end
	if self.ComponentsPopup and self.ComponentsPopup.Visible then self:_RefreshComponents() end
	if self.StylePopup and self.StylePopup.Visible then self:_RefreshStyle() end
	if self.AnimationPopup and self.AnimationPopup.Visible then self:_RefreshAnimations() end
	if self.BindingsPopup and self.BindingsPopup.Visible then self:_RefreshBindings() end
	if self.MockDataPopup and self.MockDataPopup.Visible then self:_RefreshMockData() end
	if self.ScreensPopup and self.ScreensPopup.Visible then self:_RefreshScreens() end
	if self.FlowPopup and self.FlowPopup.Visible then self:_RefreshFlow() end
	if self.ProblemsPopup and self.ProblemsPopup.Visible then self:_RefreshProblems() end
	if self.PackagePopup and self.PackagePopup.Visible then self:_RefreshPackage() end

	self:_ApplyStrokeLOD()
	self:_UpdateSelectionBox()
	self:_UpdatePreviewToolbar()
	self:_UpdateHistoryButtons()
	self:_UpdateStatus()
end

function App:Destroy()
	if not self.Destroyed
		and not RunService:IsRunning()
		and not self.SavingProject
		and self.SaveCommittedVersion < self.SaveDirtyVersion
	then
		pcall(function()
			self:_SavePersistentProject('Shutdown Save', true, self.SaveDirtyVersion)
		end)
	end

	self.Destroyed = true
	self.RuntimeSyncGeneration += 1
	self.SaveGeneration += 1
	self:_StopRuntimePreview()
	self:_ClearInteractiveConnections()
	self:_StopScreenTransition()
	for _, Connection in ipairs(self.Connections) do Connection:Disconnect() end
	for Root in pairs(self.RootConnections) do self:_UnregisterRoot(Root) end
	self:_StopAnimationPreview(true)
	self:_ResetBindingPreview()
	self:_ClearClipboard()
	self.History:Destroy()
	if self.Components then self.Components:Destroy() end
	if self.Animations then self.Animations:Destroy() end
	if self.MockData then self.MockData:Destroy() end
	if self.Screens then self.Screens:Destroy() end
	self.Selection:Destroy()
	self.Document:Destroy()
	if self.Root then self.Root:Destroy() end
end

return App