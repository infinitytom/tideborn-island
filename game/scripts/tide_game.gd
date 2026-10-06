extends Node3D
const Model = preload("res://scripts/eco_model.gd")
const Visual = preload("res://scripts/island_visual.gd")
const Sound = preload("res://scripts/nature_audio.gd")
const TOOLS = ["塑形与扩岛", "开凿", "平滑", "水源", "播种", "观察"]
const TIPS = ["左键抬升与填海 · 右键减去土石", "按住左键开凿 · Shift 固定开凿高度", "按住左键软化地形与岩壁", "点击放置淡水源 · 右键移除附近水源", "按环境撒下混合种子", "悬停查看群落与水土条件"]
const SEASONS = ["春", "夏", "秋", "冬"]
var model
var visual
var sound
var font: SystemFont
var ui: Control
var home: Control
var hud: Control
var popup: PanelContainer
var content: VBoxContainer
var tool_buttons: Array = []
var season_label: Label
var toast_label: Label
var hint_label: Label
var inspect_panel: PanelContainer
var inspect_label: Label
var inspector: bool = false
var selected_tool: int = 0
var radius: float = 12
var seed_mix: int = 0
var drawing: int = 0
var orbiting: bool = false
var panning: bool = false
var started: bool = false
var home_visible: bool = true
var night_preview: bool = false
var hover = Vector3(9999,9999,9999)
var stroke_last = Vector3(9999,9999,9999)
var stroke_height: float = 0
var brush_timer: float = 0
var pending_surface: Dictionary = {}
var speed: int = 1
var accumulator: float = 0
var sim_thread: Thread
var sim_steps: int = 0
var sim_world_revision: int = 0
var sim_edit_revision: int = 0
var world_revision: int = 0
var edit_revision: int = 0
var render_timer: float = 1
var ui_timer: float = 0
var save_timer: float = 0
var toast_time: float = 0
var records: Array = []
var save_path: String = "user://island.save"
var isolated: bool = false
var screenshots: bool = false
var benchmark: bool = false
var stress: bool = false
var samples: Array = []
var last_frame: int = 0
var stress_timer: float = 0
var previous_animals: String = ""
var available_save: bool = false
var time_button: Button
var seed_picker: OptionButton
var resume_camera: Dictionary = {}
var tool_description: Label
var brush_value: Label
var brush_strength: float = 1.0
var stamp_mode: bool = false
var placement_height: float = 24.0
var undo_history: Array = []
var redo_history: Array = []
var spring_limit: int = 32
var modal_shade: ColorRect
var popup_scroll: ScrollContainer
var support_dialog: FileDialog
var direct_species: int = 10
var screenshot_dir: String
var panorama: bool = false
var panorama_from_home: bool = false
var panorama_camera: Dictionary = {}
var continue_button: Button

func _ready():
	screenshot_dir=ProjectSettings.globalize_path("res://").path_join("..")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): screenshot_dir=arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(screenshot_dir)
	isolated = OS.get_cmdline_user_args().has("--smoke-test") or OS.get_cmdline_user_args().has("--performance-test") or OS.get_cmdline_user_args().has("--polish-test") or OS.get_cmdline_user_args().has("--promo-capture")
	if isolated: save_path = "user://validation_v2.save"
	font = SystemFont.new(); font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	DisplayServer.window_set_title("潮生岛 · 一座岛，一个小世界")
	model = Model.new(); model.reset(260104)
	visual = Visual.new(); add_child(visual); visual.setup(model)
	sound = Sound.new(); add_child(sound); sound.setup(model)
	load_settings()
	available_save = not read_bundle().is_empty() if not isolated else false
	build_ui(); show_home()
	if OS.get_cmdline_user_args().has("--smoke-test"): smoke_test.call_deferred()
	if OS.get_cmdline_user_args().has("--performance-test"): performance_test.call_deferred()
	if OS.get_cmdline_user_args().has("--polish-test"): polish_test.call_deferred()

func style(c: Color, corners: int = 15, padding: int = 12) -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(corners)
	s.content_margin_left = padding; s.content_margin_right = padding; s.content_margin_top = padding; s.content_margin_bottom = padding
	s.shadow_color = Color(0.12,0.22,0.25,0.08); s.shadow_size = 6
	return s

func label(text_value: String, size_v: int = 15, col: Color = Color("354f52")) -> Label:
	var l = Label.new(); l.text = text_value; l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font",font); l.add_theme_font_size_override("font_size",size_v); l.add_theme_color_override("font_color",col)
	return l

func button(text_value: String, callback: Callable, icon: Texture2D = null) -> Button:
	var b = Button.new(); b.text = text_value; b.icon = icon; b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font",font); b.add_theme_font_size_override("font_size",16)
	b.add_theme_color_override("font_color",Color("345255")); b.add_theme_color_override("font_hover_color",Color("1d3c41"))
	b.add_theme_color_override("font_pressed_color",Color("1d3c41")); b.add_theme_color_override("font_disabled_color",Color("9daead"))
	b.add_theme_stylebox_override("normal",style(Color(0.95,0.97,0.93,0.92)))
	b.add_theme_stylebox_override("hover",style(Color("e2ede3")))
	b.add_theme_stylebox_override("pressed",style(Color("c7dfd1")))
	b.add_theme_stylebox_override("disabled",style(Color(0.95,0.97,0.93,0.45)))
	b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND; b.pressed.connect(func(): sound.effect("click"); callback.call())
	return b

func icon_for(k: int) -> Texture2D:
	return load("res://icons/tool_%d.svg" % k)

func make_theme() -> Theme:
	var t = Theme.new(); t.default_font = font; t.default_font_size = 15
	for type_name in ["Label","Button","OptionButton","CheckButton","LineEdit","PopupMenu"]:
		for color_name in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			t.set_color(color_name,type_name,Color("294647"))
		t.set_color("font_disabled_color",type_name,Color("70827a"))
	for type_name in ["OptionButton","LineEdit","CheckButton"]:
		for state in ["normal","hover","pressed","focus"]: t.set_stylebox(state,type_name,style(Color("e5ece0"),10,10))
	t.set_color("caret_color","LineEdit",Color("294647"))
	t.set_color("font_selected_color","LineEdit",Color("ffffff"))
	t.set_color("selection_color","LineEdit",Color("44796b"))
	t.set_stylebox("panel","PopupMenu",style(Color("f5f7ef"),12,10))
	t.set_stylebox("hover","PopupMenu",style(Color("bfd9ca"),8,8))
	for state in ["slider","grabber_area","grabber_area_highlight"]:
		t.set_stylebox(state,"HSlider",style(Color("abc4b5"),4,3))
	t.set_stylebox("panel","TooltipPanel",style(Color("f5f7ef"),10,12))
	t.set_color("font_color","TooltipLabel",Color("294647"))
	return t

func backed_label(l: Label):
	l.add_theme_stylebox_override("normal",style(Color("f5f7ef"),13,10))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fit_popup():
	var current = popup
	await get_tree().process_frame
	if not is_instance_valid(current) or current!=popup: return
	var height = clampf(content.get_combined_minimum_size().y,100,680)
	popup_scroll.custom_minimum_size.y = height
	popup.size.y = height+52; popup.position.y = (900-popup.size.y)*0.5

