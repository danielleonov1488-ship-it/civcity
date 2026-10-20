@echo off
rem Steal a Legion: build the place from src\ and open it in Roblox Studio
cd /d "%~dp0"
python -I build.py
if errorlevel 1 (
  echo Build failed
  pause
  exit /b 1
)
set "STUDIO="
for /d %%v in ("%LOCALAPPDATA%\Roblox\Versions\*") do if exist "%%v\RobloxStudioBeta.exe" set "STUDIO=%%v\RobloxStudioBeta.exe"
if not defined STUDIO (
  echo Roblox Studio not found
  pause
  exit /b 1
)
start "" "%STUDIO%" "%~dp0build\StealALegion.rbxlx"
