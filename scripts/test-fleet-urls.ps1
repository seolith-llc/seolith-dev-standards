param(
    [string]$CatalogSeeder = "C:\src\seolith\seolith-apps-showcase\backend\src\AppShowcase.Infrastructure\Data\DataSeeder.cs",
    [string[]]$Url,
    [int]$TimeoutSeconds = 20,
    [switch]$Json,
    [switch]$AllowProtected
)

$ErrorActionPreference = "Stop"

function Get-CatalogUrls {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Catalog seeder was not found: $Path"
    }

    $content = Get-Content $Path -Raw
    [regex]::Matches($content, 'https://[^"'']+') |
        ForEach-Object { $_.Value.TrimEnd(".", ",", ";") } |
        Sort-Object -Unique
}

function Test-FleetUrl {
    param(
        [string]$TargetUrl,
        [int]$Timeout
    )

    try {
        $response = Invoke-WebRequest -Uri $TargetUrl -UseBasicParsing -TimeoutSec $Timeout -MaximumRedirection 5
        $title = ""
        if ($response.Content -match "<title>(.*?)</title>") {
            $title = [System.Net.WebUtility]::HtmlDecode($Matches[1])
        }

        $classification = if ($title -match "authentik|sign in|login") {
            "protected"
        } elseif ($title -match "Domain Suite|Lovable App|Create Next App|Local Environment") {
            "placeholder"
        } else {
            "app"
        }

        [pscustomobject]@{
            Url = $TargetUrl
            Status = [int]$response.StatusCode
            Classification = $classification
            Title = $title
            Bytes = $response.RawContentLength
            Error = ""
        }
    } catch {
        $status = 0
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
        }

        [pscustomobject]@{
            Url = $TargetUrl
            Status = $status
            Classification = "broken"
            Title = ""
            Bytes = 0
            Error = $_.Exception.Message
        }
    }
}

$targets = if ($Url -and $Url.Count -gt 0) {
    $Url | Sort-Object -Unique
} else {
    Get-CatalogUrls -Path $CatalogSeeder
}

$results = foreach ($target in $targets) {
    Test-FleetUrl -TargetUrl $target -Timeout $TimeoutSeconds
}

if ($Json) {
    $results | ConvertTo-Json -Depth 4
} else {
    $results | Sort-Object Status, Classification, Url | Format-Table -AutoSize
    $summary = $results | Group-Object Classification | Sort-Object Name | ForEach-Object {
        "$($_.Name)=$($_.Count)"
    }
    Write-Host ("Summary: " + ($summary -join ", "))
}

$failed = $results | Where-Object {
    $_.Status -eq 0 -or
    $_.Status -ge 400 -or
    ((-not $AllowProtected) -and $_.Classification -eq "protected")
}

if ($failed.Count -gt 0) {
    exit 2
}
