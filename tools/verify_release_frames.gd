extends SceneTree
var game
func _initialize():call_deferred("run")
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.speed=0;game.enter_world();game.hud.visible=false
	for i in 120:game.visual.animate(1.0/60);await process_frame
	game.selected_tool=0;game.radius=24;game.drawing=1
	for i in 40:
		var p=Vector2(-140+i*7,70)
		var hit=game.visual.terrain.get_voxel_tool().raycast(Vector3(p.x,959,p.y),Vector3.DOWN,1022)
		game.hover=Vector3(p.x,959-hit.distance,p.y);game.raise_active=false;game.apply_brush(.05,Vector2(i*10,0))
		await process_frame
	game.drawing=0;game.raise_active=false;game.set_process(true)
	var timings=[];var prior=Time.get_ticks_usec()
	for i in 180:
		await process_frame;var now=Time.get_ticks_usec();timings.append((now-prior)/1000.0);prior=now
	timings.sort()
	var max_ms=timings.back();var p95=timings[int(timings.size()*.95)]
	var finished=game.pending_surface.is_empty() and game.visual.uncaptured_blocks.is_empty()
	print("RELEASE_FRAME_TEST p95_ms=",p95," max_ms=",max_ms," finished=",finished)
	game.finish_simulation();quit(0 if max_ms<100 and p95<35 and finished else 1)
