param(
  [Parameter(Mandatory = $true)]
  [string]$InputPath,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath
)

Add-Type -AssemblyName System.Drawing

$sizes = @(16, 24, 32, 48, 64, 96, 128, 256)
$images = New-Object System.Collections.Generic.List[byte[]]

foreach ($size in $sizes) {
  $icon = $null
  $bitmap = $null
  $stream = $null

  try {
    $icon = New-Object System.Drawing.Icon($InputPath, $size, $size)
    $bitmap = $icon.ToBitmap()
    $stream = New-Object System.IO.MemoryStream
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $images.Add($stream.ToArray())
  }
  finally {
    if ($stream -ne $null) { $stream.Dispose() }
    if ($bitmap -ne $null) { $bitmap.Dispose() }
    if ($icon -ne $null) { $icon.Dispose() }
  }
}

$out = New-Object System.IO.MemoryStream
$writer = New-Object System.IO.BinaryWriter($out)

# ICONDIR
$writer.Write([UInt16]0) # reserved
$writer.Write([UInt16]1) # icon type
$writer.Write([UInt16]$images.Count)

$offset = 6 + (16 * $images.Count)
for ($i = 0; $i -lt $images.Count; $i++) {
  $size = $sizes[$i]
  $png = $images[$i]

  $writer.Write([byte]($(if ($size -eq 256) { 0 } else { $size })))
  $writer.Write([byte]($(if ($size -eq 256) { 0 } else { $size })))
  $writer.Write([byte]0) # color count
  $writer.Write([byte]0) # reserved
  $writer.Write([UInt16]1) # planes
  $writer.Write([UInt16]32) # bit count
  $writer.Write([UInt32]$png.Length)
  $writer.Write([UInt32]$offset)

  $offset += $png.Length
}

foreach ($png in $images) {
  $writer.Write($png)
}

$writer.Flush()
[System.IO.File]::WriteAllBytes($OutputPath, $out.ToArray())

$writer.Dispose()
$out.Dispose()
