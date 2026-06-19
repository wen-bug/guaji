class_name HomeMap
extends Node2D

signal home_node_selected(node_name: String)

const OUTLINE_HIGHLIGHT_SHADER = preload("res://scripts/map/outline_highlight.gdshader")
const NODE_MEDITATE := "meditate"
const NODE_FARMLAND := "farmland"
const NODE_FORGE := "forge"
const NODE_ALCHEMY := "alchemy"
const NODE_FIGHT := "fight"
const ACTION_NODE_NAMES := [NODE_MEDITATE, NODE_FORGE, NODE_ALCHEMY, NODE_FARMLAND, NODE_FIGHT]
const HIGHLIGHT_SCALE := Vector2(1.12, 1.12)
const HIGHLIGHT_Z_OFFSET := 5
const META_ORIGINAL_SCALE := "home_original_scale"
const META_ORIGINAL_Z_INDEX := "home_original_z_index"
const SHADER_PARAM_OUTLINE_ENABLED := "outline_enabled"
const ALERT_TEXT := "!"

var active_crop_nodes: Array[Node2D] = []
var alert_labels := {}
var _is_setup := false


static func task_type_for_node(node_name: String) -> int:
	match node_name:
		NODE_MEDITATE:
			return GameDefs.TaskType.MEDITATE
		NODE_FARMLAND:
			return GameDefs.TaskType.FARM
		NODE_FORGE:
			return GameDefs.TaskType.FORGE
		NODE_ALCHEMY:
			return GameDefs.TaskType.ALCHEMY
		NODE_FIGHT:
			return GameDefs.TaskType.FIGHT
	return -1


func _ready() -> void:
	setup_home_map()


func setup_home_map() -> void:
	if _is_setup:
		return
	_is_setup = true
	_setup_action_areas()
	_setup_farm_slots()


func farm_slot_count() -> int:
	return 0


func active_crop_count() -> int:
	var count := 0
	for crop_node in active_crop_nodes:
		if is_instance_valid(crop_node):
			count += 1
	return count


func show_farm_crops(crop_id: String, amount: int) -> void:
	setup_home_map()
	_clear_farm_crops()


func show_farm_slots(farm_slots: Array) -> void:
	setup_home_map()
	_clear_farm_crops()


func clear_farm_crops() -> void:
	_clear_farm_crops()


func _setup_action_areas() -> void:
	for node_name in ACTION_NODE_NAMES:
		var action_node := get_node_or_null(node_name)
		_connect_action_area(action_node, node_name, false)


func _setup_farm_slots() -> void:
	pass


func _connect_action_area(action_node: Node, action_name: String, connect_mouse_signals := true) -> void:
	_ensure_alert_label(action_node, action_name)
	if action_node == null:
		return
	var area := action_node.get_node_or_null("Area2D") as Area2D
	if area == null:
		return
	area.visible = true
	area.input_pickable = true
	area.monitoring = true
	area.monitorable = true
	_bind_outline_material(action_name)
	var input_callback := Callable(self, "_on_action_area_input").bind(action_name)
	if not area.input_event.is_connected(input_callback):
		area.input_event.connect(input_callback)
	if connect_mouse_signals:
		var enter_callback := Callable(self, "_on_action_area_mouse_entered").bind(action_name)
		if not area.mouse_entered.is_connected(enter_callback):
			area.mouse_entered.connect(enter_callback)
		var exit_callback := Callable(self, "_on_action_area_mouse_exited").bind(action_name)
		if not area.mouse_exited.is_connected(exit_callback):
			area.mouse_exited.connect(exit_callback)


func _on_action_area_input(_viewport: Node, event: InputEvent, _shape_idx: int, action_name: String) -> void:
	if event is InputEventMouseMotion:
		_set_action_highlight(action_name, true)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		home_node_selected.emit(action_name)


func _on_action_area_mouse_entered(action_name: String) -> void:
	_set_action_highlight(action_name, true)


func _on_action_area_mouse_exited(action_name: String) -> void:
	_set_action_highlight(action_name, false)


func _on_meditate_area_mouse_entered() -> void:
	_on_action_area_mouse_entered(NODE_MEDITATE)


func _on_meditate_area_mouse_exited() -> void:
	_on_action_area_mouse_exited(NODE_MEDITATE)


func _on_alchemy_area_mouse_entered() -> void:
	_on_action_area_mouse_entered(NODE_ALCHEMY)


func _on_alchemy_area_mouse_exited() -> void:
	_on_action_area_mouse_exited(NODE_ALCHEMY)


func _on_forge_area_mouse_entered() -> void:
	_on_action_area_mouse_entered(NODE_FORGE)


func _on_forge_area_mouse_exited() -> void:
	_on_action_area_mouse_exited(NODE_FORGE)


