$projectRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $projectRoot 'src\Installer.psm1') -Force
Describe 'Installing an app selection' {
    $fixtureRoot = Join-Path $TestDrive 'installer test files'
    [void][IO.Directory]::CreateDirectory($fixtureRoot)
    $fakeWinget = Join-Path $fixtureRoot 'winget.exe'
    Add-Type -TypeDefinition (Get-Content (Join-Path $PSScriptRoot 'fixtures\FakeWinGet.cs') -Raw) -OutputAssembly $fakeWinget -OutputType ConsoleApplication

    BeforeEach {
        Mock Write-Host {} -ModuleName Installer
        $env:COMPACT_TEST_SCENARIO = 'success'
        $env:COMPACT_TEST_CALLS = Join-Path $fixtureRoot ([guid]::NewGuid().ToString('N') + '.txt')
        $log = New-RunLog $fixtureRoot
        $catalog = @(Get-AppCatalog)
    }

    It 'starts every catalog with the five agreed defaults and three optional apps' {
        (($catalog | Where-Object Selected | ForEach-Object Name) -join ',') | Should Be 'Steam,Discord,Notepad++,UniKey,7-Zip'
        (($catalog | Where-Object { -not $_.Selected } | ForEach-Object Name) -join ',') | Should Be 'Everything,VLC,PowerToys'
        $catalog[0].Selected = $false
        @(Get-AppCatalog)[0].Selected | Should Be $true
    }

    It 'installs only the chosen app using its exact identity without upgrading' {
        $results = @(Invoke-InstallSession -Apps @($catalog[2]) -WingetPath $fakeWinget -LogPath $log -RetryPrompt { throw 'No failure to retry' })
        $results.Count | Should Be 1
        $results[0].Status | Should Be 'Installed'
        $calls = Get-Content $env:COMPACT_TEST_CALLS
        $calls.Count | Should Be 2
        $calls[1] | Should Match '^install --id Notepad\+\+\.Notepad\+\+ --exact --source winget '
        $calls[1] | Should Match '--no-upgrade'
        $calls[1] | Should Not Match '--allow-reboot|--force|--ignore-security-hash'
    }

    It 'skips an existing app, continues after a failure, and records failure details at the end' {
        $env:COMPACT_TEST_SCENARIO = 'mixed'
        $results = @(Invoke-InstallSession -Apps $catalog[0..2] -WingetPath $fakeWinget -LogPath $log -RetryPrompt { $false })
        ($results.Status -join ',') | Should Be 'Skipped,Failed,Installed'
        (Get-Content $env:COMPACT_TEST_CALLS -Raw) | Should Not Match 'install --id Valve.Steam'
        $summary = (Get-Content $log -Raw) -split 'Installation summary' | Select-Object -Last 1
        $summary | Should Match 'Failed apps:'
        $summary | Should Match 'Discord \(Discord.Discord\): Installation failed \(0x8A150008\)'
        $summary | Should Match 'Download failed: connection lost'
        $summary | Should Match ([regex]::Escape('Log: ' + $log))
    }

    It 'retries only failed apps and retains their earlier errors in the same log' {
        $env:COMPACT_TEST_SCENARIO = 'retry'
        $retryState = @{ Count = 0 }
        $retryPrompt = { $retryState.Count++; if ($retryState.Count -gt 1) { throw 'Unexpected second retry prompt' }; $true }.GetNewClosure()
        $results = @(Invoke-InstallSession -Apps $catalog[0..2] -WingetPath $fakeWinget -LogPath $log -RetryPrompt $retryPrompt)
        ($results.Status -join ',') | Should Be 'Installed,Installed,Installed'
        $calls = Get-Content $env:COMPACT_TEST_CALLS
        @($calls | Where-Object { $_ -match '^install --id Discord.Discord ' }).Count | Should Be 2
        @($calls | Where-Object { $_ -match '^install --id Valve.Steam ' }).Count | Should Be 1
        @($calls | Where-Object { $_ -match '^install --id Notepad' }).Count | Should Be 1
        (Get-Content $log -Raw) | Should Match 'Download failed: connection lost'
        $summary = (Get-Content $log -Raw) -split 'Installation summary' | Select-Object -Last 1
        $summary | Should Not Match 'Failed apps:'
    }

    It 'does not install when installed-app detection fails for a reason other than not found' {
        $env:COMPACT_TEST_SCENARIO = 'list-error'
        $results = @(Invoke-InstallSession -Apps @($catalog[0]) -WingetPath $fakeWinget -LogPath $log -RetryPrompt { $false })
        $results[0].Status | Should Be 'Failed'
        $results[0].Detail | Should Match 'Could not check installed apps.*0x8A150045'
        (Get-Content $env:COMPACT_TEST_CALLS -Raw) | Should Not Match 'install --id'
    }

    It 'passes the chosen app destination as one argument to the installer' {
        $catalog[2] | Add-Member NoteProperty Location 'D:\Apps\Notepad++'
        $results = @(Invoke-InstallSession -Apps @($catalog[2]) -WingetPath $fakeWinget -LogPath $log -RetryPrompt { $false })
        $results[0].Status | Should Be 'Installed'
        (Get-Content $env:COMPACT_TEST_CALLS -Raw) | Should Match '--location D:\\Apps\\Notepad\+\+'
    }

    It 'uses the compatible x64 UniKey build' {
        $results = @(Invoke-InstallSession -Apps @($catalog[3]) -WingetPath $fakeWinget -LogPath $log -RetryPrompt { $false })
        $results[0].Status | Should Be 'Installed'
        (Get-Content $env:COMPACT_TEST_CALLS -Raw) | Should Match '--version 4\.6\.230919 --architecture x64'
    }

    It 'reports a restart-required installation as successful without restarting Windows' {
        $env:COMPACT_TEST_SCENARIO = 'reboot'
        $results = @(Invoke-InstallSession -Apps @($catalog[0]) -WingetPath $fakeWinget -LogPath $log -RetryPrompt { throw 'Successful install must not be retried' })
        $results[0].Status | Should Be 'Installed'
        $results[0].Detail | Should Match 'Restart Windows'
    }

    It 'handles an app installed between the initial check and the install command' {
        $env:COMPACT_TEST_SCENARIO = 'already'
        $results = @(Invoke-InstallSession -Apps @($catalog[0]) -WingetPath $fakeWinget -LogPath $log -RetryPrompt { throw 'Skipped app must not be retried' })
        $results[0].Status | Should Be 'Skipped'
    }

    It 'reports unknown native failures with their exit code and stderr' {
        $env:COMPACT_TEST_SCENARIO = 'unknown-exit'
        $results = @(Invoke-InstallSession -Apps @($catalog[0]) -WingetPath $fakeWinget -LogPath $log -RetryPrompt { $false })
        $results[0].Status | Should Be 'Failed'
        $results[0].Detail | Should Match '0x00000057'
        $results[0].Detail | Should Match 'Unexpected installer error'
    }

    It 'does not execute any package command for an empty selection' {
        $results = @(Invoke-InstallSession -Apps @() -WingetPath $fakeWinget -LogPath $log -RetryPrompt { throw 'Nothing to retry' })
        $results.Count | Should Be 0
        Test-Path $env:COMPACT_TEST_CALLS | Should Be $false
    }

    It 'creates a separate timestamped log for each run without overwriting earlier logs' {
        $otherLog = New-RunLog $fixtureRoot
        $otherLog | Should Not Be $log
        Split-Path $log -Leaf | Should Match '^install-\d{8}-\d{6}-\d{3}-[a-f0-9]{8}\.log$'
        Test-Path $log | Should Be $true
        Test-Path $otherLog | Should Be $true
    }
}

Remove-Item Env:\COMPACT_TEST_SCENARIO, Env:\COMPACT_TEST_CALLS -ErrorAction SilentlyContinue
