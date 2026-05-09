param(
    [Parameter(Mandatory = $true)]
    [string]$Organization,

    [Parameter(Mandatory = $true)]
    [string]$RunnerName,

    [string]$RunnerVersion = "2.329.0",
    [string]$RunnerRoot = "C:\actions-runner",
    [string]$RunnerGroup = "Default",
    [string]$Labels = ""
)

$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "Run this script from an elevated PowerShell session."
}

$runnerUrl = "https://github.com/organizations/$Organization/settings/actions/runners/new?arch=x64&os=win"
Write-Host "Create a short-lived Windows x64 organization runner token here:"
Write-Host $runnerUrl
$token = Read-Host "Paste registration token"

New-Item -ItemType Directory -Force -Path $RunnerRoot | Out-Null
Set-Location $RunnerRoot

$archive = Join-Path $RunnerRoot "actions-runner-win-x64-$RunnerVersion.zip"
$downloadUrl = "https://github.com/actions/runner/releases/download/v$RunnerVersion/actions-runner-win-x64-$RunnerVersion.zip"

if (-not (Test-Path $archive)) {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archive
}

Expand-Archive -Path $archive -DestinationPath $RunnerRoot -Force

$configArgs = @(
    "--url", "https://github.com/$Organization",
    "--token", $token,
    "--name", $RunnerName,
    "--runnergroup", $RunnerGroup,
    "--work", "_work",
    "--replace",
    "--unattended"
)

if (-not [string]::IsNullOrWhiteSpace($Labels)) {
    $configArgs += @("--labels", $Labels)
}

& .\config.cmd @configArgs
if ($LASTEXITCODE -ne 0) {
    throw "Runner registration failed. Generate a fresh token and run the script again."
}

if (-not (Test-Path ".\svc.cmd")) {
    throw "Runner service helper svc.cmd was not found in $RunnerRoot."
}

& .\svc.cmd install
if ($LASTEXITCODE -ne 0) {
    throw "Runner service install failed."
}

& .\svc.cmd start
if ($LASTEXITCODE -ne 0) {
    throw "Runner service start failed."
}

Write-Host "Runner installed and started: $RunnerName"
if ([string]::IsNullOrWhiteSpace($Labels)) {
    Write-Host "Labels: self-hosted, windows, x64"
} else {
    Write-Host "Labels: self-hosted, windows, x64, $Labels"
}
