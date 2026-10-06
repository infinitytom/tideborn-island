extends RefCounted
const N = 128
const COUNT = N * N
const SIZE = 1024.0
const CELL = 8.0
const HALF = 512.0
const SPECIES_NAMES = ["苔藓", "蕨类", "莎草", "芦苇", "香蒲", "白三叶", "野菊", "灌木", "柳树", "桦树", "栎树", "松树"]
const CONDITIONS = ["湿润、背阴的地表", "林下湿润的半阴环境", "湿草甸和浅水岸边", "阳光充足的浅水与湿地", "平缓的浅水湖岸", "日照较好的湿润草地", "排水良好的开阔草甸", "较干燥的林缘与坡地", "湿润河岸的开阔地", "凉爽、湿润的次生林", "温暖、排水良好的林地", "干燥的山坡与岩地"]
const COLORS = [Color("577347"),Color("497d53"),Color("8b9c58"),Color("99a564"),Color("7d8f50"),Color("75a25e"),Color("e6d6a1"),Color("687c42"),Color("80a868"),Color("8dae72"),Color("567d4e"),Color("3c6851")]
const BIOMES = ["岩岸", "草甸", "河岸湿地", "阔叶林", "山地针叶林"]
var world_seed: int = 260104
var ticks: int = 0
var elapsed: float = 0
var sun_angle: float = -0.6
var heights = PackedFloat32Array()
var base_heights = PackedFloat32Array()
var water = PackedFloat32Array()
var moisture = PackedFloat32Array()
var light = PackedFloat32Array()
var temperature = PackedFloat32Array()
var habitat = PackedByteArray()
var slope = PackedFloat32Array()
var canopy = PackedFloat32Array()
var seeds = PackedByteArray()
var seed_set = PackedByteArray()
var species = PackedInt32Array()
var growth = PackedFloat32Array()
var observations = PackedInt32Array()
var plant_count: int = 0
var wet_count: int = 0
var springs: Array = []
var terrain_blocks: Dictionary = {}
var animals: Array = []
var community_counts = PackedInt32Array()
var render_frame: Dictionary = {}
var vapor: float = 0.42
var cloud_cover: float = 0.48
var rainfall: float = 0.0
var plankton: float = 0.40
var fish_population: float = 0.30
var weather_mode: int = 0
var creative: bool = false

func hash01(i: int, salt: int = 0) -> float:
	var v = (world_seed * 73856093 + i * 19349663 + salt * 83492791) & 0x7fffffff
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7fffffff
	return float(v % 100000) / 100000.0

func pos(i: int) -> Vector2:
	return Vector2((i % N) * CELL - HALF, (i / N) * CELL - HALF)

func index_at(p: Vector2) -> int:
	return clampi(int((p.x + HALF) / CELL),0,N-1) + clampi(int((p.y + HALF)/CELL),0,N-1)*N

func height_at(p: Vector2, use_base: bool = false) -> float:
	var gx = clampf((p.x+HALF)/CELL,0,N-1.001)
	var gz = clampf((p.y+HALF)/CELL,0,N-1.001)
	var x = int(gx); var z = int(gz)
	var a = base_heights if use_base else heights
	return lerpf(lerpf(a[x+z*N],a[x+1+z*N],gx-x),lerpf(a[x+(z+1)*N],a[x+1+(z+1)*N],gx-x),gz-z)

