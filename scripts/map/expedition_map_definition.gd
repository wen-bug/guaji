class_name ExpeditionMapDefinition
extends Resource

@export_group("地图信息")
## 存档和代码使用的稳定 ID；发布后不应修改。
@export var map_id := "default"
@export var display_name := "历练地图"
@export_multiline var description := ""
@export_range(1, 999, 1) var unlock_expedition_level := 1

@export_group("地图内容")
@export var encounter_profile: Resource
@export var background_color := Color(0.10, 0.16, 0.12, 1.0)
@export var ground_color := Color(0.20, 0.30, 0.18, 1.0)


func is_unlocked(expedition_level: int) -> bool:
	return expedition_level >= maxi(1, unlock_expedition_level)


func summary(expedition_level: int) -> Dictionary:
	return {
		"id": map_id,
		"name": display_name,
		"description": description,
		"unlock_level": maxi(1, unlock_expedition_level),
		"unlocked": is_unlocked(expedition_level),
	}
