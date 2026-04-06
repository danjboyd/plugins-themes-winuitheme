param(
  [switch]$Build,
  [switch]$RunTests,
  [string]$DocumentPath = "C:\Users\Support\git\ObjcMarkdown\TableRenderDemo.md",
  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$objcMarkdownRoot = Join-Path (Split-Path -Parent $repoRoot) "ObjcMarkdown"
$captureScript = Join-Path $PSScriptRoot "Capture-Window.ps1"
$buildScript = Join-Path $objcMarkdownRoot "scripts\windows\build-from-powershell.ps1"

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $repoRoot "Tests\Screenshots\ObjcMarkdown"
}

if ($Build) {
  & $buildScript -Task build
  if ($LASTEXITCODE -ne 0) {
    throw "ObjcMarkdown build failed with exit code $LASTEXITCODE"
  }
}

if ($RunTests) {
  & $buildScript -Task test
  if ($LASTEXITCODE -ne 0) {
    throw "ObjcMarkdown tests failed with exit code $LASTEXITCODE"
  }
}

$process = & (Join-Path $repoRoot "Scripts\Run-ObjcMarkdownValidation.ps1") `
  -DocumentPath $DocumentPath `
  -PassThru

$capturePath = Join-Path $OutputRoot "objcmarkdown-main-window.png"
$metadataPath = Join-Path $OutputRoot "objcmarkdown-validation.json"

try {
  & $captureScript -ProcessId $process.Id -OutPath $capturePath -TimeoutSeconds 30
  [ordered]@{
    generatedAt = (Get-Date).ToString("s")
    documentPath = $DocumentPath
    screenshotPath = $capturePath
    theme = "WinUITheme"
    processId = $process.Id
  } | ConvertTo-Json -Depth 3 | Set-Content -Encoding UTF8 $metadataPath
} finally {
  if ($process -and -not $process.HasExited) {
    Stop-Process -Id $process.Id -Force
  }
}

Write-Host "ObjcMarkdown validation capture written to $capturePath"
