extends Node3D
const TerrainFactory = preload("res://scripts/native_terrain.gd")
var model
var terrain: VoxelLodTerrain
var camera: Camera3D
var sun: DirectionalLight3D
var environment: WorldEnvironment
var ocean: MeshInstance3D
var lake: MeshInstance3D
var terrain_material: ShaderMaterial
var ocean_material: ShaderMaterial
var lake_material: ShaderMaterial
var field_texture: ImageTexture
var height_texture: ImageTexture
var water_texture: ImageTexture
var plant_nodes: Array = []
var props: Node3D
var source_markers: Node3D
var source_signature: String = ""
var flying: Array = []
var clouds: MultiMeshInstance3D
var rain: MultiMeshInstance3D
var cursor: MeshInstance3D
var brush_ball: MeshInstance3D
var dirty_blocks: Dictionary = {}
var yaw: float = 0.55
var pitch: float = 0.62
var distance: float = 620
var focus = Vector3(0,25,0)
var target_yaw: float = 0.55
var target_pitch: float = 0.62
var target_distance: float = 620
var target_focus = Vector3(0,25,0)
var phase: float = 0
var night: bool = false
var render_pending: Dictionary = {}
var render_stage: int = -1
var last_season: int = -1
var last_pick_screen = Vector2(-999,-999)
var last_pick_transform = Transform3D()
var last_pick = Vector3(9999,9999,9999)
var last_normal = Vector3.UP
var terrain_revision: int = 0
var picked_revision: int = -1
const TOP = 960.0
const BOTTOM = -64.0
var daylight: float = 1.0
var preview_clock: float = -1.0
var season_weights = Vector4(1,0,0,0)

