@tool
class_name ItemEffectDef
extends Resource

@export_category("类型化道具效果")
@export_group("标识与类型")
@export var effect_id := "effect"
@export_enum("restore_resource", "temporary_modifier", "permanent_attribute", "unlock_content", "breakthrough", "building_quality", "farm_seed", "equipment_enhancement_material", "currency") var kind := "restore_resource"
@export_enum("none", "member", "home_global", "combat_global") var target := "member"

@export_group("数值")
@export var stat := ""
@export_enum("flat", "percent") var operation := "flat"
@export var value := 0.0
@export var ratio := 0.0

@export_group("Buff")
@export var buff_id := ""
@export_enum("timed", "permanent") var duration_mode := "timed"
@export var duration_seconds := 0.0
@export_enum("replace", "refresh", "extend", "stack") var stack_mode := "refresh"
@export_range(1, 99, 1) var max_stacks := 1

@export_group("内容引用")
@export var reference_kind := ""
@export var reference_id := ""
@export var tier_id := ""
@export var group_id := ""
@export var amount := 0
@export var auxiliary_value := 0.0


func to_dictionary() -> Dictionary:
	return {
		"effect_id": effect_id,
		"kind": kind,
		"target": target,
		"stat": stat,
		"operation": operation,
		"value": value,
		"ratio": ratio,
		"buff_id": buff_id,
		"duration_mode": duration_mode,
		"duration_seconds": duration_seconds,
		"stack_mode": stack_mode,
		"max_stacks": max_stacks,
		"reference_kind": reference_kind,
		"reference_id": reference_id,
		"tier_id": tier_id,
		"group_id": group_id,
		"amount": amount,
		"auxiliary_value": auxiliary_value,
	}
