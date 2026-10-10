local ReplicatedStorage = game:GetService('ReplicatedStorage')

local RuckusStyleModule = script.Parent:FindFirstChild('RuckusStyle')
local RuckusStyle = RuckusStyleModule and require(RuckusStyleModule)
local RuckusTheme = RuckusStyle and RuckusStyle.Theme

local StylePacks = {}

StylePacks.Default = 'RUCKUS'

local function Sequence(...)
	local Values = {...}
	local Points = {}
	for Index = 1, #Values, 2 do
		table.insert(Points, ColorSequenceKeypoint.new(Values[Index], Values[Index + 1]))
	end
	return ColorSequence.new(Points)
end

local function SafeSet(Object, Property, Value)
	pcall(function() Object[Property] = Value end)
end

local function FindOrCreate(Parent, ClassName, Name)
	local Current = Parent:FindFirstChild(Name)
	if Current and Current.ClassName == ClassName then return Current end
	if Current then Current:Destroy() end

	local Success, Object = pcall(Instance.new, ClassName)
	if not Success or not Object then return nil end
	Object.Name = Name
	Object:SetAttribute('FORGEStyleInternal', true)
	Object.Parent = Parent
	return Object
end

local function Remove(Parent, Name)
	local Object = Parent and Parent:FindFirstChild(Name)
	if Object and Object:GetAttribute('FORGEStyleInternal') == true then Object:Destroy() end
end

local function Deepen(Color, ValueScale, SaturationScale)
	local H, S, V = Color:ToHSV()
	return Color3.fromHSV(
		H,
		math.clamp(S * (SaturationScale or 1.2), 0, 1),
		math.clamp(V * (ValueScale or .68), 0, 1)
	)
end

