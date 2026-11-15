$root = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'src\Installer.psm1') -Force
Import-Module (Join-Path $root 'src\Destination.psm1') -Force
Import-Module (Join-Path $root 'src\DryRun.psm1') -Force
Describe 'Dry-run verification' {
    $fake = Join-Path $TestDrive 'winget.exe'
    Add-Type -TypeDefinition (Get-Content (Join-Path $PSScriptRoot 'fixtures\FakeWinGet.cs') -Raw) -OutputAssembly $fake -OutputType ConsoleApplication
    BeforeEach {
        Mock Write-Host {} -ModuleName Installer
        Mock Get-DestinationDisks { [pscustomobject]@{ Root = 'C:\' } } -ModuleName DryRun
        $env:COMPACT_TEST_CALLS = Join-Path $TestDrive ([guid]::NewGuid().ToString('N') + '.txt')
        $env:COMPACT_TEST_SCENARIO = 'success'
        $log = New-RunLog $TestDrive
    }
    It 'verifies a pinned package without executing an installer or creating app directories' {
        $apps = @(Get-AppCatalog)
        Invoke-InstallationDryRun @($apps[3]) 'C:\' $fake $log | Should Be $true
        $calls = Get-Content $env:COMPACT_TEST_CALLS -Raw
        $calls | Should Match 'show --id UniKey.UniKey'
        $calls | Should Match '--version 4.6.230919 --architecture x64'
        $calls | Should Not Match '(?m)^install '
        (Get-Content $log -Raw) | Should Match 'winget install'
    }
    It 'blocks installation when package verification fails' {
        $env:COMPACT_TEST_SCENARIO = 'missing-package'
        Invoke-InstallationDryRun @(@(Get-AppCatalog)[0]) 'C:\' $fake $log | Should Be $false
        (Get-Content $env:COMPACT_TEST_CALLS -Raw) | Should Not Match '(?m)^install '
    }
}
Remove-Item Env:\COMPACT_TEST_SCENARIO, Env:\COMPACT_TEST_CALLS -ErrorAction SilentlyContinue
