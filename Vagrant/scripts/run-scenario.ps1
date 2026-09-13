[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]{0,63}$')]
    [string]$ScenarioId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$manifestPath = "C:\vagrant\resources\scenarios\$ScenarioId.json"
$eventPath = "C:\SocLab\Replay\events.jsonl"
$allowedProperties = @(
    "schema_version", "id", "title", "kind", "attack_technique",
    "atomic_guid", "risk", "timeout_seconds", "telemetry",
    "expected_alert", "cleanup"
)
$atomicAllowlist = @{
    "powershell-obfuscated"  = "a538de64-1c74-46ed-aa60-b995ed302598"
    "registry-run-key"       = "e55be3fd-3521-4610-9d1a-e210e42dcf05"
    "credential-enumeration" = "36753ded-e5c4-4eb5-bc3c-e8fba236878d"
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Scenario manifest not found."
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$unexpected = @($manifest.PSObject.Properties.Name | Where-Object { $_ -notin $allowedProperties })
if ($unexpected.Count -gt 0) {
    throw "Unexpected manifest fields: $($unexpected -join ', ')"
}
if ($manifest.schema_version -ne 1 -or $manifest.id -ne $ScenarioId) {
    throw "Scenario manifest identity or schema is invalid."
}
if ($manifest.kind -notin @("atomic", "builtin") -or
    $manifest.risk -notin @("low", "medium") -or
    $manifest.attack_technique -notmatch '^T\d{4}(?:\.\d{3})?$' -or
    -not ($manifest.title -is [string]) -or
    $manifest.title.Length -gt 160) {
    throw "Scenario manifest fields are invalid."
}
if ($manifest.timeout_seconds -lt 10 -or $manifest.timeout_seconds -gt 300) {
    throw "Scenario timeout is outside the allowed range."
}

New-Item -ItemType Directory -Path (Split-Path -Parent $eventPath) -Force | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-ScenarioEvent {
    param(
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][bool]$ExpectedAlert
    )

    $event = @{
        timestamp = [DateTime]::UtcNow.ToString("o")
        soc_lab = @{
            event_type = "telemetry"
            scenario_id = $manifest.id
            title = $manifest.title
            attack_technique = $manifest.attack_technique
            status = $Status
            expected_alert = $ExpectedAlert
        }
    } | ConvertTo-Json -Compress -Depth 4
    [IO.File]::AppendAllText($eventPath, "$event`n", $utf8)
}

function Invoke-AllowlistedAtomic {
    $expectedGuid = $atomicAllowlist[$ScenarioId]
    if (-not $expectedGuid -or $manifest.atomic_guid -ne $expectedGuid) {
        throw "Atomic test is not allowlisted for this scenario."
    }

    $atomicsPath = "C:\Tools\AtomicRedTeam\atomic-red-team\atomics"
    $job = Start-Job -ArgumentList $expectedGuid, $atomicsPath -ScriptBlock {
        param($Guid, $AtomicsPath)
        Import-Module Invoke-AtomicRedTeam -Force
        Invoke-AtomicTest -TestGuids $Guid -PathToAtomicsFolder $AtomicsPath -Confirm:$false
    }
    try {
        if (-not (Wait-Job -Job $job -Timeout $manifest.timeout_seconds)) {
            Stop-Job -Job $job
            throw "Atomic test exceeded its timeout."
        }
        Receive-Job -Job $job -ErrorAction Stop
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        Import-Module Invoke-AtomicRedTeam -Force
        Invoke-AtomicTest -TestGuids $expectedGuid -PathToAtomicsFolder $atomicsPath -Cleanup -Confirm:$false
    }
}

function Invoke-BuiltinScenario {
    switch ($ScenarioId) {
        "lateral-smb-probe" {
            $target = if (Test-Connection -ComputerName "192.168.56.102" -Count 1 -Quiet) {
                "192.168.56.102"
            } else {
                "127.0.0.1"
            }
            Test-NetConnection -ComputerName $target -Port 445 -InformationLevel Detailed | Out-String | Write-Host
        }
        "patch-compliance" {
            Get-CimInstance Win32_OperatingSystem |
                Select-Object Caption, Version, BuildNumber |
                ConvertTo-Json -Compress |
                Write-Host
            Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20 | Format-Table
        }
        "response-containment" {
            $process = Start-Process "$env:SystemRoot\System32\ping.exe" `
                -ArgumentList @("-t", "127.0.0.1") -WindowStyle Hidden -PassThru
            try {
                Start-Sleep -Seconds 5
            }
            finally {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
        }
        default {
            throw "Builtin scenario is not allowlisted."
        }
    }
}

Write-ScenarioEvent -Status "started" -ExpectedAlert $false
try {
    if ($manifest.kind -eq "atomic") {
        Invoke-AllowlistedAtomic
    }
    elseif ($manifest.kind -eq "builtin") {
        Invoke-BuiltinScenario
    }
    else {
        throw "Unsupported scenario kind."
    }
    Write-ScenarioEvent -Status "completed" -ExpectedAlert $true
}
catch {
    Write-ScenarioEvent -Status "failed" -ExpectedAlert $false
    throw
}
