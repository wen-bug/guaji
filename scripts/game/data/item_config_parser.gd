class_name ItemConfigParser
extends RefCounted

const INDEX_PATH := "res://resources/items/index.tres"
const FORMAT_VERSION := 1
const VALID_TYPES := ["skill_book", "equipment", "material", "crop", "pill", "alchemy_recipe", "blueprint"]
const VALID_CONTEXTS := ["none", "home", "combat", "both"]
const VALID_TARGETS := ["none", "member", "home_global", "combat_global"]
const VALID_KINDS := ["restore_resource", "temporary_modifier", "permanent_attribute", "unlock_content", "breakthrough", "building_quality", "farm_seed", "equipment_enhancement_material", "currency"]
const VALID_STATS := ["hp", "mp", "attack", "defense", "max_hp", "max_mp", "root_bone", "element_wood", "element_fire", "element_earth", "element_metal", "element_water", "farm_speed"]
const VALID_OPERATIONS := ["flat", "percent"]
const VALID_DURATION_MODES := ["timed", "permanent"]
const VALID_STACK_MODES := ["replace", "refresh", "extend", "stack"]
const VALID_REFERENCE_KINDS := ["skill", "alchemy_recipe", "equipment_template"]
const ContentIndexResourceScript = preload("res://scripts/game/data/content_index_resource.gd")

static var _loaded := false
static var _definitions: Dictionary = {}
static var _paths: Dictionary = {}
static var _groups: Dictionary = {}
static var _errors: Array[String] = []


static func clear_cache() -> void:
	_loaded = false
	_definitions.clear()
	_paths.clear()
	_groups.clear()
	_errors.clear()


static func definitions() -> Dictionary:
	_ensure_loaded()
	return _definitions.duplicate(true)


static func definition(item_id: String) -> Dictionary:
	_ensure_loaded()
	return (_definitions.get(item_id, {}) as Dictionary).duplicate(true)


static func item_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for item_id in _definitions:
		result.append(str(item_id))
	result.sort()
	return result


static func resource_path(item_id: String) -> String:
	_ensure_loaded()
	return str(_paths.get(item_id, ""))


static func groups() -> Dictionary:
	_ensure_loaded()
	return _groups.duplicate(true)


static func validation_errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


static func normalize_external_definition(item_id: String, data: Dictionary) -> Dictionary:
	var normalized := data.duplicate(true)
	normalized["id"] = item_id
	if not normalized.has("use_context"):
		normalized["use_context"] = str(normalized.get("use_scope", "none"))
	normalized["use_scope"] = normalized["use_context"]
	if not normalized.has("effects") or not (normalized.get("effects") is Array):
		normalized["effects"] = legacy_payload_to_effects(item_id, normalized.get("payload", {}), normalized)
	return normalized


static func legacy_payload_to_effects(item_id: String, payload_value, _item_data: Dictionary = {}) -> Array:
	var payload: Dictionary = payload_value if payload_value is Dictionary else {}
	var result: Array = []
	for resource_id in ["hp", "mp"]:
		if int(payload.get(resource_id, 0)) > 0 or float(payload.get("%s_ratio" % resource_id, 0.0)) > 0.0:
			result.append({"effect_id": "restore_%s" % resource_id, "kind": "restore_resource", "target": "member", "stat": resource_id, "amount": int(payload.get(resource_id, 0)), "ratio": float(payload.get("%s_ratio" % resource_id, 0.0))})
	if payload.has("stat") and payload.has("duration"):
		result.append({"effect_id": "%s_buff" % item_id, "kind": "temporary_modifier", "target": "combat_global", "stat": str(payload.get("stat", "")), "operation": "flat", "value": float(payload.get("amount", 0.0)), "buff_id": "%s_buff" % item_id, "duration_mode": "timed", "duration_seconds": float(payload.get("duration", 0.0)), "stack_mode": "refresh", "max_stacks": 1})
	if bool(payload.get("farm_speed", false)):
		result.append({"effect_id": "farm_speed", "kind": "temporary_modifier", "target": "home_global", "stat": "farm_speed", "operation": "percent", "value": 0.5, "buff_id": "farm_speed", "duration_mode": "timed", "duration_seconds": 300.0, "stack_mode": "refresh", "max_stacks": 1})
	if bool(payload.get("breakthrough", false)):
		result.append({"effect_id": "breakthrough", "kind": "breakthrough", "target": "member"})
	for pair in [["skill_id", "skill"], ["recipe_id", "alchemy_recipe"], ["equipment_template_id", "equipment_template"]]:
		if not str(payload.get(pair[0], "")).is_empty():
			result.append({"effect_id": "unlock_%s" % pair[1], "kind": "unlock_content", "target": "member" if pair[1] == "skill" else "none", "reference_kind": pair[1], "reference_id": str(payload.get(pair[0], ""))})
	var permanent = payload.get("permanent_attribute_enhance", {})
	if permanent is Dictionary:
		for raw_effect in permanent.get("effects", []):
			if raw_effect is Dictionary:
				result.append({"effect_id": "permanent_%s" % str(raw_effect.get("stat", "")), "kind": "permanent_attribute", "target": "member", "stat": str(raw_effect.get("stat", "")), "amount": int(raw_effect.get("amount", 0)), "tier_id": str(permanent.get("tier_id", ""))})
	if payload.has("seed_yield"):
		result.append({"effect_id": "seed", "kind": "farm_seed", "target": "none", "amount": int(payload.get("seed_yield", 0)), "auxiliary_value": float(payload.get("growth_seconds", 0.0))})
	if payload.has("enhance_amount"):
		result.append({"effect_id": "enhance_material", "kind": "equipment_enhancement_material", "target": "none", "stat": str(payload.get("stat", "")), "amount": int(payload.get("enhance_amount", 0)), "group_id": str(payload.get("stone_group", ""))})
	if bool(payload.get("market_currency", false)) or bool(payload.get("recruit_currency", false)):
		result.append({"effect_id": "currency", "kind": "currency", "target": "none", "group_id": "market" if bool(payload.get("market_currency", false)) else "recruit"})
	return result


