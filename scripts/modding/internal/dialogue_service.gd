extends RefCounted
class_name ModDialogueService

var registry = null
var condition_resolver: Callable
var _last_used_msec: Dictionary = {}


func setup(value_registry, value_condition_resolver: Callable) -> void:
	registry = value_registry
	condition_resolver = value_condition_resolver


func pick_line(context: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	if registry == null:
		return {}
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for dialogue_id in registry.ids("dialogue"):
		var definition: Dictionary = registry.definition("dialogue", dialogue_id)
		if not _matches(dialogue_id, definition, context):
			continue
		var weight := maxf(0.001, float(definition.get("weight", 1.0)))
		total_weight += weight
		candidates.append({"id": dialogue_id, "definition": definition, "weight": weight})
	if candidates.is_empty():
		return {}
	var roll := random.randf_range(0.0, total_weight)
	var cursor := 0.0
	for candidate in candidates:
		cursor += float(candidate.get("weight", 1.0))
		if roll <= cursor:
			return _select(candidate)
	return _select(candidates.back())


func _select(candidate: Dictionary) -> Dictionary:
	var dialogue_id := str(candidate.get("id", ""))
	_last_used_msec[dialogue_id] = Time.get_ticks_msec()
	var definition: Dictionary = candidate.get("definition", {}).duplicate(true)
	definition["id"] = dialogue_id
	return definition


func _matches(dialogue_id: String, definition: Dictionary, context: Dictionary) -> bool:
	if not _matches_array(definition.get("scenes", []), str(context.get("scene", ""))):
		return false
	if not _matches_array(definition.get("states", []), str(context.get("state", ""))):
		return false
	if not _matches_array(definition.get("member_ids", []), str(context.get("member_id", ""))):
		return false
	if not _matches_array(definition.get("visual_ids", []), str(context.get("visual_id", ""))):
		return false
	var level := int(context.get("level", 1))
	if level < int(definition.get("min_level", 1)) or level > int(definition.get("max_level", 2147483647)):
		return false
	var required_traits: Array = definition.get("trait_ids_any", []) if definition.get("trait_ids_any", []) is Array else []
	if not required_traits.is_empty():
		var member_traits: Array = context.get("trait_ids", []) if context.get("trait_ids", []) is Array else []
		var found := false
		for trait_id in required_traits:
			if member_traits.has(trait_id):
				found = true
				break
		if not found:
			return false
	var cooldown_msec := int(maxf(0.0, float(definition.get("cooldown_seconds", 0.0))) * 1000.0)
	if cooldown_msec > 0 and Time.get_ticks_msec() - int(_last_used_msec.get(dialogue_id, -cooldown_msec)) < cooldown_msec:
		return false
	for condition_id in definition.get("custom_conditions", []):
		if not condition_resolver.is_valid():
			return false
		var callback = condition_resolver.call(str(condition_id))
		if not (callback is Callable) or not callback.is_valid() or not bool(callback.call(context.duplicate(true), definition.duplicate(true))):
			return false
	return true


func _matches_array(raw_values, value: String) -> bool:
	if not (raw_values is Array) or raw_values.is_empty():
		return true
	return raw_values.has(value)
