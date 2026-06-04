class_name Hud
extends CanvasLayer

const MENU_USE := 1
const MENU_DROP := 2
const MENU_ENHANCE := 3
const MENU_AFFIX := 4
const INVENTORY_CATEGORIES := [
	{"type": DataTables.ITEM_TYPE_SKILL_BOOK, "label": "技能书", "node": "SkillBookButton"},
	{"type": DataTables.ITEM_TYPE_ALCHEMY_RECIPE, "label": "图纸", "node": "RecipeButton"},
	{"type": DataTables.ITEM_TYPE_EQUIPMENT, "label": "装备", "node": "EquipmentButton"},
	{"type": DataTables.ITEM_TYPE_MATERIAL, "label": "材料", "node": "MaterialButton"},
	{"type": DataTables.ITEM_TYPE_CROP, "label": "作物", "node": "CropButton"},
	{"type": DataTables.ITEM_TYPE_PILL, "label": "丹药", "node": "PillButton"},
]

signal home_action_requested(task_type: int)
signal hud_save_requested()

const DRAG_MARGIN := 12.0
const INVENTORY_SLOT_COUNT := 25
const INVENTORY_DOUBLE_CLICK_MS := 350

@onready var menu_panel: PanelContainer = $Root/MenuPanel
@onready var character_info_panel: PanelContainer = $Root/CharacterInfoPanel
@onready var inventory_panel: PanelContainer = $Root/InventoryPanel
@onready var farm_panel: PanelContainer = $Root/FarmPanel
@onready var forge_panel: PanelContainer = $Root/ForgePanel
@onready var alchemy_panel: PanelContainer = $Root/AlchemyPanel
@onready var meditate_panel: PanelContainer = $Root/MeditatePanel
@onready var fight_panel: PanelContainer = $Root/FightPanel
@onready var character_attribute_grid: GridContainer = $Root/CharacterInfoPanel/PanelLayout/AttributeGrid
@onready var character_equipment_grid: GridContainer = $Root/CharacterInfoPanel/PanelLayout/EquipmentGrid
@onready var character_skill_grid: GridContainer = $Root/CharacterInfoPanel/PanelLayout/SkillGrid
@onready var inventory_grid: GridContainer = $Root/InventoryPanel/InventoryLayout/InventoryGrid
@onready var inventory_item_detail_panel: PanelContainer = $Root/InventoryPanel/InventoryLayout/InventoryItemDetailPanel
@onready var inventory_item_detail_label: Label = $Root/InventoryPanel/InventoryLayout/InventoryItemDetailPanel/DetailLabel
@onready var inventory_menu: PopupMenu = $Root/InventoryMenu
@onready var category_row: HBoxContainer = $Root/InventoryPanel/InventoryLayout/CategoryRow
@onready var farm_detail: Label = $Root/FarmPanel/PanelLayout/ActionDetail
@onready var forge_detail: Label = $Root/ForgePanel/PanelLayout/ActionDetail
@onready var meditate_detail: Label = $Root/MeditatePanel/PanelLayout/ActionDetail
@onready var fight_detail: Label = $Root/FightPanel/PanelLayout/ActionDetail
@onready var alchemy_recipe_slot_button: Button = $Root/AlchemyPanel/PanelLayout/RecipeSlotButton
@onready var alchemy_recipe_picker_panel: PanelContainer = $Root/AlchemyPanel/PanelLayout/RecipePickerPanel
@onready var alchemy_recipe_list: ItemList = $Root/AlchemyPanel/PanelLayout/RecipePickerPanel/RecipeList
@onready var alchemy_material_grid: GridContainer = $Root/AlchemyPanel/PanelLayout/MaterialGrid
@onready var alchemy_max_count_label: Label = $Root/AlchemyPanel/PanelLayout/MaxCountLabel
@onready var alchemy_craft_count_spinbox: SpinBox = $Root/AlchemyPanel/PanelLayout/CraftCountSpinBox
@onready var alchemy_craft_button: Button = $Root/AlchemyPanel/PanelLayout/CraftButton
@onready var alchemy_hint_label: Label = $Root/AlchemyPanel/PanelLayout/HintLabel

var category_buttons: Array[Button] = []
var inventory_slot_buttons: Array[Button] = []
var inventory_slot_instance_ids: Array[String] = []
var current_inventory_type := DataTables.ITEM_TYPE_EQUIPMENT
var selected_inventory_instance_id := ""
var last_inventory_click_instance_id := ""
var last_inventory_click_time_ms := 0
var current_game_state
var log_lines: Array = []
var selected_alchemy_recipe_id := ""
var alchemy_controls_connected := false
var saved_panel_positions := {}
var dragging_panel: Control = null
var drag_mouse_start := Vector2.ZERO
var drag_panel_start := Vector2.ZERO


