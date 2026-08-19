extends SceneTree

const ModSchemaValidatorScript = preload("res://scripts/modding/internal/mod_schema_validator.gd")
const SkillSceneRegistryScript = preload("res://scripts/game/skills/base/skill_scene_registry.gd")

const MOD_ID := "com.example.guaji"
const PACKED_ROOT := "res://mods/com.example.guaji"


func _init() -> void:
	var package_path := "res://artifacts/example_mod.pck"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		package_path = str(args[0])
	var errors: Array[String] = []
	if not ProjectSettings.load_resource_pack(package_path, false):
		errors.append("无法挂载示例包: %s" % package_path)
	else:
		_validate_example(errors)
	if errors.is_empty():
		print("MOD API 2 CONTRACT PASS")
		quit(0)
		return
	for error in errors:
		push_error(error)
	quit(1)


func _validate_example(errors: Array[String]) -> void:
	var validator = ModSchemaValidatorScript.new()
	var manifest := _read_json("%s/manifest.json" % PACKED_ROOT, errors)
	if manifest.is_empty():
		return
	errors.append_array(validator.validate_manifest(manifest, "%s/manifest.json" % PACKED_ROOT))
	for content_path in manifest.get("content", []):
		var document := _read_json(str(content_path), errors)
		if document.is_empty():
			continue
		errors.append_array(validator.validate_content_document(document))
		var kind := str(document.get("kind", ""))
		for entry in document.get("entries", []):
			if str(entry.get("operation", "")) != "add":
				continue
			var local_id := str(entry.get("local_id", ""))
			var data: Dictionary = entry.get("data", {})
			errors.append_array(validator.validate_owned_values(data, MOD_ID))
			if kind != "skill":
				errors.append_array(validator.validate_definition(kind, "%s:%s" % [MOD_ID, local_id], data))
	_validate_skill(validator, errors)


func _validate_skill(validator, errors: Array[String]) -> void:
	var registry = SkillSceneRegistryScript.new()
	var result: Dictionary = registry.register_mod_scene(
		"%s/scenes/storm.tscn" % PACKED_ROOT,
		MOD_ID,
		"storm"
	)
	if not bool(result.get("ok", false)):
		errors.append(str(result.get("error", "技能场景注册失败")))
		return
	var definition: Dictionary = result.get("definition", {})
	errors.append_array(validator.validate_definition("skill", "%s:storm" % MOD_ID, definition))
	errors.append_array(validator.validate_owned_values(definition, MOD_ID))


func _read_json(path: String, errors: Array[String]) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("无法读取 JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		errors.append("JSON 根节点不是对象: %s" % path)
		return {}
	return parsed
