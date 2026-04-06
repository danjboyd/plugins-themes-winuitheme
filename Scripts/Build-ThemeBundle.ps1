$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$compatDir = & (Join-Path $PSScriptRoot "Prepare-GNUstepCompat.ps1")
$bash = "C:\msys64\usr\bin\bash.exe"
$gnuStepMakefiles = "/clang64/share/GNUstep/Makefiles/GNUstep.sh"

if (-not (Test-Path $bash)) {
  throw "Missing bash at $bash"
}

$compatUnix = $compatDir.Replace('\', '/').Replace('C:', '/c')
$command = @"
export PATH=/usr/bin:/clang64/bin:/mingw64/bin:`$PATH
export LIBRARY_PATH=${compatUnix}:/clang64/lib
source $gnuStepMakefiles
cd /c/Users/Support/git/plugins-themes-winuitheme
make clean
make
"@

try {
  & $bash -lc $command

  if ($LASTEXITCODE -ne 0) {
    throw "Theme bundle build failed with exit code $LASTEXITCODE"
  }
} catch {
  Write-Warning "Theme bundle linking is still blocked by the local clang64 GNUstep toolchain. The same machine currently fails to link neighboring Win11Theme and Adwaita bundles as well."
  throw
}