func _ready() -> void:

	$Root/CharacterInfoPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): character_info_panel.visible = false)
	$Root/InventoryPanel/InventoryLayout/Header/CloseButton.pressed.connect(func(): inventory_panel.visible = false)
	$Root/FarmPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): farm_panel.visible = false)
	$Root/ForgePanel/PanelLayout/Header/CloseButton.pressed.connect(func(): forge_panel.visible = false)
	$Root/AlchemyPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): alchemy_panel.visible = false)
	$Root/MeditatePanel/PanelLayout/Header/CloseButton.pressed.connect(func(): meditate_panel.visible = false)
	$Root/FightPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): fight_panel.visible = false)

	$Root/FarmPanel/PanelLayout/ExecuteButton.pressed.connect(func(): home_action_requested.emit(GameDefs.TaskType.FARM))
	$Root/ForgePanel/PanelLayout/ExecuteButton.pressed.connect(func(): home_action_requested.emit(GameDefs.TaskType.FORGE))
	$Root/MeditatePanel/PanelLayout/ExecuteButton.pressed.connect(func(): home_action_requested.emit(GameDefs.TaskType.MEDITATE))
	$Root/FightPanel/PanelLayout/ExecuteButton.pressed.connect(func(): home_action_requested.emit(GameDefs.TaskType.FIGHT))
	_connect_alchemy_controls()

	for category in INVENTORY_CATEGORIES:
		var button := category_row.get_node(category["node"]) as Button
		button.text = category["label"]
		button.pressed.connect(func(type_id = category["type"]): _set_inventory_category(type_id))
		category_buttons.append(button)

	inventory_menu.id_pressed.connect(_on_inventory_menu_id_pressed)
	_ensure_inventory_slots()
	_capture_default_panel_positions()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_panel_drag(event.position)
		else:
			_end_panel_drag()
	elif event is InputEventMouseMotion and dragging_panel != null:
		var motion_event := event as InputEventMouseMotion
		var next_position: Vector2 = drag_panel_start + motion_event.position - drag_mouse_start
		dragging_panel.position = _clamp_panel_position(dragging_panel, next_position)


func load_hud_save_data(data: Dictionary) -> void:
	_ensure_menu_panel_refs()
	saved_panel_positions.clear()
	var panel_positions = data.get("panel_positions", {})
	if panel_positions is Dictionary:
		for panel_name in panel_positions.keys():
			var position_data = panel_positions[panel_name]
			if position_data is Dictionary:
				saved_panel_positions[panel_name] = {
					"x": float(position_data.get("x", 0.0)),
					"y": float(position_data.get("y", 0.0)),
				}
	_apply_saved_positions_to_visible_panels()


func to_hud_save_data() -> Dictionary:
	_ensure_menu_panel_refs()
	_capture_current_panel_positions()
	return {"panel_positions": saved_panel_positions.duplicate(true)}


func refresh(game_state) -> void:
	_ensure_menu_panel_refs()
	current_game_state = game_state
	_refresh_character_info(game_state)

	if inventory_panel.visible:
		_refresh_inventory()
	if alchemy_panel.visible:
		_refresh_alchemy_panel()
	_refresh_visible_action_details()


func push_log(message: String) -> void:
	log_lines.push_front(message)
	if log_lines.size() > 3:
		log_lines.resize(3)


func _refresh_character_info(game_state) -> void:
	_refresh_character_attributes(game_state)
	_refresh_character_equipment(game_state)
	_refresh_character_skills(game_state)


func _refresh_character_attributes(game_state) -> void:
	_clear_control_children(character_attribute_grid)
	_add_attribute_row("等级", "Lv.%d  阶段 %d/%d" % [int(game_state.stats.get("level", 1)), int(game_state.stats.get("stage", 1)), int(game_state.stats.get("level_cap", 10))])
	_add_attribute_row("HP", "%d/%d" % [int(game_state.stats.get("hp", 0)), int(game_state.stats.get("max_hp", 0))])
	_add_attribute_row("MP", "%d/%d" % [int(game_state.stats.get("mp", 0)), int(game_state.stats.get("max_mp", 0))])
	_add_attribute_row("修为", "%d/%d" % [int(game_state.stats.get("cultivation", 0)), int(game_state.stats.get("next_cultivation", 0))])
	_add_attribute_row("攻击", str(game_state.total_attack()))
	_add_attribute_row("防御", str(game_state.total_defense()))
	_add_attribute_row("根骨", str(game_state.total_stat("root_bone")))
	_add_attribute_row("五行", game_state.element_summary())
	_add_attribute_row("主属性", DataTables.element_name(game_state.dominant_element()))


