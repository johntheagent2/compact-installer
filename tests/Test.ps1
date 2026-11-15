#Requires -Version 5.1
[CmdletBinding()]
param([string]$TestFile)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sources = @(Get-ChildItem (Join-Path $root 'src') -File -Filter *.psm1) + @(Get-Item (Join-Path $root 'Install.ps1')) + @(Get-ChildItem $PSScriptRoot -File -Filter *.ps1) + @(Get-ChildItem (Join-Path $root 'scripts') -File -Filter *.ps1)
foreach ($source in $sources) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($source.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
}
Import-Module Pester -MinimumVersion 3.4 -MaximumVersion 4.99 -ErrorAction Stop
$target = if ($TestFile) { Join-Path $PSScriptRoot $TestFile } else { $PSScriptRoot }
$result = Invoke-Pester -Script $target -PassThru
if ($result.FailedCount -gt 0 -or $result.TotalCount -eq 0) { exit 1 }
exit 0
