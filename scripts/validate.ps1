$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$File = Join-Path $Root 'grow-a-planet.project.json'
if (-not (Test-Path -LiteralPath $File)) { throw 'Missing project file.' }
$Project = Get-Content -LiteralPath $File -Raw | ConvertFrom-Json
if ([long]$Project.placeId -ne 102865473124541) { throw 'Wrong place ID.' }
if ([long]$Project.gameId -ne 10770120558) { throw 'Wrong experience ID.' }
if (@($Project.servePlaceIds).Count -ne 1 -or [long]$Project.servePlaceIds[0] -ne 102865473124541) { throw 'Expected one served place.' }
if ([int]$Project.servePort -ne 34878) { throw 'Wrong Rojo port.' }
foreach ($FilePath in @(
    'src/shared/ReplicatedStorage/FORGE/init.lua',
    'src/shared/ServerScriptService/FORGE/Launch/Bootstrap.server.lua',
    'src/shared/ServerScriptService/VAULT/init.lua',
    'src/shared/StarterPlayerScripts/FORGE/Launch/Bootstrap.client.lua',
    'src/shared/ReplicatedStorage/GrowAPlanet/Generation/Config.lua',
    'src/shared/ReplicatedStorage/GrowAPlanet/Generation/VoxelField.lua',
    'src/shared/ReplicatedStorage/GrowAPlanet/Generation/GreedyMesher.lua',
    'src/shared/ReplicatedStorage/GrowAPlanet/Generation/Renderer.lua',
    'src/shared/ReplicatedStorage/GrowAPlanet/Generation/SelfTest.lua',
    'src/game/ServerScriptService/PlanetBootstrap.server.lua',
    'src/game/StarterPlayerScripts/PlanetPrototype.client.lua'
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $FilePath))) { throw "Missing FORGE/VAULT file: $FilePath" }
}
if (Test-Path -LiteralPath (Join-Path $Root 'src/plugin')) { throw 'Legacy Studio designer plugin is still present.' }
if ($Project.tree.ServerScriptService.PlanetBootstrap.'$path' -ne 'src/game/ServerScriptService/PlanetBootstrap.server.lua') { throw 'PlanetBootstrap not mapped.' }
if ($Project.tree.StarterPlayer.StarterPlayerScripts.PlanetPrototype.'$path' -ne 'src/game/StarterPlayerScripts/PlanetPrototype.client.lua') { throw 'PlanetPrototype not mapped.' }
Write-Host '[Grow a Planet] Single-place generation prototype configuration valid.' -ForegroundColor Green
