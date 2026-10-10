local Theme = require(script.Parent.Theme)

local Widgets = {}

local function Text(Object, Size, Weight)
	local Font = Theme.FontFace
	if Weight == 'Medium' then Font = Theme.FontFaceMedium
	elseif Weight == 'Bold' then Font = Theme.FontFaceBold
	elseif Weight == 'Heavy' then Font = Theme.FontFaceHeavy end

	Object.FontFace = Font
	Object.TextSize = Size or 11
	Object.TextColor3 = Theme.Color.Text
	Object.TextXAlignment = Enum.TextXAlignment.Left
	Object.TextYAlignment = Enum.TextYAlignment.Center
end

local function Corner(Object, Radius)
	local Current = Object:FindFirstChild('_FORGECorner')
	if not Current then
		Current = Instance.new('UICorner')
		Current.Name = '_FORGECorner'
		Current.Parent = Object
	end
	Current.CornerRadius = UDim.new(0, Radius or Theme.Metric.ControlRadius)
	return Current
end

local function Stroke(Object, Color, Transparency)
	local Current = Object:FindFirstChild('_FORGEStroke')
	if not Current then
		Current = Instance.new('UIStroke')
		Current.Name = '_FORGEStroke'
		Current.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		Current.LineJoinMode = Enum.LineJoinMode.Miter
		Current.Parent = Object
	end
	Current.Thickness = Theme.Material.Stroke
	Current.LineJoinMode = Enum.LineJoinMode.Round
	Current.Color = Color or Theme.Color.AccentMuted
	Current.Transparency = Transparency or 0
	return Current
end

local function Gradient(Object, Top, Bottom)
	local Current = Object:FindFirstChild('_FORGEGradient')
	if not Current then
		Current = Instance.new('UIGradient')
		Current.Name = '_FORGEGradient'
		Current.Rotation = 90
		Current.Parent = Object
	end
	Current.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Top),
		ColorSequenceKeypoint.new(1, Bottom)
	})
	return Current
end

local function Material(Object, Kind)
	local Layer = Object:FindFirstChild('_FORGEMaterial')
	if not Layer then
		Layer = Instance.new('Frame')
		Layer.Name = '_FORGEMaterial'
		Layer.BorderSizePixel = 0
		Layer.Position = UDim2.fromScale(0, 0)
		Layer.Size = UDim2.fromScale(1, 1)
		Layer.Active = false
		Layer.Parent = Object
	end

	Layer.ZIndex = (Object:IsA('TextButton') or Object:IsA('TextBox')) and math.max(1, Object.ZIndex - 1) or Object.ZIndex
	Corner(Layer)

	local Satin = Layer:FindFirstChild('_FORGESatin')
	if not Satin then
		Satin = Instance.new('ImageLabel')
		Satin.Name = '_FORGESatin'
		Satin.BackgroundTransparency = 1
		Satin.BorderSizePixel = 0
		Satin.Position = UDim2.fromScale(0, 0)
		Satin.Size = UDim2.fromScale(1, 1)
		Satin.ScaleType = Enum.ScaleType.Crop
		Satin.Image = Theme.Asset.Satin
		Satin.Active = false
		Satin.Parent = Layer
	end
	Satin.ZIndex = Layer.ZIndex
	Corner(Satin)

	local Inset = Layer:FindFirstChild('_FORGEInset')
	if not Inset then
		Inset = Instance.new('Frame')
		Inset.Name = '_FORGEInset'
		Inset.BackgroundTransparency = 1
		Inset.BorderSizePixel = 0
		Inset.Active = false
		Inset.Parent = Layer
	end
	Inset.Position = UDim2.fromOffset(Theme.Material.Inset, Theme.Material.Inset)
	Inset.Size = UDim2.new(1, -Theme.Material.Inset * 2, 1, -Theme.Material.Inset * 2)
	Inset.ZIndex = Layer.ZIndex + 1
	Corner(Inset, math.max(Theme.Metric.ControlRadius - 1, 0))

	local Border = Stroke(Inset, Theme.Color.AccentMuted, .52)
	local Gradient = Layer:FindFirstChild('_FORGEGradient')
	if Gradient then Gradient:Destroy() end
	local BorderGradient = Border:FindFirstChild('_FORGEOutlineGradient')
	if BorderGradient then BorderGradient:Destroy() end

	if Kind == 'Panel' then
		Layer.BackgroundColor3 = Theme.Color.Window
		Satin.ImageColor3 = Theme.Color.SatinDeep
		Satin.ImageTransparency = Theme.Material.PanelSatin
		Border.Color = Theme.Color.AccentMuted
		Border.Transparency = .62
	elseif Kind == 'Header' then
		Layer.BackgroundColor3 = Theme.Color.FaceDark
		Satin.ImageColor3 = Theme.Color.SatinDark
		Satin.ImageTransparency = Theme.Material.HeaderSatin
		Border.Color = Theme.Color.AccentMuted
		Border.Transparency = .58
	elseif Kind == 'Input' then
		Layer.BackgroundColor3 = Theme.Color.PropertyValue
		Satin.ImageColor3 = Theme.Color.SatinDeep
		Satin.ImageTransparency = Theme.Material.InputSatin
		Border.Color = Theme.Color.AccentMuted
		Border.Transparency = .42
	elseif Kind == 'Active' then
		Layer.BackgroundColor3 = Theme.Color.SelectionSecondary
		Satin.ImageColor3 = Theme.Color.Accent
		Satin.ImageTransparency = .93
		Border.Color = Theme.Color.Selection
		Border.Transparency = .05
	else
		Layer.BackgroundColor3 = Theme.Color.Face
		Satin.ImageColor3 = Theme.Color.SatinDark
		Satin.ImageTransparency = Theme.Material.ButtonSatin
		Border.Color = Theme.Color.AccentMuted
		Border.Transparency = .38
	end

	return Layer
