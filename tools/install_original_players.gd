extends SceneTree

# Explicit migration: replace only the visual rig, preserve editable IK anchors.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var roles := {"kicker": "cobalt_striker", "keeper": "amber_keeper", "wall_player": "graphite_defender"}
	for kind in roles:
		var path := "res://scenes/characters/%s.tscn" % kind
		var actor = load(path).instantiate()
		root.add_child(actor)
		actor.build(Color.WHITE)
		actor.pose_idle()
		var previous: Node = actor.get_node_or_null("VisualRig")
		if previous:
			actor.remove_child(previous)
			previous.free()
		actor.visual_skeleton = null
		actor.rig_rest_parts.clear()
		for key in actor.body_parts():
			actor.rig_rest_parts[key] = actor.body_parts()[key].transform
		for child in actor.get_children():
			if child is MeshInstance3D:
				child.visible = false
		var visual = load("res://assets/models/%s.glb" % roles[kind]).instantiate()
		visual.name = "VisualRig"
		actor.add_child(visual)
		visual.owner = actor
		actor.initialize_rig()
		assert(actor.rig_bones.size() == 15, "All IK anchors map to authored rig bones")
		var packed := PackedScene.new()
		assert(packed.pack(actor) == OK)
		assert(ResourceSaver.save(packed, path) == OK)
		print("INSTALLED ", kind, " bones=", actor.rig_bones.size())
		actor.queue_free()
		await process_frame
	quit()
