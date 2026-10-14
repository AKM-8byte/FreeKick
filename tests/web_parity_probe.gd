extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.add_child(preload("res://tests/web_parity_scene.gd").new())
