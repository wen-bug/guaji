class_name ModRng
extends RefCounted

var _streams: Dictionary = {}
var _backend = null
var _mod_id: String = ""


func _init(backend = null, mod_id: String = "") -> void:
	_backend = backend
	_mod_id = mod_id


func stream(purpose: String) -> RandomNumberGenerator:
	if _mod_id.is_empty():
		push_warning("ModRng.stream 只能通过绑定到当前 Mod 的 rng 使用")
		return RandomNumberGenerator.new()
	return _root()._stream_for(_mod_id, purpose)


func _view(mod_id: String):
	return get_script().new(_root(), mod_id)


func _root():
	return _backend._root() if _backend != null else self


func _stream_for(mod_id: String, purpose: String) -> RandomNumberGenerator:
	var key := "%s:%s" % [mod_id, purpose]
	if _streams.has(key):
		return _streams[key]
	var generator := RandomNumberGenerator.new()
	generator.seed = hash(key)
	_streams[key] = generator
	return generator


func import_state(data: Dictionary) -> void:
	var root = _root()
	root._streams.clear()
	for key in data.keys():
		var state_data = data[key]
		if not (state_data is Dictionary):
			continue
		var generator := RandomNumberGenerator.new()
		generator.seed = int(state_data.get("seed", hash(str(key))))
		generator.state = int(state_data.get("state", generator.state))
		root._streams[str(key)] = generator


func export_state() -> Dictionary:
	var result: Dictionary = {}
	for key in _root()._streams.keys():
		var generator: RandomNumberGenerator = _root()._streams[key]
		result[key] = {"seed": int(generator.seed), "state": int(generator.state)}
	return result