end

local function Glow(Object, Enabled)
	local Current = Object:FindFirstChild('_FORGEGlow')
	if not Enabled then
		if Current then Current:Destroy() end
		return
	end
	if not Current then
		Current = Instance.new('UIShadow')
		Current.Name = '_FORGEGlow'
		Current.Parent = Object
	end
	Current.Color = Theme.Color.Selection
	Current.Transparency = Theme.Material.GlowTransparency
	Current.BlurRadius = UDim.new(0, Theme.Material.GlowBlur)
end

function Widgets.Flat(Object, Color)
	for _, Name in ipairs({'_FORGEMaterial', '_FORGEGlow', '_FORGEStroke'}) do
		local Child = Object:FindFirstChild(Name)
		if Child then Child:Destroy() end
	end
	Object.BackgroundTransparency = 0
	Object.BackgroundColor3 = Color or Theme.Color.FaceDark
	Object.BorderSizePixel = 0
	return Object
end

function Widgets.Bevel(Object, InsetMode)
	return Stroke(Object, InsetMode and Theme.Color.FaceDarker or Theme.Color.AccentMuted, InsetMode and .25 or .1)
end

function Widgets.Surface(Object, Kind)
	Object.BorderSizePixel = 0
	Object.ClipsDescendants = false
	Object.BackgroundTransparency = 1
	Material(Object, Kind or 'Button')
	Glow(Object, Kind == 'Active')
	return Object
end

