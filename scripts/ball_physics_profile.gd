@tool
extends Resource

@export var profile_name := "Arcade — mevcut oyun"
@export_multiline var provenance := "Eski FreeKick parametreleri; deneysel kalibrasyon değildir."

@export_range(0.35, 0.65) var mass := 0.46
@export_range(0.75, 1.30) var strength := 0.98
@export_range(7.0, 13.0) var gravity := 9.8
@export_range(0.5, 2.0) var drag := 1.10
@export var magnus_enabled := true
@export_range(0.0, 1.5) var curl := 0.80
@export_range(0.1, 0.65) var bounce := 0.32
@export_range(0.35, 0.95) var friction := 0.72
@export_range(0.0, 2.5) var knuckle := 1.50

@export_group("Top boyutu")
@export_range(0.08, 0.15, 0.001, "suffix:m") var radius := 0.11

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for key in ["mass", "radius", "gravity", "strength", "drag", "curl", "bounce", "friction", "knuckle"]:
		if not is_finite(get(key)) or get(key) < 0:
			errors.append("%s sonlu ve negatif olmayan değer olmalıdır." % key)
	if mass <= 0 or radius <= 0:
		errors.append("Kütle ve yarıçap pozitif olmalıdır.")
	if bounce > 1 or friction > 1:
		errors.append("Sekme ve sürtünme 0–1 aralığında olmalıdır.")
	return errors

func apply() -> void:
	preload("res://scripts/physics_settings.gd").configure(self)
