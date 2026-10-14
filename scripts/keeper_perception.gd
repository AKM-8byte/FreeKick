extends RefCounted

# Delayed, seeded observations; never reads the shot target or future wake phase.
var samples: Array[Dictionary] = []
var random := RandomNumberGenerator.new()
var bias := Vector3.ZERO
var last_sample_time := -1.0
var last_observation_time := -1.0

func reset(seed_value: int, error_metres: float) -> void:
	samples.clear()
	random.seed = seed_value
	bias = Vector3(random.randf_range(-1, 1), random.randf_range(-0.5, 0.5), 0) * error_metres
	last_sample_time = -1
	last_observation_time = -1

func record(time: float, position: Vector3, velocity: Vector3, spin: Vector3) -> void:
	if last_sample_time >= 0 and time - last_sample_time < 0.025: return
	last_sample_time = time
	samples.append({"time": time, "position": position, "velocity": velocity, "spin": spin})
	while samples.size() > 1 and samples[1].time < time - 0.6: samples.pop_front()

func observe(time: float, delay: float, velocity_error: float) -> Dictionary:
	var selected := {}
	for sample in samples:
		if sample.time <= time - delay: selected = sample
		else: break
	if selected.is_empty(): return {}
	last_observation_time = selected.time
	var result: Dictionary = selected.duplicate()
	# Small smooth estimation noise rather than independent frame-to-frame steering.
	var phase := float(random.seed % 997) * 0.031
	result.velocity += Vector3(sin(time * 2.1 + phase), sin(time * 1.7 + phase * 0.7) * 0.45, sin(time * 1.3 + phase * 1.5) * 0.25) * velocity_error
	result.position += bias * 0.12
	return result
