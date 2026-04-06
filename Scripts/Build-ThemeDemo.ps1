$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$compatDir = & (Join-Path $PSScriptRoot "Prepare-GNUstepCompat.ps1")
$bash = "C:\msys64\usr\bin\bash.exe"

if (-not (Test-Path $bash)) {
  throw "Missing bash at $bash"
}

$compatUnix = $compatDir.Replace('\', '/').Replace('C:', '/c')
$command = @"
export PATH=/clang64/bin:`$PATH
export LIBRARY_PATH=${compatUnix}:/clang64/lib
source /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
cd /c/Users/Support/git/plugins-themes-winuitheme/Examples/ThemeDemo
make clean
make
"@

& $bash -lc $command

if ($LASTEXITCODE -ne 0) {
  throw "ThemeDemo build failed with exit code $LASTEXITCODE"
}
