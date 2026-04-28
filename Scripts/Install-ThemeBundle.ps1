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
$gnuStepUserRoot = Resolve-GNUstepUserRoot
$userThemePath = Join-Path $gnuStepUserRoot "Library\Themes\WinUITheme.theme"
$runtimeThemeRoot = "C:\msys64\clang64\lib\GNUstep\Themes"
$runtimeThemePath = Join-Path $runtimeThemeRoot "WinUITheme.theme"
$builtThemePath = Join-Path $repoRoot "WinUITheme.theme"

if (-not (Test-Path $builtThemePath)) {
  throw "Missing built theme bundle at $builtThemePath. Build it first with Scripts/Build-ThemeBundle.ps1."
}

$userThemeRoot = Split-Path -Parent $userThemePath
New-Item -ItemType Directory -Force -Path $userThemeRoot | Out-Null
Remove-Item $userThemePath -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item $builtThemePath $userThemeRoot -Recurse -Force

if (Test-Path $runtimeThemeRoot) {
  Remove-Item $runtimeThemePath -Recurse -Force -ErrorAction SilentlyContinue
  Copy-Item $builtThemePath $runtimeThemeRoot -Recurse -Force
}
