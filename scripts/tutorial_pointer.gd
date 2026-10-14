extends Control
var origin := Vector2.ZERO
var destination := Vector2.ZERO
func _draw() -> void:
	var direction := (destination - origin).normalized()
	var end := destination - direction * 18
	draw_line(origin, end, Color("d9fa70"), 2, true)
	var normal := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([end, end - direction * 13 + normal * 6, end - direction * 13 - normal * 6]), Color("d9fa70"))
	draw_arc(destination, 12, 0, TAU, 24, Color("d9fa70"), 2, true)
