param(
  [string]$OutputDirectory,
  [string]$Theme,
  [string[]]$Mode = @("light", "dark"),
  [int]$TimeoutSeconds = 60
)

# Measures the theme against WinUI 3 itself (#105). The reference app
# (Reference/WinUI3ReferenceApp) and ThemeDemo both have a "specimens" page:
# one of each control at the same place on a canvas marked by a magenta
# square. This captures each in each mode, measures the controls' sizes,
# fills, strokes and the type ramp's text widths (Tests/Scripts/measure_specimens.py),
# and compares them. The exit code is the number of measurements out of
# tolerance; the report and the captures are in -OutputDirectory.
#
# Build first:
#   Reference/WinUI3ReferenceApp/build.ps1
#   Scripts/Invoke-GNUstepMake.ps1 -Directory .                 (the theme)
#   Scripts/Invoke-GNUstepMake.ps1 -Directory Examples/ThemeDemo

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$referenceExe = Join-Path $repoRoot "Reference\WinUI3ReferenceApp\bin\Debug\net8.0-windows10.0.22621.0\win-x64\WinUI3ReferenceApp.exe"
$measure = Join-Path $PSScriptRoot "measure_specimens.py"
# The Python with Pillow, found before ThemeDemo's runner puts MSYS2 first on PATH.
$python = (Get-Command python -ErrorAction Stop).Source

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("winui-reference-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputDirectory = (Resolve-Path $OutputDirectory).Path
if (-not (Test-Path $referenceExe)) {
  throw "Missing $referenceExe. Build it with Reference/WinUI3ReferenceApp/build.ps1."
}

Add-Type -AssemblyName System.Drawing
if (-not ("WinUIThemeReference.Capture" -as [type])) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace WinUIThemeReference
{
    public static class Capture
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct RECT { public int Left, Top, Right, Bottom; }

        delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc proc, IntPtr lParam);
        [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
        [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
        [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);

        public static IntPtr FindWindow(uint processId)
        {
            IntPtr found = IntPtr.Zero;
            EnumWindows(delegate (IntPtr hWnd, IntPtr lParam)
            {
                uint pid;
                RECT rect;
                GetWindowThreadProcessId(hWnd, out pid);
                if (pid != processId || !IsWindowVisible(hWnd) || !GetWindowRect(hWnd, out rect))
                    return true;
                if (rect.Right - rect.Left < 400 || rect.Bottom - rect.Top < 240)
                    return true;
                found = hWnd;
                return false;
            }, IntPtr.Zero);
            return found;
        }
    }
}
"@
}

# PW_RENDERFULLCONTENT: WinUI draws through DirectComposition.
function Save-WindowImage([IntPtr]$Handle, [string]$Path) {
  $rect = New-Object WinUIThemeReference.Capture+RECT
  if (-not [WinUIThemeReference.Capture]::GetWindowRect($Handle, [ref]$rect)) {
    return $false
  }
  $bitmap = New-Object System.Drawing.Bitmap ($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $hdc = $graphics.GetHdc()
  $ok = [WinUIThemeReference.Capture]::PrintWindow($Handle, $hdc, 2)
  $graphics.ReleaseHdc($hdc)
  $graphics.Dispose()
  if ($ok) {
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  }
  $bitmap.Dispose()
  return $ok
}

function Save-ReferenceCapture([string]$CaptureMode, [string]$Path) {
  $process = Start-Process -FilePath $referenceExe -ArgumentList @("--page", "specimens", "--mode", $CaptureMode) -PassThru
  try {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $handle = [IntPtr]::Zero
    while ((Get-Date) -lt $deadline -and $handle -eq [IntPtr]::Zero) {
      Start-Sleep -Milliseconds 250
      $handle = [WinUIThemeReference.Capture]::FindWindow([uint32]$process.Id)
    }
    if ($handle -eq [IntPtr]::Zero) {
      throw "The reference app showed no window"
    }
    # Let it lay out and finish its entrance.
    Start-Sleep -Seconds 2
    if (-not (Save-WindowImage $handle $Path)) {
      throw "PrintWindow failed for the reference app"
    }
  } finally {
    if (-not $process.HasExited) {
      Stop-Process -Id $process.Id -Force
    }
  }
}

function Save-ThemeDemoCapture([string]$CaptureMode, [string]$Path) {
  $script = Join-Path $OutputDirectory "themedemo-$CaptureMode.txt"
  $demoOut = Join-Path $OutputDirectory "themedemo-$CaptureMode"
  @(
    "wait 1.5",
    "screenshot $Path",
    "quit"
  ) | Set-Content -Path $script
  $arguments = @{
    Script = $script
    OutputDirectory = $demoOut
    Mode = $CaptureMode
    Arguments = @("--page", "specimens")
    TimeoutSeconds = $TimeoutSeconds
  }
  if (-not [string]::IsNullOrWhiteSpace($Theme)) {
    $arguments.Theme = $Theme
  }
  & (Join-Path $PSScriptRoot "Invoke-ThemeDemoScript.ps1") @arguments | Out-Null
  if (-not (Test-Path $Path)) {
    throw "ThemeDemo didn't capture its specimens page (see $demoOut)"
  }
}

$failures = 0
foreach ($captureMode in $Mode) {
  $referencePng = Join-Path $OutputDirectory "reference-$captureMode.png"
  $themePng = Join-Path $OutputDirectory "theme-$captureMode.png"

  Save-ReferenceCapture $captureMode $referencePng
  Save-ThemeDemoCapture $captureMode $themePng

  & $python -I $measure --mode $captureMode --reference $referencePng --theme $themePng `
    --report (Join-Path $OutputDirectory "report-$captureMode.md") `
    --sheet (Join-Path $OutputDirectory "sheet-$captureMode.png")
  $failures += $LASTEXITCODE
}

Write-Host "== $failures measurement(s) out of tolerance; output in $OutputDirectory"
exit $failures