func _add_attribute_row(label_text: String, value_text: String) -> void:
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(72, 18)
	name_label.text = label_text
	character_attribute_grid.add_child(name_label)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(330, 18)
	value_label.text = value_text
	character_attribute_grid.add_child(value_label)


func _refresh_character_equipment(game_state) -> void:
	_clear_control_children(character_equipment_grid)
	var slots := [
		{"slot": "weapon", "label": "武器"},
		{"slot": "helmet", "label": "头盔"},
		{"slot": "armor", "label": "护甲"},
		{"slot": "leggings", "label": "腿甲"},
		{"slot": "gloves", "label": "护手"},
		{"slot": "accessory_1", "label": "饰品 1"},
		{"slot": "accessory_2", "label": "饰品 2"},
	]
	for slot_def in slots:
		var slot_id: String = slot_def.get("slot", "")
		var item: Dictionary = game_state.equipped_item(slot_id)
		var item_name := "未装备"
		var detail := ""
		if not item.is_empty():
			item_name = str(item.get("name", "装备"))
			detail = "L%d %s" % [int(item.get("equipment_level", 1)), DataTables.equipment_rarity_name(str(item.get("rarity", "t1")))]
		character_equipment_grid.add_child(_create_character_slot(str(slot_def.get("label", slot_id)), item_name, detail))


func _refresh_character_skills(game_state) -> void:
	_clear_control_children(character_skill_grid)
	if game_state.skills.is_empty():
		character_skill_grid.add_child(_create_character_slot("技能", "未学习技能", ""))
		return
	for skill in game_state.skills:
		var element_id: String = skill.get("element", "")
		var detail := "%s  CD %.1fs  MP %d" % [DataTables.element_name(element_id), float(skill.get("cooldown", 0.0)), int(skill.get("mp_cost", 0))]
		character_skill_grid.add_child(_create_character_slot("技能", str(skill.get("name", "未命名技能")), detail))


func _create_character_slot(slot_label: String, item_name: String, detail_text: String) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(220, 48)
	var layout := HBoxContainer.new()
	layout.name = "SlotLayout"
	layout.add_theme_constant_override("separation", 6)
	slot.add_child(layout)
	var icon := TextureRect.new()
	icon.name = "IconPlaceholder"
	icon.custom_minimum_size = Vector2(34, 34)
	layout.add_child(icon)
	var text_layout := VBoxContainer.new()
	text_layout.name = "TextLayout"
	text_layout.add_theme_constant_override("separation", 1)
	layout.add_child(text_layout)
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "%s：%s" % [slot_label, item_name]
	text_layout.add_child(name_label)
	var detail_label := Label.new()
	detail_label.name = "DetailLabel"
	detail_label.text = detail_text
	text_layout.add_child(detail_label)
	return slot


func _clear_control_children(container: Control) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func show_home_action_panel(task_type: int) -> void:
	_ensure_menu_panel_refs()
	var panel := _panel_for_task(task_type)
	if panel == null:
		return
	_close_popup_panels()
	var menu := get_node_or_null("Root/MenuPanel") as Control
	if menu != null:
		menu.visible = false
	_apply_saved_panel_position(panel)
	panel.visible = true
	_refresh_action_detail(task_type)
	if task_type == GameDefs.TaskType.ALCHEMY:
		_refresh_alchemy_panel()


func _toggle_menu() -> void:
	_ensure_menu_panel_refs()
	var next_visible := not menu_panel.visible
	_close_popup_panels()
	_apply_saved_panel_position(menu_panel)
	menu_panel.visible = next_visible


func _open_character_info_panel() -> void:
	_ensure_menu_panel_refs()
	_close_popup_panels()
	menu_panel.visible = false
	_apply_saved_panel_position(character_info_panel)
	character_info_panel.visible = true


func _open_inventory_panel() -> void:
	_ensure_menu_panel_refs()
	_close_popup_panels()
	menu_panel.visible = false
	_apply_saved_panel_position(inventory_panel)
	inventory_panel.visible = true
	_refresh_inventory()


