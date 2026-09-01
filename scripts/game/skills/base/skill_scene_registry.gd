class_name SkillSceneRegistry
extends RefCounted

const SkillConfigParserScript = preload("res://scripts/game/data/skill_config_parser.gd")

var _scenes: Dictionary = {}
var _definitions: Dictionary = {}
var _errors: Array[String] = []


func clear() -> void:
	_scenes.clear()
	_definitions.clear()
	_errors.clear()


func scan_core() -> Array[String]:
	clear()
	for parser_error in SkillConfigParserScript.validation_errors():
		_errors.append(str(parser_error))
	for skill_id in SkillConfigParserScript.definitions():
		var path := SkillConfigParserScript.scene_path(str(skill_id))
		if not path.is_empty():
			_register_scene(path, str(skill_id))
	return errors()


func packed_scene(skill_id: String) -> PackedScene:
	return _scenes.get(skill_id) as PackedScene


func definition(skill_id: String) -> Dictionary:
	return (_definitions.get(skill_id, {}) as Dictionary).duplicate(true)


func definitions() -> Dictionary:
	return _definitions.duplicate(true)


func has(skill_id: String) -> bool:
	return _scenes.has(skill_id) and _definitions.has(skill_id)


func errors() -> Array[String]:
	return _errors.duplicate()


func _register_scene(path: String, expected_skill_id: String) -> Dictionary:
	var packed_scene_resource := load(path) as PackedScene
	if packed_scene_resource == null:
		return _fail("技能场景无法加载: %s" % path)
	var scene_instance := packed_scene_resource.instantiate()
	var skill_scene := scene_instance as SkillSceneBase
	if skill_scene == null:
		scene_instance.free()
		return {"ok": true, "ignored": true}
	if skill_scene.skill_resource == null:
		skill_scene.free()
		return {"ok": true, "ignored": true}
	var skill_id := str(skill_scene.skill_resource.id)
	if skill_id.is_empty():
		skill_scene.free()
		return _fail("技能场景绑定的 SkillDef.id 不能为空: %s" % path)
	if not expected_skill_id.is_empty() and skill_id != expected_skill_id:
		skill_scene.free()
		return _fail("技能场景资源 ID 不一致: %s（%s != %s）" % [path, skill_id, expected_skill_id])
	if _scenes.has(skill_id):
		skill_scene.free()
		return _fail("存在重复技能场景 ID %s: %s" % [skill_id, path])
	var registration_errors := skill_scene.contract_errors()
	registration_errors.append_array(status_visual_errors(skill_scene.skill_resource))
	if not registration_errors.is_empty():
		skill_scene.free()
		return _fail("技能场景契约无效 %s: %s" % [path, "；".join(registration_errors)])
	var skill_definition := skill_scene.skill_resource.to_dictionary()
	var skill_resource_path := skill_scene.skill_resource.resource_path
	skill_definition["id"] = skill_id
	skill_definition["scene_path"] = path
	_scenes[skill_id] = packed_scene_resource
	_definitions[skill_id] = skill_definition
	skill_scene.free()
	return {
		"ok": true,
		"content_id": skill_id,
		"definition": skill_definition.duplicate(true),
		"scene_path": path,
		"resource_path": skill_resource_path,
	}


func status_visual_errors(skill: SkillDef) -> Array[String]:
	var validation_errors: Array[String] = []
	for raw_effect in skill.effects:
		var effect := raw_effect as SkillEffectDef
		if effect == null or effect.kind != "status":
			continue
		var label := effect.status_id if not effect.status_id.is_empty() else effect.effect_id
		if effect.status_visual_scene == null:
			validation_errors.append("状态效果 %s 未选择 status_visual_scene" % label)
			continue
		var visual_instance := effect.status_visual_scene.instantiate()
		var visual := visual_instance as StatusVisualBase
		if visual == null:
			visual_instance.free()
			validation_errors.append("状态效果 %s 的场景根节点必须继承 StatusVisualBase" % label)
			continue
		var visual_contract_errors := visual.contract_errors()
		for visual_error in visual_contract_errors:
			validation_errors.append("状态效果 %s: %s" % [label, visual_error])
		visual.free()
	return validation_errors


func _fail(message: String) -> Dictionary:
	_errors.append(message)
	return {"ok": false, "error": message}
