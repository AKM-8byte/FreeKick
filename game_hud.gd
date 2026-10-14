extends CanvasLayer

signal settings_changed
signal reset_requested
signal charge_started
signal charge_released
signal replay_requested
signal replay_closed
signal menu_requested
signal timing_pressed
signal difficulty_accepted
signal difficulty_declined
signal guide_requested
signal quality_requested(level: int)
const Picker = preload("res://contact_picker.gd")
const PHYSICS_HELP := {
	"mass": "Topun kütlesi. Aynı vuruşta ağır top daha yavaş çıkar.",
	"strength": "Ayağın topa aktardığı kuvveti artırır veya azaltır.",
	"gravity": "Yükselişten sonra topun aşağı çekilme kuvveti.",
	"drag": "Topun uçuş sırasında ne kadar hız kaybettiği.",
	"curl": "Yandan temasın topu havada ne kadar büktüğü.",
	"bounce": "Topun zeminden ne kadar geri sıçradığı.",
	"friction": "Yerde yuvarlanan topun ne kadar hızlı yavaşladığı.",
	"knuckle": "Az dönen ölü yaprak şutunun düzensiz hava hareketi."
}
const Physics = preload("res://scripts/physics_settings.gd")
var picker: Picker
var contact_label: Label
var wall_distance_label: Label
var distance_slider: HSlider
var lateral_slider: HSlider
var wall_slider: HSlider
var difficulty_select: OptionButton
var camera_select: OptionButton
var trace_toggle: CheckButton
var power_bar: ProgressBar
var power_label: Label
var result_label: Label
var detail_label: Label
var stats_label: Label
var speed_label: Label
var distance_label: Label
var recommendation_label: Label
var fire_button: Button
var training_panel: PanelContainer
var training_button: Button
var setting_controls: Array[Control] = []
var locked := false
var recommended := 0.55
var root: Control
var goal_card: PanelContainer
var replay_button: Button
var cinema_root: Control
var cinema_label: Label
var cinema_stats: Label
var cinema_fade: ColorRect
var advanced_panel: PanelContainer
var advanced_button: Button
var physics_sliders: Dictionary = {}
var updating_physics := false
# Saved node paths keep the layout editable without rebuilding it at runtime.
@export var scene_bindings: Dictionary = {}
@export_range(0, 2) var initial_difficulty := 0
@export_range(17, 30) var initial_distance := 21.0
@export_range(-25, 25) var initial_lateral := 0.0
@export_range(1, 5) var initial_wall_count := 4
@export var show_instructions := true
var reset_button: Button
var menu_button: Button
var guide_button: Button
var next_button: Button
var close_button: Button
var defaults_button: Button
var help_label: Label
var timing_bar: Control
var difficulty_offer: PanelContainer
var magnus_value: SpinBox
var magnus_toggle: CheckButton
var quality_select: OptionButton