local RUCKUS = {
	Name = 'RUCKUS',
	Asset = {
		Satin = RuckusTheme and RuckusTheme.Assets.Satin or 'rbxassetid://113178592047341',
		Rubik = RuckusTheme and RuckusTheme.Assets.Rubik or 'rbxassetid://12187365977'
	},
	Color = {
		Base = RuckusTheme and RuckusTheme.Colors.Dark or Color3.fromRGB(39, 39, 39),
		Dark = RuckusTheme and RuckusTheme.Colors.Dark or Color3.fromRGB(39, 39, 39),
		Ivory = RuckusTheme and RuckusTheme.Colors.Ivory or Color3.fromRGB(255, 251, 210),
		Warm = RuckusTheme and RuckusTheme.Colors.Warm or Color3.fromRGB(255, 241, 162),
		Accent = RuckusTheme and RuckusTheme.Colors.Accent or Color3.fromRGB(126, 227, 255),
		AccentMuted = RuckusTheme and RuckusTheme.Colors.AccentMuted or Color3.fromRGB(120, 192, 200),
		AccentSoft = RuckusTheme and RuckusTheme.Colors.AccentSoft or Color3.fromRGB(130, 187, 200),
		Surface = RuckusTheme and RuckusTheme.Colors.Surface or Color3.fromRGB(120, 192, 200),
		Text = RuckusTheme and RuckusTheme.Colors.Text or Color3.fromRGB(255, 251, 210),
		TextMuted = RuckusTheme and RuckusTheme.Colors.TextMuted or Color3.fromRGB(226, 221, 187),
		Danger = RuckusTheme and RuckusTheme.Colors.Danger or Color3.fromRGB(200, 110, 87),
		Success = RuckusTheme and RuckusTheme.Colors.Success or Color3.fromRGB(113, 200, 111),
		Black = Color3.new(0, 0, 0),
		Gold = RuckusTheme and RuckusTheme.Colors.Gold or Color3.fromRGB(200, 182, 111),
		GoldLight = RuckusTheme and RuckusTheme.Colors.GoldLight or Color3.fromRGB(255, 241, 162),
		GoldHighlight = Color3.fromRGB(255, 248, 205),
		GoldMid = Color3.fromRGB(220, 164, 50),
		GoldDark = RuckusTheme and RuckusTheme.Colors.GoldDark or Color3.fromRGB(126, 98, 48),
		GoldShadow = Color3.fromRGB(70, 52, 13),
		GoldOutline = RuckusTheme and RuckusTheme.Colors.GoldLight or Color3.fromRGB(255, 239, 170),
		GoldGlow = RuckusTheme and RuckusTheme.Colors.Gold or Color3.fromRGB(255, 211, 91),
		GoldText = RuckusTheme and RuckusTheme.Colors.Ivory or Color3.fromRGB(255, 251, 210),
		Silver = RuckusTheme and RuckusTheme.Colors.Silver or Color3.fromRGB(184, 193, 205),
		SilverLight = RuckusTheme and RuckusTheme.Colors.SilverLight or Color3.fromRGB(245, 249, 255),
		SilverHighlight = Color3.fromRGB(255, 255, 255),
		SilverMid = Color3.fromRGB(159, 167, 177),
		SilverDark = RuckusTheme and RuckusTheme.Colors.SilverDark or Color3.fromRGB(89, 98, 111),
		SilverShadow = Color3.fromRGB(69, 75, 83),
		SilverOutline = RuckusTheme and RuckusTheme.Colors.SilverLight or Color3.fromRGB(245, 249, 255),
		SilverGlow = RuckusTheme and RuckusTheme.Colors.Silver or Color3.fromRGB(184, 193, 205),
		SilverText = Color3.new(1, 1, 1)
	},
	Metric = {
		Inset = 3,
		InnerInset = 2,
		Stroke = 1,
		Padding = 12,
		PaddingLarge = 16,
		ControlHeight = 36,
		ControlHeightLarge = 44,
		BarHeight = RuckusTheme and RuckusTheme.Metric.BarHeight or 10,
		BarInset = RuckusTheme and RuckusTheme.Metric.BarInset or 2,
		ProfileHeight = 96,
		NavigationHeight = 34,
		NavigationWidth = 118,
		ListSpacing = 5,
		Icon = 20,
		PillRadius = 0
	},
	Typography = {
		Hero = {Size = 20, Weight = Enum.FontWeight.Heavy},
		Header = {Size = 15, Weight = Enum.FontWeight.Bold},
		Subtext = {Size = 12, Weight = Enum.FontWeight.Regular},
		Body = {Size = 14, Weight = Enum.FontWeight.Regular},
		Strong = {Size = 14, Weight = Enum.FontWeight.Bold},
		Caption = {Size = 12, Weight = Enum.FontWeight.Medium}
	},
	Effect = {
		Shadow = {Color = Color3.new(0, 0, 0), Transparency = .5, BlurRadius = UDim.new(0, 20)},
		Glow = {Color = Color3.fromRGB(255, 251, 210), Transparency = .5, BlurRadius = UDim.new(0, 10)},
		GlowStrong = {Color = Color3.fromRGB(255, 251, 210), Transparency = .5, BlurRadius = UDim.new(0, 20)},
		BarGlow = RuckusTheme and RuckusTheme.Effect and RuckusTheme.Effect.BarGlow
			or {Color = Color3.fromRGB(255, 251, 210), Transparency = .08, BlurRadius = UDim.new(0, 14)}
	},
	TextShadow = {
		Small = {Color = Color3.new(0, 0, 0), Transparency = .45, Offset = Vector2.new(1, 1)},
		Heavy = {Color = Color3.new(0, 0, 0), Transparency = .3, Offset = Vector2.new(2, 2)}
	},
	Opacity = {
		PanelSatin = 0,
		Disabled = .45,
		Muted = .35
	}
}

local function SurfaceFromTheme(Name, Shadow)
	local Source = RuckusTheme and RuckusTheme.Surfaces[Name]
	if not Source then return nil end
	return {
		SurfaceColor = Source.SatinColor,
		BaseColor = Source.BaseColor,
		AccentColor = Source.StrokeColor,
		Text = Source.TextColor or RUCKUS.Color.Text,
		BaseFill = true,
		SatinTransparency = Source.SatinTransparency,
		Gradient = Source.Gradient,
		OutlineGradient = Source.OutlineGradient,
		ShadowData = Shadow == false and nil or {
			Color = Source.ShadowColor,
			Transparency = Source.ShadowTransparency,
			BlurRadius = UDim.new(0, Source.ShadowBlur or 12)
		},
		Shadow = Shadow == false and false or 'Shadow',
		StrokeThickness = Source.StrokeThickness or 1,
		PersistentBorderShine = Source.PersistentBorderShine == true,
		PersistentShine = Source.PersistentShine == true,
		Metallic = Source.Metallic == true
	}
end

