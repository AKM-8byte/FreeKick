extends Node3D

const Player = preload("res://procedural_player.gd")
const Flight = preload("res://flight_model.gd")
const Perception = preload("res://scripts/keeper_perception.gd")
const WALL_SCALE := 0.93
const WALL_HEIGHT := 1.85 * WALL_SCALE
enum KeeperPhase { READY, READING, SET, DIVE, LAND, RECOVER }
@export_group("Characters")
@export var wall_character: PackedScene
@export var keeper_character: PackedScene
@export_group("Keeper difficulty: Easy / Normal / Hard")
@export var reaction_delays := PackedFloat32Array([0.38, 0.23, 0.16])
@export var running_speeds := PackedFloat32Array([1.35, 2.50, 3.5])
@export var diving_speeds := PackedFloat32Array([2.4, 3.80, 5.1])
@export var spin_readings := PackedFloat32Array([0.25, 0.70, 0.85])
@export var decision_windows := PackedFloat32Array([0.45, 0.50, 0.54])
@export var observation_delays := PackedFloat32Array([0.12, 0.08, 0.05])
@export var prediction_errors := PackedFloat32Array([0.24, 0.14, 0.07])
@export var velocity_errors := PackedFloat32Array([0.75, 0.40, 0.20])
@export var running_accelerations := PackedFloat32Array([9.0, 14.0, 19.0])
@export var vertical_dive_speeds := PackedFloat32Array([3.9, 4.8, 5.4])
@export_range(0.06, 0.3, 0.01, "suffix:s") var observation_interval := 0.12
@export_range(0.04, 0.15, 0.005, "suffix:s") var dive_set_seconds := 0.075
@export_range(0, 0.4, 0.01, "suffix:m") var maximum_hand_adjustment := 0.22
@export var perception_seed := 12345
@export_range(0.01, 0.25) var normal_hand_correction := 0.09
@export_range(0.01, 0.25) var hard_hand_correction := 0.14
@export_group("Wall")
@export_range(9.15, 15.0) var minimum_wall_distance := 9.15
@export_range(0.4, 0.8) var wall_distance_ratio := 0.60
@export_range(0.8, 1.1) var wall_actor_scale := 0.93
@export_range(0.45, 0.8) var wall_spacing := 0.50
var wall: Array[Player] = []
var wall_pool: Array[Player] = []
var keeper: Player
var keeper_body: AnimatableBody3D
var glove_shapes: Array[CollisionShape3D] = []
var head_collision: CollisionShape3D
var wall_center := Vector3.ZERO
var wall_distance := 9.15
var elapsed := -1.0
var idle_elapsed := 0.0
var keeper_home := Vector3.ZERO
var keeper_target := Vector3.ZERO
var keeper_reach := Vector3.ZERO
var reacted := false
var diving := false
var keeper_phase := KeeperPhase.READY
var difficulty_level := 1
var reaction_delay := 0.16
var run_speed := 3.2
var max_dive_speed := 4.8
var spin_reading := 0.65
var decision_window := 0.60
var next_read := 0.0
var keeper_velocity := 0.0
var predicted_time := 1.0
var set_elapsed := 0.0
var planted_feet: Array[Vector3] = []
var dive_elapsed := 0.0
var dive_side := 1.0
var dive_start := Vector3.ZERO
var dive_hip_start := Vector3.ZERO
var dive_velocity := Vector3.ZERO
var dive_shape_time := 0.45
var vertical_save := false
var landing_elapsed := 0.0
var landing_position := Vector3.ZERO
var landing_basis := Basis.IDENTITY
var recovery_position := Vector3.ZERO
var watch_ball := Vector3.ZERO
var save_kind := ""
var held_ball: RigidBody3D
var landing_hands: Array[Vector3] = []
var push_foot := Vector3.ZERO
var low_save := false
var neck_yaw := 0.0
var neck_pitch := 0.0
var perception := Perception.new()
var committed_reach := Vector3.ZERO

func make_body(actor: Node3D, kind: String) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.set_meta("kind", kind)
	actor.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.23 if kind == "wall" else 0.20
	shape.height = 1.55 if kind == "wall" else 1.42
	collision.shape = shape
	collision.position.y = 0.92
	body.add_child(collision)
	var head := CollisionShape3D.new()
	var head_shape := SphereShape3D.new()
	head_shape.radius = 0.12
	head.shape = head_shape
	head.position.y = 1.73
	body.add_child(head)
	if kind == "keeper":
		head_collision = head
	return body

