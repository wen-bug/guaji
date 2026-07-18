extends Node

const RESULT_PATH := "res://.funplay/mod_api_contract_result.txt"
const ActorStateMachineScript = preload("res://scripts/modding/api/actor_state_machine.gd")
const ContentRegistryScript = preload("res://scripts/modding/api/mod_content_registry.gd")
const ContextScript = preload("res://scripts/modding/api/mod_context.gd")
const EventBusScript = preload("res://scripts/modding/api/mod_event_bus.gd")
const GameStateScript = preload("res://scripts/game/core/game_state.gd")
const RngScript = preload("res://scripts/modding/api/mod_rng.gd")
const StorageScript = preload("res://scripts/modding/api/mod_storage.gd")
const ValidatorScript = preload("res://scripts/modding/internal/mod_schema_validator.gd")

var failures: Array[String] = []


func _ready() -> void:
	_run()
	_write_result()
	get_tree().quit(0 if failures.is_empty() else 1)


func _run() -> void:
	_test_registry()
	_test_context()
	_test_services()
	_test_public_surface()
	_test_schemas()
	_test_document_json_examples()
	_test_orphan_round_trip()


func _test_registry() -> void:
	var registry = ContentRegistryScript.new()
	_expect(registry._define("item", "core_item", {"name": "Core", "type": "material"}, "core"), "core define")
	_expect(not registry._define("item", "core_item", {}, "other"), "duplicate define rejected")
	var value: Dictionary = registry.definition("item", "core_item")
	value["name"] = "Mutated"
	_expect(registry.definition("item", "core_item").get("name") == "Core", "registry returns deep copy")
	var merged: Dictionary = ContentRegistryScript.merge_patch({"a": {"b": 1}, "list": [1, 2]}, {"a": {"c": 2}, "list": [3]})
	_expect(merged == {"a": {"b": 1, "c": 2}, "list": [3]}, "RFC 7396 merge")
	registry._freeze()
	_expect(not registry._define("item", "late", {}, "test"), "frozen registry rejects mutation")


func _test_context() -> void:
	var storage = StorageScript.new()
	var rng = RngScript.new()
	var context = ContextScript.new("com.test.api", ["skill:heal"], storage, rng)
	_expect(context.define("skill", "storm", {"name": "Storm"}), "context define")
	_expect(str(context._operations[0].get("content_id", "")) == "com.test.api:storm", "namespace applied")
	_expect(context.patch("skill", "heal", {"mp_cost": 1}), "authorized patch")
	_expect(not context.patch("skill", "thunder", {}), "unauthorized patch rejected")


func _test_services() -> void:
	var storage = StorageScript.new()
	var scoped_storage = storage._view("com.test.api")
	scoped_storage.set_value("value", {"n": 1})
	var copy: Dictionary = scoped_storage.get_value("value", {})
	copy["n"] = 2
	_expect(scoped_storage.get_value("value", {}).get("n") == 1, "storage returns deep copy")
	_expect(storage.data_for("com.other").is_empty(), "storage namespace isolated")
	var rng = RngScript.new()
	var scoped_rng = rng._view("com.test.api")
	var first: RandomNumberGenerator = scoped_rng.stream("loot")
	var state := rng.export_state()
	var expected := first.randi()
	var restored = RngScript.new()
	restored.import_state(state)
	_expect(restored._view("com.test.api").stream("loot").randi() == expected, "RNG state round trip")
	var events = EventBusScript.new()
	_expect(not events.subscribe(&"unsupported", func(_payload): pass), "unsupported event rejected")
	var original_payload := {"nested": {"value": 1}}
	var observed := {"value": 0}
	events.subscribe(&"game_ready", func(payload): payload["nested"]["value"] = 2)
	events.subscribe(&"game_ready", func(payload): observed["value"] = int(payload.get("nested", {}).get("value", 0)))
	events.emit_event(&"game_ready", original_payload)
	_expect(int(original_payload.get("nested", {}).get("value", 0)) == 1, "event payload protects publisher data")
	_expect(int(observed.get("value", 0)) == 1, "each event listener receives an independent deep copy")


