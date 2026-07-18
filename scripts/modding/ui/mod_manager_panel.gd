extends PanelContainer
class_name ModManagerPanel

var mod_api = null
var list: VBoxContainer
var restart_label: Label
var empty_label: Label
var consent_dialog: ConfirmationDialog
var pending_consent_mod_id := ""


func _ready() -> void:
	custom_minimum_size = Vector2(320, 240)
	visible = false
	_build_ui()
	_layout_in_viewport()
	get_viewport().size_changed.connect(_layout_in_viewport)


func setup(value_mod_api) -> void:
	mod_api = value_mod_api
	refresh()


func open() -> void:
	refresh()
	_layout_in_viewport()
	visible = true
	move_to_front()


func _layout_in_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	size = Vector2(
		minf(560.0, maxf(320.0, viewport_size.x - 24.0)),
		minf(360.0, maxf(240.0, viewport_size.y - 24.0))
	)
	position = (viewport_size - size) * 0.5


func refresh() -> void:
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()
	var records: Array = mod_api.installed_mods() if mod_api != null else []
	empty_label.visible = records.is_empty()
	for record in records:
		_add_mod_row(record)
	restart_label.visible = mod_api != null and mod_api.has_pending_restart()


func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "Mod 管理"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "关闭"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.pressed.connect(func(): visible = false)
	header.add_child(close_button)

	restart_label = Label.new()
	restart_label.text = "配置已修改，重启游戏后生效"
	restart_label.modulate = Color(1.0, 0.78, 0.28)
	restart_label.visible = false
	layout.add_child(restart_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	empty_label = Label.new()
	empty_label.text = "未在用户 Mod 目录发现 PCK 或 ZIP"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(empty_label)

	consent_dialog = ConfirmationDialog.new()
	consent_dialog.title = "执行代码 Mod"
	consent_dialog.dialog_text = "此 Mod 包含 GDScript，拥有与游戏相同的文件、网络和系统访问能力。仅启用你信任的来源。"
	consent_dialog.confirmed.connect(_on_code_consent_confirmed)
	add_child(consent_dialog)


func _add_mod_row(record: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 70)
	list.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var enabled := CheckButton.new()
	enabled.button_pressed = bool(record.get("enabled", false))
	enabled.tooltip_text = "启用或禁用，重启后生效"
	enabled.toggled.connect(func(pressed: bool): _on_enabled_toggled(record, pressed))
	row.add_child(enabled)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := Label.new()
	var code_suffix := "  [代码]" if bool(record.get("contains_code", false)) else ""
	name_label.text = "%s  v%s%s" % [record.get("name", record.get("id", "")), record.get("version", ""), code_suffix]
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_label)
	var status_label := Label.new()
	status_label.text = "%s · %s" % [record.get("id", ""), _status_text(str(record.get("status", "")))]
	status_label.modulate = _status_color(str(record.get("status", "")))
	info.add_child(status_label)
	var errors: Array = record.get("errors", []) if record.get("errors", []) is Array else []
	if not errors.is_empty():
		var error_label := Label.new()
		error_label.text = str(errors[0])
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error_label.modulate = Color(1.0, 0.46, 0.42)
		info.add_child(error_label)

	var up_button := Button.new()
	up_button.text = "↑"
	up_button.tooltip_text = "提高加载优先级"
	up_button.custom_minimum_size = Vector2(34, 30)
	up_button.pressed.connect(func(): _move(record, 1))
	row.add_child(up_button)
	var down_button := Button.new()
	down_button.text = "↓"
	down_button.tooltip_text = "降低加载优先级"
	down_button.custom_minimum_size = Vector2(34, 30)
	down_button.pressed.connect(func(): _move(record, -1))
	row.add_child(down_button)


func _on_enabled_toggled(record: Dictionary, pressed: bool) -> void:
	if mod_api == null:
		return
	var mod_id := str(record.get("id", ""))
	if pressed and bool(record.get("contains_code", false)) and str(record.get("status", "")) == "permission_required":
		pending_consent_mod_id = mod_id
		consent_dialog.popup_centered()
		call_deferred("refresh")
		return
	mod_api.set_mod_enabled(mod_id, pressed)
	call_deferred("refresh")


func _on_code_consent_confirmed() -> void:
	if mod_api != null and not pending_consent_mod_id.is_empty():
		mod_api.grant_code_consent(pending_consent_mod_id)
	pending_consent_mod_id = ""
	refresh()


func _move(record: Dictionary, direction: int) -> void:
	if mod_api != null:
		mod_api.move_mod(str(record.get("id", "")), direction)
	refresh()


func _status_text(status: String) -> String:
	return {
		"loaded": "已加载",
		"discovered": "已发现",
		"pending": "等待加载",
		"disabled": "未加载",
		"permission_required": "需要代码授权",
		"failed": "加载失败",
		"invalid": "包无效",
	}.get(status, status)


func _status_color(status: String) -> Color:
	if status == "loaded":
		return Color(0.42, 0.9, 0.56)
	if status in ["failed", "invalid"]:
		return Color(1.0, 0.4, 0.36)
	if status == "permission_required":
		return Color(1.0, 0.74, 0.26)
	return Color(0.78, 0.78, 0.78)