func _ensure_menu_panel_refs() -> void:
	if menu_panel == null:
		menu_panel = $Root/MenuPanel
	if character_info_panel == null:
		character_info_panel = $Root/CharacterInfoPanel
	if inventory_panel == null:
		inventory_panel = $Root/InventoryPanel
	if farm_panel == null:
		farm_panel = $Root/FarmPanel
	if forge_panel == null:
		forge_panel = $Root/ForgePanel
	if alchemy_panel == null:
		alchemy_panel = $Root/AlchemyPanel
	if meditate_panel == null:
		meditate_panel = $Root/MeditatePanel
	if fight_panel == null:
		fight_panel = $Root/FightPanel
	if character_attribute_grid == null:
		character_attribute_grid = $Root/CharacterInfoPanel/PanelLayout/AttributeGrid
	if character_equipment_grid == null:
		character_equipment_grid = $Root/CharacterInfoPanel/PanelLayout/EquipmentGrid
	if character_skill_grid == null:
		character_skill_grid = $Root/CharacterInfoPanel/PanelLayout/SkillGrid
	if inventory_grid == null:
		inventory_grid = $Root/InventoryPanel/InventoryLayout/InventoryGrid
	if inventory_item_detail_panel == null:
		inventory_item_detail_panel = $Root/InventoryPanel/InventoryLayout/InventoryItemDetailPanel
	if inventory_item_detail_label == null:
		inventory_item_detail_label = $Root/InventoryPanel/InventoryLayout/InventoryItemDetailPanel/DetailLabel
	if inventory_menu == null:
		inventory_menu = $Root/InventoryMenu
	if category_row == null:
		category_row = $Root/InventoryPanel/InventoryLayout/CategoryRow
	if farm_detail == null:
		farm_detail = $Root/FarmPanel/PanelLayout/ActionDetail
	if forge_detail == null:
		forge_detail = $Root/ForgePanel/PanelLayout/ActionDetail
	if meditate_detail == null:
		meditate_detail = $Root/MeditatePanel/PanelLayout/ActionDetail
	if fight_detail == null:
		fight_detail = $Root/FightPanel/PanelLayout/ActionDetail
	if alchemy_recipe_slot_button == null:
		alchemy_recipe_slot_button = $Root/AlchemyPanel/PanelLayout/RecipeSlotButton
	if alchemy_recipe_picker_panel == null:
		alchemy_recipe_picker_panel = $Root/AlchemyPanel/PanelLayout/RecipePickerPanel
	if alchemy_recipe_list == null:
		alchemy_recipe_list = $Root/AlchemyPanel/PanelLayout/RecipePickerPanel/RecipeList
	if alchemy_material_grid == null:
		alchemy_material_grid = $Root/AlchemyPanel/PanelLayout/MaterialGrid
	if alchemy_max_count_label == null:
		alchemy_max_count_label = $Root/AlchemyPanel/PanelLayout/MaxCountLabel
	if alchemy_craft_count_spinbox == null:
		alchemy_craft_count_spinbox = $Root/AlchemyPanel/PanelLayout/CraftCountSpinBox
	if alchemy_craft_button == null:
		alchemy_craft_button = $Root/AlchemyPanel/PanelLayout/CraftButton
	if alchemy_hint_label == null:
		alchemy_hint_label = $Root/AlchemyPanel/PanelLayout/HintLabel
	_connect_alchemy_controls()


func _connect_alchemy_controls() -> void:
	if alchemy_controls_connected:
		return
	if alchemy_recipe_slot_button == null or alchemy_recipe_list == null or alchemy_craft_button == null:
		return
	alchemy_recipe_slot_button.pressed.connect(_on_alchemy_recipe_slot_pressed)
	alchemy_recipe_list.item_selected.connect(_on_alchemy_recipe_selected)
	alchemy_craft_button.pressed.connect(_on_alchemy_craft_pressed)
	alchemy_controls_connected = true


func _draggable_panels() -> Array[Control]:
	return [
		menu_panel,
		character_info_panel,
		inventory_panel,
		farm_panel,
		forge_panel,
		alchemy_panel,
		meditate_panel,
		fight_panel,
	]


func _capture_default_panel_positions() -> void:
	_ensure_menu_panel_refs()
	for panel in _draggable_panels():
		if panel == null or saved_panel_positions.has(panel.name):
			continue
		saved_panel_positions[panel.name] = _position_to_dictionary(panel.position)


func _capture_current_panel_positions() -> void:
	for panel in _draggable_panels():
		if panel == null:
			continue
		saved_panel_positions[panel.name] = _position_to_dictionary(panel.position)


func _apply_saved_positions_to_visible_panels() -> void:
	for panel in _draggable_panels():
		if panel != null and panel.visible:
			_apply_saved_panel_position(panel)


