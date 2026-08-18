class_name Hud
extends CanvasLayer

const ModManagerPanelScript = preload("res://scripts/modding/ui/mod_manager_panel.gd")
const SkillValueResolverScript = preload("res://scripts/game/combat/skill_value_resolver.gd")

const MENU_USE := 1
const MENU_DROP := 2
const MENU_ENHANCE := 3
const MENU_AFFIX := 4
const MENU_EQUIP := 5
const MENU_SALVAGE := 6
const FORGE_MODE_CRAFT := "craft"
const FORGE_MODE_ENHANCE := "enhance"
const FORGE_MODE_REFINE := "refine"
const PARTY_MAX_SIZE := 4
const ROSTER_MAX_SIZE := 8
const INVENTORY_CATEGORIES := [
	{"type": DataTables.ITEM_TYPE_SKILL_BOOK, "label": "技能书", "node": "SkillBookButton"},
	{"type": DataTables.ITEM_TYPE_ALCHEMY_RECIPE, "label": "丹方", "node": "RecipeButton"},
	{"type": DataTables.ITEM_TYPE_BLUEPRINT, "label": "装备图纸", "node": "BlueprintButton"},
	{"type": DataTables.ITEM_TYPE_EQUIPMENT, "label": "装备", "node": "EquipmentButton"},
	{"type": DataTables.ITEM_TYPE_MATERIAL, "label": "材料", "node": "MaterialButton"},
	{"type": DataTables.ITEM_TYPE_CROP, "label": "作物", "node": "CropButton"},
	{"type": DataTables.ITEM_TYPE_PILL, "label": "丹药", "node": "PillButton"},
]
const DEBUG_STAT_OPTIONS := [
	{"id": "level", "label": "等级"},
	{"id": "level_cap", "label": "等级上限"},
	{"id": "stage", "label": "阶段"},
	{"id": "root_bone", "label": "根骨"},
	{"id": "exp", "label": "经验"},
	{"id": "next_exp", "label": "下级经验"},
	{"id": "hp", "label": "气血"},
	{"id": "max_hp", "label": "气血上限"},
	{"id": "mp", "label": "法力"},
	{"id": "max_mp", "label": "法力上限"},
	{"id": "attack", "label": "攻击"},
	{"id": "defense", "label": "防御"},
	{"id": "wood", "label": "木"},
	{"id": "fire", "label": "火"},
	{"id": "earth", "label": "土"},
	{"id": "metal", "label": "金"},
	{"id": "water", "label": "水"},
]

signal home_action_requested(task_type: int)
signal expedition_map_selected(map_id: String)
signal hud_save_requested()
signal expedition_exit_requested()
signal home_camera_pan_started(direction: int)
signal home_camera_pan_stopped()
signal scene_transition_midpoint()
signal scene_transition_finished()

const DRAG_MARGIN := 12.0
const INVENTORY_SLOT_COUNT := 25
const INVENTORY_DOUBLE_CLICK_MS := 350
const INVENTORY_SLOT_SIZE := Vector2(78, 54)
const INVENTORY_ICON_SIZE := Vector2(42, 42)
const PARTY_VISUAL_ROOT := "res://scripts/actors/visuals/party"
const DEFAULT_PARTY_VISUAL_ID := "actor_default"
const PANEL_FILL_COLOR := Color(0.13, 0.09, 0.06, 0.9)
const PANEL_BORDER_COLOR := Color(0.72, 0.55, 0.28, 0.95)
const TITLE_FILL_COLOR := Color(0.18, 0.12, 0.07, 0.88)
const TITLE_BORDER_COLOR := Color(0.86, 0.72, 0.36, 1.0)
const BUTTON_FILL_COLOR := Color(0.25, 0.18, 0.11, 0.95)
const BUTTON_BORDER_COLOR := Color(0.77, 0.62, 0.34, 1.0)
const BUTTON_HOVER_FILL_COLOR := Color(0.34, 0.24, 0.13, 1.0)
const BUTTON_HOVER_BORDER_COLOR := Color(0.95, 0.8, 0.46, 1.0)
const BUTTON_PRESSED_FILL_COLOR := Color(0.18, 0.12, 0.07, 1.0)
const BUTTON_PRESSED_BORDER_COLOR := Color(0.62, 0.45, 0.18, 1.0)
const BUTTON_DISABLED_FILL_COLOR := Color(0.18, 0.15, 0.12, 0.75)
const BUTTON_DISABLED_BORDER_COLOR := Color(0.35, 0.3, 0.24, 0.9)
const BUTTON_FOCUS_FILL_COLOR := Color(0.3, 0.22, 0.12, 1.0)
const BUTTON_FOCUS_BORDER_COLOR := Color(1, 0.86, 0.58, 1.0)
const CARD_FILL_COLOR := Color(0.18, 0.13, 0.08, 0.88)
const CARD_BORDER_COLOR := Color(0.72, 0.55, 0.28, 0.9)
const SLOT_FILL_COLOR := Color(0.16, 0.11, 0.07, 0.92)
const SLOT_BORDER_COLOR := Color(0.55, 0.42, 0.24, 0.9)
const INVENTORY_ICON_BORDER_COLOR := Color(0.9, 0.8, 0.56, 1.0)
const INVENTORY_ICON_DIM_COLOR := Color(0.32, 0.28, 0.22, 1.0)
const INVENTORY_ICON_HIGHLIGHT_COLOR := Color(0.98, 0.9, 0.62, 1.0)

@onready var menu_panel: PanelContainer = $Root/MenuPanel
@onready var member_info_panel: PanelContainer = $Root/MemberInfoPanel
@onready var inventory_panel: PanelContainer = $Root/InventoryPanel
@onready var farm_panel: PanelContainer = $Root/FarmPanel
@onready var forge_panel: PanelContainer = $Root/ForgePanel
@onready var alchemy_panel: PanelContainer = $Root/AlchemyPanel
@onready var recruit_panel: PanelContainer = $Root/RecruitPanel
@onready var fight_panel: PanelContainer = $Root/FightPanel
@onready var member_info_member_list: ItemList = $Root/MemberInfoPanel/PanelLayout/MemberList
@onready var member_info_attribute_grid: GridContainer = $Root/MemberInfoPanel/PanelLayout/ContentRow/InfoTabs/属性/AttributeGrid
@onready var member_info_trait_grid: GridContainer = $Root/MemberInfoPanel/PanelLayout/ContentRow/InfoTabs/命格/TraitGrid
@onready var member_info_equipment_grid: GridContainer = $Root/MemberInfoPanel/PanelLayout/ContentRow/InfoTabs/装备/EquipmentGrid
@onready var member_info_skill_grid: GridContainer = $Root/MemberInfoPanel/PanelLayout/ContentRow/InfoTabs/技能/SkillGrid
@onready var member_info_portrait_root: Node2D = $Root/MemberInfoPanel/PanelLayout/ContentRow/PortraitPanel/PortraitLayout/PortraitViewportContainer/PortraitViewport/PortraitRoot
@onready var member_info_portrait_name: Label = $Root/MemberInfoPanel/PanelLayout/ContentRow/PortraitPanel/PortraitLayout/PortraitName
@onready var inventory_grid: GridContainer = $Root/InventoryPanel/InventoryLayout/InventoryGrid
@onready var inventory_detail_view: InventoryDetailView = $Root/InventoryItemDetailPanel
@onready var damage_popup_layer: DamagePopupManager = $Root/DamagePopupLayer
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
@onready var forge_action_button: Button = $Root/ForgePanel/PanelLayout/ExecuteButton
@onready var forge_craft_mode_button: Button = $Root/ForgePanel/PanelLayout/ModeRow/ForgeCraftButton
@onready var forge_enhance_mode_button: Button = $Root/ForgePanel/PanelLayout/ModeRow/ForgeEnhanceButton
@onready var forge_refine_mode_button: Button = $Root/ForgePanel/PanelLayout/ModeRow/ForgeRefineButton
@onready var forge_equipment_slot_button: Button = $Root/ForgePanel/PanelLayout/EquipmentSlotButton
@onready var forge_equipment_picker_panel: PanelContainer = $Root/ForgePanel/PanelLayout/EquipmentPickerPanel
@onready var forge_equipment_list: ItemList = $Root/ForgePanel/PanelLayout/EquipmentPickerPanel/EquipmentList
@onready var forge_material_grid: GridContainer = $Root/ForgePanel/PanelLayout/MaterialGrid
@onready var forge_hint_label: Label = $Root/ForgePanel/PanelLayout/HintLabel
@onready var recruit_detail: Label = $Root/RecruitPanel/PanelLayout/ActionDetail
@onready var recruit_candidate_list: ItemList = $Root/RecruitPanel/PanelLayout/CandidateList
@onready var recruit_button: Button = $Root/RecruitPanel/PanelLayout/RecruitButton
@onready var recruit_refresh_button: Button = $Root/RecruitPanel/PanelLayout/ButtonRow/RefreshButton
@onready var party_list: ItemList = $Root/RecruitPanel/PanelLayout/PartyList
@onready var party_move_up_button: Button = $Root/RecruitPanel/PanelLayout/PartyButtonRow/MoveUpButton
@onready var party_move_down_button: Button = $Root/RecruitPanel/PanelLayout/PartyButtonRow/MoveDownButton
@onready var party_toggle_active_button: Button = $Root/RecruitPanel/PanelLayout/PartyButtonRow/ToggleActiveButton
@onready var party_dismiss_button: Button = $Root/RecruitPanel/PanelLayout/PartyButtonRow/DismissButton
@onready var release_confirmation_dialog: ConfirmationDialog = $Root/ReleaseConfirmationDialog
@onready var fight_detail: Label = $Root/FightPanel/PanelLayout/ActionDetail
@onready var expedition_map_option: OptionButton = $Root/FightPanel/PanelLayout/MapRow/MapOption
@onready var expedition_hud: PanelContainer = $Root/ExpeditionHud
@onready var return_home_button: Button = $Root/ExpeditionHud/PanelLayout/ReturnHomeButton
@onready var home_camera_controls: Control = $Root/HomeCameraControls
@onready var home_camera_left_button: Button = $Root/HomeCameraControls/LeftButton
@onready var home_camera_right_button: Button = $Root/HomeCameraControls/RightButton
@onready var loading_overlay: Control = $Root/LoadingOverlay
@onready var loading_label: Label = $Root/LoadingOverlay/LoadingLabel
@onready var window_drag_button: Button = $Root/WindowDragButton
@onready var debug_button: Button = $Root/DebugButton
@onready var debug_panel: PanelContainer = $Root/DebugPanel
@onready var debug_item_option: OptionButton = $Root/DebugPanel/PanelLayout/AddItemRow/ItemOption
@onready var debug_item_amount_spinbox: SpinBox = $Root/DebugPanel/PanelLayout/AddItemRow/ItemAmountSpinBox
@onready var debug_add_item_button: Button = $Root/DebugPanel/PanelLayout/AddItemRow/AddItemButton
@onready var debug_equipment_option: OptionButton = $Root/DebugPanel/PanelLayout/EquipmentRow/EquipmentOption
@onready var debug_equipment_level_spinbox: SpinBox = $Root/DebugPanel/PanelLayout/EquipmentRow/EquipmentLevelSpinBox
@onready var debug_equipment_rarity_option: OptionButton = $Root/DebugPanel/PanelLayout/EquipmentRow/EquipmentRarityOption
@onready var debug_add_equipment_button: Button = $Root/DebugPanel/PanelLayout/EquipmentRow/AddEquipmentButton
@onready var debug_stat_option: OptionButton = $Root/DebugPanel/PanelLayout/StatRow/StatOption
@onready var debug_stat_value_spinbox: SpinBox = $Root/DebugPanel/PanelLayout/StatRow/StatValueSpinBox
@onready var debug_set_stat_button: Button = $Root/DebugPanel/PanelLayout/StatRow/SetStatButton
@onready var alchemy_recipe_slot_button: Button = $Root/AlchemyPanel/PanelLayout/RecipeSlotButton
@onready var alchemy_recipe_picker_panel: PanelContainer = $Root/AlchemyPanel/PanelLayout/RecipePickerPanel
@onready var alchemy_recipe_list: ItemList = $Root/AlchemyPanel/PanelLayout/RecipePickerPanel/RecipeList
@onready var alchemy_material_grid: GridContainer = $Root/AlchemyPanel/PanelLayout/MaterialGrid
@onready var alchemy_max_count_label: Label = $Root/AlchemyPanel/PanelLayout/MaxCountLabel
@onready var alchemy_craft_count_spinbox: SpinBox = $Root/AlchemyPanel/PanelLayout/CraftCountSpinBox
@onready var alchemy_craft_button: Button = $Root/AlchemyPanel/PanelLayout/CraftButton
@onready var alchemy_hint_label: Label = $Root/AlchemyPanel/PanelLayout/HintLabel

var farm_upgrade_button: Button = null
var forge_upgrade_button: Button = null
var alchemy_upgrade_button: Button = null
var recruit_upgrade_button: Button = null
var category_buttons: Array[Button] = []
var inventory_slot_buttons: Array[Button] = []
var inventory_slot_instance_ids: Array[String] = []
var inventory_slot_color_rects: Array[ColorRect] = []
var inventory_slot_texture_rects: Array[TextureRect] = []
var current_inventory_type: String = DataTables.ITEM_TYPE_EQUIPMENT
var selected_inventory_instance_id: String = ""
var hovered_inventory_instance_id: String = ""
var last_inventory_click_instance_id: String = ""
var last_inventory_click_time_ms: int = 0
var current_game_state = null
var current_progress_state: Dictionary = {}
var log_lines: Array = []
var selected_farm_seed_id: String = ""
var selected_farm_slot_index: int = -1
var selected_farm_speed_item_id: String = ""
var farm_controls_connected: bool = false
var selected_forge_mode: String = FORGE_MODE_CRAFT
var selected_forge_equipment_instance_id: String = ""
var forge_controls_connected: bool = false
var selected_party_member_id: String = ""
var selected_recruit_candidate_id: String = ""
var selected_recruit_party_member_id: String = ""
var pending_release_member_id: String = ""
var recruit_controls_connected: bool = false
var selected_alchemy_recipe_id: String = ""
var selected_expedition_map_id := ""
var expedition_map_summaries: Array[Dictionary] = []
var alchemy_controls_connected: bool = false
var debug_controls_connected: bool = false
var debug_options_populated: bool = false
var saved_panel_positions: Dictionary = {}
var dragging_panel: Control = null
var drag_mouse_start: Vector2 = Vector2.ZERO
var drag_panel_start: Vector2 = Vector2.ZERO
var dragging_window: bool = false
var window_drag_mouse_start: Vector2 = Vector2.ZERO
var window_drag_start_position: Vector2i = Vector2i.ZERO
var menu_button_hover_tween: Tween = null
var scene_transition_tween: Tween = null
var mod_manager_button: Button = null
var mod_manager_panel: Control = null
var forge_blueprint_row: HBoxContainer = null
var forge_blueprint_option: OptionButton = null
var forge_target_button: Button = null
var salvage_confirmation_dialog: ConfirmationDialog = null
var pending_salvage_instance_id := ""
var recruit_mode_recruit_button: Button = null
var recruit_mode_manual_button: Button = null
var recruit_manual_page: VBoxContainer = null
var manual_exchange_list: ItemList = null
var manual_exchange_button: Button = null
var spirit_stone_row: HBoxContainer = null
var spirit_stone_option: OptionButton = null
var spirit_stone_convert_button: Button = null
var market_button: Button = null
var market_panel: PanelContainer = null
var market_token_label: Label = null
var market_timer_label: Label = null
var market_refresh_button: Button = null
var market_tabs: TabContainer = null
var market_offer_grid: GridContainer = null
var market_commission_list: VBoxContainer = null
var market_recycle_option: OptionButton = null
var market_recycle_amount: SpinBox = null
var market_recycle_preview_label: Label = null
var market_recycle_button: Button = null
var market_recycle_confirmation: ConfirmationDialog = null
var pending_market_recycle_item_id := ""
var pending_market_recycle_amount := 0
var market_clock_accumulator := 0.0


