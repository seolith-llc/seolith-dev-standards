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

# Detect Tech Stack (Fixed Logic)
$hasSln = Test-Path (Join-Path $TargetRepoPath "*.sln")
$hasCsproj = Get-ChildItem -Path $TargetRepoPath -Filter "*.csproj" -Recurse | Select-Object -First 1
$isDotNet = ($hasSln -or $hasCsproj)

$pkgJsonPath = Join-Path $TargetRepoPath "package.json"
$isAngular = $false
if (Test-Path $pkgJsonPath) {
    $content = Get-Content $pkgJsonPath
    if ($content -match "@angular/core") {
        $isAngular = $true
    }
}

if ($isDotNet) {
    Write-Host "  [DETECTION] Found .NET Project" -ForegroundColor Cyan
    $ciFile = Join-Path $targetGithubDir "ci.yml"
    @"
name: CI

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  build-and-test:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/dotnet-build-test.yml@main
"@ | Out-File -FilePath $ciFile -Encoding utf8
    Write-Host "  [OK] Injected .NET CI Pipeline" -ForegroundColor Green
}

if ($isAngular) {
    Write-Host "  [DETECTION] Found Angular Project" -ForegroundColor Cyan
    $ciFile = Join-Path $targetGithubDir "ci.yml"
    @"
name: CI

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  lint-and-build:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/angular-build-lint.yml@main
"@ | Out-File -FilePath $ciFile -Encoding utf8
    Write-Host "  [OK] Injected Angular CI Pipeline" -ForegroundColor Green
}

Write-Host "`nStandards applied successfully." -ForegroundColor Cyan
