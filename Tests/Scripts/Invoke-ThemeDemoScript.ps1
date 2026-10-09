param(
  [Parameter(Mandatory = $true)]
  [string]$Script,
  [string]$OutputDirectory,
  [string]$Theme,
  [ValidateSet("light", "dark")]
  [string]$Mode = "light",
  # More ThemeDemo arguments, such as "--contrast-theme", "dusk".
  [string[]]$Arguments = @(),
  [int]$TimeoutSeconds = 60
)

# Runs ThemeDemo with a command script (#17; the commands are in
# Examples/ThemeDemo/README.md), against the theme built in this checkout
# (or -Theme PATH). "{out}" in the script stands for -OutputDirectory, so a
# script can name its captures "{out}\popup.png". Prints ThemeDemo's
# report of each command, and exits with the number of commands that
# failed, or 1 if ThemeDemo didn't quit in time. Build the theme and
# ThemeDemo first:
#   Scripts/Build-ThemeBundle.ps1
#   Scripts/Invoke-GNUstepMake.ps1 -Directory Examples/ThemeDemo

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$demoExe = Join-Path $repoRoot "Examples\ThemeDemo\ThemeDemo.app\ThemeDemo.exe"

if ([string]::IsNullOrWhiteSpace($Theme)) {
  $Theme = Join-Path $repoRoot "WinUITheme.theme"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("themedemo-" + [guid]::NewGuid())
}
if (-not (Test-Path $demoExe)) {
  throw "Missing $demoExe. Build it with Scripts/Invoke-GNUstepMake.ps1 -Directory Examples/ThemeDemo."
}
if (-not (Test-Path $Theme)) {
  throw "Missing theme bundle at $Theme. Build it with Scripts/Build-ThemeBundle.ps1."
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputDirectory = (Resolve-Path $OutputDirectory).Path

$env:PATH = "C:\msys64\clang64\bin;C:\msys64\mingw64\bin;" + $env:PATH
Remove-Item Env:GNUSTEP_PATHLIST -ErrorAction SilentlyContinue
. (Join-Path $PSScriptRoot "GNUstepTestHome.ps1")

$commands = Join-Path $OutputDirectory "commands.txt"
(Get-Content $Script) -replace '\{out\}', $OutputDirectory | Set-Content -Encoding UTF8 $commands
$stdout = Join-Path $OutputDirectory "themedemo.out"
$stderr = Join-Path $OutputDirectory "themedemo.err"
$launchArguments = @("-GSTheme", "`"$Theme`"", "--mode", $Mode) + $Arguments +
  @("--command-script", "`"$commands`"")
# ThemeDemo gets a home directory of its own, as the probe does, so it
# neither reads nor writes the owner's GNUstep defaults.
$testHome = Enter-GNUstepTestHome
try {
  $process = Start-Process -FilePath $demoExe `
                           -WorkingDirectory (Split-Path -Parent $demoExe) `
                           -ArgumentList $launchArguments `
                           -RedirectStandardOutput $stdout `
                           -RedirectStandardError $stderr `
                           -PassThru
  $null = $process.Handle

  $finished = $process.WaitForExit($TimeoutSeconds * 1000)
  if (-not $finished) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    $null = $process.WaitForExit(5000)
  }
} finally {
  Exit-GNUstepTestHome $testHome
}
if (-not $finished) {
  Get-Content $stdout -ErrorAction SilentlyContinue | Write-Output
  Write-Output "FAIL  ThemeDemo didn't quit within $TimeoutSeconds s (end the script with quit)"
  exit 1
}

$lines = @(Get-Content $stdout -ErrorAction SilentlyContinue)
$lines | Write-Output
$failed = @($lines | Where-Object { $_ -match '^ThemeDemo: (failed|unknown command|no |can''t )' }).Count
Write-Output "== $failed failed; output in $OutputDirectory"
exit $failed
