class_name BuffSkill
extends SkillSceneBase


func apply_marker(marker: String) -> void:
	var expected_marker: String = str(skill_data.get("buff_marker", skill_data.get("apply_marker", "impact")))
	if marker != expected_marker:
		return
	var target: CombatActorStatus = primary_target()
	if target == null:
		target = caster
	if target == null:
		return
	for buff in skill_data.get("combat_buffs", []):
		if not (buff is Dictionary):
			continue
		var next_buff: Dictionary = buff.duplicate(true)
		next_buff["source_skill_id"] = str(skill_data.get("id", ""))
		target.add_buff(next_buff)
		add_event({"type": "buff", "actor_id": target.actor_id, "buff": next_buff})
