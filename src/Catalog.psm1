#Requires -Version 5.1
Set-StrictMode -Version Latest
function Read-AppCatalog {
    param([string]$Path)
    try { $document = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
    catch { throw ('Cannot read apps.json: ' + $_.Exception.Message) }
    if (-not $document -or -not $document.PSObject.Properties['schemaVersion'] -or $document.schemaVersion -isnot [int] -or $document.schemaVersion -ne 1) { throw 'apps.json: schemaVersion must be 1.' }
    if (-not $document.PSObject.Properties['apps'] -or $document.apps -isnot [array] -or $document.apps.Count -eq 0) { throw 'apps.json: apps must be a nonempty array.' }
    $ids = @{}
    $names = @{}
    $result = @()
    foreach ($app in $document.apps) {
        if ($null -eq $app) { throw 'apps.json: app entry cannot be null.' }
        foreach ($field in @('name', 'id', 'description')) {
            if (-not $app.PSObject.Properties[$field] -or $app.$field -isnot [string] -or [string]::IsNullOrWhiteSpace($app.$field)) { throw "apps.json: app field '$field' must be a nonempty string." }
        }
        $label = $app.name
        if ($label -match '[<>:"/\\|?*\x00-\x1F]' -or $label -match '[ .]$' -or $label -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)' -or $label.Length -gt 100) { throw "apps.json: '$label' is not a valid app folder name." }
        if ($app.id -notmatch '^[A-Za-z0-9][A-Za-z0-9.+_-]*\.[A-Za-z0-9.+_-]+$') { throw "apps.json: '$label' has an invalid id." }
        if ($ids.ContainsKey($app.id) -or $names.ContainsKey($label)) { throw "apps.json: duplicate id or name for '$label'." }
        $ids[$app.id] = $true; $names[$label] = $true
        foreach ($field in @('selectedByDefault', 'supportsCustomLocation')) {
            if (-not $app.PSObject.Properties[$field] -or $app.$field -isnot [bool]) { throw "apps.json: '$label.$field' must be true or false." }
        }
        foreach ($field in @('version', 'architecture', 'notes')) {
            if (-not $app.PSObject.Properties[$field]) { $app | Add-Member NoteProperty $field $null }
            if ($null -ne $app.$field -and ($app.$field -isnot [string] -or [string]::IsNullOrWhiteSpace($app.$field) -or $app.$field -match '[\x00-\x1F]')) { throw "apps.json: '$label.$field' must be a nonempty string or null." }
        }
        if ($app.version -and $app.version -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]*$') { throw "apps.json: '$label.version' is invalid." }
        if ($app.architecture -and $app.architecture -notin @('x64', 'x86', 'neutral')) { throw "apps.json: '$label.architecture' must be x64, x86, or neutral on this x64 installer." }
        $result += [pscustomobject]@{ Name = $label; Id = $app.id; Description = $app.description; Selected = $app.selectedByDefault; SupportsCustomLocation = $app.supportsCustomLocation; Version = $app.version; Architecture = $app.architecture; Notes = $app.notes; Location = $null }
    }
    $result
}
Export-ModuleMember -Function Read-AppCatalog
