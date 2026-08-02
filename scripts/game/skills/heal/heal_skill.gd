class_name HealSkill
extends SkillSceneBase


func apply_marker(marker: String) -> void:
	var expected_marker: String = str(skill_data.get("heal_marker", skill_data.get("apply_marker", "impact")))
	if marker != expected_marker:
		return
	if caster == null:
		return
	var amount: int = skill_heal_amount()
	last_result["heal"] = 0
	last_result["target_ids"] = []
	last_result["target_results"] = []
	for candidate in targets:
		if not (candidate is CombatActorStatus):
			continue
		var target := candidate as CombatActorStatus
		if not target.is_alive():
			continue
		var result: Dictionary = target.apply_heal(amount)
		last_result["heal"] = int(last_result.get("heal", 0)) + int(result.get("amount", 0))
		var target_ids: Array = last_result.get("target_ids", [])
		target_ids.append(target.actor_id)
		last_result["target_ids"] = target_ids
		var target_results: Array = last_result.get("target_results", [])
		target_results.append({"target_id": target.actor_id, "heal": int(result.get("amount", 0))})
		last_result["target_results"] = target_results
		add_event(result)
	if not last_result.get("target_ids", []).is_empty():
		last_result["target_id"] = str(last_result.get("target_ids", [""])[0])
