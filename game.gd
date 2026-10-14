extends Node3D

const Geo = preload("res://geometry.gd")
const Ball = preload("res://ball.gd")
const Player = preload("res://procedural_player.gd")
const Hud = preload("res://game_hud.gd")
const Defenders = preload("res://defenders.gd")
const Timing = preload("res://scripts/shot_timing.gd")
const Shot = preload("res://shot_model.gd")
const GoalNet = preload("res://scripts/goal_net.gd")
const Replay = preload("res://scripts/cinematic_replay.gd")
const AimGuide = preload("res://scripts/aim_guide.gd")
const Positions = preload("res://scripts/training_positions.gd")
const BallPhysicsProfile = preload("res://scripts/ball_physics_profile.gd")
const PhysicsSettings = preload("res://scripts/physics_settings.gd")
const QualitySettings = preload("res://scripts/quality_settings.gd")
signal aim_changed(point: Vector3)

@export_group("Ball physics")
@export var physics_profile: BallPhysicsProfile
@export var quality_profile: Resource
@export_group("Shot and camera")
@export var initial_target := Vector3(2.8, 1.75, 0)
@export_range(0.5, 3.0) var charge_seconds := 1.35
@export_range(15, 75) var ball_camera_fov := 26.0
@export var ball_camera_offset := Vector3(0.60, 1.7, 8.0)
@export_range(30, 85) var player_camera_fov := 54.0
@export var player_camera_offset := Vector3(0.65, 3.2, 3.5)
@export_group("Procedural run-up")
@export var runup_distance := Vector2(2.4, 1.8)
@export_range(0.5, 1.5) var runup_seconds := 1.10
@export_range(0.12, 0.40) var backswing_seconds := 0.20
@export_range(0.08, 0.25) var stride_height := 0.14
@export_group("Optional shot timing")
@export_range(1.0, 1.2) var perfect_power_bonus := 1.08
@export_range(0.0, 0.6) var perfect_aim_assistance := 0.35
@export_group("Replay")
@export_range(0.1, 1.0) var replay_speed := 0.25

enum Phase { PREPARE, KICK, FLIGHT, RESULT, REPLAY }
const GOAL_HALF_WIDTH := 3.66
const GOAL_HEIGHT := 2.44
var phase := Phase.PREPARE
var ball: Ball
var player: Player
var hud: Hud
var defenders: Defenders
var camera: Camera3D
var target_marker: Node3D
var trace_root: Node3D
var trace_points: Array[Vector3] = []
var target := Vector3(2.8, 1.75, 0)
var origin := Vector3(0, 0.115, 21)
var forward := Vector3.FORWARD
var player_start := Vector3.ZERO
var player_finish := Vector3.ZERO
var support_world := Vector3.ZERO
var contact := Vector3.ZERO
var contact_ankle := Vector3.ZERO
var swing_start := Vector3.ZERO
var swing_end := Vector3.ZERO
var foot_velocity := Vector3.ZERO
var kick_elapsed := 0.0
var swing_duration := 0.15
var power := 0.0
var charging := false
var charge_source := ""
var flight_elapsed := 0.0
var stopped_elapsed := 0.0
var last_ball_position := Vector3.ZERO
var attempts := 0
var goals := 0
var goal_scored := false
var goal_time := 0.0
var launch_speed := 0.0
var camera_look := Vector3.ZERO
var aim_guide: AimGuide
var goal_net: GoalNet
var replay: Replay
var guide_power := -1.0
var exit_elapsed := 0.0
var sound: Node
var last_run_step := 0
var backswing_foot := Vector3.ZERO
var strike_shoe_rotation := Vector3.ZERO
var next_origin := Vector3.ZERO
var new_position_pending := false
var position_rng := RandomNumberGenerator.new()
var timing_rating := ""
var timing_locked := false
var timing_seed := 0
var difficulty_goals := [0, 0, 0]
var difficulty_offer_pending := false
var guide: Control
var controller_guide_clock := 0.0

