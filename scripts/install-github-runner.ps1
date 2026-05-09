param(
    [Parameter(Mandatory = $true)]
    [string]$Organization,

    [Parameter(Mandatory = $true)]
    [string]$RunnerName,

    [string]$RunnerVersion = "2.329.0",
    [string]$RunnerRoot = "C:\actions-runner",
    [string]$RunnerGroup = "Default",
    [string]$Labels = "seolith-build,docker,dotnet10,node24"
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

& .\config.cmd `
    --url "https://github.com/$Organization" `
    --token $token `
    --name $RunnerName `
    --runnergroup $RunnerGroup `
    --labels $Labels `
    --work "_work" `
    --replace `
    --unattended

& .\svc install
& .\svc start

Write-Host "Runner installed and started: $RunnerName"
Write-Host "Labels: self-hosted, windows, x64, $Labels"