func volume_slider(title_text: String, key: String):
	var row = HBoxContainer.new(); content.add_child(row)
	var name_l = label(title_text,14); name_l.custom_minimum_size.x = 125; row.add_child(name_l)
	var slider = HSlider.new(); slider.min_value=0; slider.max_value=1; slider.step=0.01; slider.value=sound.get(key)
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL; slider.custom_minimum_size=Vector2(190,28)
	slider.value_changed.connect(func(v): sound.set(key,v); save_settings()); row.add_child(slider)

func show_creation():
	open_popup("随心塑造",560)
	var mode = CheckButton.new(); mode.text="自由创造 · 直接种植并保留植物"; mode.button_pressed=model.creative
	mode.toggled.connect(func(v): model.creative=v; edit_revision+=1; select_tool(selected_tool)); content.add_child(mode)
	content.add_child(label("自然模式播下种子，由环境决定生长。\n自由创造可以直接种下成株，植物不会因环境不适而消失。",14))
	var plant_picker = OptionButton.new()
	for name_text in model.SPECIES_NAMES: plant_picker.add_item(name_text)
	plant_picker.selected=direct_species; plant_picker.item_selected.connect(func(i): direct_species=i); content.add_child(plant_picker)
	var stamp = CheckButton.new(); stamp.text="悬空塑形 · 在指定高度添加土石球"; stamp.button_pressed=stamp_mode
	stamp.toggled.connect(func(v): stamp_mode=v); content.add_child(stamp)
	content.add_child(label("高度（米） · PageUp / PageDown 也可调整",14))
	var altitude = SpinBox.new(); altitude.min_value=-40; altitude.max_value=900; altitude.step=4; altitude.value=placement_height
	altitude.value_changed.connect(func(v): placement_height=v); content.add_child(altitude)
	content.add_child(label("塑形力度",14))
	var strength = HSlider.new(); strength.min_value=0.25; strength.max_value=5; strength.step=0.25; strength.value=brush_strength
	strength.custom_minimum_size.y=28; strength.value_changed.connect(func(v): brush_strength=v); content.add_child(strength)
	content.add_child(label("笔刷范围 3–48 米 · 水源最多 32 处\n右键清除植物或水源 · Shift 固定塑形/开凿高度\nCtrl Z 撤销 · Ctrl Y 重做（最近 6 次编辑）\n地形范围 1024×1024 米，最高可塑造至约 950 米。\n生态仍采样最高地表，悬空岛下方和洞内无独立生态。",14))
	var row = HBoxContainer.new(); content.add_child(row)
	row.add_child(button("撤销",undo_edit)); row.add_child(button("重做",redo_edit)); row.add_child(button("开始创造",close_popup))

func remember_edit():
	finish_simulation(); update_surface(); visual.capture_edits()
	undo_history.append(model.snapshot())
	if undo_history.size()>6: undo_history.pop_front()
	redo_history.clear()

func restore_edit(state: Dictionary):
	finish_simulation(); world_revision+=1; pending_surface={}; drawing=0
	model.restore(state); visual.model=model; sound.model=model
	visual.rebuild_terrain(); model.prepare_render_frame(); visual.queue_render(model.render_frame); visual.refresh_animals()
	select_tool(selected_tool); render_timer=2

func undo_edit():
	if undo_history.is_empty(): toast("还没有可撤销的编辑。"); return
	finish_simulation(); update_surface(); visual.capture_edits(); redo_history.append(model.snapshot())
	restore_edit(undo_history.pop_back()); toast("已撤销；Ctrl Y 可重做。")

func redo_edit():
	if redo_history.is_empty(): toast("没有可重做的编辑。"); return
	finish_simulation(); update_surface(); visual.capture_edits(); undo_history.append(model.snapshot())
	restore_edit(redo_history.pop_back()); toast("已重做。")

func support_texture() -> Texture2D:
	if not isolated and FileAccess.file_exists("user://support.png"):
		var img=Image.load_from_file("user://support.png")
		if img!=null: return ImageTexture.create_from_image(img)
	return load("res://assets/support.png") as Texture2D

