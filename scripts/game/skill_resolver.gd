class_name SkillResolver
extends RefCounted


func resolve_skill(skill: Dictionary, game_state, combat_context := {}) -> Dictionary:
	if skill.is_empty():
		return _failed_result("技能不存在")

	var mp_cost := int(skill.get("mp_cost", 0))
	if int(game_state.stats.get("mp", 0)) < mp_cost:
		return _failed_result("法力不足")

	if mp_cost > 0 and not game_state.spend_mp(mp_cost):
		return _failed_result("法力不足")

	var total_attack := int(combat_context.get("total_attack", 0))
	var damage := int(total_attack * float(skill.get("damage_multiplier", 0.0)))
	return {
		"success": true,
		"skill_id": str(skill.get("id", "")),
		"skill_name": str(skill.get("name", "技能")),
		"damage": max(0, damage),
		"element": str(skill.get("element", "")),
		"mp_spent": mp_cost,
		"cooldown": float(skill.get("cooldown", 0.0)),
		"combat_buffs": skill.get("combat_buffs", []).duplicate(true),
		"message": "释放%s" % str(skill.get("name", "技能")),
	}


func _failed_result(message: String) -> Dictionary:
	return {
		"success": false,
		"damage": 0,
		"element": "",
		"mp_spent": 0,
		"cooldown": 0.0,
		"combat_buffs": [],
		"message": message,
	}
