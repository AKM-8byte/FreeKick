@tool
extends EditorPlugin

const Catalog = preload("res://scripts/dev/parameter_catalog.gd")
var dock: Control
var inspector: EditorInspectorPlugin
var debugger: EditorDebuggerPlugin

func _enter_tree() -> void:
	inspector = preload("res://addons/freekick_tools/inspector.gd").new()
	add_inspector_plugin(inspector)
	dock = preload("res://addons/freekick_tools/dock.gd").new()
	dock.name = "FreeKick Lab"
	dock.plugin = self
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	debugger = preload("res://addons/freekick_tools/debugger.gd").new()
	debugger.dock = dock
	add_debugger_plugin(debugger)
	scene_changed.connect(func(_root): if is_instance_valid(dock): dock.select_source())
	if "--freekick-tools-qa" in OS.get_cmdline_user_args() or "--freekick-live-qa" in OS.get_cmdline_user_args(): call_deferred("run_qa")

func _exit_tree() -> void:
	if inspector: remove_inspector_plugin(inspector)
	if debugger: remove_debugger_plugin(debugger)
	if is_instance_valid(dock):
		remove_control_from_docks(dock)
		dock.queue_free()

func change_values(target: Object, values: Dictionary) -> PackedStringArray:
	var errors := Catalog.validate_values(target, values)
	if not errors.is_empty(): return errors
	var undo := get_undo_redo()
	var keys: Array = values.keys()
	keys.sort()
	undo.create_action("FreeKick: " + ", ".join(keys), UndoRedo.MERGE_ENDS, target)
	for key in values:
		undo.add_do_property(target, key, values[key])
		undo.add_undo_property(target, key, target.get(key))
	undo.add_do_method(self, "after_change", target)
	undo.add_undo_method(self, "after_change", target)
	undo.commit_action()
	return errors

func after_change(target: Object) -> void:
	if target is Resource: target.emit_changed()
	else: EditorInterface.mark_scene_as_unsaved()

func run_qa() -> void:
	# A dedicated editor invocation exercises the installed plugin; production
	# opening never runs tests or changes a scene automatically.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	var profile: Resource = load("res://settings/arcade_physics.tres").duplicate(true)
	dock.target = profile
	dock.target_kind = "physics"
	dock.rebuild_fields()
	var count := Catalog.properties(profile).size()
	var errors := change_values(profile, {"mass": 0.44})
	assert(errors.is_empty() and is_equal_approx(profile.mass, 0.44))
	var manager := get_undo_redo()
	var history := manager.get_history_undo_redo(manager.get_object_history_id(profile))
	history.undo()
	assert(is_equal_approx(profile.mass, 0.46))
	history.redo()
	assert(is_equal_approx(profile.mass, 0.44))
	assert(not change_values(profile, {"mass": -1.0}).is_empty() and is_equal_approx(profile.mass, 0.44))
	dock.search.text = "Kütle"
	dock.search.text_changed.emit(dock.search.text)
	assert(dock.fields.get_child_count() == 1)
	dock.search.text = ""
	dock.search.text_changed.emit(dock.search.text)
	dock.save_to("res://test-output/physics/editor-profile.tres")
	var saved: Resource = ResourceLoader.load("res://test-output/physics/editor-profile.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(is_equal_approx(saved.mass, 0.44))
	EditorInterface.edit_resource(profile)
	await get_tree().process_frame
	await get_tree().process_frame
	if dock.get_parent() is TabContainer:
		dock.get_parent().current_tab = dock.get_parent().get_tab_idx_from_control(dock)
	if dock.get_parent().has_method("make_visible"): dock.get_parent().make_visible()
	await get_tree().create_timer(0.5).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png("res://test-output/physics/developer-editor.png")
	print("EDITOR DEVELOPER QA: PASS, parameters=", count)
	if "--freekick-live-qa" in OS.get_cmdline_user_args():
		EditorInterface.play_custom_scene("res://main.tscn")
		var connected := false
		for _attempt in range(60):
			await get_tree().create_timer(0.5).timeout
			for session in debugger.get_sessions():
				connected = connected or session.is_active()
			if connected: break
		await get_tree().create_timer(1.0).timeout
		if DisplayServer.get_name() != "headless":
			EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png("res://test-output/physics/developer-live-session.png")
		if not debugger.send_settings("physics", {"mass": 0.445}):
			push_error("EDITOR LIVE QA: no active debugger session; playing=" + str(EditorInterface.is_playing_scene()) + "; sessions=" + str(debugger.get_sessions().size()))
			get_tree().quit(1)
			return
		await get_tree().create_timer(1.0).timeout
		assert(debugger.ack_count > 0 and debugger.last_ack.ok and is_equal_approx(debugger.last_ack.mass, 0.445))
		var before: int = debugger.ack_count
		assert(debugger.send_settings("quality", Catalog.snapshot(load("res://settings/web_low.tres"))))
		await get_tree().create_timer(1.0).timeout
		assert(debugger.ack_count > before and debugger.last_ack.ok and debugger.last_ack.quality == 0)
		print("EDITOR LIVE QA: PASS, ack=", debugger.last_ack)
		EditorInterface.stop_playing_scene()
		await get_tree().create_timer(1.0).timeout
	get_tree().quit()
