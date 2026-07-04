class_name DirectDamageSkill
extends SkillSceneBase


func apply_marker(marker: String) -> void:
	var expected_marker: String = str(skill_data.get("damage_marker", skill_data.get("apply_marker", "impact")))
	if marker != expected_marker:
		return
	var target: CombatActorStatus = primary_target()
	if caster == null or target == null:
		return
	_apply_skill_buffs()
	var raw_damage: int = _raw_damage()
	if raw_damage <= 0:
		return
	var element_id: String = str(skill_data.get("element", ""))
	if element_id.is_empty():
		element_id = caster.dominant_element()
	var amount: int = _final_damage(raw_damage, element_id, target)
	var result: Dictionary = target.apply_damage(amount, damage_type_from_element(element_id), {
		"skill_id": str(skill_data.get("id", "")),
		"caster_id": caster.actor_id,
		"raw_damage": raw_damage,
	})
	last_result["damage"] = int(result.get("amount", 0))
	last_result["target_id"] = target.actor_id
	add_event(result)


func _apply_skill_buffs() -> void:
	for buff in skill_data.get("combat_buffs", []):
		if buff is Dictionary:
			var next_buff: Dictionary = buff.duplicate(true)
			next_buff["source_skill_id"] = str(skill_data.get("id", ""))
			caster.add_buff(next_buff)


func _raw_damage() -> int:
	if skill_data.has("base_damage"):
		return maxi(0, int(skill_data.get("base_damage", 0)))
	return maxi(0, int(caster.total_stat("attack") * float(skill_data.get("damage_multiplier", 1.0))))


func _final_damage(raw_damage: int, element_id: String, target: CombatActorStatus) -> int:
	var damage: int = max(1, raw_damage - target.total_stat("defense"))
	if caster.actor_kind == CombatActorStatus.KIND_MEMBER:
		damage += int(caster.total_element(element_id) * 0.5)
	if target.actor_kind == CombatActorStatus.KIND_ENEMY:
		if element_id == str(target.data.get("weak_element", "")):
			damage += max(1, int(raw_damage * 0.25)) + caster.total_element(element_id)
	else:
		if not element_id.is_empty():
			damage = max(0, damage - int(target.total_element(element_id) * 0.35))
	return damage
