param(
  [string[]]$Pages = @("controls", "text-input", "commands", "data-views", "dialogs", "stress", "real-app"),
  [switch]$CaptureReferenceApp = $true,
  [switch]$SkipBuild,
  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$scriptsDir = Join-Path $repoRoot "Scripts"
$captureScript = Join-Path $PSScriptRoot "Capture-Window.ps1"

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $repoRoot "Tests\Screenshots"
}

$variants = @(
  @{ Id = "light-100"; Arguments = @("--mode", "light", "--scale", "100") },
  @{ Id = "dark-100"; Arguments = @("--mode", "dark", "--scale", "100") },
  @{ Id = "high-contrast-100"; Arguments = @("--mode", "light", "--high-contrast", "yes", "--scale", "100") },
  @{ Id = "reduced-transparency-100"; Arguments = @("--mode", "light", "--reduced-transparency", "yes", "--scale", "100") },
  @{ Id = "light-125"; Arguments = @("--mode", "light", "--scale", "125") },
  @{ Id = "light-150"; Arguments = @("--mode", "light", "--scale", "150") },
  @{ Id = "light-200"; Arguments = @("--mode", "light", "--scale", "200") }
)

if (-not $SkipBuild) {
  & (Join-Path $scriptsDir "Build-ThemeBundle.ps1")
  & (Join-Path $scriptsDir "Install-ThemeBundle.ps1")
  & (Join-Path $scriptsDir "Build-ThemeDemo.ps1")
  if ($CaptureReferenceApp) {
    & (Join-Path $scriptsDir "Build-WinUIReferenceApp.ps1")
  }
}

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToString("s")
  themeDemo = @()
  reference = @()
}

foreach ($variant in $variants) {
  foreach ($page in $Pages) {
    $variantDir = Join-Path $OutputRoot ("ThemeDemo\" + $variant.Id)
    $capturePath = Join-Path $variantDir ($page + ".png")
    $process = & (Join-Path $scriptsDir "Run-ThemeDemo.ps1") `
      -Theme "WinUITheme" `
      -Page $page `
      -Arguments $variant.Arguments `
      -PassThru

    try {
      Start-Sleep -Seconds 4
      & $captureScript -ProcessId $process.Id -OutPath $capturePath
      $manifest.themeDemo += [ordered]@{
        variant = $variant.Id
        page = $page
        path = $capturePath
      }
    } finally {
      if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
      }
    }
  }
}

if ($CaptureReferenceApp) {
  foreach ($page in $Pages) {
    $capturePath = Join-Path $OutputRoot ("Reference\default\" + $page + ".png")
    $process = & (Join-Path $scriptsDir "Run-WinUIReferenceApp.ps1") `
      -Page $page `
      -PassThru

    try {
      & $captureScript -ProcessId $process.Id -OutPath $capturePath
      $manifest.reference += [ordered]@{
        variant = "default"
        page = $page
        path = $capturePath
      }
    } finally {
      if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
      }
    }
  }
}

$manifestPath = Join-Path $OutputRoot "acceptance-manifest.json"
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 $manifestPath
Write-Host "Acceptance captures written to $OutputRoot"