func _ready() -> void:

	$Root/MemberInfoPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): member_info_panel.visible = false)
	$Root/InventoryPanel/InventoryLayout/Header/CloseButton.pressed.connect(func(): inventory_panel.visible = false)
	$Root/FarmPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): farm_panel.visible = false)
	$Root/ForgePanel/PanelLayout/Header/CloseButton.pressed.connect(func(): forge_panel.visible = false)
	$Root/AlchemyPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): alchemy_panel.visible = false)
	$Root/RecruitPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): recruit_panel.visible = false)
	$Root/FightPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): fight_panel.visible = false)

	$Root/FightPanel/PanelLayout/ExecuteButton.pressed.connect(func(): home_action_requested.emit(GameDefs.TaskType.FIGHT))
	expedition_map_option.item_selected.connect(_on_expedition_map_option_selected)
	return_home_button.pressed.connect(func(): expedition_exit_requested.emit())
	home_camera_left_button.button_down.connect(func(): home_camera_pan_started.emit(-1))
	home_camera_left_button.button_up.connect(func(): home_camera_pan_stopped.emit())
	home_camera_right_button.button_down.connect(func(): home_camera_pan_started.emit(1))
	home_camera_right_button.button_up.connect(func(): home_camera_pan_stopped.emit())
	debug_button.pressed.connect(_toggle_debug_panel)
	if inventory_detail_view != null:
		inventory_detail_view.setup()
		inventory_detail_view.use_button.pressed.connect(_on_inventory_detail_use_pressed)
	if damage_popup_layer != null:
		damage_popup_layer.visible = true
	$Root/DebugPanel/PanelLayout/Header/CloseButton.pressed.connect(func(): debug_panel.visible = false)
	window_drag_button.button_down.connect(_on_window_drag_button_down)
	window_drag_button.button_up.connect(_on_window_drag_button_up)
	_ensure_equipment_loop_controls()
	_ensure_progression_exchange_controls()
	_ensure_market_controls()
	_connect_farm_controls()
	_connect_forge_controls()
	_connect_alchemy_controls()
	_connect_recruit_controls()
	release_confirmation_dialog.confirmed.connect(_on_release_confirmed)
	_connect_debug_controls()
	_populate_debug_options()

	for category in INVENTORY_CATEGORIES:
		var button: Button = category_row.get_node(category["node"]) as Button
		button.text = category["label"]
		button.pressed.connect(func(type_id = category["type"]): _set_inventory_category(type_id))
		category_buttons.append(button)

	inventory_menu.id_pressed.connect(_on_inventory_menu_id_pressed)
	_ensure_inventory_slots()
	_capture_default_panel_positions()
	$Root/MenuButton.pivot_offset = $Root/MenuButton.size * 0.5
	window_drag_button.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_overlay.visible = false
	loading_overlay.modulate.a = 0.0
	_setup_mod_manager()


func _ensure_market_controls() -> void:
	var root := get_node_or_null("Root") as Control
	var menu_layout := get_node_or_null("Root/MenuPanel/MenuLayout") as VBoxContainer
	if root == null or menu_layout == null:
		return
	market_button = menu_layout.get_node_or_null("MarketButton") as Button
	if market_button == null:
		market_button = Button.new()
		market_button.name = "MarketButton"
		market_button.text = "坊市"
		market_button.custom_minimum_size = Vector2(120.0, 28.0)
		_style_market_button(market_button)
		menu_layout.add_child(market_button)
		market_button.pressed.connect(_open_market_panel)
		menu_panel.reset_size()
	market_panel = root.get_node_or_null("MarketPanel") as PanelContainer
	if market_panel != null:
		return
	market_panel = PanelContainer.new()
	market_panel.name = "MarketPanel"
	market_panel.visible = false
	market_panel.position = Vector2(170.0, 28.0)
	market_panel.custom_minimum_size = Vector2(620.0, 420.0)
	market_panel.add_theme_stylebox_override("panel", _create_panel_style(PANEL_FILL_COLOR, PANEL_BORDER_COLOR, 2, 8))
	root.add_child(market_panel)

	var layout := VBoxContainer.new()
	layout.name = "PanelLayout"
	layout.add_theme_constant_override("separation", 7)
	market_panel.add_child(layout)

	var header := HBoxContainer.new()
	header.name = "Header"
	layout.add_child(header)
	var title := Label.new()
	title.text = "坊市"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(1.0, 0.93, 0.73))
	header.add_child(title)
	market_token_label = Label.new()
	market_token_label.name = "TokenLabel"
	header.add_child(market_token_label)
	market_timer_label = Label.new()
	market_timer_label.name = "TimerLabel"
	market_timer_label.custom_minimum_size.x = 110.0
	header.add_child(market_timer_label)
	var close_button := Button.new()
	close_button.text = "关闭"
	_style_market_button(close_button)
	close_button.pressed.connect(func(): market_panel.visible = false)
	header.add_child(close_button)

	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	layout.add_child(action_row)
	var cycle_label := Label.new()
	cycle_label.text = "货架与委托每 10 分钟自然更新"
	cycle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(cycle_label)
	market_refresh_button = Button.new()
	market_refresh_button.name = "RefreshButton"
	_style_market_button(market_refresh_button)
	market_refresh_button.pressed.connect(_on_market_refresh_pressed)
	action_row.add_child(market_refresh_button)

	market_tabs = TabContainer.new()
	market_tabs.name = "MarketTabs"
	market_tabs.custom_minimum_size = Vector2(596.0, 330.0)
	market_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(market_tabs)

	var shelf_page := ScrollContainer.new()
	shelf_page.name = "货架"
	market_tabs.add_child(shelf_page)
	market_offer_grid = GridContainer.new()
	market_offer_grid.name = "OfferGrid"
	market_offer_grid.columns = 2
	market_offer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_offer_grid.add_theme_constant_override("h_separation", 8)
	market_offer_grid.add_theme_constant_override("v_separation", 8)
	shelf_page.add_child(market_offer_grid)

	var commission_scroll := ScrollContainer.new()
	commission_scroll.name = "委托"
	market_tabs.add_child(commission_scroll)
	market_commission_list = VBoxContainer.new()
	market_commission_list.name = "CommissionList"
	market_commission_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_commission_list.add_theme_constant_override("separation", 8)
	commission_scroll.add_child(market_commission_list)

	var recycle_page := VBoxContainer.new()
	recycle_page.name = "回收"
	recycle_page.add_theme_constant_override("separation", 10)
	market_tabs.add_child(recycle_page)
	market_recycle_option = OptionButton.new()
	market_recycle_option.name = "RecycleItemOption"
	market_recycle_option.custom_minimum_size = Vector2(0.0, 38.0)
	recycle_page.add_child(market_recycle_option)
	var amount_row := HBoxContainer.new()
	recycle_page.add_child(amount_row)
	var amount_label := Label.new()
	amount_label.text = "回收数量"
	amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount_row.add_child(amount_label)
	market_recycle_amount = SpinBox.new()
	market_recycle_amount.name = "RecycleAmount"
	market_recycle_amount.custom_minimum_size.x = 150.0
	market_recycle_amount.allow_greater = false
	market_recycle_amount.allow_lesser = false
	amount_row.add_child(market_recycle_amount)
	market_recycle_preview_label = Label.new()
	market_recycle_preview_label.name = "RecyclePreview"
	market_recycle_preview_label.custom_minimum_size.y = 50.0
	recycle_page.add_child(market_recycle_preview_label)
	market_recycle_button = Button.new()
	market_recycle_button.name = "RecycleButton"
	market_recycle_button.text = "确认回收"
	_style_market_button(market_recycle_button)
	recycle_page.add_child(market_recycle_button)

	market_recycle_confirmation = ConfirmationDialog.new()
	market_recycle_confirmation.name = "MarketRecycleConfirmation"
	market_recycle_confirmation.title = "确认回收贵重物品"
	root.add_child(market_recycle_confirmation)
	market_recycle_option.item_selected.connect(_on_market_recycle_item_selected)
	market_recycle_amount.value_changed.connect(_on_market_recycle_amount_changed)
	market_recycle_button.pressed.connect(_on_market_recycle_pressed)
	market_recycle_confirmation.confirmed.connect(_on_market_recycle_confirmed)


func _style_market_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _create_button_style(BUTTON_FILL_COLOR, BUTTON_BORDER_COLOR))
	button.add_theme_stylebox_override("hover", _create_button_style(BUTTON_HOVER_FILL_COLOR, BUTTON_HOVER_BORDER_COLOR))
	button.add_theme_stylebox_override("pressed", _create_button_style(BUTTON_PRESSED_FILL_COLOR, BUTTON_PRESSED_BORDER_COLOR))
	button.add_theme_stylebox_override("disabled", _create_button_style(BUTTON_DISABLED_FILL_COLOR, BUTTON_DISABLED_BORDER_COLOR))
	button.add_theme_stylebox_override("focus", _create_button_style(BUTTON_FOCUS_FILL_COLOR, BUTTON_FOCUS_BORDER_COLOR))


func _open_market_panel() -> void:
	_ensure_menu_panel_refs()
	_close_popup_panels()
	menu_panel.visible = false
	market_panel.visible = true
	_refresh_market_panel()
	market_panel.reset_size()
	_apply_saved_panel_position(market_panel)
	call_deferred("_apply_saved_panel_position_if_visible", market_panel)


func _refresh_market_panel() -> void:
	if current_game_state == null or market_panel == null:
		return
	_refresh_market_header()
	_refresh_market_offers()
	_refresh_market_commissions()
	_refresh_market_recycle_options()


func _refresh_market_header() -> void:
	if current_game_state == null:
		return
	var seconds: int = int(current_game_state.market_seconds_until_refresh())
	var minutes := floori(float(seconds) / 60.0)
	var remainder: int = seconds % 60
	market_token_label.text = "坊市令 %d" % current_game_state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN)
	market_timer_label.text = "%02d:%02d" % [minutes, remainder]
	var cost: int = int(current_game_state.market_manual_refresh_cost())
	market_refresh_button.text = "刷新 · %d" % cost
	market_refresh_button.disabled = current_game_state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN) < cost


func _refresh_market_offers() -> void:
	_clear_control_children(market_offer_grid)
	var token_count: int = int(current_game_state.inventory_item_count(DataTables.ITEM_ID_MARKET_TOKEN))
	for offer in current_game_state.market_offers():
		if not (offer is Dictionary):
			continue
		var slot_index := int(offer.get("slot_index", market_offer_grid.get_child_count()))
		var item_id := str(offer.get("item_id", ""))
		var amount := int(offer.get("amount", 0))
		var price := int(offer.get("price", 0))
		var sold := bool(offer.get("sold", false))
		var button := Button.new()
		button.custom_minimum_size = Vector2(286.0, 82.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s  x%d\n%s" % [
			DataTables.resource_name(item_id),
			amount,
			"已售罄" if sold else "坊市令 x%d" % price,
		]
		button.tooltip_text = str(DataTables.item_definition(item_id).get("description", ""))
		button.disabled = sold or token_count < price
		_style_market_button(button)
		button.pressed.connect(func(index = slot_index): _on_market_offer_pressed(index))
		market_offer_grid.add_child(button)


func _refresh_market_commissions() -> void:
	_clear_control_children(market_commission_list)
	var commission_index := 0
	for commission in current_game_state.market_commissions():
		if not (commission is Dictionary):
			continue
		var parts: Array[String] = []
		var can_submit := true
		for requirement in commission.get("requirements", []):
			var item_id := str(requirement.get("item_id", ""))
			var amount := int(requirement.get("amount", 0))
			var owned: int = int(current_game_state.inventory_item_count(item_id))
			parts.append("%s %d/%d" % [DataTables.resource_name(item_id), owned, amount])
			if owned < amount:
				can_submit = false
		var completed := bool(commission.get("completed", false))
		var button := Button.new()
		button.custom_minimum_size = Vector2(570.0, 78.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n%s" % [
			" · ".join(parts),
			"已完成" if completed else "提交 · 坊市令 x%d" % int(commission.get("reward", 0)),
		]
		button.disabled = completed or not can_submit
		_style_market_button(button)
		button.pressed.connect(func(index = commission_index): _on_market_commission_pressed(index))
		market_commission_list.add_child(button)
		commission_index += 1


func _refresh_market_recycle_options() -> void:
	var previous_item_id := _selected_market_recycle_item_id()
	market_recycle_option.clear()
	for item_id in current_game_state.market_recyclable_item_ids():
		var definition: Dictionary = current_game_state.market_recycle_definition(item_id)
		var index := market_recycle_option.item_count
		market_recycle_option.add_item("%s  持有%d  每%d换%d" % [
			DataTables.resource_name(item_id),
			current_game_state.inventory_item_count(item_id),
			int(definition.get("amount", 1)),
			int(definition.get("tokens", 1)),
		])
		market_recycle_option.set_item_metadata(index, item_id)
		if item_id == previous_item_id:
			market_recycle_option.select(index)
	if market_recycle_option.item_count <= 0:
		market_recycle_amount.min_value = 0.0
		market_recycle_amount.max_value = 0.0
		market_recycle_amount.value = 0.0
		market_recycle_button.disabled = true
		market_recycle_preview_label.text = "暂无满足完整批次的可回收物品"
		return
	_on_market_recycle_item_selected(market_recycle_option.selected)


func _selected_market_recycle_item_id() -> String:
	if market_recycle_option == null or market_recycle_option.item_count <= 0 or market_recycle_option.selected < 0:
		return ""
	return str(market_recycle_option.get_item_metadata(market_recycle_option.selected))


func _on_market_recycle_item_selected(_index: int) -> void:
	var item_id := _selected_market_recycle_item_id()
	var definition: Dictionary = current_game_state.market_recycle_definition(item_id)
	var batch := maxi(1, int(definition.get("amount", 1)))
	var owned: int = int(current_game_state.inventory_item_count(item_id))
	market_recycle_amount.min_value = float(batch)
	market_recycle_amount.max_value = float(floori(float(owned) / float(batch)) * batch)
	market_recycle_amount.step = float(batch)
	market_recycle_amount.value = float(batch)
	_refresh_market_recycle_preview()


func _on_market_recycle_amount_changed(_value: float) -> void:
	_refresh_market_recycle_preview()


func _refresh_market_recycle_preview() -> void:
	if current_game_state == null:
		return
	var item_id := _selected_market_recycle_item_id()
	var amount := int(market_recycle_amount.value)
	var reward: int = int(current_game_state.market_recycle_preview(item_id, amount))
	var definition: Dictionary = current_game_state.market_recycle_definition(item_id)
	market_recycle_preview_label.text = "回收 %s x%d  获得坊市令 x%d%s" % [
		DataTables.resource_name(item_id),
		amount,
		reward,
		"  · 贵重物品需再次确认" if bool(definition.get("valuable", false)) else "",
	]
	market_recycle_button.disabled = reward <= 0


func _on_market_offer_pressed(slot_index: int) -> void:
	if current_game_state != null and current_game_state.buy_market_offer(slot_index):
		_refresh_market_panel()


func _on_market_commission_pressed(commission_index: int) -> void:
	if current_game_state != null and current_game_state.complete_market_commission(commission_index):
		_refresh_market_panel()


func _on_market_refresh_pressed() -> void:
	if current_game_state != null and current_game_state.refresh_market():
		_refresh_market_panel()


func _on_market_recycle_pressed() -> void:
	if current_game_state == null:
		return
	var item_id := _selected_market_recycle_item_id()
	var amount := int(market_recycle_amount.value)
	var definition: Dictionary = current_game_state.market_recycle_definition(item_id)
	if bool(definition.get("valuable", false)):
		pending_market_recycle_item_id = item_id
		pending_market_recycle_amount = amount
		market_recycle_confirmation.dialog_text = "确认回收%s x%d？贵重物品回收后无法恢复。" % [DataTables.resource_name(item_id), amount]
		market_recycle_confirmation.popup_centered()
		return
	if current_game_state.recycle_market_item(item_id, amount):
		_refresh_market_panel()


func _on_market_recycle_confirmed() -> void:
	if current_game_state != null and current_game_state.recycle_market_item(pending_market_recycle_item_id, pending_market_recycle_amount, true):
		_refresh_market_panel()
	pending_market_recycle_item_id = ""
	pending_market_recycle_amount = 0


func _process(delta: float) -> void:
	if market_panel == null or not market_panel.visible or current_game_state == null:
		return
	market_clock_accumulator += delta
	if market_clock_accumulator < 1.0:
		return
	market_clock_accumulator = 0.0
	var previous_refresh := int(current_game_state.market_state.get("next_free_refresh_unix", 0))
	current_game_state.market_offers()
	var current_refresh := int(current_game_state.market_state.get("next_free_refresh_unix", 0))
	if current_refresh != previous_refresh:
		_refresh_market_panel()
	else:
		_refresh_market_header()


