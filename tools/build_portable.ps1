param(
    [Parameter(Mandatory=$true)][string]$EnginePath,
    [string]$Version = "0.3.4"
)
$ErrorActionPreference = "Stop"
$taskProjectRoot = Split-Path $PSScriptRoot -Parent
$taskEngine = (Resolve-Path -LiteralPath $EnginePath).Path
$taskGameRoot = Join-Path $taskProjectRoot "game"
$taskDist = Join-Path $taskProjectRoot "dist"
$taskBundle = Join-Path $taskDist "IslandStack-Windows-x64"
New-Item -ItemType Directory -Path $taskBundle -Force | Out-Null
& $taskEngine --headless --path $taskGameRoot --editor --import | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Resource import failed" }
& $taskEngine --headless --path $taskGameRoot --export-pack "Windows Portable" (Join-Path $taskBundle "IslandStack.pck") | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Game pack export failed" }
Copy-Item -LiteralPath $taskEngine -Destination (Join-Path $taskBundle "IslandStack.exe")
foreach ($taskName in @("THIRD_PARTY_NOTICES.txt", "使用说明.md")) {
    Copy-Item -LiteralPath (Join-Path $taskProjectRoot $taskName) -Destination (Join-Path $taskBundle $taskName)
}
$taskLauncher = '@echo off' + "`r`n" + 'cd /d "%~dp0"' + "`r`n" + 'start "" "%~dp0IslandStack.exe"' + "`r`n"
[IO.File]::WriteAllText((Join-Path $taskBundle "启动游戏.cmd"), $taskLauncher, [Text.Encoding]::ASCII)
$taskWelcome = "小岛叠叠乐 v$Version · Windows x64`n完整解压后运行 IslandStack.exe。P 全景，P / Esc 返回，F1 帮助。`n下载与源码：https://github.com/infinitytom/tideborn-island`n第三方许可见 THIRD_PARTY_NOTICES.txt。"
[IO.File]::WriteAllText((Join-Path $taskBundle "先读我.txt"), $taskWelcome, [Text.UTF8Encoding]::new($false))
$taskZip = Join-Path $taskDist "IslandStack-v$Version-Windows-x64.zip"
Compress-Archive -LiteralPath $taskBundle -DestinationPath $taskZip -CompressionLevel Optimal -Force
$taskHash = (Get-FileHash -LiteralPath $taskZip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $taskDist "SHA256SUMS.txt"), "$taskHash  $([IO.Path]::GetFileName($taskZip))`n", [Text.UTF8Encoding]::new($false))
Get-Item -LiteralPath $taskZip | Select-Object FullName,Length
