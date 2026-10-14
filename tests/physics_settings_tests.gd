extends SceneTree

const Game = preload("res://game.gd")
const Settings = preload("res://scripts/physics_settings.gd")
const Shot = preload("res://shot_model.gd")
const Flight = preload("res://flight_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	Settings.reset()
	var game := Game.new()
	root.add_child(game)
	await process_frame
	var speed := Shot.speed_for_power(0.6)
	game.hud.physics_sliders.mass.value = 0.60
	check(is_equal_approx(game.ball.mass, 0.60) and Shot.speed_for_power(0.6) < speed, "Mass changes the actual body and launch calculation together")
	game.hud.physics_sliders.gravity.value = 11
	check(is_equal_approx(game.ball.gravity_scale, 11.0 / 9.8) and Flight.gravity() == 11, "Gravity agrees between live physics and aiming")
	var before := Flight.force(Vector3(0, 0, -25), Vector3(0, 80, 0)).x
	game.hud.physics_sliders.curl.value = 0
	check(before < -0.1 and Flight.force(Vector3(0, 0, -25), Vector3(0, 80, 0)).x == 0, "Curl slider actually controls Magnus force")
	game.hud.physics_sliders.bounce.value = 0.2
	check(is_equal_approx(game.ball.physics_material_override.bounce, 0.2), "Bounce changes the collision material")
	game.hud.set_locked(true)
	for slider in game.hud.physics_sliders.values():
		check(not slider.editable, "Physics sliders lock during a shot")
	game.hud.set_locked(false)
	Settings.reset()
	game.reset_attempt()
	check(is_equal_approx(game.ball.mass, 0.46), "Reset applies heavier default mass")
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 64
	game.hud.physics_sliders.mass.value = 0.60
	game.hud.physics_sliders.strength.value = 1.20
	game.hud.physics_sliders.gravity.value = 11
	game.hud.physics_sliders.drag.value = 1.30
	for actor in game.defenders.wall:
		for body in actor.get_children():
			if body is AnimatableBody3D:
				body.collision_layer = 0
	game.defenders.keeper_body.collision_layer = 0
	game.defenders.keeper_body.collision_mask = 0
	game.target = Vector3(2.8, 1.4, 0)
	game.hud.picker.point = Vector2.ZERO
	game.power = 0.80
	game.start_kick()
	var previous := game.ball.position
	var crossing := Vector3.INF
	for _step in range(600):
		await physics_frame
		var position := game.ball.position
		if previous.z > 0 and position.z <= 0:
			crossing = previous.lerp(position, -previous.z / (position.z - previous.z))
			break
		previous = position
	check(crossing.is_finite() and crossing.distance_to(game.target) < 0.12, "Custom mass, force, gravity and drag agree with actual neutral flight")
	Settings.reset()
	game.reset_attempt()
	var net := game.goal_net
	# One callback can cross an entire panel: use the actual deformed triangles.
	var routes := [
		[Vector3(0, 1.2, -0.2), Vector3(0, 1.2, -5), Vector3(0, 0, -130)],
		[Vector3(3.1, 1.2, -0.6), Vector3(6, 1.2, -0.6), Vector3(130, 0, 0)],
		[Vector3(-3.1, 1.2, -0.6), Vector3(-6, 1.2, -0.6), Vector3(-130, 0, 0)],
		[Vector3(0, 1.8, -0.6), Vector3(0, 5, -0.6), Vector3(0, 130, 0)],
		[Vector3(3.3, 2.1, -0.7), Vector3(5, 3, -3), Vector3(65, 40, -100)]
	]
	for route in routes:
		net.reset()
		net.active = true
		var response: Dictionary = net.contain_sweep(route[0], route[1], route[2])
		check(net.sweep_repairs >= 1 and response.position.distance_to(route[1]) > 0.2, "Continuous sphere contact catches panel and seam crossings")
		check(response.velocity.length() < route[2].length() and net.contacted, "Contact removes energy and excites the cloth")
		net.reset()
		check(net.sweep_repairs == 0 and not net.contacted, "Repeated resets remove contact state")
	net.active = false
	check(net.contain_sweep(routes[0][0], routes[0][1], routes[0][2]).position == routes[0][1], "An unscored shot is not attracted by the net")
	game.set_physics_process(false)
	game.set_process(false)
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 64
	for route in routes.slice(0, 4):
		game.ball.reset_at(route[0])
		net.reset()
		net.active = true
		game.ball.strike(Vector3.ZERO, route[2] * game.ball.mass, Vector3.ZERO)
		var escaped := false
		for _step in range(180):
			await physics_frame
			net.step(1.0 / 120.0)
			var p := game.ball.position
			escaped = escaped or absf(p.x) > 4.4 or p.z < -3.2 or p.y > 3.1
		check(not escaped and net.contacted, "Live 130 m/s ball remains contained by rear, side and roof cloth")
	print("PHYSICS SETTINGS/CCD CHECKS: %d, FAILURES: %d" % [checks, failures])
	game.queue_free()
	await process_frame
	# Let the audio mixing thread release stopped playback references.
	await create_timer(1.2).timeout
	quit(1 if failures else 0)