function Widgets.Label(Parent, Value, Size, Bold)
	local Label = Instance.new('TextLabel')
	Label.BackgroundTransparency = 1
	Label.BorderSizePixel = 0
	Label.Text = Value or ''
	Text(Label, Size or 11, Bold and 'Bold' or nil)
	Label.ZIndex = Parent and Parent:IsA('GuiObject') and Parent.ZIndex + 2 or 2
	Label.Parent = Parent

	if Bold then
		local DisplayTransparency = Label.TextTransparency

		local Shadow = Instance.new('TextLabel')
		Shadow.Name = '_FORGETextShadow'
		Shadow.BackgroundTransparency = 1
		Shadow.BorderSizePixel = 0
		Shadow.Active = false
		Shadow.Position = UDim2.fromOffset(1, 1)
		Shadow.Size = UDim2.fromScale(1, 1)
		Shadow.TextColor3 = Theme.Color.Black
		Shadow.TextTransparency = .3
		Shadow.ZIndex = Label.ZIndex + 1
		Shadow.Parent = Label

		local Main = Instance.new('TextLabel')
		Main.Name = '_FORGETextMain'
		Main.BackgroundTransparency = 1
		Main.BorderSizePixel = 0
		Main.Active = false
		Main.Position = UDim2.fromScale(0, 0)
		Main.Size = UDim2.fromScale(1, 1)
		Main.ZIndex = Label.ZIndex + 2
		Main.Parent = Label

		local Syncing = false
		local function Sync()
			if Syncing then return end
			Syncing = true

			for _, Target in ipairs({Shadow, Main}) do
				Target.Text = Label.Text
				Target.FontFace = Label.FontFace
				Target.TextSize = Label.TextSize
				Target.TextXAlignment = Label.TextXAlignment
				Target.TextYAlignment = Label.TextYAlignment
				Target.TextWrapped = Label.TextWrapped
				Target.TextTruncate = Label.TextTruncate
				Target.LineHeight = Label.LineHeight
				Target.Visible = Label.Visible
			end

			Main.TextColor3 = Label.TextColor3
			Main.TextTransparency = DisplayTransparency
			Shadow.TextTransparency = math.clamp(.3 + DisplayTransparency, 0, 1)
			Shadow.ZIndex = Label.ZIndex + 1
			Main.ZIndex = Label.ZIndex + 2
			Label.TextTransparency = 1
			Syncing = false
		end

		for _, Property in ipairs({
			'Text',
			'FontFace',
			'TextSize',
			'TextColor3',
			'TextXAlignment',
			'TextYAlignment',
			'TextWrapped',
			'TextTruncate',
			'LineHeight',
			'Visible',
			'ZIndex'
		}) do
			Label:GetPropertyChangedSignal(Property):Connect(Sync)
		end

		Label:GetPropertyChangedSignal('TextTransparency'):Connect(function()
			if Syncing then return end
			if Label.TextTransparency < 1 then
				DisplayTransparency = Label.TextTransparency
				Sync()
			end
		end)

		Sync()
	end

	return Label
end

local function EnsureButtonText(Button)
	local Label = Button:FindFirstChild('_FORGEText')
	if Label then return Label end

	Label = Instance.new('TextLabel')
	Label.Name = '_FORGEText'
	Label.BackgroundTransparency = 1
	Label.BorderSizePixel = 0
	Label.Active = false
	Label.Position = UDim2.fromScale(0, 0)
	Label.Size = UDim2.fromScale(1, 1)
	Label.Parent = Button

	local Syncing = false
	local DisplayTransparency = Button.TextTransparency

	local function Sync()
		if Syncing then return end
		Syncing = true
		Label.Text = Button.Text
		Label.FontFace = Button.FontFace
		Label.TextSize = Button.TextSize
		Label.TextColor3 = Button.TextColor3
		Label.TextTransparency = DisplayTransparency
		Label.TextXAlignment = Button.TextXAlignment
		Label.TextYAlignment = Button.TextYAlignment
		Label.TextWrapped = Button.TextWrapped
		Label.TextTruncate = Button.TextTruncate
		local Left = Button:GetAttribute('FORGETextInsetLeft')
		local Right = Button:GetAttribute('FORGETextInsetRight')
		if Left == nil then Left = Button.TextXAlignment == Enum.TextXAlignment.Left and 6 or 0 end
		if Right == nil then Right = Button.TextXAlignment == Enum.TextXAlignment.Right and 6 or 0 end
		Label.Position = UDim2.fromOffset(Left, 0)
		Label.Size = UDim2.new(1, -(Left + Right), 1, 0)
		Label.ZIndex = Button.ZIndex + 4
		Button.TextTransparency = 1
		Syncing = false
	end

	for _, Property in ipairs({
		'Text',
		'FontFace',
		'TextSize',
		'TextColor3',
		'TextXAlignment',
		'TextYAlignment',
		'TextWrapped',
		'TextTruncate',
		'ZIndex'
	}) do
		Button:GetPropertyChangedSignal(Property):Connect(Sync)
	end

	Button:GetPropertyChangedSignal('TextTransparency'):Connect(function()
		if Syncing then return end
		if Button.TextTransparency < 1 then
			DisplayTransparency = Button.TextTransparency
			Sync()
		end
	end)

	Button:GetAttributeChangedSignal('FORGETextInsetLeft'):Connect(Sync)
	Button:GetAttributeChangedSignal('FORGETextInsetRight'):Connect(Sync)

	Sync()
	return Label