func _ready() -> void:
	if not scene_bindings.is_empty():
		preload("res://scripts/scene_bindings.gd").restore(self, scene_bindings)
	else:
		build_layout()
	for node in find_children("*", "Control", true, false):
		if node is Label or node is Button:
			node.text = tr(node.text.replace("\r\n", "\n"))
		if node is OptionButton:
			for index in node.item_count:
				node.set_item_text(index, tr(node.get_item_text(index)))
		if node.has_meta("caption") and node.get_meta("caption") is NodePath:
			node.set_meta("caption", node.get_node(node.get_meta("caption")))
	for control in setting_controls:
		control.focus_mode = Control.FOCUS_NONE
	set_slider_value(distance_slider, initial_distance)
	set_slider_value(lateral_slider, initial_lateral)
	set_slider_value(wall_slider, initial_wall_count)
	difficulty_select.select(initial_difficulty)
	help_label.visible = show_instructions
	timing_bar = root.get_node_or_null("TimingBar")
	if timing_bar == null:
		timing_bar = preload("res://scenes/ui/timing_bar.tscn").instantiate()
		root.add_child(timing_bar)
		anchor(timing_bar, Control.PRESET_CENTER_BOTTOM, Rect2(-250, -200, 500, 108))
	difficulty_offer = root.get_node_or_null("DifficultyOffer")
	if difficulty_offer == null:
		difficulty_offer = preload("res://scenes/ui/difficulty_offer.tscn").instantiate()
		root.add_child(difficulty_offer)
		anchor(difficulty_offer, Control.PRESET_CENTER_TOP, Rect2(-235, 120, 470, 176))
	timing_bar.get_node("Title").text = tr("VURUŞ ZAMANLAMASI")
	timing_bar.pressed.connect(func(): timing_pressed.emit())
	difficulty_offer.get_node("Column/Buttons/Accept").pressed.connect(func(): difficulty_accepted.emit())
	difficulty_offer.get_node("Column/Buttons/Decline").pressed.connect(func(): difficulty_declined.emit())
	quality_select = advanced_panel.find_child("QualityMode", true, false)
	if quality_select == null:
		var column: VBoxContainer = advanced_panel.find_children("*", "VBoxContainer", true, false)[0]
		var caption := Label.new()
		caption.text = tr("GÖRSEL KALİTE")
		column.add_child(caption)
		column.move_child(caption, 2)
		quality_select = OptionButton.new()
		quality_select.name = "QualityMode"
		for text in ["Low", "Medium", "High"]: quality_select.add_item(text)
		column.add_child(quality_select)
		column.move_child(quality_select, caption.get_index() + 1)
	quality_select.focus_mode = Control.FOCUS_NONE
	quality_select.select(preload("res://scripts/quality_settings.gd").current().level)
	quality_select.item_selected.connect(func(level): quality_requested.emit(level))
	setting_controls.append(quality_select)
	magnus_toggle = CheckButton.new()
	magnus_toggle.name = "MagnusEffect"
	magnus_toggle.text = tr("Magnus etkisi")
	magnus_toggle.tooltip_text = tr("Spin kaynaklı hava kuvvetini açar / kapatır. Şiddetini falso ayarıyla değiştir.")
	magnus_toggle.focus_mode = Control.FOCUS_NONE
	var physics_column: VBoxContainer = quality_select.get_parent()
	physics_column.add_child(magnus_toggle)
	physics_column.move_child(magnus_toggle, quality_select.get_index() + 1)
	magnus_toggle.set_pressed_no_signal(Physics.magnus_enabled())
	magnus_toggle.toggled.connect(func(enabled):
		if locked: return
		Physics.set_magnus_enabled(enabled)
		settings_changed.emit())
	setting_controls.append(magnus_toggle)
	var magnus_row := HBoxContainer.new()
	physics_column.add_child(magnus_row)
	physics_column.move_child(magnus_row, magnus_toggle.get_index() + 1)
	var magnus_caption := Label.new()
	magnus_caption.text = tr("Magnus şiddeti")
	magnus_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	magnus_row.add_child(magnus_caption)
	magnus_value = SpinBox.new()
	magnus_value.name = "MagnusValue"
	magnus_value.min_value = Physics.RANGES.curl.x
	magnus_value.max_value = Physics.RANGES.curl.y
	magnus_value.step = 0.01
	magnus_value.suffix = " ×"
	magnus_value.custom_minimum_size.x = 110
	magnus_value.tooltip_text = tr("Magnus şiddeti") + " · 0.00–1.50"
	magnus_row.add_child(magnus_value)
	magnus_value.set_value_no_signal(Physics.get_value("curl"))
	magnus_value.value_changed.connect(func(value):
		if locked or updating_physics: return
		Physics.set_value("curl", value)
		sync_physics_controls()
		settings_changed.emit())
	physics_sliders.curl.step = 0.01
	setting_controls.append(magnus_value)
	physics_sliders.curl.set_meta("title", "Magnus şiddeti")
	wire_controls()
	if picker.tooltip_text.is_empty():
		picker.tooltip_text = tr("Alt: yükseliş · Üst: alçak şut · Yan: falso")
	if fire_button.tooltip_text.is_empty():
		fire_button.tooltip_text = tr("Basılı tutarken güç dolar. Bıraktığında oyuncu şutu çeker.")
	if distance_slider.tooltip_text.is_empty():
		distance_slider.tooltip_text = tr("Kale çizgisine uzaklık. Top ceza sahasının dışında kalır.")
	if lateral_slider.tooltip_text.is_empty():
		lateral_slider.tooltip_text = tr("Eksi: sol taraf · Artı: sağ taraf")
	for key in physics_sliders:
		if physics_sliders[key].tooltip_text.is_empty():
			physics_sliders[key].tooltip_text = tr(PHYSICS_HELP[key])

