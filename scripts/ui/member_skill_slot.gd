extends PanelContainer
## Draggable skill slot in the member info skill grid.
##
## Emits nothing itself; the owning HUD supplies a swap_callback(from_index, to_index)
## that reorders member["skills"] and refreshes the grid.

var slot_index: int = -1
var swap_callback: Callable


func _get_drag_data(_at_position: Vector2) -> Variant:
	if slot_index < 0:
		return null
	var preview := ColorRect.new()
	preview.color = Color(1, 0.93, 0.74, 0.45)
	preview.custom_minimum_size = size
	set_drag_preview(preview)
	return {"skill_slot_index": slot_index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if slot_index < 0:
		return false
	if not (data is Dictionary):
		return false
	var drag_index := int(data.get("skill_slot_index", -1))
	return drag_index >= 0 and drag_index != slot_index


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary) or not swap_callback.is_valid():
		return
	var drag_index := int(data.get("skill_slot_index", -1))
	if drag_index < 0 or drag_index == slot_index:
		return
	swap_callback.call(drag_index, slot_index)
