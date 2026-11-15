#Requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $root 'dist'
[void][IO.Directory]::CreateDirectory($destination)
$archive = Join-Path $destination 'compact-installer.zip'
$files = @('install.cmd', 'Install.ps1', 'src', 'README.md') | ForEach-Object { Join-Path $root $_ }
Compress-Archive -LiteralPath $files -DestinationPath $archive -Force
Write-Host ('Created ' + $archive)
