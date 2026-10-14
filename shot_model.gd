extends RefCounted

const RADIUS := 0.11
const MASS := 0.43
const MAX_SPIN := 110.0
const Flight = preload("res://flight_model.gd")
const Settings = preload("res://scripts/physics_settings.gd")

static func speed_for_power(power: float) -> float:
	return foot_speed_for_power(power) * MASS / Flight.effective_mass()

static func foot_speed_for_power(power: float) -> float:
	return lerpf(18.0, 33.0, clampf(power, 0.0, 1.0)) * Settings.get_value("strength")

static func swing_speed_for_power(power: float) -> float:
	return foot_speed_for_power(power) / 1.7

static func knuckle_contact(point: Vector2) -> float:
	var side := 1 - smoothstep(0.07, 0.20, absf(point.x))
	var height := 1 - smoothstep(0.07, 0.17, absf(point.y + 0.20))
	return side * height

static func recommended_power(distance: float, point: Vector2 = Vector2.ZERO) -> float:
	var base := 0.55 + (distance - 21.0) * 0.018
	var loft_power := clampf(0.16 + (distance - 16.0) * 0.045, 0.16, 0.76)
	var recommendation := lerpf(base, loft_power, clampf(-point.y / 0.65, 0, 1))
	return clampf(lerpf(recommendation, maxf(0.58, base + 0.08), knuckle_contact(point)), 0.16, 0.76)

static func contact_offset(point: Vector2, forward: Vector3) -> Vector3:
	var p := point.limit_length(0.98)
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward.normalized()).normalized()
	return (right * p.x + up * p.y - forward.normalized() * sqrt(maxf(0.0, 1.0 - p.length_squared()))) * Settings.current_radius()

static func approach(ball_position: Vector3, target: Vector3, power: float) -> Vector3:
	var horizontal := target - ball_position
	horizontal.y = 0.0
	var axis := horizontal.normalized()
	var speed := speed_for_power(power)
	var low := -0.06
	var high := 0.85
	# Aim establishes a neutral foot approach. Contact must remain an independent
	# input: fitting its spin back to the same target inverted the visible loft.
	for _iteration in range(12):
		var angle := (low + high) * 0.5
		var direction := axis * cos(angle) + Vector3.UP * sin(angle)
		var prediction := Flight.crossing_at_z(ball_position, direction * speed, Vector3.ZERO, 0, 5.0)
		if prediction.position.y < target.y:
			low = angle
		else:
			high = angle
	var angle := (low + high) * 0.5
	return axis * cos(angle) + Vector3.UP * sin(angle)

static func impact(foot_velocity: Vector3, offset: Vector3, forward: Vector3) -> Dictionary:
	var right := forward.cross(Vector3.UP).normalized()
	var lateral := offset.dot(right) / RADIUS
	var vertical := offset.y / RADIUS
	var velocity := foot_velocity * 1.7
	# The shoe opens/closes continuously with side contact. Bottom contact adds
	# lift, top contact takes it away; there is no separate selectable shot mode.
	velocity += right * lateral * foot_velocity.length() * 0.035
	velocity += Vector3.UP * -vertical * foot_velocity.length() * 0.16
	var impulse := velocity * MASS
	var inertia := 0.4 * MASS * RADIUS * RADIUS
	var side_offset := right * lateral * RADIUS
	var height_offset := Vector3.UP * vertical * RADIUS
	# Shoe brushing transfers stronger sidespin than vertical spin, avoiding an
	# exaggerated backspin lift while retaining the same Magnus law in all axes.
	var spin := (side_offset.cross(impulse) * 0.16 + height_offset.cross(impulse) * 0.01925) / inertia
	var knuckle := knuckle_contact(Vector2(lateral, vertical)) * smoothstep(21, 26, velocity.length() * MASS / Flight.effective_mass())
	spin *= 1 - knuckle * 0.96
	return {"impulse": impulse, "spin": spin.limit_length(MAX_SPIN), "knuckle": knuckle}

static func shoe_rotation(point: Vector2, local_approach: Vector3 = Vector3.FORWARD) -> Vector3:
	var aim_yaw := atan2(-local_approach.x, -local_approach.z)
	return Vector3(point.y * 0.12, aim_yaw * 0.60 - point.x * 0.38, point.x * 0.14)