func _apply_saved_panel_position(panel: Control) -> void:
	if panel == null or not saved_panel_positions.has(panel.name):
		return
	var position_data = saved_panel_positions[panel.name]
	if not position_data is Dictionary:
		return
	var target: Vector2 = Vector2(float(position_data.get("x", panel.position.x)), float(position_data.get("y", panel.position.y)))
	panel.position = _clamp_panel_position(panel, target)
	saved_panel_positions[panel.name] = _position_to_dictionary(panel.position)


func _begin_panel_drag(mouse_position: Vector2) -> void:
	_ensure_menu_panel_refs()
	for panel in _draggable_panels():
		if panel == null or not panel.visible:
			continue
		var handle := _drag_handle_for_panel(panel)
		if handle == null or not handle.get_global_rect().has_point(mouse_position):
			continue
		if _interactive_child_contains_point(handle, mouse_position):
			continue
		dragging_panel = panel
		drag_mouse_start = mouse_position
		drag_panel_start = panel.position
		return


func _end_panel_drag() -> void:
	if dragging_panel == null:
		return
	dragging_panel.position = _clamp_panel_position(dragging_panel, dragging_panel.position)
	saved_panel_positions[dragging_panel.name] = _position_to_dictionary(dragging_panel.position)
	dragging_panel = null
	hud_save_requested.emit()


func _drag_handle_for_panel(panel: Control) -> Control:
	var header := panel.get_node_or_null("PanelLayout/Header") as Control
	if header != null:
		return header
	return panel


func _interactive_child_contains_point(node: Node, mouse_position: Vector2) -> bool:
	for child in node.get_children():
		if child is Button and child.get_global_rect().has_point(mouse_position):
			return true
		if _interactive_child_contains_point(child, mouse_position):
			return true
	return false


func _clamp_panel_position(panel: Control, target: Vector2) -> Vector2:
	var viewport_size: Vector2 = _viewport_size()
	var panel_size: Vector2 = panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = panel.get_combined_minimum_size()
	var max_x: float = max(DRAG_MARGIN, viewport_size.x - panel_size.x - DRAG_MARGIN)
	var max_y: float = max(DRAG_MARGIN, viewport_size.y - panel_size.y - DRAG_MARGIN)
	return Vector2(
		clampf(target.x, DRAG_MARGIN, max_x),
		clampf(target.y, DRAG_MARGIN, max_y)
	)


func _position_to_dictionary(position: Vector2) -> Dictionary:
	return {"x": float(position.x), "y": float(position.y)}


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		return viewport.get_visible_rect().size
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 480))
	)


func _close_popup_panels() -> void:
	for panel_path in ["Root/CharacterInfoPanel", "Root/InventoryPanel", "Root/FarmPanel", "Root/ForgePanel", "Root/AlchemyPanel", "Root/MeditatePanel", "Root/FightPanel"]:
		var panel := get_node_or_null(panel_path) as Control
		if panel != null:
			panel.visible = false


func _panel_for_task(task_type: int) -> PanelContainer:
	if task_type == GameDefs.TaskType.FARM:
		return get_node_or_null("Root/FarmPanel") as PanelContainer
	if task_type == GameDefs.TaskType.FORGE:
		return get_node_or_null("Root/ForgePanel") as PanelContainer
	if task_type == GameDefs.TaskType.ALCHEMY:
		return get_node_or_null("Root/AlchemyPanel") as PanelContainer
	if task_type == GameDefs.TaskType.MEDITATE:
		return get_node_or_null("Root/MeditatePanel") as PanelContainer
	if task_type == GameDefs.TaskType.FIGHT:
		return get_node_or_null("Root/FightPanel") as PanelContainer
	return null


func _refresh_visible_action_details() -> void:
	if farm_panel.visible:
		_refresh_action_detail(GameDefs.TaskType.FARM)
	if forge_panel.visible:
		_refresh_action_detail(GameDefs.TaskType.FORGE)
	if alchemy_panel.visible:
		_refresh_alchemy_panel()
	if meditate_panel.visible:
		_refresh_action_detail(GameDefs.TaskType.MEDITATE)
	if fight_panel.visible:
		_refresh_action_detail(GameDefs.TaskType.FIGHT)