func material(c: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new(); mat.albedo_color = c; mat.roughness = 0.85
	return mat

func sphere(radius: float, height: float = -1) -> SphereMesh:
	var mesh = SphereMesh.new(); mesh.radius = radius; mesh.height = height if height>0 else radius*2
	mesh.radial_segments = 12; mesh.rings = 6
	return mesh

func cylinder(top: float, bottom: float, h: float, sides: int = 12) -> CylinderMesh:
	var mesh = CylinderMesh.new(); mesh.top_radius = top; mesh.bottom_radius = bottom; mesh.height = h; mesh.radial_segments = sides
	return mesh

func piece(mesh: Mesh, mat: Material, p: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mi = MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position = p; parent.add_child(mi); return mi

func setup(m):
	model = m
	environment = WorldEnvironment.new()
	var e = Environment.new(); e.background_mode = Environment.BG_SKY
	var sky = Sky.new(); var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("8ab7cc"); sky_mat.sky_horizon_color = Color("dce5dc")
	sky_mat.ground_bottom_color = Color("617e88"); sky_mat.ground_horizon_color = Color("dce5dc")
	sky_mat.sun_angle_max = 12; sky.sky_material = sky_mat
	e.sky = sky; e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b4cfcc"); e.ambient_light_energy = 0.38
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.fog_enabled = true; e.fog_light_color = Color("b6cbd0"); e.fog_density = 0.00018
	environment.environment = e; add_child(environment)
	sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_color = Color("ffeace"); sun.light_energy = 1.12
	sun.shadow_enabled = true; sun.directional_shadow_max_distance = 850
	add_child(sun)
	camera = Camera3D.new(); camera.fov = 48; camera.near = 0.3; camera.far = 18000
	add_child(camera); camera.current = true
	var viewer = VoxelViewer.new(); viewer.view_distance = 2600; viewer.requires_collisions = false
	camera.add_child(viewer); update_camera(1.0)
	field_texture = ImageTexture.create_from_image(Image.create(128,128,false,Image.FORMAT_RGBA8))
	height_texture = ImageTexture.create_from_image(Image.create_from_data(128,128,false,Image.FORMAT_RF,model.heights.to_byte_array()))
	water_texture = ImageTexture.create_from_image(Image.create_from_data(128,128,false,Image.FORMAT_RF,model.water.to_byte_array()))
	terrain_material = ShaderMaterial.new(); terrain_material.shader = load("res://shaders/natural_ground.gdshader")
	terrain_material.set_shader_parameter("fields",field_texture)
	ocean_material = ShaderMaterial.new(); ocean_material.shader = load("res://shaders/smooth_water.gdshader")
	ocean_material.set_shader_parameter("heightmap",height_texture)
	var plane = PlaneMesh.new(); plane.size = Vector2(18000,18000); plane.subdivide_width = 100; plane.subdivide_depth = 100
	ocean = piece(plane,ocean_material,Vector3.ZERO); ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lake_material = ShaderMaterial.new(); lake_material.shader = ocean_material.shader
	lake_material.set_shader_parameter("heightmap",height_texture); lake_material.set_shader_parameter("lake",true)
	lake_material.set_shader_parameter("watermap",water_texture)
	lake = MeshInstance3D.new(); lake.material_override = lake_material
	lake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(lake)
	props = Node3D.new(); add_child(props)
	source_markers = Node3D.new(); add_child(source_markers)
	for k in 12:
		var mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = false
		mm.mesh = make_plant(k,model.COLORS[k])
		var node = MultiMeshInstance3D.new(); node.multimesh = mm
		var mat = ShaderMaterial.new(); mat.shader = load("res://shaders/vegetation.gdshader")
		mat.set_shader_parameter("woody",k>=7)
		mat.set_shader_parameter("deciduous",k>=7 and k<11)
		mat.set_shader_parameter("kind",k)
		node.material_override = mat
		if k<7: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node); plant_nodes.append(node)
	var cursor_mat = material(Color("ffef9c")); cursor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor = piece(make_ring(10,0.42),cursor_mat,Vector3.ZERO)
	cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; cursor.visible = false
	var brush_mat = StandardMaterial3D.new(); brush_mat.albedo_color = Color(0.92,0.95,0.85,0.13)
	brush_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; brush_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	brush_ball = piece(sphere(1),brush_mat,Vector3.ZERO); brush_ball.visible = false
	make_atmosphere()
	rebuild_terrain()
	queue_render(model.render_frame)
	refresh_animals()
	refresh_sources()

func rebuild_terrain():
	if is_instance_valid(terrain): terrain.free()
	dirty_blocks = {}
	terrain = VoxelLodTerrain.new(); terrain.name = "VolumetricIsland"
	terrain.voxel_bounds = AABB(Vector3(-512,BOTTOM,-512),Vector3(1024,TOP-BOTTOM,1024))
	terrain.lod_count = 6; terrain.lod_distance = 48; terrain.secondary_lod_distance = 64
	terrain.view_distance = 2600; terrain.mesh_block_size = 16
	terrain.full_load_mode_enabled = true; terrain.generate_collisions = false
	terrain.generator = TerrainFactory.create(model); terrain.mesher = VoxelMesherTransvoxel.new()
	terrain.material = terrain_material; add_child(terrain)
	var tool = terrain.get_voxel_tool(); tool.channel = VoxelBuffer.CHANNEL_SDF
	tool.set_raycast_normal_enabled(true)
	for origin in model.terrain_blocks:
		var b = VoxelBuffer.new(); b.create(32,32,32)
		b.set_channel_from_byte_array(VoxelBuffer.CHANNEL_SDF,model.terrain_blocks[origin])
		tool.paste(origin,b,VoxelBuffer.CHANNEL_SDF_BIT)
	terrain_revision += 1

func pick(screen: Vector2) -> Vector3:
	if screen == last_pick_screen and camera.global_transform == last_pick_transform and picked_revision == terrain_revision: return last_pick
	last_pick_screen = screen; last_pick_transform = camera.global_transform; picked_revision = terrain_revision
	var origin = camera.project_ray_origin(screen); var dir = camera.project_ray_normal(screen)
	var hit = terrain.get_voxel_tool().raycast(origin,dir,2500)
	var sea_dist = -origin.y/dir.y if dir.y < -0.0001 else 99999.0
	last_pick = Vector3(9999,9999,9999); last_normal = Vector3.UP
	if hit != null:
		last_pick = origin+dir*hit.distance; last_normal = hit.normal
		if last_normal.length()<0.5: last_normal = Vector3.UP
	if sea_dist>0 and sea_dist<2500 and (hit == null or sea_dist<hit.distance):
		last_pick = origin+dir*sea_dist; last_normal = Vector3.UP
	if absf(last_pick.x)>490 or absf(last_pick.z)>490: last_pick = Vector3(9999,9999,9999)
	return last_pick

func pick_plane(screen: Vector2, altitude: float) -> Vector3:
	var origin = camera.project_ray_origin(screen); var dir = camera.project_ray_normal(screen)
	if absf(dir.y)<0.0001: return Vector3(9999,9999,9999)
	var t = (altitude-origin.y)/dir.y
	if t<0 or t>4000: return Vector3(9999,9999,9999)
	var p = origin+dir*t
	if absf(p.x)>490 or absf(p.z)>490: return Vector3(9999,9999,9999)
	return p

func edit(p: Vector3, radius: float, tool_kind: int, remove: bool = false, strength: float = 1.0, stamp: bool = false) -> bool:
	if absf(p.x)+radius>504 or absf(p.z)+radius>504 or p.y+radius>TOP-8 or p.y-radius<BOTTOM+8: return false
	var center = p
	var tool = terrain.get_voxel_tool(); tool.channel = VoxelBuffer.CHANNEL_SDF
	if tool_kind==0 and not remove:
		if stamp:
			tool.mode = VoxelTool.MODE_ADD; tool.sdf_strength = 1.0; tool.do_sphere(p,radius)
		elif p.y<0.3:
			center.y = -radius*0.6
			tool.mode = VoxelTool.MODE_ADD; tool.sdf_strength = 1.0
			tool.do_sphere(center,radius)
		else: tool.grow_sphere(p,radius,0.8*strength)
	elif tool_kind==2:
		tool.smooth_sphere(p,minf(radius,14),1)
	else:
		center = p-last_normal*radius*0.55
		tool.mode = VoxelTool.MODE_REMOVE; tool.sdf_strength = 1
		tool.do_sphere(center,radius)
	var low = Vector3i((center-Vector3.ONE*(radius+3))/32.0)
	var high = Vector3i((center+Vector3.ONE*(radius+3))/32.0)
	# Floor is required at negative coordinates, not integer truncation.
	low = Vector3i(floor((center.x-radius-3)/32),floor((center.y-radius-3)/32),floor((center.z-radius-3)/32))
	high = Vector3i(floor((center.x+radius+3)/32),floor((center.y+radius+3)/32),floor((center.z+radius+3)/32))
	for z in range(low.z,high.z+1):
		for x in range(low.x,high.x+1):
			for y in range(low.y,high.y+1): dirty_blocks[Vector3i(x,y,z)*32] = true
	terrain_revision += 1
	return true

func sync_surface(p: Vector2, radius: float):
	var ci = model.index_at(p); var r = int(ceil(radius/model.CELL))+1
	var tool = terrain.get_voxel_tool()
	for z in range(maxi(1,ci/model.N-r),mini(model.N-1,ci/model.N+r+1)):
		for x in range(maxi(1,ci%model.N-r),mini(model.N-1,ci%model.N+r+1)):
			var i = x+z*model.N; var q = model.pos(i)
			if q.distance_to(p)>radius+model.CELL: continue
			var hit = tool.raycast(Vector3(q.x,TOP-1,q.y),Vector3.DOWN,TOP-BOTTOM-2)
			model.heights[i] = TOP-1-hit.distance if hit != null else -48.0
	model.refresh_fields()

func capture_edits() -> Dictionary:
	var blocks = model.terrain_blocks.duplicate()
	var tool = terrain.get_voxel_tool()
	for origin in dirty_blocks:
		var buffer = VoxelBuffer.new(); buffer.create(32,32,32)
		tool.copy(origin,buffer,VoxelBuffer.CHANNEL_SDF_BIT,false)
		blocks[origin] = buffer.get_channel_as_byte_array(VoxelBuffer.CHANNEL_SDF)
	model.terrain_blocks = blocks
	return blocks

func update_camera(dt: float):
	var t = 1.0-exp(-dt*16.0)
	yaw = lerpf(yaw,target_yaw,t); pitch = lerpf(pitch,target_pitch,t); distance = lerpf(distance,target_distance,t)
	focus = focus.lerp(target_focus,t)
	camera.position = focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(focus)

func orbit(delta: Vector2):
	target_yaw -= delta.x*0.006; target_pitch = clampf(target_pitch+delta.y*0.004,0.15,1.40)

func pan(delta: Vector2):
	var right = camera.global_basis.x
	var forward = Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
	target_focus += (-right*delta.x+forward*delta.y)*target_distance*0.0014
	target_focus.x = clampf(target_focus.x,-460,460); target_focus.z = clampf(target_focus.z,-460,460)

func set_cursor(p: Vector3, radius: float, excavation: bool):
	cursor.visible = p.x<9000 and not excavation; brush_ball.visible = p.x<9000 and excavation
	if p.x<9000:
		cursor.position = p+Vector3.UP*0.15; cursor.scale = Vector3(radius/10,1,radius/10)
		brush_ball.position = p-last_normal*radius*0.55; brush_ball.scale = Vector3.ONE*radius

func queue_render(frame: Dictionary):
	if frame.is_empty(): return
	render_pending = frame; render_stage = 0

func apply_render_stage():
	if render_stage<0: return
	if render_stage<12:
		var data: PackedFloat32Array = render_pending.plants[render_stage]
		var mm: MultiMesh = plant_nodes[render_stage].multimesh
		var count = data.size()/12
		if mm.instance_count!=count: mm.instance_count = count
		if count>0: mm.buffer = data
	elif render_stage==12:
		if render_pending.water[Mesh.ARRAY_VERTEX].is_empty(): lake.mesh = null
		else:
			var mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,render_pending.water); lake.mesh = mesh
	elif render_stage==13:
		field_texture.update(Image.create_from_data(128,128,false,Image.FORMAT_RGBA8,render_pending.fields))
		height_texture.update(Image.create_from_data(128,128,false,Image.FORMAT_RF,render_pending.heights))
		water_texture.update(Image.create_from_data(128,128,false,Image.FORMAT_RF,render_pending.depths))
		refresh_sources()
	else: render_stage = -1; return
	render_stage += 1

