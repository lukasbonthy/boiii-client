$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom($Path, $Content) {
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
}

function Apply-SwiflyBranding($Content) {
  $c = $Content

  # Known upstream links/domains first so generic EZZ replacements do not produce bad URLs.
  $c = $c.Replace('https://r2.ezz.lol/', 'https://swifly-servers.onrender.com/disabled-upstream/')
  $c = $c.Replace('https://cdn.ezz.lol/', 'https://swifly-servers.onrender.com/disabled-cdn/')
  $c = $c.Replace('https://ezz.lol', 'https://swifly.gg')
  $c = $c.Replace('http://ezz.lol', 'https://swifly.gg')
  $c = $c.Replace('discord.gg/ezz', 'discord.gg/swifly')
  $c = $c.Replace('r2.ezz.lol', 'swifly-servers.onrender.com')
  $c = $c.Replace('cdn.ezz.lol', 'swifly-servers.onrender.com')
  $c = $c.Replace('ezz.lol', 'swifly.gg')

  # Broken/old mixed branding cleanup.
  $mixed = @(
    'EZZ Swifly', 'Ezz Swifly', 'ezz Swifly',
    'EZZ SWIFLY', 'Ezz SWIFLY', 'ezz swifly',
    'Swifly Swifly', 'SWIFLY Swifly', 'SWIFLY BOIII'
  )
  foreach ($m in $mixed) {
    $c = $c.Replace($m, 'Swifly BOIII')
  }

  # Product/title branding. Use ordered pairs instead of a hashtable because
  # PowerShell hashtable keys are case-insensitive by default.
  $brandReplacements = @(
    @('EZZ BOIII', 'Swifly BOIII'),
    @('Ezz BOIII', 'Swifly BOIII'),
    @('ezz BOIII', 'Swifly BOIII'),
    @('EZZ Boiii', 'Swifly BOIII'),
    @('Ezz Boiii', 'Swifly BOIII'),
    @('EZZ Client', 'Swifly Client'),
    @('Ezz Client', 'Swifly Client'),
    @('EZZ', 'SWIFLY'),
    @('Ezz', 'Swifly'),
    @('ezz', 'swifly')
  )

  foreach ($pair in $brandReplacements) {
    $c = $c.Replace($pair[0], $pair[1])
  }

  # Normalize visible product names after broad replacements.
  $c = $c.Replace('SWIFLY BOIII', 'Swifly BOIII')
  $c = $c.Replace('Swifly Boiii', 'Swifly BOIII')
  $c = $c.Replace('Swifly boiii', 'Swifly BOIII')
  $c = $c.Replace('Swifly BOIII BOIII', 'Swifly BOIII')
  $c = $c.Replace('Swifly Swifly', 'Swifly BOIII')

  return $c
}

# Broad text pass over our editable source/data files. Avoid third-party deps and generated output.
$roots = @('data', 'src')
$extensions = @(
  '.bat', '.cfg', '.c', '.cc', '.cpp', '.css', '.h', '.hpp', '.html', '.ini',
  '.js', '.json', '.lua', '.md', '.ps1', '.rc', '.txt', '.xml', '.yml', '.yaml'
)

foreach ($root in $roots) {
  if (!(Test-Path $root)) {
    continue
  }

  Get-ChildItem $root -Recurse -File | Where-Object {
    $extensions -contains $_.Extension.ToLowerInvariant() -and
    $_.FullName -notmatch '\build\' -and
    $_.FullName -notmatch '\deps\' -and
    $_.FullName -notmatch '\third_party\'
  } | ForEach-Object {
    $path = $_.FullName
    $original = Get-Content $path -Raw
    $updated = Apply-SwiflyBranding $original
    if ($updated -ne $original) {
      Write-Utf8NoBom $path $updated
    }
  }
}

# Root project files.
foreach ($file in @('premake5.lua', 'generate.bat', 'README.md')) {
  if (Test-Path $file) {
    $original = Get-Content $file -Raw
    $updated = Apply-SwiflyBranding $original
    if ($updated -ne $original) {
      Write-Utf8NoBom $file $updated
    }
  }
}

# Launcher HTML needs structural title cleanup, not just text replacement.
$htmlPath = 'data/launcher/main.html'
if (Test-Path $htmlPath) {
  $html = Get-Content $htmlPath -Raw
  $html = $html.Replace('<title>BOIII</title>', '<title>Swifly BOIII</title>')
  $html = [regex]::Replace($html, '<title>.*?</title>', '<title>Swifly BOIII</title>', 1)
  $html = [regex]::Replace(
    $html,
    '<span class="title-white title-big">.*?</span><span class="title-white">.*?</span>\s*<span class="title-orange">.*?</span>',
    '<span class="title-white title-big">S</span><span class="title-white">wifly</span> <span class="title-orange">BOIII</span>',
    1
  )
  $html = $html.Replace('Call of Duty: Black Ops 3 enhanced with our modifications.', 'Call of Duty: Black Ops 3 enhanced by Swifly BOIII.')
  $html = $html.Replace('Latest (Auto-update)', 'Latest')

  if ($html -notmatch 'data-option="vanilla"') {
    $marker = '              <div class="launch-option-card" data-option="console"'
    $insert = '              <div class="launch-option-card" data-option="vanilla" title="Enable BOIII Vanilla campaign/speedrun-friendly behavior"><span class="launch-option-dot"></span><span class="launch-option-name">Vanilla Mode</span></div>' + [Environment]::NewLine
    $html = $html.Replace($marker, $insert + $marker)
  }

  Write-Utf8NoBom $htmlPath $html
}

# Native launcher window title.
$cppPath = 'src/client/launcher/launcher.cpp'
if (Test-Path $cppPath) {
  $cpp = Get-Content $cppPath -Raw
  $cpp = [regex]::Replace($cpp, 'html_window window\(".*?(BOIII|Swifly).*?", 1260, 680\);', 'html_window window("Swifly BOIII", 1260, 680);')
  $cpp = Apply-SwiflyBranding $cpp
  Write-Utf8NoBom $cppPath $cpp
}

# Join Game status styling if the launcher uses it.
$cssPath = 'data/launcher/main.css'
if (Test-Path $cssPath) {
  $css = Get-Content $cssPath -Raw
  if ($css -notmatch 'join-game-status') {
    $css += @'

.join-game-status {
  margin-top: 10px;
  color: rgba(255, 255, 255, 0.62);
  font-size: 0.78rem;
  text-align: center;
  min-height: 1rem;
}

.join-game-status.error {
  color: rgba(239, 68, 68, 0.95);
}

.join-game-status.ok {
  color: rgba(34, 197, 94, 0.95);
}
'@
    Write-Utf8NoBom $cssPath $css
  }
}

Write-Host 'Swifly BOIII branding normalized.'
