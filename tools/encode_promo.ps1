param([string]$FFmpegPath="ffmpeg")
$ErrorActionPreference="Stop"
$taskRepositoryRoot=Split-Path $PSScriptRoot -Parent
$taskMediaWork=Join-Path $taskRepositoryRoot "media_work"
$taskMedia=Join-Path $taskRepositoryRoot "media"
New-Item -ItemType Directory -Path $taskMediaWork,$taskMedia -Force | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot "promo_text/*.txt") -Destination $taskMediaWork
Copy-Item -LiteralPath (Join-Path $env:WINDIR "Fonts/msyh.ttc") -Destination (Join-Path $taskMediaWork "msyh.ttc")
Push-Location $taskRepositoryRoot
try {
    & $FFmpegPath -hide_banner -loglevel warning -y -framerate 30 -i media_work/frames/frame_%05d.png -i game/audio/island_music.wav -stream_loop -1 -i game/audio/sea.wav -i game/audio/earth.wav -i game/audio/seed.wav -filter_complex_script tools/promo.filters -map "[v]" -map "[a]" -t 32 -r 30 -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k -ar 48000 -movflags +faststart media/TidebornIsland-Trailer.mp4 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Trailer encoding failed" }
} finally { Pop-Location }
