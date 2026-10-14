extends SceneTree

var game

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/" + name + ".png")

func run() -> void:
	root.size = Vector2i(1440, 900)
	root.get_node("Locale").set_language("tr")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	game.set_process(false)
	game.set_physics_process(false)
	game.power = 0.65
	game.start_kick()
	var duration: float = game.runup_seconds + game.backswing_seconds + game.swing_duration
	game.animate_kick(duration * 0.45)
	await capture("timing-approach")
	game.animate_kick(duration * 0.44)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.hud.timing_bar.get_global_rect().get_center()
	click.global_position = click.position
	Input.parse_input_event(click)
	await process_frame
	if game.timing_rating != "perfect":
		push_error("Actual timing bar click did not choose the green zone")
		quit(1)
		return
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await create_timer(0.07).timeout
	await capture("timing-perfect")
	game.reset_attempt()
	game.difficulty_offer_pending = true
	game.hud.show_difficulty_offer(1)
	await capture("difficulty-offer")
	game.sound.stop_effects()
	game.sound.ambience.stop()
	game.queue_free()
	await process_frame
	var gallery := Node3D.new()
	root.add_child(gallery)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("1f2d38")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("c3d4de")
	world.environment.ambient_light_energy = 0.8
	gallery.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.4
	gallery.add_child(light)
	var camera := Camera3D.new()
	gallery.add_child(camera)
	camera.position = Vector3(0, 1.65, -6.4)
	camera.look_at(Vector3(0, 0.95, 0))
	camera.fov = 35
	camera.current = true
	var roles := ["kicker", "keeper", "wall_player"]
	for index in range(3):
		var actor = load("res://scenes/characters/%s.tscn" % roles[index]).instantiate()
		gallery.add_child(actor)
		actor.position.x = (index - 1) * 1.35
		actor.build(Color.WHITE)
		actor.pose_idle()
	await capture("original-player-gallery")
	var keeper = gallery.get_child(4)
	keeper.pelvis.y = 0.85
	keeper.feet[0] = Vector3(-0.35, 0.07, 0)
	keeper.feet[1] = Vector3(0.3, 0.2, -0.1)
	keeper.hand_targets[0] = Vector3(-0.45, 1.75, -0.15)
	keeper.hand_targets[1] = Vector3(0.25, 1.6, -0.15)
	keeper.update_pose()
	await capture("original-player-rig-pose")
	print("ORIGINAL PLAYERS / TIMING BAR VISUAL CHECK: PASS")
	quit()
