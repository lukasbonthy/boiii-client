@echo off
git submodule update --init --recursive
powershell -NoProfile -ExecutionPolicy Bypass -Command "$b64 = Get-Content 'src/client/resources/icon.ico.b64' -Raw; [IO.File]::WriteAllBytes('src/client/resources/icon.ico.raw', [Convert]::FromBase64String($b64))"
powershell -NoProfile -ExecutionPolicy Bypass -File tools\make_png_ico.ps1 -InputPath src\client\resources\icon.ico.raw -OutputPath src\client\resources\icon.ico
tools\premake5 %* vs2022
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Path build -Recurse -Filter *.vcxproj | ForEach-Object { $p = $_.FullName; $c = Get-Content $p -Raw; $c = $c -replace '<TargetName>boiii</TargetName>', '<TargetName>swiflyboiii</TargetName>'; $c = $c -replace '</ClCompile>', '  <AdditionalOptions>-Wno-deprecated-declarations %(AdditionalOptions)</AdditionalOptions>' + [Environment]::NewLine + '</ClCompile>'; Set-Content -Path $p -Value $c -NoNewline }"
