extends SceneTree

const Game = preload("res://game.gd")
const Shot = preload("res://shot_model.gd")
const Defenders = preload("res://defenders.gd")
var checks := 0
var failures := 0
var game: Game

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func disable_keeper() -> void:
	game.defenders.keeper_body.collision_layer = 0
	game.defenders.keeper_body.collision_mask = 0

func disable_wall() -> void:
	for actor in game.defenders.wall:
		var body := actor.get_child(actor.get_child_count() - 1)
		body.collision_layer = 0
		body.collision_mask = 0

func reset_fixture() -> void:
	# Isolated flight comparisons deliberately reuse their chosen position.
	game.new_position_pending = false
	game.reset_attempt()

func shoot(target: Vector3, point: Vector2, power: float, duration: float = 4.0) -> Dictionary:
	game.target = target
	game.hud.picker.point = point
	game.power = power
	game.start_kick()
	var previous := game.ball.position
	var crossing := Vector3.INF
	var wall_crossing := Vector3.INF
	var clearance := -100.0
	var early_height := -100.0
	var launch_velocity := Vector3.ZERO
	var air_spin := 0.0
	var max_tilt := 0.0
	var max_movement := 0.0
	var stages := {}
	var minimum_floor := 100.0
	for _step in range(int((duration + game.runup_seconds + game.backswing_seconds + game.swing_duration) * 120)):
		await physics_frame
		var position := game.ball.position
		if game.flight_elapsed > 0.025 and launch_velocity == Vector3.ZERO:
			launch_velocity = game.ball.linear_velocity
			air_spin = game.ball.angular_velocity.length()
		if game.flight_elapsed >= 0.30 and early_height == -100.0:
			early_height = position.y
		if previous.z > 0 and position.z <= 0 and not crossing.is_finite():
			crossing = previous.lerp(position, -previous.z / (position.z - previous.z))
		var wall_z := game.defenders.wall_center.z
		if previous.z > wall_z and position.z <= wall_z and not wall_crossing.is_finite():
			wall_crossing = previous.lerp(position, (wall_z - previous.z) / (position.z - previous.z))
			clearance = wall_crossing.y - 0.11 - (game.defenders.wall[0].position.y + Defenders.WALL_HEIGHT)
		previous = position
		var keeper := game.defenders.keeper
		max_tilt = maxf(max_tilt, acos(clampf(keeper.basis.y.dot(Vector3.UP), -1, 1)))
		max_movement = maxf(max_movement, absf(keeper.position.x - game.defenders.keeper_home.x))
		stages[game.defenders.keeper_phase] = true
		for boot in keeper.boots:
			for x in [-0.06, 0.06]:
				for z in [-0.12, 0.12]:
					minimum_floor = minf(minimum_floor, boot.to_global(Vector3(x, -0.05, z)).y)
	return {"crossing": crossing, "wall_crossing": wall_crossing, "clearance": clearance, "early_height": early_height, "launch_velocity": launch_velocity, "air_spin": air_spin, "tilt": max_tilt, "movement": max_movement, "stages": stages, "floor": minimum_floor}