func _refresh_action_detail(task_type: int) -> void:
	if current_game_state == null:
		return

	if task_type == GameDefs.TaskType.FARM:
		farm_detail.text = "消耗 1 个作物种子\n农田等级：%d\n作物：%d" % [
			int(current_game_state.stats.get("farm_level", 1)),
			current_game_state.inventory_total_for_type(DataTables.ITEM_TYPE_CROP),
		]
	elif task_type == GameDefs.TaskType.FORGE:
		forge_detail.text = "消耗 2 个材料\n材料：%d\n炼器加成：%d" % [
			current_game_state.inventory_total_for_type(DataTables.ITEM_TYPE_MATERIAL),
			current_game_state.craft_bonus(),
		]
	elif task_type == GameDefs.TaskType.MEDITATE:
		meditate_detail.text = "恢复生命和法力\n获得修为：%d\n根骨：%d" % [
			8 + int(current_game_state.stats["level"]),
			int(current_game_state.stats.get("root_bone", 0)),
		]
	elif task_type == GameDefs.TaskType.FIGHT:
		fight_detail.text = "遭遇一次敌人\n攻击：%d\n防御：%d" % [
			current_game_state.total_attack(),
			current_game_state.total_defense(),
		]


func _set_inventory_category(type_id: String) -> void:
	current_inventory_type = type_id
	_refresh_inventory()


func _refresh_inventory() -> void:
	if current_game_state == null:
		return
	_ensure_inventory_slots()

	for button in category_buttons:
		var selected := false
		for category in INVENTORY_CATEGORIES:
			if category["node"] == button.name:
				selected = category["type"] == current_inventory_type
				break
		button.disabled = selected

	var items: Array = current_game_state.inventory_items_for_type(current_inventory_type)
	for index in range(INVENTORY_SLOT_COUNT):
		var item: Dictionary = {}
		if index < items.size():
			item = items[index]
		_update_inventory_slot(index, item)


func _format_inventory_item(item: Dictionary) -> String:
	if item.get("type", "") == DataTables.ITEM_TYPE_EQUIPMENT:
		var equipped_mark := ""
		if bool(item.get("equipped", false)):
			equipped_mark = "[E] "
		return "%s%s [%s] L%d Attr%d +%d R%d ATK%d DEF%d" % [
			equipped_mark,
			item["name"],
			DataTables.slot_name(item.get("slot", "")),
			int(item.get("equipment_level", 1)),
			item.get("base_attributes", []).size(),
			int(item.get("enhance_count", 0)),
			int(item.get("refine_count", 0)),
			item.get("attack_bonus", 0),
			item.get("defense_bonus", 0),
		]

	var count: int = int(item.get("count", 0))
	if count > 1:
		return "%s x%d" % [item["name"], count]
	return item["name"]


func _format_inventory_item_detail(item: Dictionary) -> String:
	var lines := [
		str(item.get("name", "")),
		"类型：%s" % DataTables.item_type_name(str(item.get("type", ""))),
	]
	if int(item.get("count", 0)) > 1:
		lines.append("数量：%d" % int(item.get("count", 0)))
	var description := str(item.get("description", ""))
	if not description.is_empty():
		lines.append(description)
	if item.get("type", "") == DataTables.ITEM_TYPE_EQUIPMENT:
		lines.append("槽位：%s  等级：%d" % [DataTables.slot_name(str(item.get("slot", ""))), int(item.get("equipment_level", 1))])
		if current_game_state != null:
			var requirement_text: String = current_game_state.equipment_requirement_text(item)
			if not requirement_text.is_empty():
				lines.append("穿戴需求：%s" % requirement_text)
		lines.append("强化：+%d  洗练：%d" % [int(item.get("enhance_count", 0)), int(item.get("refine_count", 0))])
		lines.append("ATK:%d DEF:%d" % [int(item.get("attack_bonus", 0)), int(item.get("defense_bonus", 0))])
	elif item.get("type", "") == DataTables.ITEM_TYPE_PILL:
		var payload: Dictionary = item.get("payload", {})
		if payload.get("effect_mode", "instant") == "duration":
			lines.append("效果：%s +%d，持续 %d 秒" % [payload.get("stat", ""), int(payload.get("amount", 0)), int(payload.get("duration", 0))])
		else:
			lines.append("效果：HP +%d MP +%d" % [int(payload.get("hp", 0)), int(payload.get("mp", 0))])
	return "\n".join(lines)


