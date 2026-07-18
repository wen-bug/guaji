extends Node

const ActorStateScript = preload("res://scripts/modding/api/actor_state.gd")
const DialogueServiceScript = preload("res://scripts/modding/internal/dialogue_service.gd")
const ModContentRegistryScript = preload("res://scripts/modding/api/mod_content_registry.gd")
const ModContextScript = preload("res://scripts/modding/api/mod_context.gd")
const ModEventBusScript = preload("res://scripts/modding/api/mod_event_bus.gd")
const ModPluginScript = preload("res://scripts/modding/api/mod_plugin.gd")
const ModRngScript = preload("res://scripts/modding/api/mod_rng.gd")
const ModSchemaValidatorScript = preload("res://scripts/modding/internal/mod_schema_validator.gd")
const ModStorageScript = preload("res://scripts/modding/api/mod_storage.gd")
const MOD_API_VERSION := 1
const GAME_VERSION := "0.1.0"
const MOD_CONFIG_PATH := "user://mods.cfg"
const MOD_DIRECTORY := "user://mods"

var content = ModContentRegistryScript.new()
var events = ModEventBusScript.new()
var storage = ModStorageScript.new()
var rng = ModRngScript.new()
var dialogues = DialogueServiceScript.new()

var _validator = ModSchemaValidatorScript.new()
var _manifests: Dictionary = {}
var _mod_records: Dictionary = {}
var _plugins: Dictionary = {}
var _actor_states: Dictionary = {}
var _effect_handlers: Dictionary = {}
var _ai_conditions: Dictionary = {}
var _dialogue_conditions: Dictionary = {}
var _config := ConfigFile.new()
var _pending_restart := false
var config_path := MOD_CONFIG_PATH
var mod_directory := MOD_DIRECTORY


func _ready() -> void:
	_load_config()
	_register_core_content()
	dialogues.setup(content, dialogue_condition)
	_discover_packages()
	var load_order := _resolve_load_order()
	for mod_id in load_order:
		_register_mod(str(mod_id))
	content._freeze()


func installed_mods() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mod_id in _ordered_mod_ids():
		var record: Dictionary = _mod_records.get(mod_id, {}).duplicate(true)
		record.erase("manifest")
		result.append(record)
	return result


func mod_record(mod_id: String) -> Dictionary:
	var result: Dictionary = _mod_records.get(mod_id, {}).duplicate(true)
	result.erase("manifest")
	return result


func has_pending_restart() -> bool:
	return _pending_restart


func set_mod_enabled(mod_id: String, enabled: bool) -> bool:
	if not _mod_records.has(mod_id):
		return false
	_config.set_value("mod:%s" % mod_id, "enabled", enabled)
	_config.save(config_path)
	_pending_restart = true
	return true


func grant_code_consent(mod_id: String) -> bool:
	if not _manifests.has(mod_id):
		return false
	var version := str((_manifests[mod_id] as Dictionary).get("version", ""))
	_config.set_value("mod:%s" % mod_id, "code_consent", version)
	_config.set_value("mod:%s" % mod_id, "enabled", true)
	_config.save(config_path)
	_pending_restart = true
	return true


func move_mod(mod_id: String, direction: int) -> bool:
	var order := _configured_order()
	var index := order.find(mod_id)
	if index < 0:
		return false
	var target := clampi(index + signi(direction), 0, order.size() - 1)
	if target == index:
		return false
	var swap_value = order[target]
	order[target] = order[index]
	order[index] = swap_value
	_config.set_value("mods", "order", PackedStringArray(order))
	_config.save(config_path)
	_pending_restart = true
	return true


func actor_state_factory(state_id: String) -> Callable:
	return _actor_states.get(state_id, Callable())


func effect_handler(kind: String) -> Callable:
	return _effect_handlers.get(kind, Callable())


func ai_condition(condition_id: String) -> Callable:
	return _ai_conditions.get(condition_id, Callable())


