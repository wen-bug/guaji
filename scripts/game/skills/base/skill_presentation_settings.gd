class_name SkillPresentationSettings
extends Node

signal mode_changed(mode: StringName)

const MODE_MATERIAL := &"material"
const MODE_HITBOX := &"hitbox"
const VALID_MODES: Array[StringName] = [MODE_MATERIAL, MODE_HITBOX]

var _mode := MODE_MATERIAL


func set_mode(mode: StringName) -> void:
	var normalized := mode if VALID_MODES.has(mode) else MODE_MATERIAL
	if _mode == normalized:
		return
	_mode = normalized
	mode_changed.emit(_mode)


func get_mode() -> StringName:
	return _mode


func is_hitbox_mode() -> bool:
	return _mode == MODE_HITBOX