func setup(ball_position: Vector3, count: int, difficulty: int = 1) -> void:
	if wall_pool.is_empty():
		for child in get_children():
			if child is Player and child.name != "Keeper":
				wall_pool.append(child)
	for actor in wall_pool:
		actor.visible = false
		var body := actor.get_node_or_null("PhysicsBody")
		if body:
			body.collision_layer = 0
	wall.clear()
	if keeper == null:
		keeper = get_node_or_null("Keeper")
	difficulty_level = clampi(difficulty, 0, 2)
	reaction_delay = profile_value(reaction_delays, 0.27)
	run_speed = profile_value(running_speeds, 2.25)
	max_dive_speed = profile_value(diving_speeds, 3.5)
	spin_reading = profile_value(spin_readings, 0.60)
	decision_window = profile_value(decision_windows, 0.50)
	next_read = 0
	watch_ball = ball_position
	var near_side := 1.0 if ball_position.x > 0.5 else -1.0
	var wall_goal := Vector3(near_side * 2.5, 0, 0)
	var ground_ball := Vector3(ball_position.x, 0, ball_position.z)
	var wall_forward := (wall_goal - ground_ball).normalized()
	var right := wall_forward.cross(Vector3.UP)
	# Long-range training places the wall deeper, while respecting a 9.15 m
	# minimum. Fixed ball distance plus aggressive zoom made it loom on screen.
	wall_distance = maxf(minimum_wall_distance, ground_ball.distance_to(wall_goal) * wall_distance_ratio)
	wall_center = ground_ball + wall_forward * wall_distance
	for index in range(count):
		var actor: Player
		if index < wall_pool.size():
			actor = wall_pool[index]
		else:
			actor = wall_character.instantiate() if wall_character else Player.new()
			actor.name = "WallPlayer" + str(index)
			add_child(actor)
			wall_pool.append(actor)
		actor.visible = true
		actor.build(Color("161d23"), true)
		actor.scale = Vector3.ONE * wall_actor_scale
		actor.position = wall_center + right * (index - (count - 1) * 0.5) * wall_spacing
		actor.look_at(ground_ball, Vector3.UP)
		actor.hand_targets = [Vector3(-0.1, 0.94, -0.22), Vector3(0.1, 0.94, -0.22)]
		actor.update_pose()
		if not actor.has_node("PhysicsBody"):
			actor.add_number(index + 6)
			make_body(actor, "wall").name = "PhysicsBody"
		actor.get_node("PhysicsBody").collision_layer = 1
		actor.get_node("PhysicsBody").collision_mask = 1
		wall.append(actor)
	if keeper == null:
		keeper = keeper_character.instantiate() if keeper_character else Player.new()
		keeper.name = "Keeper"
		add_child(keeper)
	keeper.build(Color("f47732"), false, true)
	keeper_home = Vector3(-near_side * 0.75 + ball_position.x * 0.04, 0, 0.65)
	keeper.position = keeper_home
	keeper.rotation = Vector3(0, PI, 0)
	keeper.pose_idle()
	keeper_body = keeper.get_node_or_null("PhysicsBody")
	if keeper_body == null:
		keeper_body = make_body(keeper, "keeper")
		keeper_body.name = "PhysicsBody"
		for side in range(2):
			var glove := CollisionShape3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = 0.14
			glove.shape = sphere
			keeper_body.add_child(glove)
			glove_shapes.append(glove)
	keeper_body.collision_layer = 1
	keeper_body.collision_mask = 1
	keeper_target = keeper.position
	keeper_reach = Vector3(keeper.position.x, 1.3, 0.8)
	elapsed = -1
	idle_elapsed = 0
	reacted = false
	diving = false
	keeper_phase = KeeperPhase.READY
	dive_elapsed = 0
	landing_elapsed = 0
	set_elapsed = 0
	keeper_velocity = 0
	vertical_save = false
	low_save = false
	neck_yaw = 0
	neck_pitch = 0
	save_kind = ""
	held_ball = null
	perception.reset(perception_seed, profile_value(prediction_errors, 0.14))
	ready_pose()
	sync_collision_pose()

func ready_pose() -> void:
	keeper.pelvis = Vector3(0, 0.89, 0)
	keeper.feet = [Vector3(-0.25, 0.07, -0.03), Vector3(0.25, 0.07, 0.03)]
	keeper.hand_targets = [Vector3(-0.39, 1.16, -0.30), Vector3(0.39, 1.16, -0.30)]
	keeper.lean = 0.30
	keeper.update_pose()

