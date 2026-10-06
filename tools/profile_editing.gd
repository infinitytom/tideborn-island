extends SceneTree
var game
func _initialize():call_deferred("run")
func top(p:Vector2) -> float:
	var hit=game.visual.terrain.get_voxel_tool().raycast(Vector3(p.x,959,p.y),Vector3.DOWN,1022)
	return 959-hit.distance if hit!=null else -48.0
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.speed=0
	game.enter_world();game.hud.visible=false
	for i in 100:game.visual.animate(1.0/60);await process_frame
	game.radius=24;game.selected_tool=0;game.drawing=1
	var edit_max=0.0
	for i in 40:
		var p=Vector2(-140+i*7,70)
		game.hover=Vector3(p.x,top(p),p.y)
		game.raise_active=false
		var started=Time.get_ticks_usec();game.apply_brush()
		edit_max=maxf(edit_max,(Time.get_ticks_usec()-started)/1000.0)
	game.drawing=0
	var count=game.pending_surface.size();var start=Time.get_ticks_usec();var surface_max=0.0;var surface_total=0.0;var batches=0
	while not game.pending_surface.is_empty():
		start=Time.get_ticks_usec();game.update_surface()
		var cost=(Time.get_ticks_usec()-start)/1000.0;surface_max=maxf(surface_max,cost);surface_total+=cost;batches+=1
	game.model.prepare_render_frame();game.visual.queue_render(game.model.render_frame)
	var plant_max=0.0;var plant_total=0.0
	while game.visual.render_stage>=0:
		var stage=game.visual.render_stage
		start=Time.get_ticks_usec();game.visual.apply_render_stage()
		var cost=(Time.get_ticks_usec()-start)/1000.0;plant_max=maxf(plant_max,cost);plant_total+=cost
		if cost>8:print("UPLOAD_COST stage=",stage," ms=",cost)
	var cache_max=0.0;var cache_batches=0
	while not game.visual.uncaptured_blocks.is_empty():
		start=Time.get_ticks_usec();game.visual.cache_edit_blocks()
		cache_max=maxf(cache_max,(Time.get_ticks_usec()-start)/1000.0);cache_batches+=1
	start=Time.get_ticks_usec();game.remember_edit()
	var snapshot_ms=(Time.get_ticks_usec()-start)/1000.0
	print("EDIT_PROFILE surface_samples=",count," surface_max_ms=",surface_max," surface_total_ms=",surface_total," batches=",batches," plant_max_ms=",plant_max," plant_total_ms=",plant_total," cache_max_ms=",cache_max," cache_batches=",cache_batches," next_snapshot_ms=",snapshot_ms," edit_max_ms=",edit_max)
	# Keep the pointer still at the centre of a hill, as during actual raising.
	var v=game.visual;var p=Vector2(45,70);var h=top(p)
	v.target_focus=Vector3(p.x,h,p.y);v.target_distance=350;v.target_pitch=.62
	for i in 30:v.animate(1.0/60);await process_frame
	var screen=v.camera.unproject_position(Vector3(p.x,h,p.y));game.radius=12;game.stroke_last=Vector3(9999,9999,9999);game.drawing=1;game.raise_active=false
	for i in 60:
		game.hover=v.pick(screen);game.apply_brush(.05,screen)
	var rise=top(p)-h
	print("POINTER_RAISE seconds=3 samples=60 rise=",rise," last_hover=",game.hover," anchor=",game.raise_anchor)
	var release_ok=surface_max<35 and plant_max<15 and cache_max<15 and snapshot_ms<20
	var raising_ok=rise>60
	print("EDITING_TEST release=",release_ok," raising=",raising_ok)
	quit(0 if release_ok and raising_ok else 1)
