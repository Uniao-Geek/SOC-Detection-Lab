# Purpose: Installs a handful of SysInternals tools on the host into c:\Tools\Sysinternals
# Also installs Sysmon and Olaf Harton's Sysmon config

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$commonScript = if (Test-Path "$PSScriptRoot\SocLab.Common.ps1") {
  "$PSScriptRoot\SocLab.Common.ps1"
} else {
  "C:\vagrant\scripts\SocLab.Common.ps1"
}
. $commonScript
$configuration = Get-SocLabConfiguration

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing SysInternals Tooling..."
$sysinternalsDir = "C:\Tools\Sysinternals"
$sysmonDir = "C:\ProgramData\Sysmon"
New-Item -ItemType Directory -Force -Path $sysinternalsDir | Out-Null
New-Item -ItemType Directory -Force -Path $sysmonDir | Out-Null

$autorunsPath = "C:\Tools\Sysinternals\Autoruns64.exe"
$procmonPath = "C:\Tools\Sysinternals\Procmon.exe"
$psexecPath = "C:\Tools\Sysinternals\PsExec64.exe"
$procexpPath = "C:\Tools\Sysinternals\procexp64.exe"
$sysmonPath = "C:\Tools\Sysinternals\Sysmon64.exe"
$sdeletePath = "C:\Tools\Sysinternals\Sdelete64.exe"
$tcpviewPath = "C:\Tools\Sysinternals\Tcpview.exe"
$sysmonConfigPath = "$sysmonDir\sysmonConfig.xml"
$shortcutLocation = "$ENV:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\"

$WScriptShell = New-Object -ComObject WScript.Shell

# Microsoft likes TLSv1.2 as well
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Autoruns64.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/Autoruns64.exe', $autorunsPath) 
} Catch { 
  throw "HTTPS download failed for Autoruns64.exe: $_"
}
$Shortcut = $WScriptShell.CreateShortcut($ShortcutLocation + "Autoruns.lnk")
$Shortcut.TargetPath = $autorunsPath
$Shortcut.Save()

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Procmon.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/Procmon.exe', $procmonPath)
} Catch { 
  throw "HTTPS download failed for Procmon.exe: $_"
}
$Shortcut = $WScriptShell.CreateShortcut($ShortcutLocation + "Process Monitor.lnk")
$Shortcut.TargetPath = $procmonPath
$Shortcut.Save()

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading PsExec64.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/PsExec64.exe', $psexecPath)
} Catch { 
  throw "HTTPS download failed for PsExec64.exe: $_"
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading procexp64.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/procexp64.exe', $procexpPath)
} Catch { 
  throw "HTTPS download failed for procexp64.exe: $_"
}
$Shortcut = $WScriptShell.CreateShortcut($ShortcutLocation + "Process Explorer.lnk")
$Shortcut.TargetPath = $procexpPath
$Shortcut.Save()

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading sdelete64.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/sdelete64.exe', $sdeletePath)
}
Catch { 
  throw "HTTPS download failed for sdelete64.exe: $_"
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Sysmon64.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/Sysmon64.exe', $sysmonPath)
} Catch { 
  throw "HTTPS download failed for Sysmon64.exe: $_"
}
Copy-Item $sysmonPath $sysmonDir

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Tcpview.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/Tcpview.exe', $tcpviewPath)
} Catch { 
  throw "HTTPS download failed for Tcpview.exe: $_"
}
$Shortcut = $WScriptShell.CreateShortcut($ShortcutLocation + "Tcpview.lnk")
$Shortcut.TargetPath = $tcpviewPath
$Shortcut.Save()

# Restart Explorer so the taskbar shortcuts show up
if (Get-Process -ProcessName explorer -ErrorAction 'silentlycontinue') {
  Stop-Process -ProcessName explorer -Force
}

# Download Olaf Hartongs Sysmon config
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Olaf Hartong's Sysmon config..."
$sysmonConfigUrl = "https://raw.githubusercontent.com/olafhartong/sysmon-modular/$($configuration.SYSMON_CONFIG_COMMIT)/sysmonconfig.xml"
Invoke-VerifiedDownload -Uri $sysmonConfigUrl -Destination $sysmonConfigPath -Sha256 $configuration.SYSMON_CONFIG_SHA256

$trustedTools = @($autorunsPath, $procmonPath, $psexecPath, $procexpPath, $sysmonPath, $sdeletePath, $tcpviewPath)
foreach ($tool in $trustedTools) {
  $signature = Get-AuthenticodeSignature -FilePath $tool
  if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or
      $signature.SignerCertificate.Subject -notlike "*Microsoft Corporation*") {
    throw "Invalid Microsoft signature on $tool."
  }
}
# Start Sysmon
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Starting Sysmon..."
Start-Process -FilePath "$sysmonDir\Sysmon64.exe" -ArgumentList "-accepteula -i $sysmonConfigPath"
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Waiting 5 seconds to give the service time to install..."
Start-Sleep 5
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Verifying that the Sysmon service is running..."

# Poll the sysmon service every 5 seconds to see if it has started (up to 25 seconds)
$tries = 1
While ($tries -lt 6) {
  If ((Get-Service -name Sysmon64).Status -ne "Running") {
    Write-Host "Waiting for the Sysmon service to start... (Attempt $tries of 5)"
    Start-Sleep 5
    $tries += 1
  } Else {
    Write-Host "The Sysmon service has started successfully!"
    break
  }
}

If ((Get-Service -name Sysmon64).Status -ne "Running")
{
  throw "The Sysmon service failed to start successfully"
}

# Make the event log channel readable. For some reason this doesn't work in the GPO and only works when run manually.
wevtutil sl Microsoft-Windows-Sysmon/Operational "/ca:O:BAG:SYD:(A;;0x5;;;BA)(A;;0x1;;;S-1-5-20)(A;;0x1;;;S-1-5-32-573)"
