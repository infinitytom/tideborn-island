extends SceneTree
# Real voxel tools and undo API; deterministic shooting without touching player saves.
const FPS=30
const DURATION=36
var game
var output_dir:String
var pilot=false
var arch_only=false
var actions:Array=[]
var arch_height=0.0
var stamps=[Vector3(238,90,80),Vector3(254,108,80),Vector3(273,124,80),Vector3(292,134,80),Vector3(318,140,80),Vector3(346,140,80),Vector3(330,150,68),Vector3(330,150,92)]
var radii=[17,17,17,17,25,25,22,22]
func _initialize(): call_deferred("capture")
func action(kind:String,t:float):
	actions.append({"kind":kind,"time":t}); print("ACTION ",kind," ",t)
func upload():
	game.model.prepare_render_frame(); game.visual.queue_render(game.model.render_frame)
	for i in 16: game.visual.apply_render_stage()
func pose(p:Vector3,d:float,pitch:float,yaw:float,cut=false):
	var v=game.visual
	v.target_focus=p; v.target_distance=d; v.target_pitch=pitch; v.target_yaw=yaw
	if cut: v.focus=p; v.distance=d; v.pitch=pitch; v.yaw=yaw
	v.update_camera(1.0/30)
func settle(frames=90):
	for i in frames:
		game.visual.animate(1.0/FPS,false)
		await process_frame
func capture():
	pilot=OS.get_cmdline_user_args().has("--pilot")
	arch_only=OS.get_cmdline_user_args().has("--arch-only")
	game=load("res://main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.speed=0; game.set_panorama(true)
	output_dir=ProjectSettings.globalize_path("res://../media_work/frames_v2")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game.model.elapsed=40; game.model.creative=true; game.visual.preview_clock=40
	# Clear foreground foliage in this filming world so the arch edits stay visible.
	game.model.paint_plants(Vector2(120,-65),200,-1)
	upload(); await settle()
	var v=game.visual; v.last_normal=Vector3.ZERO
	v.edit(Vector3(260,0,80),48,0,false,1,true)
	v.edit(Vector3(260,32,80),48,0,false,1,true)
	arch_height=game.model.height_at(Vector2(120,-65),true)+19
	pose(Vector3(260,38,80),190,.12,0,true); await settle()
	if arch_only:
		for z in range(27,136,9): v.edit(Vector3(260,38,z),17,1)
	for frame in range(210 if arch_only else 0,420 if arch_only else FPS*DURATION):
		var t=float(frame)/FPS
		v.last_normal=Vector3.ZERO
		v.brush_ball.visible=false; v.cursor.visible=false
		if t<7:
			pose(Vector3(260,38,80),190,.12,maxf(0,t-5)*.10)
			if frame>=30 and frame<=138 and (frame-30)%9==0:
				var p=Vector3(260,38,135-(frame-30)/9*9)
				v.edit(p,17,1); v.set_cursor(p,17,true)
				action("cut",t)
			if frame>=30 and frame<155: v.set_cursor(Vector3(260,38,135-minf(108,frame-30)),17,true)
		elif t<14:
			if frame==210:
				pose(Vector3(120,arch_height+10,-65),140,.18,.12,true)
				game.remember_edit()
			pose(Vector3(120,arch_height+10,-65),140,.18,.12)
			if frame>=255 and frame<=315 and (frame-255)%10==0:
				var p=Vector3(102+(frame-255)/10*6,arch_height+24,-65)
				v.edit(p,12,1); action("cut",t)
			if frame>=255 and frame<325: v.set_cursor(Vector3(102+minf(36,(frame-255)*.6),arch_height+24,-65),12,true)
			if frame==366:
				game.undo_edit(); upload(); await settle(90)
				action("click",t)
		elif t<25:
			if frame==420: pose(Vector3(290,105,80),270,.24,.40,true)
			pose(Vector3(290,105,80),270,.24,.40)
			for i in stamps.size():
				if frame==444+i*25:
					v.edit(stamps[i],radii[i],0,false,1,true)
					action("earth",t)
				if frame>=444+i*25 and frame<455+i*25: v.set_cursor(stamps[i],radii[i],true)
			if frame==690:
				v.edit(Vector3(282,124,80),25,1)
				action("cut",t)
			if frame>=690 and frame<708: v.set_cursor(Vector3(282,124,80),25,true)
		elif t<31:
			if frame==750:
				v.sync_surface(Vector2(330,80),65)
				pose(Vector3(290,110,80),285,.3,.40,true)
			if frame==777:
				game.model.paint_plants(Vector2(330,80),25,9); upload(); action("seed",t)
			if frame==807:
				game.model.paint_plants(Vector2(350,90),13,6); upload(); action("seed",t)
			if frame==837:
				game.model.paint_plants(Vector2(252,80),20,7); upload(); action("seed",t)
			pose(Vector3(290,110,80),285,.3,.40+(t-25)*.018)
			if frame==915:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../media_work/cover-scene.png"))
		else:
			if frame==930: pose(Vector3(205,76,25),510,.33,.65,true)
			pose(Vector3(205,76,25),510+(t-31)*3,.33,.65+(t-31)*.025)
		v.animate(1.0/FPS,false)
		await process_frame; await RenderingServer.frame_post_draw
		if not pilot or frame%30==0:
			var im=root.get_texture().get_image()
			var name="pilot_%02d.png" % int(t) if pilot else "frame_%05d.png" % frame
			if im.save_png(output_dir.path_join(name))!=OK: quit(1); return
		if frame%150==0: print("PROMO_FRAMES ",frame,"/",FPS*DURATION)
	print("PROMO_CAPTURE complete=",210 if arch_only else FPS*DURATION," fps=",FPS," duration=",7 if arch_only else DURATION)
	if arch_only: quit(); return
	var events=FileAccess.open(ProjectSettings.globalize_path("res://../media_work/actions.json"),FileAccess.WRITE)
	events.store_string(JSON.stringify(actions,"\t")); events.close()
	root.size=Vector2i(1920,1080)
	pose(Vector3(275,105,70),360,.28,.45,true); await settle(60)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../media_work/cover-scene.png"))
	quit()
