$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Logs = Join-Path $Root 'logs'
$SyncPid = Join-Path $Logs 'live-sync.pid'
Set-Location $Root
New-Item -ItemType Directory -Force -Path $Logs | Out-Null
& (Join-Path $PSScriptRoot 'validate.ps1')

function Prepare-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue) -or -not (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
        Write-Warning 'Git unavailable; running Rojo without live sync.'
        return $false
    }
    $Branch = (& git branch --show-current).Trim()
    if (-not $Branch) { Write-Warning 'Detached HEAD; live sync disabled.'; return $false }
    Write-Host "[Grow a Planet] Current branch: $Branch"
    & git fetch --quiet origin $Branch 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Warning 'Remote fetch failed; live sync will retry.'; return $true }
    $Dirty = @(& git status --porcelain)
    $Ahead = [int]((& git rev-list "origin/$Branch..HEAD" --count).Trim())
    $Behind = [int]((& git rev-list "HEAD..origin/$Branch" --count).Trim())
    if ($Dirty.Count -eq 0 -and $Ahead -eq 0 -and $Behind -gt 0) {
        & git pull --ff-only origin $Branch
        if ($LASTEXITCODE -ne 0) { throw 'Fast-forward pull failed.' }
    } elseif ($Dirty.Count -gt 0 -or $Ahead -gt 0) {
        Write-Warning 'Local work exists. Auto-pull will not overwrite it.'
    }
    return $true
}
function Start-Sync {
    if (Test-Path -LiteralPath $SyncPid) {
        $RecordedId = 0
        [void][int]::TryParse((Get-Content -LiteralPath $SyncPid -Raw).Trim(), [ref]$RecordedId)
        if ($RecordedId -gt 0) {
            $Proc = Get-Process -Id $RecordedId -ErrorAction SilentlyContinue
            if ($Proc -and $Proc.ProcessName -match '^(powershell|pwsh)$') {
                try {
                    $Info = Get-CimInstance Win32_Process -Filter "ProcessId = $RecordedId" -ErrorAction Stop
                    if ($Info -and $Info.CommandLine -like '*live-sync.ps1*') {
                        Write-Host "[Grow a Planet] Git sync already running ($RecordedId)."
                        return
                    }
                } catch {}
            }
        }
        Remove-Item -LiteralPath $SyncPid -Force -ErrorAction SilentlyContinue
    }
    $ScriptPath = Join-Path $PSScriptRoot 'live-sync.ps1'
    $Out = Join-Path $Logs 'live-sync.log'
    $Err = Join-Path $Logs 'live-sync.error.log'
    Remove-Item -LiteralPath $Out,$Err -Force -ErrorAction SilentlyContinue
    $Arguments = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $ScriptPath + '"'))
    $Proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $Arguments -WorkingDirectory $Root -WindowStyle Hidden -RedirectStandardOutput $Out -RedirectStandardError $Err -PassThru
    Set-Content -LiteralPath $SyncPid -Value $Proc.Id -Encoding ascii
    Write-Host "[Grow a Planet] Git sync started (PID $($Proc.Id))."
}
$CanSync = Prepare-Git
& (Join-Path $PSScriptRoot 'serve.ps1')
if ($CanSync) { Start-Sync }
Write-Host '[Grow a Planet] Rojo: http://localhost:34878' -ForegroundColor Green
