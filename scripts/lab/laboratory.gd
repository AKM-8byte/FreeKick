extends Node3D

const Geo = preload("res://geometry.gd")
const Presets = preload("res://scripts/lab/shot_presets.gd")
@export var arcade_profile: Resource = preload("res://settings/arcade_physics.tres")
@export var start_position := Vector3(0, 0.12, 25)
@export_range(-80, 80, 0.1, "suffix:°") var yaw_degrees := 0.0
@export_range(-45, 80, 0.1, "suffix:°") var elevation_degrees := 18.0
@export_range(0, 45, 0.1, "suffix:m/s") var launch_speed := 27.0
@export var spin_axis := Vector3.UP
@export_range(0, 120, 0.1, "suffix:rad/s") var spin_speed := 35.0
@export_range(0, 2, 0.01) var air_drag := 1.10
@export_range(0, 1.5, 0.01) var magnus_scale := 0.80
@export var include_goal_collisions := false
@export_range(0, 1, 0.01) var ground_bounce := 0.55
@export_range(0, 1, 0.01) var ground_friction := 0.55
@export_range(2, 120, 1, "suffix:s") var maximum_time := 30.0
@export var shot_seed := 12345
@export var knuckle_requested := false
var balls: Array = []
var tracks: Array[MeshInstance3D] = []
var points: Array[PackedVector3Array] = []
var metrics: Array[Dictionary] = []
var running := false
var elapsed := 0.0
var sample_clock := 0.0
var generation := 0
var result_label: RichTextLabel
var inputs: Dictionary = {}
var knuckle_toggle: CheckButton
var goal_toggle: CheckButton
var feedback: Label
var run_position := Vector3.ZERO
var run_velocity := Vector3.ZERO
var run_seed := 0
var run_maximum_time := 30.0
var run_air_drag := 1.10

func _ready() -> void:
	build_world()
	for index in range(1):
		var ball = preload("res://scenes/ball.tscn").instantiate()
		ball.name = "Ball"
		ball.physics_profile = arcade_profile.duplicate(true)
		ball.collision_layer = 2
		ball.collision_mask = 1
		add_child(ball)
		balls.append(ball)
		ball.obstacle_hit.connect(func(kind): ground_contact(index, kind))
		ball.first_ground_contact.connect(func(speed):
			var unseen: bool = not metrics[index].contacted
			ground_contact(index, "ground")
			if unseen:
				metrics[index].first_contact_speed = speed)
		var material := Geo.material(Color("54baff"))
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var trace := MeshInstance3D.new()
		trace.material_override = material
		trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(trace)
		tracks.append(trace)
	build_ui()
	launch_compare()

