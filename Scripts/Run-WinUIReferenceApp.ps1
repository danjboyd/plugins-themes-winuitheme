param(
  [string]$Page,
  [switch]$PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$appExe = Join-Path $repoRoot "Reference\WinUI3ReferenceApp\bin\Debug\net8.0-windows10.0.19041.0\win-x64\WinUI3ReferenceApp.exe"

if (-not (Test-Path $appExe)) {
  throw "Missing WinUI 3 reference app executable at $appExe. Build it first with Scripts/Build-WinUIReferenceApp.ps1."
}

$launchArguments = @()
if (-not [string]::IsNullOrWhiteSpace($Page)) {
  $launchArguments += "--page"
  $launchArguments += $Page
}

$process = Start-Process -FilePath $appExe `
                         -WorkingDirectory (Split-Path -Parent $appExe) `
                         -ArgumentList $launchArguments `
                         -PassThru

if ($PassThru) {
  $process
}
