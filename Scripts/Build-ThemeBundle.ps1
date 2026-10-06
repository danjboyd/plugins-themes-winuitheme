$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot "Invoke-GNUstepMake.ps1") -Directory $repoRoot -Clean
