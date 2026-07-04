class_name SaveManager
extends RefCounted

const SAVE_VERSION := 2
const DEFAULT_SAVE_PATH := "user://save.cfg"

var save_path: String = DEFAULT_SAVE_PATH


func _init(path: String = DEFAULT_SAVE_PATH) -> void:
	save_path = path


func load_data() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}

	var config: ConfigFile = ConfigFile.new()
	if config.load(save_path) != OK:
		return {}

	return {
		"version": int(config.get_value("meta", "version", 0)),
		"game_state": _duplicate_dictionary(config.get_value("game", "state", {})),
		"hud": _duplicate_dictionary(config.get_value("hud", "data", {})),
		"config": _duplicate_dictionary(config.get_value("config", "data", {})),
	}


func save_data(data: Dictionary) -> bool:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("game", "state", _duplicate_dictionary(data.get("game_state", {})))
	config.set_value("hud", "data", _duplicate_dictionary(data.get("hud", {})))
	config.set_value("config", "data", _duplicate_dictionary(data.get("config", {})))
	return config.save(save_path) == OK


func _duplicate_dictionary(value) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}
