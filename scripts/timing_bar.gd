@tool
extends Control

signal pressed
@export_range(0.3, 0.7) var orange_start := 0.55
@export_range(0.75, 0.95) var green_start := 0.82
@export var red_color := Color("e65555")
@export var orange_color := Color("ffbc50")
@export var green_color := Color("7efa9a")
var progress := 0.0
var rating := ""
var glow_clock := 0.0

func update_progress(value: float) -> void:
	progress = clampf(value, 0, 1)
	queue_redraw()

func set_rating(value: String) -> void:
	rating = value
	get_node("Hint").text = tr({"perfect": "MÜKEMMEL! · GÜÇ + İSABET", "normal": "NORMAL VURUŞ", "bad": "ERKEN! · ZAYIF VE SAPMALI", "": "Boşluk / Vur: tekrar bas · Basmazsan normal şut"}[value])
	queue_redraw()

func _process(delta: float) -> void:
	if is_visible_in_tree() and rating == "perfect":
		glow_clock += delta
		queue_redraw()

func _draw() -> void:
	var track := Rect2(18, 33, size.x - 36, 16)
	if rating == "perfect":
		var pulse := 0.30 + (sin(glow_clock * 28) + 1) * 0.18
		draw_rect(track.grow(8), Color(green_color, pulse))
		if has_node("Hint"):
			get_node("Hint").modulate = green_color
	else:
		if has_node("Hint"):
			get_node("Hint").modulate = Color.WHITE
	for index in range(96):
		var t := float(index) / 95
		var color := red_color.lerp(orange_color, t / orange_start) if t < orange_start else orange_color.lerp(green_color, (t - orange_start) / (1 - orange_start))
		draw_rect(Rect2(track.position + Vector2(track.size.x * t, 0), Vector2(track.size.x / 95 + 1, track.size.y)), color)
	for boundary in [orange_start, green_start]:
		var x: float = track.position.x + boundary * track.size.x
		draw_line(Vector2(x, track.position.y - 2), Vector2(x, track.end.y + 2), Color(0.02, 0.05, 0.08, 0.9), 2)
	var needle_x := track.position.x + progress * track.size.x
	draw_colored_polygon(PackedVector2Array([Vector2(needle_x, 52), Vector2(needle_x - 6, 63), Vector2(needle_x + 6, 63)]), green_color if rating == "perfect" else Color.WHITE)
	draw_line(Vector2(needle_x, 30), Vector2(needle_x, 50), Color.WHITE, 2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()
		accept_event()
