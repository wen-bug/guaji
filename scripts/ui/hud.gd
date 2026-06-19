class_name Hud
extends CanvasLayer

const MENU_USE := 1
const MENU_DROP := 2
const MENU_ENHANCE := 3
const MENU_AFFIX := 4
const FORGE_MODE_CRAFT := "craft"
const FORGE_MODE_ENHANCE := "enhance"
const FORGE_MODE_REFINE := "refine"
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
signal combat_mode_toggle_requested()
signal combat_action_requested(action_id: String, skill_id: String)
signal expedition_exit_requested()

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
@onready var farm_progress_label: Label = $Root/FarmPanel/PanelLayout/ProgressLabel
@onready var farm_seed_slot_button: Button = $Root/FarmPanel/PanelLayout/SeedSlotButton
@onready var farm_seed_picker_panel: PanelContainer = $Root/FarmPanel/PanelLayout/SeedPickerPanel
@onready var farm_seed_list: ItemList = $Root/FarmPanel/PanelLayout/SeedPickerPanel/SeedList
@onready var farm_slot_list: ItemList = $Root/FarmPanel/PanelLayout/FarmSlotList
@onready var farm_speed_item_slot_button: Button = $Root/FarmPanel/PanelLayout/SpeedItemSlotButton
@onready var farm_speed_item_picker_panel: PanelContainer = $Root/FarmPanel/PanelLayout/SpeedItemPickerPanel
@onready var farm_speed_item_list: ItemList = $Root/FarmPanel/PanelLayout/SpeedItemPickerPanel/SpeedItemList
@onready var farm_speed_status_label: Label = $Root/FarmPanel/PanelLayout/SpeedStatusLabel
@onready var farm_use_speed_item_button: Button = $Root/FarmPanel/PanelLayout/UseSpeedItemButton
@onready var farm_plant_button: Button = $Root/FarmPanel/PanelLayout/ActionRow/PlantButton
@onready var farm_claim_button: Button = $Root/FarmPanel/PanelLayout/ActionRow/ClaimButton
@onready var farm_claim_all_button: Button = $Root/FarmPanel/PanelLayout/ActionRow/ClaimAllButton
@onready var farm_hint_label: Label = $Root/FarmPanel/PanelLayout/HintLabel
@onready var forge_detail: Label = $Root/ForgePanel/PanelLayout/ActionDetail
@onready var forge_progress_label: Label = $Root/ForgePanel/PanelLayout/ProgressLabel
@onready var forge_action_button: Button = $Root/ForgePanel/PanelLayout/ExecuteButton
@onready var forge_craft_mode_button: Button = $Root/ForgePanel/PanelLayout/ModeRow/ForgeCraftButton
@onready var forge_enhance_mode_button: Button = $Root/ForgePanel/PanelLayout/ModeRow/ForgeEnhanceButton
@onready var forge_refine_mode_button: Button = $Root/ForgePanel/PanelLayout/ModeRow/ForgeRefineButton
@onready var forge_equipment_slot_button: Button = $Root/ForgePanel/PanelLayout/EquipmentSlotButton
@onready var forge_equipment_picker_panel: PanelContainer = $Root/ForgePanel/PanelLayout/EquipmentPickerPanel
@onready var forge_equipment_list: ItemList = $Root/ForgePanel/PanelLayout/EquipmentPickerPanel/EquipmentList
@onready var forge_material_grid: GridContainer = $Root/ForgePanel/PanelLayout/MaterialGrid
@onready var forge_hint_label: Label = $Root/ForgePanel/PanelLayout/HintLabel
@onready var meditate_detail: Label = $Root/MeditatePanel/PanelLayout/ActionDetail
@onready var fight_detail: Label = $Root/FightPanel/PanelLayout/ActionDetail
@onready var battle_action_hud: PanelContainer = $Root/BattleActionHud
@onready var battle_mode_button: Button = $Root/BattleActionHud/ActionLayout/ModeButton
@onready var battle_status_label: Label = $Root/BattleActionHud/ActionLayout/StatusLabel
@onready var battle_attack_button: Button = $Root/BattleActionHud/ActionLayout/AttackButton
@onready var battle_defend_button: Button = $Root/BattleActionHud/ActionLayout/DefendButton
@onready var battle_skill_button_row: HBoxContainer = $Root/BattleActionHud/ActionLayout/SkillButtonRow
@onready var expedition_exit_button: Button = $Root/BattleActionHud/ActionLayout/ExitExpeditionButton
@onready var window_drag_button: Button = $Root/WindowDragButton
@onready var damage_feedback_label: Label = $Root/BattleActionHud/DamageFeedbackLabel
@onready var alchemy_recipe_slot_button: Button = $Root/AlchemyPanel/PanelLayout/RecipeSlotButton
@onready var alchemy_recipe_picker_panel: PanelContainer = $Root/AlchemyPanel/PanelLayout/RecipePickerPanel
@onready var alchemy_recipe_list: ItemList = $Root/AlchemyPanel/PanelLayout/RecipePickerPanel/RecipeList
@onready var alchemy_material_grid: GridContainer = $Root/AlchemyPanel/PanelLayout/MaterialGrid
@onready var alchemy_max_count_label: Label = $Root/AlchemyPanel/PanelLayout/MaxCountLabel
@onready var alchemy_craft_count_spinbox: SpinBox = $Root/AlchemyPanel/PanelLayout/CraftCountSpinBox
@onready var alchemy_craft_button: Button = $Root/AlchemyPanel/PanelLayout/CraftButton
@onready var alchemy_progress_label: Label = $Root/AlchemyPanel/PanelLayout/ProgressLabel
@onready var alchemy_hint_label: Label = $Root/AlchemyPanel/PanelLayout/HintLabel