func reset(s: int):
	world_seed = s; ticks = 0; elapsed = 0
	vapor = 0.42; cloud_cover = 0.48; rainfall = 0; plankton = 0.4; fish_population = 0.3; weather_mode = 0
	sun_angle = -0.6 + hash01(8)*0.3
	for name in ["heights","water","moisture","light","temperature","slope","canopy","growth"]:
		var a = PackedFloat32Array(); a.resize(COUNT); set(name,a)
	seeds.resize(COUNT); seed_set.resize(COUNT); species.resize(COUNT); habitat.resize(COUNT)
	seeds.fill(0); seed_set.fill(0); species.fill(-1); growth.fill(0); canopy.fill(0)
	observations.resize(12); observations.fill(0)
	community_counts.resize(5); community_counts.fill(0)
	springs = [{"x": -8.0,"z": -140.0}]; terrain_blocks = {}; animals = []
	var noise = FastNoiseLite.new(); noise.seed = s; noise.frequency = 0.009; noise.fractal_octaves = 4
	var forest_noise = FastNoiseLite.new(); forest_noise.seed = s+185; forest_noise.frequency = 0.018
	for i in COUNT:
		var p = pos(i)
		var broad = noise.get_noise_2d(p.x,p.y)
		var r = Vector2(p.x,p.y*1.10).length()
		var coast = smoothstep(160+broad*55,290+broad*42,r)
		var hills = 76*exp(-p.distance_squared_to(Vector2(-105,-85))/9000.0)+67*exp(-p.distance_squared_to(Vector2(115,55))/6500.0)+38*exp(-p.distance_squared_to(Vector2(80,-150))/5500.0)
		var h = 19+broad*23+hills
		var river_x = sin(p.y*0.018)*21+sin(p.y*0.03)*8
		var river_d = absf(p.x-river_x)
		var river_level = 8.0-p.y*0.019
		h = lerpf(h,river_level-2.0+pow(river_d/30.0,2)*6.0,exp(-pow(river_d/43,2)))
		var lake = exp(-p.distance_squared_to(Vector2(-15,40))/2700.0)
		h = lerpf(h,4.0, lake*0.95)
		heights[i] = lerpf(h,-28.0,coast)
		water[i] = maxf(0, (river_level if river_d < 16 and absf(p.y)<175 else 7.3 if lake>0.26 else 0.0)-heights[i])
		if heights[i] < 1: water[i] = 0
		moisture[i] = clampf(0.30+lake*0.48+exp(-river_d/30)*0.45+forest_noise.get_noise_2d(p.x,p.y)*0.2,0.12,1)
		canopy[i] = clampf(0.42+forest_noise.get_noise_2d(p.x,p.y)*1.25,0,1)
	base_heights = heights.duplicate()
	refresh_fields()
	for i in COUNT:
		if heights[i] > 1.5 and heights[i] < 135 and hash01(i,21) < (0.46 if habitat[i]>=3 else 0.76):
			seeds[i] = 1
			species[i] = choose_species(i)
			growth[i] = 0.45+hash01(i,22)*0.5
	count_ecology()
	prepare_render_frame()

func season() -> int: return int(elapsed/300.0)%4
func is_night() -> bool: return fmod(elapsed,160.0)>=95

func refresh_fields():
	var base_t = [14.0,25.0,11.0,-3.0][season()]
	for z in range(1,N-1):
		for x in range(1,N-1):
			var i = x+z*N
			var sx = (heights[i+1]-heights[i-1])/(CELL*2)
			var sz = (heights[i+N]-heights[i-N])/(CELL*2)
			slope[i] = sqrt(sx*sx+sz*sz)
			light[i] = clampf(0.82-sx*0.3-sz*0.22-canopy[i]*0.36,0.18,1)
			temperature[i] = base_t-maxf(0,heights[i]-25)*0.045
			habitat[i] = 0 if heights[i] < 7 or slope[i]>1.15 else 2 if moisture[i]>0.68 else 4 if heights[i]>48 and moisture[i]<0.60 else 3 if canopy[i]>0.42 else 1

