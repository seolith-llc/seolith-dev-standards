param(
    [string]$Root = "C:\src\seolith"
)

$ErrorActionPreference = "Stop"

Get-ChildItem $Root -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName ".git") } |
    ForEach-Object {
        $path = $_.FullName
        $status = @(git -C $path status --short 2>$null)
        $branch = git -C $path branch --show-current 2>$null
        $remote = git -C $path remote -v 2>$null | Select-Object -First 1
        $package = Join-Path $path "package.json"
        $frameworks = @()
        if (Test-Path $package) {
            try {
                $json = Get-Content $package -Raw | ConvertFrom-Json
                $deps = @()
                if ($json.dependencies) { $deps += $json.dependencies.PSObject.Properties.Name }
                if ($json.devDependencies) { $deps += $json.devDependencies.PSObject.Properties.Name }
                $frameworks = $deps | Where-Object { $_ -in @("next", "vite", "react", "@angular/core", "@capacitor/core") }
            } catch {
                $frameworks = @("package-json-parse-error")
            }
        }

        [pscustomobject]@{
            Name = $_.Name
            Branch = $branch
            Dirty = $status.Count -gt 0
            Frameworks = ($frameworks -join ",")
            Remote = $remote
            Status = (($status | Select-Object -First 3) -join "; ")
        }
    } |
    Sort-Object Name |
    Format-Table -AutoSize