func _ready() -> void:
	position_rng.randomize()
	target = initial_target
	if physics_profile:
		physics_profile.apply()
	build_world()
	build_ball()
	sound = get_node_or_null("Audio")
	if sound == null:
		sound = preload("res://scripts/game_audio.gd").new()
		add_child(sound)
	player = get_node_or_null("Kicker")
	if player == null:
		player = load("res://scenes/characters/kicker.tscn").instantiate() if ResourceLoader.exists("res://scenes/characters/kicker.tscn") else Player.new()
	if player.get_parent() == null:
		add_child(player)
	player.build(Color("5aaeff"))
	defenders = get_node_or_null("Defenders")
	if defenders == null:
		defenders = Defenders.new()
		add_child(defenders)
	if defenders.wall_character == null and ResourceLoader.exists("res://scenes/characters/wall_player.tscn"):
		defenders.wall_character = load("res://scenes/characters/wall_player.tscn")
	if defenders.keeper_character == null and ResourceLoader.exists("res://scenes/characters/keeper.tscn"):
		defenders.keeper_character = load("res://scenes/characters/keeper.tscn")
	hud = get_node_or_null("HUD")
	if hud == null:
		hud = load("res://scenes/ui/game_hud.tscn").instantiate() if ResourceLoader.exists("res://scenes/ui/game_hud.tscn") else Hud.new()
		add_child(hud)
	replay = Replay.new()
	replay.playback_speed = replay_speed
	add_child(replay)
	sound.event_played.connect(replay.record_sound)
	hud.settings_changed.connect(func():
		# Explicit training edits take precedence over the queued next shot.
		new_position_pending = false
		difficulty_offer_pending = false
		reset_attempt()
	)
	hud.reset_requested.connect(reset_attempt)
	hud.charge_started.connect(func(): begin_charge("button"))
	hud.charge_released.connect(func(): release_charge("button"))
	hud.picker.selected.connect(func(_point): update_aim_guide())
	hud.replay_requested.connect(start_replay)
	hud.replay_closed.connect(end_replay)
	hud.menu_requested.connect(open_menu)
	hud.guide_requested.connect(show_guide)
	hud.quality_requested.connect(func(level):
		if phase not in [Phase.PREPARE, Phase.RESULT]: return
		QualitySettings.apply(self, QualitySettings.factory_profile(level))
	)
	hud.timing_pressed.connect(register_timing)
	hud.difficulty_accepted.connect(accept_difficulty_offer)
	hud.difficulty_declined.connect(decline_difficulty_offer)
	ball.obstacle_hit.connect(on_obstacle_hit)
	ball.goal_net = goal_net
	goal_net.ball = ball
	goal_net.touched.connect(func(): ball.register_hit("net"))
	reset_attempt()
	var quality_errors := QualitySettings.apply(self, quality_profile)
	hud.quality_select.select(QualitySettings.current().level)
	if not quality_errors.is_empty(): push_error("; ".join(quality_errors))
	var tuning := preload("res://scripts/dev/runtime_tuning.gd").new()
	tuning.name = "DeveloperTuning"
	add_child(tuning)
	if get_node("/root/Locale").tutorial_pending:
		get_node("/root/Locale").tutorial_pending = false
		call_deferred("show_guide")

func open_menu() -> void:
	var flow := get_node("/root/Flow")
	if flow.tutorial_running: flow.finish_tutorial(true)
	else: flow.request_scene("res://scenes/main_menu.tscn")

func show_guide() -> void:
	if phase != Phase.PREPARE or is_instance_valid(guide):
		return
	charging = false
	power = 0
	hud.set_power(0)
	guide = preload("res://scripts/quick_guide.gd").new()
	guide.game = self
	hud.add_child(guide)

func build_world() -> void:
	if has_node("World"):
		goal_net = get_node_or_null("GoalNet")
		if goal_net == null:
			goal_net = GoalNet.new()
			add_child(goal_net)
		build_camera_and_guides()
		return
	var environment := WorldEnvironment.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("254b72")
	sky.sky_horizon_color = Color("a9c9d5")
	sky.ground_horizon_color = Color("a9c9d5")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9d5ed")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("ffecd5")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	var grass_material := ShaderMaterial.new()
	grass_material.shader = preload("res://grass.gdshader")
	grass_material.set_shader_parameter("grass_color", preload("res://texture/grass/Grass005_1K-PNG_Color.png"))
	grass_material.set_shader_parameter("grass_normal", preload("res://texture/grass/Grass005_1K-PNG_NormalGL.png"))
	grass_material.set_shader_parameter("grass_roughness", preload("res://texture/grass/Grass005_1K-PNG_Roughness.png"))
	Geo.box(self, Vector3(80, 0.2, 76), grass_material, Vector3(0, -0.1, 19))
	Geo.collider(self, Vector3(80, 0.2, 76), Vector3(0, -0.1, 19), "ground")
	var line := Geo.material(Color("cbe5cf"))
	for x in [-34.0, 34.0]:
		Geo.box(self, Vector3(0.08, 0.012, 62), line, Vector3(x, 0.009, 25))
	Geo.box(self, Vector3(68, 0.012, 0.08), line, Vector3(0, 0.009, 0))
	for x in [-20.16, 20.16]:
		Geo.box(self, Vector3(0.08, 0.012, 16.5), line, Vector3(x, 0.009, 8.25))
	Geo.box(self, Vector3(40.32, 0.012, 0.08), line, Vector3(0, 0.009, 16.5))
	for x in [-9.16, 9.16]:
		Geo.box(self, Vector3(0.08, 0.012, 5.5), line, Vector3(x, 0.009, 2.75))
	Geo.box(self, Vector3(18.32, 0.012, 0.08), line, Vector3(0, 0.009, 5.5))
	Geo.sphere(self, 0.07, line, Vector3(0, 0.005, 11)).scale.y = 0.05
	for index in range(41):
		var angle := lerpf(-0.93, 0.93, index / 40.0)
		var a := Vector3(sin(angle) * 9.15, 0.015, 11 + cos(angle) * 9.15)
		var b := Vector3(sin(angle + 0.045) * 9.15, 0.015, 11 + cos(angle + 0.045) * 9.15)
		Geo.between(Geo.rod(self, 0.035, line), a, b)
	build_goal()
	# A quiet stadium backdrop, built entirely from geometry.
	var concrete := Geo.material(Color("243b4a"))
	var seating := Geo.material(Color("42647a"))
	for side in [-1, 1]:
		for tier in range(4):
			Geo.box(self, Vector3(3, 0.65, 65), concrete, Vector3(side * (39 + tier * 2.5), 0.3 + tier * 0.8, 19))
			Geo.box(self, Vector3(2.6, 0.16, 64), seating, Vector3(side * (39 + tier * 2.5), 0.72 + tier * 0.8, 19))
	Geo.box(self, Vector3(60, 2.4, 1), concrete, Vector3(0, 1.2, -7))
	build_crowd(concrete, seating)
	preload("res://scripts/stadium_details.gd").build(self)
	for index in range(9):
		var board := Geo.material(Color("358ca0") if index % 2 == 0 else Color("c89752"))
		Geo.box(self, Vector3(5.7, 0.7, 0.08), board, Vector3(-25.6 + index * 6.4, 0.65, -5.8))
	build_camera_and_guides()

