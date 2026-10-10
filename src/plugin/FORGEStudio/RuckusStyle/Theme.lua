local Theme = {}

Theme.Name = 'RUCKUS'
Theme.Default = true

Theme.Assets = {
	Satin = 'rbxassetid://113178592047341',
	Rubik = 'rbxassetid://12187365977'
}

Theme.Colors = {
	Surface = Color3.fromRGB(120, 192, 200),
	SurfaceTop = Color3.fromRGB(45, 45, 45),
	SurfaceBottom = Color3.fromRGB(28, 28, 28),
	Inset = Color3.fromRGB(24, 34, 35),
	InsetTop = Color3.fromRGB(31, 45, 46),
	InsetBottom = Color3.fromRGB(17, 25, 26),
	InsetDark = Color3.fromRGB(255, 251, 210),
	Text = Color3.fromRGB(255, 251, 210),
	TextMuted = Color3.fromRGB(226, 221, 187),
	Ivory = Color3.fromRGB(255, 251, 210),
	Warm = Color3.fromRGB(255, 241, 162),
	Accent = Color3.fromRGB(126, 227, 255),
	AccentMuted = Color3.fromRGB(120, 192, 200),
	AccentSoft = Color3.fromRGB(130, 187, 200),
	Danger = Color3.fromRGB(200, 110, 87),
	Success = Color3.fromRGB(113, 200, 111),
	Gold = Color3.fromRGB(200, 182, 111),
	GoldLight = Color3.fromRGB(255, 241, 162),
	GoldDark = Color3.fromRGB(126, 98, 48),
	Silver = Color3.fromRGB(184, 193, 205),
	SilverLight = Color3.fromRGB(245, 249, 255),
	SilverDark = Color3.fromRGB(89, 98, 111),
	Dark = Color3.fromRGB(39, 39, 39),
	DarkSoft = Color3.fromRGB(27, 38, 39),
	DarkRaised = Color3.fromRGB(48, 67, 69),
	CreamDepth = Color3.fromRGB(120, 192, 200),
	Black = Color3.new(0, 0, 0),
	White = Color3.new(1, 1, 1)
}

local function Sequence(...)
	local Values = {...}
	local Points = {}
	for Index = 1, #Values, 2 do
		table.insert(Points, ColorSequenceKeypoint.new(Values[Index], Values[Index + 1]))
	end
	return ColorSequence.new(Points)
end

Theme.Rarities = {
	Common = {Color = Theme.Colors.Ivory, Text = Theme.Colors.Dark},
	Uncommon = {Color = Theme.Colors.Success, Text = Theme.Colors.Ivory},
	Rare = {Color = Theme.Colors.Accent, Text = Theme.Colors.Ivory},
	Epic = {Color = Color3.fromRGB(198, 151, 255), Text = Theme.Colors.Ivory},
	Legendary = {Color = Theme.Colors.GoldLight, Text = Theme.Colors.Dark},
	Mythic = {Color = Color3.fromRGB(255, 147, 199), Text = Theme.Colors.Ivory}
}

