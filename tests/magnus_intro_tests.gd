extends SceneTree

const Settings = preload("res://scripts/physics_settings.gd")
const Flight = preload("res://flight_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var velocity := Vector3(0, 0, -25)
	var spin := Vector3.UP * 50
	var original := Flight.force(velocity, spin)
	check(original.x < -0.1, "Magnus remains enabled with the original force by default")
	game.hud.magnus_toggle.button_pressed = false
	var disabled := Flight.force(velocity, spin)
	check(disabled.x == 0 and is_equal_approx(disabled.z, original.z), "In-game Magnus toggle removes lift while preserving drag")
	check(is_equal_approx(game.ball.angular_damp, 0.22), "Magnus switch does not change spin damping")
	game.hud.magnus_toggle.button_pressed = true
	check(Flight.force(velocity, spin).is_equal_approx(original), "Turning Magnus back on restores the original force")
	game.hud.set_locked(true)
	check(game.hud.magnus_toggle.disabled, "Magnus control is locked during a shot")
	game.hud.set_locked(false)
	game.hud.magnus_value.value = 0.37
	check(is_equal_approx(Settings.get_value("curl"), 0.37) and is_equal_approx(game.hud.physics_sliders.curl.value, 0.37), "Numeric Magnus input changes the real force value and slider")
	game.hud.physics_sliders.curl.value = 0.91
	check(is_equal_approx(game.hud.magnus_value.value, 0.91), "Slider changes update the numeric input")
	game.hud.set_locked(true)
	check(not game.hud.magnus_value.editable, "Numeric Magnus input locks during flight")
	game.hud.set_locked(false)
	var bridge = game.get_node("DeveloperTuning")
	check(bridge.submit({"target": "physics", "values": {"magnus_enabled": false, "curl": 0.4}}).is_empty(), "Editor live protocol accepts the Magnus switch and strength")
	check(not Settings.magnus_enabled() and Flight.force(velocity, spin).x == 0, "Editor and game use the same live Magnus setting")
	Settings.active_profile.magnus_enabled = true
	check(absf(Flight.force(velocity, spin).x) < absf(original.x), "Magnus strength changes the actual flight force")
	check(ResourceSaver.save(Settings.active_profile, "user://magnus-qa.tres") == OK, "Magnus profile can be saved")
	var saved := ResourceLoader.load("user://magnus-qa.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(saved.magnus_enabled and is_equal_approx(saved.curl, 0.4), "Magnus settings persist in the profile")
	Engine.max_fps = 120
	await process_frame
	await process_frame
	var flow := root.get_node("Flow")
	var was_shown: bool = flow.intro_shown
	flow.intro_shown = false
	var loading = preload("res://scripts/loading_screen.gd").new()
	loading.auto_start = false
	loading.opening_fade_seconds = 0.08
	root.add_child(loading)
	check(loading.opening_screen and loading.credit_label.text == "Created by Ahmet Kayra", "Creator credit is the initial loading screen itself")
	check(loading.credit_label.modulate.a == 0, "Native opening credit begins its animation hidden")
	await create_timer(0.15, true, false, true).timeout
	check(loading.credit_label.modulate.a > 0.8, "Loading screen credit fades into view")
	loading.show_progress("Kaynaklar yükleniyor…", 0.37)
	check(is_equal_approx(loading.bar.value, 37) and loading.credit_label.text == "Created by Ahmet Kayra", "Real resource progress retains the opening credit")
	var transition = preload("res://scripts/loading_screen.gd").new()
	transition.auto_start = false
	root.add_child(transition)
	check(not transition.opening_screen, "Later scene transitions do not replay the opening credit")
	transition.queue_free()
	loading.queue_free()
	flow.intro_shown = was_shown
	game.sound.stop_effects()
	game.sound.ambience.stop()
	game.queue_free()
	await process_frame
	print("MAGNUS / INTRO CHECKS: ", checks, ", FAILURES: ", failures)
	quit(1 if failures else 0)
