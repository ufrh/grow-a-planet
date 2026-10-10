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
    'src/shared/StarterPlayerScripts/FORGE/Launch/Bootstrap.client.lua'
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $FilePath))) { throw "Missing FORGE/VAULT file: $FilePath" }
}
if (Test-Path -LiteralPath (Join-Path $Root 'src/plugin')) { throw 'Legacy Studio designer plugin is still present.' }
Write-Host '[Grow a Planet] Single-place configuration valid.' -ForegroundColor Green