func _ensure_equipment_loop_controls() -> void:
	if not category_row.has_node("BlueprintButton"):
		var blueprint_button := Button.new()
		blueprint_button.name = "BlueprintButton"
		blueprint_button.custom_minimum_size = Vector2(92.0, 34.0)
		category_row.add_child(blueprint_button)
	var forge_layout := get_node_or_null("Root/ForgePanel/PanelLayout") as VBoxContainer
	if forge_layout != null:
		var forge_hint := forge_layout.get_node_or_null("HintLabel") as Label
		if forge_hint != null:
			forge_hint.custom_minimum_size.y = 23.0
		forge_blueprint_row = forge_layout.get_node_or_null("BlueprintForgeRow") as HBoxContainer
		if forge_blueprint_row == null:
			forge_blueprint_row = HBoxContainer.new()
			forge_blueprint_row.name = "BlueprintForgeRow"
			forge_layout.add_child(forge_blueprint_row)
		forge_blueprint_option = forge_blueprint_row.get_node_or_null("BlueprintOption") as OptionButton
		if forge_blueprint_option == null:
			forge_blueprint_option = OptionButton.new()
			forge_blueprint_option.name = "BlueprintOption"
			forge_blueprint_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			forge_blueprint_option.custom_minimum_size = Vector2(0.0, 34.0)
			forge_blueprint_row.add_child(forge_blueprint_option)
		forge_target_button = forge_blueprint_row.get_node_or_null("TargetForgeButton") as Button
		if forge_target_button == null:
			forge_target_button = Button.new()
			forge_target_button.name = "TargetForgeButton"
			forge_target_button.text = "定向打造"
			forge_target_button.custom_minimum_size = Vector2(112.0, 34.0)
			forge_blueprint_row.add_child(forge_target_button)
		forge_target_button.pressed.connect(_on_target_forge_pressed)
	var root := get_node_or_null("Root")
	if root != null:
		salvage_confirmation_dialog = root.get_node_or_null("SalvageConfirmationDialog") as ConfirmationDialog
		if salvage_confirmation_dialog == null:
			salvage_confirmation_dialog = ConfirmationDialog.new()
			salvage_confirmation_dialog.name = "SalvageConfirmationDialog"
			salvage_confirmation_dialog.title = "确认分解"
			salvage_confirmation_dialog.dialog_text = "分解只返还阶级矿石，不返还强化和洗练材料。"
			root.add_child(salvage_confirmation_dialog)
		salvage_confirmation_dialog.confirmed.connect(_on_salvage_confirmed)

func _ensure_progression_exchange_controls() -> void:
	var recruit_layout := get_node_or_null("Root/RecruitPanel/PanelLayout") as VBoxContainer
	if recruit_layout != null:
		var mode_row := recruit_layout.get_node_or_null("RecruitModeRow") as HBoxContainer
		if mode_row == null:
			mode_row = HBoxContainer.new()
			mode_row.name = "RecruitModeRow"
			recruit_layout.add_child(mode_row)
			recruit_layout.move_child(mode_row, 1)
		recruit_mode_recruit_button = mode_row.get_node_or_null("RecruitModeButton") as Button
		if recruit_mode_recruit_button == null:
			recruit_mode_recruit_button = Button.new()
			recruit_mode_recruit_button.name = "RecruitModeButton"
			recruit_mode_recruit_button.text = "招募"
			recruit_mode_recruit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mode_row.add_child(recruit_mode_recruit_button)
		recruit_mode_manual_button = mode_row.get_node_or_null("ManualModeButton") as Button
		if recruit_mode_manual_button == null:
			recruit_mode_manual_button = Button.new()
			recruit_mode_manual_button.name = "ManualModeButton"
			recruit_mode_manual_button.text = "功法兑换"
			recruit_mode_manual_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mode_row.add_child(recruit_mode_manual_button)
		recruit_manual_page = recruit_layout.get_node_or_null("ManualExchangePage") as VBoxContainer
		if recruit_manual_page == null:
			recruit_manual_page = VBoxContainer.new()
			recruit_manual_page.name = "ManualExchangePage"
			var title := Label.new()
			title.text = "功法兑换"
			recruit_manual_page.add_child(title)
			manual_exchange_list = ItemList.new()
			manual_exchange_list.name = "ManualExchangeList"
			manual_exchange_list.custom_minimum_size = Vector2(320.0, 110.0)
			recruit_manual_page.add_child(manual_exchange_list)
			manual_exchange_button = Button.new()
			manual_exchange_button.name = "ManualExchangeButton"
			manual_exchange_button.text = "兑换功法"
			recruit_manual_page.add_child(manual_exchange_button)
			recruit_layout.add_child(recruit_manual_page)
		else:
			manual_exchange_list = recruit_manual_page.get_node_or_null("ManualExchangeList") as ItemList
			manual_exchange_button = recruit_manual_page.get_node_or_null("ManualExchangeButton") as Button
		if manual_exchange_button != null:
			manual_exchange_button.pressed.connect(_on_manual_exchange_pressed)
		if manual_exchange_list != null:
			manual_exchange_list.item_selected.connect(func(_index): manual_exchange_button.disabled = false)
		recruit_mode_recruit_button.pressed.connect(func(): _set_recruit_exchange_page(false))
		recruit_mode_manual_button.pressed.connect(func(): _set_recruit_exchange_page(true))
		_set_recruit_exchange_page(false)
	var forge_layout := get_node_or_null("Root/ForgePanel/PanelLayout") as VBoxContainer
	if forge_layout != null:
		spirit_stone_row = forge_layout.get_node_or_null("SpiritStoneRow") as HBoxContainer
		if spirit_stone_row == null:
			spirit_stone_row = HBoxContainer.new()
			spirit_stone_row.name = "SpiritStoneRow"
			forge_layout.add_child(spirit_stone_row)
		spirit_stone_option = spirit_stone_row.get_node_or_null("SpiritStoneOption") as OptionButton
		if spirit_stone_option == null:
			spirit_stone_option = OptionButton.new()
			spirit_stone_option.name = "SpiritStoneOption"
			spirit_stone_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for element_id in ["wood", "fire", "earth", "metal", "water"]:
				spirit_stone_option.add_item(DataTables.element_name(element_id))
				spirit_stone_option.set_item_metadata(spirit_stone_option.item_count - 1, element_id)
			spirit_stone_row.add_child(spirit_stone_option)
		spirit_stone_convert_button = spirit_stone_row.get_node_or_null("SpiritStoneConvertButton") as Button
		if spirit_stone_convert_button == null:
			spirit_stone_convert_button = Button.new()
			spirit_stone_convert_button.name = "SpiritStoneConvertButton"
			spirit_stone_convert_button.text = "灵石 x3 转换"
			spirit_stone_convert_button.custom_minimum_size = Vector2(116.0, 0.0)
			spirit_stone_row.add_child(spirit_stone_convert_button)
		spirit_stone_convert_button.pressed.connect(_on_spirit_stone_convert_pressed)


func _set_recruit_exchange_page(show_manual: bool) -> void:
	if recruit_manual_page != null:
		recruit_manual_page.visible = show_manual
	if recruit_mode_recruit_button != null:
		recruit_mode_recruit_button.disabled = not show_manual
	if recruit_mode_manual_button != null:
		recruit_mode_manual_button.disabled = show_manual
	var recruit_layout := get_node_or_null("Root/RecruitPanel/PanelLayout")
	if recruit_layout == null:
		return
	for node_name in [
		"ActionDetail",
		"RecruitUpgradeButton",
		"CandidateList",
		"RecruitButton",
		"ButtonRow",
		"PartyLabel",
		"PartyList",
		"PartyButtonRow",
	]:
		var control := recruit_layout.get_node_or_null(node_name) as Control
		if control != null:
			control.visible = not show_manual

func _setup_mod_manager() -> void:
	var root := get_node_or_null("Root") as Control
	var mod_api := get_node_or_null("/root/ModAPI")
	if root == null or mod_api == null:
		return
	mod_manager_button = Button.new()
	mod_manager_button.name = "ModManagerButton"
	mod_manager_button.text = "MOD"
	mod_manager_button.tooltip_text = "Mod 管理"
	mod_manager_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mod_manager_button.position = Vector2(-58, 42)
	mod_manager_button.size = Vector2(50, 28)
	mod_manager_button.pressed.connect(func(): mod_manager_panel.open())
	root.add_child(mod_manager_button)
	mod_manager_panel = ModManagerPanelScript.new()
	mod_manager_panel.name = "ModManagerPanel"
	root.add_child(mod_manager_panel)
	mod_manager_panel.setup(mod_api)


func set_expedition_controls_visible(controls_visible: bool) -> void:
	_ensure_menu_panel_refs()
	if expedition_hud != null:
		expedition_hud.visible = controls_visible


func set_home_camera_controls(controls_visible: bool, can_move_left: bool, can_move_right: bool) -> void:
	if home_camera_controls == null:
		return
	home_camera_controls.visible = controls_visible
	if home_camera_left_button != null:
		home_camera_left_button.disabled = not can_move_left
	if home_camera_right_button != null:
		home_camera_right_button.disabled = not can_move_right


func play_scene_transition(message: String = "加载中...") -> void:
	_ensure_menu_panel_refs()
	if loading_overlay == null or loading_label == null:
		scene_transition_midpoint.emit()
		scene_transition_finished.emit()
		return
	if scene_transition_tween != null:
		scene_transition_tween.kill()
		scene_transition_tween = null
	loading_label.text = message
	loading_overlay.visible = true
	loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_overlay.modulate.a = 0.0
	scene_transition_tween = create_tween()
	scene_transition_tween.set_trans(Tween.TRANS_SINE)
	scene_transition_tween.set_ease(Tween.EASE_IN_OUT)
	scene_transition_tween.tween_property(loading_overlay, "modulate:a", 1.0, 0.18)
	scene_transition_tween.tween_callback(func(): scene_transition_midpoint.emit())
	scene_transition_tween.tween_interval(0.24)
	scene_transition_tween.tween_property(loading_overlay, "modulate:a", 0.0, 0.18)
	scene_transition_tween.tween_callback(func():
		loading_overlay.visible = false
		scene_transition_tween = null
		scene_transition_finished.emit()
	)


func hide_home_ui() -> void:
	_ensure_menu_panel_refs()
	_close_popup_panels()
	if menu_panel != null:
		menu_panel.visible = false
	if inventory_detail_view != null:
		inventory_detail_view.hide_item()
	if farm_seed_picker_panel != null:
		farm_seed_picker_panel.visible = false
	if farm_speed_item_picker_panel != null:
		farm_speed_item_picker_panel.visible = false
	if forge_equipment_picker_panel != null:
		forge_equipment_picker_panel.visible = false
	if alchemy_recipe_picker_panel != null:
		alchemy_recipe_picker_panel.visible = false
	if inventory_menu != null:
		inventory_menu.hide()


func _on_menu_button_mouse_entered() -> void:
	_animate_menu_button_hover(true)


func _on_menu_button_mouse_exited() -> void:
	_animate_menu_button_hover(false)


func _animate_menu_button_hover(hovered: bool) -> void:
	var button: Button = $Root/MenuButton as Button
	if menu_button_hover_tween != null:
		menu_button_hover_tween.kill()
		menu_button_hover_tween = null

	var target_scale: Vector2 = Vector2(1.08, 1.08) if hovered else Vector2.ONE
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
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if dragging_window:
			var delta: Vector2 = motion_event.position - window_drag_mouse_start
			DisplayServer.window_set_position(window_drag_start_position + Vector2i(roundi(delta.x), roundi(delta.y)))
		elif dragging_panel != null:
			var next_position: Vector2 = drag_panel_start + motion_event.position - drag_mouse_start
			dragging_panel.position = _clamp_panel_position(dragging_panel, next_position)

func load_hud_save_data(data: Dictionary) -> void:
	_ensure_menu_panel_refs()
	saved_panel_positions.clear()
	var panel_positions: Variant = data.get("panel_positions", {})
	if panel_positions is Dictionary:
		for panel_name in panel_positions.keys():
			var position_data: Variant = panel_positions[panel_name]
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
	current_progress_state = game_state.progress_states.duplicate(true) if game_state != null else {}
	if current_game_state != null and current_game_state.member_by_id(selected_party_member_id).is_empty():
		selected_party_member_id = _first_party_member_id()
	if current_game_state != null and current_game_state.member_by_id(selected_recruit_party_member_id).is_empty():
		selected_recruit_party_member_id = selected_party_member_id
	_refresh_member_info(game_state)

	if inventory_panel.visible:
		_refresh_inventory()
	if alchemy_panel.visible:
		_refresh_alchemy_panel()
	if member_info_panel.visible:
		_refresh_member_info(current_game_state)
	if recruit_panel.visible:
		_refresh_recruit_panel()
	if market_panel != null and market_panel.visible:
		_refresh_market_panel()
	_refresh_visible_action_details()


func push_log(message: String) -> void:
	log_lines.push_front(message)
	if log_lines.size() > 3:
		log_lines.resize(3)


func set_expedition_maps(map_summaries: Array[Dictionary], selected_map_id: String) -> void:
	expedition_map_summaries = map_summaries.duplicate(true)
	selected_expedition_map_id = selected_map_id
	_refresh_expedition_map_options()
	if fight_panel != null and fight_panel.visible:
		_refresh_action_detail(GameDefs.TaskType.FIGHT)


func _refresh_expedition_map_options() -> void:
	if expedition_map_option == null:
		return
	expedition_map_option.clear()
	var selected_index := -1
	for summary in expedition_map_summaries:
		var map_id := str(summary.get("id", ""))
		var unlocked := bool(summary.get("unlocked", false))
		var label := str(summary.get("name", map_id))
		if not unlocked:
			label += "（历练%d级）" % int(summary.get("unlock_level", 1))
		var index := expedition_map_option.item_count
		expedition_map_option.add_item(label)
		expedition_map_option.set_item_metadata(index, map_id)
		expedition_map_option.set_item_disabled(index, not unlocked)
		if map_id == selected_expedition_map_id:
			selected_index = index
	if selected_index >= 0:
		expedition_map_option.select(selected_index)
	elif expedition_map_option.item_count > 0:
		expedition_map_option.select(0)


func _on_expedition_map_option_selected(index: int) -> void:
	if expedition_map_option == null or index < 0 or index >= expedition_map_option.item_count:
		return
	if expedition_map_option.is_item_disabled(index):
		return
	var map_id := str(expedition_map_option.get_item_metadata(index))
	if map_id.is_empty() or map_id == selected_expedition_map_id:
		return
	selected_expedition_map_id = map_id
	expedition_map_selected.emit(map_id)
	_refresh_action_detail(GameDefs.TaskType.FIGHT)


func _selected_expedition_map_summary() -> Dictionary:
	for summary in expedition_map_summaries:
		if str(summary.get("id", "")) == selected_expedition_map_id:
			return summary
	return {}


func _first_party_member_id() -> String:
	if current_game_state == null:
		return ""
	var members: Array = current_game_state.roster_members()
	if members.is_empty():
		return ""
	return str(members[0].get("id", ""))


func _refresh_member_info(game_state) -> void:
	_refresh_member_info_member_list(game_state)
	_refresh_member_info_portrait(game_state)
	_refresh_member_info_attributes(game_state)
	_refresh_member_info_traits(game_state)
	_refresh_member_info_equipment(game_state)
	_refresh_member_info_skills(game_state)


func _refresh_member_info_member_list(game_state) -> void:
	if member_info_member_list == null or game_state == null:
		return
	member_info_member_list.clear()
	var selected_index := 0
	var members: Array = game_state.roster_members()
	if members.is_empty():
		var empty_index: int = member_info_member_list.add_item("暂无角色")
		member_info_member_list.set_item_metadata(empty_index, "")
		member_info_member_list.select(empty_index)
		selected_party_member_id = ""
		return
	for index in range(members.size()):
		var member: Dictionary = members[index]
		var member_id: String = str(member.get("id", ""))
		var member_stats: Dictionary = member.get("stats", {})
		var label := "%s %s  Lv.%d" % [
			"[出战]" if game_state.is_member_active(member_id) else "[候补]",
			str(member.get("name", "成员")),
			int(member_stats.get("level", 1)),
		]
		var item_index := member_info_member_list.add_item(label)
		member_info_member_list.set_item_metadata(item_index, member_id)
		if member_id == selected_party_member_id:
			selected_index = item_index
	if member_info_member_list.item_count > 0:
		member_info_member_list.select(selected_index)
		selected_party_member_id = str(member_info_member_list.get_item_metadata(selected_index))