func idle_step(delta: float) -> void:
	if elapsed >= 0:
		return
	idle_elapsed += delta
	keeper.position.x = keeper_home.x + sin(idle_elapsed * 1.5) * 0.10
	ready_pose()
	keeper.pelvis.y += sin(idle_elapsed * 3) * 0.014
	keeper.update_pose()
	look_at_ball(delta)
	sync_collision_pose()

func start_reaction(shot_seed: int = -1) -> void:
	elapsed = 0.0
	keeper_phase = KeeperPhase.READING
	perception.reset(perception_seed if shot_seed == -1 else perception_seed ^ shot_seed, profile_value(prediction_errors, 0.14))

func observed_crossing() -> Dictionary:
	var sample := perception.observe(elapsed, profile_value(observation_delays, 0.08), profile_value(velocity_errors, 0.4))
	if sample.is_empty() or sample.velocity.z >= -0.5 or sample.position.z <= 0.65: return {}
	var prediction := Flight.keeper_crossing(sample.position, sample.velocity, sample.spin * spin_reading)
	prediction.position += perception.bias
	prediction.time = maxf(0, prediction.time - (elapsed - sample.time))
	return prediction

func read_shot(ball: RigidBody3D) -> void:
	if ball.linear_velocity.z >= -0.5 or ball.position.z <= 0.65:
		return
	# Read only part of the spin. After takeoff the hips stay ballistic;
	# later observations can make bounded corrections to the glove targets.
	var prediction := observed_crossing()
	if prediction.is_empty(): return
	var predicted: Vector3 = prediction.position
	predicted_time = prediction.time
	keeper_target.x = clampf(predicted.x, -3.45, 3.45)
	keeper_reach = Vector3(clampf(predicted.x, -3.65, 3.65), clampf(predicted.y, 0.12, 2.40), 0.80)
	reacted = true

func step(delta: float, ball: RigidBody3D) -> void:
	if elapsed < 0:
		return
	elapsed += delta
	perception.record(elapsed, ball.position, ball.linear_velocity, ball.angular_velocity)
	watch_ball = ball.position
	# Late observation moves the hands only; a committed jump cannot steer its hips.
	if keeper_phase == KeeperPhase.DIVE and difficulty_level > 0 and ball.position.z > 0.8 and elapsed >= next_read:
		var observed := observed_crossing()
		if not observed.is_empty():
			var destination: Vector3 = observed.position
			destination.y = clampf(destination.y, ball.radius_value() if ball.has_method("radius_value") else 0.12, 2.4)
			destination.x = clampf(destination.x, -3.65, 3.65)
			keeper_reach += (destination - keeper_reach).limit_length(normal_hand_correction if difficulty_level == 1 else hard_hand_correction)
			keeper_reach = committed_reach + (keeper_reach - committed_reach).limit_length(maximum_hand_adjustment)
		next_read = elapsed + observation_interval
	var jump_time := elapsed - 0.09
	var jump := maxf(0.0, 2.15 * jump_time - 4.9 * jump_time * jump_time) if jump_time > 0 else 0.0
	for actor in wall:
		actor.position.y = jump
		actor.pelvis.y = 1.01
		actor.update_pose()
	if keeper_phase == KeeperPhase.READING and elapsed > reaction_delay and elapsed >= next_read:
		read_shot(ball)
		next_read = elapsed + observation_interval
	elif keeper_phase in [KeeperPhase.READING, KeeperPhase.SET]:
		predicted_time = maxf(0, predicted_time - delta)
	match keeper_phase:
		KeeperPhase.READING:
			step_reading(delta)
		KeeperPhase.SET:
			step_set(delta)
		KeeperPhase.DIVE:
			step_dive(delta)
		KeeperPhase.LAND:
			step_landing(delta)
		KeeperPhase.RECOVER:
			step_recovery(delta)
		KeeperPhase.READY:
			ready_pose()
			if save_kind == "TUTTU":
				keeper.hand_targets = [Vector3(-0.10, 1.20, -0.34), Vector3(0.10, 1.20, -0.34)]
				keeper.update_pose()
	look_at_ball(delta)
	sync_collision_pose()
	if is_instance_valid(held_ball):
		var hands_center := (keeper.hands[0].position + keeper.hands[1].position) * 0.5
		held_ball.held_offset = hands_center + Vector3(0, 0, -0.09)

