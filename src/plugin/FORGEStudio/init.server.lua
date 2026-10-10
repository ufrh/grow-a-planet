local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerStorage = game:GetService('ServerStorage')

local BundledApp = require(script.App)
local BundledBuilder = require(script.Builder)
local BundledBuilderGenerators = require(script.BuilderGenerators)
local BundledBuilderModuleTools = require(script.BuilderModuleTools)
local BundledBuilderApp = BundledBuilderModuleTools.wrap(BundledBuilderGenerators.wrap(BundledBuilder))

local ServerDev = ServerStorage:FindFirstChild('FORGEStudioDev')
local LegacyDev = ReplicatedStorage:FindFirstChild('FORGEStudioDev')
if ServerDev and LegacyDev then LegacyDev:Destroy() end

local Toolbar = plugin:CreateToolbar('FORGE')
local StudioButton = Toolbar:CreateButton('FORGEStudioOpen', 'Open FORGE UI Studio', '', 'FORGE Studio')
local BuilderButton = Toolbar:CreateButton('FORGEBuilder', 'Open FORGE Builder', '', 'FORGE Builder')
local ReloadDevButton = Toolbar:CreateButton('FORGEReloadDev', 'Reload FORGE Studio + Builder from FORGEStudioDev', '', 'Reload Dev')

local Info = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	true,
	1200,
	720,
	720,
	480
)

local Widget = plugin:CreateDockWidgetPluginGui('FORGE_UI_STUDIO_V1', Info)
Widget.Title = 'FORGE UI Studio'

local BuilderInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	true,
	380,
	650,
	320,
	420
)

local BuilderWidget = plugin:CreateDockWidgetPluginGui('FORGE_BUILDER_V1', BuilderInfo)
BuilderWidget.Title = 'FORGE Builder'

local Studio
local RuntimeSource
local CurrentApp = BundledApp
local CurrentDevMode = false
local Reloading = false
local ReloadDev

local BuilderStudio
local BuilderRuntimeSource
local CurrentBuilderApp = BundledBuilderApp
local CurrentBuilderDevMode = false
local BuilderReloading = false
local ReloadBuilderDev

local function ClearOrphanedRoots(Keep)
	for _, Child in ipairs(Widget:GetChildren()) do
		if Child:IsA('GuiObject') and Child.Name == 'FORGEStudio' and Child ~= Keep then
			Child:Destroy()
		end
	end
end

local function ClearOrphanedBuilderRoots(Keep)
	for _, Child in ipairs(BuilderWidget:GetChildren()) do
		if Child:IsA('GuiObject') and Child.Name == 'FORGEBuilder' and Child ~= Keep then
			Child:Destroy()
		end
	end
end

local function SetStatus(Text)
	if Studio and Studio.SetStatus then
		Studio:SetStatus(Text)
	else
		warn('[FORGE Studio] ' .. tostring(Text))
	end
end

local function SetBuilderStatus(Text, Good)
	if BuilderStudio and BuilderStudio._setStatus then
		BuilderStudio:_setStatus(Text, Good)
	else
		warn('[FORGE Builder] ' .. tostring(Text))
	end
end

local function GetDevSource()
	local Source = ServerStorage:FindFirstChild('FORGEStudioDev')
		or ReplicatedStorage:FindFirstChild('FORGEStudioDev')
	if not Source then
		return nil, 'FORGEStudioDev is not mounted. Using bundled FORGE Studio until Rojo reconnects.'
	end

	for _, Name in ipairs({'App', 'Document', 'Selection', 'Theme', 'Widgets'}) do
		if not Source:FindFirstChild(Name) then
			return nil, 'FORGEStudioDev is incomplete. Missing ' .. Name .. '.'
		end
	end

	return Source
end

local function LoadDevApp()
	local Source, Error = GetDevSource()
	if not Source then return nil, nil, Error end

	local Clone = Source:Clone()
	Clone.Name = 'FORGEStudioRuntime'

	for _, Name in ipairs({'History', 'Components', 'Animations', 'Bindings', 'MockData', 'Screens', 'Navigation', 'StylePacks', 'ComponentPresets', 'Modifiers', 'RuckusStyle', 'Serializer', 'Packaging', 'Problems', 'Persistence'}) do
		if not Clone:FindFirstChild(Name) then
			local Bundled = script.Parent:FindFirstChild(Name)
			if Bundled then Bundled:Clone().Parent = Clone end
		end
	end

	Clone.Parent = script

	local Success, Result = pcall(function()
		return require(Clone.App)
	end)

	if not Success then
		Clone:Destroy()
		return nil, nil, 'Dev compile failed: ' .. tostring(Result)
	end

	return Result, Clone
