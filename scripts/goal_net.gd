extends Node3D

signal touched
const Geo = preload("res://geometry.gd")
const Cloth = preload("res://scripts/cloth_solver.gd")
const WIDTH := 7.32
const HEIGHT := 2.44
const BACK_BOTTOM := -2.20
const BACK_TOP := -1.40
const RADIUS := 0.11
const CONTACT_COMPLIANCE := 0.025
@export_group("Cloth")
@export_range(0.5, 8.0) var cloth_damping := 2.6
@export_range(2, 8) var solver_iterations := 4
@export_range(0.001, 0.008) var rope_radius := 0.0032
@export var rope_color := Color(0.80, 0.82, 0.76)
var active := false
var clock := 0.0
var contacted := false
var impact_count := 0
var impacts: Array[Vector4] = []
var pushes: Array[Vector4] = []
var ropes: MeshInstance3D
var rope_material: ShaderMaterial
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var weights := PackedColorArray()
var particle_ids := PackedVector2Array()
var particle_ids_extra := PackedVector2Array()
var cloth := Cloth.new()
var displacement_image: Image
var displacement_texture: ImageTexture
var contact_step := 1.0 / 120.0
var visual_dirty := true
var wrap_balls: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
var wrap_normals: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var wrap_times := PackedFloat32Array([0, 0, 0, 0])
var ball: RigidBody3D
var sweep_repairs := 0
var visual_density := 1.0
var wrap_dirty := true
var visual_upload_count := 0
var sweep_triangle_checks := 0

func ball_radius() -> float:
	return float(ball.radius_value()) if is_instance_valid(ball) and ball.has_method("radius_value") else RADIUS

func _ready() -> void:
	reset()
	cloth.damping_rate = cloth_damping
	cloth.solver_iterations = solver_iterations
	cloth.add_patch(0, Vector3(-3.66, 0, BACK_BOTTOM), Vector3(3.66, 0, BACK_BOTTOM), Vector3(-3.66, HEIGHT, BACK_TOP), Vector3(3.66, HEIGHT, BACK_TOP), 20, 8, Vector3(0, -0.8 / HEIGHT, -1).normalized(), 0.025)
	cloth.add_patch(3, Vector3(-3.66, HEIGHT, 0), Vector3(3.66, HEIGHT, 0), Vector3(-3.66, HEIGHT, BACK_TOP), Vector3(3.66, HEIGHT, BACK_TOP), 20, 6, Vector3.UP, -0.06)
	for side in [-1.0, 1.0]:
		cloth.add_patch(1 if side < 0 else 2, Vector3(side * 3.66, 0, 0), Vector3(side * 3.66, 0, BACK_BOTTOM), Vector3(side * 3.66, HEIGHT, 0), Vector3(side * 3.66, HEIGHT, BACK_TOP), 6, 8, Vector3.RIGHT * side, 0.025)
	cloth.settle()
	rope_material = ShaderMaterial.new()
	rope_material.shader = preload("res://scripts/net_rope.gdshader")
	displacement_image = Image.create(512, 1, false, Image.FORMAT_RGBAF)
	displacement_texture = ImageTexture.create_from_image(displacement_image)
	rope_material.set_shader_parameter("particle_displacements", displacement_texture)
	rope_material.set_shader_parameter("rope_color", rope_color)
	ropes = get_node_or_null("Ropes")
	if ropes == null:
		ropes = MeshInstance3D.new()
		add_child(ropes)
		ropes.name = "Ropes"
	ropes.material_override = rope_material
	ropes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ropes.extra_cull_margin = 1.0
	set_visual_quality(preload("res://scripts/quality_settings.gd").current().net_visual_density, true)
	# Safety catchers sit beyond the flexible net, not on the visible rest surface.
	Geo.collider(self, Vector3(8.5, 3.4, 0.05), Vector3(0, 1.7, -3.45), "net")
	for side in [-1.0, 1.0]:
		Geo.collider(self, Vector3(0.05, 3.4, 3.5), Vector3(side * 4.75, 1.7, -1.75), "net")
	Geo.collider(self, Vector3(9.5, 0.05, 3.5), Vector3(0, 3.35, -1.75), "net")
	var trim := Geo.material(Color("deded2"))
	for side in [-1.0, 1.0]:
		Geo.between(Geo.rod(self, 0.018, trim), Vector3(side * 3.66, 0, BACK_BOTTOM), Vector3(side * 3.66, HEIGHT, BACK_TOP))
	Geo.between(Geo.rod(self, 0.006, trim), Vector3(-3.66, 0.012, BACK_BOTTOM), Vector3(3.66, 0.012, BACK_BOTTOM))
	update_visual()

