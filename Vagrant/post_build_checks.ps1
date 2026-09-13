[CmdletBinding()]
param(
    [ValidateSet("wazuh-core", "wazuh-ad", "soar-ai")]
    [string]$Profile = $(if ($env:SOC_PROFILE) { $env:SOC_PROFILE } else { "wazuh-core" })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

& "$PSScriptRoot\test_lab_health.ps1" -Profile $Profile
exit $LASTEXITCODE
