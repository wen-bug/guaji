class_name BuffSkill
extends SkillSceneBase


func accepts_skill_type(skill_type: String) -> bool:
	return skill_type in ["buff", "defense"]
