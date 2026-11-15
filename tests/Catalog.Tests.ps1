$root = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'src\Installer.psm1') -Force
Describe 'Editable catalog' {
    It 'loads the bundled metadata and returns independent selections' {
        $apps = @(Get-AppCatalog)
        $apps[0].Description | Should Be 'Gaming'
        $apps[1].SupportsCustomLocation | Should Be $false
        $apps[3].Architecture | Should Be 'x64'
    }
    It 'rejects duplicate package identities before returning a catalog' {
        $doc = Get-Content (Join-Path $root 'apps.json') -Raw | ConvertFrom-Json
        $doc.apps[1].id = $doc.apps[0].id
        $file = Join-Path $TestDrive 'bad.json'
        $doc | ConvertTo-Json -Depth 5 | Set-Content $file
        { Get-AppCatalog $file } | Should Throw 'duplicate'
    }
    It 'rejects string booleans and invalid folder names' {
        $doc = Get-Content (Join-Path $root 'apps.json') -Raw | ConvertFrom-Json
        $file = Join-Path $TestDrive 'bad.json'
        $doc.apps[0].selectedByDefault = 'false'
        $doc | ConvertTo-Json -Depth 5 | Set-Content $file
        { Get-AppCatalog $file } | Should Throw 'must be true or false'
        $doc.apps[0].selectedByDefault = $true
        $doc.apps[0].name = '..'
        $doc | ConvertTo-Json -Depth 5 | Set-Content $file
        { Get-AppCatalog $file } | Should Throw 'folder name'
    }
}
