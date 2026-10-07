param(
  [string]$Theme,
  [string]$OutputDirectory,
  [string[]]$Configuration = @("light", "dark", "high-contrast", "light-150"),
  [int]$TimeoutSeconds = 60
)

# Runs Examples/QuirkProbe against the theme built in this checkout (or
# -Theme PATH) once per configuration, and exits with the number of failed
# checks. Build the theme and the probe first:
#   Scripts/Build-ThemeBundle.ps1
#   Scripts/Invoke-GNUstepMake.ps1 -Directory Examples/QuirkProbe

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$probeExe = Join-Path $repoRoot "Examples\QuirkProbe\QuirkProbe.app\QuirkProbe.exe"

if ([string]::IsNullOrWhiteSpace($Theme)) {
  $Theme = Join-Path $repoRoot "WinUITheme.theme"
}
if (-not (Test-Path $probeExe)) {
  throw "Missing $probeExe. Build it with Scripts/Invoke-GNUstepMake.ps1 -Directory Examples/QuirkProbe."
}
if (-not (Test-Path $Theme)) {
  throw "Missing theme bundle at $Theme. Build it with Scripts/Build-ThemeBundle.ps1."
}

$env:PATH = "C:\msys64\clang64\bin;C:\msys64\mingw64\bin;" + $env:PATH
Remove-Item Env:GNUSTEP_PATHLIST -ErrorAction SilentlyContinue

$configurationArguments = @{
  "light"         = @("--mode", "light")
  "dark"          = @("--mode", "dark")
  "high-contrast" = @("--mode", "light", "--high-contrast", "yes")
  "light-150"     = @("--mode", "light", "--scale", "1.5")
}

$totalFailed = 0
$logDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("quirkprobe-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

foreach ($name in $Configuration) {
  if (-not $configurationArguments.ContainsKey($name)) {
    throw "Unknown configuration '$name'. Known: $($configurationArguments.Keys -join ', ')"
  }

  $arguments = @("-GSTheme", "`"$Theme`"") + $configurationArguments[$name]
  if (-not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $arguments += @("-ProbeOutput", "`"$(Join-Path $OutputDirectory $name)`"")
  }

  $stdout = Join-Path $logDirectory "$name.out"
  $stderr = Join-Path $logDirectory "$name.err"
  $process = Start-Process -FilePath $probeExe `
                           -WorkingDirectory (Split-Path -Parent $probeExe) `
                           -ArgumentList $arguments `
                           -RedirectStandardOutput $stdout `
                           -RedirectStandardError $stderr `
                           -PassThru
  # Without a cached handle, ExitCode is empty once the process has exited.
  $null = $process.Handle

  Write-Output "== $name"
  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    Write-Output "FAIL  probe: timed out after $TimeoutSeconds s"
    $totalFailed += 1
    continue
  }

  $lines = @(Get-Content $stdout -ErrorAction SilentlyContinue)
  $lines | Write-Output
  $failed = @($lines | Where-Object { $_ -match '^FAIL' }).Count
  if ($process.ExitCode -lt 0 -or ($failed -eq 0 -and -not ($lines -match '^SUMMARY'))) {
    Write-Output "FAIL  probe: exited with $($process.ExitCode) before finishing (stderr: $stderr)"
    $failed += 1
  }
  $totalFailed += $failed
}

Write-Output "== total failures: $totalFailed"
exit $totalFailed
