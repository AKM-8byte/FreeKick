extends RefCounted

const Flight = preload("res://flight_model.gd")

static func quality(progress: float, orange_start: float = 0.55, green_start: float = 0.82) -> String:
	return "perfect" if progress >= green_start else ("normal" if progress >= orange_start else "bad")

# The caller still applies this impulse only on physical foot contact.
# No second press returns the original impact unchanged.
static func apply(impact: Dictionary, rating: String, origin: Vector3, target: Vector3, mass: float, seed_value: int, bonus: float = 1.08, assistance: float = 0.35) -> Dictionary:
	var result := impact.duplicate()
	if rating == "perfect":
		var original_velocity: Vector3 = impact.impulse / mass
		var original_crossing := Flight.crossing_at_z(origin, original_velocity, impact.spin, 0, 5.0)
		var desired_landing: Vector3 = original_crossing.position.lerp(target, assistance)
		var desired_speed := original_velocity.length() * bonus
		var velocity := original_velocity * bonus
		# Compensate the extra speed's change in flight time before adding the
		# accuracy assist. Keep the selected spin and a strictly bounded correction.
		for _iteration in range(4):
			var crossing := Flight.crossing_at_z(origin, velocity, impact.spin, 0, 5.0)
			if crossing.time <= 0.05 or not crossing.position.is_finite():
				break
			var correction: Vector3 = (desired_landing - crossing.position) / crossing.time
			correction.z = 0
			velocity += correction.limit_length(1.8)
			velocity = velocity.normalized() * desired_speed
		result.impulse = velocity * mass
	elif rating == "bad":
		var random := RandomNumberGenerator.new()
		random.seed = seed_value
		var side := -1.0 if random.randf() < 0.5 else 1.0
		var velocity: Vector3 = impact.impulse / mass
		velocity = velocity.rotated(Vector3.UP, side * random.randf_range(0.16, 0.27)) * 0.58
		velocity.y += random.randf_range(-2.0, 1.0)
		result.impulse = velocity * mass
		result.spin = impact.spin * 0.75
		result.knuckle = 0.0
	return result
