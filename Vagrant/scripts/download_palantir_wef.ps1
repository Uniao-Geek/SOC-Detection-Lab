# Downloads a pinned Palantir Windows Event Forwarding snapshot.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$commonScript = if (Test-Path "$PSScriptRoot\SocLab.Common.ps1") {
    "$PSScriptRoot\SocLab.Common.ps1"
} else {
    "C:\vagrant\scripts\SocLab.Common.ps1"
}
. $commonScript

$configuration = Get-SocLabConfiguration
$cacheRoot = "C:\ProgramData\SocDetectionLab\cache"
$archive = Join-Path $cacheRoot "windows-event-forwarding.zip"
$staging = Join-Path $cacheRoot "windows-event-forwarding-staging"
$destination = "C:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master"
$sourceUrl = "https://github.com/palantir/windows-event-forwarding/archive/$($configuration.PALANTIR_WEF_COMMIT).zip"

if (Test-Path -LiteralPath $destination -PathType Container) {
    Write-Host "Pinned Windows Event Forwarding content already exists."
    return
}

Invoke-VerifiedDownload -Uri $sourceUrl -Destination $archive -Sha256 $configuration.PALANTIR_WEF_SHA256
Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -LiteralPath $archive -DestinationPath $staging -Force

$extracted = Get-ChildItem -LiteralPath $staging -Directory
if ($extracted.Count -ne 1 -or $extracted[0].Name -ne "windows-event-forwarding-$($configuration.PALANTIR_WEF_COMMIT)") {
    throw "Unexpected Windows Event Forwarding archive layout."
}

New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
Move-Item -LiteralPath $extracted[0].FullName -Destination $destination
Remove-Item -LiteralPath $archive, $staging -Recurse -Force
Write-Host "Pinned Windows Event Forwarding content installed."