func dialogue_condition(condition_id: String) -> Callable:
	return _dialogue_conditions.get(condition_id, Callable())


func pick_dialogue(context: Dictionary, random: RandomNumberGenerator) -> Dictionary:
	return dialogues.pick_line(context, random)


func actor_state_instance(state_id: String):
	var factory := actor_state_factory(state_id)
	return factory.call() if factory.is_valid() else null


func import_save_data(data: Dictionary) -> void:
	storage.import_data(data.get("mod_data", {}))
	rng.import_state(data.get("mod_rng", {}))
	var previous_profile: Dictionary = data.get("mod_profile", {})
	for mod_id in _plugins.keys():
		var plugin = _plugins[mod_id]
		var previous_version := str(previous_profile.get(mod_id, {}).get("version", ""))
		var current_version := str((_manifests.get(mod_id, {}) as Dictionary).get("version", ""))
		if not previous_version.is_empty() and previous_version != current_version:
			var migrated = plugin.migrate_save(storage.data_for(str(mod_id)), previous_version, current_version)
			if migrated is Dictionary:
				storage.replace_data_for(str(mod_id), migrated)
			else:
				_fail_record(str(mod_id), ["migrate_save 必须返回 Dictionary"])
	events.emit_event(ModEventBusScript.EVENT_SAVE_LOADED, {
		"mod_profile": previous_profile.duplicate(true),
		"orphaned_mod_data": data.get("orphaned_mod_data", {}).duplicate(true),
	})


func export_save_data() -> Dictionary:
	var profile: Dictionary = {}
	for mod_id in _plugins.keys():
		var manifest: Dictionary = _manifests.get(mod_id, {})
		profile[mod_id] = {
			"version": str(manifest.get("version", "")),
			"fingerprint": "%s@%s" % [mod_id, manifest.get("version", "")],
		}
	return {
		"mod_profile": profile,
		"mod_data": storage.export_data(),
		"mod_rng": rng.export_state(),
	}


func notify_game_ready(game_state = null) -> void:
	for mod_id in _plugins.keys():
		var plugin = _plugins[mod_id]
		plugin.on_game_ready(self)
	events.emit_event(ModEventBusScript.EVENT_GAME_READY, {
		"game_version": GAME_VERSION,
		"mod_api_version": MOD_API_VERSION,
	})


func emit_event(event_id: StringName, payload: Dictionary = {}) -> void:
	events.emit_event(event_id, payload)


func _load_config() -> void:
	if _config.load(config_path) != OK:
		_config = ConfigFile.new()


func _discover_packages() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(mod_directory))
	var directory := DirAccess.open(mod_directory)
	if directory == null:
		return
	var package_files: Array[String] = []
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() in ["pck", "zip"]:
			package_files.append(file_name)
	package_files.sort()
	var known_manifests := _manifest_paths()
	for file_name in package_files:
		var package_path := "%s/%s" % [mod_directory, file_name]
		if not ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(package_path), false):
			_push_package_error(file_name, "无法挂载资源包")
			continue
		var current_manifests := _manifest_paths()
		var added: Array[String] = []
		for path in current_manifests:
			if not known_manifests.has(path):
				added.append(path)
		known_manifests = current_manifests
		if added.size() != 1:
			_push_package_error(file_name, "每个包必须新增且只新增一个 manifest.json")
			continue
		_load_manifest(added[0], file_name)
	_append_new_mods_to_order()


func _manifest_paths() -> Array[String]:
	var result: Array[String] = []
	var root := DirAccess.open("res://mods")
	if root == null:
		return result
	for directory_name in root.get_directories():
		var path := "res://mods/%s/manifest.json" % directory_name
		if FileAccess.file_exists(path):
			result.append(path)
	result.sort()
	return result


