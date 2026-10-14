extends SceneTree

var game: Node3D
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/" + filename)

func click_at(location: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = location
	event.global_position = location
	event.pressed = pressed
	Input.parse_input_event(event)
	await create_timer(0.05).timeout

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	await capture("ready.png")
	game.hud.advanced_button.pressed.emit()
	await capture("advanced-physics.png")
	game.hud.advanced_button.pressed.emit()
	var picker_location: Vector2 = game.hud.picker.get_global_rect().get_center() + Vector2(8, 8)
	await click_at(picker_location, true)
	await click_at(picker_location, false)
	check(game.hud.picker.point.x > 0.1 and game.hud.picker.point.y < -0.1, "GUI contact picker input failed")
	var aim := Vector3(2.6, 1.8, 0)
	var aim_location: Vector2 = game.camera.unproject_position(aim)
	await click_at(aim_location, true)
	await click_at(aim_location, false)
	check(game.target.distance_to(aim) < 0.05, "Mouse goal aiming failed")
	var button_location: Vector2 = game.hud.fire_button.get_global_rect().get_center()
	await click_at(button_location, true)
	await create_timer(0.7).timeout
	check(game.charging and game.power > 0.4, "Holding GUI shoot button failed")
	await click_at(button_location, false)
	check(game.phase == game.Phase.KICK, "Releasing GUI shoot button failed")
	await create_timer(0.83).timeout
	await capture("backswing.png")
	await create_timer(0.45).timeout
	await capture("flight.png")
	await create_timer(0.5).timeout
	await capture("keeper-dive.png")
	game.reset_attempt()
	root.size = Vector2i(1100, 760)
	await create_timer(0.2).timeout
	check(game.ball.position.distance_to(game.origin) < 0.001, "Ball transform was not restored after mid-flight reset")
	await capture("small-window.png")
	root.size = Vector2i(1440, 900)
	game.reset_attempt()
	game.hud.toggle_training()
	await capture("training.png")
	game.hud.toggle_training()
	game.target = Vector3(-3.35, 0.5, 0)
	game.hud.picker.point = Vector2(0, -0.65)
	game.power = 0.40
	game.start_kick()
	var stages := {}
	for _step in range(600):
		await physics_frame
		var defenders: Node3D = game.defenders
		if defenders.keeper_phase == defenders.KeeperPhase.DIVE and defenders.dive_elapsed > 0.27 and not stages.has("dive"):
			stages["dive"] = true
			await capture("keeper-extension.png")
		if defenders.keeper_phase == defenders.KeeperPhase.LAND and not stages.has("land"):
			stages["land"] = true
			await capture("keeper-landing.png")
		if defenders.keeper_phase == defenders.KeeperPhase.RECOVER and defenders.landing_elapsed > 0.4 and not stages.has("recover"):
			stages["recover"] = true
			await capture("keeper-recovery.png")
		if stages.size() == 3 and defenders.keeper_phase == defenders.KeeperPhase.READY:
			break
	check(stages.size() == 3, "Keeper dive, landing and recovery were visually exercised")
	game.reset_attempt()
	game.defenders.keeper_body.collision_layer = 0
	game.defenders.keeper_body.collision_mask = 0
	game.target = Vector3(-5.1, 1.2, 0)
	game.hud.picker.point = Vector2(-0.75, 0)
	game.power = 0.55
	game.start_kick()
	for _step in range(400):
		await physics_frame
		if game.goal_scored:
			break
	check(game.goal_scored and not "wall" in game.ball.hit_kinds, "Rendered physics curls around the physical wall into the goal")
	await capture("curled-goal.png")
	for _step in range(1000):
		await physics_frame
		if game.phase == game.Phase.RESULT:
			break
	check(game.hud.goal_card.visible and not game.hud.replay_button.disabled, "Goal replay card becomes clickable after recording")
	await capture("goal-card.png")
	var replay_location: Vector2 = game.hud.goal_card.get_global_rect().position + Vector2(170, 32)
	await click_at(replay_location, true)
	await click_at(replay_location, false)
	check(game.phase == game.Phase.REPLAY, "Actual goal card click opens cinematic replay")
	var replay_angles := {}
	var net_impact_time: float = game.goal_net.impacts[0].w - game.replay.frames[0].net_time
	for _step in range(18000):
		await process_frame
		if game.phase != game.Phase.REPLAY:
			break
		var angle: int = game.replay.angle_index
		if game.replay.play_time > net_impact_time + 0.08 and not replay_angles.has(angle):
			replay_angles[angle] = true
			await capture("replay-angle-%d.png" % angle)
	check(replay_angles.size() == 7 and game.phase == game.Phase.RESULT, "Seven cinematic angles finish and return to result")
	for distance in [16, 30]:
		game.hud.distance_slider.value = distance
		game.reset_attempt()
		await create_timer(0.2).timeout
		await capture("camera-%dm.png" % distance)
	game.hud.distance_slider.value = 21
	game.reset_attempt()
	game.defenders.keeper_body.collision_layer = 0
	game.defenders.keeper_body.collision_mask = 0
	game.target = Vector3(1.4, 1.3, 0)
	game.hud.picker.point = Vector2.ZERO
	game.power = 0.55
	game.start_kick()
	for _step in range(800):
		await physics_frame
		if game.phase == game.Phase.RESULT:
			break
	check(game.goal_scored and game.goal_net.contacted, "Central shot exercises cloth contact")
	game.start_replay()
	game.replay.angle_index = 1
	game.replay.play_time = game.goal_net.impacts[0].w - game.replay.frames[0].net_time + 0.05
	game.replay.sample_index = 0
	game.replay.cut_elapsed = 1
	game.replay.apply_frame(game)
	await capture("cloth-contact.png")
	game.end_replay()
	game.reset_attempt()
	for actor in game.defenders.wall:
		actor.get_children().filter(func(child): return child is AnimatableBody3D)[0].collision_layer = 0
	game.target = Vector3(0.75, 1.2, 0)
	game.power = 0.20
	game.start_kick()
	for _step in range(700):
		await physics_frame
		if game.defenders.save_kind != "":
			break
	await capture("keeper-catch.png")
	check(game.defenders.save_kind == "TUTTU", "Rendered central shot is caught with two hands")
	game.reset_attempt()
	game.hud.picker.point = Vector2(0, -0.20)
	game.update_aim_guide()
	await capture("knuckle-ready.png")
	print("VISUAL/INPUT FAILURES: %d" % failures)
	quit(1 if failures else 0)
