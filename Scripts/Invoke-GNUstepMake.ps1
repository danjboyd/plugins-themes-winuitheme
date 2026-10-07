param(
  [Parameter(Mandatory = $true)]
  [string]$Directory,
  [switch]$Clean,
  [string[]]$MakeArguments = @()
)

# Builds a GNUstep make project. Uses the `gnustep` CLI when it is on PATH;
# otherwise runs GNUstep Make under MSYS2's clang64 environment.

$ErrorActionPreference = "Stop"

$directoryPath = (Resolve-Path $Directory).Path
$gnuStepCli = Get-Command gnustep -ErrorAction SilentlyContinue

if ($gnuStepCli -ne $null -and $MakeArguments.Count -eq 0) {
  $cliArguments = @("build")
  if ($Clean) {
    $cliArguments += "--clean"
  }
  $cliArguments += $directoryPath

  & $gnuStepCli.Source @cliArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Build of $directoryPath failed with exit code $LASTEXITCODE"
  }
  return
}

$bash = "C:\msys64\usr\bin\bash.exe"
$gnuStepMakefiles = "/clang64/share/GNUstep/Makefiles/GNUstep.sh"

if (-not (Test-Path $bash)) {
  throw ("Neither the gnustep CLI nor MSYS2 ($bash) was found. Install one " +
         "of them; see Docs/WINDOWS_BUILD.md.")
}

$compatDir = & (Join-Path $PSScriptRoot "Prepare-GNUstepCompat.ps1")
$compatUnix = (& $bash -lc "cygpath -u '$compatDir'").Trim()
$directoryUnix = (& $bash -lc "cygpath -u '$directoryPath'").Trim()
$makeCommand = "make " + ($MakeArguments -join " ")
$cleanCommand = if ($Clean) { "make clean" } else { "true" }

$command = @"
export PATH=/usr/bin:/clang64/bin:/mingw64/bin:`$PATH
export LIBRARY_PATH=${compatUnix}:/clang64/lib
source $gnuStepMakefiles
cd '$directoryUnix'
$cleanCommand && $makeCommand
"@

& $bash -lc $command
if ($LASTEXITCODE -ne 0) {
  throw "Build of $directoryPath failed with exit code $LASTEXITCODE"
}