func build_camera_and_guides() -> void:
	camera = get_node_or_null("Camera")
	if camera == null:
		camera = Camera3D.new()
	camera.fov = 58
	camera.current = true
	if camera.get_parent() == null:
		add_child(camera)
	var marker_material := Geo.material(Color("ffbd59"))
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var torus := TorusMesh.new()
	torus.inner_radius = 0.13
	torus.outer_radius = 0.16
	target_marker = Geo.mesh(self, torus, marker_material)
	target_marker.rotation.x = PI / 2
	target_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trace_root = Node3D.new()
	add_child(trace_root)
	aim_guide = AimGuide.new()
	add_child(aim_guide)

func build_crowd(concrete: Material, seating: Material) -> void:
	var bodies := MultiMesh.new()
	bodies.transform_format = MultiMesh.TRANSFORM_3D
	bodies.use_colors = true
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.17
	body_mesh.height = 0.55
	body_mesh.radial_segments = 6
	body_mesh.rings = 2
	bodies.mesh = body_mesh
	bodies.instance_count = 384
	var heads := MultiMesh.new()
	heads.transform_format = MultiMesh.TRANSFORM_3D
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.105
	head_mesh.height = 0.21
	head_mesh.radial_segments = 6
	head_mesh.rings = 3
	heads.mesh = head_mesh
	heads.instance_count = 384
	var colors := [Color("364d69"), Color("b67c63"), Color("6d7564"), Color("c4c3af"), Color("b34c55"), Color("353e45"), Color("cb9b52")]
	for row in range(8):
		var y := 1.1 + row * 0.48
		var z := -8 - row * 0.95
		Geo.box(self, Vector3(46, 0.5, 1.1), concrete, Vector3(0, y - 0.25, z))
		Geo.box(self, Vector3(45.5, 0.1, 0.6), seating, Vector3(0, y + 0.1, z))
		for column in range(48):
			var index := row * 48 + column
			var x := -22 + column * 0.94 + sin(index * 2.8) * 0.08
			var height := y + 0.55 + sin(index * 1.6) * 0.06
			bodies.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(x, height, z)))
			bodies.set_instance_color(index, colors[index % colors.size()])
			heads.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(x, height + 0.38, z)))
	var spectators := MultiMeshInstance3D.new()
	spectators.multimesh = bodies
	var fabric := Geo.material(Color.WHITE)
	fabric.vertex_color_use_as_albedo = true
	fabric.vertex_color_is_srgb = true
	spectators.material_override = fabric
	add_child(spectators)
	var faces := MultiMeshInstance3D.new()
	faces.multimesh = heads
	faces.material_override = Geo.material(Color("b79d87"))
	add_child(faces)
	for height in [1.0, 1.7]:
		Geo.box(self, Vector3(46, 0.035, 0.04), Geo.material(Color("c0c7be")), Vector3(0, height + 1.8, -7.6))

func build_goal() -> void:
	var white := Geo.material(Color("edf3ee"))
	for x in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
		Geo.box(self, Vector3(0.12, GOAL_HEIGHT + 0.12, 0.12), white, Vector3(x, GOAL_HEIGHT * 0.5, 0))
		Geo.collider(self, Vector3(0.12, GOAL_HEIGHT + 0.12, 0.12), Vector3(x, GOAL_HEIGHT * 0.5, 0), "post")
	Geo.box(self, Vector3(7.44, 0.12, 0.12), white, Vector3(0, GOAL_HEIGHT, 0))
	Geo.collider(self, Vector3(7.44, 0.12, 0.12), Vector3(0, GOAL_HEIGHT, 0), "post")
	goal_net = GoalNet.new()
	add_child(goal_net)

