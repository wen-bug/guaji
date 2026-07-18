class_name BuffSkill
extends SkillSceneBase


func apply_marker(marker: String) -> void:
	var expected_marker: String = str(skill_data.get("buff_marker", skill_data.get("apply_marker", "impact")))
	if marker != expected_marker:
		return
	if caster == null:
		return
	var resolved_targets: Array = targets if not targets.is_empty() else [caster]
	last_result["target_ids"] = []
	last_result["target_results"] = []
	for candidate in resolved_targets:
		if not (candidate is CombatActorStatus):
			continue
		var target := candidate as CombatActorStatus
		if not target.is_alive():
			continue
		_apply_to_target(target)
		var target_ids: Array = last_result.get("target_ids", [])
		target_ids.append(target.actor_id)
		last_result["target_ids"] = target_ids
		var target_results: Array = last_result.get("target_results", [])
		target_results.append({"target_id": target.actor_id})
		last_result["target_results"] = target_results
	if not last_result.get("target_ids", []).is_empty():
		last_result["target_id"] = str(last_result.get("target_ids", [""])[0])


func _apply_to_target(target: CombatActorStatus) -> void:
	for buff in skill_data.get("combat_buffs", []):
		if not (buff is Dictionary):
			continue
		var next_buff: Dictionary = buff.duplicate(true)
		next_buff["source_skill_id"] = str(skill_data.get("id", ""))
		target.add_buff(next_buff)
		add_event({"type": "buff", "actor_id": target.actor_id, "buff": next_buff})
	for effect in skill_data.get("effects", []):
		if not (effect is Dictionary):
			continue
		var next_effect: Dictionary = effect.duplicate(true)
		next_effect["source_skill_id"] = str(skill_data.get("id", ""))
		target.add_status_effect(next_effect)
		add_event({"type": "status", "actor_id": target.actor_id, "effect": next_effect})