func animate(dt: float, allow_upload: bool = true):
	phase += dt; update_camera(dt)
	update_atmosphere(dt)
	if allow_upload: apply_render_stage()
	clouds.position.x = sin(phase*0.035)*70
	if model.get("rainfall")!=null:
		rain.visible = model.rainfall>0.1
		clouds.material_override.set_shader_parameter("coverage",model.cloud_cover)
		clouds.multimesh.visible_instance_count = clampi(int(model.cloud_cover*36)*3,3,108)
	for data in flying:
		var node: Node3D = data.node
		var t = phase*data.speed+data.phase
		node.position = data.origin+Vector3(sin(t)*data.radius,sin(t*2)*data.height,cos(t)*data.radius*0.7)
		node.rotation.y = -t

func set_night(value: bool):
	preview_clock = 120.0 if value else 40.0

func update_atmosphere(dt: float):
	var clock = model.elapsed if preview_clock < 0 else preview_clock
	var cycle = fmod(clock,160.0)/160.0
	var altitude = sin(cycle*TAU)
	var target_day = smoothstep(-0.22,0.24,altitude)
	daylight = lerpf(daylight,target_day,1.0-exp(-dt*0.85))
	night = daylight<0.35
	var dusk = (1.0-absf(daylight*2.0-1.0))*0.82
	var e = environment.environment
	var sky_mat = e.sky.sky_material
	sky_mat.sky_top_color = Color("14283b").lerp(Color("75abc8"),daylight).lerp(Color("ac8195"),dusk*0.38)
	sky_mat.sky_horizon_color = Color("34475f").lerp(Color("e0e9e3"),daylight).lerp(Color("edac79"),dusk)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color("162a3c").lerp(Color("647e88"),daylight)
	e.fog_light_color = sky_mat.sky_horizon_color
	e.ambient_light_energy = lerpf(0.22,0.38,daylight)
	e.ambient_light_color = Color("8b9ebf").lerp(Color("b4cfcc"),daylight)
	sun.light_energy = lerpf(0.12,1.12,daylight)
	sun.light_color = Color("bbc4e6").lerp(Color("fff0d7"),daylight).lerp(Color("ffb873"),dusk*0.7)
	# Follow a smooth orbit for moving shadows, including the short moonlit night.
	var angle = -20.0-50.0*maxf(0,altitude)
	sun.rotation_degrees.x = lerpf(sun.rotation_degrees.x,angle,1-exp(-dt*0.7))
	sun.rotation_degrees.y = lerpf(sun.rotation_degrees.y,-65.0+cycle*100.0,1-exp(-dt*0.7))
	var s = model.season(); var blend = smoothstep(255.0,300.0,fmod(model.elapsed,300.0))
	var target = Vector4.ZERO; target[s] = 1.0-blend; target[(s+1)%4] += blend
	season_weights = season_weights.lerp(target,1.0-exp(-dt*0.55))
	RenderingServer.global_shader_parameter_set("island_winter",season_weights.w)
	RenderingServer.global_shader_parameter_set("island_autumn",season_weights.z)
	RenderingServer.global_shader_parameter_set("island_spring",season_weights.x)
	for node in plant_nodes:
		node.material_override.set_shader_parameter("season_weights",season_weights)
	lake_material.set_shader_parameter("ice",season_weights.w*0.90)
	ocean_material.set_shader_parameter("night",1.0-daylight)
	lake_material.set_shader_parameter("night",1.0-daylight)
	if is_instance_valid(clouds): clouds.material_override.set_shader_parameter("daylight",daylight)

