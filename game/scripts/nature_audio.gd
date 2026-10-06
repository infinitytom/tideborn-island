extends Node
# Original offline-rendered loops keep playing during terrain edits.
var model
var enabled_music: bool = true
var music_volume: float = 0.65
var ambience_volume: float = 0.70
var effects_volume: float = 0.55
var music: AudioStreamPlayer
var sea: AudioStreamPlayer
var rain: AudioStreamPlayer
var effects: Array = []
var clips: Dictionary = {}
var last_effect: int = -1000
var effect_index: int = 0
func player(path: String, looping: bool) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	var clip = load(path) as AudioStreamWAV
	if clip == null: push_error("Missing sound: " + path); return p
	if looping:
		clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
		clip = clip.duplicate()
		clip.loop_end = int(clip.get_length()*clip.mix_rate)
	p.stream = clip; add_child(p)
	if looping: p.play()
	return p
func setup(m):
	model = m
	music = player("res://audio/island_music.wav",true)
	sea = player("res://audio/sea.wav",true)
	rain = player("res://audio/rain.wav",true)
	for name_text in ["click","earth","cut","smooth","water","seed"]:
		clips[name_text] = load("res://audio/"+name_text+".wav") as AudioStreamWAV
	for i in 2:
		var p = AudioStreamPlayer.new(); p.max_polyphony = 1; add_child(p); effects.append(p)
	refresh_volume()
func level(v: float) -> float:
	return linear_to_db(maxf(v,0.0001))
func refresh_volume():
	music.volume_db = level(music_volume * 0.65 if enabled_music else 0.0)
	sea.volume_db = level(ambience_volume * 0.55)
	rain.volume_db = level(ambience_volume * clampf(model.rainfall,0,1) * 0.65)
func _process(_dt):
	if is_instance_valid(music): refresh_volume()
func effect(name_text: String):
	var now = Time.get_ticks_msec()
	if now-last_effect < (90 if name_text=="click" else 190): return
	last_effect = now
	var p = effects[effect_index % effects.size()]; effect_index += 1
	p.stream = clips.get(name_text,clips.get("click"))
	p.volume_db = level(effects_volume * 0.55)
	p.pitch_scale = 1.0 if name_text=="click" else randf_range(0.96,1.02)
	p.play()