func step_reading(delta: float) -> void:
	if not reacted:
		ready_pose()
		return
	var difference := keeper_target.x - keeper.position.x
	var desired_velocity := clampf(difference * 6, -run_speed, run_speed)
	keeper_velocity = move_toward(keeper_velocity, desired_velocity, delta * profile_value(running_accelerations, 14))
	keeper.position.x = clampf(keeper.position.x + keeper_velocity * delta, -3.05, 3.05)
	ready_pose()
	var stride := sin(elapsed * 21)
	keeper.feet[0] = Vector3(-0.25, 0.07 + maxf(0, stride) * 0.07, stride * 0.06)
	keeper.feet[1] = Vector3(0.25, 0.07 + maxf(0, -stride) * 0.07, -stride * 0.06)
	var local_reach := keeper.to_local(keeper_reach)
	var prepare_hands := 1 - smoothstep(0.45, 0.95, predicted_time)
	keeper.hand_targets[0] = keeper.hand_targets[0].lerp(local_reach + Vector3(-0.16, 0, 0), prepare_hands)
	keeper.hand_targets[1] = keeper.hand_targets[1].lerp(local_reach + Vector3(0.16, 0, 0), prepare_hands)
	keeper.update_pose()
	var commit_time := minf(decision_window, 0.33) if keeper_reach.y < 0.65 else decision_window
	if predicted_time < commit_time and (absf(keeper_reach.x - keeper.position.x) > 0.48 or keeper_reach.y > 1.7 or keeper_reach.y < 0.65):
		keeper_phase = KeeperPhase.SET
		set_elapsed = 0
		planted_feet = [keeper.to_global(keeper.feet[0]), keeper.to_global(keeper.feet[1])]

func step_set(delta: float) -> void:
	set_elapsed += delta
	var t := clampf(set_elapsed / dive_set_seconds, 0, 1)
	keeper.pelvis.y = lerpf(0.89, 0.78, t)
	for side in range(2):
		keeper.feet[side] = keeper.to_local(planted_feet[side])
	var gather := sin(t * PI)
	keeper.hand_targets = [Vector3(-0.25, 1.18 - gather * 0.10, -0.24 + gather * 0.09), Vector3(0.25, 1.18 - gather * 0.10, -0.24 + gather * 0.09)]
	keeper.lean = 0.32 + gather * 0.10
	keeper.update_pose()
	if set_elapsed >= dive_set_seconds:
		begin_dive()

func begin_dive() -> void:
	diving = true
	keeper_phase = KeeperPhase.DIVE
	dive_elapsed = 0
	committed_reach = keeper_reach
	dive_start = keeper.position
	dive_hip_start = keeper.to_global(keeper.hips.position)
	dive_side = 1.0 if keeper_reach.x >= dive_hip_start.x else -1.0
	low_save = keeper_reach.y < 0.65
	push_foot = planted_feet[0 if dive_side > 0 else 1]
	var time := clampf(predicted_time, 0.20, 0.65)
	vertical_save = absf(keeper_reach.x - dive_hip_start.x) < 0.65 and keeper_reach.y > 1.7
	var hip_goal := keeper_reach - Vector3(0, 0.95, 0) if vertical_save else keeper_reach - Vector3(dive_side * 0.65, 0.35, 0)
	if low_save:
		hip_goal.y = 0.30
	var horizontal_speed := clampf((hip_goal.x - dive_hip_start.x) / time, -max_dive_speed, max_dive_speed)
	var vertical_speed := clampf((hip_goal.y - dive_hip_start.y + 4.9 * time * time) / time, -2.0 if low_save else 0.45, profile_value(vertical_dive_speeds, 4.8))
	dive_velocity = Vector3(horizontal_speed, vertical_speed, 0.35)
	dive_shape_time = maxf(0.36, time + 0.08)
	if low_save:
		dive_shape_time = maxf(0.20, time * 0.72)

