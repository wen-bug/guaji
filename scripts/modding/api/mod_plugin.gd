class_name ModPlugin
extends RefCounted

var mod_id: String = ""
var storage = null
var rng = null


func _bind_runtime(value_mod_id: String, value_storage, value_rng) -> void:
	mod_id = value_mod_id
	storage = value_storage
	rng = value_rng


func register(_context) -> void:
	pass


func on_game_ready(_api) -> void:
	pass


func migrate_save(data: Dictionary, _from_version: String, _to_version: String) -> Dictionary:
	return data.duplicate(true)
