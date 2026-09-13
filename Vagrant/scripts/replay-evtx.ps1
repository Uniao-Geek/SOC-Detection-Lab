[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [string]$TrustedSampleRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$replayRoot = [IO.Path]::GetFullPath("C:\vagrant\.replay") + [IO.Path]::DirectorySeparatorChar
$resolvedPath = [IO.Path]::GetFullPath($Path)
$isStaged = $resolvedPath.StartsWith($replayRoot, [StringComparison]::OrdinalIgnoreCase)
$isTrustedSample = $false
if ($TrustedSampleRoot) {
    $trustedRoot = [IO.Path]::GetFullPath($TrustedSampleRoot) + [IO.Path]::DirectorySeparatorChar
    $isTrustedSample = $resolvedPath.StartsWith($trustedRoot, [StringComparison]::OrdinalIgnoreCase)
}
if (-not $isStaged -and -not $isTrustedSample) {
    throw "EVTX input is outside the allowed staging roots."
}

$inputFile = Get-Item -LiteralPath $resolvedPath
if ($inputFile.Extension -ne ".evtx" -or $inputFile.Length -le 0 -or $inputFile.Length -gt 1GB) {
    throw "EVTX input is invalid or exceeds the 1 GB limit."
}

$stream = [IO.File]::OpenRead($inputFile.FullName)
try {
    $header = New-Object byte[] 8
    if ($stream.Read($header, 0, 8) -ne 8 -or [Text.Encoding]::ASCII.GetString($header) -ne "ElfFile`0") {
        throw "EVTX magic bytes are invalid."
    }
}
finally {
    $stream.Dispose()
}

$runId = "{0}-{1}" -f [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ"), ([guid]::NewGuid().ToString("N").Substring(0, 12))
$outputDirectory = "C:\SocLab\Replay"
$outputPath = Join-Path $outputDirectory "evtx-$runId.jsonl"
$utf8 = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

function Write-ReplayRecord {
    param([Parameter(Mandatory)][hashtable]$Record)

    $json = $Record | ConvertTo-Json -Compress -Depth 6
    [IO.File]::AppendAllText($outputPath, "$json`n", $utf8)
}

function Invoke-OptionalHayabusa {
    $binary = "C:\Tools\Hayabusa\hayabusa.exe"
    $hashFile = "$binary.sha256"
    if (-not (Test-Path -LiteralPath $binary) -or -not (Test-Path -LiteralPath $hashFile)) {
        return $false
    }

    $expectedHash = (Get-Content -LiteralPath $hashFile -Raw).Trim()
    if ($expectedHash -notmatch '^[a-fA-F0-9]{64}$') {
        throw "Hayabusa checksum sidecar is invalid."
    }
    $actualHash = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash
    if (-not [string]::Equals($actualHash, $expectedHash, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Hayabusa checksum validation failed."
    }

    $hayabusaOutput = Join-Path $outputDirectory "hayabusa-$runId.jsonl"
    $process = Start-Process -FilePath $binary `
        -ArgumentList @("json-timeline", "-f", "`"$resolvedPath`"", "-o", "`"$hayabusaOutput`"", "-L", "-q") `
        -PassThru -WindowStyle Hidden
    if (-not $process.WaitForExit(180000)) {
        $process.Kill()
        throw "Hayabusa exceeded the 180 second timeout."
    }
    if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $hayabusaOutput)) {
        throw "Hayabusa analysis failed."
    }

    foreach ($line in Get-Content -LiteralPath $hayabusaOutput) {
        $finding = $line | ConvertFrom-Json
        Write-ReplayRecord @{
            timestamp = [DateTime]::UtcNow.ToString("o")
            finding = $finding
            soc_lab = @{
                event_type = "telemetry"
                scenario_id = $runId
                title = "Hayabusa EVTX replay"
                source_type = "hayabusa"
                expected_alert = $true
            }
        }
    }
    Remove-Item -LiteralPath $hayabusaOutput -Force
    return $true
}

try {
    if (-not (Invoke-OptionalHayabusa)) {
        $count = 0
        foreach ($event in Get-WinEvent -Path $resolvedPath -Oldest -MaxEvents 5000) {
            $count++
            $message = [string]$event.Message
            if ($message.Length -gt 4096) {
                $message = $message.Substring(0, 4096)
            }
            Write-ReplayRecord @{
                timestamp = [DateTime]::UtcNow.ToString("o")
                event = @{
                    provider = $event.ProviderName
                    event_id = $event.Id
                    original_time = if ($event.TimeCreated) { $event.TimeCreated.ToUniversalTime().ToString("o") } else { $null }
                    level = $event.LevelDisplayName
                    record_id = $event.RecordId
                    machine = $event.MachineName
                    message = $message
                }
                soc_lab = @{
                    event_type = "telemetry"
                    scenario_id = $runId
                    title = "Native EVTX replay"
                    source_type = "windows_evtx"
                    expected_alert = $true
                }
            }
        }
        if ($count -eq 0) {
            throw "No events were read from the EVTX file."
        }
    }
}
finally {
    if ($isStaged) {
        Remove-Item -LiteralPath $resolvedPath -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "EVTX replay completed: $outputPath"