func _refresh_member_info_portrait(game_state) -> void:
	if member_info_portrait_root == null or member_info_portrait_name == null or game_state == null:
		return
	var member: Dictionary = game_state.member_by_id(selected_party_member_id)
	if member.is_empty():
		member_info_portrait_name.text = "暂无角色"
		_clear_member_info_portrait()
		return

	member_info_portrait_name.text = str(member.get("name", "成员"))
	var visual_id: String = _safe_party_visual_id(str(member.get("visual_id", DEFAULT_PARTY_VISUAL_ID)))
	if member_info_portrait_root.get_child_count() > 0:
		var current_visual: Node = member_info_portrait_root.get_child(0)
		if str(current_visual.get_meta("visual_id", "")) == visual_id:
			return
	_clear_member_info_portrait()

	var appearance := DataTables.content_definition("appearance", visual_id)
	var scene_path := str(appearance.get("scene_path", ""))
	if not ResourceLoader.exists(scene_path):
		visual_id = DEFAULT_PARTY_VISUAL_ID
		appearance = DataTables.content_definition("appearance", visual_id)
		scene_path = str(appearance.get("scene_path", "%s/%s.tscn" % [PARTY_VISUAL_ROOT, visual_id]))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return
	var visual := packed.instantiate() as Node2D
	if visual == null:
		return
	member_info_portrait_root.add_child(visual)
	visual.set_meta("visual_id", visual_id)
	visual.position = Vector2.ZERO
	visual.scale = Vector2(2.4, 2.4)
	if visual.has_method("play_idle"):
		visual.call_deferred("play_idle")


func _clear_member_info_portrait() -> void:
	if member_info_portrait_root == null:
		return
	for child in member_info_portrait_root.get_children():
		member_info_portrait_root.remove_child(child)
		child.queue_free()


func _safe_party_visual_id(value: String) -> String:
	var result := ""
	for character in value:
		if character.is_valid_identifier() or character == "_" or character.is_valid_int():
			result += character
	return result if not result.is_empty() else DEFAULT_PARTY_VISUAL_ID


func _refresh_member_info_attributes(game_state) -> void:
	_clear_control_children(member_info_attribute_grid)
	var member: Dictionary = game_state.member_by_id(selected_party_member_id)
	if member.is_empty():
		_add_attribute_row("角色", "暂无角色")
		return
	var member_id: String = str(member.get("id", ""))
	var member_stats: Dictionary = member.get("stats", {})
	_add_attribute_row("姓名", str(member.get("name", "成员")))
	_add_attribute_row("等级", "%d  阶段 %d/%d" % [int(member_stats.get("level", 1)), int(member_stats.get("stage", 1)), int(member_stats.get("level_cap", 10))])
	_add_attribute_row("气血", "%d/%d" % [int(member_stats.get("hp", 0)), game_state.total_stat_for(member_id, "max_hp")])
	_add_attribute_row("法力", "%d/%d" % [int(member_stats.get("mp", 0)), game_state.total_stat_for(member_id, "max_mp")])
	_add_attribute_row("经验", "%d/%d" % [int(member_stats.get("exp", 0)), int(member_stats.get("next_exp", 0))])
	_add_attribute_row("成长", game_state.growth_summary_for(member_id))
	_add_attribute_row("攻击", str(game_state.total_attack_for(member_id)))
	_add_attribute_row("防御", str(game_state.total_defense_for(member_id)))
	_add_attribute_row("根骨", str(game_state.total_stat_for(member_id, "root_bone")))
	_add_attribute_row("五行", game_state.element_summary_for(member_id))
	_add_attribute_row("主五行", DataTables.element_name(game_state.dominant_element_for(member_id)))


func _add_attribute_row(label_text: String, value_text: String) -> void:
	var value_label: Label = Label.new()
	value_label.custom_minimum_size = Vector2(184, 18)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.text = value_text
	_add_attribute_control_row(label_text, value_label)


func _add_attribute_control_row(label_text: String, value_control: Control) -> void:
	var name_label: Label = Label.new()
	name_label.custom_minimum_size = Vector2(56, 18)
	name_label.text = label_text
	member_info_attribute_grid.add_child(name_label)
	member_info_attribute_grid.add_child(value_control)


func _refresh_member_info_traits(game_state) -> void:
	_clear_control_children(member_info_trait_grid)
	var member: Dictionary = game_state.member_by_id(selected_party_member_id) if game_state != null else {}
	if member.is_empty():
		member_info_trait_grid.add_child(_create_member_info_slot("命格", "暂无角色", ""))
		return
	var traits: Array = member.get("innate_traits", []) if member.get("innate_traits", []) is Array else []
	if traits.is_empty():
		member_info_trait_grid.add_child(_create_member_info_slot("命格", "暂无命格", "该角色没有已记录的先天命格。"))
		return
	for raw_trait in traits:
		var slot := DataTables.innate_trait_slot(raw_trait)
		var header := "%s · %s" % [
			DataTables.innate_trait_rarity_name(DataTables.innate_trait_rarity(raw_trait)),
			DataTables.innate_trait_slot_name(slot),
		]
		if raw_trait is Dictionary and bool(raw_trait.get("awakened", false)):
			header += " · 已觉醒"
		var detail := "%s\n%s" % [
			DataTables.innate_trait_description(raw_trait),
			DataTables.innate_trait_effect_summary(raw_trait),
		]
		var trait_slot := _create_member_info_slot(header, DataTables.innate_trait_name(raw_trait), detail)
		if slot == "flaw":
			trait_slot.modulate = Color(1.0, 0.72, 0.72, 1.0)
		member_info_trait_grid.add_child(trait_slot)


func _create_panel_style(fill_color: Color, border_color: Color, border_width: int = 1, corner_radius: int = 6, left_margin: float = 8.0, top_margin: float = 6.0, right_margin: float = 8.0, bottom_margin: float = 6.0, shadow_size: int = 2, shadow_color: Color = Color(0, 0, 0, 0.28)) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.content_margin_left = left_margin
	style.content_margin_top = top_margin
	style.content_margin_right = right_margin
	style.content_margin_bottom = bottom_margin
	style.shadow_size = shadow_size
	style.shadow_color = shadow_color
	return style


func _create_button_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	return _create_panel_style(fill_color, border_color, 1, 6, 10.0, 5.0, 10.0, 5.0, 1, Color(0, 0, 0, 0.3))