end

function Widgets.Button(Parent, Value)
	local Button = Instance.new('TextButton')
	Button.AutoButtonColor = false
	Button.BackgroundTransparency = 1
	Button.BorderSizePixel = 0
	Button.Text = Value or ''
	Button.ZIndex = Parent and Parent:IsA('GuiObject') and Parent.ZIndex + 3 or 3
	Text(Button, 11, 'Medium')
	Button.TextXAlignment = Enum.TextXAlignment.Center
	Button.Parent = Parent
	Widgets.Surface(Button, 'Button')
	EnsureButtonText(Button)

	Button.MouseEnter:Connect(function()
		local Layer = Button:FindFirstChild('_FORGEMaterial')
		local Satin = Layer and Layer:FindFirstChild('_FORGESatin')
		if Satin then Satin.ImageTransparency = Theme.Material.HoverSatin end
		local GlowLayer = Button:FindFirstChild('_FORGEGlow')
		if GlowLayer then GlowLayer.Transparency = .68 end
	end)

	Button.MouseLeave:Connect(function()
		local Active = Button:GetAttribute('FORGEActive') == true
		Material(Button, Active and 'Active' or 'Button')
		local GlowLayer = Button:FindFirstChild('_FORGEGlow')
		if GlowLayer then GlowLayer.Transparency = Theme.Material.GlowTransparency end
	end)

	Button.MouseButton1Down:Connect(function()
		Material(Button, 'Active')
	end)

	Button.MouseButton1Up:Connect(function()
		Material(Button, Button:GetAttribute('FORGEActive') == true and 'Active' or 'Button')
	end)

	return Button
end

function Widgets.DecorateDropdown(Button)
	if not Button then return nil end
	Button.TextXAlignment = Enum.TextXAlignment.Left
	Button.TextTruncate = Enum.TextTruncate.AtEnd

	local OldPadding = Button:FindFirstChild('_DropdownPadding')
	if OldPadding then OldPadding:Destroy() end

	Button:SetAttribute('FORGETextInsetLeft', 8)
	Button:SetAttribute('FORGETextInsetRight', 30)

	local TextLayer = Button:FindFirstChild('_FORGEText')
	if TextLayer then
		TextLayer.TextXAlignment = Enum.TextXAlignment.Left
		TextLayer.TextYAlignment = Enum.TextYAlignment.Center
	end

	local Arrow = Button:FindFirstChild('_DropdownArrow')
	if not Arrow then
		Arrow = Widgets.Label(Button, 'v', 10, true)
		Arrow.Name = '_DropdownArrow'
	end
	Arrow.AnchorPoint = Vector2.new(1, .5)
	Arrow.Position = UDim2.new(1, -5, .5, 0)
	Arrow.Size = UDim2.fromOffset(16, 16)
	Arrow.TextXAlignment = Enum.TextXAlignment.Center
	Arrow.TextYAlignment = Enum.TextYAlignment.Center
	Arrow.TextColor3 = Theme.Color.Ivory
	Arrow.ZIndex = Button.ZIndex + 5
	return Button
end
function Widgets.DropdownButton(Parent, Value)
	return Widgets.DecorateDropdown(Widgets.Button(Parent, Value))
end

