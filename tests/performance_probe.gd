extends Node

var game
var results: Array[Dictionary] = []
const Quality = preload("res://scripts/quality_settings.gd")

func _ready() -> void:
	call_deferred("run")

func percentile(values: Array[float], fraction: float) -> float:
	values.sort()
	return values[mini(values.size() - 1, floori((values.size() - 1) * fraction))] if not values.is_empty() else 0.0

func measure(name: String, seconds: float = 2.0) -> Dictionary:
	var times: Array[float] = []
	var physics: Array[float] = []
	var process_times: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	var actors: Array = [game.player, game.defenders.keeper] + game.defenders.wall_pool
	var start_uploads := 0
	for actor in actors: start_uploads += actor.bone_upload_count
	while Time.get_ticks_usec() - start < seconds * 1000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - previous) / 1000.0)
		previous = now
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
	var end_uploads := 0
	for actor in actors: end_uploads += actor.bone_upload_count
	return {"name": name, "quality": Quality.current().level, "bone_uploads_per_s": (end_uploads - start_uploads) / seconds, "render_scale": get_viewport().scaling_3d_scale, "samples": times.size(), "frame_median_ms": percentile(times, 0.5), "frame_p95_ms": percentile(times, 0.95), "physics_median_ms": percentile(physics, 0.5), "process_median_ms": percentile(process_times, 0.5), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}

func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var start := Time.get_ticks_usec()
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	var scene_ms := (Time.get_ticks_usec() - start) / 1000.0
	await get_tree().create_timer(1.0).timeout
	results.append(await measure("cold_platform_default"))
	await get_tree().create_timer(20.0).timeout
	results.append(await measure("warm_platform_default"))
	Quality.apply(game, Quality.factory_profile(2))
	await get_tree().create_timer(6.0).timeout
	results.append(await measure("warm_high_comparable_baseline"))
	game.goal_net.ropes.visible = false
	results.append(await measure("without_net_render"))
	game.goal_net.ropes.visible = true
	var actors: Array = [game.player, game.defenders.keeper] + game.defenders.wall
	for actor in actors:
		actor.set_process(false)
	await get_tree().create_timer(2.0).timeout
	results.append(await measure("without_skeleton_updates"))
	for actor in actors:
		actor.set_process(true)
	await get_tree().create_timer(2.0).timeout
	results.append(await measure("baseline_restored_after_skeleton"))
	game.set_physics_process(false)
	results.append(await measure("without_game_physics_ai_ik"))
	game.set_physics_process(true)
	for node in game.get_node("World").find_children("*", "Light3D", true, false):
		node.shadow_enabled = false
	results.append(await measure("without_shadows"))
	# Restore authored lighting before the final combined ablation.
	for node in game.get_node("World").find_children("*", "Light3D", true, false):
		node.shadow_enabled = true
	game.get_node("World").visible = false
	game.goal_net.ropes.visible = false
	results.append(await measure("without_stadium_and_net"))
	game.get_node("World").visible = true
	game.goal_net.ropes.visible = true
	Quality.apply(game, Quality.factory_profile(1))
	await get_tree().create_timer(6.0).timeout
	results.append(await measure("warm_medium"))
	Quality.apply(game, Quality.factory_profile(0))
	await get_tree().create_timer(6.0).timeout
	results.append(await measure("warm_low"))
	# Separate render-scale cost from rig throttling and preset transitions.
	for test in [[1.0, 45.0], [1.0, 0.0], [0.85, 0.0]]:
		var profile: Resource = Quality.factory_profile(1).duplicate(true)
		profile.render_scale = test[0]
		profile.skeleton_rate = test[1]
		Quality.apply(game, profile)
		await get_tree().create_timer(5.0).timeout
		results.append(await measure("medium_scale_%s_rig_%s" % [test[0], test[1]]))
	var output := {"engine": Engine.get_version_info().string, "web": OS.has_feature("web"), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y], "physics_hz": Engine.physics_ticks_per_second, "scene_instantiation_ms": scene_ms, "measurements": results}
	print("PERFORMANCE_RESULT " + JSON.stringify(output))
	if not OS.has_feature("web"):
		DirAccess.make_dir_recursive_absolute("res://test-output/performance")
		var file := FileAccess.open("res://test-output/performance/native-optimized.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(output, "\t"))
		game.sound.stop_effects()
		game.sound.ambience.stop()
		await get_tree().create_timer(0.3).timeout
		get_tree().quit()
