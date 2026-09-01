class_name SkillConfigParser
extends RefCounted

const INDEX_PATH := "res://resources/skills/index.tres"
const FORMAT_VERSION := 1
const VALID_TYPES := ["normal_attack", "damage", "heal", "buff", "defense", "resource"]
const VALID_SCOPES := ["self", "single_ally", "all_allies", "single_enemy", "all_enemies"]
const VALID_TARGET_TENDENCIES := ["front", "back"]
const VALID_EFFECT_KINDS := ["damage", "heal", "status", "cooldown"]
const VALID_EFFECT_TARGETS := ["skill_targets", "caster", "primary_target", "hit_targets"]
const VALID_STATUS_KINDS := ["dot", "hot", "shield", "buff_stat", "debuff_stat"]
const VALID_STACK_MODES := ["refresh", "stack"]
const VALID_ATTACK_MODES := ["auto", "melee", "ranged"]
const ContentIndexResourceScript = preload("res://scripts/game/data/content_index_resource.gd")

static var _loaded := false
static var _definitions: Dictionary = {}
static var _basic_attacks: Dictionary = {}
static var _exchange: Dictionary = {}
static var _scene_paths: Dictionary = {}
static var _resource_paths: Dictionary = {}
static var _errors: Array[String] = []


static func clear_cache() -> void:
	_loaded = false
	_definitions.clear(); _basic_attacks.clear(); _exchange.clear(); _scene_paths.clear(); _resource_paths.clear(); _errors.clear()


static func definitions() -> Dictionary:
	_ensure_loaded(); return _definitions.duplicate(true)


static func basic_attack_definitions() -> Dictionary:
	_ensure_loaded(); return _basic_attacks.duplicate(true)


static func exchange_definitions() -> Dictionary:
	_ensure_loaded(); return _exchange.duplicate(true)


static func scene_path(skill_id: String) -> String:
	_ensure_loaded(); return str(_scene_paths.get(skill_id, ""))


static func resource_path(skill_id: String) -> String:
	_ensure_loaded(); return str(_resource_paths.get(skill_id, ""))


static func validation_errors() -> Array[String]:
	_ensure_loaded(); return _errors.duplicate()


static func definition(skill_id: String) -> Dictionary:
	_ensure_loaded()
	var data = _definitions.get(skill_id, {}) if _definitions.has(skill_id) else _basic_attacks.get(skill_id, {})
	return data.duplicate(true) if data is Dictionary else {}