RUCKUS.Surfaces = {
	Regular = SurfaceFromTheme('Dark') or {
		SurfaceColor = RUCKUS.Color.AccentMuted, BaseColor = RUCKUS.Color.Dark,
		AccentColor = RUCKUS.Color.Ivory, Text = RUCKUS.Color.Ivory,
		BaseFill = true, SatinTransparency = 0, Shadow = 'Shadow'
	},
	Panel = SurfaceFromTheme('Panel') or {
		SurfaceColor = RUCKUS.Color.AccentMuted, BaseColor = RUCKUS.Color.Dark,
		AccentColor = RUCKUS.Color.Ivory, Text = RUCKUS.Color.Ivory,
		BaseFill = true, SatinTransparency = 0, Shadow = 'Shadow'
	},
	Inset = SurfaceFromTheme('Inset', false) or {
		SurfaceColor = RUCKUS.Color.AccentMuted, BaseColor = RUCKUS.Color.Dark,
		AccentColor = RUCKUS.Color.Ivory, Text = RUCKUS.Color.Ivory,
		BaseFill = true, SatinTransparency = .7, Shadow = false
	},
	Accent = SurfaceFromTheme('Accent') or {
		SurfaceColor = RUCKUS.Color.Accent, BaseColor = RUCKUS.Color.Dark,
		AccentColor = RUCKUS.Color.Ivory, Text = RUCKUS.Color.Ivory,
		BaseFill = true, SatinTransparency = 0, Shadow = 'Glow'
	},
	Danger = SurfaceFromTheme('Danger') or {
		SurfaceColor = Color3.fromRGB(200, 110, 87), BaseColor = RUCKUS.Color.Dark,
		AccentColor = RUCKUS.Color.Danger, Text = RUCKUS.Color.Ivory,
		BaseFill = true, SatinTransparency = 0, Shadow = 'Shadow'
	},
	Success = SurfaceFromTheme('Success') or {
		SurfaceColor = Color3.fromRGB(113, 200, 111), BaseColor = RUCKUS.Color.Dark,
		AccentColor = RUCKUS.Color.Success, Text = RUCKUS.Color.Ivory,
		BaseFill = true, SatinTransparency = 0, Shadow = 'Glow'
	},
	Gold = SurfaceFromTheme('Gold') or {
		SurfaceColor = RUCKUS.Color.Gold, BaseColor = RUCKUS.Color.Dark,
		AccentColor = RUCKUS.Color.GoldOutline, Text = RUCKUS.Color.Ivory,
		BaseFill = true, SatinTransparency = 0, Shadow = 'Shadow',
		PersistentBorderShine = true, PersistentShine = true, Metallic = true
	},
	Silver = SurfaceFromTheme('Silver') or {
		SurfaceColor = RUCKUS.Color.Silver, BaseColor = RUCKUS.Color.Dark,
		AccentColor = RUCKUS.Color.SilverOutline, Text = RUCKUS.Color.Ivory,
		BaseFill = true, SatinTransparency = .08, Shadow = 'Shadow',
		PersistentBorderShine = true, PersistentShine = true, Metallic = true
	}
}

RUCKUS.Surfaces.Gold.Gradient = Sequence(
	0, RUCKUS.Color.Dark,
	1, RUCKUS.Color.Dark
)
RUCKUS.Surfaces.Gold.OutlineGradient = Sequence(
	0, RUCKUS.Color.GoldLight,
	.5, RUCKUS.Color.Ivory,
	1, RUCKUS.Color.Gold
)
RUCKUS.Surfaces.Silver.Gradient = Sequence(
	0, RUCKUS.Color.Dark,
	1, RUCKUS.Color.Dark
)
RUCKUS.Surfaces.Silver.OutlineGradient = Sequence(
	0, RUCKUS.Color.SilverDark,
	.5, Color3.new(1, 1, 1),
	1, RUCKUS.Color.SilverLight
)

RUCKUS.Rarities = {}
if RuckusTheme then
	for Name, Data in pairs(RuckusTheme.Rarities) do
		RUCKUS.Rarities[Name] = {Color = Data.Color, Text = Data.Text or RUCKUS.Color.Text}
	end
else
	RUCKUS.Rarities = {
		Common = {Color = RUCKUS.Color.Surface, Text = RUCKUS.Color.Text},
		Uncommon = {Color = RUCKUS.Color.Success, Text = RUCKUS.Color.Text},
		Rare = {Color = RUCKUS.Color.Accent, Text = RUCKUS.Color.Text},
		Epic = {Color = Color3.fromRGB(206, 153, 255), Text = RUCKUS.Color.Ivory},
		Legendary = {Color = RUCKUS.Color.Warm, Text = RUCKUS.Color.Text},
		Mythic = {Color = Color3.fromRGB(255, 151, 204), Text = RUCKUS.Color.Text}
	}