func build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("16332c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -25, 0)
	add_child(light)
	var ground := StaticBody3D.new()
	ground.set_meta("kind", "ground")
	add_child(ground)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(160, 0.2, 180)
	collision.shape = shape
	collision.position = Vector3(0, -0.1, -25)
	ground.add_child(collision)
	Geo.box(ground, shape.size, Geo.material(Color("2d6540")), collision.position)
	for z in range(-100, 41, 5):
		Geo.box(self, Vector3(50, 0.005, 0.025), Geo.material(Color("94bc95")), Vector3(0, 0.004, z))
		var caption := Label3D.new()
		caption.text = "%d m" % (25 - z)
		caption.position = Vector3(9, 0.05, z)
		caption.rotation_degrees.x = -90
		caption.pixel_size = 0.012
		add_child(caption)
	var post_material := Geo.material(Color.WHITE)
	for x in [-3.66, 3.66]:
		var post := StaticBody3D.new()
		post.set_meta("kind", "post")
		post.collision_layer = 8
		add_child(post)
		var post_shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.06
		cylinder.height = 2.44
		post_shape.shape = cylinder
		post_shape.position = Vector3(x, 1.22, 0)
		post.add_child(post_shape)
		Geo.between(Geo.rod(post, 0.06, post_material), Vector3(x, 0, 0), Vector3(x, 2.44, 0))
	var crossbar := StaticBody3D.new()
	crossbar.set_meta("kind", "post")
	crossbar.collision_layer = 8
	add_child(crossbar)
	var cross_shape := CollisionShape3D.new()
	var cross_cylinder := CylinderShape3D.new()
	cross_cylinder.radius = 0.06
	cross_cylinder.height = 7.32
	cross_shape.shape = cross_cylinder
	cross_shape.rotation.z = PI / 2
	cross_shape.position = Vector3(0, 2.44, 0)
	crossbar.add_child(cross_shape)
	Geo.between(Geo.rod(crossbar, 0.06, post_material), Vector3(-3.66, 2.44, 0), Vector3(3.66, 2.44, 0))
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(35, 27, 39)
	camera.look_at(Vector3(0, 0, 5))
	camera.fov = 58
	camera.current = true

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	canvas.add_child(panel)
	panel.position = Vector2(14, 14)
	panel.custom_minimum_size = Vector2(340, 0)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 700)
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var title := Label.new()
	title.text = "BALL PHYSICS LABORATORY"
	column.add_child(title)
	var preset := OptionButton.new()
	preset.add_item("Test şutu seç…")
	for caption in Presets.PRESETS: preset.add_item(caption)
	column.add_child(preset)
	preset.item_selected.connect(func(index):
		if index > 0: select_preset(preset.get_item_text(index)))
	for item in [["Yaw (°)", "yaw_degrees", -80, 80, 0.1], ["Yükseliş (°)", "elevation_degrees", -45, 80, 0.1], ["Hız (m/s)", "launch_speed", 0, 45, 0.1], ["Spin (rad/s)", "spin_speed", 0, 120, 0.1], ["Hava direnci ×", "air_drag", 0, 2, 0.01], ["Falso ×", "magnus_scale", 0, 1.5, 0.01], ["Sekme e", "ground_bounce", 0, 1, 0.01], ["Kayma μ", "ground_friction", 0, 1, 0.01]]:
		add_number(column, item[0], item[1], item[2], item[3], item[4])
	for item in [["Başlangıç (m)", "start_position"], ["Spin ekseni", "spin_axis"]]:
		add_vector(column, item[0], item[1])
	knuckle_toggle = CheckButton.new()
	knuckle_toggle.text = "Ölü yaprak şutu"
	column.add_child(knuckle_toggle)
	knuckle_toggle.toggled.connect(func(value): knuckle_requested = value)
	goal_toggle = CheckButton.new()
	goal_toggle.text = "Direk çarpışmalarını dahil et"
	column.add_child(goal_toggle)
	goal_toggle.toggled.connect(func(value): include_goal_collisions = value)
	var button := Button.new()
	button.text = "AYNI ŞUTU TEKRARLA  [R]"
	button.pressed.connect(launch_compare)
	column.add_child(button)
	var save_button := Button.new()
	save_button.text = "ÖLÇÜMLERİ JSON / CSV KAYDET"
	save_button.pressed.connect(export_results)
	column.add_child(save_button)
	for item in [["Top fiziği profilini kaydet", "save"], ["Top fiziği profilini yükle", "load"]]:
		var action := Button.new()
		action.text = item[0]
		column.add_child(action)
		action.pressed.connect(func(): choose_file(item[1]))
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(feedback)
	result_label = RichTextLabel.new()
	canvas.add_child(result_label)
	result_label.position = Vector2(370, 18)
	result_label.size = Vector2(730, 165)
	result_label.bbcode_enabled = true
	result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func add_number(parent: Control, caption: String, key: String, minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.value = get(key)
	input.custom_minimum_size.x = 110
	row.add_child(input)
	inputs[key] = input
	input.value_changed.connect(func(value): set(key, value))

func add_vector(parent: Control, caption: String, key: String) -> void:
	var label := Label.new()
	label.text = caption
	parent.add_child(label)
	var row := HBoxContainer.new()
	parent.add_child(row)
	inputs[key] = []
	for axis in range(3):
		var input := SpinBox.new()
		input.min_value = -100
		input.max_value = 100
		input.step = 0.01
		input.value = get(key)[axis]
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(input)
		inputs[key].append(input)
		input.value_changed.connect(func(value):
			var vector: Vector3 = get(key)
			vector[axis] = value
			set(key, vector))

func initial_velocity() -> Vector3:
	var pitch := deg_to_rad(elevation_degrees)
	return (Vector3.FORWARD * cos(pitch) + Vector3.UP * sin(pitch)).rotated(Vector3.UP, deg_to_rad(yaw_degrees)) * launch_speed

func launch_compare() -> void:
	generation += 1
	var queued := generation
	running = false
	metrics.clear()
	points.clear()
	run_position = start_position
	run_velocity = initial_velocity()
	run_seed = shot_seed
	run_maximum_time = maximum_time
	run_air_drag = air_drag
	var run_spin := spin_axis.normalized() * spin_speed
	var run_knuckle := knuckle_requested
	for index in range(balls.size()):
		var p: Resource = arcade_profile.duplicate(true)
		p.drag = air_drag
		p.curl = magnus_scale
		p.bounce = ground_bounce
		p.friction = ground_friction
		balls[index].physics_profile = p
		balls[index].collision_mask = 1 | (8 if include_goal_collisions else 0)
		balls[index].configure_physics()
		balls[index].reset_at(run_position)
		balls[index].visible = true
		tracks[index].visible = balls[index].visible
		tracks[index].mesh = null
		points.append(PackedVector3Array([run_position]))
		metrics.append({"profile": p.profile_name, "max_height": start_position.y, "flight_time": -1.0, "lateral_deviation": 0.0, "horizontal_distance": 0.0, "path_length": 0.0, "first_contact_speed": -1.0, "initial_spin": spin_speed, "final_spin": spin_speed, "bounce_height": 0.0, "stopping_distance": -1.0, "stopped": false, "timed_out": false, "contacted": false, "settled_time": 0.0, "previous": start_position})
	await get_tree().physics_frame
	await get_tree().physics_frame
	if queued != generation:
		return
	for ball in balls:
		if ball.visible:
			ball.strike(Vector3.ZERO, run_velocity * ball.mass, run_spin, 1 if run_knuckle else 0, run_seed)
	elapsed = 0
	sample_clock = 0
	running = true

func ground_contact(index: int, kind: String) -> void:
	if not running or kind != "ground" or metrics[index].contacted:
		return
	metrics[index].contacted = true
	metrics[index].flight_time = elapsed
	metrics[index].first_contact_position = balls[index].position
	metrics[index].first_contact_speed = balls[index].last_air_velocity.length()

func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	sample_clock += delta
	var finished := true
	for index in range(balls.size()):
		var ball = balls[index]
		if not ball.visible:
			continue
		var m: Dictionary = metrics[index]
		var position: Vector3 = ball.position
		m.max_height = maxf(m.max_height, position.y)
		var launch_axis := Vector3(run_velocity.x, 0, run_velocity.z).normalized()
		m.lateral_deviation = (position - run_position).dot(launch_axis.cross(Vector3.UP))
		m.horizontal_distance = Vector2(position.x - run_position.x, position.z - run_position.z).length()
		m.path_length += position.distance_to(m.previous)
		m.previous = position
		m.final_spin = ball.angular_velocity.length()
		if m.contacted:
			m.bounce_height = maxf(m.bounce_height, position.y - ball.radius_value())
		if ball.linear_velocity.length() < 0.08 and ball.angular_velocity.length() * ball.radius_value() < 0.08 and m.contacted:
			m.settled_time += delta
		else:
			m.settled_time = 0.0
		if m.settled_time > 0.3:
			m.stopped = true
			m.stopping_distance = m.horizontal_distance
		if not m.stopped:
			finished = false
		if sample_clock >= 0.05:
			points[index].append(position)
	if sample_clock >= 0.05:
		sample_clock = 0
		redraw_tracks()
		refresh_results()
	if elapsed >= run_maximum_time or finished:
		running = false
		for m in metrics:
			m.timed_out = not m.stopped
		refresh_results()
		if run_air_drag == 0 and metrics[0].contacted:
			var radius: float = balls[0].radius_value()
			var gravity: float = balls[0].physics_profile.gravity
			var ideal_time := (run_velocity.y + sqrt(run_velocity.y * run_velocity.y + 2 * gravity * maxf(0, run_position.y - radius))) / gravity
			feedback.text = "Vakum uçuş süresi: ölçüm %.4f s / analitik %.4f s; hata %.4f s.\nSekme: ilk temastan sonraki en yüksek yükseklik." % [metrics[0].flight_time, ideal_time, absf(metrics[0].flight_time - ideal_time)]

func redraw_tracks() -> void:
	for index in range(tracks.size()):
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points[index]
		if points[index].size() > 1:
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
			tracks[index].mesh = mesh

func refresh_results() -> void:
	if result_label == null:
		return
	var text := ""
	for index in range(metrics.size()):
		if not balls[index].visible:
			continue
		var m: Dictionary = metrics[index]
		text += "[color=%s]%s[/color]  t=%.2f s\n" % ["#54baff", m.profile, elapsed]
		text += "Hmax %.2f m · Uçuş %.2f s · Sapma %.2f m · Menzil %.2f m\n" % [m.max_height, m.flight_time, m.lateral_deviation, m.horizontal_distance]
		text += "İlk temas %.2f m/s · Spin %.2f → %.2f rad/s · Sekme %.2f m · Durma %s\n" % [m.first_contact_speed, m.initial_spin, m.final_spin, m.bounce_height, "%.2f m" % m.stopping_distance if m.stopped else "henüz durmadı"]
	result_label.text = text

func export_results() -> void:
	DirAccess.make_dir_recursive_absolute("user://physics-lab")
	var rows := []
	for m in metrics:
		var copy: Dictionary = m.duplicate()
		copy.erase("previous")
		if copy.has("first_contact_position"):
			var contact: Vector3 = copy.first_contact_position
			copy.first_contact_position = [contact.x, contact.y, contact.z]
		rows.append(copy)
	var json := FileAccess.open("user://physics-lab/latest.json", FileAccess.WRITE)
	json.store_string(JSON.stringify({"seed": run_seed, "start_position_m": [run_position.x, run_position.y, run_position.z], "initial_velocity_m_s": [run_velocity.x, run_velocity.y, run_velocity.z], "dt": 1.0 / Engine.physics_ticks_per_second, "elapsed": elapsed, "metrics": rows}, "\t"))
	var csv := FileAccess.open("user://physics-lab/latest.csv", FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["profile", "max_height_m", "flight_time_s", "deviation_m", "range_m", "contact_m_s", "spin_rad_s", "bounce_m", "stop_m", "timed_out"]))
	for m in metrics:
		csv.store_csv_line(PackedStringArray([m.profile, str(m.max_height), str(m.flight_time), str(m.lateral_deviation), str(m.horizontal_distance), str(m.first_contact_speed), str(m.final_spin), str(m.bounce_height), str(m.stopping_distance), str(m.timed_out)]))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		launch_compare()