func build_layout() -> void:
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", Color("f2f6e7"))
	theme.set_color("font_color", "Button", Color("f2f6e7"))
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.8))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 2)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := panel_style(Color(0.035, 0.06, 0.025, 0.65 if state == "normal" else 0.85))
		style.set_content_margin_all(9)
		theme.set_stylebox(state, "Button", style)
		theme.set_stylebox(state, "OptionButton", style)
	root.theme = theme
	var title := label(root, tr("SERBEST VURUŞ"), 19)
	title.position = Vector2(32, 26)
	title.modulate.a = 0.85
	stats_label = label(root, "", 16)
	anchor(stats_label, Control.PRESET_TOP_RIGHT, Rect2(-280, 25, 246, 30))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	training_button = Button.new()
	root.add_child(training_button)
	training_button.text = tr("ANTRENMAN  [Tab]")
	anchor(training_button, Control.PRESET_TOP_RIGHT, Rect2(-210, 67, 176, 36))
	training_button.focus_mode = Control.FOCUS_NONE
	var status := VBoxContainer.new()
	root.add_child(status)
	anchor(status, Control.PRESET_CENTER_TOP, Rect2(-350, 26, 700, 62))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_label = label(status, tr("YÖNÜNÜ SEÇ"), 19)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label = label(status, "", 13, Color("e5ecd7"))
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picker = Picker.new()
	picker.world_mode = true
	root.add_child(picker)
	contact_label = label(root, tr("MERKEZ TEMAS"), 16, Color("e3ff75"))
	anchor(contact_label, Control.PRESET_CENTER_BOTTOM, Rect2(-280, -82, 560, 30))
	contact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label = label(root, tr("1 · Kaleye tıkla: nişan al     2 · Topa tıkla: temas / falso seç\n3 · Boşluk veya Vur: basılı tut, gücü seç; bırakınca şut çek"), 14)
	var help := help_label
	anchor(help, Control.PRESET_CENTER_BOTTOM, Rect2(-385, -46, 770, 44))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var distance_panel := PanelContainer.new()
	root.add_child(distance_panel)
	anchor(distance_panel, Control.PRESET_BOTTOM_LEFT, Rect2(42, -180, 205, 108))
	distance_panel.add_theme_stylebox_override("panel", panel_style(Color(0.03, 0.07, 0.025, 0.62)))
	var distance_column := VBoxContainer.new()
	distance_panel.add_child(distance_column)
	label(distance_column, tr("KALEYE UZAKLIK"), 13, Color("d8eaaa"))
	distance_label = label(distance_column, "21 m", 35)
	speed_label = label(distance_column, tr("Çıkış hızı —"), 13, Color("e3ff75"))
	var power_panel := PanelContainer.new()
	root.add_child(power_panel)
	anchor(power_panel, Control.PRESET_BOTTOM_RIGHT, Rect2(-282, -206, 240, 152))
	power_panel.add_theme_stylebox_override("panel", panel_style(Color(0.03, 0.07, 0.025, 0.66)))
	var power_column := VBoxContainer.new()
	power_column.add_theme_constant_override("separation", 7)
	power_panel.add_child(power_column)
	power_label = label(power_column, tr("GÜÇ %0"), 16)
	power_bar = ProgressBar.new()
	power_bar.custom_minimum_size = Vector2(204, 12)
	power_bar.show_percentage = false
	var background := panel_style(Color("344b27"))
	background.set_content_margin_all(0)
	var fill := panel_style(Color("d9fa70"))
	fill.set_content_margin_all(0)
	power_bar.add_theme_stylebox_override("background", background)
	power_bar.add_theme_stylebox_override("fill", fill)
	power_column.add_child(power_bar)
	recommendation_label = label(power_column, tr("ÖNERİ: %50–65"), 13, Color("e3ff75"))
	fire_button = Button.new()
	fire_button.text = tr("BASILI TUT → BIRAK / VUR")
	fire_button.focus_mode = Control.FOCUS_NONE
	power_column.add_child(fire_button)
	reset_button = Button.new()
	var reset := reset_button
	reset.text = tr("TEKRAR  [R]")
	reset.focus_mode = Control.FOCUS_NONE
	root.add_child(reset)
	anchor(reset, Control.PRESET_BOTTOM_LEFT, Rect2(42, -56, 205, 32))
	build_training()
	build_advanced()
	build_goal_card()
	build_cinema()
	menu_button = Button.new()
	var menu := menu_button
	root.add_child(menu)
	menu.text = tr("ANA MENÜ  [Esc]")
	menu.focus_mode = Control.FOCUS_NONE
	anchor(menu, Control.PRESET_TOP_LEFT, Rect2(32, 67, 200, 36))
	guide_button = Button.new()
	var guide := guide_button
	root.add_child(guide)
	guide.text = "?"
	guide.focus_mode = Control.FOCUS_NONE
	anchor(guide, Control.PRESET_TOP_LEFT, Rect2(240, 67, 40, 36))
	for control in setting_controls:
		control.focus_mode = Control.FOCUS_NONE

