# Installs AutorunsToWinEventLog from the pinned Palantir WEF snapshot.
# Logs Autoruns entries to Windows Event Log for collection by the Wazuh agent.
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing AutorunsToWinEventLog..."
If ((Get-ScheduledTask -TaskName "AutorunsToWinEventLog" -ea silent) -eq $null)
{
    $trustedAutoruns = "C:\Tools\Sysinternals\Autoruns64.exe"
    $signature = Get-AuthenticodeSignature -FilePath $trustedAutoruns
    if ($signature.Status -ne "Valid" -or $signature.SignerCertificate.Subject -notlike "*Microsoft Corporation*") {
        throw "Trusted Autoruns binary is missing or has an invalid signature."
    }

    # Reuse the verified local binary instead of downloading during upstream installation.
    (Get-Content c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\AutorunsToWinEventLog\Install.ps1 -Raw) -replace 'Invoke-WebRequest -Uri "https://live.sysinternals.com/autorunsc64.exe" -OutFile "\$autorunsPath"', 'Try {
    Copy-Item -LiteralPath ''C:\Tools\Sysinternals\Autoruns64.exe'' -Destination $autorunsPath -Force
  } Catch { throw "Unable to stage verified Autoruns binary: $_" }' | Set-Content -Path "c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\AutorunsToWinEventLog\Install.ps1"
    . c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\AutorunsToWinEventLog\Install.ps1
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) AutorunsToWinEventLog installed. Starting the scheduled task. Future runs will begin at 11am"
    Start-ScheduledTask -TaskName "AutorunsToWinEventLog"
    # https://mcpmag.com/articles/2018/03/16/wait-action-function-powershell.aspx
    # Wait 30 seconds for the scheduled task to enter the "Running" state
    $Timeout = 30
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (($timer.Elapsed.TotalSeconds -lt $Timeout) -and ((Get-ScheduledTask -TaskName "AutorunsToWinEventLog").State -ne "Running")) {
        Start-Sleep -Seconds 3
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Still waiting for scheduled task to start after "$timer.Elapsed.Seconds" seconds..."
    }
    $timer.Stop()
    $Tsk = Get-ScheduledTask -TaskName "AutorunsToWinEventLog"
    if ($Tsk.State -ne "Running")
    {
        throw "AutorunsToWinEventLog scheduled tasks wasn't running after starting it"
    }
}
else
{
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) AutorunsToWinEventLog already installed. Moving On."
}
