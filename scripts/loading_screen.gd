extends CanvasLayer

@export var force_staged_loading := false
@export var auto_start := true
@export_range(0.1, 1.5, 0.05) var opening_fade_seconds := 0.6
var bar: ProgressBar
var status: Label
var detail: Label
var retained: Array[Resource] = []
var trace: Array[Dictionary] = []
var opening_screen := false
var credit_tween: Tween
var credit_label: Label

func _ready() -> void:
	opening_screen = not get_node("/root/Flow").intro_shown
	get_node("/root/Flow").intro_shown = true
	build_ui()
	if auto_start: call_deferred("start_loading")

func build_ui() -> void:
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	root.add_child(background)
	background.color = Color("071b18") if opening_screen else Color("102a25")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	root.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 420
	column.add_theme_constant_override("separation", 18)
	centre.add_child(column)
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/ui/freekick_mark.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size.y = 86
	column.add_child(logo)
	logo.visible = not opening_screen
	if opening_screen:
		var brand := Label.new()
		brand.text = "F R E E K I C K"
		brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		brand.add_theme_font_size_override("font_size", 16)
		brand.modulate = Color("7aceab")
		column.add_child(brand)
	var title := Label.new()
	title.text = "Created by Ahmet Kayra" if opening_screen else "FREEKICK"
	title.add_theme_font_size_override("font_size", 30 if opening_screen else 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	credit_label = title
	if opening_screen and not OS.has_feature("web"):
		title.modulate.a = 0
		credit_tween = create_tween().set_ignore_time_scale(true)
		credit_tween.tween_property(title, "modulate:a", 1.0, opening_fade_seconds).set_trans(Tween.TRANS_SINE)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status)
	bar = ProgressBar.new()
	bar.custom_minimum_size.y = 16
	bar.show_percentage = false
	column.add_child(bar)
	detail = Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)

func show_progress(message: String, fraction: float = -1, information: String = "") -> void:
	status.text = tr(message)
	bar.indeterminate = fraction < 0
	if fraction >= 0: bar.value = fraction * 100
	detail.text = information if not information.is_empty() else ("%d%%" % roundi(fraction * 100) if fraction >= 0 else "")
	trace.append({"stage": message, "fraction": fraction, "time_us": Time.get_ticks_usec()})

func dependency_order(path: String, visited: Dictionary, output: PackedStringArray) -> void:
	if visited.has(path): return
	visited[path] = true
	for dependency in ResourceLoader.get_dependencies(path):
		var child: String = dependency.get_slice("::", 2) if dependency.contains("::") else dependency
		if ResourceLoader.exists(child): dependency_order(child, visited, output)
	output.append(path)

func load_staged(path: String) -> PackedScene:
	var order := PackedStringArray()
	dependency_order(path, {}, order)
	var loaded := 0
	for resource_path in order:
		show_progress("Kaynaklar yükleniyor…", float(loaded) / order.size(), tr("Tamamlanan kaynak: %d / %d") % [loaded, order.size()])
		await get_tree().process_frame
		var resource := ResourceLoader.load(resource_path)
		if resource == null: return null
		retained.append(resource)
		loaded += 1
	show_progress("Kaynaklar hazır", 1.0)
	return retained[-1] as PackedScene

func load_threaded(path: String) -> PackedScene:
	var error := ResourceLoader.load_threaded_request(path, "PackedScene", false)
	if error != OK:
		show_progress("Yükleme başarısız", -1, error_string(error))
		return null
	while true:
		var progress := []
		var state := ResourceLoader.load_threaded_get_status(path, progress)
		show_progress("Kaynaklar yükleniyor…", float(progress[0]) if not progress.is_empty() else -1)
		match state:
			ResourceLoader.THREAD_LOAD_LOADED: return ResourceLoader.load_threaded_get(path) as PackedScene
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: return null
		await get_tree().process_frame
	return null

func start_loading() -> void:
	var flow := get_node("/root/Flow")
	flow.is_loading = true
	var request: Dictionary = flow.consume_request()
	var start := Time.get_ticks_usec()
	show_progress("Hazırlanıyor…")
	await get_tree().process_frame
	await get_tree().process_frame
	var staged := OS.has_feature("web") or force_staged_loading
	var scene: PackedScene = await load_staged(request.path) if staged else await load_threaded(request.path)
	if scene == null:
		show_progress("Yükleme başarısız", -1, request.path)
		flow.is_loading = false
		return
	show_progress("Sahne kuruluyor…")
	await get_tree().process_frame
	await get_tree().process_frame
	var build_start := Time.get_ticks_usec()
	var next := scene.instantiate()
	get_tree().root.add_child(next)
	var build_ms := (Time.get_ticks_usec() - build_start) / 1000.0
	if next.get_script() != null and next.get_script().resource_path == "res://game.gd":
		next.hud.set_locked(true)
		show_progress("Grafikler hazırlanıyor…")
		# Keep the initial rig pose stable while the first visible pipelines warm.
		var actors: Array = [next.player, next.defenders.keeper] + next.defenders.wall_pool
		for actor in actors: actor.set_process(false)
		await get_tree().process_frame
		await get_tree().process_frame
		if OS.has_feature("web"): await get_tree().create_timer(0.25).timeout
		for actor in actors: actor.set_process(true)
		next.hud.set_locked(false)
		if request.tutorial:
			get_node("/root/Locale").tutorial_pending = false
			flow.tutorial_running = true
			var tutorial := preload("res://scripts/interactive_tutorial.gd").new()
			tutorial.game = next
			next.add_child(tutorial)
	if opening_screen and not OS.has_feature("web"):
		var remaining := 1.2 - (Time.get_ticks_usec() - start) / 1000000.0
		if remaining > 0: await get_tree().create_timer(remaining, true, false, true).timeout
	flow.last_loading_report = {"path": request.path, "staged": staged, "build_ms": build_ms, "total_ms": (Time.get_ticks_usec() - start) / 1000.0, "progress": trace}
	flow.is_loading = false
	get_tree().current_scene = next
	retained.clear()
	queue_free()
