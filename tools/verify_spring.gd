extends SceneTree
var game
var output_dir:String
func _initialize(): call_deferred("run")
func shot(name:String):
	for i in 60:
		game.visual.animate(1.0/30,false); await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))!=OK:
		quit(1)
func run():
	output_dir=OS.get_executable_path().get_base_dir().path_join("spring-validation")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output_dir=arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.speed=0; game.set_panorama(true)
	game.visual.preview_clock=40
	game.model.prepare_render_frame(); game.visual.queue_render(game.model.render_frame)
	while game.visual.render_stage>=0: game.visual.apply_render_stage()
	for i in 90: await process_frame
	var p=Vector2(45,70); var h=game.model.height_at(p)
	game.model.paint_plants(p,70,-1)
	game.model.prepare_render_frame(); game.visual.queue_render(game.model.render_frame)
	while game.visual.render_stage>=0: game.visual.apply_render_stage()
	var v=game.visual
	v.target_focus=Vector3(p.x,h,p.y); v.target_distance=45; v.target_pitch=1.0; v.target_yaw=.4
	game.select_tool(3); game.hover=Vector3(p.x,h,p.y)
	var old=game.model.springs.size()
	game.use_tool(false); v.refresh_sources(); v.set_source_focus(false,game.hover)
	await shot("spring-natural")
	var added=game.model.springs.size()==old+1
	var grounded=true
	for seep in v.source_markers.get_children():
		if seep.is_queued_for_deletion(): continue
		grounded=grounded and seep is MeshInstance3D and seep.get_child_count()==0
	v.set_source_focus(true,game.hover); await shot("spring-selected")
	game.use_tool(true); v.refresh_sources(); await process_frame
	var removed=game.model.springs.size()==old
	print("SPRING_VERIFY added=",added," grounded=",grounded," removed=",removed)
	quit(0 if added and grounded and removed else 1)
