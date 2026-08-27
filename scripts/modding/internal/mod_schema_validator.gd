class_name ModSchemaValidator
extends RefCounted

const ModContentRegistryScript = preload("res://scripts/modding/api/mod_content_registry.gd")
const ItemConfigParserScript = preload("res://scripts/game/data/item_config_parser.gd")
const MANIFEST_SCHEMA_VERSION := 2
const MOD_API_VERSION := 2
const GAME_VERSION := "0.2.0"
const PERMANENT_ATTRIBUTE_ENHANCE_STATS := ["attack", "defense", "max_hp", "max_mp", "root_bone", "element_wood", "element_fire", "element_earth", "element_metal", "element_water"]
const PERMANENT_ATTRIBUTE_ENHANCE_TIERS := ["t1"]

var _mod_id_regex := RegEx.new()
var _local_id_regex := RegEx.new()


func _init() -> void:
	_mod_id_regex.compile("^[a-z0-9][a-z0-9._-]{2,63}$")
	_local_id_regex.compile("^[a-z0-9][a-z0-9_-]{0,63}$")


func validate_manifest(manifest: Dictionary, manifest_path: String) -> Array[String]:
	var errors: Array[String] = []
	var allowed_fields := [
		"schema_version", "id", "name", "version", "description", "authors",
		"mod_api_version", "game_version", "dependencies", "conflicts",
		"load_after", "content", "entry_script", "overrides",
	]
	for key in manifest.keys():
		if not allowed_fields.has(str(key)):
			errors.append("Manifest 包含未知字段: %s" % key)
	for field in ["schema_version", "id", "name", "version", "mod_api_version", "game_version", "content"]:
		if not manifest.has(field):
			errors.append("Manifest 缺少 %s" % field)
	var mod_id := str(manifest.get("id", ""))
	if int(manifest.get("schema_version", 0)) != MANIFEST_SCHEMA_VERSION:
		errors.append("不支持的 Manifest schema_version")
	if _mod_id_regex.search(mod_id) == null:
		errors.append("Mod ID 不合法: %s" % mod_id)
	var expected_path := "res://mods/%s/manifest.json" % mod_id
	if manifest_path != expected_path:
		errors.append("Manifest 路径必须为 %s" % expected_path)
	for field in ["name", "version"]:
		if str(manifest.get(field, "")).is_empty():
			errors.append("Manifest 缺少 %s" % field)
	if not is_semver(str(manifest.get("version", ""))):
		errors.append("Mod version 必须为 SemVer")
	if int(manifest.get("mod_api_version", 0)) != MOD_API_VERSION:
		errors.append("mod_api_version 与游戏不兼容")
	var game_range = manifest.get("game_version", {})
	if not (game_range is Dictionary) or not version_in_range(GAME_VERSION, game_range):
		errors.append("游戏版本不在 Mod 声明范围内")
	for field in ["dependencies", "conflicts", "load_after", "content", "overrides", "authors"]:
		if manifest.has(field) and not (manifest[field] is Array):
			errors.append("Manifest.%s 必须为数组" % field)
	for author in manifest.get("authors", []):
		if not (author is String) or str(author).strip_edges().is_empty():
			errors.append("authors 元素必须为非空字符串")
	for field in ["conflicts", "load_after"]:
		for referenced_mod_id in manifest.get(field, []):
			if not (referenced_mod_id is String) or _mod_id_regex.search(str(referenced_mod_id)) == null:
				errors.append("Manifest.%s 包含无效 Mod ID" % field)
	for dependency in manifest.get("dependencies", []):
		if not (dependency is Dictionary) or _mod_id_regex.search(str(dependency.get("id", ""))) == null:
			errors.append("依赖声明无效")
			continue
		for key in dependency.keys():
			if not ["id", "min_version", "max_version_exclusive", "optional"].has(str(key)):
				errors.append("依赖 %s 包含未知字段: %s" % [dependency.get("id", ""), key])
		if dependency.has("optional") and not (dependency.get("optional") is bool):
			errors.append("依赖 %s 的 optional 必须为 boolean" % dependency.get("id", ""))
		for key in ["min_version", "max_version_exclusive"]:
			var value := str(dependency.get(key, ""))
			if not value.is_empty() and not is_semver(value):
				errors.append("依赖 %s 的 %s 不是 SemVer" % [dependency.get("id", ""), key])
	for path in manifest.get("content", []):
		if not is_owned_path(str(path), mod_id, ".json"):
			errors.append("内容路径越界或格式错误: %s" % path)
	var entry_script := str(manifest.get("entry_script", ""))
	if not entry_script.is_empty() and not is_owned_path(entry_script, mod_id, ".gd"):
		errors.append("entry_script 路径越界或格式错误")
	return errors