func _refresh_member_info_equipment(game_state) -> void:
	_clear_control_children(member_info_equipment_grid)
	if game_state == null or game_state.member_by_id(selected_party_member_id).is_empty():
		member_info_equipment_grid.add_child(_create_member_info_slot("装备", "暂无角色", ""))
		return
	var slots: Array[Dictionary] = [
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
		var item: Dictionary = game_state.equipped_item_for(selected_party_member_id, slot_id)
		var item_name: String = "未装备"
		var detail: String = ""
		if not item.is_empty():
			item_name = str(item.get("name", "装备"))
			detail = "等级 %d  %s" % [int(item.get("equipment_level", 1)), DataTables.equipment_rarity_name(str(item.get("rarity", "t1")))]
		member_info_equipment_grid.add_child(_create_member_info_slot(str(slot_def.get("label", slot_id)), item_name, detail))


func _refresh_member_info_skills(game_state) -> void:
	_clear_control_children(member_info_skill_grid)
	var member: Dictionary = game_state.member_by_id(selected_party_member_id)
	if member.is_empty():
		member_info_skill_grid.add_child(_create_member_info_slot("技能", "暂无角色", ""))
		return
	var member_skills: Array = member.get("skills", [])
	if member_skills.is_empty():
		member_info_skill_grid.add_child(_create_member_info_slot("技能", "未学习技能", ""))
		return
	for skill in member_skills:
		var skill_id: String = str(skill.get("id", ""))
		if bool(skill.get("disabled", false)):
			member_info_skill_grid.add_child(_create_member_info_slot("技能", skill_id, "Mod 技能缺失，当前已禁用"))
			continue
		var element_id: String = str(skill.get("element", ""))
		var target_mode_text: String = DataTables.skill_target_mode_name(DataTables.skill_target_mode(skill))
		var effect_names := PackedStringArray()
		for tag in DataTables.skill_effect_tags(skill):
			if effect_names.size() >= 2:
				break
			effect_names.append(DataTables.skill_effect_tag_name(str(tag)))
		var classification := target_mode_text
		if not effect_names.is_empty():
			classification += "·%s" % "/".join(effect_names)
		var cooldown_text: String = str(int(skill.get("cooldown", 0)))
		var detail: String = "%s  %s  CD%s  MP%d" % [classification, DataTables.element_name(element_id), cooldown_text, int(skill.get("mp_cost", 0))]
		var scaling_text := _skill_scaling_text(skill, game_state, selected_party_member_id)
		if not scaling_text.is_empty():
			detail += "\n%s" % scaling_text
		member_info_skill_grid.add_child(_create_member_info_slot("技能", str(skill.get("name", "未命名技能")), detail, DataTables.skill_icon_texture(skill_id)))


func _skill_scaling_text(skill: Dictionary, game_state, member_id: String) -> String:
	var skill_element: String = str(skill.get("element", ""))
	var parts := PackedStringArray()
	if skill.has("damage_attribute_multiplier"):
		parts.append(_skill_value_formula(
			"伤害",
			int(skill.get("base_damage", 0)),
			float(skill.get("damage_attribute_multiplier", 0.0)),
			skill_element,
			game_state,
			member_id
		))
	elif skill.has("base_damage"):
		parts.append("伤害 %d（固定）" % maxi(0, int(skill.get("base_damage", 0))))
	if skill.has("heal_attribute_multiplier"):
		parts.append(_skill_value_formula(
			"治疗",
			int(skill.get("heal_amount", 0)),
			float(skill.get("heal_attribute_multiplier", 0.0)),
			skill_element,
			game_state,
			member_id
		))
	elif skill.has("heal_amount"):
		parts.append("治疗 %d（固定）" % maxi(0, int(skill.get("heal_amount", 0))))
	for effect in skill.get("effects", []):
		if not (effect is Dictionary):
			continue
		var effect_kind := str(effect.get("kind", ""))
		if not SkillValueResolverScript.SCALABLE_EFFECT_KINDS.has(effect_kind):
			continue
		var label: String = {
			"damage_flat": "附伤",
			"defense_ignore": "破防",
			"dot": "持续伤害",
			"hot": "持续治疗",
			"shield": "护盾",
			"heal": "治疗",
			"buff_stat": "属性提升",
			"debuff_stat": "属性降低",
		}.get(effect_kind, "效果")
		var base_value := int(effect.get("amount", effect.get("value", 0)))
		if effect.has("attribute_multiplier"):
			parts.append(_skill_value_formula(
				label,
				base_value,
				float(effect.get("attribute_multiplier", 0.0)),
				str(effect.get("element", skill_element)),
				game_state,
				member_id
			))
		else:
			parts.append("%s %d（固定）" % [label, base_value])
	return "；".join(parts)


func _skill_value_formula(label: String, base_amount: int, multiplier: float, element_id: String, game_state, member_id: String) -> String:
	var resolved_element := element_id
	if resolved_element.is_empty():
		resolved_element = str(game_state.dominant_element_for(member_id))
	var attribute_value: int = int(game_state.total_element_for(member_id, resolved_element))
	var current_value := SkillValueResolverScript.scaled_amount_from_attribute(base_amount, multiplier, attribute_value)
	return "%s %d + %s%d x %.2f = %d" % [
		label,
		base_amount,
		DataTables.element_name(resolved_element),
		attribute_value,
		multiplier,
		current_value,
	]


func _create_member_info_slot(slot_label: String, item_name: String, detail_text: String, icon_texture: Texture2D = null) -> PanelContainer:
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = Vector2(264, 48)
	slot.add_theme_stylebox_override("panel", _create_panel_style(CARD_FILL_COLOR, CARD_BORDER_COLOR))
	var layout: HBoxContainer = HBoxContainer.new()
	layout.name = "SlotLayout"
	layout.add_theme_constant_override("separation", 6)
	slot.add_child(layout)
	var icon: TextureRect = TextureRect.new()
	icon.name = "IconPlaceholder"
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = icon_texture
	icon.visible = icon_texture != null
	layout.add_child(icon)
	var text_layout: VBoxContainer = VBoxContainer.new()
	text_layout.name = "TextLayout"
	text_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_layout.add_theme_constant_override("separation", 1)
	layout.add_child(text_layout)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "%s：%s" % [slot_label, item_name]
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_color", Color(1, 0.93, 0.74, 1))
	text_layout.add_child(name_label)
	var detail_label: Label = Label.new()
	detail_label.name = "DetailLabel"
	detail_label.text = detail_text
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_layout.add_child(detail_label)
	return slot



func _clear_control_children(container: Control) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _begin_window_drag(mouse_position: Vector2) -> bool:
	_ensure_menu_panel_refs()
	if window_drag_button == null or not window_drag_button.get_global_rect().has_point(mouse_position):
		return false
	_start_window_drag(mouse_position)
	return true


func _on_window_drag_button_down() -> void:
	_ensure_menu_panel_refs()
	_start_window_drag(get_viewport().get_mouse_position())


func _on_window_drag_button_up() -> void:
	_end_window_drag()


func _start_window_drag(mouse_position: Vector2) -> void:
	dragging_window = true
	window_drag_mouse_start = mouse_position
	window_drag_start_position = DisplayServer.window_get_position()


func _end_window_drag() -> void:
	dragging_window = false


func show_home_action_panel(task_type: int) -> void:
	_ensure_menu_panel_refs()
	var panel: Control = _panel_for_task(task_type)
	if panel == null:
		return
	_close_popup_panels()
	var menu: Control = get_node_or_null("Root/MenuPanel") as Control
	if menu != null:
		menu.visible = false
	panel.visible = true
	_refresh_action_detail(task_type)
	if task_type == GameDefs.TaskType.FARM:
		_refresh_farm_panel()
	if task_type == GameDefs.TaskType.FORGE:
		_refresh_forge_panel()
	if task_type == GameDefs.TaskType.ALCHEMY:
		_refresh_alchemy_panel()
	if task_type == GameDefs.TaskType.RECRUIT:
		_refresh_recruit_panel()
	panel.reset_size()
	_apply_saved_panel_position(panel)
	call_deferred("_apply_saved_panel_position_if_visible", panel)


func _toggle_menu() -> void:
	_ensure_menu_panel_refs()
	var next_visible: bool = not menu_panel.visible
	_close_popup_panels()
	_apply_saved_panel_position(menu_panel)
	menu_panel.visible = next_visible


func _open_member_info_panel() -> void:
	_ensure_menu_panel_refs()
	_close_popup_panels()
	menu_panel.visible = false
	_apply_saved_panel_position(member_info_panel)
	member_info_panel.visible = true


func _open_inventory_panel() -> void:
	_ensure_menu_panel_refs()
	_close_popup_panels()
	menu_panel.visible = false
	_apply_saved_panel_position(inventory_panel)
	inventory_panel.visible = true
	_refresh_inventory()


func _toggle_debug_panel() -> void:
	_ensure_menu_panel_refs()
	_populate_debug_options()
	var next_visible: bool = not debug_panel.visible
	_close_popup_panels()
	_apply_saved_panel_position(debug_panel)
	debug_panel.visible = next_visible


func _ensure_menu_panel_refs() -> void:
	if menu_panel == null:
		menu_panel = $Root/MenuPanel
	if member_info_panel == null:
		member_info_panel = $Root/MemberInfoPanel
	if inventory_panel == null:
		inventory_panel = $Root/InventoryPanel
	if farm_panel == null:
		farm_panel = $Root/FarmPanel
	if forge_panel == null:
		forge_panel = $Root/ForgePanel
	if alchemy_panel == null:
		alchemy_panel = $Root/AlchemyPanel
	if recruit_panel == null:
		recruit_panel = $Root/RecruitPanel
	if fight_panel == null:
		fight_panel = $Root/FightPanel
	if member_info_member_list == null:
		member_info_member_list = $Root/MemberInfoPanel/PanelLayout/MemberList
	if member_info_attribute_grid == null:
		member_info_attribute_grid = $Root/MemberInfoPanel/PanelLayout/ContentRow/InfoTabs/属性/AttributeGrid
	if member_info_trait_grid == null:
		member_info_trait_grid = $Root/MemberInfoPanel/PanelLayout/ContentRow/InfoTabs/命格/TraitGrid
	if member_info_equipment_grid == null:
		member_info_equipment_grid = $Root/MemberInfoPanel/PanelLayout/ContentRow/InfoTabs/装备/EquipmentGrid
	if member_info_skill_grid == null:
		member_info_skill_grid = $Root/MemberInfoPanel/PanelLayout/ContentRow/InfoTabs/技能/SkillGrid
	if member_info_portrait_root == null:
		member_info_portrait_root = $Root/MemberInfoPanel/PanelLayout/ContentRow/PortraitPanel/PortraitLayout/PortraitViewportContainer/PortraitViewport/PortraitRoot
	if member_info_portrait_name == null:
		member_info_portrait_name = $Root/MemberInfoPanel/PanelLayout/ContentRow/PortraitPanel/PortraitLayout/PortraitName
	if inventory_grid == null:
		inventory_grid = $Root/InventoryPanel/InventoryLayout/InventoryGrid
	if inventory_detail_view == null:
		inventory_detail_view = $Root/InventoryItemDetailPanel
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
	if recruit_detail == null:
		recruit_detail = $Root/RecruitPanel/PanelLayout/ActionDetail
	if recruit_candidate_list == null:
		recruit_candidate_list = $Root/RecruitPanel/PanelLayout/CandidateList
	if recruit_button == null:
		recruit_button = $Root/RecruitPanel/PanelLayout/RecruitButton
	if recruit_refresh_button == null:
		recruit_refresh_button = $Root/RecruitPanel/PanelLayout/ButtonRow/RefreshButton
	if party_list == null:
		party_list = $Root/RecruitPanel/PanelLayout/PartyList
	if party_move_up_button == null:
		party_move_up_button = $Root/RecruitPanel/PanelLayout/PartyButtonRow/MoveUpButton
	if party_move_down_button == null:
		party_move_down_button = $Root/RecruitPanel/PanelLayout/PartyButtonRow/MoveDownButton
	if party_toggle_active_button == null:
		party_toggle_active_button = $Root/RecruitPanel/PanelLayout/PartyButtonRow/ToggleActiveButton
	if party_dismiss_button == null:
		party_dismiss_button = $Root/RecruitPanel/PanelLayout/PartyButtonRow/DismissButton
	if release_confirmation_dialog == null:
		release_confirmation_dialog = $Root/ReleaseConfirmationDialog
	if fight_detail == null:
		fight_detail = $Root/FightPanel/PanelLayout/ActionDetail
	if expedition_map_option == null:
		expedition_map_option = $Root/FightPanel/PanelLayout/MapRow/MapOption
	if expedition_hud == null:
		expedition_hud = $Root/ExpeditionHud
	if return_home_button == null:
		return_home_button = $Root/ExpeditionHud/PanelLayout/ReturnHomeButton
	if loading_overlay == null:
		loading_overlay = $Root/LoadingOverlay
	if loading_label == null:
		loading_label = $Root/LoadingOverlay/LoadingLabel
	if window_drag_button == null:
		window_drag_button = $Root/WindowDragButton
	if debug_button == null:
		debug_button = $Root/DebugButton
	if debug_panel == null:
		debug_panel = $Root/DebugPanel
	if debug_item_option == null:
		debug_item_option = $Root/DebugPanel/PanelLayout/AddItemRow/ItemOption
	if debug_item_amount_spinbox == null:
		debug_item_amount_spinbox = $Root/DebugPanel/PanelLayout/AddItemRow/ItemAmountSpinBox
	if debug_add_item_button == null:
		debug_add_item_button = $Root/DebugPanel/PanelLayout/AddItemRow/AddItemButton
	if debug_equipment_option == null:
		debug_equipment_option = $Root/DebugPanel/PanelLayout/EquipmentRow/EquipmentOption
	if debug_equipment_level_spinbox == null:
		debug_equipment_level_spinbox = $Root/DebugPanel/PanelLayout/EquipmentRow/EquipmentLevelSpinBox
	if debug_equipment_rarity_option == null:
		debug_equipment_rarity_option = $Root/DebugPanel/PanelLayout/EquipmentRow/EquipmentRarityOption
	if debug_add_equipment_button == null:
		debug_add_equipment_button = $Root/DebugPanel/PanelLayout/EquipmentRow/AddEquipmentButton
	if debug_stat_option == null:
		debug_stat_option = $Root/DebugPanel/PanelLayout/StatRow/StatOption
	if debug_stat_value_spinbox == null:
		debug_stat_value_spinbox = $Root/DebugPanel/PanelLayout/StatRow/StatValueSpinBox
	if debug_set_stat_button == null:
		debug_set_stat_button = $Root/DebugPanel/PanelLayout/StatRow/SetStatButton
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
	if farm_upgrade_button == null:
		farm_upgrade_button = _ensure_building_upgrade_button(farm_panel, "farm")
	if forge_upgrade_button == null:
		forge_upgrade_button = _ensure_building_upgrade_button(forge_panel, "forge")
	if alchemy_upgrade_button == null:
		alchemy_upgrade_button = _ensure_building_upgrade_button(alchemy_panel, "alchemy")
	if recruit_upgrade_button == null:
		recruit_upgrade_button = _ensure_building_upgrade_button(recruit_panel, "recruit")
	_connect_farm_controls()
	_connect_forge_controls()
	_connect_alchemy_controls()
	_connect_recruit_controls()
	_connect_debug_controls()


func _ensure_building_upgrade_button(panel: PanelContainer, building_id: String) -> Button:
	if panel == null:
		return null
	var layout: VBoxContainer = panel.get_node_or_null("PanelLayout") as VBoxContainer
	if layout == null:
		return null
	var button_name: String = "%sUpgradeButton" % building_id.capitalize()
	var button: Button = layout.get_node_or_null(button_name) as Button
	if button == null:
		button = Button.new()
		button.name = button_name
		button.custom_minimum_size = Vector2(120, 28)
		button.add_theme_stylebox_override("normal", _create_button_style(BUTTON_FILL_COLOR, BUTTON_BORDER_COLOR))
		button.add_theme_stylebox_override("hover", _create_button_style(BUTTON_HOVER_FILL_COLOR, BUTTON_HOVER_BORDER_COLOR))
		button.add_theme_stylebox_override("pressed", _create_button_style(BUTTON_PRESSED_FILL_COLOR, BUTTON_PRESSED_BORDER_COLOR))
		button.add_theme_stylebox_override("disabled", _create_button_style(BUTTON_DISABLED_FILL_COLOR, BUTTON_DISABLED_BORDER_COLOR))
		layout.add_child(button)
		var action_detail: Node = layout.get_node_or_null("ActionDetail")
		if action_detail != null:
			layout.move_child(button, action_detail.get_index() + 1)
	if not bool(button.get_meta("upgrade_connected", false)):
		button.pressed.connect(func(): _on_building_upgrade_pressed(building_id))
		button.set_meta("upgrade_connected", true)
	return button


func _on_building_upgrade_pressed(building_id: String) -> void:
	if current_game_state == null:
		return
	if current_game_state.upgrade_building(building_id):
		_refresh_visible_action_details()
		if inventory_panel.visible:
			_refresh_inventory()


func _refresh_building_upgrade_button(button: Button, building_id: String) -> void:
	if button == null or current_game_state == null:
		return
	var level: int = current_game_state.building_level(building_id)
	var max_level: int = DataTables.building_max_level(building_id)
	if level >= max_level:
		button.text = "%s已满级" % DataTables.building_name(building_id)
		button.disabled = true
		return
	if level >= current_game_state.building_level_cap():
		button.text = "历练%d解锁%d级" % [current_game_state.next_building_level_requirement(building_id), level + 1]
		button.disabled = true
		return
	var cost: Dictionary = current_game_state.building_upgrade_cost(building_id)
	var item_id: String = str(cost.get("item_id", ""))
	var amount: int = int(cost.get("amount", 0))
	var current: int = current_game_state.inventory_item_count(item_id)
	button.text = "升级%s %d/%d" % [DataTables.building_name(building_id), current, amount]
	button.disabled = not current_game_state.can_upgrade_building(building_id)


func _building_level_summary(building_id: String) -> String:
	if current_game_state == null:
		return ""
	var level: int = current_game_state.building_level(building_id)
	var max_level: int = DataTables.building_max_level(building_id)
	var level_cap: int = current_game_state.building_level_cap()
	var summary := "%s %d/%d｜上限%d" % [DataTables.building_name(building_id), level, max_level, level_cap]
	if level >= max_level:
		return "%s  已满级" % summary
	var requirement: int = current_game_state.next_building_level_requirement(building_id)
	if level >= level_cap:
		return "%s｜下级需历练%d" % [summary, requirement]
	var cost: Dictionary = current_game_state.building_upgrade_cost(building_id)
	return "%s｜升级%s x%d｜下级需历练%d" % [
		summary,
		DataTables.resource_name(str(cost.get("item_id", ""))),
		int(cost.get("amount", 0)),
		requirement,
	]


func _trait_summary(traits: Array) -> String:
	if traits.is_empty():
		return "无命格"
	var names: Array[String] = []
	for raw_trait in traits:
		names.append(DataTables.innate_trait_compact_summary(raw_trait))
	return "/".join(names)


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
	alchemy_craft_count_spinbox.value_changed.connect(func(_value): _refresh_alchemy_material_cost_grid())
	alchemy_controls_connected = true


func _connect_recruit_controls() -> void:
	if recruit_controls_connected:
		return
	if recruit_candidate_list == null or recruit_button == null or party_list == null:
		return
	recruit_candidate_list.item_selected.connect(_on_recruit_candidate_selected)
	recruit_button.pressed.connect(_on_recruit_pressed)
	recruit_refresh_button.pressed.connect(_on_recruit_refresh_pressed)
	party_list.item_selected.connect(_on_recruit_party_member_selected)
	party_move_up_button.pressed.connect(func(): _on_party_move_pressed(-1))
	party_move_down_button.pressed.connect(func(): _on_party_move_pressed(1))
	party_toggle_active_button.pressed.connect(_on_party_toggle_active_pressed)
	party_dismiss_button.pressed.connect(_on_party_dismiss_pressed)
	if member_info_member_list != null:
		member_info_member_list.item_selected.connect(_on_member_info_member_selected)
	recruit_controls_connected = true


func _connect_debug_controls() -> void:
	if debug_controls_connected:
		return
	if debug_add_item_button == null or debug_add_equipment_button == null or debug_set_stat_button == null:
		return
	debug_add_item_button.pressed.connect(_on_debug_add_item_pressed)
	debug_add_equipment_button.pressed.connect(_on_debug_add_equipment_pressed)
	debug_set_stat_button.pressed.connect(_on_debug_set_stat_pressed)
	debug_controls_connected = true


func _draggable_panels() -> Array[Control]:
	return [
		menu_panel,
		member_info_panel,
		inventory_panel,
		farm_panel,
		forge_panel,
		alchemy_panel,
		recruit_panel,
		fight_panel,
		market_panel,
		debug_panel,
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
	if not (position_data is Dictionary):
		return
	var target: Vector2 = Vector2(float(position_data.get("x", panel.position.x)), float(position_data.get("y", panel.position.y)))
	panel.position = _clamp_panel_position(panel, target)


func _apply_saved_panel_position_if_visible(panel: Control) -> void:
	if panel != null and is_instance_valid(panel) and panel.visible:
		_apply_saved_panel_position(panel)


func _begin_panel_drag(mouse_position: Vector2) -> void:
	_ensure_menu_panel_refs()
	for panel in _draggable_panels():
		if panel == null or not panel.visible:
			continue
		var handle: Control = _drag_handle_for_panel(panel)
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
	var header: Control = panel.get_node_or_null("PanelLayout/Header") as Control
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


func _populate_debug_options() -> void:
	_ensure_menu_panel_refs()
	if debug_options_populated:
		return
	_populate_debug_item_options()
	_populate_debug_equipment_options()
	_populate_debug_rarity_options()
	_populate_debug_stat_options()
	debug_options_populated = true


func _populate_debug_item_options() -> void:
	debug_item_option.clear()
	var item_ids: Array = DataTables.content_ids("item", DataTables.ITEM_DEFS)
	item_ids.sort()
	for item_id in item_ids:
		var item_data: Dictionary = DataTables.item_definition(str(item_id))
		if item_data.is_empty():
			continue
		var index: int = debug_item_option.item_count
		debug_item_option.add_item("%s (%s)" % [DataTables.resource_name(str(item_id)), str(item_id)])
		debug_item_option.set_item_metadata(index, str(item_id))


func _populate_debug_equipment_options() -> void:
	debug_equipment_option.clear()
	var template_ids: Array = DataTables.content_ids("equipment", DataTables.EQUIPMENT_DEFS)
	template_ids.sort()
	for template_id in template_ids:
		var template_data: Dictionary = DataTables.content_definition("equipment", str(template_id), DataTables.EQUIPMENT_DEFS.get(str(template_id), {}))
		var label: String = str(template_data.get("name", DataTables.slot_name(str(template_data.get("slot", template_id)))))
		var index: int = debug_equipment_option.item_count
		debug_equipment_option.add_item("%s (%s)" % [label, str(template_id)])
		debug_equipment_option.set_item_metadata(index, str(template_id))


func _populate_debug_rarity_options() -> void:
	debug_equipment_rarity_option.clear()
	for rarity in DataTables.EQUIPMENT_RARITY_ORDER:
		var index: int = debug_equipment_rarity_option.item_count
		debug_equipment_rarity_option.add_item(DataTables.equipment_rarity_name(str(rarity)))
		debug_equipment_rarity_option.set_item_metadata(index, str(rarity))


func _populate_debug_stat_options() -> void:
	debug_stat_option.clear()
	for option in DEBUG_STAT_OPTIONS:
		var stat_id: String = str(option.get("id", ""))
		var label: String = str(option.get("label", stat_id))
		var index: int = debug_stat_option.item_count
		debug_stat_option.add_item("%s (%s)" % [label, stat_id])
		debug_stat_option.set_item_metadata(index, stat_id)


func _on_debug_add_item_pressed() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null or debug_item_option.item_count <= 0:
		return
	var item_id: String = _selected_option_metadata(debug_item_option)
	var amount: int = int(clamp(debug_item_amount_spinbox.value, 1.0, 999.0))
	if current_game_state.debug_add_item(item_id, amount):
		_refresh_after_debug_change()


func _on_debug_add_equipment_pressed() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null or debug_equipment_option.item_count <= 0 or debug_equipment_rarity_option.item_count <= 0:
		return
	var template_id: String = _selected_option_metadata(debug_equipment_option)
	var rarity: String = _selected_option_metadata(debug_equipment_rarity_option)
	var level: int = maxi(1, int(debug_equipment_level_spinbox.value))
	if current_game_state.debug_add_equipment(template_id, level, rarity):
		_refresh_after_debug_change()


func _on_debug_set_stat_pressed() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null or debug_stat_option.item_count <= 0:
		return
	var stat_id: String = _selected_option_metadata(debug_stat_option)
	var value: int = int(debug_stat_value_spinbox.value)
	if current_game_state.debug_set_stat(stat_id, value, selected_party_member_id):
		_refresh_after_debug_change()


func _selected_option_metadata(option: OptionButton) -> String:
	var selected_index: int = option.selected
	if selected_index < 0:
		return ""
	return str(option.get_item_metadata(selected_index))


func _refresh_after_debug_change() -> void:
	if current_game_state == null:
		return
	_refresh_member_info(current_game_state)
	if inventory_panel.visible:
		_refresh_inventory()
	if forge_panel.visible:
		_refresh_forge_panel()
	if alchemy_panel.visible:
		_refresh_alchemy_panel()
	_refresh_visible_action_details()


func _clamp_panel_position(panel: Control, target: Vector2) -> Vector2:
	var viewport_size: Vector2 = _viewport_size()
	var minimum_size: Vector2 = panel.get_combined_minimum_size()
	var panel_size := Vector2(
		maxf(panel.size.x, minimum_size.x),
		maxf(panel.size.y, minimum_size.y)
	)
	var max_x: float = max(DRAG_MARGIN, viewport_size.x - panel_size.x - DRAG_MARGIN)
	var max_y: float = max(DRAG_MARGIN, viewport_size.y - panel_size.y - DRAG_MARGIN)
	return Vector2(
		clampf(target.x, DRAG_MARGIN, max_x),
		clampf(target.y, DRAG_MARGIN, max_y)
	)


func _position_to_dictionary(position: Vector2) -> Dictionary:
	return {"x": float(position.x), "y": float(position.y)}


func _viewport_size() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		return viewport.get_visible_rect().size
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 480))
	)