var category_buttons: Array[Button] = []
var inventory_slot_buttons: Array[Button] = []
var inventory_slot_instance_ids: Array[String] = []
var current_inventory_type := DataTables.ITEM_TYPE_EQUIPMENT
var selected_inventory_instance_id := ""
var last_inventory_click_instance_id := ""
var last_inventory_click_time_ms := 0
var current_game_state
var current_progress_state := {}
var log_lines: Array = []
var selected_farm_seed_id := ""
var selected_farm_slot_index := -1
var selected_farm_speed_item_id := ""
var farm_controls_connected := false
var selected_forge_mode := FORGE_MODE_CRAFT
var selected_forge_equipment_instance_id := ""
var forge_controls_connected := false
var selected_alchemy_recipe_id := ""
var alchemy_controls_connected := false
var saved_panel_positions := {}
var dragging_panel: Control = null
var drag_mouse_start := Vector2.ZERO
var drag_panel_start := Vector2.ZERO
var dragging_window := false
var window_drag_mouse_start := Vector2.ZERO
var window_drag_start_position := Vector2i.ZERO
var damage_feedback_tween: Tween = null
var menu_button_hover_tween: Tween = null


func _ready() -> void:

	$Root/CharacterInfoPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): character_info_panel.visible = false)
	$Root/InventoryPanel/InventoryLayout/Header/CloseButton.pressed.connect(func(): inventory_panel.visible = false)
	$Root/FarmPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): farm_panel.visible = false)
	$Root/ForgePanel/PanelLayout/Header/CloseButton.pressed.connect(func(): forge_panel.visible = false)
	$Root/AlchemyPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): alchemy_panel.visible = false)
	$Root/MeditatePanel/PanelLayout/Header/CloseButton.pressed.connect(func(): meditate_panel.visible = false)
	$Root/FightPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): fight_panel.visible = false)

	$Root/MeditatePanel/PanelLayout/ExecuteButton.pressed.connect(func(): home_action_requested.emit(GameDefs.TaskType.MEDITATE))
	$Root/FightPanel/PanelLayout/ExecuteButton.pressed.connect(func(): home_action_requested.emit(GameDefs.TaskType.FIGHT))
	battle_mode_button.pressed.connect(func(): combat_mode_toggle_requested.emit())
	battle_attack_button.pressed.connect(func(): combat_action_requested.emit("attack", ""))
	battle_defend_button.pressed.connect(func(): combat_action_requested.emit("defend", ""))
	expedition_exit_button.pressed.connect(func(): expedition_exit_requested.emit())
	_connect_farm_controls()
	_connect_forge_controls()
	_connect_alchemy_controls()

	for category in INVENTORY_CATEGORIES:
		var button := category_row.get_node(category["node"]) as Button
		button.text = category["label"]
		button.pressed.connect(func(type_id = category["type"]): _set_inventory_category(type_id))
		category_buttons.append(button)

	inventory_menu.id_pressed.connect(_on_inventory_menu_id_pressed)
	_ensure_inventory_slots()
	_capture_default_panel_positions()
	$Root/MenuButton.pivot_offset = $Root/MenuButton.size * 0.5
	window_drag_button.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_menu_button_mouse_entered() -> void:
	_animate_menu_button_hover(true)


func _on_menu_button_mouse_exited() -> void:
	_animate_menu_button_hover(false)


func _animate_menu_button_hover(hovered: bool) -> void:
	var button := $Root/MenuButton as Button
	if menu_button_hover_tween != null:
		menu_button_hover_tween.kill()
		menu_button_hover_tween = null

	var target_scale := Vector2(1.08, 1.08) if hovered else Vector2.ONE
	menu_button_hover_tween = create_tween()
	menu_button_hover_tween.set_trans(Tween.TRANS_SINE)
	menu_button_hover_tween.set_ease(Tween.EASE_OUT)
	menu_button_hover_tween.tween_property(button, "scale", target_scale, 0.12)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _begin_window_drag(event.position):
				return
			_begin_panel_drag(event.position)
		else:
			_end_window_drag()
			_end_panel_drag()
	elif event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if dragging_window:
			var delta := motion_event.position - window_drag_mouse_start
			DisplayServer.window_set_position(window_drag_start_position + Vector2i(roundi(delta.x), roundi(delta.y)))
		elif dragging_panel != null:
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


