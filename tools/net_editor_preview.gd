extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var net := preload("res://scripts/goal_net.gd").new()
	root.add_child(net)
	var points := PackedVector3Array()
	for patch in net.cloth.patches.values():
		for row in range(patch.rows + 1):
			for column in range(patch.columns + 1):
				var index: int = row * (patch.columns + 1) + column
				for neighbor in [index + 1 if column < patch.columns else -1, index + patch.columns + 1 if row < patch.rows else -1]:
					if neighbor >= 0:
						points.append(net.cloth.positions[patch.indices[index]])
						points.append(net.cloth.positions[patch.indices[neighbor]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	assert(ResourceSaver.save(mesh, "res://scenes/world/net_preview.res", ResourceSaver.FLAG_COMPRESS) == OK)
	net.queue_free()
	await process_frame
	quit()