func _on_farmland_area_mouse_entered() -> void:
	_on_action_area_mouse_entered(NODE_FARMLAND)


func _on_farmland_area_mouse_exited() -> void:
	_on_action_area_mouse_exited(NODE_FARMLAND)


func _on_fight_area_mouse_entered() -> void:
	_on_action_area_mouse_entered(NODE_FIGHT)


func _on_fight_area_mouse_exited() -> void:
	_on_action_area_mouse_exited(NODE_FIGHT)


func _set_action_highlight(action_name: String, enabled: bool) -> void:
	var action_node := get_node_or_null(action_name) as CanvasItem
	if action_node == null:
		return
	if action_node is Node2D and not action_node.has_meta(META_ORIGINAL_SCALE):
		action_node.set_meta(META_ORIGINAL_SCALE, action_node.scale)
	if not action_node.has_meta(META_ORIGINAL_Z_INDEX):
		action_node.set_meta(META_ORIGINAL_Z_INDEX, action_node.z_index)
	if enabled:
		_set_outline_enabled(action_node, true)
		if action_node is Node2D:
			action_node.scale = action_node.get_meta(META_ORIGINAL_SCALE, Vector2.ONE) * HIGHLIGHT_SCALE
		action_node.z_index = int(action_node.get_meta(META_ORIGINAL_Z_INDEX, 0)) + HIGHLIGHT_Z_OFFSET
	else:
		_set_outline_enabled(action_node, false)
		if action_node is Node2D:
			action_node.scale = action_node.get_meta(META_ORIGINAL_SCALE, Vector2.ONE)
		action_node.z_index = int(action_node.get_meta(META_ORIGINAL_Z_INDEX, 0))


func _bind_outline_material(action_name: String) -> void:
	var action_node := get_node_or_null(action_name) as CanvasItem
	if action_node == null:
		return
	for item in _canvas_items_for_highlight(action_node):
		_bind_outline_material_to_item(item)


func _set_outline_enabled(root_item: CanvasItem, enabled: bool) -> void:
	for item in _canvas_items_for_highlight(root_item):
		_bind_outline_material_to_item(item)
		(item.material as ShaderMaterial).set_shader_parameter(SHADER_PARAM_OUTLINE_ENABLED, enabled)


func _canvas_items_for_highlight(root_item: CanvasItem) -> Array[CanvasItem]:
	var items: Array[CanvasItem] = [root_item]
	_collect_canvas_item_children(root_item, items)
	return items


func _collect_canvas_item_children(node: Node, items: Array[CanvasItem]) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			items.append(child)
		_collect_canvas_item_children(child, items)


func _bind_outline_material_to_item(item: CanvasItem) -> void:
	if item.material is ShaderMaterial and (item.material as ShaderMaterial).shader == OUTLINE_HIGHLIGHT_SHADER:
		return
	item.material = _create_outline_material()


func _create_outline_material() -> ShaderMaterial:
	var outline_material := ShaderMaterial.new()
	outline_material.shader = OUTLINE_HIGHLIGHT_SHADER
	outline_material.set_shader_parameter(SHADER_PARAM_OUTLINE_ENABLED, false)
	return outline_material




func update_progress_alerts(game_state) -> void:
	setup_home_map()
	for node_name in [NODE_ALCHEMY, NODE_FORGE, NODE_FARMLAND]:
		var progress_id := _progress_id_for_node(node_name)
		var state: Dictionary = game_state.progress_state(progress_id) if game_state != null else {}
		_set_alert_visible(node_name, bool(state.get("claimable", false)) or bool(state.get("completed", false)))


func clear_progress_alert(node_name: String) -> void:
	_set_alert_visible(node_name, false)


func _progress_id_for_node(node_name: String) -> String:
	match node_name:
		NODE_ALCHEMY:
			return "alchemy"
		NODE_FORGE:
			return "forge"
		NODE_FARMLAND:
			return "farm"
	return ""


func _set_alert_visible(node_name: String, visible: bool) -> void:
	var label: Label = alert_labels.get(node_name, null)
	if label == null:
		return
	label.visible = visible


func _ensure_alert_label(action_node: Node, action_name: String) -> void:
	if action_node == null or alert_labels.has(action_name):
		return
	var label := Label.new()
	label.name = "AlertLabel"
	label.text = ALERT_TEXT
	label.position = Vector2(0, -18)
	label.visible = false
	label.z_index = 50
	action_node.add_child(label)
	alert_labels[action_name] = label

func _clear_farm_crops() -> void:
	for crop_node in active_crop_nodes:
		if is_instance_valid(crop_node):
			var parent := crop_node.get_parent()
			if parent != null:
				parent.remove_child(crop_node)
			crop_node.free()
	active_crop_nodes.clear()