function Widgets.TextBox(Parent, Value)
	local Box = Instance.new('TextBox')
	Box.BackgroundTransparency = 1
	Box.BorderSizePixel = 0
	Box.ClearTextOnFocus = false
	Box.Text = Value or ''
	Box.PlaceholderColor3 = Theme.Color.TextMuted
	Box.TextColor3 = Theme.Color.Text
	Box.TextSize = 11
	Box.TextXAlignment = Enum.TextXAlignment.Left
	Box.TextYAlignment = Enum.TextYAlignment.Center
	Box.TextTruncate = Enum.TextTruncate.AtEnd
	Box.LineHeight = 1
	Box.ZIndex = Parent and Parent:IsA('GuiObject') and Parent.ZIndex + 4 or 4
	Box.FontFace = Theme.FontFace
	Box.Parent = Parent

	local Backdrop = Instance.new('Frame')
	Backdrop.Name = '_FORGEInputBackdrop'
	Backdrop.BackgroundTransparency = 1
	Backdrop.BorderSizePixel = 0
	Backdrop.Active = false
	Backdrop.ZIndex = math.max(1, Box.ZIndex - 1)
	Backdrop.Parent = Parent
	Widgets.Surface(Backdrop, 'Input')

	local Padding = Instance.new('UIPadding')
	Padding.Name = '_FORGETextPadding'
	Padding.PaddingLeft = UDim.new(0, 9)
	Padding.PaddingRight = UDim.new(0, 7)
	Padding.PaddingTop = UDim.new(0, 2)
	Padding.PaddingBottom = UDim.new(0, 2)
	Padding.Parent = Box

	local function GetBorder()
		local Layer = Backdrop:FindFirstChild('_FORGEMaterial')
		local Inset = Layer and Layer:FindFirstChild('_FORGEInset')
		return Inset and Inset:FindFirstChild('_FORGEStroke')
	end

	local function SyncBackdrop()
		if not Box.Parent or not Backdrop.Parent then return end
		Backdrop.AnchorPoint = Box.AnchorPoint
		Backdrop.Position = Box.Position
		Backdrop.Size = Box.Size
		Backdrop.Rotation = Box.Rotation
		Backdrop.Visible = Box.Visible
		Backdrop.ZIndex = math.max(1, Box.ZIndex - 1)
		local Layer = Backdrop:FindFirstChild('_FORGEMaterial')
		if Layer then Layer.ZIndex = Backdrop.ZIndex end
	end

	for _, Property in ipairs({'Position', 'Size', 'AnchorPoint', 'Rotation', 'Visible', 'ZIndex'}) do
		Box:GetPropertyChangedSignal(Property):Connect(SyncBackdrop)
	end

	Box.AncestryChanged:Connect(function(_, NewParent)
		if not NewParent and Backdrop.Parent then Backdrop:Destroy() end
	end)

	Box.Focused:Connect(function()
		local Border = GetBorder()
		if Border then
			Border.Color = Theme.Color.Warm
			Border.Transparency = 0
		end
	end)

	Box.FocusLost:Connect(function()
		local Border = GetBorder()
		if Border then
			Border.Color = Theme.Color.AccentMuted
			Border.Transparency = .28
		end
	end)

	SyncBackdrop()
	return Box
end
function Widgets.SmallButton(Parent, Value)
	local Button = Widgets.Button(Parent, Value)
	Button.TextSize = 10
	return Button
end

function Widgets.Toggle(Parent, Value, Checked)
	local Button = Widgets.Button(Parent, '')
	Button.TextXAlignment = Enum.TextXAlignment.Left

	local Box = Instance.new('Frame')
	Box.Name = 'Check'
	Box.Position = UDim2.fromOffset(5, 5)
	Box.Size = UDim2.fromOffset(12, 12)
	Box.ZIndex = Button.ZIndex + 1
	Box.Parent = Button
	Widgets.Surface(Box, 'Input')

	local Mark = Widgets.Label(Box, 'X', 8, true)
	Mark.Size = UDim2.fromScale(1, 1)
	Mark.TextXAlignment = Enum.TextXAlignment.Center
	Mark.TextColor3 = Theme.Color.Warm
	Mark.Visible = Checked == true

	local Label = Widgets.Label(Button, Value or '', 11, false)
	Label.Position = UDim2.fromOffset(22, 0)
	Label.Size = UDim2.new(1, -24, 1, 0)
	return Button, Mark, Label
