@tool
extends VBoxContainer

const Catalog = preload("res://scripts/dev/parameter_catalog.gd")
var plugin: EditorPlugin
var target: Object
var target_kind := "physics"
var category: OptionButton
var source: OptionButton
var search: LineEdit
var fields: VBoxContainer
var status: Label
var save_dialog: EditorFileDialog
var load_dialog: EditorFileDialog
var binding_button: Button
var live_button: Button
var default_button: Button
var inspector_button: Button
var monitor: Label

func _ready() -> void:
	custom_minimum_size = Vector2(310, 360)
	name = "FreeKick Lab"
	var header := Label.new()
	header.text = "FREEKICK · GELİŞTİRİCİ"
	add_child(header)
	category = OptionButton.new()
	for caption in ["Top fiziği", "Kaleci / baraj", "Animasyon / IK", "Grafik / file", "Oynanış / kamera", "Tutorial"]:
		category.add_item(caption)
	add_child(category)
	category.item_selected.connect(func(_index): rebuild_sources())
	source = OptionButton.new()
	add_child(source)
	source.item_selected.connect(func(_index): select_source())
	search = LineEdit.new()
	search.placeholder_text = "Ayar ara · isim / açıklama / birim"
	add_child(search)
	search.text_changed.connect(func(_text): rebuild_fields())
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	button(toolbar, "Kaydet…", func(): save_dialog.popup_centered_ratio(0.65))
	button(toolbar, "Yükle…", func(): load_dialog.popup_centered_ratio(0.65))
	default_button = button(toolbar, "Varsayılan", restore_defaults)
	binding_button = button(self, "Bu fizik profilini sahneye bağla", bind_profile)
	live_button = button(self, "Çalışan oyuna gönder", send_live)
	var links := HBoxContainer.new()
	add_child(links)
	button(links, "Laboratuvar", func(): EditorInterface.open_scene_from_path("res://scenes/physics_lab.tscn"))
	button(links, "Oyun sahnesi", func(): EditorInterface.open_scene_from_path("res://main.tscn"))
	inspector_button = button(self, "Tam Inspector'ı aç", func():
		if target is Resource: EditorInterface.edit_resource(target)
		elif target is Node: EditorInterface.edit_node(target))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	monitor = Label.new()
	monitor.text = "Performans: editörden oyunu çalıştır."
	monitor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(monitor)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	fields = VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(fields)
	fields.add_theme_constant_override("separation", 14)
	save_dialog = dialog(EditorFileDialog.FILE_MODE_SAVE_FILE, PackedStringArray(["*.tres ; FreeKick profil"]), save_to)
	load_dialog = dialog(EditorFileDialog.FILE_MODE_OPEN_FILE, PackedStringArray(["*.tres ; FreeKick profil"]), load_from)
	rebuild_sources()

func button(parent: Control, caption: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = caption
	parent.add_child(result)
	result.pressed.connect(action)
	return result

func dialog(mode: EditorFileDialog.FileMode, filters: PackedStringArray, action: Callable) -> EditorFileDialog:
	var result := EditorFileDialog.new()
	result.file_mode = mode
	result.access = EditorFileDialog.ACCESS_RESOURCES
	result.filters = filters
	add_child(result)
	result.file_selected.connect(action)
	return result

func rebuild_sources() -> void:
	if source == null:
		return
	source.clear()
	var choices: Array = []
	match category.selected:
		0: choices = ["Sahne profili", "Varsayılan fizik"]
		1: choices = ["Defenders düğümü"]
		2: choices = ["Şutçu", "Kaleci", "Baraj oyuncusu"]
		3: choices = ["Web Low", "Web Medium", "Web High", "File / cloth"]
		4: choices = ["Freekick düğümü"]
		5: choices = ["Tutorial kaynağı"]
	for caption in choices:
		source.add_item(caption)
	select_source()

func scene_node(path: String) -> Node:
	var root := EditorInterface.get_edited_scene_root()
	return root.get_node_or_null(path) if root else null

func select_source() -> void:
	target = null
	match category.selected:
		0:
			target_kind = "physics"
			var path := "res://settings/ball_physics.tres" if source.selected == 0 else "res://settings/arcade_physics.tres"
			var root := scene_node(".")
			var authored = root.get("physics_profile") if root else null
			target = authored if source.selected == 0 and authored is Resource else ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE).duplicate(true)
		1:
			target_kind = "keeper"
			target = scene_node("Defenders")
		2:
			target_kind = ["player", "keeper_actor", "wall_actor"][source.selected]
			target = scene_node(["Kicker", "Defenders/Keeper", "Defenders/WallPlayer0"][source.selected])
			var root := scene_node(".")
			if target == null and root and root.get_script() != null and root.get_script().resource_path == "res://procedural_player.gd": target = root
		3:
			target_kind = "quality" if source.selected < 3 else "net"
			target = ResourceLoader.load(["res://settings/web_low.tres", "res://settings/web_medium.tres", "res://settings/web_high.tres"][source.selected], "", ResourceLoader.CACHE_MODE_IGNORE).duplicate(true) if source.selected < 3 else scene_node("GoalNet")
		4:
			target_kind = "gameplay"
			target = scene_node(".")
			if target and (target.get_script() == null or target.get_script().resource_path != "res://game.gd"): target = null
		5:
			target_kind = "tutorial"
			target = load("res://settings/tutorial.tres")
	rebuild_fields()

