$root = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'src\Installer.psm1') -Force
Import-Module (Join-Path $root 'src\Destination.psm1') -Force
Describe 'Choosing installation destinations' {
    It 'uses app defaults on C even after another disk was chosen' {
        $apps = @(Get-AppCatalog)
        Set-AppDestination $apps 'D:\'
        $apps[0].Location | Should Be 'D:\Apps\Steam'
        Set-AppDestination $apps 'C:\'
        @($apps | Where-Object Location).Count | Should Be 0
    }
    It 'assigns separate folders while preserving unsupported app defaults' {
        $apps = @(Get-AppCatalog)
        Set-AppDestination $apps 'E:\'
        $apps[3].Location | Should Be 'E:\Apps\UniKey'
        $apps[4].Location | Should Be 'E:\Apps\7-Zip'
        $apps[1].Location | Should BeNullOrEmpty
        $apps[7].Location | Should BeNullOrEmpty
    }
    It 'rejects a disk that disappeared instead of switching destinations' {
        Mock Get-DestinationDisks { @() } -ModuleName Destination
        { Test-AppDestinations @() 'D:\' } | Should Throw 'no longer available'
    }
}
