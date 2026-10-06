param([string]$FFmpegPath="ffmpeg")
$ErrorActionPreference="Stop"
$taskRepositoryRoot=Split-Path $PSScriptRoot -Parent
$taskMediaWork=Join-Path $taskRepositoryRoot "media_work"
$taskMedia=Join-Path $taskRepositoryRoot "media"
New-Item -ItemType Directory -Path $taskMediaWork,$taskMedia -Force | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot "promo_text/*.txt") -Destination $taskMediaWork
Copy-Item -LiteralPath (Join-Path $env:WINDIR "Fonts/msyh.ttc") -Destination (Join-Path $taskMediaWork "msyh.ttc")
$taskEvents=Get-Content -LiteralPath (Join-Path $taskMediaWork "actions.json") -Raw | ConvertFrom-Json
$taskFilters=[Collections.Generic.List[string]]::new()
$taskFilters.Add('[1:a]volume=0.68,atrim=duration=36,asetpts=PTS-STARTPTS[m]')
$taskFilters.Add('[2:a]volume=0.16,atrim=duration=36,asetpts=PTS-STARTPTS[s]')
$taskMix='[m][s]'
$taskClips=@{cut=3;earth=4;seed=5;click=6}
$taskCount=0
foreach($taskKind in @('cut','earth','seed','click')) {
    $taskGroup=@($taskEvents | Where-Object {$_.kind -eq $taskKind})
    if($taskGroup.Count -eq 0){continue}
    $taskOutputs=($taskGroup | ForEach-Object -Begin {$taskIndex=0} -Process {"[${taskKind}$taskIndex]";$taskIndex++}) -join ''
    $taskFilters.Add("[$($taskClips[$taskKind]):a]asplit=$($taskGroup.Count)$taskOutputs")
    for($taskIndex=0;$taskIndex -lt $taskGroup.Count;$taskIndex++) {
        $taskDelay=[int][Math]::Round($taskGroup[$taskIndex].time*1000)
        $taskFilters.Add("[${taskKind}$taskIndex]volume=0.65,adelay=${taskDelay}:all=1[fx$taskCount]")
        $taskMix+="[fx$taskCount]";$taskCount++
    }
}
$taskFilters.Add("${taskMix}amix=inputs=$($taskCount+2):duration=longest:normalize=0,atrim=duration=36,afade=t=in:st=0:d=0.25,afade=t=out:st=34.5:d=1.5,alimiter=limit=0.85:level=false,volume=0.9[a]")
$taskGraph=(Get-Content -LiteralPath (Join-Path $PSScriptRoot "promo.filters") -Raw).Trim()+"`n"+($taskFilters -join ";`n")
[IO.File]::WriteAllText((Join-Path $taskMediaWork "promo_v2.filters"),$taskGraph,[Text.UTF8Encoding]::new($false))
Push-Location $taskRepositoryRoot
try {
    & $FFmpegPath -hide_banner -loglevel warning -y -framerate 30 -i media_work/frames_v2/frame_%05d.png -i game/audio/island_music.wav -stream_loop -1 -i game/audio/sea.wav -i game/audio/cut.wav -i game/audio/earth.wav -i game/audio/seed.wav -i game/audio/click.wav -filter_complex_script media_work/promo_v2.filters -map "[v]" -map "[a]" -t 36 -r 30 -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -c:a aac -b:a 192k -ar 48000 -movflags +faststart media/TidebornIsland-Trailer.mp4 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Trailer encoding failed" }
    $taskCover="scale=1920:1080,drawbox=x=0:y=0:w=650:h=1080:color=0x10363d@0.92:t=fill,drawbox=x=650:y=0:w=8:h=1080:color=0xf3d38e:t=fill,drawtext=fontfile=media_work/msyh.ttc:textfile=media_work/coverbadge.txt:fontsize=30:fontcolor=0xb9dcd1:x=65:y=95,drawtext=fontfile=media_work/msyh.ttc:textfile=media_work/cover1.txt:fontsize=128:fontcolor=white:x=60:y=238,drawtext=fontfile=media_work/msyh.ttc:textfile=media_work/cover2.txt:fontsize=102:fontcolor=white:x=65:y=405,drawtext=fontfile=media_work/msyh.ttc:textfile=media_work/cover3.txt:fontsize=102:fontcolor=0xffd786:x=65:y=550,drawtext=fontfile=media_work/msyh.ttc:textfile=media_work/covernote.txt:fontsize=33:fontcolor=0xd2e7df:x=65:y=740,drawbox=x=65:y=843:w=120:h=5:color=0xffd786:t=fill,drawtext=fontfile=media_work/msyh.ttc:text='挖洞 / 拆山 / 搭浮岛':fontsize=31:fontcolor=white:x=65:y=888"
    & $FFmpegPath -hide_banner -loglevel warning -y -i media_work/cover-scene.png -vf $taskCover -frames:v 1 -update 1 media/TidebornIsland-Cover.png | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Cover encoding failed" }
    & $FFmpegPath -hide_banner -loglevel warning -y -i media/TidebornIsland-Cover.png -q:v 2 -frames:v 1 -update 1 docs/images/trailer-cover.jpg | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "README cover encoding failed" }
} finally { Pop-Location }