func step_dive(delta: float) -> void:
	dive_elapsed += delta
	var t := clampf(dive_elapsed / dive_shape_time, 0, 1)
	var angle := smoothstep(0, 1, t) * (0.08 if vertical_save else 1.42)
	# Rotate around the pelvis in WORLD space. Euler Z combined with a 180-degree
	# facing direction used to tip the body away from the side of the save.
	keeper.basis = Basis(Vector3.BACK, -dive_side * angle) * Basis(Vector3.UP, PI)
	var hip := dive_hip_start + dive_velocity * dive_elapsed + Vector3.DOWN * 4.9 * dive_elapsed * dive_elapsed
	keeper.pelvis = Vector3(0, 0.87, 0)
	keeper.position = hip - keeper.basis * keeper.pelvis
	keeper.position.x = clampf(keeper.position.x, -3.7, 3.7)
	var tuck := sin(t * PI) * (0.35 if keeper_reach.y > 1.65 else 1.0)
	var push_side := 0 if dive_side > 0 else 1
	for side in range(2):
		var near_leg := side == push_side
		keeper.feet[side] = Vector3(-0.19 if side == 0 else 0.19, 0.09 + tuck * (0.30 if near_leg else 0.10), 0.10 + tuck * (0.29 if near_leg else 0.13))
	if dive_elapsed < 0.060:
		keeper.feet[0 if dive_side > 0 else 1] = keeper.to_local(push_foot)
	keeper.lean = 0.20 + tuck * 0.10
	if vertical_save:
		keeper.hand_targets = [keeper.to_local(keeper_reach + Vector3(-0.10, 0, 0)), keeper.to_local(keeper_reach + Vector3(0.10, 0, 0))]
	else:
		reach_hands()
	if save_kind == "TUTTU":
		var secure := smoothstep(0, 1, minf(1, dive_elapsed / 0.5))
		keeper.hand_targets[0] = keeper.hand_targets[0].lerp(Vector3(-0.10, 1.20, -0.34), secure)
		keeper.hand_targets[1] = keeper.hand_targets[1].lerp(Vector3(0.10, 1.20, -0.34), secure)
	keeper.update_pose()
	var floor_hit := keep_above_ground()
	if floor_hit and low_save and save_kind != "TUTTU":
		# Ground correction raises the actor. Re-solve the glove target afterwards,
		# otherwise the whole hand rises with the body and misses rolling balls.
		reach_hands()
		keeper.update_pose()
	if floor_hit and dive_elapsed > (0.42 if low_save else 0.28) and dive_velocity.y - 9.8 * dive_elapsed < 0:
		keeper_phase = KeeperPhase.LAND
		landing_elapsed = 0
		landing_position = keeper.position
		landing_basis = keeper.basis
		landing_hands = keeper.hand_targets.duplicate()
		recovery_position = Vector3(clampf(keeper.position.x + dive_side * 0.3, -3, 3), 0, 0.65)

func reach_hands() -> void:
	var leading := 0 if dive_side > 0 else 1
	# Upper hand reaches high shots; the opposite arm balances the body.
	if keeper_reach.y > 1.65:
		leading = 1 - leading
	keeper.hand_targets[leading] = keeper.to_local(keeper_reach)
	if keeper_reach.y > 1.65 or keeper_reach.y < 0.75:
		var sign_x := -1.0 if 1 - leading == 0 else 1.0
		keeper.hand_targets[1 - leading] = Vector3(sign_x * 0.72, 1.35, 0.12)
	else:
		keeper.hand_targets[1 - leading] = keeper.to_local(keeper_reach - Vector3(dive_side * 0.17, 0.13, 0.02))

func keep_above_ground() -> bool:
	var lowest := keeper.to_global(keeper.head.position).y - 0.12
	for boot in keeper.boots:
		for x in [-0.06, 0.06]:
			for z in [-0.12, 0.12]:
				lowest = minf(lowest, boot.to_global(Vector3(x, -0.05, z)).y)
	lowest = minf(lowest, keeper.position.y + keeper.basis.y.y * 0.92 - absf(keeper.basis.y.y) * 0.51 - 0.20)
	if lowest < 0.003:
		keeper.position.y += 0.003 - lowest
		return true
	return false

func step_landing(delta: float) -> void:
	landing_elapsed += delta
	var absorb := 1 - exp(-landing_elapsed * 13)
	keeper.position = landing_position + Vector3(dive_velocity.x * 0.055 * absorb, 0, 0.05 * absorb)
	keeper.basis = Basis(Vector3.BACK, -dive_side * sin(landing_elapsed * 12) * exp(-landing_elapsed * 8) * 0.10) * landing_basis
	for side in range(2):
		var support := Vector3(-0.28 if side == 0 else 0.28, 0.57, -0.25)
		if save_kind == "TUTTU":
			support = Vector3(-0.10 if side == 0 else 0.10, 1.20, -0.34)
		keeper.hand_targets[side] = landing_hands[side].lerp(support, absorb)
	keeper.pelvis.y = 0.73 if vertical_save else 0.83
	# The lower knee absorbs the landing while the trailing leg settles later.
	for side in range(2):
		keeper.feet[side] = keeper.feet[side].lerp(Vector3(-0.17 if side == 0 else 0.17, 0.09, 0.25 if side == (0 if dive_side > 0 else 1) else 0.12), minf(1, delta * 5))
	keeper.update_pose()
	keep_above_ground()
	if landing_elapsed > (0.20 if vertical_save else 0.36):
		keeper_phase = KeeperPhase.RECOVER
		landing_elapsed = 0
		landing_position = keeper.position