func refresh(game_state, combat = null, expedition_active := false) -> void:
	_ensure_menu_panel_refs()
	current_game_state = game_state
	current_progress_state = game_state.progress_states.duplicate(true) if game_state != null else {}
	_refresh_character_info(game_state)
	_refresh_battle_action_hud(game_state, combat, expedition_active)

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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.13, 0.08, 0.88)
	style.border_color = Color(0.72, 0.55, 0.28, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	slot.add_theme_stylebox_override("panel", style)
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
	name_label.add_theme_color_override("font_color", Color(1, 0.93, 0.74, 1))
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


func _refresh_battle_action_hud(game_state, combat, expedition_active := false) -> void:
	_ensure_menu_panel_refs()
	var in_combat := combat != null and bool(combat.active) and not bool(combat.finished)
	battle_action_hud.visible = in_combat or expedition_active
	expedition_exit_button.visible = expedition_active
	if not in_combat or game_state == null:
		battle_mode_button.visible = false
		battle_status_label.visible = false
		battle_attack_button.visible = false
		battle_defend_button.visible = false
		_clear_control_children(battle_skill_button_row)
		return
	battle_mode_button.visible = true
	battle_status_label.visible = true
	battle_attack_button.visible = true
	battle_defend_button.visible = true

	var status: Dictionary = combat.combat_status()
	var mode: String = status.get("player_mode", "auto")
	var is_manual := mode == "manual"
	var turn_ready := bool(status.get("player_turn_ready", false))
	var pending_mode: String = status.get("pending_player_mode", "")
	battle_mode_button.text = "切手动" if mode == "auto" else "切自动"
	battle_status_label.text = _battle_status_text(mode, pending_mode, turn_ready, bool(status.get("defending", false)))
	battle_attack_button.disabled = not (is_manual and turn_ready)
	battle_defend_button.disabled = not (is_manual and turn_ready)
	_refresh_battle_skill_buttons(game_state, status, is_manual and turn_ready)


func _battle_status_text(mode: String, pending_mode: String, turn_ready: bool, is_defending: bool) -> String:
	if not pending_mode.is_empty():
		return "本轮后切%s" % ("自动" if pending_mode == "auto" else "手动")
	if is_defending:
		return "防御中"
	if mode == "auto":
		return "自动战斗"
	return "请选择动作" if turn_ready else "等待回合"


func _refresh_battle_skill_buttons(game_state, status: Dictionary, can_act: bool) -> void:
	_clear_control_children(battle_skill_button_row)
	var cooldowns: Dictionary = status.get("skill_cooldowns", {})
	for skill in game_state.skills:
		var skill_id: String = skill.get("id", "")
		if skill_id.is_empty():
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(98, 32)
		_style_inventory_slot_button(button)
		var cooldown := float(cooldowns.get(skill_id, 0.0))
		var mp_cost := int(skill.get("mp_cost", 0))
		button.text = "%s MP%d" % [skill.get("name", skill_id), mp_cost]
		if cooldown > 0.0:
			button.text = "%s %.1fs" % [skill.get("name", skill_id), cooldown]
		button.disabled = not can_act or cooldown > 0.0 or int(game_state.stats.get("mp", 0)) < mp_cost
		button.pressed.connect(func(id = skill_id): combat_action_requested.emit("skill", id))
		battle_skill_button_row.add_child(button)


func show_damage_feedback(payload: Dictionary) -> void:
	_ensure_menu_panel_refs()
	if damage_feedback_label == null:
		return
	var damage := int(payload.get("damage", 0))
	var message := str(payload.get("message", ""))
	var skill_name := str(payload.get("skill_name", ""))
	if damage > 0:
		damage_feedback_label.text = "%s -%d" % [skill_name if not skill_name.is_empty() else message, damage]
	else:
		damage_feedback_label.text = message
	damage_feedback_label.visible = true
	damage_feedback_label.modulate = Color(1, 1, 1, 1)
	if damage_feedback_tween != null:
		damage_feedback_tween.kill()
	damage_feedback_tween = create_tween()
	damage_feedback_tween.tween_property(damage_feedback_label, "position:y", damage_feedback_label.position.y - 8.0, 0.18)
	damage_feedback_tween.parallel().tween_property(damage_feedback_label, "modulate:a", 0.0, 0.45).set_delay(0.25)
	damage_feedback_tween.tween_callback(func(): damage_feedback_label.visible = false)


func _begin_window_drag(mouse_position: Vector2) -> bool:
	_ensure_menu_panel_refs()
	if window_drag_button == null or not window_drag_button.get_global_rect().has_point(mouse_position):
		return false
	dragging_window = true
	window_drag_mouse_start = mouse_position
	window_drag_start_position = DisplayServer.window_get_position()
	return true


func _end_window_drag() -> void:
	dragging_window = false


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
	if task_type == GameDefs.TaskType.FARM:
		_refresh_farm_panel()
	if task_type == GameDefs.TaskType.FORGE:
		_refresh_forge_panel()
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
	if farm_progress_label == null:
		farm_progress_label = $Root/FarmPanel/PanelLayout/ProgressLabel
	if farm_seed_slot_button == null:
		farm_seed_slot_button = $Root/FarmPanel/PanelLayout/SeedSlotButton
	if farm_seed_picker_panel == null:
		farm_seed_picker_panel = $Root/FarmPanel/PanelLayout/SeedPickerPanel
	if farm_seed_list == null:
		farm_seed_list = $Root/FarmPanel/PanelLayout/SeedPickerPanel/SeedList
	if farm_slot_list == null:
		farm_slot_list = $Root/FarmPanel/PanelLayout/FarmSlotList
	if farm_speed_item_slot_button == null:
		farm_speed_item_slot_button = $Root/FarmPanel/PanelLayout/SpeedItemSlotButton
	if farm_speed_item_picker_panel == null:
		farm_speed_item_picker_panel = $Root/FarmPanel/PanelLayout/SpeedItemPickerPanel
	if farm_speed_item_list == null:
		farm_speed_item_list = $Root/FarmPanel/PanelLayout/SpeedItemPickerPanel/SpeedItemList
	if farm_speed_status_label == null:
		farm_speed_status_label = $Root/FarmPanel/PanelLayout/SpeedStatusLabel
	if farm_use_speed_item_button == null:
		farm_use_speed_item_button = $Root/FarmPanel/PanelLayout/UseSpeedItemButton
	if farm_plant_button == null:
		farm_plant_button = $Root/FarmPanel/PanelLayout/ActionRow/PlantButton
	if farm_claim_button == null:
		farm_claim_button = $Root/FarmPanel/PanelLayout/ActionRow/ClaimButton
	if farm_claim_all_button == null:
		farm_claim_all_button = $Root/FarmPanel/PanelLayout/ActionRow/ClaimAllButton
	if farm_hint_label == null:
		farm_hint_label = $Root/FarmPanel/PanelLayout/HintLabel
	if forge_detail == null:
		forge_detail = $Root/ForgePanel/PanelLayout/ActionDetail
	if forge_progress_label == null:
		forge_progress_label = $Root/ForgePanel/PanelLayout/ProgressLabel
	if forge_action_button == null:
		forge_action_button = $Root/ForgePanel/PanelLayout/ExecuteButton
	if forge_craft_mode_button == null:
		forge_craft_mode_button = $Root/ForgePanel/PanelLayout/ModeRow/ForgeCraftButton
	if forge_enhance_mode_button == null:
		forge_enhance_mode_button = $Root/ForgePanel/PanelLayout/ModeRow/ForgeEnhanceButton
	if forge_refine_mode_button == null:
		forge_refine_mode_button = $Root/ForgePanel/PanelLayout/ModeRow/ForgeRefineButton
	if forge_equipment_slot_button == null:
		forge_equipment_slot_button = $Root/ForgePanel/PanelLayout/EquipmentSlotButton
	if forge_equipment_picker_panel == null:
		forge_equipment_picker_panel = $Root/ForgePanel/PanelLayout/EquipmentPickerPanel
	if forge_equipment_list == null:
		forge_equipment_list = $Root/ForgePanel/PanelLayout/EquipmentPickerPanel/EquipmentList
	if forge_material_grid == null:
		forge_material_grid = $Root/ForgePanel/PanelLayout/MaterialGrid
	if forge_hint_label == null:
		forge_hint_label = $Root/ForgePanel/PanelLayout/HintLabel
	if meditate_detail == null:
		meditate_detail = $Root/MeditatePanel/PanelLayout/ActionDetail
	if fight_detail == null:
		fight_detail = $Root/FightPanel/PanelLayout/ActionDetail
	if battle_action_hud == null:
		battle_action_hud = $Root/BattleActionHud
	if battle_mode_button == null:
		battle_mode_button = $Root/BattleActionHud/ActionLayout/ModeButton
	if battle_status_label == null:
		battle_status_label = $Root/BattleActionHud/ActionLayout/StatusLabel
	if battle_attack_button == null:
		battle_attack_button = $Root/BattleActionHud/ActionLayout/AttackButton
	if battle_defend_button == null:
		battle_defend_button = $Root/BattleActionHud/ActionLayout/DefendButton
	if battle_skill_button_row == null:
		battle_skill_button_row = $Root/BattleActionHud/ActionLayout/SkillButtonRow
	if expedition_exit_button == null:
		expedition_exit_button = $Root/BattleActionHud/ActionLayout/ExitExpeditionButton
	if window_drag_button == null:
		window_drag_button = $Root/WindowDragButton
	if damage_feedback_label == null:
		damage_feedback_label = $Root/BattleActionHud/DamageFeedbackLabel
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
	if alchemy_progress_label == null:
		alchemy_progress_label = $Root/AlchemyPanel/PanelLayout/ProgressLabel
	if alchemy_hint_label == null:
		alchemy_hint_label = $Root/AlchemyPanel/PanelLayout/HintLabel
	_connect_farm_controls()
	_connect_forge_controls()
	_connect_alchemy_controls()


func _connect_farm_controls() -> void:
	if farm_controls_connected:
		return
	if farm_seed_slot_button == null or farm_seed_list == null or farm_slot_list == null or farm_plant_button == null:
		return
	farm_seed_slot_button.pressed.connect(_on_farm_seed_slot_pressed)
	farm_seed_list.item_selected.connect(_on_farm_seed_selected)
	farm_slot_list.item_selected.connect(_on_farm_slot_selected)
	farm_speed_item_slot_button.pressed.connect(_on_farm_speed_item_slot_pressed)
	farm_speed_item_list.item_selected.connect(_on_farm_speed_item_selected)
	farm_use_speed_item_button.pressed.connect(_on_farm_use_speed_item_pressed)
	farm_plant_button.pressed.connect(_on_farm_plant_pressed)
	farm_claim_button.pressed.connect(_on_farm_claim_pressed)
	farm_claim_all_button.pressed.connect(_on_farm_claim_all_pressed)
	farm_controls_connected = true


func _connect_forge_controls() -> void:
	if forge_controls_connected:
		return
	if forge_craft_mode_button == null or forge_enhance_mode_button == null or forge_refine_mode_button == null or forge_action_button == null:
		return
	forge_craft_mode_button.pressed.connect(func(): _set_forge_mode(FORGE_MODE_CRAFT))
	forge_enhance_mode_button.pressed.connect(func(): _set_forge_mode(FORGE_MODE_ENHANCE))
	forge_refine_mode_button.pressed.connect(func(): _set_forge_mode(FORGE_MODE_REFINE))
	forge_equipment_slot_button.pressed.connect(_on_forge_equipment_slot_pressed)
	forge_equipment_list.item_selected.connect(_on_forge_equipment_selected)
	forge_action_button.pressed.connect(_on_forge_action_pressed)
	forge_controls_connected = true


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
		_refresh_farm_panel()
	if forge_panel.visible:
		_refresh_forge_panel()
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
		_refresh_farm_panel()
	elif task_type == GameDefs.TaskType.FORGE:
		_refresh_forge_panel()
	elif task_type == GameDefs.TaskType.MEDITATE:
		meditate_detail.text = "???????\n?????%d\n???%d" % [
			8 + int(current_game_state.stats["level"]),
			int(current_game_state.stats.get("root_bone", 0)),
		]
	elif task_type == GameDefs.TaskType.FIGHT:
		fight_detail.text = "??????\n???%d\n???%d" % [
			current_game_state.total_attack(),
			current_game_state.total_defense(),
		]


func _progress_label_text(progress_id: String) -> String:
	return "???%s" % _progress_summary(progress_id)


func _action_button_text(progress_id: String) -> String:
	var progress: Dictionary = current_game_state.progress_state(progress_id) if current_game_state != null else {}
	if bool(progress.get("claimable", false)):
		return "??"
	if bool(progress.get("completed", false)):
		return "???"
	if progress_id == "farm":
		return "??"
	if progress_id == "forge":
		return "??"
	return "??"


func _action_button_disabled(progress_id: String) -> bool:
	var progress: Dictionary = current_game_state.progress_state(progress_id) if current_game_state != null else {}
	if bool(progress.get("claimable", false)):
		return false
	if progress_id == "farm":
		return current_game_state == null or current_game_state.inventory_total_for_type(DataTables.ITEM_TYPE_CROP) <= 0
	if progress_id == "forge":
		return current_game_state == null or current_game_state.inventory_total_for_type(DataTables.ITEM_TYPE_MATERIAL) <= 0
	return current_game_state == null


func _progress_summary(progress_id: String) -> String:
	if current_game_state == null:
		return "not_started / ???"
	var progress: Dictionary = current_game_state.progress_state(progress_id)
	var status := str(progress.get("status", "not_started"))
	var detail := str(progress.get("detail", ""))
	if detail.is_empty():
		detail = "???"
	return "%s / %s" % [status, detail]


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
		_style_inventory_slot_button(slot)
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


func _style_inventory_slot_button(slot: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.11, 0.07, 0.92)
	normal.border_color = Color(0.55, 0.42, 0.24, 0.9)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_right = 5
	normal.corner_radius_bottom_left = 5
	normal.content_margin_left = 4.0
	normal.content_margin_top = 4.0
	normal.content_margin_right = 4.0
	normal.content_margin_bottom = 4.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.17, 0.09, 1)
	hover.border_color = Color(0.9, 0.72, 0.38, 1)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.1, 0.08, 0.06, 0.6)
	disabled.border_color = Color(0.28, 0.23, 0.18, 0.75)
	slot.add_theme_stylebox_override("normal", normal)
	slot.add_theme_stylebox_override("hover", hover)
	slot.add_theme_stylebox_override("pressed", hover)
	slot.add_theme_stylebox_override("focus", hover)
	slot.add_theme_stylebox_override("disabled", disabled)


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
	if farm_panel.visible:
		_refresh_farm_panel()
	if forge_panel.visible:
		_refresh_forge_panel()
	if alchemy_panel.visible:
		_refresh_alchemy_panel()


