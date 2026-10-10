param([ValidateRange(1,3600)][int]$IntervalSeconds = 3)
$ErrorActionPreference = 'Continue'
Set-Location (Split-Path -Parent $PSScriptRoot)
Write-Host '[Grow a Planet] Fast-forward Git sync active.'
while ($true) {
    try {
        $Branch = (& git branch --show-current 2>$null).Trim()
        if ($Branch) {
            $Dirty = @(& git status --porcelain 2>$null)
            if ($Dirty.Count -eq 0) {
                & git fetch --quiet origin $Branch 2>$null
                if ($LASTEXITCODE -eq 0) {
                    & git show-ref --verify --quiet "refs/remotes/origin/$Branch"
                    if ($LASTEXITCODE -eq 0) {
                        $Ahead = [int]((& git rev-list "origin/$Branch..HEAD" --count).Trim())
                        $Behind = [int]((& git rev-list "HEAD..origin/$Branch" --count).Trim())
                        if ($Ahead -eq 0 -and $Behind -gt 0) {
                            Write-Host "[Grow a Planet] Pulling $Behind commit(s) for $Branch..."
                            & git pull --ff-only origin $Branch
                        }
                    }
                }
            }
        }
    } catch { Write-Host "[Grow a Planet] Git sync retry: $($_.Exception.Message)" }
    Start-Sleep -Seconds $IntervalSeconds
}
