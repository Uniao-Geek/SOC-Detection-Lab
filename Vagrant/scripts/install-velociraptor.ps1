# Purpose: Installs velociraptor on the host

param (
  [switch]$Update
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

# Add a hosts entry to avoid DNS issues
If (Select-String -Path "c:\windows\system32\drivers\etc\hosts" -Pattern "logger") {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Hosts file already updated. Moving on."
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Adding logger to the hosts file"
  Add-Content "c:\windows\system32\drivers\etc\hosts" "        192.168.56.105    logger"
}

# Download and install the pinned Velociraptor release.
$version = $configuration.VELOCIRAPTOR_VERSION
$velociraptorDownloadUrl = "https://github.com/Velocidex/velociraptor/releases/download/v$version/velociraptor-v$version-windows-amd64.msi"
$velociraptorMSIPath = "C:\ProgramData\SocDetectionLab\cache\velociraptor-$version.msi"
$velociraptorLogFile = 'C:\ProgramData\SocDetectionLab\velociraptor_install.log'
$clientConfig = "C:\vagrant\.secrets\velociraptor\client.config.yaml"
If (-not(Test-Path $velociraptorLogFile) -or ($Update -eq $true)) {
  if ($Update -eq $true) {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) The update flag was set. Attempting to update..."
  }
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Velociraptor..."
  Invoke-VerifiedDownload -Uri $velociraptorDownloadUrl -Destination $velociraptorMSIPath -Sha256 $configuration.VELOCIRAPTOR_WINDOWS_SHA256
  if (-not (Test-Path -LiteralPath $clientConfig -PathType Leaf)) {
    throw "Velociraptor client configuration is unavailable. Provision logger first."
  }
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing Velociraptor..."
  $process = Start-Process C:\Windows\System32\msiexec.exe -ArgumentList "/i `"$velociraptorMSIPath`" /quiet /qn /norestart /log `"$velociraptorLogFile`"" -Wait -PassThru
  if ($process.ExitCode -notin @(0, 3010)) {
    throw "Velociraptor installation failed with exit code $($process.ExitCode)."
  }
  Copy-Item $clientConfig "C:\Program Files\Velociraptor\client.config.yaml" -Force
  Restart-Service Velociraptor
  Remove-Item -LiteralPath $velociraptorMSIPath -Force -ErrorAction SilentlyContinue
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Velociraptor successfully installed!"
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Velociraptor was already installed. Moving On."
}
If ((Get-Service -name Velociraptor).Status -ne "Running")
{
  Throw "Velociraptor service is not running"
}