end

local function LoadDevBuilder()
	local Source, Error = GetDevSource()
	if not Source then return nil, nil, Error end

	for _, Name in ipairs({'Builder', 'BuilderDebug', 'BuilderGenerators', 'BuilderModuleTools', 'GeneratorControlPoints', 'Theme'}) do
		if not Source:FindFirstChild(Name) then
			return nil, nil, 'FORGEStudioDev is incomplete. Missing ' .. Name .. '.'
		end
	end

	local Clone = Source:Clone()
	Clone.Name = 'FORGEBuilderRuntime'
	Clone.Parent = script

	local Success, Result = pcall(function()
		local BaseBuilder = require(Clone.Builder)
		local Generators = require(Clone.BuilderGenerators)
		local ModuleTools = require(Clone.BuilderModuleTools)
		return ModuleTools.wrap(Generators.wrap(BaseBuilder))
	end)

	if not Success then
		Clone:Destroy()
		return nil, nil, 'Builder dev compile failed: ' .. tostring(Result)
	end

	return Result, Clone
end

local function Start(AppModule, DevMode, Session)
	ClearOrphanedRoots()
	local Result = AppModule.new(plugin, Widget, {
		ReloadDev = ReloadDev,
		DevMode = DevMode,
		Session = Session
	})
	ClearOrphanedRoots(Result and Result.Root)
	return Result
end

local function StartBuilder(AppModule, DevMode)
	ClearOrphanedBuilderRoots()
	local Result = AppModule.new(plugin, BuilderWidget, {
		ReloadDev = function()
			if ReloadBuilderDev then ReloadBuilderDev() end
		end,
		DevMode = DevMode,
	})
	ClearOrphanedBuilderRoots(Result and Result.Root)
	return Result
end

ReloadDev = function()
	if Reloading then return false end
	Reloading = true

	local NewApp, NewRuntime, Error = LoadDevApp()
	if not NewApp then
		SetStatus(Error or 'Development source unavailable; bundled FORGE Studio remains active')
		Reloading = false
		return false
	end

	local Session
	if Studio and Studio.CreateReloadSession then
		local Success, Result = pcall(function()
			return Studio:CreateReloadSession()
		end)
		if Success then Session = Result end
	end

	local PreviousStudio = Studio
	local PreviousRuntime = RuntimeSource
	local PreviousApp = CurrentApp
	local PreviousDevMode = CurrentDevMode

	if PreviousStudio then PreviousStudio:Destroy() end
	Studio = nil

	local Success, Result = pcall(function()
		return Start(NewApp, true, Session)
	end)

	if Success then
		Studio = Result
		ClearOrphanedRoots(Studio and Studio.Root)
		RuntimeSource = NewRuntime
		CurrentApp = NewApp
		CurrentDevMode = true
		if PreviousRuntime then PreviousRuntime:Destroy() end
		SetStatus('Development source reloaded')
		Reloading = false
		return true
	end

	warn('[FORGE Studio] Reload failed: ' .. tostring(Result))
	ClearOrphanedRoots()
	NewRuntime:Destroy()

	local Recovered, Recovery = pcall(function()
		return Start(PreviousApp, PreviousDevMode, Session)
	end)

	if Recovered then
		Studio = Recovery
		RuntimeSource = PreviousRuntime
		CurrentApp = PreviousApp
		CurrentDevMode = PreviousDevMode
		SetStatus('Reload failed - previous version restored')
	else
		if PreviousRuntime then PreviousRuntime:Destroy() end
		RuntimeSource = nil
		CurrentApp = BundledApp
		CurrentDevMode = false
		warn('[FORGE Studio] Recovery failed: ' .. tostring(Recovery))

		local FallbackSuccess, Fallback = pcall(function()
			return Start(BundledApp, false, Session)
		end)
		if FallbackSuccess then
			Studio = Fallback
			SetStatus('Reload failed - bundled version restored')
		end
	end

	Reloading = false
	return false
end