static func validate_definition(data: Dictionary, source_path: String = "<memory>") -> Array[String]:
	var errors: Array[String] = []
	if str(data.get("id", "")).is_empty(): errors.append("%s: id is required" % source_path)
	if int(data.get("item_no", 0)) <= 0: errors.append("%s: item_no must be positive" % source_path)
	if not VALID_TYPES.has(str(data.get("type", ""))): errors.append("%s: type is invalid" % source_path)
	if str(data.get("name", "")).is_empty(): errors.append("%s: display_name is required" % source_path)
	if not VALID_CONTEXTS.has(str(data.get("use_context", "none"))): errors.append("%s: use_context is invalid" % source_path)
	var effects = data.get("effects", [])
	if not (effects is Array):
		errors.append("%s: effects must be an array" % source_path)
		return errors
	var effect_ids := {}
	for index in range(effects.size()):
		if not (effects[index] is Dictionary):
			errors.append("%s: effects[%d] must be ItemEffectDef" % [source_path, index])
			continue
		var effect: Dictionary = effects[index]
		var prefix := "%s: effects[%d]" % [source_path, index]
		var effect_id := str(effect.get("effect_id", ""))
		if effect_id.is_empty() or effect_ids.has(effect_id): errors.append("%s.effect_id is empty or duplicated" % prefix)
		effect_ids[effect_id] = true
		var kind := str(effect.get("kind", ""))
		if not VALID_KINDS.has(kind): errors.append("%s.kind is invalid" % prefix)
		var target := str(effect.get("target", "none"))
		if not VALID_TARGETS.has(target): errors.append("%s.target is invalid" % prefix)
		if kind in ["restore_resource", "temporary_modifier", "permanent_attribute"] and not VALID_STATS.has(str(effect.get("stat", ""))): errors.append("%s.stat is invalid" % prefix)
		if kind == "restore_resource":
			if target != "member": errors.append("%s.target must be member" % prefix)
			if not ["hp", "mp"].has(str(effect.get("stat", ""))): errors.append("%s.stat must be hp or mp" % prefix)
			if int(effect.get("amount", 0)) <= 0 and float(effect.get("ratio", 0.0)) <= 0.0: errors.append("%s requires a positive amount or ratio" % prefix)
			if float(effect.get("ratio", 0.0)) < 0.0 or float(effect.get("ratio", 0.0)) > 1.0: errors.append("%s.ratio must be between 0 and 1" % prefix)
		if kind == "temporary_modifier":
			if not ["member", "home_global", "combat_global"].has(target): errors.append("%s.target cannot be none" % prefix)
			if not VALID_OPERATIONS.has(str(effect.get("operation", ""))): errors.append("%s.operation is invalid" % prefix)
			if is_zero_approx(float(effect.get("value", 0.0))): errors.append("%s.value must not be zero" % prefix)
			if str(effect.get("buff_id", "")).is_empty(): errors.append("%s.buff_id is required" % prefix)
			var duration_mode := str(effect.get("duration_mode", ""))
			if not VALID_DURATION_MODES.has(duration_mode): errors.append("%s.duration_mode is invalid" % prefix)
			if duration_mode == "timed" and float(effect.get("duration_seconds", 0.0)) <= 0.0: errors.append("%s.duration_seconds must be positive" % prefix)
			if not VALID_STACK_MODES.has(str(effect.get("stack_mode", ""))): errors.append("%s.stack_mode is invalid" % prefix)
			if int(effect.get("max_stacks", 0)) <= 0: errors.append("%s.max_stacks must be positive" % prefix)
		if kind == "permanent_attribute" and target != "member": errors.append("%s.target must be member" % prefix)
		if kind == "unlock_content":
			if not VALID_REFERENCE_KINDS.has(str(effect.get("reference_kind", ""))): errors.append("%s.reference_kind is invalid" % prefix)
			if str(effect.get("reference_id", "")).is_empty(): errors.append("%s.reference_id is required" % prefix)
		if kind == "breakthrough" and target != "member": errors.append("%s.target must be member" % prefix)
		if kind == "building_quality" and (str(effect.get("reference_id", "")).is_empty() or int(effect.get("amount", 0)) <= 0): errors.append("%s requires building reference and positive amount" % prefix)
		if kind == "farm_seed" and (target != "none" or int(effect.get("amount", 0)) <= 0 or float(effect.get("auxiliary_value", 0.0)) <= 0.0): errors.append("%s requires none target, positive yield and growth time" % prefix)
		if kind == "equipment_enhancement_material" and (target != "none" or int(effect.get("amount", 0)) <= 0 or str(effect.get("group_id", "")).is_empty()): errors.append("%s requires none target, group and positive amount" % prefix)
		if kind == "currency" and (target != "none" or str(effect.get("group_id", "")).is_empty()): errors.append("%s requires none target and group" % prefix)
	return errors