func _load_manifest(path: String, package_name: String) -> void:
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary:
		_push_package_error(package_name, "Manifest 不是 JSON 对象")
		return
	var manifest: Dictionary = parsed
	var errors: Array[String] = _validator.validate_manifest(manifest, path)
	var mod_id := str(manifest.get("id", package_name))
	if _manifests.has(mod_id):
		errors.append("存在重复 Mod ID")
	var record := {
		"id": mod_id,
		"name": str(manifest.get("name", mod_id)),
		"version": str(manifest.get("version", "")),
		"package": package_name,
		"enabled": false,
		"loaded": false,
		"status": "invalid" if not errors.is_empty() else "discovered",
		"errors": errors,
		"contains_code": not str(manifest.get("entry_script", "")).is_empty(),
	}
	_mod_records[mod_id] = record
	if errors.is_empty():
		_manifests[mod_id] = manifest


func _resolve_load_order() -> Array[String]:
	var configured := _configured_order()
	var candidates: Dictionary = {}
	for mod_id in configured:
		if not _manifests.has(mod_id):
			continue
		var manifest: Dictionary = _manifests[mod_id]
		var section := "mod:%s" % mod_id
		var contains_code := not str(manifest.get("entry_script", "")).is_empty()
		var default_enabled := not contains_code
		var enabled := bool(_config.get_value(section, "enabled", default_enabled))
		var consent := str(_config.get_value(section, "code_consent", ""))
		var record: Dictionary = _mod_records[mod_id]
		record["enabled"] = enabled
		if contains_code and enabled and consent != str(manifest.get("version", "")):
			record["status"] = "permission_required"
			record["errors"] = ["代码 Mod 需要为当前版本授予执行许可"]
			continue
		if enabled:
			candidates[mod_id] = true
			record["status"] = "pending"
	_resolve_missing_dependencies(candidates)
	_resolve_conflicts(candidates, configured)
	var resolved: Array[String] = []
	var remaining: Array[String] = []
	for mod_id in configured:
		if candidates.has(mod_id):
			remaining.append(mod_id)
	while not remaining.is_empty():
		var progressed := false
		for mod_id in remaining.duplicate():
			if _dependencies_resolved(mod_id, remaining):
				resolved.append(mod_id)
				remaining.erase(mod_id)
				progressed = true
		if not progressed:
			for mod_id in remaining:
				_disable_record(mod_id, "检测到依赖或 load_after 循环")
			break
	return resolved


func _resolve_missing_dependencies(candidates: Dictionary) -> void:
	var changed := true
	while changed:
		changed = false
		for mod_id in candidates.keys().duplicate():
			var manifest: Dictionary = _manifests[mod_id]
			for dependency in manifest.get("dependencies", []):
				if bool(dependency.get("optional", false)):
					continue
				var dependency_id := str(dependency.get("id", ""))
				if not candidates.has(dependency_id) or not _dependency_version_matches(dependency):
					candidates.erase(mod_id)
					_disable_record(mod_id, "缺失或不兼容的依赖: %s" % dependency_id)
					changed = true
					break


func _resolve_conflicts(candidates: Dictionary, configured: Array[String]) -> void:
	for mod_id in configured.duplicate():
		if not candidates.has(mod_id):
			continue
		var manifest: Dictionary = _manifests[mod_id]
		for conflict_id in manifest.get("conflicts", []):
			var other := str(conflict_id)
			if not candidates.has(other):
				continue
			var loser: String = mod_id if configured.find(mod_id) < configured.find(other) else other
			candidates.erase(loser)
			_disable_record(loser, "与高优先级 Mod 冲突: %s" % (other if loser == mod_id else mod_id))


func _dependencies_resolved(mod_id: String, remaining: Array[String]) -> bool:
	var manifest: Dictionary = _manifests[mod_id]
	for dependency in manifest.get("dependencies", []):
		var dependency_id := str(dependency.get("id", ""))
		if remaining.has(dependency_id):
			return false
	for after_id in manifest.get("load_after", []):
		if remaining.has(str(after_id)):
			return false
	return true


