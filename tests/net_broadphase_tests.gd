extends SceneTree
const Net = preload("res://scripts/goal_net.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	var net = game.goal_net
	net.active = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 312901
	var checked := 0
	for phase in range(3):
		if phase > 0:
			net.cloth.kick(net.cloth.binding(0, 0.45, 0.55), Vector3(0.2, 0.08, -0.5), 1.0 / 120.0)
			for step in range(18): net.step(1.0 / 120.0)
		for index in range(120):
			var from := Vector3(rng.randf_range(-3.4, 3.4), rng.randf_range(0.15, 2.2), rng.randf_range(-1.25, -0.1))
			var velocity := Vector3(rng.randf_range(-100, 100), rng.randf_range(-40, 80), rng.randf_range(-130, 25))
			var to := from + velocity / 120.0
			var expected := reference_sweep(net, from, to, velocity)
			var actual: Dictionary = net.contain_sweep(from, to, velocity, 2)
			checked += 1
			if actual.position.distance_to(expected.position) > 0.0001 or actual.velocity.distance_to(expected.velocity) > 0.0001:
				failures += 1
				push_error("Broad phase missed reference contact: %s -> %s" % [from, to])
	print("NET BROAD PHASE: ", checked, " comparisons, failures: ", failures)
	game.sound.stop_effects()
	game.sound.ambience.stop()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(1 if failures else 0)

func reference_sweep(net: Net, from: Vector3, to: Vector3, velocity: Vector3) -> Dictionary:
	if not net.active:
		return {"position": to, "velocity": velocity}
	var result := to
	var next_velocity := velocity
	var earliest := 2.0
	var hit: Dictionary = {}
	for surface in [0, 1, 2, 3]:
		var patch: Dictionary = net.cloth.patches[surface]
		var ids: PackedInt32Array = patch.indices
		var columns: int = patch.columns
		for row in range(patch.rows):
			for column in range(columns):
				var index := row * (columns + 1) + column
				var a := net.cloth.positions[ids[index]]
				var b := net.cloth.positions[ids[index + 1]]
				var c := net.cloth.positions[ids[index + columns + 1]]
				var d := net.cloth.positions[ids[index + columns + 2]]
				for triangle in range(2):
					var p := a if triangle == 0 else b
					var q := b if triangle == 0 else d
					var r := c
					var normal := (q - p).cross(r - p).normalized()
					if normal.dot(patch.normal) < 0:
						normal = -normal
					var start_depth := (from - p).dot(normal) + net.ball_radius()
					var end_depth := (to - p).dot(normal) + net.ball_radius()
					# The mesh itself deforms; compliance must remain below the ball radius.
					if end_depth <= net.CONTACT_COMPLIANCE + 0.001 or end_depth < start_depth - 0.00001:
						continue
					var movement := end_depth - start_depth
					var fraction := clampf((net.CONTACT_COMPLIANCE - start_depth) / movement, 0, 1) if absf(movement) > 0.00001 else 0.0
					var crossing := from.lerp(to, fraction)
					var projection := crossing - normal * (crossing - p).dot(normal)
					if fraction < earliest and net.triangle_contains(projection, p, q, r, net.ball_radius()):
						earliest = fraction
						hit = {"normal": normal, "depth": end_depth, "surface": surface, "point": projection}
	if not hit.is_empty():
		result -= hit.normal * maxf(0, hit.depth - net.CONTACT_COMPLIANCE)
		next_velocity -= hit.normal * maxf(0, next_velocity.dot(hit.normal)) * 0.38
	return {"position": result, "velocity": next_velocity}
