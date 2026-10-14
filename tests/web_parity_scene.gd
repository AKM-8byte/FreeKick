extends Node

const Game = preload("res://game.gd")

func _ready() -> void:
	call_deferred("run")

func values(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]

func run() -> void:
	var game := Game.new()
	get_tree().root.add_child(game)
	var results: Array = []
	for input in [["low", Vector2.ZERO, 0.35], ["high", Vector2.ZERO, 0.75], ["left", Vector2(0.6, 0), 0.55], ["right", Vector2(-0.6, 0), 0.55]]:
		game.new_position_pending = false
		game.reset_attempt()
		game.defenders.keeper_body.collision_layer = 0
		game.defenders.keeper_body.collision_mask = 0
		for actor in game.defenders.wall:
			var body := actor.get_child(actor.get_child_count() - 1)
			body.collision_layer = 0
			body.collision_mask = 0
		game.hud.picker.point = input[1]
		game.power = input[2]
		game.target = Vector3(2.8, 1.7, 0)
		game.start_kick()
		var previous := game.ball.position
		var spin := Vector3.ZERO
		var crossing := Vector3.INF
		var finite := true
		var stationary := true
		var launch_recorded := false
		for step in range(600):
			await get_tree().physics_frame
			var current := game.ball.position
			finite = finite and current.is_finite()
			if not game.ball.is_shot_taken:
				stationary = stationary and current.distance_to(game.origin) < 0.001
			if game.ball.is_shot_taken and not launch_recorded:
				spin = game.ball.angular_velocity
				launch_recorded = true
			if previous.z > 0 and current.z <= 0:
				crossing = previous.lerp(current, -previous.z / (current.z - previous.z))
				break
			previous = current
		results.append({"name":input[0], "speed":game.launch_speed, "spin":values(spin), "crossing":values(crossing) if crossing.is_finite() else [], "finite":finite, "stationary":stationary})
	game.new_position_pending = false
	game.reset_attempt()
	game.defenders.keeper_body.collision_layer = 0
	game.defenders.keeper_body.collision_mask = 0
	for actor in game.defenders.wall:
		var body := actor.get_child(actor.get_child_count() - 1)
		body.collision_layer = 0
		body.collision_mask = 0
	game.hud.picker.point = Vector2.ZERO
	game.target = Vector3(2.8, 1.7, 0)
	game.power = 0.75
	game.start_kick()
	for step in range(800):
		await get_tree().physics_frame
		if game.phase == Game.Phase.RESULT and not game.replay.recording:
			break
	var scored := game.goal_scored
	var net_contact := "net" in game.ball.hit_kinds
	var angles := 0
	game.start_replay()
	if game.phase == Game.Phase.REPLAY:
		for index in range(7):
			if index > 0:
				game.replay.change_angle(1, game)
			await get_tree().process_frame
			await get_tree().process_frame
			if game.replay.angle_index == index and not game.hud.cinema_stats.text.is_empty():
				angles += 1
		# Let the final cut fade finish before the screenshot fixture is frozen.
		await get_tree().create_timer(0.2).timeout
	var fps := Engine.get_frames_per_second()
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.stop_effects()
	game.sound.ambience.stop()
	await get_tree().create_timer(0.3).timeout
	if not OS.has_feature("web"):
		game.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	print("WEB_PARITY_RESULT " + JSON.stringify({"web": OS.has_feature("web"), "ticks":Engine.physics_ticks_per_second, "fps":fps, "shots":results, "goal":scored, "net_contact":net_contact, "replay_angles":angles}))
	if not OS.has_feature("web"):
		get_tree().quit()
