class_name EquipmentConfigParser
extends RefCounted

const INDEX_PATH := "res://resources/equipment/index.tres"
const INDEX_META_KEY := &"equipment_index"
const EQUIPMENT_META_KEY := &"equipment_data"
const FORMAT_VERSION := 1
const TIER_IDS := ["t1", "t2", "t3", "t4", "t5"]
const VALID_SLOTS := ["weapon", "helmet", "armor", "leggings", "gloves", "accessory"]
const VALID_STATS := [
	"attack", "defense", "max_hp", "max_mp", "root_bone",
	"element_wood", "element_fire", "element_earth", "element_metal", "element_water",
]

static var _loaded := false
static var _index_cache: Dictionary = {}
static var _equipment_cache: Dictionary = {}
static var _validation_errors: Array[String] = []


static func clear_cache() -> void:
	_loaded = false
	_index_cache.clear()
	_equipment_cache.clear()
	_validation_errors.clear()


static func index_data() -> Dictionary:
	_ensure_loaded()
	return _index_cache.duplicate(true)


static func validation_errors() -> Array[String]:
	_ensure_loaded()
	return _validation_errors.duplicate()


static func equipment_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for equipment_id in _equipment_cache:
		result.append(str(equipment_id))
	result.sort()
	return result


static func equipment_definition(equipment_id: String) -> Dictionary:
	_ensure_loaded()
	var definition = _equipment_cache.get(equipment_id, {})
	return definition.duplicate(true) if definition is Dictionary else {}


static func template_definitions() -> Dictionary:
	_ensure_loaded()
	var result := {}
	for raw_slot in _index_cache.get("slots", []):
		if not (raw_slot is Dictionary):
			continue
		var slot_id := str(raw_slot.get("id", ""))
		if slot_id.is_empty() or equipment_ids_for_template(slot_id).is_empty():
			continue
		result[slot_id] = {
			"slot": slot_id,
			"name": str(raw_slot.get("name", slot_id)),
		}
	return result


static func legacy_aliases() -> Dictionary:
	_ensure_loaded()
	var aliases = _index_cache.get("aliases", {})
	var result := {}
	if aliases is Dictionary:
		for alias_id in aliases:
			var alias = aliases[alias_id]
			if alias is Dictionary and _equipment_cache.has(str(alias.get("equipment_id", ""))):
				result[str(alias_id)] = alias.duplicate(true)
	return result


static func slot_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for raw_slot in _index_cache.get("slots", []):
		if raw_slot is Dictionary:
			result.append(str(raw_slot.get("id", "")))
	return result