func show_support():
	open_popup("支持创作者",430)
	content.add_child(label("如果这座小岛给你带来了片刻快乐，
欢迎支持它继续生长。",16))
	var picture=TextureRect.new(); picture.texture=support_texture()
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size=Vector2(320,465); content.add_child(picture)
	content.add_child(label("支付宝扫码 · 感谢每一份支持",14))
	content.add_child(button("导入 / 更换赞赏码",import_support))

func import_support():
	if is_instance_valid(support_dialog): support_dialog.queue_free()
	support_dialog=FileDialog.new(); support_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	support_dialog.access=FileDialog.ACCESS_FILESYSTEM; support_dialog.use_native_dialog=true
	support_dialog.filters=PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp;图片"]); ui.add_child(support_dialog)
	support_dialog.file_selected.connect(func(path):
		var img=Image.load_from_file(path)
		if img==null: return
		if img.save_png("user://support.png")!=OK: return
		show_support())
	support_dialog.popup_centered_ratio(0.7)

func build_ui():
	var canvas = CanvasLayer.new(); add_child(canvas)
	ui = Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; canvas.add_child(ui)
	ui.theme = make_theme()
	home = Control.new(); home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); home.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(home)
	var card = Panel.new(); card.position = Vector2(48,110); card.size = Vector2(345,690); card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel",style(Color("f5f7ef"),24,24)); home.add_child(card)
	var title = label("潮生岛",52); title.position = Vector2(82,147); home.add_child(title)
	var english = label("T I D E B O R N   I S L A N D",13,Color("68868a")); english.position = Vector2(86,219); home.add_child(english)
	var subtitle = label("从一座岛开始，\n养出一个小世界。",20); subtitle.position = Vector2(86,257); home.add_child(subtitle)
	var menus = VBoxContainer.new(); menus.position = Vector2(86,330); menus.size.x = 267; menus.add_theme_constant_override("separation",9); home.add_child(menus)
	var new_b = button("开始新岛屿",show_new_island); new_b.custom_minimum_size = Vector2(267,45); menus.add_child(new_b)
	var continue_b = button("继续",continue_game); continue_b.name = "Continue"; continue_button=continue_b; continue_b.custom_minimum_size = Vector2(267,50); menus.add_child(continue_b)
	menus.add_child(button("全景欣赏",func(): set_panorama(true))); menus.add_child(button("认识这个世界",show_help)); menus.add_child(button("设置",show_settings)); menus.add_child(button("支持创作者",show_support)); menus.add_child(button("退出",exit_game))
	var home_note = label("天空 · 陆地 · 海洋\n日照、云雨与生物群落，在这里慢慢循环。",13,Color("5d7d80")); home_note.position = Vector2(86,716); home.add_child(home_note)
	hud = Control.new(); hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(hud)
	var menu_b = button("菜单",show_pause); menu_b.position = Vector2(26,24); menu_b.custom_minimum_size = Vector2(80,44); hud.add_child(menu_b)
	season_label = label("",15); season_label.position = Vector2(1100,24); season_label.size = Vector2(300,48)
	season_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; backed_label(season_label); hud.add_child(season_label)
	var toolbox = PanelContainer.new(); toolbox.position = Vector2(26,740); toolbox.custom_minimum_size = Vector2(860,135)
	toolbox.add_theme_stylebox_override("panel",style(Color("f5f7ef"),20,12)); hud.add_child(toolbox)
	var tool_column = VBoxContainer.new(); tool_column.add_theme_constant_override("separation",9); toolbox.add_child(tool_column)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation",6); tool_column.add_child(row)
	for k in 6:
		var b = button("%d %s" % [k+1,["塑形","开凿","平滑","水源","播种","观察"][k]],func(): select_tool(k),icon_for(k))
		b.add_theme_font_size_override("font_size",14); b.custom_minimum_size = Vector2(103,45)
		b.tooltip_text = TIPS[k]; row.add_child(b); tool_buttons.append(b)
	row.add_child(button("创造",show_creation)); row.add_child(button("撤销",undo_edit))
	var brush_row = HBoxContainer.new(); brush_row.add_theme_constant_override("separation",10); tool_column.add_child(brush_row)
	brush_row.add_child(label("范围",13))
	var slider = HSlider.new(); slider.min_value = 3; slider.max_value = 48; slider.step = 1; slider.value = radius
	slider.custom_minimum_size = Vector2(155,24); slider.value_changed.connect(func(v): radius = v; brush_value.text = "%d m" % v); brush_row.add_child(slider)
	brush_value = label("12 m",13); brush_value.custom_minimum_size.x = 47; brush_row.add_child(brush_value)
	var mix = OptionButton.new(); seed_picker = mix
	for name_text in ["自然混合","草甸种子","林地种子","湿地种子"]: mix.add_item(name_text)
	mix.item_selected.connect(func(i):
		if model.creative: direct_species=i
		else: seed_mix=i
		update_tool_description()); brush_row.add_child(mix)
	tool_description = label("",14); tool_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tool_description.custom_minimum_size.x = 450; tool_column.add_child(tool_description)
	var ecology_b = button("生态",show_ecology); ecology_b.position = Vector2(1110,822); ecology_b.custom_minimum_size = Vector2(132,50); hud.add_child(ecology_b)
	var time_b = button("1×",func(): speed = 0 if speed==1 else 4 if speed==0 else 1; update_hud())
	time_button = time_b; time_b.position = Vector2(1255,822); time_b.custom_minimum_size = Vector2(150,50); hud.add_child(time_b)
	var help_b = button("说明 · F1",show_help); help_b.position = Vector2(1255,758); hud.add_child(help_b)
	var panorama_b=button("全景 · P",func(): set_panorama(true)); panorama_b.position=Vector2(1110,758); panorama_b.tooltip_text="隐藏界面与笔刷，缓慢环绕岛屿；P 或 Esc 返回"; hud.add_child(panorama_b)
	toast_label = label("",15); toast_label.position = Vector2(290,24); toast_label.size = Vector2(740,48); toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; backed_label(toast_label); hud.add_child(toast_label)
	hint_label = label("中键旋转 · Shift＋中键平移 · 滚轮缩放 · F 聚焦 · Ctrl Z 撤销",13)
	hint_label.position = Vector2(290,82); hint_label.size = Vector2(740,36); hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; backed_label(hint_label); hud.add_child(hint_label)
	inspect_panel = PanelContainer.new(); inspect_panel.position = Vector2(1060,520); inspect_panel.custom_minimum_size = Vector2(345,200)
	inspect_panel.add_theme_stylebox_override("panel",style(Color("f5f7ef"),17,18)); hud.add_child(inspect_panel)
	inspect_label = label("",14); inspect_panel.add_child(inspect_label); inspect_panel.visible = false
	select_tool(0)

func show_home():
	panorama=false; Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if started: resume_camera = camera_snapshot()
	night_preview=false; visual.set_night(false)
	home_visible = true; home.visible = true; hud.visible = false; drawing = 0; orbiting = false
	close_popup()
	visual.set_cursor(Vector3(9999,9999,9999),radius,false)
	for c in home.get_children():
		if c is VBoxContainer:
			var continue_b = c.get_node_or_null("Continue");
			if continue_b == null: continue
			continue_b.disabled = not (started or available_save)
	visual.target_distance = 650; visual.target_focus = Vector3(55,24,0)

func enter_world():
	panorama=false; Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	started = true; home_visible = false; home.visible = false; hud.visible = true; close_popup()
	visual.target_distance = 610; visual.target_focus = Vector3(0,25,0)
	visual.preview_clock = -1; undo_history.clear(); redo_history.clear()
	toast("沿岸填海，或打开「创造」直接种树、悬空造岛；F1 查看说明。",8)

func continue_game():
	if started: enter_world(); restore_camera(resume_camera); return
	var data = read_bundle()
	if data.is_empty(): toast("未找到可继续的岛屿。"); return
	model.restore(data.world); records = data.get("records",[])
	world_revision += 1; visual.model = model; sound.model = model
	visual.rebuild_terrain(); model.prepare_render_frame(); visual.queue_render(model.render_frame); visual.refresh_animals()
	enter_world(); restore_camera(data.get("camera",{}))

func select_tool(k: int):
	selected_tool = k; drawing = 0; stroke_last = Vector3(9999,9999,9999)
	for j in tool_buttons.size(): tool_buttons[j].add_theme_stylebox_override("normal",style(Color("bfd9ca") if j==k else Color(0.95,0.97,0.93,0.0),14,12))
	update_tool_description()
	inspector = k==5
	if is_instance_valid(seed_picker):
		seed_picker.clear()
		for name_text in (model.SPECIES_NAMES if model.creative else ["自然混合","草甸种子","林地种子","湿地种子"]): seed_picker.add_item(name_text)
		seed_picker.selected=direct_species if model.creative else seed_mix
		seed_picker.visible=k==4
	if is_instance_valid(inspect_panel): inspect_panel.visible = inspector

func update_tool_description():
	if not is_instance_valid(tool_description): return
	if selected_tool==4:
		tool_description.text=("直接种植 · "+model.SPECIES_NAMES[direct_species] if model.creative else "自然播种 · 环境筛选群落")+" · 按住左键涂抹，右键清除"
	elif selected_tool==0 and stamp_mode:
		tool_description.text="悬空塑形 · 高度 %d m · PageUp / PageDown 调整 · 右键开凿" % placement_height
	else: tool_description.text=TOOLS[selected_tool]+" · "+TIPS[selected_tool]

func set_panorama(value: bool):
	if panorama==value: return
	if value:
		panorama_from_home=home_visible; panorama_camera=camera_snapshot(); close_popup()
		panorama=true; home_visible=false; home.visible=false; hud.visible=false
		drawing=0; orbiting=false; panning=false; hover=Vector3(9999,9999,9999)
		visual.set_cursor(hover,radius,false); visual.preview_clock=-1
		var low=Vector2(512,512); var high=Vector2(-512,-512); var top=25.0
		for i in model.COUNT:
			if model.heights[i]>1:
				var p=model.pos(i); low=low.min(p); high=high.max(p); top=maxf(top,model.heights[i])
		if high.x<low.x: low=Vector2(-200,-200); high=Vector2(200,200)
		var center=(low+high)*0.5
		visual.target_focus=Vector3(center.x,top*0.3,center.y)
		visual.target_distance=clampf(maxf(maxf(high.x-low.x,high.y-low.y)*1.55,top*2.1),650,2200)
		visual.target_pitch=0.48 if top>180 else 0.38
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		panorama=false; orbiting=false; panning=false; Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		home_visible=panorama_from_home; home.visible=home_visible; hud.visible=not home_visible
		if home_visible: visual.set_night(false)
		restore_camera(panorama_camera); update_hud()

func advance_world(dt: float):
	accumulator=minf(accumulator+dt*speed,1.5); render_timer+=dt
	if (accumulator>=0.25 or (speed==0 and render_timer>=1.5)) and sim_thread==null: start_simulation()

func open_popup(title_text: String, width: float = 420):
	close_popup(); drawing = 0; orbiting = false; panning = false
	visual.set_cursor(Vector3(9999,9999,9999),radius,false)
	modal_shade=ColorRect.new(); modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_shade.color=Color(0.04,0.10,0.13,0.30); modal_shade.mouse_filter=Control.MOUSE_FILTER_STOP; ui.add_child(modal_shade)
	popup = PanelContainer.new(); popup.position = Vector2((1440-width)/2,80); popup.custom_minimum_size = Vector2(width,100)
	popup.add_theme_stylebox_override("panel",style(Color("f5f7ef"),23,26)); ui.add_child(popup)
	popup_scroll = ScrollContainer.new(); popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	popup_scroll.custom_minimum_size = Vector2(width-52,100); popup.add_child(popup_scroll)
	content = VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",14); popup_scroll.add_child(content)
	fit_popup.call_deferred()
	var row = HBoxContainer.new(); content.add_child(row)
	var title_l = label(title_text,26); title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(title_l)
	row.add_child(button("×",close_popup))

func close_popup():
	if is_instance_valid(modal_shade): modal_shade.queue_free()
	modal_shade=null
	if is_instance_valid(popup): ui.remove_child(popup); popup.queue_free()
	popup = null

func show_pause():
	open_popup("暂停片刻")
	content.add_child(button("回到岛屿",close_popup))
	content.add_child(button("保存岛屿",func(): save_game(); toast("岛屿已保存。")))
	content.add_child(button("岛屿记录",show_records))
	content.add_child(button("设置",show_settings))
	content.add_child(button("操作说明",show_help))
	content.add_child(button("全景欣赏 · P",func(): set_panorama(true)))
	content.add_child(button("回到开始界面",func(): save_game(); show_home()))

func show_new_island():
	open_popup("一座新的岛屿")
	content.add_child(label("一个种子，一片新的海岸。",14,Color("6f8987")))
	var seed_edit = LineEdit.new(); seed_edit.text = str(260104 if not started else int(Time.get_unix_time_from_system())%999999)
	seed_edit.add_theme_font_override("font",font); seed_edit.custom_minimum_size.y = 45; content.add_child(seed_edit)
	content.add_child(button("让小岛生长",func():
		if not seed_edit.text.is_valid_int(): return
		if started:
			save_game()
			records.append({"name":"上一座岛 · 种子 %d" % model.world_seed,"world":model.snapshot(),"camera":resume_camera if home_visible else camera_snapshot()})
		var seed_value = absi(int(seed_edit.text))%1000000
		world_revision += 1
		model = Model.new(); model.reset(seed_value); visual.model = model; sound.model = model
		visual.rebuild_terrain(); visual.queue_render(model.render_frame); visual.refresh_animals()
		accumulator = 0; pending_surface = {}; resume_camera = {}; enter_world(); save_game()))

func show_settings():
	open_popup("设置",520)
	content.add_child(label("总音量（拉到左侧静音）",16))
	var audio = HSlider.new(); audio.min_value = -40; audio.max_value = 0; audio.value = AudioServer.get_bus_volume_db(0)
	audio.custom_minimum_size.y = 28; audio.value_changed.connect(func(v): AudioServer.set_bus_volume_db(0,v); AudioServer.set_bus_mute(0,v<=-40); save_settings()); content.add_child(audio)
	var music = CheckButton.new(); music.text = "轻音乐"; music.button_pressed = sound.enabled_music
	music.add_theme_font_override("font",font); music.toggled.connect(func(v): sound.enabled_music = v; save_settings()); content.add_child(music)
	volume_slider("音乐音量", "music_volume")
	volume_slider("海浪与雨声", "ambience_volume")
	volume_slider("操作音效", "effects_volume")
	content.add_child(button("试听操作音效",func(): sound.effect("seed")))
	content.add_child(button("切换昼夜视角",func(): night_preview = not night_preview; visual.set_night(night_preview)))
	content.add_child(button("恢复自然昼夜",func(): night_preview=false; visual.preview_clock=-1))
	content.add_child(button("进入下一季",func(): model.elapsed = (int(model.elapsed/300)+1)*300.0; model.refresh_fields(); world_revision += 1; render_timer = 2))
	var weather = OptionButton.new(); weather.add_theme_font_override("font",font)
	for text_value in ["天气 · 自然循环","天气 · 晴空","天气 · 降雨"]: weather.add_item(text_value)
	weather.selected = model.weather_mode; weather.item_selected.connect(func(i): model.weather_mode = i; model.refresh_weather(); edit_revision += 1); content.add_child(weather)
	content.add_child(button("清爽截图模式 · H",func(): close_popup(); hud.visible = not hud.visible))
	content.add_child(button("关闭",close_popup))

func load_settings():
	if isolated: return
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg")==OK:
		AudioServer.set_bus_volume_db(0,clampf(cfg.get_value("sound","volume",-8.0),-40,0))
		sound.enabled_music = cfg.get_value("sound","music",true)
		for key in ["music_volume","ambience_volume","effects_volume"]: sound.set(key,clampf(cfg.get_value("sound",key,sound.get(key)),0,1))
		AudioServer.set_bus_mute(0,AudioServer.get_bus_volume_db(0)<=-40)

func save_settings():
	if isolated: return
	var cfg = ConfigFile.new()
	cfg.set_value("sound","volume",AudioServer.get_bus_volume_db(0))
	cfg.set_value("sound","music",sound.enabled_music)
	for key in ["music_volume","ambience_volume","effects_volume"]: cfg.set_value("sound",key,sound.get(key))
	cfg.save("user://settings.cfg")

func show_help():
	open_popup("认识潮生岛",660)
	var l = label("这是一座可以亲手塑造的生态沙盘。没有任务期限，
你可以造山、填海、穿山挖洞，也可以种出一片自己的森林。

第一次来到岛上
① 中键旋转，滚轮拉近；按 F 聚焦鼠标所指的位置。
② 选「塑形」，沿岸按住左键填海，右键削去土石。
③ 选「平滑」，软化新海岸；选「播种」，撒下草甸种子。
④ 放置淡水源，观察低处的水、湿地与植物慢慢变化。

想更自由地创造
打开「创造」，启用自由创造，选择 12 种植物直接种下。
悬空塑形可指定高度造土石球，连接成浮岛、石桥或高山。
笔刷可调 3–48 米，力度可调；PageUp / PageDown 调高度。
Shift 固定塑形/开凿高度，适合横向挖隧道。
右键清除植物或水源；Ctrl Z 撤销，Ctrl Y 重做。

让世界自己生长
自然模式：植物由湿度、日照、温度、坡度筛选。
水源沿地表流动；海洋蒸发与植物蒸腾补充云雨。
春季嫩绿，夏季浓绿，秋叶金红，冬季积雪与湖冰。
一昼夜约 160 秒，一季约 5 分钟（1×速度）。
晨昏会渐变；N 预览昼夜，设置可恢复自然循环。

中键旋转 · Shift＋中键或 WASD 平移 · 滚轮缩放
1–6 选工具 · 空格暂停 · Tab 生态 · H 隐藏界面
P 全景欣赏（P / Esc 返回，鼠标中键和滚轮仍可调整镜头）
Esc 菜单 · F5 保存 · F9 读档 · 每 60 秒自动保存

这个世界的范围
可塑造区域约 1024×1024 米，最高约 950 米。
地形是真正的三维体素；生态采样最高地表，洞内和
悬空岛下方没有独立生态。水与食物链是简化模型。",15)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x=590; content.add_child(l)

func show_ecology():
	open_popup("一座岛的生态",620)
	content.add_child(label("天空 → 降雨 → 河湖 → 海洋 → 蒸发 → 天空",17))
	content.add_child(label("云量 %d%%   ·   降雨 %d%%   ·   水汽 %d%%" % [model.cloud_cover*100,model.rainfall*100,model.vapor*100],14))
	content.add_child(label("海洋初级生产者 → 浮游生物 → 鱼类\n藻类与浮游生物指数 %d%% · 鱼类种群指数 %d%%" % [model.plankton*100,model.fish_population*100],14))
	content.add_child(label("陆地群落",19))
	var row = HBoxContainer.new(); content.add_child(row)
	for k in 5: row.add_child(label("%s %d" % [model.BIOMES[k],model.community_counts[k]],13))
	content.add_child(label("栖息地来访者："+"、".join(model.animals),15))
	var scroll = ScrollContainer.new(); scroll.custom_minimum_size.y = 220; content.add_child(scroll)
	var box = VBoxContainer.new(); scroll.add_child(box)
	for k in 12: box.add_child(label("%s  ·  %s" % [model.SPECIES_NAMES[k],model.CONDITIONS[k]],14))

func show_records():
	open_popup("岛屿记录",660)
	content.add_child(button("记录此刻的岛屿",func():
		visual.capture_edits()
		records.append({"name":"岛屿 %d · 种子 %d" % [records.size()+1,model.world_seed],"world":model.snapshot(),"camera":camera_snapshot()})
		save_game(); show_records()))
	var scroll = ScrollContainer.new(); scroll.custom_minimum_size.y = 260; content.add_child(scroll)
	var box = VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(box)
	if records.is_empty(): box.add_child(label("把满意的岛屿记下来，随时回来继续塑造。",15))
	for i in records.size():
		box.add_child(button(records[i].name+"   →",func():
			world_revision += 1; model.restore(records[i].world)
			visual.model = model; sound.model = model; visual.rebuild_terrain()
			model.prepare_render_frame(); visual.queue_render(model.render_frame); visual.refresh_animals()
			restore_camera(records[i].camera); close_popup(); save_game()))

func toast(text_value: String, seconds: float = 4):
	toast_label.text = text_value; toast_time = seconds; toast_label.modulate.a = 1

func _input(event):
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: drawing = 0; stroke_last = Vector3(9999,9999,9999)
		if event.button_index==MOUSE_BUTTON_MIDDLE: orbiting = false; panning = false

func _unhandled_input(event):
	if panorama:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ESCAPE,KEY_P,KEY_H]: set_panorama(false)
			elif event.keycode==KEY_SPACE: speed=1 if speed==0 else 0
			elif event.keycode==KEY_N: night_preview=not night_preview; visual.set_night(night_preview)
		if event is InputEventMouseButton:
			if event.button_index==MOUSE_BUTTON_MIDDLE: orbiting=event.pressed and not event.shift_pressed; panning=event.pressed and event.shift_pressed
			elif event.button_index==MOUSE_BUTTON_WHEEL_UP: visual.target_distance=clampf(visual.target_distance*0.9,38,2200)
			elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: visual.target_distance=clampf(visual.target_distance*1.1,38,2200)
		if event is InputEventMouseMotion:
			if orbiting: visual.orbit(event.relative)
			if panning: visual.pan(event.relative)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if is_instance_valid(popup): close_popup()
			elif not home_visible: show_pause()
			return
	if home_visible or is_instance_valid(popup): return
	if event is InputEventKey and event.pressed and event.ctrl_pressed:
		if event.keycode==KEY_Z: undo_edit(); return
		if event.keycode==KEY_Y: redo_edit(); return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode>=KEY_1 and event.keycode<=KEY_6: select_tool(event.keycode-KEY_1)
		match event.keycode:
			KEY_SPACE: speed = 1 if speed==0 else 0
			KEY_N: night_preview = not night_preview; visual.set_night(night_preview)
			KEY_H: hud.visible = not hud.visible
			KEY_F:
				if hover.x<9000: visual.target_focus = hover; visual.target_distance = 170
			KEY_PAGEUP: placement_height=minf(900,placement_height+8); toast("悬空塑形高度 %d m" % placement_height)
			KEY_PAGEDOWN: placement_height=maxf(-40,placement_height-8); toast("悬空塑形高度 %d m" % placement_height)
			KEY_P: set_panorama(true); return
			KEY_TAB: show_ecology()
			KEY_F1: show_help()
			KEY_F5: save_game(); toast("岛屿已保存。")
			KEY_F9: started = false; continue_game()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: visual.target_distance = clampf(visual.target_distance*0.9,20,2200)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: visual.target_distance = clampf(visual.target_distance*1.1,20,2200)
		elif event.button_index==MOUSE_BUTTON_MIDDLE:
			orbiting = event.pressed and not event.shift_pressed; panning = event.pressed and event.shift_pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			if selected_tool<=2:
				drawing = -1 if event.button_index==MOUSE_BUTTON_RIGHT else 1
				remember_edit(); hover = visual.pick_plane(event.position,placement_height) if stamp_mode and selected_tool==0 else visual.pick(event.position); stroke_height = hover.y; brush_timer = 0
				apply_brush()
			elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT] and selected_tool in [3,4]:
				hover = visual.pick(event.position); remember_edit(); use_tool(event.button_index==MOUSE_BUTTON_RIGHT)
				if selected_tool==4: drawing=-1 if event.button_index==MOUSE_BUTTON_RIGHT else 1; stroke_last=hover
	if event is InputEventMouseMotion:
		if orbiting: visual.orbit(event.relative)
		if panning: visual.pan(event.relative)