func set_visual_quality(density: float, force: bool = false) -> void:
	if not is_finite(density): return
	density = clampf(density, 0.3, 1.0)
	if not force and is_equal_approx(density, visual_density): return
	visual_density = density
	vertices.clear()
	normals.clear()
	weights.clear()
	particle_ids.clear()
	particle_ids_extra.clear()
	build_surface(Vector3(-3.66, 0, BACK_BOTTOM), Vector3(3.66, 0, BACK_BOTTOM), Vector3(-3.66, HEIGHT, BACK_TOP), Vector3(3.66, HEIGHT, BACK_TOP), maxi(8, roundi(62 * density)), maxi(4, roundi(21 * density)), Vector3(0, -0.8 / HEIGHT, -1).normalized(), 0.025, 0)
	build_surface(Vector3(-3.66, HEIGHT, 0), Vector3(3.66, HEIGHT, 0), Vector3(-3.66, HEIGHT, BACK_TOP), Vector3(3.66, HEIGHT, BACK_TOP), maxi(8, roundi(62 * density)), maxi(3, roundi(12 * density)), Vector3.UP, -0.06, 3)
	for side in [-1.0, 1.0]:
		build_surface(Vector3(side * 3.66, 0, 0), Vector3(side * 3.66, 0, BACK_BOTTOM), Vector3(side * 3.66, HEIGHT, 0), Vector3(side * 3.66, HEIGHT, BACK_TOP), maxi(4, roundi(18 * density)), maxi(4, roundi(21 * density)), Vector3.RIGHT * side, 0.025, 1 if side < 0 else 2)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = weights
	arrays[Mesh.ARRAY_TEX_UV] = particle_ids
	arrays[Mesh.ARRAY_TEX_UV2] = particle_ids_extra
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	ropes.mesh = mesh
	rope_material.set_shader_parameter("rope_color", rope_color)

func build_surface(a: Vector3, b: Vector3, c: Vector3, d: Vector3, columns: int, rows: int, normal: Vector3, sag: float, surface: int) -> void:
	var grid := PackedVector3Array()
	var bindings: Array[Dictionary] = []
	for row in range(rows + 1):
		for column in range(columns + 1):
			var u := float(column) / columns
			var v := float(row) / rows
			var weight := sin(u * PI) * sin(v * PI)
			grid.append(a.lerp(b, u).lerp(c.lerp(d, u), v) + normal * sag * weight)
			bindings.append(cloth.binding(surface, u, v))
	for row in range(rows + 1):
		for column in range(columns + 1):
			var index := row * (columns + 1) + column
			if column < columns:
				add_cord(grid[index], grid[index + 1], bindings[index], bindings[index + 1])
			if row < rows:
				add_cord(grid[index], grid[index + columns + 1], bindings[index], bindings[index + columns + 1])

func add_cord(a: Vector3, b: Vector3, binding_a: Dictionary, binding_b: Dictionary) -> void:
	var axis := (b - a).normalized()
	var right := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var other := axis.cross(right)
	for side in range(4):
		var n0 := right * cos(side * TAU / 4) + other * sin(side * TAU / 4)
		var n1 := right * cos((side + 1) * TAU / 4) + other * sin((side + 1) * TAU / 4)
		var radius := rope_radius
		for vertex in [a + n0 * radius, b + n0 * radius, a + n1 * radius, a + n1 * radius, b + n0 * radius, b + n1 * radius]:
			vertices.append(vertex)
		for n in [n0, n0, n1, n1, n0, n1]:
			normals.append(n)
		for binding_data in [binding_a, binding_b, binding_a, binding_a, binding_b, binding_b]:
			var ids: Vector4i = binding_data.ids
			var blend: Vector4 = binding_data.weights
			weights.append(Color(blend.x, blend.y, blend.z, blend.w))
			particle_ids.append(Vector2(ids.x, ids.y))
			particle_ids_extra.append(Vector2(ids.z, ids.w))

