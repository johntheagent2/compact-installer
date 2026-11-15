#Requires -Version 5.1
Set-StrictMode -Version Latest
function Invoke-InstallationDryRun {
    param([object[]]$Apps, [string]$Disk, [string]$WingetPath, [string]$LogPath)
    $passed = $true
    Write-RunMessage $LogPath 'DRY RUN - no app installers will run.'
    if (-not (@(Get-DestinationDisks | Where-Object Root -eq $Disk).Count)) {
        Write-RunMessage $LogPath 'FAILED: Selected disk is unavailable.'
        $passed = $false
    }
    foreach ($app in $Apps) {
        try {
            $show = @('show', '--id', $app.Id, '--exact', '--source', 'winget', '--accept-source-agreements', '--disable-interactivity')
            if ($app.Version) { $show += @('--version', $app.Version) }
            if ($app.Architecture) { $show += @('--architecture', $app.Architecture) }
            $package = Invoke-WinGet $WingetPath $show $LogPath
            if ($package.Code -ne '0x00000000') { throw ('Package verification failed: {0}. {1}' -f $package.Code, $package.Output) }
            $installed = Invoke-WinGet $WingetPath @('list', '--id', $app.Id, '--exact', '--source', 'winget', '--accept-source-agreements', '--disable-interactivity') $LogPath
            if ($installed.Code -notin @('0x00000000', '0x8A150014')) { throw ('Installed-app check failed: ' + $installed.Output) }
            $target = if ($app.Location) { $app.Location } else { 'App default location' }
            if ($installed.Code -eq '0x00000000') {
                Write-RunMessage $LogPath ($app.Name + ': PASS - already installed; will skip.')
                continue
            }
            if ($app.Location -and (Test-Path -LiteralPath $app.Location)) { throw ('Destination already exists: ' + $app.Location) }
            if ($app.Location) {
                $ancestor = Split-Path $app.Location -Parent
                while ($ancestor) {
                    if (Test-Path -LiteralPath $ancestor) {
                        if (-not (Test-Path -LiteralPath $ancestor -PathType Container)) { throw ('Destination parent is not a folder: ' + $ancestor) }
                        break
                    }
                    $ancestor = Split-Path $ancestor -Parent
                }
            }
            $command = 'winget install --id "{0}" --exact --source winget --silent --no-upgrade --accept-package-agreements --accept-source-agreements --disable-interactivity' -f $app.Id
            if ($app.Version) { $command += ' --version "' + $app.Version + '"' }
            if ($app.Architecture) { $command += ' --architecture ' + $app.Architecture }
            if ($app.Location) { $command += ' --location "' + $app.Location + '"' }
            Write-RunMessage $LogPath ('{0}: PASS - {1}' -f $app.Name, $target)
            Write-RunMessage $LogPath $command
        }
        catch { $passed = $false; Write-RunMessage $LogPath ($app.Name + ': FAILED - ' + $_.Exception.Message) }
    }
    Write-RunMessage $LogPath ('Dry run log: ' + $LogPath)
    return $passed
}
Export-ModuleMember -Function Invoke-InstallationDryRun