func _register_mod(mod_id: String) -> void:
	var manifest: Dictionary = _manifests[mod_id]
	for dependency in manifest.get("dependencies", []):
		if bool(dependency.get("optional", false)):
			continue
		var dependency_id := str(dependency.get("id", ""))
		if not bool((_mod_records.get(dependency_id, {}) as Dictionary).get("loaded", false)):
			_disable_record(mod_id, "依赖加载失败: %s" % dependency_id)
			return
	var scoped_storage = storage._view(mod_id)
	var scoped_rng = rng._view(mod_id)
	var context = ModContextScript.new(mod_id, manifest.get("overrides", []), scoped_storage, scoped_rng)
	for content_path in manifest.get("content", []):
		_stage_content_file(context, str(content_path))
	var plugin = null
	var entry_script := str(manifest.get("entry_script", ""))
	if not entry_script.is_empty() and context.errors().is_empty():
		var script := load(entry_script) as Script
		if script == null:
			context.fail("entry_script_load_failed", "入口脚本无法加载")
		else:
			var instance = script.new()
			if instance is ModPluginScript:
				plugin = instance
				plugin._bind_runtime(mod_id, scoped_storage, scoped_rng)
				plugin.register(context)
			else:
				context.fail("entry_script_type", "入口脚本必须继承 ModPlugin")
	if not context.errors().is_empty():
		_fail_record(mod_id, context.errors())
		return
	var error := _commit_context(context)
	if not error.is_empty():
		_fail_record(mod_id, [error])
		return
	if plugin != null:
		_plugins[mod_id] = plugin
	var record: Dictionary = _mod_records[mod_id]
	record["loaded"] = true
	record["status"] = "loaded"
	record["errors"] = []


func _stage_content_file(context, path: String) -> void:
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary:
		context.fail("content_json", "内容文件不是 JSON 对象: %s" % path)
		return
	var document: Dictionary = parsed
	var errors: Array[String] = _validator.validate_content_document(document)
	if not errors.is_empty():
		for error in errors:
			context.fail("content_schema", "%s: %s" % [path, error])
		return
	var kind := str(document.get("kind", ""))
	for entry in document.get("entries", []):
		if not entry is Dictionary:
			context.fail("content_entry", "entries 元素必须为对象")
			continue
		match str(entry.get("operation", "")):
			"add":
				context.define(kind, str(entry.get("local_id", "")), entry.get("data", {}))
			"patch":
				context.patch(kind, str(entry.get("target_id", "")), entry.get("patch", {}))
			_:
				context.fail("content_operation", "不支持的 operation")