func _close_popup_panels() -> void:
	for panel_path in ["Root/MemberInfoPanel", "Root/InventoryPanel", "Root/FarmPanel", "Root/ForgePanel", "Root/AlchemyPanel", "Root/RecruitPanel", "Root/FightPanel", "Root/MarketPanel", "Root/DebugPanel"]:
		var panel: Control = get_node_or_null(panel_path) as Control
		if panel != null:
			panel.visible = false


func _panel_for_task(task_type: int) -> PanelContainer:
	if task_type == GameDefs.TaskType.FARM:
		return get_node_or_null("Root/FarmPanel") as PanelContainer
	if task_type == GameDefs.TaskType.FORGE:
		return get_node_or_null("Root/ForgePanel") as PanelContainer
	if task_type == GameDefs.TaskType.ALCHEMY:
		return get_node_or_null("Root/AlchemyPanel") as PanelContainer
	if task_type == GameDefs.TaskType.RECRUIT:
		return get_node_or_null("Root/RecruitPanel") as PanelContainer
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
	if recruit_panel.visible:
		_refresh_action_detail(GameDefs.TaskType.RECRUIT)
	if fight_panel.visible:
		_refresh_action_detail(GameDefs.TaskType.FIGHT)


func _refresh_action_detail(task_type: int) -> void:
	if current_game_state == null:
		return

	if task_type == GameDefs.TaskType.FARM:
		_refresh_farm_panel()
	elif task_type == GameDefs.TaskType.FORGE:
		_refresh_forge_panel()
	elif task_type == GameDefs.TaskType.RECRUIT:
		_refresh_recruit_panel()
	elif task_type == GameDefs.TaskType.FIGHT:
		var fight_button: Button = get_node_or_null("Root/FightPanel/PanelLayout/ExecuteButton") as Button
		var has_member: bool = current_game_state.has_party_member()
		var map_summary := _selected_expedition_map_summary()
		var has_map := not map_summary.is_empty() and bool(map_summary.get("unlocked", false))
		if has_member:
			fight_detail.text = "%s\n账号历练 %d级  %d/%d" % [
				str(map_summary.get("description", "请选择历练地图")),
				current_game_state.expedition_level(),
				int(current_game_state.account_progression.get("expedition_exp", 0)),
				int(current_game_state.account_progression.get("next_expedition_exp", 1)),
			]
		else:
			fight_detail.text = "需要先招募角色"
		if fight_button != null:
			fight_button.disabled = not has_member or not has_map


func _progress_label_text(progress_id: String) -> String:
	return "进度：%s" % _progress_summary(progress_id)


func _action_button_text(progress_id: String) -> String:
	var progress: Dictionary = current_game_state.progress_state(progress_id) if current_game_state != null else {}
	if bool(progress.get("claimable", false)):
		return "领取"
	if bool(progress.get("completed", false)):
		return "已完成"
	if progress_id == "farm":
		return "种植"
	if progress_id == "forge":
		return "炼制"
	return "执行"


func _action_button_disabled(progress_id: String) -> bool:
	var progress: Dictionary = current_game_state.progress_state(progress_id) if current_game_state != null else {}
	if bool(progress.get("claimable", false)):
		return false
	if progress_id == "farm":
		return current_game_state == null or current_game_state.inventory_total_for_type(DataTables.ITEM_TYPE_CROP) <= 0
	if progress_id == "forge":
		return current_game_state == null or current_game_state.inventory_item_count(DataTables.ITEM_ID_ORE) < current_game_state.forge_material_cost()
	if progress_id == "alchemy":
		return current_game_state == null or current_game_state.known_alchemy_recipes.is_empty()
	return current_game_state == null


func _progress_summary(progress_id: String) -> String:
	if current_game_state == null:
		return "未开始"
	var progress: Dictionary = current_game_state.progress_state(progress_id)
	var status: String = str(progress.get("status", "not_started"))
	var detail: String = str(progress.get("detail", ""))
	if detail.is_empty():
		return _progress_status_text(status)
	return "%s / %s" % [_progress_status_text(status), _progress_detail_text(detail)]


func _progress_status_text(status: String) -> String:
	match status:
		"not_started":
			return "未开始"
		"growing":
			return "生长中"
		"working":
			return "进行中"
		"claimable":
			return "可领取"
		"completed":
			return "已完成"
		_:
			return status


func _progress_detail_text(detail: String) -> String:
	if detail == "Not started":
		return "未开始"
	if detail.ends_with(" growing"):
		return "%s 生长中" % detail.trim_suffix(" growing")
	if detail.ends_with(" plots ready"):
		return "%s 块农田可收取" % detail.trim_suffix(" plots ready")
	if detail.ends_with(" plots growing"):
		return "%s 块农田生长中" % detail.trim_suffix(" plots growing")
	return detail


func _refresh_recruit_panel() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null:
		return
	var stone_count: int = current_game_state.recruit_stone_count()
	var recruit_cost: int = current_game_state.recruit_cost()
	_refresh_building_upgrade_button(recruit_upgrade_button, "recruit")
	recruit_detail.text = "%s\n角色库 %d/%d  出战 %d/%d  灵石 %d/%d" % [
		_building_level_summary("recruit"),
		current_game_state.roster_member_count(),
		ROSTER_MAX_SIZE,
		current_game_state.party_member_count(),
		PARTY_MAX_SIZE,
		stone_count,
		recruit_cost,
	]
	_refresh_recruit_candidate_list()
	_refresh_recruit_party_list()
	_refresh_manual_exchange_page()
	var candidate_selected := not selected_recruit_candidate_id.is_empty()
	recruit_button.disabled = not candidate_selected or not current_game_state.can_recruit()
	if current_game_state.roster_member_count() >= ROSTER_MAX_SIZE:
		recruit_button.text = "角色库已满"
	elif stone_count < recruit_cost:
		recruit_button.text = "灵石不足"
	else:
		recruit_button.text = "招募"
	var active_index: int = current_game_state.party_order.find(selected_recruit_party_member_id)
	var selected_active := active_index >= 0
	party_move_up_button.disabled = active_index <= 0
	party_move_down_button.disabled = active_index < 0 or active_index >= current_game_state.party_member_count() - 1
	party_toggle_active_button.text = "下阵" if selected_active else "上阵"
	party_toggle_active_button.disabled = selected_recruit_party_member_id.is_empty() or (not selected_active and current_game_state.party_member_count() >= PARTY_MAX_SIZE)
	party_dismiss_button.disabled = selected_recruit_party_member_id.is_empty()


func _refresh_recruit_candidate_list() -> void:
	recruit_candidate_list.clear()
	var selected_index := -1
	for index in range(current_game_state.recruit_candidates.size()):
		var candidate: Dictionary = current_game_state.recruit_candidates[index]
		var candidate_id: String = str(candidate.get("candidate_id", ""))
		var stats_data: Dictionary = candidate.get("stats", {})
		var traits: Array = candidate.get("innate_traits", []) if candidate.get("innate_traits", []) is Array else []
		var trait_text := _trait_summary(traits)
		if not traits.is_empty():
			trait_text += " %s" % DataTables.innate_trait_effect_summary(traits[0])
		var label := "%s Lv.%d 攻%d 防%d 根%d | %s" % [
			str(candidate.get("name", "候选人")),
			int(stats_data.get("level", 1)),
			int(stats_data.get("attack", 0)),
			int(stats_data.get("defense", 0)),
			int(stats_data.get("root_bone", 0)),
			trait_text,
		]
		var item_index := recruit_candidate_list.add_item(label)
		recruit_candidate_list.set_item_metadata(item_index, candidate_id)
		recruit_candidate_list.set_item_tooltip(item_index, "%s\n%s" % [
			current_game_state.growth_summary_for_member_data(candidate),
			_trait_detail_summary(traits),
		])
		if candidate_id == selected_recruit_candidate_id:
			selected_index = item_index
	if selected_index >= 0:
		recruit_candidate_list.select(selected_index)
	elif recruit_candidate_list.item_count > 0:
		recruit_candidate_list.select(0)
		selected_recruit_candidate_id = str(recruit_candidate_list.get_item_metadata(0))


func _refresh_recruit_party_list() -> void:
	party_list.clear()
	var selected_index := 0
	var members: Array = current_game_state.roster_members()
	if members.is_empty():
		var empty_index: int = party_list.add_item("暂无角色")
		party_list.set_item_metadata(empty_index, "")
		party_list.select(empty_index)
		selected_recruit_party_member_id = ""
		return
	for index in range(members.size()):
		var member: Dictionary = members[index]
		var member_id: String = str(member.get("id", ""))
		var member_stats: Dictionary = member.get("stats", {})
		var active: bool = bool(current_game_state.is_member_active(member_id))
		var label := "%s %s  Lv.%d  血%d/%d 法%d/%d" % [
			"[出战 %d]" % (current_game_state.party_order.find(member_id) + 1) if active else "[候补]",
			str(member.get("name", "成员")),
			int(member_stats.get("level", 1)),
			int(member_stats.get("hp", 0)),
			current_game_state.total_stat_for(member_id, "max_hp"),
			int(member_stats.get("mp", 0)),
			current_game_state.total_stat_for(member_id, "max_mp"),
		]
		var item_index := party_list.add_item(label)
		party_list.set_item_metadata(item_index, member_id)
		if member_id == selected_recruit_party_member_id:
			selected_index = item_index
	if party_list.item_count > 0:
		party_list.select(selected_index)
		selected_recruit_party_member_id = str(party_list.get_item_metadata(selected_index))


func _candidate_element_summary(elements_data: Dictionary) -> String:
	return "木%d 火%d 土%d 金%d 水%d" % [
		int(elements_data.get("wood", 0)),
		int(elements_data.get("fire", 0)),
		int(elements_data.get("earth", 0)),
		int(elements_data.get("metal", 0)),
		int(elements_data.get("water", 0)),
	]


func _trait_detail_summary(traits: Array) -> String:
	if traits.is_empty():
		return "无命格"
	var lines: Array[String] = []
	for raw_trait in traits:
		lines.append("%s：%s；%s" % [
			DataTables.innate_trait_compact_summary(raw_trait),
			DataTables.innate_trait_description(raw_trait),
			DataTables.innate_trait_effect_summary(raw_trait),
		])
	return "\n".join(lines)


func _on_recruit_candidate_selected(index: int) -> void:
	if index < 0 or index >= recruit_candidate_list.item_count:
		return
	selected_recruit_candidate_id = str(recruit_candidate_list.get_item_metadata(index))
	_refresh_recruit_panel()


func _on_recruit_pressed() -> void:
	if current_game_state == null or selected_recruit_candidate_id.is_empty():
		return
	if current_game_state.recruit_candidate(selected_recruit_candidate_id):
		var members: Array = current_game_state.roster_members()
		if not members.is_empty():
			selected_party_member_id = str(members[members.size() - 1].get("id", ""))
			selected_recruit_party_member_id = selected_party_member_id
		selected_recruit_candidate_id = ""
		_refresh_recruit_panel()
		_refresh_member_info(current_game_state)
		if inventory_panel.visible:
			_refresh_inventory()


func _on_recruit_refresh_pressed() -> void:
	if current_game_state == null:
		return
	current_game_state.generate_recruit_candidates()
	selected_recruit_candidate_id = ""
	_refresh_recruit_panel()


func _on_recruit_party_member_selected(index: int) -> void:
	if index < 0 or index >= party_list.item_count:
		return
	selected_recruit_party_member_id = str(party_list.get_item_metadata(index))
	selected_party_member_id = selected_recruit_party_member_id
	_refresh_recruit_panel()
	_refresh_member_info(current_game_state)


func _on_member_info_member_selected(index: int) -> void:
	if current_game_state == null or member_info_member_list == null:
		return
	if index < 0 or index >= member_info_member_list.item_count:
		return
	selected_party_member_id = str(member_info_member_list.get_item_metadata(index))
	selected_recruit_party_member_id = selected_party_member_id
	_refresh_member_info(current_game_state)
	if inventory_panel.visible:
		_refresh_inventory()


func _on_party_move_pressed(direction: int) -> void:
	if current_game_state == null or selected_recruit_party_member_id.is_empty():
		return
	if current_game_state.move_party_member(selected_recruit_party_member_id, direction):
		_refresh_recruit_panel()
		_refresh_member_info(current_game_state)


func _on_party_toggle_active_pressed() -> void:
	if current_game_state == null or selected_recruit_party_member_id.is_empty():
		return
	var should_activate: bool = not bool(current_game_state.is_member_active(selected_recruit_party_member_id))
	if current_game_state.set_member_active(selected_recruit_party_member_id, should_activate):
		_refresh_recruit_panel()
		_refresh_member_info(current_game_state)


func _on_party_dismiss_pressed() -> void:
	if current_game_state == null or selected_recruit_party_member_id.is_empty():
		return
	var member: Dictionary = current_game_state.member_by_id(selected_recruit_party_member_id)
	if member.is_empty():
		return
	pending_release_member_id = selected_recruit_party_member_id
	release_confirmation_dialog.dialog_text = "确认放生 %s？\n角色将永久消失，装备会自动卸下，且不会返还招募资源。" % str(member.get("name", "该角色"))
	release_confirmation_dialog.popup_centered()


func _on_release_confirmed() -> void:
	if current_game_state == null or pending_release_member_id.is_empty():
		return
	if current_game_state.release_companion(pending_release_member_id):
		selected_party_member_id = _first_party_member_id()
		selected_recruit_party_member_id = selected_party_member_id
		_refresh_recruit_panel()
		_refresh_member_info(current_game_state)
		if inventory_panel.visible:
			_refresh_inventory()
	pending_release_member_id = ""


func _set_inventory_category(type_id: String) -> void:
	current_inventory_type = type_id
	_refresh_inventory()


func _refresh_inventory() -> void:
	if current_game_state == null:
		return
	_ensure_inventory_slots()

	for button in category_buttons:
		var selected: bool = false
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


func _refresh_inventory_detail(item: Dictionary) -> void:
	if inventory_detail_view != null:
		var mouse_position: Vector2 = get_viewport().get_mouse_position()
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		inventory_detail_view.show_item(item, current_game_state, mouse_position, viewport_size, selected_party_member_id)


func _on_inventory_detail_use_pressed() -> void:
	if current_game_state == null or selected_inventory_instance_id.is_empty():
		return
	var item: Dictionary = current_game_state.inventory_item_by_instance(selected_inventory_instance_id)
	if item.is_empty():
		if inventory_detail_view != null:
			inventory_detail_view.hide_item()
		return
	if DataTables.item_use_scope(str(item.get("item_id", ""))) != DataTables.ITEM_USE_SCOPE_HOME:
		return
	if current_game_state.use_inventory_item_for_member(selected_inventory_instance_id, selected_party_member_id):
		_refresh_after_inventory_action()

func show_damage_popup(amount: int, world_position: Vector2, target_key: String = "", damage_type: String = "physical", is_heal: bool = false) -> void:
	if damage_popup_layer == null:
		return
	if is_heal:
		damage_popup_layer.push_heal(amount, world_position, target_key)
	else:
		damage_popup_layer.push_damage(amount, world_position, target_key, damage_type)



func _refresh_after_inventory_action() -> void:
	if inventory_panel.visible:
		_refresh_inventory()
	if farm_panel.visible:
		_refresh_farm_panel()
	if forge_panel.visible:
		_refresh_forge_panel()
	if alchemy_panel.visible:
		_refresh_alchemy_panel()
	if current_game_state != null and not selected_inventory_instance_id.is_empty():
		var item: Dictionary = current_game_state.inventory_item_by_instance(selected_inventory_instance_id)
		_refresh_inventory_detail(item)
	else:
		if inventory_detail_view != null:
			inventory_detail_view.hide_item()


