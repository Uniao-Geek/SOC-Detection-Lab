# Installs pinned detection-validation content. It does not execute any test.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$commonScript = if (Test-Path "$PSScriptRoot\SocLab.Common.ps1") {
    "$PSScriptRoot\SocLab.Common.ps1"
} else {
    "C:\vagrant\scripts\SocLab.Common.ps1"
}
. $commonScript

$configuration = Get-SocLabConfiguration
$toolsRoot = "C:\Tools\AtomicRedTeam"
$moduleRoot = "$env:ProgramFiles\WindowsPowerShell\Modules"

function Sync-PinnedRepository {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^https://github\.com/[\w.-]+/[\w.-]+\.git$')]
        [string]$Remote,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-f0-9]{40}$')]
        [string]$Commit,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath "$Destination\.git")) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        & git -C $Destination init --quiet
        & git -C $Destination remote add origin $Remote
    }

    & git -C $Destination fetch --quiet --depth 1 origin $Commit
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to fetch pinned commit from $Remote."
    }
    & git -C $Destination checkout --quiet --detach $Commit
    if ($LASTEXITCODE -ne 0 -or (& git -C $Destination rev-parse HEAD) -ne $Commit) {
        throw "Repository integrity check failed for $Remote."
    }
}

Sync-PinnedRepository `
    -Remote "https://github.com/redcanaryco/atomic-red-team.git" `
    -Commit $configuration.ATOMIC_RED_TEAM_COMMIT `
    -Destination "$toolsRoot\atomic-red-team"

Sync-PinnedRepository `
    -Remote "https://github.com/redcanaryco/invoke-atomicredteam.git" `
    -Commit $configuration.INVOKE_ATOMIC_COMMIT `
    -Destination "$toolsRoot\invoke-atomicredteam"

Sync-PinnedRepository `
    -Remote "https://github.com/cloudbase/powershell-yaml.git" `
    -Commit "00679dffe0e7853fd63e68d3522269961652d895" `
    -Destination "$toolsRoot\powershell-yaml"

$yamlModule = "$moduleRoot\powershell-yaml"
$atomicModule = "$moduleRoot\Invoke-AtomicRedTeam"
Remove-Item -LiteralPath $yamlModule, $atomicModule -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $yamlModule, $atomicModule -Force | Out-Null
Copy-Item "$toolsRoot\powershell-yaml\*" $yamlModule -Recurse -Force
Copy-Item "$toolsRoot\invoke-atomicredteam\*" $atomicModule -Recurse -Force

$profileDirectory = Split-Path -Parent $PROFILE.AllUsersAllHosts
New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
$profileBlock = @'
# SOC-LAB-ATOMIC-START
# SOC Detection Lab: pinned Atomic Red Team module.
Import-Module Invoke-AtomicRedTeam -Force
$PSDefaultParameterValues["Invoke-AtomicTest:PathToAtomicsFolder"] = "C:\Tools\AtomicRedTeam\atomic-red-team\atomics"
# SOC-LAB-ATOMIC-END
'@
$existingProfile = if (Test-Path -LiteralPath $PROFILE.AllUsersAllHosts) {
    Get-Content -LiteralPath $PROFILE.AllUsersAllHosts -Raw
} else {
    ""
}
if ($existingProfile -notmatch '(?m)^# SOC-LAB-ATOMIC-START$') {
    Add-Content -LiteralPath $PROFILE.AllUsersAllHosts -Value $profileBlock -Encoding UTF8
}

Import-Module Invoke-AtomicRedTeam -Force
if (-not (Get-Command Invoke-AtomicTest -ErrorAction SilentlyContinue)) {
    throw "Invoke-AtomicTest was not installed."
}

Write-Host "Pinned Atomic Red Team content installed. No simulation was executed."