func apply_brush():
	if hover.x>9000: return
	if selected_tool==4:
		if stroke_last.x<9000 and stroke_last.distance_to(hover)<maxf(3,radius*0.35): return
		use_tool(drawing<0); stroke_last=hover; return
	var point = hover
	if selected_tool<=1 and Input.is_key_pressed(KEY_SHIFT): point.y = stroke_height
	if stamp_mode and selected_tool==0: point.y = placement_height
	if stroke_last.x<9000 and stroke_last.distance_to(point)>radius*0.4:
		var count = mini(3,int(stroke_last.distance_to(point)/(radius*0.4)))
		for k in range(1,count+1): visual.edit(stroke_last.lerp(point,float(k)/(count+1)),radius,selected_tool,drawing<0,brush_strength,stamp_mode)
	visual.edit(point,radius,selected_tool,drawing<0); stroke_last = point; edit_revision += 1
	var ci = model.index_at(Vector2(point.x,point.z)); var r = int(ceil(radius/model.CELL))+1
	for z in range(maxi(1,ci/model.N-r),mini(model.N-1,ci/model.N+r+1)):
		for x in range(maxi(1,ci%model.N-r),mini(model.N-1,ci%model.N+r+1)): pending_surface[x+z*model.N] = true

func use_tool(remove: bool = false):
	if hover.x>9000: return
	var p = Vector2(hover.x,hover.z)
	if selected_tool==3:
		if remove:
			var closest = -1; var d = radius*2.0
			for i in model.springs.size():
				var s = model.springs[i]; var dist = p.distance_to(Vector2(s.x,s.z))
				if dist<d: closest=i; d=dist
			if closest>=0: model.springs.remove_at(closest); toast("水源已移除。")
			else: toast("笔刷附近没有水源。")
		else:
			if hover.y<1: toast("淡水源需要放在陆地上。"); return
			if model.springs.size()>=spring_limit: toast("最多可放置 32 处淡水源；右键移除旧水源。"); return
			model.springs.append({"x":p.x,"z":p.y}); toast("水源已放置；右键可移除。")
		sound.effect("water")
	elif selected_tool==4:
		if remove or model.creative:
			model.paint_plants(p,radius*1.5,-1 if remove else direct_species)
			toast("已清除植物。" if remove else "已种下"+model.SPECIES_NAMES[direct_species]+"；自由创造模式会保留植物。")
		else: model.scatter(p,radius*2.0,seed_mix); toast("种子落下了，让日照与水土筛选群落。")
		sound.effect("seed")
	edit_revision += 1; render_timer = 2

