@tool
extends Resource

@export var profile_name := "High"
@export_enum("Low", "Medium", "High") var level: int = 2
@export_range(0.4, 1.0, 0.05) var render_scale := 1.0
@export var shadows := true
@export_enum("Disabled", "2x", "4x", "8x") var msaa: int = 2
@export_range(0, 120, 1, "suffix:Hz") var skeleton_rate := 0.0
@export_range(0.3, 1.0, 0.05) var net_visual_density := 1.0
@export var grass_details := true
@export var stadium_details := true
@export var flight_trail := true

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(render_scale) or render_scale < 0.4 or render_scale > 1:
		errors.append("Render ölçeği 0.4–1.0 olmalıdır.")
	if level < 0 or level > 2 or msaa < 0 or msaa > 3 or not is_finite(skeleton_rate) or skeleton_rate < 0 or skeleton_rate > 120:
		errors.append("MSAA / rig güncelleme oranı geçersiz.")
	if not is_finite(net_visual_density) or net_visual_density < 0.3 or net_visual_density > 1:
		errors.append("File görsel yoğunluğu 0.3–1.0 olmalıdır.")
	return errors
