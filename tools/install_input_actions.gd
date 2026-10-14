extends SceneTree
func _initialize() -> void:
	var map := preload("res://scripts/input_bindings.gd").defaults()
	for action in map:
		if not ProjectSettings.has_setting("input/" + action) or "--replace-defaults" in OS.get_cmdline_user_args():
			ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": map[action]})
	var result := ProjectSettings.save()
	print("INPUT MAP INSTALL: ", error_string(result))
	quit(0 if result == OK else 1)