end

local Generic = {
	Name = 'Generic',
	Color = {
		Text = Color3.fromRGB(32, 32, 32),
		TextMuted = Color3.fromRGB(96, 96, 96),
		Base = Color3.fromRGB(235, 235, 235),
		Inset = Color3.fromRGB(218, 218, 218),
		Accent = Color3.fromRGB(77, 148, 255),
		Danger = Color3.fromRGB(222, 92, 92),
		Success = Color3.fromRGB(107, 190, 112)
	},
	Metric = {
		Inset = 2,
		Stroke = 1,
		Padding = 8,
		PaddingLarge = 12,
		ControlHeight = 36,
		ControlHeightLarge = 44,
		PillRadius = 16
	},
	Typography = {
		Header = {Size = 16, Font = Enum.Font.ArialBold},
		Subtext = {Size = 12, Font = Enum.Font.Arial},
		Body = {Size = 12, Font = Enum.Font.Arial},
		Strong = {Size = 14, Font = Enum.Font.ArialBold},
		Caption = {Size = 11, Font = Enum.Font.Arial}
	}
}

Generic.Surfaces = {
	Regular = {
		SurfaceColor = Generic.Color.Base,
		BaseColor = Generic.Color.Base,
		AccentColor = Color3.fromRGB(130, 130, 130),
		Text = Generic.Color.Text,
		BaseFill = true,
		SatinTransparency = 1,
		Shadow = false
	},
	Panel = {
		SurfaceColor = Generic.Color.Base,
		BaseColor = Generic.Color.Base,
		AccentColor = Color3.fromRGB(130, 130, 130),
		Text = Generic.Color.Text,
		BaseFill = true,
		SatinTransparency = 1,
		Shadow = false
	},
	Inset = {
		SurfaceColor = Generic.Color.Inset,
		BaseColor = Generic.Color.Inset,
		AccentColor = Color3.fromRGB(130, 130, 130),
		Text = Generic.Color.Text,
		BaseFill = true,
		SatinTransparency = 1,
		Shadow = false
	},
	Accent = {
		SurfaceColor = Generic.Color.Accent,
		BaseColor = Generic.Color.Accent,
		AccentColor = Color3.new(1, 1, 1),
		Text = Color3.new(1, 1, 1),
		BaseFill = true,
		SatinTransparency = 1,
		Shadow = false
	},
	Danger = {
		SurfaceColor = Generic.Color.Danger,
		BaseColor = Generic.Color.Danger,
		AccentColor = Color3.new(1, 1, 1),
		Text = Color3.new(1, 1, 1),
		BaseFill = true,
		SatinTransparency = 1,
		Shadow = false
	},
	Success = {
		SurfaceColor = Generic.Color.Success,
		BaseColor = Generic.Color.Success,
		AccentColor = Color3.new(1, 1, 1),
		Text = Color3.new(1, 1, 1),
		BaseFill = true,
		SatinTransparency = 1,
		Shadow = false
	}
}

Generic.Rarities = {
	Common = {Color = Color3.fromRGB(190, 190, 190), Text = Generic.Color.Text},
	Uncommon = {Color = Color3.fromRGB(126, 190, 111), Text = Generic.Color.Text},
	Rare = {Color = Color3.fromRGB(92, 157, 222), Text = Color3.new(1, 1, 1)},
	Epic = {Color = Color3.fromRGB(151, 101, 211), Text = Color3.new(1, 1, 1)},
	Legendary = {Color = Color3.fromRGB(220, 175, 75), Text = Generic.Color.Text},
	Mythic = {Color = Color3.fromRGB(218, 106, 163), Text = Color3.new(1, 1, 1)}
}

StylePacks.Packs = {
	RUCKUS = RUCKUS,
	Generic = Generic
}

local function RuckusRuntimeTheme()
	local Ruckus = ReplicatedStorage:FindFirstChild('RUCKUS')
	local UI = Ruckus and Ruckus:FindFirstChild('UI')
	local Module = UI and UI:FindFirstChild('Theme')
	if not Module or not Module:IsA('ModuleScript') then return nil end

	local Success, Theme = pcall(require, Module)
	return Success and type(Theme) == 'table' and Theme or nil
end

function StylePacks:GetNames()
	local Names = {}
	for Name in pairs(self.Packs) do table.insert(Names, Name) end
	table.sort(Names)
	return Names
end

