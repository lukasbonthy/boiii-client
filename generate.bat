@echo off
git submodule update --init --recursive
tools\premake5 %* vs2022
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Path build -Recurse -Filter *.vcxproj | ForEach-Object { $p = $_.FullName; $c = Get-Content $p -Raw; $c = $c -replace '<TargetName>boiii</TargetName>', '<TargetName>swiflyboiii</TargetName>'; Set-Content -Path $p -Value $c -NoNewline }"
