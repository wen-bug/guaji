extends SceneTree

const SOURCE_ROOT := "res://mod_sdk/example_mod/mods/com.example.guaji"
const TARGET_ROOT := "res://mods/com.example.guaji"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var requested := str(args[0]) if not args.is_empty() else "example_mod.pck"
	var output_path := requested if requested.is_absolute_path() else ProjectSettings.globalize_path("res://%s" % requested)
	var packer := PCKPacker.new()
	var error := packer.pck_start(output_path)
	if error != OK:
		push_error("Cannot create package: %s" % error_string(error))
		quit(1)
		return
	error = _add_directory(packer, SOURCE_ROOT, TARGET_ROOT)
	if error == OK:
		error = packer.flush()
	if error != OK:
		push_error("Cannot finish package: %s" % error_string(error))
		quit(1)
		return
	print("Created Mod package: %s" % output_path)
	quit(0)


func _add_directory(packer: PCKPacker, source_root: String, target_root: String) -> Error:
	var directory := DirAccess.open(source_root)
	if directory == null:
		return ERR_FILE_NOT_FOUND
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() in ["uid", "import"]:
			continue
		var source_path := "%s/%s" % [source_root, file_name]
		var packaged_name := file_name.trim_suffix(".txt") if file_name.ends_with(".txt") else file_name
		var target_path := "%s/%s" % [target_root, packaged_name]
		var error := packer.add_file(target_path, ProjectSettings.globalize_path(source_path))
		if error != OK:
			return error
	for directory_name in directory.get_directories():
		var error := _add_directory(
			packer,
			"%s/%s" % [source_root, directory_name],
			"%s/%s" % [target_root, directory_name]
		)
		if error != OK:
			return error
	return OK