function StylePacks:Get(Name)
	local Pack = self.Packs[Name] or self.Packs[self.Default]
	if Pack.Name == 'RUCKUS' then
		local Theme = RuckusRuntimeTheme()
		if Theme then
			Pack.RuntimeTheme = Theme
			Pack.Asset.Satin = Theme.Asset and Theme.Asset.Satin or Pack.Asset.Satin
			Pack.Asset.Rubik = Theme.Asset and Theme.Asset.Rubik or Pack.Asset.Rubik
		end
	end
	return Pack
end

function StylePacks:GetSurfaceNames(PackName)
	local Pack = self:Get(PackName)
	local Names = {}
	for Name in pairs(Pack.Surfaces or {}) do table.insert(Names, Name) end
	table.sort(Names)
	return Names
end

function StylePacks:GetRarityNames(PackName)
	local Pack = self:Get(PackName)
	local Names = {}
	for Name in pairs(Pack.Rarities or {}) do table.insert(Names, Name) end
	table.sort(Names)
	return Names
end

function StylePacks:GetSurface(PackName, SurfaceName)
	local Pack = self:Get(PackName)
	return Pack.Surfaces and (Pack.Surfaces[SurfaceName] or Pack.Surfaces.Regular)
end

function StylePacks:GetTypography(PackName, Role)
	local Pack = self:Get(PackName)
	Role = Role or 'Body'
	return Pack.Typography[Role] or Pack.Typography.Body or Pack.Typography.Subtext
end

function StylePacks:ApplyTypography(Object, Role, PackName)
	if not Object or not Object:IsA('TextLabel') and not Object:IsA('TextButton') and not Object:IsA('TextBox') then
		return false
	end

	local Pack = self:Get(PackName)
	local Token = self:GetTypography(PackName, Role)
	Object:SetAttribute('FORGEStylePack', Pack.Name)
	Object:SetAttribute('FORGETypographyRole', Role or 'Body')

	if Pack.Name == 'RUCKUS' then
		SafeSet(Object, 'FontFace', Font.new(Pack.Asset.Rubik, Token.Weight, Enum.FontStyle.Normal))
		Object.TextColor3 = Pack.Color.Text
	else
		Object.Font = Token.Font or Enum.Font.Arial
		Object.TextColor3 = Pack.Color.Text
	end

	Object.TextSize = Token.Size or 12
	return true
end

function StylePacks:ApplyTextShadow(Object, Preset, PackName)
	if not Object or not Object:IsA('TextLabel') then return nil end
	local Pack = self:Get(PackName)
	if Pack.Name ~= 'RUCKUS' then return nil end

	local Data = Pack.TextShadow[Preset or 'Small'] or Pack.TextShadow.Small
	local Shadow = FindOrCreate(Object.Parent, 'TextLabel', '_FORGETextShadow_' .. Object.Name)
	if not Shadow then return nil end

	Shadow.BackgroundTransparency = 1
	Shadow.BorderSizePixel = 0
	Shadow.Text = Object.Text
	Shadow.TextColor3 = Data.Color
	Shadow.TextTransparency = Data.Transparency
	Shadow.TextSize = Object.TextSize
	Shadow.FontFace = Object.FontFace
	Shadow.TextXAlignment = Object.TextXAlignment
	Shadow.TextYAlignment = Object.TextYAlignment
	Shadow.AnchorPoint = Object.AnchorPoint
	Shadow.Position = Object.Position + UDim2.fromOffset(Data.Offset.X, Data.Offset.Y)
	Shadow.Size = Object.Size
	Shadow.ZIndex = math.max(Object.ZIndex - 1, 1)
	Shadow.Active = false
	return Shadow
end

local function CleanSurfaceInternals(Object)
	for _, Name in ipairs({
		'_FORGESurfaceGradient',
		'_FORGEBaseGradient',
		'_FORGEOutlineGradient',
		'_FORGECorner',
		'_FORGEMaterial',
		'_FORGESatin',
		'_FORGEInset',
		'_FORGEContent',
		'_FORGEOverlay',
		'_FORGEShine',
		'_FORGEShadow'
	}) do
		Remove(Object, Name)
	end
end

local function ApplyAuthoredTransparencyGradient(Object, Gradient, DefaultRotation)
	if not Object or not Gradient then return false end
	local Preset = Object:GetAttribute('FORGETransparencyGradientPreset')
	local Sequence = Object:GetAttribute('FORGETransparencyGradientSequence')
	if not Preset or Preset == 'None' or typeof(Sequence) ~= 'NumberSequence' then return false end

	Gradient.Transparency = Sequence
	Gradient.Rotation = tonumber(Object:GetAttribute('FORGETransparencyGradientRotation')) or DefaultRotation or 0
	return true
