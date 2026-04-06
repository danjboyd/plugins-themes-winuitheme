$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$compatDir = Join-Path $repoRoot "tmp\clang64-linker-compat"
$sourceLib = "C:\msys64\mingw64\lib\libgcc_s.a"
$targetLib = Join-Path $compatDir "libgcc_s.a"

if (-not (Test-Path $sourceLib)) {
  throw "Missing GNUstep compatibility library at $sourceLib"
}

New-Item -ItemType Directory -Force -Path $compatDir | Out-Null
Copy-Item $sourceLib $targetLib -Force

Write-Output $compatDir
