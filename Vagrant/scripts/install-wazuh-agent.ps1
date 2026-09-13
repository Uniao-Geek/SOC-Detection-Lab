# Installs a pinned Wazuh agent and enables the lab telemetry channels.

[CmdletBinding()]
param(
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}$')]
    [string]$ManagerAddress = "192.168.56.105"
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
$required = @("WAZUH_VERSION", "WAZUH_AGENT_URL", "WAZUH_AGENT_SHA256")
foreach ($key in $required) {
    if (-not $configuration.ContainsKey($key)) {
        throw "Missing required configuration key: $key"
    }
}

$installer = Join-Path $env:ProgramData "SocDetectionLab\cache\wazuh-agent-$($configuration.WAZUH_VERSION).msi"
$installRoot = "${env:ProgramFiles(x86)}\ossec-agent"
$service = Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue

if (-not $service) {
    Invoke-VerifiedDownload -Uri $configuration.WAZUH_AGENT_URL -Destination $installer -Sha256 $configuration.WAZUH_AGENT_SHA256
    Assert-TrustedMsiSignature -Path $installer -AllowedPublishers @("Wazuh, Inc")

    $arguments = @(
        "/i", "`"$installer`"", "/qn", "/norestart",
        "WAZUH_MANAGER=`"$ManagerAddress`"",
        "WAZUH_REGISTRATION_SERVER=`"$ManagerAddress`"",
        "WAZUH_AGENT_NAME=`"$env:COMPUTERNAME`""
    )
    $process = Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -notin @(0, 3010)) {
        throw "Wazuh agent installation failed with exit code $($process.ExitCode)."
    }
}

$configPath = Join-Path $installRoot "ossec.conf"
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Wazuh agent configuration was not created."
}

[xml]$xml = Get-Content -LiteralPath $configPath -Raw
$root = $xml.ossec_config
$locations = @(
    @{ Location = "Microsoft-Windows-Sysmon/Operational"; Format = "eventchannel"; Future = "yes" },
    @{ Location = "Microsoft-Windows-PowerShell/Operational"; Format = "eventchannel"; Future = "yes" },
    @{ Location = "C:\SocLab\Replay\events.jsonl"; Format = "json" },
    @{ Location = "C:\ProgramData\osquery\log\osqueryd.results.log"; Format = "json" }
)

$availableEventLogs = @(wevtutil.exe el)
if ($env:COMPUTERNAME -ieq "WEF") {
    $wefCandidates = @(
        "ForwardedEvents",
        "WEC-Powershell",
        "WEC-WMI",
        "WEC-EMET",
        "WEC-Authentication",
        "WEC-Services",
        "WEC-Process-Execution",
        "WEC-Code-Integrity",
        "WEC2-Registry",
        "WEC2-Applocker",
        "WEC2-Object-Manipulation",
        "WEC2-Task-Scheduler",
        "WEC2-Application-Crashes",
        "WEC2-Windows-Defender",
        "WEC2-Group-Policy-Errors",
        "WEC2-File-System",
        "WEC3-Drivers",
        "WEC3-Account-Management",
        "WEC3-Windows-Diagnostics",
        "WEC3-Smart-Card",
        "WEC3-USB",
        "WEC3-Print",
        "WEC3-Firewall",
        "WEC4-Wireless",
        "WEC4-Shares",
        "WEC4-Bits-Client",
        "WEC4-Windows-Updates",
        "WEC4-Hotpatching-Errors",
        "WEC4-DNS",
        "WEC4-System-Time-Change",
        "WEC5-Operating-System",
        "WEC5-Certificate-Authority",
        "WEC5-Crypto-API",
        "WEC5-MSI-Packages",
        "WEC5-Log-Deletion-Security",
        "WEC5-Log-Deletion-System",
        "WEC5-Autoruns",
        "WEC6-Sysmon",
        "WEC6-Software-Restriction-Policies",
        "WEC6-Microsoft-Office",
        "WEC6-Exploit-Guard",
        "WEC6-Duo-Security",
        "WEC6-Device-Guard",
        "WEC6-ADFS",
        "WEC7-Active-Directory",
        "WEC7-Terminal-Services",
        "WEC7-Privilege-Use"
    )
    foreach ($candidate in $wefCandidates) {
        if ($candidate -in $availableEventLogs) {
            $locations += @{ Location = $candidate; Format = "eventchannel"; Future = "no" }
        }
    }
    $locations += @{ Location = "C:\pslogs\*.txt"; Format = "multi-line:20" }
}

if ($env:COMPUTERNAME -ieq "EXCHANGE") {
    foreach ($candidate in @(
        "Application",
        "MSExchange Management",
        "Microsoft-Exchange-ActiveMonitoring/ProbeResult"
    )) {
        if ($candidate -in $availableEventLogs) {
            $locations += @{ Location = $candidate; Format = "eventchannel"; Future = "yes" }
        }
    }
}

New-Item -ItemType Directory -Path "C:\SocLab\Replay" -Force | Out-Null
foreach ($entry in $locations) {
    $exists = @($root.localfile) | Where-Object { $_.location -eq $entry.Location }
    if (-not $exists) {
        $localfile = $xml.CreateElement("localfile")
        $location = $xml.CreateElement("location")
        $location.InnerText = $entry.Location
        $format = $xml.CreateElement("log_format")
        $format.InnerText = $entry.Format
        [void]$localfile.AppendChild($location)
        [void]$localfile.AppendChild($format)
        if ($entry.ContainsKey("Future")) {
            $future = $xml.CreateElement("only-future-events")
            $future.InnerText = $entry.Future
            [void]$localfile.AppendChild($future)
        }
        [void]$root.AppendChild($localfile)
    }
}
$xml.Save($configPath)

Set-Service -Name "WazuhSvc" -StartupType Automatic
Restart-Service -Name "WazuhSvc" -Force
Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue

if ((Get-Service -Name "WazuhSvc").Status -ne "Running") {
    throw "Wazuh agent is not running."
}
