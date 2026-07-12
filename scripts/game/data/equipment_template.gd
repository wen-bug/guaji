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
@export var requirement_stat := ""
@export_multiline var description := ""
@export var description_effects := []


func setup(data: Dictionary) -> EquipmentTemplate:
	item_id = data.get("item_id", "")
	slot = data.get("slot", "")
	base_name = data.get("base_name", data.get("name", ""))
	display_name = data.get("display_name", base_name)
	slot_label = data.get("slot_label", slot)
	icon_name = data.get("icon_name", item_id)
	icon_path = data.get("icon_path", "res://assets/equipment/%s.png" % icon_name)
	requirement_stat = data.get("requirement_stat", "")
	description = data.get("description", "")
	description_effects = data.get("description_effects", []).duplicate(true)
	return self
