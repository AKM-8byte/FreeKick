extends Node

const Bindings = preload("res://scripts/input_bindings.gd")
@export var tutorial_settings: Resource = preload("res://settings/tutorial.tres")
@export_file("*.tscn") var training_scene := "res://scenes/detailed_training.tscn"
var pending_path := ""
var pending_tutorial := false
var intro_shown := false
var is_loading := false
var tutorial_running := false
var last_loading_report: Dictionary = {}

func _ready() -> void:
	Bindings.ensure_actions()
	tutorial_settings = tutorial_settings.duplicate(true)

func tutorial_completed() -> bool:
	var config := ConfigFile.new()
	return config.load("user://preferences.cfg") == OK and config.get_value("tutorial", "version", 0) >= tutorial_settings.persistence_version

func mark_tutorial_completed(skipped: bool) -> Error:
	var config := ConfigFile.new()
	config.load("user://preferences.cfg")
	config.set_value("tutorial", "version", tutorial_settings.persistence_version)
	config.set_value("tutorial", "skipped", skipped)
	return config.save("user://preferences.cfg")

func request_scene(path: String, tutorial: bool = false) -> void:
	if is_loading: return
	pending_path = path
	pending_tutorial = tutorial
	get_tree().change_scene_to_file("res://scenes/loading.tscn")

func consume_request() -> Dictionary:
	var tutorial := pending_tutorial
	var path := pending_path
	if path.is_empty():
		tutorial = tutorial_settings.enabled and not tutorial_completed()
		path = training_scene if tutorial else "res://scenes/main_menu.tscn"
	pending_path = ""
	pending_tutorial = false
	return {"path": path, "tutorial": tutorial}

func finish_tutorial(skipped: bool) -> void:
	if skipped and not tutorial_settings.allow_skip: return
	var error := mark_tutorial_completed(skipped)
	if error != OK: push_warning("Tutorial kaydı yazılamadı: " + error_string(error))
	tutorial_running = false
	request_scene("res://scenes/main_menu.tscn")
