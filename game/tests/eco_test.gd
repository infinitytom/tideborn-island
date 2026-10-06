extends SceneTree
const Model = preload("res://scripts/eco_model.gd")
var failures: int = 0
func check(value: bool, message: String):
	if value: print("PASS ",message)
	else: push_error(message); failures += 1
func _initialize():
	var a = Model.new(); a.reset(260104)
	var b = Model.new(); b.reset(260104)
	check(a.heights==b.heights and a.species==b.species,"seed reproduces island and communities")
	check(a.heights.size()==16384 and a.heights[0]<-20 and a.heights[Model.COUNT-1]<-20,"1024 m island domain has submerged natural borders")
	var soil = a.moisture.duplicate(); var water = a.water.duplicate(); var canopy = a.canopy.duplicate()
	a.scatter(Vector2(0,40),48,3)
	check(a.moisture==soil and a.water==water and a.canopy==canopy,"seed selection does not alter habitat conditions")
	var dry = a.index_at(Vector2(180,50)); a.water[dry]=0; a.moisture[dry]=0.2; a.seed_set[dry]=3
	check(a.choose_species(dry)==-1,"wetland seeds cannot grow in dry soil")
	b.restore(a.snapshot())
	for k in 24: a.step(0.25); b.step(0.25)
	check(a.water==b.water and a.moisture==b.moisture and a.species==b.species,"fixed steps remain deterministic")
	check(a.vapor==b.vapor and a.plankton==b.plankton and a.fish_population==b.fish_population,"atmosphere and marine cycle survive save and restore")
	var valid = true
	for i in Model.COUNT:
		if not is_finite(a.water[i]) or a.water[i]<0 or a.moisture[i]<0 or a.moisture[i]>1: valid=false
	check(valid,"water and soil stay finite and bounded")
	var wet = Model.new(); wet.restore(a.snapshot()); var sunny = Model.new(); sunny.restore(a.snapshot())
	wet.weather_mode=2; sunny.weather_mode=1
	for k in 32: wet.step(0.25); sunny.step(0.25)
	var wet_soil=0.0; var dry_soil=0.0
	for i in Model.COUNT:
		if wet.heights[i]>1: wet_soil+=wet.moisture[i]; dry_soil+=sunny.moisture[i]
	check(wet_soil>dry_soil,"rain feeds land moisture")
	check(wet.vapor<sunny.vapor,"rain consumes atmospheric vapor")
	a.prepare_render_frame()
	check(a.render_frame.depths.size()==Model.COUNT*4,"water shoreline receives continuous depth field")
	check(a.render_frame.water[Mesh.ARRAY_VERTEX].size()==a.render_frame.water[Mesh.ARRAY_NORMAL].size(),"water mesh has complete smooth normals")
	var gen=load("res://scripts/native_terrain.gd").create(a)
	check(gen.compile().get("success",false),"native smooth voxel graph compiles")
	print("ECO_TEST failures=",failures)
	quit(0 if failures==0 else 1)
