@echo off
cd /d "%~dp0"
if exist "%~dp0godot.windows.editor.double.x86_64.exe\godot.windows.editor.double.x86_64.exe" (
  start "" "%~dp0godot.windows.editor.double.x86_64.exe\godot.windows.editor.double.x86_64.exe" --editor --path "%~dp0game"
  exit /b
)
if exist "%~dp0godot-voxel.exe" (
  start "" "%~dp0godot-voxel.exe" --editor --path "%~dp0game"
  exit /b
)
echo Copy the release runtime here as godot-voxel.exe. See README.md.
pause
