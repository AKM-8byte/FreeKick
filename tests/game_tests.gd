extends SceneTree

const Game = preload("res://game.gd")
const Shot = preload("res://shot_model.gd")
const Player = preload("res://procedural_player.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func wait_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await physics_frame
		elapsed += 1.0 / 120.0

func run() -> void:
	# Accelerate wall-clock tests while preserving the production 1/120 physics step.
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 64
	var forward := Vector3.FORWARD
	var left := Shot.contact_offset(Vector2(-0.6, 0), forward)
	var right := Shot.contact_offset(Vector2(0.6, 0), forward)
	var low := Shot.contact_offset(Vector2(0, -0.6), forward)
	var high := Shot.contact_offset(Vector2(0, 0.6), forward)
	var velocity := Vector3(0, 3, -15)
	var l := Shot.impact(velocity, left, forward)
	var r := Shot.impact(velocity, right, forward)
	check(l.spin.y * r.spin.y < 0, "Opposite side contacts must reverse sidespin")
	check(Shot.impact(velocity, low, forward).impulse.y > Shot.impact(velocity, high, forward).impulse.y, "Low contact raises launch relative to high contact")
	check(Shot.contact_offset(Vector2(100, 100), forward).length() <= 0.11001, "Contact picker clamps to sphere")
	var fast := Shot.impact(velocity * 1.8, left, forward)
	check(fast.impulse.length() > l.impulse.length(), "Foot speed controls ball speed")
	check(Shot.shoe_rotation(Vector2(-0.6, 0)).y * Shot.shoe_rotation(Vector2(0.6, 0)).y < 0, "Contact automatically opens/closes the shoe without a selected mode")
	for destination in [Vector3(0, -0.9, 0), Vector3(0.3, -0.6, -0.5), Vector3(0, -1.05, 0), Vector3(0.05, -0.1, -0.1)]:
		var knee := Player.solve_joint(Vector3.ZERO, destination, Vector3.FORWARD, 0.53, 0.53)
		check(absf(knee.length() - 0.53) < 0.001, "IK thigh length remains fixed")
		check(absf(knee.distance_to(destination) - 0.53) < 0.001, "IK shin length remains fixed")
	check(Game.goal_crossing(Vector3(0, 1, 0.3), Vector3(0, 1, -0.2)), "Whole ball crossing inside goal scores")
	check(not Game.goal_crossing(Vector3(0, 1, 0.3), Vector3(0, 1, -0.05)), "Partial crossing cannot score")
	check(not Game.goal_crossing(Vector3(3.6, 1, 0.3), Vector3(3.6, 1, -0.2)), "Post edge excludes whole ball")
	check(not Game.goal_crossing(Vector3(0, 2.5, 0.3), Vector3(0, 2.5, -0.2)), "Over crossbar cannot score")
	check(Game.goal_crossing(Vector3(0, 0.11, 0.3), Vector3(0, 0.11, -0.2)), "Rolling goals count")
	check(not Game.goal_crossing(Vector3(0, 1, -0.2), Vector3(0, 1, 0.3)), "Reverse crossing cannot score")
	var game := Game.new()
	root.add_child(game)
	await process_frame
	await wait_seconds(0.03)
	game.ball.struck.connect(func(_speed):
		if game.phase == Game.Phase.KICK:
			var toe: Vector3 = game.player.boots[1].to_global(Vector3(0, -0.05, -0.12))
			check(toe.distance_to(game.origin + game.contact) < 0.008, "Rendered toe reaches selected surface at strike")
	)
	check(game.ball.freeze and not game.ball.is_shot_taken, "Ball starts frozen")
	game.power = 0.7
	game.start_kick()
	await wait_seconds(game.runup_seconds + 0.05)
	check(not game.ball.is_shot_taken and game.ball.position.distance_to(game.origin) < 0.001, "No ball movement before foot contact")
	var support: Vector3 = game.player.to_global(game.player.feet[0])
	await wait_seconds(game.backswing_seconds + game.swing_duration + 0.03)
	check(game.ball.is_shot_taken and game.attempts == 1, "Exactly one strike at contact")
	check(game.player.to_global(game.player.feet[0]).distance_to(support) < 0.001, "Support foot stays planted")
	check(not game.ball.strike(Vector3.ZERO, Vector3(0, 0, -10), Vector3.ZERO), "Duplicate strike rejected")
	check(game.hud.distance_slider.editable == false and game.hud.picker.locked, "Settings locked during flight")
	await wait_seconds(8.2)
	check(game.phase == Game.Phase.RESULT, "Shot always terminates")
	game.reset_attempt()
	await wait_seconds(0.05)
	check(game.ball.linear_velocity.length() < 0.001 and game.ball.angular_velocity.length() < 0.001, "Reset clears all ball motion")
	check(game.ball.position.distance_to(game.origin) < 0.001, "Reset restores authoritative ball transform")
	check(game.trace_points.is_empty() and game.trace_root.get_child_count() == 0, "Reset clears trail")
	check(game.hud.distance_slider.editable and not game.hud.picker.locked, "Reset unlocks controls")
	check(game.defenders.elapsed < 0 and not game.defenders.reacted, "Reset clears keeper and wall reaction")
	for point in [Vector2(0, -0.98), Vector2(0, 0.98), Vector2(-0.98, 0), Vector2(0.98, 0)]:
		game.reset_attempt()
		game.hud.picker.point = point
		game.power = 0.55
		game.start_kick()
		await wait_seconds(game.runup_seconds + game.backswing_seconds + game.swing_duration + 0.03)
		check(game.ball.is_shot_taken, "Every contact edge automatically chooses a reachable foot orientation")
	for x in [-10.0, 0.0, 10.0]:
		game.hud.lateral_slider.value = x
		game.hud.distance_slider.value = 30 if x == 10 else 16
		game.hud.wall_slider.value = 5 if x == 10 else 1
		game.reset_attempt()
		check(game.defenders.wall.size() == int(game.hud.wall_slider.value), "Wall count follows setting")
		var wall_center: Vector3 = game.defenders.wall_center
		var mean := Vector3.ZERO
		for actor in game.defenders.wall:
			mean += actor.position
		mean /= game.defenders.wall.size()
		check(mean.distance_to(wall_center) < 0.001, "Wall stays centred on its placement ray")
		check(Vector3(game.origin.x, 0, game.origin.z).distance_to(wall_center) >= 9.149, "Wall keeps a minimum 9.15 m distance")
		game.hud.picker.point = Vector2(0.65, -0.65)
		game.power = 0.9
		game.start_kick()
		await wait_seconds(game.runup_seconds + game.backswing_seconds + game.swing_duration + 0.03)
		check(game.ball.is_shot_taken, "Extreme position and low contact still strike")
		for side in range(2):
			var hip: Vector3 = game.player.hips.position + Vector3(-0.14 if side == 0 else 0.14, 0, 0)
			check(absf(hip.distance_to(game.player.knee_positions[side]) - 0.53) < 0.002, "IK retains segment length at extreme positions")
	# Exercise real physics collisions, independent of the shot's aim.
	game.reset_attempt()
	var wall_location: Vector3 = game.defenders.wall[0].position
	game.ball.reset_at(wall_location + Vector3(0, 1.0, 1.0))
	game.ball.strike(Vector3.ZERO, Vector3(0, 0, -4.3), Vector3.ZERO)
	await wait_seconds(0.22)
	check("wall" in game.ball.hit_kinds, "Wall has physical collision")
	game.reset_attempt()
	game.ball.reset_at(Vector3(3.66, 1.0, 1.0))
	game.ball.strike(Vector3.ZERO, Vector3(0, 0, -4.3), Vector3.ZERO)
	await wait_seconds(0.22)
	check("post" in game.ball.hit_kinds, "Posts have physical collision")
	game.reset_attempt()
	game.ball.reset_at(game.defenders.keeper.position + Vector3(0, 1.0, 1.0))
	game.ball.strike(Vector3.ZERO, Vector3(0, 0, -4.3), Vector3.ZERO)
	await wait_seconds(0.22)
	check("keeper" in game.ball.hit_kinds, "Keeper has physical collision")
	game.reset_attempt()
	game.phase = Game.Phase.FLIGHT
	game.ball.reset_at(Vector3(2.4, 1.3, 0.5))
	game.last_ball_position = game.ball.position
	game.ball.strike(Vector3.ZERO, Vector3(0, 0, -4.3), Vector3.ZERO)
	await wait_seconds(0.15)
	check(game.goal_scored, "Actual physics goal crossing increments score")
	var counted: int = game.goals
	await wait_seconds(0.15)
	check(game.goals == counted, "Goal only counted once")
	game.reset_attempt()
	game.begin_charge("keyboard")
	await wait_seconds(1.8)
	check(is_equal_approx(game.power, 1.0), "Power caps while held")
	game.reset_attempt()
	check(not game.charging and game.power == 0 and game.phase == Game.Phase.PREPARE, "Reset cancels pending charge")
	await wait_seconds(0.1)
	check(game.ball.position.distance_to(game.origin) < 0.001, "Reset during flight remains at starting position")
	# Same fixed-step simulation sampled under very different display frame caps.
	var samples: Array[Vector3] = []
	for cap in [30, 144]:
		Engine.max_fps = cap
		game.reset_attempt()
		await wait_seconds(0.05)
		game.power = 0.8
		game.hud.picker.point = Vector2(0.35, -0.3)
		game.start_kick()
		while game.flight_elapsed < 0.2:
			await physics_frame
		samples.append(game.ball.position)
	check(samples[0].distance_to(samples[1]) < 0.005, "Physics is repeatable at 30 and 144 display FPS")
	Engine.max_fps = 0
	# Real keyboard events exercise the complete input path.
	game.reset_attempt()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	await wait_seconds(0.2)
	check(game.charging and game.power > 0.05, "Space key starts charging through input dispatch")
	key = InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	await wait_seconds(0.04)
	check(game.phase == Game.Phase.KICK, "Releasing space starts the kick")
	game.reset_attempt()
	# UI layout checks also work in headless mode with the production viewport size.
	root.size = Vector2i(1440, 900)
	await process_frame
	check(game.hud.distance_slider.get_global_rect().position.x > 1000, "Training panel remains on the right side of viewport")
	print("CHECKS: %d, FAILURES: %d" % [checks, failures])
	game.queue_free()
	await process_frame
	# Let the audio mixing thread release stopped playback references.
	await create_timer(0.5).timeout
	quit(1 if failures else 0)

