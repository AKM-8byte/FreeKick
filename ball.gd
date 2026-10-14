extends RigidBody3D

signal struck(speed: float)
signal obstacle_hit(kind: String)
signal first_ground_contact(speed: float)
const RADIUS := 0.11
const Flight = preload("res://flight_model.gd")
const Shot = preload("res://shot_model.gd")
const Knuckle = preload("res://scripts/knuckle_flight.gd")
const Settings = preload("res://scripts/physics_settings.gd")
@export var physics_profile: Resource
var visual_base_transforms: Dictionary = {}
var is_shot_taken := false
var hit_kinds: Array[String] = []
var reset_pending := false
var reset_transform := Transform3D.IDENTITY
var reset_generation := 0
var pending_velocity := Vector3.ZERO
var pending_spin := Vector3.ZERO
var net_damping_pending := false
var goal_net: Node3D
var replay_mode := false
var knuckle_strength := 0.0
var knuckle_seed := 0
var knuckle_phases := Vector4.ZERO
var flight_time := 0.0
var keeper_response := Vector3.ZERO
var keeper_response_pending := false
var last_air_velocity := Vector3.ZERO
var held_by: Node3D
var held_offset := Vector3.ZERO
var net_previous_position := Vector3.ZERO
var ground_contact_reported := false

func _ready() -> void:
	mass = Settings.get_value("mass")
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	linear_damp = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.22
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	var material := PhysicsMaterial.new()
	material.bounce = Settings.get_value("bounce")
	material.friction = Settings.get_value("friction")
	physics_material_override = material
	body_entered.connect(_on_body_entered)
	freeze = true
	configure_physics()

func configure_physics() -> void:
	var p := selected_profile()
	mass = float(p.mass) if p else Settings.get_value("mass")
	var gravity: float = p.gravity if p else Settings.get_value("gravity")
	gravity_scale = gravity / float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	physics_material_override.bounce = float(p.bounce) if p else Settings.get_value("bounce")
	physics_material_override.friction = float(p.friction) if p else Settings.get_value("friction")
	angular_damp = 0.22
	inertia = Vector3.ZERO
	for child in get_children():
		if child is CollisionShape3D and child.shape is SphereShape3D:
			child.shape = child.shape.duplicate()
			child.shape.radius = radius_value()
		elif child is MeshInstance3D:
			if not visual_base_transforms.has(child.get_instance_id()):
				visual_base_transforms[child.get_instance_id()] = child.transform
			var authored: Transform3D = visual_base_transforms[child.get_instance_id()]
			var ratio := radius_value() / RADIUS
			child.transform = Transform3D(authored.basis.scaled(Vector3.ONE * ratio), authored.origin * ratio)

func selected_profile() -> Resource:
	return physics_profile if physics_profile != null else Settings.active_profile

func radius_value() -> float:
	var p := selected_profile()
	return float(p.radius) if p else RADIUS

func reset_at(location: Vector3) -> void:
	reset_generation += 1
	reset_transform = Transform3D(Basis.IDENTITY, location)
	reset_pending = true
	pending_velocity = Vector3.ZERO
	pending_spin = Vector3.ZERO
	net_damping_pending = false
	knuckle_strength = 0
	flight_time = 0
	ground_contact_reported = false
	keeper_response_pending = false
	held_by = null
	last_air_velocity = Vector3.ZERO
	net_previous_position = location
	global_transform = reset_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	is_shot_taken = false
	hit_kinds.clear()
	# Let the next direct-state callback consume the teleport. Setting a sleeping
	# body's Node transform alone can be overwritten by Jolt's queued old state.
	freeze = false
	sleeping = false
	reset_physics_interpolation()

func strike(contact_offset: Vector3, impulse: Vector3, spin: Vector3, knuckle: float = 0, seed_value: int = -1) -> bool:
	if is_shot_taken or contact_offset.length() > radius_value() + 0.001:
		return false
	is_shot_taken = true
	knuckle_strength = clampf(knuckle, 0, 1)
	knuckle_seed = randi() if seed_value < 0 else seed_value
	knuckle_phases = Knuckle.phases(knuckle_seed)
	flight_time = 0
	freeze = false
	sleeping = false
	if reset_pending:
		pending_velocity = impulse / mass
		pending_spin = spin.limit_length(Shot.MAX_SPIN)
	else:
		apply_central_impulse(impulse)
		angular_velocity = spin.limit_length(Shot.MAX_SPIN)
	struck.emit(impulse.length() / mass)
	return true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if replay_mode:
		return
	if reset_pending or not is_shot_taken:
		state.transform = reset_transform
		state.linear_velocity = pending_velocity if is_shot_taken else Vector3.ZERO
		state.angular_velocity = pending_spin if is_shot_taken else Vector3.ZERO
		reset_pending = false
		if not is_shot_taken:
			call_deferred("_freeze_if_idle", reset_generation)
	if not is_shot_taken:
		return
	if is_instance_valid(held_by):
		state.transform.origin = held_by.to_global(held_offset)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		return
	flight_time += state.step
	var p := selected_profile()
	if keeper_response_pending:
		state.linear_velocity = keeper_response
		state.angular_velocity *= 0.40
		keeper_response_pending = false
		knuckle_strength = 0
	if net_damping_pending:
		state.linear_velocity *= 0.12
		state.angular_velocity *= 0.2
		net_damping_pending = false
	var velocity := state.linear_velocity
	last_air_velocity = velocity
	var speed := velocity.length()
	if speed < 0.2 and (goal_net == null or not goal_net.active):
		return
	state.apply_central_force(Flight.force(velocity, state.angular_velocity, p))
	var strength: float = p.knuckle if p else Settings.get_value("knuckle")
	state.apply_central_force(Knuckle.force(velocity, state.angular_velocity, flight_time, knuckle_strength, knuckle_phases) * strength)
	if goal_net != null:
		var guard: Dictionary = goal_net.contain_sweep(net_previous_position, state.transform.origin, state.linear_velocity)
		state.transform.origin = guard.position
		state.linear_velocity = guard.velocity
		velocity = state.linear_velocity
		var net_force: Vector3 = goal_net.force_on_ball(state.transform.origin, velocity)
		state.apply_central_force(net_force)
		if net_force.length_squared() > 0.01:
			state.linear_velocity *= exp(-6.0 * state.step)
			state.angular_velocity *= exp(-4.0 * state.step)
	net_previous_position = state.transform.origin

func _freeze_if_idle(generation: int) -> void:
	if generation == reset_generation and not is_shot_taken:
		freeze = true

func _on_body_entered(body: Node) -> void:
	if not is_shot_taken or replay_mode:
		return
	var kind: String = body.get_meta("kind", "ground")
	if kind == "ground" and not ground_contact_reported:
		ground_contact_reported = true
		first_ground_contact.emit(last_air_velocity.length())
	if kind in ["ground", "wall", "post", "net", "keeper"]:
		knuckle_strength = 0
	if kind == "net":
		net_damping_pending = true
	register_hit(kind)

func register_hit(kind: String) -> void:
	if kind not in hit_kinds:
		hit_kinds.append(kind)
		obstacle_hit.emit(kind)