func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 64
	game = Game.new()
	root.add_child(game)
	await process_frame
	var neutral := Shot.impact(Vector3(0, 4, -15), Vector3(0, 0, 0.11), Vector3.FORWARD)
	check(neutral.spin.length() < 0.001, "Centre contact remains neutral")
	check(not game.player.visible and game.hud.picker.world_mode, "Preparation keeps the ball visible")
	check(not game.hud.training_panel.visible and game.hud.difficulty_select.selected == 0, "Training drawer starts closed with easy difficulty")
	check(game.hud.get("style_select") == null, "There is no manual shot-style selector")
	var previous_wall_distance := 0.0
	for distance in [17.0, 21.0, 30.0]:
		game.hud.distance_slider.value = distance
		reset_fixture()
		check(game.defenders.wall_distance > previous_wall_distance, "Moving away from goal moves the wall away from the ball")
		previous_wall_distance = game.defenders.wall_distance
		check(Defenders.WALL_HEIGHT >= 1.65 and Defenders.WALL_HEIGHT < 1.75, "Wall players have a reduced human-scale height")
		check(game.camera.fov == 26.0, "Preparation does not zoom increasingly toward the wall")
		disable_wall()
		disable_keeper()
		var target := Vector3(2.8, 1.7, 0)
		var result := await shoot(target, Vector2.ZERO, Shot.recommended_power(distance), 2.0)
		check(result.crossing.is_finite() and result.crossing.distance_to(target) < 0.12, "Neutral Jolt flight hits target within 12 cm at %d metres" % distance)
	# Same aim and power, three actual launches: bottom must fly higher and top
	# lower. Checking impact() alone previously missed the approach compensation.
	game.hud.distance_slider.value = 21
	var samples := []
	for point in [Vector2(0, -0.65), Vector2.ZERO, Vector2(0, 0.65)]:
		reset_fixture()
		disable_wall()
		disable_keeper()
		samples.append(await shoot(Vector3(2.8, 1.0, 0), point, 0.50, 2.0))
	check(samples[0].launch_velocity.y > samples[1].launch_velocity.y + 1.0, "Underneath contact really launches upward after the full kick path")
	check(samples[2].launch_velocity.y < samples[1].launch_velocity.y - 1.0, "Upper contact really launches lower after the full kick path")
	check(samples[0].early_height > samples[1].early_height + 0.3 and samples[1].early_height > samples[2].early_height + 0.3, "Visible trajectories follow bottom / centre / top order")
	check(samples[2].crossing.is_finite() and samples[2].crossing.y < 0.3, "Upper contact produces a grounded goal-plane crossing")
	# Actual jumping wall stays enabled: aim and contact alone must permit loft.
	var loft_cases := [
		[17, 0.85, Vector2(0, -0.65), 0.16],
		[21, 0.50, Vector2(0, -0.65), 0.385],
		[30, 0.15, Vector2(0, -0.45), 0.70],
	]
	for item in loft_cases:
		game.hud.distance_slider.value = item[0]
		reset_fixture()
		disable_keeper()
		var result := await shoot(Vector3(-2.7, item[1], 0), item[2], item[3], 2.6)
		check(result.clearance > 0.08, "Underneath contact clears the entire jumping wall at %d metres" % item[0])
		check(not "wall" in game.ball.hit_kinds, "Loft avoids a physical wall collision")
		check(result.crossing.is_finite() and result.crossing.y > 0.11 and result.crossing.y < 2.27, "Loft comes down inside the goal mouth")
		check(game.goal_scored, "Wall clearance is an attainable goal with no selected shot mode")
	# Both routes go below head height, around the wall, then curve into the goal.
	game.hud.distance_slider.value = 21
	var curve_cases := [
		[Vector3(-5.45, 0.8, 0), Vector2(-0.92, 0), -1.0],
		[Vector3(0.9, 0.8, 0), Vector2(0.75, 0), 1.0],
	]
	for item in curve_cases:
		reset_fixture()
		disable_keeper()
		var result := await shoot(item[0], item[1], 0.55, 2.4)
		check(game.goal_scored and not "wall" in game.ball.hit_kinds, "Side contact curls around the wall into a physical goal")
		check(result.clearance < 0, "Curve passes beside the wall, rather than above its heads")
		var wall_gap: float = item[2] * (result.wall_crossing.x - game.defenders.wall_center.x)
		check(wall_gap > 1.10, "Ball clears the chosen wall edge, including radius")
		var curve: float = absf(result.crossing.x - item[0].x)
		check(curve > 1.5 and curve < 2.5, "Curl stays useful but moderated to 1.5–2.5 m at 21 metres")
		check(result.air_spin > 55, "Physics engine preserves side spin")
	reset_fixture()
	disable_wall()
	disable_keeper()
	var strong_spin := await shoot(Vector3(3.0, 1.0, 0), Vector2(0.9, 0), 0.85, 1.0)
	check(strong_spin.air_spin > 85 and strong_spin.air_spin < 110.1, "A strong edge contact preserves the moderated spin above old limits")
	# Saves and skillful goals must remain possible with the default keeper.
	var cases := [
		[0, Vector3(3.35, 2.1, 0), Vector2.ZERO, 0.85, true],
		[1, Vector3(2.8, 1.8, 0), Vector2.ZERO, 0.58, false],
		[1, Vector3(3.35, 0.3, 0), Vector2.ZERO, 0.85, false],
		[1, Vector3(-3.35, 0.5, 0), Vector2(0, -0.65), 0.40, true],
		[2, Vector3(2.8, 1.8, 0), Vector2.ZERO, 0.58, false],
	]
	for item in cases:
		game.hud.difficulty_select.select(item[0])
		reset_fixture()
		var result := await shoot(item[1], item[2], item[3])
		check(game.goal_scored == item[4], "Difficulty %d keeps expected goal/save balance for %s" % [item[0], item[1]])
		check(game.defenders.reacted and result.movement > 0.7, "Keeper reacts and moves toward the shot")
		check(result.tilt > 0.6 and result.stages.has(Defenders.KeeperPhase.DIVE), "Keeper extends laterally")
		check(result.stages.has(Defenders.KeeperPhase.LAND) and result.stages.has(Defenders.KeeperPhase.RECOVER), "Keeper lands and recovers after the result")
		check(result.floor >= -0.002, "Keeper boots stay above the ground")
		check(game.defenders.keeper_phase == Defenders.KeeperPhase.READY, "Keeper recovery completes")
		if not item[4]:
			check("keeper" in game.ball.hit_kinds, "Physical keeper collision produces the save")
	reset_fixture()
	check(game.defenders.keeper_phase == Defenders.KeeperPhase.READY and game.defenders.next_read == 0 and not game.defenders.diving, "Reset clears reaction, dive and recovery")
	print("PLAYABILITY CHECKS: %d, FAILURES: %d" % [checks, failures])
	game.queue_free()
	await process_frame
	# Let the audio mixing thread release stopped playback references.
	await create_timer(0.5).timeout
	quit(1 if failures else 0)

