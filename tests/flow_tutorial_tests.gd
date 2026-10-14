extends SceneTree

var checks := 0
var failures := 0
var original_preferences := PackedByteArray()
var had_preferences := false

func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func load_route(path: String, tutorial: bool, staged: bool = false) -> Node:
	var flow := root.get_node("Flow")
	flow.pending_path = path
	flow.pending_tutorial = tutorial
	var loading = preload("res://scenes/loading.tscn").instantiate()
	loading.force_staged_loading = staged
	root.add_child(loading)
	current_scene = loading
	for frame in range(1200):
		await process_frame
		if current_scene != loading and not flow.is_loading: return current_scene
	check(false, "Scene load completed within the test deadline")
	return null

func wait_strike(game: Node3D) -> void:
	for frame in range(360):
		await physics_frame
		if game.ball.is_shot_taken: break
	await process_frame
	await process_frame
	check(game.ball.is_shot_taken, "Shot applies at actual procedural foot contact")

func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 64
	root.size = Vector2i(1440, 900)
	had_preferences = FileAccess.file_exists("user://preferences.cfg")
	if had_preferences: original_preferences = FileAccess.get_file_as_bytes("user://preferences.cfg")
	var flow := root.get_node("Flow")
	flow.intro_shown = true # Intro animation has a separate real-time test.
	var config := ConfigFile.new()
	config.load("user://preferences.cfg")
	config.set_value("tutorial", "version", 0)
	config.save("user://preferences.cfg")
	root.get_node("Locale").set_language("en")
	check(not flow.tutorial_completed(), "First run checks a separate versioned tutorial record")
	var boot_request: Dictionary = flow.consume_request()
	check(boot_request.tutorial and boot_request.path == flow.training_scene, "A fresh boot routes to tutorial before the menu")
	var game := await load_route("res://scenes/detailed_training.tscn", true)
	if game == null: quit(1); return
	check(flow.tutorial_running and not flow.is_loading, "Native threaded loading starts the interactive tutorial")
	check(not flow.last_loading_report.staged and flow.last_loading_report.build_ms > 0, "Loading report records real native resource / scene timing")
	var tutorial := game.get_node("InteractiveTutorial")
	check(tutorial.title.text == "1 / 4 · AIM" and game.defenders.difficulty_level == 0, "Tutorial is translated and uses Easy difficulty")
	check(tutorial.next_button.disabled, "Aim stage requires an actual aim interaction")
	var aim := InputEventMouseButton.new()
	aim.button_index = MOUSE_BUTTON_LEFT
	aim.pressed = true
	aim.position = game.camera.unproject_position(Vector3(-1, 1.5, 0))
	game._unhandled_input(aim)
	await process_frame
	check(tutorial.aimed and not tutorial.next_button.disabled, "Mouse goal picking completes aim stage")
	tutorial.advance()
	check(tutorial.stage == 1 and tutorial.instructions.text.contains("Space / X"), "Power hint derives from actual keyboard / pad mapping")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	game._unhandled_input(key)
	for step in range(48): await physics_frame
	check(game.charging and game.power >= flow.tutorial_settings.minimum_power, "Mapped keyboard hold charges power")
	key.pressed = false
	game._unhandled_input(key)
	await wait_strike(game)
	check(tutorial.charged, "Power stage completes after a real shot, independent of goal")
	tutorial.advance()
	Input.action_press("contact_right", 1.0)
	for step in range(40): await physics_frame
	Input.action_release("contact_right")
	check(game.hud.picker.point.x >= flow.tutorial_settings.minimum_side_contact, "Contact actions move the selected surface point")
	var pad := InputEventJoypadButton.new()
	pad.device = 1
	pad.button_index = JOY_BUTTON_X
	pad.pressed = true
	game._unhandled_input(pad)
	for step in range(48): await physics_frame
	check(game.charging and game.charge_source == "gamepad:1", "Gamepad mapping accepts a second controller")
	pad.pressed = false
	game._unhandled_input(pad)
	await wait_strike(game)
	check(tutorial.curved, "Side contact shot completes the spin stage")
	tutorial.advance()
	game.hud.charge_started.emit()
	for step in range(40): await physics_frame
	game.hud.charge_released.emit()
	await wait_strike(game)
	check(tutorial.completed and tutorial.stage == 3, "Practice stage counts attempts rather than goals")
	tutorial.advance()
	for frame in range(1200):
		await process_frame
		if current_scene != null and current_scene.get_script().resource_path == "res://scripts/main_menu.gd" and not flow.is_loading: break
	check(flow.tutorial_completed() and not flow.tutorial_running, "Completing tutorial persists completion and returns to main menu")
	check(not flow.consume_request().tutorial, "A completed tutorial routes the next boot directly to the menu")
	var menu := current_scene
	check(menu != null and menu.get_script().resource_path == "res://scripts/main_menu.gd" and menu.tutorial_button.text == "PLAY TUTORIAL AGAIN", "Menu exposes tutorial replay")
	menu.queue_free()
	await process_frame
	var staged_menu := await load_route("res://scenes/main_menu.tscn", false, true)
	check(staged_menu != null and flow.last_loading_report.staged, "Single-thread staged fallback loads a scene without threaded APIs")
	var fractions: Array[float] = []
	for sample in flow.last_loading_report.progress:
		if sample.fraction >= 0: fractions.append(sample.fraction)
	check(not fractions.is_empty() and fractions[-1] == 1.0, "Staged progress reaches one only after completing the dependency list")
	check(staged_menu.tutorial_button != null, "Staged transition preserves the menu controls")
	staged_menu.queue_free()
	await process_frame
	flow.tutorial_running = true
	flow.mark_tutorial_completed(true)
	check(flow.tutorial_completed(), "Skipping tutorial also prevents repeated boot prompts")
	flow.tutorial_running = false
	if had_preferences:
		var restore := FileAccess.open("user://preferences.cfg", FileAccess.WRITE)
		restore.store_buffer(original_preferences)
	else: DirAccess.remove_absolute("user://preferences.cfg")
	print("LOADING / INPUT / TUTORIAL CHECKS: ", checks, ", FAILURES: ", failures)
	await create_timer(0.5, true, false, true).timeout
	quit(1 if failures else 0)
