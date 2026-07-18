class_name ModStorage
extends RefCounted

var _data: Dictionary = {}
var _backend = null
var _mod_id: String = ""


func _init(backend = null, mod_id: String = "") -> void:
	_backend = backend
	_mod_id = mod_id


func get_value(key: String, fallback = null):
	if _mod_id.is_empty():
		push_warning("ModStorage.get_value 只能通过绑定到当前 Mod 的 storage 使用")
		return _copy_value(fallback)
	return _root()._get_for(_mod_id, key, fallback)


func set_value(key: String, value) -> void:
	if _mod_id.is_empty():
		push_warning("ModStorage.set_value 只能通过绑定到当前 Mod 的 storage 使用")
		return
	_root()._set_for(_mod_id, key, value)


func erase_value(key: String) -> void:
	if _mod_id.is_empty():
		return
	_root()._erase_for(_mod_id, key)


func all() -> Dictionary:
	return _root().data_for(_mod_id) if not _mod_id.is_empty() else {}


func _view(mod_id: String):
	return get_script().new(_root(), mod_id)


func _root():
	return _backend._root() if _backend != null else self


func _get_for(mod_id: String, key: String, fallback = null):
	var values: Dictionary = _data.get(mod_id, {})
	return _copy_value(values.get(key, fallback))


func _set_for(mod_id: String, key: String, value) -> void:
	if not _data.has(mod_id):
		_data[mod_id] = {}
	_data[mod_id][key] = _copy_value(value)


func _erase_for(mod_id: String, key: String) -> void:
	if _data.has(mod_id):
		(_data[mod_id] as Dictionary).erase(key)


func data_for(mod_id: String) -> Dictionary:
	return (_root()._data.get(mod_id, {}) as Dictionary).duplicate(true)


func replace_data_for(mod_id: String, data: Dictionary) -> void:
	_root()._data[mod_id] = data.duplicate(true)


func import_data(data: Dictionary) -> void:
	_root()._data = data.duplicate(true)


func export_data() -> Dictionary:
	return _root()._data.duplicate(true)


static func _copy_value(value):
	return value.duplicate(true) if value is Dictionary or value is Array else value
