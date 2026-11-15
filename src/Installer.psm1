#Requires -Version 5.1
Set-StrictMode -Version Latest

function Get-AppCatalog {
    @(
        [pscustomobject]@{ Name = 'Steam'; Id = 'Valve.Steam'; Selected = $true; Version = $null }
        [pscustomobject]@{ Name = 'Discord'; Id = 'Discord.Discord'; Selected = $true; Version = $null }
        [pscustomobject]@{ Name = 'Notepad++'; Id = 'Notepad++.Notepad++'; Selected = $true; Version = $null }
        # The newer 4.6.250531 build is ARM64-only. This is the official x64 build.
        [pscustomobject]@{ Name = 'UniKey'; Id = 'UniKey.UniKey'; Selected = $true; Version = '4.6.230919' }
        [pscustomobject]@{ Name = '7-Zip'; Id = '7zip.7zip'; Selected = $true; Version = $null }
        [pscustomobject]@{ Name = 'Everything'; Id = 'voidtools.Everything'; Selected = $false; Version = $null }
        [pscustomobject]@{ Name = 'VLC'; Id = 'VideoLAN.VLC'; Selected = $false; Version = $null }
        [pscustomobject]@{ Name = 'PowerToys'; Id = 'Microsoft.PowerToys'; Selected = $false; Version = $null }
    )
}

function New-RunLog {
    param([Parameter(Mandatory)][string]$Root)
    $directory = Join-Path $Root 'logs'
    [void][IO.Directory]::CreateDirectory($directory)
    $name = 'install-{0}-{1}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $path = Join-Path $directory $name
    Set-Content -LiteralPath $path -Value 'Compact Installer' -Encoding UTF8 -ErrorAction Stop
    return $path
}

function Write-RunMessage {
    param(
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message
    )
    Add-Content -LiteralPath $LogPath -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) -Encoding UTF8 -ErrorAction Stop
    Write-Host $Message
}

function Invoke-WinGet {
    param(
        [Parameter(Mandatory)][string]$WingetPath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$LogPath
    )
    Write-RunMessage $LogPath ('winget ' + ($Arguments -join ' '))
    $output = New-Object 'System.Collections.Generic.List[string]'
    # Windows PowerShell treats native stderr as ErrorRecords. Preserve it without
    # mistaking stderr output for a failed process; the exit code is authoritative.
    $previousPreference = $ErrorActionPreference
    $previousEncoding = [Console]::OutputEncoding
    try {
        $ErrorActionPreference = 'Continue'
        [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
        $global:LASTEXITCODE = $null
        & $WingetPath @Arguments 2>&1 | ForEach-Object {
            $line = [string]$_
            $line = $line -replace '\x1B\[[0-?]*[ -/]*[@-~]', ''
            $output.Add($line)
            Write-RunMessage $LogPath $line
        }
        if ($null -eq $global:LASTEXITCODE) { throw 'WinGet did not return an exit code.' }
        $exitCode = [int]$global:LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
        [Console]::OutputEncoding = $previousEncoding
    }
    # WinGet HRESULTs arrive as signed integers in Windows PowerShell.
    $code = '0x{0:X8}' -f ([long]$exitCode -band 4294967295L)
    Write-RunMessage $LogPath ('Exit code: ' + $code)
    [pscustomobject]@{ Code = $code; Output = ($output -join [Environment]::NewLine) }
}

function Invoke-AppInstall {
    param($App, [string]$WingetPath, [string]$LogPath)
    $result = [pscustomobject]@{ Id = $App.Id; Name = $App.Name; Status = 'Failed'; Detail = '' }
    try {
        Write-RunMessage $LogPath ('Checking ' + $App.Name + '...')
        $query = Invoke-WinGet $WingetPath @('list', '--id', $App.Id, '--exact', '--source', 'winget', '--accept-source-agreements', '--disable-interactivity') $LogPath
        if ($query.Code -eq '0x00000000') {
            $result.Status = 'Skipped'
            $result.Detail = 'Already installed.'
            return $result
        }
        if ($query.Code -ne '0x8A150014') {
            throw ('Could not check installed apps ({0}). {1}' -f $query.Code, $query.Output)
        }

        $arguments = @('install', '--id', $App.Id, '--exact', '--source', 'winget', '--silent', '--no-upgrade', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
        if ($App.Version) { $arguments += @('--version', $App.Version, '--architecture', 'x64') }
        Write-RunMessage $LogPath ('Installing ' + $App.Name + '...')
        $installation = Invoke-WinGet $WingetPath $arguments $LogPath
        switch ($installation.Code) {
            '0x00000000' { $result.Status = 'Installed'; $result.Detail = 'Installation completed.' }
            '0x8A150109' { $result.Status = 'Installed'; $result.Detail = 'Restart Windows to finish installation.' }
            '0x8A150061' { $result.Status = 'Skipped'; $result.Detail = 'Already installed.' }
            '0x8A15010D' { $result.Status = 'Skipped'; $result.Detail = 'Installer reports that the app is already installed.' }
            default { $result.Detail = 'Installation failed ({0}). {1}' -f $installation.Code, $installation.Output }
        }
    }
    catch { $result.Detail = $_.Exception.Message }
    Write-RunMessage $LogPath ('{0}: {1}. {2}' -f $result.Name, $result.Status, $result.Detail)
    return $result
}

function Write-InstallSummary {
    param([object[]]$Results, [string]$LogPath)
    Write-RunMessage $LogPath ''
    Write-RunMessage $LogPath 'Installation summary'
    foreach ($result in $Results) {
        $detail = if ($result.Status -eq 'Failed') { 'See failure details below.' } else { $result.Detail }
        Write-RunMessage $LogPath ('  {0,-12} {1,-9} {2}' -f $result.Name, $result.Status, $detail)
    }
    $failed = @($Results | Where-Object Status -eq 'Failed')
    if ($failed.Count -gt 0) {
        Write-RunMessage $LogPath 'Failed apps:'
        foreach ($result in $failed) {
            Write-RunMessage $LogPath ('  {0} ({1}): {2}' -f $result.Name, $result.Id, $result.Detail)
        }
    }
    Write-RunMessage $LogPath ('Log: ' + $LogPath)
}

function Invoke-InstallSession {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Apps,
        [Parameter(Mandatory)][string]$WingetPath,
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][scriptblock]$RetryPrompt
    )
    $results = @{}
    $pending = @($Apps)
    while ($pending.Count -gt 0) {
        foreach ($app in $pending) {
            $results[$app.Id] = Invoke-AppInstall $app $WingetPath $LogPath
        }
        $orderedResults = @($Apps | ForEach-Object { $results[$_.Id] })
        Write-InstallSummary $orderedResults $LogPath
        $failed = @($orderedResults | Where-Object Status -eq 'Failed')
        if ($failed.Count -eq 0 -or -not (& $RetryPrompt $failed)) { break }
        Write-RunMessage $LogPath 'Retrying failed apps...'
        $pending = @($Apps | Where-Object { $results[$_.Id].Status -eq 'Failed' })
    }
    foreach ($app in $Apps) { $results[$app.Id] }
}

Export-ModuleMember -Function Get-AppCatalog, New-RunLog, Write-RunMessage, Invoke-InstallSession, Invoke-WinGet