func reset() -> void:
	active = false
	clock = 0
	contacted = false
	impact_count = 0
	sweep_repairs = 0
	impacts = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	pushes = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	if not cloth.initial.is_empty():
		cloth.reset()
	visual_dirty = true
	wrap_balls = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	wrap_times.fill(0)
	wrap_dirty = true
	if rope_material != null:
		update_visual()

func step(delta: float) -> void:
	clock += delta
	contact_step = delta
	for index in range(4):
		if wrap_balls[index].w > 0 and clock - wrap_times[index] > 0.035:
			wrap_balls[index].w = 0
			wrap_dirty = true
	if active:
		cloth.step(delta)
		visual_dirty = true

func update_visual() -> void:
	if rope_material != null and (active or wrap_dirty):
		if is_instance_valid(ball) and not ball.replay_mode:
			for index in range(4):
				wrap_balls[index].x = ball.position.x
				wrap_balls[index].y = ball.position.y
				wrap_balls[index].z = ball.position.z
		rope_material.set_shader_parameter("wrap_balls", wrap_balls)
		rope_material.set_shader_parameter("wrap_normals", wrap_normals)
		wrap_dirty = false
	if displacement_texture != null and visual_dirty:
		var pixels := PackedFloat32Array()
		pixels.resize(512 * 4)
		for index in range(cloth.positions.size()):
			var offset := cloth.positions[index] - cloth.rest[index]
			pixels[index * 4] = offset.x
			pixels[index * 4 + 1] = offset.y
			pixels[index * 4 + 2] = offset.z
		displacement_image.set_data(512, 1, false, Image.FORMAT_RGBAF, pixels.to_byte_array())
		displacement_texture.update(displacement_image)
		visual_dirty = false
		visual_upload_count += 1

func _process(_delta: float) -> void:
	update_visual()

func force_on_ball(position: Vector3, velocity: Vector3) -> Vector3:
	if not active:
		return Vector3.ZERO
	var force := Vector3.ZERO
	var back_z := lerpf(BACK_BOTTOM, BACK_TOP, clampf(position.y / HEIGHT, 0, 1))
	if absf(position.x) < 3.80 and position.y > -0.1 and position.y < HEIGHT + 0.1:
		force += surface_force(position, velocity, Vector3(0, 0, BACK_BOTTOM), Vector3(0, -0.8 / HEIGHT, -1).normalized(), 0)
	if position.z < -0.08 and position.z > back_z - 0.25 and position.y > -0.1 and position.y < HEIGHT + 0.1:
		for side in [-1.0, 1.0]:
			force += surface_force(position, velocity, Vector3(side * 3.66, 0, 0), Vector3.RIGHT * side, 1 if side < 0 else 2)
	if position.z < -0.08 and position.z > BACK_TOP - 0.20 and absf(position.x) < 3.80:
		force += surface_force(position, velocity, Vector3(0, HEIGHT, 0), Vector3.UP, 3)
	return force.limit_length(1200)

