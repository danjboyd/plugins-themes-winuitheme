$ErrorActionPreference = "Stop"

$project = Join-Path $PSScriptRoot "WinUI3ReferenceApp.csproj"

Write-Host "Building WinUI 3 reference app from $project"
dotnet build $project -c Debug

