extends Control

var game: Node3D
var boxes: Array[PanelContainer] = []
var destinations: Array[Vector2] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.30)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	for message in ["Hedef: kaleye tıklayarak veya sürükleyerek nişan al.", "Temas: topun yanına vurmak falso, altına vurmak yükseliş verir.", "Ayarlar: uzaklık, baraj, kaleci ve top fiziğini buradan değiştir.", "Güç: Boşluk veya VUR düğmesini basılı tut; bırakarak şut çek."]:
		var box := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("142d29")
		style.border_color = Color("d9fa70")
		style.set_border_width_all(1)
		style.set_content_margin_all(14)
		box.add_theme_stylebox_override("panel", style)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		var label := Label.new()
		label.text = tr(message)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(245, 65)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
		boxes.append(box)
	var footer := Label.new()
	footer.text = tr("Herhangi bir tuşa bas veya tıkla: tanıtımı kapat.")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 20)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.offset_left = -360
	footer.offset_right = 360
	footer.offset_top = -115
	footer.offset_bottom = -75

func _process(_delta: float) -> void:
	boxes[0].position = Vector2(size.x * 0.05, size.y * 0.20)
	boxes[1].position = Vector2(size.x * 0.08, size.y * 0.56)
	boxes[2].position = Vector2(size.x * 0.67, size.y * 0.24)
	boxes[3].position = Vector2(size.x * 0.65, size.y * 0.55)
	destinations = [game.camera.unproject_position(game.target), game.hud.picker.position + game.hud.picker.size * 0.5, game.hud.training_button.get_global_rect().get_center(), game.hud.fire_button.get_global_rect().get_center()]
	queue_redraw()

func _draw() -> void:
	for i in destinations.size():
		var end := destinations[i]
		var rect := boxes[i].get_rect()
		var centre := rect.get_center()
		var direction := (end - centre).normalized()
		var start := centre + direction * minf(rect.size.x / maxf(absf(direction.x), 0.001), rect.size.y / maxf(absf(direction.y), 0.001)) * 0.5
		draw_line(start, end, Color("d9fa70"), 3, true)
		var normal := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([end, end - direction * 15 + normal * 7, end - direction * 15 - normal * 7]), Color("d9fa70"))
		draw_arc(end, 13, 0, TAU, 32, Color("d9fa70"), 2, true)

func dismiss() -> void:
	get_node("/root/Locale").mark_guide_seen()
	game.guide = null
	queue_free()