func build_ball() -> void:
	ball = get_node_or_null("Ball")
	if ball != null:
		return
	ball = Ball.new()
	add_child(ball)
	var shape := SphereShape3D.new()
	shape.radius = Ball.RADIUS
	var collision := CollisionShape3D.new()
	collision.shape = shape
	ball.add_child(collision)
	Geo.sphere(ball, Ball.RADIUS, Geo.material(Color("f3f4ed")))
	var black := Geo.material(Color("a63d66"))
	for normal in [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var patch := Geo.sphere(ball, 0.042, black, normal * 0.097)
		patch.scale = Vector3(1, 0.3, 1)
		patch.quaternion = Quaternion(Vector3.UP, normal)

func reset_attempt() -> void:
	if new_position_pending:
		hud.set_slider_value(hud.distance_slider, next_origin.z)
		hud.set_slider_value(hud.lateral_slider, next_origin.x)
		new_position_pending = false
	timing_rating = ""
	timing_locked = false
	hud.set_timing_visible(false)
	hud.difficulty_offer.visible = false
	sound.stop_effects()
	if phase == Phase.REPLAY:
		end_replay()
	replay.reset()
	goal_net.reset()
	hud.goal_card.visible = false
	phase = Phase.PREPARE
	charging = false
	charge_source = ""
	power = 0
	kick_elapsed = 0
	last_run_step = 0
	flight_elapsed = 0
	stopped_elapsed = 0
	goal_scored = false
	goal_time = 0
	launch_speed = 0
	exit_elapsed = 0
	origin = Positions.safe_position(hud.lateral_slider.value, hud.distance_slider.value)
	origin.y = ball.radius_value() + 0.005
	ball.reset_at(origin)
	ball.configure_physics()
	hud.sync_physics_controls()
	last_ball_position = origin
	forward = (Vector3(0, 0, 0) - Vector3(origin.x, 0, origin.z)).normalized()
	var right := forward.cross(Vector3.UP)
	player_finish = Vector3(origin.x, 0, origin.z) - right * 0.16 - forward * 0.12
	player_start = player_finish - forward * runup_distance.y - right * runup_distance.x
	player.position = player_start
	player.visible = hud.camera_select.selected == 1
	player.look_at(player.position + forward, Vector3.UP)
	player.pose_idle()
	player.boots[1].rotation = Vector3.ZERO
	support_world = player_finish - right * 0.16 + Vector3.UP * 0.07
	defenders.setup(origin, roundi(hud.wall_slider.value), hud.difficulty_select.selected)
	for child in trace_root.get_children():
		trace_root.remove_child(child)
		child.queue_free()
	trace_points.clear()
	hud.set_locked(false)
	hud.set_power(0)
	hud.set_stats(attempts, goals)
	update_shot_advice()
	hud.wall_distance_label.text = tr("Baraj mesafesi: %.1f m") % defenders.wall_distance
	hud.speed_label.text = tr("Çıkış hızı —")
	hud.set_status(tr("YÖNÜNÜ SEÇ"), tr("Alt temas: yükselt • Üst temas: alçalt • Yan temas: falso"))
	target_marker.position = target + Vector3(0, 0, 0.12)
	target_marker.visible = true
	camera.position = preparation_camera()
	camera_look = preparation_look()
	camera.look_at(camera_look)
	hud.picker.visible = true
	hud.position_contact(camera, origin)
	update_aim_guide()
	if difficulty_offer_pending:
		hud.show_difficulty_offer(hud.difficulty_select.selected + 1)

func preparation_camera() -> Vector3:
	if hud.camera_select.selected == 1:
		camera.fov = player_camera_fov
		return player_start - forward * player_camera_offset.z + Vector3.UP * player_camera_offset.y + forward.cross(Vector3.UP) * player_camera_offset.x
	camera.fov = ball_camera_fov
	return Vector3(origin.x, ball_camera_offset.y, origin.z) - forward * ball_camera_offset.z + forward.cross(Vector3.UP) * ball_camera_offset.x

func preparation_look() -> Vector3:
	if hud.camera_select.selected == 1:
		return Vector3(origin.x * 0.35, 0.5, origin.z * 0.45)
	return Vector3(origin.x * 0.30, 0, origin.z * 0.30)

func update_shot_advice() -> void:
	hud.set_training_info(Vector2(origin.x, origin.z).length(), Shot.recommended_power(Vector2(origin.x, origin.z).length(), hud.picker.point))
	hud.set_contact_info(hud.picker.point)

func update_aim_guide() -> void:
	if hud == null or phase != Phase.PREPARE:
		return
	update_shot_advice()
	guide_power = power if charging else hud.recommended
	var direction := Shot.approach(origin, target, guide_power)
	var offset := Shot.contact_offset(hud.picker.point, forward)
	var impact := Shot.impact(direction * Shot.swing_speed_for_power(guide_power), offset, forward)
	aim_guide.set_shot(origin, impact.impulse / ball.mass, impact.spin)
	aim_guide.visible = true

func _input(event: InputEvent) -> void:
	if get_node("/root/Flow").is_loading: return
	if is_instance_valid(guide):
		if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed):
			guide.dismiss()
			get_viewport().set_input_as_handled()
		return
	if not event.is_echo():
		if phase == Phase.REPLAY and (event.is_action_pressed("replay_previous") or event.is_action_pressed("replay_next")):
			replay.change_angle(-1 if event.is_action_pressed("replay_previous") else 1, self)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("reset_shot"):
			reset_attempt()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("menu") and phase == Phase.REPLAY:
			end_replay()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("menu"):
			open_menu()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if get_node("/root/Flow").is_loading: return
	if is_instance_valid(guide):
		return
	if not event.is_echo():
		if event.is_action_pressed("training"):
			hud.toggle_training()
		var source := "gamepad:%d" % event.device if event is InputEventJoypadButton or event is InputEventJoypadMotion else "keyboard"
		if event.is_action_pressed("shoot"): begin_charge(source)
		elif event.is_action_released("shoot"): release_charge(source)
	if phase != Phase.PREPARE or charging:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var ray_start := camera.project_ray_origin(event.position)
		var ray_direction := camera.project_ray_normal(event.position)
		if ray_direction.z < -0.001:
			var intersection := ray_start + ray_direction * (-ray_start.z / ray_direction.z)
			target = Vector3(clampf(intersection.x, -7.0, 7.0), clampf(intersection.y, 0.15, 2.25), 0)
			target_marker.position = target + Vector3(0, 0, 0.12)
			aim_changed.emit(target)
			update_aim_guide()

