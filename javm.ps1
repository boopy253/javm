# JAVM: Lightweight Java version manager for PowerShell
#
# Manages multiple Java installations and allows switching between them.
# Functions are exposed as 'javm' command for easy shell integration.
#
# Usage:
#   javm list              - List all registered Java versions
#   javm add <alias> <dir> - Register a new Java installation
#   javm use <alias>       - Switch to a registered Java version
#   javm default [alias]   - View or set the default Java version
#   javm rm <alias>        - Unregister a Java version
#   javm clear             - Restore PATH and unset JAVA_HOME
#   javm current           - Display the currently active Java version

if ($env:JAVM_HOME -and (Test-Path $env:JAVM_HOME)) {
    $Script:JavaHome = $env:JAVM_HOME
} else {
    $Script:JavaHome = $PSScriptRoot
}

$Script:JavaRegistry = Join-Path $Script:JavaHome "versions.map"
$Script:JavaDefault  = Join-Path $Script:JavaHome "default"

if (-not (Test-Path $Script:JavaHome)) { New-Item -ItemType Directory -Path $Script:JavaHome | Out-Null }
if (-not (Test-Path $Script:JavaRegistry)) { New-Item -ItemType File -Path $Script:JavaRegistry | Out-Null }
if (-not (Test-Path $Script:JavaDefault))  { New-Item -ItemType File -Path $Script:JavaDefault  | Out-Null }

if (-not $Script:JavaPathBase) { $Script:JavaPathBase = $env:Path }

# Reads all registered Java versions from the registry file
# Returns an array of PSCustomObjects with Name and Path properties
function Get-JavmEntries {
    Get-Content $Script:JavaRegistry | Where-Object { $_ -match '\S' } | ForEach-Object {
        $parts = $_ -split '\|', 2
        [PSCustomObject]@{ Name = $parts[0].Trim(); Path = $parts[1].Trim() }
    }
}

# Writes the registry file with provided entries, sorted by name
function Save-JavmEntries($entries) {
    $entries | Sort-Object Name | ForEach-Object { "$($_.Name)|$($_.Path)" } | Set-Content $Script:JavaRegistry
}

# Registers a new Java installation with an alias
# Validates that bin\java.exe exists in the specified directory
function Add-Javm([string]$Name, [string]$Path) {
    if (-not $Name) { throw "Usage: javm add <alias> <directory>" }
    if (-not $Path) { $Path = (Get-Location).Path }
    $resolved = (Resolve-Path -Path $Path).ProviderPath
    if (-not (Test-Path (Join-Path $resolved "bin\java.exe"))) {
        throw "Error: bin\java.exe not found in: $resolved"
    }
    $entries = Get-JavmEntries | Where-Object Name -ne $Name
    $entries += [pscustomobject]@{Name=$Name; Path=$resolved}
    Save-JavmEntries $entries
    Write-Host "Registered: $Name -> $resolved"
}

# Removes a registered Java installation by name
function Remove-Javm([string]$Name) {
    if (-not $Name) { throw "Usage: javm rm <alias>" }
    $entries = Get-JavmEntries | Where-Object Name -ne $Name
    Save-JavmEntries $entries
    if ($Script:JavaCurrent -eq $Name) { Clear-Javm }
    Write-Host "Removed: $Name"
}

# Switches to a registered Java installation
# Updates JAVA_HOME and PATH environment variables
function Use-Javm([string]$Name) {
    if (-not $Name) { throw "Usage: javm use <alias>" }
    $entry = Get-JavmEntries | Where-Object Name -eq $Name
    if (-not $entry) { throw "Error: Unknown alias: $Name" }
    if (-not (Test-Path $entry.Path)) { throw "Error: Directory not accessible: $($entry.Path)" }
    $env:JAVA_HOME = $entry.Path
    $env:Path = (Join-Path $entry.Path "bin") + ";" + $Script:JavaPathBase
    $Script:JavaCurrent = $entry.Name
    Write-Host "Now using $($entry.Name) ($($entry.Path))"
}

# Clears the current Java environment and restores original PATH
function Clear-Javm {
    $env:Path = $Script:JavaPathBase
    Remove-Item Env:JAVA_HOME -ErrorAction SilentlyContinue
    $Script:JavaCurrent = $null
}

# Sets or displays the default Java version
# The default version is automatically loaded when the shell starts
function Set-JavmDefault([string]$Name) {
    if ($Name) {
        $entry = Get-JavmEntries | Where-Object Name -eq $Name
        if (-not $entry) { throw "Error: Unknown alias: $Name" }
        Set-Content -Path $Script:JavaDefault -Value $Name
        Use-Javm $Name | Out-Null
    } else {
        if (Test-Path $Script:JavaDefault) { Get-Content $Script:JavaDefault } else { "(not set)" }
    }
}

# Displays all registered Java versions with a marker for the current one
function Show-JavmList {
    Get-JavmEntries | ForEach-Object {
        $mark = if ($_.Name -eq $Script:JavaCurrent) { "*" } else { " " }
        "{0} {1,-15} {2}" -f $mark, $_.Name, $_.Path
    }
}

# Displays the currently active Java version and JAVA_HOME
function Show-JavmCurrent {
    if ($Script:JavaCurrent) { "$($Script:JavaCurrent) -> $env:JAVA_HOME" }
    elseif ($env:JAVA_HOME) { "(external) -> $env:JAVA_HOME" }
    else { "(not selected)" }
}

# Main javm command dispatcher
function javm([string]$Command, [string]$Arg1, [string]$Arg2) {
    switch ($Command) {
        "list" { Show-JavmList }
        "ls" { Show-JavmList }
        "add" { Add-Javm $Arg1 $Arg2 }
        "use" { Use-Javm $Arg1 }
        "default" { if ($Arg1) { Set-JavmDefault $Arg1 } else { Set-JavmDefault } }
        "rm" { Remove-Javm $Arg1 }
        "remove" { Remove-Javm $Arg1 }
        "clear" { Clear-Javm }
        "current" { Show-JavmCurrent }
        "help" {
@"
JAVM: Java Version Manager

Commands:
  javm list              - List registered Java versions
  javm add <alias> <dir> - Register a Java installation
  javm use <alias>       - Switch to a Java version
  javm default [alias]   - View or set default version
  javm rm <alias>        - Unregister a Java version
  javm clear             - Clear PATH and JAVA_HOME
  javm current           - Show current Java version
"@
        }
        default { Show-JavmList }
    }
}

# Auto-load the default Java version when the shell starts
if (Test-Path $Script:JavaDefault) {
    $default = (Get-Content $Script:JavaDefault -ErrorAction SilentlyContinue).Trim()
    if ($default) { try { Use-Javm $default | Out-Null } catch {} }
}
