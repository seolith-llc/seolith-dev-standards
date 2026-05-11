param(
    [string]$Root = "C:\src\seolith",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Test-FileContains {
    param(
        [string]$Path,
        [string[]]$Patterns
    )

    if (-not (Test-Path $Path)) { return $false }
    $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
    foreach ($pattern in $Patterns) {
        if ($content -match $pattern) { return $true }
    }
    return $false
}

$repos = Get-ChildItem $Root -Directory | Where-Object { Test-Path (Join-Path $_.FullName ".git") }

$results = foreach ($repo in $repos) {
    $path = $repo.FullName
    $tracked = @(git -C $path ls-files 2>$null)
    $csprojs = @($tracked | Where-Object { $_ -like "*.csproj" })
    $packages = @($tracked | Where-Object { $_ -eq "package.json" -or $_ -like "*/package.json" })
    $workerConfig = @($tracked | Where-Object { $_ -in @("wrangler.toml", "wrangler.json", "wrangler.jsonc") -or $_ -like "*/wrangler.toml" -or $_ -like "*/wrangler.json" -or $_ -like "*/wrangler.jsonc" })
    $workflows = @($tracked | Where-Object { $_ -like ".github/workflows/*.yml" -or $_ -like ".github/workflows/*.yaml" })

    $csprojText = ($csprojs | ForEach-Object { Get-Content (Join-Path $path $_) -Raw -ErrorAction SilentlyContinue }) -join "`n"
    $workflowText = ($workflows | ForEach-Object { Get-Content (Join-Path $path $_) -Raw -ErrorAction SilentlyContinue }) -join "`n"
    $packageText = ($packages | ForEach-Object { Get-Content (Join-Path $path $_) -Raw -ErrorAction SilentlyContinue }) -join "`n"

    $isDotNet = $csprojs.Count -gt 0
    $isNode = $packages.Count -gt 0
    $isWorker = $workerConfig.Count -gt 0

    $gaps = New-Object System.Collections.Generic.List[string]

    if ($isDotNet) {
        foreach ($pkg in @(
            "Seolith.Platform.Auth",
            "Seolith.Platform.Audit",
            "Seolith.Platform.Telemetry",
            "Seolith.Platform.Mail",
            "Seolith.Platform.Configuration",
            "Seolith.Platform.HealthChecks"
        )) {
            if ($csprojText -notmatch [regex]::Escape($pkg)) {
                $gaps.Add("dotnet-missing-$pkg")
            }
        }
    }

    if ($isNode -and $packageText -match '"(@angular/core|next|vite|react)"') {
        if ($packageText -notmatch '(@auth|oidc|oauth|angular-oauth2-oidc|next-auth|@azure/msal|auth0)') {
            $gaps.Add("frontend-no-obvious-oidc-client")
        }
        if ($packageText -match '"(@vite-pwa|vite-plugin-pwa|next-pwa|@angular/pwa|workbox-webpack-plugin)"') {
            if ($workflowText -notmatch "node-pwa-build.yml") {
                $gaps.Add("pwa-not-using-standard-workflow")
            }
        }
    }

    if ($isWorker) {
        $workerText = ($workerConfig | ForEach-Object { Get-Content (Join-Path $path $_) -Raw -ErrorAction SilentlyContinue }) -join "`n"
        if ($workerText -notmatch "(d1_databases|kv_namespaces|r2_buckets)") {
            $gaps.Add("worker-no-persistent-binding-detected")
        }
        if ($workflowText -notmatch "(self-hosted|wrangler|node-pwa-build.yml)") {
            $gaps.Add("worker-no-deploy-workflow-detected")
        }
    }

    if (($isDotNet -or $isNode) -and $workflowText -notmatch "seolith-dev-standards") {
        $gaps.Add("not-using-standards-workflows")
    }

    [pscustomobject]@{
        Name = $repo.Name
        Path = $path
        DotNet = $isDotNet
        Node = $isNode
        Worker = $isWorker
        CommonServicesReady = $gaps.Count -eq 0
        Gaps = ($gaps -join ",")
    }
}

if ($Json) {
    $results | Sort-Object Name | ConvertTo-Json -Depth 4
} else {
    $results | Sort-Object Name | Format-Table -AutoSize
}