func _ensure_inventory_slots() -> void:
	_ensure_menu_panel_refs()
	if inventory_slot_buttons.size() == INVENTORY_SLOT_COUNT:
		return
	inventory_slot_buttons.clear()
	inventory_slot_instance_ids.clear()
	for child in inventory_grid.get_children():
		child.queue_free()
	for index in range(INVENTORY_SLOT_COUNT):
		var slot := Button.new()
		slot.name = "InventorySlot%d" % (index + 1)
		slot.custom_minimum_size = Vector2(78, 54)
		slot.clip_contents = true
		var layout := VBoxContainer.new()
		layout.name = "SlotLayout"
		slot.add_child(layout)
		var icon := TextureRect.new()
		icon.name = "IconPlaceholder"
		icon.custom_minimum_size = Vector2(36, 18)
		layout.add_child(icon)
		var name_label := Label.new()
		name_label.name = "NameLabel"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		layout.add_child(name_label)
		var count_label := Label.new()
		count_label.name = "CountLabel"
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		layout.add_child(count_label)
		slot.gui_input.connect(func(event, slot_index = index): _on_inventory_slot_gui_input(event, slot_index))
		slot.mouse_entered.connect(func(slot_index = index): _on_inventory_slot_mouse_entered(slot_index))
		slot.mouse_exited.connect(_on_inventory_slot_mouse_exited)
		inventory_grid.add_child(slot)
		inventory_slot_buttons.append(slot)
		inventory_slot_instance_ids.append("")


func _update_inventory_slot(index: int, item: Dictionary) -> void:
	var slot := inventory_slot_buttons[index]
	var name_label := slot.get_node("SlotLayout/NameLabel") as Label
	var count_label := slot.get_node("SlotLayout/CountLabel") as Label
	if item.is_empty():
		inventory_slot_instance_ids[index] = ""
		name_label.text = ""
		count_label.text = ""
		slot.disabled = true
		return
	inventory_slot_instance_ids[index] = str(item.get("instance_id", ""))
	name_label.text = str(item.get("name", ""))
	var count := int(item.get("count", 0))
	count_label.text = "x%d" % count if count > 1 else ""
	slot.disabled = false


func _on_inventory_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_on_inventory_slot_pressed(slot_index)
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_show_inventory_slot_menu(slot_index)


func _on_inventory_slot_pressed(slot_index: int) -> void:
	if current_game_state == null or slot_index < 0 or slot_index >= inventory_slot_instance_ids.size():
		return
	var instance_id := inventory_slot_instance_ids[slot_index]
	if instance_id.is_empty():
		return
	var now_ms := Time.get_ticks_msec()
	var is_double_click := instance_id == last_inventory_click_instance_id and now_ms - last_inventory_click_time_ms <= INVENTORY_DOUBLE_CLICK_MS
	selected_inventory_instance_id = instance_id
	last_inventory_click_instance_id = instance_id
	last_inventory_click_time_ms = now_ms
	if is_double_click and current_game_state.is_inventory_item_direct_usable(instance_id):
		if current_game_state.use_inventory_item(instance_id):
			_refresh_inventory()
			_refresh_visible_action_details()


func _show_inventory_slot_menu(slot_index: int) -> void:
	if current_game_state == null or slot_index < 0 or slot_index >= inventory_slot_instance_ids.size():
		return
	var instance_id := inventory_slot_instance_ids[slot_index]
	if instance_id.is_empty():
		return
	selected_inventory_instance_id = instance_id
	inventory_menu.clear()
	inventory_menu.add_item("使用", MENU_USE)
	inventory_menu.set_item_disabled(0, not current_game_state.is_inventory_item_usable(selected_inventory_instance_id))
	var selected_item: Dictionary = current_game_state.inventory_item_by_instance(selected_inventory_instance_id)
	if selected_item.get("type", "") == DataTables.ITEM_TYPE_EQUIPMENT:
		inventory_menu.add_item("强化", MENU_ENHANCE)
		inventory_menu.add_item("洗练", MENU_AFFIX)
	inventory_menu.add_item("丢弃", MENU_DROP)
	var mouse_position := get_viewport().get_mouse_position()
	inventory_menu.position = Vector2i(int(mouse_position.x), int(mouse_position.y))
	inventory_menu.popup()


func _on_inventory_slot_mouse_entered(slot_index: int) -> void:
	if current_game_state == null or slot_index < 0 or slot_index >= inventory_slot_instance_ids.size():
		return
	var instance_id := inventory_slot_instance_ids[slot_index]
	if instance_id.is_empty():
		inventory_item_detail_panel.visible = false
		return
	var item: Dictionary = current_game_state.inventory_item_by_instance(instance_id)
	if item.is_empty():
		inventory_item_detail_panel.visible = false
		return
	inventory_item_detail_label.text = _format_inventory_item_detail(item)
	inventory_item_detail_panel.visible = true


func _on_inventory_slot_mouse_exited() -> void:
	inventory_item_detail_panel.visible = false


