extends "res://tests/playability_tests.gd"

func run() -> void:
	var perception = preload("res://scripts/keeper_perception.gd").new()
	perception.reset(42, 0.14)
	var first_bias: Vector3 = perception.bias
	for step in range(40):
		var time := step / 120.0
		perception.record(time, Vector3(time, 1, 25 - time * 20), Vector3(1, 0, -20), Vector3.UP * 30)
	check(perception.observe(0.03, 0.08, 0.4).is_empty(), "No observation is available before perception delay")
	var observed: Dictionary = perception.observe(0.30, 0.08, 0.4)
	check(observed.time <= 0.22 and perception.last_observation_time <= 0.22, "Decision reads a past sample rather than current ball state")
	check(observed.velocity.distance_to(Vector3(1, 0, -20)) <= 0.46, "Observation velocity error is bounded")
	perception.reset(42, 0.14)
	check(perception.bias == first_bias, "Perception errors repeat with the same shot seed")
	for step in range(1000): perception.record(step / 120.0, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	check(perception.samples.size() <= 26, "Observation history remains bounded during long shots")
	perception = null
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 64
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var cases := [[Vector3(-2, 0.2, 0), Vector2(0, 0.65), 0.55], [Vector3(0, 0.2, 0), Vector2(0, 0.65), 0.55], [Vector3(2, 0.2, 0), Vector2(0, 0.65), 0.55], [Vector3(1.5, 1.1, 0), Vector2(0.75, 0), 0.55], [Vector3(3, 1.1, 0), Vector2(0.75, 0), 0.55], [Vector3(-3.35, 2.15, 0), Vector2.ZERO, 0.85]]
	var results := []
	for difficulty in range(3):
		game.hud.difficulty_select.select(difficulty)
		var saves := 0
		var goals := 0
		var samples := []
		for input in cases:
			reset_fixture()
			disable_wall()
			await shoot(input[0], input[1], input[2], 3.0)
			var saved := "keeper" in game.ball.hit_kinds and not game.goal_scored
			saves += int(saved)
			goals += int(game.goal_scored)
			check(game.defenders.perception.last_observation_time <= game.defenders.elapsed - game.defenders.profile_value(game.defenders.observation_delays, 0.08) + 0.001, "Keeper uses delayed observations through every difficulty")
			if game.defenders.diving:
				check(game.defenders.keeper_reach.distance_to(game.defenders.committed_reach) <= game.defenders.maximum_hand_adjustment + 0.001, "Committed hand corrections cannot accumulate beyond reach limit")
			samples.append({"target": [input[0].x, input[0].y], "saved": saved, "goal": game.goal_scored, "kind": game.defenders.save_kind})
		results.append({"difficulty": difficulty, "saves": saves, "goals": goals, "samples": samples})
		check(saves > 0 and saves < cases.size(), "Each difficulty has reachable saves and misses in the fixed shot set")
	# Small paired set is a gameplay comparison, not a population estimate.
	check(results[-1].saves >= results[-3].saves, "Hard difficulty saves at least as many paired shots as Easy")
	game.hud.difficulty_select.select(1)
	var repeated := []
	for repeat in range(2):
		reset_fixture()
		disable_wall()
		await shoot(Vector3(1.5, 1.1, 0), Vector2(0.75, 0), 0.55, 3.0)
		repeated.append({"kind": game.defenders.save_kind, "goal": game.goal_scored, "bias": game.defenders.perception.bias, "dive": game.defenders.dive_velocity})
	check(repeated[0] == repeated[1], "Repeated identical shots make the same keeper decision and launch")
	DirAccess.make_dir_recursive_absolute("res://test-output/physics")
	var file := FileAccess.open("res://test-output/physics/keeper-comparison.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	print("KEEPER PERCEPTION CHECKS: ", checks, ", FAILURES: ", failures)
	for result in results: print("KEEPER PAIRED SET: difficulty=", result.difficulty, " saves=", result.saves, "/", cases.size(), " goals=", result.goals)
	game.sound.stop_effects()
	game.sound.ambience.stop()
	game.queue_free()
	game = null
	await process_frame
	await create_timer(0.5).timeout
	quit(1 if failures else 0)
