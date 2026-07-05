class_name ItemDef
extends Resource

@export var id := ""
@export var item_no := 0
@export var type := ""
@export var display_name := ""
@export var icon_texture: Texture2D
@export var icon_name := ""
@export var icon_path := ""
@export_multiline var description := ""
@export var stackable := true
@export var usable := false
@export var use_scope := ""
@export var gain_target := "none"
@export var payload: Dictionary = {}


func setup(def_id: String, data: Dictionary) -> ItemDef:
	id = def_id
	item_no = int(data.get("item_no", 0))
	type = data.get("type", "")
	display_name = data.get("name", data.get("display_name", def_id))
	icon_name = data.get("icon_name", def_id)
	icon_path = data.get("icon_path", "res://assets/items/%s.png" % icon_name)
	description = data.get("description", "")
	stackable = bool(data.get("stackable", true))
	usable = bool(data.get("usable", false))
	use_scope = data.get("use_scope", "")
	gain_target = data.get("gain_target", "none")
	payload = data.get("payload", {}).duplicate(true)
	return self


func to_item_data() -> Dictionary:
	return {
		"item_no": item_no,
		"type": type,
		"name": display_name,
		"icon_name": icon_name,
		"icon_path": icon_path,
		"description": description,
		"stackable": stackable,
		"usable": usable,
		"use_scope": use_scope,
		"gain_target": gain_target,
		"payload": payload.duplicate(true),
	}
