param(
    [string]$RunnerName = "seolith-build-01",
    [string]$Organization = "seolith-llc",
    [switch]$InstallRunner
)

$ErrorActionPreference = "Stop"

function Require-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run PowerShell as Administrator."
    }
}

function Require-Command {
    param([string]$Command)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "$Command is required. Install it first, then re-run this script."
    }
}

Require-Admin

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is required for the default bootstrap. Install App Installer from Microsoft Store first."
}

$packages = @(
    "Git.Git",
    "Microsoft.PowerShell",
    "Microsoft.DotNet.SDK.8",
    "Microsoft.DotNet.SDK.Preview",
    "OpenJS.NodeJS.LTS",
    "Docker.DockerDesktop",
    "EclipseAdoptium.Temurin.21.JDK"
)

foreach ($package in $packages) {
    Write-Host "Ensuring $package..." -ForegroundColor Cyan
    winget install --id $package --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>$null
}

Require-Command git
Require-Command node
Require-Command npm
Require-Command dotnet

$npmMajor = [int]((node --version).TrimStart("v").Split(".")[0])
if ($npmMajor -lt 24) {
    Write-Warning "Node 24 is the SEOlith standard. If winget installed an older LTS, install Node 24 before using this as the primary runner."
}

dotnet --list-sdks

if ($InstallRunner) {
    $script = Join-Path $PSScriptRoot "install-github-runner.ps1"
    & $script -Organization $Organization -RunnerName $RunnerName
}

Write-Host "Windows build VM baseline complete." -ForegroundColor Green
Write-Host "Next: confirm Docker Desktop starts, install Android command-line tools if needed, and add GitHub runner labels in the org settings."
