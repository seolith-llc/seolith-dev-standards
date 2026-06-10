param(
    [string]$Root = "C:\src\seolith",
    [string]$GitleaksPath = "C:\Tools\gitleaks\gitleaks.exe",
    [string]$GitleaksConfigPath = "C:\src\seolith\.gitleaks.toml",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Convert-ToGitBashPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath -match "^([A-Za-z]):\\(.*)$") {
        $drive = $Matches[1].ToLowerInvariant()
        $rest = $Matches[2] -replace "\\", "/"
        return "/$drive/$rest"
    }

    return ($fullPath -replace "\\", "/")
}

if (-not (Test-Path $Root)) {
    Write-Error "Root path does not exist: $Root"
    exit 1
}

if (-not (Test-Path $GitleaksPath)) {
    Write-Warning "gitleaks was not found at $GitleaksPath. Hooks will install, but commits will skip scanning until it exists."
}

if (-not (Test-Path $GitleaksConfigPath)) {
    Write-Warning "gitleaks config was not found at $GitleaksConfigPath."
}

$gitBashGitleaks = Convert-ToGitBashPath $GitleaksPath
$gitBashConfig = Convert-ToGitBashPath $GitleaksConfigPath

$hook = @"
#!/bin/sh
set -eu

echo "[gitleaks] Scanning staged files for secrets..."

GITLEAKS="$gitBashGitleaks"
CONFIG="$gitBashConfig"

if [ ! -x "`$GITLEAKS" ]; then
  echo "[gitleaks] Skipping: `$GITLEAKS is not executable."
  exit 0
fi

"`$GITLEAKS" protect --staged --config "`$CONFIG" --verbose
echo "[gitleaks] No secrets detected. Commit allowed."
"@

$repos = Get-ChildItem $Root -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName ".git") } |
    Sort-Object Name

$results = foreach ($repo in $repos) {
    $hookPathFromGit = git -C $repo.FullName rev-parse --git-path hooks/pre-commit 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($hookPathFromGit)) {
        [pscustomobject]@{
            Repo = $repo.Name
            Action = "skipped"
            Hook = "git hook path unavailable"
        }
        continue
    }

    if ([System.IO.Path]::IsPathRooted($hookPathFromGit)) {
        $hookPath = $hookPathFromGit
    } else {
        $hookPath = Join-Path $repo.FullName $hookPathFromGit
    }

    $hooksDir = Split-Path -Parent $hookPath
    $existed = Test-Path $hookPath

    if ($existed -and -not $Force) {
        [pscustomobject]@{
            Repo = $repo.Name
            Action = "kept"
            Hook = $hookPath
        }
        continue
    }

    if (-not (Test-Path $hooksDir)) {
        New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
    }

    Set-Content -LiteralPath $hookPath -Value $hook -NoNewline -Encoding utf8

    [pscustomobject]@{
        Repo = $repo.Name
        Action = if ($existed) { "updated" } else { "installed" }
        Hook = $hookPath
    }
}

$results | Format-Table -AutoSize

$installed = @($results | Where-Object Action -eq "installed").Count
$updated = @($results | Where-Object Action -eq "updated").Count
$kept = @($results | Where-Object Action -eq "kept").Count
$skipped = @($results | Where-Object Action -eq "skipped").Count

Write-Host ""
Write-Host "Pre-commit hook install complete: $installed installed, $updated updated, $kept kept, $skipped skipped." -ForegroundColor Cyan
