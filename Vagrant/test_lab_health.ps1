[CmdletBinding()]
param(
    [ValidateSet("wazuh-core", "wazuh-ad", "soar-ai")]
    [string]$Profile = "wazuh-core"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$env:SOC_PROFILE = $Profile
$env:VAGRANT_DEFAULT_PROVIDER = "virtualbox"
$failures = [Collections.Generic.List[string]]::new()

function Test-TcpPort {
    param([Parameter(Mandatory)][int]$Port)

    $client = [Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync("127.0.0.1", $Port)
        return $task.Wait([TimeSpan]::FromSeconds(5)) -and $client.Connected
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function Test-VagrantMachine {
    param([Parameter(Mandatory)][string]$Name)

    $status = & vagrant status $Name --machine-readable 2>$null
    if ($LASTEXITCODE -ne 0 -or $status -notmatch ',state,running') {
        $failures.Add("Machine is not running: $Name")
    }
}

function Test-LoggerService {
    param([Parameter(Mandatory)][string]$Name)

    & vagrant ssh logger -c "sudo systemctl is-active --quiet '$Name'"
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Logger service is not active: $Name")
    }
}

function Test-WindowsService {
    param(
        [Parameter(Mandatory)][string]$Machine,
        [Parameter(Mandatory)][string]$Service
    )

    $command = "powershell.exe -NoProfile -Command `"if ((Get-Service '$Service').Status -ne 'Running') { exit 1 }`""
    & vagrant winrm $Machine -c $command
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("$Service is not active on $Machine")
    }
}

$machines = if ($Profile -in @("wazuh-core", "soar-ai")) {
    @("logger", "win10")
} else {
    @("logger", "dc", "wef", "win10")
}
foreach ($machine in $machines) {
    Test-VagrantMachine $machine
}

if (-not (Test-TcpPort 8443)) {
    $failures.Add("Wazuh dashboard host port is closed: 8443")
}
foreach ($service in @("wazuh-indexer", "wazuh-manager", "wazuh-dashboard", "suricata", "zeek", "velociraptor_server")) {
    Test-LoggerService $service
}
if ($Profile -eq "soar-ai") {
    Test-LoggerService "soc-lab-soar"
}

foreach ($machine in ($machines | Where-Object { $_ -ne "logger" })) {
    Test-WindowsService -Machine $machine -Service "WazuhSvc"
    & vagrant ssh logger -c "sudo /var/ossec/bin/agent_control -lc | grep -qi '$machine'"
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Wazuh manager does not report an active $machine agent")
    }
}

& vagrant ssh logger -c "if sudo ss -ltn | grep -q ':9997 '; then exit 1; fi"
if ($LASTEXITCODE -ne 0) {
    $failures.Add("Removed SIEM forwarding port 9997 is unexpectedly listening")
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "All Wazuh health checks passed for profile $Profile."
