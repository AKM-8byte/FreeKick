extends RefCounted

static func defaults() -> Dictionary:
	var map := {}
	for item in [["shoot", KEY_SPACE, JOY_BUTTON_X], ["reset_shot", KEY_R, JOY_BUTTON_Y], ["training", KEY_TAB, JOY_BUTTON_BACK], ["menu", KEY_ESCAPE, JOY_BUTTON_START], ["replay_previous", KEY_LEFT, JOY_BUTTON_DPAD_LEFT], ["replay_next", KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT], ["tutorial_next", KEY_ENTER, JOY_BUTTON_A]]:
		var key := InputEventKey.new()
		key.physical_keycode = item[1]
		var pad := InputEventJoypadButton.new()
		pad.device = -1
		pad.button_index = item[2]
		map[item[0]] = [key, pad]
	for item in [["aim_left", KEY_LEFT, JOY_AXIS_LEFT_X, -1.0], ["aim_right", KEY_RIGHT, JOY_AXIS_LEFT_X, 1.0], ["aim_up", KEY_UP, JOY_AXIS_LEFT_Y, -1.0], ["aim_down", KEY_DOWN, JOY_AXIS_LEFT_Y, 1.0], ["contact_left", KEY_J, JOY_AXIS_RIGHT_X, -1.0], ["contact_right", KEY_L, JOY_AXIS_RIGHT_X, 1.0], ["contact_up", KEY_I, JOY_AXIS_RIGHT_Y, -1.0], ["contact_down", KEY_K, JOY_AXIS_RIGHT_Y, 1.0]]:
		var key := InputEventKey.new()
		key.physical_keycode = item[1]
		var pad := InputEventJoypadMotion.new()
		pad.device = -1
		pad.axis = item[2]
		pad.axis_value = item[3]
		map[item[0]] = [key, pad]
	return map

static func ensure_actions() -> void:
	var map := defaults()
	for action in map:
		if InputMap.has_action(action): continue
		InputMap.add_action(action, 0.2)
		for event in map[action]: InputMap.action_add_event(action, event)

static func hint(action: String) -> String:
	var hints := PackedStringArray()
	for event in InputMap.action_get_events(action):
		if event is InputEventKey: hints.append(OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode))
		elif event is InputEventJoypadButton: hints.append(["A", "B", "X", "Y"][event.button_index] if event.button_index < 4 else "Gamepad %d" % event.button_index)
		elif event is InputEventJoypadMotion: hints.append("Gamepad axis %d" % event.axis)
	return " / ".join(hints)