func _commit_context(context) -> String:
	var content_snapshot: Dictionary = content._snapshot()
	var actor_snapshot := _actor_states.duplicate()
	var effect_snapshot := _effect_handlers.duplicate()
	var ai_snapshot := _ai_conditions.duplicate()
	var dialogue_snapshot := _dialogue_conditions.duplicate()
	var staged_definitions: Array[Dictionary] = []
	for operation in context._operations:
		var kind := str(operation.get("kind", ""))
		var content_id := str(operation.get("content_id", ""))
		if not ModContentRegistryScript.KINDS.has(kind):
			_restore_transaction(content_snapshot, actor_snapshot, effect_snapshot, ai_snapshot, dialogue_snapshot)
			return "不支持的内容 kind: %s" % kind
		var data: Dictionary
		if operation.get("operation", "") == "add":
			data = operation.get("data", {}).duplicate(true)
			var path_errors: Array[String] = _validator.validate_owned_values(data, context.mod_id)
			if not path_errors.is_empty():
				_restore_transaction(content_snapshot, actor_snapshot, effect_snapshot, ai_snapshot, dialogue_snapshot)
				return path_errors[0]
			if content.has(kind, content_id):
				_restore_transaction(content_snapshot, actor_snapshot, effect_snapshot, ai_snapshot, dialogue_snapshot)
				return "内容 ID 已存在: %s:%s" % [kind, content_id]
		else:
			if not content.has(kind, content_id):
				_restore_transaction(content_snapshot, actor_snapshot, effect_snapshot, ai_snapshot, dialogue_snapshot)
				return "覆盖目标不存在: %s:%s" % [kind, content_id]
			var patch_data: Dictionary = operation.get("patch", {})
			var path_errors: Array[String] = _validator.validate_owned_values(patch_data, context.mod_id)
			if not path_errors.is_empty():
				_restore_transaction(content_snapshot, actor_snapshot, effect_snapshot, ai_snapshot, dialogue_snapshot)
				return path_errors[0]
			data = ModContentRegistryScript.merge_patch(content.definition(kind, content_id), patch_data)
		var definition_errors: Array[String] = _validator.validate_definition(kind, content_id, data)
		if not definition_errors.is_empty():
			_restore_transaction(content_snapshot, actor_snapshot, effect_snapshot, ai_snapshot, dialogue_snapshot)
			return definition_errors[0]
		var applied: bool = content._define(kind, content_id, data, context.mod_id) if operation.get("operation", "") == "add" else content._replace(kind, content_id, data, context.mod_id)
		if not applied:
			_restore_transaction(content_snapshot, actor_snapshot, effect_snapshot, ai_snapshot, dialogue_snapshot)
			return "无法提交内容: %s:%s" % [kind, content_id]
		staged_definitions.append({"kind": kind, "content_id": content_id, "data": data.duplicate(true)})
	_actor_states.merge(context._actor_states, true)
	_effect_handlers.merge(context._effect_handlers, true)
	_ai_conditions.merge(context._ai_conditions, true)
	_dialogue_conditions.merge(context._dialogue_conditions, true)
	if not context.errors().is_empty():
		_restore_transaction(content_snapshot, actor_snapshot, effect_snapshot, ai_snapshot, dialogue_snapshot)
		return context.errors()[0]
	for staged in staged_definitions:
		var reference_error := _validate_references(
			str(staged.get("kind", "")),
			str(staged.get("content_id", "")),
			staged.get("data", {}),
			context.mod_id
		)
		if not reference_error.is_empty():
			_restore_transaction(content_snapshot, actor_snapshot, effect_snapshot, ai_snapshot, dialogue_snapshot)
			return reference_error
	return ""


func _restore_transaction(
	content_snapshot: Dictionary,
	actor_snapshot: Dictionary,
	effect_snapshot: Dictionary,
	ai_snapshot: Dictionary,
	dialogue_snapshot: Dictionary
) -> void:
	content._restore(content_snapshot)
	_actor_states = actor_snapshot
	_effect_handlers = effect_snapshot
	_ai_conditions = ai_snapshot
	_dialogue_conditions = dialogue_snapshot


