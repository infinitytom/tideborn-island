extends SceneTree
const Model=preload("res://scripts/eco_model.gd")
const Terrain=preload("res://scripts/native_terrain.gd")
var game
var output_dir="F:/微光盆地/开发验证"
func _initialize():call_deferred("run")
func shot(name:String):
	await process_frame;RenderingServer.force_draw(false,1.0/60)
	root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):output_dir=arg.trim_prefix("--output-dir=")
	var reference=Model.new();reference.reset(12345)
	var repeat=Model.new();repeat.reset(12345)
	var deterministic=reference.base_heights==repeat.base_heights and reference.species==repeat.species
	var varied=true;var compiled=true;var borders=true
	for seed_value in [0,1,2,42,999,54321,999999]:
		var m=Model.new();m.reset(seed_value)
		var changed=0;var coast_changed=0
		for i in m.COUNT:
			if absf(m.heights[i]-reference.heights[i])>5:changed+=1
			if (m.heights[i]>1)!=(reference.heights[i]>1):coast_changed+=1
			if i%m.N==0 or i%m.N==m.N-1 or i<m.N or i>=m.COUNT-m.N:
				borders=borders and m.heights[i]<0
		var graph=Terrain.create(m);compiled=compiled and graph.compile().success
		varied=varied and changed>1000 and coast_changed>400
		print("SEED_VARIETY seed=",seed_value," heights_changed=",changed," coast_changed=",coast_changed)
	var restored=Model.new();restored.restore(reference.snapshot())
	var saved=restored.terrain_layout==1 and restored.layout_parameters()==reference.layout_parameters() and restored.base_heights==reference.base_heights
	var old=reference.snapshot();old.erase("terrain_layout");restored.restore(old)
	var legacy=restored.terrain_layout==0 and restored.layout_point(Vector2(120,-65))==Vector2(120,-65) and restored.base_heights==reference.base_heights
	game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.speed=0
	var ui_ok=true
	for seed_value in [12345,54321]:
		game.show_new_island()
		for control in game.content.get_children():
			if control is LineEdit:control.text=str(seed_value)
		for control in game.content.get_children():
			if control is Button and control.text=="让小岛生长":control.pressed.emit();break
		ui_ok=ui_ok and game.model.world_seed==seed_value
		game.set_panorama(true)
		var v=game.visual;v.preview_clock=40;v.daylight=1
		while v.render_stage>=0:v.apply_render_stage()
		v.target_focus=Vector3(0,30,0);v.target_distance=650;v.target_pitch=.85;v.target_yaw=.55
		for i in 120:v.animate(1.0/30);await process_frame
		await shot("seed-"+str(seed_value))
	var v=game.visual
	var highest=0
	for i in game.model.COUNT:
		if game.model.heights[i]>game.model.heights[highest]:highest=i
	var sample=game.model.pos(highest)
	game.model.paint_plants(sample,55,-1);game.model.prepare_render_frame();v.queue_render(game.model.render_frame)
	while v.render_stage>=0:v.apply_render_stage()
	var hit=v.terrain.get_voxel_tool().raycast(Vector3(sample.x,959,sample.y),Vector3.DOWN,1022)
	var p=Vector3(sample.x,959-hit.distance,sample.y)
	print("PREVIEW_POINT ",p," model_height=",game.model.height_at(sample))
	v.target_focus=p;v.target_distance=80;v.target_pitch=.6
	for i in 30:v.animate(1.0/30);await process_frame
	var revision=v.terrain_revision
	v.last_normal=Vector3.UP;v.set_cursor(p,12,false,false,true)
	var add_ok=v.brush_ball.visible and v.brush_ball.position==v.brush_center(p,12,false)
	await shot("preview-add")
	v.set_cursor(p,12,true,false,true)
	var cut_ok=v.brush_ball.position==v.brush_center(p,12,true)
	await shot("preview-cut")
	var air=p+Vector3.UP*30;v.set_cursor(air,12,false,true,true)
	var stamp_ok=v.brush_ball.position==air and v.brush_ball.visible
	await shot("preview-air")
	var unchanged=v.terrain_revision==revision
	v.edit(air,12,0,false,1,true)
	var placement_ok=v.terrain.get_voxel_tool().get_voxel_f(Vector3i(air))<0
	v.set_cursor(Vector3(9999,9999,9999),12,false)
	var hidden=not v.brush_ball.visible and not v.cursor.visible
	var smooth_bounds=v.edit(Vector3(487,2,0),48,2) and not v.edit(Vector3(500,2,0),48,2)
	print("SEED_PREVIEW_TEST deterministic=",deterministic," varied=",varied," compiled=",compiled," borders=",borders," saved=",saved," legacy=",legacy," ui=",ui_ok," add=",add_ok," cut=",cut_ok," air=",stamp_ok," placement=",placement_ok," unchanged=",unchanged," hidden=",hidden," smooth_bounds=",smooth_bounds)
	quit(0 if deterministic and varied and compiled and borders and saved and legacy and ui_ok and add_ok and cut_ok and stamp_ok and placement_ok and unchanged and hidden and smooth_bounds else 1)
