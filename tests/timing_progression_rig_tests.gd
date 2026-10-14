extends SceneTree

const Game = preload("res://game.gd")
var checks := 0
var failures := 0
var game: Game

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func shot(rating: String) -> Dictionary:
	game.new_position_pending = false
	game.reset_attempt()
	await physics_frame
	await physics_frame
	game.set_physics_process(false)
	for actor in game.defenders.wall:
		actor.get_node("PhysicsBody").collision_layer = 0
		actor.get_node("PhysicsBody").collision_mask = 0
	game.defenders.keeper_body.collision_layer = 0
	game.defenders.keeper_body.collision_mask = 0
	game.power = 0.65
	game.target = Vector3(2.0, 1.4, 0)
	game.hud.picker.point = Vector2(0.50, 0)
	game.start_kick()
	check(game.hud.timing_bar.visible and not game.ball.is_shot_taken, "Timing appears during the approach, before contact")
	var total := game.runup_seconds + game.backswing_seconds + game.swing_duration
	var fraction: float = {"bad": 0.20, "normal": 0.65, "perfect": 0.90, "skip": 0.65}[rating]
	game.animate_kick(total * fraction)
	if rating != "skip":
		var event := InputEventKey.new()
		event.physical_keycode = KEY_SPACE
		event.pressed = true
		game._unhandled_input(event)
		check(game.timing_rating == rating, "Second Space press selects the actual needle zone")
		game.register_timing()
		check(game.timing_rating == rating, "Repeated input cannot change a locked rating")
	else:
		check(not game.timing_locked and game.timing_rating == "", "No second press has no timing penalty")
	game.animate_kick(total - game.kick_elapsed + 0.02)
	check(game.ball.is_shot_taken and not game.hud.timing_bar.visible, "The timing bar closes at physical foot contact")
	var velocity := game.replay.launch_velocity
	var previous := game.ball.position
	var crossing := Vector3.INF
	for _step in range(650):
		await physics_frame
		var current := game.ball.position
		if previous.z > 0 and current.z <= 0:
			crossing = previous.lerp(current, -previous.z / (current.z - previous.z))
			break
		previous = current
	return {"velocity": velocity, "crossing": crossing}

func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 64
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var skip := await shot("skip")
	var normal := await shot("normal")
	var perfect := await shot("perfect")
	var bad := await shot("bad")
	check(skip.velocity.distance_to(normal.velocity) < 0.0001, "Skipping timing preserves the original normal impulse")
	check(skip.crossing.distance_to(normal.crossing) < 0.01, "Normal and skipped timing produce the same actual flight")
	check(perfect.velocity.length() > normal.velocity.length() * 1.05, "Perfect timing gives extra actual launch speed")
	check(perfect.crossing.distance_to(game.target) < normal.crossing.distance_to(game.target), "Perfect timing improves actual curled-shot goal-plane accuracy")
	check(bad.velocity.length() < normal.velocity.length() * 0.65, "Red timing produces a genuinely weak shot")
	check(bad.velocity.normalized().angle_to(normal.velocity.normalized()) > 0.10, "Red timing also changes launch direction")
	game.reset_attempt()
	game.set_physics_process(false)
	check(not game.hud.timing_bar.visible and game.timing_rating == "", "Reset clears timing and glow")
	for actor in [game.player, game.defenders.keeper, game.defenders.wall[0]]:
		check(actor.visual_skeleton != null and actor.rig_bones.size() == 15, "Each original player has a live IK-driven deformation rig")
		var meshes: Array[Node] = actor.get_node("VisualRig").find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty() and meshes[0].skin != null, "Rendered character mesh is skinned to the rig")
		var model_bounds: AABB = meshes[0].mesh.get_aabb()
		check(model_bounds.size.y > 1.6 and model_bounds.size.y < 2.0 and model_bounds.size.x < 1.2 and model_bounds.size.z < 0.8, "Original model exports retain human metre scale")
		var colors := {}
		for surface in meshes[0].mesh.get_surface_count():
			var material: StandardMaterial3D = meshes[0].mesh.surface_get_material(surface)
			colors[material.albedo_color.to_html()] = true
		check(colors.size() >= 8, "Distinct Blender materials export with their actual colors")
		actor.feet[1] += Vector3(0.08, 0.15, -0.24)
		actor.boots[1].rotation = Vector3(0.08, 0.25, 0.12)
		actor.update_pose()
		actor.sync_rig()
		await process_frame
		var rig: Skeleton3D = actor.visual_skeleton
		var bone: int = actor.rig_bones.boot_r
		var rest_part: Transform3D = actor.rig_rest_parts.boot_r
		var rest_to_skeleton: Transform3D = rig.global_transform.affine_inverse() * actor.global_transform
		var bind_point: Vector3 = rest_to_skeleton * rest_part * Vector3(0, -0.05, -0.12)
		var visual_toe: Vector3 = rig.global_transform * rig.get_bone_global_pose(bone) * rig.get_bone_global_rest(bone).affine_inverse() * bind_point
		check(visual_toe.distance_to(actor.boots[1].to_global(Vector3(0, -0.05, -0.12))) < 0.002, "Rigged shoe follows the same physical IK contact point")
	game.reset_attempt()
	game.hud.difficulty_select.select(0)
	game.difficulty_goals = [0, 0, 0]
	game.difficulty_offer_pending = false
	game.register_goal_progress()
	game.register_goal_progress()
	check(not game.difficulty_offer_pending, "Two goals do not trigger difficulty offer")
	game.register_goal_progress()
	game.finish_attempt("GOL!")
	check(game.hud.difficulty_offer.visible and game.hud.difficulty_select.selected == 0, "Third goal offers escalation without changing difficulty")
	game.hud.difficulty_declined.emit()
	check(not game.hud.difficulty_offer.visible and game.hud.difficulty_select.selected == 0, "Declining keeps the selected difficulty")
	for _goal in range(3):
		game.register_goal_progress()
	game.finish_attempt("GOL!")
	game.next_origin = Vector3(-10, 0.115, 23)
	game.new_position_pending = true
	game.hud.difficulty_accepted.emit()
	check(game.hud.difficulty_select.selected == 1 and game.defenders.difficulty_level == 1, "Accepting raises and applies difficulty")
	check(game.origin == Vector3(-10, 0.115, 23), "Escalation retains the scheduled next shot position")
	check(game.defenders.reaction_delay < 0.27 and game.defenders.max_dive_speed > 3.5, "Normal keeper is slightly stronger than previous profile")
	for _goal in range(3):
		game.register_goal_progress()
	game.finish_attempt("GOL!")
	game.hud.difficulty_accepted.emit()
	check(game.hud.difficulty_select.selected == 2, "Three normal-level goals can offer Hard")
	for _goal in range(6):
		game.register_goal_progress()
	check(not game.difficulty_offer_pending, "Hard never offers an invalid fourth difficulty")
	game.sound.stop_effects()
	game.sound.ambience.stop()
	await create_timer(0.3).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	print("TIMING / PROGRESSION / RIG CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
