extends Node

const RESULT_PATH := "res://.funplay/mod_example_smoke_result.txt"
const PACKAGE_PATH := "res://.funplay/example_mod_test.pck"
const TEST_ROOT := "res://.funplay/example_mod_install"
const MOD_ROOT := TEST_ROOT + "/mods"
const CONFIG_PATH := TEST_ROOT + "/mods.cfg"
const RuntimeScript = preload("res://scripts/modding/mod_api.gd")

var failures: Array[String] = []


func _ready() -> void:
	_prepare_install()
	var runtime = RuntimeScript.new()
	runtime.name = "ExampleModRuntime"
	runtime.mod_directory = MOD_ROOT
	runtime.config_path = CONFIG_PATH
	add_child(runtime)
	_expect(str(runtime.mod_record("com.example.guaji").get("status", "")) == "loaded", "example Mod loaded")
	_expect(runtime.content.has("skill", "com.example.guaji:storm"), "example skill registered")
	_expect(runtime.content.has("item", "com.example.guaji:storm_book"), "example item registered")
	_expect(runtime.content.has("appearance", "com.example.guaji:disciple"), "example appearance registered")
	_expect(runtime.content.has("dialogue", "com.example.guaji:meditation_line"), "example dialogue registered")
	_expect(runtime.effect_handler("com.example.guaji:spirit_burn").is_valid(), "effect handler registered")
	_expect(runtime.ai_condition("com.example.guaji:target_ready").is_valid(), "AI condition registered")
	_expect(runtime.dialogue_condition("com.example.guaji:level_two").is_valid(), "dialogue condition registered")
	_expect(runtime.actor_state_factory("com.example.guaji:meditating").is_valid(), "actor state registered")
	_test_scenes()
	runtime.notify_game_ready(null)
	var mod_data: Dictionary = runtime.export_save_data().get("mod_data", {})
	_expect(int(mod_data.get("com.example.guaji", {}).get("launches", 0)) == 1, "bound Mod storage persisted")
	_write_result()
	get_tree().quit(0 if failures.is_empty() else 1)


func _prepare_install() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOD_ROOT))
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(PACKAGE_PATH),
		ProjectSettings.globalize_path("%s/example_mod_test.pck" % MOD_ROOT)
	)
	_expect(copy_error == OK, "example PCK copied")
	var config := ConfigFile.new()
	config.set_value("mods", "order", PackedStringArray(["com.example.guaji"]))
	config.set_value("mod:com.example.guaji", "enabled", true)
	config.set_value("mod:com.example.guaji", "code_consent", "1.0.0")
	_expect(config.save(CONFIG_PATH) == OK, "example Mod config saved")


func _test_scenes() -> void:
	var skill_scene := load("res://mods/com.example.guaji/scenes/storm.tscn") as PackedScene
	_expect(skill_scene != null, "example skill scene loads")
	if skill_scene != null:
		var skill_instance = skill_scene.instantiate()
		_expect(skill_instance is SkillSceneBase, "example skill scene uses SkillSceneBase")
		skill_instance.free()
	var appearance_scene := load("res://mods/com.example.guaji/scenes/disciple.tscn") as PackedScene
	_expect(appearance_scene != null, "example appearance scene loads")
	if appearance_scene != null:
		var appearance_instance = appearance_scene.instantiate()
		_expect(appearance_instance is CombatVisual, "example appearance uses CombatVisual")
		if appearance_instance is CombatVisual:
			_expect(appearance_instance.contract_error().is_empty(), "example appearance contract is complete")
		appearance_instance.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _write_result() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("PASS" if failures.is_empty() else "FAIL\n%s" % "\n".join(failures))
