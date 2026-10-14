extends SceneTree

const Game = preload("res://game.gd")
const Shot = preload("res://shot_model.gd")
const Knuckle = preload("res://scripts/knuckle_flight.gd")
var game: Game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func disable_defenders() -> void:
	for actor in game.defenders.wall:
		actor.get_children().filter(func(child): return child is AnimatableBody3D)[0].collision_layer = 0
	game.defenders.keeper_body.collision_layer = 0
	game.defenders.keeper_body.collision_mask = 0

func knuckle_shot(seed_value: int) -> Dictionary:
	game.reset_attempt()
	disable_defenders()
	game.target = Vector3(2.4, 1.2, 0)
	game.hud.picker.point = Vector2(0, -0.20)
	game.power = 0.65
	seed(seed_value)
	game.start_kick()
	while not game.ball.is_shot_taken:
		await physics_frame
	await physics_frame
	var strength := game.ball.knuckle_strength
	var spin := game.ball.angular_velocity.length()
	var positions := PackedVector3Array()
	for _step in range(90):
		await physics_frame
		positions.append(game.ball.position)
	return {"positions": positions, "strength": strength, "spin": spin}

func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 64
	game = Game.new()
	root.add_child(game)
	await process_frame
	var cloth := game.goal_net.cloth
	check(cloth.positions.size() > 400 and cloth.positions.size() <= 512 and cloth.links_a.size() > 1500, "Cloth uses actual connected structural, shear and bending particles")
	var baseline := cloth.positions.duplicate()
	var center := cloth.binding(0, 0.5, 0.5)
	cloth.kick(center, Vector3(0, 0, -0.25), 1.0 / 120.0)
	var maximum := 0.0
	var anchored_error := 0.0
	var spread := 0
	var start := Time.get_ticks_usec()
	for _step in range(120):
		cloth.step(1.0 / 120.0)
		for index in range(cloth.positions.size()):
			maximum = maxf(maximum, cloth.positions[index].distance_to(baseline[index]))
			if cloth.movable[index] == 0:
				anchored_error = maxf(anchored_error, cloth.positions[index].distance_to(cloth.rest[index]))
	var step_ms := (Time.get_ticks_usec() - start) / 120000.0
	for index in range(cloth.positions.size()):
		if cloth.positions[index].distance_to(baseline[index]) > 0.005:
			spread += 1
	check(maximum > 0.04 and maximum < 1.0, "Contact creates bounded physical cloth displacement")
	check(spread > 8, "Impact motion propagates beyond the four contact particles")
	check(anchored_error < 0.0001, "Anchors stay attached to the frame and hem")
	var stretch := 0.0
	for index in range(cloth.links_a.size()):
		stretch = maxf(stretch, cloth.positions[cloth.links_a[index]].distance_to(cloth.positions[cloth.links_b[index]]) / cloth.lengths[index])
	check(stretch < 1.18, "Distance constraints prevent runaway stretching")
	cloth.reset()
	check(cloth.positions == baseline and cloth.previous == baseline, "Reset restores settled cloth and removes stored velocity")
	print("CLOTH CPU: %.2f ms per 120 Hz step, %d constraints" % [step_ms, cloth.links_a.size()])

	var offset := Shot.contact_offset(Vector2(0, -0.20), Vector3.FORWARD)
	var impact := Shot.impact(Vector3(0, 3, -16), offset, Vector3.FORWARD)
	check(impact.knuckle > 0.95 and impact.spin.length() < 3, "Slightly low central contact automatically launches low-spin knuckleball")
	check(Shot.knuckle_contact(Vector2.ZERO) == 0 and Shot.knuckle_contact(Vector2(0.65, -0.2)) == 0 and Shot.knuckle_contact(Vector2(0, -0.65)) == 0, "Ordinary center, side curl and loft contacts keep their own behavior")
	check(Shot.impact(Vector3(0, 1, -11), offset, Vector3.FORWARD).knuckle == 0, "Weak shots do not acquire an exaggerated knuckle wake")
	var phase := Knuckle.phases(345)
	var force := Knuckle.force(Vector3(0, 1, -28), Vector3.ZERO, 0.7, 1, phase)
	check(force.length() > 0.1 and force.length() <= 2.001, "Wake forces stay within the bounded aerodynamic scale")
	check(force == Knuckle.force(Vector3(0, 1, -28), Vector3.ZERO, 0.7, 1, Knuckle.phases(345)), "Same shot seed reproduces aerodynamic forces")
	check(force.distance_to(Knuckle.force(Vector3(0, 1, -28), Vector3.ZERO, 0.7, 1, Knuckle.phases(346))) > 0.1, "Different shots receive different wake phases")
	check(Knuckle.force(Vector3(0, 1, -28), Vector3(0, 35, 0), 0.7, 1, phase) == Vector3.ZERO, "Rapid spin suppresses the knuckle effect")
	var minimum_x := 100.0
	var maximum_x := -100.0
	for index in range(120):
		var wake := Knuckle.force(Vector3(0, 1, -28), Vector3.ZERO, index / 120.0 + 0.4, 1, phase)
		minimum_x = minf(minimum_x, wake.x)
		maximum_x = maxf(maximum_x, wake.x)
	check(minimum_x < -0.25 and maximum_x > 0.25, "Wake changes lateral direction during a shot rather than applying fixed curl")
	Engine.max_fps = 30
	var first := await knuckle_shot(778)
	Engine.max_fps = 144
	var repeat := await knuckle_shot(778)
	Engine.max_fps = 0
	var different := await knuckle_shot(781)
	check(first.strength > 0.9 and first.spin < 3, "Real procedural foot contact activates the low-spin shot")
	check(first.positions[-1].distance_to(repeat.positions[-1]) < 0.005, "Same seed reproduces actual Jolt flight at 30 and 144 FPS after resets")
	check(first.positions[-1].distance_to(different.positions[-1]) > 0.10, "Actual shots vary in flight with a different seed")
	game.reset_attempt()
	check(game.ball.knuckle_strength == 0 and game.ball.flight_time == 0 and game.ball.held_by == null, "Reset removes wake and keeper attachment state")

	# A central reachable ball is physically contacted by the gloves.
	for actor in game.defenders.wall:
		actor.get_children().filter(func(child): return child is AnimatableBody3D)[0].collision_layer = 0
	game.target = Vector3(0.75, 1.20, 0)
	game.hud.picker.point = Vector2.ZERO
	game.power = 0.20
	game.start_kick()
	for _step in range(600):
		await physics_frame
		if game.defenders.save_kind != "":
			break
	print("CENTRAL SAVE: ", game.defenders.save_kind)
	check(game.defenders.save_kind == "TUTTU" and game.ball.held_by == game.defenders.keeper, "Reachable slow two-hand save secures the ball")
	for _step in range(50):
		await physics_frame
	check(game.ball.position.distance_to(game.defenders.keeper.to_global(game.ball.held_offset)) < 0.02, "Caught ball follows the actual glove pose without drifting")
	check(not game.goal_scored, "Caught ball cannot continue through the goal")
	game.reset_attempt()
	check(game.ball.held_by == null and game.defenders.save_kind == "", "Reset safely detaches a saved ball before replacing the keeper")
	print("CLOTH/KNUCKLE/SAVE CHECKS: %d, FAILURES: %d" % [checks, failures])
	game.queue_free()
	await process_frame
	# Let the audio mixing thread release stopped playback references.
	await create_timer(0.5).timeout
	quit(1 if failures else 0)