func begin_charge(source: String) -> void:
	if phase == Phase.KICK:
		register_timing()
		return
	if phase != Phase.PREPARE or charging or is_instance_valid(guide):
		return
	charging = true
	charge_source = source
	power = 0.05
	hud.set_status(tr("GÜCÜ AYARLA"), tr("Bıraktığında koşu ve vuruş başlayacak."))

func release_charge(source: String) -> void:
	if phase != Phase.PREPARE or not charging or source != charge_source:
		return
	charging = false
	start_kick()

func start_kick() -> void:
	if phase != Phase.PREPARE:
		return
	decline_difficulty_offer()
	timing_rating = ""
	timing_locked = false
	timing_seed = int(hud.picker.point.x * 10000) + int(hud.picker.point.y * 1000) + roundi(power * 100) * 79
	phase = Phase.KICK
	player.visible = true
	hud.picker.visible = false
	aim_guide.visible = false
	hud.set_power(power)
	update_shot_advice()
	hud.set_locked(true)
	hud.set_timing_visible(true)
	hud.set_status(tr("VURUŞ HAZIRLANIYOR"), tr("Destek ayağı sabitleniyor; temas anında top hareket edecek."))
	var attack := Shot.approach(origin, target, power)
	contact = Shot.contact_offset(hud.picker.point, forward)
	foot_velocity = attack * Shot.swing_speed_for_power(power)
	strike_shoe_rotation = Shot.shoe_rotation(hud.picker.point, player.basis.inverse() * attack)
	player.boots[1].rotation = strike_shoe_rotation
	var toe_offset := player.basis * (Vector3(0, -0.015, -0.025) + player.boots[1].basis * Vector3(0, -0.05, -0.12))
	contact_ankle = origin + contact - toe_offset
	player.boots[1].rotation = Vector3.ZERO
	backswing_foot = run_foot_at(runup_seconds, 1)
	swing_start = contact_ankle - forward * 0.55 + Vector3.UP * 0.28
	swing_end = contact_ankle + attack * 0.42 + Vector3.UP * 0.12
	swing_duration = lerpf(0.18, 0.10, power)
	kick_elapsed = 0
	replay.begin(self)

static func hermite(start: Vector3, end: Vector3, start_velocity: Vector3, end_velocity: Vector3, time: float, duration: float) -> Vector3:
	var t := clampf(time / duration, 0, 1)
	return (2 * t * t * t - 3 * t * t + 1) * start + (t * t * t - 2 * t * t + t) * duration * start_velocity + (-2 * t * t * t + 3 * t * t) * end + (t * t * t - t * t) * duration * end_velocity

func run_landing(time: float, side: int) -> Vector3:
	if side == 0 and time >= runup_seconds:
		return support_world
	var progress := minf(1, time / runup_seconds + 0.10)
	return player_start.lerp(player_finish, smoothstep(0, 1, progress)) + player.basis * Vector3(-0.16 if side == 0 else 0.16, 0.07, 0)

func run_foot_at(time: float, side: int) -> Vector3:
	var planted := player_start + player.basis * Vector3(-0.16 if side == 0 else 0.16, 0.07, 0)
	var landings := [runup_seconds * 0.5, runup_seconds] if side == 0 else [runup_seconds * 0.25, runup_seconds * 0.75]
	for landing in landings:
		if time < landing - (runup_seconds * 0.25):
			return planted
		var destination := run_landing(landing, side)
		if time < landing:
			var swing := clampf((time - landing + (runup_seconds * 0.25)) / (runup_seconds * 0.25), 0, 1)
			return planted.lerp(destination, smoothstep(0, 1, swing)) + Vector3.UP * sin(swing * PI) * stride_height
		planted = destination
	return planted

