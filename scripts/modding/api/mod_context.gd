class_name ModContext
extends RefCounted

var mod_id: String = ""
var storage
var rng
var _overrides: Dictionary = {}
var _operations: Array[Dictionary] = []
var _actor_states: Dictionary = {}
var _effect_handlers: Dictionary = {}
var _ai_conditions: Dictionary = {}
var _dialogue_conditions: Dictionary = {}
var _errors: Array[String] = []


func _init(value_mod_id: String, override_tokens: Array, value_storage, value_rng) -> void:
	mod_id = value_mod_id
	storage = value_storage
	rng = value_rng
	for token in override_tokens:
		_overrides[str(token)] = true


func define(kind: String, local_id: String, data: Dictionary) -> bool:
	if not _valid_local_id(local_id):
		fail("invalid_local_id", "内容 ID 不合法: %s" % local_id)
		return false
	_operations.append({
		"operation": "add",
		"kind": kind,
		"content_id": "%s:%s" % [mod_id, local_id],
		"data": data.duplicate(true),
	})
	return true


func patch(kind: String, target_id: String, patch_data: Dictionary) -> bool:
	var token := "%s:%s" % [kind, target_id]
	if not _overrides.has(token):
		fail("override_not_authorized", "Manifest 未授权覆盖: %s" % token)
		return false
	_operations.append({
		"operation": "patch",
		"kind": kind,
		"content_id": target_id,
		"patch": patch_data.duplicate(true),
	})
	return true


func register_actor_state(local_id: String, factory: Callable) -> bool:
	return _register_callable(_actor_states, "actor_state", local_id, factory)


func register_effect_handler(local_id: String, callback: Callable) -> bool:
	return _register_callable(_effect_handlers, "effect_handler", local_id, callback)


func register_ai_condition(local_id: String, callback: Callable) -> bool:
	return _register_callable(_ai_conditions, "ai_condition", local_id, callback)


func register_dialogue_condition(local_id: String, callback: Callable) -> bool:
	return _register_callable(_dialogue_conditions, "dialogue_condition", local_id, callback)


func fail(code: String, message: String) -> void:
	_errors.append("%s: %s" % [code, message])


func errors() -> Array[String]:
	return _errors.duplicate()


func _register_callable(target: Dictionary, kind: String, local_id: String, callback: Callable) -> bool:
	if not _valid_local_id(local_id) or not callback.is_valid():
		fail("invalid_%s" % kind, "%s 注册无效: %s" % [kind, local_id])
		return false
	target["%s:%s" % [mod_id, local_id]] = callback
	return true


func _valid_local_id(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]{0,63}$")
	return regex.search(value) != null
