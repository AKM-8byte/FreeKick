@tool
extends VBoxContainer

signal value_changed(value: Variant)
var metadata: Dictionary
var current_value: Variant
var editors: Array[Control] = []
var loading := false
var value_area: VBoxContainer

func setup(property: Dictionary, value: Variant) -> void:
	metadata = property
	current_value = value
	for child in get_children():
		remove_child(child)
		child.queue_free()
	editors.clear()
	var title := Label.new()
	title.text = metadata.title + (" · " + metadata.unit if not String(metadata.unit).is_empty() else "")
	title.visible = not metadata.get("hide_title", false)
	add_child(title)
	var description := Label.new()
	description.text = metadata.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate.a = 0.72
	add_child(description)
	value_area = VBoxContainer.new()
	add_child(value_area)
	loading = true
	match int(metadata.type):
		TYPE_FLOAT, TYPE_INT:
			if metadata.hint == PROPERTY_HINT_ENUM:
				var choice := OptionButton.new()
				for caption in String(metadata.hint_string).split(","):
					choice.add_item(caption.get_slice(":", 0))
				choice.select(int(value))
				value_area.add_child(choice)
				editors.append(choice)
				choice.item_selected.connect(func(index): commit(index))
			else:
				var limits := preload("res://scripts/dev/parameter_catalog.gd").numeric_range(metadata)
				var number := numeric(value_area, value, limits)
				number.value_changed.connect(func(number_value): commit(int(number_value) if metadata.type == TYPE_INT else number_value))
				var slider := HSlider.new()
				slider.min_value = limits.x
				slider.max_value = limits.y
				slider.step = 1 if metadata.type == TYPE_INT else limits.z
				slider.value = value
				value_area.add_child(slider)
				editors.append(slider)
				slider.value_changed.connect(func(number_value):
					number.set_value_no_signal(number_value)
					commit(int(number_value) if metadata.type == TYPE_INT else number_value))
				number.value_changed.connect(func(number_value): slider.set_value_no_signal(number_value))
		TYPE_BOOL:
			var toggle := CheckButton.new()
			toggle.button_pressed = value
			toggle.text = "Etkin"
			value_area.add_child(toggle)
			editors.append(toggle)
			toggle.toggled.connect(commit)
		TYPE_STRING:
			if metadata.name == "provenance":
				var input := TextEdit.new()
				input.text = value
				input.custom_minimum_size.y = 88
				value_area.add_child(input)
				editors.append(input)
				input.text_changed.connect(func(): commit(input.text))
			else:
				var input := LineEdit.new()
				input.text = value
				value_area.add_child(input)
				editors.append(input)
				input.text_submitted.connect(commit)
				input.focus_exited.connect(func(): commit(input.text))
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_PACKED_FLOAT32_ARRAY:
			var count: int = 3 if metadata.type in [TYPE_VECTOR3, TYPE_PACKED_FLOAT32_ARRAY] else 2
			var limits := preload("res://scripts/dev/parameter_catalog.gd").numeric_range(metadata)
			for axis in range(count):
				var row := HBoxContainer.new()
				value_area.add_child(row)
				var caption := Label.new()
				caption.text = ["Kolay", "Dengeli", "Zor"][axis] if metadata.type == TYPE_PACKED_FLOAT32_ARRAY else ["X", "Y", "Z"][axis]
				caption.custom_minimum_size.x = 65
				row.add_child(caption)
				var number := numeric(row, value[axis], limits)
				number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				number.value_changed.connect(func(number_value):
					var copy = current_value.duplicate() if current_value is PackedFloat32Array else current_value
					copy[axis] = number_value
					commit(copy))
		TYPE_PACKED_VECTOR2_ARRAY:
			build_curve()
		TYPE_COLOR:
			var color := ColorPickerButton.new()
			color.color = value
			value_area.add_child(color)
			editors.append(color)
			color.color_changed.connect(commit)
	var footer := HBoxContainer.new()
	add_child(footer)
	var default_label := Label.new()
	var limits := preload("res://scripts/dev/parameter_catalog.gd").numeric_range(metadata)
	default_label.text = "Varsayılan: %s" % str(metadata.default)
	if metadata.type in [TYPE_FLOAT, TYPE_INT] and metadata.hint != PROPERTY_HINT_ENUM:
		default_label.text += " · [%s, %s]" % [str(limits.x), str(limits.y)]
	default_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	default_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	default_label.modulate.a = 0.62
	footer.add_child(default_label)
	var reset := Button.new()
	reset.text = "↶"
	reset.tooltip_text = "Bu parametreyi varsayılana döndür"
	footer.add_child(reset)
	reset.pressed.connect(func(): commit(metadata.default); call_deferred("refresh_value"))
	loading = false

func numeric(parent: Control, value: float, limits: Vector3) -> SpinBox:
	var input := SpinBox.new()
	input.min_value = limits.x
	input.max_value = limits.y
	input.step = 1 if metadata.type == TYPE_INT else limits.z
	input.value = value
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(input)
	editors.append(input)
	return input

func build_curve() -> void:
	for child in value_area.get_children():
		value_area.remove_child(child)
		child.queue_free()
	for index in range(current_value.size()):
		var row := HBoxContainer.new()
		value_area.add_child(row)
		for axis in range(2):
			var limits := Vector3(0, 10000000 if axis == 0 and metadata.name == "drag_curve" else 10, 1000 if axis == 0 and metadata.name == "drag_curve" else 0.001)
			var input := numeric(row, current_value[index][axis], limits)
			input.value_changed.connect(func(value):
				var copy: PackedVector2Array = current_value.duplicate()
				copy[index][axis] = value
				commit(copy))
		var remove := Button.new()
		remove.text = "−"
		remove.disabled = current_value.size() <= 1
		row.add_child(remove)
		remove.pressed.connect(func():
			var copy: PackedVector2Array = current_value.duplicate()
			copy.remove_at(index)
			commit(copy)
			call_deferred("refresh_value"))
	var add := Button.new()
	add.text = "Nokta ekle"
	value_area.add_child(add)
	add.pressed.connect(func():
		var copy: PackedVector2Array = current_value.duplicate()
		var last: Vector2 = copy[-1] if not copy.is_empty() else Vector2.ZERO
		copy.append(Vector2(last.x + maxf(0.05, last.x * 0.1), last.y))
		commit(copy)
		call_deferred("refresh_value"))

func refresh_value() -> void:
	set_value(current_value)

func commit(value: Variant) -> void:
	if loading:
		return
	current_value = value
	value_changed.emit(value)

func set_value(value: Variant) -> void:
	setup(metadata, value)
