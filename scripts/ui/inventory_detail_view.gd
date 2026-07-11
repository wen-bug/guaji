class_name InventoryDetailView
extends PanelContainer

@onready var detail_layout: HBoxContainer = $DetailLayout
@onready var target_column: VBoxContainer = $DetailLayout/TargetColumn
@onready var target_row: HBoxContainer = $DetailLayout/TargetColumn/TargetRow
@onready var title_label: Label = $DetailLayout/DetailColumn/TitleLabel
@onready var meta_label: Label = $DetailLayout/DetailColumn/MetaLabel
@onready var description_label: Label = $DetailLayout/DetailColumn/DescriptionLabel
@onready var use_button: Button = $DetailLayout/DetailColumn/UseButton

var target_icons: Array[ColorRect] = []
var detail_icon_placeholder: ColorRect = null
var detail_icon_texture: TextureRect = null

func setup() -> void:
	_ensure_detail_icon()
	_capture_target_icons()
	visible = false

func show_item(item: Dictionary, game_state, mouse_position: Vector2, viewport_size: Vector2, member_id: String = "") -> void:
	if item.is_empty():
		hide_item()
		return
	_position_panel(mouse_position, viewport_size)
	visible = true
	var target_id: String = str(item.get("gain_target", DataTables.item_gain_target(str(item.get("item_id", "")))))
	title_label.text = DataTables.inventory_display_name(item)
	meta_label.text = _item_meta_text(item, game_state, member_id)
	description_label.text = _item_description_text(item)
	_refresh_detail_icon(DataTables.inventory_icon_texture(item), target_id)
	_refresh_target_icons(target_id)
	var can_use: bool = false
	if game_state != null:
		can_use = DataTables.item_use_scope(str(item.get("item_id", ""))) == DataTables.ITEM_USE_SCOPE_HOME and game_state.is_inventory_item_usable(str(item.get("instance_id", "")))
		if str(item.get("type", "")) in [DataTables.ITEM_TYPE_EQUIPMENT, DataTables.ITEM_TYPE_SKILL_BOOK, DataTables.ITEM_TYPE_PILL] and member_id.is_empty():
			can_use = false
	use_button.visible = can_use
	use_button.disabled = not can_use
	use_button.text = "使用" if can_use else ""

func hide_item() -> void:
	visible = false
	title_label.text = ""
	meta_label.text = ""
	description_label.text = ""
	use_button.visible = false
	use_button.disabled = true
	_refresh_detail_icon(null, "")
	_refresh_target_icons("")

func _ensure_detail_icon() -> void:
	if target_column == null or detail_icon_texture != null:
		return
	detail_icon_placeholder = ColorRect.new()
	detail_icon_placeholder.name = "DetailIconPlaceholder"
	detail_icon_placeholder.custom_minimum_size = Vector2(64, 64)
	detail_icon_placeholder.color = Color(0.28, 0.23, 0.18, 0.75)
	detail_icon_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_column.add_child(detail_icon_placeholder)
	target_column.move_child(detail_icon_placeholder, 0)
	detail_icon_texture = TextureRect.new()
	detail_icon_texture.name = "DetailIconTexture"
	detail_icon_texture.custom_minimum_size = Vector2(64, 64)
	detail_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_column.add_child(detail_icon_texture)
	target_column.move_child(detail_icon_texture, 1)


func _refresh_detail_icon(texture: Texture2D, target_id: String) -> void:
	_ensure_detail_icon()
	if detail_icon_placeholder == null or detail_icon_texture == null:
		return
	var base_color: Color = DataTables.item_gain_target_color(target_id)
	detail_icon_placeholder.color = Color(base_color.r * 0.65, base_color.g * 0.65, base_color.b * 0.65, 0.72)
	detail_icon_texture.texture = texture
	detail_icon_texture.visible = texture != null
	detail_icon_placeholder.visible = texture == null


func _capture_target_icons() -> void:
	target_icons.clear()
	if target_row == null:
		return
	for child in target_row.get_children():
		if child is ColorRect:
			target_icons.append(child)