end

function Widgets.PropertyBase(Parent, Name)
	local Row = Instance.new('Frame')
	Row.BackgroundColor3 = Theme.Color.Window
	Row.BackgroundTransparency = 1
	Row.BorderSizePixel = 0
	Row.Size = UDim2.new(1, 0, 0, Theme.Metric.RowHeight)
	Row.ZIndex = Parent and Parent:IsA('GuiObject') and Parent.ZIndex + 1 or 1
	Row.Parent = Parent

	local NameLabel = Widgets.Label(Row, Name or '', 11, false)
	NameLabel.FontFace = Theme.FontFaceMedium
	NameLabel.Position = UDim2.fromOffset(8, 0)
	NameLabel.Size = UDim2.new(.42, -10, 1, 0)
	NameLabel.TextColor3 = Theme.Color.TextMuted
	return Row, NameLabel
end

function Widgets.PropertyBoolean(Parent, Name, Value)
	local Row, NameLabel = Widgets.PropertyBase(Parent, Name)
	local Button = Widgets.Button(Row, Value and 'true' or 'false')
	Button.Position = UDim2.new(.42, 1, 0, 0)
	Button.Size = UDim2.new(.58, -1, 1, 0)
	Button.TextXAlignment = Enum.TextXAlignment.Left
	Button:SetAttribute('FORGETextInsetLeft', 7)
	Button:SetAttribute('FORGETextInsetRight', 7)
	return Row, Button, NameLabel
end

function Widgets.PropertyColor(Parent, Name, Value, TextValue)
	local Row, NameLabel = Widgets.PropertyBase(Parent, Name)
	local Swatch = Instance.new('TextButton')
	Swatch.Text = ''
	Swatch.AutoButtonColor = false
	Swatch.BackgroundColor3 = Value
	Swatch.BorderSizePixel = 0
	Swatch.Position = UDim2.new(.42, 4, 0, 3)
	Swatch.Size = UDim2.fromOffset(20, Theme.Metric.RowHeight - 6)
	Swatch.ZIndex = Row.ZIndex + 2
	Swatch.Parent = Row
	Stroke(Swatch, Theme.Color.Ivory, .25)

	local Box = Widgets.TextBox(Row, TextValue or '')
	Box.Position = UDim2.new(.42, 27, 0, 0)
	Box.Size = UDim2.new(.58, -27, 1, 0)
	return Row, Box, Swatch, NameLabel
end

function Widgets.PropertyEnum(Parent, Name, Value)
	local Row, NameLabel = Widgets.PropertyBase(Parent, Name)
	local Button = Widgets.DropdownButton(Row, tostring(Value):match('%.([^%.]+)$') or tostring(Value))
	Button.Position = UDim2.new(.42, 1, 0, 0)
	Button.Size = UDim2.new(.58, -1, 1, 0)
	return Row, Button, NameLabel
end

function Widgets.PropertyRow(Parent, Name, Value)
	local Row, NameLabel = Widgets.PropertyBase(Parent, Name)
	local Box = Widgets.TextBox(Row, Value or '')
	Box.Position = UDim2.new(.42, 1, 0, 0)
	Box.Size = UDim2.new(.58, -1, 1, 0)
	return Row, Box, NameLabel
end

function Widgets.PropertyAxis(Parent, Name, Value, Mode)
	local Row, NameLabel = Widgets.PropertyBase(Parent, Name)
	local Unit = Widgets.DropdownButton(Row, Mode or 'px')
	Unit.AnchorPoint = Vector2.new(1, 0)
	Unit.Position = UDim2.new(1, 0, 0, 0)
	Unit.Size = UDim2.fromOffset(48, Theme.Metric.RowHeight)
	Unit.TextXAlignment = Enum.TextXAlignment.Center

	local Box = Widgets.TextBox(Row, Value or '')
	Box.Position = UDim2.new(.42, 1, 0, 0)
	Box.Size = UDim2.new(.58, -49, 1, 0)
	return Row, Box, Unit, NameLabel
