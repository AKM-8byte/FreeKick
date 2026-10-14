extends Control

@export var scene_bindings: Dictionary = {}
@export_file("*.tscn") var training_scene := "res://scenes/detailed_training.tscn"
var play_button: Button
var exit_button: Button
var fullscreen_button: Button
var language_select: OptionButton
var column: VBoxContainer
var language := "auto"
var tutorial_button: Button

func _ready() -> void:
	language = get_node("/root/Locale").language_mode
	if scene_bindings.is_empty():
		build()
	else:
		preload("res://scripts/scene_bindings.gd").restore(self, scene_bindings)
		language_select.select(["auto", "tr", "en"].find(language))
		language_select.item_selected.connect(change_language)
		play_button.pressed.connect(play)
		exit_button.pressed.connect(func(): get_tree().quit())
		fullscreen_button.pressed.connect(fullscreen)
	for item in find_children("*", "Control", true, false):
		if (item is Label or item is Button) and not item is OptionButton:
			item.set_meta("source_text", item.text)
			item.text = tr(item.text)
	language_select.set_item_text(0, tr("Bilgisayar dili"))
	fullscreen_button.visible = OS.has_feature("web")
	exit_button.visible = not OS.has_feature("web")
	if tutorial_button == null:
		tutorial_button = button(tr("TANITIMI YENİDEN OYNA"), func(): get_node("/root/Flow").request_scene(training_scene, true))
		column.move_child(tutorial_button, 1)
		tutorial_button.set_meta("source_text", "TANITIMI YENİDEN OYNA")

func play() -> void:
	get_node("/root/Locale").tutorial_pending = false
	get_node("/root/Flow").request_scene(training_scene)

func fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func change_language(index: int) -> void:
	language = ["auto", "tr", "en"][index]
	get_node("/root/Locale").set_language(language)
	# Saved scenes retain their layout when language changes.
	if scene_bindings.is_empty():
		build()
	else:
		for item in find_children("*", "Control", true, false):
			if item.has_meta("source_text"):
				item.text = tr(item.get_meta("source_text"))
		language_select.set_item_text(0, tr("Bilgisayar dili"))

func build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color("122b28")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = 380
	column.add_theme_constant_override("separation", 20)
	centre.add_child(column)
	var title := Label.new()
	title.text = tr("SERBEST VURUŞ")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)
	play_button = button(tr("OYNA"), play)
	tutorial_button = button(tr("TANITIMI YENİDEN OYNA"), func(): get_node("/root/Flow").request_scene(training_scene, true))
	var caption := Label.new()
	caption.text = tr("DİL")
	column.add_child(caption)
	language_select = OptionButton.new()
	var languages := language_select
	languages.add_item(tr("Bilgisayar dili"))
	languages.add_item("Türkçe")
	languages.add_item("English")
	languages.select(["auto", "tr", "en"].find(language))
	column.add_child(languages)
	languages.item_selected.connect(change_language)
	fullscreen_button = button(tr("TAM EKRAN"), fullscreen)
	exit_button = button(tr("ÇIKIŞ"), func(): get_tree().quit())
	fullscreen_button.visible = OS.has_feature("web")
	exit_button.visible = not OS.has_feature("web")

func button(text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 54
	column.add_child(item)
	item.pressed.connect(action)
	return item

