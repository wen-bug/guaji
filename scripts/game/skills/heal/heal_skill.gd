class_name HealSkill
extends SkillSceneBase


func apply_marker(marker: String) -> void:
	var expected_marker: String = str(skill_data.get("heal_marker", skill_data.get("apply_marker", "impact")))
	if marker != expected_marker:
		return
	var target: CombatActorStatus = primary_target()
	if caster == null or target == null:
		return
	var amount: int = int(skill_data.get("heal_amount", 0))
	if amount <= 0:
		amount = max(1, int(caster.total_stat("attack") * float(skill_data.get("heal_multiplier", 1.0))))
	var result: Dictionary = target.apply_heal(amount)
	last_result["heal"] = int(result.get("amount", 0))
	last_result["target_id"] = target.actor_id
	add_event(result)
