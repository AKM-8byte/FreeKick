extends RefCounted

const BALL_CLEARANCE := 0.115 + 0.04

# Distance is depth from the goal line, independent of lateral position.
static func safe_position(lateral: float, depth: float) -> Vector3:
	return Vector3(clampf(lateral, -25, 25), 0.115, clampf(depth, maxf(17, 16.5 + BALL_CLEARANCE), 30))

static func sample(rng: RandomNumberGenerator) -> Vector3:
	var near_goal := rng.randf() < 0.70
	var central := rng.randf() < 0.70
	# Whole metres match the training sliders; the shared 24 m boundary belongs
	# to the near group, avoiding rounding leaking into the probability groups.
	var depth := rng.randi_range(17, 24) if near_goal else rng.randi_range(25, 30)
	var lateral := rng.randi_range(-10, 10) if central else rng.randi_range(11, 25) * (-1 if rng.randf() < 0.5 else 1)
	return safe_position(lateral, depth)