func make_atmosphere():
	clouds = MultiMeshInstance3D.new()
	var mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	var cloud_mesh = sphere(1); cloud_mesh.radial_segments = 24; cloud_mesh.rings = 12; mm.mesh = cloud_mesh
	mm.instance_count = 108
	for i in 36:
		var p = Vector3((model.hash01(i,100)-0.5)*2400,470+model.hash01(i,101)*160,(model.hash01(i,102)-0.5)*2000)
		for j in 3:
			var scale_v = Vector3(35+model.hash01(i+j,103)*35,20+model.hash01(i+j,104)*16,25+model.hash01(i+j,105)*30)
			var offset = Vector3((j-1)*33,j*6,(j-1)*12)
			mm.set_instance_transform(i*3+j,Transform3D(Basis.IDENTITY.scaled(scale_v),p+offset))
	clouds.multimesh = mm
	var mat = ShaderMaterial.new(); mat.shader = load("res://shaders/cloud.gdshader")
	clouds.material_override = mat; clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clouds)
	rain = MultiMeshInstance3D.new(); var rm = MultiMesh.new(); rm.transform_format = MultiMesh.TRANSFORM_3D
	var drop = BoxMesh.new(); drop.size = Vector3(0.07,3.5,0.07); rm.mesh = drop; rm.instance_count = 900
	for i in 900:
		rm.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3((model.hash01(i,110)-0.5)*520,model.hash01(i,111)*190,(model.hash01(i,112)-0.5)*520)))
	rain.multimesh = rm; var rmat = ShaderMaterial.new(); rmat.shader = load("res://shaders/rain.gdshader")
	rain.material_override = rmat; rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; rain.visible = false; add_child(rain)

