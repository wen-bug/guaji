class_name EquipmentTemplate
extends Resource

@export var item_id := ""
@export var slot := ""
@export var base_name := ""
@export var attack_base := 0
@export var attack_scale := 0
@export var defense_base := 0
@export var defense_scale := 0
@export var base_attributes := []
@export var requirement_stat := ""
@export_multiline var description := ""


func setup(data: Dictionary) -> EquipmentTemplate:
	item_id = data.get("item_id", "")
	slot = data.get("slot", "")
	base_name = data.get("base_name", "")
	attack_base = int(data.get("attack_base", 0))
	attack_scale = int(data.get("attack_scale", 0))
	defense_base = int(data.get("defense_base", 0))
	defense_scale = int(data.get("defense_scale", 0))
	base_attributes = data.get("base_attributes", []).duplicate(true)
	requirement_stat = data.get("requirement_stat", "")
	description = data.get("description", "")
	return self
