class_name SkillDef
extends Resource

@export var id := ""
@export var display_name := ""
@export var icon_texture: Texture2D
@export var icon_name := ""
@export var icon_path := ""
@export var type := ""
@export var target_scope := "single_enemy"
@export var target_mode := "single"
@export var is_aoe := false
@export var effect_tags: Array[String] = []
@export var has_buff := false
@export var has_debuff := false
@export var element := ""
@export var mp_cost := 0
@export var cooldown := 0.0
@export var release_distance := 0.0
@export_multiline var description := ""


func setup(skill_id: String, data: Dictionary) -> SkillDef:
	id = skill_id
	display_name = data.get("name", skill_id)
	icon_name = data.get("icon_name", skill_id)
	icon_path = data.get("icon_path", "res://assets/skills/%s.png" % icon_name)
	type = data.get("type", "")
	target_scope = data.get("target_scope", "single_enemy")
	target_mode = data.get("target_mode", "single")
	is_aoe = bool(data.get("is_aoe", target_mode == "aoe"))
	effect_tags.assign(data.get("effect_tags", []))
	has_buff = bool(data.get("has_buff", false))
	has_debuff = bool(data.get("has_debuff", false))
	element = data.get("element", "")
	mp_cost = int(data.get("mp_cost", 0))
	cooldown = float(data.get("cooldown", 0.0))
	release_distance = float(data.get("release_distance", 0.0))
	description = data.get("description", "")
	return self
