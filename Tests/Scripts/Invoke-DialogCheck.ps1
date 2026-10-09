param(
  [string]$Theme,
  [int]$TimeoutSeconds = 180
)

# Runs the native dialog checks (#20, #69): QuirkProbe -ProbeOnly dialogs
# shows Windows' print, page setup, open and save dialogs for real and
# checks what comes back. The probe's own thread fills in the classic
# dialogs; Windows 11's print dialog runs in a process of its own, so this
# script drives it by UI Automation: it reports what the first one was
# seeded with (print-dialog-seeded), picks pages 2-4 in landscape and
# prints to Microsoft Print to PDF's dialog (which writes nothing until a
# job is sent; the probe sends none), and cancels the second.
#
# The dialogs take the keyboard focus for a minute; the pointer isn't
# moved. Exits with the number of failures. Build the theme and the probe
# first (see Invoke-QuirkProbe.ps1).

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$probeExe = Join-Path $repoRoot "Examples\QuirkProbe\QuirkProbe.app\QuirkProbe.exe"
if ([string]::IsNullOrWhiteSpace($Theme)) {
  $Theme = Join-Path $repoRoot "WinUITheme.theme"
}
if (-not (Test-Path $probeExe)) {
  throw "Missing $probeExe. Build it with Scripts/Invoke-GNUstepMake.ps1 -Directory Examples/QuirkProbe."
}

$env:PATH = "C:\msys64\clang64\bin;C:\msys64\mingw64\bin;" + $env:PATH
Remove-Item Env:GNUSTEP_PATHLIST -ErrorAction SilentlyContinue
. (Join-Path $PSScriptRoot "GNUstepTestHome.ps1")
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$automation = [System.Windows.Automation.AutomationElement]
$scope = [System.Windows.Automation.TreeScope]

function Find-PrintDialog {
  $windows = $automation::RootElement.FindAll($scope::Children, [System.Windows.Automation.Condition]::TrueCondition)
  foreach ($window in $windows) {
    if ($window.Current.ClassName -eq "ApplicationFrameWindow" -and $window.Current.Name -like "*Win32*Print") {
      # Ready once its Print button is there.
      if ((Find-Element $window "PrintButton") -ne $null) {
        return $window
      }
    }
  }
  return $null
}

function Find-Element($root, [string]$id) {
  $condition = New-Object System.Windows.Automation.PropertyCondition($automation::AutomationIdProperty, $id)
  return $root.FindFirst($scope::Descendants, $condition)
}

function Wait-PrintDialog([int]$seconds) {
  $deadline = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $deadline) {
    $dialog = Find-PrintDialog
    if ($dialog -ne $null) {
      Start-Sleep -Milliseconds 800
      return $dialog
    }
    Start-Sleep -Milliseconds 250
  }
  return $null
}

function Wait-PrintDialogClosed([int]$seconds) {
  $deadline = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $deadline -and (Find-PrintDialog) -ne $null) {
    Start-Sleep -Milliseconds 250
  }
}

function Select-ComboItem($dialog, [string]$comboId, [string]$itemName) {
  $combo = Find-Element $dialog $comboId
  $expand = $combo.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
  $expand.Expand()
  Start-Sleep -Milliseconds 500
  # The items' names can end with a space ("Portrait ").
  $condition = New-Object System.Windows.Automation.PropertyCondition($automation::ControlTypeProperty,
                                                                     [System.Windows.Automation.ControlType]::ListItem)
  $item = $combo.FindAll($scope::Descendants, $condition) |
    Where-Object { $_.Current.Name.Trim() -eq $itemName } | Select-Object -First 1
  if ($item -ne $null) {
    $item.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
  }
  Start-Sleep -Milliseconds 300
  try { $expand.Collapse() } catch { }
  Start-Sleep -Milliseconds 500
  return ($item -ne $null)
}