func step_recovery(delta: float) -> void:
	landing_elapsed += delta
	var t := smoothstep(0, 1, clampf(landing_elapsed / 0.85, 0, 1))
	keeper.position = landing_position.lerp(recovery_position, t)
	keeper.basis = Basis(Quaternion(landing_basis).slerp(Quaternion(Basis(Vector3.UP, PI)), t))
	keeper.pelvis.y = lerpf(0.83, 0.89, t)
	keeper.feet = [Vector3(-0.17, 0.09, 0.28).lerp(Vector3(-0.25, 0.07, -0.03), t), Vector3(0.17, 0.13, 0.28).lerp(Vector3(0.25, 0.07, 0.03), t)]
	keeper.hand_targets = [Vector3(-0.28, 0.57, -0.25).lerp(Vector3(-0.39, 1.16, -0.30), t), Vector3(0.28, 0.57, -0.25).lerp(Vector3(0.39, 1.16, -0.30), t)]
	if save_kind == "TUTTU":
		keeper.hand_targets = [Vector3(-0.10, 1.20, -0.34), Vector3(0.10, 1.20, -0.34)]
	keeper.lean = lerpf(0.4, 0.3, t)
	keeper.update_pose()
	keep_above_ground()
	if landing_elapsed >= 0.85:
		keeper_phase = KeeperPhase.READY
		keeper.position = recovery_position
		keeper.basis = Basis(Vector3.UP, PI)

func look_at_ball(delta: float) -> void:
	var direction := keeper.to_local(watch_ball) - keeper.head.position
	if direction.length_squared() < 0.01:
		return
	var wanted_yaw := clampf(atan2(-direction.x, -direction.z), -deg_to_rad(65), deg_to_rad(65))
	var wanted_pitch := clampf(atan2(direction.y, maxf(0.01, Vector2(direction.x, direction.z).length())), -deg_to_rad(35), deg_to_rad(25))
	neck_yaw = move_toward(neck_yaw, wanted_yaw, delta * 2.4)
	neck_pitch = move_toward(neck_pitch, wanted_pitch, delta * 1.8)
	keeper.head.rotation = Vector3(neck_pitch, neck_yaw, 0)
	# Once standing, turn the whole body to inspect a ball behind the goal.
	if keeper_phase == KeeperPhase.READY and save_kind != "TUTTU" and watch_ball.z < 0:
		var flat := watch_ball - keeper.position
		flat.y = 0
		if flat.length_squared() > 0.01:
			keeper.quaternion = keeper.quaternion.slerp(Basis.looking_at(flat).get_rotation_quaternion(), minf(1, delta * 1.4))

func on_keeper_contact(ball: RigidBody3D) -> void:
	if save_kind != "" or ball.position.z < 0.05:
		return
	var left := keeper.hands[0].global_position.distance_to(ball.position)
	var right := keeper.hands[1].global_position.distance_to(ball.position)
	if minf(left, right) > 0.30:
		save_kind = "BLOKLADI"
		return
	var incoming: Vector3 = ball.last_air_velocity
	if maxf(left, right) < 0.43 and incoming.length() < 24:
		save_kind = "TUTTU"
		held_ball = ball
		ball.held_by = keeper
		ball.held_offset = keeper.to_local(ball.position)
		ball.knuckle_strength = 0
	else:
		save_kind = "ÇELDİ"
		var outside := 1.0 if ball.position.x >= 0 else -1.0
		var direction := Vector3(outside * 0.65, 0.20 if ball.position.y < 1.6 else 0.40, 0.75).normalized()
		ball.keeper_response = direction * clampf(incoming.length() * 0.48, 8, 16)
		ball.keeper_response_pending = true

func sync_collision_pose() -> void:
	for side in range(glove_shapes.size()):
		glove_shapes[side].position = keeper.hands[side].position
	head_collision.position = keeper.head.position

func profile_value(values: PackedFloat32Array, fallback: float) -> float:
	return values[difficulty_level] if values.size() > difficulty_level else fallback
