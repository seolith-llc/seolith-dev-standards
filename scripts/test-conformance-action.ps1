$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$actionPath = Join-Path $repoRoot '.github/actions/conformance/action.yml'
$workflowPath = Join-Path $repoRoot '.github/workflows/conformance.yml'

if (-not (Test-Path -LiteralPath $actionPath)) {
    throw 'Conformance composite action is missing'
}

$action = Get-Content -Raw -LiteralPath $actionPath
$workflow = Get-Content -Raw -LiteralPath $workflowPath

if ($action -notmatch '(?m)^\s*using:\s*composite\s*$') {
    throw 'Conformance action must be a composite action'
}

if ($workflow -notmatch 'seolith-dev-standards/\.github/actions/conformance@') {
    throw 'Conformance workflow must consume the versioned composite action'
}

if ($workflow -match 'repository:\s*seolith-llc/seolith-dev-standards') {
    throw 'Conformance workflow must not clone the private standards repository with GITHUB_TOKEN'
}

Write-Output 'Conformance composite action contract passed.'
