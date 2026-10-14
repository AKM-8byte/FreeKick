extends RefCounted

const DEFAULTS := {"mass": 0.46, "strength": 0.98, "gravity": 9.8, "drag": 1.10, "curl": 0.80, "bounce": 0.32, "friction": 0.72, "knuckle": 0.80}
const RANGES := {"mass": Vector2(0.35, 0.65), "strength": Vector2(0.75, 1.30), "gravity": Vector2(7, 13), "drag": Vector2(0.5, 2), "curl": Vector2(0, 1.5), "bounce": Vector2(0.1, 0.65), "friction": Vector2(0.35, 0.95), "knuckle": Vector2(0, 1.5)}
static var values: Dictionary = DEFAULTS.duplicate()
static var configured_defaults: Dictionary = DEFAULTS.duplicate()
static var active_profile: Resource
static var configured_profile: Resource

static func configure(profile: Resource) -> bool:
	if not profile.validate().is_empty():
		push_error("Geçersiz top fiziği profili: " + "; ".join(profile.validate()))
		return false
	active_profile = profile.duplicate(true)
	for key in DEFAULTS:
		values[key] = active_profile.get(key)
	configured_defaults = values.duplicate()
	configured_profile = active_profile.duplicate(true)
	return true

static func current_radius() -> float:
	return float(active_profile.radius) if active_profile else 0.11

static func set_value(key: String, value: float) -> void:
	if RANGES.has(key) and is_finite(value):
		var limits: Vector2 = RANGES[key]
		values[key] = clampf(value, limits.x, limits.y)
		if active_profile != null:
			active_profile.set(key, values[key])

static func reset() -> void:
	values = configured_defaults.duplicate()
	active_profile = configured_profile.duplicate(true) if configured_profile else null

static func get_value(key: String) -> float:
	if active_profile != null and key in DEFAULTS:
		return float(active_profile.get(key))
	return float(values.get(key, DEFAULTS.get(key, 1.0)))

static func magnus_enabled(profile: Resource = null) -> bool:
	var selected := profile if profile != null else active_profile
	return selected == null or selected.magnus_enabled

static func set_magnus_enabled(enabled: bool) -> void:
	if active_profile == null:
		# Preserve settings modified before a scene profile was configured.
		var profile: Resource = load("res://settings/arcade_physics.tres").duplicate(true)
		for key in DEFAULTS: profile.set(key, get_value(key))
		configure(profile)
	active_profile.magnus_enabled = enabled
