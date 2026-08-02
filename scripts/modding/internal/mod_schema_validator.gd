class_name ModSchemaValidator
extends RefCounted

const ModContentRegistryScript = preload("res://scripts/modding/api/mod_content_registry.gd")
const MANIFEST_SCHEMA_VERSION := 1
const MOD_API_VERSION := 1
const GAME_VERSION := "0.1.0"

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
	if int(document.get("schema_version", 0)) != 1:
		errors.append("内容文件 schema_version 必须为 1")
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
		"skill": ["name", "scene_path"],
		"basic_attack": ["name", "scene_path"],
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
	if kind in ["skill", "basic_attack"]:
		var target_scope := str(data.get("target_scope", "single_enemy"))
		if not ["self", "single_ally", "all_allies", "single_enemy", "all_enemies"].has(target_scope):
			errors.append("%s:%s target_scope 无效" % [kind, content_id])
		for field in ["mp_cost", "cooldown", "release_distance"]:
			if float(data.get(field, 0.0)) < 0.0:
				errors.append("%s:%s %s 不能为负数" % [kind, content_id, field])
		for field in ["base_damage", "damage_attribute_multiplier", "heal_amount", "heal_attribute_multiplier"]:
			if data.has(field) and (typeof(data.get(field)) not in [TYPE_INT, TYPE_FLOAT] or float(data.get(field)) < 0.0):
				errors.append("%s:%s %s 必须为非负数" % [kind, content_id, field])
		var effects = data.get("effects", [])
		if effects is Array:
			for effect in effects:
				if effect is Dictionary and effect.has("attribute_multiplier") and (typeof(effect.get("attribute_multiplier")) not in [TYPE_INT, TYPE_FLOAT] or float(effect.get("attribute_multiplier")) < 0.0):
					errors.append("%s:%s effect.attribute_multiplier 必须为非负数" % [kind, content_id])
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