func run_boot_pitch(time: float, side: int) -> float:
	var landings := [runup_seconds * 0.5, runup_seconds] if side == 0 else [runup_seconds * 0.25, runup_seconds * 0.75]
	for landing in landings:
		if time >= landing - (runup_seconds * 0.25) and time < landing:
			return sin((time - landing + (runup_seconds * 0.25)) / (runup_seconds * 0.25) * PI) * 0.25
	return 0.0

func animate_kick(delta: float) -> void:
	kick_elapsed += delta
	if not ball.is_shot_taken and not timing_locked:
		hud.timing_bar.update_progress(timing_progress())
	if kick_elapsed < runup_seconds:
		var t := kick_elapsed / runup_seconds
		player.position = player_start.lerp(player_finish, smoothstep(0, 1, t))
		var stride := sin(t * TAU * 2)
		for side in range(2):
			player.feet[side] = player.to_local(run_foot_at(kick_elapsed, side))
			player.boots[side].rotation.x = run_boot_pitch(kick_elapsed, side)
		player.pelvis.y = 0.96 + absf(stride) * 0.025
		player.lean = 0.35
		player.twist = sin(t * TAU * 2) * 0.13
		player.hand_targets = [Vector3(-0.34, 1.13, stride * 0.24), Vector3(0.34, 1.13, -stride * 0.24)]
	else:
		player.position = player_finish
		player.boots[0].rotation = Vector3.ZERO
		player.feet[0] = player.to_local(support_world)
		player.hand_targets = [Vector3(-0.5, 1.25, -0.1), Vector3(0.5, 1.18, 0.13)]
		player.pelvis = Vector3(0, 0.96, 0)
		player.lean = 0.5 * power
		var coil := smoothstep(0, 1, clampf((kick_elapsed - runup_seconds) / backswing_seconds, 0, 1))
		player.boots[1].rotation = Vector3.ZERO.lerp(strike_shoe_rotation, coil)
		var release := smoothstep(0, 1, clampf((kick_elapsed - (runup_seconds + backswing_seconds)) / (swing_duration + 0.20), 0, 1))
		player.twist = lerpf(-0.30 * coil, 0.38, release) * (0.55 + power * 0.45)
		player.hand_targets[0] = Vector3(-0.50, 1.23 + release * 0.08, -0.24 + release * 0.46)
		player.hand_targets[1] = Vector3(0.45, 1.12, 0.24 - release * 0.36)
		var foot_world: Vector3
		if kick_elapsed < (runup_seconds + backswing_seconds):
			var initial := backswing_foot
			foot_world = initial.lerp(swing_start, smoothstep(0, 1, (kick_elapsed - runup_seconds) / backswing_seconds))
		elif kick_elapsed < (runup_seconds + backswing_seconds) + swing_duration:
			foot_world = hermite(swing_start, contact_ankle, Vector3.ZERO, foot_velocity, kick_elapsed - (runup_seconds + backswing_seconds), swing_duration)
		else:
			# Evaluate the exact contact endpoint, independently of render frame rate.
			if not ball.is_shot_taken:
				player.feet[1] = player.to_local(contact_ankle)
				player.update_pose()
				var impact := Shot.impact(foot_velocity, contact, forward)
				impact = Timing.apply(impact, timing_rating, origin, target, ball.mass, timing_seed, perfect_power_bonus, perfect_aim_assistance)
				hud.set_timing_visible(false)
				ball.strike(contact, impact.impulse, impact.spin, impact.knuckle)
				replay.mark_strike(impact, ball.mass)
				sound.play_effect("kick", origin, 0.9 + power * 0.2)
				launch_speed = impact.impulse.length() / ball.mass
				attempts += 1
				defenders.start_reaction(timing_seed)
				hud.set_stats(attempts, goals)
				hud.speed_label.text = tr("Çıkış hızı %.1f km/sa") % (launch_speed * 3.6)
				hud.set_status(tr("TOP OYUNDA"), tr("Topun uçuşunu izle • R: yeniden dene"))
				target_marker.visible = false
				last_ball_position = origin
			var after := kick_elapsed - (runup_seconds + backswing_seconds) - swing_duration
			foot_world = hermite(contact_ankle, swing_end, foot_velocity, Vector3.ZERO, after, 0.16)
			if after > 0.16:
				var resting := player_finish + player.basis * Vector3(0.16, 0.07, -0.18)
				foot_world = swing_end.lerp(resting, smoothstep(0, 1, (after - 0.16) / 0.35))
			if after > 0.36 and phase == Phase.KICK:
				phase = Phase.FLIGHT
		foot_world.y = maxf(0.07, foot_world.y)
		player.feet[1] = player.to_local(foot_world)
	var step_index := mini(4, floori(kick_elapsed / (runup_seconds * 0.25)))
	if step_index > last_run_step:
		for landing_step in range(last_run_step + 1, step_index + 1):
			sound.play_effect("step", run_landing(landing_step * (runup_seconds * 0.25), 1 if landing_step % 2 == 1 else 0))
		last_run_step = step_index
	player.update_pose()
	var head_direction := player.to_local(ball.global_position) - player.head.position
	if head_direction.length_squared() > 0.01:
		var horizontal := maxf(0.05, Vector2(head_direction.x, head_direction.z).length())
		head_direction.y = clampf(head_direction.y, -horizontal * 0.85, horizontal * 0.85)
		player.head.quaternion = player.head.quaternion.slerp(Basis.looking_at(head_direction, Vector3.UP).get_rotation_quaternion(), minf(1, delta * 12))