static func validate_definition(data: Dictionary, source_path: String = "<memory>") -> Array[String]:
	var errors: Array[String] = []
	if str(data.get("id", "")).is_empty(): errors.append("%s: id is required" % source_path)
	if str(data.get("name", "")).is_empty(): errors.append("%s: display_name is required" % source_path)
	if not VALID_TYPES.has(str(data.get("type", ""))): errors.append("%s: type is invalid" % source_path)
	if not VALID_SCOPES.has(str(data.get("target_scope", ""))): errors.append("%s: target_scope is invalid" % source_path)
	if data.has("target_count") and (int(data.get("target_count", 0)) < 1 or int(data.get("target_count", 0)) > 4): errors.append("%s: target_count must be between 1 and 4" % source_path)
	if data.has("target_tendency") and not VALID_TARGET_TENDENCIES.has(str(data.get("target_tendency", ""))): errors.append("%s: target_tendency is invalid" % source_path)
	if int(data.get("mp_cost", 0)) < 0: errors.append("%s: mp_cost must be non-negative" % source_path)
	if float(data.get("cooldown", 0.0)) < 0.0: errors.append("%s: cooldown must be non-negative" % source_path)
	if float(data.get("weight", 1.0)) <= 0.0: errors.append("%s: weight must be positive" % source_path)
	if data.has("attack_mode") and not VALID_ATTACK_MODES.has(str(data.get("attack_mode", ""))): errors.append("%s: attack_mode must be auto, melee or ranged" % source_path)
	var effects = data.get("effects", [])
	if not (effects is Array) or effects.is_empty():
		errors.append("%s: effects must be a non-empty array" % source_path)
		return errors
	var effect_ids := {}
	for index in range(effects.size()):
		if not (effects[index] is Dictionary):
			errors.append("%s: effects[%d] must be SkillEffectDef" % [source_path, index])
			continue
		var effect: Dictionary = effects[index]
		var prefix := "%s: effects[%d]" % [source_path, index]
		var effect_id := str(effect.get("effect_id", ""))
		if effect_id.is_empty() or effect_ids.has(effect_id): errors.append("%s.effect_id is empty or duplicated" % prefix)
		effect_ids[effect_id] = true
		var kind := str(effect.get("kind", ""))
		if not VALID_EFFECT_KINDS.has(kind): errors.append("%s.kind is invalid" % prefix)
		if not VALID_EFFECT_TARGETS.has(str(effect.get("target", ""))): errors.append("%s.target is invalid" % prefix)
		if str(effect.get("impact_id", "")).is_empty(): errors.append("%s.impact_id is required" % prefix)
		if kind in ["damage", "heal"] and (int(effect.get("base_amount", 0)) < 0 or float(effect.get("attribute_multiplier", 0.0)) < 0.0): errors.append("%s damage/heal amounts must be non-negative" % prefix)
		if kind == "status":
			if str(effect.get("status_id", "")).is_empty(): errors.append("%s.status_id is required" % prefix)
			if not VALID_STATUS_KINDS.has(str(effect.get("status_kind", ""))): errors.append("%s.status_kind is invalid" % prefix)
			if int(effect.get("duration_turns", 0)) <= 0: errors.append("%s.duration_turns must be positive" % prefix)
			if not VALID_STACK_MODES.has(str(effect.get("stack_mode", ""))): errors.append("%s.stack_mode is invalid" % prefix)
			if int(effect.get("max_stacks", 0)) <= 0: errors.append("%s.max_stacks must be positive" % prefix)
			if str(effect.get("status_kind", "")) in ["buff_stat", "debuff_stat"] and str(effect.get("stat", "")).is_empty(): errors.append("%s.stat is required for stat status" % prefix)
			var status_scene_path := str(effect.get("status_scene_path", ""))
			if status_scene_path.is_empty() or not ResourceLoader.exists(status_scene_path): errors.append("%s.status_scene_path is missing" % prefix)
		if kind == "cooldown" and float(effect.get("multiplier", 0.0)) <= 0.0: errors.append("%s.multiplier must be positive" % prefix)
	return errors


