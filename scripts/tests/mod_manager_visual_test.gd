extends Node

const RESULT_PATH := "res://.funplay/mod_manager_visual_result.txt"
const SCREENSHOT_PATH := "res://.funplay/mod_manager_visual.png"

var failures: Array[String] = []


func _ready() -> void:
	var main_scene := load("res://main.tscn") as PackedScene
	_expect(main_scene != null, "main scene loads")
	if main_scene == null:
		_finish()
		return
	var main = main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud = main.get_node_or_null("Hud")
	_expect(hud != null, "HUD exists")
	if hud != null:
		var button = hud.mod_manager_button
		var panel = hud.mod_manager_panel
		_expect(button != null and panel != null, "Mod manager controls exist")
		if button != null and panel != null:
			panel.open()
			await get_tree().process_frame
			var viewport_rect := get_viewport().get_visible_rect()
			_expect(viewport_rect.encloses(button.get_global_rect()), "Mod button stays inside viewport")
			_expect(viewport_rect.encloses(panel.get_global_rect()), "Mod panel stays inside viewport")
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty(), "runtime viewport captured")
	if image != null and not image.is_empty():
		_expect(image.save_png(SCREENSHOT_PATH) == OK, "runtime screenshot saved")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("PASS" if failures.is_empty() else "FAIL\n%s" % "\n".join(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