func refresh_animals():
	for c in props.get_children(): c.queue_free()
	flying = []
	for name_text in model.animals:
		for j in (5 if name_text in ["蝴蝶","蜻蜓","林鸟"] else 3):
			var node = Node3D.new(); props.add_child(node)
			var center = Vector2(-25+j*14,40+j*9)
			var origin = Vector3(center.x,model.height_at(center)+2,center.y)
			if name_text=="野鸭": origin.y = maxf(7.4,origin.y)
			node.position = origin
			if name_text=="青蛙":
				piece(sphere(0.8,0.8),material(Color("71844a")),Vector3.ZERO,node)
				for x in [-0.45,0.45]: piece(sphere(0.19),material(Color("20271b")),Vector3(x,0.35,0.55),node)
			elif name_text=="野鸭":
				piece(sphere(1.6,1.5),material(Color("827562")),Vector3.ZERO,node)
				piece(sphere(0.65),material(Color("426e58")),Vector3(0,0.9,1.1),node)
				piece(cylinder(0.28,0.25,0.8,5),material(Color("d7b164")),Vector3(0,0.9,1.6),node).rotation.x = PI/2
			else:
				var wing_col = Color("f4ce79") if name_text=="蝴蝶" else Color("b5d8df") if name_text=="蜻蜓" else Color("e7e8de")
				for x in [-1.0,1.0]:
					var wing = piece(sphere(0.85,0.15),material(wing_col),Vector3(x*0.7,0,0),node)
					wing.rotation.z = x*0.3
				piece(sphere(0.25,0.9),material(Color("4b615a")),Vector3.ZERO,node).rotation.x = PI/2
				origin.y += 30 if name_text=="林鸟" else 6
				flying.append({"node":node,"origin":origin,"radius":12.0+j*3,"height":2.0,"speed":0.5+j*0.1,"phase":j*2.0})

