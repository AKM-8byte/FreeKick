@tool
extends EditorProperty

var widget: VBoxContainer
var metadata: Dictionary

func _init(property: Dictionary = {}, value: Variant = null) -> void:
	metadata = property.duplicate()
	metadata.hide_title = true
	widget = preload("res://addons/freekick_tools/parameter_control.gd").new()
	add_child(widget)
	set_bottom_editor(widget)
	if not metadata.is_empty():
		widget.setup(metadata, value)
	widget.value_changed.connect(func(changed):
		var object := get_edited_object()
		if object == null: return
		var errors := preload("res://scripts/dev/parameter_catalog.gd").validate_values(object, {get_edited_property(): changed})
		if errors.is_empty(): emit_changed(get_edited_property(), changed)
		else:
			widget.tooltip_text = "; ".join(errors)
			widget.call_deferred("set_value", object.get(get_edited_property())))

func _update_property() -> void:
	if get_edited_object() != null:
		widget.set_value(get_edited_object().get(get_edited_property()))
