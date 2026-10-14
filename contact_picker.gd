extends Control

signal selected(point: Vector2)
var point := Vector2.ZERO
var locked := false
@export var world_mode := false

func _ready() -> void:
	custom_minimum_size = Vector2.ZERO if world_mode else Vector2(220, 200)
	mouse_default_cursor_shape = Control.CURSOR_CROSS

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	if world_mode:
		var ink := Color("efffd5")
		var edge := radius + 8
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				var corner := center + Vector2(sx, sy) * edge
				draw_line(corner, corner - Vector2(sx * 12, 0), ink, 2, true)
				draw_line(corner, corner - Vector2(0, sy * 12), ink, 2, true)
		var hit := center + Vector2(point.x, -point.y) * radius
		draw_circle(hit, 4, Color("e3ff75"))
		draw_arc(hit, 7, 0, TAU, 24, ink, 1.5, true)
		return
	draw_circle(center + Vector2(0, 5), radius + 4, Color("0a1324"))
	draw_circle(center, radius, Color("edf4fa"))
	draw_arc(center, radius, 0, TAU, 80, Color("91a9bd"), 2, true)
	for x in [-0.5, 0.0, 0.5]:
		var extent := sqrt(1 - x * x) * radius
		draw_line(center + Vector2(x * radius, -extent), center + Vector2(x * radius, extent), Color("bcc9d5"), 1, true)
		draw_line(center + Vector2(-extent, x * radius), center + Vector2(extent, x * radius), Color("bcc9d5"), 1, true)
	var hex := PackedVector2Array()
	for i in range(6):
		hex.append(center + Vector2.from_angle(TAU * i / 6.0) * radius * 0.25)
	draw_colored_polygon(hex, Color("223247"))
	var cursor := center + Vector2(point.x, -point.y) * radius
	draw_circle(cursor, 10, Color("ffbd59"))
	draw_circle(cursor, 4, Color("17283b"))
	draw_arc(cursor, 14, 0, TAU, 32, Color("ffbd59"), 2, true)

func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var radius := minf(size.x, size.y) * 0.43
		var local: Vector2 = (event.position - size * 0.5) / radius
		point = Vector2(local.x, -local.y).limit_length(0.98)
		queue_redraw()
		selected.emit(point)
		accept_event()
