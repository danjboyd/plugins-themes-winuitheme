$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$gnuStep = "gnustep"

& $gnuStep build --clean $repoRoot

if ($LASTEXITCODE -ne 0) {
  throw "Theme bundle build failed with exit code $LASTEXITCODE"
}
