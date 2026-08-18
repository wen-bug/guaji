class_name SkillDef
extends Resource

@export_group("标识与显示")
## 技能的稳定内容 ID；存档、技能书和冷却记录通过它引用技能。
@export var id := ""
## HUD、战斗日志和详情面板显示的技能名称。
@export var display_name := ""
## Inspector 中直接拖入的技能图标，运行时优先于 icon_path。
@export var icon_texture: Texture2D
## 默认图标文件名，不包含扩展名。
@export var icon_name := ""
## 图标资源路径；icon_texture 为空时使用。
@export var icon_path := ""

@export_group("分类与目标")
## 技能行为分类，例如 damage、heal、buff 或 defense。
@export_enum("normal_attack", "damage", "heal", "buff", "defense", "resource") var type := "damage"
## 目标范围，例如 self、single_enemy、all_enemies 或 all_allies。
@export_enum("self", "single_ally", "all_allies", "single_enemy", "all_enemies") var target_scope := "single_enemy"
## HUD 和兼容逻辑使用的目标模式，例如 single 或 aoe。
@export_enum("single", "aoe") var target_mode := "single"
## 是否为范围技能；应与 target_scope 和 target_mode 保持一致。
@export var is_aoe := false
## 用于检索和展示的效果标签，例如 damage、dot、shield。
@export var effect_tags: Array[String] = []
## 技能是否包含增益状态，用于 UI 和 AI 分类。
@export var has_buff := false
## 技能是否包含减益状态，用于 UI 和 AI 分类。
@export var has_debuff := false
## 技能默认五行；效果自身 element 非空时会覆盖它。
@export var element := ""

@export_group("消耗与 AI")
## 释放技能消耗的法力值。
@export var mp_cost := 0
## 基础冷却回合数，按施法者自身回合递减。
@export var cooldown := 0.0
## AI 候选技能优先级，数值越高越优先。
@export var priority := 0
## AI 使用条件 ID 列表，例如 always 或 hp_below_35。
@export var triggers: Array[String] = ["always"]
## 是否仅供敌人动作表使用；开启后不会进入玩家可学习技能列表。
@export var enemy_only := false
## 敌人 AI 在同优先级候选中的选择权重。
@export var weight := 1.0

@export_group("机制")
## 按数组顺序结算的 SkillEffectDef 资源列表。
@export var effects: Array[Resource] = []

@export_group("说明")
## 技能详情中显示的说明文本。
@export_multiline var description := ""


func setup(skill_id: String, data: Dictionary) -> SkillDef:
	id = skill_id
	display_name = data.get("name", skill_id)
	icon_name = data.get("icon_name", skill_id)
	icon_path = data.get("icon_path", "res://assets/skills/%s.png" % icon_name)
	type = data.get("type", "damage")
	target_scope = data.get("target_scope", "single_enemy")
	target_mode = data.get("target_mode", "single")
	is_aoe = bool(data.get("is_aoe", target_mode == "aoe"))
	effect_tags.assign(data.get("effect_tags", []))
	has_buff = bool(data.get("has_buff", false))
	has_debuff = bool(data.get("has_debuff", false))
	element = data.get("element", "")
	mp_cost = int(data.get("mp_cost", 0))
	cooldown = float(data.get("cooldown", 0.0))
	priority = int(data.get("priority", 0))
	triggers.assign(data.get("trigger", ["always"]))
	enemy_only = bool(data.get("enemy_only", false))
	weight = float(data.get("weight", 1.0))
	description = data.get("description", "")
	return self


func to_dictionary() -> Dictionary:
	var effect_values: Array = []
	for effect in effects:
		if effect != null:
			effect_values.append(effect.to_dictionary())
	return {
		"id": id,
		"name": display_name,
		"icon_name": icon_name,
		"icon_path": icon_path,
		"type": type,
		"target_scope": target_scope,
		"target_mode": target_mode,
		"element": element,
		"mp_cost": mp_cost,
		"cooldown": cooldown,
		"priority": priority,
		"trigger": triggers.duplicate(),
		"enemy_only": enemy_only,
		"weight": weight,
		"effects": effect_values,
		"description": description,
	}
