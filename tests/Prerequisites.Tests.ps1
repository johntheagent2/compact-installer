$projectRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $projectRoot 'src\Installer.psm1') -Force
Import-Module (Join-Path $projectRoot 'src\Prerequisites.psm1') -Force

# The repair command is normally supplied by the downloaded Microsoft module.
# This stub makes that external boundary mockable without downloading anything.
function global:Repair-WinGetPackageManager {
    param([switch]$Latest, [switch]$Force)
    throw 'Tests must mock the WinGet repair command.'
}

Describe 'Preparing WinGet' {
    $fixtureRoot = Join-Path $TestDrive 'prerequisite test files'
    [void][IO.Directory]::CreateDirectory($fixtureRoot)
    $fakeWinget = Join-Path $fixtureRoot 'winget.exe'
    Add-Type -TypeDefinition (Get-Content (Join-Path $PSScriptRoot 'fixtures\FakeWinGet.cs') -Raw) -OutputAssembly $fakeWinget -OutputType ConsoleApplication

    BeforeEach {
        $env:COMPACT_TEST_EXE = $fakeWinget
        $env:COMPACT_TEST_AVAILABLE = 'no'
        $env:COMPACT_TEST_SCENARIO = 'success'
        $env:COMPACT_TEST_CALLS = Join-Path $fixtureRoot ([guid]::NewGuid().ToString('N') + '.txt')
        $log = New-RunLog $fixtureRoot
        Mock Write-Host {} -ModuleName Installer
        Mock Get-Command {
            if ($env:COMPACT_TEST_AVAILABLE -eq 'yes') { [pscustomobject]@{ Source = $env:COMPACT_TEST_EXE } }
        } -ModuleName Prerequisites -ParameterFilter { $Name -eq 'winget.exe' }
        Mock Get-AppxPackage {} -ModuleName Prerequisites
        Mock Test-Path { $LiteralPath -eq $env:COMPACT_TEST_EXE -and $env:COMPACT_TEST_AVAILABLE -eq 'yes' } -ModuleName Prerequisites -ParameterFilter { $LiteralPath -like '*winget.exe' }
        Mock Add-AppxPackage {} -ModuleName Prerequisites
        Mock Install-PackageProvider {} -ModuleName Prerequisites
        Mock Install-Module {} -ModuleName Prerequisites
        Mock Import-Module {} -ModuleName Prerequisites -ParameterFilter { $Name -eq 'Microsoft.WinGet.Client' }
        Mock Repair-WinGetPackageManager { $env:COMPACT_TEST_AVAILABLE = 'yes' } -ModuleName Prerequisites
    }

    It 'uses an already working WinGet without changing prerequisites' {
        $env:COMPACT_TEST_AVAILABLE = 'yes'
        Initialize-WinGet $log | Should Be $fakeWinget
        Assert-MockCalled Add-AppxPackage -ModuleName Prerequisites -Times 0 -Exactly -Scope It
        Assert-MockCalled Install-Module -ModuleName Prerequisites -Times 0 -Exactly -Scope It
        Assert-MockCalled Repair-WinGetPackageManager -ModuleName Prerequisites -Times 0 -Exactly -Scope It
    }

    It 'registers App Installer first without downloading if registration is sufficient' {
        Mock Add-AppxPackage { $env:COMPACT_TEST_AVAILABLE = 'yes' } -ModuleName Prerequisites
        Initialize-WinGet $log | Should Be $fakeWinget
        Assert-MockCalled Add-AppxPackage -ModuleName Prerequisites -Times 1 -Exactly -Scope It
        Assert-MockCalled Install-Module -ModuleName Prerequisites -Times 0 -Exactly -Scope It
    }

    It 'automatically installs and verifies WinGet when registration is insufficient' {
        Mock Add-AppxPackage { throw 'App Installer missing' } -ModuleName Prerequisites
        Initialize-WinGet $log | Should Be $fakeWinget
        Assert-MockCalled Install-Module -ModuleName Prerequisites -Times 1 -Exactly -Scope It -ParameterFilter { $Name -eq 'Microsoft.WinGet.Client' -and $Scope -eq 'CurrentUser' -and $Repository -eq 'PSGallery' }
        Assert-MockCalled Repair-WinGetPackageManager -ModuleName Prerequisites -Times 1 -Exactly -Scope It -ParameterFilter { $Latest -and $Force }
    }

    It 'stops with an actionable error when the prerequisite download fails' {
        Mock Install-Module { throw 'Network unavailable' } -ModuleName Prerequisites
        { Initialize-WinGet $log } | Should Throw 'Automatic WinGet setup failed: Network unavailable'
        Assert-MockCalled Repair-WinGetPackageManager -ModuleName Prerequisites -Times 0 -Exactly -Scope It
    }

    It 'does not claim success when repair returns but WinGet is still unavailable' {
        Mock Repair-WinGetPackageManager {} -ModuleName Prerequisites
        { Initialize-WinGet $log } | Should Throw 'WinGet is still unavailable after setup'
    }
}

Remove-Item Function:\Repair-WinGetPackageManager -ErrorAction SilentlyContinue
Remove-Item Env:\COMPACT_TEST_EXE, Env:\COMPACT_TEST_AVAILABLE, Env:\COMPACT_TEST_SCENARIO, Env:\COMPACT_TEST_CALLS -ErrorAction SilentlyContinue
