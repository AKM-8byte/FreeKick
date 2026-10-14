extends RefCounted

# Store references as paths, so generated geometry can become ordinary scenes.
static func restore(target: Node, bindings: Dictionary) -> void:
	for key in bindings:
		var paths = bindings[key]
		if paths is NodePath:
			target.set(key, target.get_node(paths))
		elif paths is Array:
			var array: Array = target.get(key)
			array.clear()
			for path in paths:
				array.append(target.get_node(path))
		elif paths is Dictionary:
			var dict: Dictionary = target.get(key)
			dict.clear()
			for entry in paths:
				dict[entry] = target.get_node(paths[entry])
