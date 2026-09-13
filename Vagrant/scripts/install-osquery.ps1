# Installs a pinned standalone osquery sensor for Wazuh ingestion.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$commonScript = if (Test-Path "$PSScriptRoot\SocLab.Common.ps1") {
    "$PSScriptRoot\SocLab.Common.ps1"
} else {
    "C:\vagrant\scripts\SocLab.Common.ps1"
}
. $commonScript

$configuration = Get-SocLabConfiguration
$version = $configuration.OSQUERY_VERSION
$installer = "C:\ProgramData\SocDetectionLab\cache\osquery-$version.msi"
$downloadUrl = "https://github.com/osquery/osquery/releases/download/$version/osquery-$version.msi"
$programData = "C:\ProgramData\osquery"
$installRoot = "C:\Program Files\osquery"
$flagFile = Join-Path $programData "osquery.flags"
$configFile = Join-Path $programData "osquery.conf"

if (-not (Get-Service -Name "osqueryd" -ErrorAction SilentlyContinue)) {
    Invoke-VerifiedDownload -Uri $downloadUrl -Destination $installer -Sha256 $configuration.OSQUERY_WINDOWS_SHA256
    Assert-TrustedMsiSignature -Path $installer -AllowedPublishers @("The Linux Foundation", "osquery")

    $process = Start-Process "$env:SystemRoot\System32\msiexec.exe" `
        -ArgumentList @("/i", "`"$installer`"", "/qn", "/norestart") `
        -Wait -PassThru
    if ($process.ExitCode -notin @(0, 3010)) {
        throw "osquery installation failed with exit code $($process.ExitCode)."
    }
}

New-Item -ItemType Directory -Path "$programData\log" -Force | Out-Null
Copy-Item "C:\vagrant\resources\osquery\osquery.conf" $configFile -Force
@(
    "--config_path=$configFile"
    "--logger_plugin=filesystem"
    "--logger_path=$programData\log"
    "--disable_events=false"
    "--logger_min_status=1"
) | Set-Content -LiteralPath $flagFile -Encoding Ascii

$binary = Join-Path $installRoot "osqueryd\osqueryd.exe"
if (-not (Test-Path -LiteralPath $binary)) {
    throw "osqueryd binary not found after installation."
}

$service = Get-CimInstance -ClassName Win32_Service -Filter "Name='osqueryd'"
$binaryPath = "`"$binary`" --flagfile=`"$flagFile`""
if (-not $service) {
    New-Service -Name "osqueryd" -BinaryPathName $binaryPath -StartupType Automatic | Out-Null
} elseif ($service.PathName -ne $binaryPath) {
    Stop-Service -Name "osqueryd" -Force -ErrorAction SilentlyContinue
    & sc.exe config osqueryd binPath= $binaryPath start= auto | Out-Null
}

Start-Service -Name "osqueryd"
Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
if ((Get-Service -Name "osqueryd").Status -ne "Running") {
    throw "osqueryd is not running."
}
