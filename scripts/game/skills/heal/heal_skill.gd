class_name HealSkill
extends SkillSceneBase


func accepts_skill_type(skill_type: String) -> bool:
	return skill_type == "heal"
