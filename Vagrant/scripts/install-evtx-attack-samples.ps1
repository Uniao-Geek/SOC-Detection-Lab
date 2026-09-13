# Installs a pinned EVTX sample corpus without replaying it automatically.

[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9 _./\\-]+\.evtx$')]
    [string]$ReplaySample
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$commonScript = if (Test-Path "$PSScriptRoot\SocLab.Common.ps1") {
    "$PSScriptRoot\SocLab.Common.ps1"
} else {
    "C:\vagrant\scripts\SocLab.Common.ps1"
}
. $commonScript

$configuration = Get-SocLabConfiguration
$destination = "C:\Tools\EVTX-ATTACK-SAMPLES"
$commit = $configuration.EVTX_ATTACK_SAMPLES_COMMIT
$remote = "https://github.com/sbousseaden/EVTX-ATTACK-SAMPLES.git"

if (-not (Test-Path -LiteralPath "$destination\.git")) {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    & git -C $destination init --quiet
    & git -C $destination remote add origin $remote
}

& git -C $destination fetch --quiet --depth 1 origin $commit
if ($LASTEXITCODE -ne 0) {
    throw "Failed to fetch the pinned EVTX sample corpus."
}
& git -C $destination checkout --quiet --detach $commit
if ($LASTEXITCODE -ne 0 -or (& git -C $destination rev-parse HEAD) -ne $commit) {
    throw "EVTX sample corpus integrity check failed."
}

if ($ReplaySample) {
    $root = [IO.Path]::GetFullPath($destination) + [IO.Path]::DirectorySeparatorChar
    $sample = [IO.Path]::GetFullPath((Join-Path $destination $ReplaySample))
    if (-not $sample.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $sample -PathType Leaf)) {
        throw "Replay sample is outside the pinned corpus."
    }
    $replayScript = if (Test-Path "$PSScriptRoot\replay-evtx.ps1") {
        "$PSScriptRoot\replay-evtx.ps1"
    } else {
        "C:\vagrant\scripts\replay-evtx.ps1"
    }
    & $replayScript -Path $sample -TrustedSampleRoot $destination
}

Write-Host "Pinned EVTX corpus installed. No sample was replayed automatically."
