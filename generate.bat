@echo off
git submodule update --init --recursive
if exist build rmdir /s /q build
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='data/launcher/main.html'; $c=Get-Content $p -Raw; if ($c -notmatch 'data-option=\"vanilla\"') { $marker='              <div class=\"launch-option-card\" data-option=\"console\"'; $insert='              <div class=\"launch-option-card\" data-option=\"vanilla\" title=\"Enable BOIII Vanilla campaign/speedrun-friendly behavior\"><span class=\"launch-option-dot\"></span><span class=\"launch-option-name\">Vanilla Mode</span></div>' + [Environment]::NewLine; $c=$c.Replace($marker, $insert + $marker); Set-Content -Path $p -Value $c -NoNewline }"
tools\premake5 %* vs2022