func _on_farm_seed_slot_pressed() -> void:
	_ensure_menu_panel_refs()
	_refresh_farm_seed_list()
	farm_seed_picker_panel.visible = true


func _on_farm_seed_selected(index: int) -> void:
	_ensure_menu_panel_refs()
	if index < 0 or index >= farm_seed_list.item_count:
		return
	selected_farm_seed_id = str(farm_seed_list.get_item_metadata(index))
	farm_seed_picker_panel.visible = false
	_refresh_farm_panel()


func _on_farm_slot_selected(index: int) -> void:
	selected_farm_slot_index = index
	_refresh_farm_panel()


func _on_farm_speed_item_slot_pressed() -> void:
	_ensure_menu_panel_refs()
	_refresh_farm_speed_item_list()
	farm_speed_item_picker_panel.visible = true


func _on_farm_speed_item_selected(index: int) -> void:
	_ensure_menu_panel_refs()
	if index < 0 or index >= farm_speed_item_list.item_count:
		return
	selected_farm_speed_item_id = str(farm_speed_item_list.get_item_metadata(index))
	farm_speed_item_picker_panel.visible = false
	_refresh_farm_panel()


func _on_farm_use_speed_item_pressed() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null or selected_farm_speed_item_id.is_empty():
		return
	if current_game_state.use_farm_speed_item(selected_farm_speed_item_id):
		_refresh_farm_panel()
		if inventory_panel.visible:
			_refresh_inventory()


