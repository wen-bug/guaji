class_name SkillSceneBase
extends Node2D

signal finished(result: Dictionary)

var caster: CombatActorStatus = null
var targets: Array = []
var skill_data: Dictionary = {}
var last_result: Dictionary = {}


func setup(skill_caster: CombatActorStatus, skill_targets: Array, data: Dictionary) -> void:
	caster = skill_caster
	targets = skill_targets
	skill_data = data.duplicate(true)
	last_result = {"events": [], "skill_id": str(skill_data.get("id", ""))}


func start_cast() -> Dictionary:
	apply_marker(str(skill_data.get("start_marker", "impact")))
	finish_cast()
	return last_result


func apply_marker(_marker: String) -> void:
	pass


func finish_cast() -> void:
	finished.emit(last_result)


func primary_target() -> CombatActorStatus:
	if targets.is_empty():
		return null
	return targets[0]


func add_event(event: Dictionary) -> void:
	var events: Array = last_result.get("events", [])
	events.append(event)
	last_result["events"] = events


func damage_type_from_element(element_id: String) -> String:
	if element_id.is_empty():
		return "physical"
	return "element_%s" % element_id