end

function Widgets.SectionRow(Parent, Value)
	local Row = Instance.new('Frame')
	Row.BackgroundColor3 = Theme.Color.FaceDark
	Row.BorderSizePixel = 0
	Row.Size = UDim2.new(1, 0, 0, 20)
	Row.ZIndex = Parent and Parent:IsA('GuiObject') and Parent.ZIndex + 1 or 1
	Row.Parent = Parent

	local Top = Instance.new('Frame')
	Top.BackgroundColor3 = Theme.Color.AccentMuted
	Top.BackgroundTransparency = .55
	Top.BorderSizePixel = 0
	Top.Size = UDim2.new(1, 0, 0, 1)
	Top.Parent = Row

	local Label = Widgets.Label(Row, string.upper(Value or ''), 10, true)
	Label.Position = UDim2.fromOffset(5, 0)
	Label.Size = UDim2.new(1, -10, 1, 0)
	Label.TextColor3 = Theme.Color.Warm
	return Row, Label
end

function Widgets.Scroll(Parent)
	local Scroll = Instance.new('ScrollingFrame')
	Scroll.BackgroundColor3 = Theme.Color.Window
	Scroll.BorderSizePixel = 0
	Scroll.CanvasSize = UDim2.new()
	Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Scroll.ScrollBarThickness = 6
	Scroll.ScrollBarImageColor3 = Theme.Color.Gold
	Scroll.ScrollBarImageTransparency = .32
	Scroll.ClipsDescendants = true
	Scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	Scroll.ZIndex = Parent and Parent:IsA('GuiObject') and Parent.ZIndex + 2 or 2
	Scroll.Parent = Parent
	Widgets.Surface(Scroll, 'Input')
	Scroll.ClipsDescendants = true

	local Layout = Instance.new('UIListLayout')
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.Padding = UDim.new(0, 1)
	Layout.Parent = Scroll
	return Scroll, Layout
end

function Widgets.Panel(Parent, Title)
	local Frame = Instance.new('Frame')
	Frame.BackgroundColor3 = Theme.Color.Window
	Frame.BorderSizePixel = 0
	Frame.ZIndex = Parent and Parent:IsA('GuiObject') and Parent.ZIndex + 1 or 1
	Frame.Parent = Parent
	Widgets.Flat(Frame, Theme.Color.Window)
	Corner(Frame, 0)

	local Header = Instance.new('Frame')
	Header.Name = 'Header'
	Header.BackgroundColor3 = Theme.Color.FaceDark
	Header.BorderSizePixel = 0
	Header.Size = UDim2.new(1, 0, 0, Theme.Metric.PanelHeaderHeight)
	Header.ZIndex = Frame.ZIndex + 2
	Header.Parent = Frame

	local Label = Widgets.Label(Header, Title or '', 11, true)
	Label.Position = UDim2.fromOffset(10, 0)
	Label.Size = UDim2.new(1, -20, 1, 0)
	Label.TextColor3 = Theme.Color.Text
	Label.TextXAlignment = Enum.TextXAlignment.Left

	local Body = Instance.new('Frame')
	Body.Name = 'Body'
	Body.BackgroundColor3 = Theme.Color.Window
	Body.BorderSizePixel = 0
	Body.Position = UDim2.fromOffset(0, Theme.Metric.PanelHeaderHeight)
	Body.Size = UDim2.new(1, 0, 1, -Theme.Metric.PanelHeaderHeight)
	Body.ZIndex = Frame.ZIndex + 2
	Body.Parent = Frame
	return Frame, Body, Label
end

