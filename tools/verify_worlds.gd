extends SceneTree
var game
func _initialize():call_deferred("run")
func create_world(seed_value:int):
	game.show_new_island()
	for control in game.content.get_children():
		if control is LineEdit:control.text=str(seed_value)
	for control in game.content.get_children():
		if control is Button and control.text=="让小岛生长":control.pressed.emit();break
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.speed=0
	game.save_path="user://world_manager_validation.save"
	game.started=true;game.model.reset(111);game.visual.model=game.model;game.visual.rebuild_terrain()
	game.records=[]
	var edited=Vector3(320,200,80);game.visual.edit(edited,8,0,false,1,true);game.save_game()
	create_world(222)
	var archived=game.records.size()==1 and game.records[0].world.seed==111 and not game.records[0].world.terrain_blocks.is_empty()
	# Simulate returning after application restart, before pressing Continue.
	game.started=false;game.records=[];game.model.reset(260104);game.show_home()
	create_world(333)
	var restart_preserved=game.records.size()==2 and game.records[0].world.seed==111 and game.records[1].world.seed==222
	game.open_record(0)
	var switched=game.started and not game.home_visible and game.model.world_seed==111 and game.records.size()==2 and game.records[1].world.seed==333
	var geometry=game.visual.terrain.get_voxel_tool().get_voxel_f(Vector3i(edited))<0
	var data=game.read_bundle()
	var saved=data.world.seed==111 and data.records.size()==2
	game.started=false;game.records=[];game.show_home();game.show_records()
	var count=game.records.size();game.confirm_delete_record(0);game.show_records()
	var cancel_ok=game.records.size()==count
	game.confirm_delete_record(0)
	var confirmation=false
	for row in game.content.get_children():
		if not row is HBoxContainer:continue
		for control in row.get_children():
			if control is Button and control.text=="删除这座世界":control.pressed.emit();confirmation=true;break
	data=game.read_bundle()
	var deleted=confirmation and data.records.size()==count-1 and data.world.seed==111 and game.model.world_seed==111
	game.show_records()
	var reload=game.records.size()==count-1
	for i in 90:game.visual.animate(1.0/30);await process_frame
	await process_frame;RenderingServer.force_draw(false,1.0/60)
	root.get_texture().get_image().save_png("F:/微光盆地/开发验证/world-manager.png")
	game.close_popup();await process_frame;RenderingServer.force_draw(false,1.0/60)
	root.get_texture().get_image().save_png("F:/微光盆地/开发验证/home-worlds.png")
	print("WORLD_MANAGER_TEST archived=",archived," restart_preserved=",restart_preserved," switched=",switched," geometry=",geometry," saved=",saved," cancel=",cancel_ok," deleted=",deleted," reload=",reload)
	quit(0 if archived and restart_preserved and switched and geometry and saved and cancel_ok and deleted and reload else 1)