func _on_farm_plant_pressed() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null or selected_farm_slot_index < 0 or selected_farm_seed_id.is_empty():
		return
	if current_game_state.plant_farm_slot(selected_farm_slot_index, selected_farm_seed_id):
		_refresh_farm_panel()
		if inventory_panel.visible:
			_refresh_inventory()


func _on_farm_claim_pressed() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null or selected_farm_slot_index < 0:
		return
	if current_game_state.claim_farm_slot(selected_farm_slot_index):
		_refresh_farm_panel()
		if inventory_panel.visible:
			_refresh_inventory()


func _on_farm_claim_all_pressed() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null:
		return
	if current_game_state.claim_all_farm_slots() > 0:
		_refresh_farm_panel()
		if inventory_panel.visible:
			_refresh_inventory()


func _refresh_farm_panel() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null:
		return
	if selected_farm_slot_index >= current_game_state.farm_slots.size():
		selected_farm_slot_index = -1
	farm_progress_label.text = _progress_label_text("farm")
	farm_seed_slot_button.text = "选择种子" if selected_farm_seed_id.is_empty() else DataTables.resource_name(selected_farm_seed_id)
	farm_speed_item_slot_button.text = "选择加速道具" if selected_farm_speed_item_id.is_empty() else DataTables.resource_name(selected_farm_speed_item_id)
	farm_speed_status_label.text = "当前倍率：x%.1f  剩余：%s" % [current_game_state.farm_speed_multiplier(), _format_seconds(current_game_state.farm_speed_remaining_seconds())]
	_refresh_farm_slot_list()
	_refresh_farm_buttons()