end

local function ApplyGenericSurface(Object, Surface, Pack, Options)
	Object.BackgroundColor3 = Surface.BaseColor or Surface.SurfaceColor
	Object.BackgroundTransparency = Surface.BaseFill == false and 1 or 0
	Object.BorderSizePixel = 0

	local Preset = Object:GetAttribute('FORGETransparencyGradientPreset')
	if Preset and Preset ~= 'None' then
		local Gradient = FindOrCreate(Object, 'UIGradient', '_FORGEBaseGradient')
		if Gradient then
			Gradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
			ApplyAuthoredTransparencyGradient(Object, Gradient, 0)
		end
	end

	local InsetEnabled = Object:GetAttribute('FORGEInsetEnabled') ~= false
	if InsetEnabled then
		local Stroke = FindOrCreate(Object, 'UIStroke', '_FORGEInset')
		if Stroke then
			Stroke.Color = Surface.AccentColor
			Stroke.Thickness = Pack.Metric.Stroke or 1
		end
	else
		Remove(Object, '_FORGEInset')
	end

	if Options.Pill then
		local Corner = FindOrCreate(Object, 'UICorner', '_FORGECorner')
		if Corner then Corner.CornerRadius = UDim.new(0, Pack.Metric.PillRadius or 16) end
	end
end

local function ResolveSurfaceColor(Surface, Pack)
	return Surface.SurfaceColor or Surface.BaseColor or Pack.Color.Surface or Pack.Color.Base or Color3.new(1, 1, 1)
end

local function ResolveAccentColor(Surface, Pack)
	return Surface.AccentColor or Pack.Color.InsetDark or Pack.Color.Ivory or ResolveSurfaceColor(Surface, Pack)
end

