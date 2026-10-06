extends RefCounted
# Native graph execution avoids per-voxel GDScript work.
static func expression(fn: VoxelGraphFunction, code: String, names: PackedStringArray, sources: Array) -> int:
	var id = fn.create_node(VoxelGraphFunction.NODE_EXPRESSION,Vector2.ZERO)
	fn.set_node_param(id,0,code); fn.set_expression_node_inputs(id,names)
	for i in sources.size(): fn.add_connection(sources[i],0,id,i)
	return id

static func shifted(axis:String,value:float) -> String:
	return "%s%s%f" % [axis,"+" if value<0 else "-",absf(value)]

static func create(model) -> VoxelGeneratorGraph:
	var gen = VoxelGeneratorGraph.new(); var fn = gen.get_main_function()
	var x = fn.create_node(VoxelGraphFunction.NODE_INPUT_X,Vector2.ZERO)
	var y = fn.create_node(VoxelGraphFunction.NODE_INPUT_Y,Vector2.ZERO)
	var z = fn.create_node(VoxelGraphFunction.NODE_INPUT_Z,Vector2.ZERO)
	var px = expression(fn,"clamp((x+512)*0.125,0,126.999)",["x"],[x])
	var pz = expression(fn,"clamp((z+512)*0.125,0,126.999)",["z"],[z])
	var image = Image.create_from_data(128,128,false,Image.FORMAT_RF,model.base_heights.to_byte_array())
	var image_node = fn.create_node(VoxelGraphFunction.NODE_IMAGE_2D,Vector2.ZERO)
	fn.set_node_param(image_node,0,image); fn.set_node_param(image_node,1,1)
	fn.add_connection(px,0,image_node,0); fn.add_connection(pz,0,image_node,1)
	var base = expression(fn,"max((y-h)*0.8,0-y-48)",["y","h"],[y,image_node])
	var arch_p=model.layout_point(Vector2(120,-65))
	var arch_h = model.height_at(arch_p,true)+19
	var ax = expression(fn,"%s+sin(z*0.14)*1.1" % shifted("x",arch_p.x),["x","z"],[x,z])
	var ay = expression(fn,"(%s)*1.1+sin(x*0.12)*1.4" % shifted("y",arch_h),["x","y"],[x,y])
	var az = expression(fn,"%s+sin(x*0.075)*2" % shifted("z",arch_p.y),["x","z"],[x,z])
	var arch = expression(fn,"sqrt((sqrt(a*a+b*b)-26)*(sqrt(a*a+b*b)-26)+c*c)-8+sin(a*0.16+c*0.09)*1.4",["a","b","c"],[ax,ay,az])
	var land = expression(fn,"min(a,b)",["a","b"],[base,arch])
	var cave_p=model.layout_point(Vector2(-100,-65))
	var cave_h = model.height_at(cave_p,true)-12
	var cx=shifted("x",cave_p.x);var cy=shifted("y",cave_h);var cz=shifted("z",cave_p.y)
	var cave = expression(fn,"max(sqrt((%s)*(%s)+(%s)*(%s))-13,abs(%s)-52)" % [cx,cx,cy,cy,cz],["x","y","z"],[x,y,z])
	var sdf = expression(fn,"max(a,0-b)",["a","b"],[land,cave])
	var output = fn.create_node(VoxelGraphFunction.NODE_OUTPUT_SDF,Vector2.ZERO)
	fn.add_connection(sdf,0,output,0)
	var result = gen.compile()
	if not result.get("success",false): push_error("Voxel graph compile: "+str(result))
	return gen
