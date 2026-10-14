extends RefCounted
static var parts: Dictionary = {}

static func apply(actor: Node3D) -> void:
	if parts.is_empty():
		var source: Node3D = load("res://assets/models/football_parts.glb").instantiate()
		for node in source.find_children("*", "MeshInstance3D", true, false):
			parts[String(node.name)] = node.mesh
		source.free()
	actor.torso.mesh = parts.Torso
	actor.torso.scale = Vector3.ONE
	actor.hips.mesh = parts.Hips
	actor.hips.scale = Vector3.ONE
	actor.head.mesh = parts.Head
	actor.head.scale = Vector3.ONE
	for side in range(2):
		actor.thighs[side].mesh = parts.Thigh
		actor.shins[side].mesh = parts.Shin
		actor.upper_arms[side].mesh = parts.UpperArm
		actor.forearms[side].mesh = parts.Forearm
		actor.boots[side].mesh = parts.Boot
		for child in actor.boots[side].get_children():
			child.queue_free()
		var sole := preload("res://geometry.gd").mesh(actor.boots[side], parts.Sole, preload("res://geometry.gd").material(Color("151c24")))
		sole.name = "Sole"
		var geo = preload("res://geometry.gd")
		for row in range(4):
			geo.box(actor.boots[side], Vector3(0.061, 0.005, 0.008), geo.material(Color("e4e9e4")), Vector3(0, 0.042 + row * 0.006, -0.025 + row * 0.02))
		for x in [-0.037, 0.037]:
			for z in [-0.088, -0.035, 0.077]:
				geo.sphere(actor.boots[side], 0.009, geo.material(Color("343b42")), Vector3(x, -0.049, z)).scale.y = 0.65
