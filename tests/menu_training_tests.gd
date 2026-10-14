extends SceneTree

const Game = preload("res://game.gd")
const Positions = preload("res://scripts/training_positions.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var locale := root.get_node("Locale")
	for system_language in ["tr_TR", "tr-TR", "TR", "tr"]:
		check(locale.locale_for_system(system_language) == "tr", "Turkish system locale")
	for system_language in ["en_US", "de_DE", "ar", "ja_JP", "", "az_AZ"]:
		check(locale.locale_for_system(system_language) == "en", "Non-Turkish system locale defaults to English")
	locale.set_language("en")
	check(tr("YÖNÜNÜ SEÇ") == "CHOOSE YOUR AIM", "English translation")
	check(tr("Ayarlar yeni denemeye uygulanır.\nUçuş ve tekrar sırasında kilitlenir.").begins_with("Settings apply"), "Multiline translation")
	locale.set_language("tr")
	check(tr("YÖNÜNÜ SEÇ") == "YÖNÜNÜ SEÇ", "Turkish source retained")
	locale.set_language("en")
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	check(menu.column.get_child(1).text == "PLAY", "English main menu")
	menu.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 89714
	var near_count := 0
	var central_count := 0
	var valid := true
	for i in range(20000):
		var p := Positions.sample(rng)
		near_count += int(p.z <= 24)
		central_count += int(absf(p.x) <= 10)
		valid = valid and p.z >= 17 and p.z <= 30 and absf(p.x) <= 25 and p.z - 0.115 > 16.5
	check(valid, "Every sampled ball is within the ranges and fully outside the penalty area")
	check(absf(near_count / 20000.0 - 0.70) < 0.015, "Near-distance probability is 70 percent")
	check(absf(central_count / 20000.0 - 0.70) < 0.015, "Central probability is 70 percent")
	print("SAMPLES: near=%.3f central=%.3f" % [near_count / 20000.0, central_count / 20000.0])
	for x in range(-25, 26):
		for z in range(17, 31):
			var p := Positions.safe_position(x, z)
			check(p.z - 0.115 > 16.5, "Entire ball stays outside box at every whole-metre option")
	check(Positions.safe_position(0, 0).z == 17, "Invalid depth clamped safely")
	var game := Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	check(game.hud.result_label.text == "CHOOSE YOUR AIM", "English dynamic status")
	check(game.hud.distance_slider.min_value == 17 and game.hud.lateral_slider.max_value == 25, "Slider bounds")
	for x in [-25, -20, 0, 20, 25]:
		for z in [17, 30]:
			game.hud.set_slider_value(game.hud.distance_slider, z)
			game.hud.set_slider_value(game.hud.lateral_slider, x)
			game.reset_attempt()
			check(game.ball.position.z - 0.115 > 16.5 and absf(game.ball.position.x) <= 25, "Actual reset at extreme option outside box")
	game.last_ball_position = Vector3(0, 1, 0.5)
	game.ball.position = Vector3(0, 1, -0.5)
	game.check_flight(1.0 / 120)
	check(game.goals == 1 and game.new_position_pending, "Goal schedules a new origin exactly once")
	var scheduled := game.next_origin
	game.check_flight(1.0 / 120)
	check(game.goals == 1 and game.next_origin == scheduled, "Repeated goal checks do not resample")
	check(game.origin != scheduled, "Replay retains the original shot location")
	game.reset_attempt()
	check(game.origin == scheduled and not game.new_position_pending, "Next attempt consumes random origin")
	game.reset_attempt()
	check(game.origin == scheduled, "Miss/retry preserves origin")
	game.next_origin = Vector3(-25, 0.115, 30)
	game.new_position_pending = true
	game.hud.lateral_slider.value = 5
	check(game.origin.x == 5 and not game.new_position_pending, "Manual settings override queued random position")
	game.hud.camera_select.select(1)
	game.reset_attempt()
	check(game.player.visible and game.camera.position.y >= 2.7, "Elevated player camera")
	check((game.camera.position - game.player_start).dot(game.forward) < 0, "Camera behind player")
	game.show_guide()
	await process_frame
	await process_frame
	check(is_instance_valid(game.guide) and game.guide.destinations.size() == 4, "Guide has four UI arrows")
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_SPACE
	game._input(event)
	check(game.guide == null and not game.charging and game.phase == Game.Phase.PREPARE, "Dismiss key consumed without firing")
	game.show_guide()
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	game._input(click)
	check(game.guide == null and not game.charging, "Dismiss click consumed without shooting")
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	print("MENU TRAINING CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)

