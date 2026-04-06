$ErrorActionPreference = "Stop"

function Resolve-GNUstepUserRoot {
  $candidates = @()

  if (-not [string]::IsNullOrWhiteSpace($env:GNUSTEP_USER_ROOT)) {
    $candidates += $env:GNUSTEP_USER_ROOT
  }
  if (-not [string]::IsNullOrWhiteSpace($env:USERNAME)) {
    $candidates += (Join-Path (Join-Path "C:\msys64\home" $env:USERNAME) "GNUstep")
  }
  if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
    $candidates += (Join-Path $env:USERPROFILE "GNUstep")
  }

  foreach ($candidate in $candidates) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
      return $candidate
    }
  }

  if ($candidates.Count -gt 0) {
    return $candidates[0]
  }

  throw "Unable to resolve a GNUstep user root."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$compatDir = & (Join-Path $PSScriptRoot "Prepare-GNUstepCompat.ps1")
$bash = "C:\msys64\usr\bin\bash.exe"
$gnuStepMakefiles = "/clang64/share/GNUstep/Makefiles/GNUstep.sh"
$gnuStepUserRoot = Resolve-GNUstepUserRoot
$userThemePath = Join-Path $gnuStepUserRoot "Library\Themes\WinUITheme.theme"
$runtimeThemeRoot = "C:\msys64\clang64\lib\GNUstep\Themes"
$runtimeThemePath = Join-Path $runtimeThemeRoot "WinUITheme.theme"

if (-not (Test-Path $bash)) {
  throw "Missing bash at $bash"
}

$compatUnix = $compatDir.Replace('\', '/').Replace('C:', '/c')
$command = @"
export PATH=/usr/bin:/clang64/bin:/mingw64/bin:`$PATH
export LIBRARY_PATH=${compatUnix}:/clang64/lib
source $gnuStepMakefiles
cd /c/Users/Support/git/plugins-themes-winuitheme
make install GNUSTEP_INSTALLATION_DOMAIN=USER
"@

& $bash -lc $command

if ($LASTEXITCODE -ne 0) {
  throw "Theme bundle install failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $userThemePath)) {
  throw "Installed user theme bundle was not found at $userThemePath"
}
if (-not (Test-Path $runtimeThemeRoot)) {
  throw "GNUstep runtime themes directory was not found at $runtimeThemeRoot"
}

Remove-Item $runtimeThemePath -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item $userThemePath $runtimeThemeRoot -Recurse -Force