function Widgets.TreeRow(Parent, TextValue, Depth)
	local Row = Instance.new('TextButton')
	Row.AutoButtonColor = false
	Row.BackgroundColor3 = Theme.Color.Window
	Row.BackgroundTransparency = 1
	Row.BorderSizePixel = 0
	Row.Size = UDim2.new(1, 0, 0, Theme.Metric.RowHeight)
	Row.Text = ''
	Row.ZIndex = Parent and Parent:IsA('GuiObject') and Parent.ZIndex + 1 or 1
	Row.Parent = Parent

	local Icon = Instance.new('TextButton')
	Icon.Text = ''
	Icon.AutoButtonColor = false
	Icon.BackgroundColor3 = Theme.Color.FaceLight
	Icon.BorderSizePixel = 0
	Icon.Position = UDim2.fromOffset(5 + (Depth or 0) * 13, 7)
	Icon.Size = UDim2.fromOffset(8, 8)
	Icon.ZIndex = Row.ZIndex + 2
	Icon.Parent = Row
	Stroke(Icon, Theme.Color.AccentMuted, .30)

	local Label = Widgets.Label(Row, TextValue or '', 11, false)
	Label.Position = UDim2.fromOffset(18 + (Depth or 0) * 13, 0)
	Label.Size = UDim2.new(1, -22 - (Depth or 0) * 13, 1, 0)

	Row.MouseEnter:Connect(function()
		if Row:GetAttribute('FORGETreeSelected') ~= true then
			Row.BackgroundTransparency = .55
			Row.BackgroundColor3 = Theme.Color.FaceLight
		end
	end)
	Row.MouseLeave:Connect(function()
		if Row:GetAttribute('FORGETreeSelected') ~= true then
			Row.BackgroundTransparency = 1
		end
	end)
	return {Object = Row, Label = Label, Icon = Icon}
end

function Widgets.SetTreeRowSelected(Row, Value, Primary)
	if not Row then return end
	Row.Object:SetAttribute('FORGETreeSelected', Value == true)
	Row.Object.BackgroundTransparency = Value and 0 or 1
	Row.Object.BackgroundColor3 = Primary == false and Theme.Color.SelectionSecondary or Theme.Color.Selection
	Row.Label.TextColor3 = Value and Theme.Color.SelectionText or Theme.Color.Text
end

function Widgets.SetTreeRowDrop(Row, Mode)
	if not Row or not Row.Object then return end
	local Existing = Row.Object:FindFirstChild('_FORGEDropLine')
	if not Mode then
		if Existing then Existing:Destroy() end
		if Row.Object:GetAttribute('FORGETreeSelected') ~= true then
			Row.Object.BackgroundTransparency = 1
		end
		return
	end

	if Mode == 'Into' then
		if Existing then Existing:Destroy() end
		Row.Object.BackgroundColor3 = Theme.Color.SelectionSecondary
		Row.Object.BackgroundTransparency = .15
		return
	end

	local Line = Existing or Instance.new('Frame')
	Line.Name = '_FORGEDropLine'
	Line.BackgroundColor3 = Theme.Color.Selection
	Line.BorderSizePixel = 0
	Line.Position = Mode == 'Before' and UDim2.fromOffset(3, 0) or UDim2.new(0, 3, 1, -2)
	Line.Size = UDim2.new(1, -6, 0, 2)
	Line.ZIndex = Row.Object.ZIndex + 5
	Line.Parent = Row.Object
end

function Widgets.SetActive(Button, Value)
	if not Button then return end
	Button:SetAttribute('FORGEActive', Value == true)
	Material(Button, Value and 'Active' or 'Button')
end

function Widgets.TabButton(Parent, Value)
	local Button = Widgets.Button(Parent, string.upper(Value or ''))
	Button.TextSize = 10
	return Button
end

function Widgets.ToolButton(Parent, Short, Label)
	local Button = Widgets.Button(Parent, Short or '')
	Button:SetAttribute('FORGEToolLabel', Label or Short or '')
	Button.TextSize = 10
	return Button
end

function Widgets.Divider(Parent, Vertical)
	local Line = Instance.new('Frame')
	Line.BackgroundColor3 = Theme.Color.AccentMuted
	Line.BackgroundTransparency = .58
	Line.BorderSizePixel = 0
	Line.Size = Vertical and UDim2.new(0, 1, 1, -6) or UDim2.new(1, -6, 0, 1)
	Line.Parent = Parent
	return Line
end

return Widgets
