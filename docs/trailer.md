# 宣传片

标题：**造一座岛，等一个世界生长｜潮生岛**

32 秒，720p、30 FPS，H.264 / AAC。内容来自真实 Godot 场景；镜头脚本调用游戏同样的地形、种植与季节方法，未使用生成式视频替代游戏画面。音乐、海浪与操作声来自游戏内原创资源。

镜头顺序：全岛开场 → 填海塑形 → 种植森林与花草 → 秋叶与冬雪 → 石拱与天色变化 → 全景和下载信息。

## 重新制作

准备原生 Voxel Tools 定制引擎、FFmpeg 及 Windows 微软雅黑字体。从项目根目录运行：

~~~powershell
.\godot-voxel.exe --path game --script ../tools/capture_promo.gd --fixed-fps 30 -- --promo-capture
.\tools\encode_promo.ps1
~~~

镜头输出到 media_work/frames，视频输出到 media/TidebornIsland-Trailer.mp4。录制使用独立测试模式，不读取或覆盖玩家正式存档。字体文件只在本地复制用于渲染，不包含在下载包或源码仓库中。
