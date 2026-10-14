extends SceneTree

const Game = preload("res://game.gd")
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

func finish_shot() -> void:
	for _step in range(1200):
		await physics_frame
		if game.phase == Game.Phase.RESULT:
			return
	check(false, "Shot completes before the timeout")

func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 64
	game = Game.new()
	root.add_child(game)
	await process_frame
	check(game.goal_net.ropes.mesh.get_surface_count() == 1, "Fine net cords use one batched mesh")
	check(game.goal_net.vertices.size() > 50000, "Net has dense rear, roof and side weaving")
	check(not game.hud.goal_card.visible and not game.replay.available(), "No replay is offered before a goal")
	game.target = Vector3(-2.8, 1, 0)
	game.update_aim_guide()
	var left := game.aim_guide.points[-1]
	game.target = Vector3(2.8, 1, 0)
	game.update_aim_guide()
	check(game.aim_guide.points[-1].x > left.x + 1, "Departure arrow changes direction before shooting")
	game.target = Vector3(0, 1, 0)
	game.hud.picker.point = Vector2(-0.75, 0)
	game.update_aim_guide()
	var curve_a := game.aim_guide.points[-1]
	game.hud.picker.point = Vector2(0.75, 0)
	game.update_aim_guide()
	check(curve_a.x > game.aim_guide.points[-1].x + 0.2, "Departure arrow bends with side contact before impact")
	var tip_direction := (game.aim_guide.points[-1] - game.aim_guide.points[-2]).normalized()
	check(game.aim_guide.arrow.basis.y.normalized().dot(tip_direction) > 0.999, "Arrowhead follows the changing tip tangent")
	game.hud.picker.point = Vector2(0, -0.65)
	game.update_aim_guide()
	var raised := game.aim_guide.points[-1].y
	game.hud.picker.point = Vector2(0, 0.65)
	game.update_aim_guide()
	check(raised > game.aim_guide.points[-1].y + 0.3, "Departure cue distinguishes low and high contact")
	check(not game.ball.is_shot_taken and game.ball.position.distance_to(game.origin) < 0.001, "Preview never moves or strikes the real ball")
	game.reset_attempt()
	game.target = Vector3(1.4, 1.3, 0)
	game.hud.picker.point = Vector2.ZERO
	game.power = 0.55
	game.defenders.keeper_body.collision_layer = 0
	game.defenders.keeper_body.collision_mask = 0
	game.start_kick()
	await finish_shot()
	check(game.goal_scored and game.hud.goal_card.visible, "A real goal shows the clickable goal box")
	check(not game.hud.replay_button.disabled and game.replay.available(), "Replay becomes ready after net impact is recorded")
	check(game.goal_net.contacted and "net" in game.ball.hit_kinds, "Goal ball reaches the flexible net")
	check(game.goal_net.pushes[0].w > 0.1, "Net records an impact-dependent deformation")
	var pocket := 0.0
	for frame in game.replay.frames:
		for index in range(frame.cloth.size()):
			pocket = maxf(pocket, frame.cloth[index].distance_to(game.goal_net.cloth.initial[index]))
	check(pocket > 0.40 and pocket < 1.20, "Goal impact creates a substantial bounded cloth pocket around the ball")
	var rear_seam := game.goal_net.cloth.binding(0, 0, 0.5)
	var side_seam := game.goal_net.cloth.binding(1, 1, 0.5)
	check(rear_seam.ids.x == side_seam.ids.y, "Rear and side panels share the same movable seam particles")
	check(game.ball.position.z < -0.11 and game.ball.position.z > -2.85, "Soft net retains the ball inside goal depth")
	check(game.replay.frames.size() > 40 and game.replay.frames.size() < 600, "Actual fixed-step movement is recorded at bounded replay sampling")
	var result_position := game.ball.global_transform
	var scores := Vector2i(game.goals, game.attempts)
	game.start_replay()
	check(game.phase == Game.Phase.REPLAY and game.replay.playing, "Goal-box action starts the cinematic")
	check(game.ball.freeze and not game.ball.visible and game.replay.visual_ball.visible, "Replay uses a visual ball while the authoritative ball stays frozen")
	check(not game.hud.root.visible and game.hud.cinema_root.visible, "Cinematic hides training UI and shows letterboxing")
	var sample_index := game.replay.frames.size() / 2
	var sample: Dictionary = game.replay.frames[sample_index]
	game.replay.play_time = sample.time
	game.replay.sample_index = 0
	game.replay.apply_frame(game)
	check(game.replay.visual_ball.global_transform.origin.distance_to(sample.ball.origin) < 0.001, "Playback reproduces the recorded ball position exactly")
	check(game.player.global_transform.origin.distance_to(sample.player.transform.origin) < 0.001, "Playback reproduces the recorded striker motion")
	check(absf(game.goal_net.clock - sample.net_time) < 0.001, "Net deformation uses the recorded impact clock")
	check(game.goal_net.cloth.positions == sample.cloth, "Replay restores actual cloth particles instead of recalculating the net")
	check(game.ball.global_transform == result_position and Vector2i(game.goals, game.attempts) == scores, "Sampling replay never changes the live physics result or score")
	game.replay.reset_cut()
	game.replay.play_time = game.replay.strike_time
	var slow_start := game.replay.play_time
	for _step in range(50):
		game.replay.advance(0.05, game)
	check(absf(game.replay.play_time - slow_start - 0.625) < 0.02, "Whole cinematic stays at quarter speed")
	var normal_start := game.replay.play_time
	game.replay.advance(0.10, game)
	check(game.replay.playback_speed == 0.25 and absf(game.replay.play_time - normal_start - 0.025) < 0.001, "Slow playback continues after 2.5 viewing seconds")
	check(game.hud.cinema_stats.text.contains("ÇIKIŞ") and game.hud.cinema_stats.text.contains("FALSO"), "Replay displays recorded speed and spin statistics")
	check(game.replay.launch_velocity.length() > 15 and game.replay.sound_events.size() >= 6, "Launch telemetry and footstep/kick/net/goal audio are recorded")
	game.replay.reset_cut()
	game.replay.change_angle(-1, game)
	check(game.replay.angle_index == 6 and game.camera.position.is_finite(), "Previous camera wraps to the seventh angle")
	game.replay.change_angle(1, game)
	check(game.replay.angle_index == 0, "Next camera wraps back to the first angle")
	var angles := {}
	for _step in range(12000):
		angles[game.replay.angle_index] = true
		if not game.replay.advance(1.0 / 60.0, game):
			break
	check(angles.size() == 7, "Cinematic presents all seven different camera angles")
	game.end_replay()
	check(game.phase == Game.Phase.RESULT and game.hud.goal_card.visible, "Cinematic returns to the existing result")
	check(game.ball.visible and not game.ball.replay_mode and game.ball.global_transform == result_position, "Live ball is restored without a physics teleport")
	check(Vector2i(game.goals, game.attempts) == scores, "Seven-angle replay does not count the goal again")
	game.start_replay()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await process_frame
	await create_timer(0.05).timeout
	check(game.phase == Game.Phase.RESULT, "Escape closes replay through actual input dispatch")
	game.start_replay()
	game.reset_attempt()
	check(game.phase == Game.Phase.PREPARE and not game.replay.playing and game.replay.frames.is_empty(), "Reset during replay clears the whole recording")
	check(game.hud.root.visible and not game.hud.cinema_root.visible and not game.hud.goal_card.visible, "Reset removes replay and goal overlays")
	check(not game.goal_net.contacted and not game.goal_net.active and game.goal_net.pushes[0].w == 0, "Reset clears net deformation and force state")
	check(game.goal_net.force_on_ball(Vector3(0, 1, -2.4), Vector3(0, 0, -20)) == Vector3.ZERO, "Net cannot affect an unscored shot")
	game.target = Vector3(7, 1, 0)
	game.power = 0.55
	game.start_kick()
	await finish_shot()
	check(not game.goal_scored and not game.hud.goal_card.visible and not game.replay.available(), "A missed shot never offers a goal replay")
	print("CINEMATIC/NET CHECKS: %d, FAILURES: %d" % [checks, failures])
	game.queue_free()
	await process_frame
	# Let the audio mixing thread release stopped playback references.
	await create_timer(0.5).timeout
	quit(1 if failures else 0)

