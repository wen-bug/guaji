## 核心敌人静态资源。空的战斗属性表示每个实例在生成时随机抽取。
@tool
class_name EnemyDef
extends Resource

@export_category("敌人配置（悬停字段查看说明）")
@export_group("基础信息｜ID、名称、形象与场景")
## 稳定敌人 ID；地图遭遇、存档和技能动作表通过它引用敌人。
@export var id := ""
## 战斗日志和遭遇界面显示的名称。
@export var display_name := ""
## 敌人视觉定义 ID。
@export var visual_id := "enemy_default"
## 专用敌人场景；为空时使用通用敌人场景回退。
@export_file("*.tscn") var scene_path := ""

@export_group("分类｜遭遇类别与成长类别")
@export_enum("normal", "elite", "boss") var encounter_class := "normal"
@export_enum("normal", "elite", "boss") var enemy_class := "normal"

@export_group("基础数值｜等级、生命、攻击与防御")
@export var level_offset := 0
@export var max_hp := 1
@export var attack := 1
@export var defense := 0
## 模板与阶位成长完成后应用的基础属性倍率。
@export var reference_stat_multipliers: Dictionary = {}

@export_group("五行与成长｜技能缩放、克制标签、主副属性")
## 敌人技能缩放使用的五行；与 combat_affinity 相互独立。
@export_enum("none", "wood", "fire", "earth", "metal", "water") var element := "none"
@export var element_power := 0
## 唯一战斗属性；auto 表示普通/精英实例生成时从六类中随机抽取。
@export_enum("auto", "normal", "wood", "fire", "earth", "metal", "water") var combat_affinity := "auto"
## 小于 0 时按 enemy_class 使用默认倍率。
@export var attribute_point_multiplier := -1.0
@export_enum("none", "max_hp", "attack", "defense", "element_wood", "element_fire", "element_earth", "element_metal", "element_water") var growth_primary_stat := "none"
@export var growth_secondary_stats: Array[String] = []

@export_group("技能与行动｜技能表、解锁阶位与场景节奏")
@export var skills: Array[String] = []
@export_enum("t1", "t2", "t3", "t4", "t5") var skill_unlock_rank := "t2"
@export var move_speed := 120.0
@export var player_move_speed := 120.0
@export var attack_range := 88.0
@export var player_attack_range := 96.0
@export var spawn_delay := 0.6
@export var turn_wait := 1.4

@export_group("奖励｜经验、掉落池与装备概率")
@export var experience_multiplier := 1.0
@export var drop_chance_bonus := 0.0
@warning_ignore("shadowed_global_identifier")
@export var exp := 5
@export var use_drop := true
@export var use_class_drop_pool := false
@export var use_rank_drop_pool := false
## 小于 0 时按 enemy_class 使用默认概率。
@export var equipment_drop_chance := -1.0
@export var drop_profile: Dictionary = {}
@export var drops: Dictionary = {}

@export_group("其他｜预置状态与特殊标记")
@export var effects: Array[Dictionary] = []
@export var is_training_dummy := false


func to_dictionary() -> Dictionary:
	var definition := {
		"id": id,
		"name": display_name,
		"visual_id": visual_id,
		"encounter_class": encounter_class,
		"enemy_class": enemy_class,
		"level_offset": level_offset,
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"element": "" if element == "none" else element,
		"element_power": element_power,
		"skills": skills.duplicate(),
		"skill_unlock_rank": skill_unlock_rank,
		"move_speed": move_speed,
		"player_move_speed": player_move_speed,
		"attack_range": attack_range,
		"player_attack_range": player_attack_range,
		"spawn_delay": spawn_delay,
		"turn_wait": turn_wait,
		"experience_multiplier": experience_multiplier,
		"drop_chance_bonus": drop_chance_bonus,
		"exp": exp,
		"use_drop": use_drop,
		"use_class_drop_pool": use_class_drop_pool,
		"use_rank_drop_pool": use_rank_drop_pool,
		"drop_profile": drop_profile.duplicate(true),
		"drops": drops.duplicate(true),
		"effects": effects.duplicate(true),
		"is_training_dummy": is_training_dummy,
	}
	if not scene_path.is_empty():
		definition["scene_path"] = scene_path
	if not reference_stat_multipliers.is_empty():
		definition["reference_stat_multipliers"] = reference_stat_multipliers.duplicate(true)
	if combat_affinity != "auto":
		definition["combat_affinity"] = combat_affinity
	if attribute_point_multiplier >= 0.0:
		definition["attribute_point_multiplier"] = attribute_point_multiplier
	if growth_primary_stat != "none":
		definition["growth_primary_stat"] = growth_primary_stat
	if not growth_secondary_stats.is_empty():
		definition["growth_secondary_stats"] = growth_secondary_stats.duplicate()
	if equipment_drop_chance >= 0.0:
		definition["equipment_drop_chance"] = equipment_drop_chance
	return definition
