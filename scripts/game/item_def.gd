class_name ItemDef
extends Resource

@export var id := ""
@export var type := ""
@export var display_name := ""
@export_multiline var description := ""
@export var stackable := true
@export var usable := false
var payload := {}


func setup(def_id: String, data: Dictionary) -> ItemDef:
	id = def_id
	type = data.get("type", "")
	display_name = data.get("name", data.get("display_name", def_id))
	description = data.get("description", "")
	stackable = bool(data.get("stackable", true))
	usable = bool(data.get("usable", false))
	payload = data.get("payload", {}).duplicate(true)
	return self


func to_item_data() -> Dictionary:
	return {
		"type": type,
		"name": display_name,
		"description": description,
		"stackable": stackable,
		"usable": usable,
		"payload": payload.duplicate(true),
	}
