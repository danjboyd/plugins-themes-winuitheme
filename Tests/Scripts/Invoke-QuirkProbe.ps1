param(
  [string]$Theme,
  # A libs-back bundle to run on instead of the installed one, such as
  # danjboyd/libs-back's carry build (GNUstepTestHome.ps1).
  [string]$Backend,
  [string]$OutputDirectory,
  [string[]]$Configuration = @("light", "dark", "high-contrast", "light-150", "large-text", "compact", "dusk", "desert"),
  [int]$TimeoutSeconds = 60,
  # Checks that move the real pointer (button-hover, table-row-hover,
  # scroller-hover-expands, popup-click-stays-open) skip unless -Pointer is
  # given: they take over the desktop's pointer, and fail when other
  # windows are in the way. Run them with the desktop clear.
  [switch]$Pointer,
  # The default now; kept so older command lines still work.
  [switch]$NoPointer
)

# Runs Examples/QuirkProbe against the theme built in this checkout (or
# -Theme PATH) once per configuration, and exits with the number of failed
# checks. Each run gets a home directory of its own (GNUstepTestHome.ps1),
# so the probe neither reads nor writes the owner's GNUstep defaults.
# Build the theme and the probe first:
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
. (Join-Path $PSScriptRoot "GNUstepTestHome.ps1")

$configurationArguments = @{
  "light"         = @("--mode", "light")
  "dark"          = @("--mode", "dark")
  "high-contrast" = @("--mode", "light", "--high-contrast", "yes")
  "light-150"     = @("--mode", "light", "--scale", "1.5")
  # Dark at 150% (#209): card fills and washes at a scaled desktop. Not in
  # the default list; run it with -Configuration dark-150.
  "dark-150"      = @("--mode", "dark", "--scale", "1.5")
  # Windows' Text size at 150% (Accessibility).
  "large-text"    = @("--mode", "light", "-WinUIThemeTextScaleFactor", "150")
  # Compact metrics (#31), as apps with a main nib or Gorm file get them.
  "compact"       = @("--mode", "light", "-WinUIThemeMetrics", "compact")
  # The gui drawing at 1.5, as on a 150% monitor with the DPI-aware carried
  # backend (GSScaleFactor). The theme's metrics stay at 1.0 there, as a
  # DPI-aware process's (WinUIThemeSystemDpi). Not in the default list:
  # run it with -Configuration scaled-150, on the stock backend. With the
  # carried one the forced factor contradicts its per-monitor DPI on a
  # 100% monitor (dpi-per-monitor-aware and the caption hit tests fail);
  # there, set the monitor itself to 150% instead.
  "scaled-150"    = @("--mode", "light", "-GSScaleFactor", "1.5")
  # The same at 1.25, on the stock backend too: its corners and strokes land
  # between pixels where 1.5 often lands on them. CI runs it.
  "scaled-125"    = @("--mode", "light", "-GSScaleFactor", "1.25")
  "dusk"          = @("--mode", "light", "--high-contrast", "yes", "--contrast-theme", "dusk")
  "desert"        = @("--mode", "light", "--high-contrast", "yes", "--contrast-theme", "desert")
}

$totalFailed = 0
$logDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("quirkprobe-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

foreach ($name in $Configuration) {
  if (-not $configurationArguments.ContainsKey($name)) {
    throw "Unknown configuration '$name'. Known: $($configurationArguments.Keys -join ', ')"
  }

  # Window tabs are off by default (#72); the probe checks them on.
  $arguments = @("-GSTheme", "`"$Theme`"", "-WinUIThemeWindowTabs", "YES") + $configurationArguments[$name]
  if ($Pointer -and -not $NoPointer) {
    $arguments += @("-ProbeMovesPointer", "YES")
  }
  if (-not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $arguments += @("-ProbeOutput", "`"$(Join-Path $OutputDirectory $name)`"")
  }

  $stdout = Join-Path $logDirectory "$name.out"
  $stderr = Join-Path $logDirectory "$name.err"
  # A fresh home for each configuration, so one can't leave defaults that
  # change the next.
  $testHome = Enter-GNUstepTestHome -Backend $Backend
  # The pasteboard daemon (gpbs) a probe starts with --auto outlives it by
  # about 8 s, then exits. The next configuration started inside that
  # window found the dying gpbs, and its first pasteboard request (an
  # editable combo box taking focus) failed with "port was invalidated":
  # desert, after the quick dusk, every time. So each configuration waits
  # for the gpbs its predecessor started to exit. Nothing is stopped: gpbs
  # is the desktop's pasteboard server, and ones already running are left
  # alone.
  $gpbsBefore = @(Get-Process -Name gpbs -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
  try {
    $process = Start-Process -FilePath $probeExe `
                             -WorkingDirectory (Split-Path -Parent $probeExe) `
                             -ArgumentList $arguments `
                             -RedirectStandardOutput $stdout `
                             -RedirectStandardError $stderr `
                             -PassThru
    # Without a cached handle, ExitCode is empty once the process has exited.
    $null = $process.Handle

    Write-Output "== $name"
    $finished = $process.WaitForExit($TimeoutSeconds * 1000)
    $hangLog = $null
    if (-not $finished) {
      # Where it hung: every thread's backtrace, from MSYS2's lldb when
      # there is one, before the probe is killed. lldb's batch mode treats
      # the attach break as a crash, so the commands go in -k.
      $lldb = "C:\msys64\clang64\bin\lldb.exe"
      if (Test-Path $lldb) {
        $hangLog = Join-Path $logDirectory "$name.hang.txt"
        $debugger = Start-Process -FilePath $lldb -PassThru -WindowStyle Hidden `
                                  -ArgumentList @("--batch", "-p", $process.Id, "-k", "`"thread backtrace all`"",
                                                  "-k", "`"process detach`"", "-k", "quit") `
                                  -RedirectStandardOutput $hangLog `
                                  -RedirectStandardError (Join-Path $logDirectory "$name.hang.err")
        if (-not $debugger.WaitForExit(90000)) {
          Stop-Process -Id $debugger.Id -Force -ErrorAction SilentlyContinue
        }
      }
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      $null = $process.WaitForExit(5000)
    }
  } finally {
    Exit-GNUstepTestHome $testHome
  }
  $started = @(Get-Process -Name gpbs -ErrorAction SilentlyContinue | Where-Object { $gpbsBefore -notcontains $_.Id })
  foreach ($daemon in $started) {
    if (-not $daemon.WaitForExit(20000)) {
      Write-Output "NOTE  gpbs $($daemon.Id), started by this run, still running after 20 s; the next configuration may meet it"
    }
  }
  if (-not $finished) {
    Write-Output "FAIL  probe: timed out after $TimeoutSeconds s"
    # What it had got through, and anything it said, to show where it hung.
    Get-Content $stdout -Tail 20 -ErrorAction SilentlyContinue | ForEach-Object { "  out: $_" }
    Get-Content $stderr -Tail 40 -ErrorAction SilentlyContinue | ForEach-Object { "  err: $_" }
    if ($hangLog -and (Test-Path $hangLog)) {
      # The main thread's innermost frames; the whole dump is in the file.
      $main = @(Get-Content $hangLog | Select-String -Pattern '^\*? *thread #1\b' -Context 0, 12)
      if ($main.Count -gt 0) {
        "  hang: thread #1 (all threads in $hangLog)"
        $main[0].Context.PostContext | Where-Object { $_ -match 'frame #' } | ForEach-Object { "  hang: $($_.Trim())" }
      } else {
        "  hang: no backtrace in $hangLog"
      }
    }
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