func update_surface():
	if pending_surface.is_empty(): return
	var tool = visual.terrain.get_voxel_tool()
	for i in pending_surface:
		var p = model.pos(i); var hit = tool.raycast(Vector3(p.x,visual.TOP-1,p.y),Vector3.DOWN,visual.TOP-visual.BOTTOM-2)
		model.heights[i] = visual.TOP-1-hit.distance if hit!=null else -48.0
	pending_surface = {}; model.refresh_fields(); edit_revision += 1; render_timer = 2

func _process(dt: float):
	if model==null: return
	if benchmark:
		var now = Time.get_ticks_usec()
		if last_frame>0: samples.append(float(now-last_frame)/1000.0)
		last_frame = now
		if stress:
			visual.target_yaw += dt*0.3; visual.target_distance = 480+sin(now/1000000.0)*220
			stress_timer += dt
			if stress_timer>0.04:
				stress_timer = 0; var p = Vector2(sin(now/1000000.0)*60,cos(now/1000000.0)*60)
				visual.edit(Vector3(p.x,model.height_at(p),p.y),10,0); edit_revision += 1
	poll_simulation()
	visual.animate(dt,drawing==0)
	if panorama:
		if not orbiting and not panning: visual.target_yaw+=dt*0.035
		visual.set_cursor(Vector3(9999,9999,9999),radius,false)
		advance_world(dt)
		save_timer+=dt
		if save_timer>=60 and not isolated: save_game(); save_timer=0
		return
	if home_visible:
		visual.target_yaw += dt*0.015
		return
	if is_instance_valid(popup): return
	var blocked = get_viewport().gui_get_hovered_control()!=null
	hover = Vector3(9999,9999,9999) if blocked else visual.pick(get_viewport().get_mouse_position())
	if stamp_mode and selected_tool==0 and not blocked: hover=visual.pick_plane(get_viewport().get_mouse_position(),placement_height)
	visual.set_cursor(hover,radius,selected_tool==1 or (stamp_mode and selected_tool==0))
	if drawing!=0 and not blocked:
		brush_timer += dt
		if brush_timer>=0.033: brush_timer = 0; apply_brush()
	elif drawing==0: update_surface()
	if Input.is_key_pressed(KEY_W): visual.pan(Vector2(0,-dt*150))
	if Input.is_key_pressed(KEY_S): visual.pan(Vector2(0,dt*150))
	if Input.is_key_pressed(KEY_A): visual.pan(Vector2(-dt*150,0))
	if Input.is_key_pressed(KEY_D): visual.pan(Vector2(dt*150,0))
	advance_world(dt)
	ui_timer += dt
	if ui_timer>0.2:
		ui_timer = 0; update_hud()
	if toast_time>0: toast_time -= dt; toast_label.modulate.a = clampf(toast_time,0,1)
	save_timer += dt
	if save_timer>=60 and drawing==0 and not orbiting and not panning and not isolated: save_game(); save_timer = 0