Theme.Typography = {
	Hero = {
		FontFace = Font.new(Theme.Assets.Rubik, Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		TextSize = 20,
		TextColor3 = Theme.Colors.Text
	},
	Header = {
		FontFace = Font.new(Theme.Assets.Rubik, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		TextSize = 15,
		TextColor3 = Theme.Colors.Text
	},
	Button = {
		FontFace = Font.new(Theme.Assets.Rubik, Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		TextSize = 14,
		TextColor3 = Theme.Colors.Text
	},
	Body = {
		FontFace = Font.new(Theme.Assets.Rubik, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		TextSize = 14,
		TextColor3 = Theme.Colors.Text
	},
	Subtext = {
		FontFace = Font.new(Theme.Assets.Rubik, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		TextSize = 12,
		TextColor3 = Theme.Colors.TextMuted
	},
	Caption = {
		FontFace = Font.new(Theme.Assets.Rubik, Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		TextSize = 12,
		TextColor3 = Theme.Colors.TextMuted
	}
}

local Regular = {
	BaseColor = Theme.Colors.Dark,
	SatinColor = Theme.Colors.Surface,
	SatinTransparency = 0,
	Gradient = Sequence(0, Theme.Colors.Dark, 1, Theme.Colors.Dark),
	StrokeColor = Theme.Colors.Ivory,
	OutlineGradient = Sequence(0, Theme.Colors.Ivory, .5, Theme.Colors.Warm, 1, Theme.Colors.Ivory),
	StrokeThickness = 1,
	TextColor = Theme.Colors.Text,
	ShadowColor = Theme.Colors.Black,
	ShadowTransparency = .5,
	ShadowBlur = 20,
	PersistentBorderShine = true,
	PersistentShine = false
}

local Inset = {
	BaseColor = Theme.Colors.DarkSoft,
	SatinColor = Theme.Colors.AccentMuted,
	SatinTransparency = .7,
	Gradient = Sequence(0, Theme.Colors.DarkSoft, 1, Color3.fromRGB(16, 24, 25)),
	StrokeColor = Theme.Colors.Ivory,
	OutlineGradient = Sequence(0, Theme.Colors.Ivory, 1, Theme.Colors.Ivory),
	StrokeThickness = 1,
	TextColor = Theme.Colors.Text,
	ShadowColor = Theme.Colors.Black,
	ShadowTransparency = .62,
	ShadowBlur = 14,
	PersistentBorderShine = true,
	PersistentShine = false
}

Theme.Surfaces = {
	Regular = Regular,
	Dark = Regular,
	Panel = Regular,
	Inset = Inset,
	Accent = {
		BaseColor = Theme.Colors.Dark,
		SatinColor = Theme.Colors.Accent,
		SatinTransparency = 0,
		Gradient = Sequence(0, Theme.Colors.Dark, 1, Theme.Colors.Dark),
		StrokeColor = Theme.Colors.Ivory,
		OutlineGradient = Sequence(0, Theme.Colors.Ivory, 1, Theme.Colors.Ivory),
		StrokeThickness = 1,
		TextColor = Theme.Colors.Ivory,
		ShadowColor = Theme.Colors.Ivory,
		ShadowTransparency = .5,
		ShadowBlur = 12,
		PersistentBorderShine = true,
		PersistentShine = false
	},
	Danger = {
		BaseColor = Theme.Colors.Dark,
		SatinColor = Theme.Colors.Danger,
		SatinTransparency = 0,
		Gradient = Sequence(0, Theme.Colors.Dark, 1, Theme.Colors.Dark),
		StrokeColor = Color3.fromRGB(255, 161, 139),
		OutlineGradient = Sequence(0, Color3.fromRGB(255, 215, 197), 1, Theme.Colors.Danger),
		StrokeThickness = 1,
		TextColor = Theme.Colors.Ivory,
		ShadowColor = Theme.Colors.Danger,
		ShadowTransparency = .42,
		ShadowBlur = 18,
		PersistentBorderShine = true,
		PersistentShine = false
	},
	Success = {
		BaseColor = Theme.Colors.Dark,
		SatinColor = Theme.Colors.Success,
		SatinTransparency = 0,
		Gradient = Sequence(0, Theme.Colors.Dark, 1, Theme.Colors.Dark),
		StrokeColor = Color3.fromRGB(184, 255, 179),
		OutlineGradient = Sequence(0, Color3.fromRGB(226, 255, 215), 1, Theme.Colors.Success),
		StrokeThickness = 1,
		TextColor = Theme.Colors.Ivory,
		ShadowColor = Theme.Colors.Success,
		ShadowTransparency = .42,
		ShadowBlur = 18,
		PersistentBorderShine = true,
		PersistentShine = false
	},
	Gold = {
		BaseColor = Theme.Colors.Dark,
		SatinColor = Theme.Colors.Gold,
		SatinTransparency = 0,
		Gradient = Sequence(0, Theme.Colors.Dark, 1, Theme.Colors.Dark),
		StrokeColor = Theme.Colors.Warm,
		OutlineGradient = Sequence(0, Theme.Colors.Warm, .5, Theme.Colors.Ivory, 1, Theme.Colors.Gold),
		StrokeThickness = 1,
		TextColor = Theme.Colors.Ivory,
		ShadowColor = Theme.Colors.Ivory,
		ShadowTransparency = .5,
		ShadowBlur = 20,
		Metallic = true,
		PersistentBorderShine = true,
		PersistentShine = true
	},
	Silver = {
		BaseColor = Theme.Colors.Dark,
		SatinColor = Theme.Colors.Silver,
		SatinTransparency = .08,
		Gradient = Sequence(0, Theme.Colors.Dark, 1, Theme.Colors.Dark),
		StrokeColor = Theme.Colors.SilverLight,
		OutlineGradient = Sequence(0, Theme.Colors.SilverDark, .5, Theme.Colors.White, 1, Theme.Colors.SilverLight),
		StrokeThickness = 1,
		TextColor = Theme.Colors.Ivory,
		ShadowColor = Theme.Colors.Black,
		ShadowTransparency = .5,
		ShadowBlur = 18,
		Metallic = true,
		PersistentBorderShine = true,
		PersistentShine = true
	}
}

Theme.Effect = {
	BarGlow = {
		Color = Theme.Colors.Ivory,
		Transparency = .08,
		BlurRadius = UDim.new(0, 14)
	}
}

Theme.Metric = {
	Inset = 3,
	InnerInset = 2,
	Stroke = 1,
	PanelSatinTransparency = 0,
	ShadowTransparency = .5,
	ButtonHeight = 46,
	ControlHeight = 36,
	ControlHeightLarge = 44,
	BarHeight = 10,
	BarInset = 2,
	RowHeight = 54,
	Gap = 8,
	Padding = 8,
	PaddingLarge = 16,
	PillRadius = 999
}

function Theme.GetTypography(Name)
	return Theme.Typography[Name] or Theme.Typography.Body
end

function Theme.GetSurface(Name)
	return Theme.Surfaces[Name] or Theme.Surfaces.Regular
end

function Theme.GetRarity(Name)
	return Theme.Rarities[Name] or Theme.Rarities.Common
end

return table.freeze(Theme)
