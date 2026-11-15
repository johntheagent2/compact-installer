#Requires -Version 5.1
Set-StrictMode -Version Latest

function Write-TerminalLine {
    param([string]$Text = '', [string]$Color = 'Gray')
    $width = [math]::Max(20, [Console]::WindowWidth - 1)
    while ($Text.Length -gt $width) {
        Write-Host $Text.Substring(0, $width) -ForegroundColor $Color
        $Text = $Text.Substring($width)
    }
    Write-Host $Text -ForegroundColor $Color
}

function Write-ScreenHeader {
    param([string]$Step)
    Clear-Host
    Write-TerminalLine ' COMPACT INSTALLER' Cyan
    Write-TerminalLine (' ' + $Step) White
    Write-TerminalLine ('-' * [math]::Min(72, [math]::Max(20, [Console]::WindowWidth - 1))) DarkGray
}

function Read-DestinationDisk {
    param([string]$Notice = '')
    $disks = @(Get-DestinationDisks)
    if ($disks.Count -eq 0) { throw 'No local fixed disks with drive letters are available.' }
    $position = 0
    for ($i = 0; $i -lt $disks.Count; $i++) { if ($disks[$i].Root -eq 'C:\') { $position = $i } }
    while ($true) {
        Write-ScreenHeader 'STEP 1 / 3   Choose installation disk'
        if ($Notice) { Write-TerminalLine $Notice Yellow }
        for ($i = 0; $i -lt $disks.Count; $i++) {
            $disk = $disks[$i]
            $cursor = if ($i -eq $position) { '>' } else { ' ' }
            $color = if ($i -eq $position) { 'Cyan' } else { 'Gray' }
            $target = if ($disk.Root -eq 'C:\') { 'App defaults' } else { $disk.Root + 'Apps' }
            Write-TerminalLine ('{0} {1} {2} | {3} GB free | {4}' -f $cursor, $disk.Root, $disk.Label, $disk.FreeGB, $target) $color
        }
        Write-TerminalLine ''
        Write-TerminalLine 'Up/Down Move | Enter Choose | Esc Cancel'
        switch ([Console]::ReadKey($true).Key) {
            'UpArrow' { $position = ($position + $disks.Count - 1) % $disks.Count }
            'DownArrow' { $position = ($position + 1) % $disks.Count }
            'Enter' { return $disks[$position].Root }
            'Escape' { return }
        }
    }
}

function Read-AppSelection {
    param([Parameter(Mandatory)][object[]]$Catalog, [string]$Disk = 'C:\')
    $position = 0
    $notice = ''
    while ($true) {
        Write-ScreenHeader 'STEP 2 / 3   Choose your apps'
        Write-TerminalLine ('Disk: {0} | Selected: {1}' -f $Disk, @($Catalog | Where-Object Selected).Count) Cyan
        Write-Host ''
        for ($index = 0; $index -lt $Catalog.Count; $index++) {
            $cursor = if ($index -eq $position) { '>' } else { ' ' }
            $mark = if ($Catalog[$index].Selected) { 'x' } else { ' ' }
            $color = if ($index -eq $position) { 'Cyan' } else { 'Gray' }
            Write-TerminalLine ('{0} [{1}] {2,-12} {3}' -f $cursor, $mark, $Catalog[$index].Name, $Catalog[$index].Description) $color
            $target = if ($Catalog[$index].Location) { $Catalog[$index].Location } else { 'App default location' }
            Write-TerminalLine ('      ' + $target) DarkGray
        }
        Write-Host ''
        Write-Host 'Up/Down: move | Space: toggle | A: select all | D: deselect all'
        Write-Host 'Enter: review | Esc: back to disks'
        if ($notice) { Write-Host $notice -ForegroundColor Yellow }
        $key = [Console]::ReadKey($true)
        $notice = ''
        switch ($key.Key) {
            'UpArrow' { $position = ($position + $Catalog.Count - 1) % $Catalog.Count }
            'DownArrow' { $position = ($position + 1) % $Catalog.Count }
            'Spacebar' { $Catalog[$position].Selected = -not $Catalog[$position].Selected }
            'A' { foreach ($app in $Catalog) { $app.Selected = $true } }
            'D' { foreach ($app in $Catalog) { $app.Selected = $false } }
            'Escape' { return }
            'Enter' {
                $selected = @($Catalog | Where-Object Selected)
                if ($selected.Count -eq 0) {
                    $notice = 'Select at least one app, or press Esc to cancel.'
                    continue
                }
                Write-ScreenHeader 'STEP 3 / 3   Review installation'
                foreach ($app in $selected) {
                    $target = if ($app.Location) { $app.Location } else { 'App default location' }
                    Write-TerminalLine ('  {0}: {1}' -f $app.Name, $target) White
                }
                Write-Host ''
                Write-Host 'Existing apps will be skipped. Windows may ask for permission.'
                Write-Host 'Continuing accepts the selected app licenses and WinGet source terms.'
                Write-Host 'Dry run checks packages without running app installers.'
                Write-Host ''
                Write-Host '> Dry run: Enter or D | Esc: back to disks | Other: change selection'
                $confirmation = [Console]::ReadKey($true)
                if ($confirmation.Key -in @('Enter', 'D')) { return $selected }
                if ($confirmation.Key -eq 'Escape') { return }
            }
        }
    }
}

function Read-RetryChoice {
    param([object[]]$FailedApps)
    Write-Host ''
    Write-Host ('Retry {0} failed app(s)? [y/N]' -f $FailedApps.Count)
    return ([Console]::ReadKey($true).Key -eq 'Y')
}

Export-ModuleMember -Function Read-AppSelection, Read-RetryChoice, Read-DestinationDisk
