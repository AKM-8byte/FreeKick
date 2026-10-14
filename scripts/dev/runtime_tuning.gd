extends Node

const Catalog = preload("res://scripts/dev/parameter_catalog.gd")
const Physics = preload("res://scripts/physics_settings.gd")
const Quality = preload("res://scripts/quality_settings.gd")
var pending: Array[Dictionary] = []
var game: Node3D
var monitor_clock := 0.0

func _ready() -> void:
	game = get_parent()
	if EngineDebugger.is_active() and not EngineDebugger.has_capture("freekick_tools"):
		EngineDebugger.register_message_capture("freekick_tools", capture)
	set_physics_process(EngineDebugger.is_active())

func _exit_tree() -> void:
	if EngineDebugger.is_active() and EngineDebugger.has_capture("freekick_tools"):
		EngineDebugger.unregister_message_capture("freekick_tools")

func capture(message: String, data: Array) -> bool:
	if message != "apply": return false
	if data.size() != 1 or not data[0] is Dictionary:
		ack(false, "Geçersiz ayar paketi.")
		return true
	submit(data[0])
	return true

func targets(kind: String) -> Array:
	match kind:
		"physics": return [Physics.active_profile if Physics.active_profile else load("res://settings/arcade_physics.tres").duplicate(true)]
		"quality": return [Quality.current()]
		"keeper": return [game.defenders]
		"player": return [game.player]
		"keeper_actor": return [game.defenders.keeper]
		"wall_actor": return game.defenders.wall_pool
		"gameplay": return [game]
		"net": return [game.goal_net]
		"tutorial": return [get_node("/root/Flow").tutorial_settings]
	return []

func submit(packet: Dictionary) -> PackedStringArray:
	var kind := String(packet.get("target", ""))
	var values = packet.get("values", {})
	var errors := PackedStringArray()
	var selected := targets(kind)
	if not values is Dictionary or selected.is_empty(): errors.append("Ayar hedefi / değer paketi geçersiz.")
	else:
		for target in selected: errors.append_array(Catalog.validate_values(target, values))
	if not errors.is_empty():
		ack(false, "; ".join(errors))
		return errors
	if game.phase not in [game.Phase.PREPARE, game.Phase.RESULT]:
		# Replace the pending update for the same target, not an unbounded queue.
		for index in range(pending.size() - 1, -1, -1):
			if pending[index].target == kind: pending.remove_at(index)
		pending.append(packet.duplicate(true))
		set_physics_process(true)
		ack(true, "Ayarlar bir sonraki hazırlıkta uygulanacak.")
		return errors
	apply_packet(packet)
	return errors

func apply_packet(packet: Dictionary) -> void:
	var kind := String(packet.target)
	var selected := targets(kind)
	# Validate again after a queue delay; profiles may have changed in the UI.
	for target in selected:
		var errors := Catalog.validate_values(target, packet.values)
		if not errors.is_empty():
			ack(false, "; ".join(errors))
			return
	if kind in ["physics", "quality", "tutorial"]:
		var profile: Resource = selected[0].duplicate(true)
		for key in packet.values: profile.set(key, packet.values[key])
		match kind:
			"physics": Physics.configure(profile)
			"quality": Quality.apply(game, profile)
			"tutorial": get_node("/root/Flow").tutorial_settings = profile
	else:
		for target in selected:
			for key in packet.values: target.set(key, packet.values[key])
		if kind == "net":
			game.goal_net.cloth.damping_rate = game.goal_net.cloth_damping
			game.goal_net.cloth.solver_iterations = game.goal_net.solver_iterations
			game.goal_net.set_visual_quality(Quality.current().net_visual_density, true)
	if kind == "gameplay": game.replay.playback_speed = game.replay_speed
	if kind != "tutorial": game.reset_attempt()
	ack(true, "Ayarlar uygulandı: " + kind)

func _physics_process(_delta: float) -> void:
	if EngineDebugger.is_active():
		monitor_clock += _delta
		if monitor_clock >= 0.5:
			monitor_clock = 0
			EngineDebugger.send_message("freekick_tools:metrics", [{"fps": Engine.get_frames_per_second(), "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576, "quality": Quality.current().profile_name}])
	if pending.is_empty() or game.phase != game.Phase.PREPARE: return
	var updates := pending.duplicate(true)
	pending.clear()
	for packet in updates: apply_packet(packet)
	if not EngineDebugger.is_active(): set_physics_process(false)

func ack(ok: bool, message: String) -> void:
	if EngineDebugger.is_active():
		EngineDebugger.send_message("freekick_tools:ack", [{"ok": ok, "message": message, "mass": Physics.get_value("mass"), "quality": Quality.current().level}])
