# apply-standard.ps1
# This script injects SEOlith enterprise standards into a target repository.

param (
    [Parameter(Mandatory=$true)]
    [string]$TargetRepoPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

if (-not (Test-Path $TargetRepoPath)) {
    Write-Error "Target repository path does not exist: $TargetRepoPath"
    exit 1
}

$standardsPath = Get-Location
$devContainerSource = Join-Path $standardsPath "devcontainers/universal/devcontainer.json"

Write-Host "Applying SEOlith Standards to: $TargetRepoPath" -ForegroundColor Cyan

# 1. Inject DevContainer
$targetDevContainerDir = Join-Path $TargetRepoPath ".devcontainer"
if (-not (Test-Path $targetDevContainerDir)) {
    New-Item -ItemType Directory -Path $targetDevContainerDir -Force
}

$targetFile = Join-Path $targetDevContainerDir "devcontainer.json"
if ((Test-Path $targetFile) -and (-not $Force)) {
    Write-Warning "devcontainer.json already exists in target. Use -Force to overwrite."
} else {
    Copy-Item -Path $devContainerSource -Destination $targetFile -Force
    Write-Host "  [OK] Injected Universal DevContainer" -ForegroundColor Green
}

# 2. Inject .editorconfig
$editorConfigPath = Join-Path $standardsPath ".editorconfig"
if (-not (Test-Path $editorConfigPath)) {
    @"
root = true
[*]
indent_style = space
indent_size = 4
[*.{js,jsx,ts,tsx,html,css,scss,json}]
indent_size = 2
"@ | Out-File -FilePath $editorConfigPath -Encoding utf8
}
Copy-Item -Path $editorConfigPath -Destination (Join-Path $TargetRepoPath ".editorconfig") -Force
Write-Host "  [OK] Injected Standard .editorconfig" -ForegroundColor Green

# 3. Inject CI Pipeline (Caller Workflows)
$targetGithubDir = Join-Path $TargetRepoPath ".github/workflows"
if (-not (Test-Path $targetGithubDir)) {
    New-Item -ItemType Directory -Path $targetGithubDir -Force
}

# Detect Tech Stack (Fixed Logic - Recursive)
$hasSln = Get-ChildItem -Path $TargetRepoPath -Filter "*.sln" -Recurse | Select-Object -First 1
$hasCsproj = Get-ChildItem -Path $TargetRepoPath -Filter "*.csproj" -Recurse | Select-Object -First 1
$isDotNet = ($null -ne $hasSln -or $null -ne $hasCsproj)

$pkgJson = Get-ChildItem -Path $TargetRepoPath -Filter "package.json" -Recurse | Where-Object { (Get-Content $_.FullName -Raw) -match "@angular/core" } | Select-Object -First 1
$isAngular = ($null -ne $pkgJson)

if ($isDotNet -or $isAngular) {
    $ciFileContent = @"
name: CI

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
"@

    if ($isDotNet) {
        Write-Host "  [DETECTION] Found .NET Project" -ForegroundColor Cyan
        $ciFileContent += "`n  dotnet-build-test:`n    uses: seolith-llc/seolith-dev-standards/.github/workflows/dotnet-build-test.yml@main"
        Write-Host "  [OK] Added .NET job to CI" -ForegroundColor Green
    }

    if ($isAngular) {
        Write-Host "  [DETECTION] Found Angular Project" -ForegroundColor Cyan
        $ciFileContent += "`n  angular-lint-build:`n    uses: seolith-llc/seolith-dev-standards/.github/workflows/angular-build-lint.yml@main"
        Write-Host "  [OK] Added Angular job to CI" -ForegroundColor Green
    }

    $ciFile = Join-Path $targetGithubDir "ci.yml"
    $ciFileContent | Out-File -FilePath $ciFile -Encoding utf8
}

Write-Host "`nStandards applied successfully." -ForegroundColor Cyan
