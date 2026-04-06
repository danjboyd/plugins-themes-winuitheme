param(
  [string]$DocumentPath = "C:\Users\Support\git\ObjcMarkdown\TableRenderDemo.md",
  [string]$Theme = "WinUITheme",
  [switch]$Build,
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
$objcMarkdownRoot = Join-Path (Split-Path -Parent $repoRoot) "ObjcMarkdown"
$appExe = Join-Path $objcMarkdownRoot "ObjcMarkdownViewer\MarkdownViewer.app\MarkdownViewer.exe"
$buildScript = Join-Path $objcMarkdownRoot "scripts\windows\build-from-powershell.ps1"

if ($Build) {
  & $buildScript -Task build
  if ($LASTEXITCODE -ne 0) {
    throw "ObjcMarkdown build failed with exit code $LASTEXITCODE"
  }
}

if (-not (Test-Path $appExe)) {
  throw "Missing ObjcMarkdown viewer executable at $appExe. Build ObjcMarkdown first."
}

$env:GNUSTEP_USER_ROOT = Resolve-GNUstepUserRoot
Remove-Item Env:GNUSTEP_PATHLIST -ErrorAction SilentlyContinue
$runtimePaths = @(
  "C:\msys64\clang64\bin",
  "C:\msys64\mingw64\bin",
  (Join-Path $objcMarkdownRoot "ObjcMarkdown\obj"),
  (Join-Path $objcMarkdownRoot "third_party\libs-OpenSave\Source\obj"),
  (Join-Path $objcMarkdownRoot "third_party\TextViewVimKitBuild\obj")
)
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
if (-not [string]::IsNullOrWhiteSpace($DocumentPath)) {
  $launchArguments += $DocumentPath
}

$process = Start-Process -FilePath $appExe `
                         -WorkingDirectory (Split-Path -Parent $appExe) `
                         -ArgumentList $launchArguments `
                         -PassThru

if ($PassThru) {
  $process
}