static func _ensure_loaded() -> void:
	if _loaded: return
	_loaded = true
	var index = load(INDEX_PATH)
	if index == null or index.get_script() != ContentIndexResourceScript:
		_errors.append("%s: index must use ContentIndexResource" % INDEX_PATH); return
	if index.format_version != FORMAT_VERSION:
		_errors.append("%s: format_version must be %d" % [INDEX_PATH, FORMAT_VERSION]); return
	for raw_id in index.entries:
		var skill_id := str(raw_id)
		var entry = index.entries[raw_id]
		if not (entry is Dictionary):
			_errors.append("%s: entries.%s must be a dictionary" % [INDEX_PATH, skill_id]); continue
		var path := str(entry.get("resource_path", ""))
		var scene_path_value := str(entry.get("scene_path", ""))
		var category := str(entry.get("category", "active"))
		if not ["active", "basic_attack"].has(category):
			_errors.append("%s: entries.%s.category is invalid" % [INDEX_PATH, skill_id]); continue
		if not ResourceLoader.exists(path):
			_errors.append("%s: entries.%s.resource_path does not exist: %s" % [INDEX_PATH, skill_id, path]); continue
		var resource := load(path) as SkillDef
		if resource == null or resource.id != skill_id:
			_errors.append("%s: SkillDef id must match %s" % [path, skill_id]); continue
		var data := _normalized(resource.to_dictionary())
		var local_errors := validate_definition(data, path)
		if not local_errors.is_empty():
			_errors.append_array(local_errors); continue
		var exchange = data.get("exchange", {})
		if exchange is Dictionary and not exchange.is_empty():
			var exchange_valid := true
			for field in ["book_item_id", "element_stone_id"]:
				if not ResourceLoader.exists("res://resources/items/%s.tres" % str(exchange.get(field, ""))):
					_errors.append("%s: exchange.%s references a missing item" % [path, field])
					exchange_valid = false
			if int(exchange.get("fragment_cost", 0)) <= 0 or int(exchange.get("stone_cost", 0)) <= 0:
				_errors.append("%s: exchange costs must be positive" % path)
				exchange_valid = false
			if not exchange_valid: continue
		if category == "basic_attack":
			var mode := str(data.get("basic_attack_mode", ""))
			if not ["melee", "ranged"].has(mode):
				_errors.append("%s: basic_attack_mode must be melee or ranged" % path); continue
			if _basic_attacks.has(mode):
				_errors.append("%s: duplicate basic_attack_mode %s" % [path, mode]); continue
			_basic_attacks[mode] = data
		else:
			if scene_path_value.is_empty() or not ResourceLoader.exists(scene_path_value):
				_errors.append("%s: entries.%s.scene_path does not exist: %s" % [INDEX_PATH, skill_id, scene_path_value]); continue
			var packed := load(scene_path_value) as PackedScene
			var scene_instance := packed.instantiate() if packed != null else null
			var bound_resource = scene_instance.get("skill_resource") if scene_instance != null else null
			if bound_resource == null or str(bound_resource.get("id")) != skill_id:
				if scene_instance != null: scene_instance.free()
				_errors.append("%s: scene_path must bind SkillDef %s" % [scene_path_value, skill_id]); continue
			scene_instance.free()
			_definitions[skill_id] = data
			_scene_paths[skill_id] = scene_path_value
		if exchange is Dictionary and not exchange.is_empty():
			_exchange[skill_id] = exchange.duplicate(true)
		_resource_paths[skill_id] = path
	for group_id in index.groups:
		var group_values = index.groups[group_id]
		var seen_group_ids := {}
		if not (group_values is Array):
			_errors.append("%s: groups.%s must be an array" % [INDEX_PATH, group_id]); continue
		for raw_skill_id in group_values:
			var skill_id := str(raw_skill_id)
			if seen_group_ids.has(skill_id): _errors.append("%s: groups.%s contains duplicate id %s" % [INDEX_PATH, group_id, skill_id])
			elif not _resource_paths.has(skill_id): _errors.append("%s: groups.%s references unregistered id %s" % [INDEX_PATH, group_id, skill_id])
			seen_group_ids[skill_id] = true


static func _normalized(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var scope := str(result.get("target_scope", "single_enemy"))
	result["target_mode"] = "aoe" if scope in ["all_allies", "all_enemies"] else "single"
	result["is_aoe"] = result["target_mode"] == "aoe"
	var tags: Array[String] = []
	for raw_effect in result.get("effects", []):
		if not (raw_effect is Dictionary): continue
		var effect: Dictionary = raw_effect
		var kind := str(effect.get("kind", ""))
		if not tags.has(kind): tags.append(kind)
		if kind == "status":
			var status_kind := str(effect.get("status_kind", ""))
			if not tags.has(status_kind): tags.append(status_kind)
			var marker := "debuff" if status_kind in ["dot", "debuff_stat"] else "buff"
			if not tags.has(marker): tags.append(marker)
	result["effect_tags"] = tags
	result["has_buff"] = tags.has("buff")
	result["has_debuff"] = tags.has("debuff")
	return result
