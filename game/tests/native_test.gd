extends SceneTree
func _initialize():
	var model = load("res://scripts/eco_model.gd").new(); model.reset(260104)
	var gen = load("res://scripts/native_terrain.gd").create(model)
	var buffer = VoxelBuffer.new(); buffer.create(16,16,16)
	gen.generate_block(buffer,Vector3i(-8,20,-8),0)
	print("NATIVE_COMPILE ",gen.compile()," sample=",buffer.get_voxel_f(8,0,8,VoxelBuffer.CHANNEL_SDF)," plants=",model.plant_count)
	quit()