func _test_public_surface() -> void:
	var required := {
		"res://scripts/modding/api/mod_plugin.gd": {
			"register": ["context"],
			"on_game_ready": ["api"],
			"migrate_save": ["data", "from_version", "to_version"],
		},
		"res://scripts/modding/api/mod_context.gd": {
			"define": ["kind", "local_id", "data"],
			"patch": ["kind", "target_id", "patch_data"],
			"register_actor_state": ["local_id", "factory"],
			"register_effect_handler": ["local_id", "callback"],
			"register_ai_condition": ["local_id", "callback"],
			"register_dialogue_condition": ["local_id", "callback"],
		},
		"res://scripts/modding/api/mod_storage.gd": {
			"get_value": ["key", "fallback"],
			"set_value": ["key", "value"],
			"erase_value": ["key"],
			"all": [],
		},
		"res://scripts/modding/api/mod_rng.gd": {
			"stream": ["purpose"],
		},
		"res://scripts/modding/api/mod_event_bus.gd": {
			"subscribe": ["event_id", "callback"],
			"unsubscribe": ["event_id", "callback"],
		},
		"res://scripts/modding/api/actor_state.gd": {
			"can_enter": ["actor", "payload"],
			"enter": ["actor", "payload"],
			"update": ["actor", "delta"],
			"handle_event": ["actor", "event_id", "payload"],
			"exit": ["actor"],
		},
		"res://scripts/modding/api/mod_content_registry.gd": {
			"definition": ["kind", "content_id", "fallback"],
			"has": ["kind", "content_id"],
			"ids": ["kind"],
			"source_of": ["kind", "content_id"],
			"all": ["kind"],
		},
		"res://scripts/game/skills/base/skill_scene_base.gd": {
			"setup": ["skill_caster", "skill_targets", "data", "resolver", "random_source"],
			"start_cast": [],
			"apply_marker": ["marker"],
			"finish_cast": [],
			"primary_target": [],
			"add_event": ["event"],
		},
		"res://scripts/actors/visuals/combat_visual.gd": {
			"configure_identity": ["value_actor_id", "value_team"],
			"play_idle": [],
			"play_walk": [],
			"play_run": [],
			"play_melee_attack": ["action_id"],
			"play_ranged_attack": ["action_id"],
			"play_hurt": [],
			"play_death": [],
			"play_level_up": [],
			"cancel_action": [],
			"contract_error": [],
			"set_hit_points": ["current_hp", "max_hp"],
		},
	}
	var global_names := {
		"res://scripts/modding/api/mod_plugin.gd": "ModPlugin",
		"res://scripts/modding/api/mod_context.gd": "ModContext",
		"res://scripts/modding/api/actor_state.gd": "ActorState",
		"res://scripts/modding/api/mod_content_registry.gd": "ModContentRegistry",
		"res://scripts/modding/api/mod_event_bus.gd": "ModEventBus",
		"res://scripts/modding/api/mod_storage.gd": "ModStorage",
		"res://scripts/modding/api/mod_rng.gd": "ModRng",
		"res://scripts/game/skills/base/skill_scene_base.gd": "SkillSceneBase",
		"res://scripts/actors/visuals/combat_visual.gd": "CombatVisual",
	}
	for path in required.keys():
		var script := load(path) as Script
		_expect(script != null, "public script loads: %s" % path)
		if script == null:
			continue
		_expect(script.get_global_name() == global_names.get(path, ""), "public class name changed: %s" % path)
		var actual: Dictionary = {}
		for method in script.get_script_method_list():
			var argument_names: Array[String] = []
			for argument in method.get("args", []):
				argument_names.append(str(argument.get("name", "")).trim_prefix("_"))
			actual[str(method.get("name", ""))] = argument_names
		for method_name in required[path]:
			_expect(actual.has(method_name), "%s exposes %s" % [path, method_name])
			if actual.has(method_name):
				_expect(actual[method_name] == required[path][method_name], "%s signature changed: %s" % [path, method_name])
	var machine = ActorStateMachineScript.new()
	_expect(machine.has_method("transition") and machine.has_method("handle_event"), "actor state machine surface")
	var api := get_node_or_null("/root/ModAPI")
	_expect(api != null and int(api.MOD_API_VERSION) == 1, "ModAPI version remains 1")


