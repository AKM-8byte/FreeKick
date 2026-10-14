extends SceneTree
const Game = preload("res://game.gd")
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
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	for kind in game.sound.KINDS:
		check(game.sound.streams[kind] is AudioStreamWAV and game.sound.streams[kind].get_length() > 0.1, "Playable generated sound: " + kind)
	var events: Array[String] = []
	game.sound.event_played.connect(func(kind, _location, _pitch): events.append(kind))
	game.power = 0.65
	game.start_kick()
	game.animate_kick(game.runup_seconds * 0.25 + 0.025)
	var planted: Vector3 = game.player.boots[1].global_position
	for _step in range(5):
		game.animate_kick(0.025)
		check(game.player.boots[1].global_position.distance_to(planted) < 0.005, "Actual stance boot stays planted while the body advances")
	game.animate_kick(game.runup_seconds - 0.001 - game.kick_elapsed)
	var last_foot: Vector3 = game.player.boots[1].global_position
	game.animate_kick(0.002)
	check(game.player.boots[1].global_position.distance_to(last_foot) < 0.025, "Final step connects continuously to the backswing")
	var support: Vector3 = game.player.boots[0].global_position
	game.animate_kick(0.12)
	check(game.player.boots[0].global_position.distance_to(support) < 0.005, "Support boot stays fixed during preparation")
	game.animate_kick(game.runup_seconds + game.backswing_seconds + game.swing_duration + 0.02 - game.kick_elapsed)
	check(events.count("step") == 4 and events.count("kick") == 1, "Four timed landings and exactly one contact play sounds")
	check(game.replay.launch_velocity.length() > 15 and game.replay.sound_events.size() == 5, "Replay records actual impact and timed audio events")
	game.reset_attempt()
	check(game.replay.sound_events.is_empty() and not game.ball.is_shot_taken, "Reset clears audio replay and shot state")
	for voice in game.sound.voices:
		check(not voice.playing, "Reset stops pending effects")
	print("PRESENTATION CHECKS: %d, FAILURES: %d" % [checks, failures])
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(1 if failures else 0)
