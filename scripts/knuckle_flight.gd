extends RefCounted

# Low-spin wake instability: smooth, shot-seeded forces, not random teleports.
# Hong & Asai (2010): fluctuating lift around 3.5 Hz, peaks about 2 N.
static func phases(seed_value: int) -> Vector4:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return Vector4(generator.randf() * TAU, generator.randf() * TAU, generator.randf() * TAU, generator.randf() * TAU)

static func force(velocity: Vector3, spin: Vector3, time: float, strength: float, phase: Vector4) -> Vector3:
	if strength <= 0 or velocity.length_squared() < 144:
		return Vector3.ZERO
	var envelope := strength * smoothstep(12, 24, velocity.length()) * (1 - smoothstep(3, 12, spin.length())) * smoothstep(0.12, 0.40, time)
	var side := velocity.normalized().cross(Vector3.UP).normalized()
	var up := side.cross(velocity.normalized()).normalized()
	var lateral := sin(time * TAU * 0.90 + phase.x) * 0.72 + sin(time * TAU * 3.5 + phase.y) * 0.28
	var lift := sin(time * TAU * 1.15 + phase.z) * 0.65 + sin(time * TAU * 3.5 + phase.w) * 0.35
	return ((side * lateral + up * lift) * 1.65 * envelope).limit_length(2.0)
