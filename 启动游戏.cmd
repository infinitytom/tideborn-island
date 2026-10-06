@echo off
cd /d "%~dp0"
if exist "%~dp0godot.windows.editor.double.x86_64.exe\godot.windows.editor.double.x86_64.exe" (
  start "" "%~dp0godot.windows.editor.double.x86_64.exe\godot.windows.editor.double.x86_64.exe" --path "%~dp0game"
  exit /b
)
if exist "%~dp0godot-voxel.exe" (
  start "" "%~dp0godot-voxel.exe" --path "%~dp0game"
  exit /b
)
if exist "%~dp0TidebornIsland.exe" (
  start "" "%~dp0TidebornIsland.exe" --path "%~dp0game"
  exit /b
)
echo Download the Windows runtime from https://github.com/infinitytom/tideborn-island/releases/latest
pause
