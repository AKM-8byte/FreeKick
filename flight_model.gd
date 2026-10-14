extends RefCounted
const Settings = preload("res://scripts/physics_settings.gd")

const MASS := 0.43
const DRAG := 0.0013
const MAGNUS := 0.0018
const GRAVITY := 9.8
const SPIN_DECAY := 0.22

static func force(velocity: Vector3, spin: Vector3, profile: Resource = null) -> Vector3:
	var drag: float = profile.drag if profile else Settings.get_value("drag")
	var curl: float = profile.curl if profile else Settings.get_value("curl")
	if not Settings.magnus_enabled(profile): curl = 0.0
	return -velocity * velocity.length() * DRAG * drag + (spin.cross(velocity) * MAGNUS * curl).limit_length(4.8 * curl)

static func decay_spin(spin: Vector3, step: float, profile: Resource = null) -> Vector3:
	return spin / (1.0 + SPIN_DECAY * step)

static func effective_mass() -> float:
	return Settings.get_value("mass")

static func gravity() -> float:
	return Settings.get_value("gravity")

static func crossing_at_distance(distance: float, velocity: Vector3, spin: Vector3, axis: Vector3, initial_height: float) -> Vector3:
	var position := Vector3(0, initial_height, 0)
	const STEP := 1.0 / 120.0
	for _step in range(600):
		var previous := position
		velocity += (force(velocity, spin) / effective_mass() + Vector3.DOWN * gravity()) * STEP
		spin = decay_spin(spin, STEP)
		position += velocity * STEP
		var progress := position.dot(axis)
		if progress >= distance:
			var fraction := (distance - previous.dot(axis)) / (progress - previous.dot(axis))
			return previous.lerp(position, fraction)
	return Vector3(0, -100, 0)

static func crossing_at_z(position: Vector3, velocity: Vector3, spin: Vector3, plane: float, max_time: float = 2.0) -> Dictionary:
	const STEP := 1.0 / 120.0
	for index in range(ceili(max_time / STEP)):
		var previous := position
		velocity += (force(velocity, spin) / effective_mass() + Vector3.DOWN * gravity()) * STEP
		spin = decay_spin(spin, STEP)
		position += velocity * STEP
		if position.z <= plane and previous.z > plane:
			var fraction := (plane - previous.z) / (position.z - previous.z)
			return {"position": previous.lerp(position, fraction), "time": (index + fraction) * STEP}
	return {"position": position, "time": max_time}

static func keeper_crossing(position: Vector3, velocity: Vector3, spin: Vector3) -> Dictionary:
	var radius: float = Settings.active_profile.radius if Settings.active_profile else 0.11
	const STEP := 1.0 / 120.0
	for index in range(480):
		var previous := position
		velocity += (force(velocity, spin) / effective_mass() + Vector3.DOWN * gravity()) * STEP
		spin = decay_spin(spin, STEP)
		position += velocity * STEP
		if position.y < radius + 0.003:
			position.y = radius + 0.003
			velocity.y = -velocity.y * Settings.get_value("bounce") if velocity.y < -0.8 else 0.0
			velocity.x *= exp(-0.45 * STEP)
			velocity.z *= exp(-0.45 * STEP)
		if position.z <= 0.80 and previous.z > 0.80:
			var fraction := (0.80 - previous.z) / (position.z - previous.z)
			return {"position": previous.lerp(position, fraction), "time": (index + fraction) * STEP}
	return {"position": position, "time": 4.0}

static func height_at_distance(distance: float, speed: float, angle: float, initial_height: float) -> float:
	var position := Vector3(0, initial_height, 0)
	var velocity := Vector3(0, sin(angle), cos(angle)) * speed
	const STEP := 1.0 / 120.0
	for _step in range(600):
		var previous := position
		velocity += (force(velocity, Vector3.ZERO) / effective_mass() + Vector3.DOWN * gravity()) * STEP
		position += velocity * STEP
		if position.z >= distance:
			return lerpf(previous.y, position.y, (distance - previous.z) / (position.z - previous.z))
	return -100.0
