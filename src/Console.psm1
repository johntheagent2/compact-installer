#Requires -Version 5.1
Set-StrictMode -Version Latest

function Read-AppSelection {
    param([Parameter(Mandatory)][object[]]$Catalog)
    $position = 0
    $notice = ''
    while ($true) {
        Clear-Host
        Write-Host 'COMPACT INSTALLER' -ForegroundColor Cyan
        Write-Host 'Choose your apps'
        Write-Host ''
        for ($index = 0; $index -lt $Catalog.Count; $index++) {
            $cursor = if ($index -eq $position) { '>' } else { ' ' }
            $mark = if ($Catalog[$index].Selected) { 'x' } else { ' ' }
            $color = if ($index -eq $position) { 'Cyan' } else { 'Gray' }
            Write-Host ('{0} [{1}] {2}' -f $cursor, $mark, $Catalog[$index].Name) -ForegroundColor $color
        }
        Write-Host ''
        Write-Host 'Up/Down: move | Space: toggle | A: select all | D: deselect all'
        Write-Host 'Enter: review | Esc: cancel'
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
                Clear-Host
                Write-Host 'Ready to install' -ForegroundColor Cyan
                foreach ($app in $selected) { Write-Host ('  - ' + $app.Name) }
                Write-Host ''
                Write-Host 'Existing apps will be skipped. Windows may ask for permission.'
                Write-Host 'Continuing accepts the selected app licenses and WinGet source terms.'
                Write-Host 'WinGet will be prepared automatically if needed.'
                Write-Host ''
                Write-Host 'Y: install | Esc: cancel | Any other key: change selection'
                $confirmation = [Console]::ReadKey($true)
                if ($confirmation.Key -eq 'Y') { return $selected }
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

Export-ModuleMember -Function Read-AppSelection, Read-RetryChoice