func start_simulation():
	var next = Model.new(); next.restore(model.snapshot(false))
	sim_steps = mini(4,int(accumulator/0.25)); sim_world_revision = world_revision; sim_edit_revision = edit_revision
	var build_frame = render_timer>=1.5
	if build_frame: render_timer = 0
	sim_thread = Thread.new(); sim_thread.start(simulate.bind(next,sim_steps,build_frame))

func simulate(next, count: int, build_frame: bool):
	for k in count: next.step(0.25)
	if build_frame: next.prepare_render_frame()
	return next

func poll_simulation():
	if sim_thread!=null and not sim_thread.is_alive(): finish_simulation()

func finish_simulation():
	if sim_thread==null: return
	var result = sim_thread.wait_to_finish(); sim_thread = null
	if sim_world_revision!=world_revision: return
	result.terrain_blocks = model.terrain_blocks
	if sim_edit_revision!=edit_revision:
		result.heights = model.heights.duplicate(); result.springs = model.springs.duplicate(true)
		result.canopy = model.canopy.duplicate(); result.weather_mode = model.weather_mode
		result.refresh_weather()
		result.creative = model.creative
		result.seed_set = model.seed_set.duplicate()
		result.species = model.species.duplicate(); result.growth = model.growth.duplicate()
		result.seeds = model.seeds.duplicate()
		result.count_ecology()
		render_timer = 2
	else:
		if not result.render_frame.is_empty(): visual.queue_render(result.render_frame)
	model = result; visual.model = model; sound.model = model; accumulator = maxf(0,accumulator-sim_steps*0.25)
	var animals_text = "、".join(model.animals)
	if animals_text!=previous_animals: previous_animals = animals_text; visual.refresh_animals()

