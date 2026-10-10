local Theme = {}

Theme.Asset = {
	Rubik = 'rbxassetid://12187365977',
	Satin = 'rbxassetid://113178592047341'
}

Theme.Color = {
	Face = Color3.fromRGB(42, 44, 50),
	FaceLight = Color3.fromRGB(51, 54, 62),
	FaceDark = Color3.fromRGB(31, 33, 38),
	FaceDarker = Color3.fromRGB(21, 22, 26),
	Highlight = Color3.fromRGB(241, 244, 250),
	Window = Color3.fromRGB(27, 29, 34),
	Workspace = Color3.fromRGB(17, 18, 21),
	Canvas = Color3.new(0, 0, 0),
	Text = Color3.fromRGB(236, 239, 245),
	TextMuted = Color3.fromRGB(143, 149, 161),
	Selection = Color3.fromRGB(68, 128, 245),
	SelectionText = Color3.fromRGB(255, 255, 255),
	SelectionSecondary = Color3.fromRGB(43, 70, 121),
	Handle = Color3.fromRGB(247, 249, 252),
	HandleBorder = Color3.fromRGB(83, 145, 255),
	Guide = Color3.fromRGB(78, 138, 245),
	PropertyName = Color3.fromRGB(29, 31, 36),
	PropertyValue = Color3.fromRGB(24, 26, 30),
	Accent = Color3.fromRGB(92, 153, 255),
	AccentMuted = Color3.fromRGB(73, 81, 96),
	AccentSoft = Color3.fromRGB(122, 175, 255),
	SatinDark = Color3.fromRGB(84, 96, 117),
	SatinDeep = Color3.fromRGB(48, 55, 67),
	Danger = Color3.fromRGB(226, 92, 92),
	Success = Color3.fromRGB(83, 186, 125),
	Gold = Color3.fromRGB(92, 153, 255),
	Ivory = Color3.fromRGB(244, 246, 250),
	Warm = Color3.fromRGB(124, 178, 255),
	Black = Color3.new(0, 0, 0)
}

Theme.Font = Enum.Font.Gotham
Theme.FontBold = Enum.Font.GothamBold
Theme.FontFace = Font.new(Theme.Asset.Rubik, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
Theme.FontFaceMedium = Font.new(Theme.Asset.Rubik, Enum.FontWeight.Medium, Enum.FontStyle.Normal)
Theme.FontFaceBold = Font.new(Theme.Asset.Rubik, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
Theme.FontFaceHeavy = Font.new(Theme.Asset.Rubik, Enum.FontWeight.Heavy, Enum.FontStyle.Normal)

Theme.Material = {
	Inset = 1,
	Stroke = 1,
	PanelSatin = .97,
	HeaderSatin = .96,
	ButtonSatin = .96,
	InputSatin = .985,
	HoverSatin = .90,
	GlowTransparency = .94,
	GlowBlur = 6
}

Theme.Metric = {
	MenuHeight = 32,
	ToolbarHeight = 42,
	ToolbarRowHeight = 34,
	CanvasBarHeight = 26,
	StatusHeight = 24,
	PanelHeaderHeight = 30,
	DockTabHeight = 28,
	RowHeight = 28,
	ToolRailWidth = 0,
	LeftWidth = 260,
	RightWidth = 340,
	Splitter = 2,
	Handle = 5,
	HandleHitbox = 15,
	ScreenMargin = 16,
	SearchHeight = 28,
	Nudge = 1,
	NudgeLarge = 10,
	DuplicateOffset = 10,
	ZoomMin = .25,
	ZoomMax = 3,
	ZoomStep = .25,
	MinObjectSize = 8,
	ControlRadius = 6,
	PopupPadding = 8,
	SpaceXS = 4,
	SpaceS = 6,
	SpaceM = 8,
	SpaceL = 12,
	SpaceXL = 16,
	ExplorerRatio = .55,
	ColorPanelHeight = 370
}

Theme.Zones = {
	'TopLeft',
	'TopCenter',
	'TopRight',
	'CenterLeft',
	'Center',
	'CenterRight',
	'BottomLeft',
	'BottomCenter',
	'BottomRight'
}

Theme.ZoneAnchor = {
	TopLeft = Vector2.new(0, 0),
	TopCenter = Vector2.new(.5, 0),
	TopRight = Vector2.new(1, 0),
	CenterLeft = Vector2.new(0, .5),
	Center = Vector2.new(.5, .5),
	CenterRight = Vector2.new(1, .5),
	BottomLeft = Vector2.new(0, 1),
	BottomCenter = Vector2.new(.5, 1),
	BottomRight = Vector2.new(1, 1)
}

Theme.ReferenceSize = Vector2.new(1920, 1080)
Theme.ReferenceDevice = 'Desktop 16:9'
Theme.ReferenceScaleMode = 'Fit'
Theme.StrokeLODThreshold = .5
Theme.StrokeLODBoost = 1

Theme.Devices = {
	{Name = 'Desktop 16:9', Width = 1920, Height = 1080},
	{Name = 'Laptop', Width = 1366, Height = 768},
	{Name = 'Tablet', Width = 1024, Height = 768},
	{Name = 'Phone Landscape', Width = 844, Height = 390},
	{Name = 'Phone Wide', Width = 932, Height = 430},
	{Name = 'Ultrawide 21:9', Width = 2560, Height = 1080},
	{Name = 'Studio Viewport', Width = 1920, Height = 1080, Dynamic = 'StudioViewport'}
}

Theme.ClassicColors = {
	Color3.fromRGB(39, 39, 39),
	Color3.fromRGB(24, 34, 35),
	Color3.fromRGB(120, 192, 200),
	Color3.fromRGB(126, 227, 255),
	Color3.fromRGB(255, 251, 210),
	Color3.fromRGB(255, 241, 162),
	Color3.fromRGB(113, 200, 111),
	Color3.fromRGB(200, 110, 87),
	Color3.fromRGB(200, 182, 111),
	Color3.fromRGB(184, 193, 205),
	Color3.fromRGB(198, 151, 255),
	Color3.fromRGB(255, 147, 199),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(0, 0, 0),
	Color3.fromRGB(70, 139, 151),
	Color3.fromRGB(130, 187, 200),
	Color3.fromRGB(48, 103, 126),
	Color3.fromRGB(27, 38, 39),
	Color3.fromRGB(48, 67, 69),
	Color3.fromRGB(18, 25, 26),
	Color3.fromRGB(245, 249, 255),
	Color3.fromRGB(89, 98, 111),
	Color3.fromRGB(176, 122, 34),
	Color3.fromRGB(255, 215, 197)
}

return table.freeze(Theme)