# A collapsed combo box holds only its selected item.
function Get-ComboSelection($dialog, [string]$comboId) {
  $combo = Find-Element $dialog $comboId
  $condition = New-Object System.Windows.Automation.PropertyCondition($automation::ControlTypeProperty,
                                                                     [System.Windows.Automation.ControlType]::ListItem)
  $item = if ($combo -ne $null) { $combo.FindFirst($scope::Descendants, $condition) } else { $null }
  if ($item -ne $null) {
    return $item.Current.Name.Trim()
  }
  return ""
}

$testHome = Enter-GNUstepTestHome
$stdout = Join-Path $testHome.Path "probe.out"
$stderr = Join-Path $testHome.Path "probe.err"
$driverLines = @()
try {
  $process = Start-Process -FilePath $probeExe `
                           -WorkingDirectory (Split-Path -Parent $probeExe) `
                           -ArgumentList @("-GSTheme", "`"$Theme`"", "--mode", "light",
                                           "-ProbeOnly", "dialogs", "-ProbeDrivesPrintDialog", "YES") `
                           -RedirectStandardOutput $stdout `
                           -RedirectStandardError $stderr `
                           -PassThru
  $null = $process.Handle

  # The first dialog: seeded with Print to PDF, pages 3-5, portrait.
  $dialog = Wait-PrintDialog 60
  if ($dialog -eq $null) {
    $driverLines += "FAIL  print-dialog-seeded: no Windows print dialog opened"
  } else {
    $printer = Get-ComboSelection $dialog "printerSelector"
    $pages = Get-ComboSelection $dialog "com.microsoft.JobCustomPageRange_ItemList"
    $rangeEdit = Find-Element $dialog "com.microsoft.JobCustomPageRange_ValueText"
    $range = if ($rangeEdit -ne $null) { $rangeEdit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value } else { "" }
    $orientation = Get-ComboSelection $dialog "PageOrientation_ItemList"
    if ($printer -eq "Microsoft Print to PDF" -and $range -eq "3-5" -and $orientation -eq "Portrait") {
      $driverLines += "PASS  print-dialog-seeded: the dialog opens on $printer, $pages $range, $orientation"
    } else {
      $driverLines += "FAIL  print-dialog-seeded: the dialog showed '$printer', '$pages' '$range', '$orientation' (expected Microsoft Print to PDF, 3-5, Portrait)"
    }

    $null = Select-ComboItem $dialog "PageOrientation_ItemList" "Landscape"
    # The dialog takes the range when the field loses focus; retry until it
    # reads back.
    for ($try = 0; $try -lt 3; $try++) {
      $rangeEdit = Find-Element $dialog "com.microsoft.JobCustomPageRange_ValueText"
      if ($rangeEdit -eq $null) { break }
      $rangeEdit.SetFocus()
      $value = $rangeEdit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
      $value.SetValue("2-4")
      Start-Sleep -Milliseconds 800
      if ($value.Current.Value -eq "2-4") { break }
    }
    $printButton = Find-Element $dialog "PrintButton"
    $printButton.SetFocus()
    Start-Sleep -Milliseconds 800
    $printButton.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    Wait-PrintDialogClosed 20

    # The second: cancelled.
    $dialog = Wait-PrintDialog 30
    if ($dialog -ne $null) {
      (Find-Element $dialog "CloseButton").GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
      Wait-PrintDialogClosed 20
    }
  }

  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    $null = $process.WaitForExit(5000)
    $driverLines += "FAIL  probe: timed out after $TimeoutSeconds s"
  }
  $lines = @(Get-Content $stdout -ErrorAction SilentlyContinue) + $driverLines
} catch {
  $lines = @(Get-Content $stdout -ErrorAction SilentlyContinue) + $driverLines + @("FAIL  driver: $_")
} finally {
  if ($process -ne $null -and -not $process.HasExited) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    $null = $process.WaitForExit(5000)
  }
  Exit-GNUstepTestHome $testHome
}

$lines | Write-Output
$failed = @($lines | Where-Object { $_ -match '^FAIL' }).Count
if (-not ($lines -match '^SUMMARY')) {
  Write-Output "FAIL  probe: exited before finishing"
  $failed += 1
}
Write-Output "== total failures: $failed"
exit $failed