func _ensure_inventory_slots() -> void:
	_ensure_menu_panel_refs()
	if inventory_slot_buttons.size() == INVENTORY_SLOT_COUNT:
		return
	inventory_slot_buttons.clear()
	inventory_slot_instance_ids.clear()
	inventory_slot_color_rects.clear()
	inventory_slot_texture_rects.clear()
	for child in inventory_grid.get_children():
		child.queue_free()
	for index in range(INVENTORY_SLOT_COUNT):
		var slot: Button = Button.new()
		slot.name = "InventorySlot%d" % (index + 1)
		slot.custom_minimum_size = INVENTORY_SLOT_SIZE
		slot.clip_contents = true
		_style_inventory_slot_button(slot)
		var layout: CenterContainer = CenterContainer.new()
		layout.name = "SlotLayout"
		layout.set_anchors_preset(Control.PRESET_FULL_RECT)
		layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(layout)
		var icon_frame: Control = Control.new()
		icon_frame.name = "IconFrame"
		icon_frame.custom_minimum_size = INVENTORY_ICON_SIZE
		icon_frame.clip_contents = true
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(icon_frame)
		var icon: ColorRect = ColorRect.new()
		icon.name = "IconBlock"
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.color = INVENTORY_ICON_DIM_COLOR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_child(icon)
		inventory_slot_color_rects.append(icon)
		var icon_texture: TextureRect = TextureRect.new()
		icon_texture.name = "IconTexture"
		icon_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_texture.visible = false
		icon_frame.add_child(icon_texture)
		inventory_slot_texture_rects.append(icon_texture)
		slot.gui_input.connect(func(event, slot_index = index): _on_inventory_slot_gui_input(event, slot_index))
		slot.mouse_entered.connect(func(slot_index = index): _on_inventory_slot_mouse_entered(slot_index))
		slot.mouse_exited.connect(_on_inventory_slot_mouse_exited)
		inventory_grid.add_child(slot)
		inventory_slot_buttons.append(slot)
		inventory_slot_instance_ids.append("")


func _style_inventory_slot_button(slot: Button) -> void:
	var normal: StyleBoxFlat = _create_panel_style(SLOT_FILL_COLOR, SLOT_BORDER_COLOR, 1, 5, 4.0, 4.0, 4.0, 4.0, 0, Color(0, 0, 0, 0))
	var hover: StyleBoxFlat = _create_panel_style(Color(0.24, 0.17, 0.09, 1), BUTTON_HOVER_BORDER_COLOR, 1, 5, 4.0, 4.0, 4.0, 4.0, 0, Color(0, 0, 0, 0))
	var disabled: StyleBoxFlat = _create_panel_style(Color(0.1, 0.08, 0.06, 0.6), Color(0.28, 0.23, 0.18, 0.75), 1, 5, 4.0, 4.0, 4.0, 4.0, 0, Color(0, 0, 0, 0))
	slot.add_theme_stylebox_override("normal", normal)
	slot.add_theme_stylebox_override("hover", hover)
	slot.add_theme_stylebox_override("pressed", hover)
	slot.add_theme_stylebox_override("focus", hover)
	slot.add_theme_stylebox_override("disabled", disabled)


func _update_inventory_slot(index: int, item: Dictionary) -> void:
	var slot: Button = inventory_slot_buttons[index]
	var icon_block: ColorRect = inventory_slot_color_rects[index] if index < inventory_slot_color_rects.size() else null
	var icon_texture: TextureRect = inventory_slot_texture_rects[index] if index < inventory_slot_texture_rects.size() else null
	if item.is_empty():
		inventory_slot_instance_ids[index] = ""
		if icon_block != null:
			icon_block.color = INVENTORY_ICON_DIM_COLOR
			icon_block.visible = false
		if icon_texture != null:
			icon_texture.texture = null
			icon_texture.visible = false
		slot.tooltip_text = ""
		slot.disabled = true
		return
	inventory_slot_instance_ids[index] = str(item.get("instance_id", ""))
	if icon_block != null:
		icon_block.color = _inventory_slot_color(item)
	if icon_texture != null:
		icon_texture.texture = _load_inventory_icon_texture(item)
		icon_texture.visible = icon_texture.texture != null
		if icon_block != null:
			icon_block.visible = icon_texture.texture == null
	slot.tooltip_text = ""
	slot.disabled = false


func _inventory_slot_color(item: Dictionary) -> Color:
	var target_id: String = str(item.get("gain_target", DataTables.item_gain_target(str(item.get("item_id", "")))))
	var color: Color = DataTables.item_gain_target_color(target_id)
	if DataTables.item_use_scope(str(item.get("item_id", ""))) == DataTables.ITEM_USE_SCOPE_HOME:
		return Color(color.r, color.g, color.b, 0.95)
	return Color(color.r * 0.78, color.g * 0.78, color.b * 0.78, 0.88)


func _load_inventory_icon_texture(item: Dictionary) -> Texture2D:
	return DataTables.inventory_icon_texture(item)


func _on_inventory_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_on_inventory_slot_pressed(slot_index)
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_show_inventory_slot_menu(slot_index)


func _on_inventory_slot_pressed(slot_index: int) -> void:
	if current_game_state == null or slot_index < 0 or slot_index >= inventory_slot_instance_ids.size():
		return
	var instance_id: String = inventory_slot_instance_ids[slot_index]
	if instance_id.is_empty():
		return
	var now_ms: int = Time.get_ticks_msec()
	var is_double_click: bool = instance_id == last_inventory_click_instance_id and now_ms - last_inventory_click_time_ms <= INVENTORY_DOUBLE_CLICK_MS
	selected_inventory_instance_id = instance_id
	last_inventory_click_instance_id = instance_id
	last_inventory_click_time_ms = now_ms
	var clicked_item: Dictionary = current_game_state.inventory_item_by_instance(instance_id)
	var can_direct_use: bool = current_game_state.is_inventory_item_direct_usable(instance_id) or str(clicked_item.get("type", "")) == DataTables.ITEM_TYPE_EQUIPMENT
	if is_double_click and can_direct_use:
		if current_game_state.use_inventory_item_for_member(instance_id, selected_party_member_id):
			_refresh_after_inventory_action()


func _show_inventory_slot_menu(slot_index: int) -> void:
	if current_game_state == null or slot_index < 0 or slot_index >= inventory_slot_instance_ids.size():
		return
	var instance_id: String = inventory_slot_instance_ids[slot_index]
	if instance_id.is_empty():
		return
	selected_inventory_instance_id = instance_id
	inventory_menu.clear()
	var selected_item: Dictionary = current_game_state.inventory_item_by_instance(selected_inventory_instance_id)
	var use_scope: String = DataTables.item_use_scope(str(selected_item.get("item_id", "")))
	if selected_item.get("type", "") == DataTables.ITEM_TYPE_EQUIPMENT:
		inventory_menu.add_item("装备给当前成员", MENU_EQUIP)
	elif use_scope == DataTables.ITEM_USE_SCOPE_HOME:
		inventory_menu.add_item("使用", MENU_USE)
	if selected_item.get("type", "") == DataTables.ITEM_TYPE_EQUIPMENT:
		inventory_menu.add_item("强化", MENU_ENHANCE)
		inventory_menu.add_item("洗练", MENU_AFFIX)
		inventory_menu.add_item("分解", MENU_SALVAGE)
		inventory_menu.set_item_disabled(inventory_menu.item_count - 1, current_game_state.is_equipment_equipped(selected_inventory_instance_id))
	else:
		inventory_menu.add_item("丢弃", MENU_DROP)
	if use_scope == DataTables.ITEM_USE_SCOPE_HOME and inventory_menu.item_count > 0:
		inventory_menu.set_item_disabled(0, false)
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	inventory_menu.position = Vector2i(int(mouse_position.x), int(mouse_position.y))
	inventory_menu.popup()


func _on_inventory_slot_mouse_entered(slot_index: int) -> void:
	if current_game_state == null or slot_index < 0 or slot_index >= inventory_slot_instance_ids.size():
		return
	var instance_id: String = inventory_slot_instance_ids[slot_index]
	if instance_id.is_empty():
		if inventory_detail_view != null:
			inventory_detail_view.hide_item()
		return
	var item: Dictionary = current_game_state.inventory_item_by_instance(instance_id)
	if item.is_empty():
		if inventory_detail_view != null:
			inventory_detail_view.hide_item()
		return
	hovered_inventory_instance_id = instance_id
	_refresh_inventory_detail(item)


func _on_inventory_slot_mouse_exited() -> void:
	hovered_inventory_instance_id = ""
	if inventory_detail_view != null:
		inventory_detail_view.hide_item()


func _on_inventory_menu_id_pressed(id: int) -> void:
	if current_game_state == null or selected_inventory_instance_id.is_empty():
		return
	var selected_item: Dictionary = current_game_state.inventory_item_by_instance(selected_inventory_instance_id)
	if selected_item.is_empty():
		return

	match id:
		MENU_USE:
			if DataTables.item_use_scope(str(selected_item.get("item_id", ""))) == DataTables.ITEM_USE_SCOPE_HOME:
				current_game_state.use_inventory_item_for_member(selected_inventory_instance_id, selected_party_member_id)
		MENU_EQUIP:
			current_game_state.equip_item_for_member(selected_inventory_instance_id, selected_party_member_id)
		MENU_ENHANCE:
			current_game_state.enhance_equipment(selected_inventory_instance_id)
		MENU_AFFIX:
			current_game_state.add_equipment_affix(selected_inventory_instance_id)
		MENU_SALVAGE:
			pending_salvage_instance_id = selected_inventory_instance_id
			if salvage_confirmation_dialog != null:
				salvage_confirmation_dialog.popup_centered()
		MENU_DROP:
			current_game_state.drop_inventory_item(selected_inventory_instance_id)

	_refresh_inventory()
	if farm_panel.visible:
		_refresh_farm_panel()
	if forge_panel.visible:
		_refresh_forge_panel()
	if alchemy_panel.visible:
		_refresh_alchemy_panel()
	if member_info_panel.visible:
		_refresh_member_info(current_game_state)
	if hovered_inventory_instance_id.is_empty():
		if inventory_detail_view != null:
			inventory_detail_view.hide_item()
	else:
		var hovered_item: Dictionary = current_game_state.inventory_item_by_instance(hovered_inventory_instance_id)
		_refresh_inventory_detail(hovered_item)


func _inventory_item_source_text(item: Dictionary) -> String:
	if item.is_empty():
		return "非掉落"
	var payload: Dictionary = item.get("payload", {})
	var source_id: String = str(payload.get("obtain_source", item.get("obtain_source", "non_drop")))
	return DataTables.obtain_source_name(source_id)


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
	_refresh_building_upgrade_button(farm_upgrade_button, "farm")
	farm_progress_label.text = _progress_label_text("farm")
	farm_seed_slot_button.text = "选择种子" if selected_farm_seed_id.is_empty() else DataTables.resource_name(selected_farm_seed_id)
	farm_speed_item_slot_button.text = "选择加速道具" if selected_farm_speed_item_id.is_empty() else DataTables.resource_name(selected_farm_speed_item_id)
	farm_speed_status_label.text = "当前倍率：x%.1f  剩余：%s" % [current_game_state.farm_speed_multiplier(), _format_seconds(current_game_state.farm_speed_remaining_seconds())]
	_refresh_farm_slot_list()
	_refresh_farm_buttons()


func _refresh_farm_buttons() -> void:
	var selected_slot: Dictionary = _selected_farm_slot()
	var selected_status: String = str(selected_slot.get("status", "empty"))
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
	farm_detail.text = "%s  空槽：%d  成熟：%d" % [_building_level_summary("farm"), _empty_farm_slot_count(), current_game_state.ready_farm_slot_count()]


func _refresh_farm_seed_list() -> void:
	_ensure_menu_panel_refs()
	farm_seed_list.clear()
	if current_game_state == null:
		return
	for item: Dictionary in current_game_state.inventory_items_for_type(DataTables.ITEM_TYPE_CROP):
		var item_id: String = str(item.get("item_id", ""))
		if not DataTables.is_farm_seed(item_id):
			continue
		var count: int = current_game_state.inventory_item_count(item_id)
		var growth_seconds: float = DataTables.crop_growth_seconds(item_id) * DataTables.farm_growth_multiplier(current_game_state.building_level("farm"))
		var label: String = "%s x%d  产量%d  %s" % [DataTables.resource_name(item_id), count, current_game_state.farm_harvest_amount_for(item_id), _format_seconds(growth_seconds)]
		var index: int = farm_seed_list.add_item(label)
		farm_seed_list.set_item_metadata(index, item_id)


func _refresh_farm_speed_item_list() -> void:
	_ensure_menu_panel_refs()
	farm_speed_item_list.clear()
	if current_game_state == null:
		return
	for item: Dictionary in current_game_state.inventory_items_for_type(DataTables.ITEM_TYPE_MATERIAL):
		var item_id: String = str(item.get("item_id", ""))
		if not DataTables.is_farm_speed_item(item_id):
			continue
		var label: String = "%s x%d  x%.1f/%s" % [DataTables.resource_name(item_id), current_game_state.inventory_item_count(item_id), DataTables.farm_speed_item_multiplier(item_id), _format_seconds(DataTables.farm_speed_item_duration(item_id))]
		var index: int = farm_speed_item_list.add_item(label)
		farm_speed_item_list.set_item_metadata(index, item_id)


func _refresh_farm_slot_list() -> void:
	farm_slot_list.clear()
	for index in range(current_game_state.farm_slots.size()):
		var slot: Dictionary = current_game_state.farm_slots[index]
		var label: String = _farm_slot_label(index, slot)
		farm_slot_list.add_item(label)
	if selected_farm_slot_index >= 0 and selected_farm_slot_index < farm_slot_list.item_count:
		farm_slot_list.select(selected_farm_slot_index)


func _farm_slot_label(index: int, slot: Dictionary) -> String:
	var status: String = str(slot.get("status", "empty"))
	if status == "empty":
		return "%d. 空地" % (index + 1)
	var crop_id: String = str(slot.get("crop_id", ""))
	var amount: int = int(slot.get("harvest_amount", 0))
	if status == "ready":
		return "%d. %s x%d  已成熟" % [index + 1, DataTables.resource_name(crop_id), amount]
	var elapsed: float = float(slot.get("elapsed_seconds", 0.0))
	var growth: float = float(slot.get("growth_seconds", 1.0))
	var percent: int = int(clamp(elapsed / max(1.0, growth) * 100.0, 0.0, 100.0))
	return "%d. %s x%d  %d%%  剩余%s" % [index + 1, DataTables.resource_name(crop_id), amount, percent, _format_seconds(max(0.0, growth - elapsed))]


func _selected_farm_slot() -> Dictionary:
	if current_game_state == null or selected_farm_slot_index < 0 or selected_farm_slot_index >= current_game_state.farm_slots.size():
		return {}
	return current_game_state.farm_slots[selected_farm_slot_index]


func _empty_farm_slot_count() -> int:
	var count: int = 0
	for slot in current_game_state.farm_slots:
		if str(slot.get("status", "empty")) == "empty":
			count += 1
	return count


func _format_seconds(seconds: float) -> String:
	var total: int = maxi(0, int(ceil(seconds)))
	var minutes: int = int(float(total) / 60.0)
	var rest: int = total % 60
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
		if current_game_state.craft_equipment():
			_refresh_forge_panel()
			if inventory_panel.visible:
				_refresh_inventory()
			if member_info_panel.visible:
				_refresh_member_info(current_game_state)
		return
	if selected_forge_equipment_instance_id.is_empty():
		return
	var succeeded: bool = false
	if selected_forge_mode == FORGE_MODE_ENHANCE:
		succeeded = current_game_state.enhance_equipment(selected_forge_equipment_instance_id)
	elif selected_forge_mode == FORGE_MODE_REFINE:
		succeeded = current_game_state.add_equipment_affix(selected_forge_equipment_instance_id)
	if succeeded:
		_refresh_forge_equipment_list()
		_refresh_forge_panel()
		if inventory_panel.visible:
			_refresh_inventory()
		if member_info_panel.visible:
			_refresh_member_info(current_game_state)