func rebuild_fields() -> void:
	for child in fields.get_children():
		fields.remove_child(child)
		child.queue_free()
	var valid := is_instance_valid(target)
	default_button.disabled = not valid
	inspector_button.disabled = not valid
	live_button.disabled = not valid
	binding_button.visible = valid and target_kind in ["physics", "quality"]
	binding_button.text = "Bu kalite profilini sahneye bağla" if target_kind == "quality" else "Bu fizik profilini sahneye bağla"
	if not valid:
		set_status("Bu kategori için oyun / karakter sahnesini aç.")
		return
	var query := search.text.to_lower()
	var count := 0
	for property in Catalog.properties(target):
		var searchable: String = (String(property.name) + " " + property.title + " " + property.description + " " + property.unit).to_lower()
		if not query.is_empty() and not searchable.contains(query):
			continue
		var widget := preload("res://addons/freekick_tools/parameter_control.gd").new()
		fields.add_child(widget)
		widget.setup(property, target.get(property.name))
		var edited: Object = target
		widget.value_changed.connect(func(value):
			if is_instance_valid(edited):
				var errors: PackedStringArray = plugin.change_values(edited, {property.name: value})
				if not errors.is_empty():
					set_status("; ".join(errors), true)
					widget.call_deferred("set_value", edited.get(property.name)))
		count += 1
	set_status("%d parametre · değişiklikler Ctrl+Z ile geri alınabilir." % count)

func set_status(text: String, error: bool = false) -> void:
	status.text = text
	status.modulate = Color("f5a4a4") if error else Color("a5d8b2")

func restore_defaults() -> void:
	if not is_instance_valid(target): return
	var defaults := {}
	for property in Catalog.properties(target): defaults[property.name] = property.default
	var errors: PackedStringArray = plugin.change_values(target, defaults)
	if not errors.is_empty(): set_status("; ".join(errors), true)
	else: rebuild_fields()

func save_to(path: String) -> void:
	if not is_instance_valid(target): return
	var data: Resource
	if target is Resource:
		data = target.duplicate(true)
	else:
		data = preload("res://scripts/dev/tuning_snapshot.gd").new()
		data.target_script = target.get_script().resource_path
		data.values = Catalog.snapshot(target)
	var error := ResourceSaver.save(data, path)
	set_status("Profil kaydedildi: " + path if error == OK else "Profil kaydedilemedi: " + error_string(error), error != OK)
	if error == OK: EditorInterface.get_resource_filesystem().scan()

func load_from(path: String) -> void:
	if not is_instance_valid(target): return
	var data := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var values := {}
	if data == null:
		set_status("Profil yüklenemedi.", true)
		return
	if data.get_script() == preload("res://scripts/dev/tuning_snapshot.gd"):
		if data.target_script != target.get_script().resource_path:
			set_status("Profil farklı düğüm türüne ait.", true)
			return
		values = data.values
	elif data.get_script() == target.get_script():
		values = Catalog.snapshot(data)
	else:
		set_status("Profil türü seçili kategoriyle uyuşmuyor.", true)
		return
	var errors: PackedStringArray = plugin.change_values(target, values)
	if errors.is_empty(): rebuild_fields(); set_status("Profil yüklendi: " + path)
	else: set_status("; ".join(errors), true)

func bind_profile() -> void:
	var root := scene_node(".")
	if root == null or root.get_script() == null or root.get_script().resource_path != "res://game.gd":
		set_status("Önce main.tscn / detailed_training.tscn aç.", true)
		return
	var undo := plugin.get_undo_redo()
	var key := "quality_profile" if target_kind == "quality" else "physics_profile"
	undo.create_action("FreeKick profilini bağla", UndoRedo.MERGE_DISABLE, root)
	undo.add_do_property(root, key, target)
	undo.add_undo_property(root, key, root.get(key))
	undo.add_do_method(plugin, "after_change", root)
	undo.commit_action()
	set_status("Sahneye bağlandı. Ctrl+S ile sahneyi kaydet.")

func send_live() -> void:
	if is_instance_valid(target):
		var sent: bool = plugin.debugger.send_settings(target_kind, Catalog.snapshot(target))
		set_status("Gönderildi; uçuşta ise hazırlıkta uygulanır." if sent else "Editörden native oyunu F5/F6 ile debug başlat.", not sent)

