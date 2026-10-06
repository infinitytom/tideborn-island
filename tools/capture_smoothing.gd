extends SceneTree
const FPS=30
const DURATION=8
var game
func _initialize():call_deferred("capture")
func capture():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.speed=0;game.set_panorama(true)
	var v=game.visual
	game.model.elapsed=40;v.preview_clock=40
	game.model.paint_plants(Vector2(260,80),65,-1)
	game.model.prepare_render_frame();v.queue_render(game.model.render_frame)
	while v.render_stage>=0:v.apply_render_stage()
	v.edit(Vector3(260,45,80),24,0,false,1,true)
	for i in 8:
		var a=i*TAU/8
		v.edit(Vector3(260+cos(a)*7,69.5,80+sin(a)*7),4,0,false,1,true)
	v.target_focus=Vector3(260,69,80);v.focus=v.target_focus
	v.target_distance=48;v.distance=48;v.target_pitch=.8;v.pitch=.8;v.target_yaw=.4;v.yaw=.4
	for i in 60:v.animate(1.0/FPS,false);await process_frame
	var before=VoxelBuffer.new();before.create(40,40,40)
	v.terrain.get_voxel_tool().copy(Vector3i(240,50,60),before,VoxelBuffer.CHANNEL_SDF_BIT,false)
	var pilot=OS.get_cmdline_user_args().has("--pilot")
	var output=ProjectSettings.globalize_path("res://../media_work/smooth_frames")
	DirAccess.make_dir_recursive_absolute(output)
	for frame in FPS*DURATION:
		if frame>=60 and frame<180 and frame%2==0:
			var a=float(frame-60)/120*TAU*2
			var p=Vector2(260+cos(a)*4,80+sin(a)*4)
			var hit=v.terrain.get_voxel_tool().raycast(Vector3(p.x,959,p.y),Vector3.DOWN,1022)
			game.hover=Vector3(p.x,959-hit.distance,p.y)
			game.selected_tool=2;game.radius=14;game.drawing=1;game.brush_strength=1
			game.apply_brush(2.0/FPS,Vector2.ZERO)
		v.animate(1.0/FPS,false);await process_frame
		RenderingServer.force_draw(false,1.0/FPS)
		if not pilot or frame%30==0:
			var name="pilot_%02d.png"%(frame/30) if pilot else "frame_%05d.png"%frame
			if root.get_texture().get_image().save_png(output.path_join(name))!=OK:quit(1);return
	var after=VoxelBuffer.new();after.create(40,40,40)
	v.terrain.get_voxel_tool().copy(Vector3i(240,50,60),after,VoxelBuffer.CHANNEL_SDF_BIT,false)
	var changed=before.get_channel_as_byte_array(VoxelBuffer.CHANNEL_SDF)!=after.get_channel_as_byte_array(VoxelBuffer.CHANNEL_SDF)
	print("SMOOTH_CAPTURE changed=",changed," frames=",FPS*DURATION)
	quit(0 if changed else 1)
