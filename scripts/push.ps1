param([Parameter(Position=0)][string]$Message = 'Update Grow a Planet')
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
if (-not (Get-Command git -ErrorAction SilentlyContinue) -or -not (Test-Path -LiteralPath (Join-Path $Root '.git'))) { throw 'Git or the local repository is missing.' }
$Branch = (& git branch --show-current).Trim()
if (-not $Branch) { throw 'Cannot push a detached HEAD.' }
& git add -A
if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }
$Dirty = @(& git status --porcelain)
if ($Dirty.Count -gt 0) {
    & git commit -m $Message
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed; local files remain.' }
}
& git push origin "HEAD:refs/heads/$Branch"
if ($LASTEXITCODE -ne 0) { throw 'git push failed. Commits remain locally.' }
Write-Host "[Grow a Planet] Pushed origin/$Branch." -ForegroundColor Green
