extends SceneTree
var game
var output_dir:String
func _initialize(): call_deferred("run")
func upload():
	game.model.prepare_render_frame(); game.visual.queue_render(game.model.render_frame)
	for i in 16: game.visual.apply_render_stage()
func pose(p:Vector3,d:float,pitch:float,yaw:float):
	var v=game.visual
	v.focus=p;v.target_focus=p;v.distance=d;v.target_distance=d;v.pitch=pitch;v.target_pitch=pitch;v.yaw=yaw;v.target_yaw=yaw
	v.update_camera(1)
func settle(frames=90):
	for i in frames:
		game.visual.animate(1.0/30,false);await process_frame
func shot(name:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))
func run():
	output_dir=OS.get_executable_path().get_base_dir().path_join("animal-validation")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):output_dir=arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.speed=0;game.visual.preview_clock=40
	upload();await settle()
	print("ANIMALS=",game.model.animals," walkers=",game.visual.walkers.size())
	await shot("v6-home")
	game.set_panorama(true);game.visual.preview_clock=40
	for data in game.visual.walkers:
		game.model.paint_plants(data.home,45,-1)
	upload()
	var deer=game.visual.walkers.filter(func(d):return d.kind=="鹿")
	var fox=game.visual.walkers.filter(func(d):return d.kind=="狐狸")
	if deer.is_empty() or fox.is_empty():quit(1);return
	pose(deer[0].node.position+Vector3.UP*3,32,.5,.75);await settle(60);await shot("v6-deer")
	var old=deer[0].node.position
	await settle(150)
	var moved=old.distance_to(deer[0].node.position)>.2
	pose(fox[0].node.position+Vector3.UP*2,24,.9,.9);await settle(30);await shot("v6-fox")
	var ground_ok=true
	for data in game.visual.walkers:
		ground_ok=ground_ok and is_finite(data.node.position.y) and absf(data.node.position.y-data.ground)<.01
	var saved=game.model.snapshot();game.model.restore(saved)
	var restored=game.model.animals.has("鹿") and game.model.animals.has("狐狸")
	game.enter_world();game.hud.visible=false;game.speed=0
	game.stamp_mode=true;game.placement_height=240;game.radius=12;game.select_tool(0)
	var p=Vector3(320,240,80)
	pose(p,180,.5,.5);await settle(30)
	var count=game.sound.effect_index
	var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=game.visual.camera.unproject_position(p)
	game._unhandled_input(click)
	var stamping=game.visual.terrain.get_voxel_tool().get_voxel_f(Vector3i(p))<0
	var effect=game.sound.effect_index>count
	game.drawing=0;game.undo_edit()
	var undo=game.visual.terrain.get_voxel_tool().get_voxel_f(Vector3i(p))>0
	game.redo_edit()
	var redo=game.visual.terrain.get_voxel_tool().get_voxel_f(Vector3i(p))<0
	game.visual.sync_surface(Vector2(320,80),24)
	game.model.paint_plants(Vector2(320,80),24,9);upload()
	var floating_plants=true;var found=0
	var mm=game.visual.plant_nodes[9].multimesh
	for i in mm.instance_count:
		var position=mm.get_instance_transform(i).origin
		if Vector2(position.x,position.z).distance_to(Vector2(320,80))>30:continue
		found+=1
		var hit=game.visual.terrain.get_voxel_tool().raycast(Vector3(position.x,959,position.z),Vector3.DOWN,1022)
		floating_plants=floating_plants and hit!=null and absf(position.y-(959-hit.distance))<.02
	floating_plants=floating_plants and found>0
	print("ANIMAL_VERIFY moving=",moved," grounded=",ground_ok," restored=",restored," input_stamp=",stamping," brush_sound=",effect," undo=",undo," redo=",redo," floating_plants=",floating_plants)
	quit(0 if moved and ground_ok and restored and stamping and effect and undo and redo and floating_plants else 1)
