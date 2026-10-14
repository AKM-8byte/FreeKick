extends RefCounted

# Verlet particles with structural, shear and bending distance constraints.
# Every rope vertex follows these simulated particles; no canned impact wave.
var damping_rate := 2.6
var solver_iterations := 4

var positions := PackedVector3Array()
var previous := PackedVector3Array()
var rest := PackedVector3Array()
var initial := PackedVector3Array()
var movable := PackedFloat32Array()
var links_a := PackedInt32Array()
var links_b := PackedInt32Array()
var lengths := PackedFloat32Array()
var stiffness := PackedFloat32Array()
var patches: Dictionary = {}
var shared_nodes: Dictionary = {}
var contacts: Dictionary = {}
# Cached topology factors: pinned links need no solver work.
var active_links := PackedInt32Array()
var correction_a := PackedFloat32Array()
var correction_b := PackedFloat32Array()
var deformation_extent := Vector3.ZERO

func add_patch(id: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3, columns: int, rows: int, normal: Vector3, sag: float) -> void:
	var grid := PackedInt32Array()
	for row in range(rows + 1):
		for column in range(columns + 1):
			var u := float(column) / columns
			var v := float(row) / rows
			var point := a.lerp(b, u).lerp(c.lerp(d, u), v) + normal * sag * sin(u * PI) * sin(v * PI)
			var key := Vector3i(roundi(point.x * 10000), roundi(point.y * 10000), roundi(point.z * 10000))
			# Stitch meeting panels; frame, ground hem and upper rear rail are
			# pinned. Vertical seams move and pull their neighboring panels.
			var anchor := point.y < 0.001 or absf(point.z) < 0.001 or (point.y > 2.439 and absf(point.z + 1.4) < 0.001)
			if not shared_nodes.has(key):
				shared_nodes[key] = positions.size()
				positions.append(point)
				rest.append(point)
				previous.append(point)
				movable.append(0.0 if anchor else 1.0)
			grid.append(shared_nodes[key])
	var bounds := AABB(a, Vector3.ZERO).expand(b).expand(c).expand(d).grow(absf(sag))
	patches[id] = {"indices": grid, "columns": columns, "rows": rows, "normal": normal, "bounds": bounds}
	for row in range(rows + 1):
		for column in range(columns + 1):
			var index := row * (columns + 1) + column
			if column < columns:
				add_link(grid[index], grid[index + 1], 0.78)
			if row < rows:
				add_link(grid[index], grid[index + columns + 1], 0.78)
			if column < columns and row < rows:
				add_link(grid[index], grid[index + columns + 2], 0.32)
				add_link(grid[index + 1], grid[index + columns + 1], 0.32)
			if column + 2 <= columns:
				add_link(grid[index], grid[index + 2], 0.08)
			if row + 2 <= rows:
				add_link(grid[index], grid[index + 2 * (columns + 1)], 0.08)

func add_link(a: int, b: int, strength: float) -> void:
	links_a.append(a)
	links_b.append(b)
	lengths.append(rest[a].distance_to(rest[b]) * 1.018)
	stiffness.append(strength)
	var weight := movable[a] + movable[b]
	correction_a.append(strength * movable[a] / weight if weight > 0 else 0.0)
	correction_b.append(strength * movable[b] / weight if weight > 0 else 0.0)
	if weight > 0: active_links.append(links_a.size() - 1)

func binding(id: int, u: float, v: float) -> Dictionary:
	var patch: Dictionary = patches[id]
	var x: float = clampf(u, 0, 1) * patch.columns
	var y: float = clampf(v, 0, 1) * patch.rows
	var column := mini(floori(x), patch.columns - 1)
	var row := mini(floori(y), patch.rows - 1)
	var fx := x - column
	var fy := y - row
	var index: int = row * (patch.columns + 1) + column
	var grid: PackedInt32Array = patch.indices
	return {"ids": Vector4i(grid[index], grid[index + 1], grid[index + patch.columns + 1], grid[index + patch.columns + 2]), "weights": Vector4((1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy)}

func sample(binding_data: Dictionary, source: PackedVector3Array) -> Vector3:
	var ids: Vector4i = binding_data.ids
	var weights: Vector4 = binding_data.weights
	return source[ids.x] * weights.x + source[ids.y] * weights.y + source[ids.z] * weights.z + source[ids.w] * weights.w

func kick(binding_data: Dictionary, impulse: Vector3, delta: float) -> void:
	var ids: Vector4i = binding_data.ids
	var weights: Vector4 = binding_data.weights
	for corner in range(4):
		var index := ids[corner]
		if movable[index] > 0:
			# About 40 g of cloth per node, with bounded contact transfer.
			previous[index] -= (impulse * weights[corner] / 0.04).limit_length(7.0) * delta

func step(delta: float) -> void:
	var damping := exp(-damping_rate * delta)
	for index in range(positions.size()):
		if movable[index] == 0:
			continue
		var point := positions[index]
		positions[index] += (point - previous[index]) * damping + Vector3.DOWN * 9.8 * delta * delta
		previous[index] = point
	for _iteration in range(solver_iterations):
		for link in active_links:
			var a := links_a[link]
			var b := links_b[link]
			var difference := positions[b] - positions[a]
			var distance := difference.length()
			if distance < 0.00001:
				continue
			var correction := difference * ((distance - lengths[link]) / distance)
			positions[a] += correction * correction_a[link]
			positions[b] -= correction * correction_b[link]
		for index in range(positions.size()):
			positions[index].y = maxf(0.012 if movable[index] > 0 else 0.0, positions[index].y)
		for contact in contacts.values():
			project_contact(contact)
	contacts.clear()
	update_deformation_extent()

func update_deformation_extent() -> void:
	deformation_extent = Vector3.ZERO
	for index in range(positions.size()):
		deformation_extent = deformation_extent.max((positions[index] - rest[index]).abs())

func project_contact(contact: Dictionary) -> void:
	var data: Dictionary = contact.binding
	var normal: Vector3 = contact.normal
	var point := sample(data, positions)
	var correction: float = (contact.center - point).dot(normal) + contact.get("radius", 0.115)
	if correction <= 0:
		return
	var ids: Vector4i = data.ids
	var weights: Vector4 = data.weights
	var weight_sum := 0.0
	for corner in range(4):
		weight_sum += weights[corner] * weights[corner] * movable[ids[corner]]
	if weight_sum < 0.01:
		return
	for corner in range(4):
		var index := ids[corner]
		var offset := normal * minf(correction, 0.18) * weights[corner] * movable[index] / weight_sum
		positions[index] += offset
		# Contact projection must not create extra spring energy from a teleport.
		previous[index] += offset * 0.80

func settle() -> void:
	for _iteration in range(48):
		step(1.0 / 120.0)
	initial = positions.duplicate()
	previous = positions.duplicate()

func reset() -> void:
	positions = initial.duplicate()
	previous = initial.duplicate()
	contacts.clear()
	update_deformation_extent()
