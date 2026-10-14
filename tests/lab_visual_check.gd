extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var lab = preload("res://scenes/physics_lab.tscn").instantiate()
	root.add_child(lab)
	await create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/physics/laboratory.png")
	lab.export_results()
	print("LAB VISUAL: metrics=", lab.metrics.size(), " samples=", lab.points[0].size(), "/", lab.points[1].size())
	lab.queue_free()
	await process_frame
	quit()