local function ApplyRuckusSurface(Object, Surface, Pack, Options)
	Object.BorderSizePixel = 0
	Object.BackgroundColor3 = Surface.BaseColor or Pack.Color.Dark
	Object.BackgroundTransparency = Surface.BaseFill == false and 1 or 0
	Object.ClipsDescendants = false
	if Object.ZIndex < 2 then Object.ZIndex = 2 end

	local TransparencyPreset = Object:GetAttribute('FORGETransparencyGradientPreset')
	if Surface.Gradient or (TransparencyPreset and TransparencyPreset ~= 'None') then
		local BaseGradient = FindOrCreate(Object, 'UIGradient', '_FORGEBaseGradient')
		if BaseGradient then
			BaseGradient.Color = Surface.Gradient or ColorSequence.new(Color3.new(1, 1, 1))
			if not ApplyAuthoredTransparencyGradient(Object, BaseGradient, Surface.Gradient and 90 or 0) then
				BaseGradient.Transparency = NumberSequence.new(0)
				BaseGradient.Rotation = Surface.Gradient and 90 or 0
			end
		end
	else
		Remove(Object, '_FORGEBaseGradient')
	end

	local Material = FindOrCreate(Object, 'Frame', '_FORGEMaterial')
	Material.BackgroundTransparency = 1
	Material.BorderSizePixel = 0
	Material.Position = UDim2.fromScale(0, 0)
	Material.Size = UDim2.fromScale(1, 1)
	Material.ZIndex = Object.ZIndex
	Material.Active = false
	Material.ClipsDescendants = Options.Pill == true

	local Satin = FindOrCreate(Material, 'ImageLabel', '_FORGESatin')
	if Satin then
		Satin.BackgroundTransparency = 1
		Satin.BorderSizePixel = 0
		Satin.Image = Pack.Asset.Satin
		Satin.ImageColor3 = ResolveSurfaceColor(Surface, Pack)
		Satin.ImageTransparency = Surface.SatinTransparency or 0
		Satin.ScaleType = Enum.ScaleType.Crop
		Satin.Position = UDim2.fromScale(0, 0)
		Satin.Size = UDim2.fromScale(1, 1)
		Satin.ZIndex = Material.ZIndex
		Satin.Active = false

		Remove(Satin, '_FORGESurfaceGradient')
	end

	local InsetEnabled = Object:GetAttribute('FORGEInsetEnabled') ~= false
	if InsetEnabled then
		local InsetPixels = math.max(0, math.floor((tonumber(Object:GetAttribute('FORGEInsetPixels')) or Pack.Metric.Inset or 2) + .5))
		local Inset = FindOrCreate(Object, 'Frame', '_FORGEInset')
		if Inset then
			Inset.BackgroundTransparency = 1
			Inset.BorderSizePixel = 0
			Inset.Position = UDim2.fromOffset(InsetPixels, InsetPixels)
			Inset.Size = UDim2.new(1, -(InsetPixels * 2), 1, -(InsetPixels * 2))
			Inset.ZIndex = Object.ZIndex + 1
			Inset.Active = false

			local Stroke = FindOrCreate(Inset, 'UIStroke', '_FORGEOutline')
			if Stroke then
				Stroke.LineJoinMode = Enum.LineJoinMode.Miter
				Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				Stroke.Thickness = Surface.StrokeThickness or Pack.Metric.Stroke
				Stroke.Color = ResolveAccentColor(Surface, Pack)
				Stroke.Transparency = 0

				if Surface.OutlineGradient then
					local Gradient = FindOrCreate(Stroke, 'UIGradient', '_FORGEOutlineGradient')
					if Gradient then
						Gradient.Color = Surface.OutlineGradient
						Gradient.Rotation = 18
						Gradient.Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, .18),
							NumberSequenceKeypoint.new(.5, 0),
							NumberSequenceKeypoint.new(1, .18)
						})
					end
				else
					Remove(Stroke, '_FORGEOutlineGradient')
				end
			end
		end
	else
		Remove(Object, '_FORGEInset')
	end

	local Shadow = FindOrCreate(Object, 'UIShadow', '_FORGEShadow')
	if Shadow then
		local Data = Surface.ShadowData or Pack.Effect[Surface.Shadow or 'Shadow']
		if Surface.Shadow == false then
			Shadow.Enabled = false
		elseif Data then
			Shadow.Enabled = true
			SafeSet(Shadow, 'Color', Data.Color)
			SafeSet(Shadow, 'Transparency', Data.Transparency)
			SafeSet(Shadow, 'BlurRadius', Data.BlurRadius)
			SafeSet(Shadow, 'Offset', UDim2.fromOffset(0, 0))
		end
	end

	local NeedsShine = Surface.PersistentShine == true or Object:IsA('GuiButton')
	if NeedsShine then
		local Shine = FindOrCreate(Material, 'Frame', '_FORGEShine')
		if Shine then
			Shine.BackgroundColor3 = Color3.new(1, 1, 1)
			Shine.BorderSizePixel = 0
			Shine.Position = UDim2.fromScale(0, 0)
			Shine.Size = UDim2.fromScale(1, 1)
			Shine.ZIndex = Material.ZIndex + 1
			Shine.Active = false
			Shine.BackgroundTransparency = Surface.PersistentShine and .94 or 1
			Shine:SetAttribute('FORGEPersistentShine', Surface.PersistentShine == true)

			local Gradient = FindOrCreate(Shine, 'UIGradient', '_FORGEShineGradient')
			if Gradient then
				Gradient.Rotation = 18
				Gradient.Offset = Vector2.new(-1.15, 0)
				Gradient.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(.34, 1),
					NumberSequenceKeypoint.new(.45, .52),
					NumberSequenceKeypoint.new(.5, .2),
					NumberSequenceKeypoint.new(.55, .52),
					NumberSequenceKeypoint.new(.66, 1),
					NumberSequenceKeypoint.new(1, 1)
				})
			end
		end
	else
		Remove(Material, '_FORGEShine')
	end
end