func _refresh_farm_buttons() -> void:
	var selected_slot := _selected_farm_slot()
	var selected_status := str(selected_slot.get("status", "empty"))
	var can_plant: bool = selected_farm_slot_index >= 0 and selected_status == "empty" and not selected_farm_seed_id.is_empty() and current_game_state.inventory_item_count(selected_farm_seed_id) > 0
	var can_claim: bool = selected_farm_slot_index >= 0 and selected_status == "ready"
	farm_plant_button.disabled = not can_plant
	farm_claim_button.disabled = not can_claim
	farm_claim_all_button.disabled = current_game_state.ready_farm_slot_count() <= 0
	var can_use_speed: bool = not selected_farm_speed_item_id.is_empty() and current_game_state.inventory_item_count(selected_farm_speed_item_id) > 0
	farm_use_speed_item_button.disabled = not can_use_speed
	farm_speed_item_slot_button.disabled = false
	if can_use_speed:
		farm_speed_item_slot_button.text = DataTables.resource_name(selected_farm_speed_item_id)
	if selected_farm_slot_index < 0:
		farm_hint_label.text = "请选择农田槽位"
	elif selected_status == "empty":
		farm_hint_label.text = "选择种子后可种植到空槽"
	elif selected_status == "growing":
		farm_hint_label.text = "作物生长中：%s / %s" % [_format_seconds(float(selected_slot.get("elapsed_seconds", 0.0))), _format_seconds(float(selected_slot.get("growth_seconds", 0.0)))]
	else:
		farm_hint_label.text = "作物已成熟，可收取"
	farm_detail.text = "农田等级：%d  空槽：%d  成熟：%d" % [int(current_game_state.stats.get("farm_level", 1)), _empty_farm_slot_count(), current_game_state.ready_farm_slot_count()]


func _refresh_farm_seed_list() -> void:
	_ensure_menu_panel_refs()
	farm_seed_list.clear()
	if current_game_state == null:
		return
	for item in current_game_state.inventory_items_for_type(DataTables.ITEM_TYPE_CROP):
		var item_id := str(item.get("item_id", ""))
		if not DataTables.is_farm_seed(item_id):
			continue
		var count: int = current_game_state.inventory_item_count(item_id)
		var label := "%s x%d  产量%d  %s" % [DataTables.resource_name(item_id), count, DataTables.crop_seed_yield(item_id) + int(current_game_state.stats.get("farm_level", 1)) - 1, _format_seconds(DataTables.crop_growth_seconds(item_id))]
		var index := farm_seed_list.add_item(label)
		farm_seed_list.set_item_metadata(index, item_id)


