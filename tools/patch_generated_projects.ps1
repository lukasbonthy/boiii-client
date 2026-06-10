$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$buildPath = Join-Path $root 'build'

if (-not (Test-Path $buildPath)) {
  throw "Build folder not found. Run Premake before patching generated projects."
}

$projects = Get-ChildItem -Path $buildPath -Recurse -Filter '*.vcxproj'
if (-not $projects) {
  throw "No .vcxproj files found under $buildPath"
}

foreach ($project in $projects) {
  Write-Host "Patching $($project.FullName)"
  $content = Get-Content $project.FullName -Raw
  $content = $content -replace '<TargetName>boiii</TargetName>', '<TargetName>swiflyboiii</TargetName>'
  Set-Content -Path $project.FullName -Value $content -NoNewline
}