func choose_species(i: int) -> int:
	var m = moisture[i]; var h = heights[i]; var l = light[i]
	var variation = hash01(i,41)
	if h < 1 or slope[i]>1.2: return -1
	if seed_set[i]==1: return (5 if variation<0.55 else 6) if water[i]<0.25 and l>0.45 else -1
	if seed_set[i]==2:
		if water[i]>0.3 or m<0.2: return -1
		return 8 if m>0.65 else 11 if m<0.40 and h>30 else 9 if variation<0.45 else 10
	if seed_set[i]==3: return (4 if variation<0.45 else 3) if water[i]>0.3 and water[i]<3.8 else 2 if m>0.65 else -1
	if water[i]>0.3:
		return 4 if water[i]<2 and variation<0.45 else 3 if water[i]<3.8 else -1
	if habitat[i] == 2: return 8 if variation<0.22 else 2 if l>0.55 else 1
	if habitat[i] == 4: return 11 if variation<0.62 else 7
	if habitat[i] == 3: return 9 if variation<0.24 else 10 if variation<0.52 else 1 if m>0.47 else 0
	if habitat[i] == 0: return 7 if m<0.48 and variation<0.26 else 0 if m>0.6 else 6
	return 5 if variation<0.46 else 6 if variation<0.84 else 7

func refresh_weather():
	var weather = sin(elapsed*0.009+world_seed*0.0007)*0.5+0.5
	cloud_cover = clampf(0.18+weather*0.65+vapor*0.18,0.15,0.96)
	rainfall = maxf(0,cloud_cover-0.68)*3.0
	if weather_mode==1: cloud_cover = 0.18; rainfall = 0
	elif weather_mode==2: cloud_cover = 0.86; rainfall = 0.75

func step(dt: float):
	elapsed += dt; ticks += 1
	refresh_weather()
	var evaporated = 0.0; var runoff = 0.0; var sea_cells = 0
	var next_w = water.duplicate(); var next_m = moisture.duplicate()
	for s in springs:
		var si = index_at(Vector2(s.x,s.z))
		water[si] += dt*6.0; next_w[si] += dt*6.0
	for z in range(1,N-1):
		for x in range(1,N-1):
			var i = x+z*N
			if heights[i] < 1:
				runoff += next_w[i]; next_w[i] = 0; sea_cells += 1; continue
			var w = water[i]
			if w>0.0001 and temperature[i]>0:
				var level = heights[i]+w
				var f0 = maxf(0,level-heights[i-1]-water[i-1]); var f1 = maxf(0,level-heights[i+1]-water[i+1])
				var f2 = maxf(0,level-heights[i-N]-water[i-N]); var f3 = maxf(0,level-heights[i+N]-water[i+N])
				var total = f0+f1+f2+f3
				if total>0.0001:
					var amount = minf(w*0.35,total*dt*0.22)
					var ratio = amount/total
					next_w[i] -= amount; next_w[i-1] += f0*ratio; next_w[i+1] += f1*ratio; next_w[i-N] += f2*ratio; next_w[i+N] += f3*ratio
			var evap = (0.002+light[i]*0.003)*(0.3 if is_night() else 1.0)*dt
			var surface_evap = minf(next_w[i],evap)
			var transpiration = canopy[i]*moisture[i]*evap*0.3
			evaporated += surface_evap+transpiration
			# Rain first wets soil; saturated soil releases surface runoff.
			var rain = rainfall*dt*0.06
			var infiltrated = minf(rain,(1.0-moisture[i])*0.06)
			next_w[i] = maxf(0,next_w[i]-surface_evap+rain-infiltrated)
			var average = (moisture[i-1]+moisture[i+1]+moisture[i-N]+moisture[i+N])*0.25
			next_m[i] = clampf(moisture[i]+(average-moisture[i])*dt*0.22+minf(w,1)*dt*0.09+infiltrated*3.0-transpiration-evap*0.04,0.1,1)
			if seeds[i] > 0:
				if not creative and (species[i]<0 or (i+ticks)%16==0):
					var chosen = choose_species(i)
					if chosen != species[i]: species[i] = chosen; growth[i] = minf(growth[i],0.12)
				if species[i] >= 0:
					var aquatic = species[i] in [2,3,4]
					var stress = maxf(0,0.23-moisture[i])*0.25+maxf(0,water[i]-(4.0 if aquatic else 0.5))*0.05
					var photosynthesis = light[i]*(0.18 if is_night() else 1.0)
					if creative: stress = 0
					if temperature[i]>3 or creative: growth[i] = clampf(growth[i]+dt*((0.01 if species[i]>=8 else 0.035)*photosynthesis-stress),0,1)
					if growth[i]>0.65 and (i+ticks)%96==0:
						var neighbors = [-1,1,-N,N]
						var j = i+neighbors[int(hash01(i,ticks)*4)%4]
						if heights[j]>1 and seeds[j]==0:
							seeds[j]=1; seed_set[j]=0
					observations[species[i]] += 1
					if species[i]>=8: canopy[i] = minf(0.85,canopy[i]+growth[i]*dt*0.004)
	water = next_w; moisture = next_m
	# A reservoir model connects ocean evaporation, land transpiration and rain.
	var ocean_evap = sea_cells*dt*0.003*(0.35 if is_night() else 1.0)
	vapor = clampf(vapor+(evaporated+ocean_evap)/COUNT*0.45-rainfall*dt*0.0014,0.08,0.98)
	var solar = (0.20 if is_night() else 1.0)*(1.0-cloud_cover*0.45)
	var marine_temperature = [0.75,1.0,0.65,0.25][season()]
	plankton = clampf(plankton+dt*solar*marine_temperature*0.0012+minf(runoff/COUNT,0.002)*0.15-fish_population*dt*0.0011,0.05,1.0)
	fish_population = clampf(fish_population+dt*(plankton*0.0009-0.00025),0.05,1.0)
	if ticks%4==0: refresh_fields()
	count_ecology()

