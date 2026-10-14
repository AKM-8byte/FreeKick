@tool
extends EditorDebuggerPlugin
var dock: Control
var revision := 0
var ack_count := 0
var last_ack: Dictionary = {}

func _has_capture(prefix: String) -> bool:
	return prefix == "freekick_tools"

func _capture(message: String, data: Array, _session_id: int) -> bool:
	if message == "freekick_tools:metrics" and not data.is_empty() and is_instance_valid(dock):
		var m: Dictionary = data[0]
		dock.monitor.text = "%s · %d FPS\nCPU %.2f ms · Fizik %.2f ms\n%d draw call · GPU %.1f MiB" % [m.quality, m.fps, m.process_ms, m.physics_ms, m.draw_calls, m.video_mb]
		return true
	if message == "freekick_tools:ack" and not data.is_empty() and is_instance_valid(dock):
		ack_count += 1
		last_ack = data[0]
		dock.set_status(String(data[0].get("message", "Yanıt alındı.")), not data[0].get("ok", false))
		return true
	return false

func send_settings(kind: String, values: Dictionary) -> bool:
	var sent := false
	revision += 1
	for session in get_sessions():
		if session.is_active():
			session.send_message("freekick_tools:apply", [{"target": kind, "values": values, "revision": revision}])
			sent = true
	return sent
