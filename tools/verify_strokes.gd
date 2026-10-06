extends SceneTree
var game
func _initialize():call_deferred("run")
func region() -> PackedByteArray:
	var buffer=VoxelBuffer.new();buffer.create(80,80,80)
	game.visual.terrain.get_voxel_tool().copy(Vector3i(280,200,40),buffer,VoxelBuffer.CHANNEL_SDF_BIT,false)
	return buffer.get_channel_as_byte_array(VoxelBuffer.CHANNEL_SDF)
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.speed=0;game.enter_world()
	var v=game.visual;v.natural_edges=false;v.capture_edits();var original=game.model.snapshot()
	var p=Vector3(320,240,80)
	v.edit(p,24,0,false,1,true);var smooth=region()
	game.restore_edit(original);v.natural_edges=true;v.edit(p,24,0,false,1,true)
	var rough=region();var noise_add=rough!=smooth
	game.restore_edit(original);v.natural_edges=false;v.edit(p,35,0,false,1,true)
	v.capture_edits();var ball=game.model.snapshot();var before_cut=region()
	var cut=p+Vector3.UP*24;v.last_normal=Vector3.UP;v.edit(cut,18,1,true)
	var smooth_cut=region()
	game.restore_edit(ball);v.natural_edges=true;game.remember_edit();v.last_normal=Vector3.UP;v.edit(cut,18,1,true)
	var rough_cut=region();var noise_cut=rough_cut!=smooth_cut
	game.undo_edit();var undo=region()==before_cut
	game.redo_edit();var redo=region()==rough_cut
	game.save_game();var saved=game.read_bundle();game.model.restore(saved.world);v.model=game.model;v.rebuild_terrain()
	var restored=region()==rough_cut
	game.restore_edit(original);v.natural_edges=false
	var rises=[]
	for step in [.05,.10]:
		game.restore_edit(original);game.raise_active=false;game.stroke_last=Vector3(9999,9999,9999)
		game.selected_tool=0;game.radius=12;game.drawing=1;game.brush_strength=1;game.stamp_mode=false
		for i in int(3.0/step):game.hover=p;game.apply_brush(step,Vector2.ZERO)
		var hit=v.terrain.get_voxel_tool().raycast(Vector3(p.x,959,p.z),Vector3.DOWN,1022)
		rises.append(959-hit.distance-p.y)
	var timing=absf(rises[0]-rises[1])<1 and rises[0]>65
	print("STROKE_TEST noise_add=",noise_add," noise_cut=",noise_cut," undo=",undo," redo=",redo," restored=",restored," time_independent=",timing," rises=",rises)
	quit(0 if noise_add and noise_cut and undo and redo and restored and timing else 1)
