@echo off
git submodule update --init --recursive
if exist build rmdir /s /q build
powershell -NoProfile -ExecutionPolicy Bypass -File tools\patch_swifly_launcher.ps1
tools\premake5 %* vs2022
