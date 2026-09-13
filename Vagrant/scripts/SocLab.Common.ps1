Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-SocLabConfiguration {
    [CmdletBinding()]
    param(
        [string]$Path = "C:\soc-detection-lab.conf"
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "SOC lab configuration not found."
    }

    $configuration = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*([A-Z][A-Z0-9_]*)="([^"\r\n]*)"\s*$') {
            $configuration[$Matches[1]] = $Matches[2]
        }
    }
    return $configuration
}

function Invoke-VerifiedDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^https://')]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-fA-F0-9]{64}$')]
        [string]$Sha256
    )

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $Uri -OutFile $Destination -UseBasicParsing
    $actual = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if (-not [string]::Equals($actual, $Sha256, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        throw "SHA-256 validation failed for $Uri."
    }
}

function Assert-TrustedMsiSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string[]]$AllowedPublishers
    )

    $signature = Get-AuthenticodeSignature -FilePath $Path
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        throw "MSI signature is not valid: $($signature.Status)."
    }

    $subject = $signature.SignerCertificate.Subject
    if (-not ($AllowedPublishers | Where-Object { $subject -like "*$_*" })) {
        throw "MSI publisher is not allowlisted: $subject."
    }
}