func _validate_references(kind: String, content_id: String, data: Dictionary, owner_mod_id: String) -> String:
	for field in ["scene_path", "resource_path", "icon_path"]:
		var path := str(data.get(field, ""))
		if not path.is_empty() and not ResourceLoader.exists(path):
			return "%s:%s 引用的资源不存在: %s" % [kind, content_id, path]
	if kind == "item":
		var skill_id := str(data.get("payload", {}).get("skill_id", "")) if data.get("payload", {}) is Dictionary else ""
		if not skill_id.is_empty():
			var error := _content_reference_error("skill", skill_id, owner_mod_id, "技能书")
			if not error.is_empty():
				return error
	if kind == "recipe":
		var error := _content_reference_error("item", str(data.get("result_item_id", "")), owner_mod_id, "配方产物")
		if not error.is_empty():
			return error
		for material in data.get("materials", []):
			if material is Dictionary:
				error = _content_reference_error("item", str(material.get("item_id", "")), owner_mod_id, "配方材料")
				if not error.is_empty():
					return error
	if kind == "enemy":
		var visual_error := _content_reference_error("appearance", str(data.get("visual_id", "")), owner_mod_id, "敌人形象")
		if not visual_error.is_empty():
			return visual_error
		for skill_id in data.get("skills", []):
			var error := _content_reference_error("skill", str(skill_id), owner_mod_id, "敌人技能")
			if not error.is_empty():
				return error
	if kind == "appearance":
		var fallback_id := str(data.get("fallback_id", ""))
		if not fallback_id.is_empty():
			var error := _content_reference_error("appearance", fallback_id, owner_mod_id, "形象回退")
			if not error.is_empty():
				return error
			error = _appearance_cycle_error(content_id)
			if not error.is_empty():
				return error
	if kind in ["skill", "basic_attack"]:
		for trigger in data.get("trigger", []):
			var trigger_id := str(trigger)
			if trigger_id in ["always", "hp_below_50", "hp_below_35", "target_hp_below_35"]:
				continue
			var error := _callable_reference_error(_ai_conditions, trigger_id, owner_mod_id, "AI condition")
			if not error.is_empty():
				return error
		for effect in data.get("effects", []):
			if not (effect is Dictionary):
				continue
			var effect_kind := str(effect.get("kind", ""))
			if effect_kind in [
				"damage_percent", "damage_flat", "defense_ignore", "element_attach",
				"dot", "hot", "shield", "heal", "leech", "buff_stat",
				"debuff_stat", "cooldown_percent"
			]:
				continue
			var error := _callable_reference_error(_effect_handlers, effect_kind, owner_mod_id, "effect handler")
			if not error.is_empty():
				return error
	if kind == "dialogue":
		for condition_id in data.get("custom_conditions", []):
			var error := _callable_reference_error(_dialogue_conditions, str(condition_id), owner_mod_id, "dialogue condition")
			if not error.is_empty():
				return error
	return ""


func _content_reference_error(kind: String, target_id: String, owner_mod_id: String, label: String) -> String:
	if target_id.is_empty() or not content.has(kind, target_id):
		return "%s引用不存在: %s:%s" % [label, kind, target_id]
	if not _reference_namespace_allowed(target_id, owner_mod_id):
		return "%s未声明对应硬依赖: %s" % [label, target_id]
	return ""


func _callable_reference_error(registry: Dictionary, target_id: String, owner_mod_id: String, label: String) -> String:
	if target_id.is_empty() or not registry.has(target_id):
		return "%s 不存在: %s" % [label, target_id]
	if not _reference_namespace_allowed(target_id, owner_mod_id):
		return "%s 未声明对应硬依赖: %s" % [label, target_id]
	return ""


func _reference_namespace_allowed(target_id: String, owner_mod_id: String) -> bool:
	if not target_id.contains(":"):
		return true
	var source_namespace := target_id.get_slice(":", 0)
	if source_namespace == owner_mod_id:
		return true
	for dependency in (_manifests.get(owner_mod_id, {}) as Dictionary).get("dependencies", []):
		if not bool(dependency.get("optional", false)) and str(dependency.get("id", "")) == source_namespace:
			return true
	return false


func _appearance_cycle_error(start_id: String) -> String:
	var current_id := start_id
	var visited: Dictionary = {}
	while not current_id.is_empty() and content.has("appearance", current_id):
		if visited.has(current_id):
			return ""
		visited[current_id] = true
		var fallback_id := str(content.definition("appearance", current_id).get("fallback_id", ""))
		if fallback_id == start_id:
			return "appearance:%s 存在循环 fallback_id" % start_id
		current_id = fallback_id
	return ""