func _on_inventory_menu_id_pressed(id: int) -> void:
	if current_game_state == null or selected_inventory_instance_id.is_empty():
		return

	match id:
		MENU_USE:
			current_game_state.use_inventory_item(selected_inventory_instance_id)
		MENU_ENHANCE:
			current_game_state.enhance_equipment(selected_inventory_instance_id)
		MENU_AFFIX:
			current_game_state.add_equipment_affix(selected_inventory_instance_id)
		MENU_DROP:
			current_game_state.drop_inventory_item(selected_inventory_instance_id)

	_refresh_inventory()
	if alchemy_panel.visible:
		_refresh_alchemy_panel()


func _on_alchemy_recipe_slot_pressed() -> void:
	_ensure_menu_panel_refs()
	_refresh_alchemy_recipe_list()
	alchemy_recipe_picker_panel.visible = true


func _on_alchemy_recipe_selected(index: int) -> void:
	_ensure_menu_panel_refs()
	if index < 0 or index >= alchemy_recipe_list.item_count:
		return
	selected_alchemy_recipe_id = str(alchemy_recipe_list.get_item_metadata(index))
	alchemy_recipe_picker_panel.visible = false
	_refresh_alchemy_panel()


func _on_alchemy_craft_pressed() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null or selected_alchemy_recipe_id.is_empty():
		return
	var amount := int(alchemy_craft_count_spinbox.value)
	if current_game_state.craft_alchemy_recipe(selected_alchemy_recipe_id, amount):
		_refresh_alchemy_recipe_list()
		_refresh_alchemy_panel()
		if inventory_panel.visible:
			_refresh_inventory()


func _refresh_alchemy_panel() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null:
		return

	if selected_alchemy_recipe_id.is_empty() or DataTables.alchemy_recipe_def(selected_alchemy_recipe_id).is_empty():
		alchemy_recipe_slot_button.text = "选择图纸"
		alchemy_max_count_label.text = "最多可做：0"
		alchemy_craft_count_spinbox.min_value = 0.0
		alchemy_craft_count_spinbox.max_value = 0.0
		alchemy_craft_count_spinbox.value = 0.0
		alchemy_craft_button.disabled = true
		alchemy_hint_label.text = "请选择图纸"
		_clear_alchemy_material_grid()
		return

	alchemy_recipe_slot_button.text = DataTables.resource_name(selected_alchemy_recipe_id)
	var max_count: int = current_game_state.alchemy_max_craft_count(selected_alchemy_recipe_id)
	alchemy_max_count_label.text = "最多可做：%d" % max_count
	alchemy_craft_count_spinbox.min_value = 0.0 if max_count <= 0 else 1.0
	alchemy_craft_count_spinbox.max_value = float(max_count)
	alchemy_craft_count_spinbox.value = float(max_count)

	_clear_alchemy_material_grid()
	for material in DataTables.alchemy_recipe_materials(selected_alchemy_recipe_id):
		alchemy_material_grid.add_child(_create_alchemy_material_slot(material))

	var learned: bool = current_game_state.known_alchemy_recipes.has(selected_alchemy_recipe_id)
	alchemy_craft_button.disabled = max_count <= 0 or not learned
	if not learned:
		alchemy_hint_label.text = "尚未学习该丹方"
	elif max_count <= 0:
		alchemy_hint_label.text = "材料不足"
	else:
		alchemy_hint_label.text = "额外出丹：%d%%" % int(current_game_state.alchemy_extra_chance() * 100.0)


func _refresh_alchemy_recipe_list() -> void:
	_ensure_menu_panel_refs()
	alchemy_recipe_list.clear()
	if current_game_state == null:
		return
	for recipe_id in current_game_state.known_alchemy_recipes:
		if recipe_id.is_empty():
			continue
		var label := DataTables.resource_name(recipe_id)
		var index := alchemy_recipe_list.add_item(label)
		alchemy_recipe_list.set_item_metadata(index, recipe_id)


func _clear_alchemy_material_grid() -> void:
	_ensure_menu_panel_refs()
	for child in alchemy_material_grid.get_children():
		child.queue_free()


func _create_alchemy_material_slot(material: Dictionary) -> PanelContainer:
	var item_id: String = material.get("item_id", "")
	var required := int(material.get("amount", 0))
	var current: int = current_game_state.inventory_item_count(item_id)
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(144, 60)

	var layout := VBoxContainer.new()
	layout.name = "SlotLayout"
	slot.add_child(layout)

	var icon := TextureRect.new()
	icon.name = "IconPlaceholder"
	icon.custom_minimum_size = Vector2(28, 18)
	layout.add_child(icon)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = DataTables.resource_name(item_id)
	layout.add_child(name_label)

	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.text = "%d/%d" % [current, required]
	if current < required:
		count_label.modulate = Color(1.0, 0.2, 0.2)
	layout.add_child(count_label)
	return slot
