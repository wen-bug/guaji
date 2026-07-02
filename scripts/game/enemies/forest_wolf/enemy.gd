extends BaseEnemy

const TEMPLATE_ID := "forest_wolf"


func template_id() -> String:
	return TEMPLATE_ID


func setup(data: Dictionary) -> void:
	var prepared_data: Dictionary = data.duplicate(true)
	prepared_data["id"] = TEMPLATE_ID
	prepared_data["is_training_dummy"] = false
	super.setup(prepared_data)