ReloadBuilderDev = function()
	if BuilderReloading then return false end
	BuilderReloading = true

	local NewApp, NewRuntime, Error = LoadDevBuilder()
	if not NewApp then
		SetBuilderStatus(Error or 'Builder development source unavailable.', false)
		BuilderReloading = false
		return false
	end

	local PreviousStudio = BuilderStudio
	local PreviousRuntime = BuilderRuntimeSource
	local PreviousApp = CurrentBuilderApp
	local PreviousDevMode = CurrentBuilderDevMode

	if PreviousStudio then PreviousStudio:Destroy() end
	BuilderStudio = nil

	local Success, Result = pcall(function()
		return StartBuilder(NewApp, true)
	end)

	if Success then
		BuilderStudio = Result
		ClearOrphanedBuilderRoots(BuilderStudio and BuilderStudio.Root)
		BuilderRuntimeSource = NewRuntime
		CurrentBuilderApp = NewApp
		CurrentBuilderDevMode = true
		if PreviousRuntime then PreviousRuntime:Destroy() end
		SetBuilderStatus('Development source reloaded.', true)
		BuilderReloading = false
		return true
	end

	warn('[FORGE Builder] Reload failed: ' .. tostring(Result))
	ClearOrphanedBuilderRoots()
	NewRuntime:Destroy()

	local Recovered, Recovery = pcall(function()
		return StartBuilder(PreviousApp, PreviousDevMode)
	end)

	if Recovered then
		BuilderStudio = Recovery
		BuilderRuntimeSource = PreviousRuntime
		CurrentBuilderApp = PreviousApp
		CurrentBuilderDevMode = PreviousDevMode
		SetBuilderStatus('Reload failed - previous version restored.', false)
	else
		if PreviousRuntime then PreviousRuntime:Destroy() end
		BuilderRuntimeSource = nil
		CurrentBuilderApp = BundledBuilderApp
		CurrentBuilderDevMode = false
		warn('[FORGE Builder] Recovery failed: ' .. tostring(Recovery))

		local FallbackSuccess, Fallback = pcall(function()
			return StartBuilder(BundledBuilderApp, false)
		end)
		if FallbackSuccess then
			BuilderStudio = Fallback
			SetBuilderStatus('Reload failed - bundled version restored.', false)
		end
	end

	BuilderReloading = false
	return false
end

ClearOrphanedRoots()
ClearOrphanedBuilderRoots()

if ServerStorage:FindFirstChild('FORGEStudioDev') or ReplicatedStorage:FindFirstChild('FORGEStudioDev') then
	local DevApp, DevRuntime = LoadDevApp()
	if DevApp then
		local Success, Result = pcall(function()
			return Start(DevApp, true)
		end)
		if Success then
			Studio = Result
			RuntimeSource = DevRuntime
			CurrentApp = DevApp
			CurrentDevMode = true
		else
			DevRuntime:Destroy()
			warn('[FORGE Studio] Dev startup failed: ' .. tostring(Result))
		end
	end

	local DevBuilder, DevBuilderRuntime = LoadDevBuilder()
	if DevBuilder then
		local Success, Result = pcall(function()
			return StartBuilder(DevBuilder, true)
		end)
		if Success then
			BuilderStudio = Result
			BuilderRuntimeSource = DevBuilderRuntime
			CurrentBuilderApp = DevBuilder
			CurrentBuilderDevMode = true
		else
			DevBuilderRuntime:Destroy()
			warn('[FORGE Builder] Dev startup failed: ' .. tostring(Result))
		end
	end
end

if not Studio then Studio = Start(BundledApp, false) end
if not BuilderStudio then BuilderStudio = StartBuilder(BundledBuilderApp, false) end

StudioButton.Click:Connect(function()
	Widget.Enabled = not Widget.Enabled
end)

BuilderButton.Click:Connect(function()
	BuilderWidget.Enabled = not BuilderWidget.Enabled
end)

ReloadDevButton.Click:Connect(function()
	ReloadDevButton:SetActive(true)
	local StudioOK = ReloadDev()
	local BuilderOK = ReloadBuilderDev()
	ReloadDevButton:SetActive(false)

	if StudioOK and BuilderOK then
		SetStatus('FORGE Studio + Builder development source reloaded')
		SetBuilderStatus('FORGE Studio + Builder development source reloaded.', true)
	elseif not StudioOK and not BuilderOK then
		warn('[FORGE] Reload Dev failed for Studio and Builder.')
	elseif not StudioOK then
		warn('[FORGE] Builder reloaded, but FORGE Studio reload failed.')
	else
		warn('[FORGE] FORGE Studio reloaded, but Builder reload failed.')
	end
end)

Widget:GetPropertyChangedSignal('Enabled'):Connect(function()
	StudioButton:SetActive(Widget.Enabled)
end)

BuilderWidget:GetPropertyChangedSignal('Enabled'):Connect(function()
	BuilderButton:SetActive(BuilderWidget.Enabled)
end)

plugin.Unloading:Connect(function()
	if BuilderStudio then BuilderStudio:Destroy() end
	if BuilderRuntimeSource then BuilderRuntimeSource:Destroy() end
	if Studio then Studio:Destroy() end
	if RuntimeSource then RuntimeSource:Destroy() end
end)
