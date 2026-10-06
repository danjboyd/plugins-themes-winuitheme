$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$themeDemoDir = Join-Path $repoRoot "Examples\ThemeDemo"

& (Join-Path $PSScriptRoot "Invoke-GNUstepMake.ps1") -Directory $themeDemoDir -Clean
