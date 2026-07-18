class_name ModContentRegistry
extends RefCounted

const KINDS: Array[String] = [
	"item",
	"equipment",
	"skill",
	"basic_attack",
	"recipe",
	"trait",
	"enemy",
	"enemy_rank",
	"drop_table",
	"appearance",
	"dialogue",
]

var _definitions: Dictionary = {}
var _sources: Dictionary = {}
var _frozen := false


func _init() -> void:
	for kind in KINDS:
		_definitions[kind] = {}
		_sources[kind] = {}


func definition(kind: String, content_id: String, fallback: Dictionary = {}) -> Dictionary:
	var values: Dictionary = _definitions.get(kind, {})
	var value = values.get(content_id, fallback)
	return value.duplicate(true) if value is Dictionary else fallback.duplicate(true)


func has(kind: String, content_id: String) -> bool:
	return _definitions.has(kind) and (_definitions[kind] as Dictionary).has(content_id)


func ids(kind: String) -> Array[String]:
	var result: Array[String] = []
	for content_id in (_definitions.get(kind, {}) as Dictionary).keys():
		result.append(str(content_id))
	result.sort()
	return result


func source_of(kind: String, content_id: String) -> String:
	return str((_sources.get(kind, {}) as Dictionary).get(content_id, ""))


func all(kind: String) -> Dictionary:
	return (_definitions.get(kind, {}) as Dictionary).duplicate(true)


func kinds() -> Array[String]:
	return KINDS.duplicate()


func is_frozen() -> bool:
	return _frozen


func _define(kind: String, content_id: String, data: Dictionary, source_mod_id: String) -> bool:
	if _frozen or not KINDS.has(kind) or has(kind, content_id):
		return false
	_definitions[kind][content_id] = data.duplicate(true)
	_sources[kind][content_id] = source_mod_id
	return true


func _replace(kind: String, content_id: String, data: Dictionary, source_mod_id: String) -> bool:
	if _frozen or not KINDS.has(kind) or not has(kind, content_id):
		return false
	_definitions[kind][content_id] = data.duplicate(true)
	_sources[kind][content_id] = source_mod_id
	return true


func _snapshot() -> Dictionary:
	return {
		"definitions": _definitions.duplicate(true),
		"sources": _sources.duplicate(true),
	}


func _restore(snapshot: Dictionary) -> void:
	if _frozen:
		return
	_definitions = snapshot.get("definitions", {}).duplicate(true)
	_sources = snapshot.get("sources", {}).duplicate(true)


func _freeze() -> void:
	_frozen = true


static func merge_patch(target, patch):
	if not (patch is Dictionary):
		return patch.duplicate(true) if patch is Array or patch is Dictionary else patch
	var result: Dictionary = target.duplicate(true) if target is Dictionary else {}
	for key in patch.keys():
		var value = patch[key]
		if value == null:
			result.erase(key)
		elif value is Dictionary:
			result[key] = merge_patch(result.get(key, {}), value)
		else:
			result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result
