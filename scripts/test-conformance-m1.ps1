$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path $repoRoot 'tests/fixtures/conformance-m1'
$tempRepo = Join-Path ([IO.Path]::GetTempPath()) ('seolith-conformance-m1-' + [Guid]::NewGuid().ToString('N'))

try {
    Copy-Item -LiteralPath $fixture -Destination $tempRepo -Recurse
    git -C $tempRepo init -q
    git -C $tempRepo config user.email test@example.invalid
    git -C $tempRepo config user.name conformance-test
    git -C $tempRepo add -- .
    git -C $tempRepo commit -qm fixture

    $scriptPath = (Resolve-Path (Join-Path $repoRoot 'scripts/seolith-conformance.sh')).Path.Replace('\', '/')
    $tempRepoBash = $tempRepo.Replace('\', '/')
    if ($scriptPath -match '^([A-Za-z]):/(.*)$') { $scriptPath = "/mnt/$($matches[1].ToLower())/$($matches[2])" }
    if ($tempRepoBash -match '^([A-Za-z]):/(.*)$') { $tempRepoBash = "/mnt/$($matches[1].ToLower())/$($matches[2])" }
    $output = & bash $scriptPath $tempRepoBash 2>&1
    $m1Findings = @($output | Where-Object { $_ -match '^M1\t' })

    if ($m1Findings.Count -ne 1) {
        throw "Expected exactly one M1 finding, got $($m1Findings.Count):`n$($output -join "`n")"
    }
    if ($m1Findings[0] -notmatch 'generic-ci\.yml') {
        throw "The generic workflow must remain subject to M1: $($m1Findings[0])"
    }
    if ($m1Findings[0] -match 'security-gates\.yml') {
        throw "The security-gates workflow must be exempt from M1: $($m1Findings[0])"
    }

    Write-Output 'M1 security-gates exception contract passed.'
}
finally {
    if (Test-Path -LiteralPath $tempRepo) {
        Remove-Item -LiteralPath $tempRepo -Recurse -Force
    }
}
