extends CanvasLayer

const Bindings = preload("res://scripts/input_bindings.gd")
var game: Node3D
var stage := 0
var aimed := false
var charged := false
var curved := false
var practice_start := 0
var completed := false
var title: Label
var instructions: Label
var feedback: Label
var next_button: Button
var skip_button: Button
var pointer: Control

func _ready() -> void:
	layer = 30
	name = "InteractiveTutorial"
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.position = Vector2(28, 118)
	panel.custom_minimum_size.x = 390
	var style := StyleBoxFlat.new()
	style.bg_color = Color("132e28")
	style.border_color = Color("d9fa70")
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 23)
	column.add_child(title)
	instructions = Label.new()
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.custom_minimum_size.x = 352
	instructions.add_theme_font_size_override("font_size", 17)
	column.add_child(instructions)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(feedback)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	next_button = Button.new()
	next_button.custom_minimum_size = Vector2(170, 48)
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.pressed.connect(advance)
	buttons.add_child(next_button)
	skip_button = Button.new()
	skip_button.text = tr("TANITIMI ATLA")
	skip_button.custom_minimum_size = Vector2(130, 48)
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.pressed.connect(func(): get_node("/root/Flow").finish_tutorial(true))
	buttons.add_child(skip_button)
	pointer = preload("res://scripts/tutorial_pointer.gd").new()
	root.add_child(pointer)
	pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.aim_changed.connect(func(_target): aimed = true)
	game.ball.struck.connect(func(_speed):
		if stage == 1 and game.power >= settings().minimum_power: charged = true
		if stage == 2 and absf(game.hud.picker.point.x) >= settings().minimum_side_contact: curved = true)
	game.hud.difficulty_select.select(settings().goalkeeper_level)
	game.new_position_pending = false
	game.reset_attempt()
	show_stage()

func settings() -> Resource: return get_node("/root/Flow").tutorial_settings

func show_stage() -> void:
	title.text = tr(["1 / 4 · NİŞAN AL", "2 / 4 · GÜCÜ AYARLA", "3 / 4 · FALSO VER", "4 / 4 · SERBEST DENEME"][stage])
	var messages := [tr("Kaleye tıkla veya sürükle. Hedefi seçince Devam'a bas. Yön kontrolleri: %s · %s") % [Bindings.hint("aim_left"), Bindings.hint("aim_right")], tr("%s tuşunu veya VUR düğmesini basılı tut. Güç dolunca bırak; oyuncu topa yaklaşarak vurur.") % Bindings.hint("shoot"), tr("Topun sağ veya sol yanını seç, sonra şut çek. Alt temas yükseltir, üst temas alçaltır. Temas kontrolleri: %s · %s") % [Bindings.hint("contact_left"), Bindings.hint("contact_right")], tr("Öğrendiklerini dene. Gol atman gerekmiyor. %s veya TEKRAR ile yeni şuta geçebilirsin.") % Bindings.hint("reset_shot")]
	instructions.text = messages[stage]
	if stage == 1 and settings().show_timing_tip: instructions.text += "\n" + tr("İkinci basışla zamanlama isteğe bağlıdır; basmazsan normal vurursun.")
	next_button.text = tr("ANA MENÜYE GEÇ") if stage == 3 else tr("DEVAM")
	next_button.tooltip_text = Bindings.hint("tutorial_next")
	skip_button.visible = settings().allow_skip
	completed = false
	if stage == 3: practice_start = game.attempts

func _process(_delta: float) -> void:
	if game == null: return
	game.new_position_pending = false
	game.difficulty_offer_pending = false
	game.hud.difficulty_offer.hide()
	completed = [aimed, charged, curved, game.attempts - practice_start >= settings().practice_shots][stage]
	next_button.disabled = not completed
	feedback.text = tr("Tamamlandı — devam edebilirsin.") if completed else tr("Bu adımı deneyerek tamamla. Gol şart değil.")
	feedback.modulate = Color("d9fa70") if completed else Color("c5d4cf")
	if stage == 0: pointer.destination = game.camera.unproject_position(game.target)
	elif stage == 2: pointer.destination = game.hud.picker.position + game.hud.picker.size * 0.5
	else: pointer.destination = game.hud.fire_button.get_global_rect().get_center()
	pointer.origin = Vector2(418, 160)
	pointer.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tutorial_next") and completed:
		advance()
		get_viewport().set_input_as_handled()

func advance() -> void:
	if not completed: return
	if stage == 3:
		get_node("/root/Flow").finish_tutorial(false)
		return
	stage += 1
	game.new_position_pending = false
	game.reset_attempt()
	show_stage()
