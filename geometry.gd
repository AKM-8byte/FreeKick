extends RefCounted

static func material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result

static func mesh(parent: Node3D, shape: Mesh, mat: Material, location: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat
	parent.add_child(node)
	node.position = location
	return node

static func box(parent: Node3D, size: Vector3, mat: Material, location: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, mat, location)

static func sphere(parent: Node3D, radius: float, mat: Material, location: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 16
	shape.rings = 8
	return mesh(parent, shape, mat, location)

static func rod(parent: Node3D, radius: float, mat: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = 1.0
	shape.radial_segments = 10
	return mesh(parent, shape, mat)

static func between(node: Node3D, start: Vector3, end: Vector3) -> void:
	var axis := end - start
	var length := maxf(axis.length(), 0.001)
	var up := axis / length
	var reference := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var right := up.cross(reference).normalized()
	node.transform = Transform3D(Basis(right, up, right.cross(up)), (start + end) * 0.5)
	node.scale = Vector3(1.0, length, 1.0)

static func collider(parent: Node3D, size: Vector3, location: Vector3, kind: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_meta("kind", kind)
	parent.add_child(body)
	body.position = location
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body
