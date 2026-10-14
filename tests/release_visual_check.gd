extends SceneTree

func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	root.get_node("Locale").set_language("en")
	DirAccess.make_dir_recursive_absolute("res://test-output/physics")
	root.get_node("Flow").intro_shown = false
	var intro = preload("res://scripts/loading_screen.gd").new()
	intro.auto_start = false
	root.add_child(intro)
	await create_timer(0.75).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/physics/creator-intro.png")
	intro.queue_free()
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.hud.advanced_panel.show()
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/physics/magnus-settings.png")
	print("RELEASE VISUAL CHECK: captured creator intro and Magnus settings")
	game.sound.stop_effects()
	game.sound.ambience.stop()
	game.queue_free()
	await process_frame
	quit()
