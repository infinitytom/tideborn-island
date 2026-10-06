param([string]$FFmpegPath="ffmpeg",[switch]$IncludeSmoothing)
$ErrorActionPreference="Stop"
$taskRepositoryRoot=Split-Path $PSScriptRoot -Parent
$taskMediaWork=Join-Path $taskRepositoryRoot "media_work"
$taskMedia=Join-Path $taskRepositoryRoot "media"
New-Item -ItemType Directory -Path $taskMediaWork,$taskMedia -Force | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot "promo_text/*.txt") -Destination $taskMediaWork
Copy-Item -LiteralPath (Join-Path $env:WINDIR "Fonts/msyh.ttc") -Destination (Join-Path $taskMediaWork "msyh.ttc")
$taskEvents=Get-Content -LiteralPath (Join-Path $taskMediaWork "actions.json") -Raw | ConvertFrom-Json
$taskDuration=49
$taskExtraInputs=@()
if($IncludeSmoothing) {
    $taskDuration=57
    foreach($taskEvent in $taskEvents){if($taskEvent.time -ge 34){$taskEvent.time+=8}}
    for($taskTick=0;$taskTick -lt 20;$taskTick++){$taskEvents+=@{kind='smooth';time=36+$taskTick*.2}}
    $taskExtraInputs=@('-i','game/audio/smooth.wav','-framerate','30','-i','media_work/smooth_frames/frame_%05d.png')
}
$taskFadeStart=$taskDuration-1.5
$taskFilters=[Collections.Generic.List[string]]::new()
$taskFilters.Add("[1:a]volume=0.68,atrim=duration=$taskDuration,asetpts=PTS-STARTPTS[m]")
$taskFilters.Add("[2:a]volume=0.16,atrim=duration=$taskDuration,asetpts=PTS-STARTPTS[s]")
$taskMix='[m][s]'
$taskClips=@{cut=3;earth=4;seed=5;click=6;smooth=7}
$taskCount=0
foreach($taskKind in @('cut','earth','seed','click','smooth')) {
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
$taskFilters.Add("${taskMix}amix=inputs=$($taskCount+2):duration=longest:normalize=0,atrim=duration=$taskDuration,afade=t=in:st=0:d=0.25,afade=t=out:st=${taskFadeStart}:d=1.5,alimiter=limit=0.85:level=false,volume=0.9[a]")
$taskVideoGraph=(Get-Content -LiteralPath (Join-Path $PSScriptRoot "promo.filters") -Raw).Trim()
if($IncludeSmoothing) {
    $taskVideoGraph=$taskVideoGraph.Replace('[v];','[base];')
    $taskVideoGraph+="`n[base]split=2[first][last];[first]trim=end=34,setpts=PTS-STARTPTS[before];[last]trim=start=34:end=49,setpts=PTS-STARTPTS[after];[8:v]crop=1280:720:0:40,setsar=1,drawbox=x=0:y=620:w=1280:h=100:color=0x103638@0.68:t=fill,drawtext=fontfile=media_work/msyh.ttc:textfile=media_work/smooth.txt:fontsize=32:fontcolor=white:x=(w-tw)/2:y=651,drawbox=x=28:y=25:w=220:h=48:color=0x103638@0.68:t=fill,drawtext=fontfile=media_work/msyh.ttc:text='平滑前':fontsize=28:fontcolor=white:x=48:y=34:enable='lt(t,2)',drawtext=fontfile=media_work/msyh.ttc:text='正在平滑':fontsize=28:fontcolor=0xffdf97:x=48:y=34:enable='between(t,2,5.99)',drawtext=fontfile=media_work/msyh.ttc:text='平滑后':fontsize=28:fontcolor=white:x=48:y=34:enable='gte(t,6)',trim=duration=8,setpts=PTS-STARTPTS[smoothvideo];[before][smoothvideo][after]concat=n=3:v=1:a=0[v];"
}
$taskGraph=$taskVideoGraph+"`n"+($taskFilters -join ";`n")
[IO.File]::WriteAllText((Join-Path $taskMediaWork "promo_v3.filters"),$taskGraph,[Text.UTF8Encoding]::new($false))
Push-Location $taskRepositoryRoot
try {
    & $FFmpegPath -hide_banner -loglevel warning -y -framerate 30 -i media_work/frames_v3/frame_%05d.png -stream_loop -1 -i game/audio/island_music.wav -stream_loop -1 -i game/audio/sea.wav -i game/audio/cut.wav -i game/audio/earth.wav -i game/audio/seed.wav -i game/audio/click.wav @taskExtraInputs -filter_complex_script media_work/promo_v3.filters -map "[v]" -map "[a]" -t $taskDuration -r 30 -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -c:a aac -b:a 192k -ar 48000 -movflags +faststart media/IslandStack-Trailer.mp4 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Trailer encoding failed" }
    $taskCover="scale=1920:1080,drawbox=x=0:y=0:w=650:h=1080:color=0x10363d@0.92:t=fill,drawbox=x=650:y=0:w=8:h=1080:color=0xf3d38e:t=fill,drawtext=fontfile=media_work/msyh.ttc:textfile=media_work/coverbadge.txt:fontsize=30:fontcolor=0xb9dcd1:x=65:y=95,drawtext=fontfile=media_work/msyh.ttc:textfile=media_work/cover1.txt:fontsize=128:fontcolor=white:x=60:y=238,drawtext=fontfile=media_work/msyh.ttc:textfile=media_work/cover2.txt:fontsize=102:fontcolor=white:x=65:y=405,drawtext=fontfile=media_work/msyh.ttc:textfile=media_work/cover3.txt:fontsize=90:fontcolor=0xffd786:x=65:y=550,drawtext=fontfile=media_work/msyh.ttc:textfile=media_work/covernote.txt:fontsize=33:fontcolor=0xd2e7df:x=65:y=740,drawbox=x=65:y=843:w=120:h=5:color=0xffd786:t=fill,drawtext=fontfile=media_work/msyh.ttc:text='挖洞 / 搭桥 / 造浮岛':fontsize=31:fontcolor=white:x=65:y=888"
    $taskCoverGraph="[0:v]${taskCover}[base];[1:v]crop=1280:720:0:40,scale=310:174,pad=318:182:4:4:color=0xffe6b0[deer];[2:v]crop=1280:720:0:40,scale=310:174,pad=318:182:4:4:color=0xffe6b0[fox];[base][deer]overlay=x=1220:y=840[one];[one][fox]overlay=x=1565:y=840,drawtext=fontfile=media_work/msyh.ttc:text='小动物来作伴':fontsize=31:fontcolor=white:shadowcolor=black@0.75:shadowx=2:shadowy=2:x=1220:y=786[cover]"
    & $FFmpegPath -hide_banner -loglevel warning -y -i media_work/cover-scene.png -i media_work/frames_v3/frame_01110.png -i media_work/frames_v3/frame_01275.png -filter_complex $taskCoverGraph -map "[cover]" -frames:v 1 -update 1 media/IslandStack-Cover.png | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Cover encoding failed" }
    & $FFmpegPath -hide_banner -loglevel warning -y -i media/IslandStack-Cover.png -q:v 2 -frames:v 1 -update 1 docs/images/trailer-cover.jpg | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "README cover encoding failed" }
} finally { Pop-Location }
