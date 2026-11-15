#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$logPath = $null
$exitCode = 0
try {
    Import-Module (Join-Path $PSScriptRoot 'src\Installer.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'src\Console.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'src\Prerequisites.psm1') -Force
    $logPath = New-RunLog $PSScriptRoot
    Assert-SupportedWindows
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        throw 'Open install.cmd in an interactive Windows terminal; redirected input/output is not supported.'
    }
    $selection = @(Read-AppSelection -Catalog @(Get-AppCatalog))
    if ($selection.Count -eq 0) {
        Write-RunMessage $logPath 'Cancelled. No installations were requested.'
        Write-RunMessage $logPath ('Log: ' + $logPath)
    }
    else {
        Write-RunMessage $logPath ('Selected apps: ' + (($selection | ForEach-Object Name) -join ', '))
        $wingetPath = Initialize-WinGet $logPath
        $results = @(Invoke-InstallSession -Apps $selection -WingetPath $wingetPath -LogPath $logPath -RetryPrompt {
            param($failedApps)
            Read-RetryChoice -FailedApps $failedApps
        })
        if (@($results | Where-Object Status -eq 'Failed').Count -gt 0) { $exitCode = 1 }
    }
}
catch {
    $exitCode = 1
    $message = 'Installer stopped: ' + $_.Exception.Message
    Write-Host $message -ForegroundColor Red
    if ($logPath) {
        try { Add-Content -LiteralPath $logPath -Value $message -Encoding UTF8 -ErrorAction Stop }
        catch { Write-Host ('Could not append to the log: ' + $_.Exception.Message) -ForegroundColor Red }
        Write-Host ('Log: ' + $logPath)
    }
    else { Write-Host 'No log could be created. Extract the installer into a folder you can write to.' }
}
exit $exitCode