func _physics_process(delta: float) -> void:
	if get_node("/root/Flow").is_loading: return
	if phase == Phase.PREPARE and not charging:
		var aim := Input.get_vector("aim_left", "aim_right", "aim_down", "aim_up")
		var touch := Input.get_vector("contact_left", "contact_right", "contact_down", "contact_up")
		if aim.length_squared() + touch.length_squared() > 0:
			target.x = clampf(target.x + aim.x * delta * 3, -7, 7)
			target.y = clampf(target.y + aim.y * delta * 1.8, 0.15, 2.25)
			target_marker.position = target + Vector3(0, 0, 0.12)
			hud.picker.point = (hud.picker.point + touch * delta * 0.9).limit_length(0.92)
			hud.picker.queue_redraw()
			if not aim.is_zero_approx(): aim_changed.emit(target)
			controller_guide_clock += delta
			if controller_guide_clock >= 0.05:
				controller_guide_clock = 0
				update_aim_guide()
	if phase == Phase.REPLAY:
		return
	goal_net.step(delta)
	if charging:
		power = minf(1, power + delta / charge_seconds)
		hud.set_power(power)
	if phase == Phase.KICK:
		animate_kick(delta)
	elif ball.is_shot_taken:
		settle_after_kick(delta)
	if not ball.is_shot_taken:
		defenders.idle_step(delta)
	if ball.is_shot_taken:
		defenders.step(delta, ball)
		if phase != Phase.RESULT:
			flight_elapsed += delta
			check_flight(delta)
	if replay.recording:
		replay.record(delta, self, phase == Phase.RESULT)
		if phase == Phase.RESULT and goal_scored:
			hud.show_goal_card(replay.available())

func settle_after_kick(delta: float) -> void:
	exit_elapsed += delta
	var t := smoothstep(0, 1, exit_elapsed / 0.42)
	var right := forward.cross(Vector3.UP)
	player.position = player_finish - right * 2.50 * t - forward * 0.25 * t
	var stride := sin(minf(exit_elapsed / 0.42, 1) * TAU * 1.5) * (1 - t)
	player.feet = [Vector3(-0.16, 0.07 + maxf(0, stride) * 0.07, stride * 0.12), Vector3(0.16, 0.07 + maxf(0, -stride) * 0.07, -stride * 0.12)]
	player.pelvis.y = 1.01
	player.hand_targets = [Vector3(-0.36, 1.10, 0), Vector3(0.36, 1.10, 0)]
	player.lean = 0.1
	player.twist = lerpf(player.twist, 0, minf(1, delta * 8))
	player.update_pose()

static func goal_crossing(previous: Vector3, current: Vector3, radius: float = Ball.RADIUS) -> bool:
	var plane := -radius
	if previous.z <= plane or current.z > plane:
		return false
	var crossing := previous.lerp(current, (plane - previous.z) / (current.z - previous.z))
	# Inner edges of the 12 cm posts and crossbar, plus the complete ball radius.
	return absf(crossing.x) < GOAL_HALF_WIDTH - 0.06 - radius and crossing.y >= radius - 0.01 and crossing.y < GOAL_HEIGHT - 0.06 - radius

func check_flight(delta: float) -> void:
	var location := ball.position
	if not goal_scored and goal_crossing(last_ball_position, location, ball.radius_value()):
		goal_scored = true
		goal_time = flight_elapsed
		goal_net.active = true
		replay.goal_time = replay.elapsed
		goals += 1
		register_goal_progress()
		next_origin = Positions.sample(position_rng)
		while next_origin.distance_to(origin) < 0.5:
			next_origin = Positions.sample(position_rng)
		new_position_pending = true
		sound.play_effect("goal", Vector3(0, 1, 0))
		hud.set_stats(attempts, goals)
		hud.set_status(tr("GOL!"), tr("Topun tamamı kale çizgisini geçti.  •  R: yeniden dene"))
		hud.show_goal_card(false)
	last_ball_position = location
	if trace_points.is_empty() or location.distance_to(trace_points.back()) > 0.35:
		if not trace_points.is_empty():
			var segment := Geo.rod(trace_root, 0.008, Geo.material(Color("80dfe9")))
			segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Geo.between(segment, trace_points.back(), location)
		trace_points.append(location)
		if trace_root.get_child_count() > 400:
			var first := trace_root.get_child(0)
			trace_root.remove_child(first)
			first.queue_free()
	if ball.linear_velocity.length() < 0.5 and flight_elapsed > 0.5:
		stopped_elapsed += delta
	else:
		stopped_elapsed = 0
	if goal_scored and flight_elapsed - goal_time > 0.7:
		finish_attempt(tr("GOL!"))
	elif stopped_elapsed > 0.8 or flight_elapsed > 8 or absf(location.x) > 34 or location.z < -4 or location.z > 48:
		var result := tr("KAÇTI")
		if "keeper" in ball.hit_kinds:
			result = tr("KALECİ KURTARDI")
		elif "wall" in ball.hit_kinds:
			result = tr("BARAJA TAKILDI")
		elif "post" in ball.hit_kinds:
			result = tr("DİREK!")
		finish_attempt(result)

