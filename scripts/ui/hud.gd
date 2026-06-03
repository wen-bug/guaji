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

@onready var menu_panel: PanelContainer = $Root/MenuPanel
@onready var character_info_panel: PanelContainer = $Root/CharacterInfoPanel
@onready var inventory_panel: PanelContainer = $Root/InventoryPanel
@onready var farm_panel: PanelContainer = $Root/FarmPanel
@onready var forge_panel: PanelContainer = $Root/ForgePanel
@onready var alchemy_panel: PanelContainer = $Root/AlchemyPanel
@onready var meditate_panel: PanelContainer = $Root/MeditatePanel
@onready var fight_panel: PanelContainer = $Root/FightPanel
@onready var status_label: Label = $Root/CharacterInfoPanel/PanelLayout/StatusLabel
@onready var element_label: Label = $Root/CharacterInfoPanel/PanelLayout/ElementLabel
@onready var log_label: Label = $Root/CharacterInfoPanel/PanelLayout/LogLabel
@onready var inventory_list: ItemList = $Root/InventoryPanel/InventoryLayout/InventoryList
@onready var inventory_menu: PopupMenu = $Root/InventoryMenu
@onready var category_row: HBoxContainer = $Root/InventoryPanel/InventoryLayout/CategoryRow
@onready var farm_detail: Label = $Root/FarmPanel/PanelLayout/ActionDetail
@onready var forge_detail: Label = $Root/ForgePanel/PanelLayout/ActionDetail
@onready var alchemy_detail: Label = $Root/AlchemyPanel/PanelLayout/ActionDetail
@onready var meditate_detail: Label = $Root/MeditatePanel/PanelLayout/ActionDetail
@onready var fight_detail: Label = $Root/FightPanel/PanelLayout/ActionDetail

var category_buttons: Array[Button] = []
var current_inventory_type := DataTables.ITEM_TYPE_EQUIPMENT
var selected_inventory_instance_id := ""
var current_game_state
var log_lines: Array = []


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
	$Root/AlchemyPanel/PanelLayout/ExecuteButton.pressed.connect(func(): home_action_requested.emit(GameDefs.TaskType.ALCHEMY))
	$Root/MeditatePanel/PanelLayout/ExecuteButton.pressed.connect(func(): home_action_requested.emit(GameDefs.TaskType.MEDITATE))
	$Root/FightPanel/PanelLayout/ExecuteButton.pressed.connect(func(): home_action_requested.emit(GameDefs.TaskType.FIGHT))

	for category in INVENTORY_CATEGORIES:
		var button := category_row.get_node(category["node"]) as Button
		button.text = category["label"]
		button.pressed.connect(func(type_id = category["type"]): _set_inventory_category(type_id))
		category_buttons.append(button)

	inventory_list.allow_rmb_select = true
	inventory_list.item_clicked.connect(_on_inventory_item_clicked)
	inventory_menu.id_pressed.connect(_on_inventory_menu_id_pressed)


func refresh(game_state, _task_manager = null) -> void:
	current_game_state = game_state
	status_label.text = "Lv.%d HP:%d/%d MP:%d/%d 修为:%d/%d %s" % [
		game_state.stats["level"],
		game_state.stats["hp"],
		game_state.stats["max_hp"],
		game_state.stats["mp"],
		game_state.stats["max_mp"],
		game_state.stats["cultivation"],
		game_state.stats["next_cultivation"],
		game_state.resource_summary(),
	]
	element_label.text = "五行：%s  主：%s" % [
		game_state.element_summary(),
		DataTables.element_name(game_state.dominant_element()),
	]

	if inventory_panel.visible:
		_refresh_inventory()
	_refresh_visible_action_details()


func push_log(message: String) -> void:
	log_lines.push_front(message)
	if log_lines.size() > 3:
		log_lines.resize(3)
	var text := ""
	for line in log_lines:
		text += line + "\n"
	log_label.text = text.strip_edges()


func show_home_action_panel(task_type: int) -> void:
	var panel := _panel_for_task(task_type)
	if panel == null:
		return
	_close_popup_panels()
	var menu := get_node_or_null("Root/MenuPanel") as Control
	if menu != null:
		menu.visible = false
	panel.visible = true
	_refresh_action_detail(task_type)


func _toggle_menu() -> void:
	_ensure_menu_panel_refs()
	var next_visible := not menu_panel.visible
	_close_popup_panels()
	menu_panel.visible = next_visible


func _open_character_info_panel() -> void:
	_ensure_menu_panel_refs()
	_close_popup_panels()
	menu_panel.visible = false
	character_info_panel.visible = true


func _open_inventory_panel() -> void:
	_ensure_menu_panel_refs()
	_close_popup_panels()
	menu_panel.visible = false
	inventory_panel.visible = true
	_refresh_inventory()


func _ensure_menu_panel_refs() -> void:
	if menu_panel == null:
		menu_panel = $Root/MenuPanel
	if character_info_panel == null:
		character_info_panel = $Root/CharacterInfoPanel
	if inventory_panel == null:
		inventory_panel = $Root/InventoryPanel


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
		_refresh_action_detail(GameDefs.TaskType.ALCHEMY)
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
	elif task_type == GameDefs.TaskType.ALCHEMY:
		alchemy_detail.text = "消耗 2 个作物\n已学丹方：%d\n额外出丹：%d%%" % [
			current_game_state.known_alchemy_recipes.size(),
			int(current_game_state.alchemy_extra_chance() * 100.0),
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

	for button in category_buttons:
		var selected := false
		for category in INVENTORY_CATEGORIES:
			if category["node"] == button.name:
				selected = category["type"] == current_inventory_type
				break
		button.disabled = selected

	inventory_list.clear()
	for item in current_game_state.inventory_items_for_type(current_inventory_type):
		var index := inventory_list.add_item(_format_inventory_item(item))
		inventory_list.set_item_metadata(index, item["instance_id"])


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


func _on_inventory_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	if current_game_state == null:
		return

	inventory_list.select(index)
	selected_inventory_instance_id = str(inventory_list.get_item_metadata(index))
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