func count_ecology():
	plant_count = 0; wet_count = 0; community_counts.fill(0)
	var flowers = 0; var forests = 0
	for i in COUNT:
		if heights[i]>1 and water[i]>0.1: wet_count += 1
		if species[i]>=0 and growth[i]>0.08:
			plant_count += 1; community_counts[habitat[i]] += 1
			if species[i] in [5,6]: flowers += 1
			if species[i]>=8: forests += 1
	animals = []
	if wet_count>25 and community_counts[2]>20: animals.append("青蛙"); animals.append("蜻蜓")
	if wet_count>90: animals.append("野鸭")
	if flowers>40: animals.append("蝴蝶")
	if forests>70: animals.append("林鸟")
	if forests>70 and community_counts[1]>35: animals.append("鹿")
	if forests>100 and plant_count>250: animals.append("狐狸")

func scatter(p: Vector2, radius: float, community: int = 0):
	var ci = index_at(p); var r = int(ceil(radius/CELL))+1
	for z in range(maxi(1,ci/N-r),mini(N-1,ci/N+r+1)):
		for x in range(maxi(1,ci%N-r),mini(N-1,ci%N+r+1)):
			var i = x+z*N
			if pos(i).distance_to(p)<radius and heights[i]>1:
				seeds[i] = 1
				seed_set[i] = community
	refresh_fields()

func paint_plants(p: Vector2, radius: float, kind: int):
	for i in COUNT:
		if pos(i).distance_to(p)>radius or heights[i]<1: continue
		species[i]=kind; growth[i]=1.0 if kind>=0 else 0.0; seeds[i]=1 if kind>=0 else 0
		if kind>=8: canopy[i]=0.6
		elif kind<0: canopy[i]=0.0
	count_ecology()

func snapshot(include_geometry: bool = true) -> Dictionary:
	var d = {"version":2,"seed":world_seed,"ticks":ticks,"elapsed":elapsed,"sun_angle":sun_angle,"springs":springs.duplicate(true),"terrain_blocks":terrain_blocks.duplicate(true) if include_geometry else {},"vapor":vapor,"cloud_cover":cloud_cover,"rainfall":rainfall,"plankton":plankton,"fish_population":fish_population,"weather_mode":weather_mode,"creative":creative}
	for key in ["heights","base_heights","water","moisture","light","temperature","habitat","slope","canopy","seeds","seed_set","species","growth","observations"]: d[key] = get(key).duplicate()
	return d

