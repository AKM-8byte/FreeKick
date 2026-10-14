extends SceneTree
const Game = preload("res://game.gd")
const Meshes = preload("res://scripts/character_meshes.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	# Saved authoring scenes retain the Blender mesh data; they no longer fill
	# the runtime generator's cache as a side effect of construction.
	var source: Node3D = load("res://assets/models/football_parts.glb").instantiate()
	var parts := {}
	for node in source.find_children("*", "MeshInstance3D", true, false):
		parts[String(node.name)] = node.mesh
	check(parts.size() == 9, "Nine actual Blender mesh parts are available")
	check(game.player.boots[1].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == parts.Boot.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] and game.defenders.keeper.boots[1].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == parts.Boot.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "Saved striker and keeper both retain Blender shoe vertices")
	var bounds: AABB = game.player.boots[1].mesh.get_aabb()
	check(bounds.size.z > 0.24 and bounds.size.z < 0.29 and bounds.size.x < 0.15, "Boot export has correct metre scale and forward axis")
	check(game.player.boots[1].get_node("Sole").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == parts.Sole.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "Rounded outsole is attached to the IK foot")
	source.free()
	var defenders := game.defenders
	defenders.keeper_phase = defenders.KeeperPhase.DIVE
	for local in [Vector3(0, 1.3, 3), Vector3(4, 3, 0), Vector3(-4, -2, 0)]:
		defenders.watch_ball = defenders.keeper.to_global(local)
		var previous := defenders.neck_yaw
		var maximum_yaw := 0.0
		var minimum_pitch := 0.0
		var maximum_pitch := 0.0
		var maximum_step := 0.0
		for _step in range(120):
			defenders.look_at_ball(1.0 / 120.0)
			maximum_yaw = maxf(maximum_yaw, absf(defenders.keeper.head.rotation.y))
			minimum_pitch = minf(minimum_pitch, defenders.keeper.head.rotation.x)
			maximum_pitch = maxf(maximum_pitch, defenders.keeper.head.rotation.x)
			maximum_step = maxf(maximum_step, absf(defenders.neck_yaw - previous))
			previous = defenders.neck_yaw
		check(maximum_yaw <= deg_to_rad(65) + 0.0001, "Actual head cannot rotate through 180 degrees")
		check(minimum_pitch >= deg_to_rad(-35) - 0.0001 and maximum_pitch <= deg_to_rad(25) + 0.0001, "Actual head pitch stays bounded")
		check(maximum_step <= 2.4 / 120 + 0.0001, "Head turns smoothly rather than snapping")
	game.reset_attempt()
	check(defenders.neck_yaw == 0 and defenders.neck_pitch == 0, "Reset clears head tracking")
	print("CHARACTER UPGRADE CHECKS: %d, FAILURES: %d" % [checks, failures])
	game.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