func update_hud():
	update_tool_description()
	time_button.text = "暂停" if speed==0 else "%d×"%speed
	toast_label.visible = toast_time>0
	season_label.text = "%s · %s" % [SEASONS[model.season()]+"季","雨" if model.rainfall>0.15 else "月色" if visual.night else "阴" if model.cloud_cover>0.60 else "晴"]
	inspect_panel.visible = inspector and hover.x<9000
	if inspect_panel.visible:
		var i = model.index_at(Vector2(hover.x,hover.z))
		if hover.y<0.3:
			inspect_label.text = "近海生态\n\n水深 %.1f m\n浮游生物指数 %d%%\n鱼类种群指数 %d%%\n海洋蒸发补给岛上的云雨。" % [maxf(0,-model.height_at(Vector2(hover.x,hover.z))),model.plankton*100,model.fish_population*100]
		else:
			inspect_label.text = "%s  ·  %s\n\n湿度 %d%%    光照 %d%%\n温度 %.1f°C   水深 %.1f m\n%s" % [model.BIOMES[model.habitat[i]],model.SPECIES_NAMES[model.species[i]] if model.species[i]>=0 else "裸地",model.moisture[i]*100,model.light[i]*100,model.temperature[i],model.water[i],"、".join(model.animals)]

func camera_snapshot() -> Dictionary:
	return {"yaw":visual.target_yaw,"pitch":visual.target_pitch,"distance":visual.target_distance,"focus":visual.target_focus}

func restore_camera(d: Dictionary):
	if d.is_empty(): return
	visual.target_yaw = d.yaw; visual.target_pitch = d.pitch; visual.target_distance = d.distance; visual.target_focus = d.focus

func valid_world(d) -> bool:
	if not d is Dictionary or d.get("version",0)!=2: return false
	for key in ["seed","ticks","elapsed","sun_angle","springs","terrain_blocks","vapor","cloud_cover","rainfall","plankton","fish_population","weather_mode"]:
		if not d.has(key): return false
	for key in ["heights","base_heights","water","moisture","light","temperature","habitat","slope","canopy","seeds","seed_set","species","growth"]:
		if not d.has(key) or not (d[key] is PackedFloat32Array or d[key] is PackedInt32Array or d[key] is PackedByteArray) or d[key].size()!=model.COUNT: return false
	return d.has("observations") and d.observations.size()==12 and d.terrain_blocks is Dictionary

func read_bundle() -> Dictionary:
	for path in [save_path,save_path+".bak"]:
		if not FileAccess.file_exists(path): continue
		var f = FileAccess.open(path,FileAccess.READ)
		if f==null: continue
		var data = f.get_var(false)
		if data is Dictionary and valid_world(data.get("world")): return data
	return {}

func save_game():
	if not started: return
	update_surface(); visual.capture_edits()
	var f = FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if f==null: toast("无法保存，请检查磁盘空间。"); return
	f.store_var({"world":model.snapshot(),"records":records,"camera":resume_camera if home_visible and not resume_camera.is_empty() else camera_snapshot()}); f.flush(); f.close()
	if FileAccess.file_exists(save_path): DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path),ProjectSettings.globalize_path(save_path+".bak"))
	var error = DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path+".tmp"),ProjectSettings.globalize_path(save_path))
	available_save = error==OK

func exit_game():
	finish_simulation()
	if not isolated: save_game()
	get_tree().quit()

func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST: exit_game()

func _exit_tree():
	if sim_thread!=null: sim_thread.wait_to_finish(); sim_thread = null

