$ErrorActionPreference = 'Stop'
$Logs = Join-Path (Split-Path -Parent $PSScriptRoot) 'logs'
function Stop-Recorded([string]$FileName,[string]$ExePattern,[string]$ArgPattern) {
    $File = Join-Path $Logs $FileName
    if (-not (Test-Path -LiteralPath $File)) { return }
    $ProcessId = 0
    [void][int]::TryParse((Get-Content -LiteralPath $File -Raw).Trim(), [ref]$ProcessId)
    if ($ProcessId -gt 0) {
        $Proc = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($Proc -and $Proc.ProcessName -match $ExePattern) {
            try {
                $Info = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction Stop
                if ($Info -and $Info.CommandLine -like "*$ArgPattern*") {
                    Write-Host "[Grow a Planet] Stopping PID $ProcessId..."
                    Stop-Process -Id $ProcessId -Force
                } else { Write-Warning "PID $ProcessId does not belong to this project. Not stopping." }
            } catch { Write-Warning "Unable to verify/stop PID $ProcessId : $_" }
        }
    }
    Remove-Item -LiteralPath $File -Force -ErrorAction SilentlyContinue
}
Stop-Recorded 'rojo.pid' '^rojo' 'grow-a-planet.project.json'
Stop-Recorded 'live-sync.pid' '^(powershell|pwsh)$' 'live-sync.ps1'
Write-Host '[Grow a Planet] Development processes stopped.' -ForegroundColor Green