function StylePacks:ApplySurface(Object, SurfaceName, PackName, Options)
	if not Object or not Object:IsA('GuiObject') then return false end

	local Pack = self:Get(PackName)
	local Surface = self:GetSurface(PackName, SurfaceName)
	if not Surface then return false end
	Options = Options or {}

	-- Once a surface has been authored, rebuilding its generated internals must
	-- never reset user-facing appearance state. Persistence intentionally prunes
	-- those internals, so this path runs again after reopening FORGE Studio.
	local HadSurface = Object:GetAttribute('FORGEStyleSurface') ~= nil
	local PreserveAppearance = HadSurface or Options.PreserveAppearance == true
	local Appearance
	if PreserveAppearance then
		Appearance = {
			Visible = Object.Visible,
			BackgroundTransparency = Object.BackgroundTransparency
		}
		if Object:IsA('TextLabel') or Object:IsA('TextButton') or Object:IsA('TextBox') then
			Appearance.TextTransparency = Object.TextTransparency
		end
		if Object:IsA('ImageLabel') or Object:IsA('ImageButton') then
			Appearance.ImageTransparency = Object.ImageTransparency
		end
		if Object:IsA('CanvasGroup') then
			Appearance.GroupTransparency = Object.GroupTransparency
		end
	end

	Object:SetAttribute('FORGEStylePack', Pack.Name)
	Object:SetAttribute('FORGEStyleSurface', SurfaceName)
	CleanSurfaceInternals(Object)

	if Pack.Name == 'RUCKUS' then
		ApplyRuckusSurface(Object, Surface, Pack, Options)
	else
		ApplyGenericSurface(Object, Surface, Pack, Options)
	end

	if Object:IsA('TextLabel') or Object:IsA('TextButton') or Object:IsA('TextBox') then
		Object.TextColor3 = Surface.Text or Pack.Color.Text
	end

	if Appearance then
		Object.Visible = Appearance.Visible
		Object.BackgroundTransparency = Appearance.BackgroundTransparency
		if Appearance.TextTransparency ~= nil then Object.TextTransparency = Appearance.TextTransparency end
		if Appearance.ImageTransparency ~= nil then Object.ImageTransparency = Appearance.ImageTransparency end
		if Appearance.GroupTransparency ~= nil then Object.GroupTransparency = Appearance.GroupTransparency end
	end
	return true
end

function StylePacks:SetRuckusSurfaceState(Object, State, PackName)
	if not Object or not Object:IsA('GuiObject') then return false end
	local Pack = self:Get(PackName or 'RUCKUS')
	if Pack.Name ~= 'RUCKUS' then return false end

	local SurfaceName = Object:GetAttribute('FORGEStyleSurface') or 'Regular'
	local Surface = self:GetSurface(Pack.Name, SurfaceName)
	local Material = Object:FindFirstChild('_FORGEMaterial')
	local Satin = Material and Material:FindFirstChild('_FORGESatin')
	local Shine = Material and Material:FindFirstChild('_FORGEShine')
	local Shadow = Object:FindFirstChild('_FORGEShadow')
	local Active = State == 'Hover' or State == 'Pressed' or State == 'Selected'

	if Satin then
		Satin.ImageColor3 = ResolveSurfaceColor(Surface, Pack)
		Satin.ImageTransparency = State == 'Disabled'
			and math.min((Surface.SatinTransparency or 0) + .35, 1)
			or Surface.SatinTransparency or 0
	end

	if Shine then
		if Surface.PersistentShine then
			Shine.BackgroundTransparency = .94
		else
			Shine.BackgroundTransparency = Active and .94 or 1
		end
	end

	if Shadow then
		local Base = Surface.ShadowData or Pack.Effect.Shadow
		local Data = Active and Pack.Effect.GlowStrong or Base
		if Data then
			Shadow.Enabled = true
			SafeSet(Shadow, 'Color', Data.Color)
			SafeSet(Shadow, 'Transparency', Data.Transparency)
			SafeSet(Shadow, 'BlurRadius', Data.BlurRadius)
		end
	end
	return true
end

function StylePacks:ApplyRarity(Object, RarityName, PackName)
	local Pack = self:Get(PackName)
	local Rarity = Pack.Rarities and Pack.Rarities[RarityName]
	if not Rarity or not Object or not Object:IsA('GuiObject') then return false end

	Object:SetAttribute('FORGEStylePack', Pack.Name)
	Object:SetAttribute('FORGERarity', RarityName)

	if Pack.Name == 'RUCKUS' then
		local Material = Object:FindFirstChild('_FORGEMaterial')
		local Satin = Material and Material:FindFirstChild('_FORGESatin') or Object:FindFirstChild('Satin')
		local Inset = Object:FindFirstChild('_FORGEInset') or Object:FindFirstChild('Inset')
		local Stroke = Inset and (Inset:FindFirstChild('_FORGEOutline') or Inset:FindFirstChildWhichIsA('UIStroke'))
		local Color = Rarity.Color or Pack.Color.Surface or Pack.Color.Base or Color3.new(1, 1, 1)
		if Satin then Satin.ImageColor3 = Color end
		if Stroke then Stroke.Color = Color end
	else
		Object.BackgroundColor3 = Rarity.Color
	end

	if Object:IsA('TextLabel') or Object:IsA('TextButton') or Object:IsA('TextBox') then
		Object.TextColor3 = Rarity.Text or Pack.Color.Text
	end
	return true
end

return StylePacks