func finish_attempt(result: String) -> void:
	phase = Phase.RESULT
	if difficulty_offer_pending:
		hud.show_difficulty_offer(hud.difficulty_select.selected + 1)
	hud.set_status(result, tr("R veya TEKRAR ile aynı ayarlarda yeniden dene."))
	if goal_scored:
		hud.set_status(result, tr("Yeni vuruş konumu hazır. R veya SONRAKİ ŞUT ile devam et."))
	ball.freeze = not is_instance_valid(ball.held_by)
	if goal_scored and not replay.recording:
		hud.show_goal_card(replay.available())

func start_replay() -> void:
	if phase != Phase.RESULT or not goal_scored:
		return
	if replay.start(self):
		phase = Phase.REPLAY
		hud.difficulty_offer.visible = false
		hud.set_replay(true)

func end_replay() -> void:
	if phase != Phase.REPLAY:
		return
	replay.stop(self)
	phase = Phase.RESULT
	hud.set_replay(false)
	hud.show_goal_card(replay.available())
	if difficulty_offer_pending:
		hud.show_difficulty_offer(hud.difficulty_select.selected + 1)

func on_obstacle_hit(kind: String) -> void:
	if phase != Phase.REPLAY:
		sound.play_effect("net" if kind == "net" else ("post" if kind == "post" else "bounce"), ball.position)
	if goal_scored or phase == Phase.RESULT:
		return
	if kind == "keeper":
		defenders.on_keeper_contact(ball)
	var titles := {"wall": tr("BARAJA ÇARPTI"), "keeper": tr("KALECİ TEMAS ETTİ"), "post": tr("DİREĞE ÇARPTI")}
	if titles.has(kind):
		hud.set_status(titles[kind], tr("Top oyunda; şutun sonucu bekleniyor."))

func _process(delta: float) -> void:
	if camera == null or hud == null:
		return
	if phase == Phase.REPLAY:
		if not replay.advance(delta, self):
			end_replay()
		return
	trace_root.visible = hud.trace_toggle.button_pressed and QualitySettings.current().flight_trail
	if phase == Phase.PREPARE:
		hud.position_contact(camera, origin)
		if charging and absf(power - guide_power) > 0.04:
			update_aim_guide()
	if ball.is_shot_taken:
		var home := preparation_camera()
		var camera_target := home + forward * minf(flight_elapsed * 0.55, 1.4)
		camera.position = camera.position.lerp(camera_target, 1 - exp(-delta * 2.2))
		var look := preparation_look() + Vector3(ball.position.x * 0.05, ball.position.y * 0.02, 0)
		camera_look = camera_look.lerp(look, 1 - exp(-delta * 3))
		camera.look_at(camera_look)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and charging:
		charging = false
		charge_source = ""
		power = 0
		if hud != null:
			hud.set_power(0)
			hud.set_status(tr("HAZIR"), tr("Boşluk tuşunu basılı tutup bırakarak vur."))

func timing_progress() -> float:
	return clampf(kick_elapsed / (runup_seconds + backswing_seconds + swing_duration), 0, 1)

func register_timing() -> void:
	if phase != Phase.KICK or timing_locked or ball.is_shot_taken:
		return
	timing_locked = true
	timing_rating = Timing.quality(timing_progress(), hud.timing_bar.orange_start, hud.timing_bar.green_start)
	hud.timing_bar.set_rating(timing_rating)
	hud.fire_button.disabled = true

func register_goal_progress() -> void:
	var level := hud.difficulty_select.selected
	if level >= 2:
		return
	difficulty_goals[level] += 1
	if difficulty_goals[level] >= 3:
		difficulty_goals[level] = 0
		difficulty_offer_pending = true

func accept_difficulty_offer() -> void:
	if not difficulty_offer_pending or phase not in [Phase.PREPARE, Phase.RESULT]:
		return
	var level := hud.difficulty_select.selected
	hud.difficulty_select.select(mini(2, level + 1))
	difficulty_offer_pending = false
	reset_attempt()

func decline_difficulty_offer() -> void:
	difficulty_offer_pending = false
	hud.difficulty_offer.visible = false