func smoke_test():
	await get_tree().create_timer(5).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(screenshot_dir.path_join("潮生岛_开始.png"))
	enter_world(); speed = 0
	var key = InputEventKey.new(); key.pressed=true; key.keycode=KEY_5
	Input.parse_input_event(key); await get_tree().process_frame
	var input_ok = selected_tool==4 and seed_picker.visible
	key = InputEventKey.new(); key.pressed=true; key.keycode=KEY_SPACE
	Input.parse_input_event(key); await get_tree().process_frame
	input_ok = input_ok and speed==1; speed=0
	var old_yaw=visual.target_yaw
	var press=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_MIDDLE; press.pressed=true; press.position=Vector2(900,400)
	Input.parse_input_event(press); await get_tree().process_frame
	var motion=InputEventMouseMotion.new(); motion.position=Vector2(920,410); motion.relative=Vector2(20,10); motion.button_mask=MOUSE_BUTTON_MASK_MIDDLE
	Input.parse_input_event(motion); await get_tree().process_frame
	input_ok = input_ok and visual.target_yaw!=old_yaw
	press.pressed=false; Input.parse_input_event(press); await get_tree().process_frame
	key = InputEventKey.new(); key.pressed=true; key.keycode=KEY_ESCAPE
	Input.parse_input_event(key); await get_tree().process_frame
	input_ok = input_ok and is_instance_valid(popup); close_popup(); select_tool(0)
	var cave_p = Vector3(-100,model.height_at(Vector2(-100,-65))-12,-65)
	var native_cave = visual.terrain.get_voxel_tool().get_voxel_f(Vector3i(cave_p))>0
	var sea_p = Vector3(275,0,25)
	visual.edit(sea_p,20,0)
	var fill_ok = visual.terrain.get_voxel_tool().get_voxel_f(Vector3i(275,2,25))<0
	var cut_p = Vector3(115,model.height_at(Vector2(115,55))-8,55)
	visual.last_normal = Vector3.FORWARD; visual.edit(cut_p,9,1)
	var carved = visual.terrain.get_voxel_tool().get_voxel_f(Vector3i(cut_p-Vector3.FORWARD*4.95))>0
	model.scatter(Vector2(0,40),35,3); edit_revision += 1
	model.weather_mode = 2
	for k in 8: model.step(0.25)
	model.prepare_render_frame(); visual.queue_render(model.render_frame)
	show_help(); close_popup(); show_settings(); close_popup(); show_ecology(); close_popup()
	save_game(); var data = read_bundle(); var blocks = model.terrain_blocks.size()
	started = false; continue_game(); speed = 0
	var persist_ok = visual.terrain.get_voxel_tool().get_voxel_f(Vector3i(275,2,25))<0
	print("SMOKE_V2 input=",input_ok," native_cave=",native_cave," fill=",fill_ok," carved=",carved," save=",not data.is_empty()," blocks=",blocks," geometry_restored=",persist_ok," plants=",model.plant_count)
	model.weather_mode = 1; model.rainfall = 0; model.cloud_cover = 0.35
	await get_tree().create_timer(4).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(screenshot_dir.path_join("潮生岛_游戏.png"))
		visual.target_focus = Vector3(120,model.height_at(Vector2(120,-65))+15,-65); visual.target_distance = 170; visual.target_pitch = 0.32
		await get_tree().create_timer(3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(screenshot_dir.path_join("潮生岛_体素.png"))
		visual.target_focus = Vector3(0,25,0); visual.target_distance = 680; visual.target_pitch = 0.15; visual.target_yaw = 0.65
		await get_tree().create_timer(3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(screenshot_dir.path_join("潮生岛_天地海.png"))
		world_revision+=1; model.weather_mode=2; model.step(0.25)
		await get_tree().create_timer(1).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(screenshot_dir.path_join("潮生岛_雨.png"))
		show_ecology()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(screenshot_dir.path_join("潮生岛_生态.png"))
		close_popup(); night_preview=true; visual.set_night(true)
		await get_tree().create_timer(4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(screenshot_dir.path_join("潮生岛_夜.png"))
	get_tree().quit(0 if input_ok and native_cave and fill_ok and carved and persist_ok and not data.is_empty() else 1)

func frame_report(name_text: String) -> Dictionary:
	var sum = 0.0
	for value in samples: sum += value
	samples.sort()
	return {"scenario":name_text,"average_fps":snappedf(samples.size()*1000/maxf(sum,1),0.1),"p95_ms":snappedf(samples[int(samples.size()*0.95)],0.1),"max_ms":snappedf(samples.back(),0.1),"plants":model.plant_count,"frames":samples.size()}

func shot(name_text: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_dir.path_join("潮生岛_"+name_text+".png"))

func polish_test():
	await get_tree().create_timer(4).timeout
	var support_ok=support_texture()!=null and support_texture().get_width()==480 and home.find_children("*","TextureRect",true,false).is_empty()
	var home_continue_ok=continue_button.disabled
	enter_world(); speed=0; toast_time=0
	var saved_camera=camera_snapshot(); var start_clock=model.elapsed
	set_panorama(true); speed=1
	var before_yaw=visual.target_yaw
	await get_tree().create_timer(2.0).timeout
	var panorama_ok=not home.visible and not hud.visible and not visual.cursor.visible and not visual.brush_ball.visible and model.elapsed>start_clock and visual.target_yaw>before_yaw
	await shot("全景")
	var key_back=InputEventKey.new(); key_back.pressed=true; key_back.keycode=KEY_ESCAPE; Input.parse_input_event(key_back)
	await get_tree().process_frame
	panorama_ok=panorama_ok and not panorama and hud.visible and visual.target_focus.is_equal_approx(saved_camera.focus)
	speed=0
	var capture = AudioEffectCapture.new(); capture.buffer_length=1.0
	AudioServer.add_bus_effect(0,capture)
	sound.effect("seed")
	await get_tree().create_timer(0.5).timeout
	var energy = 0.0; var frames = capture.get_buffer(capture.get_frames_available())
	for f in frames: energy += f.length_squared()
	var audio_ok = energy>0.001 and sound.music.playing and sound.sea.playing
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	# Create well above the former 180 m sampling and 192 m voxel ceiling.
	var baseline=model.snapshot()
	var high = Vector3(320,320,80)
	remember_edit(); visual.edit(high,20,0,false,1,true); visual.sync_surface(Vector2(320,80),28)
	var height_ok = model.height_at(Vector2(320,80))>330
	save_game(); var data = read_bundle()
	undo_edit(); var undo_ok = visual.terrain.get_voxel_tool().get_voxel_f(Vector3i(high))>0
	redo_edit(); var redo_ok = visual.terrain.get_voxel_tool().get_voxel_f(Vector3i(high))<0
	var save_ok = not data.is_empty() and data.world.heights[model.index_at(Vector2(320,80))]>330
	started=false; continue_game(); speed=0
	var high_restored=visual.terrain.get_voxel_tool().get_voxel_f(Vector3i(high))<0
	restore_edit(baseline)
	model.creative=true; model.paint_plants(Vector2(40,70),24,6)
	var idx=model.index_at(Vector2(40,70)); var planted=model.species[idx]
	model.moisture[idx]=0.1; model.water[idx]=6
	for i in 20: model.step(0.25)
	var creative_ok = planted==6 and model.species[idx]==6 and model.growth[idx]>0.9
	model.prepare_render_frame(); visual.queue_render(model.render_frame)
	var buffers_ok=true
	for buffer in model.render_frame.plants:
		if buffer.size()%12!=0: buffers_ok=false
	visual.preview_clock=40; model.elapsed=40; model.weather_mode=1; model.refresh_weather()
	await get_tree().create_timer(3).timeout
	await shot("春")
	var prior=visual.daylight; visual.set_night(true); visual.update_atmosphere(1.0/60)
	var transition_ok=absf(visual.daylight-prior)<0.03 and visual.daylight>0.5
	await get_tree().create_timer(0.3).timeout
	transition_ok=transition_ok and visual.daylight<prior-0.1
	await get_tree().create_timer(4).timeout
	await shot("夜")
	visual.preview_clock=78
	await get_tree().create_timer(4).timeout
	await shot("晨昏")
	visual.preview_clock=40; model.elapsed=640; world_revision+=1
	await get_tree().create_timer(6).timeout
	await shot("秋")
	model.elapsed=940; world_revision+=1
	await get_tree().create_timer(6).timeout
	await shot("冬")
	var seasons_ok=visual.daylight>0.95 and visual.season_weights.w>0.9 and visual.lake_material.get_shader_parameter("ice")>0.8
	show_creation(); await get_tree().create_timer(0.3).timeout; await shot("创造")
	var popup_ok=popup.position.y>=0 and popup.position.y+popup.size.y<=900
	close_popup(); show_settings(); await get_tree().create_timer(0.3).timeout; await shot("设置")
	show_help(); await get_tree().create_timer(0.3).timeout; await shot("介绍")
	popup_ok=popup_ok and popup.position.y>=0 and popup.position.y+popup.size.y<=900
	close_popup(); show_support(); await get_tree().create_timer(0.3).timeout; await shot("支持")
	print("POLISH_TEST support=",support_ok," home_continue=",home_continue_ok," panorama=",panorama_ok," audio=",audio_ok," energy=",energy," frames=",frames.size()," height=",height_ok," save_high=",save_ok," high_restored=",high_restored," undo=",undo_ok," redo=",redo_ok," creative=",creative_ok," buffers=",buffers_ok," smooth_daylight=",transition_ok," seasons=",seasons_ok," popup_bounds=",popup_ok)
	get_tree().quit(0 if support_ok and home_continue_ok and panorama_ok and audio_ok and height_ok and save_ok and high_restored and undo_ok and redo_ok and creative_ok and buffers_ok and transition_ok and seasons_ok and popup_ok else 1)

func performance_test():
	enter_world(); speed = 1
	await get_tree().create_timer(7).timeout
	benchmark = true
	await get_tree().create_timer(6).timeout
	benchmark = false; var normal = frame_report("normal")
	samples = []; last_frame = 0; speed = 4; stress = true; benchmark = true
	await get_tree().create_timer(8).timeout
	benchmark = false; stress = false; var heavy = frame_report("25hz_voxel_edits_orbit_zoom_4x")
	var f = FileAccess.open(screenshot_dir.path_join("潮生岛_性能.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"device":RenderingServer.get_video_adapter_name(),"normal":normal,"stress":heavy},"\t"))
	print("PERF_V2 ",normal," ",heavy)
	finish_simulation(); get_tree().quit()
