extends SceneTree
# Scripted filming uses the same spherical edits, planting and undo as the game.
const FPS=30
const DURATION=49
var game
var pilot=false
var start_frame=0
var actions:Array=[]
var arch_height=0.0
var wild_state:Dictionary
var built_state:Dictionary
var deer:Dictionary
var fox:Dictionary
var output_dir:String
func _initialize():call_deferred("capture")
func action(kind:String,t:float):actions.append({"kind":kind,"time":t})
func upload():
	game.model.prepare_render_frame();game.visual.queue_render(game.model.render_frame)
	for i in 16:game.visual.apply_render_stage()
func pose(p:Vector3,d:float,pitch:float,yaw:float,cut=false):
	var v=game.visual
	v.target_focus=p;v.target_distance=d;v.target_pitch=pitch;v.target_yaw=yaw
	if cut:v.focus=p;v.distance=d;v.pitch=pitch;v.yaw=yaw
	v.update_camera(1.0/FPS)
func settle(frames=90):
	for i in frames:
		game.visual.animate(1.0/FPS,false);await process_frame
func capture():
	pilot=OS.get_cmdline_user_args().has("--pilot")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start-frame="):start_frame=int(arg.trim_prefix("--start-frame="))
	game=load("res://main.tscn").instantiate();root.add_child(game)
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	game.set_process(false);game.speed=0;game.set_panorama(true)
	output_dir=ProjectSettings.globalize_path("res://../media_work/frames_v3")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game.model.elapsed=40;game.model.creative=true;game.visual.preview_clock=40
	wild_state=game.model.snapshot()
	game.model.paint_plants(Vector2(120,-65),200,-1)
	upload();await settle()
	var v=game.visual;v.last_normal=Vector3.ZERO
	v.edit(Vector3(260,0,80),48,0,false,1,true)
	v.edit(Vector3(260,32,80),48,0,false,1,true)
	arch_height=game.model.height_at(Vector2(120,-65),true)+19
	pose(Vector3(260,48,80),215,.90,.4,true);await settle()
	for frame in FPS*DURATION:
		var t=float(frame)/FPS
		v.last_normal=Vector3.ZERO;v.brush_ball.visible=false;v.cursor.visible=false
		if t<6:
			pose(Vector3(260,48,80),215,.90,.4)
			if frame>=24 and frame<=144 and (frame-24)%4==0:
				var u=float(frame-24)/120
				var x=220+u*80;var z=80+sin(u*TAU)*12
				var y=32+sqrt(maxf(0,48*48-pow(x-260,2)-pow(z-80,2)))-3
				v.edit(Vector3(x,y,z),7,1)
				if frame%12==0:action("cut",t)
		elif t<12:
			if frame==180:pose(Vector3(260,38,80),190,.12,0,true)
			pose(Vector3(260,38,80),190,.12,maxf(0,t-10)*.1)
			if frame>=210 and frame<=318 and (frame-210)%9==0:
				var p=Vector3(260,38,135-(frame-210)/9*9)
				v.edit(p,17,1);action("cut",t)
		elif t<18:
			if frame==360:
				pose(Vector3(120,arch_height+10,-65),140,.18,.12,true)
				game.remember_edit()
			pose(Vector3(120,arch_height+10,-65),140,.18,.12)
			if frame>=390 and frame<=450 and (frame-390)%10==0:
				v.edit(Vector3(102+(frame-390)/10*6,arch_height+24,-65),12,1);action("cut",t)
			if frame==492:
				game.undo_edit();upload();await settle();action("click",t)
		elif t<29:
			if frame==540:pose(Vector3(298,108,80),280,.42,.40,true)
			pose(Vector3(298,108,80),280,.42,.40)
			if frame>=564 and frame<=744 and (frame-564)%5==0:
				var u=float(frame-564)/180
				var p=Vector3(232+u*116,70+u*68,80+sin(u*PI)*18)
				v.edit(p,9,0,false,1,true)
				if frame%15==9:action("earth",t)
			if frame==755:v.edit(Vector3(348,145,80),25,0,false,1,true);action("earth",t)
			if frame==775:v.edit(Vector3(370,145,80),23,0,false,1,true);action("earth",t)
			if frame==802:
				v.edit(Vector3(306,113,98),16,1);action("cut",t)
		elif t<34:
			if frame==870:
				v.sync_surface(Vector2(355,80),55)
				pose(Vector3(302,106,80),310,.4,.40,true)
			if frame==894:game.model.paint_plants(Vector2(351,80),21,9);upload();action("seed",t)
			if frame==924:game.model.paint_plants(Vector2(370,91),12,6);upload();action("seed",t)
			pose(Vector3(302,106,80),310,.4,.40+(t-29)*.03)
		elif t<39:
			if frame==1020:
				v.capture_edits();built_state=game.model.snapshot()
				game.restore_edit(wild_state);upload();await settle()
				v.preview_clock=40
				for data in v.walkers:
					if data.kind=="鹿" and deer.is_empty():deer=data
					if data.kind=="狐狸" and fox.is_empty():fox=data
				if deer.is_empty() or fox.is_empty():push_error("Missing wildlife in filming world");quit(1);return
				game.model.paint_plants(deer.home,45,-1);game.model.paint_plants(fox.home,45,-1);upload()
				v.phase=8
				pose(deer.node.position+Vector3.UP*3,30,.5,.75,true)
			pose(deer.node.position+Vector3.UP*3,30,.5,.75)
		elif t<44:
			if frame==1170:pose(fox.node.position+Vector3.UP*1.5,23,.85,.9,true)
			pose(fox.node.position+Vector3.UP*1.5,23,.85,.9)
		else:
			if frame==1320:
				game.restore_edit(built_state);upload();await settle()
				v.preview_clock=40
				pose(Vector3(210,80,30),545,.35,.65,true)
			pose(Vector3(210,80,30),545+(t-44)*3,.35,.65+(t-44)*.025)
		v.animate(1.0/FPS,false)
		await process_frame
		# Explicit drawing keeps capture progressing even when another window covers it.
		RenderingServer.force_draw(false,1.0/FPS)
		if frame>=start_frame and (not pilot or frame%30==0):
			var name="pilot_%02d.png"%int(t) if pilot else "frame_%05d.png"%frame
			if root.get_texture().get_image().save_png(output_dir.path_join(name))!=OK:quit(1);return
		if frame%150==0:print("PROMO_FRAMES ",frame,"/",FPS*DURATION)
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../media_work/actions.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(actions,"\t"));file.close()
	root.size=Vector2i(1920,1080)
	pose(Vector3(285,109,77),375,.4,.45,true);await settle(60)
	RenderingServer.force_draw(false,1.0/FPS)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../media_work/cover-scene.png"))
	print("PROMO_CAPTURE complete=",FPS*DURATION," duration=",DURATION)
	quit()