static func equipment_ids_for_template(template_id: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for raw_slot in _index_cache.get("slots", []):
		if raw_slot is Dictionary and str(raw_slot.get("id", "")) == template_id:
			for value in raw_slot.get("equipment_ids", []):
				var equipment_id := str(value)
				if _equipment_cache.has(equipment_id):
					result.append(equipment_id)
			break
	return result


static func resolve_equipment_id(template_id: String, variant_id: String = "") -> String:
	_ensure_loaded()
	if not variant_id.is_empty() and _equipment_cache.has(variant_id):
		return variant_id
	var aliases = _index_cache.get("aliases", {})
	if aliases is Dictionary and aliases.has(template_id):
		var alias = aliases[template_id]
		if alias is Dictionary:
			var alias_equipment_id := str(alias.get("equipment_id", alias.get("variant_id", "")))
			return alias_equipment_id if _equipment_cache.has(alias_equipment_id) else ""
	if _equipment_cache.has(template_id):
		return template_id
	var candidates := equipment_ids_for_template(template_id)
	return candidates[0] if not candidates.is_empty() else ""


static func resolve_template(template_id: String) -> Dictionary:
	_ensure_loaded()
	var aliases = _index_cache.get("aliases", {})
	if aliases is Dictionary and aliases.has(template_id):
		var alias = aliases[template_id]
		if alias is Dictionary and _equipment_cache.has(str(alias.get("equipment_id", ""))):
			return alias.duplicate(true)
		return {}
	if _equipment_cache.has(template_id):
		var definition: Dictionary = _equipment_cache[template_id]
		return {
			"template_id": str(definition.get("template_id", template_id)),
			"variant_id": str(definition.get("variant_id", "")),
			"equipment_id": template_id,
		}
	if template_definitions().has(template_id):
		return {"template_id": template_id, "variant_id": "", "equipment_id": ""}
	return {}


static func roll_template_id(rng: RandomNumberGenerator) -> String:
	_ensure_loaded()
	var entries: Array = []
	for raw_slot in _index_cache.get("slots", []):
		if raw_slot is Dictionary and not equipment_ids_for_template(str(raw_slot.get("id", ""))).is_empty():
			entries.append({"id": str(raw_slot.get("id", "")), "weight": int(raw_slot.get("weight", 0))})
	return _roll_weighted(entries, rng)


static func roll_equipment_id(template_id: String, rng: RandomNumberGenerator) -> String:
	var entries: Array = []
	for equipment_id in equipment_ids_for_template(template_id):
		var definition: Dictionary = _equipment_cache[equipment_id]
		entries.append({"id": equipment_id, "weight": int(definition.get("selection_weight", 0))})
	return _roll_weighted(entries, rng)


static func tier_definition(equipment_id: String, rarity: String) -> Dictionary:
	var definition := equipment_definition(equipment_id)
	for raw_tier in definition.get("tiers", []):
		if raw_tier is Dictionary and str(raw_tier.get("rarity", "")) == rarity:
			return raw_tier.duplicate(true)
	return {}


static func default_rarity_weights() -> Dictionary:
	_ensure_loaded()
	var default_id := str(_index_cache.get("default_equipment_id", ""))
	return rarity_weights(default_id)


static func rarity_weights(equipment_id: String) -> Dictionary:
	var definition := equipment_definition(equipment_id)
	var result := {}
	for raw_tier in definition.get("tiers", []):
		if raw_tier is Dictionary:
			result[str(raw_tier.get("rarity", ""))] = int(raw_tier.get("generation_weight", 0))
	return result


static func resource_path(equipment_id: String) -> String:
	_ensure_loaded()
	if not _equipment_cache.has(equipment_id):
		return ""
	var paths = _index_cache.get("equipment_paths", {})
	return str(paths.get(equipment_id, "")) if paths is Dictionary else ""


static func validate_equipment_data(data: Dictionary, source_path: String = "<memory>") -> Array[String]:
	var errors: Array[String] = []
	if int(data.get("format_version", 0)) != FORMAT_VERSION:
		errors.append("%s: format_version must be %d" % [source_path, FORMAT_VERSION])
	var equipment_id := str(data.get("id", ""))
	var template_id := str(data.get("template_id", ""))
	var slot := str(data.get("slot", ""))
	if equipment_id.is_empty():
		errors.append("%s: id is required" % source_path)
	if not VALID_SLOTS.has(template_id) or slot != template_id:
		errors.append("%s: template_id and slot must name the same valid slot" % source_path)
	if str(data.get("name", "")).is_empty():
		errors.append("%s: name is required" % source_path)
	if int(data.get("selection_weight", 0)) <= 0:
		errors.append("%s: selection_weight must be positive" % source_path)
	var attribute_order = data.get("attribute_order", [])
	if not (attribute_order is Array) or attribute_order.size() != 2 or str(attribute_order[0]) == str(attribute_order[1]):
		errors.append("%s: attribute_order must contain two distinct stats" % source_path)
	elif not VALID_STATS.has(str(attribute_order[0])) or not VALID_STATS.has(str(attribute_order[1])):
		errors.append("%s: attribute_order contains an invalid stat" % source_path)
	var variant_id := str(data.get("variant_id", ""))
	if ["weapon", "accessory"].has(template_id) and variant_id != equipment_id:
		errors.append("%s: weapon and accessory variant_id must match id" % source_path)
	if not ["weapon", "accessory"].has(template_id) and not variant_id.is_empty():
		errors.append("%s: fixed-slot equipment must have an empty variant_id" % source_path)
	if str(data.get("icon_path", "")).is_empty():
		errors.append("%s: icon_path is required" % source_path)
	var units = data.get("attribute_units", {})
	if not (units is Dictionary):
		errors.append("%s: attribute_units must be a dictionary" % source_path)
	else:
		for stat_id in VALID_STATS:
			if int(units.get(stat_id, 0)) <= 0:
				errors.append("%s: attribute_units.%s must be positive" % [source_path, stat_id])
	var pool = data.get("random_attribute_pool", [])
	var seen_pool: Array[String] = []
	if not (pool is Array):
		errors.append("%s: random_attribute_pool must be an array" % source_path)
	else:
		for value in pool:
			var stat_id := str(value)
			if not VALID_STATS.has(stat_id) or seen_pool.has(stat_id):
				errors.append("%s: random_attribute_pool contains invalid or duplicate stat %s" % [source_path, stat_id])
			else:
				seen_pool.append(stat_id)
	var tiers = data.get("tiers", [])
	if not (tiers is Array) or tiers.size() != TIER_IDS.size():
		errors.append("%s: tiers must contain t1 through t5" % source_path)
		return errors
	for index in range(TIER_IDS.size()):
		var tier_path := "%s: tiers[%d]" % [source_path, index]
		if not (tiers[index] is Dictionary):
			errors.append("%s must be a dictionary" % tier_path)
			continue
		var tier: Dictionary = tiers[index]
		if int(tier.get("tier", 0)) != index + 1 or str(tier.get("rarity", "")) != TIER_IDS[index]:
			errors.append("%s must identify %s" % [tier_path, TIER_IDS[index]])
		var attributes = tier.get("base_attributes", [])
		if not (attributes is Array) or attributes.size() != 2:
			errors.append("%s.base_attributes must contain two entries" % tier_path)
		else:
			for attribute_index in range(2):
				var attribute = attributes[attribute_index]
				if not (attribute is Dictionary) or str(attribute.get("stat", "")) != str(attribute_order[attribute_index]) or int(attribute.get("amount", 0)) <= 0:
					errors.append("%s.base_attributes[%d] must match attribute_order and have a positive amount" % [tier_path, attribute_index])
		var random_count := int(tier.get("random_count", -1))
		var random_budget := int(tier.get("random_budget", -1))
		if random_count < 0 or random_budget < random_count:
			errors.append("%s random budget must give every random stat at least one point" % tier_path)
		var available_random_count := seen_pool.size()
		for fixed_stat in attribute_order:
			if seen_pool.has(str(fixed_stat)):
				available_random_count -= 1
		if random_count > available_random_count:
			errors.append("%s.random_count exceeds the pool after fixed attributes are excluded" % tier_path)
		if int(tier.get("generation_weight", 0)) <= 0:
			errors.append("%s.generation_weight must be positive" % tier_path)
		if int(tier.get("affix_count", -1)) < 0:
			errors.append("%s.affix_count must be non-negative" % tier_path)
		if int(tier.get("enhance_limit", 0)) <= 0:
			errors.append("%s.enhance_limit must be positive" % tier_path)
		var enhance_cost = tier.get("enhance_cost", {})
		if not (enhance_cost is Dictionary) or int(enhance_cost.get("enhancement_stone", 0)) <= 0:
			errors.append("%s.enhance_cost must contain enhancement_stone" % tier_path)
		elif _has_non_positive_cost(enhance_cost):
			errors.append("%s.enhance_cost values must be positive" % tier_path)
		var ascension_cost = tier.get("ascension_cost", {})
		if not (ascension_cost is Dictionary):
			errors.append("%s.ascension_cost must be a dictionary" % tier_path)
		elif index == TIER_IDS.size() - 1 and not ascension_cost.is_empty():
			errors.append("%s.ascension_cost must be empty for t5" % tier_path)
		elif index < TIER_IDS.size() - 1:
			if int(ascension_cost.get("ore", 0)) <= 0 or int(ascension_cost.get("ascension_stone", 0)) <= 0:
				errors.append("%s.ascension_cost must contain positive ore and ascension_stone values" % tier_path)
			elif _has_non_positive_cost(ascension_cost):
				errors.append("%s.ascension_cost values must be positive" % tier_path)
	return errors


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var resource := _load_resource(INDEX_PATH)
	if resource == null:
		_record_error("%s: index resource could not be loaded" % INDEX_PATH)
		return
	var raw_index = resource.get_meta(INDEX_META_KEY, {})
	if not (raw_index is Dictionary):
		_record_error("%s: metadata/equipment_index must be a dictionary" % INDEX_PATH)
		return
	_index_cache = raw_index.duplicate(true)
	_validate_index()
	var paths = _index_cache.get("equipment_paths", {})
	if not (paths is Dictionary):
		return
	for raw_id in paths:
		var equipment_id := str(raw_id)
		var path := str(paths[raw_id])
		var equipment_resource := _load_resource(path)
		if equipment_resource == null:
			_record_error("%s: indexed equipment resource could not be loaded" % path)
			continue
		var raw_data = equipment_resource.get_meta(EQUIPMENT_META_KEY, {})
		if (not (raw_data is Dictionary) or raw_data.is_empty()) and equipment_resource.has_method("to_equipment_data"):
			raw_data = equipment_resource.call("to_equipment_data")
		if not (raw_data is Dictionary):
			_record_error("%s: resource must expose equipment data" % path)
			continue
		var data: Dictionary = raw_data.duplicate(true)
		var errors := validate_equipment_data(data, path)
		if str(data.get("id", "")) != equipment_id:
			errors.append("%s: index id %s does not match resource id" % [path, equipment_id])
		if not errors.is_empty():
			for error in errors:
				_record_error(error)
			continue
		_equipment_cache[equipment_id] = data
	_validate_index_references()


static func _validate_index() -> void:
	if int(_index_cache.get("format_version", 0)) != FORMAT_VERSION:
		_record_error("%s: format_version must be %d" % [INDEX_PATH, FORMAT_VERSION])
	if not (_index_cache.get("equipment_paths", {}) is Dictionary):
		_record_error("%s: equipment_paths must be a dictionary" % INDEX_PATH)
	var slots = _index_cache.get("slots", [])
	if not (slots is Array) or slots.size() != VALID_SLOTS.size():
		_record_error("%s: slots must contain six entries" % INDEX_PATH)
		return
	var seen: Array[String] = []
	for raw_slot in slots:
		if not (raw_slot is Dictionary):
			_record_error("%s: every slot entry must be a dictionary" % INDEX_PATH)
			continue
		var slot_id := str(raw_slot.get("id", ""))
		if not VALID_SLOTS.has(slot_id) or seen.has(slot_id) or int(raw_slot.get("weight", 0)) <= 0:
			_record_error("%s: slot %s is invalid, duplicated, or has non-positive weight" % [INDEX_PATH, slot_id])
		seen.append(slot_id)


static func _validate_index_references() -> void:
	for raw_slot in _index_cache.get("slots", []):
		if not (raw_slot is Dictionary):
			continue
		var slot_id := str(raw_slot.get("id", ""))
		var candidates = raw_slot.get("equipment_ids", [])
		if not (candidates is Array) or candidates.is_empty():
			_record_error("%s: slot %s has no equipment_ids" % [INDEX_PATH, slot_id])
			continue
		for value in candidates:
			var equipment_id := str(value)
			if not _equipment_cache.has(equipment_id):
				_record_error("%s: slot %s references invalid equipment %s" % [INDEX_PATH, slot_id, equipment_id])
			elif str(_equipment_cache[equipment_id].get("template_id", "")) != slot_id:
				_record_error("%s: equipment %s belongs to a different slot" % [INDEX_PATH, equipment_id])
	var default_id := str(_index_cache.get("default_equipment_id", ""))
	if not _equipment_cache.has(default_id):
		_record_error("%s: default_equipment_id is invalid" % INDEX_PATH)
	var aliases = _index_cache.get("aliases", {})
	if not (aliases is Dictionary):
		_record_error("%s: aliases must be a dictionary" % INDEX_PATH)
		return
	for alias_id in aliases:
		var alias = aliases[alias_id]
		if not (alias is Dictionary) or not _equipment_cache.has(str(alias.get("equipment_id", ""))):
			_record_error("%s: alias %s references invalid equipment" % [INDEX_PATH, str(alias_id)])


static func _roll_weighted(entries: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for entry in entries:
		if entry is Dictionary:
			total += maxi(0, int(entry.get("weight", 0)))
	if total <= 0:
		return ""
	var roll := rng.randi_range(1, total)
	for entry in entries:
		if not (entry is Dictionary):
			continue
		roll -= maxi(0, int(entry.get("weight", 0)))
		if roll <= 0:
			return str(entry.get("id", ""))
	return ""


static func _load_resource(path: String) -> Resource:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)


static func _has_non_positive_cost(cost: Dictionary) -> bool:
	for item_id in cost:
		if str(item_id).is_empty() or int(cost[item_id]) <= 0:
			return true
	return false


static func _record_error(message: String) -> void:
	_validation_errors.append(message)
	push_error(message)