func restore(d: Dictionary):
	creative = d.get("creative",false)
	world_seed = d.seed; ticks = d.ticks; elapsed = d.elapsed; sun_angle = d.sun_angle
	for key in ["vapor","cloud_cover","rainfall","plankton","fish_population","weather_mode"]: set(key,d[key])
	for key in ["heights","base_heights","water","moisture","light","temperature","habitat","slope","canopy","seeds","seed_set","species","growth","observations"]: set(key,d[key].duplicate())
	springs = d.springs.duplicate(true); terrain_blocks = d.terrain_blocks.duplicate(true)
	community_counts.resize(5); count_ecology()

func prepare_render_frame():
	var buffers: Array = []
	for k in 12: buffers.append(PackedFloat32Array())
	for i in COUNT:
		var k = species[i]
		if k<0 or growth[i]<0.08 or heights[i]<1: continue
		var p = pos(i)+Vector2(hash01(i,12)-0.5,hash01(i,13)-0.5)*CELL*0.85
		var scale_v = (0.72+hash01(i,14)*0.65)*(0.18+0.82*growth[i])
		var a = hash01(i,15)*TAU
		var cs = cos(a)*scale_v; var sn = sin(a)*scale_v
		var h = height_at(p)
		var buffer: PackedFloat32Array = buffers[k]
		buffer.append_array(PackedFloat32Array([cs,0,sn,p.x,0,scale_v,0,h,-sn,0,cs,p.y,]))
	var verts = PackedVector3Array(); var norms = PackedVector3Array(); var colors = PackedColorArray()
	var levels = PackedFloat32Array(); levels.resize(COUNT)
	for z in range(2,N-2):
		for x in range(2,N-2):
			var i = x+z*N; var sum = 0.0; var weight = 0.0
			for dz in range(-2,3):
				for dx in range(-2,3):
					var j = i+dx+dz*N
					if heights[j]>1 and water[j]>0.18 and (water[i]<0.18 or absf(heights[j]+water[j]-heights[i]-water[i])<2.5):
						var w = 1.0/(1+dx*dx+dz*dz)
						sum += (heights[j]+water[j])*w; weight += w
			levels[i] = sum/weight+0.04 if weight>0 else heights[i]-0.15
	for z in range(1,N-2):
		for x in range(1,N-2):
			var i = x+z*N
			if heights[i]<1 or maxf(maxf(water[i],water[i+1]),maxf(water[i+N],water[i+N+1]))<0.18: continue
			# Bilinear subdivision makes adjacent water patches share identical vertices.
			for iz in 4:
				for ix in 4:
					for offset in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
						var u = (ix+offset.x)/4.0; var v = (iz+offset.y)/4.0
						var p = pos(i)+Vector2(u,v)*CELL
						var level = lerpf(lerpf(levels[i],levels[i+1],u),lerpf(levels[i+N],levels[i+N+1],u),v)
						verts.append(Vector3(p.x,level,p.y)); norms.append(Vector3.UP)
						colors.append(Color(1 if temperature[i]<0 else 0,0,0))
	var water_arrays: Array = []; water_arrays.resize(Mesh.ARRAY_MAX)
	water_arrays[Mesh.ARRAY_VERTEX] = verts; water_arrays[Mesh.ARRAY_NORMAL] = norms; water_arrays[Mesh.ARRAY_COLOR] = colors
	var pixels = PackedByteArray(); pixels.resize(COUNT*4)
	for i in COUNT:
		pixels[i*4] = int(moisture[i]*255); pixels[i*4+1] = int(clampf(canopy[i],0,1)*255)
		pixels[i*4+2] = int(habitat[i]*51); pixels[i*4+3] = 255
	render_frame = {"plants":buffers,"water":water_arrays,"fields":pixels,"heights":heights.to_byte_array(),"depths":water.to_byte_array(),"season":season()}
