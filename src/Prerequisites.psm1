#Requires -Version 5.1
Set-StrictMode -Version Latest

function Assert-SupportedWindows {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $architecture = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITEW6432')
    if (-not $architecture) { $architecture = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE') }
    if ([int]$os.BuildNumber -lt 22000 -or $os.ProductType -ne 1 -or $architecture -ne 'AMD64' -or -not [Environment]::Is64BitProcess) {
        throw 'This installer requires Windows 11 on an Intel/AMD 64-bit PC. Launch it using install.cmd.'
    }
}

function Find-WorkingWinGet {
    param([string]$LogPath)
    $candidates = @()
    $command = Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
    $candidates += Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    $package = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue
    if ($package) { $candidates += Join-Path $package.InstallLocation 'winget.exe' }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        try {
            $probe = Invoke-WinGet $candidate @('--version') $LogPath
            if ($probe.Code -eq '0x00000000' -and $probe.Output -match 'v?(\d+\.\d+\.\d+)') {
                if ([version]$Matches[1] -ge [version]'1.9.0') { return $candidate }
            }
        }
        catch { Write-RunMessage $LogPath ('WinGet check failed: ' + $_.Exception.Message) }
    }
}

function Initialize-WinGet {
    param([Parameter(Mandatory)][string]$LogPath)
    $path = Find-WorkingWinGet $LogPath
    if ($path) { return $path }
    Write-RunMessage $LogPath 'Preparing WinGet...'
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
    }
    catch { Write-RunMessage $LogPath ('App Installer registration: ' + $_.Exception.Message) }
    $path = Find-WorkingWinGet $LogPath
    if ($path) { return $path }

    # Microsoft documents this repair path. Use current-user scope so the CLI
    # remains in the signed-in user's context; app installers handle their UAC.
    $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol -bor [Net.SecurityProtocolType]::Tls12
        Write-RunMessage $LogPath 'Installing the Microsoft.WinGet.Client prerequisite from PowerShell Gallery...'
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Repository PSGallery -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Import-Module Microsoft.WinGet.Client -ErrorAction Stop
        Repair-WinGetPackageManager -Latest -Force -ErrorAction Stop | Out-Null
    }
    catch {
        throw ('Automatic WinGet setup failed: {0} Install or update Microsoft App Installer, then run install.cmd again. https://apps.microsoft.com/detail/9nblggh4nns1' -f $_.Exception.Message)
    }
    finally { [Net.ServicePointManager]::SecurityProtocol = $previousProtocol }
    $path = Find-WorkingWinGet $LogPath
    if (-not $path) {
        throw 'WinGet is still unavailable after setup. Sign out and back in, then run install.cmd again. If it still fails, install or update Microsoft App Installer.'
    }
    return $path
}

Export-ModuleMember -Function Assert-SupportedWindows, Initialize-WinGet, Find-WorkingWinGet