func _refresh_farm_speed_item_list() -> void:
	_ensure_menu_panel_refs()
	farm_speed_item_list.clear()
	if current_game_state == null:
		return
	for item in current_game_state.inventory_items_for_type(DataTables.ITEM_TYPE_MATERIAL):
		var item_id := str(item.get("item_id", ""))
		if not DataTables.is_farm_speed_item(item_id):
			continue
		var label := "%s x%d  x%.1f/%s" % [DataTables.resource_name(item_id), current_game_state.inventory_item_count(item_id), DataTables.farm_speed_item_multiplier(item_id), _format_seconds(DataTables.farm_speed_item_duration(item_id))]
		var index := farm_speed_item_list.add_item(label)
		farm_speed_item_list.set_item_metadata(index, item_id)


func _refresh_farm_slot_list() -> void:
	farm_slot_list.clear()
	for index in range(current_game_state.farm_slots.size()):
		var slot: Dictionary = current_game_state.farm_slots[index]
		var label := _farm_slot_label(index, slot)
		farm_slot_list.add_item(label)
	if selected_farm_slot_index >= 0 and selected_farm_slot_index < farm_slot_list.item_count:
		farm_slot_list.select(selected_farm_slot_index)


func _farm_slot_label(index: int, slot: Dictionary) -> String:
	var status := str(slot.get("status", "empty"))
	if status == "empty":
		return "%d. 空地" % (index + 1)
	var crop_id := str(slot.get("crop_id", ""))
	var amount := int(slot.get("harvest_amount", 0))
	if status == "ready":
		return "%d. %s x%d  已成熟" % [index + 1, DataTables.resource_name(crop_id), amount]
	var elapsed := float(slot.get("elapsed_seconds", 0.0))
	var growth := float(slot.get("growth_seconds", 1.0))
	var percent := int(clamp(elapsed / max(1.0, growth) * 100.0, 0.0, 100.0))
	return "%d. %s x%d  %d%%  剩余%s" % [index + 1, DataTables.resource_name(crop_id), amount, percent, _format_seconds(max(0.0, growth - elapsed))]


func _selected_farm_slot() -> Dictionary:
	if current_game_state == null or selected_farm_slot_index < 0 or selected_farm_slot_index >= current_game_state.farm_slots.size():
		return {}
	return current_game_state.farm_slots[selected_farm_slot_index]


func _empty_farm_slot_count() -> int:
	var count := 0
	for slot in current_game_state.farm_slots:
		if str(slot.get("status", "empty")) == "empty":
			count += 1
	return count


func _format_seconds(seconds: float) -> String:
	var total := maxi(0, int(ceil(seconds)))
	var minutes := total / 60
	var rest := total % 60
	return "%02d:%02d" % [minutes, rest]


func _set_forge_mode(mode: String) -> void:
	selected_forge_mode = mode
	if forge_equipment_picker_panel != null:
		forge_equipment_picker_panel.visible = false
	_refresh_forge_panel()


func _on_forge_equipment_slot_pressed() -> void:
	_ensure_menu_panel_refs()
	_refresh_forge_equipment_list()
	forge_equipment_picker_panel.visible = true


func _on_forge_equipment_selected(index: int) -> void:
	_ensure_menu_panel_refs()
	if index < 0 or index >= forge_equipment_list.item_count:
		return
	selected_forge_equipment_instance_id = str(forge_equipment_list.get_item_metadata(index))
	forge_equipment_picker_panel.visible = false
	_refresh_forge_panel()


func _on_forge_action_pressed() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null:
		return
	if selected_forge_mode == FORGE_MODE_CRAFT:
		home_action_requested.emit(GameDefs.TaskType.FORGE)
		return
	if selected_forge_equipment_instance_id.is_empty():
		return
	var succeeded := false
	if selected_forge_mode == FORGE_MODE_ENHANCE:
		succeeded = current_game_state.enhance_equipment(selected_forge_equipment_instance_id)
	elif selected_forge_mode == FORGE_MODE_REFINE:
		succeeded = current_game_state.add_equipment_affix(selected_forge_equipment_instance_id)
	if succeeded:
		_refresh_forge_equipment_list()
		_refresh_forge_panel()
		if inventory_panel.visible:
			_refresh_inventory()
		if character_info_panel.visible:
			_refresh_character_info(current_game_state)


func _refresh_forge_panel() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null:
		return
	if not [FORGE_MODE_CRAFT, FORGE_MODE_ENHANCE, FORGE_MODE_REFINE].has(selected_forge_mode):
		selected_forge_mode = FORGE_MODE_CRAFT

	forge_craft_mode_button.disabled = selected_forge_mode == FORGE_MODE_CRAFT
	forge_enhance_mode_button.disabled = selected_forge_mode == FORGE_MODE_ENHANCE
	forge_refine_mode_button.disabled = selected_forge_mode == FORGE_MODE_REFINE
	forge_progress_label.text = _progress_label_text("forge")
	_clear_forge_material_grid()

	if selected_forge_mode == FORGE_MODE_CRAFT:
		_refresh_forge_craft_panel()
	else:
		_refresh_forge_equipment_action_panel()


