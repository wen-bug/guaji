extends Node

const RESULT_PATH := "res://.funplay/mod_package_smoke_result.txt"
const RuntimeScript = preload("res://scripts/modding/mod_api.gd")
const TEST_ROOT := "res://.funplay/mod_api_test"
const MOD_ROOT := TEST_ROOT + "/mods"

var failures: Array[String] = []


func _ready() -> void:
	_prepare_directory()
	_create_pck("a_library.pck", "com.test.pck", "pck_item", [], true)
	_create_zip("b_dependent.zip", "com.test.zip", "zip_item", [
		{"id": "com.test.pck", "min_version": "1.0.0", "max_version_exclusive": "2.0.0", "optional": false},
	])
	_create_patch_zip("c_patch.zip")
	_create_pck("d_bad.pck", "com.test.bad", "bad_item", [], false)
	var runtime = RuntimeScript.new()
	runtime.name = "TestModRuntime"
	runtime.mod_directory = MOD_ROOT
	runtime.config_path = TEST_ROOT + "/mods.cfg"
	add_child(runtime)
	_expect(runtime.content.has("item", "com.test.pck:pck_item"), "PCK content loaded")
	_expect(runtime.content.has("item", "com.test.zip:zip_item"), "ZIP content loaded")
	_expect(runtime.content.definition("item", "com.test.pck:pck_item").get("name", "") == "patched_item", "authorized patch applied in load order")
	_expect(not runtime.content.has("item", "com.test.bad:bad_item"), "invalid Mod transaction rolled back")
	_expect(str(runtime.mod_record("com.test.pck").get("status", "")) == "loaded", "PCK status loaded")
	_expect(str(runtime.mod_record("com.test.zip").get("status", "")) == "loaded", "dependent ZIP status loaded")
	_expect(str(runtime.mod_record("com.test.patch").get("status", "")) == "loaded", "patch ZIP status loaded")
	_expect(str(runtime.mod_record("com.test.bad").get("status", "")) == "failed", "invalid content status failed")
	_write_result()
	get_tree().quit(0 if failures.is_empty() else 1)


func _prepare_directory() -> void:
	_remove_tree(ProjectSettings.globalize_path(TEST_ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOD_ROOT))


func _create_pck(file_name: String, mod_id: String, local_item_id: String, dependencies: Array, valid: bool) -> void:
	var source_root := "%s/source_%s" % [TEST_ROOT, mod_id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source_root))
	var manifest_text := JSON.stringify(_manifest(mod_id, dependencies))
	var content_text := JSON.stringify(_content(local_item_id, valid))
	var manifest_source := "%s/manifest.json" % source_root
	var content_source := "%s/items.json" % source_root
	_write_text(manifest_source, manifest_text)
	_write_text(content_source, content_text)
	var packer := PCKPacker.new()
	var output := ProjectSettings.globalize_path("%s/%s" % [MOD_ROOT, file_name])
	_expect(packer.pck_start(output) == OK, "PCK start")
	_expect(packer.add_file("res://mods/%s/manifest.json" % mod_id, ProjectSettings.globalize_path(manifest_source)) == OK, "PCK manifest")
	_expect(packer.add_file("res://mods/%s/content/items.json" % mod_id, ProjectSettings.globalize_path(content_source)) == OK, "PCK content")
	_expect(packer.flush() == OK, "PCK flush")


func _create_zip(file_name: String, mod_id: String, local_item_id: String, dependencies: Array) -> void:
	var packer := ZIPPacker.new()
	var output := ProjectSettings.globalize_path("%s/%s" % [MOD_ROOT, file_name])
	_expect(packer.open(output, ZIPPacker.APPEND_CREATE) == OK, "ZIP open")
	_add_zip_text(packer, "mods/%s/manifest.json" % mod_id, JSON.stringify(_manifest(mod_id, dependencies)))
	_add_zip_text(packer, "mods/%s/content/items.json" % mod_id, JSON.stringify(_content(local_item_id, true)))
	_expect(packer.close() == OK, "ZIP close")


func _create_patch_zip(file_name: String) -> void:
	var dependency := {
		"id": "com.test.pck",
		"min_version": "1.0.0",
		"max_version_exclusive": "2.0.0",
		"optional": false,
	}
	var manifest := _manifest("com.test.patch", [dependency])
	manifest["overrides"] = ["item:com.test.pck:pck_item"]
	var document := {
		"schema_version": 1,
		"kind": "item",
		"entries": [{
			"operation": "patch",
			"target_id": "com.test.pck:pck_item",
			"patch": {"name": "patched_item"},
		}],
	}
	var packer := ZIPPacker.new()
	var output := ProjectSettings.globalize_path("%s/%s" % [MOD_ROOT, file_name])
	_expect(packer.open(output, ZIPPacker.APPEND_CREATE) == OK, "patch ZIP open")
	_add_zip_text(packer, "mods/com.test.patch/manifest.json", JSON.stringify(manifest))
	_add_zip_text(packer, "mods/com.test.patch/content/items.json", JSON.stringify(document))
	_expect(packer.close() == OK, "patch ZIP close")


func _add_zip_text(packer: ZIPPacker, path: String, value: String) -> void:
	_expect(packer.start_file(path) == OK, "ZIP start %s" % path)
	_expect(packer.write_file(value.to_utf8_buffer()) == OK, "ZIP write %s" % path)
	_expect(packer.close_file() == OK, "ZIP close %s" % path)


func _manifest(mod_id: String, dependencies: Array) -> Dictionary:
	return {
		"schema_version": 1,
		"id": mod_id,
		"name": mod_id,
		"version": "1.0.0",
		"authors": ["test"],
		"mod_api_version": 1,
		"game_version": {"min": "0.1.0", "max_exclusive": "0.2.0"},
		"dependencies": dependencies,
		"conflicts": [],
		"load_after": [],
		"content": ["res://mods/%s/content/items.json" % mod_id],
		"entry_script": "",
		"overrides": [],
	}


func _content(local_item_id: String, valid: bool) -> Dictionary:
	var data := {"name": local_item_id}
	if valid:
		data["type"] = "material"
	return {
		"schema_version": 1,
		"kind": "item",
		"entries": [{"operation": "add", "local_id": local_item_id, "data": data}],
	}


func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "open source %s" % path)
	if file != null:
		file.store_string(value)


func _remove_tree(absolute_path: String) -> void:
	var directory := DirAccess.open(absolute_path)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute("%s/%s" % [absolute_path, file_name])
	for directory_name in directory.get_directories():
		var child := "%s/%s" % [absolute_path, directory_name]
		_remove_tree(child)
		DirAccess.remove_absolute(child)
	DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _write_result() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("PASS" if failures.is_empty() else "FAIL\n%s" % "\n".join(failures))