func validate_content_document(document: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in document.keys():
		if not ["schema_version", "kind", "entries"].has(str(key)):
			errors.append("内容文件包含未知字段: %s" % key)
	if int(document.get("schema_version", 0)) != 2:
		errors.append("内容文件 schema_version 必须为 2；v1 已停止支持")
	var kind := str(document.get("kind", ""))
	if not ModContentRegistryScript.KINDS.has(kind):
		errors.append("不支持的内容 kind: %s" % kind)
	if not (document.get("entries", null) is Array):
		errors.append("内容文件 entries 必须为数组")
		return errors
	for entry in document.get("entries", []):
		if not (entry is Dictionary):
			errors.append("entries 元素必须为对象")
			continue
		var operation := str(entry.get("operation", ""))
		if operation == "add":
			for key in entry.keys():
				if not ["operation", "local_id", "data"].has(str(key)):
					errors.append("add entry 包含未知字段: %s" % key)
			if _local_id_regex.search(str(entry.get("local_id", ""))) == null:
				errors.append("add entry.local_id 无效")
			if not (entry.get("data") is Dictionary):
				errors.append("add entry.data 必须为对象")
		elif operation == "patch":
			for key in entry.keys():
				if not ["operation", "target_id", "patch"].has(str(key)):
					errors.append("patch entry 包含未知字段: %s" % key)
			if str(entry.get("target_id", "")).is_empty():
				errors.append("patch entry.target_id 不能为空")
			if not (entry.get("patch") is Dictionary):
				errors.append("patch entry.patch 必须为对象")
		else:
			errors.append("不支持的 content operation: %s" % operation)
	return errors


func validate_definition(kind: String, content_id: String, data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if data.is_empty():
		errors.append("%s:%s 定义不能为空" % [kind, content_id])
		return errors
	var required: Dictionary = {
		"item": ["name", "type"],
		"equipment": ["name", "slot"],
		"skill": ["name", "type", "target_scope", "target_mode", "effects"],
		"basic_attack": ["name", "effects"],
		"recipe": ["result_item_id", "materials"],
		"trait": ["name", "effects"],
		"enemy": ["name", "visual_id", "scene_path"],
		"enemy_rank": ["name"],
		"drop_table": [],
		"appearance": ["kind", "scene_path"],
		"dialogue": ["text"],
	}
	for field in required.get(kind, []):
		if not data.has(field):
			errors.append("%s:%s 缺少字段 %s" % [kind, content_id, field])
		elif field in ["name", "scene_path", "visual_id", "slot", "result_item_id", "text"] and str(data.get(field, "")).strip_edges().is_empty():
			errors.append("%s:%s 字段 %s 不能为空" % [kind, content_id, field])
	if kind == "item":
		var combat_target_mode := str(data.get("combat_target_mode", ItemConfigParserScript.infer_combat_target_mode(data.get("effects", []))))
		if not ["single", "aoe"].has(combat_target_mode):
			errors.append("item:%s combat_target_mode 只能为 single 或 aoe" % content_id)
		var payload = data.get("payload", {})
		if data.has("payload") and not (payload is Dictionary):
			errors.append("item:%s payload 必须为对象" % content_id)
		elif payload is Dictionary and payload.has("permanent_attribute_enhance"):
			var enhance_data = payload.get("permanent_attribute_enhance")
			if not (enhance_data is Dictionary):
				errors.append("item:%s permanent_attribute_enhance 必须为对象" % content_id)
			else:
				var tier_id := str(enhance_data.get("tier_id", ""))
				if not PERMANENT_ATTRIBUTE_ENHANCE_TIERS.has(tier_id):
					errors.append("item:%s permanent_attribute_enhance.tier_id 无效" % content_id)
				var effects = enhance_data.get("effects", [])
				if not (effects is Array) or effects.is_empty():
					errors.append("item:%s permanent_attribute_enhance.effects 必须为非空数组" % content_id)
				else:
					var seen_stats: Dictionary = {}
					for effect in effects:
						if not (effect is Dictionary):
							errors.append("item:%s permanent_attribute_enhance.effects 元素必须为对象" % content_id)
							continue
						var stat_id := str(effect.get("stat", ""))
						if not PERMANENT_ATTRIBUTE_ENHANCE_STATS.has(stat_id):
							errors.append("item:%s permanent_attribute_enhance.stat 无效" % content_id)
						elif seen_stats.has(stat_id):
							errors.append("item:%s permanent_attribute_enhance.stat 不能重复" % content_id)
						seen_stats[stat_id] = true
						if effect.has("amount") and (typeof(effect.get("amount")) != TYPE_INT or int(effect.get("amount", 0)) <= 0):
							errors.append("item:%s permanent_attribute_enhance.amount 必须为正整数" % content_id)
		if data.has("effects"):
			var item_effects = data.get("effects", [])
			if not (item_effects is Array):
				errors.append("item:%s effects 必须为数组" % content_id)
			else:
				var effect_ids := {}
				for effect in item_effects:
					if not (effect is Dictionary):
						errors.append("item:%s effects 元素必须为对象" % content_id)
						continue
					var effect_id := str(effect.get("effect_id", ""))
					if effect_id.is_empty() or effect_ids.has(effect_id): errors.append("item:%s effect_id 不能为空或重复" % content_id)
					effect_ids[effect_id] = true
					var effect_kind := str(effect.get("kind", ""))
					var effect_target := str(effect.get("target", "none"))
					if not ["restore_resource", "temporary_modifier", "permanent_attribute", "unlock_content", "breakthrough", "building_quality", "farm_seed", "equipment_enhancement_material", "currency"].has(effect_kind): errors.append("item:%s effect.kind 无效" % content_id)
					if not ["none", "member", "home_global", "combat_global"].has(effect_target): errors.append("item:%s effect.target 无效" % content_id)
					if combat_target_mode == "single" and effect_target == "combat_global": errors.append("item:%s combat_global 效果必须使用 aoe combat_target_mode" % content_id)
					if effect_kind == "restore_resource":
						if effect_target != "member" or not ["hp", "mp"].has(str(effect.get("stat", ""))): errors.append("item:%s 恢复效果必须指向人物的 hp/mp" % content_id)
						if int(effect.get("amount", 0)) <= 0 and float(effect.get("ratio", 0.0)) <= 0.0: errors.append("item:%s 恢复效果必须有正数 amount 或 ratio" % content_id)
					if effect_kind == "temporary_modifier":
						if effect_target == "none": errors.append("item:%s 临时属性效果必须指定目标" % content_id)
						if not ["flat", "percent"].has(str(effect.get("operation", ""))): errors.append("item:%s effect.operation 无效" % content_id)
						if str(effect.get("buff_id", "")).is_empty(): errors.append("item:%s 临时属性效果缺少 buff_id" % content_id)
						var duration_mode := str(effect.get("duration_mode", "timed"))
						if not ["timed", "permanent"].has(duration_mode): errors.append("item:%s effect.duration_mode 无效" % content_id)
						if duration_mode == "timed" and float(effect.get("duration_seconds", 0.0)) <= 0.0: errors.append("item:%s 限时效果 duration_seconds 必须为正数" % content_id)
						if not ["replace", "refresh", "extend", "stack"].has(str(effect.get("stack_mode", "refresh"))): errors.append("item:%s effect.stack_mode 无效" % content_id)
						if int(effect.get("max_stacks", 1)) <= 0: errors.append("item:%s effect.max_stacks 必须为正数" % content_id)
					if effect_kind == "permanent_attribute" and effect_target != "member": errors.append("item:%s 永久属性效果必须指向人物" % content_id)
					if effect_kind == "unlock_content" and (str(effect.get("reference_kind", "")).is_empty() or str(effect.get("reference_id", "")).is_empty()): errors.append("item:%s 内容解锁效果缺少引用" % content_id)
	if kind in ["skill", "basic_attack"]:
		var target_scope := str(data.get("target_scope", "single_enemy"))
		if not ["self", "single_ally", "all_allies", "single_enemy", "all_enemies"].has(target_scope):
			errors.append("%s:%s target_scope 无效" % [kind, content_id])
		if data.has("target_mode") and not ["single", "aoe"].has(str(data.get("target_mode", ""))):
			errors.append("%s:%s target_mode 只能为 single 或 aoe" % [kind, content_id])
		for field in ["mp_cost", "cooldown"]:
			if float(data.get(field, 0.0)) < 0.0:
				errors.append("%s:%s %s 不能为负数" % [kind, content_id, field])
		for field in ["base_damage", "damage_attribute_multiplier", "heal_amount", "heal_attribute_multiplier"]:
			if data.has(field) and (typeof(data.get(field)) not in [TYPE_INT, TYPE_FLOAT] or float(data.get(field)) < 0.0):
				errors.append("%s:%s %s 必须为非负数" % [kind, content_id, field])
		var effects = data.get("effects", [])
		if not (effects is Array):
			errors.append("%s:%s effects 必须为数组" % [kind, content_id])
		else:
			for effect in effects:
				if not (effect is Dictionary):
					errors.append("%s:%s effects 元素必须为对象" % [kind, content_id])
					continue
				if str(effect.get("impact_id", "impact")).strip_edges().is_empty():
					errors.append("%s:%s effect.impact_id 不能为空" % [kind, content_id])
				if effect.has("attribute_multiplier") and (typeof(effect.get("attribute_multiplier")) not in [TYPE_INT, TYPE_FLOAT] or float(effect.get("attribute_multiplier")) < 0.0):
					errors.append("%s:%s effect.attribute_multiplier 必须为非负数" % [kind, content_id])
				if str(effect.get("kind", "")) == "status":
					if str(effect.get("status_id", "")).is_empty():
						errors.append("%s:%s status effect 缺少 status_id" % [kind, content_id])
					if not ["dot", "hot", "shield", "buff_stat", "debuff_stat"].has(str(effect.get("status_kind", ""))):
						errors.append("%s:%s status_kind 无效" % [kind, content_id])
					if int(effect.get("duration_turns", 0)) < 1:
						errors.append("%s:%s duration_turns 必须至少为 1" % [kind, content_id])
					if not ["refresh", "stack"].has(str(effect.get("stack_mode", "refresh"))):
						errors.append("%s:%s stack_mode 无效" % [kind, content_id])
					if int(effect.get("max_stacks", 1)) < 1:
						errors.append("%s:%s max_stacks 必须至少为 1" % [kind, content_id])
					if str(effect.get("status_scene_path", "")).is_empty():
						errors.append("%s:%s status effect 缺少 status_scene_path" % [kind, content_id])
	if kind == "enemy":
		var enemy_class := str(data.get("enemy_class", data.get("encounter_class", "normal")))
		if not ["normal", "elite", "boss"].has(enemy_class):
			errors.append("enemy:%s enemy_class 无效" % content_id)
		for field in ["experience_multiplier", "drop_chance_bonus", "equipment_drop_chance"]:
			if data.has(field) and (typeof(data.get(field)) not in [TYPE_INT, TYPE_FLOAT] or float(data.get(field)) < 0.0):
				errors.append("enemy:%s %s 必须为非负数" % [content_id, field])
		if data.has("skill_unlock_rank") and not ["t1", "t2", "t3", "t4", "t5"].has(str(data.get("skill_unlock_rank", ""))):
			errors.append("enemy:%s skill_unlock_rank 无效" % content_id)
	if kind == "appearance" and not ["party", "enemy"].has(str(data.get("kind", ""))):
		errors.append("appearance:%s kind 必须为 party 或 enemy" % content_id)
	if kind == "appearance" and int(data.get("contract_version", 1)) != 1:
		errors.append("appearance:%s contract_version 必须为 1" % content_id)
	if kind == "recipe" and not (data.get("materials") is Array):
		errors.append("recipe:%s materials 必须为数组" % content_id)
	if kind == "dialogue":
		if str(data.get("text", "")).strip_edges().is_empty():
			errors.append("dialogue:%s text 不能为空" % content_id)
		if float(data.get("weight", 1.0)) <= 0.0 or float(data.get("cooldown_seconds", 0.0)) < 0.0:
			errors.append("dialogue:%s 权重或冷却无效" % content_id)
		if int(data.get("min_level", 1)) > int(data.get("max_level", 2147483647)):
			errors.append("dialogue:%s min_level 不能大于 max_level" % content_id)
	return errors


func validate_owned_values(value, mod_id: String, key: String = "") -> Array[String]:
	var errors: Array[String] = []
	if value is Dictionary:
		for child_key in value.keys():
			errors.append_array(validate_owned_values(value[child_key], mod_id, str(child_key)))
	elif value is Array:
		for child in value:
			errors.append_array(validate_owned_values(child, mod_id, key))
	elif value is String and (key.ends_with("_path") or key in ["path", "scene"]):
		var path := str(value)
		if path.begins_with("res://") and not is_owned_path(path, mod_id):
			errors.append("资源路径不属于当前 Mod: %s" % path)
	return errors


func is_owned_path(path: String, mod_id: String, extension: String = "") -> bool:
	if path.contains("..") or not path.begins_with("res://mods/%s/" % mod_id):
		return false
	return extension.is_empty() or path.get_extension().to_lower() == extension.trim_prefix(".").to_lower()


func is_semver(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?$")
	return regex.search(value) != null


func compare_versions(left: String, right: String) -> int:
	if not is_semver(left) or not is_semver(right):
		return 0
	var left_parts := left.split("-")[0].split(".")
	var right_parts := right.split("-")[0].split(".")
	for index in range(3):
		var delta := int(left_parts[index]) - int(right_parts[index])
		if delta != 0:
			return 1 if delta > 0 else -1
	var left_prerelease := left.substr(left.find("-") + 1) if left.contains("-") else ""
	var right_prerelease := right.substr(right.find("-") + 1) if right.contains("-") else ""
	if left_prerelease.is_empty() or right_prerelease.is_empty():
		if left_prerelease == right_prerelease:
			return 0
		return 1 if left_prerelease.is_empty() else -1
	var left_ids := left_prerelease.split(".")
	var right_ids := right_prerelease.split(".")
	for index in range(mini(left_ids.size(), right_ids.size())):
		var left_id := str(left_ids[index])
		var right_id := str(right_ids[index])
		if left_id == right_id:
			continue
		var left_numeric := left_id.is_valid_int()
		var right_numeric := right_id.is_valid_int()
		if left_numeric and right_numeric:
			return 1 if int(left_id) > int(right_id) else -1
		if left_numeric != right_numeric:
			return -1 if left_numeric else 1
		return 1 if left_id > right_id else -1
	if left_ids.size() == right_ids.size():
		return 0
	return 1 if left_ids.size() > right_ids.size() else -1


func version_in_range(version: String, range_data: Dictionary) -> bool:
	if not is_semver(version):
		return false
	var minimum := str(range_data.get("min", ""))
	var maximum := str(range_data.get("max_exclusive", ""))
	if not minimum.is_empty() and (not is_semver(minimum) or compare_versions(version, minimum) < 0):
		return false
	if not maximum.is_empty() and (not is_semver(maximum) or compare_versions(version, maximum) >= 0):
		return false
	return true
