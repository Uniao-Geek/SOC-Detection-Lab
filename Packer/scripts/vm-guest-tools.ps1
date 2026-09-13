Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($env:PACKER_BUILDER_TYPE -ne "virtualbox-iso") {
    throw "Only the VirtualBox Packer builder is supported."
}

$guestAdditionsIso = "C:\Users\vagrant\VBoxGuestAdditions.iso"
if (-not (Test-Path -LiteralPath $guestAdditionsIso -PathType Leaf)) {
    throw "Packer did not upload the VirtualBox Guest Additions ISO."
}

$image = Mount-DiskImage -ImagePath $guestAdditionsIso -PassThru
try {
    $volume = $image | Get-Volume
    if (-not $volume.DriveLetter) {
        throw "VirtualBox Guest Additions volume has no drive letter."
    }
    $installer = "$($volume.DriveLetter):\VBoxWindowsAdditions.exe"
    $signature = Get-AuthenticodeSignature -FilePath $installer
    if ($signature.Status -ne "Valid" -or
        $signature.SignerCertificate.Subject -notlike "*Oracle Corporation*") {
        throw "VirtualBox Guest Additions signature validation failed."
    }

    $process = Start-Process -FilePath $installer -ArgumentList "/S" -Wait -PassThru
    if ($process.ExitCode -notin @(0, 3010)) {
        throw "VirtualBox Guest Additions failed with exit code $($process.ExitCode)."
    }
}
finally {
    Dismount-DiskImage -ImagePath $guestAdditionsIso -ErrorAction SilentlyContinue
}

if (-not (Get-Service -Name "VBoxService" -ErrorAction SilentlyContinue)) {
    throw "VirtualBox Guest Additions service was not installed."
}
