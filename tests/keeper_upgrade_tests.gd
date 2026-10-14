extends "res://tests/playability_tests.gd"

func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 64
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.hud.difficulty_select.select(1)
	var low_saves := 0
	var curve_saves := 0
	for x in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		reset_fixture()
		disable_wall()
		var result := await shoot(Vector3(x, 0.20, 0), Vector2(0, 0.65), 0.55, 3.0)
		var saved := "keeper" in game.ball.hit_kinds and not game.goal_scored
		low_saves += int(saved)
		print("LOW ", x, " save=", saved, " kind=", game.defenders.save_kind, " cross=", result.crossing)
	check(low_saves >= 3, "Balanced keeper physically saves reachable grounded shots on both sides")
	for x in [0.9, 1.5, 2.2, 3.0, 4.0]:
		reset_fixture()
		disable_wall()
		await shoot(Vector3(x, 1.1, 0), Vector2(0.75, 0), 0.55, 3.0)
		var saved := "keeper" in game.ball.hit_kinds and not game.goal_scored
		curve_saves += int(saved)
		print("CURVE ", x, " save=", saved, " kind=", game.defenders.save_kind)
	# Delayed perception and a total hand correction limit intentionally make
	# the new Normal keeper less omniscient than the original three-save gate.
	check(curve_saves >= 2 and curve_saves < 5, "Balanced keeper saves reachable curves while remaining beatable under delayed perception")
	reset_fixture()
	disable_wall()
	await shoot(Vector3(-3.35, 2.15, 0), Vector2.ZERO, 0.85, 3.0)
	check(game.goal_scored, "A strong distant corner remains scoreable against balanced difficulty")
	reset_fixture()
	check(not game.defenders.low_save and game.defenders.save_kind == "", "Reset clears low dive and save state")
	print("KEEPER UPGRADE CHECKS: %d, FAILURES: %d" % [checks, failures])
	game.sound.stop_effects()
	game.sound.ambience.stop()
	await create_timer(0.3).timeout
	game.queue_free()
	await process_frame
	# Let the audio mixing thread release stopped playback references.
	await create_timer(0.5).timeout
	quit(1 if failures else 0)

