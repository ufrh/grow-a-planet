$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Logs = Join-Path $Root 'logs'
$PidFile = Join-Path $Logs 'rojo.pid'
$Port = 34878

function Get-Listener {
    try { return Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop | Select-Object -First 1 }
    catch { return $null }
}
function Find-Rojo {
    $Cmd = Get-Command rojo -ErrorAction SilentlyContinue
    if ($Cmd -and $Cmd.Source) { return $Cmd.Source }
    foreach ($Candidate in @(
        (Join-Path $env:USERPROFILE '.rokit\bin\rojo.exe'),
        (Join-Path $env:USERPROFILE '.aftman\bin\rojo.exe'),
        (Join-Path $env:LOCALAPPDATA 'Rokit\bin\rojo.exe')
    )) {
        if ($Candidate -and (Test-Path -LiteralPath $Candidate)) { return $Candidate }
    }
    throw 'Rojo not found. Run rokit install or add Rojo to PATH.'
}
function Own-Rojo([int]$ProcessId) {
    $Proc = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $Proc -or $Proc.ProcessName -notmatch '^rojo') { return $false }
    try {
        $Info = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction Stop
        return ($Info -and $Info.CommandLine -like '*grow-a-planet.project.json*')
    } catch { return $false }
}

New-Item -ItemType Directory -Force -Path $Logs | Out-Null
$Rojo = Find-Rojo
if (Test-Path -LiteralPath $PidFile) {
    $RecordedId = 0
    [void][int]::TryParse((Get-Content -LiteralPath $PidFile -Raw).Trim(), [ref]$RecordedId)
    if ($RecordedId -gt 0 -and (Own-Rojo $RecordedId)) {
        Write-Host "[Grow a Planet] Restarting our Rojo PID $RecordedId..."
        Stop-Process -Id $RecordedId -Force
        Start-Sleep -Milliseconds 250
    }
    Remove-Item -LiteralPath $PidFile -Force
}
$Other = Get-Listener
if ($Other) { throw "Port $Port is busy (PID $($Other.OwningProcess)). Refusing to stop another project." }

$Out = Join-Path $Logs 'rojo.log'
$Err = Join-Path $Logs 'rojo.error.log'
Remove-Item -LiteralPath $Out,$Err -Force -ErrorAction SilentlyContinue
Write-Host "[Grow a Planet] Starting single-place Rojo at http://localhost:$Port..."
$Proc = Start-Process -FilePath $Rojo -ArgumentList @('serve', 'grow-a-planet.project.json', '--port', [string]$Port) -WorkingDirectory $Root -RedirectStandardOutput $Out -RedirectStandardError $Err -PassThru
$Ready = $false
for ($i = 0; $i -lt 60; $i++) {
    if ($Proc.HasExited) { break }
    if (Get-Listener) { $Ready = $true; break }
    Start-Sleep -Milliseconds 150
}
if (-not $Ready) {
    if (-not $Proc.HasExited) { Stop-Process -Id $Proc.Id -Force -ErrorAction SilentlyContinue }
    $Detail = if (Test-Path -LiteralPath $Err) { Get-Content -LiteralPath $Err -Raw } else { '' }
    throw "Rojo failed to start. $Detail"
}
Set-Content -LiteralPath $PidFile -Value $Proc.Id -Encoding ascii
Write-Host "[Grow a Planet] Rojo running (PID $($Proc.Id))." -ForegroundColor Green
