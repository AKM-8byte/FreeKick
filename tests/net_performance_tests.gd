extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var net = game.goal_net
	var results := {}
	var step := 1.0 / 120.0
	net.active = true
	var started := Time.get_ticks_usec()
	for index in range(120):
		if index % 30 == 0:
			net.cloth.kick(net.cloth.binding(0, 0.5, 0.5), Vector3(0, 0, -0.25), step)
		net.step(step)
	results.cloth_step_ms = (Time.get_ticks_usec() - started) / 120000.0
	for route in ["approaching", "contact"]:
		started = Time.get_ticks_usec()
		for index in range(120):
			var z := -0.2 if route == "approaching" else -1.9
			var position := Vector3((index % 7 - 3) * 0.12, 1.2, z)
			net.contain_sweep(position, position + Vector3(0, 0, -0.22), Vector3(0, 0, -26.4))
		results[route + "_sweep_ms"] = (Time.get_ticks_usec() - started) / 120000.0
	var tag := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	DirAccess.make_dir_recursive_absolute("res://test-output/physics")
	var file := FileAccess.open("res://test-output/physics/net-performance-" + tag + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	print("NET PERFORMANCE ", tag, ": ", results)
	game.sound.stop_effects()
	game.sound.ambience.stop()
	game.queue_free()
	await process_frame
	quit()
