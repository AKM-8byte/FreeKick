extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	root.get_node("Locale").set_language("en")
	var scene: PackedScene = load("res://main.tscn")
	var game = scene.instantiate()
	var hud = game.get_node("HUD")
	hud.initial_distance = 27
	hud.initial_lateral = -12
	hud.initial_wall_count = 2
	game.physics_profile = game.physics_profile.duplicate()
	game.physics_profile.mass = 0.57
	game.ball_camera_fov = 32
	game.replay_speed = 0.35
	var authored_body: MeshInstance3D = game.get_node("Kicker/VisualRig").find_children("*", "MeshInstance3D", true, false)[0]
	var edited_material := StandardMaterial3D.new()
	edited_material.albedo_color = Color("4982c5")
	authored_body.material_override = edited_material
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	check(game.has_node("World") and game.hud == hud, "Saved world and HUD are used without duplicate builders")
	check(game.origin == Vector3(-12, 0.115, 27), "Inspector training settings determine actual starting position")
	check(game.defenders.wall.size() == 2, "Inspector wall count controls active actors")
	check(game.defenders.wall_pool.size() == 4, "Scene actors stay available for reuse")
	check(game.defenders.wall_pool[2].get_node_or_null("PhysicsBody") == null, "Inactive authoring actors do not create physical obstacles")
	check(is_equal_approx(game.ball.mass, 0.57), "Editable resource sets actual ball mass")
	check(authored_body.material_override == edited_material and authored_body.visible, "Rendered rig material edits survive IK initialization")
	check(is_equal_approx(game.camera.fov, 32), "Camera Inspector setting applies")
	check(is_equal_approx(game.replay.playback_speed, 0.35), "Replay Inspector speed applies")
	check(hud.difficulty_select.selected == 0, "Default difficulty is Easy")
	check(game.defenders.reaction_delay > 0.30 and game.defenders.max_dive_speed < 2.8, "Easy keeper is slower than previous Easy profile")
	check(hud.picker.world_mode, "Saved contact picker retains its world overlay mode")
	check(hud.help_label.text.begins_with("1 · Click the goal"), "Saved multiline help translates into English")
	check(hud.fire_button.tooltip_text.begins_with("Hold to charge"), "English tooltip explains charge and release")
	var keeper_id: int = game.defenders.keeper.get_instance_id()
	var wall_id: int = game.defenders.wall[0].get_instance_id()
	game.defenders.keeper.rotation.z = 1.3
	game.reset_attempt()
	check(game.defenders.keeper.get_instance_id() == keeper_id and game.defenders.wall[0].get_instance_id() == wall_id, "Reset retains authored actors")
	check(absf(game.defenders.keeper.rotation.z) < 0.001, "Reset clears dive orientation")
	check(authored_body.material_override == edited_material, "Rendered model edits survive repeated reset")
	hud.physics_sliders.mass.value = 0.60
	hud.defaults_button.pressed.emit()
	check(is_equal_approx(game.ball.mass, 0.57), "Defaults button restores authored physics profile")
	hud.training_button.pressed.emit()
	check(hud.training_panel.visible, "Saved training button signal opens settings")
	hud.advanced_button.pressed.emit()
	check(hud.advanced_panel.visible and not hud.training_panel.visible, "Saved advanced button signal switches panels")
	hud.distance_slider.value = 19
	check(is_equal_approx(game.origin.z, 19), "Saved slider signal resets actual shot position")
	hud.set_locked(true)
	check(not hud.distance_slider.editable and hud.fire_button.disabled, "Flight still locks controls")
	hud.set_locked(false)
	check(game.goal_net.get_child_count() == 8, "Saved net preview reuses ropes without duplicating geometry")
	root.size = Vector2i(1100, 760)
	await process_frame
	await process_frame
	check(hud.timing_bar.get_global_rect().position.y > root.size.y * 0.5, "Timing bar stays below the game view")
	check(not hud.timing_bar.get_global_rect().intersects(hud.fire_button.get_global_rect()) and not hud.timing_bar.get_global_rect().intersects(hud.help_label.get_global_rect()), "Timing stays clear of shoot and help at minimum window size")
	check(not hud.help_label.get_global_rect().intersects(hud.fire_button.get_global_rect()), "Help stays clear of shoot control at minimum window size")
	check(not hud.help_label.get_global_rect().intersects(hud.reset_button.get_global_rect()), "Help stays clear of retry control at minimum window size")
	check(hud.help_label.get_minimum_size().y <= hud.help_label.size.y, "All help lines fit at minimum window size")
	game.sound.stop_effects()
	game.sound.ambience.stop()
	await create_timer(0.3).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	check(menu.play_button.text == "PLAY", "Saved menu uses English")
	var column_id: int = menu.column.get_instance_id()
	menu.change_language(1)
	check(menu.play_button.text == "OYNA" and menu.column.get_instance_id() == column_id, "Changing language preserves authored menu layout")
	menu.queue_free()
	await process_frame
	print("EDITOR AUTHORING CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