func _register_core_content() -> void:
	_register_core_kind("item", DataTables.ITEM_DEFS)
	_register_core_kind("equipment", DataTables.EQUIPMENT_DEFS)
	_register_core_kind("skill", DataTables.SKILL_DEFS)
	_register_core_kind("basic_attack", DataTables.BASIC_ATTACK_DEFS)
	_register_core_kind("recipe", DataTables.ALCHEMY_RECIPE_DEFS)
	_register_core_kind("trait", DataTables.INNATE_TRAIT_DEFS)
	for enemy_id in DataTables.ENEMY_TEMPLATES.keys():
		var enemy_definition: Dictionary = DataTables.ENEMY_TEMPLATES[enemy_id].duplicate(true)
		enemy_definition["scene_path"] = str(DataTables.ENEMY_SCENE_PATHS.get(enemy_id, ""))
		content._define("enemy", str(enemy_id), enemy_definition, "core")
	_register_core_kind("enemy_rank", DataTables.ENEMY_RANK_DEFS)
	content._define("drop_table", "enemy_drop_categories", {"categories": DataTables.ENEMY_DROP_CATEGORY_ITEMS.duplicate(true)}, "core")
	for state_id in ["idle", "roaming", "talking", "paused", "expedition_running", "combat_ready", "combat_moving", "combat_acting", "dead"]:
		_actor_states["core:%s" % state_id] = ActorStateScript.new
	for visual_id in ["actor_default"]:
		content._define("appearance", visual_id, {"kind": "party", "scene_path": "res://scripts/actors/visuals/party/%s.tscn" % visual_id, "fallback_id": "actor_default", "contract_version": 1}, "core")
	for visual_id in ["enemy_default", "forest_wolf", "training_dummy"]:
		content._define("appearance", visual_id, {"kind": "enemy", "scene_path": "res://scripts/actors/visuals/enemies/%s.tscn" % visual_id, "fallback_id": "enemy_default", "contract_version": 1}, "core")
	var lines := ["今天也要稳稳修行。", "家里真清静。", "等一个新任务。", "先散散步。"]
	for index in range(lines.size()):
		content._define("dialogue", "home_idle_%d" % index, {"text": lines[index], "scenes": ["home"], "states": ["idle"], "weight": 1.0, "cooldown_seconds": 0.0}, "core")


func _register_core_kind(kind: String, values: Dictionary) -> void:
	for content_id in values.keys():
		content._define(kind, str(content_id), values[content_id], "core")


func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data


func _configured_order() -> Array[String]:
	var result: Array[String] = []
	for value in _config.get_value("mods", "order", PackedStringArray()):
		result.append(str(value))
	for mod_id in _manifests.keys():
		if not result.has(str(mod_id)):
			result.append(str(mod_id))
	return result


func _append_new_mods_to_order() -> void:
	var order := _configured_order()
	_config.set_value("mods", "order", PackedStringArray(order))
	_config.save(config_path)


func _ordered_mod_ids() -> Array[String]:
	var order := _configured_order()
	for mod_id in _mod_records.keys():
		if not order.has(str(mod_id)):
			order.append(str(mod_id))
	return order


func _dependency_version_matches(dependency: Dictionary) -> bool:
	var dependency_id := str(dependency.get("id", ""))
	if not _manifests.has(dependency_id):
		return false
	var version := str((_manifests[dependency_id] as Dictionary).get("version", ""))
	var range_data := {
		"min": str(dependency.get("min_version", "")),
		"max_exclusive": str(dependency.get("max_version_exclusive", "")),
	}
	return _validator.version_in_range(version, range_data)


func _disable_record(mod_id: String, message: String) -> void:
	if not _mod_records.has(mod_id):
		return
	var record: Dictionary = _mod_records[mod_id]
	record["status"] = "disabled"
	record["loaded"] = false
	record["errors"] = [message]


func _fail_record(mod_id: String, errors: Array) -> void:
	var record: Dictionary = _mod_records[mod_id]
	record["status"] = "failed"
	record["loaded"] = false
	record["errors"] = errors.duplicate()


func _push_package_error(package_name: String, message: String) -> void:
	var key := "package:%s" % package_name
	_mod_records[key] = {
		"id": key,
		"name": package_name,
		"version": "",
		"package": package_name,
		"enabled": false,
		"loaded": false,
		"status": "invalid",
		"errors": [message],
		"contains_code": false,
	}