func surface_force(position: Vector3, velocity: Vector3, plane: Vector3, normal: Vector3, surface: int) -> Vector3:
	var u := (position.x + 3.66) / WIDTH
	var v := position.y / HEIGHT
	if surface in [1, 2]:
		var depth := lerpf(BACK_BOTTOM, BACK_TOP, clampf(v, 0, 1))
		u = position.z / depth
	elif surface == 3:
		v = position.z / BACK_TOP
	var binding_data := cloth.binding(surface, u, v)
	# Find the contact on the deformed panel, including its tangential sag.
	for _iteration in range(3):
		var current := cloth.sample(binding_data, cloth.positions)
		if surface in [1, 2]:
			u += (position.z - current.z) / lerpf(BACK_BOTTOM, BACK_TOP, clampf(v, 0, 1))
			v += (position.y - current.y) / HEIGHT
		elif surface == 3:
			u += (position.x - current.x) / WIDTH
			v += (position.z - current.z) / BACK_TOP
		else:
			u += (position.x - current.x) / WIDTH
			v += (position.y - current.y) / HEIGHT
		binding_data = cloth.binding(surface, u, v)
	var cloth_position := cloth.sample(binding_data, cloth.positions)
	var rest_position := cloth.sample(binding_data, cloth.rest)
	plane += cloth_position - rest_position
	var penetration := (position - plane).dot(normal) + ball_radius()
	if penetration <= 0 or velocity.dot(normal) < -2.0:
		return Vector3.ZERO
	cloth.contacts[surface] = {"binding": binding_data, "normal": normal, "center": position, "radius": ball_radius() + 0.005}
	wrap_balls[surface] = Vector4(position.x, position.y, position.z, ball_radius() + 0.005)
	wrap_times[surface] = clock
	wrap_normals[surface] = normal
	if pushes[surface].w == 0:
		impacts[surface] = Vector4(position.x, position.y, position.z, clock)
		var amplitude := clampf(velocity.length() * 0.018, 0.10, 0.45)
		pushes[surface] = Vector4(normal.x, normal.y, normal.z, amplitude)
		impact_count += 1
		if not contacted:
			contacted = true
			touched.emit()
	var cloth_velocity := (cloth_position - cloth.sample(binding_data, cloth.previous)) / contact_step
	var outward_speed := (velocity - cloth_velocity).dot(normal)
	var stretch := maxf(0, (cloth_position - rest_position).dot(normal))
	var tension := clampf(penetration * 350 + outward_speed * 7 + stretch * 100, 0, 260)
	var tangent := velocity - normal * outward_speed
	var tangent_force := -tangent * 0.7
	var reaction := -normal * tension + tangent_force
	cloth.kick(binding_data, -reaction * contact_step, contact_step)
	return reaction

static func triangle_contains(point: Vector3, a: Vector3, b: Vector3, c: Vector3, margin: float) -> bool:
	var v0 := b - a
	var v1 := c - a
	var v2 := point - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var denominator := d00 * d11 - d01 * d01
	if denominator < 0.0000001:
		return false
	var u := (d11 * v2.dot(v0) - d01 * v2.dot(v1)) / denominator
	var v := (d00 * v2.dot(v1) - d01 * v2.dot(v0)) / denominator
	var tolerance := margin / maxf(0.1, minf(v0.length(), v1.length()))
	return u >= -tolerance and v >= -tolerance and u + v <= 1 + tolerance

# Conservative broad phase in each patch's original grid. The envelope includes
# ALL current particle displacements, sphere radius and authored sag. Narrow
# phase still uses the actual deformed triangles, including seams and corners.
func sweep_cells(surface: int, from: Vector3, to: Vector3) -> Rect2i:
	var padding := cloth.deformation_extent + Vector3.ONE * (ball_radius() + 0.06)
	var low := from.min(to) - padding
	var high := from.max(to) + padding
	var patch: Dictionary = cloth.patches[surface]
	if not patch.bounds.intersects(AABB(low, high - low)): return Rect2i()
	var u_min := (low.x + WIDTH * 0.5) / WIDTH
	var u_max := (high.x + WIDTH * 0.5) / WIDTH
	var v_min := low.y / HEIGHT
	var v_max := high.y / HEIGHT
	if surface in [1, 2]:
		# Side depth varies with height; interval bounds cover both extrema.
		u_min = minf(low.z / BACK_TOP, high.z / BACK_TOP)
		u_min = minf(u_min, minf(low.z / BACK_BOTTOM, high.z / BACK_BOTTOM))
		u_max = maxf(low.z / BACK_TOP, high.z / BACK_TOP)
		u_max = maxf(u_max, maxf(low.z / BACK_BOTTOM, high.z / BACK_BOTTOM))
	elif surface == 3:
		v_min = high.z / BACK_TOP
		v_max = low.z / BACK_TOP
	var first := Vector2i(clampi(floori(u_min * patch.columns), 0, patch.columns - 1), clampi(floori(v_min * patch.rows), 0, patch.rows - 1))
	var last := Vector2i(clampi(floori(u_max * patch.columns) + 1, 0, patch.columns), clampi(floori(v_max * patch.rows) + 1, 0, patch.rows))
	return Rect2i(first, last - first)