func _refresh_forge_craft_panel() -> void:
	forge_equipment_slot_button.visible = false
	forge_equipment_picker_panel.visible = false
	forge_action_button.text = "开始炼器"
	forge_action_button.disabled = _action_button_disabled("forge")
	forge_detail.text = "可用材料：%d / 2" % current_game_state.inventory_total_for_type(DataTables.ITEM_TYPE_MATERIAL)
	forge_material_grid.add_child(_create_forge_material_slot("material", "任意材料", current_game_state.inventory_total_for_type(DataTables.ITEM_TYPE_MATERIAL), 2))
	forge_material_grid.add_child(_create_forge_material_slot("bonus", "根骨加成", current_game_state.craft_bonus(), 0))
	if forge_action_button.disabled:
		forge_hint_label.text = "材料不足，炼器需要 2 个任意材料"
	else:
		forge_hint_label.text = "消耗 2 个材料，随机炼制一件装备。根骨加成：%d" % current_game_state.craft_bonus()


func _refresh_forge_equipment_action_panel() -> void:
	forge_equipment_slot_button.visible = true
	var selected_item: Dictionary = current_game_state.inventory_item_by_instance(selected_forge_equipment_instance_id)
	if selected_item.is_empty() or selected_item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		selected_forge_equipment_instance_id = ""
		forge_equipment_slot_button.text = "选择装备"
	else:
		forge_equipment_slot_button.text = str(selected_item.get("name", "装备"))

	var has_selection := not selected_forge_equipment_instance_id.is_empty()
	forge_action_button.disabled = not has_selection
	if selected_forge_mode == FORGE_MODE_ENHANCE:
		forge_action_button.text = "强化装备"
		_refresh_forge_enhance_cost(selected_item)
	elif selected_forge_mode == FORGE_MODE_REFINE:
		forge_action_button.text = "洗练装备"
		_refresh_forge_refine_cost(selected_item)
	if not has_selection:
		forge_hint_label.text = "请选择装备"


func _refresh_forge_enhance_cost(item: Dictionary) -> void:
	var cost := int(item.get("enhance_count", 0)) + 1 if not item.is_empty() else 1
	forge_detail.text = "强化消耗：匹配灵石 x%d" % cost
	if item.is_empty():
		forge_material_grid.add_child(_create_forge_material_slot("stone", "匹配灵石", 0, cost))
		return
	var best_item_id := _first_matching_enhance_stone_id(item, cost)
	if best_item_id.is_empty():
		forge_material_grid.add_child(_create_forge_material_slot("stone", "匹配灵石", 0, cost))
		forge_hint_label.text = "缺少可强化该装备属性的灵石"
	else:
		var current: int = current_game_state.inventory_item_count(best_item_id)
		forge_material_grid.add_child(_create_forge_material_slot(best_item_id, DataTables.resource_name(best_item_id), current, cost))
		forge_hint_label.text = "强化等级：+%d → +%d" % [int(item.get("enhance_count", 0)), int(item.get("enhance_count", 0)) + 1]


func _refresh_forge_refine_cost(item: Dictionary) -> void:
	var cost := int(item.get("refine_count", 0)) + 1 if not item.is_empty() else 1
	var current: int = current_game_state.inventory_item_count("refine_talisman")
	forge_detail.text = "洗练消耗：洗练符 x%d" % cost
	forge_material_grid.add_child(_create_forge_material_slot("refine_talisman", DataTables.resource_name("refine_talisman"), current, cost))
	if item.is_empty():
		return
	if current < cost:
		forge_hint_label.text = "洗练符不足"
	else:
		forge_hint_label.text = "当前洗练词条：%d，洗练后新增百分比词条" % int(item.get("refine_count", 0))


func _refresh_forge_equipment_list() -> void:
	_ensure_menu_panel_refs()
	forge_equipment_list.clear()
	if current_game_state == null:
		return
	for item in current_game_state.inventory_items_for_type(DataTables.ITEM_TYPE_EQUIPMENT):
		var instance_id := str(item.get("instance_id", ""))
		if instance_id.is_empty():
			continue
		var label := "%s  +%d / 洗练%d" % [str(item.get("name", "装备")), int(item.get("enhance_count", 0)), int(item.get("refine_count", 0))]
		var index := forge_equipment_list.add_item(label)
		forge_equipment_list.set_item_metadata(index, instance_id)


func _clear_forge_material_grid() -> void:
	_ensure_menu_panel_refs()
	for child in forge_material_grid.get_children():
		child.queue_free()


func _create_forge_material_slot(item_id: String, item_name: String, current: int, required: int) -> PanelContainer:
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
	name_label.text = item_name
	layout.add_child(name_label)
	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.text = str(current) if required <= 0 else "%d/%d" % [current, required]
	if required > 0 and current < required:
		count_label.modulate = Color(1.0, 0.2, 0.2)
	layout.add_child(count_label)
	return slot


func _first_matching_enhance_stone_id(item: Dictionary, cost: int) -> String:
	var base_stats := []
	for attribute in item.get("base_attributes", []):
		var stat_id: String = attribute.get("stat", "")
		if not stat_id.is_empty() and not base_stats.has(stat_id):
			base_stats.append(stat_id)
	for quality in DataTables.SPIRIT_STONE_QUALITY_ORDER:
		for stat_id in base_stats:
			var item_id := DataTables.enhance_stone_item_id(stat_id, quality)
			if not item_id.is_empty() and current_game_state.inventory_item_count(item_id) >= cost:
				return item_id
	return ""


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
	alchemy_progress_label.text = _progress_label_text("alchemy")
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
