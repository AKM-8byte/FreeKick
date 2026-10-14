extends SceneTree

const Game = preload("res://game.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 64
	var game := Game.new()
	root.add_child(game)
	for x in [-25, 25]:
		for depth in [17, 30]:
			game.new_position_pending = false
			game.hud.set_slider_value(game.hud.lateral_slider, x)
			game.hud.set_slider_value(game.hud.distance_slider, depth)
			game.reset_attempt()
			game.defenders.keeper_body.collision_layer = 0
			game.defenders.keeper_body.collision_mask = 0
			for actor in game.defenders.wall:
				var body := actor.get_child(actor.get_child_count() - 1)
				body.collision_layer = 0
				body.collision_mask = 0
			game.target = Vector3(1.5, 1.2, 0)
			game.hud.picker.point = Vector2.ZERO
			game.power = 0.75
			var shot_origin := game.origin
			game.start_kick()
			var before_contact := true
			for step in range(600):
				await physics_frame
				if not game.ball.is_shot_taken:
					before_contact = before_contact and game.ball.position.distance_to(shot_origin) < 0.001
			check(before_contact, "Extreme shot stays still until foot contact")
			check(game.ball.is_shot_taken and game.launch_speed > 20, "Extreme shot launches normally")
			check(game.goal_scored, "Neutral shot reaches the goal from x=%d depth=%d" % [x, depth])
	Engine.time_scale = 1
	game.set_physics_process(false)
	game.sound.stop_effects()
	game.sound.ambience.stop()
	# The mixer acknowledges stopped voices asynchronously; keep players alive
	# until that acknowledgement before destroying the fixture.
	await create_timer(0.3).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	print("EXTREME SHOT CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
