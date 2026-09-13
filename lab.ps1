[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [ValidateSet("doctor", "up", "down", "status", "scenario", "replay", "validate", "reset")]
    [string]$Command = "status",

    [ValidateSet("wazuh-core", "wazuh-ad", "soar-ai")]
    [string]$Profile = "wazuh-core",

    [ValidatePattern('^[a-z0-9][a-z0-9-]{0,63}$')]
    [string]$ScenarioId,

    [ValidateSet("pcap", "evtx", "log")]
    [string]$ReplayType,

    [string]$Path,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$vagrantRoot = Join-Path $projectRoot "Vagrant"
$replayRoot = Join-Path $vagrantRoot ".replay"
$scenarioRoot = Join-Path $vagrantRoot "resources\scenarios"
$env:SOC_PROFILE = $Profile
$env:VAGRANT_DEFAULT_PROVIDER = "virtualbox"

function Invoke-Native {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter()]
        [string[]]$Arguments = @()
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE."
    }
}

function Test-HostCapacity {
    $requirements = @{
        "wazuh-core"    = 10
        "wazuh-ad"      = 15
        "soar-ai"       = 12
    }

    foreach ($commandName in @("vagrant", "VBoxManage")) {
        if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
            throw "Required command not found: $commandName"
        }
    }

    $operatingSystem = Get-CimInstance Win32_OperatingSystem
    $freeMemoryGb = [math]::Round($operatingSystem.FreePhysicalMemory / 1MB, 1)
    $drive = Get-PSDrive -Name ([IO.Path]::GetPathRoot($projectRoot).TrimEnd(":\"))
    $freeDiskGb = [math]::Round($drive.Free / 1GB, 1)
    $requiredMemoryGb = $requirements[$Profile]

    Write-Host "Profile: $Profile"
    Write-Host "Free memory: $freeMemoryGb GB, required: $requiredMemoryGb GB"
    Write-Host "Free disk: $freeDiskGb GB, required: 70 GB"

    if ($freeMemoryGb -lt $requiredMemoryGb) {
        throw "Insufficient free memory. Stop other workloads manually before starting the lab."
    }
    if ($freeDiskGb -lt 70) {
        throw "Insufficient free disk space."
    }
}

function Get-ProfileMachines {
    switch ($Profile) {
        "wazuh-core" { return @("logger", "win10") }
        "soar-ai" { return @("logger", "win10") }
        default { return @("logger", "dc", "wef", "win10") }
    }
}

function Assert-RunningMachine {
    param([Parameter(Mandatory)][string]$Machine)

    $status = & vagrant status $Machine --machine-readable 2>$null
    if ($LASTEXITCODE -ne 0 -or $status -notmatch ',state,running') {
        throw "Vagrant machine '$Machine' is not running."
    }
}

function Assert-WazuhDetection {
    param(
        [Parameter(Mandatory)][string]$Since,
        [string]$Scenario
    )

    $arguments = @(
        "ssh", "logger", "-c",
        "sudo /vagrant/scripts/validate-wazuh-alert.sh --since $Since" +
            $(if ($Scenario) { " --scenario $Scenario" } else { "" })
    )
    Invoke-Native "vagrant" $arguments
}

Push-Location $vagrantRoot
try {
    switch ($Command) {
        "doctor" {
            Test-HostCapacity
        }
        "up" {
            Test-HostCapacity
            foreach ($machine in Get-ProfileMachines) {
                Invoke-Native "vagrant" @("up", $machine)
            }
            if ($Profile -eq "soar-ai") {
                Invoke-Native "vagrant" @(
                    "ssh", "logger", "-c",
                    "sudo /vagrant/scripts/install-optional-services.sh"
                )
            }
        }
        "down" {
            Invoke-Native "vagrant" @("halt")
        }
        "status" {
            Invoke-Native "vagrant" @("status")
        }
        "scenario" {
            if (-not $ScenarioId) {
                throw "ScenarioId is required."
            }
            $manifest = Join-Path $scenarioRoot "$ScenarioId.json"
            if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
                throw "Unknown scenario: $ScenarioId"
            }
            Assert-RunningMachine "win10"
            $startedAt = [DateTime]::UtcNow.AddSeconds(-1).ToString("yyyy-MM-ddTHH:mm:ssZ")
            Invoke-Native "vagrant" @("provision", "win10", "--provision-with", "atomic")
            $guestCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\vagrant\scripts\run-scenario.ps1 -ScenarioId $ScenarioId"
            Invoke-Native "vagrant" @("winrm", "win10", "-c", $guestCommand)
            Assert-WazuhDetection -Since $startedAt -Scenario $ScenarioId
        }
        "replay" {
            if (-not $ReplayType -or -not $Path) {
                throw "ReplayType and Path are required."
            }
            $source = Get-Item -LiteralPath (Resolve-Path -LiteralPath $Path)
            if ($source.PSIsContainer -or $source.Length -gt 1GB) {
                throw "Replay input must be a file no larger than 1 GB."
            }
            $allowedExtensions = @{
                "pcap" = @(".pcap", ".pcapng")
                "evtx" = @(".evtx")
                "log"  = @(".json", ".jsonl", ".log")
            }
            if ($source.Extension.ToLowerInvariant() -notin $allowedExtensions[$ReplayType]) {
                throw "File extension is not allowed for replay type '$ReplayType'."
            }

            New-Item -ItemType Directory -Path $replayRoot -Force | Out-Null
            $safeName = "{0}-{1}{2}" -f $ReplayType, ([guid]::NewGuid().ToString("N")), $source.Extension.ToLowerInvariant()
            $staged = Join-Path $replayRoot $safeName
            Copy-Item -LiteralPath $source.FullName -Destination $staged
            $startedAt = [DateTime]::UtcNow.AddSeconds(-1).ToString("yyyy-MM-ddTHH:mm:ssZ")

            if ($ReplayType -eq "evtx") {
                Assert-RunningMachine "win10"
                $guestCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\vagrant\scripts\replay-evtx.ps1 -Path C:\vagrant\.replay\$safeName"
                Invoke-Native "vagrant" @("winrm", "win10", "-c", $guestCommand)
            } else {
                Assert-RunningMachine "logger"
                Invoke-Native "vagrant" @(
                    "ssh", "logger", "-c",
                    "sudo /vagrant/scripts/replay-telemetry.sh --type $ReplayType --file /vagrant/.replay/$safeName"
                )
            }
            Assert-WazuhDetection -Since $startedAt
        }
        "validate" {
            Invoke-Native "powershell.exe" @(
                "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-File", (Join-Path $vagrantRoot "test_lab_health.ps1"),
                "-Profile", $Profile
            )
        }
        "reset" {
            $machines = Get-ProfileMachines
            $target = "$Profile ($($machines -join ', '))"
            if (-not $Force -and -not $PSCmdlet.ShouldContinue("Destroy $target?", "Destructive lab reset")) {
                return
            }
            if ($PSCmdlet.ShouldProcess($target, "Destroy Vagrant machines")) {
                Invoke-Native "vagrant" (@("destroy", "-f") + $machines)
            }
        }
    }
}
finally {
    Pop-Location
}