static func _ensure_loaded() -> void:
	if _loaded: return
	_loaded = true
	var index = load(INDEX_PATH)
	if index == null or index.get_script() != ContentIndexResourceScript:
		_errors.append("%s: index must use ContentIndexResource" % INDEX_PATH)
		return
	if index.format_version != FORMAT_VERSION:
		_errors.append("%s: format_version must be %d" % [INDEX_PATH, FORMAT_VERSION])
		return
	_groups = index.groups.duplicate(true)
	var seen_numbers := {}
	for raw_id in index.entries:
		var item_id := str(raw_id)
		var path := str(index.entries[raw_id])
		if path.is_empty() or not ResourceLoader.exists(path):
			_errors.append("%s: entries.%s path does not exist: %s" % [INDEX_PATH, item_id, path])
			continue
		var resource := load(path) as ItemDef
		if resource == null:
			_errors.append("%s: resource must be ItemDef" % path)
			continue
		var data := resource.to_item_data()
		data["id"] = resource.id
		if not resource.payload.is_empty():
			_errors.append("%s: payload is legacy-only and must be empty for core resources" % path)
			continue
		var local_errors := validate_definition(data, path)
		if resource.id != item_id: local_errors.append("%s: id does not match index key %s" % [path, item_id])
		var number := int(data.get("item_no", 0))
		if seen_numbers.has(number): local_errors.append("%s: duplicate item_no %d (also %s)" % [path, number, seen_numbers[number]])
		if not local_errors.is_empty():
			_errors.append_array(local_errors)
			continue
		seen_numbers[number] = path
		_definitions[item_id] = data
		_paths[item_id] = path
	var invalid_reference_ids: Array[String] = []
	for item_id in _definitions:
		var item_definition: Dictionary = _definitions[item_id]
		for raw_effect in item_definition.get("effects", []):
			if not (raw_effect is Dictionary) or str(raw_effect.get("kind", "")) != "unlock_content": continue
			var reference_kind := str(raw_effect.get("reference_kind", ""))
			var reference_id := str(raw_effect.get("reference_id", ""))
			if reference_kind == "skill" and not ResourceLoader.exists("res://resources/skills/%s.tres" % reference_id):
				_errors.append("%s: effects reference missing skill %s" % [_paths[item_id], reference_id])
				invalid_reference_ids.append(str(item_id))
			elif reference_kind == "equipment_template" and not ["weapon", "helmet", "armor", "leggings", "gloves", "accessory"].has(reference_id):
				_errors.append("%s: effects reference invalid equipment template %s" % [_paths[item_id], reference_id])
				invalid_reference_ids.append(str(item_id))
	for item_id in invalid_reference_ids:
		_definitions.erase(item_id)
		_paths.erase(item_id)
	for group_id in _groups:
		var seen_group_ids := {}
		var group_values = _groups[group_id]
		if not (group_values is Array):
			_errors.append("%s: groups.%s must be an array" % [INDEX_PATH, group_id])
			continue
		for raw_item_id in group_values:
			var item_id := str(raw_item_id)
			if seen_group_ids.has(item_id): _errors.append("%s: groups.%s contains duplicate id %s" % [INDEX_PATH, group_id, item_id])
			elif not _definitions.has(item_id): _errors.append("%s: groups.%s references unregistered id %s" % [INDEX_PATH, group_id, item_id])
			seen_group_ids[item_id] = true
