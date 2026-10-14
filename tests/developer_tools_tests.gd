extends SceneTree

const Physics = preload("res://scripts/physics_settings.gd")
const Quality = preload("res://scripts/quality_settings.gd")
const Catalog = preload("res://scripts/dev/parameter_catalog.gd")
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
	var bridge = game.get_node("DeveloperTuning")
	check(Quality.current().level == 2 and game.player.visual_update_hz == 0, "Native starts with authored high quality and full rig rate")
	check(game.hud.advanced_panel.find_child("PhysicsMode", true, false) == null, "Removed physics mode has no in-game selector")
	check(not game.has_method("change_physics_mode") and not Physics.new().has_method("select_mode"), "Removed mode cannot be activated through the game or settings API")
	check(not FileAccess.file_exists("res://scripts/simulation_flight.gd") and not FileAccess.file_exists("res://settings/simulation_physics.tres"), "Rejected physics implementation and resource are removed")
	check(is_equal_approx(game.ball.mass, 0.46) and is_equal_approx(game.ball.angular_damp, 0.22), "The saved game uses its existing mass and spin damping")
	game.phase = game.Phase.FLIGHT
	var errors: PackedStringArray = bridge.submit({"target": "physics", "values": {"mass": 0.45}})
	check(errors.is_empty() and bridge.pending.size() == 1 and is_equal_approx(game.ball.mass, 0.46), "Live physics update queues during flight")
	bridge.submit({"target": "physics", "values": {"mass": 0.46}})
	check(bridge.pending.size() == 1, "Repeated live edits replace the queued target")
	game.reset_attempt()
	await physics_frame
	await physics_frame
	check(bridge.pending.is_empty() and is_equal_approx(game.ball.mass, 0.46), "Queued live edit applies at the next preparation")
	check(not bridge.submit({"target": "physics", "values": {"mass": -2.0}}).is_empty(), "Live protocol rejects invalid physics")
	check(not bridge.submit({"target": "gameplay", "values": {"script": null}}).is_empty(), "Live protocol rejects non-parameter properties")
	bridge.submit({"target": "keeper", "values": {"reaction_delays": PackedFloat32Array([0.32, 0.25, 0.20])}})
	check(is_equal_approx(game.defenders.reaction_delays[1], 0.25), "Keeper live values use existing authoring arrays")
	bridge.submit({"target": "gameplay", "values": {"charge_seconds": 1.5, "replay_speed": 0.30}})
	check(is_equal_approx(game.charge_seconds, 1.5) and is_equal_approx(game.replay.playback_speed, 0.30), "Gameplay and replay runtime parameters are applied")
	var particle_count: int = game.goal_net.cloth.positions.size()
	var high_vertices: int = game.goal_net.vertices.size()
	var physics_mass: float = game.ball.mass
	var low: Resource = Quality.factory_profile(0).duplicate(true)
	check(Quality.apply(game, low).is_empty(), "Low quality validates")
	check(game.goal_net.vertices.size() < high_vertices and game.goal_net.cloth.positions.size() == particle_count, "Reduced rope mesh preserves cloth physics")
	check(game.player.visual_update_hz == 30 and is_equal_approx(game.ball.mass, physics_mass), "Visual throttling preserves ball mechanics")
	check(not game.get_node("World/Node3d98").visible, "Low quality hides only tagged decorative stadium details")
	check(game.get_viewport().msaa_3d == 0 and is_equal_approx(game.get_viewport().scaling_3d_scale, 0.65), "Low render settings reach the viewport")
	var low_defaults: float = Catalog.default_value(low, "render_scale")
	check(is_equal_approx(low_defaults, 0.65), "Default reset uses the selected quality preset")
	Quality.apply(game, Quality.factory_profile(2))
	check(game.goal_net.vertices.size() == high_vertices and game.player.visual_update_hz == 0, "High restores authored mesh and rig quality")
	check(game.get_node("World/Node3d98").visible, "High restores authored stadium decorations")
	var before_uploads: int = game.goal_net.visual_upload_count
	for frame in range(4): game.goal_net.update_visual()
	check(game.goal_net.visual_upload_count == before_uploads, "Resting net does not upload a displacement texture each frame")
	game.player.visible = true
	game.player.sync_rig()
	var bone_uploads: int = game.player.bone_upload_count
	game.player.sync_rig()
	check(game.player.bone_upload_count == bone_uploads, "An unchanged pose reuses cached bone transforms")
	game.player.rig_ik_weight = 0.8
	game.player.sync_rig()
	check(game.player.bone_upload_count == bone_uploads + 15, "Changing the rig weight refreshes every bone")
	game.player.rig_ik_weight = 1
	game.player.sync_rig()
	for actor in [game.player, game.defenders.keeper] + game.defenders.wall_pool:
		check(actor.cached_parts.size() == 15, "Every skinned character has cached IK bindings")
	var invalid: Resource = preload("res://settings/arcade_physics.tres").duplicate(true)
	invalid.mass = NAN
	check(not invalid.validate().is_empty(), "Physics rejects NaN mass")
	invalid = preload("res://settings/arcade_physics.tres").duplicate(true)
	invalid.radius = 0
	check(not invalid.validate().is_empty(), "Physics rejects zero radius")
	low.skeleton_rate = NAN
	check(not low.validate().is_empty(), "Quality rejects NaN rate")
	game.queue_free()
	await process_frame
	var lab = preload("res://scenes/physics_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	check(preload("res://scripts/lab/shot_presets.gd").PRESETS.size() == 10, "All ten named physics experiments are available")
	check(lab.balls.size() == 1 and lab.get("simulation_profile") == null, "Laboratory uses only the current game physics")
	check(lab.save_profile("user://developer-qa-profile.tres") and lab.load_profile("user://developer-qa-profile.tres"), "Lab saves and reloads a validated ball profile")
	lab.select_preset("Saf yuvarlanma")
	await physics_frame
	await physics_frame
	check(lab.spin_axis == Vector3.LEFT and lab.launch_speed == 4, "Rolling preset selects no-slip initial conditions")
	var frozen_start: Vector3 = lab.run_position
	lab.start_position.x = 10
	await physics_frame
	await physics_frame
	check(lab.run_position == frozen_start and absf(lab.metrics[0].lateral_deviation) < 0.01, "Editing the next shot cannot corrupt running-shot metrics")
	lab.queue_free()
	await process_frame
	print("DEVELOPER / QUALITY / LAB CHECKS: ", checks, ", FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
