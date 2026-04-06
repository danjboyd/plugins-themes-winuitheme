param(
  [string]$Theme,
  [string]$Page,
  [string[]]$Arguments = @(),
  [switch]$PassThru
)

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
$themeDemoDir = Join-Path $repoRoot "Examples\ThemeDemo"
$themeDemoExe = Join-Path $themeDemoDir "ThemeDemo.app\ThemeDemo.exe"
$env:GNUSTEP_USER_ROOT = Resolve-GNUstepUserRoot
Remove-Item Env:GNUSTEP_PATHLIST -ErrorAction SilentlyContinue
$runtimePaths = @(
  "C:\msys64\clang64\bin",
  "C:\msys64\mingw64\bin"
)

if (-not (Test-Path $themeDemoExe)) {
  throw "Missing ThemeDemo executable at $themeDemoExe. Build it first with Scripts/Build-ThemeDemo.ps1."
}

$existingPath = ($env:PATH -split ';') | Where-Object { $_ -and $_.Trim().Length -gt 0 }
$combinedPath = @()

foreach ($path in $runtimePaths + $existingPath) {
  if (-not $combinedPath.Contains($path)) {
    $combinedPath += $path
  }
}

$env:PATH = ($combinedPath -join ';')

$launchArguments = @()

if (-not [string]::IsNullOrWhiteSpace($Theme)) {
  $launchArguments += "-GSTheme"
  $launchArguments += $Theme
}
if (-not [string]::IsNullOrWhiteSpace($Page)) {
  $launchArguments += "--page"
  $launchArguments += $Page
}
if ($Arguments -ne $null -and $Arguments.Count -gt 0) {
  $launchArguments += $Arguments
}

$process = Start-Process -FilePath $themeDemoExe `
                         -WorkingDirectory (Split-Path -Parent $themeDemoExe) `
                         -ArgumentList $launchArguments `
                         -PassThru

if ($PassThru) {
  $process
}