func refresh_sources():
	var signature=str(terrain_revision)+str(model.springs)
	for s in model.springs:
		signature+=str(snappedf(model.water[model.index_at(Vector2(s.x,s.z))],0.2))
	if signature==source_signature: return
	source_signature=signature
	for c in source_markers.get_children(): c.queue_free()
	for s in model.springs:
		# A small seep follows the actual terrain; no upright marker in the scenery.
		var center=Vector2(s.x,s.z)
		var heights={}
		var mesh=SurfaceTool.new(); mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in 48:
			var a=j*TAU/48; var b=(j+1)*TAU/48
			for offset in [Vector2.ZERO,Vector2(cos(b),sin(b))*2.8,Vector2(cos(a),sin(a))*2.8]:
				var q=center+offset
				if not heights.has(offset):
					var ground=model.height_at(q)
					var hit=terrain.get_voxel_tool().raycast(Vector3(q.x,TOP-1,q.y),Vector3.DOWN,TOP-BOTTOM-2)
					if hit!=null: ground=TOP-1-hit.distance
					heights[offset]=maxf(ground,model.height_at(q)+model.water[model.index_at(q)])
				mesh.set_uv(Vector2.ONE*0.5+offset/5.6); mesh.set_normal(Vector3.UP)
				mesh.add_vertex(Vector3(q.x,heights[offset]+0.14,q.y))
		var mat=ShaderMaterial.new(); mat.shader=load("res://shaders/spring.gdshader")
		var seep=piece(mesh.commit(),mat,Vector3.ZERO,source_markers)
		seep.set_meta("source_position",center)
		seep.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_source_focus(enabled: bool, p: Vector3):
	for seep in source_markers.get_children():
		if seep.is_queued_for_deletion(): continue
		var near=enabled and Vector2(p.x,p.z).distance_to(seep.get_meta("source_position"))<12
		seep.material_override.set_shader_parameter("selected",1.0 if near else 0.0)

func make_ring(radius: float, thickness: float) -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 96:
		var a = j*TAU/96; var b = (j+1)*TAU/96
		for v in [Vector3(cos(a)*(radius-thickness),0,sin(a)*(radius-thickness)),Vector3(cos(b)*(radius+thickness),0,sin(b)*(radius+thickness)),Vector3(cos(a)*(radius+thickness),0,sin(a)*(radius+thickness)),Vector3(cos(a)*(radius-thickness),0,sin(a)*(radius-thickness)),Vector3(cos(b)*(radius-thickness),0,sin(b)*(radius-thickness)),Vector3(cos(b)*(radius+thickness),0,sin(b)*(radius+thickness))]:
			st.set_normal(Vector3.UP); st.add_vertex(v)
	return st.commit()