func _test_schemas() -> void:
	var schema_root := "res://docs/modding/schemas/v1"
	var directory := DirAccess.open(schema_root)
	_expect(directory != null, "schema directory exists")
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.get_extension() != "json":
			continue
		var file := FileAccess.open("%s/%s" % [schema_root, file_name], FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		_expect(parsed is Dictionary and str(parsed.get("$schema", "")).contains("2020-12"), "valid schema: %s" % file_name)
	var validator = ValidatorScript.new()
	var manifest := {
		"schema_version": 1,
		"id": "com.test.valid",
		"name": "Valid",
		"version": "1.0.0",
		"mod_api_version": 1,
		"game_version": {"min": "0.1.0", "max_exclusive": "0.2.0"},
		"content": [],
	}
	_expect(validator.validate_manifest(manifest, "res://mods/com.test.valid/manifest.json").is_empty(), "valid manifest accepted")


func _test_document_json_examples() -> void:
	var validator = ValidatorScript.new()
	var docs := DirAccess.open("res://docs/modding")
	_expect(docs != null, "modding docs directory exists")
	if docs == null:
		return
	var example_count := 0
	for file_name in docs.get_files():
		if file_name.get_extension() != "md":
			continue
		var file := FileAccess.open("res://docs/modding/%s" % file_name, FileAccess.READ)
		if file == null:
			continue
		var in_json := false
		var buffer: Array[String] = []
		for line in file.get_as_text().split("\n"):
			if not in_json and line.strip_edges() == "```json":
				in_json = true
				buffer.clear()
			elif in_json and line.strip_edges() == "```":
				in_json = false
				example_count += 1
				var parsed = JSON.parse_string("\n".join(buffer))
				_expect(parsed is Dictionary, "JSON example parses: %s #%d" % [file_name, example_count])
				if parsed is Dictionary and parsed.has("kind"):
					_expect(validator.validate_content_document(parsed).is_empty(), "content example validates: %s" % file_name)
					for entry in parsed.get("entries", []):
						if entry is Dictionary and entry.get("operation", "") == "add":
							var local_id := str(entry.get("local_id", "example"))
							var content_id := "com.docs.example:%s" % local_id
							_expect(validator.validate_definition(str(parsed.get("kind", "")), content_id, entry.get("data", {})).is_empty(), "definition example validates: %s:%s" % [file_name, local_id])
				elif parsed is Dictionary and parsed.has("mod_api_version"):
					var mod_id := str(parsed.get("id", "com.docs.example"))
					_expect(validator.validate_manifest(parsed, "res://mods/%s/manifest.json" % mod_id).is_empty(), "manifest example validates: %s" % file_name)
			elif in_json:
				buffer.append(line)
	_expect(example_count > 0, "modding docs contain JSON examples")


func _test_orphan_round_trip() -> void:
	var state = GameStateScript.new()
	state.load_save_data({
		"schema_version": 10,
		"inventory": [{
			"instance_id": "com.test.missing:item",
			"item_id": "com.test.missing:item",
			"name": "Missing",
			"type": "material",
			"count": 1,
		}],
		"companions": [{
			"id": "test_orphan_member",
			"name": "Test",
			"visual_id": "actor_default",
			"skills": [{"id": "com.test.missing:skill", "name": "Missing Skill"}],
			"innate_traits": [],
		}],
		"party_order": ["test_orphan_member"],
	})
	_expect(state.inventory_item_by_instance("com.test.missing:item").is_empty(), "missing item quarantined")
	_expect(state.orphaned_mod_data.get("inventory", []).size() == 1, "orphan item retained")
	_expect(state.orphaned_mod_data.get("skills", []).size() == 1, "orphan skill retained")
	var repeated_save := state.to_save_data()
	state.load_save_data(repeated_save)
	_expect(state.orphaned_mod_data.get("inventory", []).size() == 1, "repeated load does not duplicate orphan item")
	_expect(state.orphaned_mod_data.get("skills", []).size() == 1, "repeated load does not duplicate orphan skill")
	var api := get_node_or_null("/root/ModAPI")
	if api == null:
		_expect(false, "ModAPI autoload exists")
		return
	var snapshot: Dictionary = api.content._snapshot()
	api.content._frozen = false
	api.content._define("item", "com.test.missing:item", {"name": "Restored", "type": "material"}, "com.test.missing")
	api.content._define("skill", "com.test.missing:skill", {"name": "Restored", "scene_path": "res://scripts/game/skills/damage/direct_damage_skill.tscn"}, "com.test.missing")
	state._restore_available_mod_content()
	_expect(not state.inventory_item_by_instance("com.test.missing:item").is_empty(), "orphan item restored")
	_expect(state.member_by_id("test_orphan_member").get("skills", []).size() == 1, "orphan skill restored")
	api.content._restore(snapshot)
	api.content._frozen = true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _write_result() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("PASS" if failures.is_empty() else "FAIL\n%s" % "\n".join(failures))
