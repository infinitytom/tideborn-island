extends SceneTree
var game
var output_dir: String
func _initialize():
	call_deferred("capture")
func upload():
	game.model.prepare_render_frame(); game.visual.queue_render(game.model.render_frame)
	for i in 16: game.visual.apply_render_stage()
func camera_pose(focus: Vector3, distance: float, pitch: float, yaw: float):
	var v=game.visual; v.target_focus=focus; v.target_distance=distance; v.target_pitch=pitch; v.target_yaw=yaw
func capture():
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.speed=0
	output_dir=ProjectSettings.globalize_path("res://../media_work/frames")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game.set_panorama(true); upload()
	await create_timer(4.0).timeout
	for frame in 960:
		var t=float(frame)/30.0; var v=game.visual
		if frame==0: print("PROMO establishing")
		if t<5:
			game.model.elapsed=40; v.preview_clock=40
			camera_pose(Vector3(0,24,0),780-t*12,0.52,0.52+t*0.045)
		elif t<11:
			if frame==150: print("PROMO terrain shaping")
			v.preview_clock=40
			camera_pose(Vector3(175,15,50),420,0.52,-0.4+(t-5)*0.035)
			if frame%6==0:
				var p=Vector2(220+(t-5)*12,45+sin((t-5)*0.65)*25)
				v.edit(Vector3(p.x,0,p.y),23,0)
				v.sync_surface(p,27); upload()
		elif t<16:
			if frame==330: print("PROMO planting")
			game.model.creative=true
			camera_pose(Vector3(70,22,-20),370,0.52,1.1+(t-11)*0.03)
			if frame%15==0:
				var p=Vector2(35+(t-11)*17,-10+sin((t-11))*24)
				game.model.paint_plants(p,16,9 if frame%30==0 else 6); upload()
		elif t<22:
			if frame==480: print("PROMO autumn and snow")
			game.model.elapsed=640 if t<19 else 940
			v.preview_clock=40
			camera_pose(Vector3(0,24,0),750,0.5,0.62+(t-16)*0.035)
		elif t<27:
			if frame==660: print("PROMO cave and dusk")
			game.model.elapsed=40; v.preview_clock=78+(t-22)*8
			camera_pose(Vector3(120,45,-65),220+(t-22)*13,0.32,1.18+(t-22)*0.045)
		else:
			if frame==810: print("PROMO panorama finale")
			game.model.elapsed=40; v.preview_clock=40
			camera_pose(Vector3(0,25,0),770+(t-27)*9,0.4,0.58+(t-27)*0.025)
		v.animate(1.0/30.0,false)
		await process_frame; await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		if image.save_png(output_dir.path_join("frame_%05d.png" % frame))!=OK: quit(1); return
		if frame%150==0: print("PROMO_FRAMES ",frame,"/960")
	print("PROMO_CAPTURE complete=960 fps=30 duration=32")
	quit()
