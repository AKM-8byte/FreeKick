@tool
extends Resource

@export var enabled := true
@export_range(1, 20, 1) var persistence_version := 1
@export var allow_skip := true
@export_range(0, 2, 1) var goalkeeper_level := 0
@export_range(0.1, 1, 0.01) var minimum_power := 0.25
@export_range(0.02, 0.5, 0.01) var minimum_side_contact := 0.12
@export_range(1, 5, 1) var practice_shots := 1
@export var show_timing_tip := true

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if persistence_version < 1 or goalkeeper_level < 0 or goalkeeper_level > 2:
		errors.append("Tutorial sürümü / kaleci seviyesi geçersiz.")
	if not is_finite(minimum_power) or not is_finite(minimum_side_contact) or minimum_power < 0.1 or minimum_power > 1 or minimum_side_contact < 0.02 or minimum_side_contact > 0.5 or practice_shots < 1 or practice_shots > 5:
		errors.append("Tutorial görev eşikleri geçersiz.")
	return errors
