class_name EquipmentTemplate
extends Resource

@export var item_id := ""
@export var slot := ""
@export var base_name := ""
@export var display_name := ""
@export var slot_label := ""
@export var icon_texture: Texture2D
@export var icon_name := ""
@export var icon_path := ""
@export var attack_base := 0
@export var attack_scale := 0
@export var defense_base := 0
@export var defense_scale := 0
@export var level_scale := 0.0
@export var base_attributes := []
@export var requirement_stat := ""
@export_multiline var description := ""


func setup(data: Dictionary) -> EquipmentTemplate:
	item_id = data.get("item_id", "")
	slot = data.get("slot", "")
	base_name = data.get("base_name", data.get("name", ""))
	display_name = data.get("display_name", base_name)
	slot_label = data.get("slot_label", slot)
	icon_name = data.get("icon_name", item_id)
	icon_path = data.get("icon_path", "res://assets/equipment/%s.png" % icon_name)
	attack_base = int(data.get("attack_base", 0))
	attack_scale = int(data.get("attack_scale", 0))
	defense_base = int(data.get("defense_base", 0))
	defense_scale = int(data.get("defense_scale", 0))
	level_scale = float(data.get("level_scale", 0.0))
	base_attributes = data.get("base_attributes", []).duplicate(true)
	requirement_stat = data.get("requirement_stat", "")
	description = data.get("description", "")
	return self
