@tool
extends EditorInspectorPlugin
const Catalog = preload("res://scripts/dev/parameter_catalog.gd")

func _can_handle(object: Object) -> bool:
	return object.get_script() != null and object.get_script().resource_path in ["res://scripts/ball_physics_profile.gd", "res://scripts/quality_profile.gd", "res://scripts/tutorial_settings.gd"]

func _parse_begin(object: Object) -> void:
	var info := Label.new()
	info.text = "FREEKICK · Birimler / kaynak / sınırlar\nRuntime kopyası authoring dosyasını değiştirmez."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_custom_control(info)

func _parse_property(object: Object, _type: Variant.Type, name: String, _hint: PropertyHint, _hint_string: String, _usage: int, _wide: bool) -> bool:
	for property in Catalog.properties(object):
		if property.name == name:
			var editor := preload("res://addons/freekick_tools/inspector_property.gd").new(property, object.get(name))
			add_property_editor(name, editor, false, property.title + (" · " + property.unit if not String(property.unit).is_empty() else ""))
			return true
	return false