func anchor(control: Control, preset: int, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(preset)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y

func panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	style.set_content_margin_all(14)
	return style

func label(parent: Node, text: String, font_size: int, color: Color = Color("f2f6e7")) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.modulate = color
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func build_training() -> void:
	training_panel = PanelContainer.new()
	root.add_child(training_panel)
	anchor(training_panel, Control.PRESET_TOP_RIGHT, Rect2(-292, 153, 258, 440))
	training_panel.add_theme_stylebox_override("panel", panel_style(Color(0.025, 0.045, 0.025, 0.96)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	training_panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	label(column, tr("ANTRENMAN AYARLARI"), 17)
	distance_slider = slider(column, "Uzaklık", 17, 30, 21, " m")
	lateral_slider = slider(column, "Yatay konum", -25, 25, 0, " m")
	wall_slider = slider(column, "Baraj", 1, 5, 4, tr(" kişi"))
	wall_distance_label = label(column, tr("Baraj mesafesi: —"), 13, Color("d8eaaa"))
	label(column, tr("KALECİ ZORLUĞU"), 13)
	difficulty_select = OptionButton.new()
	for item in [tr("Kolay"), tr("Dengeli"), tr("Zor")]:
		difficulty_select.add_item(item)
	difficulty_select.select(initial_difficulty)
	column.add_child(difficulty_select)
	setting_controls.append(difficulty_select)
	label(column, tr("Kolay: daha geç tepki, kısa uzanış.\nDengeli: köşeler hâlâ gol olabilir.\nZor: hızlı tepki ve iyi falso okuma."), 12, Color("d8eaaa"))
	label(column, tr("KAMERA"), 13)
	camera_select = OptionButton.new()
	camera_select.add_item(tr("Top odaklı"))
	camera_select.add_item(tr("Oyuncu arkası / üstü"))
	column.add_child(camera_select)
	setting_controls.append(camera_select)
	trace_toggle = CheckButton.new()
	trace_toggle.text = tr("Uçuş izi")
	trace_toggle.button_pressed = true
	trace_toggle.focus_mode = Control.FOCUS_NONE
	column.add_child(trace_toggle)
	label(column, tr("Alt temas: yükselt • Üst: alçalt\nSağ temas: sola falso\nSol temas: sağa falso\nMerkezin hafif altı: ölü yaprak"), 13, Color("d8eaaa"))
	training_panel.visible = false

func slider(parent: Node, title: String, minimum: float, maximum: float, initial: float, suffix: String) -> HSlider:
	var caption := label(parent, tr(title) + ": " + str(int(initial)) + tr(suffix), 14)
	var item := HSlider.new()
	item.min_value = minimum
	item.max_value = maximum
	item.step = 1
	item.value = initial
	item.custom_minimum_size.y = 20
	parent.add_child(item)
	item.set_meta("caption", caption)
	item.set_meta("title", title)
	item.set_meta("suffix", suffix)
	setting_controls.append(item)
	return item

func set_slider_value(item: HSlider, value: float) -> void:
	item.set_value_no_signal(value)
	var caption: Label = item.get_meta("caption")
	caption.text = tr(item.get_meta("title")) + ": " + str(int(item.value)) + tr(item.get_meta("suffix"))

func toggle_training() -> void:
	training_panel.visible = not training_panel.visible
	advanced_panel.visible = false

func build_advanced() -> void:
	advanced_button = Button.new()
	root.add_child(advanced_button)
	advanced_button.text = tr("GELİŞMİŞ ÖZELLİKLER")
	advanced_button.focus_mode = Control.FOCUS_NONE
	anchor(advanced_button, Control.PRESET_TOP_RIGHT, Rect2(-258, 107, 224, 36))
	advanced_panel = PanelContainer.new()
	root.add_child(advanced_panel)
	anchor(advanced_panel, Control.PRESET_TOP_RIGHT, Rect2(-336, 153, 302, 384))
	advanced_panel.add_theme_stylebox_override("panel", panel_style(Color(0.025, 0.045, 0.035, 0.97)))
	var scroll := ScrollContainer.new()
	advanced_panel.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 9)
	scroll.add_child(column)
	label(column, tr("TOP FİZİĞİ"), 17)
	label(column, tr("Ayarlar yeni denemeye uygulanır.\nUçuş ve tekrar sırasında kilitlenir."), 12, Color("d8eaaa"))
	var fields := [["mass", tr("Kütle"), 0.01, " kg"], ["strength", tr("Vuruş kuvveti"), 0.01, " ×"], ["gravity", tr("Yerçekimi"), 0.1, " m/s²"], ["drag", tr("Hava direnci"), 0.05, " ×"], ["curl", tr("Falso etkisi"), 0.05, " ×"], ["bounce", tr("Sekme"), 0.01, ""], ["friction", tr("Zemin sürtünmesi"), 0.01, ""], ["knuckle", tr("Ölü yaprak etkisi"), 0.05, " ×"]]
	for field in fields:
		var key: String = field[0]
		var caption := label(column, "", 13)
		var item := HSlider.new()
		var limits: Vector2 = Physics.RANGES[key]
		item.min_value = limits.x
		item.max_value = limits.y
		item.step = field[2]
		item.value = Physics.get_value(key)
		item.custom_minimum_size.y = 20
		item.focus_mode = Control.FOCUS_NONE
		column.add_child(item)
		physics_sliders[key] = item
		setting_controls.append(item)
		var title: String = field[1]
		var suffix: String = field[3]
		caption.text = "%s: %.2f%s" % [title, item.value, suffix]
		item.set_meta("caption", caption)
		item.set_meta("title", field[1])
		item.set_meta("suffix", suffix)
		item.set_meta("physics_key", key)
	defaults_button = Button.new()
	var defaults := defaults_button
	defaults.text = tr("FİZİĞİ VARSAYILANA DÖNDÜR")
	defaults.focus_mode = Control.FOCUS_NONE
	column.add_child(defaults)
	advanced_panel.visible = false

func set_locked(value: bool) -> void:
	locked = value
	picker.locked = value
	for item in setting_controls:
		if item is HSlider or item is SpinBox:
			item.editable = not value
		elif item is BaseButton:
			item.disabled = value
		item.modulate.a = 0.45 if value else 1.0
	fire_button.disabled = value
	if value:
		training_panel.visible = false
		advanced_panel.visible = false

func set_training_info(distance: float, suggested_power: float) -> void:
	distance_label.text = "%.0f m" % distance
	recommended = suggested_power
	recommendation_label.text = tr("ÖNERİ: %%%d–%d") % [roundi(maxf(0, recommended - 0.07) * 100), roundi(minf(1, recommended + 0.07) * 100)]

func set_contact_info(point: Vector2) -> void:
	if preload("res://shot_model.gd").knuckle_contact(point) > 0.55:
		contact_label.text = tr("ÖLÜ YAPRAK BÖLGESİ · DÜŞÜK DÖNÜŞ · GÜÇ %55+")
		return
	var height := tr("ALT TEMAS · YÜKSELEN") if point.y < -0.15 else (tr("ÜST TEMAS · ALÇAK") if point.y > 0.15 else tr("MERKEZ TEMAS"))
	var curve := tr(" · SOLA FALSO") if point.x > 0.15 else (tr(" · SAĞA FALSO") if point.x < -0.15 else "")
	contact_label.text = height + curve

func position_contact(camera: Camera3D, location: Vector3) -> void:
	var center := camera.unproject_position(location)
	var edge := camera.unproject_position(location + camera.global_basis.x * 0.11)
	var diameter := clampf(center.distance_to(edge) / 0.43, 40, 140)
	picker.size = Vector2.ONE * diameter
	picker.position = center - picker.size * 0.5
	picker.queue_redraw()

func set_power(value: float) -> void:
	power_bar.value = value * 100
	power_label.text = tr("GÜÇ %%%d") % roundi(value * 100)
	power_label.modulate = Color("e3ff75") if absf(value - recommended) <= 0.07 else Color("f2f6e7")

func set_status(title: String, detail: String) -> void:
	result_label.text = tr(title)
	detail_label.text = tr(detail)

func set_stats(attempts: int, goals: int) -> void:
	stats_label.text = tr("%d GOL  /  %d ŞUT") % [goals, attempts]

func build_goal_card() -> void:
	goal_card = PanelContainer.new()
	root.add_child(goal_card)
	anchor(goal_card, Control.PRESET_CENTER, Rect2(-170, 90, 340, 182))
	var style := panel_style(Color(0.025, 0.045, 0.035, 0.96))
	style.border_color = Color("d9fa70")
	style.set_border_width_all(1)
	goal_card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 9)
	goal_card.add_child(column)
	var title := label(column, tr("GOL!"), 26, Color("e3ff75"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var caption := label(column, tr("7 kamera · Sinematik ağır çekim"), 14)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_button = Button.new()
	replay_button.text = tr("GOLÜ İZLE  ▶")
	replay_button.focus_mode = Control.FOCUS_NONE
	column.add_child(replay_button)
	next_button = Button.new()
	var next := next_button
	next.text = tr("SONRAKİ ŞUT  [R]")
	next.focus_mode = Control.FOCUS_NONE
	column.add_child(next)
	goal_card.visible = false

func show_goal_card(ready: bool) -> void:
	goal_card.visible = true
	replay_button.disabled = not ready
	replay_button.text = tr("GOLÜ İZLE  ▶") if ready else tr("Tekrar hazırlanıyor…")

func build_cinema() -> void:
	cinema_root = Control.new()
	add_child(cinema_root)
	cinema_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cinema_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinema_root.theme = root.theme
	for preset in [Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE]:
		var bar := ColorRect.new()
		cinema_root.add_child(bar)
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(preset)
		bar.offset_top = 0 if preset == Control.PRESET_TOP_WIDE else -58
		bar.offset_bottom = 58 if preset == Control.PRESET_TOP_WIDE else 0
	cinema_label = label(cinema_root, tr("GOL TEKRARI"), 17)
	anchor(cinema_label, Control.PRESET_CENTER_TOP, Rect2(-360, 18, 720, 32))
	cinema_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cinema_stats = label(cinema_root, "", 16)
	anchor(cinema_stats, Control.PRESET_BOTTOM_WIDE, Rect2(20, -47, -20, 40))
	cinema_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button = Button.new()
	var close := close_button
	cinema_root.add_child(close)
	close.text = tr("GERİ DÖN  [Esc]")
	anchor(close, Control.PRESET_TOP_RIGHT, Rect2(-206, 12, 188, 36))
	close.focus_mode = Control.FOCUS_NONE
	cinema_fade = ColorRect.new()
	cinema_root.add_child(cinema_fade)
	cinema_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cinema_fade.color = Color(0, 0, 0, 0)
	cinema_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinema_root.visible = false

func set_replay(value: bool) -> void:
	root.visible = not value
	cinema_root.visible = value

func wire_controls() -> void:
	training_button.pressed.connect(toggle_training)
	advanced_button.pressed.connect(func():
		advanced_panel.visible = not advanced_panel.visible
		training_panel.visible = false)
	fire_button.button_down.connect(func(): charge_started.emit())
	fire_button.button_up.connect(func(): charge_released.emit())
	reset_button.pressed.connect(func(): reset_requested.emit())
	next_button.pressed.connect(func(): reset_requested.emit())
	menu_button.pressed.connect(func(): menu_requested.emit())
	guide_button.pressed.connect(func(): guide_requested.emit())
	close_button.pressed.connect(func(): replay_closed.emit())
	replay_button.pressed.connect(func(): replay_requested.emit())
	goal_card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not replay_button.disabled:
			goal_card.accept_event()
			replay_requested.emit())
	for item in [distance_slider, lateral_slider, wall_slider]:
		item.value_changed.connect(func(value):
			set_slider_value(item, value)
			settings_changed.emit())
	for item in [difficulty_select, camera_select]:
		item.item_selected.connect(func(_index): settings_changed.emit())
	for key in physics_sliders:
		var item: HSlider = physics_sliders[key]
		item.value = Physics.get_value(key)
		update_physics_caption(item)
		item.value_changed.connect(func(value):
			Physics.set_value(key, value)
			if key == "curl" and magnus_value != null: magnus_value.set_value_no_signal(Physics.get_value("curl"))
			update_physics_caption(item)
			if not updating_physics:
				settings_changed.emit())
	defaults_button.pressed.connect(func():
		if locked:
			return
		Physics.reset()
		updating_physics = true
		for key in physics_sliders:
			physics_sliders[key].set_value_no_signal(Physics.get_value(key))
			update_physics_caption(physics_sliders[key])
		updating_physics = false
		settings_changed.emit())
	for node in find_children("*", "Control", true, false):
		if node.has_meta("caption") and node.get_meta("caption") is NodePath:
			node.set_meta("caption", node.get_node(node.get_meta("caption")))

func update_physics_caption(item: HSlider) -> void:
	var caption = item.get_meta("caption")
	if caption is NodePath:
		caption = item.get_node(caption)
	var key := ""
	for candidate in physics_sliders:
		if physics_sliders[candidate] == item:
			key = candidate
			break
	caption.text = "%s: %.2f%s" % [tr(item.get_meta("title")), Physics.get_value(key) if not key.is_empty() else item.value, item.get_meta("suffix")]

func sync_physics_controls() -> void:
	updating_physics = true
	if magnus_toggle != null: magnus_toggle.set_pressed_no_signal(Physics.magnus_enabled())
	if magnus_value != null: magnus_value.set_value_no_signal(Physics.get_value("curl"))
	for key in physics_sliders:
		var item: HSlider = physics_sliders[key]
		item.set_value_no_signal(Physics.get_value(key))
		update_physics_caption(item)
	updating_physics = false

func set_timing_visible(value: bool) -> void:
	timing_bar.visible = value
	if value:
		timing_bar.progress = 0
		timing_bar.glow_clock = 0
		timing_bar.set_rating("")
		fire_button.disabled = false
		fire_button.text = tr("TEKRAR BAS: ZAMANLA")
	else:
		fire_button.disabled = locked
		fire_button.text = tr("BASILI TUT → BIRAK / VUR")

func show_difficulty_offer(level: int) -> void:
	if level > 2:
		return
	difficulty_offer.get_node("Column/Title").text = tr("3 GOL! · YENİ BİR MEYDAN OKUMA?")
	difficulty_offer.get_node("Column/Detail").text = tr("Kaleciyi %s seviyesine yükseltmek ister misin?") % tr("Dengeli" if level == 1 else "Zor")
	difficulty_offer.get_node("Column/Buttons/Accept").text = tr("SEVİYEYİ YÜKSELT")
	difficulty_offer.get_node("Column/Buttons/Decline").text = tr("BU SEVİYEDE KAL")
	difficulty_offer.visible = true