func _refresh_forge_panel() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null:
		return
	if not [FORGE_MODE_CRAFT, FORGE_MODE_ENHANCE, FORGE_MODE_REFINE].has(selected_forge_mode):
		selected_forge_mode = FORGE_MODE_CRAFT
	_refresh_building_upgrade_button(forge_upgrade_button, "forge")
	_refresh_spirit_stone_conversion()

	forge_craft_mode_button.disabled = selected_forge_mode == FORGE_MODE_CRAFT
	forge_enhance_mode_button.disabled = selected_forge_mode == FORGE_MODE_ENHANCE
	forge_refine_mode_button.disabled = selected_forge_mode == FORGE_MODE_REFINE
	_clear_forge_material_grid()

	if forge_blueprint_row != null:
		forge_blueprint_row.visible = selected_forge_mode == FORGE_MODE_CRAFT
	if selected_forge_mode == FORGE_MODE_CRAFT:
		_refresh_forge_craft_panel()
	else:
		_refresh_forge_equipment_action_panel()


func _refresh_forge_craft_panel() -> void:
	forge_equipment_slot_button.visible = false
	forge_equipment_picker_panel.visible = false
	forge_action_button.text = "立即炼器"
	var material_cost: int = current_game_state.forge_material_cost()
	forge_action_button.disabled = not current_game_state.can_craft_equipment()
	forge_detail.text = "%s\n随机炼器  升阶率：%d%%" % [
		_building_level_summary("forge"),
		int(round(current_game_state.forge_rarity_upgrade_chance() * 100.0)),
	]
	_refresh_forge_blueprint_options()
	forge_material_grid.add_child(_create_forge_material_slot("material", "矿石", current_game_state.inventory_item_count(DataTables.ITEM_ID_ORE), material_cost))
	if forge_action_button.disabled:
		forge_hint_label.text = "矿石不足，炼器需要 %d 个矿石" % material_cost
	else:
		var output_count: int = 2 if current_game_state.building_level("forge") >= 6 else 1
		forge_hint_label.text = "消耗 %d 个矿石，立即获得 %d 件随机装备" % [material_cost, output_count]


func _refresh_forge_equipment_action_panel() -> void:
	forge_equipment_slot_button.visible = true
	var selected_item: Dictionary = current_game_state.inventory_item_by_instance(selected_forge_equipment_instance_id)
	if selected_item.is_empty() or selected_item.get("type", "") != DataTables.ITEM_TYPE_EQUIPMENT:
		selected_forge_equipment_instance_id = ""
		forge_equipment_slot_button.text = "选择装备"
	else:
		forge_equipment_slot_button.text = str(selected_item.get("name", "装备"))

	var has_selection: bool = not selected_forge_equipment_instance_id.is_empty()
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
	var rarity := str(item.get("rarity", "t1")) if not item.is_empty() else "t1"
	var current_level := int(item.get("enhance_count", 0)) if not item.is_empty() else 0
	var limit := DataTables.equipment_enhance_limit(rarity)
	var cost := DataTables.equipment_enhance_cost(rarity, current_level + 1)
	forge_detail.text = "强化消耗：随机基础属性对应灵石 x%d" % cost
	if item.is_empty():
		forge_material_grid.add_child(_create_forge_material_slot("stone", "匹配灵石", 0, cost))
		return
	if current_level >= limit:
		forge_action_button.disabled = true
		forge_hint_label.text = "强化已达到上限：+%d" % limit
		return
	var stone_ids := _matching_enhance_stone_ids(item)
	if stone_ids.is_empty():
		forge_material_grid.add_child(_create_forge_material_slot("stone", "匹配灵石", 0, cost))
		forge_hint_label.text = "缺少可强化该装备属性的灵石"
	else:
		for item_id in stone_ids:
			var current: int = current_game_state.inventory_item_count(item_id)
			forge_material_grid.add_child(_create_forge_material_slot(item_id, DataTables.resource_name(item_id), current, cost))
		forge_hint_label.text = "随机强化基础属性：+%d → +%d（上限 +%d）" % [current_level, current_level + 1, limit]


func _refresh_forge_refine_cost(item: Dictionary) -> void:
	var cost: int = int(item.get("refine_count", 0)) + 1 if not item.is_empty() else 1
	var current: int = current_game_state.inventory_item_count("refine_talisman")
	forge_detail.text = "洗练消耗：洗练符 x%d" % cost
	forge_material_grid.add_child(_create_forge_material_slot("refine_talisman", DataTables.resource_name("refine_talisman"), current, cost))
	if item.is_empty():
		return
	if current < cost:
		forge_hint_label.text = "洗练符不足"
	else:
		forge_hint_label.text = "重洗随机属性；强化等级 +%d 保持不变" % int(item.get("enhance_count", 0))


func _refresh_forge_equipment_list() -> void:
	_ensure_menu_panel_refs()
	forge_equipment_list.clear()
	if current_game_state == null:
		return
	for item: Dictionary in current_game_state.inventory_items_for_type(DataTables.ITEM_TYPE_EQUIPMENT):
		var instance_id: String = str(item.get("instance_id", ""))
		if instance_id.is_empty():
			continue
		var label: String = "%s  +%d / 洗练%d" % [str(item.get("name", "装备")), int(item.get("enhance_count", 0)), int(item.get("refine_count", 0))]
		var index: int = forge_equipment_list.add_item(label)
		forge_equipment_list.set_item_metadata(index, instance_id)


func _clear_forge_material_grid() -> void:
	_ensure_menu_panel_refs()
	for child in forge_material_grid.get_children():
		child.queue_free()


func _create_forge_material_slot(_item_id: String, item_name: String, current: int, required: int) -> PanelContainer:
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = Vector2(144, 60)
	slot.add_theme_stylebox_override("panel", _create_panel_style(CARD_FILL_COLOR, CARD_BORDER_COLOR))
	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "SlotLayout"
	slot.add_child(layout)
	var icon: TextureRect = TextureRect.new()
	icon.name = "IconPlaceholder"
	icon.custom_minimum_size = Vector2(28, 18)
	layout.add_child(icon)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = item_name
	layout.add_child(name_label)
	var count_label: Label = Label.new()
	count_label.name = "CountLabel"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.text = str(current) if required <= 0 else "%d/%d" % [current, required]
	if required > 0 and current < required:
		count_label.modulate = Color(1.0, 0.2, 0.2)
	layout.add_child(count_label)
	return slot


func _matching_enhance_stone_ids(item: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for attribute in item.get("base_attributes", []):
		var stat_id: String = attribute.get("stat", "")
		var item_id: String = DataTables.enhance_stone_item_id(stat_id)
		if not item_id.is_empty() and not result.has(item_id):
			result.append(item_id)
	return result


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
	if current_game_state == null:
		return
	if selected_alchemy_recipe_id.is_empty():
		return
	var amount: int = int(alchemy_craft_count_spinbox.value)
	if current_game_state.craft_alchemy_recipe(selected_alchemy_recipe_id, amount):
		_refresh_alchemy_recipe_list()
		_refresh_alchemy_panel()
		if inventory_panel.visible:
			_refresh_inventory()


func _refresh_alchemy_panel() -> void:
	_ensure_menu_panel_refs()
	if current_game_state == null:
		return
	_refresh_building_upgrade_button(alchemy_upgrade_button, "alchemy")
	alchemy_craft_button.text = "立即炼丹"

	if selected_alchemy_recipe_id.is_empty() or DataTables.alchemy_recipe_def(selected_alchemy_recipe_id).is_empty():
		alchemy_recipe_slot_button.text = "选择图纸"
		alchemy_max_count_label.text = "最多可做：0"
		alchemy_craft_count_spinbox.min_value = 0.0
		alchemy_craft_count_spinbox.max_value = 0.0
		alchemy_craft_count_spinbox.value = 0.0
		alchemy_craft_button.disabled = true
		alchemy_hint_label.text = "%s\n请选择图纸" % _building_level_summary("alchemy")
		_clear_alchemy_material_grid()
		return

	alchemy_recipe_slot_button.text = DataTables.resource_name(selected_alchemy_recipe_id)
	var max_count: int = current_game_state.alchemy_max_craft_count(selected_alchemy_recipe_id)
	alchemy_max_count_label.text = "%s  最多可做：%d" % [_building_level_summary("alchemy"), max_count]
	var previous_value := int(alchemy_craft_count_spinbox.value)
	alchemy_craft_count_spinbox.min_value = 0.0 if max_count <= 0 else 1.0
	alchemy_craft_count_spinbox.max_value = float(max_count)
	alchemy_craft_count_spinbox.value = float(clampi(previous_value if previous_value > 0 else max_count, int(alchemy_craft_count_spinbox.min_value), max_count))

	_refresh_alchemy_material_cost_grid()

	var learned: bool = current_game_state.known_alchemy_recipes.has(selected_alchemy_recipe_id)
	alchemy_craft_button.disabled = max_count <= 0 or not learned
	if not learned:
		alchemy_hint_label.text = "尚未学习该丹方"
	elif max_count <= 0:
		alchemy_hint_label.text = "材料不足"
	else:
		var recipe: Dictionary = DataTables.alchemy_recipe_def(selected_alchemy_recipe_id)
		var allow_output_multiplier: bool = bool(recipe.get("allow_output_multiplier", true))
		var allow_bonus_output: bool = bool(recipe.get("allow_bonus_output", true))
		var output_multiplier := 2 if current_game_state.building_level("alchemy") >= 6 and allow_output_multiplier else 1
		var bonus_output_chance := 0.02 * float(current_game_state.building_level("alchemy") - 1) if allow_bonus_output else 0.0
		alchemy_hint_label.text = "立即完成；每份基础产出 x%d，额外出丹率 %d%%" % [
			output_multiplier,
			int(round(bonus_output_chance * 100.0)),
		]


func _refresh_alchemy_material_cost_grid() -> void:
	if current_game_state == null or alchemy_material_grid == null:
		return
	_clear_alchemy_material_grid()
	if selected_alchemy_recipe_id.is_empty() or DataTables.alchemy_recipe_def(selected_alchemy_recipe_id).is_empty():
		return
	var craft_amount: int = maxi(1, int(alchemy_craft_count_spinbox.value))
	for material in DataTables.alchemy_recipe_materials(selected_alchemy_recipe_id):
		alchemy_material_grid.add_child(_create_alchemy_material_slot(material, craft_amount))


func _refresh_alchemy_recipe_list() -> void:
	_ensure_menu_panel_refs()
	alchemy_recipe_list.clear()
	if current_game_state == null:
		return
	for recipe_id in current_game_state.known_alchemy_recipes:
		if recipe_id.is_empty():
			continue
		var label: String = DataTables.resource_name(recipe_id)
		var index: int = alchemy_recipe_list.add_item(label)
		alchemy_recipe_list.set_item_metadata(index, recipe_id)


func _clear_alchemy_material_grid() -> void:
	_ensure_menu_panel_refs()
	for child in alchemy_material_grid.get_children():
		child.queue_free()


func _create_alchemy_material_slot(material: Dictionary, craft_amount: int) -> PanelContainer:
	var item_id: String = material.get("item_id", "")
	var required: int = current_game_state.alchemy_material_cost(item_id, int(material.get("amount", 0)), craft_amount)
	var current: int = current_game_state.inventory_item_count(item_id)
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = Vector2(144, 60)
	slot.add_theme_stylebox_override("panel", _create_panel_style(CARD_FILL_COLOR, CARD_BORDER_COLOR))

	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "SlotLayout"
	slot.add_child(layout)

	var icon: TextureRect = TextureRect.new()
	icon.name = "IconPlaceholder"
	icon.custom_minimum_size = Vector2(28, 18)
	layout.add_child(icon)

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = DataTables.resource_name(item_id)
	layout.add_child(name_label)

	var count_label: Label = Label.new()
	count_label.name = "CountLabel"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.text = "%d/%d" % [current, required]
	if current < required:
		count_label.modulate = Color(1.0, 0.2, 0.2)
	layout.add_child(count_label)
	return slot


func _refresh_forge_blueprint_options() -> void:
	if forge_blueprint_option == null or forge_target_button == null or current_game_state == null:
		return
	var previous_id := ""
	if forge_blueprint_option.selected >= 0:
		previous_id = str(forge_blueprint_option.get_item_metadata(forge_blueprint_option.selected))
	forge_blueprint_option.clear()
	var unlocked: Array = current_game_state.unlocked_blueprint_templates()
	unlocked.sort()
	for template_id in unlocked:
		var definition: Dictionary = DataTables.EQUIPMENT_DEFS.get(str(template_id), {})
		forge_blueprint_option.add_item(DataTables.slot_name(str(definition.get("slot", template_id))))
		forge_blueprint_option.set_item_metadata(forge_blueprint_option.item_count - 1, str(template_id))
		if str(template_id) == previous_id:
			forge_blueprint_option.select(forge_blueprint_option.item_count - 1)
	forge_blueprint_option.disabled = forge_blueprint_option.item_count == 0
	forge_target_button.disabled = forge_blueprint_option.item_count == 0 or not current_game_state.can_craft_equipment()


func _on_target_forge_pressed() -> void:
	if current_game_state == null or forge_blueprint_option == null or forge_blueprint_option.selected < 0:
		return
	var template_id := str(forge_blueprint_option.get_item_metadata(forge_blueprint_option.selected))
	if current_game_state.craft_equipment_from_template(template_id):
		_refresh_forge_panel()
		if inventory_panel.visible:
			_refresh_inventory()


func _on_salvage_confirmed() -> void:
	if current_game_state == null or pending_salvage_instance_id.is_empty():
		return
	current_game_state.salvage_equipment(pending_salvage_instance_id)
	pending_salvage_instance_id = ""
	_refresh_after_inventory_action()


func _refresh_manual_exchange_page() -> void:
	if manual_exchange_list == null or manual_exchange_button == null or current_game_state == null:
		return
	var previous_id := ""
	if manual_exchange_list.get_selected_items().size() > 0:
		previous_id = str(manual_exchange_list.get_item_metadata(manual_exchange_list.get_selected_items()[0]))
	manual_exchange_list.clear()
	var skill_ids: Array = DataTables.SKILL_EXCHANGE_DEFS.keys()
	skill_ids.sort()
	for skill_id in skill_ids:
		var exchange: Dictionary = DataTables.SKILL_EXCHANGE_DEFS.get(skill_id, {})
		var skill: Dictionary = DataTables.create_skill(str(skill_id))
		var stone_id := str(exchange.get("element_stone_id", ""))
		var label := "%s  残页3 + %s1" % [str(skill.get("name", skill_id)), DataTables.resource_name(stone_id)]
		manual_exchange_list.add_item(label)
		manual_exchange_list.set_item_metadata(manual_exchange_list.item_count - 1, str(skill_id))
		if str(skill_id) == previous_id:
			manual_exchange_list.select(manual_exchange_list.item_count - 1)
	manual_exchange_button.disabled = manual_exchange_list.get_selected_items().is_empty()


func _on_manual_exchange_pressed() -> void:
	if current_game_state == null or manual_exchange_list == null:
		return
	var selected := manual_exchange_list.get_selected_items()
	if selected.is_empty():
		return
	var skill_id := str(manual_exchange_list.get_item_metadata(selected[0]))
	if current_game_state.exchange_skill_manual(skill_id):
		_refresh_manual_exchange_page()
		if inventory_panel.visible:
			_refresh_inventory()


func _refresh_spirit_stone_conversion() -> void:
	if spirit_stone_option == null or spirit_stone_convert_button == null or current_game_state == null:
		return
	var unlocked: bool = current_game_state.building_level("forge") >= 3
	if spirit_stone_row != null:
		spirit_stone_row.visible = unlocked
	spirit_stone_option.visible = unlocked
	spirit_stone_convert_button.visible = unlocked
	spirit_stone_convert_button.disabled = not unlocked or current_game_state.inventory_item_count(DataTables.ITEM_ID_SPIRIT_STONE) < 3


func _on_spirit_stone_convert_pressed() -> void:
	if current_game_state == null or spirit_stone_option == null or spirit_stone_option.selected < 0:
		return
	var element_id := str(spirit_stone_option.get_item_metadata(spirit_stone_option.selected))
	if current_game_state.convert_spirit_stones(element_id):
		_refresh_forge_panel()
		if inventory_panel.visible:
			_refresh_inventory()