func select_preset(caption: String) -> void:
	var data := Presets.values(caption)
	for key in data: set(key, data[key])
	if caption == "Saf yuvarlanma": spin_speed = launch_speed / arcade_profile.radius
	if caption in ["Saf yuvarlanma", "Yerden şut / kayma"]:
		start_position.y = arcade_profile.radius + 0.0005
	for key in inputs:
		if inputs[key] is Array:
			for axis in range(3): inputs[key][axis].set_value_no_signal(get(key)[axis])
		else: inputs[key].set_value_no_signal(get(key))
	knuckle_toggle.set_pressed_no_signal(knuckle_requested)
	goal_toggle.set_pressed_no_signal(include_goal_collisions)
	launch_compare()

func choose_file(action: String) -> void:
	var picker := FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE if action == "save" else FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.tres ; Top fiziği profili"])
	picker.current_dir = ProjectSettings.globalize_path("user://")
	add_child(picker)
	picker.file_selected.connect(func(path):
		match action:
			"save": save_profile(path)
			"load": load_profile(path)
		picker.queue_free())
	picker.canceled.connect(picker.queue_free)
	picker.popup_centered_ratio(0.7)

func save_profile(path: String) -> bool:
	var saved := ResourceSaver.save(arcade_profile, path) == OK
	feedback.text = "Top fiziği profili kaydedildi." if saved else "Profil kaydedilemedi."
	return saved

func load_profile(path: String) -> bool:
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null or resource.get_script() != preload("res://scripts/ball_physics_profile.gd") or not resource.validate().is_empty():
		feedback.text = "Geçerli Top fiziği profili gerekli."
		return false
	arcade_profile = resource.duplicate(true)
	feedback.text = "Top fiziği profili yüklendi; R ile dene."
	return true