func _refresh_target_icons(target_id: String) -> void:
	if target_icons.is_empty():
		return
	for index in range(target_icons.size()):
		var icon: ColorRect = target_icons[index]
		var icon_target: String = DataTables.ITEM_GAIN_TARGET_ORDER[index] if index < DataTables.ITEM_GAIN_TARGET_ORDER.size() else ""
		var base_color: Color = DataTables.item_gain_target_color(icon_target)
		if icon_target == target_id:
			icon.color = Color(base_color.r, base_color.g, base_color.b, 0.98)
		else:
			icon.color = Color(base_color.r * 0.55, base_color.g * 0.55, base_color.b * 0.55, 0.45)

func _item_meta_text(item: Dictionary, game_state, member_id: String = "") -> String:
	var parts: Array[String] = [
		"类型：%s" % DataTables.item_type_name(str(item.get("type", ""))),
		"数量：%d" % max(1, int(item.get("count", 0))),
		"使用分组：%s" % DataTables.item_use_scope_label(DataTables.item_use_scope(str(item.get("item_id", "")))),
		"目标：%s" % DataTables.item_gain_target_label(str(item.get("gain_target", DataTables.item_gain_target(str(item.get("item_id", "")))))),
		"来源：%s" % _item_source_text(item),
	]
	if item.get("type", "") == DataTables.ITEM_TYPE_EQUIPMENT:
		parts.append("槽位：%s" % DataTables.slot_name(str(item.get("slot", ""))))
		parts.append("等级：%d" % int(item.get("equipment_level", 1)))
		if game_state != null and not member_id.is_empty():
			var requirement_text: String = game_state.equipment_requirement_text_for(item, member_id)
			if not requirement_text.is_empty():
				parts.append("需求：%s" % requirement_text)
		parts.append("强化 +%d" % int(item.get("enhance_count", 0)))
		parts.append("洗练 %d" % int(item.get("refine_count", 0)))
	elif item.get("type", "") == DataTables.ITEM_TYPE_PILL:
		var payload: Dictionary = item.get("payload", {})
		if payload.get("effect_mode", "instant") == "duration":
			parts.append("效果：%s +%d" % [DataTables.attribute_display_name(str(payload.get("stat", ""))), int(payload.get("amount", 0))])
			parts.append("持续：%d 秒" % int(payload.get("duration", 0)))
		else:
			parts.append("效果：气血 +%d / 法力 +%d" % [int(payload.get("hp", 0)), int(payload.get("mp", 0))])
	return "  ".join(parts)

func _item_description_text(item: Dictionary) -> String:
	var description: String = DataTables.inventory_display_description(item)
	if item.get("type", "") == DataTables.ITEM_TYPE_EQUIPMENT:
		var details: Array[String] = []
		details.append("攻击 %d" % int(item.get("attack_bonus", 0)))
		details.append("防御 %d" % int(item.get("defense_bonus", 0)))
		if not description.is_empty():
			details.append(description)
		return "  ".join(details)
	if item.get("type", "") == DataTables.ITEM_TYPE_PILL:
		var payload: Dictionary = item.get("payload", {})
		if payload.get("effect_mode", "instant") == "duration":
			return "%s，持续 %d 秒" % [description, int(payload.get("duration", 0))]
		return description
	return description

func _item_source_text(item: Dictionary) -> String:
	if item.is_empty():
		return "非掉落"
	var payload: Dictionary = item.get("payload", {})
	var source_id: String = str(payload.get("obtain_source", item.get("obtain_source", "non_drop")))
	return DataTables.obtain_source_name(source_id)

func _position_panel(mouse_position: Vector2, viewport_size: Vector2) -> void:
	var panel_size: Vector2 = get_combined_minimum_size()
	if panel_size == Vector2.ZERO:
		panel_size = size
	if panel_size == Vector2.ZERO:
		panel_size = Vector2(420, 132)
	var offset_x: float = 18.0
	var offset_y: float = -12.0
	var x: float = mouse_position.x + offset_x
	var y: float = mouse_position.y + offset_y
	if x + panel_size.x > viewport_size.x:
		x = mouse_position.x - panel_size.x - offset_x
	if y + panel_size.y > viewport_size.y:
		y = viewport_size.y - panel_size.y - 8.0
	if y < 8.0:
		y = 8.0
	if x < 8.0:
		x = 8.0
	position = Vector2i(int(x), int(y))
