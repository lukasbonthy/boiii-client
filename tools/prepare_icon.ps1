$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$base64Path = Join-Path $root 'src\client\resources\icon.ico.b64'
$rawPath = Join-Path $root 'src\client\resources\icon.ico.raw'
$icoPath = Join-Path $root 'src\client\resources\icon.ico'
$converter = Join-Path $root 'tools\make_png_ico.ps1'

if (Test-Path $base64Path) {
  Write-Host "Restoring icon raw bytes from icon.ico.b64"
  $b64 = Get-Content $base64Path -Raw
  [IO.File]::WriteAllBytes($rawPath, [Convert]::FromBase64String($b64))
} else {
  Write-Host "icon.ico.b64 not found; skipping raw icon restore"
}

if ((Test-Path $converter) -and (Test-Path $rawPath)) {
  Write-Host "Converting raw icon data to icon.ico"
  & $converter -InputPath $rawPath -OutputPath $icoPath
} else {
  Write-Host "Icon converter or raw icon data not found; skipping icon conversion"
}