func append_primitive(st: SurfaceTool, mesh: PrimitiveMesh, p: Vector3, scale_v: Vector3, col: Color, rot: float = 0):
	var arr = mesh.get_mesh_arrays(); var b = Basis(Vector3.UP,rot)
	var verts = arr[Mesh.ARRAY_VERTEX]; var normals = arr[Mesh.ARRAY_NORMAL]
	for idx in arr[Mesh.ARRAY_INDEX]:
		st.set_color(col); st.set_normal((b*(normals[idx]/scale_v)).normalized()); st.add_vertex(b*(verts[idx]*scale_v)+p)

func petal(st: SurfaceTool, root: Vector3, tip: Vector3, width: float, col: Color):
	var axis = (tip-root).normalized(); var cross_v = axis.cross(Vector3.UP)
	if cross_v.length()<0.01: cross_v = Vector3.RIGHT
	cross_v = cross_v.normalized()*width; var center = root.lerp(tip,0.55)+Vector3.UP*0.15
	for v in [root,center-cross_v,tip,root,tip,center+cross_v]:
		st.set_color(col); st.set_normal(Vector3.UP); st.add_vertex(v)

func make_plant(kind: int, col: Color) -> ArrayMesh:
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark = Color("6a5946")
	if kind>=8:
		var h = 20 if kind==11 else 14 if kind==8 else 18
		append_primitive(st,cylinder(0.4,0.9,h,9),Vector3(0,h/2,0),Vector3.ONE,Color("dad5bc") if kind==9 else bark)
		if kind==11:
			for j in 4: append_primitive(st,cylinder(0,7-j*1.2,9,14),Vector3(0,8+j*4,0),Vector3.ONE,col.lightened(j*0.035))
		else:
			for j in 5:
				var a = j*TAU/5
				var p = Vector3(cos(a)*3,h+sin(a)*2,sin(a)*3)
				append_primitive(st,sphere(4.5,7.0),p,Vector3(1.0,0.9 if kind!=8 else 1.5,1.0),col.lightened(j*0.018))
			if kind==8:
				for j in 8:
					var a = j*TAU/8
					petal(st,Vector3(cos(a)*4,15,sin(a)*4),Vector3(cos(a)*5,4,sin(a)*5),0.5,col)
	elif kind==7:
		for j in 4: append_primitive(st,sphere(2.6,4.2),Vector3(sin(j*2)*1.9,2.5,cos(j*2)*1.9),Vector3.ONE,col.lightened(j*0.03))
	elif kind==0:
		for j in 3: append_primitive(st,sphere(1.3,0.5),Vector3(j-1,0.2,0),Vector3.ONE,col)
	elif kind in [3,4]:
		for j in 4:
			var p = Vector3(sin(j*2)*1.2,0,cos(j*2)*1.2)
			append_primitive(st,cylinder(0.06,0.10,5.5,5),p+Vector3.UP*2.75,Vector3.ONE,col)
			petal(st,p+Vector3.UP*2,p+Vector3(sin(j)*1.7,4.5,cos(j)*1.7),0.35,col)
			append_primitive(st,sphere(0.25,1.5),p+Vector3.UP*5.6,Vector3.ONE,Color("79583b") if kind==4 else Color("c3b78e"))
	elif kind in [1,2]:
		for j in 7:
			var a = j*TAU/7
			petal(st,Vector3.ZERO,Vector3(cos(a)*2.5,3.3,sin(a)*2.5),0.45 if kind==1 else 0.12,col)
	else:
		for j in 3:
			var p = Vector3(sin(j*2)*1.0,0,cos(j*2)*1.0)
			append_primitive(st,cylinder(0.06,0.08,1.8,5),p+Vector3.UP*0.9,Vector3.ONE,Color("669154"))
			for k in 6:
				var a = k*TAU/6
				petal(st,p+Vector3.UP*1.8,p+Vector3(cos(a)*0.6,2,sin(a)*0.6),0.21,Color("edf0db") if kind==5 else col)
			append_primitive(st,sphere(0.2,0.25),p+Vector3.UP*1.95,Vector3.ONE,Color("d0b863"))
	return st.commit()
