#Requires -Version 5.1
Set-StrictMode -Version Latest

function Get-DestinationDisks {
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 3' -ErrorAction Stop |
        Sort-Object DeviceID | ForEach-Object {
            [pscustomobject]@{ Root = $_.DeviceID + '\'; Label = $_.VolumeName; FreeGB = [math]::Round($_.FreeSpace / 1GB, 1) }
        }
}

function Set-AppDestination {
    param([object[]]$Apps, [ValidatePattern('^[A-Za-z]:\\$')][string]$Disk)
    foreach ($app in $Apps) {
        $location = $null
        if ($Disk -ne 'C:\' -and $app.Id -notin @('Discord.Discord', 'Microsoft.PowerToys')) {
            $location = $Disk + 'Apps\' + $app.Name
        }
        $app | Add-Member NoteProperty Location $location -Force
    }
}

function Test-AppDestinations {
    param([object[]]$Apps, [string]$Disk, [string]$WingetPath, [string]$LogPath)
    if (-not (@(Get-DestinationDisks | Where-Object Root -eq $Disk).Count)) { throw 'The selected disk is no longer available.' }
    foreach ($app in $Apps) {
        if (-not $app.Location) { continue }
        if ($WingetPath) {
            $installed = Invoke-WinGet $WingetPath @('list', '--id', $app.Id, '--exact', '--source', 'winget', '--accept-source-agreements', '--disable-interactivity') $LogPath
            if ($installed.Code -eq '0x00000000') { continue }
            if ($installed.Code -ne '0x8A150014') { throw ('Could not check {0}: {1}' -f $app.Name, $installed.Output) }
        }
        # Probe only the shared parent; portable installers need to own their
        # exact per-app directory. Never write into existing application folders.
        $parent = Split-Path $app.Location -Parent
        if (Test-Path -LiteralPath $app.Location) {
            throw ('Destination already exists for a new installation: ' + $app.Location)
        }
        [void][IO.Directory]::CreateDirectory($parent)
        $probe = Join-Path $parent ([guid]::NewGuid().ToString('N') + '.tmp')
        try { [IO.File]::WriteAllText($probe, '') }
        finally { if ([IO.File]::Exists($probe)) { [IO.File]::Delete($probe) } }
    }
}

Export-ModuleMember -Function Get-DestinationDisks, Set-AppDestination, Test-AppDestinations