func contain_sweep(from: Vector3, to: Vector3, velocity: Vector3, pass_index: int = 0) -> Dictionary:
	if not active:
		return {"position": to, "velocity": velocity}
	var result := to
	var next_velocity := velocity
	var earliest := 2.0
	var hit: Dictionary = {}
	for surface in [0, 1, 2, 3]:
		var patch: Dictionary = cloth.patches[surface]
		var ids: PackedInt32Array = patch.indices
		var columns: int = patch.columns
		var candidates := sweep_cells(surface, from, to)
		if candidates.size.x <= 0 or candidates.size.y <= 0: continue
		for row in range(candidates.position.y, candidates.end.y):
			for column in range(candidates.position.x, candidates.end.x):
				var index := row * (columns + 1) + column
				var a := cloth.positions[ids[index]]
				var b := cloth.positions[ids[index + 1]]
				var c := cloth.positions[ids[index + columns + 1]]
				var d := cloth.positions[ids[index + columns + 2]]
				for triangle in range(2):
					sweep_triangle_checks += 1
					var p := a if triangle == 0 else b
					var q := b if triangle == 0 else d
					var r := c
					var normal := (q - p).cross(r - p).normalized()
					if normal.dot(patch.normal) < 0:
						normal = -normal
					var start_depth := (from - p).dot(normal) + ball_radius()
					var end_depth := (to - p).dot(normal) + ball_radius()
					# The mesh itself deforms; compliance must remain below the ball radius.
					if end_depth <= CONTACT_COMPLIANCE + 0.001 or end_depth < start_depth - 0.00001:
						continue
					var movement := end_depth - start_depth
					var fraction := clampf((CONTACT_COMPLIANCE - start_depth) / movement, 0, 1) if absf(movement) > 0.00001 else 0.0
					var crossing := from.lerp(to, fraction)
					var projection := crossing - normal * (crossing - p).dot(normal)
					if fraction < earliest and triangle_contains(projection, p, q, r, ball_radius()):
						earliest = fraction
						hit = {"normal": normal, "depth": end_depth, "surface": surface, "point": projection}
	if not hit.is_empty():
		var normal: Vector3 = hit.normal
		result -= normal * maxf(0, hit.depth - CONTACT_COMPLIANCE)
		var outward := maxf(0, next_velocity.dot(normal))
		next_velocity -= normal * outward * 0.38
		sweep_repairs += 1
		# Feed the same contact into the cloth instead of an invisible static wall.
		var surface: int = hit.surface
		var u := (result.x + 3.66) / WIDTH
		var v := result.y / HEIGHT
		if surface in [1, 2]:
			u = result.z / lerpf(BACK_BOTTOM, BACK_TOP, clampf(v, 0, 1))
		elif surface == 3:
			v = result.z / BACK_TOP
		var binding_data := cloth.binding(surface, u, v)
		cloth.contacts[surface] = {"binding": binding_data, "normal": normal, "center": result, "radius": ball_radius() + 0.005}
		cloth.kick(binding_data, normal * outward * 0.38 * ball.mass, contact_step)
		wrap_balls[surface] = Vector4(result.x, result.y, result.z, ball_radius() + 0.005)
		wrap_normals[surface] = normal
		wrap_times[surface] = clock
		if not contacted:
			contacted = true
			impacts[surface] = Vector4(result.x, result.y, result.z, clock)
			pushes[surface] = Vector4(normal.x, normal.y, normal.z, 0.3)
			impact_count += 1
			touched.emit()
		# A diagonal shot may cross two stitched panels in the same step.
		if pass_index < 2:
			return contain_sweep(from, result, next_velocity, pass_index + 1)
	return {"position": result, "velocity": next_velocity}
