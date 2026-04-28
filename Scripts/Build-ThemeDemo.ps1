$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$themeDemoDir = Join-Path $repoRoot "Examples\ThemeDemo"
$gnuStep = "gnustep"

& $gnuStep build --clean $themeDemoDir

if ($LASTEXITCODE -ne 0) {
  throw "ThemeDemo build failed with exit code $LASTEXITCODE"
}
