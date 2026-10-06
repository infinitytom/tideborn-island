extends SceneTree
var game
var output_dir="F:/微光盆地/开发验证"
func _initialize():call_deferred("run")
func surface(p:Vector2) -> float:
	var hit=game.visual.terrain.get_voxel_tool().raycast(Vector3(p.x,959,p.y),Vector3.DOWN,1022)
	return 959-hit.distance if hit!=null else -48.0
func image_mean(img:Image) -> float:
	var total=0.0;var count=0
	for y in range(250,700,8):
		for x in range(400,1000,8):
			var c=img.get_pixel(x,y);total+=c.r*.2126+c.g*.7152+c.b*.0722;count+=1
	return total/count
func shot(name:String) -> Image:
	await process_frame;RenderingServer.force_draw(false,1.0/60)
	var img=root.get_texture().get_image();img.save_png(output_dir.path_join(name+".png"));return img
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):output_dir=arg.trim_prefix("--output-dir=")
	game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false)
	game.speed=0;game.set_panorama(true)
	var v=game.visual
	game.model.prepare_render_frame();v.queue_render(game.model.render_frame)
	for i in 16:v.apply_render_stage()
	for i in 90:await process_frame
	var p=Vector2(45,70);var initial=surface(p);v.capture_edits();var state=game.model.snapshot()
	for i in 30:v.edit(Vector3(p.x,surface(p),p.y),12,0,false,1.0/3.0)
	var old_rise=surface(p)-initial
	game.restore_edit(state)
	game.radius=12;game.selected_tool=0;game.drawing=1;game.brush_strength=1;game.stamp_mode=false
	for i in 30:
		game.hover=Vector3(p.x,surface(p),p.y);game.apply_brush()
	var new_rise=surface(p)-initial;game.drawing=0
	var prior=game.sound.effect_index
	game.sound.last_effect=-1000
	for i in 100:game.sound.effect("earth")
	var throttled=game.sound.effect_index-prior==1
	v.target_focus=Vector3(0,40,0);v.target_distance=520;v.target_pitch=.42;v.target_yaw=.55
	v.set_night(true)
	for i in 240:v.animate(1.0/30);await process_frame
	var new_img=await shot("night-moonlight")
	var new_mean=image_mean(new_img)
	var moon_ok=v.moon.light_energy>.6 and v.moon_disc.visible
	# Reconstruct v0.3.2 illumination for a same-camera comparison.
	v.moon.light_energy=0;v.moon_disc.visible=false
	v.environment.environment.ambient_light_energy=.22;v.sun.light_energy=.12
	var old_img=await shot("night-previous");var old_mean=image_mean(old_img)
	var rise_ok=new_rise>old_rise*1.8 and new_rise>2
	var light_ok=new_mean>old_mean*1.15
	v.target_pitch=.15;v.target_yaw=deg_to_rad(v.moon.rotation_degrees.y)-PI
	for i in 120:v.animate(1.0/30);await process_frame
	var moon_pixel=v.camera.unproject_position(v.moon_disc.position)
	var visible_moon=root.get_visible_rect().has_point(moon_pixel) and not v.camera.is_position_behind(v.moon_disc.position)
	await shot("night-visible-moon")
	print("COMFORT_TEST old_rise=",old_rise," new_rise=",new_rise," rise=",rise_ok," throttled=",throttled," moon=",moon_ok," old_luma=",old_mean," new_luma=",new_mean," night_readable=",light_ok," moon_in_view=",visible_moon)
	quit(0 if rise_ok and throttled and moon_ok and light_ok and visible_moon else 1)
