extends SceneTree

func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	root.get_node("Locale").set_language("en")
	var flow := root.get_node("Flow")
	flow.pending_path = "res://scenes/detailed_training.tscn"
	flow.pending_tutorial = true
	var loading = preload("res://scenes/loading.tscn").instantiate()
	loading.force_staged_loading = true
	root.add_child(loading)
	current_scene = loading
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/physics/loading-screen.png")
	while flow.is_loading or current_scene == loading: await process_frame
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/physics/tutorial-aim.png")
	var game := current_scene
	var tutorial := game.get_node("InteractiveTutorial")
	tutorial.stage = 2
	tutorial.show_stage()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/physics/tutorial-spin.png")
	print("FLOW VISUAL: ", flow.last_loading_report)
	game.sound.stop_effects()
	game.sound.ambience.stop()
	game.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	quit()
