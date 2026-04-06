param(
  [Parameter(Mandatory = $true)]
  [int]$ProcessId,
  [Parameter(Mandatory = $true)]
  [string]$OutPath,
  [int]$TimeoutSeconds = 20
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not ("Codex.WindowCapture.NativeMethods" -as [type])) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Codex.WindowCapture
{
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static class NativeMethods
    {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern int GetWindowTextLength(IntPtr hWnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        public static IntPtr FindWindowForProcess(uint processId)
        {
            IntPtr found = IntPtr.Zero;

            EnumWindows(delegate (IntPtr hWnd, IntPtr lParam)
            {
                uint windowPid;
                RECT rect;

                GetWindowThreadProcessId(hWnd, out windowPid);
                if (windowPid != processId)
                {
                    return true;
                }
                if (!GetWindowRect(hWnd, out rect))
                {
                    return true;
                }
                if ((rect.Right - rect.Left) < 400 || (rect.Bottom - rect.Top) < 240)
                {
                    return true;
                }

                found = hWnd;
                return false;
            }, IntPtr.Zero);

            return found;
        }
    }
}
"@
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$windowHandle = [System.IntPtr]::Zero

while ((Get-Date) -lt $deadline) {
  $windowHandle = [Codex.WindowCapture.NativeMethods]::FindWindowForProcess([uint32]$ProcessId)
  if ($windowHandle -ne [System.IntPtr]::Zero) {
    break
  }
  Start-Sleep -Milliseconds 250
}

if ($windowHandle -eq [System.IntPtr]::Zero) {
  $shell = New-Object -ComObject WScript.Shell
  [void]$shell.AppActivate($ProcessId)
  Start-Sleep -Milliseconds 500

  $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $outDirectory = Split-Path -Parent $OutPath
  if (-not (Test-Path $outDirectory)) {
    New-Item -ItemType Directory -Force -Path $outDirectory | Out-Null
  }

  $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

  try {
    $graphics.CopyFromScreen($bounds.Left, $bounds.Top, 0, 0, $bitmap.Size)
    $bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
  return
}

[void][Codex.WindowCapture.NativeMethods]::ShowWindow($windowHandle, 9)
[void][Codex.WindowCapture.NativeMethods]::SetForegroundWindow($windowHandle)
Start-Sleep -Milliseconds 400

$rect = New-Object Codex.WindowCapture.RECT
if (-not [Codex.WindowCapture.NativeMethods]::GetWindowRect($windowHandle, [ref]$rect)) {
  throw "Unable to read window bounds for process $ProcessId."
}

$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -le 0 -or $height -le 0) {
  throw "Window bounds for process $ProcessId were empty."
}

$outDirectory = Split-Path -Parent $OutPath
if (-not (Test-Path $outDirectory)) {
  New-Item -ItemType Directory -Force -Path $outDirectory | Out-Null
}

$bitmap = New-Object System.Drawing.Bitmap $width, $height
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)

try {
  $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
  $bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
  $graphics.Dispose()
  $bitmap.Dispose()
}
