class_name SkillResolver
extends RefCounted

const SkillValueResolverScript = preload("res://scripts/game/combat/skill_value_resolver.gd")

func resolve_skill(skill: Dictionary, game_state, combat_context: Dictionary = {}) -> Dictionary:
	if skill.is_empty():
		return _failed_result("技能不存在")

	var mp_cost: int = int(skill.get("mp_cost", 0))
	var member_id: String = str(combat_context.get("member_id", ""))
	var member: Dictionary = game_state.member_by_id(member_id)
	var member_stats: Dictionary = member.get("stats", {})
	if int(member_stats.get("mp", 0)) < mp_cost:
		return _failed_result("法力不足")

	if mp_cost > 0 and not game_state.spend_mp_for(member_id, mp_cost):
		return _failed_result("法力不足")

	var damage: int = 0
	if skill.has("damage_attribute_multiplier"):
		var element_id: String = str(skill.get("element", ""))
		var element_value: int = int(combat_context.get("total_element", game_state.total_element_for(member_id, element_id)))
		damage = SkillValueResolverScript.scaled_amount_from_attribute(
			int(skill.get("base_damage", 0)),
			float(skill.get("damage_attribute_multiplier", 0.0)),
			element_value
		)
	elif skill.has("base_damage"):
		damage = maxi(0, int(skill.get("base_damage", 0)))
	else:
		var total_attack: int = int(combat_context.get("total_attack", 0))
		damage = int(total_attack * float(skill.get("damage_multiplier", 0.0)))
	return {
		"success": true,
		"skill_id": str(skill.get("id", "")),
		"skill_name": str(skill.get("name", "技能")),
		"damage": max(0, damage),
		"element": str(skill.get("element", "")),
		"mp_spent": mp_cost,
		"cooldown": float(skill.get("cooldown", 0.0)),
		"release_distance": float(skill.get("release_distance", 0.0)),
		"combat_buffs": skill.get("combat_buffs", []).duplicate(true),
		"effects": skill.get("effects", []).duplicate(true),
		"message": "释放%s" % str(skill.get("name", "技能")),
	}


func _failed_result(message: String) -> Dictionary:
	return {
		"success": false,
		"damage": 0,
		"element": "",
		"mp_spent": 0,
		"cooldown": 0.0,
		"release_distance": 0.0,
		"combat_buffs": [],
		"effects": [],
		"message": message,
	}
