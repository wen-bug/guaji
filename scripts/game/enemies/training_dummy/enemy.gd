extends BaseEnemy

const TEMPLATE_ID := "training_dummy"


func template_id() -> String:
	return TEMPLATE_ID


func setup(data: Dictionary) -> void:
	var prepared_data: Dictionary = data.duplicate(true)
	prepared_data["id"] = TEMPLATE_ID
	prepared_data["is_training_dummy"] = true
	prepared_data["use_drop"] = false
	super.setup(prepared_data)


func select_action(_game_state) -> Dictionary:
	if enemy_data.is_empty():
		return {}
	return {
		"kind": "basic_attack",
		"base_damage": int(enemy_data.get("attack", 1)),
		"element": "",
	}
