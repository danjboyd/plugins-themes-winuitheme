$ErrorActionPreference = "Stop"

$dotnet = "C:\Program Files\dotnet\dotnet.exe"
$project = Join-Path (Split-Path -Parent $PSScriptRoot) "Reference\WinUI3ReferenceApp\WinUI3ReferenceApp.csproj"

if (-not (Test-Path $dotnet)) {
  throw "Missing dotnet at $dotnet"
}

& $dotnet build $project -c Debug

if ($LASTEXITCODE -ne 0) {
  throw "WinUI 3 reference app build failed with exit code $LASTEXITCODE"
}
